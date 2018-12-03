using System;
using System.Diagnostics;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Rhino;
using Rhino.Geometry;
using Rhino.DocObjects;
using Rhino.Display;
using Rhino.Commands;
using Rhino.Input;
using KhepriBase;


namespace KhepriRhinoceros {
    class Primitives : KhepriBase.Primitives {

        RhinoDoc doc;

        public Primitives(RhinoDoc doc) : base() {
            this.doc = doc;
        }


        R and_delete<R>(R obj_to_return, RhinoObject obj_to_delete) {
            doc.Objects.Delete(obj_to_delete, true);
            return obj_to_return;
        }
        R and_delete<R>(R obj_to_return, RhinoObject[] objs_to_delete) {
            foreach (RhinoObject obj_to_delete in objs_to_delete) {
                doc.Objects.Delete(obj_to_delete, true);
            }
            return obj_to_return;
        }
        R singleton_element<R>(R[] rs) {
            Debug.Assert(rs.Length == 1);
            return rs[0];
        }

        T RotateAndTranslate<T>(Point3d c, double angle, T t) where T : GeometryBase {
            t.Rotate(angle, Vector3d.ZAxis, Point3d.Origin);
            t.Translate(new Vector3d(c));
            return t;
        }

        T[] RotateAndTranslate<T>(Point3d c, double angle, T[] ts) where T : GeometryBase {
            foreach (T t in ts) {
                t.Rotate(angle, Vector3d.ZAxis, Point3d.Origin);
                t.Translate(new Vector3d(c));
            }
            return ts;
        }

        public void SetView(Point3d position, Point3d target, double lens, bool perspective, string mode) {
            RhinoView view = doc.Views.Find("Perspective", true);
            if (!view.Maximized) {
                view.Maximized = true;
            }
            RhinoViewport viewport = view.ActiveViewport;
            bool current_perspective = viewport.IsPerspectiveProjection;
            if (perspective != current_perspective) {
                if (perspective) {
                    viewport.ChangeToPerspectiveProjection(true, lens);
                } else {
                    viewport.ChangeToParallelProjection(true);
                }
            }
            viewport.Camera35mmLensLength = lens;
            viewport.SetCameraLocation(position, false);
            viewport.SetCameraTarget(target, false);
            viewport.DisplayMode = DisplayModeDescription.FindByName(mode);
            view.Redraw();
        }
        public void View(Point3d position, Point3d target, double lens) => SetView(position, target, lens, true, "Shaded");
        public void ViewTop() => SetView(new Point3d(0.0, 0.0, 1.0), Point3d.Origin, 50.0, false, "Wireframe");
        public Point3d ViewCamera() {
            RhinoView view = doc.Views.Find("Perspective", true);
            return view.ActiveViewport.CameraLocation;
        }
        public Point3d ViewTarget() {
            RhinoView view = doc.Views.Find("Perspective", true);
            return view.ActiveViewport.CameraTarget;
        }
        public double ViewLens() {
            RhinoView view = doc.Views.Find("Perspective", true);
            return view.ActiveViewport.Camera35mmLensLength;
        }
        public byte Sync() => 1;
        public byte Disconnect() => 2;
        public void Delete(Guid id) {
            doc.Objects.Delete(id, true);
        }
        public void DeleteMany(Guid[] ids) {
            doc.Objects.Delete(ids, true);
        }
        public int DeleteAll() {
            int count = doc.Objects.Count();
            foreach (RhinoObject o in doc.Objects) {
                doc.Objects.Delete(o, true);
            }
            return count;
        }
        public int DeleteAllInLayer(String name) {
            return doc.Objects.Delete(doc.Objects.FindByLayer(name).Select(o => o.Id).ToArray(), true);
        }

        public Guid Point(Point3d p) => doc.Objects.AddPoint(p);
        public Point3d PointPosition(Guid id) => ((Point)doc.Objects.Find(id).Geometry).Location;
        public Guid PolyLine(Point3d[] pts) => doc.Objects.AddPolyline(pts);
        public Point3d[] LineVertices(RhinoObject obj) {
            PolylineCurve polyline_curve = (PolylineCurve)obj.Geometry;
            Polyline polyline = new Polyline();
            Debug.Assert(polyline_curve.TryGetPolyline(out polyline));
            return polyline.ToArray();
        }
        public Guid ClosedPolyLine(Point3d[] pts) => doc.Objects.AddPolyline(pts.Concat(new[] { pts[0] }));
        public Guid Spline(Point3d[] pts) => doc.Objects.AddCurve(Curve.CreateInterpolatedCurve(pts, 3));
        public Guid ClosedSpline(Point3d[] pts) => doc.Objects.AddCurve(Curve.CreateInterpolatedCurve(pts.Concat(new[] { pts[0] }), 3));
        public Guid Circle(Point3d c, Vector3d n, double r) => doc.Objects.AddCircle(new Circle(new Plane(c, n), r));
        Circle CircleFrom(RhinoObject obj) {
            Circle circle = new Circle();
            Debug.Assert(((Curve)obj.Geometry).TryGetCircle(out circle));
            return circle;
        }
        public Point3d CircleCenter(RhinoObject obj) => CircleFrom(obj).Center;
        public Vector3d CircleNormal(RhinoObject obj) => CircleFrom(obj).Normal;
        public double CircleRadius(RhinoObject obj) => CircleFrom(obj).Radius;
        public Guid Ellipse(Point3d c, Vector3d n, double radius_x, double radius_y) =>
            doc.Objects.AddEllipse(new Ellipse(new Plane(c, n), radius_x, radius_y));
        Plane RotatedPlane(Point3d c, Vector3d n, double startAngle) {
            Plane pl = new Plane(c, n);
            if (startAngle != 0) {
                Debug.Assert(pl.Rotate(startAngle, n));
            }
            return pl;
        }
        public Guid Arc(Point3d c, Vector3d n, double radius, double startAngle, double endAngle) =>
            doc.Objects.AddArc(//new Arc(RotatedPlane(c, n, startAngle), radius, endAngle - startAngle)
                new Arc(new Circle(new Plane(c, n), radius), new Interval(startAngle, endAngle)));

        /*
                public Guid Text(string str, Point3d corner, Vector3d vx, Vector3d vy, double height) {
                    vx = vx.GetNormal();
                    vy = vy.GetNormal();
                    Vector3d vz = vx.CrossProduct(vy);
                    DBText acText = new DBText();
                    acText.Position = Point3d.Origin;
                    acText.Height = height;
                    acText.TextString = str;
                    //acText.TransformBy(Matrix3d.Displacement(Vector3d.ZAxis * height / 2));
                    acText.TransformBy(Matrix3d.AlignCoordinateSystem(
                        Point3d.Origin, Vector3d.XAxis, Vector3d.YAxis, Vector3d.ZAxis,
                        corner, vx, vy, vz)
                        );
                    return acText;
                }
                public Guid SurfaceFromCurve(Guid curve) {
                    using (curve)
                    using (DBObjectCollection coll = new DBObjectCollection()) {
                        coll.Add(curve);
                        DBObjectCollection curves = Region.CreateFromCurves(coll);
                        return (Guid)curves[0];
                    }
                }
        */

        public Brep SurfaceFromCurve(RhinoObject obj) =>
            and_delete(Brep.CreatePlanarBreps(AsCurve(obj))[0], obj);
        public Brep[] SurfaceFromCurves(RhinoObject[] objs) =>
            and_delete(Brep.CreatePlanarBreps(objs.Select(AsCurve).ToArray()), objs);
        public Guid SurfaceCircle(Point3d c, Vector3d n, double r) =>
            doc.Objects.AddBrep(
                Brep.CreatePlanarBreps(
                    (new Circle(new Plane(c, n), r)).ToNurbsCurve())[0]);
        /*
        public Guid SurfaceEllipse(Point3d c, Vector3d n, Vector3d majorAxis, double radiusRatio) =>
            SurfaceFromCurve(new Ellipse(c, n, majorAxis, radiusRatio, 0, 2 * Math.PI));
        public Guid SurfaceArc(Point3d c, Vector3d n, double radius, double startAngle, double endAngle) =>
            SurfaceFromCurve(new Arc(c, n, radius, startAngle, endAngle));
            */
        public Guid SurfaceClosedPolyLine(Point3d[] pts) =>
            (pts.Length > 2 && pts.Length <= 4) ?
                doc.Objects.AddSurface(
                    pts.Length == 3 ?
                        NurbsSurface.CreateFromCorners(pts[0], pts[1], pts[2]) :
                        NurbsSurface.CreateFromCorners(pts[0], pts[1], pts[2], pts[3])) :
                doc.Objects.AddBrep(
                    Brep.CreatePlanarBreps(new PolylineCurve(pts))[0]);

        public Guid Sphere(Point3d c, double r) => doc.Objects.AddSphere(new Sphere(c, r));
        public Guid Torus(Point3d c, Vector3d vz, double majorRadius, double minorRadius) =>
            doc.Objects.AddSurface(new Torus(new Plane(c, vz), majorRadius, minorRadius).ToRevSurface());
        public Brep Cylinder(Point3d bottom, double radius, Point3d top) =>
            Brep.CreateFromCylinder(new Cylinder(new Circle(new Plane(bottom, top - bottom), radius), bottom.DistanceTo(top)), true, true);
        public Brep Cone(Point3d bottom, double radius, Point3d top) =>
            Brep.CreateFromCone(new Cone(new Plane(bottom, top - bottom), bottom.DistanceTo(top), radius), true);
        public Brep ConeFrustum(Point3d bottom, double bottom_radius, Point3d top, double top_radius) {
            Vector3d vec = top - bottom;
            Circle bottomCircle = new Circle(new Plane(bottom, vec), bottom_radius);
            Circle topCircle = new Circle(new Plane(top, vec), top_radius);
            LineCurve shapeCurve = new LineCurve(bottomCircle.PointAt(0), topCircle.PointAt(0));
            Line axis = new Line(bottom, top);
            return Brep.CreateFromRevSurface(RevSurface.Create(shapeCurve, axis), true, true);
        }
        public Brep Box(Point3d corner, Vector3d vx, Vector3d vy, double dx, double dy, double dz) {
            Vector3d vz = Vector3d.CrossProduct(vx, vy);
            vx.Unitize();
            vy.Unitize();
            vz.Unitize();
            vx = vx * dx;
            vy = vy * dy;
            vz = vz * dz;
            return Brep.CreateFromBox(new Point3d[] {
                corner,
                corner + vx,
                corner + vx + vy,
                corner + vy,
                corner + vz,
                corner + vx + vz,
                corner + vx + vy + vz,
                corner + vy + vz });
        }
        public Brep XYCenteredBox(Point3d corner, Vector3d vx, Vector3d vy, double dx, double dy, double dz) {
            Vector3d vz = Vector3d.CrossProduct(vx, vy);
            vx.Unitize();
            vy.Unitize();
            vz.Unitize();
            vx = vx * (dx / 2);
            vy = vy * (dy / 2);
            vz = vz * dz;
            return Brep.CreateFromBox(new Point3d[] {
                corner - vx - vy,
                corner + vx - vy,
                corner + vx + vy,
                corner - vx + vy,
                corner - vx - vy + vz,
                corner + vx - vy + vz,
                corner + vx + vy + vz,
                corner - vx + vy + vz });
        }
        /*               public Guid IrregularPyramidMesh(Point3d[] pts, Point3d apex) {
                           Document doc = Application.DocumentManager.MdiActiveDocument;
                           using (doc.LockDocument())
                           using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                               BlockTable bt = (BlockTable)tr.GetObject(doc.Database.BlockTableId, OpenMode.ForRead);
                               BlockTableRecord btr = (BlockTableRecord)tr.GetObject(bt[BlockTableRecord.ModelSpace], OpenMode.ForWrite);
                               PolyFaceMesh pfm = new PolyFaceMesh();
                               Guid id = btr.AppendGuid(pfm);
                               tr.AddNewlyCreatedDBObject(pfm, true);
                               foreach (var p in pts) {
                                   using (var v = new PolyFaceMeshVertex(p)) {
                                       pfm.AppendVertex(v);
                                       tr.AddNewlyCreatedDBObject(v, true);
                                   }
                               }
                               using (var v = new PolyFaceMeshVertex(apex)) {
                                   pfm.AppendVertex(v);
                                   tr.AddNewlyCreatedDBObject(v, true);
                               }
                               int n = pts.Length;
                               for (int i = 0; i < n; i++) {
                                   var face = new FaceRecord((short)(i + 1), (short)((i + 1) % n + 1), (short)(n + 1), (short)(n + 1));
                                   pfm.AppendFaceRecord(face);
                                   tr.AddNewlyCreatedDBObject(face, true);
                               }
                               for (int i = 2; i < n; i++) {
                                   var face = new FaceRecord((short)1, (short)i, (short)(i + 1), (short)(i + 1));
                                   pfm.AppendFaceRecord(face);
                                   tr.AddNewlyCreatedDBObject(face, true);
                               }
                               tr.Commit();
                               return id;
                           }
                       }
                       public Guid IrregularPyramid(Point3d[] pts, Point3d apex) {
                           Document doc = Application.DocumentManager.MdiActiveDocument;
                           using (doc.LockDocument())
                           using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                               BlockTable bt = (BlockTable)tr.GetObject(doc.Database.BlockTableId, OpenMode.ForRead);
                               BlockTableRecord btr = (BlockTableRecord)tr.GetObject(bt[BlockTableRecord.ModelSpace], OpenMode.ForWrite);
                               Point3dCollection vertarray = new Point3dCollection(pts);
                               vertarray.Add(apex);
                               Int32Collection facearray = new Int32Collection();
                               int n = pts.Length;
                               for (int i = 0; i < n; i++) {
                                   facearray.Add(3);
                                   facearray.Add(i);
                                   facearray.Add((i + 1) % n);
                                   facearray.Add(n);
                               }
                               facearray.Add(n);
                               for (int i = n - 1; i >= 0; i--) facearray.Add(i);
                               SubDMesh sdm = new SubDMesh();
                               sdm.SetDatabaseDefaults();
                               sdm.SetSubDMesh(vertarray, facearray, 0);
                               btr.AppendGuid(sdm);
                               tr.AddNewlyCreatedDBObject(sdm, true);
                               Solid3d sol = sdm.ConvertToSolid(false, false);
                               Guid id = btr.AppendGuid(sol);
                               tr.AddNewlyCreatedDBObject(sol, true);
                               sdm.Erase();
                               tr.Commit();
                               return id;
                           }
                       }
                       */
        public Brep IrregularPyramid(Point3d[] bpts, Point3d apex) {
            int n = bpts.Length;
            double tol = doc.ModelAbsoluteTolerance;
            List<Brep> breps = new List<Brep>();
            for (int i = 0; i < n; i++) {
                breps.Add(Brep.CreateFromCornerPoints(bpts[i], bpts[(i + 1) % n], apex, tol));
            }
            Brep[] joined = Brep.JoinBreps(breps.AsEnumerable(), tol);
            Debug.Assert(joined.Length == 1);
            return joined[0].CapPlanarHoles(tol);
        }
        public Brep IrregularPyramidFrustum(Point3d[] bpts, Point3d[] tpts) {
            int n = bpts.Length;
            double tol = doc.ModelAbsoluteTolerance;
            List<Brep> breps = new List<Brep>();
            for (int i = 0; i < n; i++) {
                breps.Add(Brep.CreateFromCornerPoints(bpts[i], bpts[(i + 1) % n], tpts[(i + 1) % n], tpts[i], tol));
            }
            Brep[] joined = Brep.JoinBreps(breps.AsEnumerable(), tol);
            Debug.Assert(joined.Length == 1);
            return joined[0].CapPlanarHoles(tol);
        }
        /*
                       public Guid MeshFromGrid(int m, int n, Point3d[] pts, bool closedM, bool closedN) =>
                           new PolygonMesh(PolyMeshType.SimpleMesh, m, n, new Point3dCollection(pts), closedM, closedN);
                       public Guid SurfaceFromGrid(int m, int n, Point3d[] pts, bool closedM, bool closedN, int level) {
                           Point3dCollection vertarray = new Point3dCollection(pts);
                           Int32Collection facearray = new Int32Collection();
                           int rm = closedM ? m : m - 1;
                           int rn = closedN ? n : n - 1;
                           for (int i = 0; i < rm; i++) {
                               for (int j = 0; j < rn; j++) {
                                   facearray.Add(4);
                                   facearray.Add(i * n + j);
                                   facearray.Add(i * n + (j + 1) % n);
                                   facearray.Add(((i + 1) % m) * n + (j + 1) % n);
                                   facearray.Add(((i + 1) % m) * n + j);
                               }
                           }
                           SubDMesh sdm = new SubDMesh();
                           sdm.SetDatabaseDefaults();
                           sdm.SetSubDMesh(vertarray, facearray, level);
                           return sdm;
                       }
                       public Guid SolidFromGrid(int m, int n, Point3d[] pts, bool closedM, bool closedN, int level, double thickness) {
                           using (SubDMesh sdm = SurfaceFromGrid(m, n, pts, closedM, closedN, level) as SubDMesh) {
                               DBSurface s = sdm.ConvertToSurface(true, true);
                               return s.Thicken(thickness, true);
                           }
                       }
                       */
        public Curve AsCurve(RhinoObject obj) =>
            (obj.Geometry as Curve);
        public Brep AsBrep(RhinoObject obj) =>
            (obj.Geometry as Brep) ?? (obj.Geometry as Extrusion)?.ToBrep();

        //        public AsGeometry(RhinoObject obj) => 
        public BrepFace AsBrepFace(RhinoObject obj) {
            Brep brep = AsBrep(obj);
            Debug.Assert(brep.Faces.Count == 1, "Brep '" + obj + "' has more than one face!");
            return brep.Faces[0];
        }
        public Surface AsSurface(RhinoObject obj) {
            Surface srf = obj.Geometry as Surface;
            if (srf != null) {
                return srf;
            } else {
                Brep brep = obj.Geometry as Brep;
                if (brep != null && brep.Faces.Count == 1) {
                    return brep.Faces[0];
                }
            }
            throw new Exception("Unable to obtain a surface");
        }

        public Brep[] Thicken(RhinoObject obj, double thickness) {
            Brep brep = AsBrep(obj);
            return and_delete(
                brep.Faces.Select(face =>
                    Brep.CreateFromOffsetFace(
                        face,
                        thickness,
                        doc.ModelAbsoluteTolerance,
                        true,
                        true)).ToArray(),
                obj);
        }
        static double sphPhi(Vector3d v) => (v.X == 0.0 && v.Y == 0.0) ? 0.0 : Math.Atan2(v.Y, v.X);
        static Vector3d vpol(double rho, double phi) => new Vector3d(rho * Math.Cos(phi), rho * Math.Sin(phi), 0);

        public double[] CurveDomain(RhinoObject obj) {
            Curve c = AsCurve(obj);
            return new double[] { c.Domain.T0, c.Domain.T1 };
        }

        public double CurveLength(RhinoObject obj) {
            Curve c = AsCurve(obj);
            return c.GetLength();
        }
        public Plane CurveFrameAt(RhinoObject obj, double t) {
            Curve c = AsCurve(obj);
            Plane pl;
            check(c.FrameAt(t, out pl));
            return pl;
        }

        private void check(bool v) {
            if (!v) {
                throw new Exception("The operation failed");
            }
        }

/*
        public Frame3d CurveFrameAtLength(Guid ent, double l) {
            Curve c = ent as Curve;
            double t = c.GetParameterAtDistance(l);
            Point3d origin = c.GetPointAtParameter(t);
            Vector3d vt = c.GetFirstDerivative(t);
            Vector3d vn = c.GetSecondDerivative(t);
            Vector3d vx = (vn.Length < 1e-14) ? vpol(1, sphPhi(vt) + Math.PI / 2) : vn;
            Vector3d vy = vt.CrossProduct(vx);
            return new Frame3d(origin, vx / vx.Length, vy / vy.Length);
        }
        public Frame3d CurveClosestFrameTo(Guid ent, Point3d p) {
            Curve c = ent as Curve;
            Point3d ptOnCurve = c.GetClosestPointTo(p, false);
            return CurveFrameAt(c, c.GetParameterAtPoint(ptOnCurve));
        }
        public Point3dCollection CurveLocations(Curve c, int n) {
            Point3dCollection pts = new Point3dCollection();
            double startParam = c.StartParam;
            double sep = (c.EndParam - startParam) / n;
            for (int i = 0; i < n + 1; i++) {
                pts.Add(c.GetPointAtParameter(startParam + sep * i));
            }
            return pts;
        }
        public Curve PolyFrom(Arc arc, Document doc, Transaction tr) {
            BlockTable bt = (BlockTable)tr.GetObject(doc.Database.BlockTableId, OpenMode.ForRead);
            BlockTableRecord btr = (BlockTableRecord)tr.GetObject(bt[BlockTableRecord.ModelSpace], OpenMode.ForWrite);
            /*
            // Plane pl = new Plane(new Point3d(0, 0, 0), arc.Normal);
            double deltaAng = arc.EndAngle - arc.StartAngle;
            if (deltaAng < 0) { deltaAng += 2 * Math.PI; }
            double bulge = Math.Tan(deltaAng * 0.25);
            Polyline poly = new Polyline();
            poly.AddVertexAt(0, new Point2d(arc.StartPoint.X, arc.StartPoint.Y), bulge, 0, 0);
            poly.AddVertexAt(1, new Point2d(arc.EndPoint.X, arc.EndPoint.Y), 0, 0, 0);
            poly.LayerId = arc.LayerId;
            poly.Normal = arc.Normal;
            arc.Erase();
            return poly;
            */
        /*            Point3dCollection pts = CurveLocations(arc, 32);
                    arc.Erase();
                    Curve c = new Polyline3d(Poly3dType.SimplePoly, pts, false);
                    btr.AppendGuid(c);
                    tr.AddNewlyCreatedDBObject(c, true);
                    return c;
                }
                */

        public Guid JoinCurves(Guid[] ids) {
            PolyCurve curve = new PolyCurve();
            foreach (Guid id in ids) {
                Curve crv = ((Curve)doc.Objects.Find(id).Geometry);
                curve.Append(crv.ToNurbsCurve());
            }
            foreach (Guid id in ids) {
                doc.Objects.Delete(id, true);
            }
            return doc.Objects.Add(curve);
        }
        /*
                public DBNurbSurface AsNurbSurface(Guid ent) {
                    var ns = DBSurface.CreateFrom(ent).ConvertToNurbSurface();
                    if (ns.Length != 1) {
                        throw new AcadException(Autodesk.AutoCAD.Runtime.ErrorStatus.InvalidInput,
                            "Generated zero or more than one Nurb surface");
                    } else {
                        return ns[0];
                    }
                }
                public Guid NurbSurfaceFrom(Guid id) {
                    Document doc = Application.DocumentManager.MdiActiveDocument;
                    using (doc.LockDocument())
                    using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                        return addAndCommit(AsNurbSurface(tr.GetObject(id, OpenMode.ForRead) as Guid), doc, tr);
                    }
                }
                */
        public double[] SurfaceDomain(RhinoObject obj) {
            Surface s = AsSurface(obj);
            Interval domain0 = s.Domain(0);
            Interval domain1 = s.Domain(1);
            return new double[] {
                domain0.T0, domain0.T1,
                domain1.T0, domain1.T1 };
        }
        public Plane SurfaceFrameAt(RhinoObject obj, double u, double v) {
            Surface s = AsSurface(obj);
            Plane pl;
            check(s.FrameAt(u, v, out pl));
            return pl;
        }
        
        /*
        public Brep Extrusion(RhinoObject obj, Vector3d dir) {
            if (obj.Geometry is Curve) {
                return and_delete(Surface.CreateExtrusion(obj.Geometry as Curve, dir).ToBrep(), obj);
            } else { // Must be a surface
                Curve[] curves = Curve.JoinCurves(AsBrep(obj).DuplicateEdgeCurves());
                Debug.Assert(curves.Length == 1);
                Surface surf = Surface.CreateExtrusion(curves[0], dir);
                return and_delete(surf.ToBrep().CapPlanarHoles(doc.ModelAbsoluteTolerance), obj);
            }
        }
        /*
        public Guid Sweep(Guid pathId, Guid profileId, double rotation, double scale) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                Curve path = tr.GetObject(pathId, OpenMode.ForRead) as Curve;
                Guid profile = tr.GetObject(profileId, OpenMode.ForWrite) as Guid;
                Frame3d f = CurveFrameAt(path, CurveDomain(path)[0]);
                profile.TransformBy(Matrix3d.AlignCoordinateSystem(
                    Point3d.Origin, Vector3d.XAxis, Vector3d.YAxis, Vector3d.ZAxis,
                    f.origin, f.xaxis, f.yaxis, f.zaxis));
                SweepOptionsBuilder sob = new SweepOptionsBuilder();
                sob.Align = SweepOptionsAlignOption.NoAlignment;
                sob.Bank = false;
                sob.BasePoint = path.StartPoint;
                sob.TwistAngle = rotation;
                sob.ScaleFactor = scale;
                if (profile is Region) {
                    using (Solid3d s = new Solid3d()) {
                        s.CreateSweptSolid(profile, path, sob.ToSweepOptions());
                        profile.Erase();
                        path.Erase();
                        return addAndCommit(s, doc, tr);
                    }
                } else {
                    using (SweptSurface s = new SweptSurface()) {
                        s.CreateSweptSurface(profile, path, sob.ToSweepOptions());
                        profile.Erase();
                        path.Erase();
                        return addAndCommit(s, doc, tr);
                    }
                }
            }
        }
        public Guid Loft(Guid[] profilesIds, Guid[] guidesIds, bool ruled, bool closed) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                Guid[] profiles = profilesIds.Select(i => tr.GetObject(i, OpenMode.ForRead) as Guid).ToArray();
                Guid[] guides = guidesIds.Select(i => tr.GetObject(i, OpenMode.ForRead) as Guid).ToArray();
                LoftOptionsBuilder lob = new LoftOptionsBuilder();
                lob.NormalOption = LoftOptionsNormalOption.NoNormal;
                lob.Ruled = ruled;
                lob.Closed = closed;
                if (profiles[0] is Region) {
                    using (Solid3d s = new Solid3d()) {
                        s.CreateLoftedSolid(profiles, guides, null, lob.ToLoftOptions());
                        return addAndCommit(s, doc, tr);
                    }
                } else {
                    using (LoftedSurface s = new LoftedSurface()) {
                        s.CreateLoftedSurface(profiles, guides, null, lob.ToLoftOptions());
                        return addAndCommit(s, doc, tr);
                    }
                }
            }
        }
        */

        public void Unite(Guid objId0, Guid objId1) {
            //TO BE DONE
        }
        public Guid[] Intersect(RhinoObject obj0, RhinoObject obj1) {
            Brep brep0 = AsBrep(obj0);
            Brep brep1 = AsBrep(obj1);
            for (int e = 5; e > 2; e--) {
                Brep[] newBreps = Brep.CreateBooleanIntersection(brep0, brep1, Math.Pow(10, -e));
                if (newBreps != null) {
                    doc.Objects.Delete(obj0, true);
                    doc.Objects.Delete(obj1, true);
                    return newBreps.Select(brep => doc.Objects.AddBrep(brep)).ToArray();
                }
            }
            Point3d c1 = brep1.Vertices[0].Location;
            if (brep0.IsPointInside(c1, doc.ModelAbsoluteTolerance, false)) {
                doc.Objects.Delete(obj0, true);
                return new[] { obj1.Id };
            } else {
                Point3d c0 = brep0.Vertices[0].Location;
                if (brep1.IsPointInside(c0, doc.ModelAbsoluteTolerance, false)) {
                    doc.Objects.Delete(obj1, true);
                    return new[] { obj1.Id };
                } else {
                    doc.Objects.Delete(obj0, true);
                    doc.Objects.Delete(obj1, true);
                    return new Guid[] { };
                }
            }
        }
        public Guid[] Subtract(RhinoObject obj0, RhinoObject obj1) {
            Brep brep0 = AsBrep(obj0);
            Brep brep1 = AsBrep(obj1);
            for (int e = 5; e > 2; e--) {
                Brep[] newBreps = Brep.CreateBooleanDifference(brep0, brep1, Math.Pow(10, -e));
                if (newBreps != null) {
                    doc.Objects.Delete(obj0, true);
                    doc.Objects.Delete(obj1, true);
                    return newBreps.Select(brep => doc.Objects.AddBrep(brep)).ToArray();
                }
            }
            Point3d c1 = brep1.Vertices[0].Location;
            if (brep0.IsPointInside(c1, doc.ModelAbsoluteTolerance, false)) {
                return new[] { Guid.Empty }; //Signal failure
            } else {
                Point3d c0 = brep0.Vertices[0].Location;
                if (brep1.IsPointInside(c0, doc.ModelAbsoluteTolerance, false)) {
                    doc.Objects.Delete(obj0, true);
                    doc.Objects.Delete(obj1, true);
                    return new Guid[] { };
                } else {
                    doc.Objects.Delete(obj1, true);
                    return new Guid[] { obj0.Id };
                }
            }
        }
        public void Slice(Guid id, Point3d p, Vector3d n) {
            //TO BE DONE
        }
        /*
        public Guid Revolve(Guid profileId, Point3d p, Vector3d n, double startAngle, double amplitude) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                Guid profile = tr.GetObject(profileId, OpenMode.ForWrite) as Guid;
                RevolveOptionsBuilder rob = new RevolveOptionsBuilder();
                rob.CloseToAxis = false;
                rob.DraftAngle = 0;
                rob.TwistAngle = 0;
                if (profile is Region) {
                    using (Solid3d sol = new Solid3d()) {
                        sol.CreateRevolvedSolid(profile, p, n, amplitude, startAngle, rob.ToRevolveOptions());
                        return addAndCommit(sol, doc, tr);
                    }
                } else {
                    using (RevolvedSurface ss = new RevolvedSurface()) {
                        ss.CreateRevolvedSurface(profile, p, n, amplitude, startAngle, rob.ToRevolveOptions());
                        return addAndCommit(ss, doc, tr);
                    }
                }
            }
        }
        public void Move(Guid id, Vector3d v) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                Guid sh = tr.GetObject(id, OpenMode.ForWrite) as Guid;
                sh.TransformBy(Matrix3d.Displacement(v));
                tr.Commit();
            }
        }
        public void Scale(Guid id, Point3d p, double s) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                Guid sh = tr.GetObject(id, OpenMode.ForWrite) as Guid;
                sh.TransformBy(Matrix3d.Scaling(s, p));
                tr.Commit();
            }
        }
        public void Rotate(Guid id, Point3d p, Vector3d n, double a) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                Guid sh = tr.GetObject(id, OpenMode.ForWrite) as Guid;
                sh.TransformBy(Matrix3d.Rotation(a, n, p));
                tr.Commit();
            }
        }
        public Guid Mirror(Guid id, Point3d p, Vector3d n, bool copy) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                Guid sh = tr.GetObject(id, OpenMode.ForWrite) as Guid;
                if (copy) {
                    sh = sh.Clone() as Guid;
                    BlockTable bt = (BlockTable)tr.GetObject(doc.Database.BlockTableId, OpenMode.ForRead);
                    BlockTableRecord btr = (BlockTableRecord)tr.GetObject(bt[BlockTableRecord.ModelSpace], OpenMode.ForWrite);
                    id = btr.AppendGuid(sh);
                    tr.AddNewlyCreatedDBObject(sh, true);
                }
                sh.TransformBy(Matrix3d.Mirroring(new Plane(p, n)));
                tr.Commit();
                return id;
            }
        }
        */
        public Point3d[] GetPosition(string prompt) {
            Point3d location;
            Result res = RhinoGet.GetPoint(prompt, false, out location);
            if (res == Result.Success) {
                return new Point3d[] { location };
            } else {
                return new Point3d[] { };
            }
        }

        public Guid[] GetShapeOfType(string prompt, ObjectType filter) {
            ObjRef objref;
            Result rc = RhinoGet.GetOneObject(prompt, false, filter, out objref);
            if (rc == Result.Success) {
                return new Guid[] { objref.ObjectId };
            } else {
                return new Guid[] { };
            }
        }

        public Guid[] GetShapesOfType(string prompt, ObjectType filter) {
            ObjRef[] objrefs;
            Result rc = RhinoGet.GetMultipleObjects(prompt, false, filter, out objrefs);
            if (rc == Result.Success) {
                return objrefs.Select(o => o.ObjectId).ToArray();
            } else {
                return new Guid[] { };
            }
        }

        public Guid[] GetPoint(string prompt) => GetShapeOfType(prompt, ObjectType.Point);
        public Guid[] GetPoints(string prompt) => GetShapesOfType(prompt, ObjectType.Point);

        public Guid[] GetCurve(string prompt) => GetShapeOfType(prompt, ObjectType.Curve);
        public Guid[] GetCurves(string prompt) => GetShapesOfType(prompt, ObjectType.Curve);

        public Guid[] GetSurface(string prompt) => GetShapeOfType(prompt, ObjectType.Surface);
        public Guid[] GetSurfaces(string prompt) => GetShapesOfType(prompt, ObjectType.Surface);

        public Guid[] GetSolid(string prompt) => GetShapeOfType(prompt, ObjectType.Surface);
        public Guid[] GetSolids(string prompt) => GetShapesOfType(prompt, ObjectType.Surface);

        public Guid[] GetShape(string prompt) => GetShapeOfType(prompt, ObjectType.AnyObject);
        public Guid[] GetShapes(string prompt) => GetShapesOfType(prompt, ObjectType.AnyObject);

        public Guid[] GetAllShapes() => doc.Objects.GetObjectList(ObjectType.AnyObject).Select(o=>o.Id).ToArray();
        public Guid[] GetAllShapesInLayer(String name) => doc.Objects.FindByLayer(name).Select(o => o.Id).ToArray();

        public bool IsPoint(RhinoObject e) => e.Geometry is Point;
        public bool IsCircle(RhinoObject e) => (e.Geometry as Curve)?.IsCircle() ?? false;
        public bool IsPolyLine(RhinoObject e) => (e.Geometry as Curve)?.IsPolyline() ?? false;
        //public bool IsSpline(RhinoObject e) => e is Polyline3d && (e as Polyline3d).PolyType == Poly3dType.CubicSplinePoly;
        //public bool IsInterpSpline(RhinoObject e) => e is Spline;
        public bool IsClosedPolyLine(RhinoObject e) => ((e.Geometry as Curve)?.IsPolyline() ?? false) && ((e.Geometry as Curve)?.IsClosed ?? false);
        //public bool IsClosedSpline(RhinoObject e) => IsSpline(e) && (e as Polyline3d).Closed;
        //public bool IsInterpClosedSpline(RhinoObject e) => IsInterpSpline(e) && (e as Spline).Closed;
        public bool IsEllipse(RhinoObject e) => (e.Geometry as Curve)?.IsEllipse() ?? false;
        public bool IsArc(RhinoObject e) => (e.Geometry as Curve)?.IsArc() ?? false;
        //public bool IsText(RhinoObject e) => e is DBText;

        public byte ShapeCode(RhinoObject obj) {
            GeometryBase geo = obj.Geometry;
            if (geo is Point) {
                return 1;
            }
            if (geo is Curve) {
                Curve c = geo as Curve;
                if (c.IsCircle()) {
                    return 2;
                } else if (c.IsPolyline()) {
                    return (byte)(4 + (c.IsClosed ? 100 : 0));
                } else if (c.IsEllipse()) {
                    return 8;
                } else if (c.IsArc()) {
                    return 9;
                } else { // Assume is a spline
                    return (byte)(7 + (c.IsClosed ? 100 : 0));
                }
            }
            if (geo is Brep) {
                Brep s = geo as Brep;
                if (s.Faces.Count == 1) {
                    geo = s.Faces[0];
                } else {
                    return 0;
                }
            }
            if (geo is Surface) {
                Surface s = geo as Surface;
                if (s.IsSolid) {
                    return (byte)(
                        s.IsSphere() ? 81 :
                        s.IsCylinder() ? 82 :
                        s.IsCone() ? 83 :
                        s.IsTorus() ? 84 :
                        80);
                } else {
                    return (byte)(s.IsPlanar() ? 41 : 40);
                }
            } else {
                return 0;
            }
        }

        /*
        public Point3d[] BoundingBox(Guid[] ids) {
            if (ids.Length == 0) {
                ids = GetAllShapes();
            }
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                var ext = new Extents3d();
                foreach (var id in ids) {
                    var ent = tr.GetObject(id, OpenMode.ForRead) as Guid;
                    ext.AddExtents(ent.GeometricExtents);
                }
                tr.Commit();
                return new Point3d[] { ext.MinPoint, ext.MaxPoint };
            }
        }
        public void ZoomExtents() {
            dynamic acad = Application.AcadApplication;
            acad.ZoomExtents();
        }
        */
        /*
                public void SetShapeColor(Guid id, byte r, byte g, byte b) {
                    Document doc = Application.DocumentManager.MdiActiveDocument;
                    using (doc.LockDocument())
                    using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                        Guid sh = tr.GetObject(id, OpenMode.ForWrite) as Guid;
                        sh.Color = Color.FromRgb(r, g, b);
                        tr.Commit();
                    }
                }
        */

        public String CreateLayer(String name) {
            int idx = doc.Layers.FindByFullPath(name, true);
            if (idx == -1) { // Not found
                Layer layer = Layer.GetDefaultLayerProperties();
                layer.Name = name;
                return doc.Layers[doc.Layers.Add(layer)].FullPath;
            } else {
                return name;
            }
        }
        public String CurrentLayer() {
            return doc.Layers.CurrentLayer.FullPath;
        }
        public void SetCurrentLayer(String name) {
            int idx = doc.Layers.FindByFullPath(name, true);
            doc.Layers.SetCurrentLayerIndex(idx, true);
        }
/*
        public Guid ShapeLayer(Guid objId) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                Guid sh = tr.GetObject(objId, OpenMode.ForWrite) as Guid;
                tr.Commit();
                return sh.LayerId;
            }
        }
        public void SetShapeLayer(Guid objId, Guid layerId) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                Guid sh = tr.GetObject(objId, OpenMode.ForWrite) as Guid;
                sh.LayerId = layerId;
                tr.Commit();
            }
        }
        public void SetSystemVariableInt(string name, int value) {
            Application.SetSystemVariable(name, value);
        }
        public int Render(int width, int height, string path) {
            Version version = Application.Version;
            string fmt = "._-render {0} _R {1} {2} _yes {3}\n";
            string s = String.Format(fmt,
                (version.Major < 20 ||
                 (version.Major == 20 && version.Minor == 0) ? "P" : "H"),
                width, height, path);
            //Document doc = Application.DocumentManager.MdiActiveDocument;
            //doc.SendStringToExecute(s, false, false, false);
            dynamic doc = Application.DocumentManager.MdiActiveDocument.GetAcadDocument();
            doc.SendCommand(s);
            return 1;
        }
        public int Command(string cmd) {
            dynamic doc = Application.DocumentManager.MdiActiveDocument.GetAcadDocument();
            doc.SendCommand(cmd);
            return 1;
        }
        private const int WM_SETREDRAW = 0x000B;

        public void DisableUpdate() {

            IntPtr handle = Application.MainWindow.Handle;
            NativeMethods.SendMessage(handle, WM_SETREDRAW, IntPtr.Zero, IntPtr.Zero);
            //            LockWindowUpdate(handle);

            //            Message msgSuspendUpdate = Message.Create(handle, WM_SETREDRAW, IntPtr.Zero, IntPtr.Zero);
            //            NativeWindow window = NativeWindow.FromHandle(handle);
            //            Application.MainWindow.UnmanagedWindow.DefWndProc(ref msgSuspendUpdate);
        }

        public void EnableUpdate() {
            IntPtr handle = Application.MainWindow.Handle;
            NativeMethods.SendMessage(handle, WM_SETREDRAW, new IntPtr(1), IntPtr.Zero);
            //            LockWindowUpdate(IntPtr.Zero);

            //            IntPtr handle = Application.MainWindow.Handle;
            //            Message msgResumeUpdate = Message.Create(handle, WM_SETREDRAW, new IntPtr(1), IntPtr.Zero);
            //            NativeWindow window = NativeWindow.FromHandle(handle);
            //            window.DefWndProc(ref msgResumeUpdate);
            Application.UpdateScreen();
        }

        // BIM

        public BIMLevel FindOrCreateLevelAtElevation(double elevation) =>
            BIMLevel.FindOrCreateLevelAtElevation(elevation);
        public BIMLevel UpperLevel(BIMLevel currentLevel, double addedElevation) =>
            BIMLevel.FindOrCreateLevelAtElevation(currentLevel.elevation + addedElevation);
        public double GetLevelElevation(BIMLevel level) => level.elevation;

        public FloorFamily FloorFamilyInstance(double totalThickness, double coatingThickness) =>
            new FloorFamily { totalThickness = totalThickness, coatingThickness = coatingThickness };
*/
        Curve ArcFromPointsAngle(Point3d p0, Point3d p1, double angle) {
            Vector3d v = p1 - p0;
            double d2 = v.X * v.X + v.Y * v.Y;
            double r2 = d2 / (2 * (1 - Math.Cos(angle)));
            double l = Math.Sqrt(r2 - d2 / 4);
            Point3d m = p0 + v * 0.5;
            double phi = Math.Atan2(v.Y, v.X) + Math.PI / 2;
            Point3d center = m + new Vector3d(l * Math.Cos(phi), l * Math.Sin(phi), 0);
            double radius = Math.Sqrt(r2);
            Vector3d v1 = p0 - center;
            double startAngle = Math.Atan2(v1.Y, v1.X);
            return new ArcCurve(new Circle(center, radius), startAngle, angle);
        }
        /*       DBObjectCollection ClosedPathCurveArray(XYZ[] pts, double[] angles) {
                   DBObjectCollection profile = new DBObjectCollection();
                   for (int i = 0; i < pts.Length; i++) {
                       if (angles[i] == 0) {
                           profile.Add(PolyLine(new XYZ[] { pts[i], pts[(i + 1) % pts.Length] }));
                       } else {
                           profile.Add(ArcFromPointsAngle(pts[i], pts[(i + 1) % pts.Length], angles[i]));
                       }
                   }
                   return profile;
               }

               public Guid LightweightPolyLine(Point2d[] pts, double[] angles, double elevation) {
                   Polyline p = new Polyline(pts.Length + 1);
                   p.Elevation = elevation;
                   for (int i = 0; i < pts.Length; i++) {
                       p.AddVertexAt(i, pts[i], Math.Tan(angles[i] / 4.0), 0.0, 0.0);
                   }
                   p.Closed = true;
                   return p;
               }
               public Guid SurfaceLightweightPolyLine(Point2d[] pts, double[] angles, double elevation) =>
                   SurfaceFromCurve(LightweightPolyLine(pts, angles, elevation));

               //Recognizers
               public bool IsSolid3dAndSatisfies(Guid objId, Predicate<Solid3d> p) {
                   Document doc = Application.DocumentManager.MdiActiveDocument;
                   using (doc.LockDocument())
                   using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                       Solid3d sh = tr.GetObject(objId, OpenMode.ForWrite) as Solid3d;
                       bool result = sh != null;
                       result &= p(sh);
                       tr.Commit();
                       return result;
                   }
               }
               //       public bool IsCylinderP(Solid3d solid)
               //       {
               //           Acad3DSolid oSol = (Acad3DSolid)solid.AcadObject;
               //           return oSol.SolidType.equals("Cylinder");
               //       }
               //       public bool IsCylinder(Guid id) => IsSolid3dAndSatisfies(id, IsCylinderP);

               //BIM operations

               public Guid CreatePathFloor(Point2d[] pts, double[] angles, BIMLevel level, FloorFamily family) {
                   double elevation = level.elevation - family.totalThickness + family.coatingThickness;
                   Vector3d dir = new Vector3d(0, 0, family.totalThickness);
                   Document doc = Application.DocumentManager.MdiActiveDocument;
                   using (doc.LockDocument())
                   using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                       using (Solid3d s = new Solid3d()) {
                           s.CreateExtrudedSolid(SurfaceLightweightPolyLine(pts, angles, elevation), dir, new SweepOptions());
                           return addAndCommit(s, doc, tr);
                       }
                   }
               }
               */

        Guid ClosedPathCurveArray(Point3d[] pts, double[] angles) {
            PolyCurve curve = new PolyCurve();
            for (int i = 0; i < pts.Length; i++) {
                if (angles[i] == 0) {
                    Debug.Assert(curve.Append(new PolylineCurve(new Point3d[] { pts[i], pts[(i + 1) % pts.Length] })));
                } else {
                    Debug.Assert(curve.Append(ArcFromPointsAngle(pts[i], pts[(i + 1) % pts.Length], angles[i])));
                }
            }
            return doc.Objects.Add(curve);
        }

        public Brep[] PathWall(RhinoObject obj, double thickness, double height) {
            Curve path = (Curve)obj.Geometry;
            Plane plane = new Plane();
            Debug.Assert(path.FrameAt(path.Domain[0], out plane));
            if (plane.Normal * Plane.WorldXY.Normal <= 1e-16) {
                height = -height;
            }
            Curve cross_section = new PolylineCurve(new Point3d[] {
                plane.PointAt(0,thickness/-2,0),
                plane.PointAt(0,thickness/+2,0),
                plane.PointAt(0,thickness/+2,height),
                plane.PointAt(0,thickness/-2,height),
                plane.PointAt(0,thickness/-2,0) });
            Brep[] breps = Brep.CreateFromSweep(path, cross_section, path.IsClosed, doc.ModelAbsoluteTolerance);
            return (path.IsClosed ? breps : breps.Select(brep => brep.CapPlanarHoles(doc.ModelAbsoluteTolerance)).ToArray());
        }

        // BIM Families
        /*
                public int CreateTableFamily(double length, double width, double height, double top_thickness, double leg_thickness) =>
            TableFamily.FindOrCreate(length, width, height, top_thickness, leg_thickness);

                public TableChairFamily FindOrCreateTableChairFamily(TableFamily tableFamily, ChairFamily chairFamily,
                    int chairsOnTop, int chairsOnBottom, int chairsOnRight, int chairsOnLeft, double spacing) =>
                    TableChairFamily.FindOrCreate(tableFamily, chairFamily, chairsOnTop, chairsOnBottom, chairsOnRight, chairsOnLeft, spacing);
            }
            */
        public Guid CreateFamilyInstance(Point3d c, double angle, int family) {
            Transform xform = Transform.Translation(new Vector3d(c)) * Transform.Rotation(angle, Point3d.Origin);
            return doc.Objects.AddInstanceObject(family, xform);
        }

        public GeometryBase FamilyInstanceGeometry(Point3d c, double angle, int family) {
            Transform xform = Transform.Translation(new Vector3d(c)) * Transform.Rotation(angle, Point3d.Origin);
            return new InstanceReferenceGeometry(doc.InstanceDefinitions[family].Id, xform);
        }

        public GeometryBase[] RowOfInstancesGeometry(Point3d c, double angle, int n, double spacing, int family) =>
            Enumerable.Range(0, n).Select(i => FamilyInstanceGeometry(c + vcyl(spacing * i, angle, 0), angle + Math.PI / 2, family)).ToArray();

        public GeometryBase[] CenteredRowOfInstancesGeometry(Point3d c, double angle, int n, double spacing, int family) =>
            RowOfInstancesGeometry(c + vcyl(-spacing * (n - 1) / 2, angle, 0), angle, n, spacing, family);

        // BIM Table
        public Brep[] BaseRectangularTable(double length, double width, double height, double top_thickness, double leg_thickness) {
            List<Brep> breps = new List<Brep>();
            double dx = length / 2;
            double dy = width / 2;
            double dz = height;
            breps.Add(Brep.CreateFromBox(new BoundingBox(new Point3d(-dx, -dy, dz - top_thickness), new Point3d(+dx, +dy, dz))));
            double leg_x = dx - leg_thickness / 2;
            double leg_y = dy - leg_thickness / 2;
            Point3d[] pts = new Point3d[] {
                        new Point3d(+leg_x, -leg_y, 0),
                        new Point3d(+leg_x, +leg_y, 0),
                        new Point3d(-leg_x, +leg_y, 0),
                        new Point3d(-leg_x, -leg_y, 0)
                    };
            Vector3d vmin = new Vector3d(-leg_thickness / 2, -leg_thickness / 2, 0);
            Vector3d vmax = new Vector3d(+leg_thickness / 2, +leg_thickness / 2, height - top_thickness / 2);
            foreach (Point3d p in pts) {
                breps.Add(Brep.CreateFromBox(new BoundingBox(p + vmin, p + vmax)));
            }
            return breps.ToArray();
        }
        public int CreateRectangularTableFamily(double length, double width, double height, double top_thickness, double leg_thickness) =>
            doc.InstanceDefinitions.Add(doc.InstanceDefinitions.GetUnusedInstanceDefinitionName(), "Khepri Table",
                    Point3d.Origin, BaseRectangularTable(length, width, height, top_thickness, leg_thickness));

        public Guid Table(Point3d c, double angle, int family) => CreateFamilyInstance(c, angle, family);

        // BIM Chair
        public Brep[] BaseChair(double length, double width, double height, double seat_height, double thickness) {
            Brep[] table = BaseRectangularTable(length, width, seat_height, thickness, thickness);
            double vx = length / 2;
            double vy = width / 2;
            double vz = height;
            Brep back = Brep.CreateFromBox(new BoundingBox(
                new Point3d(-vx, -vy, seat_height - thickness / 2),
                new Point3d(-vx + thickness, +vy, height)));
            return table.Concat(new Brep[] { back }).ToArray();
        }
        public int CreateChairFamily(double length, double width, double height, double seat_height, double thickness) =>
            doc.InstanceDefinitions.Add(doc.InstanceDefinitions.GetUnusedInstanceDefinitionName(), "Khepri Chair",
                    Point3d.Origin, BaseChair(length, width, height, seat_height, thickness));

        public Guid Chair(Point3d c, double angle, int family) => CreateFamilyInstance(c, angle, family);

        // BIM Table and chairs
        public GeometryBase[] BaseRectangularTableAndChairs(int tableFamily, int chairFamily, double tableLength, double tableWidth, int chairsOnTop, int chairsOnBottom, int chairsOnRight, int chairsOnLeft, double spacing) {
            List<GeometryBase> blocks = new List<GeometryBase>();
            double dx = tableLength / 2;
            double dy = tableWidth / 2;
            blocks.Add(FamilyInstanceGeometry(Point3d.Origin, 0, tableFamily));
            blocks.AddRange(CenteredRowOfInstancesGeometry(new Point3d(-dx, 0, 0), -Math.PI / 2, chairsOnBottom, spacing, chairFamily));
            blocks.AddRange(CenteredRowOfInstancesGeometry(new Point3d(+dx, 0, 0), +Math.PI / 2, chairsOnTop, spacing, chairFamily));
            blocks.AddRange(CenteredRowOfInstancesGeometry(new Point3d(0, +dy, 0), -Math.PI, chairsOnRight, spacing, chairFamily));
            blocks.AddRange(CenteredRowOfInstancesGeometry(new Point3d(0, -dy, 0), 0, chairsOnLeft, spacing, chairFamily));
            return blocks.ToArray();
        }

        public int CreateRectangularTableAndChairsFamily(int tableFamily, int chairFamily, double tableLength, double tableWidth, int chairsOnTop, int chairsOnBottom, int chairsOnRight, int chairsOnLeft, double spacing) =>
            doc.InstanceDefinitions.Add(doc.InstanceDefinitions.GetUnusedInstanceDefinitionName(), "Khepri Table&Chairs",
                    Point3d.Origin, BaseRectangularTableAndChairs(tableFamily, chairFamily, tableLength, tableWidth,
                        chairsOnTop, chairsOnBottom, chairsOnRight, chairsOnLeft,
                        spacing));

        public Guid TableAndChairs(Point3d c, double angle, int family) => CreateFamilyInstance(c, angle, family);

        /*
        public Brep[] RectangularTableAndChairs(Point3d c, double angle, TableChairFamily f) {
            List<Brep> breps = new List<Brep>();
            double dx = f.tableFamily.length / 2;
            double dy = f.tableFamily.width / 2;
            breps.Add(RectangularTable(c, angle, f.tableFamily));
            breps.AddRange(CenteredRowOfChairs(c + vcyl(dx, angle + Math.PI, 0), angle - Math.PI / 2, f.chairsOnBottom, f.spacing, f.chairFamily));
            breps.AddRange(CenteredRowOfChairs(c + vcyl(dx, angle, 0), angle + Math.PI / 2, f.chairsOnTop, f.spacing, f.chairFamily));
            breps.AddRange(CenteredRowOfChairs(c + vcyl(dy, angle + Math.PI / 2, 0), angle - Math.PI, f.chairsOnRight, f.spacing, f.chairFamily));
            breps.AddRange(CenteredRowOfChairs(c + vcyl(dy, angle - Math.PI / 2, 0), angle, f.chairsOnLeft, f.spacing, f.chairFamily));
            return breps.ToArray();
        }
        */
        Vector3d vcyl(double rho, double phi, double z) => new Vector3d(rho * Math.Cos(phi), rho * Math.Sin(phi), z);


        //public Brep Chair2(Point3d c, double angle, double length, double width, double height, double seat_height, double thickness) {
        //    Brep table = BaseRectangularTable(length, width, seat_height, thickness, thickness);
        //    double vx = length / 2;
        //    double vy = width / 2;
        //    double vz = height;
        //    Brep back = Brep.CreateFromBox(new BoundingBox(
        //        new Point3d(-vx, -vy, seat_height - thickness / 2),
        //        new Point3d(-vx + thickness, +vy, height)));
        //    /*Box(new Point3d((length - thickness) / -2, width / -2, seat_height), thickness, width, height - seat_height);
        //    Brep back = XYCenteredBox(c + vcyl((length - thickness)/2, angle + Math.PI, seat_height),
        //        vcyl(1, angle, 0),
        //        vcyl(1, angle + Math.PI / 2, 0),
        //        thickness,
        //        width,
        //        height - seat_height);
        //    //doc.Objects.AddBrep(table); doc.Objects.AddBrep(back);
        //    // We should expect only one element but Rhino is returning more than one
        //    return Brep.CreateBooleanUnion(new Brep[] { back, table }, doc.ModelAbsoluteTolerance)[0]; */
        //    return RotateAndTranslate(c, angle, Brep.CreateBooleanUnion(new Brep[] { back, table }, doc.ModelAbsoluteTolerance)[0]);
        //}
    }
}

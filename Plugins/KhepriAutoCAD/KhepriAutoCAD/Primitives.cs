using System;
using System.Collections.Generic;
using System.Linq;

//using System.Windows;
using Autodesk.AutoCAD.EditorInput;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Geometry;
//using Autodesk.AutoCAD.Interop.Common;
using DBSurface = Autodesk.AutoCAD.DatabaseServices.Surface;
using DBNurbSurface = Autodesk.AutoCAD.DatabaseServices.NurbSurface;
using AcadException = Autodesk.AutoCAD.Runtime.Exception;
using Autodesk.AutoCAD.Runtime;
using System.Runtime.InteropServices;
using Autodesk.AutoCAD.Colors;
//using XYZ = Autodesk.AutoCAD.Geometry.Point3d;
//using VXYZ = Autodesk.AutoCAD.Geometry.Vector3d;
using KhepriBase;

namespace KhepriAutoCAD {
    public class Frame3d {
        public Point3d origin;
        public Vector3d xaxis;
        public Vector3d yaxis;
        public Vector3d zaxis;

        public Frame3d(Point3d origin, Vector3d xaxis, Vector3d yaxis, Vector3d zaxis) {
            this.origin = origin;
            this.xaxis = xaxis;
            this.yaxis = yaxis;
            this.zaxis = zaxis;
        }

        public Frame3d(Point3d origin, Vector3d xaxis, Vector3d yaxis) :
            this(origin, xaxis, yaxis, xaxis.CrossProduct(yaxis)) { }
    }

    class NativeMethods {
        [DllImport("user32.dll")]
        internal static extern IntPtr SendMessage(IntPtr hWnd, uint wMsg, IntPtr wParam, IntPtr lParam);
    }

    public class Primitives : KhepriBase.Primitives {
        public int DeleteAll() {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (var tr = doc.Database.TransactionManager.StartTransaction()) {
                BlockTable bt = (BlockTable)tr.GetObject(doc.Database.BlockTableId, OpenMode.ForRead);
                BlockTableRecord btr = (BlockTableRecord)tr.GetObject(bt[BlockTableRecord.ModelSpace], OpenMode.ForRead);
                foreach (var entId in btr) {
                    var ent = tr.GetObject(entId, OpenMode.ForRead) as Entity;
                    if (ent != null) {
                        ent.UpgradeOpen();
                        ent.Erase();
                        ent.DowngradeOpen();
                    }
                }
                tr.Commit();
            }
            return 0;
        }

        public void SetView(Point3d position, Point3d target, double lens, bool perspective, string style) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument()) {
                Database db = doc.Database;
                Editor ed = doc.Editor;
                using (Transaction tr = db.TransactionManager.StartTransaction()) {
                    const double DIAG35MM = 42.0;
                    double projectionPlaneDistance = (target - position).Length;
                    double aspectRatio = 1.0;
                    ViewTable viewTable = tr.GetObject(db.ViewTableId, OpenMode.ForWrite) as ViewTable;
                    ViewportTable vpTbl = tr.GetObject(db.ViewportTableId, OpenMode.ForRead) as ViewportTable;
                    ViewportTableRecord viewportTableRec = tr.GetObject(vpTbl["*Active"], OpenMode.ForRead) as ViewportTableRecord;
                    DBDictionary styleDict = tr.GetObject(db.VisualStyleDictionaryId, OpenMode.ForRead) as DBDictionary;
                    aspectRatio = (viewportTableRec.Width / viewportTableRec.Height);
                    double fieldHeight =
                            (projectionPlaneDistance * DIAG35MM) /
                            (lens * Math.Sqrt(1.0 + aspectRatio * aspectRatio));
                    double fieldWidth = aspectRatio * fieldHeight;
                    using (ViewTableRecord vtr = new ViewTableRecord()) {
                        vtr.BackClipEnabled = false;
                        vtr.BackClipDistance = 0.0;
                        vtr.CenterPoint = Point2d.Origin;
                        vtr.FrontClipAtEye = false;
                        vtr.FrontClipEnabled = false;
                        vtr.FrontClipDistance = projectionPlaneDistance;
                        vtr.LensLength = lens;
                        vtr.PerspectiveEnabled = perspective;
                        vtr.VisualStyleId = styleDict.GetAt(style);
                        vtr.Target = target;
                        vtr.ViewTwist = 0.0;
                        vtr.ViewDirection = position - target;
                        vtr.Width = fieldWidth;
                        vtr.Height = fieldHeight;
                        ed.SetCurrentView(vtr);
                        ed.Regen();
                    }
                    tr.Commit();
                }
            }
        }

        public void View(Point3d position, Point3d target, double lens) => SetView(position, target, lens, true, "Conceptual");
        public void ViewTop() => SetView(new Point3d(0.0, 0.0, 1.0), Point3d.Origin, 50.0, false, "2dWireframe");
        public Point3d ViewCamera() {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument()) {
                ViewTableRecord view = doc.Editor.GetCurrentView();
                return view.Target + view.ViewDirection;
            }
        }
        public Point3d ViewTarget() {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument()) {
                return doc.Editor.GetCurrentView().Target;
            }
        }
        public double ViewLens() {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument()) {
                return doc.Editor.GetCurrentView().LensLength;
            }
        }

        public void ForEachEntity(Database db, Action<Entity> f) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (var tr = db.TransactionManager.StartTransaction()) {
                var bt = (BlockTable)tr.GetObject(db.BlockTableId, OpenMode.ForRead);
                foreach (ObjectId btrId in bt) {
                    var btr = (BlockTableRecord)tr.GetObject(btrId, OpenMode.ForRead);
                    foreach (ObjectId entId in btr) {
                        var ent = tr.GetObject(entId, OpenMode.ForRead) as Entity;
                        if (ent != null) {
                            f(ent);
                        }
                    }
                }
                tr.Commit();
            }
        }
        static ObjectId Add(Entity e, Document doc, Transaction tr) {
            BlockTable bt = (BlockTable)tr.GetObject(doc.Database.BlockTableId, OpenMode.ForRead);
            BlockTableRecord btr = (BlockTableRecord)tr.GetObject(bt[BlockTableRecord.ModelSpace], OpenMode.ForWrite);
            ObjectId id = btr.AppendEntity(e);
            tr.AddNewlyCreatedDBObject(e, true);
            return id;
        }
        static ObjectId AddAndCommit(Entity e, Document doc, Transaction tr) {
            ObjectId id = Add(e, doc, tr);
            tr.Commit();
            return id;
        }
        static ObjectId AddAndDeleteAndCommit(Entity e, Entity del, Document doc, Transaction tr) {
            ObjectId id = Add(e, doc, tr);
            del.Erase();
            tr.Commit();
            return id;
        }
        static T SingletonElement<T>(T[] elements) {
            if (elements.Length == 1) {
                return elements[0];
            } else {
                throw new AcadException(ErrorStatus.InvalidInput, "Generated zero or more than one element");
            }
        }
        static DBObject SingletonElement(DBObjectCollection elements) {
            if (elements.Count == 1) {
                foreach (DBObject obj in elements) {
                    return obj;
                }
                return null;
            } else {
                throw new AcadException(ErrorStatus.InvalidInput, "Generated zero or more than one element");
            }
        }

        public byte Sync() => 1;
        public byte Disconnect() => 2;
        public void Delete(ObjectId id) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                Entity ent = tr.GetObject(id, OpenMode.ForWrite) as Entity;
                ent.Erase();
                tr.Commit();
            }
        }
        public void DeleteMany(ObjectId[] ids) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                foreach (var id in ids) {
                    Entity ent = tr.GetObject(id, OpenMode.ForWrite) as Entity;
                    ent.Erase();
                }
                tr.Commit();
            }
        }
        public ObjectId Copy(ObjectId id) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                Entity obj = tr.GetObject(id, OpenMode.ForWrite) as Entity;
                return AddAndCommit(obj.Clone() as Entity, doc, tr);
            }
        }

        public Entity Point(Point3d p) => new DBPoint(p);
        public Point3d PointPosition(Entity ent) => ((DBPoint)ent).Position;
        public Entity PolyLine(Point3d[] pts) => new Polyline3d(Poly3dType.SimplePoly, new Point3dCollection(pts), false);
        public Point3d[] LineVertices(ObjectId id) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartOpenCloseTransaction()) {
                Entity ent = tr.GetObject(id, OpenMode.ForRead) as Entity;
                List<Point3d> verts = new List<Point3d>();
                switch (ent.ObjectId.ObjectClass.Name) {
                    case "AcDbLine":
                        Line l = ent as Line;
                        verts.Add(l.StartPoint);
                        verts.Add(l.EndPoint);
                        break;
                    case "AcDbPolyline":
                        Polyline pl = ent as Polyline;
                        int pln = pl.NumberOfVertices;
                        for (int i = 0; i < pln; i++) {
                            verts.Add(pl.GetPoint3dAt(i));
                        }
                        break;
                    case "AcDb2dPolyline":
                        Polyline2d pl2d = ent as Polyline2d;
                        Matrix3d mWPlane = Matrix3d.WorldToPlane(pl2d.Normal);
                        foreach (ObjectId vId in pl2d) {
                            Vertex2d v2d = (Vertex2d)tr.GetObject(vId, OpenMode.ForRead);
                            Point3d p = (new Point3d(v2d.Position.X, v2d.Position.Y, pl2d.Elevation)).TransformBy(mWPlane);
                            verts.Add(p);
                        }
                        break;
                    case "AcDb3dPolyline":
                        Polyline3d pl3d = ent as Polyline3d;
                        foreach (ObjectId vId in pl3d) {
                            PolylineVertex3d plv3d = tr.GetObject(vId, OpenMode.ForRead) as PolylineVertex3d;
                            verts.Add(plv3d.Position);
                        }
                        break;
                }
                tr.Commit();
                return verts.ToArray();
            }
        }

        public Entity Spline(Point3d[] pts) => new Polyline3d(Poly3dType.CubicSplinePoly, new Point3dCollection(pts), false);
        public Entity InterpSpline(Point3d[] pts, Vector3d tan0, Vector3d tan1) =>
            new Spline(new Point3dCollection(pts), tan0, tan1, 3, 0.0);
        public Entity ClosedPolyLine(Point3d[] pts) => new Polyline3d(Poly3dType.SimplePoly, new Point3dCollection(pts), true);
        public Entity ClosedSpline(Point3d[] pts) => new Polyline3d(Poly3dType.CubicSplinePoly, new Point3dCollection(pts), true);
        public Entity InterpClosedSpline(Point3d[] pts) =>
            new Spline(new Point3dCollection(pts), true, KnotParameterizationEnum.Chord, 3, 0.0);

        public Entity Circle(Point3d c, Vector3d n, double r) => new Circle(c, n, r);
        public Point3d CircleCenter(Entity ent) => ((Circle)ent).Center;
        public Vector3d CircleNormal(Entity ent) => ((Circle)ent).Normal;
        public double CircleRadius(Entity ent) => ((Circle)ent).Radius;

        public Entity Ellipse(Point3d c, Vector3d n, Vector3d majorAxis, double radiusRatio) =>
            new Ellipse(c, n, majorAxis, radiusRatio, 0, 2 * Math.PI);

        public Entity Arc(Point3d c, Vector3d n, double radius, double startAngle, double endAngle) =>
            new Arc(c, n, radius, startAngle, endAngle);
        public Point3d ArcCenter(Entity ent) => ((Arc)ent).Center;
        public Vector3d ArcNormal(Entity ent) => ((Arc)ent).Normal;
        public double ArcRadius(Entity ent) => ((Arc)ent).Radius;
        public double ArcStartAngle(Entity ent) => ((Arc)ent).StartAngle;
        public double ArcEndAngle(Entity ent) => ((Arc)ent).EndAngle;


        public Entity Text(string str, Point3d corner, Vector3d vx, Vector3d vy, double height) {
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
        public String TextString(Entity ent) => ((DBText)ent).TextString;
        public Point3d TextPosition(Entity ent) => ((DBText)ent).Position;
        public double TextHeight(Entity ent) => ((DBText)ent).Height;
        public String MTextString(Entity ent) => ((MText)ent).Text;
        public Point3d MTextPosition(Entity ent) => ((MText)ent).Location;
        public double MTextHeight(Entity ent) => ((MText)ent).Height;

        public Entity SurfaceFromCurve(Entity curve) {
            using (curve)
            using (DBObjectCollection coll = new DBObjectCollection()) {
                coll.Add(curve);
                DBObjectCollection curves = Region.CreateFromCurves(coll);
                return (Entity)curves[0];
            }
        }
        public Entity SurfaceCircle(Point3d c, Vector3d n, double r) =>
            SurfaceFromCurve(new Circle(c, n, r));
        public Entity SurfaceEllipse(Point3d c, Vector3d n, Vector3d majorAxis, double radiusRatio) =>
            SurfaceFromCurve(new Ellipse(c, n, majorAxis, radiusRatio, 0, 2 * Math.PI));
        public Entity SurfaceArc(Point3d c, Vector3d n, double radius, double startAngle, double endAngle) =>
            SurfaceFromCurve(new Arc(c, n, radius, startAngle, endAngle));
        public Entity SurfaceClosedPolyLine(Point3d[] pts) =>
            SurfaceFromCurve(new Polyline3d(Poly3dType.SimplePoly, new Point3dCollection(pts), true));

        public ObjectId[] SurfaceFromCurves(ObjectId[] ids) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction())
            using (DBObjectCollection coll = new DBObjectCollection()) {
                foreach (var id in ids) {
                    coll.Add(tr.GetObject(id, OpenMode.ForWrite));
                }
                using (DBObjectCollection regions = Region.CreateFromCurves(coll)) {
                    BlockTable bt = (BlockTable)tr.GetObject(doc.Database.BlockTableId, OpenMode.ForRead);
                    BlockTableRecord btr = (BlockTableRecord)tr.GetObject(bt[BlockTableRecord.ModelSpace], OpenMode.ForWrite);
                    var regionsIds = new List<ObjectId>();
                    foreach (var region in regions) {
                        var obj = region as Entity;
                        regionsIds.Add(btr.AppendEntity(obj));
                        tr.AddNewlyCreatedDBObject(obj, true);
                    }
                    foreach (DBObject obj in coll) {
                        obj.Erase();
                    }
                    tr.Commit();
                    return regionsIds.ToArray();
                }
            }
        }

        public ObjectId[] CurvesFromSurface(ObjectId id) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                Entity e = tr.GetObject(id, OpenMode.ForWrite) as Entity;
                DBObjectCollection objs = new DBObjectCollection();
                e.Explode(objs);
                BlockTable bt = (BlockTable)tr.GetObject(doc.Database.BlockTableId, OpenMode.ForRead);
                BlockTableRecord btr = (BlockTableRecord)tr.GetObject(bt[BlockTableRecord.ModelSpace], OpenMode.ForWrite);
                var curveIds = new List<ObjectId>();
                foreach (DBObject obj in objs) {
                    Entity ent = (Entity)obj;
                    curveIds.Add(btr.AppendEntity(ent));
                    tr.AddNewlyCreatedDBObject(ent, true);
                }
                tr.Commit();
                return curveIds.ToArray();
            }
        }

        public Entity Sphere(Point3d c, double r) {
            Solid3d shape = new Solid3d();
            shape.CreateSphere(r);
            shape.TransformBy(Matrix3d.Displacement(c - Point3d.Origin));
            return shape;
        }
        public Entity Torus(Point3d c, Vector3d vz, double majorRadius, double minorRadius) {
            Solid3d shape = new Solid3d();
            shape.CreateTorus(majorRadius, minorRadius);
            double phi = Math.Atan2(vz.Y, vz.X) + Math.PI / 2;
            Vector3d vx = new Vector3d(Math.Cos(phi), Math.Sin(phi), 0);
            Vector3d vy = vz.CrossProduct(vx);
            shape.TransformBy(Matrix3d.AlignCoordinateSystem(
                Point3d.Origin, Vector3d.XAxis, Vector3d.YAxis, Vector3d.ZAxis,
                c, vx, vy, vz));
            return shape;
        }
        public Entity ConeFrustum(Point3d bottom, double base_radius, Point3d top, double top_radius) {
            Solid3d shape = new Solid3d();
            shape.RecordHistory = true;
            Vector3d vec = top - bottom;
            double height = vec.Length;
            Vector3d vz = vec.GetNormal();
            double phi = Math.Atan2(vz.Y, vz.X) + Math.PI / 2;
            Vector3d vx = new Vector3d(Math.Cos(phi), Math.Sin(phi), 0);
            Vector3d vy = vz.CrossProduct(vx);
            shape.CreateFrustum(height, base_radius, base_radius, top_radius);
            shape.TransformBy(Matrix3d.Displacement(Vector3d.ZAxis * height / 2));
            shape.TransformBy(Matrix3d.AlignCoordinateSystem(
                Point3d.Origin, Vector3d.XAxis, Vector3d.YAxis, Vector3d.ZAxis,
                bottom, vx, vy, vz));
            return shape;
        }

        public Entity Cylinder(Point3d bottom, double radius, Point3d top) {
            //Trocar para Cylinder?
            return ConeFrustum(bottom, radius, top, radius);
        }

        public Entity Cone(Point3d bottom, double radius, Point3d top) {
            return ConeFrustum(top, radius, bottom, 0.0); //Is this OK?
        }
        Entity Transform(Entity shape, Frame3d frame) {
            shape.TransformBy(Matrix3d.AlignCoordinateSystem(
                Point3d.Origin, Vector3d.XAxis, Vector3d.YAxis, Vector3d.ZAxis,
                frame.origin, frame.xaxis, frame.yaxis, frame.zaxis));
            return shape;
        }
        Entity Transform(Entity shape, Vector3d displacement, Frame3d frame) {
            shape.TransformBy(Matrix3d.Displacement(displacement));
            return Transform(shape, frame);
        }
        public Entity Box(Frame3d frame, double dx, double dy, double dz) {
            Solid3d shape = new Solid3d();
            shape.CreateBox(Math.Abs(dx), Math.Abs(dy), Math.Abs(dz));
            return Transform(shape, new Vector3d(dx / 2, dy / 2, dz / 2), frame);
        }
        //Solid3d shape = new Solid3d();
        //Vector3d vz = vx.CrossProduct(vy);
        //shape.CreateBox(Math.Abs(dx), Math.Abs(dy), Math.Abs(dz));
        //shape.TransformBy(Matrix3d.Displacement(new Vector3d(dx / 2, dy / 2, dz / 2)));
        //shape.TransformBy(Matrix3d.AlignCoordinateSystem(
        //    Point3d.Origin, Vector3d.XAxis, Vector3d.YAxis, Vector3d.ZAxis,
        //    corner, vx, vy, vz));
        //return shape;

        public Entity CenteredBox(Frame3d frame, double dx, double dy, double dz) {
            Solid3d shape = new Solid3d();
            shape.CreateBox(Math.Abs(dx), Math.Abs(dy), Math.Abs(dz));
            return Transform(shape, new Vector3d(0, 0, dz / 2), frame);
            //Vector3d vz = vx.CrossProduct(vy);
            //shape.TransformBy(Matrix3d.Displacement(new Vector3d(0, 0, dz / 2)));
            //shape.TransformBy(Matrix3d.AlignCoordinateSystem(
            //    Point3d.Origin, Vector3d.XAxis, Vector3d.YAxis, Vector3d.ZAxis,
            //    corner, vx, vy, vz));
            //return shape;
        }
        public ObjectId IrregularPyramidMesh(Point3d[] pts, Point3d apex) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                BlockTable bt = (BlockTable)tr.GetObject(doc.Database.BlockTableId, OpenMode.ForRead);
                BlockTableRecord btr = (BlockTableRecord)tr.GetObject(bt[BlockTableRecord.ModelSpace], OpenMode.ForWrite);
                PolyFaceMesh pfm = new PolyFaceMesh();
                ObjectId id = btr.AppendEntity(pfm);
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
        public ObjectId IrregularPyramid(Point3d[] pts, Point3d apex) {
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
                btr.AppendEntity(sdm);
                tr.AddNewlyCreatedDBObject(sdm, true);
                Solid3d sol = sdm.ConvertToSolid(false, false);
                ObjectId id = btr.AppendEntity(sol);
                tr.AddNewlyCreatedDBObject(sol, true);
                sdm.Erase();
                tr.Commit();
                return id;
            }
        }
        public ObjectId IrregularPyramidFrustum(Point3d[] bpts, Point3d[] tpts) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                BlockTable bt = (BlockTable)tr.GetObject(doc.Database.BlockTableId, OpenMode.ForRead);
                BlockTableRecord btr = (BlockTableRecord)tr.GetObject(bt[BlockTableRecord.ModelSpace], OpenMode.ForWrite);
                Point3dCollection vertarray = new Point3dCollection(bpts);
                foreach (var p in tpts) vertarray.Add(p);
                Int32Collection facearray = new Int32Collection();
                int n = bpts.Length;
                for (int i = 0; i < n; i++) {
                    facearray.Add(4);
                    facearray.Add(i);
                    facearray.Add((i + 1) % n);
                    facearray.Add((i + 1) % n + n);
                    facearray.Add(i + n);
                }
                facearray.Add(n);
                for (int i = n - 1; i >= 0; i--) facearray.Add(i);
                facearray.Add(n);
                for (int i = n; i < 2 * n; i++) facearray.Add(i);
                SubDMesh sdm = new SubDMesh();
                sdm.SetDatabaseDefaults();
                sdm.SetSubDMesh(vertarray, facearray, 0);
                btr.AppendEntity(sdm);
                tr.AddNewlyCreatedDBObject(sdm, true);
                Solid3d sol = sdm.ConvertToSolid(false, false);
                ObjectId id = btr.AppendEntity(sol);
                tr.AddNewlyCreatedDBObject(sol, true);
                sdm.Erase();
                tr.Commit();
                return id;
            }
        }
        public Entity MeshFromGrid(int m, int n, Point3d[] pts, bool closedM, bool closedN) =>
            new PolygonMesh(PolyMeshType.SimpleMesh, m, n, new Point3dCollection(pts), closedM, closedN);
        public Entity SurfaceFromGrid(int m, int n, Point3d[] pts, bool closedM, bool closedN, int level) {
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
        public Entity SolidFromGrid(int m, int n, Point3d[] pts, bool closedM, bool closedN, int level, double thickness) {
            using (SubDMesh sdm = SurfaceFromGrid(m, n, pts, closedM, closedN, level) as SubDMesh) {
                DBSurface s = sdm.ConvertToSurface(true, true);
                return s.Thicken(thickness, true);
            }
        }
        public DBSurface AsSurface(Entity obj) =>
            (obj as DBSurface) ?? (obj as SubDMesh)?.ConvertToSurface(true, true) ?? DBSurface.CreateFrom(obj);

        public Region SurfaceAsRegion(DBSurface obj) =>
            SingletonElement(obj.ConvertToRegion()) as Region;

        public ObjectId Thicken(ObjectId obj, double thickness) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                Entity e = tr.GetObject(obj, OpenMode.ForWrite) as Entity;
                return AddAndDeleteAndCommit(AsSurface(e).Thicken(thickness, true), e, doc, tr);
            }
        }

        static double sphPhi(Vector3d v) => (v.X == 0.0 && v.Y == 0.0) ? 0.0 : Math.Atan2(v.Y, v.X);
        static Vector3d vpol(double rho, double phi) => new Vector3d(rho * Math.Cos(phi), rho * Math.Sin(phi), 0);

        public double[] CurveDomain(Entity ent) {
            Curve c = ent as Curve;
            return new double[] { c.StartParam, c.EndParam };
        }

        public double CurveLength(Entity ent) {
            Curve c = ent as Curve;
            return c.GetDistanceAtParameter(c.EndParam);
        }
        public Frame3d CurveFrameAt(Entity ent, double t) {
            Curve c = ent as Curve;
            Point3d origin = c.GetPointAtParameter(t);
            Vector3d vt = c.GetFirstDerivative(t);
            Vector3d vn = c.GetSecondDerivative(t);
            Vector3d vx = (vn.Length < 1e-14) ? vpol(1, sphPhi(vt) + Math.PI / 2) : vn;
            Vector3d vy = vt.CrossProduct(vx);
            return new Frame3d(origin, vx / vx.Length, vy / vy.Length);
        }
        public Frame3d CurveFrameAtLength(Entity ent, double l) {
            Curve c = ent as Curve;
            double t = c.GetParameterAtDistance(l);
            Point3d origin = c.GetPointAtParameter(t);
            Vector3d vt = c.GetFirstDerivative(t);
            Vector3d vn = c.GetSecondDerivative(t);
            Vector3d vx = (vn.Length < 1e-14) ? vpol(1, sphPhi(vt) + Math.PI / 2) : vn;
            Vector3d vy = vt.CrossProduct(vx);
            return new Frame3d(origin, vx / vx.Length, vy / vy.Length);
        }
        public Frame3d CurveClosestFrameTo(Entity ent, Point3d p) {
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
            Point3dCollection pts = CurveLocations(arc, 32);
            arc.Erase();
            Curve c = new Polyline3d(Poly3dType.SimplePoly, pts, false);
            btr.AppendEntity(c);
            tr.AddNewlyCreatedDBObject(c, true);
            return c;
        }
        public ObjectId JoinCurves(ObjectId[] ids) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                Curve c0 = tr.GetObject(ids[0], OpenMode.ForWrite) as Curve;
                //AutoCAD does not like to join starting from an Arc
                if (c0 is Arc) { c0 = PolyFrom(c0 as Arc, doc, tr); }
                for (int i = 1; i < ids.Length; i++) {
                    Curve c1 = tr.GetObject(ids[i], OpenMode.ForWrite) as Curve;
                    if (c1 is Arc) { c1 = PolyFrom(c1 as Arc, doc, tr); }
                    c0.JoinEntity(c1);
                    c1.Erase();
                }
                tr.Commit();
                return c0.Id;
            }
        }

        public DBNurbSurface AsNurbSurface(Entity ent) =>
            SingletonElement(DBSurface.CreateFrom(ent).ConvertToNurbSurface());
        public ObjectId NurbSurfaceFrom(ObjectId id) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                return AddAndCommit(AsNurbSurface(tr.GetObject(id, OpenMode.ForRead) as Entity), doc, tr);
            }
        }
        public double[] SurfaceDomain(Entity ent) {
            DBNurbSurface s = ent as DBNurbSurface;
            return new double[] {
                s.UKnots.StartParameter, s.UKnots.EndParameter,
                s.VKnots.StartParameter, s.VKnots.EndParameter };
        }
        public Frame3d SurfaceFrameAt(Entity ent, double u, double v) {
            var s = ent as DBNurbSurface;
            Point3d p = new Point3d();
            Vector3d du = new Vector3d();
            Vector3d dv = new Vector3d();
            s.Evaluate(u, v, ref p, ref du, ref dv);
            //Vector3d n = du.CrossProduct(dv);
            return new Frame3d(p, du / du.Length, dv / dv.Length);
        }
        public ObjectId Extrude(ObjectId profileId, Vector3d dir) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                Entity profile = tr.GetObject(profileId, OpenMode.ForWrite) as Entity;
                if (profile is Region) {
                    using (Solid3d s = new Solid3d()) {
                        s.CreateExtrudedSolid(profile, dir, new SweepOptions());
                        return AddAndDeleteAndCommit(s, profile, doc, tr);
                    }
                } else {
                    using (ExtrudedSurface s = new ExtrudedSurface()) {
                        s.CreateExtrudedSurface(profile, dir, new SweepOptions());
                        return AddAndDeleteAndCommit(s, profile, doc, tr);
                    }
                }
            }
        }
        public ObjectId Sweep(ObjectId pathId, ObjectId profileId, double rotation, double scale) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                Curve path = tr.GetObject(pathId, OpenMode.ForWrite) as Curve;
                Frame3d frame = CurveFrameAt(path, CurveDomain(path)[0]);
                Entity profile = Transform(tr.GetObject(profileId, OpenMode.ForWrite) as Entity, frame);
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
                        return AddAndCommit(s, doc, tr);
                    }
                } else {
                    using (SweptSurface s = new SweptSurface()) {
                        s.CreateSweptSurface(profile, path, sob.ToSweepOptions());
                        profile.Erase();
                        path.Erase();
                        return AddAndCommit(s, doc, tr);
                    }
                }
            }
        }
        public ObjectId Loft(ObjectId[] profilesIds, ObjectId[] guidesIds, bool ruled, bool closed) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                Entity[] profiles = profilesIds.Select(i => tr.GetObject(i, OpenMode.ForRead) as Entity).ToArray();
                Entity[] guides = guidesIds.Select(i => tr.GetObject(i, OpenMode.ForRead) as Entity).ToArray();
                LoftOptionsBuilder lob = new LoftOptionsBuilder();
                lob.NormalOption = LoftOptionsNormalOption.NoNormal;
                lob.Ruled = ruled;
                lob.Closed = closed;
                if (profiles[0] is Region) {
                    using (Solid3d s = new Solid3d()) {
                        s.CreateLoftedSolid(profiles, guides, null, lob.ToLoftOptions());
                        return AddAndCommit(s, doc, tr);
                    }
                } else {
                    using (LoftedSurface s = new LoftedSurface()) {
                        s.CreateLoftedSurface(profiles, guides, null, lob.ToLoftOptions());
                        return AddAndCommit(s, doc, tr);
                    }
                }
            }
        }
        ObjectId BooleanOperation(ObjectId objId0, ObjectId objId1, BooleanOperationType op) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                Entity ent0 = tr.GetObject(objId0, OpenMode.ForWrite) as Entity;
                Entity ent1 = tr.GetObject(objId1, OpenMode.ForWrite) as Entity;
                if (ent0 is DBSurface) {
                    Region r0 = SurfaceAsRegion(ent0 as DBSurface);
                    Add(r0, doc, tr);
                    ent0.Erase();
                    ent0 = r0;
                }
                if (ent1 is DBSurface) {
                    Region r1 = SurfaceAsRegion(ent1 as DBSurface);
                    Add(r1, doc, tr);
                    ent1.Erase();
                    ent1 = r1;
                }
                if (ent0 is Region) {
                    ((Region)ent0).BooleanOperation(op, (Region)ent1);
                } else {
                    ((Solid3d)ent0).BooleanOperation(op, (Solid3d)ent1);
                }
                tr.Commit();
                return ent0.Id;
            }
        }
        public ObjectId Unite(ObjectId objId0, ObjectId objId1) =>
            BooleanOperation(objId0, objId1, BooleanOperationType.BoolUnite);
        public ObjectId Intersect(ObjectId objId0, ObjectId objId1) =>
            BooleanOperation(objId0, objId1, BooleanOperationType.BoolIntersect);
        public ObjectId Subtract(ObjectId objId0, ObjectId objId1) =>
            BooleanOperation(objId0, objId1, BooleanOperationType.BoolSubtract);
        public void Slice(ObjectId id, Point3d p, Vector3d n) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                Solid3d obj = tr.GetObject(id, OpenMode.ForWrite) as Solid3d;
                obj.Slice(new Plane(p, n.Negate()));
                tr.Commit();
            }
        }
        public ObjectId Revolve(ObjectId profileId, Point3d p, Vector3d n, double startAngle, double amplitude) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                Entity profile = tr.GetObject(profileId, OpenMode.ForWrite) as Entity;
                RevolveOptionsBuilder rob = new RevolveOptionsBuilder();
                rob.CloseToAxis = false;
                rob.DraftAngle = 0;
                rob.TwistAngle = 0;
                if (profile is Region) {
                    using (Solid3d sol = new Solid3d()) {
                        sol.CreateRevolvedSolid(profile, p, n, amplitude, startAngle, rob.ToRevolveOptions());
                        return AddAndCommit(sol, doc, tr);
                    }
                } else {
                    using (RevolvedSurface ss = new RevolvedSurface()) {
                        ss.CreateRevolvedSurface(profile, p, n, amplitude, startAngle, rob.ToRevolveOptions());
                        return AddAndCommit(ss, doc, tr);
                    }
                }
            }
        }

        public void Transform(ObjectId id, Frame3d frame) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                Entity sh = tr.GetObject(id, OpenMode.ForWrite) as Entity;
                Transform(sh, frame);
                tr.Commit();
            }
        }
        public void Move(ObjectId id, Vector3d v) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                Entity sh = tr.GetObject(id, OpenMode.ForWrite) as Entity;
                sh.TransformBy(Matrix3d.Displacement(v));
                tr.Commit();
            }
        }
        public void Scale(ObjectId id, Point3d p, double s) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                Entity sh = tr.GetObject(id, OpenMode.ForWrite) as Entity;
                sh.TransformBy(Matrix3d.Scaling(s, p));
                tr.Commit();
            }
        }
        public void Rotate(ObjectId id, Point3d p, Vector3d n, double a) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                Entity sh = tr.GetObject(id, OpenMode.ForWrite) as Entity;
                sh.TransformBy(Matrix3d.Rotation(a, n, p));
                tr.Commit();
            }
        }
        public ObjectId Mirror(ObjectId id, Point3d p, Vector3d n, bool copy) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                Entity sh = tr.GetObject(id, OpenMode.ForWrite) as Entity;
                if (copy) {
                    sh = sh.Clone() as Entity;
                    BlockTable bt = (BlockTable)tr.GetObject(doc.Database.BlockTableId, OpenMode.ForRead);
                    BlockTableRecord btr = (BlockTableRecord)tr.GetObject(bt[BlockTableRecord.ModelSpace], OpenMode.ForWrite);
                    id = btr.AppendEntity(sh);
                    tr.AddNewlyCreatedDBObject(sh, true);
                }
                sh.TransformBy(Matrix3d.Mirroring(new Plane(p, n)));
                tr.Commit();
                return id;
            }
        }
        public Point3d[] GetPoint(string prompt) {
            Document acDoc = Application.DocumentManager.MdiActiveDocument;
            PromptPointResult pPtRes;
            PromptPointOptions pPtOpts = new PromptPointOptions(prompt);
            pPtOpts.AllowArbitraryInput = true;
            pPtRes = acDoc.Editor.GetPoint(pPtOpts);
            return pPtRes.Status == PromptStatus.Cancel ? new Point3d[] { } : new Point3d[] { pPtRes.Value };
        }
        public ObjectId[] GetAllShapes() {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                Database database = HostApplicationServices.WorkingDatabase;
                BlockTableRecord btRecord = (BlockTableRecord)tr.GetObject(SymbolUtilityServices.GetBlockModelSpaceId(database), OpenMode.ForRead);
                var res = (from ObjectId id in btRecord select id).ToArray();
                tr.Commit();
                return res;
            }
        }
        public ObjectId[] GetAllShapesInLayer(ObjectId layerId) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartOpenCloseTransaction()) {
                Database database = HostApplicationServices.WorkingDatabase;
                BlockTableRecord btRecord = (BlockTableRecord)tr.GetObject(SymbolUtilityServices.GetBlockModelSpaceId(database), OpenMode.ForRead);
                var res = new List<ObjectId>();
                foreach (var id in btRecord) {
                    Entity ent = tr.GetObject(id, OpenMode.ForRead) as Entity;
                    if (ent.LayerId == layerId) {
                        res.Add(id);
                    }
                }
                return res.ToArray();
            }
        }
        public bool IsPoint(Entity e) => e is DBPoint;
        public bool IsCircle(Entity e) => e is Circle;
        public bool IsPolyLine(Entity e) => e is Polyline3d && (e as Polyline3d).PolyType == Poly3dType.SimplePoly;
        public bool IsSpline(Entity e) => e is Polyline3d && (e as Polyline3d).PolyType == Poly3dType.CubicSplinePoly;
        public bool IsInterpSpline(Entity e) => e is Spline;
        public bool IsClosedPolyLine(Entity e) => IsPolyLine(e) && (e as Polyline3d).Closed;
        public bool IsClosedSpline(Entity e) => IsSpline(e) && (e as Polyline3d).Closed;
        public bool IsInterpClosedSpline(Entity e) => IsInterpSpline(e) && (e as Spline).Closed;
        public bool IsEllipse(Entity e) => e is Ellipse;
        public bool IsArc(Entity e) => e is Arc;
        public bool IsText(Entity e) => e is DBText;

        public bool IsClosed(Entity e) =>
            (e is Line && (e as Line).Closed) ||
            (e is Polyline && (e as Polyline).Closed) ||
            (e is Polyline2d && (e as Polyline2d).Closed) ||
            (e is Polyline3d && (e as Polyline3d).Closed);
        public bool IsClosed(ObjectId id) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartOpenCloseTransaction()) {
                //This doesn't seem very safe, but it is working
                return IsClosed(tr.GetObject(id, OpenMode.ForRead) as Entity);
            }
        }

        //To speedup type identification, we will use an old approach
        IDictionary<RXClass, byte> shapeCode = 
            new Dictionary<RXClass, byte>() {
                { RXClass.GetClass(typeof(DBPoint)), 1},
                { RXClass.GetClass(typeof(Circle)), 2},
                { RXClass.GetClass(typeof(Line)), 3},
                { RXClass.GetClass(typeof(Polyline)), 4},
                { RXClass.GetClass(typeof(Polyline2d)), 5},
                { RXClass.GetClass(typeof(Polyline3d)), 6},
                { RXClass.GetClass(typeof(Spline)), 7},
                { RXClass.GetClass(typeof(Ellipse)), 8},
                { RXClass.GetClass(typeof(Arc)), 9},
                { RXClass.GetClass(typeof(DBText)), 10},
                { RXClass.GetClass(typeof(MText)), 11},
                { RXClass.GetClass(typeof(BlockReference)), 50 },
                { RXClass.GetClass(typeof(Viewport)), 70 },
        };
        public byte ShapeCode(ObjectId id) {
            byte code;
            if (shapeCode.TryGetValue(id.ObjectClass, out code)) {
                if (code >= 3 && code <= 7 && IsClosed(id)) {
                    code += 100;
                }
                return code;
            } else {
                return 0;
            }
        }

        public Point3d[] BoundingBox(ObjectId[] ids) {
            if (ids.Length == 0) {
                ids = GetAllShapes();
            }
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                var ext = new Extents3d();
                foreach (var id in ids) {
                    var ent = tr.GetObject(id, OpenMode.ForRead) as Entity;
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

        public ObjectId CreateLayer(string name) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                LayerTable lt = (LayerTable)tr.GetObject(doc.Database.LayerTableId, OpenMode.ForRead);
                ObjectId id;
                if (lt.Has(name)) {
                    id = lt[name];
                } else {
                    LayerTableRecord ltr = new LayerTableRecord();
                    ltr.Name = name;
                    lt.UpgradeOpen();
                    id = lt.Add(ltr);
                    tr.AddNewlyCreatedDBObject(ltr, true);
                }
                tr.Commit();
                return id;
            }
        }
        public void SetLayerColor(ObjectId id, byte r, byte g, byte b) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                LayerTable lt = (LayerTable)tr.GetObject(doc.Database.LayerTableId, OpenMode.ForRead);
                LayerTableRecord layer = tr.GetObject(id, OpenMode.ForWrite) as LayerTableRecord;
                layer.Color = Color.FromRgb(r, g, b);
                tr.Commit();
            }
        }
        public void SetShapeColor(ObjectId id, byte r, byte g, byte b) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                Entity sh = tr.GetObject(id, OpenMode.ForWrite) as Entity;
                sh.Color = Color.FromRgb(r, g, b);
                tr.Commit();
            }
        }
        public ObjectId CurrentLayer() {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartOpenCloseTransaction()) {
                return doc.Database.Clayer;
            }
        }
        public void SetCurrentLayer(ObjectId id) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                doc.Database.Clayer = id;
                tr.Commit();
            }
        }
        public ObjectId ShapeLayer(ObjectId objId) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                Entity sh = tr.GetObject(objId, OpenMode.ForWrite) as Entity;
                tr.Commit();
                return sh.LayerId;
            }
        }
        public void SetShapeLayer(ObjectId objId, ObjectId layerId) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                Entity sh = tr.GetObject(objId, OpenMode.ForWrite) as Entity;
                sh.LayerId = layerId;
                tr.Commit();
            }
        }
        public void SetSystemVariableInt(string name, int value) {
            Application.SetSystemVariable(name, value);
        }

        public Entity SpotLight(Point3d position, double hotspot, double falloff, Point3d target) {
            Light light = new Light();
            light.LightType = Autodesk.AutoCAD.GraphicsInterface.DrawableType.SpotLight;
            light.Position = position;
            light.SetHotspotAndFalloff(hotspot, falloff);
            light.TargetLocation = target;
            return light;
        }

        public ObjectId IESLight(String webFile, Point3d position, Point3d target, Vector3d rotation) {
            Light light = new Light();
            light.LightType = Autodesk.AutoCAD.GraphicsInterface.DrawableType.WebLight;
            light.Position = position;
            light.TargetLocation = target;
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                Add(light, doc, tr);
                light.WebFile = webFile;
                light.WebRotation = rotation;
                tr.Commit();
            }
            return light.Id;
        }

        public int MentalRayRender(int width, int height, string path, double exposure) {
            Version version = Application.Version;
            if (version.Major > 20 || (version.Major == 20 && version.Minor > 0)) { //MentalRay is hidden
                Application.SetSystemVariable("RENDERENGINE", 0);
            }
            string fmt = "._-render P _R {1} {2} _yes {3}\n";
            string s = String.Format(fmt, width, height, path);
            //Document doc = Application.DocumentManager.MdiActiveDocument;
            //doc.SendStringToExecute(s, false, false, false);
            dynamic doc = Application.DocumentManager.MdiActiveDocument.GetAcadDocument();
            doc.SendCommand(s);
            return 1;
        }

        public int RapidRTRender(int width, int height, string path, string quality, double exposure) {
            Version version = Application.Version;
            if (version.Major > 20 || (version.Major == 20 && version.Minor > 0)) { //RapidRT is the default
                Application.SetSystemVariable("RENDERENGINE", 1);
            }
            string fmt = "._-render {0} _R {1} {2} _yes {3}\n";
            string s = String.Format(fmt, quality, width, height, path);
            Application.SetSystemVariable("EXPVALUE", exposure);
            //Document doc = Application.DocumentManager.MdiActiveDocument;
            //doc.SendStringToExecute(s, false, false, false);
            dynamic doc = Application.DocumentManager.MdiActiveDocument.GetAcadDocument();
            doc.SendCommand(s);
            return 1;
        }


        public int Render(int width, int height, string path, string quality, double exposure) {
            Version version = Application.Version;
            string fmt = "._-render {0} _R {1} {2} _yes {3}\n";
            string s = String.Format(fmt,
                (version.Major < 20 ||
                 (version.Major == 20 && version.Minor == 0) ? "P" : quality),
                width, height, path);
            //Document doc = Application.DocumentManager.MdiActiveDocument;
            //doc.SendStringToExecute(s, false, false, false);
            Application.SetSystemVariable("EXPVALUE", exposure);
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

        Arc ArcFromPointsAngle(Point3d p0, Point3d p1, double angle) {
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
            return new Arc(center, Vector3d.ZAxis, radius, startAngle, startAngle + angle);
        }
        DBObjectCollection ClosedPathCurveArray(Point3d[] pts, double[] angles) {
            DBObjectCollection profile = new DBObjectCollection();
            for (int i = 0; i < pts.Length; i++) {
                if (angles[i] == 0) {
                    profile.Add(PolyLine(new Point3d[] { pts[i], pts[(i + 1) % pts.Length] }));
                } else {
                    profile.Add(ArcFromPointsAngle(pts[i], pts[(i + 1) % pts.Length], angles[i]));
                }
            }
            return profile;
        }

        public Entity LightweightPolyLine(Point2d[] pts, double[] angles, double elevation) {
            Polyline p = new Polyline(pts.Length + 1);
            p.Elevation = elevation;
            for (int i = 0; i < pts.Length; i++) {
                p.AddVertexAt(i, pts[i], Math.Tan(angles[i] / 4.0), 0.0, 0.0);
            }
            p.Closed = true;
            return p;
        }
        public Entity SurfaceLightweightPolyLine(Point2d[] pts, double[] angles, double elevation) =>
            SurfaceFromCurve(LightweightPolyLine(pts, angles, elevation));

        //Recognizers
        public bool IsSolid3dAndSatisfies(ObjectId objId, Predicate<Solid3d> p) {
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
        //       public bool IsCylinder(ObjectId id) => IsSolid3dAndSatisfies(id, IsCylinderP);

        //BIM operations

        public ObjectId CreatePathFloor(Point2d[] pts, double[] angles, BIMLevel level, FloorFamily family) {
            double elevation = level.elevation - family.totalThickness + family.coatingThickness;
            Vector3d dir = new Vector3d(0, 0, family.totalThickness);
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                using (Solid3d s = new Solid3d()) {
                    s.CreateExtrudedSolid(SurfaceLightweightPolyLine(pts, angles, elevation), dir, new SweepOptions());
                    return AddAndCommit(s, doc, tr);
                }
            }
        }

        //Blocks
        //Creating instances
        public ObjectId CreateInstanceFromBlockNamed(String name, Frame3d frame) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            Database db = doc.Database;
            using (doc.LockDocument())
            using (Transaction tr = db.TransactionManager.StartTransaction()) {
                BlockTable bt = tr.GetObject(db.BlockTableId, OpenMode.ForRead) as BlockTable;
                using (BlockReference r = new BlockReference(new Point3d(0, 0, 0), bt[name])) {
                    return AddAndCommit(Transform(r, frame), doc, tr);
                }
            }
        }
        public ObjectId CreateInstanceFromBlockNamedAtRotated(String name, Point3d c, double angle) =>
            CreateInstanceFromBlockNamed(name, new Frame3d(c, vpol(1, angle), vpol(1, angle + Math.PI / 2)));
        //    CreateInstanceFromBlockNamed(
        //        name,
        //        Matrix3d.Displacement(c - Point3d.Origin) * Matrix3d.Rotation(angle, Vector3d.ZAxis, Point3d.Origin));

        public ObjectId CreateBlockInstance(ObjectId id, Frame3d frame) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            Database db = doc.Database;
            using (doc.LockDocument())
            using (Transaction tr = db.TransactionManager.StartTransaction()) {
                using (BlockReference r = new BlockReference(new Point3d(0, 0, 0), id)) {
                    return AddAndCommit(Transform(r, frame), doc, tr);
                }
            }
        }
        public ObjectId CreateBlockInstanceAtRotated(ObjectId family, Point3d c, double angle) =>
            CreateBlockInstance(family, new Frame3d(c, vpol(1, angle), vpol(1, angle + Math.PI / 2)));
        //    CreateBlockInstance(
        //        family,
        //        Matrix3d.Displacement(c - Point3d.Origin) * Matrix3d.Rotation(angle, Vector3d.ZAxis, Point3d.Origin));

        //Creating blocks
        String GenerateBlockName(BlockTable bt, String name) {
            if (bt.Has(name)) {
                int i;
                for (i = 0; bt.Has(name + i); i++) ;
                return name + i;
            } else {
                return name;
            }
        }

        public ObjectId CreateBlockFromFunc(String baseName, Func<List<Entity>> f) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            Database db = doc.Database;
            using (doc.LockDocument())
            using (Transaction tr = db.TransactionManager.StartTransaction()) {
                BlockTable bt = tr.GetObject(db.BlockTableId, OpenMode.ForRead) as BlockTable;
                String name = GenerateBlockName(bt, baseName);
                using (BlockTableRecord block = new BlockTableRecord()) {
                    block.Name = name;
                    block.Origin = new Point3d(0, 0, 0);
                    foreach (Entity e in f()) {
                        block.AppendEntity(e);
                    }
                    bt.UpgradeOpen();
                    ObjectId id = bt.Add(block);
                    tr.AddNewlyCreatedDBObject(block, true);
                    tr.Commit();
                    return id;
                }
            }
        }

        public ObjectId CreateBlockFromShapes(String baseName, ObjectId[] ids) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            Database db = doc.Database;
            using (doc.LockDocument())
            using (Transaction tr = db.TransactionManager.StartTransaction()) {
                BlockTable bt = tr.GetObject(db.BlockTableId, OpenMode.ForRead) as BlockTable;
                String name = GenerateBlockName(bt, baseName);
                using (BlockTableRecord block = new BlockTableRecord()) {
                    block.Name = name;
                    block.Origin = new Point3d(0, 0, 0);
                    bt.UpgradeOpen();
                    ObjectId id = bt.Add(block);
                    tr.AddNewlyCreatedDBObject(block, true);
                    block.AssumeOwnershipOf(new ObjectIdCollection(ids));
                    tr.Commit();
                    return id;
                }
            }
        }

        // Rows of blocks
        public BlockReference TransformedBlockReference(ObjectId id, Matrix3d xform) {
            BlockReference r = new BlockReference(new Point3d(0, 0, 0), id);
            r.TransformBy(xform);
            return r;
        }

        public List<BlockReference> RowOfBlockReferences(Point3d c, double angle, int n, double spacing, ObjectId id) {
            Matrix3d rot = Matrix3d.Rotation(angle + Math.PI / 2, Vector3d.ZAxis, Point3d.Origin);
            return Enumerable.Range(0, n).Select(i => TransformedBlockReference(id, 
                Matrix3d.Displacement(c + vpol(spacing * i, angle) - Point3d.Origin) * rot)).ToList();
        }

        public List<BlockReference> CenteredRowOfBlockReferences(Point3d c, double angle, int n, double spacing, ObjectId family) =>
            RowOfBlockReferences(c + vpol(-spacing * (n - 1) / 2, angle), angle, n, spacing, family);

        // BIM Table block
        public List<Entity> BaseRectangularTable(double length, double width, double height, double top_thickness, double leg_thickness) {
            List<Entity> objs = new List<Entity>();
            Solid3d table = new Solid3d();
            table.CreateBox(length, width, top_thickness);
            table.TransformBy(Matrix3d.Displacement(new Vector3d(0, 0, height - top_thickness / 2)));
            objs.Add(table);
            double dx = length / 2;
            double dy = width / 2;
            double leg_x = dx - leg_thickness / 2;
            double leg_y = dy - leg_thickness / 2;
            Point3d[] pts = new Point3d[] {
                    new Point3d(+leg_x, -leg_y, 0),
                    new Point3d(+leg_x, +leg_y, 0),
                    new Point3d(-leg_x, +leg_y, 0),
                    new Point3d(-leg_x, -leg_y, 0)
                };
            foreach (Point3d p in pts) {
                Solid3d leg = new Solid3d();
                leg.CreateBox(leg_thickness, leg_thickness, height - top_thickness);
                leg.TransformBy(Matrix3d.Displacement(p - Point3d.Origin + new Vector3d(0, 0, (height - top_thickness) / 2)));
                objs.Add(leg);
            }
            return objs;
        }
        public ObjectId CreateRectangularTableFamily(double length, double width, double height, double top_thickness, double leg_thickness) =>
            CreateBlockFromFunc("Khepri Table", () => BaseRectangularTable(length, width, height, top_thickness, leg_thickness));


        public ObjectId Table(Point3d c, double angle, ObjectId family) =>
            CreateBlockInstanceAtRotated(family, c, angle);

        // BIM Chair block
        public List<Entity> BaseChair(double length, double width, double height, double seat_height, double thickness) {
            List<Entity> objs = BaseRectangularTable(length, width, seat_height, thickness, thickness);
            double vx = length / 2;
            double vy = width / 2;
            double vz = height;
            Solid3d back = new Solid3d();
            back.CreateBox(thickness, width, height - seat_height);
            back.TransformBy(Matrix3d.Displacement(new Vector3d((thickness - length) / 2, 0, (seat_height + height) / 2)));
            objs.Add(back);
            return objs;
        }
        public ObjectId CreateChairFamily(double length, double width, double height, double seat_height, double thickness) =>
            CreateBlockFromFunc("Khepri Chair", () => BaseChair(length, width, height, seat_height, thickness));

        public ObjectId Chair(Point3d c, double angle, ObjectId family) =>
            CreateBlockInstance(family, new Frame3d(c, vpol(1, angle), vpol(1, angle + Math.PI / 2)));

        // BIM Table and chairs block
        public List<Entity> BaseRectangularTableAndChairs(ObjectId tableFamily, ObjectId chairFamily, double tableLength, double tableWidth, int chairsOnTop, int chairsOnBottom, int chairsOnRight, int chairsOnLeft, double spacing) {
            List<Entity> objs = new List<Entity>();
            double dx = tableLength / 2;
            double dy = tableWidth / 2;
            objs.Add(new BlockReference(new Point3d(0, 0, 0), tableFamily));
            objs.AddRange(CenteredRowOfBlockReferences(new Point3d(-dx, 0, 0), -Math.PI / 2, chairsOnBottom, spacing, chairFamily));
            objs.AddRange(CenteredRowOfBlockReferences(new Point3d(+dx, 0, 0), +Math.PI / 2, chairsOnTop, spacing, chairFamily));
            objs.AddRange(CenteredRowOfBlockReferences(new Point3d(0, +dy, 0), -Math.PI, chairsOnRight, spacing, chairFamily));
            objs.AddRange(CenteredRowOfBlockReferences(new Point3d(0, -dy, 0), 0, chairsOnLeft, spacing, chairFamily));
            return objs;
        }

        public ObjectId CreateRectangularTableAndChairsFamily(ObjectId tableFamily, ObjectId chairFamily, double tableLength, double tableWidth, int chairsOnTop, int chairsOnBottom, int chairsOnRight, int chairsOnLeft, double spacing) =>
            CreateBlockFromFunc("Khepri Table&Chair", () => BaseRectangularTableAndChairs(
                tableFamily, chairFamily, tableLength, tableWidth,
                chairsOnTop, chairsOnBottom, chairsOnRight, chairsOnLeft,
                spacing));

        public ObjectId TableAndChairs(Point3d c, double angle, ObjectId family) =>
            CreateBlockInstanceAtRotated(family, c, angle);

        //Dimensions

        public ObjectId GetDimensionBlock(String name) {
            if (name == "") {
                return ObjectId.Null;
            } else {
                Document doc = Application.DocumentManager.MdiActiveDocument;
                Database db = doc.Database;
                using (doc.LockDocument())
                using (Transaction tr = db.TransactionManager.StartTransaction()) {
                    BlockTable bt = (BlockTable)tr.GetObject(db.BlockTableId, OpenMode.ForRead);
                    if (!bt.Has(name)) {
                        // We need to load it
                        String var = "DIMBLK";
                        String prevName = Application.GetSystemVariable(var) as String;
                        Application.SetSystemVariable(var, name);
                        Application.SetSystemVariable(var, prevName == "" ? "." : prevName);
                    }
                    ObjectId id = bt[name];
                    tr.Commit();
                    return id;
                }
            }
        }

        public ObjectId CreateAlignedDimension(Point3d p0, Point3d p1, Point3d p, double scale, String mark) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            Database db = doc.Database;
            ObjectId markId = GetDimensionBlock(mark);
            using (doc.LockDocument())
            using (Transaction tr = db.TransactionManager.StartTransaction()) {
                using (AlignedDimension dim = new AlignedDimension()) {
                    dim.Dimscale = scale;
                    dim.Dimblk = markId;
                    dim.XLine1Point = p0;
                    dim.XLine2Point = p1;
                    dim.DimLinePoint = p;
                    dim.DimensionStyle = db.Dimstyle;
                    return AddAndCommit(dim, doc, tr);
                }
            }
        }

        static Dictionary<string, int> unit_code = new Dictionary<string, int>() { { "in", 1 }, { "ft", 2 }, { "mm", 3 }, { "cm", 4 }, { "dm", 5 }, { "m", 6 } };
        public void SetLengthUnit(String unit) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            Database db = doc.Database;
            using (doc.LockDocument()) {
                using (Transaction tr = db.TransactionManager.StartTransaction()) {
                    db.Unitmode = unit_code[unit];
                    tr.Commit();
                }
            }
        }

        //Save

        public void SaveAs(string pathname, string format) {
            if ("DWG".Equals(format)) {
                Document doc = Application.DocumentManager.MdiActiveDocument;
                using (doc.LockDocument())
                    doc.Database.SaveAs(pathname, true, DwgVersion.Current, doc.Database.SecurityParameters);
            } else {
                throw new AcadException(ErrorStatus.InvalidInput, "Unknown format: " + format);
            }
        }
    }
}

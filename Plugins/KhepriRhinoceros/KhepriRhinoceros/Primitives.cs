using KhepriBase;
using Rhino;
using Rhino.Commands;
using Rhino.Display;
using Rhino.DocObjects;
using Rhino.Geometry;
using Rhino.Geometry.Intersect;
using Rhino.Input;
using Rhino.PlugIns;
using Rhino.Render;
using Rhino.Render.Fields;
using Rhino.Runtime.InteropWrappers;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using static System.Net.Mime.MediaTypeNames;
using Color = System.Drawing.Color;
using MatId = System.Int32;

namespace KhepriRhinoceros {

    class Primitives : KhepriBase.Primitives {

        [DllImport("user32.dll", SetLastError = true)]
        static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
        const uint SWP_NOMOVE = 0x0002;
        const uint SWP_NOZORDER = 0x0004;

        RhinoDoc doc;

        public Primitives(RhinoDoc doc) : base() {
            this.doc = doc;
        }

        private void Ensure(bool v) {
            if (!v) {
                throw new Exception("The operation failed");
            }
        }
        R AndDelete<R>(R obj_to_return, RhinoObject obj_to_delete) {
            doc.Objects.Delete(obj_to_delete, true);
            return obj_to_return;
        }
        R AndDelete<R>(R obj_to_return, Guid obj_to_delete) {
            doc.Objects.Delete(obj_to_delete, true);
            return obj_to_return;
        }
        R AndDelete<R>(R obj_to_return, RhinoObject[] objs_to_delete) {
            foreach (RhinoObject obj_to_delete in objs_to_delete) {
                doc.Objects.Delete(obj_to_delete, true);
            }
            return obj_to_return;
        }
        R AndDelete<R>(R obj_to_return, Guid[] objs_to_delete) {
            foreach (Guid obj_to_delete in objs_to_delete) {
                doc.Objects.Delete(obj_to_delete, true);
            }
            return obj_to_return;
        }
        R SingletonElement<R>(R[] rs) {
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

        public void RunScript(string script) {
            RhinoApp.RunScript(script, true);
        }

        readonly List<RenderMaterial> renderMaterials = new List<RenderMaterial>();
        public int AddRenderMaterial(RenderMaterial mat) {
            doc.RenderMaterials.Add(mat);
            renderMaterials.Add(mat);
            return renderMaterials.Count - 1;
        }
        public MatId LoadRenderMaterialFromPath(string path) => 
            AddRenderMaterial(RenderContent.LoadFromFile(path) as RenderMaterial);

        public string DefaultMaterialsFolder() => 
            Path.GetFullPath(Path.Combine(Rhino.ApplicationSettings.FileSettings.TemplateFolder, @"..\Render Content\"));

        public Guid SetMaterial(Guid guid, int idx) {
            if (idx >= 0) {
                doc.Objects.ModifyRenderMaterial(guid, renderMaterials[idx]);
            }
            return guid;
        }
        Guid Add(Mesh geo, int mat) => SetMaterial(doc.Objects.AddMesh(geo), mat);
        Guid Add(Brep geo, int mat) => SetMaterial(doc.Objects.AddBrep(geo), mat);
        Guid Add(Sphere geo, int mat) => SetMaterial(doc.Objects.AddSphere(geo), mat);
        Guid Add(Surface geo, int mat) => SetMaterial(doc.Objects.AddSurface(geo), mat);

        public MatId CreateMaterial(string name, Color diffuse, Color specular, Color ambient, Color emission, Color reflection, double reflectivity, double reflectionGlossiness, double refractionIndex, double transparency) {
            Material mat = new Material();
            mat.Name = name;
            mat.DiffuseColor = diffuse;
            mat.SpecularColor = specular;
            mat.AmbientColor = ambient;
            mat.EmissionColor = emission;
            mat.ReflectionColor = reflection;
            mat.Reflectivity = reflectivity;
            mat.IndexOfRefraction = refractionIndex;
            mat.Transparency = transparency;
            mat.CommitChanges();
            return AddRenderMaterial(RenderMaterial.CreateBasicMaterial(mat, doc));
        }

        public MatId CreateColorMaterial(Color color) {
            int idx = doc.Materials.Add();
            Material mat = doc.Materials[idx];
            mat.DiffuseColor = color;
            mat.AmbientColor = Color.Black;
            mat.SpecularColor = Color.White;
            mat.EmissionColor = Color.FromArgb(color.A, color.R / 3, color.G / 3, color.B / 3);
            mat.Shine = 0.5;
            mat.Transparency = ((double)(255 - color.A) / 255.0);
            mat.CommitChanges();
            return AddRenderMaterial(RenderMaterial.CreateBasicMaterial(mat, doc));
        }

        public ObjectAttributes WithMaterial(int idx) =>
            idx < 0 ? null : new ObjectAttributes {
                MaterialIndex = idx,
                MaterialSource = ObjectMaterialSource.MaterialFromObject
            };
    
        public void View(Point3d position, Point3d target, double lens, bool perspective) {
            RhinoView view = PerspectiveView();
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
            viewport.SetCameraDirection(target - position, true);
            view.Redraw();
        }
        public void SetView(Point3d position, Point3d target, double lens) => View(position, target, lens, true);
        public void SetViewTop() {
            RhinoView view = doc.Views.Find("Top", true) ?? doc.Views.ActiveView;
            view.Maximized = true;
            RhinoViewport viewport = view.ActiveViewport;
            viewport.ChangeToParallelProjection(true);
            viewport.SetCameraLocation(new Point3d(0, 0, 1), false);
            viewport.SetCameraTarget(Point3d.Origin, false);
            viewport.CameraUp = Vector3d.YAxis;
            view.Redraw();
        }
        public void SetViewDisplayMode(string mode) =>
            doc.Views.ActiveView.ActiveViewport.DisplayMode = DisplayModeDescription.FindByName(mode);
        public void ViewSize(int width, int height) {
            SetWindowPos(RhinoApp.MainWindowHandle(), IntPtr.Zero, 0, 0, width, height, SWP_NOMOVE | SWP_NOZORDER);
        }

        RhinoView PerspectiveView() =>
            doc.Views.Find("Perspective", true) ?? doc.Views.ActiveView;
        public Point3d ViewCamera() =>
            PerspectiveView().ActiveViewport.CameraLocation;
        public Point3d ViewTarget() {
            RhinoView view = PerspectiveView();
            //return view.ActiveViewport.CameraTarget;
            return view.ActiveViewport.CameraLocation + view.ActiveViewport.CameraDirection;
        }
        public double ViewLens() =>
            PerspectiveView().ActiveViewport.Camera35mmLensLength;

        public void RenderLoadHDRiEnvironment(string name, string path) {
            RenderEnvironment env = doc.RenderEnvironments.FirstOrDefault(e => e.Name == name);
            if (env == null) {
                env = RenderContent.LoadFromFile(path) as RenderEnvironment;
                doc.RenderEnvironments.Add(env);
            }
        }
        public void RenderUseHDRiEnvironment(string name, double rotation) {
            RenderEnvironment renv = doc.RenderEnvironments.First(e => e.Name == name);
            if (Math.Abs(rotation) > 1e-6) {
                RenderTexture rt = renv.FindChild("texture") as RenderTexture;
                rt.BeginChange(RenderContent.ChangeContexts.Ignore);
                rt.SetParameter("azimuth", rotation);
                rt.EndChange();
            }
            // RhinoDoc.CurrentEnvironment.ForAnyUsage is obsolete: assign the
            // environment to each usage individually via RenderSettings (Rhino 8).
            // RenderSettings is returned by value, so every edit here — including
            // the background style — must be written back to the document.
            RenderSettings rs = doc.RenderSettings;
            foreach (RenderSettings.EnvironmentUsage usage in new[] {
                         RenderSettings.EnvironmentUsage.Background,
                         RenderSettings.EnvironmentUsage.Reflection,
                         RenderSettings.EnvironmentUsage.Skylighting }) {
                rs.SetRenderEnvironmentId(usage, renv.Id);
                rs.SetRenderEnvironmentOverride(usage, true);
            }
            rs.BackgroundStyle = BackgroundStyle.Environment;
            rs.TransparentBackground = true;
            doc.RenderSettings = rs;
        }
        public void ClayRenderBlack(string env, double rotation, int width, int height, int quality, string path) {
            RenderUseHDRiEnvironment(env, rotation);
            // RhinoDoc.GroundPlane is obsolete; use RenderSettings.GroundPlane
            // (value copy -> write back).
            RenderSettings rs = doc.RenderSettings;
            rs.GroundPlane.Enabled = false;
            rs.GroundPlane.ShadowOnly = true;
            doc.RenderSettings = rs;
            Render(width, height, quality, path);
        }
        public void ClayRenderWhite(string env, double rotation, int width, int height, int quality, string path) {
            RenderUseHDRiEnvironment(env, rotation);
            RenderSettings rs = doc.RenderSettings;
            rs.GroundPlane.Enabled = true;
            rs.GroundPlane.ShadowOnly = false;
            doc.RenderSettings = rs;
            Render(width, height, quality, path);
        }
        public void SetBackgroundHDRi(string path, double angle) {
            // RhinoDoc.CurrentEnvironment.ForLighting is obsolete: look up the
            // skylighting environment via RenderSettings (Rhino 8) and edit its texture.
            Guid envId = doc.RenderSettings.RenderEnvironmentId(
                RenderSettings.EnvironmentUsage.Skylighting, RenderSettings.EnvironmentPurpose.Standard);
            RenderEnvironment renv = RenderContent.FromId(doc, envId) as RenderEnvironment;
            RenderTexture rt = renv.FindChild("texture") as RenderTexture;
            rt.Fields.Set("filename", path);

            //rt.SetEnvironmentMappingMode(TextureEnvironmentMappingMode.EnvironmentMap);
            //rt.SetRotation(new Vector3d(0.0, 0.0, 0.0));
            //rt.GetProjectionMode(TextureProjectionMode.);

        }
        public void Render(int width, int height, int quality, string path) {
            System.Drawing.Size size = new System.Drawing.Size(width, height);
            doc.RenderSettings.ImageSize = size;
            doc.RenderSettings.UseViewportSize = false;
            doc.RenderSettings.AntialiasLevel = (AntialiasLevel)quality;
            RhinoApp.RunScript("_-Render", true);
            RhinoApp.RunScript($"_-SaveRenderWindowAs \"{path}\" EnterEnd", true);
            RhinoApp.RunScript($"_-CloseRenderWindow", true);
        }
        public void SaveView(int width, int height, string path) {
            RhinoView view = doc.Views.ActiveView;
            System.Drawing.Size size = new System.Drawing.Size(width, height);
            var capture = view.CaptureToBitmap(size);
            capture.Save(path);
        }
        public byte Sync() => 1;
        public byte Disconnect() => 2;
        public void Delete(Guid id) =>
            doc.Objects.Delete(id, true);
        public void DeleteMany(Guid[] ids) =>
            doc.Objects.Delete(ids, true);
        public int DeleteAll() {
            int count = 0;
            foreach (RhinoObject o in doc.Objects) {
                doc.Objects.Delete(o, true);
                count++;
            }
            for(int idx = 0; idx < doc.Lights.Count; idx++) {
                doc.Lights.Delete(idx, true);
                count++;
            }
            return count;
        }
        public int DeleteAllInLayer(Guid id) =>
            doc.Objects.Delete(doc.Objects.FindByLayer(doc.Layers[doc.Layers.Find(id, true, -1)]).Select(o => o.Id).ToArray(), true);

        public void Select(Guid id) {
            doc.Objects.Select(id);
        }
        public void SelectMany(Guid[] ids) {
            doc.Objects.Select(ids);
        }
        public void Highlight(RhinoObject o) => o.Highlight(true);
        public void Unhighlight(RhinoObject o) => o.Highlight(false);
        public void UnhighlightAll() {
            foreach (RhinoObject o in doc.Objects) {
                o.Highlight(false);
            }
        }

        public Guid Point(Point3d p) => doc.Objects.AddPoint(p);
        public Point3d PointPosition(Guid id) => ((Point)doc.Objects.Find(id).Geometry).Location;
        public Guid PolyLine(Point3d[] pts) => doc.Objects.AddPolyline(pts);
        public Point3d[] LineVertices(RhinoObject obj) {
            GeometryBase geo = obj.Geometry;
            if (geo is LineCurve lc) {
                return new Point3d[] { lc.PointAtStart, lc.PointAtEnd };
            } else if (geo is PolylineCurve plc) {
                Polyline polyline = new Polyline();
                Debug.Assert(plc.TryGetPolyline(out polyline));
                return polyline.ToArray();
            } else {
                throw new Exception("Unknown object");
            }
        }
        public Guid ClosedPolyLine(Point3d[] pts) => doc.Objects.AddPolyline(pts.Concat(new[] { pts[0] }));
        public Guid Spline(Point3d[] pts) => doc.Objects.AddCurve(Curve.CreateInterpolatedCurve(pts, 3));
        public Guid SplineTangents(Point3d[] pts, Vector3d start, Vector3d end) => doc.Objects.AddCurve(Curve.CreateInterpolatedCurve(pts, 3, CurveKnotStyle.Chord, start, end));
        public Guid ClosedSpline(Point3d[] pts) => doc.Objects.AddCurve(Curve.CreateInterpolatedCurve(pts.Concat(new[] { pts[0] }), 3));
        double[] RhinoStyleKnots(double[] knots, int targetCount) {
            if (knots.Length == targetCount) {
                return knots;
            } else if (knots.Length == targetCount + 2) {
                return knots.Skip(1).Take(targetCount).ToArray();
            } else {
                throw new ArgumentException("Unexpected knot vector length");
            }
        }
        void SetKnots(Rhino.Geometry.NurbsCurve curve, double[] knots) {
            double[] ks = RhinoStyleKnots(knots, curve.Knots.Count);
            for (int i = 0; i < ks.Length; i++) {
                curve.Knots[i] = ks[i];
            }
        }
        void SetKnots(Rhino.Geometry.NurbsSurface surface, int direction, double[] knots) {
            var knotList = direction == 0 ? surface.KnotsU : surface.KnotsV;
            double[] ks = RhinoStyleKnots(knots, knotList.Count);
            for (int i = 0; i < ks.Length; i++) {
                knotList[i] = ks[i];
            }
        }
        static double[] BezierKnots(int count) =>
            Enumerable.Repeat(0.0, count).Concat(Enumerable.Repeat(1.0, count)).ToArray();
        public Guid BezierCurve(Point3d[][] controlPoints, bool closed, MatId mat) {
            PolyCurve curve = new PolyCurve();
            foreach (Point3d[] pts in controlPoints) {
                curve.Append(new BezierCurve(pts).ToNurbsCurve());
            }
            return SetMaterial(doc.Objects.AddCurve(curve), mat);
        }
        Rhino.Geometry.NurbsCurve NurbsCurveFrom(Point3d[] controlPoints, int degree, double[] knots, double[] weights, bool closed) {
            bool rational = weights != null && weights.Length == controlPoints.Length && weights.Any(w => Math.Abs(w - 1.0) > 1e-12);
            Rhino.Geometry.NurbsCurve curve = new Rhino.Geometry.NurbsCurve(3, rational, degree + 1, controlPoints.Length);
            for (int i = 0; i < controlPoints.Length; i++) {
                curve.Points.SetPoint(i, controlPoints[i], rational ? weights[i] : 1.0);
            }
            SetKnots(curve, knots);
            return curve;
        }
        public Guid BSplineCurve(Point3d[] controlPoints, int degree, double[] knots, bool closed, MatId mat) =>
            SetMaterial(doc.Objects.AddCurve(NurbsCurveFrom(controlPoints, degree, knots, null, closed)), mat);
        public Guid NurbsCurve(Point3d[] controlPoints, int degree, double[] knots, double[] weights, bool closed, MatId mat) =>
            SetMaterial(doc.Objects.AddCurve(NurbsCurveFrom(controlPoints, degree, knots, weights, closed)), mat);
        public Guid Circle(Point3d c, Vector3d n, double r) => doc.Objects.AddCircle(new Circle(new Plane(c, n), r));
        Circle CircleFrom(RhinoObject obj) {
            Circle circle = new Circle();
            Debug.Assert(((Curve)obj.Geometry).TryGetCircle(out circle));
            return circle;
        }
        public Point3d CircleCenter(RhinoObject obj) => CircleFrom(obj).Center;
        public Vector3d CircleNormal(RhinoObject obj) => CircleFrom(obj).Normal;
        public double CircleRadius(RhinoObject obj) => CircleFrom(obj).Radius;
        public Guid Ellipse(Plane p, double radiusX, double radiusY) =>
            doc.Objects.AddEllipse(new Ellipse(p, radiusX, radiusY));
        Ellipse AsEllipse(RhinoObject obj) {
            Ellipse ellipse;
            if (!AsCurve(obj).TryGetEllipse(out ellipse)) {
                throw new Exception("Object is not an ellipse");
            }
            return ellipse;
        }
        public Plane EllipsePlane(RhinoObject obj) => AsEllipse(obj).Plane;
        public double EllipseRadiusX(RhinoObject obj) => AsEllipse(obj).Radius1;
        public double EllipseRadiusY(RhinoObject obj) => AsEllipse(obj).Radius2;
        Plane RotatedPlane(Point3d c, Vector3d n, double startAngle) {
            Plane pl = new Plane(c, n);
            if (startAngle != 0) {
                Debug.Assert(pl.Rotate(startAngle, n));
            }
            return pl;
        }
        public Guid Arc(Plane p, double radius, double startAngle, double endAngle) =>
            doc.Objects.AddArc(new Arc(new Circle(p, radius), new Interval(startAngle, endAngle)));

        Arc AsArc(RhinoObject obj) {
            Arc arc;
            if (!AsCurve(obj).TryGetArc(out arc)) {
                throw new Exception("Object is not an arc");
            }
            return arc;
        }
        public Point3d ArcCenter(RhinoObject obj) => AsArc(obj).Center;
        public Vector3d ArcNormal(RhinoObject obj) => AsArc(obj).Plane.Normal;
        public double ArcRadius(RhinoObject obj) => AsArc(obj).Radius;
        public double ArcStartAngle(RhinoObject obj) => AsArc(obj).StartAngle;
        public double ArcEndAngle(RhinoObject obj) => AsArc(obj).EndAngle;
        public Point3d[] CurveSamplePoints(RhinoObject obj, int samples) => SampleCurve(AsCurve(obj), samples);

        public Point3d CurveClosestPoint(RhinoObject obj, Point3d point) {
            Curve curve = AsCurve(obj);
            Ensure(curve.ClosestPoint(point, out double t));
            return curve.PointAt(t);
        }

        public double CurveClosestParameter(RhinoObject obj, Point3d point) {
            Curve curve = AsCurve(obj);
            Ensure(curve.ClosestPoint(point, out double t));
            return t;
        }

        public Point3d[] CurveCurveClosestPoints(RhinoObject obj0, RhinoObject obj1) {
            Curve curve0 = AsCurve(obj0);
            Curve curve1 = AsCurve(obj1);
            Ensure(curve0.ClosestPoints(curve1, out Point3d point0, out Point3d point1));
            return new[] { point0, point1 };
        }

        public double[] CurveCurveClosestParameters(RhinoObject obj0, RhinoObject obj1) {
            Point3d[] points = CurveCurveClosestPoints(obj0, obj1);
            return new[] {
                CurveClosestParameter(obj0, points[0]),
                CurveClosestParameter(obj1, points[1])
            };
        }

        public Point3d BrepClosestPoint(RhinoObject obj, Point3d point) =>
            AsBrep(obj).ClosestPoint(point);

        public int CurvePointClassification(RhinoObject obj, Point3d point, double tolerance) =>
            CurveClosestPoint(obj, point).DistanceTo(point) <= tolerance ? 1 : 0;

        public int BrepPointClassification(RhinoObject obj, Point3d point, double tolerance) {
            Brep brep = AsBrep(obj);
            if (brep.IsSolid && brep.IsPointInside(point, tolerance, true)) {
                return 1;
            }
            Point3d closest;
            ComponentIndex componentIndex;
            double u, v;
            Vector3d normal;
            if (!brep.ClosestPoint(point, out closest, out componentIndex, out u, out v, tolerance, out normal)) {
                return 0;
            }
            if (closest.DistanceTo(point) > tolerance) {
                return 0;
            }
            if (componentIndex.ComponentIndexType == ComponentIndexType.BrepFace) {
                PointFaceRelation relation = brep.Faces[componentIndex.Index].IsPointOnFace(u, v);
                return relation == PointFaceRelation.Boundary ? 2 : 1;
            }
            return 2;
        }

        public Guid Text(string str, Plane p, double height, string fontName, bool bold, bool italic) =>
            doc.Objects.AddText(str, p, height, fontName, bold, italic);

        Guid AddMesh(Mesh mesh, MatId mat, bool smooth) {
            mesh.FaceNormals.ComputeFaceNormals();
            if (smooth) {
                mesh.Normals.ComputeNormals();
            }
            mesh.Compact();
            return Add(mesh, mat);
        }

        public Guid Mesh(Point3d[] pts, int[][] faces, MatId mat) {
            Mesh mesh = new Mesh();
            mesh.Vertices.AddVertices(pts);
            foreach(int[] face in faces) {
                mesh.Faces.AddFace(face[0], face[1], face[2], face[3]);
            }
            return AddMesh(mesh, mat, false);
        }
        public Guid NGon(Point3d[] pts, Point3d pivot, bool smooth, MatId mat) {
            int n = pts.Length;
            Mesh mesh = new Mesh();
            mesh.Vertices.AddVertices(pts);
            mesh.Vertices.Add(pivot);
            for (int i = 0; i < n - 1; i++) {
                mesh.Faces.AddFace(i, i + 1, n);
            }
            mesh.Faces.AddFace(n - 1, 0, n);
            return AddMesh(mesh, mat, smooth);
        }

        public Guid SurfaceFrom(Guid[] ids, MatId mat) {
            PolyCurve curve = new PolyCurve();
            foreach (Guid id in ids) {
                Curve crv = ((Curve)doc.Objects.Find(id).Geometry);
                curve.Append(crv.ToNurbsCurve());
            }
            foreach (Guid id in ids) {
                doc.Objects.Delete(id, true);
            }
            return Add(SingletonElement(Brep.CreatePlanarBreps(curve, doc.ModelAbsoluteTolerance)), mat);
        }
        public Guid SurfaceFromCurve(Curve c, MatId mat) =>
            Add(SingletonElement(Brep.CreatePlanarBreps(c, doc.ModelAbsoluteTolerance)), mat);
        public Guid SurfaceFromCurves(Curve[] cs, MatId mat) =>
            Add(SingletonElement(Brep.CreatePlanarBreps(cs, doc.ModelAbsoluteTolerance)), mat);
        public Guid SurfaceCircle(Point3d c, Vector3d n, double r, MatId mat) =>
            SurfaceFromCurve(new Circle(new Plane(c, n), r).ToNurbsCurve(), mat);
        public Guid SurfaceEllipse(Plane p, double radiusX, double radiusY, MatId mat) =>
            SurfaceFromCurve(new Ellipse(p, radiusX, radiusY).ToNurbsCurve(), mat);
        public Guid SurfaceArc(Plane p, double radius, double startAngle, double endAngle, MatId mat) {
            Curve arc = new Arc(new Circle(p, radius), new Interval(startAngle, endAngle)).ToNurbsCurve();
            return SurfaceFromCurves(new Curve[] {
                arc,
                new PolylineCurve(new Point3d[] { p.Origin, arc.PointAtStart }).ToNurbsCurve(),
                new PolylineCurve(new Point3d[] { p.Origin, arc.PointAtEnd }).ToNurbsCurve() }, mat);
        }
        public Guid SurfaceClosedPolyLine(Point3d[] pts, MatId mat) =>
            (pts.Length > 2 && pts.Length <= 4) ?
                Add(pts.Length == 3 ?
                        Rhino.Geometry.NurbsSurface.CreateFromCorners(pts[0], pts[1], pts[2]) :
                        Rhino.Geometry.NurbsSurface.CreateFromCorners(pts[0], pts[1], pts[2], pts[3]),
                    mat) :
                SurfaceFromCurve(new PolylineCurve(pts.Concat(new[] { pts[0] }).ToArray()).ToNurbsCurve(), mat);
        Curve[] ClosedCurvesFromPoints(Point3d[][] ptss, bool[] smooths) =>
           ptss.Zip(smooths, (pts, smooth) => smooth ?
                    Curve.CreateInterpolatedCurve(pts.Concat(new[] { pts[0] }), 3) :
                    new PolylineCurve(pts.Concat(new[] { pts[0] }))).ToArray();
        public Guid SurfaceFromCurvesPoints(Point3d[][] ptss, bool[] smooths, MatId mat) =>
            SurfaceFromCurves(ClosedCurvesFromPoints(ptss, smooths), mat);
        public Guid Sphere(Point3d c, double r, MatId mat) => Add(new Sphere(c, r), mat);
        public Guid Torus(Point3d c, Vector3d vz, double majorRadius, double minorRadius, MatId mat) =>
            Add(new Torus(new Plane(c, vz), majorRadius, minorRadius).ToRevSurface(), mat);
        public Guid Cylinder(Point3d bottom, double radius, Point3d top, MatId mat) =>
            Add(Brep.CreateFromCylinder(new Cylinder(new Circle(new Plane(bottom, top - bottom), radius), bottom.DistanceTo(top)), true, true), mat);
        Cylinder CylinderFrom(RhinoObject obj) {
            Cylinder cylinder = new Cylinder();
                Debug.Assert(((Brep)obj.Geometry).Faces[0].TryGetCylinder(out cylinder));
                return cylinder;
        }
        // This is not an efficient way to retrieve cylinder information. Maybe memoize the CylinderFrom function? Another option is to return a tuple
        public Point3d CylinderCenter(RhinoObject obj) => CylinderFrom(obj).Center;
        public Vector3d CylinderAxis(RhinoObject obj) => CylinderFrom(obj).Axis;
        public Double CylinderHeight1(RhinoObject obj) => CylinderFrom(obj).Height1;
        public Double CylinderHeight2(RhinoObject obj) => CylinderFrom(obj).Height2;
        public Double CylinderRadius(RhinoObject obj) => CylinderFrom(obj).CircleAt(0.0).Radius;
        // This is the efficient version
        public Tuple<Point3d, Vector3d, double, double, double, double> CylinderInfo(RhinoObject obj) {
            Cylinder cyl = CylinderFrom(obj);
            return Tuple.Create(cyl.Center, cyl.Axis, cyl.Height1, cyl.Height2, cyl.CircleAt(0.0).Radius, cyl.CircleAt(1.0).Radius);
        }
        public Guid Cone(Point3d bottom, double radius, Point3d top, MatId mat) =>
            Add(Brep.CreateFromCone(new Cone(new Plane(bottom, top - bottom), bottom.DistanceTo(top), radius), true), mat);
        public Guid ConeFrustum(Point3d bottom, double bottom_radius, Point3d top, double top_radius, MatId mat) {
            Vector3d vec = top - bottom;
            Circle bottomCircle = new Circle(new Plane(bottom, vec), bottom_radius);
            Circle topCircle = new Circle(new Plane(top, vec), top_radius);
            LineCurve shapeCurve = new LineCurve(bottomCircle.PointAt(0), topCircle.PointAt(0));
            Line axis = new Line(bottom, top);
            return Add(Brep.CreateFromRevSurface(RevSurface.Create(shapeCurve, axis), true, true), mat);
        }
        public Guid Box(Point3d corner, Vector3d vx, Vector3d vy, double dx, double dy, double dz, MatId mat) {
            Vector3d vz = Vector3d.CrossProduct(vx, vy);
            vx.Unitize();
            vy.Unitize();
            vz.Unitize();
            vx = vx * dx;
            vy = vy * dy;
            vz = vz * dz;
            return Add(Brep.CreateFromBox(new Point3d[] {
                corner,
                corner + vx,
                corner + vx + vy,
                corner + vy,
                corner + vz,
                corner + vx + vz,
                corner + vx + vy + vz,
                corner + vy + vz }),
                mat);
        }
        public Guid XYCenteredBox(Point3d corner, Vector3d vx, Vector3d vy, double dx, double dy, double dz, MatId mat) {
            Vector3d vz = Vector3d.CrossProduct(vx, vy);
            vx.Unitize();
            vy.Unitize();
            vz.Unitize();
            vx = vx * (dx / 2);
            vy = vy * (dy / 2);
            vz = vz * dz;
            return Add(Brep.CreateFromBox(new Point3d[] {
                corner - vx - vy,
                corner + vx - vy,
                corner + vx + vy,
                corner - vx + vy,
                corner - vx - vy + vz,
                corner + vx - vy + vz,
                corner + vx + vy + vz,
                corner - vx + vy + vz }),
                mat);
        }
        public Guid IrregularPyramid(Point3d[] bpts, Point3d apex, MatId mat) {
            int n = bpts.Length;
            double tol = doc.ModelAbsoluteTolerance;
            List<Brep> breps = new List<Brep>();
            for (int i = 0; i < n; i++) {
                breps.Add(Brep.CreateFromCornerPoints(bpts[i], bpts[(i + 1) % n], apex, tol));
            }
            Brep[] joined = Brep.JoinBreps(breps.AsEnumerable(), tol);
            return Add(SingletonElement(joined).CapPlanarHoles(tol), mat);
        }
        public Guid IrregularPyramidFrustum(Point3d[] bpts, Point3d[] tpts, MatId mat) {
            int n = bpts.Length;
            double tol = doc.ModelAbsoluteTolerance;
            List<Brep> breps = new List<Brep>();
            for (int i = 0; i < n; i++) {
                breps.Add(Brep.CreateFromCornerPoints(bpts[i], bpts[(i + 1) % n], tpts[(i + 1) % n], tpts[i], tol));
            }
            breps.AddRange(Brep.CreatePlanarBreps(new PolylineCurve(tpts.Concat(new Point3d[] { tpts[0] })), doc.ModelAbsoluteTolerance));
            Curve bot = new PolylineCurve(bpts.Concat(new Point3d[] { bpts[0] }));
            bot.Reverse();
            breps.AddRange(Brep.CreatePlanarBreps(bot, doc.ModelAbsoluteTolerance));
            Brep[] joined = Brep.JoinBreps(breps.AsEnumerable(), tol);
            return Add(SingletonElement(joined), mat);
        }
        public Guid PrismWithHoles(Point3d[][] ptss, bool[] smooths, Vector3d dir, MatId mat) {
            Curve[] curves = ClosedCurvesFromPoints(ptss, smooths);
            foreach (Curve curve in curves) {
                curve.Reverse();
            }
            Brep[] bots = Brep.CreatePlanarBreps(curves, doc.ModelAbsoluteTolerance);
            Brep[] sides = curves.Select(curve => Surface.CreateExtrusion(curve, dir).ToBrep()).ToArray();
            foreach (Curve curve in curves) {
                curve.Reverse();
                curve.Translate(dir);
            }
            Brep[] tops = Brep.CreatePlanarBreps(curves, doc.ModelAbsoluteTolerance);
            Brep[] joined = Brep.JoinBreps(bots.Concat(sides).Concat(tops).AsEnumerable(), doc.ModelAbsoluteTolerance);
            return Add(SingletonElement(joined), mat);
        }

        /*
        public Guid MeshFromGrid(int m, int n, Point3d[] pts, bool closedM, bool closedN) =>
            new PolygonMesh(PolyMeshType.SimpleMesh, m, n, new Point3dCollection(pts), closedM, closedN);
            */
        public Guid SurfaceFromGrid(int nU, int nV, Point3d[] pts, bool closedU, bool closedV, int degreeU, int degreeV, MatId mat) =>
            Add(Rhino.Geometry.NurbsSurface.CreateThroughPoints(pts, nU, nV, degreeU, degreeV, closedU, closedV), mat);
        Rhino.Geometry.NurbsSurface NurbsSurfaceFrom(Point3d[] controlPoints, int nU, int nV, int degreeU, int degreeV,
                                                     double[] knotsU, double[] knotsV, double[] weights) {
            bool rational = weights != null && weights.Length == controlPoints.Length && weights.Any(w => Math.Abs(w - 1.0) > 1e-12);
            Rhino.Geometry.NurbsSurface surface = Rhino.Geometry.NurbsSurface.Create(3, rational, degreeU + 1, degreeV + 1, nU, nV);
            for (int u = 0; u < nU; u++) {
                for (int v = 0; v < nV; v++) {
                    int i = u * nV + v;
                    surface.Points.SetPoint(u, v, controlPoints[i], rational ? weights[i] : 1.0);
                }
            }
            SetKnots(surface, 0, knotsU);
            SetKnots(surface, 1, knotsV);
            return surface;
        }
        public Guid BezierSurface(Point3d[] controlPoints, int nU, int nV, bool closedU, bool closedV, MatId mat) =>
            Add(NurbsSurfaceFrom(controlPoints, nU, nV, nU - 1, nV - 1,
                                 BezierKnots(nU), BezierKnots(nV), null), mat);
        public Guid BSplineSurface(Point3d[] controlPoints, int nU, int nV, int degreeU, int degreeV,
                                   double[] knotsU, double[] knotsV, bool closedU, bool closedV, MatId mat) =>
            Add(NurbsSurfaceFrom(controlPoints, nU, nV, degreeU, degreeV, knotsU, knotsV, null), mat);
        public Guid NurbsSurface(Point3d[] controlPoints, int nU, int nV, int degreeU, int degreeV,
                                 double[] knotsU, double[] knotsV, double[] weights, bool closedU, bool closedV, MatId mat) =>
            Add(NurbsSurfaceFrom(controlPoints, nU, nV, degreeU, degreeV, knotsU, knotsV, weights), mat);

        /*
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

        public BrepFace AsBrepFace(RhinoObject obj) {
            Brep brep = AsBrep(obj);
            Debug.Assert(brep.Faces.Count == 1, "Brep '" + obj + "' has more than one face!");
            return brep.Faces[0];
        }
        public Surface AsSurface(RhinoObject obj) {
            if (obj.Geometry is Surface srf) {
                return srf;
            } else {
                if (obj.Geometry is Brep brep) {
                    if (brep.Faces.Count == 1) {
                        return brep.Faces[0];
                    }
                }
            }
            throw new Exception("Unable to obtain a surface");
        }

        public Brep[] Thicken(RhinoObject obj, double thickness) {
            Brep brep = AsBrep(obj);
            return AndDelete(
                brep.Faces.Select(face =>
                    Brep.CreateFromOffsetFace(
                        face,
                        thickness,
                        doc.ModelAbsoluteTolerance,
                        true,
                        true)).ToArray(),
                obj);
        }
        static double SphPhi(Vector3d v) => (v.X == 0.0 && v.Y == 0.0) ? 0.0 : Math.Atan2(v.Y, v.X);
        static Vector3d Vpol(double rho, double phi) => new Vector3d(rho * Math.Cos(phi), rho * Math.Sin(phi), 0);

        public double[] CurveDomain(RhinoObject obj) {
            Curve c = AsCurve(obj);
            return new double[] { c.Domain.T0, c.Domain.T1 };
        }

        public double CurveLength(RhinoObject obj) {
            Curve c = AsCurve(obj);
            return c.GetLength();
        }
        public Plane CurveFrameAtOld(RhinoObject obj, double t) {
            Curve c = AsCurve(obj);
            Ensure(c.FrameAt(t, out Plane pl));
            return pl;
        }
        public Plane CurveFrameAtLengthOld(RhinoObject obj, double l) {
            Curve c = AsCurve(obj);
            Ensure(c.LengthParameter(l, out double t));
            Ensure(c.FrameAt(t, out Plane pl));
            return pl;
        }

        public Point3d[] CurvePointsAt(RhinoObject obj, double[] ts) {
            Curve c = AsCurve(obj);
            return ts.Select(t => c.PointAt(t)).ToArray();
        }
        public Vector3d[] CurveTangentsAt(RhinoObject obj, double[] ts) {
            Curve c = AsCurve(obj);
            return ts.Select(t => c.TangentAt(t)).ToArray();
        }
        public Vector3d[] CurveNormalsAt(RhinoObject obj, double[] ts) {
            Curve c = AsCurve(obj);
            return ts.Select(t => c.DerivativeAt(t, 2)[2]).ToArray();
        }
        public Plane FrameAt(Curve c, double t) {
            Point3d origin = c.PointAt(t);
            Vector3d[] derivs = c.DerivativeAt(t, 2);
            Vector3d vt = derivs[1];
            Vector3d vn = derivs[2];
            // Probably, a bad idea. It should only be attempted if interpolating from neighboring frames does not help
            Vector3d vx = (vn.Length < 1e-14) ? Vpol(1, SphPhi(vt) + Math.PI / 2) : vn;
            Vector3d vy = Vector3d.CrossProduct(vt, vx);
            return new Plane(origin, vx / vx.Length, vy / vy.Length);
        }
        public Plane CurveFrameAt(RhinoObject obj, double t) => FrameAt(AsCurve(obj), t);
        public Plane CurveFrameAtLength(RhinoObject obj, double l) {
            Curve c = AsCurve(obj);
            Ensure(c.LengthParameter(l, out double t));
            return FrameAt(c, t);
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
            Ensure(s.FrameAt(u, v, out Plane pl));
            return pl;
        }
        
        public Brep Extrusion(RhinoObject obj, Vector3d dir) {
            if (obj.Geometry is Curve) {
                return AndDelete(Surface.CreateExtrusion(obj.Geometry as Curve, dir).ToBrep(), obj);
            } else { // Must be a surface
                Curve[] curves = Curve.JoinCurves(AsBrep(obj).DuplicateEdgeCurves());
                Surface surf = Surface.CreateExtrusion(SingletonElement(curves), dir);
                return AndDelete(surf.ToBrep().CapPlanarHoles(doc.ModelAbsoluteTolerance), obj);
            }
        }

        RhinoObject TransformProfile(Curve path, RhinoObject profile, double t, double rotation, double scale) {
            Ensure(path.PerpendicularFrameAt(t, out Plane plane));
            Transform xform = Transform.ChangeBasis(plane, Plane.WorldXY);
            xform = Transform.Multiply(xform, Transform.Scale(Point3d.Origin, scale));
            xform = Transform.Multiply(xform, Transform.Rotation(rotation, Vector3d.ZAxis, Point3d.Origin));
            return new ObjRef(doc, doc.Objects.Transform(profile, xform, false)).Object();
        }

        IEnumerable<double> Division(double start, double end, int n) {
            return Enumerable.Range(0, n).Select(i => start + (end - start) / n * i);
        }

        public Brep[] SweepPathCurve(RhinoObject path, RhinoObject profile, double rotation, double scale) {
            Curve pathCurve = path.Geometry as Curve;
            RhinoObject[] profiles;
            if (rotation == 0 && scale == 1) {
                // Shouldn't t = 0.0 be t = pathCurve.Domain.T1 ?
                profiles = new RhinoObject[] { TransformProfile(pathCurve, profile, 0.0, 0.0, 1.0) };
            } else {
                int n = 20;
                profiles = Division(pathCurve.Domain.T0, pathCurve.Domain.T1, n).Zip(Division(0, rotation, n),
                    (t, r) => Tuple.Create(t, r)).Zip(Division(1, scale, n),
                    (tt, s) => TransformProfile(pathCurve, profile, tt.Item1, tt.Item2, s)).ToArray();
            }
            Brep[] breps = Brep.CreateFromSweep(pathCurve, profiles.Select(p => p.Geometry as Curve), false, doc.ModelAbsoluteTolerance);
            return AndDelete(AndDelete(AndDelete(breps, profiles), path), profile);
        }

        public Brep[] SolidSweepPathProfile(RhinoObject path, RhinoObject profile, double rotation, double scale) {
            Brep[] breps = SweepPathCurve(path, profile, rotation, scale);
            return breps.Select(brep => brep.CapPlanarHoles(doc.ModelAbsoluteTolerance)).ToArray();
        }

        public Brep[] SolidSweepPathCurve(RhinoObject path, Curve profile, double rotation, double scale) =>
            SolidSweepPathProfile(path, new ObjRef(doc, doc.Objects.AddCurve(profile)).Object(), rotation, scale);

        Brep[] TryBooleanDifference(Brep brep0, Brep brep1) {
            for (int e = 5; e > 2; e--) {
                Brep[] newBreps = Brep.CreateBooleanDifference(brep0, brep1, Math.Pow(10, -e));
                if (newBreps != null) {
                    return newBreps;
                }
            }
            return null;
        }
        Brep[] TryBooleanDifference(IEnumerable<Brep> brep0, IEnumerable<Brep> brep1) {
            for (int e = 5; e > 2; e--) {
                Brep[] newBreps = Brep.CreateBooleanDifference(brep0, brep1, Math.Pow(10, -e));
                if (newBreps != null) {
                    return newBreps;
                }
            }
            return null;
        }

        public Brep[] SweepPathProfile(RhinoObject path, RhinoObject profile, double rotation, double scale) {
            if (profile.Geometry is Curve) {
                return SweepPathCurve(path, profile, rotation, scale);
            } else {
                Brep brep = AsBrep(profile);
                Curve outCurve = SingletonElement(Curve.JoinCurves(brep.DuplicateNakedEdgeCurves(true, false)));
                Brep[] outSolid = SolidSweepPathCurve(path, outCurve, rotation, scale);
                Curve[] inCurves = Curve.JoinCurves(brep.DuplicateNakedEdgeCurves(false, true));
                if (inCurves.Length > 0) {
                    Brep[] inSolids = inCurves.Select(curve => SingletonElement(SolidSweepPathCurve(path, curve, rotation, scale))).ToArray();
                    outSolid = TryBooleanDifference(outSolid, inSolids);
                }
                if (outSolid == null) {
                    throw new Exception("Sweep failed");
                } else {
                    return AndDelete(outSolid, profile);
                }
            }
        }

        /*            return single_ref_or_union(sweep_path_curve(path, profile, rotation, scale))
            elif rh.IsSurface(profile):
                o_refs, i_refs = ([single_ref_or_union(solid_sweep_path_curve(path, border, rotation, scale))
                                   for border in rh.DuplicateSurfaceBorder(profile, i)]
                                  for i in (1, 2))
                if i_refs == []:
                    return native_ref_or_union(o_refs)
                else:
                    return subtract_refs(native_ref_or_union(o_refs),
                                         native_ref_or_union(i_refs))
            else:
                raise RuntimeError('Continue this')
        */

        public Brep Loft(RhinoObject[] profiles, RhinoObject[] rails, bool ruled, bool closed) {
            double tol = doc.ModelAbsoluteTolerance;
            Brep[] breps;
            if (rails.Length == 0) {
                Point3d startPt = Point3d.Unset;
                Point3d endPt = Point3d.Unset;
                int startIdx = 0;
                int endIdx = profiles.Length;
                if (profiles[0].Geometry is Point p0) {
                    startPt = p0.Location;
                    startIdx = 1;
                }
                if (profiles[profiles.Length - 1].Geometry is Point pN) {
                    endPt = pN.Location;
                    endIdx = profiles.Length - 1;
                }
                Curve[] curves = profiles.Skip(startIdx).Take(endIdx - startIdx)
                    .Select(AsCurve).ToArray();
                LoftType loftType = ruled ? LoftType.Straight : LoftType.Normal;
                breps = Brep.CreateFromLoft(curves, startPt, endPt, loftType, closed);
            } else if (rails.Length == 1) {
                Curve[] curves = profiles.Select(AsCurve).ToArray();
                breps = Brep.CreateFromSweep(AsCurve(rails[0]), curves, closed, tol);
            } else {
                Curve[] curves = profiles.Select(AsCurve).ToArray();
                breps = Brep.CreateFromSweep(AsCurve(rails[0]), AsCurve(rails[1]), curves, closed, tol);
            }
            if (breps == null || breps.Length == 0) {
                throw new Exception("Loft failed");
            }
            if (breps.Length == 1) {
                return breps[0];
            }
            Brep[] joined = Brep.JoinBreps(breps, tol);
            if (joined != null && joined.Length > 0) {
                return joined[0];
            }
            return breps[0];
        }

        public bool DoBrepsIntersect(Brep brepA, Brep brepB, double tolerance) {
            Curve[] outCurves;
            Point3d[] outPoints;
            return Intersection.BrepBrep(brepA, brepB, tolerance, out outCurves, out outPoints) &&
                outCurves.All(curve => curve.IsClosed);
        }

        Point3d[] SampleCurve(Curve curve, int samples) {
            int count = Math.Max(2, samples);
            double[] parameters = curve.DivideByCount(count - 1, true);
            if (parameters == null || parameters.Length == 0) {
                return new[] { curve.PointAtStart, curve.PointAtEnd };
            }
            return parameters.Select(t => curve.PointAt(t)).ToArray();
        }

        Point3d[][] SampleCurves(IEnumerable<Curve> curves, int samples) {
            return curves
                .Where(curve => curve != null)
                .Select(curve => SampleCurve(curve, samples))
                .Where(points => points.Length >= 2)
                .ToArray();
        }

        public Point3d[] CurveCurveIntersectionPoints(RhinoObject obj0, RhinoObject obj1, double tolerance) {
            Curve curve0 = AsCurve(obj0);
            Curve curve1 = AsCurve(obj1);
            CurveIntersections events = Intersection.CurveCurve(curve0, curve1, tolerance, tolerance);
            return events
                .Where(e => e.IsPoint)
                .Select(e => e.PointA)
                .ToArray();
        }

        public Point3d[][] CurveCurveIntersectionPolylines(RhinoObject obj0, RhinoObject obj1, double tolerance, int samples) {
            Curve curve0 = AsCurve(obj0);
            Curve curve1 = AsCurve(obj1);
            CurveIntersections events = Intersection.CurveCurve(curve0, curve1, tolerance, tolerance);
            Curve[] overlaps = events
                .Where(e => e.IsOverlap)
                .Select(e => curve0.Trim(e.OverlapA))
                .Where(curve => curve != null)
                .ToArray();
            return SampleCurves(overlaps, samples);
        }

        public Point3d[] CurveBrepIntersectionPoints(RhinoObject curveObj, RhinoObject brepObj, double tolerance) {
            Curve curve = AsCurve(curveObj);
            Brep brep = AsBrep(brepObj);
            Curve[] overlapCurves;
            Point3d[] intersectionPoints;
            Intersection.CurveBrep(curve, brep, tolerance, out overlapCurves, out intersectionPoints);
            return intersectionPoints ?? new Point3d[] { };
        }

        public Point3d[][] CurveBrepIntersectionPolylines(RhinoObject curveObj, RhinoObject brepObj, double tolerance, int samples) {
            Curve curve = AsCurve(curveObj);
            Brep brep = AsBrep(brepObj);
            Curve[] overlapCurves;
            Point3d[] intersectionPoints;
            Intersection.CurveBrep(curve, brep, tolerance, out overlapCurves, out intersectionPoints);
            return SampleCurves(overlapCurves ?? new Curve[] { }, samples);
        }

        public Point3d[] BrepBrepIntersectionPoints(RhinoObject obj0, RhinoObject obj1, double tolerance) {
            Brep brep0 = AsBrep(obj0);
            Brep brep1 = AsBrep(obj1);
            Curve[] intersectionCurves;
            Point3d[] intersectionPoints;
            Intersection.BrepBrep(brep0, brep1, tolerance, out intersectionCurves, out intersectionPoints);
            return intersectionPoints ?? new Point3d[] { };
        }

        public Point3d[][] BrepBrepIntersectionPolylines(RhinoObject obj0, RhinoObject obj1, double tolerance, int samples) {
            Brep brep0 = AsBrep(obj0);
            Brep brep1 = AsBrep(obj1);
            Curve[] intersectionCurves;
            Point3d[] intersectionPoints;
            Intersection.BrepBrep(brep0, brep1, tolerance, out intersectionCurves, out intersectionPoints);
            return SampleCurves(intersectionCurves ?? new Curve[] { }, samples);
        }

        public Guid[] Unite(RhinoObject[]objs) {
            Brep[] breps = objs.Select(AsBrep).ToArray();
            Brep[] newBreps = null;
            for (int e = 5; e > 2; e--) {
                newBreps = Brep.CreateBooleanUnion(breps, Math.Pow(10, -e));
                if (newBreps != null && newBreps.Length > 0) {
                    break;
                }
            }
            if (newBreps == null || newBreps.Length == 0) {
                // Union failed, likely because breps don't intersect.
                // Return the originals unchanged.
                return objs.Select(obj => obj.Id).ToArray();
            }
            foreach(RhinoObject obj in objs) {
                doc.Objects.Delete(obj, true);
            }
            Guid[] result = newBreps
                .Where(brep => brep != null)
                .Select(brep => doc.Objects.AddBrep(brep))
                .Where(id => id != Guid.Empty)
                .ToArray();
            if (result.Length == 0) {
                throw new Exception("Union failed: could not add result to document");
            }
            return result;
        }

        public Guid[] Intersect(RhinoObject obj0, RhinoObject obj1) {
            Brep brep0 = AsBrep(obj0);
            Brep brep1 = AsBrep(obj1);
            Brep[] newBreps = null;
            for (int e = 5; e > 2; e--) {
                newBreps = Brep.CreateBooleanIntersection(brep0, brep1, Math.Pow(10, -e));
                if (newBreps != null) {
                    break;
                }
            }
            if (newBreps == null) {
                throw new Exception("Intersect failed");
            }
            if (newBreps.Length > 0) {
                doc.Objects.Delete(obj0, true);
                doc.Objects.Delete(obj1, true);
                return newBreps
                    .Where(brep => brep != null)
                    .Select(brep => doc.Objects.AddBrep(brep))
                    .Where(id => id != Guid.Empty)
                    .ToArray();
            }
            Point3d c1 = brep1.Vertices[0].Location;
            if (brep0.IsPointInside(c1, doc.ModelAbsoluteTolerance, false)) {
                doc.Objects.Delete(obj0, true);
                return new[] { obj1.Id };
            } else {
                Point3d c0 = brep0.Vertices[0].Location;
                if (brep1.IsPointInside(c0, doc.ModelAbsoluteTolerance, false)) {
                    doc.Objects.Delete(obj1, true);
                    return new[] { obj0.Id };
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
            // Try the boolean across a wider tolerance range than before
            // (was 1e-5 .. 1e-3). Tangent or near-coincident operands often
            // resolve only at looser tolerances, while pathological floating-
            // point boundaries occasionally need tighter ones. If the
            // single-Brep overload returns null at every tolerance, fall back
            // to the multi-Brep overload (Brep[] in, Brep[] in) — RhinoCommon
            // dispatches them to slightly different internal paths and the
            // multi-version sometimes succeeds where the single version fails
            // (e.g. when the operand has near-coplanar faces with the result).
            Brep[] newBreps = null;
            for (int e = 7; e > 1; e--) {
                newBreps = Brep.CreateBooleanDifference(brep0, brep1, Math.Pow(10, -e));
                if (newBreps != null) {
                    break;
                }
            }
            if (newBreps == null) {
                Brep[] arr0 = new[] { brep0 };
                Brep[] arr1 = new[] { brep1 };
                for (int e = 7; e > 1; e--) {
                    newBreps = Brep.CreateBooleanDifference(arr0, arr1, Math.Pow(10, -e));
                    if (newBreps != null) {
                        break;
                    }
                }
            }
            if (newBreps == null) {
                throw new Exception("Subtract failed");
            }
            if (newBreps.Length > 0) {
                doc.Objects.Delete(obj0, true);
                doc.Objects.Delete(obj1, true);
                return newBreps
                    .Where(brep => brep != null)
                    .Select(brep => doc.Objects.AddBrep(brep))
                    .Where(id => id != Guid.Empty)
                    .ToArray();
            }
            // newBreps.Length == 0: the boolean engine returned successfully
            // with no solids. Three sub-cases distinguished by point-in-Brep
            // tests:
            Point3d c1 = brep1.Vertices[0].Location;
            if (brep0.IsPointInside(c1, doc.ModelAbsoluteTolerance, false)) {
                // brep1 is fully inside brep0 — the subtraction is well-
                // defined as a hollow brep0 (outer shell + inner cavity), but
                // CreateBooleanDifference doesn't always produce that. The
                // earlier code threw "Subtract failed" here unconditionally.
                // Construct the hollow manually: flip the inner Brep so its
                // surface normals point into the cavity, then JoinBreps to
                // assemble a single multi-shell Brep with the original outer
                // and the inverted inner.
                Brep flipped = brep1.DuplicateBrep();
                flipped.Flip();
                Brep[] hollow = Brep.CreateSolid(new[] { brep0.DuplicateBrep(), flipped },
                                                 doc.ModelAbsoluteTolerance);
                if (hollow != null && hollow.Length > 0) {
                    doc.Objects.Delete(obj0, true);
                    doc.Objects.Delete(obj1, true);
                    return hollow
                        .Where(brep => brep != null)
                        .Select(brep => doc.Objects.AddBrep(brep))
                        .Where(id => id != Guid.Empty)
                        .ToArray();
                }
                throw new Exception("Subtract failed");
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
        public Guid[] Slice(RhinoObject obj, Point3d p, Vector3d n) {
            Brep brep = AsBrep(obj);
            Plane plane = new Plane(p, n);
            double tol = RhinoDoc.ActiveDoc.ModelAbsoluteTolerance;
            Brep[] newBreps = brep.Trim(plane, tol);
            doc.Objects.Delete(obj, true);
            return newBreps.Select(br => doc.Objects.AddBrep(br.CapPlanarHoles(tol))).ToArray();
        }
        /*
         * 
         * 
         def Pl(p):
    t = p.world_transformation
    pl = geo.Plane(geo.Point3d(t[3,0], t[3,1], t[3,2]), 
                   geo.Vector3d(t[0,0], t[0,1], t[0,2]),
                   geo.Vector3d(t[1,0], t[1,1], t[1,2]))
    return pl

def fromPlane(pl):
    return u0(cs_from_o_vx_vy_vz(fromPt(pl.Origin),
                                 fromVt(pl.XAxis),
                                 fromVt(pl.YAxis),
                                 fromVt(pl.ZAxis)))

def _surface_from_curves(curves):
    return db.AddBrep(singleton(geo.Brep.CreatePlanarBreps(curves)))

def _geometry_from_id(id):
    return db.Find(id).Geometry

def _surface_from_id(id):
    curve = _geometry_from_id(id)
    r = db.AddBrep(singleton(geo.Brep.CreatePlanarBreps([curve])))
    return r

def _brep_from_id(id):
    geom = _geometry_from_id(id)
    if isinstance(geom, geo.Brep): return geom
    if isinstance(geom, geo.Extrusion): return geom.ToBrep(True)
    raise ValueError("unable to convert %s into Brep geometry"%id)

def _point_in_surface(id):
    v = rh.BrepClosestPoint(id, rawu0)
    if v:
        return fromPt(v[0])
    else:
        u, v = rh.SurfaceDomain(id, 0), rh.SurfaceDomain(id, 1)
        return rh.EvaluateSurface(id, u[0], v[0])

def is_point_in_surface(id, p):
    return rh.IsPointInSurface(id, Pt(p))

def is_point_on_surface(id, p):
    return rh.IsPointOnSurface(id, Pt(p))

def is_point_on(r, c):
    try:
        return is_point_in_surface(r, c)
    except:
        return is_point_on_surface(r, c)


    def delete(self):
# Perhaps optimize this in case the shape was not yet realized
        self.realize().do(lambda r: self.destroy(r))

    def destroy(self, guid):
        db.Delete(guid, True)
    
    def copy_ref(self, guid):
        return rh.CopyObject(guid)

    def intersect_ref(self, r0, r1):
        brep0 = _brep_from_id(r0)
        brep1 = _brep_from_id(r1)
        for e in range(5,2,-1):
            tol = pow(10,-e)
            newbreps = geo.Brep.CreateBooleanIntersection([brep0], [brep1], tol)
            if newbreps:
                db.Delete(r0, True)
                db.Delete(r1, True)
                return single_ref_or_union([db.AddBrep(brep) for brep in newbreps])
        c1 = _point_in_surface(r1)
        if is_point_on(r0, c1):
            db.Delete(r0, True)
            return native_ref(r1)
        else:
            c0 = _point_in_surface(r0)
            if is_point_on(r1, c0):
                db.Delete(r1, True)
                return native_ref(r0)
            else:
                db.Delete(r0, True)
                db.Delete(r1, True)
                return empty_ref()

    def subtract_ref(self, r0, r1):
        brep0 = _brep_from_id(r0)
        brep1 = _brep_from_id(r1)
        for e in range(5,2,-1):
            tol = pow(10,-e)
            newbreps = geo.Brep.CreateBooleanDifference([brep0], [brep1], tol)
            if newbreps:
                db.Delete(r0, True)
                db.Delete(r1, True)
                return single_ref_or_union([db.AddBrep(brep) for brep in newbreps])
        c1 = _point_in_surface(r1)
        if is_point_on(r0, c1):
            return subtraction_ref([native_ref(r0), native_ref(r1)])
        else:
            c0 = _point_in_surface(r0)
            if is_point_on(r1, c0):
                db.Delete(r0, True)
                db.Delete(r1, True)
                return empty_ref()
            else:
                db.Delete(r1, True)
                return native_ref(r0)

    def slice_ref(self, r, p, n):
        cutter = rh.AddCutPlane([r], Pt(p), Pt(p + vx(1, p.cs)), Pt(vy(1, p.cs)))
        rs = rh.SplitBrep(r, cutter, True)
        rs = rs or [r]
        for e in rs:
            rh.CapPlanarHoles(e)
        keep, clear = partition(rs, lambda r: (fromPt(rh.SurfaceVolumeCentroid(r)[0]) - p).dot(n) < 0)
        rh.DeleteObjects(clear)
        rh.DeleteObject(cutter)
        if keep == []:
            return empty_ref()
        else:
            return single_ref_or_union(keep)

@shape_constructor(closed_curve)
def ellipse(center=u0(), radius_x=1, radius_y=1):
    return db.AddEllipse(geo.Ellipse(Pl(center), radius_x, radius_y))

@shape_constructor(surface)
def surface_ellipse(center=u0(), radius_x=1, radius_y=1):
    return _surface_from_curves([geo.Ellipse(Pl(center), radius_x, radius_y).ToNurbsCurve()])

@shape_constructor(curve)
def line(*vertices):
    vs = unvarargs(vertices)
    return db.AddPolyline(geo.Polyline([Pt(v) for v in vs]))

@shape_constructor(curve)
def spline(*positions):
    ps = unvarargs(positions)
    return rh.AddInterpCurve([Pt(p) for p in ps], 3, 1)

@shape_constructor(spline)
def spline_tangents(positions, start_tangent, end_tangent):
    return rh.AddInterpCurve([Pt(p) for p in positions], 3, 1, 
                             Vt(start_tangent),
                             Vt(end_tangent))

@shape_constructor(closed_curve)
def closed_spline(*positions):
    ps = unvarargs(positions)
    return rh.AddInterpCurve([Pt(p) for p in ps]+[Pt(ps[0])], 3, 4)
    

@shape_constructor(closed_curve)
def rectangle(corner=u0(), dx=1, dy=None):
    dy = dy or dx
    dz = 0
    c = corner
    if isinstance(dx, xyz):
        v = loc_in_cs(dx, c.cs) - c
        dx, dy, dz = v.coords
    assert dz == 0, "The rectangle is not planar"
    return db.AddPolyline([Pt(c), 
                           Pt(add_x(c, dx)),
                           Pt(add_xy(c, dx, dy)),
                           Pt(add_y(c, dy)),
                           Pt(c)])
        
@shape_constructor(surface)
def surface_rectangle(corner=u0(), dx=1, dy=None):
    r = rectangle(corner, dx, dy)
    s = rh.AddPlanarSrf(r.realize()._ref)
    r.delete()
    return s
    
@shape_constructor(closed_curve)
def polygon(*vertices):
    vs = unvarargs(vertices)
    return db.AddPolyline(geo.Polyline([Pt(v) for v in vs]+[Pt(vs[0])]))
    
@shape_constructor(surface)
def surface_polygon(*vertices):
    vs = unvarargs(vertices)
    return _surface_from_curves([geo.Polyline([Pt(v) for v in vs]+[Pt(vs[0])]).ToNurbsCurve()])
    
@shape_constructor(polygon)
def regular_polygon(edges=3, center=u0(), radius=1, angle=0, inscribed=False):
    pts = map(Pt, regular_polygon_vertices(edges, center, radius, angle, inscribed))
    return rh.AddPolyline(pts + [pts[0]])

@shape_constructor(surface_polygon)
def surface_regular_polygon(edges=3, center=u0(), radius=1, angle=0, inscribed=False):
    pts = map(Pt, regular_polygon_vertices(edges, center, radius, angle, inscribed))
    border = rh.AddPolyline(pts + [pts[0]])
    srf = rh.AddPlanarSrf([border])
    db.Delete(border, True)
    return srf

@shape_constructor(surface)
def surface_from(*curves):
    cs = unvarargs(curves)
    refs = shapes_refs(cs)
    if is_singleton(refs):
        ref = refs[0]
        if isinstance(ref, geo.Point):
            id = ref
        else:
            ids = rh.AddPlanarSrf(refs)
            if ids:
                id = singleton(ids)
            else:
                id = rh.AddPatch(refs, 3, 3)
    elif len(refs) < 0: #Temporary fix for Funda's problem# 5:
        id = rh.AddEdgeSrf(refs)
    else:
        id = rh.AddPlanarSrf(refs)
    delete_shapes(cs)
    return id

@shape_constructor(solid)
def box(corner=u0(), dx=1, dy=None, dz=None):
    dy = dy or dx
    dz = dz or dy
    c = corner
    if isinstance(dx, xyz):
        v = loc_in_cs(dx, c.cs) - c
        dx, dy, dz = v.coords
    return rh.AddBox(map(Pt, 
                         [c,
                          add_x(c, dx),
                          add_xy(c, dx, dy),
                          add_y(c, dy),
                          add_z(c, dz),
                          add_xz(c, dx, dz),
                          add_xyz(c, dx, dy, dz),
                          add_yz(c, dy, dz)]))

@shape_constructor(solid)
def cuboid(b0=None, b1=None, b2=None, b3=None, t0=None, t1=None, t2=None, t3=None):
    b0 = b0 or u0()
    b1 = b1 or add_x(b0, 1)
    b2 = b2 or add_y(b1, 1)
    b3 = b3 or add_y(b0, 1)
    t0 = t0 or add_z(b0, 1)
    t1 = t1 or add_x(t0, 1)
    t2 = t2 or add_y(t1, 1)
    t3 = t3 or add_y(t0, 1)
    return rh.AddBox(map(Pt, [b0, b1, b2, b3, t0, t1, t2, t3]))

@shape_constructor(solid)
def cone_frustum(base=u0(), base_radius=1, height=1, top_radius=1, top=None):
    base, height = base_and_height(base, top or height)
    top = top or add_z(base, height)
    bottomCircle = geo.Circle(Pl(base), base_radius)
    topCircle = geo.Circle(Pl(top), top_radius)
    shapeCurve = geo.LineCurve(bottomCircle.PointAt(0), topCircle.PointAt(0))
    axis = geo.Line(bottomCircle.Center, topCircle.Center)
    revsrf = geo.RevSurface.Create(shapeCurve, axis)
    return db.AddBrep(geo.Brep.CreateFromRevSurface(revsrf, True, True))

def _irregular_pyramid(pts0, pt1):
    pts0, pt1 = map(Pt, pts0), Pt(pt1)
    id = rh.JoinSurfaces([rh.AddSrfPt((pt00, pt01, pt1)) 
                          for pt00, pt01 in zip(pts0, pts0[1:] + [pts0[0]])])
    rh.CapPlanarHoles(id)
    return id

def _irregular_pyramid_frustum(pts0, pts1):
    pts0, pts1 = map(Pt, pts0), map(Pt, pts1)
    id = rh.JoinSurfaces([rh.AddSrfPt((pt00, pt01, pt11, pt10))
                          for pt00, pt01, pt10, pt11
                          in zip(pts0, pts0[1:] + [pts0[0]], pts1, pts1[1:] + [pts1[0]])])
    rh.CapPlanarHoles(id)
    return id

@shape_constructor(solid)
def regular_pyramid_frustum(edges=4, base=u0(), base_radius=1, angle=0, height=1, top_radius=1, inscribed=False, top=None):
    base, height = base_and_height(base, top or height)
    top = top or add_z(base, height)
    return _irregular_pyramid_frustum(
        regular_polygon_vertices(edges, base, base_radius, angle, inscribed),
        regular_polygon_vertices(edges, top, top_radius, angle, inscribed))
    
@shape_constructor(solid)
def regular_pyramid(edges=4, base=u0(), radius=1, angle=0, height=1, inscribed=False, top=None):
    base, height = base_and_height(base, top or height)
    top = top or add_z(base, height)
    return _irregular_pyramid(
        regular_polygon_vertices(edges, base, radius, angle, inscribed),
        top)

@shape_constructor(solid)
def regular_prism(edges=4, base=u0(), radius=1, angle=0, height=1, inscribed=False, top=None):
    base, height = base_and_height(base, top or height)
    top = top or add_z(base, height)
    return _irregular_pyramid_frustum(
        regular_polygon_vertices(edges, base, radius, angle, inscribed),
        regular_polygon_vertices(edges, top, radius, angle, inscribed))

@shape_constructor(solid)
def irregular_prism(base_vertices=None, direction=1):
    base_vertices = base_vertices or [ux(), uy(), uxy()]
    dir = vz(direction, base_vertices[0].cs) if is_number(direction) else direction
    return _irregular_pyramid_frustum(cbs, map((lambda p: p + dir), cbs))
    
@shape_constructor(solid)
def irregular_pyramid(base_vertices=None, top=None):
    base_vertices = base_vertices or [ux(), uy(), uxy()]
    top = top or uz()
    return _irregular_pyramid(base_vertices, top)

@shape_constructor(solid)
def right_cuboid(base=u0(), width=1, height=1, length=1, top=None):
    base, dz = base_and_height(base, top or length)
    c, dx, dy = add_xy(base, width/-2, height/-2), width, height
    return rh.AddBox(map(Pt, [c,
                              add_x(c, dx),
                              add_xy(c, dx, dy),
                              add_y(c, dy),
                              add_z(c, dz),
                              add_xz(c, dx, dz),
                              add_xyz(c, dx, dy, dz),
                              add_yz(c, dy, dz)]))

@shape_constructor(shape)
def torus(center=u0(), major_radius=1, minor_radius=1/2):
    return rh.AddTorus(Pl(center), major_radius, minor_radius)

@shape_constructor(shape)
def union(*shapes):
    shapes = filter(lambda s: not is_empty_shape(s),
                    unvarargs(shapes))
    if len(shapes) == 0:
        return empty_ref()
    elif len(shapes) == 1:
        return shapes[0].realize()
    elif any(is_universal_shape(s) for s in shapes):
        return universal_ref()
    else:
        rs = [s.realize() for s in shapes]
        for r in rs:
            assert isinstance(r,(native_ref, multiple_ref)), "BRONCA"
        unions, rs = partition(rs, is_union_ref)
        subtractions, rs = partition(rs, is_subtraction_ref)
        united = rs + [r0 for union in unions for r0 in union._refs] #Avoid this direct reference
        return native_ref_or_union(united + subtractions)

@shape_constructor(solid)
def slice(shape, p=u0(), n=None):
    n = n or vz(1, p.cs)
    p = loc_from_o_vz(p, n)
    res = shape.realize().slice(p, n, shape)
    shape.mark_deleted()
    return res

@shape_constructor(shape)
def extrusion(profile, dir=1):
    dir = dir if isinstance(dir, vxyz) else vz(dir)
    vec = Vt(dir)
    def extrude(r):
        if rh.IsCurve(r):
            return db.AddSurface(geo.Surface.CreateExtrusion(db.Find(r).Geometry, vec))
        else:
            c = rh.SurfaceAreaCentroid(r)[0]
            curve = rh.AddLine(c, c + vec)
            brep = _brep_from_id(r)
            c = db.Find(curve).Geometry
            r = single_ref_or_union([db.AddBrep(face.CreateExtrusion(c, True))
                                     for face in brep.Faces])
            rh.DeleteObject(curve)
            return r
    return and_delete(profile.realize().map(extrude), profile)

def revolve_border(border, axis, start, end):
    res = rh.AddRevSrf(border, axis, start, end)
    rh.CapPlanarHoles(res)
    rh.DeleteObject(border)
    return res

def revolve_borders(profile, axis, start, end, out):
    return [revolve_border(border, axis, start, end)
            for border in rh.DuplicateSurfaceBorder(profile, 1 if out else 2)]

@shape_constructor(shape)
def revolve(shape, c=u0(), v=vz(1), start_angle=0, amplitude=2*pi):
    if isinstance(v, loc): #HACK Should we keep this?
        v = v - c
    axis = [Pt(c), Pt(c + v)]
    start = degrees(start_angle)
    end = degrees(start_angle + amplitude)
    def revol(r):
        if rh.IsCurve(r):
            return native_ref(rh.AddRevSrf(r, axis, start, end))
        elif rh.IsSurface(r) or rh.IsPolysurface(r):
            out_refs = revolve_borders(r, axis, start, end, True)
            in_refs = revolve_borders(r, axis, start, end, False)
            return subtract_refs(single_ref_or_union(out_refs),
                                 [native_ref(r) for r in in_refs],
                                 shape)
        else:
            raise RuntimeError("Can't revolve the shape")
    return and_delete(shape.realize().map(revol), shape)

@shape_constructor(curve)
def surface_boundary(surface):
    return and_delete(surface.realize().map(
        lambda r: single_ref_or_subtraction(rh.DuplicateSurfaceBorder(r))),
                      surface)

# This is not correct. Must fix this ref mess
def adequate_ref(arg):
    if isinstance(arg, (native_ref, multiple_ref)):
        return arg
    elif isinstance(arg, (tuple, list)):
        return single_ref_or_union(arg)
    else:
        return native_ref(arg)

def loft_curve_point(curve, point):
    p = rh.PointCoordinates(point.realize()._ref)
    curve_ref = curve.realize()
    return and_delete(adequate_ref(curve_ref.map(lambda c: rh.ExtrudeCurvePoint(c, p))),
                      curve,
                      point)

def loft_surface_point(surface, point):
    boundary = surface_boundary(surface)
    rs = loft_curve_point(boundary, point)
    rs.do(rh.CapPlanarHoles)
    return adequate_ref(rs)

def loft_profiles_aux(profiles, rails, is_ruled, is_closed):
    profiles_refs = list([profile.realize()._ref
                          for profile in profiles])
    rails_refs = list([rail.realize()._ref
                       for rail in rails])
    if len(rails_refs) == 0:
        return singleton(rh.AddLoftSrf(profiles_refs, None, None, 
                          2 if is_ruled else 0, 0, 0, is_closed))
    elif len(rails_refs) == 1:
        return singleton(rh.AddSweep1(rails_refs[0], profiles_refs))
    elif len(rails_refs) == 2:
        return singleton(rh.AddSweep2(rails_refs, profiles_refs))
    elif len(rails_refs) > 2:
        print('Warning: Rhino only supports two rails but were passed {0}'.format(len(rails)))
        return singleton(rh.AddSweep2(rails_refs[:2], profiles_refs))
    else: #Remove?
        raise RuntimeError('Rhino only supports two rails but were passed {0}'.format(len(rails)))

def loft_profiles(profiles, rails, is_solid, is_ruled, is_closed):
    r = loft_profiles_aux(profiles, rails, is_ruled, is_closed)
    if is_solid:
        rh.CapPlanarHoles(r)
    return and_delete(r, *(profiles + rails))

def loft_curves(profiles, rails, is_ruled=False, is_closed=False):
    return loft_profiles(profiles, rails, False, is_ruled, is_closed)

def loft_surfaces(profiles, rails, is_ruled=False, is_closed=False):
    return loft_profiles(map(surface_boundary, profiles), rails, True, is_ruled, is_closed)

@shape_constructor(shape)
def lofted(profiles, rails=[], is_ruled=False, is_closed=False):
    if all(map(is_curve, profiles)):
        return loft_curves(profiles, rails, is_ruled, is_closed)
    elif all(map(is_surface, profiles)):
        return loft_surfaces(profiles, rails, is_ruled, is_closed)
    elif len(profiles) == 2:
        assert(rails == [])
        p, s = profiles[0], profiles[1]
        if is_point(p):
            pass
        elif is_point(s):
            p, s = s, p
        else:
            raise RuntimeError("{0}: cross sections are not either points or curves or surfaces {1}".format('loft_shapes', profiles))
        if is_curve(s):
            return loft_curve_point(s, p)
        elif is_surface(s):
            return loft_surface_point(s, p)
        else:
            raise RuntimeError("{0}: can't loft the shapes {1}".format('loft_shapes', profiles))
    else:
        raise RuntimeError("{0}: cross sections are neither points nor curves nor surfaces  {1}".format('loft_shapes', profiles))

def loft(profiles, rails=[], is_ruled=False, is_closed=False):
    if len(profiles) == 1:
        raise RuntimeError(quote(loft), 'just one cross section')
    elif all(map(is_point, profiles)):
        assert(rails == [])
        func = ((polygon if is_closed else line) 
                if is_ruled 
                else (closed_spline if is_closed else spline))
        polygon if is_closed else line if is_ruled else closed_spline if is_closed else spline
        return and_delete(func([p.position for p in profiles]),
                          *profiles)
    else:
        return lofted(profiles, rails, is_ruled, is_closed)

def loft_ruled(profiles):
    return loft(profiles, [], True)

def union_mirror(shape, plane_position=u0(), plane_normal=vz()):
    return union(shape, mirror(shape, plane_position, plane_normal, True))


@shape_constructor(surface)
def surface_mesh(trigs, pts=None):
    if pts == None:
        return rh.JoinSurfaces([rh.AddSrfPt((Pt(trig[0]), Pt(trig[1]), Pt(trig[2]))) 
                                for trig in trigs], True)
    else:
        return rh.JoinSurfaces([rh.AddSrfPt((Pt(pts[trig[0]]), Pt(pts[trig[1]]), Pt(pts[trig[2]]))) 
                                for trig in trigs], True)

@shape_constructor(solid)
def thicken(surf, h=1):
    s = rh.OffsetSurface(surf.realize()._ref, h, None, True, True)
    if not s:
        rh.UnselectAllObjects()
        rh.SelectObjects(surf.refs())
        rh.Command("OffsetSrf BothSides=Yes Solid=Yes {0} _Enter".format(h))
        s = single_ref_or_union(rh.LastCreatedObjects())
    surf.delete()
    return s



def map_surface_division(f, surface, nu, nv, include_last_u=True, include_last_v=True):
    id = surface.realize()._ref
    domain_u = rh.SurfaceDomain(id, 0)
    domain_v = rh.SurfaceDomain(id, 1)
    start_u = domain_u[0]
    end_u = domain_u[1]
    start_v = domain_v[0]
    end_v = domain_v[1]
    def surf_f(u, v):
        plane = rh.SurfaceFrame(id, (u, v))
        if rh.IsPointOnSurface(id, plane.Origin):
            return f(fromPlane(plane))
        else:
            return False
    return map_division(surf_f,
                        start_u, end_u, nu, include_last_u,
                        start_v, end_v, nv, include_last_v)


def random_integer_range(*args):
    return random_range(*args)

def prompt_point(str="Select point"):
    return rh.GetPoint(str)

def prompt_integer(str="Integer?"):
    return rh.GetInteger(str)

def prompt_real(str="Real?"):
    return rh.GetReal(str)

def get_shape_named(name):
    return shape_from_ref(rh.ObjectsByName(name, False, False, False)[0])

def shape_color(sh, color=None):
    if color:
        color = rhino_rgb_from_rgb(color)
        sh.realize().do(lambda r: rh.ObjectColor(r, color))
        return sh
    else:
        return rh.ObjectColor(sh.ref())

def shape_from_ref(r):
    with parameter(immediate_mode, False):
        obj = _geometry_from_id(r)
        ref = native_ref(r)
        if isinstance(obj, geo.Point):
            return point.new_ref(ref, fromPt(obj.Location))
        elif isinstance(obj, geo.Curve):
            if rh.IsLine(r) or rh.IsPolyline(r):
                if rh.IsCurveClosed(r):
                    return polygon.new_ref(ref, [fromPt(p) for p in rh.CurvePoints(r)[:-1]])
                else:
                    return line.new_ref(ref, [fromPt(p) for p in rh.CurvePoints(r)])
            elif obj.IsCircle(Rhino.RhinoMath.ZeroTolerance):
                return circle.new_ref(ref, fromPt(rh.CircleCenterPoint(r)), rh.CircleRadius(r))
            elif rh.IsCurveClosed(r):
                return closed_spline.new_ref(ref, [fromPt(p) for p in rh.CurvePoints(r)])
            else:
                return spline.new_ref(ref, [fromPt(p) for p in rh.CurvePoints(r)])
        elif rh.IsObject(r) and rh.IsObjectSolid(r):
            return solid(native_ref(r))
        elif rh.IsSurface(r) or rh.IsPolysurface(r):
            return surface(native_ref(r))
        else:
            raise RuntimeError("{0}: Unknown Rhino object {1}".format('shape_from_ref', r))

def brep_subbreps(object_id):
    brep = _brep_from_id(object_id)
    ids = []
    for face in brep.Faces:
        newbrep = face.DuplicateFace(True)
        id = scriptcontext.doc.Objects.AddBrep(newbrep)
        ids.append(id)
    return ids

def shape_surfaces(shape):
    ref = shape.realize()
    return ref.map(lambda r: map(shape_from_ref, brep_subbreps(r)))

def shape_edges(shape):
    ref = shape.realize()
    return ref.map(lambda r: map(shape_from_ref, rh.DuplicateEdgeCurves(r)))

def shape_vertices(shape):
    pts = []
    for edge in shape_edges(shape):
        r = edge.ref()
        pt = rh.CurveStartPoint(r)
        if pt not in pts:
            pts.append(pt)
        pt = rh.CurveEndPoint(r)
        if pt not in pts:
            pts.append(pt)
    return map(fromPt, pts)

def show_vertices(shape):
    map(lambda p: sphere(p, 0.05), shape_vertices(shape))

        */

        Brep RevolveCurve(Curve curve, Line axis, double startAngle, double endAngle) {
            RevSurface revSrf = RevSurface.Create(curve, axis, startAngle, endAngle);
            if (revSrf == null) {
                throw new Exception("Revolve failed");
            }
            Brep brep = Brep.CreateFromRevSurface(revSrf, false, false);
            brep = brep.CapPlanarHoles(doc.ModelAbsoluteTolerance) ?? brep;
            return brep;
        }

        public Brep Revolve(RhinoObject profile, Point3d p, Vector3d n, double startAngle, double amplitude) {
            double endAngle = startAngle + amplitude;
            Line axis = new Line(p, p + n);
            if (profile.Geometry is Curve curve) {
                return RevolveCurve(curve, axis, startAngle, endAngle);
            }
            Brep brep = AsBrep(profile);
            Curve[] outerBorders = Curve.JoinCurves(brep.DuplicateNakedEdgeCurves(true, false));
            Brep[] outerSolids = outerBorders.Select(border => RevolveCurve(border, axis, startAngle, endAngle)).ToArray();
            Curve[] innerBorders = Curve.JoinCurves(brep.DuplicateNakedEdgeCurves(false, true));
            if (innerBorders.Length == 0) {
                if (outerSolids.Length == 1) {
                    return outerSolids[0];
                }
                return SingletonElement(Brep.JoinBreps(outerSolids, doc.ModelAbsoluteTolerance));
            }
            Brep[] innerSolids = innerBorders.Select(border => RevolveCurve(border, axis, startAngle, endAngle)).ToArray();
            Brep[] result = TryBooleanDifference(outerSolids, innerSolids);
            if (result == null) {
                throw new Exception("Revolve subtraction failed");
            }
            return result[0];
        }

        public Guid Move(Guid id, Vector3d v) => doc.Objects.Transform(id, Transform.Translation(v), true);
        public Guid Scale(Guid id, Point3d p, double s) => doc.Objects.Transform(id, Transform.Scale(p, s), true);
        public Guid Rotate(Guid id, Point3d p, Vector3d n, double a) => doc.Objects.Transform(id, Transform.Rotation(a, n, p), true);
        public Guid Mirror(Guid id, Point3d p, Vector3d n, bool copy) => doc.Objects.Transform(id, Transform.Mirror(p, n), copy);
        public Guid Clone(RhinoObject e) => doc.Objects.Add(e.DuplicateGeometry());

        public Guid ImportOBJ(string path, Point3d origin, Vector3d vx, Vector3d vy, Vector3d vz) {
            // Record existing objects
            var before = new HashSet<Guid>(doc.Objects.GetObjectList(ObjectType.AnyObject).Select(o => o.Id));
            // Import OBJ file via Rhino command (handles OBJ+MTL)
            string escapedPath = path.Replace("\"", "\\\"");
            RhinoApp.RunScript($"_-Import \"{escapedPath}\" _Enter", true);
            // Find newly imported objects
            var after = doc.Objects.GetObjectList(ObjectType.AnyObject);
            var newIds = after.Where(o => !before.Contains(o.Id)).Select(o => o.Id).ToList();
            if (newIds.Count == 0) {
                return Guid.Empty;
            }
            // Build 4x4 transform from origin + basis vectors
            Transform xform = Transform.Identity;
            xform[0, 0] = vx.X; xform[0, 1] = vy.X; xform[0, 2] = vz.X; xform[0, 3] = origin.X;
            xform[1, 0] = vx.Y; xform[1, 1] = vy.Y; xform[1, 2] = vz.Y; xform[1, 3] = origin.Y;
            xform[2, 0] = vx.Z; xform[2, 1] = vy.Z; xform[2, 2] = vz.Z; xform[2, 3] = origin.Z;
            xform[3, 0] = 0;    xform[3, 1] = 0;    xform[3, 2] = 0;    xform[3, 3] = 1;
            // Apply transform to all imported objects
            foreach (var id in newIds) {
                doc.Objects.Transform(id, xform, false);
            }
            // If multiple objects were imported, join meshes into one
            if (newIds.Count == 1) {
                return newIds[0];
            }
            // Group all imported objects and return the first one's id
            int groupIndex = doc.Groups.Add();
            foreach (var id in newIds) {
                doc.Groups.AddToGroup(groupIndex, id);
            }
            return newIds[0];
        }

        public Point3d[] GetPosition(string prompt) {
            Result res = RhinoGet.GetPoint(prompt, false, out Point3d location);
            if (res == Result.Success) {
                return new Point3d[] { location };
            } else {
                return new Point3d[] { };
            }
        }

        public Guid[] GetShapeOfType(string prompt, ObjectType filter) {
            Result rc = RhinoGet.GetOneObject(prompt, false, filter, out ObjRef objref);
            if (rc == Result.Success) {
                return new Guid[] { objref.ObjectId };
            } else {
                return new Guid[] { };
            }
        }

        public Guid[] GetShapesOfType(string prompt, ObjectType filter) {
            Result rc = RhinoGet.GetMultipleObjects(prompt, false, filter, out ObjRef[] objrefs);
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

        public Guid[] GetSolid(string prompt) => GetShapeOfType(prompt, ObjectType.Brep);
        public Guid[] GetSolids(string prompt) => GetShapesOfType(prompt, ObjectType.Brep);

        public Guid[] GetShape(string prompt) => GetShapeOfType(prompt, ObjectType.AnyObject);
        public Guid[] GetShapes(string prompt) => GetShapesOfType(prompt, ObjectType.AnyObject);

        public Guid[] GetAllShapes() => doc.Objects.GetObjectList(ObjectType.AnyObject).Select(o=>o.Id).ToArray();
        public Guid[] GetAllShapesInLayer(Guid id) => doc.Objects.FindByLayer(doc.Layers[doc.Layers.Find(id, true, -1)]).Select(o => o.Id).ToArray();

        public bool IsPoint(RhinoObject e) => e.Geometry is Point;
        public bool IsCircle(RhinoObject e) => (e.Geometry as Curve)?.IsCircle() ?? false;
        public bool IsPolyLine(RhinoObject e) => (e.Geometry as Curve)?.IsPolyline() ?? false;
        public bool IsSpline(RhinoObject e) => (e.Geometry is Curve);
        public bool IsClosedPolyLine(RhinoObject e) => ((e.Geometry as Curve)?.IsPolyline() ?? false) && ((e.Geometry as Curve)?.IsClosed ?? false);
        public bool IsClosedSpline(RhinoObject e) => IsSpline(e) && (e.Geometry as Curve).IsClosed;
        public bool IsEllipse(RhinoObject e) => (e.Geometry as Curve)?.IsEllipse() ?? false;
        public bool IsArc(RhinoObject e) => (e.Geometry as Curve)?.IsArc() ?? false;
        public bool IsText(RhinoObject e) => e is TextObject;

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
                    if (c is LineCurve) {
                        return 3;
                    } else if (c is Rhino.Geometry.NurbsCurve) {
                        return (byte)(7 + (c.IsClosed ? 100 : 0));
                    } else {
                        return (byte)(4 + (c.IsClosed ? 100 : 0));
                    }
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
                if (s.IsSolid) {
                    Surface f = s.Faces[0];
                    if (s.Faces.Count == 1) {
                        return (byte)(
                            f.IsSphere() ? 81 :
                            f.IsTorus() ? 84 :
                            80);
                    } else if (s.Faces.Count == 2) {
                        return (byte)(
                            f.IsCone() ? 83 :
                            80);
                    } else if (s.Faces.Count == 3) {
                        return (byte)(
                            f.IsCylinder() ? 82 :
                            80);
                    } else {
                        return 0;
                    }
                } else {
                    return 0;
                }
            }
            if (geo is Surface) {
                Surface s = geo as Surface;
                if (s.IsSolid) {
                    return (byte)(80);
                } else {
                    return (byte)(s.IsPlanar() ? 41 : 40);
                }
            } else {
                return 0;
            }
        }

        public Point3d[] BoundingBox(RhinoObject[] objs) {
            var bb = new BoundingBox();
            foreach (var obj in objs) {
               bb.Union(obj.Geometry.GetBoundingBox(true));
            }
            return new Point3d[] { bb.Min, bb.Max };
        }
        public void ZoomExtents() {
            RhinoView view = doc.Views.ActiveView;
            view.ActiveViewport.ZoomExtents();
            view.Redraw();
        }

        public Guid CreateLayer(String name, bool visible, Color color) {
            int idx = doc.Layers.FindByFullPath(name, -1);
            if (idx == -1) { // Not found
                idx = doc.Layers.Add(name, color);
            }
            Layer layer = doc.Layers[idx];
            layer.IsVisible = visible;
            return layer.Id;
        }
        public Guid CurrentLayer() {
            return doc.Layers.CurrentLayer.Id;
        }
        public void SetCurrentLayer(Guid id) =>
            doc.Layers.SetCurrentLayerIndex(doc.Layers.Find(id, true, -1), true);
        public void SetLayerVisible(Guid id, bool visible) =>
             doc.Layers[doc.Layers.Find(id, true, -1)].IsVisible = visible;
        public void SetLayerTransparency(Guid layerId, double opacity) {
            int layerIndex = doc.Layers.Find(layerId, true, -1);
            if (layerIndex < 0) return;
            var objects = doc.Objects.FindByLayer(doc.Layers[layerIndex]);
            foreach (var obj in objects) {
                var attrs = obj.Attributes;
                if (opacity > 0 && opacity < 1) {
                    // Save original material source if not already saved
                    if (!attrs.UserDictionary.ContainsKey("KhepriOrigMaterialSource"))
                        attrs.UserDictionary.Set("KhepriOrigMaterialSource", (int)attrs.MaterialSource);
                    // Create a semi-transparent material from the object's current material
                    Material mat = new Material(obj.GetMaterial(true));
                    mat.Transparency = 1.0 - opacity;
                    mat.CommitChanges();
                    RenderMaterial rmat = RenderMaterial.CreateBasicMaterial(mat, doc);
                    doc.RenderMaterials.Add(rmat);
                    doc.Objects.ModifyRenderMaterial(obj.Id, rmat);
                    attrs.MaterialSource = ObjectMaterialSource.MaterialFromObject;
                    obj.CommitChanges();
                } else {
                    // Restore original material source
                    if (attrs.UserDictionary.TryGetInteger("KhepriOrigMaterialSource", out int origSource)) {
                        attrs.MaterialSource = (ObjectMaterialSource)origSource;
                        attrs.UserDictionary.Remove("KhepriOrigMaterialSource");
                        obj.CommitChanges();
                    }
                }
            }
            doc.Views.Redraw();
        }
        public string LayerName(Guid id) =>
            doc.Layers[doc.Layers.Find(id, true, -1)].Name;
        public Color LayerColor(Guid id) =>
            doc.Layers[doc.Layers.Find(id, true, -1)].Color;
        public bool LayerVisible(Guid id) =>
            doc.Layers[doc.Layers.Find(id, true, -1)].IsVisible;

        public void SetLayerMaterial(Guid layerId, int materialIndex) {
            if (materialIndex >= 0 && materialIndex < renderMaterials.Count) {
                int idx = doc.Layers.Find(layerId, true, -1);
                if (idx >= 0) {
                    doc.Layers[idx].RenderMaterial = renderMaterials[materialIndex];
                }
            }
        }

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

        public Brep[] PathWall(RhinoObject obj, double lThickness, double rThickness, double height) {
            Curve path = (Curve)obj.Geometry;
            Ensure(path.PerpendicularFrameAt(0, out Plane plane));
            // This should be ensured by the front end!
            /*if (plane.Normal * Plane.WorldXY.Normal <= 1e-16) {
                lThickness = -lThickness;
                rThickness = -rThickness;
            }*/
            Transform xform = Transform.ChangeBasis(plane, Plane.WorldXY);
            Curve cross_section = new PolylineCurve(new Point3d[] {
                new Point3d(-lThickness,0,0),
                new Point3d(rThickness,0,0),
                new Point3d(rThickness,height,0),
                new Point3d(-lThickness,height,0),
                new Point3d(-lThickness,0,0) });
            /*                plane.PointAt(0,-lThickness,0),
            plane.PointAt(0,rThickness,0),
            plane.PointAt(0,rThickness,height),
            plane.PointAt(0,-lThickness,height),
            plane.PointAt(0,-lThickness,0) });/*
            plane.PointAt(-lThickness,0,0),
                plane.PointAt(rThickness,0,0),
                plane.PointAt(rThickness,height,0),
                plane.PointAt(-lThickness,height,0),
                plane.PointAt(-lThickness,0,0) });
*/
            Ensure(cross_section.Transform(xform));
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
            Enumerable.Range(0, n).Select(i => FamilyInstanceGeometry(c + Vcyl(spacing * i, angle, 0), angle + Math.PI / 2, family)).ToArray();

        public GeometryBase[] CenteredRowOfInstancesGeometry(Point3d c, double angle, int n, double spacing, int family) =>
            RowOfInstancesGeometry(c + Vcyl(-spacing * (n - 1) / 2, angle, 0), angle, n, spacing, family);

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
        Vector3d Vcyl(double rho, double phi, double z) => new Vector3d(rho * Math.Cos(phi), rho * Math.Sin(phi), z);


        // Illustrations

        public DimensionStyle GetDimensionStyle(String name) {
            DimensionStyle ds = doc.DimStyles.FindName(name);
            if (ds == null) {
                DimensionStyle dimStyle = new DimensionStyle() {
                    Name = name,
                    Id = Guid.NewGuid(),
                    ArrowType1 = DimensionStyle.ArrowType.None,
                    ArrowType2 = DimensionStyle.ArrowType.LongTriangle,
                };
                doc.DimStyles.Add(dimStyle, false);
                ds = doc.DimStyles.FindName(name);
            }
            return ds;
        }

        public Guid CreateLeaderDimension(String text, Point3d p0, Point3d p1, double scale, String mark, Options props) {
            Leader leader = Leader.Create(text, Plane.WorldXY, GetDimensionStyle("KhepriStyle"), new Point3d[] { p0, p1 });
            Set(leader, props);
            return doc.Objects.AddLeader(leader);
        }
        /*
                public Guid CreateAlignedDimension(String text, Point3d p0, Point3d p1, Point3d p, double scale, String mark, Options props) {
                }
                public Guid CreateRadialDimension(String text, Point3d c, Point3d chord, double leader, double scale, String mark, Options props) {
                }
                }
        */
        public Guid CreateDiametricDimension(String text, Plane c, Point3d p, Point3d pdim, double scale, String mark, Options props) {
            RadialDimension dim = RadialDimension.Create(GetDimensionStyle("KhepriStyle"), AnnotationType.Diameter, c, c.Origin, p, pdim);
            dim.PlainText = text;
            Set(dim, props);
            return doc.Objects.AddRadialDimension(dim);
        }
/*        public Guid CreateAngularDimensionOld(string text, Plane p, double radius, double startAngle, double endAngle, double scale, double offset, Options props) {
            AngularDimension dim = new AngularDimension(new Arc(new Circle(p, radius), new Interval(startAngle, endAngle)), offset);
            dim.PlainText = text;
            //dim.SetRichText(text, doc.DimStyles.Current);
            Set(dim, props);
            return doc.Objects.AddAngularDimension(dim);
        }*/
        public Guid CreateAngularDimension(String text, Plane p, Point3d p0, Point3d p1, Point3d ptdim, double scale, String mark, Options props) {
            AngularDimension dim = AngularDimension.Create(GetDimensionStyle("KhepriStyle"), p, p.XAxis, p.Origin, p0, p1, ptdim);
            dim.PlainText = text;
            Set(dim, props);
            return doc.Objects.AddAngularDimension(dim);
        }
        public void SunLight(DateTime dt, double latitude, double longitude, int meridian, float turbidity, bool hasSun) {
            Sun sun = doc.Lights.Sun;
            // Sun.SetPosition(DateTime, lat, lon) and Sun.SkylightOn are obsolete:
            // set Latitude/Longitude/TimeZone and the date/time individually, and
            // enable the skylight through RenderSettings. TimeZone is set before
            // SetDateTime so the Unspecified-kind time is read at the right zone.
            sun.Latitude = latitude;
            sun.Longitude = longitude;
            sun.TimeZone = meridian;
            sun.SetDateTime(dt, DateTimeKind.Unspecified);
            sun.Enabled = hasSun;
            // RenderSettings is returned by value; modify the copy and write it back.
            RenderSettings rs = doc.RenderSettings;
            rs.Skylight.Enabled = true;
            doc.RenderSettings = rs;
        }
        public Guid PointLight(Point3d p, Color c, double power) {
            LightObject obj = doc.Lights[doc.Lights.Add(new Light())];
            Light l = obj.LightGeometry;
            l.LightStyle = LightStyle.WorldPoint;
            l.Location = p;
            l.Diffuse = c;
            l.PowerCandela = power;
            obj.CommitChanges();
            return obj.Id;
        }
        public Guid SpotLight(Point3d position, double hotspot, double falloff, Point3d target) {
            LightObject obj = doc.Lights[doc.Lights.Add(new Light())];
            Light l = obj.LightGeometry;
            l.LightStyle = LightStyle.WorldSpot;
            l.Location = position;
            l.Direction = target - position;
            l.SpotAngleRadians = falloff;
            l.HotSpot = hotspot / falloff;
            obj.CommitChanges();
            return obj.Id;
        }
        public Guid IESLight(string webFile, Point3d position, Point3d target, Vector3d rotation) {
            LightObject obj = doc.Lights[doc.Lights.Add(new Light())];
            Light l = obj.LightGeometry;
            l.LightStyle = LightStyle.WorldSpot;
            l.Location = position;
            l.Direction = target - position;
            obj.CommitChanges();
            return obj.Id;
        }
        public void EnableGrasshopperSolver() {
            dynamic gh = RhinoApp.GetPlugInObject("Grasshopper");
            gh.EnableSolver();
        }
        public void DisableGrasshopperSolver() {
            dynamic gh = RhinoApp.GetPlugInObject("Grasshopper");
            gh.DisableSolver();
        }
        public void RunGrasshopperSolver() {
            dynamic gh = RhinoApp.GetPlugInObject("Grasshopper");
            gh.RunSolver(true);
        }
    }
}

using Creation = Autodesk.Revit.Creation;
using Autodesk.Revit.DB;
using Autodesk.Revit.DB.Analysis;
using Autodesk.Revit.DB.Architecture;
using Autodesk.Revit.UI;
using Autodesk.Revit.UI.Selection;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;
using Autodesk.Revit.DB.Structure;
using VXYZ = Autodesk.Revit.DB.XYZ;
using static System.Net.WebRequestMethods;
using System.Windows.Forms;
using static System.Windows.Forms.VisualStyles.VisualStyleElement.ToolTip;

namespace KhepriRevit {
    public class Length {
        public double Value {
            get {
                return _value;
            }
        }
        private readonly double _value;
       public Length(double value) {
            _value = value;
        }
        public static bool operator ==(Length m1, Length m2) {
            if (ReferenceEquals(m1, m2))
                return true;
            if (ReferenceEquals(null, m1))
                return false;
            if (ReferenceEquals(null, m2))
                return false;
            return m1.Equals(m2);
        }
        public static bool operator !=(Length m1, Length m2) {
            return !(m1 == m2);
        }
        public static implicit operator double(Length t) {
            return t.Value;
        }
        public sealed override bool Equals(object obj) {
            var other = obj as Length;
            if (other == null)
                return false;
            return _value.Equals(other.Value);
        }
        public sealed override int GetHashCode() {
            return _value.GetHashCode();
        }
        public override string ToString() {
            return _value.ToString();
        }
    }

    public class Primitives : KhepriBase.Primitives {
        [DllImport("user32.dll", SetLastError = true)]
        static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
        const uint SWP_NOMOVE = 0x0002;
        const uint SWP_NOZORDER = 0x0004;

        private UIApplication uiapp;
        private Document doc;
        private Document familyDoc;
        public Transaction CurrentTransaction { get; set; }
        public ElementId CurrentMaterialId { get; set; }
        static private int levelCounter = 3;
        static private int customFamilyCounter = 0;
        /* Family-load cache.
         * Keyed by the *full normalized path* (Path.GetFullPath + ToLowerInvariant) so two
         * .rfa files that share a basename in different folders (e.g. a custom override of
         * a Metric-library family) are not aliased into the same Family. The previous
         * basename-only key collided silently and the second load would hit the first
         * load's cache entry, returning the wrong Family.
         */
        static private Dictionary<string, Family> pathToFamily = new Dictionary<string, Family>();
        static private Dictionary<Family, Dictionary<string, FamilySymbol>> loadedFamiliesSymbols =
            new Dictionary<Family, Dictionary<string, FamilySymbol>>();

        // Family / FamilySymbol objects are document-scoped; drop the caches when the active
        // document changes so the new document loads its own families (see EnsureTransaction).
        static private void InvalidateFamilyCaches() {
            pathToFamily.Clear();
            loadedFamiliesSymbols.Clear();
            Channel.InvalidateFamilyCache();
        }

        public Primitives(UIApplication app) : base() {
            uiapp = app;
            doc = uiapp.ActiveUIDocument.Document;
            CurrentMaterialId = ElementId.InvalidElementId;
        }

        public void UpdateDocument(Document newDoc) {
            doc = newDoc;
        }

        // Activates the symbol if needed and regenerates so it is usable as a placement
        // type. Revit refuses NewFamilyInstance against an inactive symbol.
        private void EnsureActive(FamilySymbol symbol) {
            if (!symbol.IsActive) {
                symbol.Activate();
                doc.Regenerate();
            }
        }

        public void EnsureTransaction(UIApplication app) {
            Document activeDoc = app.ActiveUIDocument.Document;
            if (CurrentTransaction == null || !activeDoc.Equals(doc)) {
                bool docChanged = !activeDoc.Equals(doc);
                CommitAndDisposeTransaction();
                if (docChanged) {
                    // The active document changed (LoadRVTFile, or the user switched project tabs).
                    // Family / FamilySymbol objects and the id->Family reverse map are DOCUMENT-SCOPED,
                    // so caches built against the previous document are invalid here — drop them so the
                    // new document loads its own families rather than reusing stale cross-document refs.
                    // Only on an actual switch, so within-document caching is preserved.
                    InvalidateFamilyCaches();
                }
                doc = activeDoc;
                CurrentTransaction = new Transaction(doc, "Execute");
                CurrentTransaction.Start();
                WarningSwallower.KhepriWarnings(CurrentTransaction);
            }
        }

        public void CommitAndDisposeTransaction() {
            if (CurrentTransaction != null) {
                try {
                    if (CurrentTransaction.GetStatus() == TransactionStatus.Started) {
                        CurrentTransaction.Commit();
                    }
                } catch (Autodesk.Revit.Exceptions.InvalidOperationException) {
                    // Transaction's document is no longer valid
                }
                try {
                    CurrentTransaction.Dispose();
                } catch (Autodesk.Revit.Exceptions.InvalidOperationException) {
                }
                CurrentTransaction = null;
            }
        }

        // Commit the current top-level transaction, run work that Revit forbids inside an open
        // transaction (StairsEditScope, ExportImage, view switching), then ALWAYS reopen a fresh
        // transaction — even if the work throws. Without the guaranteed restart, an exception in the
        // work leaves CurrentTransaction committed-but-non-null, so EnsureTransaction (which only opens
        // a new one when the field is null) stays a no-op and every later write in the read-burst is
        // silently dropped. No catch here: the exception still reaches the RPC caller, where RMIfy
        // turns it into a clean BackendError — so a failure restores the transaction AND informs Julia.
        private void WithSuspendedTransaction(Action action) {
            CurrentTransaction.Commit();
            try {
                action();
            } finally {
                CurrentTransaction.Start();
            }
        }

        public bool ConvertIFCFile(string ifcpath) {
            string rvtpath = Path.ChangeExtension(ifcpath, "rvt");
            // If the file is open, it must be closed first
            Document currDoc = uiapp.ActiveUIDocument.Document;
            if (currDoc.PathName.Equals(rvtpath)) {
                currDoc.Close();
            }
            Document ifcdoc = uiapp.Application.OpenIFCDocument(ifcpath);
            ifcdoc.SaveAs(rvtpath, new SaveAsOptions() { OverwriteExistingFile=true });
            ifcdoc.Close();
            return true;
        }
        public bool LoadRVTFile(string file) {
            CommitAndDisposeTransaction();
            uiapp.OpenAndActivateDocument(file);
            EnsureTransaction(uiapp);
            return true;
        }


        CurveArray PolygonalCurveArray(XYZ[] pts) {
            CurveArray profile = new CurveArray();
            for (int i = 0; i < pts.Length; i++) {
                profile.Append(Line.CreateBound(pts[i], pts[(i + 1) % pts.Length]));
            }
            return profile;
        }
        CurveLoop LineCurveLoop(XYZ[] pts) {
            List<Curve> curves = new List<Curve>();
            for (int i = 0; i < pts.Length - 1; i++) {
                curves.Add(Line.CreateBound(pts[i], pts[(i + 1)]));
            }
            return CurveLoop.Create(curves);
        }
        CurveLoop PolygonCurveLoop(XYZ[] pts) {
            List<Curve> curves = new List<Curve>();
            for (int i = 0; i < pts.Length; i++) {
                curves.Add(Line.CreateBound(pts[i], pts[(i + 1) % pts.Length]));
            }
            return CurveLoop.Create(curves);
        }
        Arc ArcFromPointsAngle(XYZ p0, XYZ p1, double angle) {
            // Compute the arc midpoint using the sagitta, then use three-point Arc.Create.
            // sagitta = r * (1 - cos(angle/2)), with r = halfChord / sin(angle/2)
            // This simplifies to: sagitta = halfChord * tan(angle/4) (signed by angle)
            VXYZ v = p1 - p0;
            XYZ chordMid = p0 + v * 0.5;
            double halfChord = Math.Sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) / 2;
            double sagitta = halfChord * Math.Tan(angle / 4);
            // Perpendicular to chord in the horizontal plane, pointing left of p0→p1.
            double chordLenXY = Math.Sqrt(v.X * v.X + v.Y * v.Y);
            XYZ perp = chordLenXY > 1e-10
                ? new XYZ(-v.Y / chordLenXY, v.X / chordLenXY, 0)
                : new XYZ(0, 1, 0);
            // Khepri's amplitude is CCW-positive around the CENTER, which puts the center LEFT of
            // the p0→p1 chord and the bulge RIGHT of it — so the sagitta is subtracted along the
            // left-perpendicular. (Bulging left mirrored every PathCurveArray arc across its chord:
            // the arc curtain wall rebuilt with the wrong of the two candidate centers.)
            XYZ arcMid = chordMid - perp * sagitta;
            // Arc.Create's XYZ overload is (end1, end2, pointOnArc) — the midpoint goes LAST.
            // Passing it second made the midpoint an endpoint, so the arc ran the long way
            // around (315° instead of 90°) through the far side of the circle.
            return Arc.Create(p0, p1, arcMid);
        }
        CurveArray ClosedPathCurveArray(XYZ[] pts, double[] angles) {
            CurveArray profile = new CurveArray();
            for (int i = 0; i < pts.Length; i++) {
                if (angles[i] == 0) {
                    profile.Append(Line.CreateBound(pts[i], pts[(i + 1) % pts.Length]));
                } else {
                    profile.Append(ArcFromPointsAngle(pts[i], pts[(i + 1) % pts.Length], angles[i]));
                }
            }
            return profile;
        }
        CurveArray PathCurveArray(XYZ[] pts, double[] angles) {
            CurveArray profile = new CurveArray();
            for (int i = 0; i < angles.Length; i++) {
                if (angles[i] == 0) {
                    profile.Append(Line.CreateBound(pts[i], pts[(i + 1) % pts.Length]));
                } else {
                    profile.Append(ArcFromPointsAngle(pts[i], pts[(i + 1) % pts.Length], angles[i]));
                }
            }
            return profile;
        }
        CurveLoop CurveLoopPath(XYZ[] pts, double[] angles) {
            CurveLoop profile = new CurveLoop();
            for (int i = 0; i < pts.Length; i++) {
                if (angles[i] == 0) {
                    profile.Append(Line.CreateBound(pts[i], pts[(i + 1) % pts.Length]));
                } else {
                    profile.Append(ArcFromPointsAngle(pts[i], pts[(i + 1) % pts.Length], angles[i]));
                }
            }
            return profile;
        }

        public Element SurfaceGrid(XYZ[] linearizedMatrix, int n, int m) {
            ReferenceArrayArray refarar = new ReferenceArrayArray();
            for (int i = 0; i < n; i++) {
                ReferencePointArray rpa = new ReferencePointArray();
                for (int j = 0; j < m; j++) {
                    XYZ p = linearizedMatrix[i * m + j];
                    rpa.Append(doc.FamilyCreate.NewReferencePoint(p));
                }
                ReferenceArray arr = new ReferenceArray();
                arr.Append(doc.FamilyCreate.NewCurveByPoints(rpa).GeometryCurve.Reference);
                refarar.Append(arr);
            }
            return doc.FamilyCreate.NewLoftForm(true, refarar);
        }
        // DirectShapes
        static ElementId DScategoryId = new ElementId(BuiltInCategory.OST_GenericModel);
        public Frame FrameFromAxis(XYZ o, XYZ vz) {
            double limit = 1.0 / 64;
            XYZ axis = (Math.Abs(vz.X) < limit && Math.Abs(vz.Y) < limit) ? XYZ.BasisY : XYZ.BasisZ;
            XYZ vx = axis.CrossProduct(vz).Normalize();
            XYZ vy = vz.CrossProduct(vx).Normalize();
            return new Frame(o, vx, vy, vz);
        }
        static void CreateFaces(TessellatedShapeBuilder builder, IList<XYZ> ps, IList<XYZ> qs, ElementId materialId) {
            for (int i = 0; i < ps.Count - 1; i++) {
                builder.AddFace(new TessellatedFace(new XYZ[] { ps[i], ps[i + 1], qs[i + 1], qs[i] }, materialId));
            }
            builder.AddFace(new TessellatedFace(new XYZ[] { ps[ps.Count - 1], ps[0], qs[0], qs[qs.Count - 1] }, materialId));
        }
        Element FinishBuilder(TessellatedShapeBuilder builder, string name) {
            builder.CloseConnectedFaceSet();
            builder.Target = TessellatedShapeBuilderTarget.AnyGeometry;
            builder.Fallback = TessellatedShapeBuilderFallback.Mesh;
            FilteredElementCollector collector = new FilteredElementCollector(doc).OfClass(typeof(GraphicsStyle));
            GraphicsStyle style = collector.Cast<GraphicsStyle>().FirstOrDefault<GraphicsStyle>(gs => gs.Name.Equals("<Sketch>"));
            ElementId graphicsStyleId = null;
            if (style != null) {
                graphicsStyleId = style.Id;
            }
            builder.Build();
            DirectShape ds = DirectShape.CreateElement(doc, DScategoryId);
            ds.ApplicationId = uiapp.ActiveAddInId.GetGUID().ToString();
            ds.ApplicationDataId = name;
            ds.SetShape(builder.GetBuildResult().GetGeometricalObjects());
            ds.Name = name;
            return ds;
        }
        public Element PyramidFrustumNamed(String name, XYZ[] ps, XYZ[] qs, ElementId materialId) {
            TessellatedShapeBuilder builder = new TessellatedShapeBuilder { LogString = name };
            builder.OpenConnectedFaceSet(false);
            builder.AddFace(new TessellatedFace(ps, materialId));
            builder.AddFace(new TessellatedFace(qs, materialId));
            CreateFaces(builder, ps, qs, materialId);
            return FinishBuilder(builder, name);
        }
        public Element PyramidFrustumWithMaterial(XYZ[] ps, XYZ[] qs, ElementId materialId) =>
            PyramidFrustumNamed("PyramidFrustum", ps, qs, materialId);
        public Element PyramidFrustum(XYZ[] ps, XYZ[] qs) =>
            PyramidFrustumWithMaterial(ps, qs, CurrentMaterialId);

        public Element OldExtrudedContourNamed(string name, XYZ[] contour, bool smoothContour, XYZ[][] holes, bool[] smoothHoles, XYZ v, ElementId materialId) {
            TessellatedShapeBuilder builder = new TessellatedShapeBuilder { LogString = name };
            builder.OpenConnectedFaceSet(false);
            List<IList<XYZ>> botLoops = new List<IList<XYZ>> { contour.ToList() };
            botLoops.AddRange(holes.ToList().Select(hole => hole.ToList()));
            builder.AddFace(new TessellatedFace(botLoops, ElementId.InvalidElementId));
            List<IList<XYZ>>topLoops = new List<IList<XYZ>> { contour.Select(p => p.Add(v)).ToList() };
            topLoops.AddRange(holes.ToList().Select(hole => hole.Select(p => p.Add(v)).ToList()));
            builder.AddFace(new TessellatedFace(topLoops, ElementId.InvalidElementId));
            for (int i = 0; i < botLoops.Count; i++) {
                CreateFaces(builder, botLoops[i], topLoops[i], materialId);
            }
            return FinishBuilder(builder, name);
        }

        IList<Curve> CreateCurves(XYZ[] pts, bool smooth) {
            //This should be taken care in some other place...
            XYZ[] ps = pts[pts.Length - 1].DistanceTo(pts[0]) < uiapp.Application.ShortCurveTolerance ?
                pts.Take(pts.Length - 1).ToArray() :
                pts;
            IList<Curve> curves = new List<Curve>();
            if (smooth) {
                //No profile loop can consist of a single curve.
                //If you are using a single closed curve, split the loop into two curves before using it as a profile loop.
                //A (closed) smooth pts has a duplicated point.
                Curve closedCurve = HermiteSpline.Create(ps, true);
                double p0 = closedCurve.GetEndParameter(0);
                double p1 = closedCurve.GetEndParameter(1);
                double pi = (p0 + p1) / 2;
                Curve halfCurve0 = closedCurve.Clone();
                Curve halfCurve1 = closedCurve.Clone();
                halfCurve0.MakeBound(0, pi);
                halfCurve1.MakeBound(pi, p1);
                curves.Add(halfCurve0);
                curves.Add(halfCurve1);
                //curves.Add(closedCurve);
            } else {
                for (int i = 0; i < ps.Length - 1; i++) {
                    curves.Add(Line.CreateBound(ps[i], ps[i + 1]));
                }
                curves.Add(Line.CreateBound(ps[ps.Length - 1], ps[0]));
            }
            return curves;
        }

        List<CurveLoop> CreateCurveLoops(XYZ[] contour, bool smoothContour, XYZ[][] holes, bool[] smoothHoles) {
            List<CurveLoop> curveLoopList = new List<CurveLoop>();
            curveLoopList.Add(CurveLoop.Create(CreateCurves(contour, smoothContour)));
            for (int i = 0; i < holes.Length; i++) {
                curveLoopList.Add(CurveLoop.Create(CreateCurves(holes[i], smoothHoles[i])));
            }
            return curveLoopList;
        }

        public Element ExtrudedContourNamed(string name, XYZ[] contour, bool smoothContour, XYZ[][] holes, bool[] smoothHoles, XYZ v, ElementId materialId) {
            Solid solid = GeometryCreationUtilities.CreateExtrusionGeometry(
                CreateCurveLoops(contour, smoothContour, holes, smoothHoles),
                v, v.GetLength(), new SolidOptions(materialId, ElementId.InvalidElementId));
            DirectShape ds = DirectShape.CreateElement(doc, new ElementId(BuiltInCategory.OST_GenericModel));
            ds.SetShape(new GeometryObject[] { solid });
            ds.ApplicationId = uiapp.ActiveAddInId.GetGUID().ToString();
            ds.ApplicationDataId = name;
            ds.Name = name;
            return ds;
        }
        public Element ExtrudedContourWithMaterial(XYZ[] contour, bool smoothContour, XYZ[][] holes, bool[] smoothHoles, VXYZ v, ElementId materialId) =>
             ExtrudedContourNamed("Extrusion", contour, smoothContour, holes, smoothHoles, v, materialId);
        public Element ExtrudedContour(XYZ[] contour, bool smoothContour, XYZ[][] holes, bool[] smoothHoles, VXYZ v) =>
            ExtrudedContourWithMaterial(contour, smoothContour, holes, smoothHoles, v, CurrentMaterialId);

        public Element SurfaceFromGrid(int m, int n, XYZ[] pts, bool closedM, bool closedN, int level) {
            string name = "SurfaceGrid";
            TessellatedShapeBuilder builder = new TessellatedShapeBuilder { LogString = name };
            builder.OpenConnectedFaceSet(false);
            int rm = closedM ? m : m - 1;
            int rn = closedN ? n : n - 1;
            for (int i = 0; i < rm; i++) {
                for (int j = 0; j < rn; j++) {
                    List<XYZ> corners = new List<XYZ>(4);
                    corners.Add(pts[i * n + j]);
                    corners.Add(pts[i * n + (j + 1) % n]);
                    corners.Add(pts[((i + 1) % m) * n + (j + 1) % n]);
                    corners.Add(pts[((i + 1) % m) * n + j]);
                    builder.AddFace(new TessellatedFace(corners, ElementId.InvalidElementId));
                }
            }
            return FinishBuilder(builder, name);
        }
        //
        Element ElementFromSolid(string name, Solid solid) {
            DirectShape ds = DirectShape.CreateElement(doc, DScategoryId);
            ds.ApplicationId = "Khepri";
            ds.ApplicationDataId = name;
            ds.SetShape(new GeometryObject[] { solid });
            ds.Name = name;
            return ds;
        }

        // Per-element world AABB corners (aggregated per-axis on the Julia side).
        // get_BoundingBox(null) returns a box in its own coordinate space, so all
        // eight corners are transformed to world before taking the min/max.
        void ComputeWorldBounds(Element e, out XYZ worldMin, out XYZ worldMax) {
            BoundingBoxXYZ bb = e.get_BoundingBox(null);
            if (bb == null) { worldMin = XYZ.Zero; worldMax = XYZ.Zero; return; }
            Transform t = bb.Transform;
            double minX = double.PositiveInfinity, minY = double.PositiveInfinity, minZ = double.PositiveInfinity;
            double maxX = double.NegativeInfinity, maxY = double.NegativeInfinity, maxZ = double.NegativeInfinity;
            for (int i = 0; i < 8; i++) {
                XYZ corner = new XYZ(
                    (i & 1) == 0 ? bb.Min.X : bb.Max.X,
                    (i & 2) == 0 ? bb.Min.Y : bb.Max.Y,
                    (i & 4) == 0 ? bb.Min.Z : bb.Max.Z);
                XYZ wc = t.OfPoint(corner);
                minX = Math.Min(minX, wc.X); minY = Math.Min(minY, wc.Y); minZ = Math.Min(minZ, wc.Z);
                maxX = Math.Max(maxX, wc.X); maxY = Math.Max(maxY, wc.Y); maxZ = Math.Max(maxZ, wc.Z);
            }
            worldMin = new XYZ(minX, minY, minZ);
            worldMax = new XYZ(maxX, maxY, maxZ);
        }
        public XYZ BoundingBoxMin(Element e) {
            ComputeWorldBounds(e, out XYZ worldMin, out _);
            return worldMin;
        }
        public XYZ BoundingBoxMax(Element e) {
            ComputeWorldBounds(e, out _, out XYZ worldMax);
            return worldMax;
        }

        public Element Sphere(XYZ centre, Length radius, ElementId materialId) {
            Frame frame = new Frame(centre, XYZ.BasisX, XYZ.BasisY, XYZ.BasisZ);
            XYZ p0 = centre - radius * frame.BasisZ;
            XYZ p1 = centre + radius * frame.BasisZ;
            Arc arc = Arc.Create(p0, p1, centre + radius * XYZ.BasisX);
            Line line = Line.CreateBound(p1, p0);
            // materialId bakes the current material onto the solid (InvalidElementId = none).
            return ElementFromSolid("Sphere", GeometryCreationUtilities.CreateRevolvedGeometry(
                frame,
                new List<CurveLoop>() { CurveLoop.Create(new List<Curve>(2) { arc, line }) },
                0, 2 * Math.PI,
                new SolidOptions(materialId, ElementId.InvalidElementId)));
        }
        public Element ConeFrustumNamed(string name, XYZ bottom, VXYZ axis, Length bottomRadius, Length height, Length topRadius, ElementId materialId) {
            Frame frame = FrameFromAxis(bottom, axis.Normalize());
            XYZ p0 = bottom;
            XYZ p1 = p0 + frame.BasisX * bottomRadius;
            XYZ p3 = p0 + frame.BasisZ * height;
            XYZ p2 = p3 + frame.BasisX * topRadius;
            List<Curve> profile = new List<Curve>(4) {
                Line.CreateBound(p0, p1),
                Line.CreateBound(p1, p2),
                Line.CreateBound(p2, p3),
                Line.CreateBound(p3, p0) };
            // Single material on the revolved solid (InvalidElementId = none). Per-face
            // cap materials are a future refinement. See materials design note (P2).
            return ElementFromSolid(name, GeometryCreationUtilities.CreateRevolvedGeometry(
                frame,
                new CurveLoop[] { CurveLoop.Create(profile) },
                0, 2 * Math.PI,
                new SolidOptions(materialId, ElementId.InvalidElementId)));
        }
        public Element ConeFrustum(XYZ bottom, VXYZ axis, Length bottomRadius, Length height, Length topRadius, ElementId materialId) =>
            ConeFrustumNamed("ConeFrustum", bottom, axis, bottomRadius, height, topRadius, materialId);
        public Element Cylinder(XYZ bottom, VXYZ axis, Length radius, Length height, ElementId materialId) =>
            ConeFrustumNamed("Cylinder", bottom, axis, radius, height, radius, materialId);
        public Element CylinderWithCaps(XYZ bottom, VXYZ axis, Length radius, Length height, bool bottomCap, bool topCap, ElementId materialId) {
            const int segments = 64;
            Frame frame = FrameFromAxis(bottom, axis.Normalize());
            XYZ top = bottom + frame.BasisZ * height;
            List<XYZ> bottomRing = new List<XYZ>(segments);
            List<XYZ> topRing = new List<XYZ>(segments);
            for (int i = 0; i < segments; i++) {
                double angle = 2 * Math.PI * i / segments;
                XYZ offset = frame.BasisX * (radius * Math.Cos(angle)) + frame.BasisY * (radius * Math.Sin(angle));
                bottomRing.Add(bottom + offset);
                topRing.Add(top + offset);
            }
            TessellatedShapeBuilder builder = new TessellatedShapeBuilder { LogString = "Cylinder" };
            builder.OpenConnectedFaceSet(false);
            CreateFaces(builder, bottomRing, topRing, materialId);
            if (bottomCap) {
                builder.AddFace(new TessellatedFace(bottomRing.AsEnumerable().Reverse().ToList(), materialId));
            }
            if (topCap) {
                builder.AddFace(new TessellatedFace(topRing, materialId));
            }
            return FinishBuilder(builder, "Cylinder");
        }
        public Element Cone(XYZ bottom, VXYZ axis, Length bottomRadius, Length height, ElementId materialId) {
            Frame frame = FrameFromAxis(bottom, axis.Normalize());
            XYZ p0 = bottom;
            XYZ p1 = p0 + frame.BasisX * bottomRadius;
            XYZ p2 = p0 + frame.BasisZ * height;
            List<Curve> profile = new List<Curve>(3) {
                Line.CreateBound(p0, p1),
                Line.CreateBound(p1, p2),
                Line.CreateBound(p2, p0) };
            return ElementFromSolid("Cone", GeometryCreationUtilities.CreateRevolvedGeometry(
                frame,
                new CurveLoop[] { CurveLoop.Create(profile) },
                0, 2 * Math.PI,
                new SolidOptions(materialId, ElementId.InvalidElementId)));
        }
        private Element Cylinder2(XYZ bottom, VXYZ axis, Length radius, Length height) {
            Frame frame = FrameFromAxis(bottom, axis.Normalize());
            return ElementFromSolid("Cylinder", GeometryCreationUtilities.CreateExtrusionGeometry(
                new List<CurveLoop>() { CurveLoop.Create(new List<Curve>(2) {
                    Arc.Create(bottom, radius, 0, Math.PI, frame.BasisX, frame.BasisY),
                    Arc.Create(bottom, radius, Math.PI, 2 * Math.PI, frame.BasisX, frame.BasisY) }) },
                frame.BasisZ, 
                height));
        }
        static Solid CreateRectangularPrism(
          XYZ center,
          Length d1,
          Length d2,
          Length d3) {
            List<Curve> profile = new List<Curve>();
            XYZ profile00 = new XYZ(-d1 / 2, -d2 / 2, -d3 / 2);
            XYZ profile01 = new XYZ(-d1 / 2, d2 / 2, -d3 / 2);
            XYZ profile11 = new XYZ(d1 / 2, d2 / 2, -d3 / 2);
            XYZ profile10 = new XYZ(d1 / 2, -d2 / 2, -d3 / 2);

            profile.Add(Line.CreateBound(profile00, profile01));
            profile.Add(Line.CreateBound(profile01, profile11));
            profile.Add(Line.CreateBound(profile11, profile10));
            profile.Add(Line.CreateBound(profile10, profile00));

            CurveLoop curveLoop = CurveLoop.Create(profile);

            SolidOptions options = new SolidOptions(
              ElementId.InvalidElementId,
              ElementId.InvalidElementId);

            return GeometryCreationUtilities
              .CreateExtrusionGeometry(
                new CurveLoop[] { curveLoop },
                XYZ.BasisZ, d3, options);
        }

        // Native axis-aligned box as a true extrusion Solid (a corner-based prism),
        // replacing the tessellated PyramidFrustum path b_box used before. basePts are
        // the 4 base corners in CCW order as seen from the +height side (i.e. c's
        // frame); the box extrudes from that base plane by `height` along the base
        // plane normal, computed from the corners so a rotated c.cs extrudes along its
        // own up-axis.
        public Element Box(XYZ[] basePts, Length height, ElementId materialId) {
            List<Curve> profile = new List<Curve>();
            int n = basePts.Length;
            for (int i = 0; i < n; i++) {
                profile.Add(Line.CreateBound(basePts[i], basePts[(i + 1) % n]));
            }
            CurveLoop loop = CurveLoop.Create(profile);
            XYZ dir = (basePts[1] - basePts[0]).CrossProduct(basePts[2] - basePts[1]).Normalize();
            // materialId bakes the current material onto the solid's faces (InvalidElementId
            // = no material). See materials design note (P2).
            SolidOptions options = new SolidOptions(materialId, ElementId.InvalidElementId);
            Solid solid = GeometryCreationUtilities.CreateExtrusionGeometry(
                new CurveLoop[] { loop }, dir, height, options);
            return ElementFromSolid("Box", solid);
        }

        Solid SolidFromElement(Element e) {
            using (Options opt = new Options())
            using (GeometryElement geo = e.get_Geometry(opt)) {
                Solid union = null;
                foreach (GeometryObject obj in geo) {
                    Solid solid = obj as Solid;
                    if (solid == null || solid.Faces.Size == 0) continue;   // skip non-solids / empty solids
                    union = union == null ?
                        SolidUtils.Clone(solid) :   // clone so the result outlives the disposed GeometryElement
                        BooleanOperationsUtils.ExecuteBooleanOperation(union, solid, BooleanOperationsType.Union);
                }
                if (union == null)
                    throw new InvalidOperationException($"BooleanOperation: element {e?.Id} has no solid geometry");
                return union;
            }
        }

        public Element BooleanOperation(string name, ElementId idA, ElementId idB, BooleanOperationsType op) {
            // Ensure all object creation operations are committed
            CurrentTransaction.Commit();
            CurrentTransaction.Start();
            Element a = doc.GetElement(idA) as Element;
            Element b = doc.GetElement(idB) as Element;
            Solid result = BooleanOperationsUtils.ExecuteBooleanOperation(
                SolidFromElement(a), SolidFromElement(b), op);
            doc.Delete(idA);
            doc.Delete(idB);
            return ElementFromSolid(name, result);
        }
        public Element Union(ElementId idA, ElementId idB) =>
            BooleanOperation("Union", idA, idB, BooleanOperationsType.Union);
        public Element Intersection(ElementId idA, ElementId idB) =>
            BooleanOperation("Intersection", idA, idB, BooleanOperationsType.Intersect);
        public Element Subtraction(ElementId idA, ElementId idB) =>
            BooleanOperation("Subtraction", idA, idB, BooleanOperationsType.Difference);

        public void MoveElement(ElementId id, XYZ translation) =>
            ElementTransformUtils.MoveElement(doc, id, translation);

        public void RotateElement(ElementId id, double angle, XYZ axis0, XYZ axis1) =>
            ElementTransformUtils.RotateElement(doc, id, Line.CreateBound(axis0, axis1), angle);
        
        private static IEnumerable<Family> FindCategoryFamilies(Document doc, BuiltInCategory cat) =>
            new FilteredElementCollector(doc)
                .OfClass(typeof(Family))
                .Cast<Family>()
                .Where(e => e.FamilyCategory != null && e.FamilyCategory.Id.Value == (long)cat);

       private static IEnumerable<Family> FindStructuralColumnFamilies(Document doc) =>
            FindCategoryFamilies(doc, BuiltInCategory.OST_StructuralColumns);

        private static FamilySymbol GetFirstSymbol(Family family) =>
            family.Document.GetElement(family.GetFamilySymbolIds().First()) as FamilySymbol;

        // Two levels are "the same" within this tolerance (feet, ~0.03 mm): larger than the drift from the
        // 3.28084 metre↔feet constant / ULPs, far smaller than any real level spacing. Exact == here spawned
        // duplicate Levels (each with its own FloorPlan + CeilingPlan view) via FindOrCreate/UpperLevel.
        const double LevelElevationTolerance = 1e-4; // feet
        public Level FindLevelAtElevation(Length elevation) =>
            new FilteredElementCollector(doc)
                .WherePasses(new ElementClassFilter(typeof(Level), false))
                .Cast<Level>()
                .FirstOrDefault(e => Math.Abs(e.Elevation - elevation.Value) < LevelElevationTolerance);

        public Level CreateLevelAtElevation(Length elevation) {
            Level level = Level.Create(doc, elevation);
            level.Name = "Level " + levelCounter;
            levelCounter++;
            IEnumerable<ViewFamilyType> viewFamilyTypes;
            viewFamilyTypes = from elem in new FilteredElementCollector(doc).OfClass(typeof(ViewFamilyType))
                              let type = elem as ViewFamilyType
                              where type.ViewFamily == ViewFamily.FloorPlan
                              select type;
            ViewPlan floorView = ViewPlan.Create(doc, viewFamilyTypes.First().Id, level.Id);
            viewFamilyTypes = from elem in new FilteredElementCollector(doc).OfClass(typeof(ViewFamilyType))
                              let type = elem as ViewFamilyType
                              where type.ViewFamily == ViewFamily.CeilingPlan
                              select type;
            ViewPlan ceilingView = ViewPlan.Create(doc, viewFamilyTypes.First().Id, level.Id);
            return level;
        }
        public Level FindOrCreateLevelAtElevation(Length elevation) {
            Level level = FindLevelAtElevation(elevation);
            return level ?? CreateLevelAtElevation(elevation);
        }
        public Level UpperLevel(Level level, Length addedElevation) =>
            FindOrCreateLevelAtElevation(new Length(level.Elevation + addedElevation));
        public Length GetLevelElevation(Level level) => new Length(level.Elevation);

        public Material GetMaterial(string name) =>
            new FilteredElementCollector(doc)
                .WherePasses(new ElementClassFilter(typeof(Material)))
                .Cast<Material>().FirstOrDefault(e => e.Name.ToString().Equals(name));

        // Read the "primary" material of a system element (wall/floor/…) for material round-trip: the
        // compound structure's core-layer material, else the element's largest-area material. Returned as
        // [r, g, b, transparency(0-100), shininess(0-128), smoothness(0-100)]; a neutral grey when none.
        public double[] ElementMaterial(Element element) {
            Material mat = null;
            try {
                ElementId matId = ElementId.InvalidElementId;
                var hostType = doc.GetElement(element.GetTypeId()) as HostObjAttributes;
                if (hostType != null) {
                    CompoundStructure cs = hostType.GetCompoundStructure();
                    if (cs != null && cs.LayerCount > 0) {
                        int core = cs.GetFirstCoreLayerIndex();
                        matId = cs.GetMaterialId(core >= 0 && core < cs.LayerCount ? core : 0);
                    }
                }
                if (matId == ElementId.InvalidElementId) {
                    var mids = element.GetMaterialIds(false);
                    if (mids.Count > 0) matId = mids.First();
                }
                if (matId != ElementId.InvalidElementId) mat = doc.GetElement(matId) as Material;
            } catch (Autodesk.Revit.Exceptions.ApplicationException ex) {
                // A genuine Revit read failure — log with element identity so it is visible during model
                // read, then fall through to grey. A non-ApplicationException (a programming bug) is NOT
                // caught here and propagates as an RPC error rather than silently becoming grey.
                PlugIn.WriteMessage($"ElementMaterial: could not read material for element {element?.Id}: {ex.Message}");
            }
            if (mat == null) return new double[] { 0.6, 0.6, 0.6, 0, 64, 50 };
            Color c = mat.Color;
            return new double[] { c.Red / 255.0, c.Green / 255.0, c.Blue / 255.0,
                                  mat.Transparency, mat.Shininess, mat.Smoothness };
        }

        // Material.Create throws on a duplicate name, so derive a unique one.
        string UniqueMaterialName(string baseName) {
            var existing = new HashSet<string>(
                new FilteredElementCollector(doc).OfClass(typeof(Material))
                    .Cast<Material>().Select(m => m.Name));
            if (!existing.Contains(baseName)) return baseName;
            int i = 1;
            while (existing.Contains(baseName + " " + i)) i++;
            return baseName + " " + i;
        }

        // Conservative Revit material: a Material element with Color + Transparency
        // (no AppearanceAsset yet). `color` arrives as Autodesk.Revit.DB.Color via the
        // unified 4-float color codec (Channel.rColor); transparency is Revit's 0-100
        // channel. See the materials
        // design note (P2). PBR fields (metallic/roughness/etc.) are not mapped here.
        public Element CreateMaterial(string name, Color color, int transparency) {
            ElementId id = Material.Create(doc, UniqueMaterialName(name));
            Material mat = doc.GetElement(id) as Material;
            mat.Color = color;
            mat.Transparency = Math.Max(0, Math.Min(100, transparency));
            return mat;
        }

        public String InstalledLibraryPath(String kind) {
            string libraryPath = "";
            uiapp.Application.GetLibraryPaths().TryGetValue(kind, out libraryPath);
            return libraryPath;
        }

        /* LoadFamilyOptions controls what happens when a .rfa being loaded is already
         * present in the project. The previous implementation unconditionally returned
         * overwriteParameterValues = true, which silently clobbered any in-project edits
         * to family parameters every time a script touched the family. The default below
         * preserves existing parameter values; callers that genuinely want to replace the
         * project copy must opt in via LoadFamilyOptions(overwrite: true).
         */
        class LoadFamilyOptions : IFamilyLoadOptions {
            private readonly bool _overwrite;
            public LoadFamilyOptions(bool overwrite = false) { _overwrite = overwrite; }
            public bool OnFamilyFound(bool familyInUse, out bool overwriteParameterValues) {
                overwriteParameterValues = _overwrite;
                return true;
            }
            public bool OnSharedFamilyFound(Family sharedFamily, bool familyInUse, out FamilySource source, out bool overwriteParameterValues) {
                source = FamilySource.Family;
                overwriteParameterValues = _overwrite;
                return true;
            }
        }

        public Family LoadFamily(string fileName) {
            string key = Path.GetFullPath(fileName).ToLowerInvariant();
            Family family;
            if (!pathToFamily.TryGetValue(key, out family)) {
                if (!doc.LoadFamily(fileName, new LoadFamilyOptions(overwrite: false), out family)) {
                    throw new InvalidOperationException(
                        $"Failed to load family from '{fileName}'. Check that the path exists and is a valid .rfa.");
                }
                pathToFamily[key] = family;
            }
            return family;
        }

        /* Epsilon for matching FamilySymbol parameter values during type-symbol lookup.
         *
         * Units: Revit internal feet. 0.022 ft is approximately 6.7 mm.
         *
         * Why this magnitude:
         *   FamilyElementMatches decides whether a candidate FamilySymbol is "close enough"
         *   to the requested type-level parameters that we can reuse it instead of
         *   duplicating the symbol with a new "CustomFamily<n>" name.
         *   - If the bound is too tight (e.g. 0.001 ft = 0.3 mm) we fail to reuse symbols
         *     that differ only in floating-point round-trip noise after the
         *     metres-to-feet (to_feet) conversion in Julia, and the project accumulates
         *     thousands of duplicate symbols.
         *   - If the bound is too loose (e.g. 0.1 ft = 30 mm) we collapse legitimately
         *     distinct sizes (e.g. 600 mm and 700 mm columns) onto the same symbol.
         *   6.7 mm is well below the smallest dimensional step a designer would use to
         *   distinguish two architectural variants and well above the post-conversion
         *   round-trip drift of double precision.
         *
         * Scope:
         *   This is a *type-symbol* matching tolerance only — not a geometry tolerance.
         *   It is consulted exactly once, at family-symbol resolution time, by
         *   FamilyElementMatches.
         */
        private const double FamilyParamMatchEpsilonFeet = 0.022;

        bool FamilyElementMatches(FamilySymbol symb, string[] names, Length[] values) {
            for (int i = 0; i < names.Length; i++) {
                foreach (var parameter in symb.GetParameters(names[i])) {
                    double valueTest = parameter.AsDouble();
                    if (Math.Abs(valueTest - values[i]) > FamilyParamMatchEpsilonFeet) {
                        return false;
                    }
                }
            }
            return true;
        }
        public ElementId FamilyElement(Family family, string[] names, Length[] values) {
            if (family == null) {
                return ElementId.InvalidElementId;
            }
            Dictionary<string, FamilySymbol> loadedFamilySymbols;
            if (!loadedFamiliesSymbols.TryGetValue(family, out loadedFamilySymbols)) {
                loadedFamilySymbols = new Dictionary<string, FamilySymbol>();
                loadedFamiliesSymbols[family] = loadedFamilySymbols;
            }
            string parametersStr = "";
            for (int i = 0; i < names.Length; i++) {
                parametersStr += names[i] + ":" + values[i] + ",";
            }
            FamilySymbol familySymbol;
            if (!loadedFamilySymbols.TryGetValue(parametersStr, out familySymbol)) {
                familySymbol = family.GetFamilySymbolIds()
                    .Select(id => doc.GetElement(id) as FamilySymbol)
                    .FirstOrDefault(sym => FamilyElementMatches(sym, names, values));
                if (familySymbol == null) {
                    familySymbol = doc.GetElement(family.GetFamilySymbolIds().First()) as FamilySymbol;
                    string nName = "CustomFamily" + customFamilyCounter.ToString();
                    customFamilyCounter++;
                    familySymbol = familySymbol.Duplicate(nName) as FamilySymbol;
                    for (int i = 0; i < names.Length; i++) {
                        foreach (var parameter in familySymbol.GetParameters(names[i])) {
                            parameter.Set(values[i]);
                        }
                    }
                }
                loadedFamilySymbols[parametersStr] = familySymbol;
            }
            return familySymbol.Id;
        }
        // The profile's z is the floor's elevation above its level (a raised threshold slab is above
        // its floor level). Flatten the loop to the level plane and carry the offset via
        // FLOOR_HEIGHTABOVELEVEL — otherwise a non-zero contour z is silently dropped on rebuild.
        XYZ[] FlattenZ(XYZ[] pts) => pts.Select(p => new XYZ(p.X, p.Y, 0)).ToArray();
        double ProfileOffset(XYZ[] pts) => pts.Length > 0 ? pts[0].Z : 0;

        public ElementId CreatePolygonalFloor(XYZ[] pts, Level level, ElementId famId) {
            FloorType floorType = (famId != null && famId != ElementId.InvalidElementId) ?
                doc.GetElement(famId) as FloorType :
                new FilteredElementCollector(doc).OfClass(typeof(FloorType)).First() as FloorType;
            Floor floor = Floor.Create(doc, new List<CurveLoop> { PolygonCurveLoop(FlattenZ(pts)) }, floorType.Id, level.Id);
            floor.get_Parameter(BuiltInParameter.FLOOR_HEIGHTABOVELEVEL_PARAM).Set(ProfileOffset(pts));
            return floor.Id;
        }
        public ElementId CreatePathFloor(XYZ[] pts, double[] angles, Level level, ElementId famId) {
            FloorType floorType = (famId != null && famId != ElementId.InvalidElementId) ?
                doc.GetElement(famId) as FloorType :
                new FilteredElementCollector(doc).OfClass(typeof(FloorType)).First() as FloorType;
            Floor floor = Floor.Create(doc, new List<CurveLoop> { CurveLoopPath(FlattenZ(pts), angles) }, floorType.Id, level.Id);
            floor.get_Parameter(BuiltInParameter.FLOOR_HEIGHTABOVELEVEL_PARAM).Set(ProfileOffset(pts));
            return floor.Id;
        }
        /* Panels in Khepri are a 2D region extruded by a thickness. Revit has no
         * first-class "panel" element outside curtain-wall systems (the user explicitly
         * rejected curtain panels as the implementation strategy). DirectShape is the
         * supported Revit API for "geometry that does not fit a stock category" and
         * accepts arbitrary GeometryObject[]; we use OST_GenericModel as the default
         * category so panels appear in normal model views.
         *
         * The extrusion direction is the loop's plane normal. If `angles` is non-empty
         * the loop has arc segments and we go through CurveLoopPath; otherwise the loop
         * is straight-line through PolygonCurveLoop.
         */
        public ElementId CreatePanelExtrusion(XYZ[] pts, double[] angles, double thickness, ElementId catId) {
            CurveLoop loop = (angles == null || angles.Length == 0)
                ? PolygonCurveLoop(pts)
                : CurveLoopPath(pts, angles);
            Plane plane = loop.GetPlane();
            Solid solid = GeometryCreationUtilities.CreateExtrusionGeometry(
                new List<CurveLoop> { loop }, plane.Normal, thickness);
            ElementId category = (catId != null && catId != ElementId.InvalidElementId)
                ? catId
                : new ElementId(BuiltInCategory.OST_GenericModel);
            DirectShape ds = DirectShape.CreateElement(doc, category);
            ds.ApplicationId = "Khepri";
            ds.ApplicationDataId = "Panel";
            ds.SetShape(new GeometryObject[] { solid });
            ds.Name = "Panel";
            return ds.Id;
        }
        public ElementId CreatePolygonalRoof(XYZ[] pts, Level level, ElementId famId) {
            RoofType roofType = null;
            if (famId != null && famId != ElementId.InvalidElementId) {
                roofType = doc.GetElement(famId) as RoofType;
            } else {
                var roofTypeList = new FilteredElementCollector(doc).OfClass(typeof(RoofType));
                roofType = roofTypeList.FirstOrDefault(e =>
                    e.Name.Equals("Generic - 125mm") ||
                    e.Name.Equals("Generic Roof - 300mm")) as RoofType;
                if (roofType == null) {
                    roofType = roofTypeList.First() as RoofType;
                }
            }
            ModelCurveArray curveArray = new ModelCurveArray();
            FootPrintRoof roof = doc.Create.NewFootPrintRoof(PolygonalCurveArray(pts), level, roofType, out curveArray);
            return roof.Id;
        }
        public ElementId CreatePathRoof(XYZ[] pts, double[] angles, Level level, ElementId famId) {
            RoofType roofType = null;
            if (famId != null && famId != ElementId.InvalidElementId) {
                roofType = doc.GetElement(famId) as RoofType;
            } else {
                var roofTypeList = new FilteredElementCollector(doc).OfClass(typeof(RoofType));
                roofType = roofTypeList.FirstOrDefault(e =>
                    e.Name.Equals("Generic - 125mm") ||
                    e.Name.Equals("Generic Roof - 300mm")) as RoofType;
                if (roofType == null) {
                    roofType = roofTypeList.First() as RoofType;
                }
            }
            ModelCurveArray curveArray = new ModelCurveArray();
            FootPrintRoof roof = doc.Create.NewFootPrintRoof(ClosedPathCurveArray(pts, angles), level, roofType, out curveArray);
            return roof.Id;
        }
        public void CreatePolygonalOpening(XYZ[] pts, Element host) {
            //Either commit and start the transaction or else regenerate the document
            doc.Regenerate();
            doc.Create.NewOpening(host, PolygonalCurveArray(pts), false);
        }
        public void CreatePathOpening(XYZ[] pts, double[] angles, Element host) {
            //Either commit and start the transaction or else regenerate the document
            doc.Regenerate();
            doc.Create.NewOpening(host, ClosedPathCurveArray(pts, angles), false);
        }

        public Element CreateColumn(XYZ location, Level level0, Level level1, ElementId famId) {
            FamilySymbol symbol = (famId == null || famId == ElementId.InvalidElementId) ?
                GetFirstSymbol(FindCategoryFamilies(doc, BuiltInCategory.OST_Columns).FirstOrDefault()) :
                doc.GetElement(famId) as FamilySymbol;
            EnsureActive(symbol);
            FamilyInstance col = doc.Create.NewFamilyInstance(location, symbol, level0, StructuralType.Column);
            col.get_Parameter(BuiltInParameter.FAMILY_TOP_LEVEL_PARAM).Set(level1.Id);
            col.get_Parameter(BuiltInParameter.FAMILY_TOP_LEVEL_OFFSET_PARAM).Set(0.0);
            col.get_Parameter(BuiltInParameter.FAMILY_BASE_LEVEL_OFFSET_PARAM).Set(0.0);
            return col;
        }
        public Element CreateColumnPoints(XYZ p0, XYZ p1, Level level0, Level level1, ElementId famId) {
            FamilyInstance col = CreateColumn(p0, level0, level1, famId) as FamilyInstance;
            col.get_Parameter(BuiltInParameter.SLANTED_COLUMN_TYPE_PARAM).Set((int)SlantedOrVerticalColumnType.CT_Angle);
            LocationCurve lc = col.Location as LocationCurve;
            Curve nline = Line.CreateBound(p0, p1) as Curve;
            lc.Curve = nline;
            return col;
        }
        public ElementId CreateBeam(XYZ p0, XYZ p1, double rotationAngle, ElementId famId) {
            FamilySymbol symbol = null;
            if (famId == null || famId == ElementId.InvalidElementId) {
                Family defaultBeamFam = FindCategoryFamilies(doc, BuiltInCategory.OST_StructuralFraming).First();
                symbol = doc.GetElement(defaultBeamFam.GetFamilySymbolIds().First()) as FamilySymbol;
            } else {
                symbol = doc.GetElement(famId) as FamilySymbol;
            }
            EnsureActive(symbol);
            FamilyInstance beam = doc.Create.NewFamilyInstance(Line.CreateBound(p0, p1), symbol, null, StructuralType.Beam);
            if (rotationAngle != 0.0) {
                beam.get_Parameter(BuiltInParameter.STRUCTURAL_BEND_DIR_ANGLE).Set(rotationAngle);
            }
            return beam.Id;
        }
        // Used for family_element, toilet, sink, closet — element is hosted on either a
        // Level (point-based at level) or an Element with a face (wall, ceiling, floor).
        // Two pre-existing bugs are fixed here:
        //   1. famId == null (system family with no params) used to deref into GetElement(null).
        //      Now falls back to the first generic-model symbol, mirroring CreateColumn.
        //   2. host is sometimes a Level rather than a face-host. The (XYZ, FamilySymbol, XYZ,
        //      Element, StructuralType) NewFamilyInstance overload requires a face host;
        //      passing a Level there throws "host has no face". The (XYZ, FamilySymbol, Level,
        //      StructuralType) overload is the right one for level-only placement, so we
        //      pick the overload based on the runtime type of host.
        public Element CreateElementLocDirOnHost(XYZ location, XYZ direction, Element host, ElementId famId) {
            FamilySymbol symbol = (famId == null || famId == ElementId.InvalidElementId)
                ? GetFirstSymbol(FindCategoryFamilies(doc, BuiltInCategory.OST_GenericModel).FirstOrDefault())
                : doc.GetElement(famId) as FamilySymbol;
            if (symbol == null) {
                // Last resort on templates without generic-model families: any loadable symbol is a
                // better placeholder than aborting the caller (which may be realizing a whole group).
                symbol = new FilteredElementCollector(doc).OfClass(typeof(FamilySymbol))
                    .Cast<FamilySymbol>().FirstOrDefault();
            }
            if (symbol == null) {
                throw new InvalidOperationException(
                    "No family symbol available for hosted-instance placement (famId was null and the project has no family symbols at all).");
            }
            EnsureActive(symbol);
            FamilyInstance elem;
            if (host is Level lvl) {
                // location.Z is measured from the level. Prefer the UNHOSTED overload at the world
                // point: the Level overload silently zeroes XY for wall/face-hosted symbols placed
                // without a host (and resists MoveElement). Hosted-only symbols that reject the
                // unhosted overload fall back to the Level overload.
                XYZ world = new XYZ(location.X, location.Y, location.Z + lvl.Elevation);
                try {
                    elem = doc.Create.NewFamilyInstance(world, symbol, StructuralType.NonStructural);
                } catch {
                    elem = doc.Create.NewFamilyInstance(location, symbol, lvl, StructuralType.NonStructural);
                }
                try {
                    doc.Regenerate();
                    XYZ actual = (elem.Location as LocationPoint)?.Point;
                    if (actual != null && actual.DistanceTo(world) > 0.5) {
                        // Wall-based symbols ignore the point in both point overloads (xy collapses
                        // to the symbol origin) — they place correctly ONLY via the wall-host
                        // overload. Find the nearest wall and re-place hosted on it.
                        Wall hostWall = null;
                        double best = 3.0;   // feet (~0.9 m)
                        foreach (Wall w in new FilteredElementCollector(doc).OfClass(typeof(Wall)).Cast<Wall>()) {
                            var wlc = w.Location as LocationCurve;
                            if (wlc == null) continue;
                            // Horizontal distance: the location curve lies at the wall's base
                            // elevation while the instance point may be high on the wall (upper
                            // cabinets); a 3D distance would reject the host for tall placements.
                            // But walls on OTHER storeys share the same vertical plane, so the
                            // point must also fall within the wall's vertical span.
                            double baseZ = wlc.Curve.GetEndPoint(0).Z;
                            XYZ flat = new XYZ(world.X, world.Y, baseZ);
                            double dh = wlc.Curve.Distance(flat);
                            double topZ = baseZ +
                                (w.get_Parameter(BuiltInParameter.WALL_USER_HEIGHT_PARAM)?.AsDouble() ?? 0.0);
                            double dz = world.Z < baseZ ? baseZ - world.Z :
                                        world.Z > topZ ? world.Z - topZ : 0.0;
                            double d = Math.Sqrt(dh * dh + dz * dz);
                            if (d < best) { best = d; hostWall = w; }
                        }
                        if (hostWall != null) {
                            FamilyInstance TryVerify(Func<FamilyInstance> mk) {
                                try {
                                    FamilyInstance cand = mk();
                                    if (cand == null) return null;
                                    doc.Regenerate();
                                    XYZ a2 = (cand.Location as LocationPoint)?.Point;
                                    // Verify horizontally; hosted overloads may snap Z to the
                                    // symbol's default elevation, corrected below.
                                    if (a2 != null && new XYZ(a2.X, a2.Y, world.Z).DistanceTo(world) <= 1.5) {
                                        if (Math.Abs(a2.Z - world.Z) > 1e-4)
                                            try { ElementTransformUtils.MoveElement(doc, cand.Id, new XYZ(0, 0, world.Z - a2.Z)); } catch { }
                                        return cand;
                                    }
                                    doc.Delete(cand.Id);
                                } catch { }
                                return null;
                            }
                            Level wlvl = doc.GetElement(hostWall.LevelId) as Level;
                            FamilyInstance re =
                                TryVerify(() => doc.Create.NewFamilyInstance(
                                    world, symbol, hostWall, wlvl, StructuralType.NonStructural))
                                ?? TryVerify(() => {
                                    var sideRefs = HostObjectUtils.GetSideFaces(hostWall, ShellLayerType.Interior);
                                    if (sideRefs.Count == 0)
                                        sideRefs = HostObjectUtils.GetSideFaces(hostWall, ShellLayerType.Exterior);
                                    if (sideRefs.Count == 0) return null;
                                    Face face = hostWall.GetGeometryObjectFromReference(sideRefs[0]) as Face;
                                    XYZ onFace = world;
                                    if (face != null) {
                                        var proj = face.Project(world);
                                        if (proj != null) onFace = proj.XYZPoint;
                                    }
                                    var wc = (hostWall.Location as LocationCurve).Curve;
                                    XYZ tangent = (wc.GetEndPoint(1) - wc.GetEndPoint(0)).Normalize();
                                    return doc.Create.NewFamilyInstance(sideRefs[0], onFace, tangent, symbol) as FamilyInstance;
                                });
                            if (re != null) {
                                doc.Delete(elem.Id);
                                return re;
                            }
                        }
                        try { ElementTransformUtils.MoveElement(doc, elem.Id, world - actual); } catch { }
                    }
                } catch { }
            } else {
                elem = doc.Create.NewFamilyInstance(location, symbol, direction, host, StructuralType.NonStructural);
            }
            return elem;
        }
        // Group-member creation runs with auto-join suppressed: joining a member into the
        // surrounding loose geometry can fail regeneration (overlapping collinear walls next to a
        // parallel wall), and Revit then rolls the whole transaction back, silently deleting the
        // members. CreateGroup unjoins any cross-boundary joins anyway.
        private bool autoJoinEnabled = true;
        public void EnableAutoJoin(bool enable) { autoJoinEnabled = enable; }
        void MaybeAutoJoin() {
            // doc.AutoJoinElements() joins EVERYTHING, including walls inside groups — and editing
            // a grouped element outside group-edit mode makes Revit delete the group (silently,
            // because the failure processor dismisses warnings). Once groups exist, skip the join.
            if (autoJoinEnabled && !new FilteredElementCollector(doc).OfClass(typeof(Group)).Any())
                doc.AutoJoinElements();
        }

        public ElementId[] CreateLineWall(XYZ[] pts, ElementId baseLevelId, ElementId topLevelId, ElementId famId) {
            ElementId[] ids = new ElementId[pts.Length - 1];
            for (int i = 0; i < pts.Length - 1; i++) {
                Wall wall = Wall.Create(doc, Line.CreateBound(pts[i], pts[i + 1]), baseLevelId, false);
                if (famId != null && famId != ElementId.InvalidElementId) {
                    wall.WallType = doc.GetElement(famId) as WallType;
                }
                wall.get_Parameter(BuiltInParameter.WALL_HEIGHT_TYPE).Set(topLevelId);
                ids[i] = wall.Id;
            }
            // Joins coincident wall ends so corner geometry resolves correctly. Required
            // for multi-segment polygonal walls; verified by the multi-segment-wall test
            // in test/family_tests/walls_complex.jl.
            MaybeAutoJoin();
            return ids;
        }
        public ElementId[] CreateUnconnectedLineWall(XYZ[] pts, ElementId baseLevelId, double height, ElementId famId) {
            ElementId wallTypeId = doc.GetDefaultElementTypeId(ElementTypeGroup.WallType);
            ElementId[] ids = new ElementId[pts.Length - 1];
            for (int i = 0; i < pts.Length - 1; i++) {
                Wall wall = Wall.Create(doc, Line.CreateBound(pts[i], pts[i + 1]), wallTypeId, baseLevelId, height, 0, false, false);
                if (famId != null && famId != ElementId.InvalidElementId) {
                    wall.WallType = doc.GetElement(famId) as WallType;
                }
                ids[i] = wall.Id;
            }
            // Joins coincident wall ends so corner geometry resolves correctly. Required
            // for multi-segment polygonal walls; verified by the multi-segment-wall test
            // in test/family_tests/walls_complex.jl.
            MaybeAutoJoin();
            return ids;
        }
        List<Curve> OpenPathCurves(XYZ[] pts, double[] angles) {
            List<Curve> curves = new List<Curve>();
            for (int i = 0; i < angles.Length; i++) {
                if (angles[i] == 0) {
                    curves.Add(Line.CreateBound(pts[i], pts[i + 1]));
                } else {
                    curves.Add(ArcFromPointsAngle(pts[i], pts[i + 1], angles[i]));
                }
            }
            return curves;
        }
        public ElementId[] CreatePathWall(XYZ[] pts, double[] angles, ElementId baseLevelId, ElementId topLevelId, ElementId famId, bool isStructural) {
            List<Curve> curves = OpenPathCurves(pts, angles);
            ElementId[] ids = new ElementId[curves.Count];
            for (int i = 0; i < curves.Count; i++) {
                Wall wall = Wall.Create(doc, curves[i], baseLevelId, isStructural);
                if (famId != null && famId != ElementId.InvalidElementId) {
                    wall.WallType = doc.GetElement(famId) as WallType;
                }
                wall.get_Parameter(BuiltInParameter.WALL_HEIGHT_TYPE).Set(topLevelId);
                ids[i] = wall.Id;
            }
            MaybeAutoJoin();
            return ids;
        }
        public ElementId[] CreateUnconnectedPathWall(XYZ[] pts, double[] angles, ElementId baseLevelId, double height, ElementId famId) {
            ElementId wallTypeId = (famId != null && famId != ElementId.InvalidElementId) ?
                famId : doc.GetDefaultElementTypeId(ElementTypeGroup.WallType);
            List<Curve> curves = OpenPathCurves(pts, angles);
            ElementId[] ids = new ElementId[curves.Count];
            for (int i = 0; i < curves.Count; i++) {
                Wall wall = Wall.Create(doc, curves[i], wallTypeId, baseLevelId, height, 0, false, false);
                ids[i] = wall.Id;
            }
            MaybeAutoJoin();
            return ids;
        }
        public Element CreateArcWall(XYZ center, Length radius, double startAngle, double endAngle, ElementId baseLevelId, ElementId topLevelId, ElementId famId) {
            Arc arc = Arc.Create(center, radius, startAngle, endAngle, XYZ.BasisX, XYZ.BasisY);
            Wall wall = Wall.Create(doc, arc, baseLevelId, false);
            if (famId != null && famId != ElementId.InvalidElementId) {
                wall.WallType = doc.GetElement(famId) as WallType;
            }
            wall.get_Parameter(BuiltInParameter.WALL_HEIGHT_TYPE).Set(topLevelId);
            return wall;
        }
        public Element CreateUnconnectedArcWall(XYZ center, Length radius, double startAngle, double endAngle, ElementId baseLevelId, double height, ElementId famId) {
            ElementId wallTypeId = (famId != null && famId != ElementId.InvalidElementId) ?
                famId : doc.GetDefaultElementTypeId(ElementTypeGroup.WallType);
            Arc arc = Arc.Create(center, radius, startAngle, endAngle, XYZ.BasisX, XYZ.BasisY);
            Wall wall = Wall.Create(doc, arc, wallTypeId, baseLevelId, height, 0, false, false);
            return wall;
        }
        public ElementId[] CreatePathCurtainWall(XYZ[] pts, double[] angles, ElementId baseLevelId, ElementId topLevelId, ElementId famId, bool isStructural) {
            // Resolve the curtain-wall type robustly: prefer the passed family; else any curtain-kind
            // type ("M_Storefront"/"Curtain Wall"); else the document's default wall type — so this works
            // on any template, not only ones that happen to contain a type named "M_Storefront".
            WallType wallType = (famId != null && famId != ElementId.InvalidElementId) ?
                doc.GetElement(famId) as WallType : null;
            if (wallType == null) {
                var types = new FilteredElementCollector(doc).OfClass(typeof(WallType)).Cast<WallType>().ToList();
                wallType = types.FirstOrDefault(q => q.Name == "M_Storefront")
                        ?? types.FirstOrDefault(q => q.Kind == WallKind.Curtain)
                        ?? doc.GetElement(doc.GetDefaultElementTypeId(ElementTypeGroup.WallType)) as WallType;
            }
            CurveArray curves = PathCurveArray(pts, angles);
            List<ElementId> ids = new List<ElementId>();
            foreach (Curve curve in curves) {
                Wall wall = Wall.Create(doc, curve, baseLevelId, isStructural);
                if (wallType != null) wall.WallType = wallType;
                ids.Add(wall.Id);
                wall.get_Parameter(BuiltInParameter.WALL_HEIGHT_TYPE).Set(topLevelId);
            }
            CurrentTransaction.Commit();
            CurrentTransaction.Start();
            MaybeAutoJoin();
            return ids.ToArray();
        }

        // NOTE: Revit walls only support straight-line and arc location curves, so spline/Hermite
        // wall location curves are intentionally not implemented (no CreateSplineWall op).
        //Introspection
        public XYZ[] LineWallVertices(Element element) {
            Wall wall = (Wall)element;
            Line l = (wall.Location as LocationCurve).Curve as Line;
            return new XYZ[] { l.GetEndPoint(0), l.GetEndPoint(1) };
        }
        // Instance name of any element (e.g. a Level's "Piso 1") — level HEIGHTS alone cannot
        // distinguish named storeys for selective execution.
        public string ElementName(Element element) => element.Name ?? "";
        public ElementId ElementLevel(Element element) => element.LevelId;
        // Walls can have unconnected height
        public ElementId WallTopLevel(Element element) => 
            element.get_Parameter(BuiltInParameter.WALL_HEIGHT_TYPE).AsElementId();
        // Wrap in Length so the channel converts Revit-internal feet → metres; returning a bare double
        // sent the raw feet value, which wall_from_ref then added to a metre level height (a ~3.28x-too-
        // tall "spike" wall for unconnected-top walls).
        public Length WallHeight(Element element) =>
            new Length(element.get_Parameter(BuiltInParameter.WALL_USER_HEIGHT_PARAM).AsDouble());

        public Element InsertDoor(Length deltaFromStart, Length deltaFromGround, Element host, ElementId familyId) {
            LocationCurve locCurve = host.Location as LocationCurve;
            XYZ start = locCurve.Curve.GetEndPoint(0);
            XYZ dir = locCurve.Curve.GetEndPoint(1) - start;
            XYZ location = start + dir.Normalize() * deltaFromStart;
            FamilySymbol symbol = (familyId == null || familyId == ElementId.InvalidElementId) ?
                GetFirstSymbol(FindCategoryFamilies(doc, BuiltInCategory.OST_Doors).FirstOrDefault()) :
                doc.GetElement(familyId) as FamilySymbol;
            EnsureActive(symbol);
            FamilyInstance door = doc.Create.NewFamilyInstance(location, symbol, host,
                host.Document.GetElement(host.LevelId) as Level,
                StructuralType.NonStructural);
            door.get_Parameter(BuiltInParameter.INSTANCE_SILL_HEIGHT_PARAM)?.Set(deltaFromGround);
            return door;
        }

        // Same as InsertDoor but additionally applies arbitrary instance parameters via
        // names/values (mirrors InsertWindow). Kept additive so existing callers of the
        // 4-arg InsertDoor continue to work; Julia routes here when a door family
        // declares a non-empty instance_map.
        public Element InsertDoorWithParams(Length deltaFromStart, Length deltaFromGround, Element host, ElementId familyId, string[] names, object[] values) {
            LocationCurve locCurve = host.Location as LocationCurve;
            XYZ start = locCurve.Curve.GetEndPoint(0);
            XYZ dir = locCurve.Curve.GetEndPoint(1) - start;
            XYZ location = start + dir.Normalize() * deltaFromStart.Value;
            FamilySymbol symbol = (familyId == null || familyId == ElementId.InvalidElementId) ?
                GetFirstSymbol(FindCategoryFamilies(doc, BuiltInCategory.OST_Doors).FirstOrDefault()) :
                doc.GetElement(familyId) as FamilySymbol;
            symbol = EnsureSymbolForTypeParams(symbol, names, values);
            EnsureActive(symbol);
            FamilyInstance door = doc.Create.NewFamilyInstance(location, symbol, host,
                host.Document.GetElement(host.LevelId) as Level,
                StructuralType.NonStructural);
            door.get_Parameter(BuiltInParameter.INSTANCE_SILL_HEIGHT_PARAM)?.Set(deltaFromGround);
            SetParameters(door, names, values);
            // Force Revit to flush the just-placed instance's geometry and location
            // into the document graph. Without this, queries against the new door —
            // `Location.Point`, `GetTotalTransform()`, `get_BoundingBox(null)` — all
            // return host-local placeholders or null until the next document update,
            // and `HostedElementPosition` projects from the wrong point. Calling
            // `Regenerate` here makes the placement readable in the same RPC batch.
            doc.Regenerate();
            return door;
        }

        static void SetParameter(Parameter p, object value) {
            switch (p.StorageType) {
                case StorageType.None:
                    break;
                case StorageType.Double:
                    p.Set(Convert.ToDouble(value));
                    break;
                case StorageType.Integer:
                    p.Set(Convert.ToInt32(value));
                    break;
                case StorageType.ElementId:
                    p.Set(value as ElementId);
                    break;
                case StorageType.String:
                    p.Set(value.ToString());
                    break;
            }
        }

        /* SetParameters applies a names/values list to a FamilyInstance after placement.
         *
         * obj.GetParameters(name) only returns INSTANCE-level parameters with that name.
         * If a name happens to be a TYPE-level parameter (defined on the FamilySymbol,
         * not the instance), the foreach iterates zero times and the value is silently
         * dropped. That used to be the failure mode for the default door family in
         * KhepriTemplate.rte, where Width/Height live on the symbol — every InsertDoor
         * call would place a door at the symbol's default 0.9 m / 2.1 m regardless of
         * the user's `door_family(width=..., height=...)`.
         *
         * The fix is upstream: callers run `EnsureSymbolForTypeParams(symbol, names,
         * values)` *before* placing the instance. That helper duplicates the symbol with
         * the type-level values baked in (or reuses a cached duplicate), so by the time
         * SetParameters runs here, every name in `names` is either an instance parameter
         * (which this method will set correctly) or a no-op already absorbed by the
         * symbol duplication.
         *
         * We keep this method simple — instance-only — to avoid the surprise of mutating
         * a shared symbol mid-batch and silently changing every other instance pointing
         * at it. Type-level handling is deliberately confined to the symbol-resolution
         * phase.
         *
         * See also: EnsureSymbolForTypeParams, FamilyElement (the same duplication
         * pattern for explicit type-level family ops).
         */
        static void SetParameters(FamilyInstance obj, string[] names, object[] values) {
            for (int i = 0; i < names.Length; i++) {
                foreach (var parameter in obj.GetParameters(names[i])) {
                    SetParameter(parameter, values[i]);
                }
            }
        }

        /* Returns a FamilySymbol with the requested type-level parameter values applied,
         * possibly by duplicating the original symbol.
         *
         * Why this exists:
         *   The user sends a flat (names, values) list intended for "set this Width on
         *   the placed door". For families where Width is an INSTANCE parameter (e.g.
         *   M_Instance-Window-Fixed.rfa) the existing post-placement SetParameters
         *   handles it. For families where Width is a TYPE parameter (e.g. the default
         *   project-template door), SetParameters silently does nothing because
         *   `instance.GetParameters("Width")` returns empty. The result is a placed
         *   door of the *symbol's* default size, with the user's value dropped.
         *
         *   We fix that asymmetry here: any name that resolves on the symbol is
         *   classified as a type parameter; we duplicate the symbol with those values
         *   baked in (matching the FamilyElement pattern) and return the new symbol so
         *   the instance is placed off it. Names that don't resolve on the symbol are
         *   left in `names` for SetParameters to handle as instance params.
         *
         * Why a cache:
         *   Without caching, every `door_family(width=1.1)` call would create a fresh
         *   "CustomFamily<n>" symbol — the project would accumulate identical
         *   duplicates and Revit's Project Browser would fill up. The cache key is the
         *   sorted "name:value,..." string, so two calls with the same parameter set
         *   share a symbol. This mirrors `FamilyElement` and reuses the
         *   `loadedFamiliesSymbols` table that already serves type-level family ops.
         *
         * Tolerance:
         *   `FamilyParamMatchEpsilonFeet` (~6.7 mm) lets us also reuse a project's own
         *   pre-existing FamilySymbols (e.g. the "0900 x 2100" door type that the
         *   template ships with) when the requested values match within
         *   round-trip-noise of metres-to-feet conversion. Avoids needless duplicates
         *   for designs that happen to land on stock dimensions.
         *
         * See also: FamilyElement, FamilyElementMatches, SetParameters.
         */
        FamilySymbol EnsureSymbolForTypeParams(FamilySymbol original, string[] names, object[] values) {
            if (original == null || names.Length == 0) return original;
            var typeNames = new List<string>();
            var typeValues = new List<double>();
            for (int i = 0; i < names.Length; i++) {
                var p = original.LookupParameter(names[i]);
                if (p != null && p.StorageType == StorageType.Double) {
                    typeNames.Add(names[i]);
                    typeValues.Add(Convert.ToDouble(values[i]));
                }
            }
            if (typeNames.Count == 0) return original;
            Family family = original.Family;
            if (family == null) return original;
            if (!loadedFamiliesSymbols.TryGetValue(family, out var loadedSymbols)) {
                loadedSymbols = new Dictionary<string, FamilySymbol>();
                loadedFamiliesSymbols[family] = loadedSymbols;
            }
            var keyParts = new List<string>();
            for (int i = 0; i < typeNames.Count; i++) {
                keyParts.Add(typeNames[i] + ":" + typeValues[i].ToString("R"));
            }
            keyParts.Sort();
            string key = string.Join(",", keyParts);
            if (loadedSymbols.TryGetValue(key, out var cached)) return cached;
            FamilySymbol match = family.GetFamilySymbolIds()
                .Select(id => doc.GetElement(id) as FamilySymbol)
                .FirstOrDefault(sym => MatchesTypeParams(sym, typeNames, typeValues));
            if (match == null) {
                string newName = "CustomFamily" + customFamilyCounter.ToString();
                customFamilyCounter++;
                match = original.Duplicate(newName) as FamilySymbol;
                if (match == null) return original;
                for (int i = 0; i < typeNames.Count; i++) {
                    foreach (var p in match.GetParameters(typeNames[i])) {
                        p.Set(typeValues[i]);
                    }
                }
            }
            loadedSymbols[key] = match;
            return match;
        }

        static bool MatchesTypeParams(FamilySymbol sym, List<string> names, List<double> values) {
            for (int i = 0; i < names.Count; i++) {
                var p = sym.LookupParameter(names[i]);
                if (p == null) return false;
                if (Math.Abs(p.AsDouble() - values[i]) > FamilyParamMatchEpsilonFeet) return false;
            }
            return true;
        }

        public Element InsertWindow(Length deltaFromStart, Length deltaFromGround, Element host, ElementId familyId, string[] names, object[] values) {
            LocationCurve locCurve = host.Location as LocationCurve;
            XYZ start = locCurve.Curve.GetEndPoint(0);
            XYZ dir = locCurve.Curve.GetEndPoint(1) - start;
            XYZ location = start + dir.Normalize() * deltaFromStart.Value;
            FamilySymbol symbol = (familyId == null || familyId == ElementId.InvalidElementId) ?
                GetFirstSymbol(FindCategoryFamilies(doc, BuiltInCategory.OST_Windows).FirstOrDefault()) :
                doc.GetElement(familyId) as FamilySymbol;
            symbol = EnsureSymbolForTypeParams(symbol, names, values);
            EnsureActive(symbol);
            FamilyInstance window = doc.Create.NewFamilyInstance(location, symbol, host,
                host.Document.GetElement(host.LevelId) as Level,
                StructuralType.NonStructural);
            window.get_Parameter(BuiltInParameter.INSTANCE_SILL_HEIGHT_PARAM)?.Set(deltaFromGround);
            SetParameters(window, names, values);
            // Mirrors InsertDoorWithParams: force geometry/location flush so
            // subsequent reads see the world-coords placement.
            doc.Regenerate();
            return window;
        }
        // Place a railing FamilyInstance at an explicit point. Use this when there is no
        // path (e.g. the railing is pinned to a host stair/floor and Revit derives its
        // geometry from the host) but a sensible anchor is still required. Prefer
        // CreateLineRailing / CreatePolygonRailing whenever a path is available.
        public Element InsertRailingAt(XYZ location, Element host, ElementId familyId) {
            FamilySymbol symbol = (familyId == null || familyId == ElementId.InvalidElementId) ?
                GetFirstSymbol(FindCategoryFamilies(doc, BuiltInCategory.OST_StairsRailing).FirstOrDefault()) :
                doc.GetElement(familyId) as FamilySymbol;
            EnsureActive(symbol);
            return doc.Create.NewFamilyInstance(location, symbol, host,
                host.Document.GetElement(host.LevelId) as Level,
                StructuralType.NonStructural);
        }
        // Backwards-compatible: routes to InsertRailingAt with the host curve midpoint
        // when available, falling back to origin. Replaces the previous hardcoded
        // (10, 10, 0) anchor that produced railings in arbitrary locations.
        public Element InsertRailing(Element host, ElementId familyId) {
            XYZ anchor = (host.Location is LocationCurve lc) ? lc.Curve.Evaluate(0.5, true) : XYZ.Zero;
            return InsertRailingAt(anchor, host, familyId);
        }
        public Element CreateLineRailing(XYZ[] pts, ElementId baseLevelId, ElementId familyId) {
            ElementId railingTypeId = (familyId != null && familyId != ElementId.InvalidElementId) ?
                familyId :
                new FilteredElementCollector(doc)
                    .OfClass(typeof(RailingType))
                    .ToElementIds().First();
            return Railing.Create(doc, LineCurveLoop(pts), railingTypeId, baseLevelId);
        }
        public Element CreatePolygonRailing(XYZ[] pts, ElementId baseLevelId, ElementId familyId) {
            ElementId railingTypeId = (familyId != null && familyId != ElementId.InvalidElementId) ?
                familyId :
                new FilteredElementCollector(doc)
                    .OfClass(typeof(RailingType))
                    .ToElementIds().First();
            return Railing.Create(doc, PolygonCurveLoop(pts), railingTypeId, baseLevelId);
        }
        const string familyTemplateExt = ".rft";
        const string rfaExt = ".rfa";
        const string familyTemplatesPath = "C:/ProgramData/Autodesk/RVT 2017/Family Templates/English";
        const string familyTemplateName = "Metric Structural Stiffener";
        const string familyName = "Stiffener";

        //Family Creation
        public void CreateFamily(string familyTemplatesPath, string familyTemplateName, string familyName) {
            WithSuspendedTransaction(() => {
                Family family = new FilteredElementCollector(doc)
                    .OfClass(typeof(Family)).Cast<Family>()
                    .FirstOrDefault<Family>(e => e.Name.Equals(familyName));
                familyDoc = family?.Document ??
                    uiapp.Application.NewFamilyDocument(Path.Combine(familyTemplatesPath, familyTemplateName + familyTemplateExt));
            });
        }

        public void CreateFamilyExtrusionTest(XYZ[] pts, double height) {
            using (Transaction t = new Transaction(familyDoc)) {
                t.Start("Family Creation");
                Creation.FamilyItemFactory factory = familyDoc.FamilyCreate;
                SketchPlane sketch = new FilteredElementCollector(familyDoc).OfClass(typeof(SketchPlane))
                    .First<Element>(e => e.Name.Equals("Ref. Level")) as SketchPlane;
                CurveArrArray curveArrArray = new CurveArrArray();
                curveArrArray.Append(PolygonalCurveArray(pts));
                factory.NewExtrusion(true, curveArrArray, sketch, height);
                t.Commit();
            }
        }

        public void InsertFamily(string familyName, XYZ p) {
            CurrentTransaction.Commit();
            Family family = familyDoc.LoadFamily(doc);
            FamilySymbol symbol = GetFirstSymbol(family);
            CurrentTransaction.Start();
            family.Name = familyName;
            symbol.Name = familyName;
            symbol.Activate();
            doc.Create.NewFamilyInstance(p, symbol, StructuralType.UnknownFraming);
        }

        public void ChangeElementMaterial(Element element, ElementId materialId) {
            Wall w = (Wall)element;
            WallType wt = w.WallType;
            WallType nwt;
            IList<WallType> desiredType = new FilteredElementCollector(doc)
                .OfClass(typeof(WallType))
                .Cast<WallType>()
                .Where<WallType>(wallType => wallType.Name.Equals("MyWall")).ToList<WallType>();
            if (desiredType.Count == 0) {
                nwt = wt.Duplicate("MyWall") as WallType;
                CompoundStructure cs = nwt.GetCompoundStructure();
                IList<CompoundStructureLayer> layers = nwt.GetCompoundStructure().GetLayers();
                int layerIndex = 0;
                foreach (CompoundStructureLayer l in layers) {
                    cs.SetMaterialId(layerIndex, materialId);
                    layerIndex++;
                }
                nwt.SetCompoundStructure(cs);
            } else {
                nwt = desiredType.First();
            }
            w.WallType = nwt;
        }

        public void HighlightElement(ElementId id) =>
            uiapp.ActiveUIDocument.Selection.SetElementIds(new List<ElementId> { id });

        public ElementId[] GetSelectedElements() =>
            uiapp.ActiveUIDocument.Selection.GetElementIds().ToArray();

        public bool IsProject() => !doc.IsFamilyDocument;

        public View3D GetView3D() {
            const string khepriName = "Khepri-3D";
            View3D view3D = new FilteredElementCollector(doc).OfClass(typeof(Autodesk.Revit.DB.View)).FirstOrDefault(v => v.Name == khepriName) as View3D;
            if (view3D == null) {
                var viewFamilyType = new FilteredElementCollector(doc)
                    .OfClass(typeof(ViewFamilyType))
                    .Cast<ViewFamilyType>()
                    .First(type => type.ViewFamily == ViewFamily.ThreeDimensional);
                view3D = View3D.CreatePerspective(doc, viewFamilyType.Id);
                view3D.Name = khepriName;
                view3D.CropBoxActive = false;
            }
            return view3D;
        }
        public XYZ GetCamera() {
            var view3d = GetView3D(); 
            return view3d.GetOrientation().EyePosition;
        }
        public XYZ GetTarget() {
            var view3d = GetView3D();
            var orientation = view3d.GetOrientation();
            return orientation.EyePosition + orientation.ForwardDirection;
        }
        public double GetLens() {
            var view3d = GetView3D();
            var p = view3d.CropBox.Max;
            return -p.Z*36/2/p.X;
        }

        public void SetView(XYZ camera, XYZ target, int width, int height, double lens) {
            //Do we have our own 3D view?
            View3D view3D = GetView3D();

            double Zmax = -0.1;
            double Xmax = -Zmax*36/2/lens;
            double Ymax = -Zmax*36/2/lens*height/width;
            var CalcPointMax = new XYZ(Xmax, Ymax, Zmax);
            double Xmin = -Xmax;
            double Ymin = -Ymax;
            double Zmin = Zmax * 1000;

            var CalcPointMin = new XYZ(Xmin, Ymin, Zmin);
            var NewCrop = new BoundingBoxXYZ();
            NewCrop.Min = CalcPointMin;
            NewCrop.Max = CalcPointMax;
            /*if (!view3D.CropBoxActive) {
                view3D.CropBoxActive = true;
            }*/
            view3D.CropBox = NewCrop;
            XYZ eye = camera;
            XYZ forward = (target - camera).Normalize();
            XYZ up = new XYZ(0, 0, 1);
            up = forward.CrossProduct(up).CrossProduct(forward);
            view3D.SetOrientation(new ViewOrientation3D(eye, up, forward));
            view3D.CropBoxActive = false;
            WithSuspendedTransaction(() => {
                uiapp.ActiveUIDocument.ActiveView = view3D;
                uiapp.ActiveUIDocument.RefreshActiveView();
                UIDocument uidoc = uiapp.ActiveUIDocument;
                UIView uiview = uidoc.GetOpenUIViews().First(uv => uv.ViewId.Equals(view3D.Id));
                uiview.ZoomSheetSize();
            });
        }

        public void ViewSize(int width, int height) {
            SetWindowPos(uiapp.MainWindowHandle, IntPtr.Zero, 0, 0, width, height, SWP_NOMOVE | SWP_NOZORDER);
        }

        public void RenderView(string path) {
            View3D view = uiapp.ActiveUIDocument.ActiveView as View3D;
            view.DisplayStyle = DisplayStyle.Realistic;
            view.DetailLevel = ViewDetailLevel.Fine;
            view.SunAndShadowSettings.SunAndShadowType = SunAndShadowType.Lighting;
            view.SetBackground(ViewDisplayBackground.CreateSky());
            WithSuspendedTransaction(() => {
                var options = new ImageExportOptions();
                options.ExportRange = ExportRange.VisibleRegionOfCurrentView;
                options.FilePath = path;
                options.ShadowViewsFileType = (Path.GetExtension(path) == ".png") ?
                    ImageFileType.PNG :
                    ImageFileType.JPEGLossless;
                doc.ExportImage(options);
            });
        }

        public List<Element> AllElements() {
            List<Element> elements = new List<Element>();
            FilteredElementCollector collector = new FilteredElementCollector(doc).WhereElementIsNotElementType();
            foreach (Element e in collector) {
                if (e.Category != null && e.Category.HasMaterialQuantities) {
                    elements.Add(e);
                }
            }
            return elements;
        }
        // Collect ids before deleting. Iterating AllElements() while calling doc.Delete()
        // invalidates hosted elements (e.g. doors hosted on a wall whose wall was just
        // deleted), and the next iteration step throws InvalidObjectException on
        // Element.get_Id(). Snapshotting ids and tolerating already-deleted ids gives a
        // clean reset that test harnesses can rely on.
        public void DeleteAllElements() {
            var ids = AllElements().Select(e => e.Id).ToList();
            foreach (var id in ids) {
                try {
                    if (doc.GetElement(id) != null) {
                        doc.Delete(id);
                    }
                } catch (Autodesk.Revit.Exceptions.ApplicationException) {
                    // Already deleted as a dependent of a prior Delete; safe to ignore.
                }
            }
        }
        public void DeleteElement(Element element) {
            doc.Delete(element.Id);
        }
        // Group the given elements into a real Revit group and return the group instance id, so a
        // reconstructed Khepri group_instance is a genuine Revit group (its members are excluded from
        // DocWalls/etc.) rather than loose elements.
        // Diagnostic: how many of these ids no longer resolve to a live element.
        public int CountDeadElements(ElementId[] ids) =>
            ids.Count(id => doc.GetElement(id) == null);
        public ElementId CreateGroup(ElementId[] ids) {
            // A grouped stair drags its auto-generated railings in via Revit's parent resolution
            // (shouldElementBeAddedToGroupByParent), which crashes when they are not in the list —
            // include them explicitly. If NewGroup still fails, retry without the stairs (a group
            // missing its stair beats no group), else give up gracefully with InvalidElementId.
            var all = new List<ElementId>(ids);
            foreach (var id in ids) {
                if (doc.GetElement(id) is Autodesk.Revit.DB.Architecture.Stairs) {
                    all.AddRange(new FilteredElementCollector(doc)
                        .OfClass(typeof(Autodesk.Revit.DB.Architecture.Railing))
                        .Cast<Autodesk.Revit.DB.Architecture.Railing>()
                        .Where(r => r.HasHost && r.HostId == id)
                        .Select(r => r.Id));
                }
            }
            var members = all.Distinct().ToList();
            ElementId TryNewGroup(List<ElementId> ids2) {
                using (SubTransaction st = new SubTransaction(doc)) {
                    st.Start();
                    try {
                        var g = doc.Create.NewGroup(ids2);
                        st.Commit();
                        return g.Id;
                    } catch (Exception ex) {
                        st.RollBack();
                        try {
                            System.IO.File.AppendAllText(
                                System.IO.Path.Combine(System.IO.Path.GetTempPath(), "KhepriRevit.log"),
                                "[NewGroup] " + ids2.Count + " members: " + ex.GetType().Name + ": " + ex.Message + "\n");
                        } catch { }
                        return ElementId.InvalidElementId;
                    }
                }
            }
            // A member still geometry-joined to a NON-member is the classic trigger for the
            // native crash inside NewGroup's parent resolution — and semantically a grouped
            // element should not stay joined across the group boundary anyway. This applies to
            // every joinable member (walls AND floors/slabs/roofs: AutoJoin during creation joins
            // a group's slab to adjacent loose elements just as readily as its walls).
            var memberSet = new HashSet<ElementId>(members);
            foreach (var id in members) {
                var el = doc.GetElement(id);
                if (el == null) continue;
                ICollection<ElementId> joined;
                try { joined = JoinGeometryUtils.GetJoinedElements(doc, el); } catch { continue; }
                foreach (var otherId in joined.ToList()) {
                    if (!memberSet.Contains(otherId)) {
                        var other = doc.GetElement(otherId);
                        if (other != null)
                            try { JoinGeometryUtils.UnjoinGeometry(doc, el, other); } catch { }
                    }
                }
            }
            // Regeneration between creation and deferred finalize can invalidate members (join
            // merges, hosted-element cascades); a dead id inside NewGroup is a native crash, not
            // a managed exception. Group what still exists.
            members = members.Where(id => doc.GetElement(id) != null).ToList();
            ElementId first = TryNewGroup(members);
            if (first != ElementId.InvalidElementId) return first;
            try {
                var roster = string.Join("; ", members.Select(id => {
                    var el = doc.GetElement(id);
                    return id.Value + ":" + (el == null ? "DEAD" :
                        el.GetType().Name + "/" + (el.Category?.Name ?? "?") + "@lvl" + el.LevelId.Value);
                }));
                System.IO.File.AppendAllText(
                    System.IO.Path.Combine(System.IO.Path.GetTempPath(), "KhepriRevit.log"),
                    "[NewGroup] roster: " + roster + "\n");
            } catch { }
            // Leave-one-out retry: some member combinations crash Revit's internal parent
            // resolution; dropping the single poison member (which stays a loose element)
            // preserves the rest of the group. Each attempt is sub-transaction isolated so a
            // thrown NewGroup cannot leave members partially mutated.
            for (int skip = 0; skip < members.Count; skip++) {
                var subset = members.Where((_, idx) => idx != skip).ToList();
                if (subset.Count == 0) continue;
                ElementId gid = TryNewGroup(subset);
                if (gid != ElementId.InvalidElementId) return gid;
            }
            return ElementId.InvalidElementId;
        }
        // Additional instance of an existing group type (source models share one GroupType across
        // repeated instances; recreating each instance as its own NewGroup broke that identity).
        public ElementId PlaceGroupInstance(XYZ p, ElementId groupTypeId) {
            GroupType gt = doc.GetElement(groupTypeId) as GroupType;
            return doc.Create.PlaceGroup(p, gt).Id;
        }
        // The created group's own placement point, so repeat instances can be placed at
        // first-origin + instance-delta.
        public XYZ GroupPlacementPoint(Element group) =>
            (group.Location as LocationPoint)?.Point ?? XYZ.Zero;
        public static IOrderedEnumerable<Level> FindAndSortLevels(Document doc) =>
            new FilteredElementCollector(doc)
            .WherePasses(new ElementClassFilter(typeof(Level), false))
            .Cast<Level>()
            .OrderBy(e => e.Elevation);

        //Introspection
        /*
        Quick Filters

        ElementCategoryFilter: Elements matching the input category id; shortcut OfCategoryId
        ElementClassFilter: Elements matching the input runtime class; shortcut OfClass
        ElementIsElementTypeFilter: Elements which are "Element types" (symbols); shortcuts WhereElementIsElementType, WhereElementIsNotElementType
        ElementOwnerViewFilter: Elements which are view-specific; shortcuts OwnedByView, WhereElementIsViewIndependent
        ElementDesignOptionFilter: Elements in a particular design option; shortcut ContainedInDesignOption
        ElementIsCurveDrivenFilter: Elements which are curve driven; shortcut WhereElementIsCurveDriven
        ElementStructuralTypeFilter: Elements matching the given structural type ; no shortcut
        FamilySymbolFilter: Symbols of a particular family; no shortcut
        ExclusionFilter: All elements except the element ids input to the filter; shortcut Excluding
        BoundingBoxIntersectsFilter: Elements which have a bounding box which intersects a given outline; no shortcut
        BoundingBoxIsInsideFilter: Elements which have a bounding box inside a given outline; no shortcut
        BoundingBoxContainsPointFilter: Elements which have a bounding box that contain a given point; no shortcut

        Slow Filters

        FamilyInstanceFilter: Instances of a particular family symbol
        ElementLevelFilter: Elements associated to a given level id
        ElementParameterFilter: Parameter existence, value matching, range matching, and/or string matching
        PrimaryDesignOptionMemberFilter: Elements owned by any primary design option
        StructuralInstanceUsageFilter: Structural usage parameter for FamilyInstances
        StructuralWallUsageFilter: Structural usage parameter for Walls
        StructuralMaterialTypeFilter: Material type applied to FamilyInstances
        RoomFilter: Finds rooms
        SpaceFilter: Finds spaces
        AreaFilter: Finds areas
        RoomTagFilter: Finds room tags
        SpaceTagFilter: Finds space tags
        AreaTagFilter: Finds area tags
        CurveElementFilter: Finds specific types of curve elements (model curves, symbolic curves, detail curves, etc.)
        */

        public Level[] DocLevels() => FindAndSortLevels(doc).ToArray();

        public Element[] DocElements() => AllElements().ToArray();

        public Element[] DocFamilies() => (new FilteredElementCollector(doc).OfClass(typeof(Family))).ToArray();

        public Element[] DocFloors() => (new FilteredElementCollector(doc).OfClass(typeof(Floor)))
            .Where(e => !IsGroupMember(e)).ToArray();

        public Element[] DocCeilings() => (new FilteredElementCollector(doc).OfClass(typeof(Ceiling)))
            .Where(e => !IsGroupMember(e)).ToArray();

        // The member walls of a stacked wall, so introspection can claim them (the parent represents
        // them; unclaimed they would double-emit as fallback meshes).
        public ElementId[] StackedWallMemberIds(Element element) {
            try {
                Wall w = element as Wall;
                return (w != null && w.IsStackedWall) ?
                    w.GetStackedWallMemberIds().ToArray() : new ElementId[0];
            } catch { return new ElementId[0]; }
        }
        // Stacked-wall MEMBERS are excluded: the stacked parent already carries the full curve and
        // height, so reading members too duplicates every stacked wall's geometry (inflated counts,
        // overlapping walls on rebuild).
        public Element[] DocWalls() =>
            (new FilteredElementCollector(doc).OfClass(typeof(Wall)))
            .Cast<Wall>()
            .Where(w => w.Location is LocationCurve && !IsGroupMember(w) && !w.IsStackedWallMember)
            .Cast<Element>()
            .ToArray();
        public Element[] DocWallsAtLevel(Level level) =>
            (new FilteredElementCollector(doc).OfClass(typeof(Wall)))
            .WherePasses(new ElementLevelFilter(level.Id))
            .Cast<Wall>()
            .Where(w => w.Location is LocationCurve && !w.IsStackedWallMember)
            .Cast<Element>()
            .ToArray();

        // Model introspection methods

        // Wall introspection
        public string WallCurveType(Element element) {
            Curve curve = ((Wall)element).Location is LocationCurve lc ? lc.Curve : null;
            if (curve is Line) return "Line";
            if (curve is Arc) return "Arc";
            return "Other";
        }
        // Tessellated polyline for walls whose curve is neither Line nor Arc
        // (WallCurveType == "Other") so they can be rebuilt as polygonal walls.
        public XYZ[] WallCurveVertices(Element element) {
            try {
                Curve curve = (element.Location as LocationCurve)?.Curve;
                return curve == null ? new XYZ[0] : curve.Tessellate().ToArray();
            } catch {
                return new XYZ[0];
            }
        }
        public XYZ[] ArcWallVertices(Element element) {
            Arc arc = (((Wall)element).Location as LocationCurve).Curve as Arc;
            return new XYZ[] { arc.Center, arc.GetEndPoint(0), arc.GetEndPoint(1) };
        }
        public Length ArcWallRadius(Element element) {
            Arc arc = (((Wall)element).Location as LocationCurve).Curve as Arc;
            return new Length(arc.Radius);
        }
        public double[] ArcWallAngles(Element element) {
            Arc arc = (((Wall)element).Location as LocationCurve).Curve as Arc;
            // Revit Arc: angles in the plane defined by arc.XDirection / arc.YDirection
            // We transform to world angles
            XYZ xDir = arc.XDirection;
            double csAngle = Math.Atan2(xDir.Y, xDir.X);
            // Revit raw parameter range [0,1] maps to full arc
            double startParam = arc.GetEndParameter(0);
            double endParam = arc.GetEndParameter(1);
            return new double[] { startParam + csAngle, endParam + csAngle };
        }
        public string WallTypeName(Element element) =>
            ((Wall)element).WallType.Name;
        public bool WallIsCurtainWall(Element element) =>
            ((Wall)element).WallType.Kind == WallKind.Curtain;
        public Length WallBaseOffset(Element element) =>
            new Length(element.get_Parameter(BuiltInParameter.WALL_BASE_OFFSET).AsDouble());
        public Length WallTopOffset(Element element) =>
            new Length(element.get_Parameter(BuiltInParameter.WALL_TOP_OFFSET).AsDouble());
        public ElementId[] WallInserts(Element element) =>
            ((Wall)element).FindInserts(true, false, false, false).ToArray();
        // Curtain-wall children (panels + mullions) so introspection can claim them
        // and stop them double-emitting as fallback meshes. Empty for non-curtain walls.
        public ElementId[] CurtainWallChildIds(Element element) {
            try {
                CurtainGrid grid = (element as Wall)?.CurtainGrid;
                return grid == null ?
                    new ElementId[0] :
                    grid.GetPanelIds().Concat(grid.GetMullionIds()).ToArray();
            } catch {
                return new ElementId[0];
            }
        }
        public double[] CurtainGridUVCounts(Element element) {
            try {
                CurtainGrid grid = (element as Wall)?.CurtainGrid;
                return grid == null ?
                    new double[] { -1.0, -1.0 } :
                    new double[] { grid.NumULines, grid.NumVLines };
            } catch {
                return new double[] { -1.0, -1.0 };
            }
        }
        // Host-object (wall/floor/ceiling/roof) type thickness; Length so the wire
        // converts feet to metres. 0 when the type has no compound structure.
        public Length HostObjTypeThickness(Element element) {
            try {
                if (element is Wall wall) return new Length(wall.WallType.Width);
                if (element is Floor || element is Ceiling || element is RoofBase) {
                    var hostType = doc.GetElement(element.GetTypeId()) as HostObjAttributes;
                    CompoundStructure cs = hostType?.GetCompoundStructure();
                    return new Length(cs == null ? 0 : cs.GetWidth());
                }
                return new Length(0);
            } catch {
                return new Length(0);
            }
        }

        // Floor introspection
        // All boundary loops (outer + inner openings) of an element's horizontal face, so floor/ceiling/
        // roof openings/shafts survive reconstruction as region holes. The *BoundaryVertices methods
        // return only loop 0 (the outer), dropping openings.
        XYZ[][] AllHorizontalBoundaryLoops(Element element) {
            GeometryElement geo = element.get_Geometry(new Options());
            if (geo == null) return new XYZ[0][];
            foreach (GeometryObject obj in geo) {
                Solid solid = obj as Solid;
                if (solid == null || solid.Faces.Size == 0) continue;
                foreach (Face face in solid.Faces) {
                    PlanarFace pf = face as PlanarFace;
                    if (pf != null && Math.Abs(pf.FaceNormal.Z) > 0.9) {
                        var result = new List<XYZ[]>();
                        foreach (EdgeArray loop in pf.EdgeLoops) {
                            var pts = new List<XYZ>();
                            foreach (Edge edge in loop) pts.Add(edge.AsCurve().GetEndPoint(0));
                            if (pts.Count >= 3) result.Add(pts.ToArray());
                        }
                        if (result.Count > 0) return result.ToArray();
                    }
                }
            }
            return new XYZ[0][];
        }
        public XYZ[][] FloorBoundaryLoops(Element element) => AllHorizontalBoundaryLoops(element);
        public XYZ[][] CeilingBoundaryLoops(Element element) => AllHorizontalBoundaryLoops(element);
        public XYZ[][] RoofBoundaryLoops(Element element) => AllHorizontalBoundaryLoops(element);

        public XYZ[] FloorBoundaryVertices(Element element) {
            Floor floor = (Floor)element;
            Options opt = new Options();
            GeometryElement geo = floor.get_Geometry(opt);
            foreach (GeometryObject obj in geo) {
                Solid solid = obj as Solid;
                if (solid == null || solid.Faces.Size == 0) continue;
                // Find the bottom or top horizontal face
                foreach (Face face in solid.Faces) {
                    PlanarFace pf = face as PlanarFace;
                    if (pf != null && Math.Abs(pf.FaceNormal.Z) > 0.9) {
                        EdgeArrayArray loops = pf.EdgeLoops;
                        if (loops.Size > 0) {
                            EdgeArray outer = loops.get_Item(0);
                            List<XYZ> pts = new List<XYZ>();
                            foreach (Edge edge in outer) {
                                pts.Add(edge.AsCurve().GetEndPoint(0));
                            }
                            return pts.ToArray();
                        }
                    }
                }
            }
            return new XYZ[0];
        }
        public string FloorTypeName(Element element) =>
            doc.GetElement(element.GetTypeId())?.Name ?? "";
        public ElementId FloorLevel(Element element) => element.LevelId;

        // Ceiling introspection
        public XYZ[] CeilingBoundaryVertices(Element element) {
            // Same approach as floor — extract from geometry
            Options opt = new Options();
            GeometryElement geo = element.get_Geometry(opt);
            foreach (GeometryObject obj in geo) {
                Solid solid = obj as Solid;
                if (solid == null || solid.Faces.Size == 0) continue;
                foreach (Face face in solid.Faces) {
                    PlanarFace pf = face as PlanarFace;
                    if (pf != null && Math.Abs(pf.FaceNormal.Z) > 0.9) {
                        EdgeArrayArray loops = pf.EdgeLoops;
                        if (loops.Size > 0) {
                            EdgeArray outer = loops.get_Item(0);
                            List<XYZ> pts = new List<XYZ>();
                            foreach (Edge edge in outer) {
                                pts.Add(edge.AsCurve().GetEndPoint(0));
                            }
                            return pts.ToArray();
                        }
                    }
                }
            }
            return new XYZ[0];
        }
        public string CeilingTypeName(Element element) =>
            doc.GetElement(element.GetTypeId())?.Name ?? "";
        public ElementId CeilingLevel(Element element) => element.LevelId;

        // Column introspection (structural + architectural)
        public Element[] DocColumns() =>
            new FilteredElementCollector(doc)
                .OfCategory(BuiltInCategory.OST_StructuralColumns)
                .WhereElementIsNotElementType()
                .Where(e => !IsGroupMember(e))
                .Concat(new FilteredElementCollector(doc)
                    .OfCategory(BuiltInCategory.OST_Columns)
                    .WhereElementIsNotElementType()
                    .Where(e => !IsGroupMember(e)))
                .ToArray();
        public XYZ ColumnLocation(Element element) =>
            (element.Location as LocationPoint).Point;
        public double ColumnRotation(Element element) =>
            (element.Location as LocationPoint).Rotation;
        public ElementId ColumnBaseLevel(Element element) => element.LevelId;
        public ElementId ColumnTopLevel(Element element) =>
            element.get_Parameter(BuiltInParameter.FAMILY_TOP_LEVEL_PARAM)?.AsElementId()
            ?? ElementId.InvalidElementId;
        // Rectangular profile dims (b, h, 0) of a column's symbol, in raw feet —
        // the channel's wXYZ converts per component. Circular sections report d
        // for both dims. XYZ.Zero when no known dimension parameters exist.
        public XYZ ColumnProfileDims(Element element) {
            try {
                FamilySymbol sym = (element as FamilyInstance)?.Symbol;
                if (sym == null) return XYZ.Zero;
                double? b = LookupParam(sym, "b"), h = LookupParam(sym, "h");
                if (b.HasValue && h.HasValue) return new XYZ(b.Value, h.Value, 0);
                b = LookupParam(sym, "Width"); h = LookupParam(sym, "Depth");
                if (b.HasValue && h.HasValue) return new XYZ(b.Value, h.Value, 0);
                double? d = LookupParam(sym, "d");
                return d.HasValue ? new XYZ(d.Value, d.Value, 0) : XYZ.Zero;
            } catch {
                return XYZ.Zero;
            }
        }

        // Beam introspection
        public Element[] DocBeams() =>
            new FilteredElementCollector(doc)
                .OfCategory(BuiltInCategory.OST_StructuralFraming)
                .WhereElementIsNotElementType()
                .Where(e => !IsGroupMember(e))
                .ToArray();
        public XYZ[] BeamEndpoints(Element element) {
            LocationCurve lc = element.Location as LocationCurve;
            return new XYZ[] { lc.Curve.GetEndPoint(0), lc.Curve.GetEndPoint(1) };
        }
        public double BeamRotation(Element element) =>
            element.get_Parameter(BuiltInParameter.STRUCTURAL_BEND_DIR_ANGLE)?.AsDouble() ?? 0.0;

        // Door/Window introspection
        public Element[] DocDoors() =>
            new FilteredElementCollector(doc)
                .OfCategory(BuiltInCategory.OST_Doors)
                .WhereElementIsNotElementType()
                .ToArray();
        public Element[] DocWindows() =>
            new FilteredElementCollector(doc)
                .OfCategory(BuiltInCategory.OST_Windows)
                .WhereElementIsNotElementType()
                .ToArray();
        public ElementId HostWallId(Element element) {
            FamilyInstance fi = element as FamilyInstance;
            return fi?.Host?.Id ?? ElementId.InvalidElementId;
        }
        /* Reports a wall-hosted family instance's position along its host curve, plus
         * its sill height.
         *
         * Why the location lookup is layered:
         *   For wall-hosted FamilyInstance objects, `Location` is *usually* a
         *   `LocationPoint`. The previous implementation relied on that exclusively
         *   and returned 0/0 when the cast failed — which it does in several real
         *   scenarios:
         *     - Some hosted-family categories expose `Location == null` because the
         *       placement is fully derived from the host (no independent point).
         *     - Older Revit versions and certain face-based families return a
         *       `LocationCurve` even when the instance is conceptually a point.
         *     - In-progress sketch states briefly drop the LocationPoint between
         *       transactions.
         *   When any of these happen, `pos_d[1]` came back as 0 m and tests that
         *   asked "where along the wall is this opening?" silently failed even
         *   though the instance was placed at the right XY in the world.
         *
         *   Fallback chain: LocationPoint → bounding-box centre. The bounding box is
         *   always available for placed elements and its midpoint coincides with the
         *   geometric centre of the door/window, which is what we want to project
         *   onto the host curve.
         *
         * Why we re-fetch host curve endpoints:
         *   `IntersectionResult.Parameter` would let us skip the project-then-
         *   distance step, but it's a normalized parameter for some curve types
         *   (e.g. arcs) and a length for Lines. Computing `start.DistanceTo(proj)`
         *   gives a uniform answer in feet across all wall geometry.
         *
         * Units: returned Lengths wrap Revit-internal feet; the channel's wLength
         * converts to metres on the wire.
         *
         * See also: InsertDoorWithParams, InsertWindow, EnsureSymbolForTypeParams.
         */
        /* Reports a wall-hosted family instance's position along its host curve, plus
         * its sill height.
         *
         * Why we don't use `fi.Location.Point`:
         *   For wall-hosted FamilyInstance objects, `fi.Location` is a LocationPoint
         *   but the `Point` value is **not** in the model coordinate system — it's in
         *   the family's local placement frame, with an origin at the symbol's own
         *   reference point. For a door placed at world (2764, 0, 0) on a wall that
         *   starts at (2756, 0, 0), `LocationPoint.Point` was empirically returning
         *   (0, 0.021, 0) — looking like the wall start. Projecting that onto the
         *   host curve gave distFromStart = 0 and silently broke every multi-segment
         *   opening-position assertion. The Revit SDK note "Some hosted FamilyInstance
         *   objects may have a Location of LocationPoint with a Point that does not
         *   represent the actual position in the model" applies here.
         *
         *   `fi.GetTransform().Origin` is the documented way to get the instance's
         *   placement in world coordinates regardless of host kind, so we use that
         *   directly and skip the LocationPoint path.
         *
         * Why we still keep a bounding-box fallback:
         *   A small set of hosted family kinds (typically curve-hosted instances and
         *   face-hosted families with no embedded transform) have GetTransform()
         *   return identity. The bounding-box centre is a robust last resort because
         *   it's always available and coincides with the door/window's geometric
         *   centre, which is what we want to project onto the host curve.
         *
         * Units: returned Lengths wrap Revit-internal feet; the channel's wLength
         * converts to metres on the wire.
         *
         * See also: InsertDoorWithParams, InsertWindow, EnsureSymbolForTypeParams.
         */
        /* Reports a wall-hosted family instance's position along its host curve in
         * Revit-internal feet, plus its sill height.
         *
         * Why neither `Location.Point` nor `GetTransform().Origin` works directly:
         *   - `LocationPoint.Point` for hosted instances is in the family's local
         *     placement frame (origin at the symbol's reference), not in world
         *     coordinates. A door placed at world (2764, 0, 0) reports a Point of
         *     roughly (0, 0.02, 0).
         *   - `GetTransform()` for a hosted FamilyInstance is the transform from
         *     instance space to *host* space, not to world. Its Origin is
         *     effectively (0, 0, 0) because the placement is "at the host's origin
         *     plus a host-local offset."
         *
         *   The robust way to get the world position is to read the instance's
         *   geometry — `fi.get_BoundingBox(null)` returns the BoundingBoxXYZ in
         *   model coordinates regardless of how the location is stored. The
         *   midpoint of that box coincides with the door/window's geometric centre
         *   for standard placements, which is what we want to project onto the
         *   host curve.
         *
         * Order of attempts (most reliable first):
         *   1. Bounding-box centre (model coords). Always available for placed
         *      elements.
         *   2. `GetTotalTransform().Origin` as a fallback. For non-hosted family
         *      instances, total-transform is identical to bounding-box centre; for
         *      hosted instances it composes the host transform with the local
         *      placement, so it is at least in world coordinates.
         *
         * Units: returned Lengths wrap Revit-internal feet; the channel's wLength
         * converts to metres on the wire.
         *
         * See also: InsertDoorWithParams, InsertWindow, EnsureSymbolForTypeParams.
         */
        public Length[] HostedElementPosition(Element element) {
            FamilyInstance fi = element as FamilyInstance;
            if (fi?.Host == null) return new Length[] { new Length(0), new Length(0) };
            LocationCurve hostLoc = fi.Host.Location as LocationCurve;
            if (hostLoc == null) return new Length[] { new Length(0), new Length(0) };
            XYZ elemPt = null;
            BoundingBoxXYZ bb = fi.get_BoundingBox(null);
            if (bb != null) {
                elemPt = (bb.Min + bb.Max) * 0.5;
            } else {
                elemPt = fi.GetTotalTransform()?.Origin;
            }
            if (elemPt == null) return new Length[] { new Length(0), new Length(0) };
            Curve hostCurve = hostLoc.Curve;
            XYZ startPt = hostCurve.GetEndPoint(0);
            IntersectionResult result = hostCurve.Project(elemPt);
            double distFromStart = result == null ? 0 : startPt.DistanceTo(result.XYZPoint);
            double sillHeight = fi.get_Parameter(BuiltInParameter.INSTANCE_SILL_HEIGHT_PARAM)?.AsDouble() ?? 0;
            return new Length[] { new Length(distFromStart), new Length(sillHeight) };
        }
        /* Reports the placed Width/Height of a door or window in Revit internal feet.
         *
         * Why both instance and symbol have to be checked:
         *   Revit families come in two flavours that store the same conceptual
         *   parameter in different places.
         *     - Type-parameter families (e.g. the default project-template door):
         *       Width lives on the FamilySymbol. We `Duplicate(...)` the symbol with
         *       baked values when a caller wants a non-default size (see
         *       FamilyElement / EnsureSymbolForTypeParams).
         *     - Instance-parameter families (e.g. M_Instance-Window-Fixed.rfa):
         *       Width lives on the FamilyInstance and is set after placement via
         *       SetParameters.
         *   Looking only at the symbol therefore returned the type's *default* width
         *   for instance-param families even when the user had requested a different
         *   value, which silently broke the openings tests.
         *
         * Lookup order:
         *   Instance first (so per-placement overrides are reflected) → symbol
         *   fallback (for type-param families). DOOR_WIDTH / WINDOW_WIDTH are the
         *   Revit-canonical built-ins; FAMILY_WIDTH_PARAM is the generic catch-all.
         *
         * See also: SetParameters, EnsureSymbolForTypeParams, InsertDoorWithParams,
         * InsertWindow.
         */
        static double? ReadParam(Element e, BuiltInParameter bip) =>
            e?.get_Parameter(bip)?.AsDouble();

        static double? LookupParam(Element e, string name) =>
            e?.LookupParameter(name)?.AsDouble();

        // Skip default-valued (0) parameters so they don't short-circuit the
        // fallback chain. Door/window Width/Height of 0 ft is invalid by
        // construction, so 0 always means "the parameter exists but isn't set
        // for this element" — typically the instance copy of a built-in like
        // DOOR_WIDTH that lives in parallel with the type-level value.
        static double? NonZero(double? v) =>
            v.HasValue && v.Value != 0.0 ? v : null;

        public Length[] DoorWindowDimensions(Element element) {
            FamilyInstance fi = element as FamilyInstance;
            FamilySymbol sym = fi?.Symbol;
            // Probe order: instance non-zero first (real per-placement override),
            // then symbol. For families like the default door where Width is a
            // type-level parameter, the instance's parallel copy of DOOR_WIDTH is
            // 0 by default — NonZero filters that out so the symbol value (which
            // we baked via EnsureSymbolForTypeParams) wins.
            double width = NonZero(ReadParam(fi, BuiltInParameter.DOOR_WIDTH))
                        ?? NonZero(ReadParam(fi, BuiltInParameter.WINDOW_WIDTH))
                        ?? NonZero(ReadParam(fi, BuiltInParameter.FAMILY_WIDTH_PARAM))
                        ?? NonZero(LookupParam(fi, "Width"))
                        ?? NonZero(ReadParam(sym, BuiltInParameter.DOOR_WIDTH))
                        ?? NonZero(ReadParam(sym, BuiltInParameter.WINDOW_WIDTH))
                        ?? NonZero(ReadParam(sym, BuiltInParameter.FAMILY_WIDTH_PARAM))
                        ?? NonZero(LookupParam(sym, "Width"))
                        ?? 0;
            double height = NonZero(ReadParam(fi, BuiltInParameter.DOOR_HEIGHT))
                         ?? NonZero(ReadParam(fi, BuiltInParameter.WINDOW_HEIGHT))
                         ?? NonZero(ReadParam(fi, BuiltInParameter.FAMILY_HEIGHT_PARAM))
                         ?? NonZero(LookupParam(fi, "Height"))
                         ?? NonZero(ReadParam(sym, BuiltInParameter.DOOR_HEIGHT))
                         ?? NonZero(ReadParam(sym, BuiltInParameter.WINDOW_HEIGHT))
                         ?? NonZero(ReadParam(sym, BuiltInParameter.FAMILY_HEIGHT_PARAM))
                         ?? NonZero(LookupParam(sym, "Height"))
                         ?? 0;
            return new Length[] { new Length(width), new Length(height) };
        }

        // Generic family/type info
        public string ElementFamilyName(Element element) {
            FamilyInstance fi = element as FamilyInstance;
            if (fi != null) return fi.Symbol.FamilyName;
            // For system families (walls, floors, etc.)
            ElementType et = doc.GetElement(element.GetTypeId()) as ElementType;
            return et?.FamilyName ?? "";
        }
        public string ElementTypeName(Element element) {
            FamilyInstance fi = element as FamilyInstance;
            if (fi != null) return fi.Symbol.Name;
            ElementType et = doc.GetElement(element.GetTypeId()) as ElementType;
            return et?.Name ?? "";
        }
        public string ElementFamilyPath(Element element) {
            FamilyInstance fi = element as FamilyInstance;
            if (fi == null) return "";
            Family fam = fi.Symbol.Family;
            // Family.Document is the .rfa if loaded
            try {
                return fam.Document?.PathName ?? "";
            } catch {
                return "";
            }
        }
        public bool IsSystemFamily(Element element) {
            FamilyInstance fi = element as FamilyInstance;
            return fi == null; // non-FamilyInstance elements are system families
        }

        // Model Groups
        public Element[] DocGroups() =>
            new FilteredElementCollector(doc)
                .OfClass(typeof(Group))
                .Cast<Element>()
                .ToArray();
        public string GroupTypeName(Element element) =>
            ((Group)element).GroupType?.Name ?? "";
        public ElementId GroupTypeId(Element element) =>
            ((Group)element).GroupType?.Id ?? ElementId.InvalidElementId;
        public ElementId[] GroupMemberIds(Element element) =>
            ((Group)element).GetMemberIds().ToArray();
        public XYZ GroupLocation(Element element) {
            LocationPoint lp = element.Location as LocationPoint;
            return lp?.Point ?? XYZ.Zero;
        }
        public bool IsGroupMember(Element element) =>
            element.GroupId != null && element.GroupId != ElementId.InvalidElementId;
        // Filter elements, returning only those NOT inside a group
        public Element[] NotInGroup(Element[] elements) =>
            elements.Where(e => e != null && !IsGroupMember(e)).ToArray();
        // Roof introspection
        public Element[] DocRoofs() =>
            new FilteredElementCollector(doc)
                .OfCategory(BuiltInCategory.OST_Roofs)
                .WhereElementIsNotElementType()
                .Where(e => !IsGroupMember(e))
                .ToArray();
        public XYZ[] RoofBoundaryVertices(Element element) {
            Options opt = new Options();
            GeometryElement geo = element.get_Geometry(opt);
            foreach (GeometryObject obj in geo) {
                Solid solid = obj as Solid;
                if (solid == null || solid.Faces.Size == 0) continue;
                foreach (Face face in solid.Faces) {
                    PlanarFace pf = face as PlanarFace;
                    if (pf != null && Math.Abs(pf.FaceNormal.Z) > 0.9) {
                        EdgeArrayArray loops = pf.EdgeLoops;
                        if (loops.Size > 0) {
                            EdgeArray outer = loops.get_Item(0);
                            List<XYZ> pts = new List<XYZ>();
                            foreach (Edge edge in outer) {
                                pts.Add(edge.AsCurve().GetEndPoint(0));
                            }
                            return pts.ToArray();
                        }
                    }
                }
            }
            return new XYZ[0];
        }
        public ElementId RoofLevel(Element element) => element.LevelId;

        // Furniture introspection
        public Element[] DocFurniture() =>
            new FilteredElementCollector(doc)
                .OfCategory(BuiltInCategory.OST_Furniture)
                .WhereElementIsNotElementType()
                .Where(e => !IsGroupMember(e) && e.Location is LocationPoint && (e as FamilyInstance)?.SuperComponent == null)
                .ToArray();
        // Plumbing fixture introspection
        public Element[] DocPlumbingFixtures() =>
            new FilteredElementCollector(doc)
                .OfCategory(BuiltInCategory.OST_PlumbingFixtures)
                .WhereElementIsNotElementType()
                .Where(e => !IsGroupMember(e) && e.Location is LocationPoint && (e as FamilyInstance)?.SuperComponent == null)
                .ToArray();
        // Casework introspection
        public Element[] DocCasework() =>
            new FilteredElementCollector(doc)
                .OfCategory(BuiltInCategory.OST_Casework)
                .WhereElementIsNotElementType()
                .Where(e => !IsGroupMember(e) && e.Location is LocationPoint && (e as FamilyInstance)?.SuperComponent == null)
                .ToArray();
        // Generic model introspection
        public Element[] DocGenericModels() =>
            new FilteredElementCollector(doc)
                .OfCategory(BuiltInCategory.OST_GenericModel)
                .WhereElementIsNotElementType()
                .Where(e => !IsGroupMember(e) && e.Location is LocationPoint && (e as FamilyInstance)?.SuperComponent == null)
                .ToArray();
        // Specialty equipment introspection
        public Element[] DocSpecialtyEquipment() =>
            new FilteredElementCollector(doc)
                .OfCategory(BuiltInCategory.OST_SpecialityEquipment)
                .WhereElementIsNotElementType()
                .Where(e => !IsGroupMember(e) && e.Location is LocationPoint && (e as FamilyInstance)?.SuperComponent == null)
                .ToArray();
        // Generic FamilyInstance introspection helpers
        public XYZ FamilyInstanceLocation(Element element) =>
            (element.Location as LocationPoint)?.Point ?? XYZ.Zero;
        public double FamilyInstanceRotation(Element element) {
            // Hosted instances expose a LocationPoint whose Rotation getter throws.
            try { return (element.Location as LocationPoint)?.Rotation ?? 0.0; }
            catch (Autodesk.Revit.Exceptions.InvalidOperationException) { return 0.0; }
        }
        public ElementId FamilyInstanceLevel(Element element) => element.LevelId;
        public ElementId FamilyInstanceHost(Element element) {
            FamilyInstance fi = element as FamilyInstance;
            return fi?.Host?.Id ?? ElementId.InvalidElementId;
        }

        // Stair introspection
        public Element[] DocStairs() =>
            new FilteredElementCollector(doc)
                .OfCategory(BuiltInCategory.OST_Stairs)
                .WhereElementIsNotElementType()
                .Where(e => !IsGroupMember(e))
                .ToArray();
        public ElementId StairBaseLevel(Element element) =>
            element.get_Parameter(BuiltInParameter.STAIRS_BASE_LEVEL_PARAM)?.AsElementId()
            ?? ElementId.InvalidElementId;
        public ElementId StairTopLevel(Element element) =>
            element.get_Parameter(BuiltInParameter.STAIRS_TOP_LEVEL_PARAM)?.AsElementId()
            ?? ElementId.InvalidElementId;
        // Multi-run stair introspection: one polyline per run (the run's stairs path),
        // ordered bottom-up. The path curves lie at each run's base elevation, so the
        // returned z values encode the vertical structure (top of run k = base of run k+1
        // across a flat landing; the last run tops out at the stair's top level).
        public XYZ[][] StairRunPaths(Element element) {
            Stairs stair = element as Stairs;
            if (stair == null) return new XYZ[0][];
            var runs = stair.GetStairsRuns()
                .Select(id => doc.GetElement(id) as StairsRun)
                .Where(r => r != null)
                .OrderBy(r => r.BaseElevation)
                .ToList();
            return runs.Select(r => {
                var pts = new List<XYZ>();
                foreach (Curve c in r.GetStairsPath()) {
                    if (pts.Count == 0) pts.Add(c.GetEndPoint(0));
                    pts.Add(c.GetEndPoint(1));
                }
                return pts.ToArray();
            }).Where(a => a.Length >= 2).ToArray();
        }
        // Landing footprint polygons, bottom-up by elevation. The boundary CurveLoop is
        // tessellated to its curve endpoints (landings are polygonal in practice).
        public XYZ[][] StairLandingBoundaries(Element element) {
            Stairs stair = element as Stairs;
            if (stair == null) return new XYZ[0][];
            return stair.GetStairsLandings()
                .Select(id => doc.GetElement(id) as StairsLanding)
                .Where(l => l != null)
                .OrderBy(l => l.BaseElevation)
                .Select(l => {
                    var pts = new List<XYZ>();
                    foreach (Curve c in l.GetFootprintBoundary()) {
                        foreach (XYZ q in c.Tessellate()) {
                            if (pts.Count == 0 || pts[pts.Count - 1].DistanceTo(q) > doc.Application.ShortCurveTolerance)
                                pts.Add(q);
                        }
                    }
                    // Drop a closing duplicate of the first point.
                    if (pts.Count > 1 && pts[0].DistanceTo(pts[pts.Count - 1]) <= doc.Application.ShortCurveTolerance)
                        pts.RemoveAt(pts.Count - 1);
                    return pts.ToArray();
                })
                .Where(a => a.Length >= 3).ToArray();
        }
        public Length[] StairLandingElevations(Element element) {
            Stairs stair = element as Stairs;
            if (stair == null) return new Length[0];
            return stair.GetStairsLandings()
                .Select(id => doc.GetElement(id) as StairsLanding)
                .Where(l => l != null)
                .OrderBy(l => l.BaseElevation)
                .Select(l => new Length(l.BaseElevation))
                .ToArray();
        }
        // Base and top elevation per run, flat [base1, top1, base2, top2, ...] bottom-up.
        public Length[] StairRunElevations(Element element) {
            Stairs stair = element as Stairs;
            if (stair == null) return new Length[0];
            return stair.GetStairsRuns()
                .Select(id => doc.GetElement(id) as StairsRun)
                .Where(r => r != null)
                .OrderBy(r => r.BaseElevation)
                .SelectMany(r => new[] { new Length(r.BaseElevation), new Length(r.TopElevation) })
                .ToArray();
        }
        public Length StairWidth(Element element) {
            Stairs stair = element as Stairs;
            var run = stair?.GetStairsRuns()
                .Select(id => doc.GetElement(id) as StairsRun)
                .FirstOrDefault(r => r != null);
            return new Length(run != null ? run.ActualRunWidth : 0.0);
        }
        public Length StairRiserHeight(Element element) =>
            new Length(element.get_Parameter(BuiltInParameter.STAIRS_ACTUAL_RISER_HEIGHT)?.AsDouble() ?? 0.0);
        public Length StairTreadDepth(Element element) =>
            new Length(element.get_Parameter(BuiltInParameter.STAIRS_ACTUAL_TREAD_DEPTH)?.AsDouble() ?? 0.0);
        // The railing's host element (stair, floor, ...) or InvalidElementId when unhosted.
        public ElementId RailingHostElement(Element element) {
            var railing = element as Autodesk.Revit.DB.Architecture.Railing;
            return (railing != null && railing.HasHost) ? railing.HostId : ElementId.InvalidElementId;
        }
        public XYZ StairBasePoint(Element element) {
            Stairs stair = element as Stairs;
            if (stair != null) {
                ICollection<ElementId> runIds = stair.GetStairsRuns();
                if (runIds.Count > 0) {
                    StairsRun run = doc.GetElement(runIds.First()) as StairsRun;
                    if (run != null) {
                        CurveLoop path = run.GetStairsPath();
                        if (path != null) {
                            foreach (Curve c in path) {
                                return c.GetEndPoint(0);
                            }
                        }
                    }
                }
            }
            LocationPoint lp = element.Location as LocationPoint;
            return lp?.Point ?? XYZ.Zero;
        }
        public XYZ StairDirection(Element element) {
            Stairs stair = element as Stairs;
            if (stair != null) {
                ICollection<ElementId> runIds = stair.GetStairsRuns();
                if (runIds.Count > 0) {
                    StairsRun run = doc.GetElement(runIds.First()) as StairsRun;
                    if (run != null) {
                        CurveLoop path = run.GetStairsPath();
                        if (path != null) {
                            foreach (Curve c in path) {
                                XYZ dir = (c.GetEndPoint(1) - c.GetEndPoint(0)).Normalize();
                                return dir;
                            }
                        }
                    }
                }
            }
            return XYZ.BasisY;
        }

        // Railing introspection
        public Element[] DocRailings() =>
            new FilteredElementCollector(doc)
                .OfCategory(BuiltInCategory.OST_StairsRailing)
                .WhereElementIsNotElementType()
                .Where(e => !IsGroupMember(e))
                .ToArray();
        public XYZ[] RailingPath(Element element) {
            Railing railing = element as Railing;
            if (railing == null) return new XYZ[0];
            IList<Curve> curves = railing.GetPath();
            if (curves == null || curves.Count == 0) return new XYZ[0];
            List<XYZ> pts = new List<XYZ>();
            foreach (Curve c in curves) {
                if (pts.Count == 0) pts.Add(c.GetEndPoint(0));
                pts.Add(c.GetEndPoint(1));
            }
            return pts.ToArray();
        }
        public ElementId RailingLevel(Element element) => element.LevelId;

        // Return the BuiltInCategory name for an element (for group member type classification)
        public string ElementCategoryName(Element element) {
            if (element == null) return "";
            var cat = element.Category;
            if (cat == null) return "";
            var bic = (BuiltInCategory)cat.Id.Value;
            switch (bic) {
                case BuiltInCategory.OST_Walls: return "Wall";
                case BuiltInCategory.OST_Floors: return "Floor";
                case BuiltInCategory.OST_StructuralColumns: return "Column";
                case BuiltInCategory.OST_Columns: return "Column";
                case BuiltInCategory.OST_StructuralFraming: return "Beam";
                case BuiltInCategory.OST_Ceilings: return "Ceiling";
                case BuiltInCategory.OST_Roofs: return "Roof";
                case BuiltInCategory.OST_Furniture: return "Fixture";
                case BuiltInCategory.OST_PlumbingFixtures: return "Fixture";
                case BuiltInCategory.OST_Casework: return "Fixture";
                case BuiltInCategory.OST_GenericModel: return "Fixture";
                case BuiltInCategory.OST_SpecialityEquipment: return "Fixture";
                case BuiltInCategory.OST_Stairs: return "Stair";
                case BuiltInCategory.OST_StairsRailing: return "Railing";
                default: return "";
            }
        }

        //Energy Analysis

        // Ceiling
        public ElementId CreatePolygonalCeiling(XYZ[] pts, Level level, ElementId famId) {
            CeilingType ceilingType = (famId != null && famId != ElementId.InvalidElementId) ?
                doc.GetElement(famId) as CeilingType :
                new FilteredElementCollector(doc)
                    .OfClass(typeof(CeilingType)).First() as CeilingType;
            Ceiling ceiling = Ceiling.Create(doc,
                new List<CurveLoop> { PolygonCurveLoop(pts) },
                ceilingType.Id, level.Id);
            return ceiling.Id;
        }
        public ElementId CreatePathCeiling(XYZ[] pts, double[] angles, Level level, ElementId famId) {
            CeilingType ceilingType = (famId != null && famId != ElementId.InvalidElementId) ?
                doc.GetElement(famId) as CeilingType :
                new FilteredElementCollector(doc)
                    .OfClass(typeof(CeilingType)).First() as CeilingType;
            Ceiling ceiling = Ceiling.Create(doc,
                new List<CurveLoop> { CurveLoopPath(pts, angles) },
                ceilingType.Id, level.Id);
            return ceiling.Id;
        }

        // Ramp (DirectShape with OST_Ramps category)
        public ElementId CreateRamp(XYZ p0, XYZ p1, double width, double thickness,
                                     Level baseLevel, double baseOffset, double topOffset) {
            double halfWidth = width / 2;
            XYZ dir = (p1 - p0).Normalize();
            XYZ perp = dir.CrossProduct(XYZ.BasisZ).Normalize();
            double baseElev = baseLevel.Elevation + baseOffset;
            double topElev = baseLevel.Elevation + topOffset;

            XYZ[] top = {
                p0 + perp * halfWidth + new XYZ(0, 0, baseElev),
                p0 - perp * halfWidth + new XYZ(0, 0, baseElev),
                p1 - perp * halfWidth + new XYZ(0, 0, topElev),
                p1 + perp * halfWidth + new XYZ(0, 0, topElev)
            };
            XYZ thk = new XYZ(0, 0, -thickness);
            XYZ[] bot = top.Select(p => p + thk).ToArray();

            TessellatedShapeBuilder builder = new TessellatedShapeBuilder();
            builder.OpenConnectedFaceSet(false);
            builder.AddFace(new TessellatedFace(top, CurrentMaterialId));
            builder.AddFace(new TessellatedFace(bot.Reverse().ToArray(), CurrentMaterialId));
            for (int i = 0; i < 4; i++) {
                int j = (i + 1) % 4;
                builder.AddFace(new TessellatedFace(
                    new[] { top[i], top[j], bot[j], bot[i] }, CurrentMaterialId));
            }
            builder.CloseConnectedFaceSet();
            builder.Target = TessellatedShapeBuilderTarget.AnyGeometry;
            builder.Fallback = TessellatedShapeBuilderFallback.Mesh;
            builder.Build();

            DirectShape ds = DirectShape.CreateElement(doc,
                new ElementId(BuiltInCategory.OST_Ramps));
            ds.SetShape(builder.GetBuildResult().GetGeometricalObjects());
            return ds.Id;
        }

        // Stair (Straight)
        // Stair creation requires both a StairsEditScope (replaces the outer transaction
        // for the duration of stair edits) and an *inner* Transaction inside the scope
        // for the actual run/edit operations. Without the inner Transaction,
        // StairsRun.CreateStraightRun throws "Modifying  is forbidden because the
        // document has no open transaction" — the previous code committed the outer
        // transaction and started the StairsEditScope but never opened a Transaction
        // inside the scope.
        public ElementId CreateStraightStair(XYZ basePoint, XYZ direction, double width,
                                             Level baseLevel, Level topLevel, ElementId familyId) {
            // Let a build failure PROPAGATE (RMIfy → clean BackendError) instead of swallowing it and
            // returning InvalidElementId under an OK reply. WithSuspendedTransaction's finally always
            // restarts the transaction — matching the CreateSpiralStair sibling.
            ElementId stairsId = ElementId.InvalidElementId;
            WithSuspendedTransaction(() => {
                using (var scope = new StairsEditScope(doc, "Create Stairs")) {
                    stairsId = scope.Start(baseLevel.Id, topLevel.Id);
                    using (Transaction t = new Transaction(doc, "Add Straight Run")) {
                        t.Start();
                        WarningSwallower.KhepriWarnings(t);
                        // The run's location line must sit AT the base level's elevation, be horizontal,
                        // and have non-zero length — otherwise StairsRun.CreateStraightRun rejects it
                        // ("not a valid location path line"). basePoint may be a local/xy point (z=0,
                        // e.g. inside a group) while the base level is far above, so rebuild the line at
                        // the level's Z with a guarded horizontal direction and run length.
                        double height = topLevel.Elevation - baseLevel.Elevation;
                        XYZ dir = direction.IsZeroLength() ? XYZ.BasisX : new XYZ(direction.X, direction.Y, 0.0);
                        dir = dir.IsZeroLength() ? XYZ.BasisX : dir.Normalize();
                        double runLen = Math.Max(Math.Abs(height) * 1.6, doc.Application.ShortCurveTolerance * 4);
                        XYZ p0 = new XYZ(basePoint.X, basePoint.Y, baseLevel.Elevation);
                        StairsRun run = StairsRun.CreateStraightRun(doc, stairsId,
                            Line.CreateBound(p0, p0 + dir * runLen), StairsRunJustification.Center);
                        run.ActualRunWidth = width;
                        t.Commit();
                    }
                    scope.Commit(new StairsFailurePreprocessor());
                }
            });
            // Reached only on the success path (a throw above skips these).
            if (familyId != null && familyId != ElementId.InvalidElementId) {
                doc.GetElement(stairsId).ChangeTypeId(familyId);
            }
            return stairsId;
        }

        // Stair (Spiral) — same inner-Transaction requirement as CreateStraightStair.
        // Multi-run stair from the plan centerline (z level-relative, converted to absolute
        // here): climbing segments become straight runs whose location line sits at the
        // segment's start elevation; flat segments become landings, created automatically
        // between the two adjoining runs. Same StairsEditScope discipline as
        // CreateStraightStair (see WithSuspendedTransaction's comment).
        // `landings` carries the EXACT footprint polygon of each landing (level-relative z,
        // ordered bottom-up; may be empty). Each is sketched via StairsLanding.Create; a
        // polygon Revit rejects falls back to the automatic landing between the two
        // adjoining runs, so an imperfect footprint degrades gracefully instead of failing
        // the stair.
        public ElementId CreateMultiRunStair(XYZ[] pts, XYZ[][] landings, double width,
                                             Level baseLevel, Level topLevel, ElementId familyId) {
            ElementId stairsId = ElementId.InvalidElementId;
            WithSuspendedTransaction(() => {
                using (var scope = new StairsEditScope(doc, "Create Stairs")) {
                    stairsId = scope.Start(baseLevel.Id, topLevel.Id);
                    using (Transaction t = new Transaction(doc, "Add Runs")) {
                        t.Start();
                        WarningSwallower.KhepriWarnings(t);
                        var runs = new List<StairsRun>();
                        double tol = doc.Application.ShortCurveTolerance;
                        for (int i = 0; i + 1 < pts.Length; i++) {
                            double dz = pts[i + 1].Z - pts[i].Z;
                            XYZ a = new XYZ(pts[i].X, pts[i].Y, baseLevel.Elevation + pts[i].Z);
                            XYZ c = new XYZ(pts[i + 1].X, pts[i + 1].Y, baseLevel.Elevation + pts[i].Z);
                            if (Math.Abs(dz) < 0.01 || a.DistanceTo(c) < tol)
                                continue;   // landing (or degenerate) segment: no run
                            StairsRun run = StairsRun.CreateStraightRun(doc, stairsId,
                                Line.CreateBound(a, c), StairsRunJustification.Center);
                            run.ActualRunWidth = width;
                            doc.Regenerate();
                            runs.Add(run);
                        }
                        for (int k = 0; k + 1 < runs.Count; k++) {
                            bool made = false;
                            if (landings != null && k < landings.Length && landings[k].Length >= 3) {
                                try {
                                    var loop = new CurveLoop();
                                    var poly = landings[k];
                                    double z = baseLevel.Elevation + poly[0].Z;
                                    for (int j = 0; j < poly.Length; j++) {
                                        XYZ p0 = new XYZ(poly[j].X, poly[j].Y, z);
                                        XYZ p1 = new XYZ(poly[(j + 1) % poly.Length].X,
                                                         poly[(j + 1) % poly.Length].Y, z);
                                        if (p0.DistanceTo(p1) > tol)
                                            loop.Append(Line.CreateBound(p0, p1));
                                    }
                                    StairsLanding.CreateSketchedLanding(doc, stairsId, loop, z);
                                    made = true;
                                } catch { }
                            }
                            if (!made) {
                                try {
                                    StairsLanding.CreateAutomaticLanding(doc, runs[k].Id, runs[k + 1].Id);
                                } catch { }   // runs that touch directly have no landing gap
                            }
                        }
                        t.Commit();
                    }
                    scope.Commit(new StairsFailurePreprocessor());
                }
            });
            if (familyId != null && familyId != ElementId.InvalidElementId) {
                doc.GetElement(stairsId).ChangeTypeId(familyId);
            }
            return stairsId;
        }
        public Element CreateSpiralStair(XYZ center, double radius, double startAngle,
                                          double includedAngle, bool clockwise, double width,
                                          Level baseLevel, Level topLevel, ElementId familyId) {
            // Element return has no clean null wire sentinel (wElement would NRE on null), so an
            // un-buildable stair must PROPAGATE its exception, not return null. WithSuspendedTransaction's
            // finally guarantees the restart; RMIfy turns the throw into a clean BackendError.
            ElementId stairsId = ElementId.InvalidElementId;
            WithSuspendedTransaction(() => {
                using (var scope = new StairsEditScope(doc, "Create Spiral Stairs")) {
                    stairsId = scope.Start(baseLevel.Id, topLevel.Id);
                    using (Transaction t = new Transaction(doc, "Add Spiral Run")) {
                        t.Start();
                        WarningSwallower.KhepriWarnings(t);
                        StairsRun run = StairsRun.CreateSpiralRun(doc, stairsId,
                            center, radius, startAngle, includedAngle,
                            clockwise, StairsRunJustification.Center);
                        run.ActualRunWidth = width;
                        t.Commit();
                    }
                    scope.Commit(new StairsFailurePreprocessor());
                }
            });
            // Reached only on the success path (a throw above skips these).
            if (familyId != null && familyId != ElementId.InvalidElementId) {
                doc.GetElement(stairsId).ChangeTypeId(familyId);
            }
            return doc.GetElement(stairsId);
        }

        public void EnergyAnalysis() {
            // Collect space and surface data from the building's analytical thermal model
            EnergyAnalysisDetailModelOptions options = new EnergyAnalysisDetailModelOptions();
            options.Tier = EnergyAnalysisDetailModelTier.Final; // include constructions, schedules, and non-graphical data in the computation of the energy analysis model
            options.EnergyModelType = EnergyModelType.SpatialElement;   // Energy model based on rooms or spaces
            options.EnergyModelType = EnergyModelType.BuildingElement;

            EnergyAnalysisDetailModel eadm = EnergyAnalysisDetailModel.Create(doc, options); // Create a new energy analysis detailed model from the physical model
            IList<EnergyAnalysisSpace> spaces = eadm.GetAnalyticalSpaces();
            StringBuilder builder = new StringBuilder();
            builder.AppendLine("Spaces: " + spaces.Count);
            foreach (EnergyAnalysisSpace space in spaces) {
                SpatialElement spatialElement = doc.GetElement(space.CADObjectUniqueId) as SpatialElement;
                ElementId spatialElementId = spatialElement == null ? ElementId.InvalidElementId : spatialElement.Id;
                builder.AppendLine("   >>> " + space.SpaceName + " related to " + spatialElementId);
                IList<EnergyAnalysisSurface> surfaces = space.GetAnalyticalSurfaces();
                builder.AppendLine("       has " + surfaces.Count + " surfaces.");
                foreach (EnergyAnalysisSurface surface in surfaces) {
                    builder.AppendLine("            +++ Surface from " + surface.OriginatingElementDescription);
                }
            }
            TaskDialog.Show("EAM", builder.ToString());
        }

        // OBJ Export from Family Files

        const double from_feet = 1.0 / 3.28084;

        void ExportDocumentGeometryToOBJ(Document geomDoc, string objPath) {
            string mtlPath = Path.ChangeExtension(objPath, ".mtl");
            string mtlFileName = Path.GetFileName(mtlPath);
            var options = new Options {
                ComputeReferences = false,
                DetailLevel = ViewDetailLevel.Fine
            };
            var vertices = new List<XYZ>();
            var normals = new List<XYZ>();
            var uvs = new List<UV>();
            var groups = new List<Tuple<string, List<int[][]>>>();
            var materials = new Dictionary<string, Autodesk.Revit.DB.Color>();
            var materialTransparency = new Dictionary<string, int>();
                    var materialPbr = new Dictionary<string, double[]>();

            var collector = new FilteredElementCollector(geomDoc);
            foreach (Element elem in collector.WhereElementIsNotElementType()) {
                // Skip void forms (opening cuts in door/window families)
                if (elem is GenericForm gf && !gf.IsSolid) continue;

                GeometryElement geomElem = elem.get_Geometry(options);
                if (geomElem == null) continue;
                CollectGeometry(geomDoc, geomElem, vertices, normals, uvs, groups, materials, materialTransparency, materialPbr);
            }

            if (vertices.Count > 0) {
                WriteOBJ(objPath, mtlFileName, vertices, normals, uvs, groups);
                WriteMTL(mtlPath, materials, materialTransparency, materialPbr);
            }
        }

        // Mesh-fallback (Phase 6): tessellate specific elements (by id) to per-element WORLD-space OBJ
        // files, so elements with no parametric reader (curtain panels, MEP, topography, in-place, sloped/
        // degenerate) reproduce as meshes instead of being silently dropped. CollectGeometry recurses
        // GeometryInstance.GetInstanceGeometry() (world) and WriteOBJ writes metres, so the Julia side
        // places each obj_model at u0() (identity). Returns a parallel array of obj paths ("" = no solid).
        public string[] ExportElementsToOBJ(ElementId[] ids, string folderPath) {
            Directory.CreateDirectory(folderPath);
            var options = new Options { ComputeReferences = false, DetailLevel = ViewDetailLevel.Fine };
            var result = new string[ids.Length];
            for (int i = 0; i < ids.Length; i++) {
                result[i] = "";
                try {
                    Element elem = doc.GetElement(ids[i]);
                    if (elem == null || (elem is GenericForm gf && !gf.IsSolid)) continue;
                    GeometryElement geomElem = elem.get_Geometry(options);
                    if (geomElem == null) continue;
                    var vertices = new List<XYZ>();
                    var normals = new List<XYZ>();
                    var uvs = new List<UV>();
                    var groups = new List<Tuple<string, List<int[][]>>>();
                    var materials = new Dictionary<string, Autodesk.Revit.DB.Color>();
                    var materialTransparency = new Dictionary<string, int>();
                    var materialPbr = new Dictionary<string, double[]>();
                    CollectGeometry(doc, geomElem, vertices, normals, uvs, groups, materials, materialTransparency, materialPbr);
                    if (vertices.Count == 0) continue;
                    string objPath = Path.Combine(folderPath, ids[i].Value + ".obj");
                    string mtlPath = Path.ChangeExtension(objPath, ".mtl");
                    WriteOBJ(objPath, Path.GetFileName(mtlPath), vertices, normals, uvs, groups);
                    WriteMTL(mtlPath, materials, materialTransparency, materialPbr);
                    result[i] = objPath;
                } catch { }
            }
            return result;
        }

        public void ExportFamilyToOBJ(string familyPath, string objPath) {
            CommitAndDisposeTransaction();
            Document famDoc = uiapp.Application.OpenDocumentFile(familyPath);
            try {
                ExportDocumentGeometryToOBJ(famDoc, objPath);
            } finally {
                famDoc.Close(false);
                EnsureTransaction(uiapp);
            }
        }

        public void ExportAllFamiliesToOBJ(string folderPath) {
            CommitAndDisposeTransaction();
            Directory.CreateDirectory(folderPath);
            // Collect unique families from all FamilyInstance elements in the document
            var exportedFamilies = new HashSet<long>();
            var instances = new FilteredElementCollector(doc)
                .OfClass(typeof(FamilyInstance))
                .Cast<FamilyInstance>();
            foreach (FamilyInstance fi in instances) {
                Family family = fi.Symbol.Family;
                if (family == null || !exportedFamilies.Add(family.Id.Value))
                    continue;
                string familyName = SanitizeMaterialName(family.Name);
                Document famDoc = doc.EditFamily(family);
                if (famDoc == null) continue;
                try {
                    string objPath = Path.Combine(folderPath, familyName + ".obj");
                    ExportDocumentGeometryToOBJ(famDoc, objPath);
                } finally {
                    famDoc.Close(false);
                }
            }
            EnsureTransaction(uiapp);
        }

        double? TryGetFamilyParam(FamilyManager mgr, FamilyType type, string name) {
            FamilyParameter param = mgr.get_Parameter(name);
            if (param == null || !param.StorageType.Equals(StorageType.Double)) return null;
            double val = type.AsDouble(param) ?? 0;
            return val > 0 ? val : (double?)null;
        }

        double[] GetFamilyDimensions(Document famDoc) {
            FamilyManager mgr = famDoc.FamilyManager;
            FamilyType type = mgr.CurrentType;
            if (type == null && mgr.Types.Size > 0)
                type = mgr.Types.Cast<FamilyType>().First();
            if (type == null) return new double[] { 0, 0 };

            double width = TryGetFamilyParam(mgr, type, "Width")
                        ?? TryGetFamilyParam(mgr, type, "Largura")
                        ?? 0;
            double height = TryGetFamilyParam(mgr, type, "Height")
                         ?? TryGetFamilyParam(mgr, type, "Altura")
                         ?? 0;
            return new double[] { width * from_feet, height * from_feet };
        }

        public string[] ExportFamilyToOBJWithMetadata(string familyPath, string objPath) {
            CommitAndDisposeTransaction();
            Document famDoc = uiapp.Application.OpenDocumentFile(familyPath);
            try {
                ExportDocumentGeometryToOBJ(famDoc, objPath);
                double[] dims = GetFamilyDimensions(famDoc);
                string category = famDoc.OwnerFamily?.FamilyCategory?.Name ?? "Unknown";
                string objName = Path.GetFileNameWithoutExtension(objPath);
                return new string[] {
                    objName,
                    dims[0].ToString("G"),
                    dims[1].ToString("G"),
                    category
                };
            } finally {
                famDoc.Close(false);
                EnsureTransaction(uiapp);
            }
        }

        public string[][] ExportAllFamiliesToOBJWithMetadata(string folderPath) {
            CommitAndDisposeTransaction();
            Directory.CreateDirectory(folderPath);
            var results = new List<string[]>();
            var exportedFamilies = new HashSet<long>();
            var instances = new FilteredElementCollector(doc)
                .OfClass(typeof(FamilyInstance))
                .Cast<FamilyInstance>();
            foreach (FamilyInstance fi in instances) {
                Family family = fi.Symbol.Family;
                if (family == null || !exportedFamilies.Add(family.Id.Value))
                    continue;
                // Best-effort per family: some families aren't editable (in-place, certain system-owned
                // ones) and EditFamily would throw — skip them and keep exporting the rest rather than
                // aborting the whole batch.
                try {
                    if (!family.IsEditable) continue;
                    string familyName = SanitizeMaterialName(family.Name);
                    string category = fi.Category?.Name ?? "Unknown";
                    Document famDoc = doc.EditFamily(family);
                    if (famDoc == null) continue;
                    try {
                        string objPath = Path.Combine(folderPath, familyName + ".obj");
                        ExportDocumentGeometryToOBJ(famDoc, objPath);
                        double[] dims = GetFamilyDimensions(famDoc);
                        // Also save the family as a .rfa so the reconstructed program can load the REAL
                        // native family in Revit (revit_file_family), not just a system default. Revit
                        // doesn't retain a loaded family's source path, so we re-materialize one here.
                        string rfaPath = Path.Combine(folderPath, familyName + ".rfa");
                        try {
                            SaveAsOptions opts = new SaveAsOptions { OverwriteExistingFile = true };
                            famDoc.SaveAs(rfaPath, opts);
                        } catch { rfaPath = ""; }
                        results.Add(new string[] {
                            familyName,
                            dims[0].ToString("G"),
                            dims[1].ToString("G"),
                            category,
                            rfaPath
                        });
                    } finally {
                        famDoc.Close(false);
                    }
                } catch (Exception e) {
                    PlugIn.WriteMessage($"ExportAllFamiliesToOBJWithMetadata: skipped '{family?.Name}': {e.Message}");
                }
            }
            EnsureTransaction(uiapp);
            return results.ToArray();
        }

        void CollectGeometry(Document famDoc, GeometryElement geomElem,
            List<XYZ> vertices, List<XYZ> normals, List<UV> uvs,
            List<Tuple<string, List<int[][]>>> groups,
            Dictionary<string, Autodesk.Revit.DB.Color> materials,
            Dictionary<string, int> materialTransparency,
            Dictionary<string, double[]> materialPbr) {

            foreach (GeometryObject geomObj in geomElem) {
                if (geomObj is Solid solid) {
                    if (solid.Faces.Size == 0) continue;

                    // Subcategory-based filter: skip Opening/Cut geometry
                    Face firstFace = solid.Faces.get_Item(0);
                    GraphicsStyle gs = famDoc.GetElement(firstFace.GraphicsStyleId) as GraphicsStyle;
                    if (gs != null) {
                        string subcatName = gs.GraphicsStyleCategory?.Name ?? "";
                        if (subcatName.Contains("Opening") || subcatName.Contains("Cut")) continue;
                    }

                    foreach (Face face in solid.Faces) {
                        string matName = "default";
                        ElementId matId = face.MaterialElementId;
                        if (matId != ElementId.InvalidElementId) {
                            Material mat = famDoc.GetElement(matId) as Material;
                            if (mat != null) {
                                matName = SanitizeMaterialName(mat.Name);
                                if (!materials.ContainsKey(matName)) {
                                    materials[matName] = mat.Color;
                                    materialTransparency[matName] = mat.Transparency;
                                    // [roughness 0-1, Blinn-Phong exponent 0-1000] from the
                                    // graphics props (Smoothness 0-100, Shininess 0-128).
                                    materialPbr[matName] = new double[] {
                                        1.0 - mat.Smoothness / 100.0,
                                        mat.Shininess * (1000.0 / 128.0) };
                                }
                            }
                        }
                        if (!materials.ContainsKey(matName) && matName == "default") {
                            materials["default"] = new Autodesk.Revit.DB.Color(200, 200, 200);
                            materialTransparency["default"] = 0;
                            materialPbr["default"] = new double[] { 0.5, 30.0 };
                        }

                        Mesh mesh = face.Triangulate();
                        if (mesh == null) continue;

                        int vertexOffset = vertices.Count;
                        for (int i = 0; i < mesh.Vertices.Count; i++) {
                            vertices.Add(mesh.Vertices[i]);
                            // Compute face normal from first triangle as approximation
                            // UV coords not reliably available from Mesh, use placeholder
                        }
                        // Compute normals per triangle vertex
                        int normalOffset = normals.Count;
                        var faces = new List<int[][]>();
                        for (int i = 0; i < mesh.NumTriangles; i++) {
                            MeshTriangle tri = mesh.get_Triangle(i);
                            XYZ p0 = tri.get_Vertex(0);
                            XYZ p1 = tri.get_Vertex(1);
                            XYZ p2 = tri.get_Vertex(2);
                            XYZ edge1 = p1 - p0;
                            XYZ edge2 = p2 - p0;
                            XYZ normal = edge1.CrossProduct(edge2);
                            double len = normal.GetLength();
                            if (len > 1e-10) normal = normal.Normalize();
                            else normal = XYZ.BasisZ;
                            normals.Add(normal);

                            int ni = normalOffset + i + 1; // 1-based
                            int idx0 = vertexOffset + (int)tri.get_Index(0) + 1;
                            int idx1 = vertexOffset + (int)tri.get_Index(1) + 1;
                            int idx2 = vertexOffset + (int)tri.get_Index(2) + 1;
                            faces.Add(new int[][] {
                                new int[] { idx0, ni },
                                new int[] { idx1, ni },
                                new int[] { idx2, ni }
                            });
                        }
                        if (faces.Count > 0) {
                            groups.Add(Tuple.Create(matName, faces));
                        }
                    }
                } else if (geomObj is GeometryInstance geomInst) {
                    GeometryElement instGeom = geomInst.GetInstanceGeometry();
                    if (instGeom != null) {
                        CollectGeometry(famDoc, instGeom, vertices, normals, uvs, groups, materials, materialTransparency, materialPbr);
                    }
                } else if (geomObj is Mesh directMesh) {
                    int vertexOffset = vertices.Count;
                    for (int i = 0; i < directMesh.Vertices.Count; i++) {
                        vertices.Add(directMesh.Vertices[i]);
                    }
                    int normalOffset = normals.Count;
                    var faces = new List<int[][]>();
                    for (int i = 0; i < directMesh.NumTriangles; i++) {
                        MeshTriangle tri = directMesh.get_Triangle(i);
                        XYZ p0 = tri.get_Vertex(0);
                        XYZ p1 = tri.get_Vertex(1);
                        XYZ p2 = tri.get_Vertex(2);
                        XYZ edge1 = p1 - p0;
                        XYZ edge2 = p2 - p0;
                        XYZ normal = edge1.CrossProduct(edge2);
                        double len = normal.GetLength();
                        if (len > 1e-10) normal = normal.Normalize();
                        else normal = XYZ.BasisZ;
                        normals.Add(normal);

                        int ni = normalOffset + i + 1;
                        int idx0 = vertexOffset + (int)tri.get_Index(0) + 1;
                        int idx1 = vertexOffset + (int)tri.get_Index(1) + 1;
                        int idx2 = vertexOffset + (int)tri.get_Index(2) + 1;
                        faces.Add(new int[][] {
                            new int[] { idx0, ni },
                            new int[] { idx1, ni },
                            new int[] { idx2, ni }
                        });
                    }
                    if (faces.Count > 0) {
                        groups.Add(Tuple.Create("default", faces));
                        if (!materials.ContainsKey("default")) {
                            materials["default"] = new Autodesk.Revit.DB.Color(200, 200, 200);
                            materialTransparency["default"] = 0;
                        }
                    }
                }
            }
        }

        string SanitizeMaterialName(string name) {
            return name.Replace(' ', '_').Replace('/', '_').Replace('\\', '_');
        }

        void WriteOBJ(string objPath, string mtlFileName,
            List<XYZ> vertices, List<XYZ> normals, List<UV> uvs,
            List<Tuple<string, List<int[][]>>> groups) {

            using (var sw = new StreamWriter(objPath)) {
                sw.WriteLine("# Exported from Revit family by KhepriRevit");
                sw.WriteLine("mtllib " + mtlFileName);
                sw.WriteLine();

                // Vertices (convert from feet to meters)
                foreach (var v in vertices) {
                    sw.WriteLine("v {0} {1} {2}",
                        (v.X * from_feet).ToString("G"),
                        (v.Y * from_feet).ToString("G"),
                        (v.Z * from_feet).ToString("G"));
                }
                sw.WriteLine();

                // Normals
                foreach (var n in normals) {
                    sw.WriteLine("vn {0} {1} {2}",
                        n.X.ToString("G"),
                        n.Y.ToString("G"),
                        n.Z.ToString("G"));
                }
                sw.WriteLine();

                // Faces grouped by material
                string currentMat = null;
                foreach (var group in groups) {
                    if (group.Item1 != currentMat) {
                        currentMat = group.Item1;
                        sw.WriteLine("usemtl " + currentMat);
                    }
                    foreach (var face in group.Item2) {
                        var sb = new StringBuilder("f");
                        foreach (var idx in face) {
                            sb.AppendFormat(" {0}//{1}", idx[0], idx[1]);
                        }
                        sw.WriteLine(sb.ToString());
                    }
                }
            }
        }

        void WriteMTL(string mtlPath,
            Dictionary<string, Autodesk.Revit.DB.Color> materials,
            Dictionary<string, int> materialTransparency,
            Dictionary<string, double[]> materialPbr) {

            using (var sw = new StreamWriter(mtlPath)) {
                sw.WriteLine("# Material library exported from Revit family by KhepriRevit");
                foreach (var kvp in materials) {
                    string name = kvp.Key;
                    Autodesk.Revit.DB.Color color = kvp.Value;
                    double r = color.Red / 255.0;
                    double g = color.Green / 255.0;
                    double b = color.Blue / 255.0;
                    int transparency = materialTransparency.ContainsKey(name) ? materialTransparency[name] : 0;
                    double d = 1.0 - transparency / 100.0;
                    double[] pbr = materialPbr.ContainsKey(name) ? materialPbr[name] : new double[] { 0.5, 30.0 };

                    sw.WriteLine("newmtl " + name);
                    sw.WriteLine("Kd {0} {1} {2}",
                        r.ToString("F4"), g.ToString("F4"), b.ToString("F4"));
                    sw.WriteLine("d {0}", d.ToString("F4"));
                    // PBR extension keywords (consumed by the Khepri viewers and parse_mtl);
                    // Ns kept for plain Phong consumers. Revit graphics props carry no metallic.
                    sw.WriteLine("Pr {0}", pbr[0].ToString("F4"));
                    sw.WriteLine("Pm 0.0000");
                    sw.WriteLine("Ns {0}", pbr[1].ToString("F1"));
                    sw.WriteLine("illum 2");
                    sw.WriteLine();
                }
            }
        }

    }

    //RenderView http://thebuildingcoder.typepad.com/blog/2013/08/setting-a-default-3d-view-orientation.html

    class StairsFailurePreprocessor : IFailuresPreprocessor {
        public FailureProcessingResult PreprocessFailures(FailuresAccessor a) {
            foreach (var msg in a.GetFailureMessages()) {
                if (msg.GetSeverity() == FailureSeverity.Warning) {
                    a.DeleteWarning(msg);
                }
            }
            return FailureProcessingResult.Continue;
        }
    }

    /* Failures preprocessor that quiets non-fatal Revit warnings during programmatic
     * geometry creation.
     *
     * Why: Khepri drives Revit headlessly via socket RPCs. Anything that puts up a
     * modal warning dialog (e.g. "Highlighted walls overlap", "Actual Run Width is
     * less than the Minimum Run Width specified in the stair type", inaccurate-line
     * notices, etc.) blocks the API thread waiting on a human click. Tests reproduce
     * this whenever they place geometry that Revit considers unusual but not
     * invalid — typical for parametric scripting, where dimensions are deliberately
     * varied. The previous implementation only deleted a hand-curated list of
     * `InaccurateFailures.*` ids, which left stair, wall-overlap, and many other
     * warnings to surface as dialogs and freeze the run.
     *
     * What this does: at every transaction commit, walks all failures and deletes
     * any whose severity is `Warning`. Errors (FailureSeverity.Error and above) are
     * left alone — those represent operations Revit could not complete, and we want
     * them to surface as exceptions on the Julia side rather than be silently
     * dropped.
     *
     * Trade-off: this hides legitimate model warnings the user might want to see in
     * an interactive Revit session. That's acceptable because the plugin is opted
     * into by callers who explicitly want script-driven, dialog-free behaviour; an
     * interactive Revit user without the plugin loaded sees the same warnings as
     * before.
     */
    class WarningSwallower : IFailuresPreprocessor {
        public static WarningSwallower forKhepri = new WarningSwallower();

        public static void KhepriWarnings(Transaction t) {
            FailureHandlingOptions failOp = t.GetFailureHandlingOptions();
            failOp.SetFailuresPreprocessor(WarningSwallower.forKhepri);
            t.SetFailureHandlingOptions(failOp);
        }

        public FailureProcessingResult PreprocessFailures(FailuresAccessor failuresAccessor) {
            foreach (FailureMessageAccessor failure in failuresAccessor.GetFailureMessages()) {
                if (failure.GetSeverity() == FailureSeverity.Warning) {
                    failuresAccessor.DeleteWarning(failure);
                }
            }
            return FailureProcessingResult.Continue;
        }
    }
}

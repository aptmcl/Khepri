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
        static private Dictionary<string, Family> fileNameToFamily = new Dictionary<string, Family>();
        static private Dictionary<Family, Dictionary<string, FamilySymbol>> loadedFamiliesSymbols =
            new Dictionary<Family, Dictionary<string, FamilySymbol>>();

        public Primitives(UIApplication app) : base() {
            uiapp = app;
            doc = uiapp.ActiveUIDocument.Document;
            CurrentMaterialId = ElementId.InvalidElementId;
        }

        public void UpdateDocument(Document newDoc) {
            doc = newDoc;
        }

        public void EnsureTransaction(UIApplication app) {
            Document activeDoc = app.ActiveUIDocument.Document;
            if (CurrentTransaction == null || !activeDoc.Equals(doc)) {
                CommitAndDisposeTransaction();
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
            // Perpendicular to chord in the horizontal plane, pointing left of p0→p1
            double chordLenXY = Math.Sqrt(v.X * v.X + v.Y * v.Y);
            XYZ perp = chordLenXY > 1e-10
                ? new XYZ(-v.Y / chordLenXY, v.X / chordLenXY, 0)
                : new XYZ(0, 1, 0);
            XYZ arcMid = chordMid + perp * sagitta;
            return Arc.Create(p0, arcMid, p1);
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

        public Element Sphere(XYZ centre, Length radius) {
            Frame frame = new Frame(centre, XYZ.BasisX, XYZ.BasisY, XYZ.BasisZ);
            XYZ p0 = centre - radius * frame.BasisZ;
            XYZ p1 = centre + radius * frame.BasisZ;
            Arc arc = Arc.Create(p0, p1, centre + radius * XYZ.BasisX);
            Line line = Line.CreateBound(p1, p0);
            return ElementFromSolid("Sphere", GeometryCreationUtilities.CreateRevolvedGeometry(
                frame,
                new List<CurveLoop>() { CurveLoop.Create(new List<Curve>(2) { arc, line }) },
                0, 2 * Math.PI));
        }
        public Element ConeFrustumNamed(string name, XYZ bottom, VXYZ axis, Length bottomRadius, Length height, Length topRadius) {
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
            return ElementFromSolid(name, GeometryCreationUtilities.CreateRevolvedGeometry(
                frame,
                new CurveLoop[] { CurveLoop.Create(profile) },
                0, 2 * Math.PI));
        }
        public Element ConeFrustum(XYZ bottom, VXYZ axis, Length bottomRadius, Length height, Length topRadius) =>
            ConeFrustumNamed("ConeFrustum", bottom, axis, bottomRadius, height, topRadius);
        public Element Cylinder(XYZ bottom, VXYZ axis, Length radius, Length height) =>
            ConeFrustumNamed("Cylinder", bottom, axis, radius, height, radius);
        public Element Cone(XYZ bottom, VXYZ axis, Length bottomRadius, Length height) {
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
                0, 2 * Math.PI));
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

        Solid SolidFromElement(Element e) {
            Options opt = new Options();
            GeometryElement geo = e.get_Geometry(opt);
            Solid union = null;
            foreach (GeometryObject obj in geo) {
                Solid solid = obj as Solid;
                union = union == null ?
                    solid :
                    BooleanOperationsUtils.ExecuteBooleanOperation(
                        union, solid,
                        BooleanOperationsType.Union);
            }
            return union;
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

        public Level FindLevelAtElevation(Length elevation) =>
            new FilteredElementCollector(doc)
                .WherePasses(new ElementClassFilter(typeof(Level), false))
                .Cast<Level>().FirstOrDefault(e => e.Elevation == elevation);

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

        public String InstalledLibraryPath(String kind) {
            string libraryPath = "";
            uiapp.Application.GetLibraryPaths().TryGetValue(kind, out libraryPath);
            return libraryPath;
        }

        class LoadFamilyOptions : IFamilyLoadOptions {
            public bool OnFamilyFound(bool familyInUse, out bool overwriteParameterValues) {
                overwriteParameterValues = true;
                return true;
            }
            public bool OnSharedFamilyFound(Family sharedFamily, bool familyInUse, out FamilySource source, out bool overwriteParameterValues) {
                source = FamilySource.Family;
                overwriteParameterValues = true;
                return true;
            }
        }

        public Family LoadFamily(string fileName) {
            Family family;
            if (!fileNameToFamily.TryGetValue(fileName, out family)) {
                Debug.Assert(doc.LoadFamily(fileName, new LoadFamilyOptions(), out family));
                fileNameToFamily[fileName] = family;
            }
            return family;
        }

        bool FamilyElementMatches(FamilySymbol symb, string[] names, Length[] values) {
            double epsilon = 0.022;
            for (int i = 0; i < names.Length; i++) {
                foreach (var parameter in symb.GetParameters(names[i])) {
                    double valueTest = parameter.AsDouble();
                    if (Math.Abs(valueTest - values[i]) > epsilon) {
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
        public ElementId CreatePolygonalFloor(XYZ[] pts, Level level, ElementId famId) {
            FloorType floorType = (famId != null && famId != ElementId.InvalidElementId) ?
                doc.GetElement(famId) as FloorType :
                new FilteredElementCollector(doc).OfClass(typeof(FloorType)).First() as FloorType;
            Floor floor = Floor.Create(doc, new List<CurveLoop> { PolygonCurveLoop(pts) }, floorType.Id, level.Id);
            floor.get_Parameter(BuiltInParameter.FLOOR_HEIGHTABOVELEVEL_PARAM).Set(0); //Below the level line
            return floor.Id;
        }
        public ElementId CreatePathFloor(XYZ[] pts, double[] angles, Level level, ElementId famId) {
            FloorType floorType = (famId != null && famId != ElementId.InvalidElementId) ?
                doc.GetElement(famId) as FloorType :
                new FilteredElementCollector(doc).OfClass(typeof(FloorType)).First() as FloorType;
            Floor floor = Floor.Create(doc, new List<CurveLoop> { CurveLoopPath(pts, angles) }, floorType.Id, level.Id);
            floor.get_Parameter(BuiltInParameter.FLOOR_HEIGHTABOVELEVEL_PARAM).Set(0); //Below the level line
            return floor.Id;
        }
        public ElementId CreatePolygonalRoof(XYZ[] pts, Level level, ElementId famId) {
            RoofType roofType = null;
            if (famId != null) {
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
            if (famId != null) {
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
            FamilySymbol symbol = (famId == null) ?
                GetFirstSymbol(FindCategoryFamilies(doc, BuiltInCategory.OST_Columns).FirstOrDefault()) :
                doc.GetElement(famId) as FamilySymbol;
            if (!symbol.IsActive) { symbol.Activate(); doc.Regenerate(); }
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
            if (famId == null) {
                Family defaultBeamFam = FindCategoryFamilies(doc, BuiltInCategory.OST_StructuralFraming).First();
                symbol = doc.GetElement(defaultBeamFam.GetFamilySymbolIds().First()) as FamilySymbol;
            } else {
                symbol = doc.GetElement(famId) as FamilySymbol;
            }
            if (!symbol.IsActive) { symbol.Activate(); doc.Regenerate(); }
            FamilyInstance beam = doc.Create.NewFamilyInstance(Line.CreateBound(p0, p1), symbol, null, StructuralType.Beam);
            if (rotationAngle != 0.0) {
                beam.get_Parameter(BuiltInParameter.STRUCTURAL_BEND_DIR_ANGLE).Set(rotationAngle);
            }
            return beam.Id;
        }
        public Element CreateElementLocDirOnHost(XYZ location, XYZ direction, Element host, ElementId famId) {
            FamilySymbol symbol = doc.GetElement(famId) as FamilySymbol;
            if (!symbol.IsActive) { symbol.Activate(); doc.Regenerate(); }
            FamilyInstance elem = doc.Create.NewFamilyInstance(location, symbol, direction, host, StructuralType.NonStructural);
            //col.get_Parameter(BuiltInParameter.FAMILY_TOP_LEVEL_PARAM).Set(level1.Id);
            //col.get_Parameter(BuiltInParameter.FAMILY_TOP_LEVEL_OFFSET_PARAM).Set(0.0);
            //col.get_Parameter(BuiltInParameter.FAMILY_BASE_LEVEL_OFFSET_PARAM).Set(0.0);
            return elem;
        }
        public ElementId[] CreateLineWall(XYZ[] pts, ElementId baseLevelId, ElementId topLevelId, ElementId famId) {
            ElementId[] ids = new ElementId[pts.Length - 1];
            for (int i = 0; i < pts.Length - 1; i++) {
                Wall wall = Wall.Create(doc, Line.CreateBound(pts[i], pts[i + 1]), baseLevelId, false);
                if (famId != null) {
                    wall.WallType = doc.GetElement(famId) as WallType;
                }
                wall.get_Parameter(BuiltInParameter.WALL_HEIGHT_TYPE).Set(topLevelId);
                ids[i] = wall.Id;
            }
            // IS THIS WORKING???
            doc.AutoJoinElements();
            return ids;
        }
        public ElementId[] CreateUnconnectedLineWall(XYZ[] pts, ElementId baseLevelId, double height, ElementId famId) {
            ElementId wallTypeId = doc.GetDefaultElementTypeId(ElementTypeGroup.WallType);
            ElementId[] ids = new ElementId[pts.Length - 1];
            for (int i = 0; i < pts.Length - 1; i++) {
                Wall wall = Wall.Create(doc, Line.CreateBound(pts[i], pts[i + 1]), wallTypeId, baseLevelId, height, 0, false, false);
                if (famId != null) {
                    wall.WallType = doc.GetElement(famId) as WallType;
                }
                ids[i] = wall.Id;
            }
            // IS THIS WORKING???
            doc.AutoJoinElements();
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
                if (famId != null) {
                    wall.WallType = doc.GetElement(famId) as WallType;
                }
                wall.get_Parameter(BuiltInParameter.WALL_HEIGHT_TYPE).Set(topLevelId);
                ids[i] = wall.Id;
            }
            doc.AutoJoinElements();
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
            doc.AutoJoinElements();
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
            WallType wallType = new FilteredElementCollector(doc).OfClass(typeof(WallType)).Cast<WallType>().FirstOrDefault(q => q.Name == "M_Storefront");
            CurveArray curves = PathCurveArray(pts, angles);
            List<ElementId> ids = new List<ElementId>();
            foreach (Curve curve in curves) {
                Wall wall = Wall.Create(doc, curve, baseLevelId, isStructural);
                wall.WallType = wallType;
                ids.Add(wall.Id);
                wall.get_Parameter(BuiltInParameter.WALL_HEIGHT_TYPE).Set(topLevelId);
            }
            CurrentTransaction.Commit();
            CurrentTransaction.Start();
            doc.AutoJoinElements();
            return ids.ToArray();
        }

        //AML Revit cannot handle walls with curves that are not lines or arcs!!!!
        /*
        public ElementId CreateSplineWall(XYZ[] pts, ElementId baseLevelId, ElementId topLevelId, ElementId famId, bool closed) {
            Wall wall = Wall.Create(doc, HermiteSpline.Create(pts, false), baseLevelId, closed);
            if (famId != null) {
                wall.WallType = doc.GetElement(famId) as WallType;
            }
            wall.get_Parameter(BuiltInParameter.WALL_HEIGHT_TYPE).Set(topLevelId);
            return wall.Id;
        }
        public ElementId CreateSplineCurtainWall(XYZ[] pts, ElementId baseLevelId, ElementId topLevelId, ElementId famId, bool closed) {
            WallType wallType = new FilteredElementCollector(doc).OfClass(typeof(WallType)).Cast<WallType>().FirstOrDefault(q => q.Name == "M_Storefront");
            Wall wall = Wall.Create(doc, HermiteSpline.Create(pts, false), baseLevelId, closed);
            if (famId != null) {
                wall.WallType = wallType;
            }
            wall.get_Parameter(BuiltInParameter.WALL_HEIGHT_TYPE).Set(topLevelId);
            return wall.Id;
        }
        */
        //Introspection
        public XYZ[] LineWallVertices(Element element) {
            Wall wall = (Wall)element;
            Line l = (wall.Location as LocationCurve).Curve as Line;
            return new XYZ[] { l.GetEndPoint(0), l.GetEndPoint(1) };
        }
        public ElementId ElementLevel(Element element) => element.LevelId;
        // Walls can have unconnected height
        public ElementId WallTopLevel(Element element) => 
            element.get_Parameter(BuiltInParameter.WALL_HEIGHT_TYPE).AsElementId();
        public double WallHeight(Element element) =>
            element.get_Parameter(BuiltInParameter.WALL_USER_HEIGHT_PARAM).AsDouble();

        public Element InsertDoor(Length deltaFromStart, Length deltaFromGround, Element host, ElementId familyId) {
            LocationCurve locCurve = host.Location as LocationCurve;
            XYZ start = locCurve.Curve.GetEndPoint(0);
            XYZ dir = locCurve.Curve.GetEndPoint(1) - start;
            XYZ location = start + dir.Normalize() * deltaFromStart;
            FamilySymbol symbol = (familyId == null) ?
                GetFirstSymbol(FindCategoryFamilies(doc, BuiltInCategory.OST_Doors).FirstOrDefault()) :
                doc.GetElement(familyId) as FamilySymbol;
            if (!symbol.IsActive) { symbol.Activate(); doc.Regenerate(); }
            FamilyInstance door = doc.Create.NewFamilyInstance(location, symbol, host,
                host.Document.GetElement(host.LevelId) as Level,
                StructuralType.NonStructural);
            door.get_Parameter(BuiltInParameter.INSTANCE_SILL_HEIGHT_PARAM)?.Set(deltaFromGround);
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
        static void SetParameters(FamilyInstance obj, string[] names, object[] values) {
            for (int i = 0; i < names.Length; i++) {
                foreach (var parameter in obj.GetParameters(names[i])) {
                    SetParameter(parameter, values[i]);
                }
            }
        }
        public Element InsertWindow(Length deltaFromStart, Length deltaFromGround, Element host, ElementId familyId, string[] names, object[] values) {
            LocationCurve locCurve = host.Location as LocationCurve;
            XYZ start = locCurve.Curve.GetEndPoint(0);
            XYZ dir = locCurve.Curve.GetEndPoint(1) - start;
            XYZ location = start + dir.Normalize() * deltaFromStart;
            FamilySymbol symbol = (familyId == null) ?
                GetFirstSymbol(FindCategoryFamilies(doc, BuiltInCategory.OST_Windows).FirstOrDefault()) :
                doc.GetElement(familyId) as FamilySymbol;
            if (!symbol.IsActive) { symbol.Activate(); doc.Regenerate(); }
            FamilyInstance window = doc.Create.NewFamilyInstance(location, symbol, host,
                host.Document.GetElement(host.LevelId) as Level,
                StructuralType.NonStructural);
            window.get_Parameter(BuiltInParameter.INSTANCE_SILL_HEIGHT_PARAM).Set(deltaFromGround);
            SetParameters(window, names, values);
            return window;
        }
        public Element InsertRailing(Element host, ElementId familyId) {
            FamilySymbol symbol = (familyId == null) ?
                GetFirstSymbol(FindCategoryFamilies(doc, BuiltInCategory.OST_StairsRailing).FirstOrDefault()) :
                doc.GetElement(familyId) as FamilySymbol;
            if (!symbol.IsActive) { symbol.Activate(); doc.Regenerate(); }
            return doc.Create.NewFamilyInstance(new XYZ(10, 10, 0), symbol, host,
                host.Document.GetElement(host.LevelId) as Level,
                StructuralType.NonStructural);
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
            CurrentTransaction.Commit();
            Family family = new FilteredElementCollector(doc)
                .OfClass(typeof(Family)).Cast<Family>()
                .FirstOrDefault<Family>(e => e.Name.Equals(familyName));
            familyDoc = family?.Document ??
                uiapp.Application.NewFamilyDocument(Path.Combine(familyTemplatesPath, familyTemplateName + familyTemplateExt));
            CurrentTransaction.Start();
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
            CurrentTransaction.Commit();
            uiapp.ActiveUIDocument.ActiveView = view3D;
            uiapp.ActiveUIDocument.RefreshActiveView();
            UIDocument uidoc = uiapp.ActiveUIDocument;
            UIView uiview = uidoc.GetOpenUIViews().First(uv=>uv.ViewId.Equals(view3D.Id));
            uiview.ZoomSheetSize();
            CurrentTransaction.Start();
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
            CurrentTransaction.Commit();
            var options = new ImageExportOptions();
            options.ExportRange = ExportRange.VisibleRegionOfCurrentView;
            options.FilePath = path;
            options.ShadowViewsFileType = (Path.GetExtension(path) == ".png") ? 
                ImageFileType.PNG : 
                ImageFileType.JPEGLossless;
            doc.ExportImage(options);
            CurrentTransaction.Start();
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
        public void DeleteAllElements() {
            foreach (Element e in AllElements()) {
                doc.Delete(e.Id);
            }
        }
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

        public Element[] DocWalls() =>
            (new FilteredElementCollector(doc).OfClass(typeof(Wall)))
            .Cast<Wall>()
            .Where(w => w.Location is LocationCurve && !IsGroupMember(w))
            .Cast<Element>()
            .ToArray();
        public Element[] DocWallsAtLevel(Level level) =>
            (new FilteredElementCollector(doc).OfClass(typeof(Wall)))
            .WherePasses(new ElementLevelFilter(level.Id))
            .Cast<Wall>()
            .Where(w => w.Location is LocationCurve)
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

        // Floor introspection
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
        public Length[] HostedElementPosition(Element element) {
            FamilyInstance fi = element as FamilyInstance;
            if (fi?.Host == null) return new Length[] { new Length(0), new Length(0) };
            LocationCurve hostLoc = fi.Host.Location as LocationCurve;
            if (hostLoc == null) return new Length[] { new Length(0), new Length(0) };
            LocationPoint locPt = fi.Location as LocationPoint;
            if (locPt == null) return new Length[] { new Length(0), new Length(0) };
            XYZ elemPt = locPt.Point;
            Curve hostCurve = hostLoc.Curve;
            IntersectionResult result = hostCurve.Project(elemPt);
            // Compute distance along curve from start to projected point
            double distFromStart = 0;
            if (result != null) {
                XYZ startPt = hostCurve.GetEndPoint(0);
                XYZ projPt = result.XYZPoint;
                distFromStart = startPt.DistanceTo(projPt);
            }
            // Sill height
            double sillHeight = fi.get_Parameter(BuiltInParameter.INSTANCE_SILL_HEIGHT_PARAM)?.AsDouble() ?? 0;
            return new Length[] { new Length(distFromStart), new Length(sillHeight) };
        }
        public Length[] DoorWindowDimensions(Element element) {
            FamilyInstance fi = element as FamilyInstance;
            FamilySymbol sym = fi?.Symbol;
            double width = sym?.get_Parameter(BuiltInParameter.DOOR_WIDTH)?.AsDouble()
                        ?? sym?.get_Parameter(BuiltInParameter.WINDOW_WIDTH)?.AsDouble()
                        ?? sym?.get_Parameter(BuiltInParameter.FAMILY_WIDTH_PARAM)?.AsDouble()
                        ?? 0;
            double height = sym?.get_Parameter(BuiltInParameter.DOOR_HEIGHT)?.AsDouble()
                         ?? sym?.get_Parameter(BuiltInParameter.WINDOW_HEIGHT)?.AsDouble()
                         ?? sym?.get_Parameter(BuiltInParameter.FAMILY_HEIGHT_PARAM)?.AsDouble()
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
                .Where(e => !IsGroupMember(e) && e.Location is LocationPoint)
                .ToArray();
        // Plumbing fixture introspection
        public Element[] DocPlumbingFixtures() =>
            new FilteredElementCollector(doc)
                .OfCategory(BuiltInCategory.OST_PlumbingFixtures)
                .WhereElementIsNotElementType()
                .Where(e => !IsGroupMember(e) && e.Location is LocationPoint)
                .ToArray();
        // Casework introspection
        public Element[] DocCasework() =>
            new FilteredElementCollector(doc)
                .OfCategory(BuiltInCategory.OST_Casework)
                .WhereElementIsNotElementType()
                .Where(e => !IsGroupMember(e) && e.Location is LocationPoint)
                .ToArray();
        // Generic model introspection
        public Element[] DocGenericModels() =>
            new FilteredElementCollector(doc)
                .OfCategory(BuiltInCategory.OST_GenericModel)
                .WhereElementIsNotElementType()
                .Where(e => !IsGroupMember(e) && e.Location is LocationPoint)
                .ToArray();
        // Specialty equipment introspection
        public Element[] DocSpecialtyEquipment() =>
            new FilteredElementCollector(doc)
                .OfCategory(BuiltInCategory.OST_SpecialityEquipment)
                .WhereElementIsNotElementType()
                .Where(e => !IsGroupMember(e) && e.Location is LocationPoint)
                .ToArray();
        // Generic FamilyInstance introspection helpers
        public XYZ FamilyInstanceLocation(Element element) =>
            (element.Location as LocationPoint)?.Point ?? XYZ.Zero;
        public double FamilyInstanceRotation(Element element) =>
            (element.Location as LocationPoint)?.Rotation ?? 0.0;
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
        public Element CreateStraightStair(XYZ basePoint, XYZ direction, double width,
                                            Level baseLevel, Level topLevel, ElementId familyId) {
            CurrentTransaction.Commit();
            ElementId stairsId;
            using (var scope = new StairsEditScope(doc, "Create Stairs")) {
                stairsId = scope.Start(baseLevel.Id, topLevel.Id);
                XYZ dir = direction.Normalize();
                double height = topLevel.Elevation - baseLevel.Elevation;
                StairsRun run = StairsRun.CreateStraightRun(doc, stairsId,
                    Line.CreateBound(basePoint, basePoint + dir * height * 1.6),
                    StairsRunJustification.Center);
                run.ActualRunWidth = width;
                scope.Commit(new StairsFailurePreprocessor());
            }
            CurrentTransaction.Start();
            if (familyId != null && familyId != ElementId.InvalidElementId) {
                doc.GetElement(stairsId).ChangeTypeId(familyId);
            }
            return doc.GetElement(stairsId);
        }

        // Stair (Spiral)
        public Element CreateSpiralStair(XYZ center, double radius, double startAngle,
                                          double includedAngle, bool clockwise, double width,
                                          Level baseLevel, Level topLevel, ElementId familyId) {
            CurrentTransaction.Commit();
            ElementId stairsId;
            using (var scope = new StairsEditScope(doc, "Create Spiral Stairs")) {
                stairsId = scope.Start(baseLevel.Id, topLevel.Id);
                StairsRun run = StairsRun.CreateSpiralRun(doc, stairsId,
                    center, radius, startAngle, includedAngle,
                    clockwise, StairsRunJustification.Center);
                run.ActualRunWidth = width;
                scope.Commit(new StairsFailurePreprocessor());
            }
            CurrentTransaction.Start();
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

            var collector = new FilteredElementCollector(geomDoc);
            foreach (Element elem in collector.WhereElementIsNotElementType()) {
                // Skip void forms (opening cuts in door/window families)
                if (elem is GenericForm gf && !gf.IsSolid) continue;

                GeometryElement geomElem = elem.get_Geometry(options);
                if (geomElem == null) continue;
                CollectGeometry(geomDoc, geomElem, vertices, normals, uvs, groups, materials, materialTransparency);
            }

            if (vertices.Count > 0) {
                WriteOBJ(objPath, mtlFileName, vertices, normals, uvs, groups);
                WriteMTL(mtlPath, materials, materialTransparency);
            }
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
                string familyName = SanitizeMaterialName(family.Name);
                string category = fi.Category?.Name ?? "Unknown";
                Document famDoc = doc.EditFamily(family);
                if (famDoc == null) continue;
                try {
                    string objPath = Path.Combine(folderPath, familyName + ".obj");
                    ExportDocumentGeometryToOBJ(famDoc, objPath);
                    double[] dims = GetFamilyDimensions(famDoc);
                    results.Add(new string[] {
                        familyName,
                        dims[0].ToString("G"),
                        dims[1].ToString("G"),
                        category
                    });
                } finally {
                    famDoc.Close(false);
                }
            }
            EnsureTransaction(uiapp);
            return results.ToArray();
        }

        void CollectGeometry(Document famDoc, GeometryElement geomElem,
            List<XYZ> vertices, List<XYZ> normals, List<UV> uvs,
            List<Tuple<string, List<int[][]>>> groups,
            Dictionary<string, Autodesk.Revit.DB.Color> materials,
            Dictionary<string, int> materialTransparency) {

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
                                }
                            }
                        }
                        if (!materials.ContainsKey(matName) && matName == "default") {
                            materials["default"] = new Autodesk.Revit.DB.Color(200, 200, 200);
                            materialTransparency["default"] = 0;
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
                        CollectGeometry(famDoc, instGeom, vertices, normals, uvs, groups, materials, materialTransparency);
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
            Dictionary<string, int> materialTransparency) {

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

                    sw.WriteLine("newmtl " + name);
                    sw.WriteLine("Kd {0} {1} {2}",
                        r.ToString("F4"), g.ToString("F4"), b.ToString("F4"));
                    sw.WriteLine("d {0}", d.ToString("F4"));
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

    class WarningSwallower : IFailuresPreprocessor {
        private List<FailureDefinitionId> failureDefinitionIdList = null;
        public static WarningSwallower forKhepri = new WarningSwallower();

        public static void KhepriWarnings(Transaction t) {
            FailureHandlingOptions failOp = t.GetFailureHandlingOptions();
            failOp.SetFailuresPreprocessor(WarningSwallower.forKhepri);
            t.SetFailureHandlingOptions(failOp);
        }

        public WarningSwallower() {
            failureDefinitionIdList = new List<FailureDefinitionId>();
            failureDefinitionIdList.Add(BuiltInFailures.InaccurateFailures.InaccurateLine);
            failureDefinitionIdList.Add(BuiltInFailures.InaccurateFailures.InaccurateWall);
            failureDefinitionIdList.Add(BuiltInFailures.InaccurateFailures.InaccurateAreaLine);
            failureDefinitionIdList.Add(BuiltInFailures.InaccurateFailures.InaccurateBeamOrBrace);
            failureDefinitionIdList.Add(BuiltInFailures.InaccurateFailures.InaccurateCurveBasedFamily);
            failureDefinitionIdList.Add(BuiltInFailures.InaccurateFailures.InaccurateDriveCurve);
            failureDefinitionIdList.Add(BuiltInFailures.InaccurateFailures.InaccurateGrid);
            failureDefinitionIdList.Add(BuiltInFailures.InaccurateFailures.InaccurateLevel);
            failureDefinitionIdList.Add(BuiltInFailures.InaccurateFailures.InaccurateMassingSketchLine);
            failureDefinitionIdList.Add(BuiltInFailures.InaccurateFailures.InaccurateRefPlane);
            failureDefinitionIdList.Add(BuiltInFailures.InaccurateFailures.InaccurateRoomSeparation);
            failureDefinitionIdList.Add(BuiltInFailures.InaccurateFailures.InaccurateSketchLine);
            failureDefinitionIdList.Add(BuiltInFailures.InaccurateFailures.InaccurateSpaceSeparation);
        }
        public FailureProcessingResult PreprocessFailures(FailuresAccessor failuresAccessor) {
            foreach (FailureMessageAccessor failure in failuresAccessor.GetFailureMessages()) {
                FailureDefinitionId failID = failure.GetFailureDefinitionId();
                if (failureDefinitionIdList.Exists(e => e.Guid.ToString() == failID.Guid.ToString())) {
                    failuresAccessor.DeleteWarning(failure);
                }
            }
            return FailureProcessingResult.Continue;
        }
    }
}

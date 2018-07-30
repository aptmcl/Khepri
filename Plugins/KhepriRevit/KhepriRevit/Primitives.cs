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
using System.Text;
using System.Threading.Tasks;
using Autodesk.Revit.DB.Structure;
using VXYZ = Autodesk.Revit.DB.XYZ;
using Length = System.Double;

namespace KhepriRevit {
    public class Primitives : KhepriBase.Primitives {
        private UIApplication uiapp;
        private Document doc;
        private Document familyDoc;
        public Transaction CurrentTransaction { get; set; }
        static private int levelCounter = 3;
        static private int customFamilyCounter = 0;
        static private Dictionary<string, Family> fileNameToFamily = new Dictionary<string, Family>();
        static private Dictionary<Family, Dictionary<string, FamilySymbol>> loadedFamiliesSymbols =
            new Dictionary<Family, Dictionary<string, FamilySymbol>>();

        public Primitives(UIApplication app) : base() {
            uiapp = app;
            doc = uiapp.ActiveUIDocument.Document;
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
            VXYZ v = p1 - p0;
            double d2 = v.X * v.X + v.Y * v.Y;
            double r2 = d2 / (2 * (1 - Math.Cos(angle)));
            double l = Math.Sqrt(r2 - d2 / 4);
            XYZ m = p0 + v * 0.5;
            double phi = Math.Atan2(v.Y, v.X) + Math.PI / 2;
            XYZ center = m + new VXYZ(l * Math.Cos(phi), l * Math.Sin(phi), 0);
            double radius = Math.Sqrt(r2);
            VXYZ v1 = p0 - center;
            double startAngle = Math.Atan2(v1.Y, v1.X);
            return Arc.Create(center, radius, startAngle, startAngle + angle, new XYZ(1, 0, 0), new XYZ(0, 1, 0));
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

        public void MoveElement(ElementId id, XYZ translation) =>
            ElementTransformUtils.MoveElement(doc, id, translation);

        public void RotateElement(ElementId id, double angle, XYZ axis0, XYZ axis1) =>
            ElementTransformUtils.RotateElement(doc, id, Line.CreateBound(axis0, axis1), angle);
        
        private static IEnumerable<Family> FindCategoryFamilies(Document doc, BuiltInCategory cat) =>
            new FilteredElementCollector(doc)
                .OfClass(typeof(Family))
                .Cast<Family>()
                .Where(e => e.FamilyCategory != null && e.FamilyCategory.Id.IntegerValue == (int)cat);

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
            return (level == null) ? CreateLevelAtElevation(elevation) : level;
        }
        public Level UpperLevel(Level level, Length addedElevation) =>
            FindOrCreateLevelAtElevation(level.Elevation + addedElevation);
        public Length GetLevelElevation(Level level) => level.Elevation;

        public Material GetMaterial(string name) =>
            new FilteredElementCollector(doc)
                .WherePasses(new ElementClassFilter(typeof(Material)))
                .Cast<Material>().FirstOrDefault(e => e.Name.ToString().Equals(name));

        public Family LoadFamily(string fileName) {
            Family family;
            if (!fileNameToFamily.TryGetValue(fileName, out family)) {
                Debug.Assert(doc.LoadFamily(fileName, out family));
                fileNameToFamily[fileName] = family;
            }
            return family;
        }

        bool FamilyElementMatches(FamilySymbol symb, string[] namesList, Length[] valuesList) {
            double epsilon = 0.022;
            for (int i = 0; i < namesList.Length; i++) {
                foreach (var parameter in symb.GetParameters(namesList[i])) {
                    double valueTest = parameter.AsDouble();
                    if (Math.Abs(valueTest - valuesList[i]) > epsilon) {
                        return false;
                    }
                }
            }
            return true;
        }
        public ElementId FamilyElement(Family family, string[] namesList, Length[] valuesList) {
            Dictionary<string, FamilySymbol> loadedFamilySymbols;
            if (!loadedFamiliesSymbols.TryGetValue(family, out loadedFamilySymbols)) {
                loadedFamilySymbols = new Dictionary<string, FamilySymbol>();
                loadedFamiliesSymbols[family] = loadedFamilySymbols;
            }
            string parametersStr = "";
            for (int i = 0; i < namesList.Length; i++) {
                parametersStr += namesList[i] + ":" + valuesList[i] + ",";
            }
            FamilySymbol familySymbol;
            if (!loadedFamilySymbols.TryGetValue(parametersStr, out familySymbol)) {
                familySymbol = family.GetFamilySymbolIds()
                    .Select(id => doc.GetElement(id) as FamilySymbol)
                    .FirstOrDefault(sym => FamilyElementMatches(sym, namesList, valuesList));
                if (familySymbol == null) {
                    familySymbol = doc.GetElement(family.GetFamilySymbolIds().First()) as FamilySymbol;
                    string nName = "CustomFamily" + customFamilyCounter.ToString();
                    customFamilyCounter++;
                    familySymbol = familySymbol.Duplicate(nName) as FamilySymbol;
                    for (int i = 0; i < namesList.Length; i++) {
                        foreach (var parameter in familySymbol.GetParameters(namesList[i])) {
                            parameter.Set(valuesList[i]);
                        }
                    }
                }
                loadedFamilySymbols[parametersStr] = familySymbol;
            }
            return familySymbol.Id;
        }
        public ElementId CreatePolygonalFloor(XYZ[] pts, Level level) {
            FloorType floorType = new FilteredElementCollector(doc).OfClass(typeof(FloorType)).First() as FloorType;
            Floor floor = doc.Create.NewFloor(PolygonalCurveArray(pts), floorType, level, false);
            floor.get_Parameter(BuiltInParameter.FLOOR_HEIGHTABOVELEVEL_PARAM).Set(0); //Below the level line
            return floor.Id;
        }
        public ElementId CreatePathFloor(XYZ[] pts, double[] angles, Level level) {
            FloorType floorType = new FilteredElementCollector(doc).OfClass(typeof(FloorType)).First() as FloorType;
            Floor floor = doc.Create.NewFloor(ClosedPathCurveArray(pts, angles), floorType, level, false);
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
            FamilyInstance col = doc.Create.NewFamilyInstance(location, symbol, level0, Autodesk.Revit.DB.Structure.StructuralType.Column);
            col.get_Parameter(BuiltInParameter.FAMILY_TOP_LEVEL_PARAM).Set(level1.Id);
            col.get_Parameter(BuiltInParameter.FAMILY_TOP_LEVEL_OFFSET_PARAM).Set(0.0);
            col.get_Parameter(BuiltInParameter.FAMILY_BASE_LEVEL_OFFSET_PARAM).Set(0.0);
            return col;
        }
        public Element CreateColumnPoints(XYZ p0, XYZ p1, Level level0, Level level1, ElementId famId) {
            FamilyInstance col = CreateColumn(p0, level0, level1, famId) as FamilyInstance;
            col.get_Parameter(BuiltInParameter.SLANTED_COLUMN_TYPE_PARAM).Set(2);
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
            FamilyInstance beam = doc.Create.NewFamilyInstance(Line.CreateBound(p0, p1), symbol, null, Autodesk.Revit.DB.Structure.StructuralType.Beam);
            if (rotationAngle != 0.0) {
                beam.get_Parameter(BuiltInParameter.STRUCTURAL_BEND_DIR_ANGLE).Set(rotationAngle);
            }
            return beam.Id;
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
        public ElementId CreateSplineWall(XYZ[] pts, ElementId baseLevelId, ElementId topLevelId, ElementId famId, bool closed) {
            Wall wall = Wall.Create(doc, HermiteSpline.Create(pts, false), baseLevelId, closed);
            if (famId != null) {
                wall.WallType = doc.GetElement(famId) as WallType;
            }
            wall.get_Parameter(BuiltInParameter.WALL_HEIGHT_TYPE).Set(topLevelId);
            return wall.Id;
        }
        //Introspection
        public XYZ[] LineWallVertices(Element element) {
            Wall wall = (Wall)element;
            Line l = (wall.Location as LocationCurve).Curve as Line;
            return new XYZ[] { l.GetEndPoint(0), l.GetEndPoint(1) };
        }
        public ElementId ElementLevel(Element element) => element.LevelId;
        public ElementId WallTopLevel(Element element) =>
            element.get_Parameter(BuiltInParameter.WALL_HEIGHT_TYPE).AsElementId();

        //HACK deltaFromGround is not used
        public Element InsertDoor(Length deltaFromStart, Length deltaFromGround, Element host, ElementId familyId) {
            LocationCurve locCurve = host.Location as LocationCurve;
            XYZ start = locCurve.Curve.GetEndPoint(0);
            XYZ dir = locCurve.Curve.GetEndPoint(1) - start;
            XYZ location = start + dir.Normalize() * deltaFromStart;
            FamilySymbol symbol = (familyId == null) ?
                GetFirstSymbol(FindCategoryFamilies(doc, BuiltInCategory.OST_Doors).FirstOrDefault()) :
                doc.GetElement(familyId) as FamilySymbol;
            if (!symbol.IsActive) { symbol.Activate(); doc.Regenerate(); }
            return doc.Create.NewFamilyInstance(location, symbol, host,
                host.Document.GetElement(host.LevelId) as Level,
                Autodesk.Revit.DB.Structure.StructuralType.NonStructural);
        }
        public Element InsertWindow(Length deltaFromStart, Length deltaFromGround, Element host, ElementId familyId) {
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
                Autodesk.Revit.DB.Structure.StructuralType.NonStructural);
            window.get_Parameter(BuiltInParameter.INSTANCE_SILL_HEIGHT_PARAM).Set(deltaFromGround);
            return window;
        }
        public Element InsertRailing(Element host, ElementId familyId) {
            FamilySymbol symbol = (familyId == null) ?
                GetFirstSymbol(FindCategoryFamilies(doc, BuiltInCategory.OST_StairsRailing).FirstOrDefault()) :
                doc.GetElement(familyId) as FamilySymbol;
            if (!symbol.IsActive) { symbol.Activate(); doc.Regenerate(); }
            return doc.Create.NewFamilyInstance(new XYZ(10, 10, 0), symbol, host,
                host.Document.GetElement(host.LevelId) as Level,
                Autodesk.Revit.DB.Structure.StructuralType.NonStructural);
        }
        public Element CreateLineRailing(XYZ[] pts, ElementId baseLevelId, ElementId familyId) {
            ElementId RailingTypeId = new FilteredElementCollector(doc)
                .OfClass(typeof(RailingType))
                .ToElementIds().First();
            return Railing.Create(doc, LineCurveLoop(pts), RailingTypeId, baseLevelId);
        }
        public Element CreatePolygonRailing(XYZ[] pts, ElementId baseLevelId, ElementId familyId) {
            ElementId RailingTypeId = new FilteredElementCollector(doc)
                .OfClass(typeof(RailingType))
                .ToElementIds().First();
            return Railing.Create(doc, PolygonCurveLoop(pts), RailingTypeId, baseLevelId);
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

        public void ChangeElementMaterial(Element element, Material material) {
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
                    cs.SetMaterialId(layerIndex, material.Id);
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

        public XYZ GetCamera() {
            return new XYZ(1,1,1);
        }

        public void SetView(XYZ camera, XYZ target, double focal_length) {
            const string khepriName = "Khepri-3D";
            //Do we have our own 3D view?
            var view3D = new FilteredElementCollector(doc).OfClass(typeof(View)).FirstOrDefault(v => v.Name == khepriName) as View3D;
            if (view3D == null) {
                var viewFamilyType = new FilteredElementCollector(doc)
                    .OfClass(typeof(ViewFamilyType))
                    .Cast<ViewFamilyType>()
                    .First(type => type.ViewFamily == ViewFamily.ThreeDimensional);
                view3D = View3D.CreatePerspective(doc, viewFamilyType.Id);
                view3D.Name = khepriName;
            }
            XYZ eye = camera;
            XYZ forward = (target - camera).Normalize();
            XYZ up = new XYZ(0, 0, 1);
            up = forward.CrossProduct(up).CrossProduct(forward);
            view3D.SetOrientation(new ViewOrientation3D(eye, up, forward));
            double original_focal_length = 38.6;
            double original_frame_width = 150.0;
            double original_frame_height = 113.0;
            double frame_width = original_frame_width * original_focal_length / focal_length;
            double frame_height = original_frame_height * original_focal_length / focal_length;
            double scale = Math.Max(frame_width / original_frame_width, frame_height / original_frame_height);
            view3D.Outline.Min *= scale;
            view3D.Outline.Max *= scale;
            view3D.get_Parameter(BuiltInParameter.VIEWER_BOUND_ACTIVE_FAR).Set(0);
            CurrentTransaction.Commit();
            uiapp.ActiveUIDocument.ActiveView = view3D;
            uiapp.ActiveUIDocument.RefreshActiveView();
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

        public Element[] DocFloors() => (new FilteredElementCollector(doc).OfClass(typeof(Floor))).ToArray();

        public Element[] DocCeilings() => (new FilteredElementCollector(doc).OfClass(typeof(Ceiling))).ToArray();

        public Element[] DocWalls() => (new FilteredElementCollector(doc).OfClass(typeof(Wall))).ToArray();
        public Element[] DocWallsAtLevel(Level level) =>
            (new FilteredElementCollector(doc).OfClass(typeof(Wall)))
            .WherePasses(new ElementLevelFilter(level.Id))
            .ToArray();


        //Energy Analysis

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

    }

    //RenderView http://thebuildingcoder.typepad.com/blog/2013/08/setting-a-default-3d-view-orientation.html

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

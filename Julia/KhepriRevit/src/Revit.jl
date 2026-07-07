using Dates

# Coordinate convention: Revit uses right-handed Z-up, same as Khepri.
# No axis transforms needed.

export
    revit,
    all_walls,
    all_floors,
    all_columns,
    all_beams,
    all_doors,
    all_windows,
    all_ceilings,
    all_groups,
    all_roofs,
    all_fixtures,
    all_stairs,
    all_railings,
    generate_khepri_code,
    introspect_model,
    wall_with_openings,
    RevitSystemFamily,
    RevitFileFamily,
    RevitInPlaceFamily,
    revit_system_family,
    revit_file_family,
    revit_opening_file_family

# The backend-agnostic codegen pipeline lives in KhepriBase (CodeGen.jl). Import the internals used
# by introspect_model / generate_khepri_code below; the Revit-specific pipeline hooks
# (b_native_family_expr, b_codegen_module) are defined further down, after RVT and the family types.
using KhepriBase: model_to_expr, expr_to_string, extract_levels, extract_families,
  add_backend_families, loop_rerolling, detect_level_repetition, add_header,
  family_expr_map, FamilyMeta, _shape_family_category, _dedup_slabs, is_curtain_wall,
  guarded_backend_family_expr

#=
We need to ensure the Revit plugin is properly installed.
For Revit, there are a few places where plugins can be installed:

User Addins:
%appdata%\Autodesk\Revit\Addins\<version>\
%appdata%\Autodesk\ApplicationPlugins\

Machine Addins (for all users of the machine):
C:\ProgramData\Autodesk\Revit\Addins\<version>\

Addins packaged for the Autodesk Exchange store:
C:\ProgramData\Autodesk\ApplicationPlugins\

Autodesk servers and services:
C:\Program Files\Autodesk\Revit <version>\AddIns\

C:\Users\<username>\AppData\Roaming\Autodesk\Revit \Addins\<year>

=#

julia_khepri = dirname(dirname(abspath(@__FILE__)))
# 1. The dlls are updated in VisualStudio after compilation of the plugin.
plugin_name = "KhepriRevit"
khepri_dlls = ["KhepriBase.dll", plugin_name*".dll"]
addin_name = plugin_name*".addin"
# 2. Depending on whether we are in Debug mode or Release mode,
development_phase = "Debug" # "Release"
# 3. the dlls are located in a folder
dlls_folder = joinpath("bin", "x64", development_phase)
# 4. contained inside the Plugins folder, which has a specific location regarding this file itself
plugin_folder = joinpath(dirname(dirname(dirname(dirname(abspath(@__FILE__))))), "Plugins", plugin_name, plugin_name)
# 5. Besides the dlls, we also need the bundle folder
bundle_name = plugin_name*".bundle"
bundle_dll_folder = joinpath(bundle_name, "Contents")
# 6. which is contained in the Plugins folder
bundle_path = joinpath(plugin_folder, bundle_name)
pkg_cnts_name = "PackageContents.xml"
local_plugins = joinpath(dirname(dirname(abspath(@__FILE__))), "Plugin")
local_khepri_plugin = joinpath(local_plugins, bundle_name)
local_khepri_plugin_dll_folder = joinpath(local_plugins, bundle_dll_folder)

# This only needs to be done when the Revit plugin is updated
upgrade_plugin(; advance_major_version=false, advance_minor_version=true) =
  begin
    # Update major or minor version
    if advance_major_version || advance_minor_version
      bundle_xml = joinpath(bundle_path, pkg_cnts_name)
      doc = readxml(bundle_xml)
      app_pkg = findfirst("//ApplicationPackage", doc)
      major, minor = map(s -> parse(Int, s), split(app_pkg["AppVersion"], '.'))
      print("Advancing version from $(major).$(minor) ")
      major += advance_major_version ? 1 : 0
      minor += advance_minor_version ? 1 : 0
      println("to $(major).$(minor).")
      app_pkg["AppVersion"] = "$(major).$(minor)"
      write(bundle_xml, doc)
    end
    # 7. The bundle needs to be copied to the current folder
    local_bundle_path = joinpath(julia_khepri, "Plugin", bundle_name)
    # 8. but, before, we remove any previously existing bundle
    mkpath(dirname(local_bundle_path))
    rm(local_bundle_path, force=true, recursive=true)
    # 9. Now we do the copy
    cp(bundle_path, local_bundle_path)
    # 10. and we copy the dlls to the local bundle Contents folder
    copy_plugin_files!(khepri_dlls, joinpath(plugin_folder, dlls_folder), joinpath(local_bundle_path, "Contents"))
  end

#=
Whenever the plugin is updated, run this function and commit the plugin files.
upgrade_plugin()
=#

env(name) = Sys.iswindows() ? ENV[name] : ""

revit_general_plugins = joinpath(dirname(env("CommonProgramFiles")), "Autodesk", "ApplicationPlugins")
revit_allusers_plugins = joinpath(env("ALLUSERSPROFILE"), "Autodesk", "ApplicationPlugins")
revit_user_plugins = joinpath(env("APPDATA"), "Autodesk", "ApplicationPlugins")
revit_khepri_plugin = joinpath(revit_user_plugins, bundle_name)
revit_khepri_plugin_dll_folder = joinpath(revit_user_plugins, bundle_dll_folder)

revit_version(path) =
  let doc = readxml(path),
      app_pkg = findfirst("//ApplicationPackage", doc)
    VersionNumber(map(s -> parse(Int, s), split(app_pkg["AppVersion"], '.'))...)
  end

update_plugin() =
  let local_path_xml = joinpath(local_khepri_plugin, pkg_cnts_name)
      revit_path_xml = joinpath(revit_khepri_plugin, pkg_cnts_name)
    # Do we have the bundle folder?
    isdir(revit_khepri_plugin) || mkpath(revit_khepri_plugin)
    isdir(revit_khepri_plugin_dll_folder) || mkpath(revit_khepri_plugin_dll_folder)
    # Must we upgrade?
    need_upgrade = ! isfile(revit_path_xml) || revit_version(revit_path_xml) < revit_version(local_path_xml)
    if need_upgrade
      # remove first to avoid loosing the local file
      #isfile(revit_path_xml) && rm(revit_path_xml)
      cp(local_path_xml, revit_path_xml, force=true)
      for dll in [khepri_dlls..., addin_name]
        let path = joinpath("Contents", dll),
            local_path = joinpath(local_khepri_plugin, path),
            revit_path = joinpath(revit_khepri_plugin, path)
            # remove first to avoid loosing the local file
            #isfile(revit_path_xml) && rm(revit_path_xml)
            cp(local_path, revit_path, force=true)
        end
      end
    end
  end

check_plugin = make_plugin_checker("Revit", update_plugin)

#
const revit_template = Parameter(abspath(@__DIR__, "../Plugin/KhepriTemplate.rte"))

start_revit() =
  run(`cmd /c cd "$(dirname(revit_template()))" \&\& $(basename(revit_template()))`, wait=false)

#
# RVT is a subtype of CS
parse_signature(::Val{:RVT}, sig::T) where {T} = parse_signature(Val(:CS), sig)
encode(::Val{:RVT}, t::Val{T}, c::IO, v) where {T} = encode(Val(:CS), t, c, v)
decode(::Val{:RVT}, t::Val{T}, c::IO) where {T} = decode(Val(:CS), t, c)

# CLR name mapping for signature validation:
# - VXYZ is a C# using alias for Autodesk.Revit.DB.XYZ
# - "object" maps to "Object" (System.Object); the base mapping in KhepriBase covers
#   `int`/`double`/etc. but not `object`, so InsertWindow / InsertDoorWithParams which
#   carry `object[] values` would otherwise produce "objectArray" on the Julia side
#   versus "ObjectArray" on the C# side and fail signature validation.
KhepriBase.clr_name(::Val{:RVT}, name::AbstractString) =
  name == "VXYZ" ? "XYZ" :
  name == "object" ? "Object" :
  clr_name(name)

#
# We need some additional Encoders
encode(::Val{:RVT}, t::Union{Val{:XYZ},Val{:VXYZ}}, c::IO, p) =
  encode(Val(:CS), Val(:double3), c, raw_point(p))
decode(::Val{:RVT}, t::Val{:XYZ}, c::IO) =
  xyz(decode(Val(:CS), Val(:double3), c)..., world_cs)
decode(::Val{:RVT}, t::Val{:VXYZ}, c::IO) =
  vxyz(decode(Val(:CS), Val(:double3), c)..., world_cs)
encode(ns::Val{:RVT}, t::Union{Val{:ElementId},Val{:Element},Val{:Level},Val{:Family},Val{:FloorFamily}}, c::IO, v) =
  encode(ns, Val(:long), c, v)
decode(ns::Val{:RVT}, t::Union{Val{:ElementId},Val{:Element},Val{:Level},Val{:Family},Val{:FloorFamily}}, c::IO) =
  decode(ns, Val(:long), c)

@encode_decode_as(:RVT, Val{:Length}, Val{:double})
@encode_decode_as(:RVT, Val{:object}, Val{:Any})

revit_api = @remote_api :RVT """
public bool ConvertIFCFile(string file)
public bool LoadRVTFile(string file)
public Element Sphere(XYZ centre, Length radius, ElementId materialId)
public Element ConeFrustumNamed(string name, XYZ bottom, VXYZ axis, Length bottomRadius, Length height, Length topRadius, ElementId materialId)
public Element ConeFrustum(XYZ bottom, VXYZ axis, Length bottomRadius, Length height, Length topRadius, ElementId materialId)
public Element Cylinder(XYZ bottom, VXYZ axis, Length radius, Length height, ElementId materialId)
public Element CylinderWithCaps(XYZ bottom, VXYZ axis, Length radius, Length height, bool bottomCap, bool topCap, ElementId materialId)
public Element Cone(XYZ bottom, VXYZ axis, Length bottomRadius, Length height, ElementId materialId)
public ElementId SurfaceFromGrid(int m, int n, XYZ[] pts, bool closedM, bool closedN, int level)
public Element PyramidFrustumNamed(String name, XYZ[] ps, XYZ[] qs, ElementId materialId)
public Element PyramidFrustumWithMaterial(XYZ[] ps, XYZ[] qs, ElementId materialId)
public Element PyramidFrustum(XYZ[] ps, XYZ[] qs)
public Element Box(XYZ[] basePts, Length height, ElementId materialId)
public XYZ BoundingBoxMin(Element e)
public XYZ BoundingBoxMax(Element e)
public Element ExtrudedContourNamed(string name, XYZ[] contour, bool smoothContour, XYZ[][] holes, bool[] smoothHoles, XYZ v, ElementId materialId)
public Element ExtrudedContourWithMaterial(XYZ[] contour, bool smoothContour, XYZ[][] holes, bool[] smoothHoles, VXYZ v, ElementId materialId)
public Element ExtrudedContour(XYZ[] contour, bool smoothContour, XYZ[][] holes, bool[] smoothHoles, VXYZ v)
public Element SurfaceGrid(XYZ[] linearizedMatrix, int n, int m)
public Element Union(ElementId idA, ElementId idB)
public Element Intersection(ElementId idA, ElementId idB)
public Element Subtraction(ElementId idA, ElementId idB)
public Level FindOrCreateLevelAtElevation(Length elevation)
public Level UpperLevel(Level level, Length addedElevation)
public Length GetLevelElevation(Level level)
public Family LoadFamily(string fileName)
public ElementId FamilyElement(Family family, string[] names, Length[] values)
public String InstalledLibraryPath(String root)
public void MoveElement(ElementId id, XYZ translation)
public void RotateElement(ElementId id, double angle, XYZ axis0, XYZ axis1)
public ElementId CreatePolygonalFloor(XYZ[] pts, Level level, ElementId famId)
public ElementId CreatePolygonalRoof(XYZ[] pts, Level level, ElementId famId)
public ElementId CreatePathFloor(XYZ[] pts, double[] angles, Level level, ElementId famId)
public ElementId CreatePathRoof(XYZ[] pts, double[] angles, Level level, ElementId famId)
public Element InsertDoor(Length deltaFromStart, Length deltaFromGround, Element host, ElementId familyId)
public Element InsertDoorWithParams(Length deltaFromStart, Length deltaFromGround, Element host, ElementId familyId, string[] names, object[] values)
public Element InsertWindow(Length deltaFromStart, Length deltaFromGround, Element host, ElementId familyId, string[] names, object[] values)
public Element InsertRailing(Element host, ElementId familyId)
public Element InsertRailingAt(XYZ location, Element host, ElementId familyId)
public ElementId CreatePanelExtrusion(XYZ[] pts, double[] angles, double thickness, ElementId catId)
public void CreateFamily(string familyTemplatesPath, string familyTemplateName, string familyName)
public void CreateFamilyExtrusionTest(XYZ[] pts, double height)
public void InsertFamily(string familyName, XYZ p)
public void CreatePolygonalOpening(XYZ[] pts, Element host)
public void CreatePathOpening(XYZ[] pts, double[] angles, Element host)
public ElementId CreateBeam(XYZ p0, XYZ p1, double rotationAngle, ElementId famId)
public Element CreateColumn(XYZ location, Level baseLevel, Level topLevel, ElementId famId)
public Element CreateColumnPoints(XYZ p0, XYZ p1, Level level0, Level level1, ElementId famId)
public ElementId[] CreateLineWall(XYZ[] pts, ElementId baseLevelId, ElementId topLevelId, ElementId famId)
public ElementId[] CreateUnconnectedLineWall(XYZ[] pts, ElementId baseLevelId, double height, ElementId famId)
public ElementId[] CreatePathWall(XYZ[] pts, double[] angles, ElementId baseLevelId, ElementId topLevelId, ElementId famId, bool isStructural)
public ElementId[] CreateUnconnectedPathWall(XYZ[] pts, double[] angles, ElementId baseLevelId, double height, ElementId famId)
public Element CreateArcWall(XYZ center, Length radius, double startAngle, double endAngle, ElementId baseLevelId, ElementId topLevelId, ElementId famId)
public Element CreateUnconnectedArcWall(XYZ center, Length radius, double startAngle, double endAngle, ElementId baseLevelId, double height, ElementId famId)
public ElementId[] CreatePathCurtainWall(XYZ[] pts, double[] angles, ElementId baseLevelId, ElementId topLevelId, ElementId famId, bool isStructural)
public Element CreateLineRailing(XYZ[] pts, ElementId baseLevelId, ElementId familyId)
public Element CreatePolygonRailing(XYZ[] pts, ElementId baseLevelId, ElementId familyId)
public Element CreateElementLocDirOnHost(XYZ location, XYZ direction, Element host, ElementId famId)
public Level[] DocLevels()
public Element[] DocElements()
public Element[] DocFamilies()
public Element[] DocFloors()
public Element[] DocCeilings()
public Element[] DocWalls()
public Element[] DocWallsAtLevel(Level level)
public XYZ[] LineWallVertices(Element element)
public ElementId ElementLevel(Element element)
public ElementId WallTopLevel(Element element)
public Length WallHeight(Element element)
public void HighlightElement(ElementId id)
public ElementId[] GetSelectedElements()
public bool IsProject()
public void DeleteAllElements()
public void DeleteElement(Element element)
public ElementId CreateGroup(ElementId[] ids)
public void SetView(XYZ camera, XYZ target, int width, int height, double lens)
public XYZ GetCamera()
public XYZ GetTarget()
public double GetLens()
public void ViewSize(int width, int height)
public void RenderView(string path)
public void EnergyAnalysis()
public ElementId CreatePolygonalCeiling(XYZ[] pts, Level level, ElementId famId)
public ElementId CreatePathCeiling(XYZ[] pts, double[] angles, Level level, ElementId famId)
public ElementId CreateRamp(XYZ p0, XYZ p1, double width, double thickness, Level baseLevel, double baseOffset, double topOffset)
public ElementId CreateStraightStair(XYZ basePoint, VXYZ direction, double width, Level baseLevel, Level topLevel, ElementId familyId)
public Element CreateSpiralStair(XYZ center, double radius, double startAngle, double includedAngle, bool clockwise, double width, Level baseLevel, Level topLevel, ElementId familyId)
public string WallCurveType(Element element)
public XYZ[] ArcWallVertices(Element element)
public Length ArcWallRadius(Element element)
public double[] ArcWallAngles(Element element)
public string WallTypeName(Element element)
public bool WallIsCurtainWall(Element element)
public Length WallBaseOffset(Element element)
public Length WallTopOffset(Element element)
public ElementId[] WallInserts(Element element)
public XYZ[] FloorBoundaryVertices(Element element)
public XYZ[][] FloorBoundaryLoops(Element element)
public XYZ[][] CeilingBoundaryLoops(Element element)
public XYZ[][] RoofBoundaryLoops(Element element)
public string FloorTypeName(Element element)
public ElementId FloorLevel(Element element)
public double[] ElementMaterial(Element element)
public Element[] DocColumns()
public XYZ ColumnLocation(Element element)
public double ColumnRotation(Element element)
public ElementId ColumnBaseLevel(Element element)
public ElementId ColumnTopLevel(Element element)
public Element[] DocBeams()
public XYZ[] BeamEndpoints(Element element)
public double BeamRotation(Element element)
public Element[] DocDoors()
public Element[] DocWindows()
public ElementId HostWallId(Element element)
public Length[] HostedElementPosition(Element element)
public Length[] DoorWindowDimensions(Element element)
public string ElementFamilyName(Element element)
public string ElementTypeName(Element element)
public string ElementFamilyPath(Element element)
public bool IsSystemFamily(Element element)
public XYZ[] CeilingBoundaryVertices(Element element)
public string CeilingTypeName(Element element)
public ElementId CeilingLevel(Element element)
public Element[] DocGroups()
public string GroupTypeName(Element element)
public ElementId GroupTypeId(Element element)
public ElementId[] GroupMemberIds(Element element)
public XYZ GroupLocation(Element element)
public bool IsGroupMember(Element element)
public Element[] NotInGroup(Element[] elements)
public string ElementCategoryName(Element element)
public void ExportFamilyToOBJ(string familyPath, string objPath)
public void ExportAllFamiliesToOBJ(string folderPath)
public string[] ExportFamilyToOBJWithMetadata(string familyPath, string objPath)
public string[][] ExportAllFamiliesToOBJWithMetadata(string folderPath)
public string[] ExportElementsToOBJ(ElementId[] ids, string folderPath)
public Element[] DocRoofs()
public XYZ[] RoofBoundaryVertices(Element element)
public ElementId RoofLevel(Element element)
public Element[] DocFurniture()
public Element[] DocPlumbingFixtures()
public Element[] DocCasework()
public Element[] DocGenericModels()
public Element[] DocSpecialtyEquipment()
public XYZ FamilyInstanceLocation(Element element)
public double FamilyInstanceRotation(Element element)
public ElementId FamilyInstanceLevel(Element element)
public ElementId FamilyInstanceHost(Element element)
public Element[] DocStairs()
public ElementId StairBaseLevel(Element element)
public ElementId StairTopLevel(Element element)
public XYZ StairBasePoint(Element element)
public XYZ StairDirection(Element element)
public Element[] DocRailings()
public XYZ[] RailingPath(Element element)
public ElementId RailingLevel(Element element)
public Element CreateMaterial(String name, Color color, int transparency)
"""

abstract type RVTKey end
const RVTId = Int64
const RVTIds = Vector{RVTId}
const RVTNativeRef = NativeRef{RVTKey, RVTId}
const RVT = SocketBackend{RVTKey, RVTId}
const RVTVoidId = RVTId(-1)

KhepriBase.void_ref(b::RVT) = RVTVoidId

KhepriBase.has_boolean_ops(::Type{RVT}) = HasBooleanOps{true}()

# SocketBackend has no current_layer field; override to avoid field-access crash
KhepriBase.b_current_layer_ref(b::RVT) = nothing
KhepriBase.b_current_layer_ref(b::RVT, layer) = nothing

#=
Unit conversion seam.

Revit's internal length unit is feet, while Khepri (and most users) work in
meters. Two parameter pipelines exist and they convert differently — be
deliberate about which one a given parameter flows through:

  - `Length` parameters in the C# RPC signature: serialized as `Length` and
    multiplied by `to_feet` automatically inside the C# `rLength()` decoder.
    Pass meters; the wire takes care of conversion.

  - `object` parameters (used by the `instance_map` pipeline that flows
    through `SetParameters` post-creation): serialized as raw doubles with
    no conversion. The Julia caller MUST pre-convert to feet, e.g.
    `f -> to_revit(f.width)`.

Mnemonic: if the Revit parameter you're targeting is shown in the Properties
panel in mm or m (display units), convert with `to_revit`. If you're
crossing through a `Length`-typed argument in the RPC signature, do not
convert — `rLength()` already does it.

`to_feet` is the bare conversion constant; `to_revit(x)` is the helper to
use in `instance_map` lambdas so the conversion is named where it happens.
=#
const to_feet = 3.28084

export to_revit
"to_revit(x) = x * to_feet — converts a Khepri length (meters) to Revit's internal feet."
to_revit(x::Real) = x * to_feet
#
KhepriBase.before_connecting(b::RVT) =
  check_plugin()
KhepriBase.after_connecting(b::RVT) =
  begin
    set_backend_family(default_wall_family(), b, revit_system_family())
    set_backend_family(default_curtain_wall_family(), b, revit_system_family())
    set_backend_family(default_window_family(), b, revit_file_family(
      revit_library_path("Metric Library", raw"Windows\M_Instance-Window-Fixed.rfa"),
      [], ["Width"=>f->to_revit(f.width), "Height"=>f->to_revit(f.height)],
      (f, p)->p+vx(f.width/2, p.cs)))
    set_backend_family(default_door_family(), b, revit_system_family(
      [],
      ["Width"=>f->to_revit(f.width), "Height"=>f->to_revit(f.height)],
      (f, p)->p+vx(f.width/2, p.cs)))
    set_backend_family(default_slab_family(), b, revit_system_family())
    set_backend_family(default_column_family(), b, revit_file_family(
          revit_library_path("Metric Library", raw"Structural Columns\Concrete\M_Concrete-Rectangular-Column.rfa"),
          ["b"=>f->f.profile.dx, "h"=>f->f.profile.dy]))
    set_backend_family(default_beam_family(), b, revit_file_family(
          revit_library_path("Metric Library", raw"Structural Framing\Wood\M_Timber.rfa"),
          ["b"=>f->f.profile.dx, "d"=>f->f.profile.dy]))
    set_backend_family(default_truss_bar_family(), b, revit_file_family(
          revit_library_path("Metric Library", raw"Structural Framing\Steel\M_W-Wide Flange.rfa")))
    set_backend_family(default_truss_node_family(), b, revit_file_family(
          revit_library_path("Metric Library", raw"Structural Framing\Steel\M_W-Wide Flange.rfa")))
    set_backend_family(default_toilet_family(), b, revit_file_family(
          revit_library_path("Metric Library", raw"Plumbing\Architectural\Fixtures\Water Closets\M_Toilet-Domestic-3D.rfa"),
          [], [], (f, c)->add_y(loc_from_o_phi(c, π/2), -0.12)))
    set_backend_family(default_closet_family(), b, revit_file_family(
          revit_library_path("Metric Library", raw"Furniture\Storage\M_Shelving.rfa")))
    set_backend_family(default_sink_family(), b, revit_file_family(
            revit_library_path("Metric Library", raw"Plumbing\Architectural\Fixtures\Sinks\M_Sink Vanity-Square.rfa"),
            [], [], (f, c)->add_y(loc_from_o_phi(c, π/2), 0.0)))
    #=
    #set_backend_family(default_column_family(), unity, unity_material_family("Materials/Concrete/Concrete2"))
    #set_backend_family(default_door_family(), unity, unity_material_family("Materials/Wood/InteriorWood2"))

    =#
    set_backend_family(default_panel_family(), b, revit_system_family())
    set_backend_family(default_ceiling_family(), b, revit_system_family())
    set_backend_family(default_roof_family(), b, revit_system_family())
    set_backend_family(default_railing_family(), b, revit_system_family())
    set_backend_family(default_ramp_family(), b, revit_system_family())
    set_backend_family(default_stair_family(), b, revit_system_family())
    set_backend_family(default_stair_landing_family(), b, revit_system_family())
    set_backend_family(default_family_element_family(), b, revit_system_family())
  end

const revit = RVT("Revit", revit_port, revit_api)

# IFC
export convert_ifc_file
convert_ifc_file(path) =
  @remote(revit, ConvertIFCFile(path))
export load_rvt_file
load_rvt_file(path) =
  @remote(revit, LoadRVTFile(path))

export convert_and_load_ifc_file
convert_and_load_ifc_file(path) =
  begin
    convert_ifc_file(path)
    #KhepriBase.interrupt_processing(connection(revit))
    load_rvt_file(Base.Filesystem.splitext(path)[begin]*".rvt")
  end
# Levels

realize(b::RVT, s::Level) =
  @remote(b, FindOrCreateLevelAtElevation(s.height))

# Families
#=

Revit families are divided into
1. System Families (for walls, roofs, floors, pipes)
2. Loadable Families (for building components that have an associated file)
3. In-Place Families (for unique elements created just for the current project)

=#

abstract type RevitFamily <: Family end

struct RevitSystemFamily <: RevitFamily
  family_map::Dict{String, Function}
  instance_map::Dict{String, Function}
  location_transform::Function
end

revit_system_family(family_map=(), instance_map=(), location_transform=(f, p)->p) =
  RevitSystemFamily(
    Dict(family_map...),
    Dict(instance_map...),
    location_transform)

b_get_family_ref(b::RVT, f::Family, rvtf::RevitSystemFamily) =
  let param_map = rvtf.family_map,
      params = keys(param_map)
    isempty(params) ?
      RVTId(0) :
      @remote(b, FamilyElement(0, collect(params), [param_map[param](f) for param in params]))
  end

struct RevitFileFamily <: RevitFamily
  path::String
  family_map::Dict{String, Function}
  instance_map::Dict{String, Function}
  location_transform::Function
end

revit_file_family(path, family_map=(), instance_map=(), location_transform=(f, p)->p) =
  RevitFileFamily(
    path,
    Dict(family_map...),
    Dict(instance_map...),
    location_transform)

# A loadable door/window family that keeps the standard Width/Height instance mapping and opening
# offset (matching default_window_family/default_door_family), so a reconstructed opening loads its
# real .rfa yet still receives its introspected width/height rather than the .rfa's default type.
# Lets codegen emit `revit_opening_file_family(raw"…")` without printing any lambdas.
revit_opening_file_family(path) =
  revit_file_family(path, [],
    ["Width" => f -> to_revit(f.width), "Height" => f -> to_revit(f.height)],
    (f, p) -> p + vx(f.width/2, p.cs))

b_get_family_ref(b::RVT, f::Family, rvtf::RevitFileFamily) =
  let family_id = try
        @remote(b, LoadFamily(rvtf.path))
      catch e
        # Never let a missing/unloadable .rfa abort the reconstruction: fall back to the system family
        # (id 0), exactly as RevitSystemFamily does. So reconstructed programs stay robust even when an
        # exported/native family file isn't present at rebuild time.
        @warn "could not load family from .rfa; using system family instead" path=rvtf.path
        0
      end,
      param_map = rvtf.family_map,
      params = keys(param_map)
    @remote(b, FamilyElement(family_id, collect(params), [param_map[param](f) for param in params]))
  end
#

#=
Sugar over `revit_file_family` for the canonical multi-step pattern:

  - The *type* parameter (e.g. a window's Width, or — in a parametric round
    window — the Radius) lives in `family_map` and is baked into a duplicated
    `FamilySymbol` via the C# `FamilyElement(...)` RPC. Two instances that
    request the same type values share a single duplicated symbol.

  - The *instance* parameter (e.g. Default Sill Height, or — in a parametric
    round window — the Opening Angle) lives in `instance_map` and is applied
    per-placement via `SetParameters` after `NewFamilyInstance`.

The defaults assume a stock Metric-library casement window where Width is the
type parameter and "Default Sill Height" is the per-instance parameter.
Override for round windows by passing your own `width_param`/`sill_param`
keys (e.g. "Radius" and "Opening Angle") and matching extractors.

See also: `revit_file_family`, `default_window_family`, `to_revit`.
=#
export revit_casement_window_family
"Sugar for the type-vs-instance split: type-level Width baked into the symbol, instance-level sill height set per placement."
revit_casement_window_family(path;
                              width_param="Width",
                              sill_param="Default Sill Height",
                              # width goes in the family_map → FamilyElement(Length[]) already converts
                              # m→feet; do NOT to_revit it (that double-converts). sill is instance_map
                              # (SetParameters raw doubles) so it DOES need to_revit.
                              width=f->f.width,
                              sill=f->to_revit(0.9),
                              location_transform=(f, p)->p+vx(f.width/2, p.cs)) =
  revit_file_family(path,
    [width_param=>width],
    [sill_param=>sill],
    location_transform)


# This is for future use
struct RevitInPlaceFamily <: RevitFamily
    parameter_map::Dict{Symbol,String}
    ref::IdDict{Backend, Any}
end

# Without this, dispatching family_ref on a RevitInPlaceFamily would fall through
# to the abstract method and raise a confusing MethodError deep inside realization.
# Surface a clear, actionable error at the family-resolution boundary instead.
b_get_family_ref(b::RVT, f::Family, rvtf::RevitInPlaceFamily) =
  error("RevitInPlaceFamily is not yet implemented. Use revit_file_family with " *
        "a saved .rfa, or revit_system_family for built-in types.")

#=
root should be "Imperial Library" or "Metric Library"
path can be something as "Structural Framing\\Wood\\M_Timber.rfa"
=#
export revit_library_path
revit_library_path(root::String, path::String) =
  joinpath(@remote(revit, InstalledLibraryPath(root)), path)

export export_family_to_obj
export_family_to_obj(family_path::String, obj_path::String) =
  @remote(revit, ExportFamilyToOBJ(family_path, obj_path))

export export_all_families_to_obj
export_all_families_to_obj(folder_path::String) =
  @remote(revit, ExportAllFamiliesToOBJ(folder_path))

export export_family_to_obj_with_metadata
export_family_to_obj_with_metadata(family_path::String, obj_path::String) =
  @remote(revit, ExportFamilyToOBJWithMetadata(family_path, obj_path))

export export_all_families_to_obj_with_code
function export_all_families_to_obj_with_code(obj_folder::String, jl_path::String;
                                               backend_var="THR")
  metadata_list = @remote(revit, ExportAllFamiliesToOBJWithMetadata(obj_folder))
  open(jl_path, "w") do io
    println(io, "# Auto-generated family definitions from Revit export")
    println(io, "# Generated: $(Dates.now())\n")
    for meta in metadata_list
      obj_name, width_s, height_s, category = meta
      width = parse(Float64, width_s)
      height = parse(Float64, height_s)
      var_name = replace(lowercase(obj_name), r"[^a-z0-9_]" => "_")
      family_fn = revit_category_to_khepri(category)

      if family_fn !== nothing && width > 0 && height > 0
        w = round(width, digits=3)
        h = round(height, digits=3)
        println(io, """$var_name = $family_fn("$obj_name", width=$w, height=$h)""")
        println(io, """set_backend_family($var_name, $backend_var, obj_family("$obj_name"))\n""")
      else
        println(io, """$var_name = obj_family("$obj_name")\n""")
      end
    end
  end
  jl_path
end

function revit_category_to_khepri(category)
  cat = lowercase(category)
  if contains(cat, "door") || contains(cat, "porta")
    "door_family"
  elseif contains(cat, "window") || contains(cat, "janela")
    "window_family"
  else
    nothing
  end
end

switch_to_backend(from::Backend, to::RVT) =
    let height = level_height(default_level())
        current_backend(to)
        default_level(level(height))
    end


KhepriBase.b_slab(b::RVT, profile::Region, level, family) =
  let outer = outer_path(profile),
      inners = inner_paths(profile),
      slab_r = b_slab(b, outer, level, family)
    for inner in inners
      create_slab_opening(b, inner, slab_r)
    end
    slab_r
  end

KhepriBase.b_slab(b::RVT, contour::ClosedPolygonalPath, level, family) =
  @remote(b, CreatePolygonalFloor(convert(ClosedPolygonalPath, contour).vertices, ref_value(b, level), family_ref(b, family)))

KhepriBase.b_slab(b::RVT, contour::RectangularPath, level, family) =
  @remote(b, CreatePolygonalFloor(path_vertices(contour), ref_value(b, level), family_ref(b, family)))

create_slab_opening(b::RVT, contour::ClosedPolygonalPath, slab_r) =
  @remote(b, CreatePolygonalOpening(convert(ClosedPolygonalPath, contour).vertices, slab_r))

create_slab_opening(b::RVT, contour::ClosedPath, slab_r) =
  let (locs, arcs) = locs_and_arcs(contour)
    @remote(b, CreatePathOpening(locs, arcs, slab_r))
  end

locs_and_arcs(path::OpenPolygonalPath) =
  let vs = path_vertices(path)
    (vs, zeros(length(vs)-1))
  end

locs_and_arcs(path::ClosedPolygonalPath) =
  let vs = path_vertices(path)
    (vs, zeros(length(vs)))
  end

locs_and_arcs(arc::ArcPath) =
  let p0 = arc.center + vpol(arc.radius, arc.start_angle),
      p1 = arc.center + vpol(arc.radius, arc.start_angle + arc.amplitude)
    ([p0, p1], [arc.amplitude])
  end

locs_and_arcs(circle::CircularPath) =
  let p0 = circle.center + vpol(circle.radius, 0),
      p1 = circle.center + vpol(circle.radius, π)
    ([p0, p1], [π, π])
  end

# Convert a path into (locs, arc-bulges) for Revit walls/railings, dispatching on
# each piece of a CompositePath (its path_pieces) by concrete type.
function _append_segment_locs_and_arcs!(locs, arcs, seg::LinePath)
  isempty(locs) && push!(locs, seg.p0)
  push!(locs, seg.p1)
  push!(arcs, 0.0)
end

function _append_segment_locs_and_arcs!(locs, arcs, seg::ArcPath)
  isempty(locs) && push!(locs, path_start(seg))
  if abs(arc_amplitude(seg)) >= 2π - coincidence_tolerance()
    push!(locs, location_at(seg, arc_amplitude(seg)/2))
    push!(locs, path_end(seg))
    push!(arcs, arc_amplitude(seg)/2)
    push!(arcs, arc_amplitude(seg)/2)
  else
    push!(locs, path_end(seg))
    push!(arcs, arc_amplitude(seg))
  end
end

function _append_segment_locs_and_arcs!(locs, arcs, seg::Path)
  let vs = convert(OpenPolygonalPath, seg).vertices
    isempty(vs) && return
    isempty(locs) ? append!(locs, vs) : append!(locs, vs[2:end])
    append!(arcs, zeros(max(length(vs) - 1, 0)))
  end
end

locs_and_arcs(path::CompositePath) =
  let locs = [],
      arcs = []
    for seg in path_pieces(path)
      _append_segment_locs_and_arcs!(locs, arcs, seg)
    end
    if is_closed_path(path) && length(locs) > 1 && coincident_path_location(locs[1], locs[end])
      pop!(locs)
    end
    (locs, arcs)
  end
locs_and_arcs(path::OpenPathSequence) =
  let all_locs = [],
      all_arcs = []
    for (i, sub) in enumerate(path.paths)
      (ls, as) = locs_and_arcs(sub)
      if i == 1
        append!(all_locs, ls)
      else
        append!(all_locs, ls[2:end])
      end
      append!(all_arcs, as)
    end
    (all_locs, all_arcs)
  end

# We should implement the arc-line approximation to splines that exist in RhinoCommon.
locs_and_arcs(circle::SplinePath) = error("Must be finished")

KhepriBase.b_slab(b::RVT, contour::ClosedPath, level, family) =
  let (locs, arcs) = locs_and_arcs(contour)
    @remote(b, CreatePathFloor(locs, arcs, ref_value(b, level), family_ref(b, family)))
  end

KhepriBase.b_roof(b::RVT, contour::ClosedPath, level, family) =
  let (locs, arcs) = locs_and_arcs(contour)
    @remote(b, CreatePathRoof(locs, arcs, ref_value(b, level), family_ref(b, family)))
  end

# Ceiling
KhepriBase.b_ceiling(b::RVT, profile::Region, level, family) =
  b_ceiling(b, outer_path(profile), level, family)

KhepriBase.b_ceiling(b::RVT, contour::ClosedPolygonalPath, level, family) =
  @remote(b, CreatePolygonalCeiling(contour.vertices, ref_value(b, level), family_ref(b, family)))

KhepriBase.b_ceiling(b::RVT, contour::RectangularPath, level, family) =
  @remote(b, CreatePolygonalCeiling(path_vertices(contour), ref_value(b, level), family_ref(b, family)))

KhepriBase.b_ceiling(b::RVT, contour::ClosedPath, level, family) =
  let (locs, arcs) = locs_and_arcs(contour)
    @remote(b, CreatePathCeiling(locs, arcs, ref_value(b, level), family_ref(b, family)))
  end

#=
Family-parameter lookup helper.

Many backends-specific b_* operations want to read a "logical" parameter
(width, thickness, ...) from a family. The natural source-of-truth is the
backend-specific RevitFamily mapping (`family_map` for type-level values,
`instance_map` for per-instance values). When neither map declares the
parameter, fall back to a direct field access on the Khepri family struct
— this is the original behavior and keeps default registrations working
without forcing every map to declare every field.

Returns a function `f -> value` so callers can apply it lazily.
=#
_lookup_family_param(rvtf::RevitFamily, name::AbstractString, default::Function) =
  haskey(rvtf.family_map, name)   ? rvtf.family_map[name]   :
  haskey(rvtf.instance_map, name) ? rvtf.instance_map[name] :
  default

# Railing — explicit dispatch on supported path types. Falls through to
# InsertRailingAt when the caller has a host but no path (the typical
# stair-attached-railing case); errors for any other path shape so users
# aren't silently dropped onto the InsertRailing fallback that had a
# hardcoded anchor in the previous C# code.
KhepriBase.b_railing(b::RVT, path::OpenPolygonalPath, level, host, family) =
  @remote(b, CreateLineRailing(path.vertices, ref_value(b, level), family_ref(b, family)))

KhepriBase.b_railing(b::RVT, path::ClosedPolygonalPath, level, host, family) =
  @remote(b, CreatePolygonRailing(path.vertices, ref_value(b, level), family_ref(b, family)))

KhepriBase.b_railing(b::RVT, path::CompositePath{false}, level, host, family) =
  b_railing(b, convert(OpenPolygonalPath, path), level, host, family)

KhepriBase.b_railing(b::RVT, path::CompositePath{true}, level, host, family) =
  b_railing(b, convert(ClosedPolygonalPath, path), level, host, family)

KhepriBase.b_railing(b::RVT, ::Nothing, level, host, family) =
  @remote(b, InsertRailing(ref_value(b, host), family_ref(b, family)))

KhepriBase.b_railing(b::RVT, path, level, host, family) =
  error("Revit railings need a polygonal path; got $(typeof(path)). " *
        "Use open_polygonal_path or closed_polygonal_path, or pass " *
        "path=nothing to attach the railing directly to its host.")

# Ramp / stair / spiral_stair: parameters flow through _lookup_family_param so
# users can override `width` or `thickness` via family_map/instance_map. The
# default extractors (`f -> f.width`, `f -> f.thickness`) preserve the
# pre-fix behavior for system families that already had those fields.
KhepriBase.b_ramp(b::RVT, path, bottom_level, top_level, family) =
  let rvtf = backend_family(b, family),
      width     = _lookup_family_param(rvtf, "width",     f -> f.width)(family),
      thickness = _lookup_family_param(rvtf, "thickness", f -> f.thickness)(family),
      p0 = in_world(path_start(path)),
      p1 = in_world(path_end(path)),
      bottom_h = level_height(b, bottom_level),
      top_h = level_height(b, top_level)
    # Lengths cross to the plugin as bare doubles (used as Revit feet), so convert m→feet with to_revit.
    @remote(b, CreateRamp(p0, p1, to_revit(width), to_revit(thickness),
                          ref_value(b, bottom_level), 0.0, to_revit(top_h - bottom_h)))
  end

# Stair
KhepriBase.b_stair(b::RVT, base_point, direction, bottom_level, top_level, family) =
  let rvtf = backend_family(b, family),
      width = _lookup_family_param(rvtf, "width", f -> f.width)(family)
    @remote(b, CreateStraightStair(
      base_point, direction, to_revit(width),
      ref_value(b, bottom_level), ref_value(b, top_level), family_ref(b, family)))
  end

KhepriBase.b_spiral_stair(b::RVT, center, radius, start_angle, included_angle,
                           clockwise, bottom_level, top_level, family) =
  let rvtf = backend_family(b, family),
      width = _lookup_family_param(rvtf, "width", f -> f.width)(family)
    @remote(b, CreateSpiralStair(
      center, to_revit(radius), start_angle, included_angle, clockwise, to_revit(width),
      ref_value(b, bottom_level), ref_value(b, top_level), family_ref(b, family)))
  end

KhepriBase.b_stair_landing(b::RVT, region, level, family) =
  b_slab(b, region, level, family)

#Beams are aligned along the top axis.
KhepriBase.b_beam(b::RVT, c, h, angle, family) =
  @remote(b, CreateBeam(c, add_z(c, h), angle, family_ref(b, family)))

KhepriBase.b_column(b::RVT, cb, angle, bottom_level, top_level, family) =
  @remote(b, CreateColumn(cb, ref_value(b, bottom_level), ref_value(b, top_level), family_ref(b, family)))

#Columns are aligned along the center axis.
KhepriBase.b_free_column(b::RVT, cb, h, angle, family) =
  let ct = in_world(add_z(cb, h)),
      cb = in_world(cb),
      lb = @remote(b, FindOrCreateLevelAtElevation(cb.z)),
      lt = @remote(b, FindOrCreateLevelAtElevation(ct.z))
    @remote(b, CreateColumnPoints(cb, ct, lb, lt, family_ref(b, family)))
  end

KhepriBase.realize_wall_no_openings(b::RVT, s::Wall) =
  realize_wall_path(b, s, s.path)

realize_wall_path(b::RVT, s::Wall, path::OpenPolygonalPath) =
  # Revit also considers unconnected walls. These have a top level with id -1
  if ref_value(b, s.top_level) == RVTVoidId
    @remote(b, CreateUnconnectedLineWall(
        path.vertices,
        ref_value(b, s.bottom_level),
        to_revit(s.top_level.height - s.bottom_level.height),
        family_ref(b, s.family)))
  else
    @remote(b, CreateLineWall(
        path.vertices,
        ref_value(b, s.bottom_level),
        ref_value(b, s.top_level),
        family_ref(b, s.family)))
  end

realize_wall_path(b::RVT, s::Wall, path::ClosedPolygonalPath) =
  realize_wall_path(b, s, open_polygonal_path([path.vertices..., path.vertices[1]]))

realize_wall_path(b::RVT, s::Wall, path::RectangularPath) =
  realize_wall_path(b, s, convert(ClosedPolygonalPath, path))

realize_wall_path(b::RVT, s::Wall, path::ArcPath) =
  let center = in_world(path.center),
      radius = path.radius,
      # Transform angles from the arc center's local CS to world CS
      cx = in_world(vx(1, path.center.cs)),
      cs_angle = atan(cx.y, cx.x),
      start_angle = path.start_angle + cs_angle,
      end_angle = start_angle + path.amplitude
    if ref_value(b, s.top_level) == RVTVoidId
      @remote(b, CreateUnconnectedArcWall(
          center, radius, start_angle, end_angle,
          ref_value(b, s.bottom_level),
          to_revit(s.top_level.height - s.bottom_level.height),
          family_ref(b, s.family)))
    else
      @remote(b, CreateArcWall(
          center, radius, start_angle, end_angle,
          ref_value(b, s.bottom_level),
          ref_value(b, s.top_level),
          family_ref(b, s.family)))
    end
  end

realize_wall_path(b::RVT, s::Wall, path) =
  let (locs, arcs) = locs_and_arcs(path)
    if ref_value(b, s.top_level) == RVTVoidId
      @remote(b, CreateUnconnectedPathWall(
          locs, arcs,
          ref_value(b, s.bottom_level),
          to_revit(s.top_level.height - s.bottom_level.height),
          family_ref(b, s.family)))
    else
      @remote(b, CreatePathWall(
          locs, arcs,
          ref_value(b, s.bottom_level),
          ref_value(b, s.top_level),
          family_ref(b, s.family),
          false))
    end
  end

# Multi-segment wall support for opening placement.
# CreateLineWall creates one Revit wall element per pair of consecutive vertices.
# InsertWindow/InsertDoor position openings at deltaFromStart along a single host
# element's curve, so we must map the global offset along the full wall path to
# the correct segment and a local offset within it.

_wall_segment_lengths(path::OpenPolygonalPath) =
  [distance(path.vertices[i], path.vertices[i+1]) for i in 1:length(path.vertices)-1]
_wall_segment_lengths(path::ClosedPolygonalPath) =
  let verts = [path.vertices..., path.vertices[1]]
    [distance(verts[i], verts[i+1]) for i in 1:length(verts)-1]
  end
_wall_segment_lengths(path::RectangularPath) =
  _wall_segment_lengths(convert(ClosedPolygonalPath, path))
_wall_segment_lengths(path::CompositePath) =
  [path_length(seg) for seg in path_pieces(path)]
_wall_segment_lengths(path) = [path_length(path)]

_opening_wall_segment(cum_lengths, global_x) =
  let n = length(cum_lengths)
    for i in 1:n
      if global_x <= cum_lengths[i] || i == n
        local_x = i == 1 ? global_x : global_x - cum_lengths[i-1]
        return (i, local_x)
      end
    end
  end

_wall_host_and_offset(wall_refs, wall_path, global_x) =
  if length(wall_refs) == 1
    (wall_refs[1], global_x)
  else
    let seg_lengths = _wall_segment_lengths(wall_path),
        cum_lengths = cumsum(seg_lengths),
        (seg_idx, local_x) = _opening_wall_segment(cum_lengths, global_x)
      (wall_refs[seg_idx], local_x)
    end
  end

#=
Single seam for placing wall-hosted openings (windows and doors).

This consolidates what used to be three near-identical bodies:
`realize_wall_openings`, `realize(::Window)`, and `realize(::Door)`. The
work is the same in all three: read the family's `location_transform` and
`instance_map`, map the global x-offset to a (host_segment, local_x) pair
via `_wall_host_and_offset`, then dispatch to the right C# RPC based on
opening type and whether the family declares any instance parameters.

`InsertDoorWithParams` is used when the door's instance_map is non-empty;
otherwise the legacy `InsertDoor` (4-arg) RPC is called so existing scripts
that depend on its specific signature continue to work.
=#
_insert_opening(b, opening::Window, local_x, y, host_ref, fam_ref, params, values) =
  @remote(b, InsertWindow(local_x, y, host_ref, fam_ref, params, values))

_insert_opening(b, opening::Door, local_x, y, host_ref, fam_ref, params, values) =
  isempty(params) ?
    @remote(b, InsertDoor(local_x, y, host_ref, fam_ref)) :
    @remote(b, InsertDoorWithParams(local_x, y, host_ref, fam_ref, params, values))

_realize_wall_opening(b, opening, wall_path, wall_refs) =
  let rvtf = backend_family(b, opening.family),
      loc = rvtf.location_transform(opening.family, opening.loc),
      (host_ref, local_x) = _wall_host_and_offset(wall_refs, wall_path, loc.x),
      param_map = rvtf.instance_map,
      params = collect(keys(param_map)),
      values = [param_map[p](opening.family) for p in params]
    _insert_opening(b, opening, local_x, loc.y, host_ref,
                    family_ref(b, opening.family), params, values)
  end

KhepriBase.realize_wall_openings(b::RVT, w::Wall, w_ref, openings) =
  if isempty(openings)
    w_ref
  else
    let wall_refs = ref_values(b, w_ref)
      for opening in openings
        ref!(b, opening, _realize_wall_opening(b, opening, w.path, wall_refs))
      end
      w_ref
    end
  end

# Accessing ref_values(b, s.wall) may trigger wall realization, which creates
# this opening via realize_wall_openings and caches it with ref!.
# Check realized(b, s) after to avoid creating a duplicate.
realize(b::RVT, s::Window) =
  let wall_refs = ref_values(b, s.wall)
    if realized(b, s)
      ref_value(b, ref(b, s))
    else
      _realize_wall_opening(b, s, s.wall.path, wall_refs)
    end
  end

realize(b::RVT, s::Door) =
  let wall_refs = ref_values(b, s.wall)
    if realized(b, s)
      ref_value(b, ref(b, s))
    else
      _realize_wall_opening(b, s, s.wall.path, wall_refs)
    end
  end

#

# Functional wall construction with door/window specs.
# Each spec is a tuple (loc, family).
wall_with_openings(path; doors=[], windows=[], kwargs...) =
  let w = wall(path; kwargs...)
    for (loc, family) in doors
      push!(w.doors, door(w, loc, family=family))
    end
    for (loc, family) in windows
      push!(w.windows, window(w, loc, family=family))
    end
    w
  end

KhepriBase.b_curtain_wall(b::RVT, path, bottom_level, top_level, family, offset) =
  let (locs, arcs) = locs_and_arcs(path)
    @remote(b, CreatePathCurtainWall(locs, arcs, ref_value(b, bottom_level), ref_value(b, top_level), family_ref(b, family), false))
  end

KhepriBase.b_toilet(b::RVT, c, host, family) =
  let rvtf = backend_family(b, family),
      c = rvtf.location_transform(family, c)
    @remote(b, CreateElementLocDirOnHost(c, vx(1, c.cs), ref_value(b, host), family_ref(b, family)))
  end

KhepriBase.b_closet(b::RVT, c, host, family) =
  let rvtf = backend_family(b, family),
      c = rvtf.location_transform(family, c)
    @remote(b, CreateElementLocDirOnHost(c, vx(1, c.cs), ref_value(b, host), family_ref(b, family)))
  end

KhepriBase.b_sink(b::RVT, c, host, family) =
  let rvtf = backend_family(b, family),
      c = rvtf.location_transform(family, c)
    @remote(b, CreateElementLocDirOnHost(c, vx(1, c.cs), ref_value(b, host), family_ref(b, family)))
  end

KhepriBase.b_family_element(b::RVT, loc, angle, level, family) =
  let p = loc_from_o_phi(loc, angle)
    @remote(b, CreateElementLocDirOnHost(p, vx(1, p.cs),
            ref_value(b, level), family_ref(b, family)))
  end

#=
Panels are realized as a Revit DirectShape whose geometry is the panel's region
extruded by the family's thickness. Curtain panels were rejected as the
implementation strategy because they require a hosting curtain-wall element and
do not match the Khepri panel semantics (a free-floating planar piece). The
DirectShape is placed in OST_GenericModel by default; users who need a different
category can override via `family_map["category"]`.

The thickness is read through the family seam so users can override via
`family_map["thickness"]` (e.g. for a parametric panel where thickness depends
on context). The default extractor reads PanelFamily.thickness.

See also: `b_slab`, `b_curtain_wall`, `set_backend_family`.
=#
KhepriBase.b_panel(b::RVT, region::Region, family) =
  b_panel(b, outer_path(region), family)

KhepriBase.b_panel(b::RVT, contour::ClosedPolygonalPath, family) =
  let rvtf = backend_family(b, family),
      thickness = _lookup_family_param(rvtf, "thickness", f -> f.thickness)(family)
    @remote(b, CreatePanelExtrusion(contour.vertices, Float64[], to_revit(thickness), RVTId(0)))
  end

KhepriBase.b_panel(b::RVT, contour::RectangularPath, family) =
  b_panel(b, convert(ClosedPolygonalPath, contour), family)

KhepriBase.b_panel(b::RVT, contour::ClosedPath, family) =
  let rvtf = backend_family(b, family),
      thickness = _lookup_family_param(rvtf, "thickness", f -> f.thickness)(family),
      (locs, arcs) = locs_and_arcs(contour)
    @remote(b, CreatePanelExtrusion(locs, arcs, to_revit(thickness), RVTId(0)))
  end

realize(b::RVT, s::TrussNode) =
  @remote(b, CreateBeam(s.p, add_x(s.p, 0.1), 0, family_ref(b, s.family)))

realize(b::RVT, s::TrussBar) =
  @remote(b, CreateBeam(s.p0, s.p1, s.angle, family_ref(b, s.family)))

############################################
# Select New Family ...
# Choose Metric Generic Model


# Conservative Revit materials: realize a PbrMaterial as a Revit Material element with
# Color + Transparency (Material.Create; no AppearanceAsset yet). Honors base_color and
# transparency; metallic/roughness/specular/ior/clearcoat/emission are not mapped (they
# need an AppearanceAssetElement — future). Revit has a single 0-100 transparency channel,
# so opacity (1-alpha) and transmission are collapsed into it. See materials design note (P2).
KhepriBase.b_material(b::RVT, name, base_color, metallic, roughness, specular,
                      ior, transmission, transmission_roughness,
                      clearcoat, clearcoat_roughness,
                      emission_color, emission_strength) =
  @remote(b, CreateMaterial(name, base_color,
                            round(Int, clamp(max(1 - alpha(base_color), transmission), 0, 1) * 100)))


# Pyramids use the PyramidFrustum element Revit supports (an apex pyramid is a
# frustum whose top polygon collapses to the apex, one apex copy per base vertex).
# Box is a native extrusion Solid (see b_box -> Box below), not a tessellated frustum.
# b_right_cuboid is left to the KhepriBase default, which centers and delegates to b_box.
KhepriBase.b_pyramid(b::RVT, bs, t, bmat, smat) =
  b_pyramid_frustum(b, bs, fill(t, length(bs)), bmat, smat, smat)
KhepriBase.b_pyramid_frustum(b::RVT, bs, ts, bmat, tmat, smat) =
  @remote(b, PyramidFrustum(bs, ts))
KhepriBase.b_box(b::RVT, c, dx, dy, dz, mat) =
  @remote(b, Box([c, add_x(c, dx), add_xy(c, dx, dy), add_y(c, dy)], dz, mat))
# Single-material Revit solids: pick the first available material id (side dominates);
# -1 (InvalidElementId) = no material. Per-face cap materials are a future refinement (P2).
rvt_material(ms...) = something(ms..., -1)
KhepriBase.b_cone(b::RVT, cb, r, h, bmat, smat) =
  @remote(b, Cone(cb, vz(1, cb.cs), r, h, rvt_material(smat, bmat)))
KhepriBase.b_cone_frustum(b::RVT, cb, rb, h, rt, bmat, tmat, smat) =
  @remote(b, ConeFrustum(cb, vz(1, cb.cs), rb, h, rt, rvt_material(smat, bmat, tmat)))
KhepriBase.b_cylinder(b::RVT, cb, r, h, bmat, tmat, smat) =
  isnothing(bmat) || isnothing(tmat) ?
    @remote(b, CylinderWithCaps(cb, vz(1, cb.cs), r, h, !isnothing(bmat), !isnothing(tmat), rvt_material(smat, bmat, tmat))) :
    @remote(b, Cylinder(cb, vz(1, cb.cs), r, h, rvt_material(smat, bmat, tmat)))
#Experiment with private Element Cylinder2(XYZ bottom, VXYZ axis, Length radius, Length height) {
KhepriBase.b_sphere(b::RVT, c, r, mat) =
  @remote(b, Sphere(c, r, mat))

# Per-element world AABB corners, aggregated per-axis on the Julia side. Mirrors the
# KhepriUnreal/KhepriUnity b_bounding_box convention.
KhepriBase.b_bounding_box(b::RVT, shapes::Shapes) =
  let refs = ref_values(b, shapes),
      mins = [@remote(b, BoundingBoxMin(r)) for r in refs],
      maxs = [@remote(b, BoundingBoxMax(r)) for r in refs]
    (xyz(minimum(p -> p.x, mins), minimum(p -> p.y, mins), minimum(p -> p.z, mins)),
     xyz(maximum(p -> p.x, maxs), maximum(p -> p.y, maxs), maximum(p -> p.z, maxs)))
  end
# Torus has no native Revit RPC; the KhepriBase default (b_torus -> b_surface_grid,
# which Revit implements) tessellates it.

#

KhepriBase.b_surface_grid(b::RVT, ptss, closed_u, closed_v, smooth_u, smooth_v, mat) =
    @remote(b, SurfaceFromGrid(
        size(ptss,2),
        size(ptss,1),
        reshape(ptss,:),
        closed_u,
        closed_v,
        0))

# Groups
# Each instance re-creates its member shapes at the instance location via the factory, then groups
# them into a real Revit group (doc.Create.NewGroup). Grouping keeps the members out of DocWalls/etc.
# so a round-tripped model's element counts match the source, rather than leaving loose duplicates.

realize(b::RVT, s::Group) =
  void_ref(b)  # container only; shapes created via GroupInstance

realize(b::RVT, s::GroupInstance) =
  with(current_cs, translated_cs(current_cs(), cx(s.loc), cy(s.loc), cz(s.loc))) do
    let factory = s.group.factory
      if factory !== nothing
        let shapes = collecting_shapes(factory),
            refs = ref_values(b, shapes)
          isempty(refs) ? void_ref(b) : @remote(b, CreateGroup(refs))
        end
      else
        void_ref(b)
      end
    end
  end

############################################

# Create 4 (3) reference planes that give the panel outline
# Create extrusion nos reference planes
# Use align tool to lock the extrusion to the reference planes
# Use draw tools to create the holes
# Change to Floor plan to give thickness
# Return to Elevation Front to visualize result
# [Don't (Save the family (requires name))] ->
# Load into project
# Place aligned with a wall

############################################

# Select Family Metric Mass (inside Conceptual Mass)
# Create Model
# Reference lines
# Create Form -> Solid Form
# Create Form -> Void Form
# Load into project
# Place aligned with a wall

############################################

KhepriBase.backend_name(b::RVT) = "Revit"

KhepriBase.b_set_view(b::RVT, camera::Loc, target::Loc, lens::Real, aperture::Real) =
  let width = render_width(),
      height = render_height()
    @remote(b, SetView(camera, target, width, height, lens))
  end

KhepriBase.b_get_view(b::RVT) =
  @remote(b, GetCamera()), @remote(b, GetTarget()), @remote(b, GetLens())

KhepriBase.b_set_view_size(b::RVT, width, height) =
  @remote(b, ViewSize(width, height))

KhepriBase.b_render_and_save_view(b::RVT, path::String) =
  @remote(b, RenderView(path))

KhepriBase.b_delete_all_shape_refs(b::RVT) =
  @remote(b, DeleteAllElements())

# Single-element delete — needed by delete_shape (e.g. add_door/add_window delete + re-realize the
# host wall to insert the opening). Revit previously implemented only delete-all. `r::RVTId` typing
# makes this strictly more specific than KhepriBase's generic b_delete_ref(b::Backend{K,T}, r::T).
KhepriBase.b_delete_ref(b::RVT, r::RVTId) =
  @remote(b, DeleteElement(r))

# prompt_position removed: the Revit plugin has no GetPoint RPC (only
# GetSelectedElements). Interactive position picking is not supported on Revit.

all_levels(b::RVT) =
  with_introspection(b) do
    [level_from_ref(r, b) for r in @remote(b, DocLevels())]
  end

# Cache of the model's base level, resolved once per introspection (reset in introspect_model).
const _base_level_cache = Parameter{Any}(nothing)

# An element not associated with a Revit level (unhosted furniture/plumbing fixture, orphan railing)
# reports a void level id. The old fallback default_level() (height 0) floated such elements ~226m BELOW
# a model at site elevation. Fall back instead to the model's lowest real level so they sit with the
# building; never worse than 0 (if the model genuinely has a level at 0, that stays the base).
_base_level(b::RVT) =
  _base_level_cache() !== nothing ? _base_level_cache() :
  let levels = [level_from_ref(id, b) for id in @remote(b, DocLevels())]
    if isempty(levels)
      default_level()
    else
      let base = argmin(l -> l.height, levels)
        _base_level_cache(base)
        base
      end
    end
  end

level_from_ref(r, b::RVT) =
  r == RVTVoidId ?
    _base_level(b) :
    let s = level(@remote(b, GetLevelElevation(r)))
      ref!(b, s, r)
      s
    end

unconnected_level(h::Real, b::RVT) =
  let s = level(h)
    ref!(b, s, RVTVoidId)
    s
  end

all_elements(b::RVT) =
    [element_from_ref(r, b) for r in @remote(b, DocElements())]

all_walls(b::RVT) =
  with_introspection(b) do
    [wall_from_ref(r, b) for r in @remote(b, DocWalls())]
  end
all_walls_at_level(level::Level, b::RVT) =
  with_introspection(b) do
    [wall_from_ref(r, b) for r in @remote(b, DocWallsAtLevel(ref(level).value))]
  end

# Map a Revit element material [r,g,b,transparency(0-100),shininess(0-128),smoothness(0-100)] to a
# Khepri PbrMaterial, so system-family elements carry their real appearance for non-BIM backends.
_material_from_revit(m) =
  length(m) < 6 ? material_plaster :
  pbr_material(base_color=rgba(m[1], m[2], m[3], 1 - m[4]/100),
               roughness=clamp(1 - m[6]/100, 0.0, 1.0),
               specular=clamp(m[5]/128, 0.0, 1.0),
               transmission=clamp(m[4]/100, 0.0, 1.0))

wall_from_ref(r, b::RVT) =
  let curve_type = @remote(b, WallCurveType(r)),
      is_curtain = @remote(b, WallIsCurtainWall(r)),
      bottom_level_id = @remote(b, ElementLevel(r)),
      top_level_id = @remote(b, WallTopLevel(r)),
      bottom_level = level_from_ref(bottom_level_id, b),
      top_level = top_level_id == RVTVoidId ?
                    unconnected_level(bottom_level.height + @remote(b, WallHeight(r)), b) :
                    level_from_ref(top_level_id, b),
      path = if curve_type == "Line"
               convert(Path, @remote(b, LineWallVertices(r)))
             elseif curve_type == "Arc"
               let verts = @remote(b, ArcWallVertices(r)),
                   center = verts[1],
                   radius = @remote(b, ArcWallRadius(r)),
                   angles = @remote(b, ArcWallAngles(r))
                 arc_path(center, radius, angles[1], angles[2] - angles[1])
               end
             else
               convert(Path, @remote(b, LineWallVertices(r)))
             end,
      s = is_curtain ?
            curtain_wall(path, bottom_level=bottom_level, top_level=top_level) :
            let mat = _material_from_revit(@remote(b, ElementMaterial(r)))
              wall(path, bottom_level=bottom_level, top_level=top_level,
                   family=wall_family(right_material=mat, left_material=mat, side_material=mat))
            end
    ref!(b, s, r)
    s
  end

# Floor introspection
# Drop consecutive coincident boundary vertices (and a final vertex equal to the first) so a
# reconstructed slab/ceiling/roof has no zero-length edges — Revit rejects those ("Curve length is too
# small for Revit's tolerance"). Fewer than 3 distinct vertices ⇒ degenerate, so the caller skips it.
_clean_boundary(verts; tol=0.005) =
  isempty(verts) ? verts :
  # Floors/ceilings/roofs are planar: project the boundary to a single Z (the first vertex's) so a
  # slightly non-planar boundary read from the source (e.g. a stepped/sloped floor edge) yields a
  # valid planar profile — Revit's Floor.Create rejects a non-planar profile ("Parameter name:
  # profile"). Then drop consecutive coincident vertices (and a closing dup) to avoid zero-length
  # edges ("Curve length is too small"). Fewer than 3 distinct vertices ⇒ degenerate, caller skips it.
  let z0 = cz(verts[1]),
      out = empty(verts)
    for v0 in verts
      let v = xyz(cx(v0), cy(v0), z0)
        (isempty(out) || distance(v, out[end]) > tol) && push!(out, v)
      end
    end
    length(out) > 2 && distance(out[end], out[1]) <= tol && pop!(out)
    out
  end

# Khepri places horizontal BIM elements RELATIVE to their level, but Revit returns absolute geometry Z
# (at site elevation, ~226 m below the internal origin for this model, but generally offset from the
# level). Rebase the contour Z to be relative to the element's level so realization (which re-adds the
# level height) reproduces the correct absolute Z on every backend and the generated code is portable.
_rebase_to_level(verts, lvl) =
  let h = lvl.height
    [xyz(cx(v), cy(v), cz(v) - h) for v in verts]
  end

# Build a slab/ceiling/roof region from ALL horizontal boundary loops — the first is the outer boundary,
# the rest are openings/shafts emitted as region holes (a single-loop element degrades to a plain region).
_region_from_loops(loops) =
  region(closed_polygonal_path(loops[1]), [closed_polygonal_path(l) for l in loops[2:end]]...)

_rebased_loops(loops, lvl) =
  filter(loop -> length(loop) >= 3,
         [_rebase_to_level(_clean_boundary(loop), lvl) for loop in loops])

floor_from_ref(r, b::RVT) =
  let level_id = @remote(b, FloorLevel(r)),
      lvl = level_from_ref(level_id, b),
      loops = _rebased_loops(@remote(b, FloorBoundaryLoops(r)), lvl),
      mat = _material_from_revit(@remote(b, ElementMaterial(r)))
    if isempty(loops)
      nothing
    else
      let s = slab(_region_from_loops(loops), level=lvl,
                   family=slab_family(top_material=mat, bottom_material=mat, side_material=mat))
        ref!(b, s, r)
        s
      end
    end
  end

all_floors(b::RVT) =
  with_introspection(b) do
    filter(!isnothing, [floor_from_ref(r, b) for r in @remote(b, DocFloors())])
  end

# Column introspection
column_from_ref(r, b::RVT) =
  let loc = @remote(b, ColumnLocation(r)),
      angle = @remote(b, ColumnRotation(r)),
      base_level_id = @remote(b, ColumnBaseLevel(r)),
      top_level_id = @remote(b, ColumnTopLevel(r)),
      base_level = level_from_ref(base_level_id, b),
      top_level = top_level_id == RVTVoidId ?
                    base_level :
                    level_from_ref(top_level_id, b),
      mat = _material_from_revit(@remote(b, ElementMaterial(r))),
      s = column(loc, angle=angle, bottom_level=base_level, top_level=top_level,
                 family=column_family(material=mat))
    ref!(b, s, r)
    s
  end

all_columns(b::RVT) =
  with_introspection(b) do
    [column_from_ref(r, b) for r in @remote(b, DocColumns())]
  end

# Beam introspection
beam_from_ref(r, b::RVT) =
  let endpoints = @remote(b, BeamEndpoints(r)),
      p0 = endpoints[1],
      p1 = endpoints[2],
      angle = @remote(b, BeamRotation(r)),
      mat = _material_from_revit(@remote(b, ElementMaterial(r))),
      # Two-point form: preserves the beam's orientation (the old beam(p0, h) collapsed horizontal
      # beams to ~zero height). Pairs with meta_program(::Beam), which re-emits the two endpoints.
      s = beam(p0, p1, angle=angle, family=beam_family(material=mat))
    ref!(b, s, r)
    s
  end

all_beams(b::RVT) =
  with_introspection(b) do
    [beam_from_ref(r, b) for r in @remote(b, DocBeams())]
  end

# Door/Window introspection — return info tuples for code generation
struct HostedElementInfo
  ref::RVTId
  host_wall_id::RVTId
  delta_from_start::Float64
  sill_height::Float64
  width::Float64
  height::Float64
  family_name::String
  type_name::String
  is_system::Bool
end

all_doors(b::RVT) =
  [let pos = @remote(b, HostedElementPosition(r)),
       dims = @remote(b, DoorWindowDimensions(r))
     HostedElementInfo(
       r,
       @remote(b, HostWallId(r)),
       pos[1], pos[2],
       dims[1], dims[2],
       @remote(b, ElementFamilyName(r)),
       @remote(b, ElementTypeName(r)),
       @remote(b, IsSystemFamily(r)))
   end
   for r in @remote(b, DocDoors())]

all_windows(b::RVT) =
  [let pos = @remote(b, HostedElementPosition(r)),
       dims = @remote(b, DoorWindowDimensions(r))
     HostedElementInfo(
       r,
       @remote(b, HostWallId(r)),
       pos[1], pos[2],
       dims[1], dims[2],
       @remote(b, ElementFamilyName(r)),
       @remote(b, ElementTypeName(r)),
       @remote(b, IsSystemFamily(r)))
   end
   for r in @remote(b, DocWindows())]

# Ceiling introspection
ceiling_from_ref(r, b::RVT) =
  let level_id = @remote(b, CeilingLevel(r)),
      lvl = level_from_ref(level_id, b),
      loops = _rebased_loops(@remote(b, CeilingBoundaryLoops(r)), lvl),
      mat = _material_from_revit(@remote(b, ElementMaterial(r)))
    if isempty(loops)
      nothing
    else
      let s = ceiling(_region_from_loops(loops), level=lvl,
                      family=ceiling_family(bottom_material=mat, top_material=mat, side_material=mat))
        ref!(b, s, r)
        s
      end
    end
  end

all_ceilings(b::RVT) =
  with_introspection(b) do
    filter(!isnothing, [ceiling_from_ref(r, b) for r in @remote(b, DocCeilings())])
  end

# Roof introspection
roof_from_ref(r, b::RVT) =
  let level_id = @remote(b, RoofLevel(r)),
      lvl = level_from_ref(level_id, b),
      loops = _rebased_loops(@remote(b, RoofBoundaryLoops(r)), lvl),
      mat = _material_from_revit(@remote(b, ElementMaterial(r)))
    if isempty(loops)
      nothing
    else
      let s = roof(_region_from_loops(loops), level=lvl,
                   family=roof_family(bottom_material=mat, top_material=mat, side_material=mat))
        ref!(b, s, r)
        s
      end
    end
  end

all_roofs(b::RVT) =
  with_introspection(b) do
    filter(!isnothing, [roof_from_ref(r, b) for r in @remote(b, DocRoofs())])
  end

# Fixture introspection (furniture, plumbing, casework, generic models, specialty equipment)

fixture_from_ref(r, b::RVT) =
  let loc = @remote(b, FamilyInstanceLocation(r)),
      angle = @remote(b, FamilyInstanceRotation(r)),
      level_id = @remote(b, FamilyInstanceLevel(r)),
      lvl = level_from_ref(level_id, b),
      s = family_element(loc, angle=angle, level=lvl)
    ref!(b, s, r)
    s
  end

all_fixtures(b::RVT) =
  with_introspection(b) do
    let refs = vcat(
          @remote(b, DocFurniture()),
          @remote(b, DocPlumbingFixtures()),
          @remote(b, DocCasework()),
          @remote(b, DocGenericModels()),
          @remote(b, DocSpecialtyEquipment()))
      [fixture_from_ref(r, b) for r in refs]
    end
  end

# Stair introspection
stair_from_ref(r, b::RVT) =
  let base = @remote(b, StairBasePoint(r)),
      dir = @remote(b, StairDirection(r)),
      base_level_id = @remote(b, StairBaseLevel(r)),
      top_level_id = @remote(b, StairTopLevel(r)),
      base_level = level_from_ref(base_level_id, b),
      top_level = top_level_id == RVTVoidId ? base_level : level_from_ref(top_level_id, b),
      # StairDirection comes back as an XYZ point; stair() wants a horizontal direction vector (VXY).
      s = stair(base, direction=vxy(cx(dir), cy(dir)), bottom_level=base_level, top_level=top_level)
    ref!(b, s, r)
    s
  end

all_stairs(b::RVT) =
  with_introspection(b) do
    [stair_from_ref(r, b) for r in @remote(b, DocStairs())]
  end

# Railing introspection
railing_from_ref(r, b::RVT) =
  let pts = @remote(b, RailingPath(r)),
      level_id = @remote(b, RailingLevel(r)),
      lvl = level_from_ref(level_id, b)
    if length(pts) < 2
      nothing
    else
      let s = railing(open_polygonal_path(pts), level=lvl)
        ref!(b, s, r)
        s
      end
    end
  end

all_railings(b::RVT) =
  with_introspection(b) do
    filter(!isnothing, [railing_from_ref(r, b) for r in @remote(b, DocRailings())])
  end

# Group introspection

struct GroupInstanceInfo
  ref::RVTId
  type_id::RVTId
  type_name::String
  member_ids::Vector{RVTId}
  location::Loc
end

all_groups(b::RVT) =
  with_introspection(b) do
    [GroupInstanceInfo(
       r,
       @remote(b, GroupTypeId(r)),
       @remote(b, GroupTypeName(r)),
       @remote(b, GroupMemberIds(r)),
       @remote(b, GroupLocation(r)))
     for r in @remote(b, DocGroups())]
  end

# Introspect a member element by category, returning the appropriate shape
_member_from_ref_by_category(id, cat, b::RVT) =
  if cat == "Wall"
    wall_from_ref(id, b)
  elseif cat == "Floor"
    floor_from_ref(id, b)
  elseif cat == "Column"
    column_from_ref(id, b)
  elseif cat == "Beam"
    beam_from_ref(id, b)
  elseif cat == "Ceiling"
    ceiling_from_ref(id, b)
  elseif cat == "Roof"
    roof_from_ref(id, b)
  elseif cat == "Fixture"
    fixture_from_ref(id, b)
  elseif cat == "Stair"
    stair_from_ref(id, b)
  elseif cat == "Railing"
    railing_from_ref(id, b)
  else
    nothing
  end

# ═══════════════════════════════════════════════════════════════════
# Introspection (Revit-specific)
# ═══════════════════════════════════════════════════════════════════
# The backend-agnostic code-generation pipeline (model_to_expr, transform passes,
# expr_to_string) now lives in KhepriBase/src/CodeGen.jl. Below is only the
# Revit-specific introspection that produces the portable Khepri BIM model.

_store_element_family_meta!(m, b::RVT, family_meta) =
  let mref = ref_value(b, m),
      fam_name = @remote(b, ElementFamilyName(mref)),
      type_name = @remote(b, ElementTypeName(mref)),
      is_sys = @remote(b, IsSystemFamily(mref)),
      fam_path = (m isa Column || m isa FreeColumn || m isa Beam || m isa Stair || m isa Railing) ?
                   @remote(b, ElementFamilyPath(mref)) : ""
    family_meta[m.family] = FamilyMeta(category=_shape_family_category(m),
                                       family_name=fam_name, type_name=type_name,
                                       is_system=is_sys, path=fam_path)
  end

# A few Revit family types (notably plain wall openings, "Door-Opening:…") report 0 width/height via
# DoorWindowDimensions. Recover the size from the "…W x Hmm" type name when possible, else fall back to
# the family default — so introspection never emits a 0-width opening, which Revit rejects ("cannot
# make wall") when the reconstructed program re-inserts it into its host wall.
_opening_dims(w, h, type_name) =
  (w > 0 && h > 0) ? (w, h) :
  let m = match(r"(\d{2,5})\s*[xX]\s*(\d{2,5})", type_name)
    m === nothing ? nothing : (parse(Int, m[1]) / 1000, parse(Int, m[2]) / 1000)
  end
_door_family_with_dims(key, w, h, type_name) =
  let d = _opening_dims(w, h, type_name)
    d === nothing ? door_family(key) : door_family(key, d[1], d[2])
  end
_window_family_with_dims(key, w, h, type_name) =
  let d = _opening_dims(w, h, type_name)
    d === nothing ? window_family(key) : window_family(key, d[1], d[2])
  end

introspect_model(; b::RVT=revit) =
  with_introspection(b) do
  _base_level_cache(nothing)   # reset the per-introspection base-level fallback cache
  let family_meta = IdDict{Family, FamilyMeta}(),
      # Groups — collect instances and introspect one representative per type.
      # DocWalls/DocFloors/etc. already exclude group members (filtered in C#),
      # so we use ElementCategoryName to classify each group member by type.
      group_instances = all_groups(b),
      groups = let types_seen = Set{RVTId}(),
                   group_types = []
        for g in group_instances
          if g.type_id ∉ types_seen
            push!(types_seen, g.type_id)
            # Introspect member shapes using C#-side category classification
            members = filter(!isnothing,
              [let cat = @remote(b, ElementCategoryName(id))
                 _member_from_ref_by_category(id, cat, b)
               end
               for id in g.member_ids])
            # Deduplicate slabs with same vertices in different order
            members = _dedup_slabs(members)
            # Attach doors/windows to walls in this group
            door_infos = all_doors(b)
            window_infos = all_windows(b)
            for m in members
              if m isa Wall && !is_curtain_wall(m)
                let mref = ref_value(b, m)
                  for d in filter(d -> d.host_wall_id == mref, door_infos)
                    let dfam = _door_family_with_dims("$(d.family_name):$(d.type_name)", d.width, d.height, d.type_name)
                      family_meta[dfam] = FamilyMeta(category=:door, family_name=d.family_name,
                                                     type_name=d.type_name, is_system=d.is_system)
                      push!(m.doors, door(m, xy(d.delta_from_start, d.sill_height), family=dfam))
                    end
                  end
                  for wn in filter(w -> w.host_wall_id == mref, window_infos)
                    let wfam = _window_family_with_dims("$(wn.family_name):$(wn.type_name)", wn.width, wn.height, wn.type_name)
                      family_meta[wfam] = FamilyMeta(category=:window, family_name=wn.family_name,
                                                     type_name=wn.type_name, is_system=wn.is_system)
                      push!(m.windows, window(m, xy(wn.delta_from_start, wn.sill_height), family=wfam))
                    end
                  end
                end
              end
              # Collect family metadata for group members
              _store_element_family_meta!(m, b, family_meta)
            end
            # Collect all instances of this group type (skip empty groups)
            if !isempty(members)
              instances = [gi.location for gi in group_instances if gi.type_id == g.type_id]
              push!(group_types, (type_name=g.type_name, members=members, instances=instances))
            end
          end
        end
        group_types
      end,
      # Levels
      levels = all_levels(b),
      # Walls (with doors/windows attached)
      # DocWalls() already excludes group members (filtered in C#)
      walls = let wall_shapes = [wall_from_ref(r, b) for r in @remote(b, DocWalls())],
                  door_infos = all_doors(b),
                  window_infos = all_windows(b),
                  wall_to_doors = Dict{RVTId, Vector{HostedElementInfo}}(),
                  wall_to_windows = Dict{RVTId, Vector{HostedElementInfo}}()
                for d in door_infos
                  push!(get!(wall_to_doors, d.host_wall_id, HostedElementInfo[]), d)
                end
                for wi in window_infos
                  push!(get!(wall_to_windows, wi.host_wall_id, HostedElementInfo[]), wi)
                end
                for w in wall_shapes
                  if !is_curtain_wall(w)
                    let wref = ref_value(b, w),
                        wd = get(wall_to_doors, wref, HostedElementInfo[]),
                        ww = get(wall_to_windows, wref, HostedElementInfo[])
                      for d in wd
                        let dkey = "$(d.family_name):$(d.type_name)",
                            dfam = _door_family_with_dims(dkey, d.width, d.height, d.type_name)
                          family_meta[dfam] = FamilyMeta(category=:door, family_name=d.family_name,
                                                         type_name=d.type_name, is_system=d.is_system)
                          push!(w.doors, door(w, xy(d.delta_from_start, d.sill_height), family=dfam))
                        end
                      end
                      for wn in ww
                        let wkey = "$(wn.family_name):$(wn.type_name)",
                            wfam = _window_family_with_dims(wkey, wn.width, wn.height, wn.type_name)
                          family_meta[wfam] = FamilyMeta(category=:window, family_name=wn.family_name,
                                                         type_name=wn.type_name, is_system=wn.is_system)
                          push!(w.windows, window(w, xy(wn.delta_from_start, wn.sill_height), family=wfam))
                        end
                      end
                    end
                  end
                  _store_element_family_meta!(w, b, family_meta)
                end
                wall_shapes
              end,
      # DocFloors/DocColumns/DocBeams/DocCeilings already exclude group members (filtered in C#)
      floors = filter(!isnothing, [floor_from_ref(r, b) for r in @remote(b, DocFloors())]),
      columns = [column_from_ref(r, b) for r in @remote(b, DocColumns())],
      beams = [beam_from_ref(r, b) for r in @remote(b, DocBeams())],
      ceilings = filter(!isnothing, [ceiling_from_ref(r, b) for r in @remote(b, DocCeilings())]),
      roofs = filter(!isnothing, [roof_from_ref(r, b) for r in @remote(b, DocRoofs())]),
      fixtures = let fixture_refs = vcat(
                       @remote(b, DocFurniture()),
                       @remote(b, DocPlumbingFixtures()),
                       @remote(b, DocCasework()),
                       @remote(b, DocGenericModels()),
                       @remote(b, DocSpecialtyEquipment()))
                   [fixture_from_ref(r, b) for r in fixture_refs]
                 end,
      stairs = [stair_from_ref(r, b) for r in @remote(b, DocStairs())],
      railings = filter(!isnothing, [railing_from_ref(r, b) for r in @remote(b, DocRailings())])
    # Collect family metadata for all element types
    for f in floors _store_element_family_meta!(f, b, family_meta) end
    for c in columns _store_element_family_meta!(c, b, family_meta) end
    for bm in beams _store_element_family_meta!(bm, b, family_meta) end
    for ce in ceilings _store_element_family_meta!(ce, b, family_meta) end
    for rf in roofs _store_element_family_meta!(rf, b, family_meta) end
    for fx in fixtures _store_element_family_meta!(fx, b, family_meta) end
    for st in stairs _store_element_family_meta!(st, b, family_meta) end
    for rl in railings _store_element_family_meta!(rl, b, family_meta) end
    # Mesh-fallback (Phase 6): every renderable document element that NO reader consumed becomes an
    # obj_model, so nothing is silently dropped (curtain panels/mullions, MEP, topography, mass, in-place,
    # degenerate/sloped elements). Claim reconstructed shape refs + hosted door/window ids + group
    # instances/members, then complement against DocElements (all material-bearing elements). The
    # fallback_meshes vector is filled in-place by _attach_fallback_meshes! (post-introspection).
    claimed = Set{RVTId}()
    for coll in (walls, floors, columns, beams, ceilings, roofs, fixtures, stairs, railings)
      for s in coll
        let r = ref_value(b, s); r != RVTVoidId && push!(claimed, r) end
      end
    end
    for info in vcat(all_doors(b), all_windows(b)); push!(claimed, info.ref) end
    for g in group_instances
      push!(claimed, g.ref)
      for id in g.member_ids; push!(claimed, id) end
    end
    fallback_ids = collect(setdiff(Set{RVTId}(@remote(b, DocElements())), claimed))
    (levels=levels, walls=walls, floors=floors, columns=columns,
     beams=beams, ceilings=ceilings, roofs=roofs, fixtures=fixtures,
     stairs=stairs, railings=railings, groups=groups, family_meta=family_meta,
     fallback_ids=fallback_ids, fallback_meshes=ObjModel[])
  end
  end


# generate_khepri_code composes the KhepriBase codegen pipeline over the Revit model.

# Revit-specific hooks the KhepriBase codegen pipeline calls back into.
KhepriBase.b_codegen_module(b::RVT) = :KhepriRevit

# Emit the family's backend mappings as guarded statements so the SAME generated program reproduces the
# family natively in Revit AND (when an OBJ mesh was extracted) as that mesh in KhepriThreejs, without
# either mapping erroring in the other's session. `revit`: a loadable `.rfa` if we captured its path,
# else the built-in system family. `threejs`: the extracted OBJ family, only when one exists.
KhepriBase.b_native_family_expr(b::RVT, var, meta) =
  let rfa_str = Expr(:macrocall, Symbol("@raw_str"), nothing, meta.path),
      revit_native = (meta.is_system || isempty(meta.path)) ?
        Expr(:call, :revit_system_family) :
        # Doors/windows carry their dimensions on the instance, so use the opening-specific loader that
        # preserves the Width/Height mapping; other loadable families load the .rfa directly.
        (meta.category in (:door, :window) ?
           Expr(:call, :revit_opening_file_family, rfa_str) :
           Expr(:call, :revit_file_family, rfa_str)),
      stmts = Any[guarded_backend_family_expr(var, :revit, revit_native)]
    isempty(meta.obj_name) ||
      push!(stmts, guarded_backend_family_expr(var, :threejs, Expr(:call, :obj_family, meta.obj_name)))
    stmts
  end

# Match the C# SanitizeMaterialName used to name exported OBJ files (family name → OBJ file stem).
_sanitize_family(name) = replace(name, ' ' => '_', '/' => '_', '\\' => '_')

# Export loadable families to OBJ (best-effort) and stamp each family's metadata with its OBJ name, so
# codegen emits a KhepriThreejs mesh mapping alongside the Revit-native one. Runs as a post-introspection
# pass; never affects the Revit-native reconstruction (the threejs mapping is @isdefined-guarded), so a
# failed or partial export simply omits some cross-backend meshes.
function _attach_obj_families!(model, b, obj_folder)
  exported = try
    Dict(_sanitize_family(row[1]) => (obj=row[1], rfa=(length(row) >= 5 ? row[5] : ""))
         for row in @remote(b, ExportAllFamiliesToOBJWithMetadata(obj_folder)))
  catch e
    @warn "OBJ/RFA family export failed; cross-backend mappings omitted" exception=e
    return model
  end
  for (fam, meta) in collect(model.family_meta)
    let exp = get(exported, _sanitize_family(meta.family_name), nothing)
      if exp !== nothing && (isempty(meta.obj_name) || isempty(meta.path))
        model.family_meta[fam] = FamilyMeta(
          category=meta.category, family_name=meta.family_name, type_name=meta.type_name,
          is_system=meta.is_system,
          # The exported .rfa lets the reconstruction load the real native family in Revit; keep the
          # existing path if we already had one, else fall back to a system family when no .rfa exists.
          path=isempty(meta.path) ? exp.rfa : meta.path,
          obj_name=isempty(meta.obj_name) ? exp.obj : meta.obj_name)
      end
    end
  end
  model
end

# The mesh-fallback obj_models are for cross-backend reproduction (KhepriThreejs renders them via the
# default b_obj_model → b_surface_mesh path). Revit has the real elements and no mesh primitive
# (b_trig/b_surface_mesh unimplemented), so skip obj_models on the Revit rebuild rather than erroring.
# (Rendering them as DirectShape meshes on Revit is a possible follow-up.)
KhepriBase.b_obj_model(b::RVT, path, location, scale, material) = void_ref(b)

# Mesh-fallback pass (Phase 6): tessellate the fallback elements (those no parametric reader consumed) to
# per-element WORLD-space OBJ and stamp an obj_model into the model, so un-parametrizable elements
# reproduce as meshes instead of being silently dropped. Mirrors _attach_obj_families!; best-effort (a
# failed export just omits meshes). The OBJ is world-space, so each obj_model is placed at u0().
function _attach_fallback_meshes!(model, b, obj_folder)
  isempty(model.fallback_ids) && return model
  paths = try
    @remote(b, ExportElementsToOBJ(model.fallback_ids, obj_folder))
  catch e
    @warn "Mesh-fallback export failed; un-parametrized elements omitted" exception=e
    return model
  end
  # Construct the obj_model shapes under with_introspection so they are NOT realized here (Revit has no
  # b_trig/b_surface_mesh; these shapes exist only to be meta_program'd into the generated code).
  with_introspection(b) do
    for p in paths
      isempty(p) || push!(model.fallback_meshes, obj_model(p, u0()))
    end
  end
  @info "Mesh-fallback: $(length(model.fallback_meshes)) element(s) emitted as obj_model (of $(length(model.fallback_ids)) unclaimed)"
  model
end

function generate_khepri_code(output_path::String; b::RVT=revit, export_obj::Bool=true)
  let model = introspect_model(b=b),
      _ = export_obj ? _attach_obj_families!(model, b,
              joinpath(dirname(abspath(output_path)), "khepri_obj_models")) : model,
      _fb = export_obj ? _attach_fallback_meshes!(model, b,
              joinpath(dirname(abspath(output_path)), "khepri_obj_models")) : model,
      raw_expr = model_to_expr(model),
      fmap = family_expr_map(model),
      passes = [extract_levels,
                extract_families(fmap),
                add_backend_families(b, fmap),
                loop_rerolling,
                detect_level_repetition,
                add_header(b)],
      refined_expr = foldl((e, pass) -> pass(e), passes, init=raw_expr),
      code = expr_to_string(refined_expr)
    open(output_path, "w") do io
      write(io, code)
    end
    println("Generated Khepri code: $output_path")
    output_path
  end
end

#=

struct revit_family
    path::String
    map::Dict
end

struct archicad_family
    name::String
    map::Dict
end

# for a non-BIM backend
bars_family = beam_family(width=10,height=20,based_on=Dict(
    revit => revit_family(
        "C:\\ProgramData\\Autodesk\\RVT 2017\\Libraries\\US Metric\\Structural Framing\\Steel\\M_HSS-Hollow Structural Section.rfa",
        Dict(:width=>"b", :height=>"d", :angle=>"Cross-Section Rotation"))
#    archicad => archicad_family("SpecialBeam", Dict(:width=>"width", :height=>"height"))
))

=#

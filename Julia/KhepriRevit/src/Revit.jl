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
    generate_khepri_code,
    introspect_model,
    model_to_expr,
    expr_to_string,
    wall_with_openings,
    RevitSystemFamily,
    RevitFileFamily,
    RevitInPlaceFamily,
    revit_systems_family,
    revit_file_family

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
    local_bundle_contents_path = joinpath(local_bundle_path, "Contents")
    for dll in khepri_dlls
      src = joinpath(plugin_folder, dlls_folder, dll)
      dst = joinpath(local_bundle_contents_path, dll)
      rm(dst, force=true)
      cp(src, dst)
    end
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

checked_plugin = false

check_plugin() =
  begin
    global checked_plugin
    if ! checked_plugin
      @info("Checking Revit plugin...")
      for i in 1:10
        try
          update_plugin()
          @info("done.")
          checked_plugin = true
          return
        catch exc
          if isa(exc, Base.IOError) && i < 10
            @error("The Revit plugin is outdated! Please, close Revit.")
            sleep(5)
          else
            throw(exc)
          end
        end
      end
    end
  end

#
const revit_template = Parameter(abspath(@__DIR__, "../Plugin/KhepriTemplate.rte"))

start_revit() =
  run(`cmd /c cd "$(dirname(revit_template()))" \&\& $(basename(revit_template()))`, wait=false)

#
# RVT is a subtype of CS
parse_signature(::Val{:RVT}, sig::T) where {T} = parse_signature(Val(:CS), sig)
encode(::Val{:RVT}, t::Val{T}, c::IO, v) where {T} = encode(Val(:CS), t, c, v)
decode(::Val{:RVT}, t::Val{T}, c::IO) where {T} = decode(Val(:CS), t, c)

#
# We need some additional Encoders
encode(::Val{:RVT}, t::Union{Val{:XYZ},Val{:VXYZ}}, c::IO, p) =
  encode(Val(:CS), Val(:double3), c, raw_point(p))
decode(::Val{:RVT}, t::Val{:XYZ}, c::IO) =
  xyz(decode(Val(:CS), Val(:double3), c)..., world_cs)
decode(::Val{:RVT}, t::Val{:VXYZ}, c::IO) =
  vxyz(decode(Val(:CS), Val(:double3), c)..., world_cs)
encode(ns::Val{:RVT}, t::Union{Val{:ElementId},Val{:Element},Val{:Level},Val{:FloorFamily}}, c::IO, v) =
  encode(ns, Val(:long), c, v)
decode(ns::Val{:RVT}, t::Union{Val{:ElementId},Val{:Element},Val{:Level},Val{:FloorFamily}}, c::IO) =
  decode_or_error(ns, Val(:long), c, Int64(-1234))

@encode_decode_as(:RVT, Val{:Length}, Val{:double})
@encode_decode_as(:RVT, Val{:object}, Val{:Any})

revit_api = @remote_api :RVT """
public bool ConvertIFCFile(string file)
public bool LoadRVTFile(string file)
public Element Sphere(XYZ centre, Length radius)
public Element ConeFrustumNamed(string name, XYZ bottom, VXYZ axis, Length bottomRadius, Length height, Length topRadius)
public Element ConeFrustum(XYZ bottom, VXYZ axis, Length bottomRadius, Length height, Length topRadius)
public Element Cylinder(XYZ bottom, VXYZ axis, Length radius, Length height)
public Element Cone(XYZ bottom, VXYZ axis, Length bottomRadius, Length height)
public ElementId SurfaceFromGrid(int m, int n, XYZ[] pts, bool closedM, bool closedN, int level)
public Element PyramidFrustumNamed(String name, XYZ[] ps, XYZ[] qs, ElementId materialId)
public Element PyramidFrustumWithMaterial(XYZ[] ps, XYZ[] qs, ElementId materialId)
public Element PyramidFrustum(XYZ[] ps, XYZ[] qs)
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
public ElementId LoadFamily(string fileName)
public ElementId FamilyElement(ElementId familyId, string[] names, Length[] values)
public String InstalledLibraryPath(String root)
public void MoveElement(ElementId id, XYZ translation)
public void RotateElement(ElementId id, double angle, XYZ axis0, XYZ axis1)
public ElementId CreatePolygonalFloor(XYZ[] pts, ElementId levelId, ElementId famId)
public ElementId CreatePolygonalRoof(XYZ[] pts, ElementId levelId, ElementId famId)
public ElementId CreatePathFloor(XYZ[] pts, double[] angles, ElementId levelId, ElementId famId)
public ElementId CreatePathRoof(XYZ[] pts, double[] angles, ElementId levelId, ElementId famId)
public Element InsertDoor(Length deltaFromStart, Length deltaFromGround, Element host, ElementId familyId)
public Element InsertWindow(Length deltaFromStart, Length deltaFromGround, Element host, ElementId familyId, string[] names, object[] values)
public Element InsertRailing(Element host, ElementId familyId)
public void CreateFamily(string familyTemplatesPath, string familyTemplateName, string familyName)
public void CreateFamilyExtrusionTest(XYZ[] pts, double height)
public void InsertFamily(string familyName, XYZ p)
public void CreatePolygonalOpening(XYZ[] pts, Element host)
public void CreatePathOpening(XYZ[] pts, double[] angles, Element host)
public ElementId CreateBeam(XYZ p0, XYZ p1, double rotationAngle, ElementId famId)
public Element CreateColumn(XYZ location, ElementId baseLevelId, ElementId topLevelId, ElementId famId)
public Element CreateColumnPoints(XYZ p0, XYZ p1, Level level0, Level level1, ElementId famId)
public ElementId[] CreateLineWall(XYZ[] pts, ElementId baseLevelId, ElementId topLevelId, ElementId famId)
public ElementId[] CreateUnconnectedLineWall(XYZ[] pts, ElementId baseLevelId, double height, ElementId famId)
public ElementId[] CreatePathWall(XYZ[] pts, double[] angles, ElementId baseLevelId, ElementId topLevelId, ElementId famId, bool isStructural)
public ElementId[] CreateUnconnectedPathWall(XYZ[] pts, double[] angles, ElementId baseLevelId, double height, ElementId famId)
public Element CreateArcWall(XYZ center, Length radius, double startAngle, double endAngle, ElementId baseLevelId, ElementId topLevelId, ElementId famId)
public Element CreateUnconnectedArcWall(XYZ center, Length radius, double startAngle, double endAngle, ElementId baseLevelId, double height, ElementId famId)
public ElementId CreatePathCurtainWall(XYZ[] pts, double[] angles, ElementId baseLevelId, ElementId topLevelId, ElementId famId, bool isStructural)
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
public double WallHeight(Element element)
public void HighlightElement(ElementId id)
public ElementId[] GetSelectedElements()
public bool IsProject()
public void DeleteAllElements()
public void SetView(XYZ camera, XYZ target, int width, int height, double lens)
public XYZ GetCamera()
public XYZ GetTarget()
public double GetLens()
public void ViewSize(int width, int height)
public void RenderView(string path)
public void EnergyAnalysis()
public ElementId CreatePolygonalCeiling(XYZ[] pts, ElementId levelId, ElementId famId)
public ElementId CreatePathCeiling(XYZ[] pts, double[] angles, ElementId levelId, ElementId famId)
public ElementId CreateRamp(XYZ p0, XYZ p1, double width, double thickness, ElementId baseLevelId, double baseOffset, double topOffset)
public Element CreateStraightStair(XYZ basePoint, VXYZ direction, double width, ElementId baseLevelId, ElementId topLevelId, ElementId familyId)
public Element CreateSpiralStair(XYZ center, double radius, double startAngle, double includedAngle, bool clockwise, double width, ElementId baseLevelId, ElementId topLevelId, ElementId familyId)
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
public string FloorTypeName(Element element)
public ElementId FloorLevel(Element element)
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
public double[] HostedElementPosition(Element element)
public Length[] DoorWindowDimensions(Element element)
public string ElementFamilyName(Element element)
public string ElementTypeName(Element element)
public string ElementFamilyPath(Element element)
public bool IsSystemFamily(Element element)
public XYZ[] CeilingBoundaryVertices(Element element)
public string CeilingTypeName(Element element)
public ElementId CeilingLevel(Element element)
"""

#=         //AML Revit cannot handle walls with curves that are not lines or arcs!!!!
public ElementId CreateSplineWall(XYZ[] pts, ElementId baseLevelId, ElementId topLevelId, ElementId famId, bool closed)
public ElementId CreateSplineCurtainWall(XYZ[] pts, ElementId baseLevelId, ElementId topLevelId, ElementId famId, bool closed)
=#

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

# Unit conversion: Revit internal units are feet.
# - `Length` parameters: C# `rLength()` applies `* to_feet` automatically
# - `object` parameters: C# `rObject()` reads raw doubles (no conversion)
# - `family_map` values: send in meters (C# converts via `Length`)
# - `instance_map` values: must be pre-converted to feet in Julia (sent as `object`)
const to_feet = 3.28084
#
KhepriBase.before_connecting(b::RVT) =
  check_plugin()
KhepriBase.after_connecting(b::RVT) =
  begin
    set_backend_family(default_wall_family(), b, revit_system_family())
    set_backend_family(default_curtain_wall_family(), b, revit_system_family())
    set_backend_family(default_window_family(), b, revit_file_family(
      revit_library_path("Metric Library", raw"Windows\M_Instance-Window-Fixed.rfa"),
      [], ["Width"=>f->f.width*to_feet, "Height"=>f->f.height*to_feet],
      (f, p)->p+vx(f.width/2, p.cs)))
    set_backend_family(default_door_family(), b, revit_system_family(
      [], [], (f, p)->p+vx(f.width/2, p.cs)))
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
    set_backend_family(default_railing_family(), b, revit_system_family())
    set_backend_family(default_ramp_family(), b, revit_system_family())
    set_backend_family(default_stair_family(), b, revit_system_family())
    set_backend_family(default_stair_landing_family(), b, revit_system_family())
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

backend_get_family_ref(b::RVT, f::Family, rvtf::RevitSystemFamily) =
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

backend_get_family_ref(b::RVT, f::Family, rvtf::RevitFileFamily) =
  let family_id = @remote(b, LoadFamily(rvtf.path)),
      param_map = rvtf.family_map,
      params = keys(param_map)
    @remote(b, FamilyElement(family_id, collect(params), [param_map[param](f) for param in params]))
  end
#

# This is for future use
struct RevitInPlaceFamily <: RevitFamily
    parameter_map::Dict{Symbol,String}
    ref::Parameter{Int}
end

#=
root should be "Imperial Library" or "Metric Library"
path can be something as "Structural Framing\\Wood\\M_Timber.rfa"
=#
export revit_library_path
revit_library_path(root::String, path::String) =
  joinpath(@remote(revit, InstalledLibraryPath(root)), path)

switch_to_backend(from::Backend, to::RVT) =
    let height = level_height(default_level())
        current_backend(to)
        default_level(level(height))
    end

#=
realize(b::RVT, f::TableFamily) =
    @remote(b, CreateRectangularTableFamily(f.length, f.width, f.height, f.top_thickness, f.leg_thickness))
realize(b::RVT, f::ChairFamily) =
    @remote(b, CreateChairFamily(f.length, f.width, f.height, f.seat_height, f.thickness))
realize(b::RVT, f::TableChairFamily) =
    @remote(b, CreateRectangularTableAndChairsFamily(
        ref(f.table_family), ref(f.chair_family),
        f.table_family.length, f.table_family.width,
        f.chairs_top, f.chairs_bottom, f.chairs_right, f.chairs_left,
        f.spacing)))

backend_rectangular_table(b::RVT, c, angle, family) =
    @remote(b, Table(c, angle, ref(family)))

backend_chair(b::RVT, c, angle, family) =
    @remote(b, Chair(c, angle, ref(family)))

backend_rectangular_table_and_chairs(b::RVT, c, angle, family) =
    @remote(b, TableAndChairs(c, angle, ref(family)))
=#

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

# Railing
KhepriBase.b_railing(b::RVT, path::OpenPolygonalPath, level, host, family) =
  @remote(b, CreateLineRailing(path.vertices, ref_value(b, level), family_ref(b, family)))

KhepriBase.b_railing(b::RVT, path::ClosedPolygonalPath, level, host, family) =
  @remote(b, CreatePolygonRailing(path.vertices, ref_value(b, level), family_ref(b, family)))

KhepriBase.b_railing(b::RVT, path, level, host, family) =
  @remote(b, InsertRailing(ref_value(b, host), family_ref(b, family)))

# Ramp
KhepriBase.b_ramp(b::RVT, path, bottom_level, top_level, family) =
  let p0 = in_world(path_start(path)),
      p1 = in_world(path_end(path)),
      bottom_h = level_height(b, bottom_level),
      top_h = level_height(b, top_level)
    @remote(b, CreateRamp(p0, p1, family.width, family.thickness,
                          ref_value(b, bottom_level), 0.0, top_h - bottom_h))
  end

# Stair
KhepriBase.b_stair(b::RVT, base_point, direction, bottom_level, top_level, family) =
  @remote(b, CreateStraightStair(
    base_point, direction, family.width,
    ref_value(b, bottom_level), ref_value(b, top_level), family_ref(b, family)))

KhepriBase.b_spiral_stair(b::RVT, center, radius, start_angle, included_angle,
                           clockwise, bottom_level, top_level, family) =
  @remote(b, CreateSpiralStair(
    center, radius, start_angle, included_angle, clockwise, family.width,
    ref_value(b, bottom_level), ref_value(b, top_level), family_ref(b, family)))

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
        s.top_level.height - s.bottom_level.height,
        family_ref(b, s.family)))
  else
    @remote(b, CreateLineWall(
        path.vertices,
        ref_value(b, s.bottom_level),
        ref_value(b, s.top_level),
        family_ref(b, s.family)))
  end

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
          s.top_level.height - s.bottom_level.height,
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
          s.top_level.height - s.bottom_level.height,
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

realize_wall_openings(b::RVT, w::Wall, w_ref, openings) =
  begin
      for opening in openings
          realize(b, opening)
      end
      w_ref
  end

realize(b::RVT, s::Window) =
  let rvtf = backend_family(b, s.family),
      param_map = rvtf.instance_map,
      params = keys(param_map),
      loc = rvtf.location_transform(s.family, s.loc)
    @remote(b, InsertWindow(
        loc.x,
        loc.y,
        ref_value(b, s.wall),
        family_ref(b, s.family),
        collect(params),
        [param_map[param](s.family) for param in params]))
  end

realize(b::RVT, s::Door) =
  let rvtf = backend_family(b, s.family),
      loc = rvtf.location_transform(s.family, s.loc)
    @remote(b, InsertDoor(
        loc.x,
        loc.y,
        ref_value(b, s.wall),
        family_ref(b, s.family)))
  end

backend_add_door(b::RVT, w::Wall, loc::Loc, family::DoorFamily) =
  let d = door(w, loc, family=family)
    push!(w.doors, d)
    if realized(w) && ! realized(d)
      realize(b, d)
    end
    w
  end
backend_add_window(b::RVT, w::Wall, loc::Loc, family::WindowFamily) =
    let d = window(w, loc, family=family)
        push!(w.windows, d)
        if realized(w) && ! realized(d)
            realize(b, d)
        end
        w
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

realize(b::RVT, s::TrussNode) =
  @remote(b, CreateBeam(s.p, add_x(s.p, 0.1), 0, family_ref(b, s.family)))

realize(b::RVT, s::TrussBar) =
  @remote(b, CreateBeam(s.p0, s.p1, s.angle, family_ref(b, s.family)))

############################################
# Select New Family ...
# Choose Metric Generic Model


# Revit does not use materials!
#KhepriBase.material_ref(b::RVT, m::Material) = nothing


KhepriBase.b_pyramid(b::RVT, bs, t, bmat, smat) =
  @remote(b, Pyramid(bs, t))
KhepriBase.b_pyramid_frustum(b::RVT, bs, ts, bmat, tmat, smat) =
  @remote(b, PyramidFrustum(bs, ts))
backend_right_cuboid(b::RVT, cb, width, height, h, material) =
  @remote(b, CenteredBox(cb, width, height, h))
KhepriBase.b_box(b::RVT, c, dx, dy, dz, mat) =
  @remote(b, Box(c, dx, dy, dz))
KhepriBase.b_cone(b::RVT, cb, r, h, bmat, smat) =
  @remote(b, Cone(cb, vz(1, cb.cs), r, h))
KhepriBase.b_cone_frustum(b::RVT, cb, rb, h, rt, bmat, tmat, smat) =
  @remote(b, ConeFrustum(cb, vz(1, cb.cs), rb, h, rt))
KhepriBase.b_cylinder(b::RVT, cb, r, h, bmat, tmat, smat) =
  @remote(b, Cylinder(cb, vz(1, cb.cs), r, h))
#Experiment with private Element Cylinder2(XYZ bottom, VXYZ axis, Length radius, Length height) {
KhepriBase.b_sphere(b::RVT, c, r, mat) =
  @remote(b, Sphere(c, r))
realize(b::RVT, s::Torus) =
  @remote(b, Torus(s.center, vz(1, s.center.cs), s.re, s.ri))

#
realize_prism(b::RVT, top, bot, side, path::PathSet, h::Real) =
  let v = planar_path_normal(path)*h,
      contour = path.paths[1],
      holes = path.paths[2:end]
    @remote(b, ExtrudedContour(
      path_vertices(contour), is_smooth_path(contour),
      path_vertices.(holes), is_smooth_path.(holes),
      v
      ))
  end

backend_surface_grid(b::RVT, points, closed_u, closed_v, smooth_u, smooth_v) =
    @remote(b, SurfaceFromGrid(
        size(points,2),
        size(points,1),
        reshape(points,:),
        closed_u,
        closed_v,
        0))

#=
unite_ref(b::RVT, r0::RVTNativeRef, r1::RVTNativeRef) =
    ensure_ref(b, @remote(b, Union(r0.value, r1.value)))

intersect_ref(b::RVT, r0::RVTNativeRef, r1::RVTNativeRef) =
    ensure_ref(b, @remote(b, Intersection(r0.value, r1.value)))

subtract_ref(b::RVT, r0::RVTNativeRef, r1::RVTNativeRef) =
    ensure_ref(b, @remote(b, Subtraction(r0.value, r1.value)))

unite_refs(b::RVT, refs::Vector{<:RVTRef}) =
    RVTUnionRef(tuple(refs...))
=#
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

zoom_extents(b::RVT) = @remote(b, ZoomExtents())

view_top(b::RVT) =
    @remote(b, ViewTop())

KhepriBase.b_delete_all_shape_refs(b::RVT) =
  @remote(b, DeleteAllElements())

prompt_position(prompt::String, b::RVT) =
  let ans = @remote(b, GetPoint(prompt))
    length(ans) > 0 && ans[1]
  end

all_levels(b::RVT) =
    [level_from_ref(r, b) for r in @remote(b, DocLevels())]

level_from_ref(r, b::RVT) =
  level(r == RVTVoidId ?
          error("Level for unconnected height") :
          @remote(b, GetLevelElevation(r)),
        ref=DynRefs(b=>RVTNativeRef(r)))

unconnected_level(h::Real, b::RVT) =
    level(h, ref=DynRefs(b=>RVTNativeRef(RVTVoidId)))

all_elements(b::RVT) =
    [element_from_ref(r, b) for r in @remote(b, DocElements())]

all_walls(b::RVT) =
    [wall_from_ref(r, b) for r in @remote(b, DocWalls())]
all_walls_at_level(level::Level, b::RVT) =
    [wall_from_ref(r, b) for r in @remote(b, DocWallsAtLevel(ref(level).value))]

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
             end
    is_curtain ?
      curtain_wall(path, bottom_level=bottom_level, top_level=top_level,
                   ref=DynRefs(b=>RVTNativeRef(r))) :
      wall(path, bottom_level=bottom_level, top_level=top_level,
           ref=DynRefs(b=>RVTNativeRef(r)))
  end

# Floor introspection
floor_from_ref(r, b::RVT) =
  let verts = @remote(b, FloorBoundaryVertices(r)),
      level_id = @remote(b, FloorLevel(r)),
      lvl = level_from_ref(level_id, b)
    isempty(verts) ?
      nothing :
      slab(closed_polygonal_path(verts), level=lvl,
           ref=DynRefs(b=>RVTNativeRef(r)))
  end

all_floors(b::RVT) =
  filter(!isnothing, [floor_from_ref(r, b) for r in @remote(b, DocFloors())])

# Column introspection
column_from_ref(r, b::RVT) =
  let loc = @remote(b, ColumnLocation(r)),
      base_level_id = @remote(b, ColumnBaseLevel(r)),
      top_level_id = @remote(b, ColumnTopLevel(r)),
      base_level = level_from_ref(base_level_id, b),
      top_level = top_level_id == RVTVoidId ?
                    base_level :
                    level_from_ref(top_level_id, b)
    column(loc, bottom_level=base_level, top_level=top_level,
           ref=DynRefs(b=>RVTNativeRef(r)))
  end

all_columns(b::RVT) =
  [column_from_ref(r, b) for r in @remote(b, DocColumns())]

# Beam introspection
beam_from_ref(r, b::RVT) =
  let endpoints = @remote(b, BeamEndpoints(r)),
      p0 = endpoints[1],
      p1 = endpoints[2],
      h = p1.z - p0.z,
      angle = @remote(b, BeamRotation(r))
    beam(p0, h, angle=angle,
         ref=DynRefs(b=>RVTNativeRef(r)))
  end

all_beams(b::RVT) =
  [beam_from_ref(r, b) for r in @remote(b, DocBeams())]

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
  let verts = @remote(b, CeilingBoundaryVertices(r)),
      level_id = @remote(b, CeilingLevel(r)),
      lvl = level_from_ref(level_id, b)
    isempty(verts) ?
      nothing :
      ceiling(closed_polygonal_path(verts), level=lvl,
              ref=DynRefs(b=>RVTNativeRef(r)))
  end

all_ceilings(b::RVT) =
  filter(!isnothing, [ceiling_from_ref(r, b) for r in @remote(b, DocCeilings())])

# ═══════════════════════════════════════════════════════════════════
# Code Generation — Multi-Pass Pipeline
# ═══════════════════════════════════════════════════════════════════
#
# Architecture (inspired by Tomás Grelha da Cunha's MSc thesis,
# "Refactoring for Dynamic Languages: The Julia Case", IST 2020):
#
# 1. Introspect: Query Revit model → Khepri shape objects
# 2. meta_program: Convert shapes → raw Julia Expr (AST)
# 3. Transform: Apply refactoring passes (extract variables, loop rerolling, …)
# 4. Print: Pretty-print final Expr → .jl file
#
# Each transform pass is a function Expr → Expr, composed in sequence.

# ─── Utilities ────────────────────────────────────────────────────

sanitize_name(name) =
  let s = replace(lowercase(strip(name)), r"[^a-z0-9_]" => "_"),
      s = replace(s, r"_+" => "_"),
      s = strip(s, '_')
    isempty(s) ? "unnamed" : (isdigit(s[1]) ? "_" * s : s)
  end

# Detect regular grid pattern in a set of values
function detect_regular_spacing(vals; tol=0.01)
  sorted = sort(unique(vals))
  length(sorted) < 2 && return nothing
  spacing = sorted[2] - sorted[1]
  spacing < tol && return nothing
  for i in 2:length(sorted)-1
    abs((sorted[i+1] - sorted[i]) - spacing) > tol && return nothing
  end
  (first=sorted[1], step=spacing, last=sorted[end], count=length(sorted))
end

# Bottom-up map over an Expr tree
map_expr(f, e::Expr) = f(Expr(e.head, map(x -> map_expr(f, x), e.args)...))
map_expr(f, x) = f(x)

# Collect all sub-expressions matching a predicate
collect_exprs(pred, x) = pred(x) ? [x] : []
collect_exprs(pred, e::Expr) =
  let result = pred(e) ? [e] : []
    for a in e.args
      append!(result, collect_exprs(pred, a))
    end
    result
  end

# Compare two Exprs structurally, returning list of (path, val1, val2) diffs.
# path is a vector of arg indices.
expr_diff(e1, e2) = e1 == e2 ? [] : [([],  e1, e2)]
expr_diff(e1::Expr, e2::Expr) =
  if e1.head != e2.head || length(e1.args) != length(e2.args)
    [([], e1, e2)]
  else
    let diffs = []
      for (i, (a1, a2)) in enumerate(zip(e1.args, e2.args))
        for (path, v1, v2) in expr_diff(a1, a2)
          push!(diffs, (vcat([i], path), v1, v2))
        end
      end
      diffs
    end
  end

# Replace the value at a path in an Expr with a new value
expr_replace_at(e, path, val) =
  isempty(path) ? val :
  let args = collect(e.args)
    args[path[1]] = expr_replace_at(args[path[1]], path[2:end], val)
    Expr(e.head, args...)
  end

# ─── Phase 1: Introspection ───────────────────────────────────────

# Metadata attached to shapes during introspection for use by transform passes.
# Stored as a Dict keyed by shape identity (objectid).
const _introspection_meta = Dict{UInt, NamedTuple}()

_set_meta!(shape, meta::NamedTuple) = _introspection_meta[objectid(shape)] = meta
_get_meta(shape) = get(_introspection_meta, objectid(shape), NamedTuple())

introspect_model(; b::RVT=revit) =
  let _ = empty!(_introspection_meta),
      # Levels
      levels = all_levels(b),
      # Walls (with doors/windows attached)
      walls = let wall_shapes = all_walls(b),
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
                  let wref = ref_value(b, w),
                      wd = get(wall_to_doors, wref, HostedElementInfo[]),
                      ww = get(wall_to_windows, wref, HostedElementInfo[])
                    for d in wd
                      let dkey = "$(d.family_name):$(d.type_name)",
                          dfam = door_family()
                        _set_meta!(dfam, (family_key=dkey, family_name=d.family_name,
                                         type_name=d.type_name, is_system=d.is_system, path="",
                                         category=:door))
                        push!(w.doors, door(w, xy(d.delta_from_start, d.sill_height), family=dfam))
                      end
                    end
                    for wn in ww
                      let wkey = "$(wn.family_name):$(wn.type_name)",
                          wfam = window_family()
                        _set_meta!(wfam, (family_key=wkey, family_name=wn.family_name,
                                         type_name=wn.type_name, is_system=wn.is_system, path="",
                                         category=:window))
                        push!(w.windows, window(w, xy(wn.delta_from_start, wn.sill_height), family=wfam))
                      end
                    end
                  end
                  # Collect wall family metadata
                  let fam_name = @remote(b, ElementFamilyName(ref_value(b, w))),
                      type_name = @remote(b, ElementTypeName(ref_value(b, w))),
                      is_sys = @remote(b, IsSystemFamily(ref_value(b, w))),
                      is_curtain = is_curtain_wall(w)
                    _set_meta!(w.family, (family_key="$fam_name:$type_name",
                                         family_name=fam_name, type_name=type_name,
                                         is_system=is_sys, path="",
                                         category=is_curtain ? :curtain_wall : :wall))
                  end
                end
                wall_shapes
              end,
      # Floors → slabs
      floors = all_floors(b),
      # Columns
      columns = all_columns(b),
      # Beams
      beams = all_beams(b),
      # Ceilings
      ceilings = all_ceilings(b)
    # Collect family metadata for floors, columns, beams, ceilings
    for f in floors
      let fam_name = @remote(b, ElementFamilyName(ref_value(b, f))),
          type_name = @remote(b, ElementTypeName(ref_value(b, f))),
          is_sys = @remote(b, IsSystemFamily(ref_value(b, f)))
        _set_meta!(f.family, (family_key="$fam_name:$type_name",
                              family_name=fam_name, type_name=type_name,
                              is_system=is_sys, path="", category=:slab))
      end
    end
    for c in columns
      let fam_name = @remote(b, ElementFamilyName(ref_value(b, c))),
          type_name = @remote(b, ElementTypeName(ref_value(b, c))),
          fam_path = @remote(b, ElementFamilyPath(ref_value(b, c))),
          is_sys = @remote(b, IsSystemFamily(ref_value(b, c)))
        _set_meta!(c.family, (family_key="$fam_name:$type_name",
                              family_name=fam_name, type_name=type_name,
                              is_system=is_sys, path=fam_path, category=:column))
      end
    end
    for bm in beams
      let fam_name = @remote(b, ElementFamilyName(ref_value(b, bm))),
          type_name = @remote(b, ElementTypeName(ref_value(b, bm))),
          fam_path = @remote(b, ElementFamilyPath(ref_value(b, bm))),
          is_sys = @remote(b, IsSystemFamily(ref_value(b, bm)))
        _set_meta!(bm.family, (family_key="$fam_name:$type_name",
                               family_name=fam_name, type_name=type_name,
                               is_system=is_sys, path=fam_path, category=:beam))
      end
    end
    for ce in ceilings
      let fam_name = @remote(b, ElementFamilyName(ref_value(b, ce))),
          type_name = @remote(b, ElementTypeName(ref_value(b, ce))),
          is_sys = @remote(b, IsSystemFamily(ref_value(b, ce)))
        _set_meta!(ce.family, (family_key="$fam_name:$type_name",
                               family_name=fam_name, type_name=type_name,
                               is_system=is_sys, path="", category=:ceiling))
      end
    end
    (levels=levels, walls=walls, floors=floors, columns=columns,
     beams=beams, ceilings=ceilings)
  end

is_curtain_wall(w) = w isa CurtainWall

# ─── Phase 2: Model → Expr ───────────────────────────────────────

# Side-channel: maps family Expr (from meta_program) to its introspection metadata.
# Populated by model_to_expr, consumed by extract_families and add_backend_families.
const _family_expr_meta = Dict{Expr, NamedTuple}()

# Register a family's meta_program Expr with its metadata
_register_family_expr!(family) =
  let m = _get_meta(family)
    if !isempty(m)
      _family_expr_meta[meta_program(family)] = m
    end
  end

function model_to_expr(model)
  empty!(_family_expr_meta)
  stmts = Expr[]
  for l in model.levels
    push!(stmts, meta_program(l))
  end
  for w in model.walls
    _register_family_expr!(w.family)
    for d in w.doors _register_family_expr!(d.family) end
    for wn in w.windows _register_family_expr!(wn.family) end
    push!(stmts, meta_program(w))
  end
  for f in model.floors
    _register_family_expr!(f.family)
    push!(stmts, meta_program(f))
  end
  for c in model.columns
    _register_family_expr!(c.family)
    push!(stmts, meta_program(c))
  end
  for bm in model.beams
    _register_family_expr!(bm.family)
    push!(stmts, meta_program(bm))
  end
  for ce in model.ceilings
    _register_family_expr!(ce.family)
    push!(stmts, meta_program(ce))
  end
  Expr(:block, stmts...)
end

# ─── Phase 3: Transform Passes ───────────────────────────────────

# 3.1 Extract levels: deduplicate level(h) calls into named variables
function extract_levels(e::Expr)
  level_calls = collect_exprs(
    x -> x isa Expr && x.head == :call && x.args[1] == :level && length(x.args) == 2,
    e)
  unique_levels = unique(level_calls)
  isempty(unique_levels) && return e
  # Sort by height value
  sorted = sort(unique_levels, by=x -> x.args[2] isa Real ? x.args[2] : 0.0)
  assignments = Expr[]
  replacements = Dict{Expr, Symbol}()
  for (i, lc) in enumerate(sorted)
    var = Symbol("level_$(i-1)")
    push!(assignments, Expr(:(=), var, lc))
    replacements[lc] = var
  end
  body = map_expr(x -> get(replacements, x, x), e)
  Expr(:block, assignments..., body.args...)
end

# 3.2 Extract families: deduplicate family constructors into named variables
function extract_families(e::Expr)
  family_fns = Set([:wall_family, :curtain_wall_family, :slab_family, :ceiling_family,
                    :column_family, :beam_family, :door_family, :window_family])
  family_calls = collect_exprs(
    x -> x isa Expr && x.head == :call && x.args[1] in family_fns,
    e)
  unique_families = unique(family_calls)
  isempty(unique_families) && return e
  assignments = Expr[]
  replacements = Dict{Expr, Symbol}()
  for fc in unique_families
    # Use introspection metadata for descriptive variable names
    meta = get(_family_expr_meta, fc, nothing)
    var = if meta !== nothing
      Symbol(sanitize_name("$(meta.category)_$(meta.family_name)_$(meta.type_name)"))
    else
      let cat = replace(string(fc.args[1]), "_family" => "")
        Symbol("$(cat)_fam_$(length(assignments)+1)")
      end
    end
    push!(assignments, Expr(:(=), var, fc))
    replacements[fc] = var
  end
  stmts = e.head == :block ? e.args : [e]
  # Find where levels end and elements start
  first_non_assign = findfirst(
    s -> !(s isa Expr && s.head == :(=) && s.args[2] isa Expr &&
           s.args[2].head == :call && s.args[2].args[1] == :level),
    stmts)
  insert_pos = first_non_assign === nothing ? length(stmts) + 1 : first_non_assign
  body = map_expr(x -> get(replacements, x, x), Expr(:block, stmts...))
  Expr(:block, body.args[1:insert_pos-1]..., assignments..., body.args[insert_pos:end]...)
end

# 3.3 Add backend family mappings
# Uses _family_expr_meta populated by model_to_expr
add_backend_families(model) = (e::Expr) ->
  let stmts = e.head == :block ? collect(e.args) : [e],
      family_fns = Set([:wall_family, :curtain_wall_family, :slab_family, :ceiling_family,
                        :column_family, :beam_family, :door_family, :window_family]),
      # Build var→meta lookup: when extract_families created `var = XXX_family(...)`,
      # the RHS Expr should be a key in _family_expr_meta
      new_stmts = Any[]
    for s in stmts
      push!(new_stmts, s)
      if s isa Expr && s.head == :(=) &&
         s.args[2] isa Expr && s.args[2].head == :call &&
         s.args[2].args[1] in family_fns
        let var = s.args[1],
            rhs = s.args[2],
            meta = get(_family_expr_meta, rhs, nothing)
          if meta !== nothing
            let backend_call = if meta.is_system || isempty(meta.path)
                  Expr(:call, :set_backend_family, var, :revit,
                       Expr(:call, :revit_system_family))
                else
                  Expr(:call, :set_backend_family, var, :revit,
                       Expr(:call, :revit_file_family, Expr(:macrocall, Symbol("@raw_str"), nothing, meta.path)))
                end
              push!(new_stmts, backend_call)
            end
          end
        end
      end
    end
    Expr(:block, new_stmts...)
  end

# 3.4 Loop rerolling: detect repeated shape calls forming grid patterns
loop_rerolling(e::Expr) =
  let stmts = e.head == :block ? collect(e.args) : [e],
      result = Any[],
      # Group consecutive statements by their "template" (shape call with same structure)
      i = 1
    while i <= length(stmts)
      let s = stmts[i]
        if s isa Expr && s.head == :call
          # Try to find a run of structurally similar calls
          let run_end = i,
              template = s
            for j in (i+1):length(stmts)
              let sj = stmts[j]
                if sj isa Expr && sj.head == :call && sj.args[1] == template.args[1] &&
                   length(sj.args) == length(template.args)
                  let diffs = expr_diff(template, sj)
                    # Only consider if all diffs are at leaf values (numbers, symbols)
                    all(d -> !(d[2] isa Expr) && !(d[3] isa Expr), diffs) || break
                    run_end = j
                  end
                else
                  break
                end
              end
            end
            if run_end - i + 1 >= 4  # Need at least 4 similar statements
              let run = stmts[i:run_end],
                  rerolled = _try_reroll(run)
                if rerolled !== nothing
                  push!(result, rerolled)
                  i = run_end + 1
                  continue
                end
              end
            end
          end
        end
        push!(result, s)
        i += 1
      end
    end
    Expr(:block, result...)
  end

function _try_reroll(stmts)
  length(stmts) < 4 && return nothing
  template = stmts[1]
  all_diffs = [expr_diff(template, s) for s in stmts[2:end]]
  isempty(all_diffs) && return nothing
  ref_paths = Set([d[1] for d in all_diffs[1]])
  all(ds -> Set([d[1] for d in ds]) == ref_paths, all_diffs) || return nothing
  paths = sort(collect(ref_paths))
  isempty(paths) && return nothing
  # Collect value sequences for each varying path
  value_lists = Dict{Vector{Int}, Vector{Any}}()
  for p in paths
    value_lists[p] = [_get_diff_value(template, p)]
  end
  for ds in all_diffs
    for (p, _, v2) in ds
      push!(value_lists[p], v2)
    end
  end
  # Try to detect 2D grid pattern (two varying paths)
  if length(paths) == 2
    _try_reroll_2d(template, paths, value_lists)
  elseif length(paths) == 1
    _try_reroll_1d(template, paths[1], value_lists[paths[1]])
  else
    nothing
  end
end

_get_diff_value(e::Expr, path) =
  isempty(path) ? e : _get_diff_value(e.args[path[1]], path[2:end])
_get_diff_value(x, path) = isempty(path) ? x : error("path too deep")

function _try_reroll_1d(template, path, values)
  range = _try_make_range(values)
  range === nothing && return nothing
  let var = gensym_short(:i),
      body = expr_replace_at(template, path, var)
    Expr(:for, Expr(:(=), var, range), Expr(:block, body))
  end
end

# Detect if v1, v2 form a nested grid pattern, returning path info
function _detect_nesting(v1, v2, n, p1, p2)
  let inner_unique = unique(v2), m = length(inner_unique)
    if n % m == 0
      let k = n ÷ m
        if all(i -> v2[i] == inner_unique[((i-1) % m) + 1], 1:n)
          let outer_unique = [v1[(i-1)*m + 1] for i in 1:k]
            if all(i -> all(j -> v1[(i-1)*m + j] == outer_unique[i], 1:m), 1:k)
              return (p1, outer_unique, p2, inner_unique)
            end
          end
        end
      end
    end
    # Try swapped
    let inner_unique = unique(v1), m = length(inner_unique)
      if n % m == 0
        let k = n ÷ m
          if all(i -> v1[i] == inner_unique[((i-1) % m) + 1], 1:n)
            let outer_unique = [v2[(i-1)*m + 1] for i in 1:k]
              if all(i -> all(j -> v2[(i-1)*m + j] == outer_unique[i], 1:m), 1:k)
                return (p2, outer_unique, p1, inner_unique)
              end
            end
          end
        end
      end
    end
    nothing
  end
end

function _try_reroll_2d(template, paths, value_lists)
  let p1 = paths[1], p2 = paths[2],
      v1 = value_lists[p1], v2 = value_lists[p2],
      n = length(v1),
      nested = _detect_nesting(v1, v2, n, p1, p2)
    nested === nothing && return nothing
    let (outer_path, outer_vals, inner_path, inner_vals) = nested,
        outer_range = _try_make_range(outer_vals),
        inner_range = _try_make_range(inner_vals)
      (outer_range === nothing || inner_range === nothing) && return nothing
      let outer_var = gensym_short(:x),
          inner_var = gensym_short(:y),
          body = expr_replace_at(
                   expr_replace_at(template, outer_path, outer_var),
                   inner_path, inner_var)
        Expr(:for, Expr(:(=), outer_var, outer_range),
             Expr(:block,
                  Expr(:for, Expr(:(=), inner_var, inner_range),
                       Expr(:block, body))))
      end
    end
  end
end

gensym_short(base::Symbol) =
  let names = Dict(:x => :x, :y => :y, :z => :z, :i => :i, :j => :j)
    get(names, base, base)
  end

# Try to convert a value list to a range expression
function _try_make_range(vals)
  n = length(vals)
  n < 2 && return Expr(:vect, vals...)
  sorted = sort(vals)
  spacing = sorted[2] - sorted[1]
  if spacing > 0 && all(i -> abs((sorted[i] - sorted[i-1]) - spacing) < 0.001, 2:n)
    let first_v = meta_program(sorted[1]),
        step_v = meta_program(spacing),
        last_v = meta_program(sorted[end])
      if step_v == 1
        Expr(:call, :(:), first_v, last_v)
      else
        Expr(:call, :(:), first_v, step_v, last_v)
      end
    end
  else
    Expr(:vect, map(meta_program, sorted)...)
  end
end

# 3.5 Detect level repetition: identical floor plans across levels → for loop
detect_level_repetition(e::Expr) =
  let stmts = e.head == :block ? collect(e.args) : [e]
    # Group shape calls by their level reference
    # This is a complex analysis — for now, return unchanged
    # TODO: Implement when models with repeated floor plans are available
    e
  end

# 3.6 Add header
add_header(e::Expr) =
  Expr(:block,
       Expr(:toplevel_comment, "Auto-generated Khepri code from Revit model"),
       Expr(:toplevel_comment, "Generated on: $(Dates.now())"),
       Expr(:using, Expr(:., :KhepriRevit)),
       stmts_of(e)...)

stmts_of(e::Expr) = e.head == :block ? e.args : [e]

# ─── Phase 4: Pretty-Printing ────────────────────────────────────

function expr_to_string(e::Expr; indent=0)
  let ind = "  " ^ indent,
      io = IOBuffer()
    _print_block(io, e, indent)
    String(take!(io))
  end
end

function _print_block(io, e::Expr, indent)
  let stmts = e.head == :block ? e.args : [e],
      prev_section = :none
    for (i, s) in enumerate(stmts)
      let cur_section = _stmt_section(s)
        # Add blank line between sections
        if i > 1 && cur_section != prev_section && prev_section != :none
          println(io)
        end
        _print_stmt(io, s, indent)
        println(io)
        prev_section = cur_section
      end
    end
  end
end

_stmt_section(s) =
  if s isa Expr
    if s.head == :toplevel_comment
      :header
    elseif s.head == :using
      :header
    elseif s.head == :(=) && s.args[2] isa Expr
      let rhs = s.args[2]
        if rhs.head == :call && rhs.args[1] == :level
          :levels
        elseif rhs.head == :call && rhs.args[1] in (:wall_family, :curtain_wall_family,
            :slab_family, :ceiling_family, :column_family, :beam_family,
            :door_family, :window_family)
          :families
        else
          :elements
        end
      end
    elseif s.head == :call && s.args[1] == :set_backend_family
      :families
    elseif s.head == :for
      :elements
    elseif s.head == :call
      :elements
    else
      :other
    end
  else
    :other
  end

function _print_stmt(io, s::Expr, indent)
  let ind = "  " ^ indent
    if s.head == :toplevel_comment
      print(io, "$(ind)# $(s.args[1])")
    elseif s.head == :using
      print(io, "$(ind)using $(join(map(_expr_str, s.args), ", "))")
    elseif s.head == :(=)
      print(io, "$(ind)$(s.args[1]) = $(_expr_str(s.args[2]))")
    elseif s.head == :for
      let binding = s.args[1],
          body = s.args[2]
        print(io, "$(ind)for $(_expr_str(binding))")
        println(io)
        _print_block(io, body, indent + 1)
        print(io, "$(ind)end")
      end
    elseif s.head == :call
      _print_call(io, s, ind)
    else
      print(io, "$(ind)$(_expr_str(s))")
    end
  end
end

_print_stmt(io, s, indent) = print(io, "  " ^ indent, _expr_str(s))

function _print_call(io, e::Expr, ind)
  let fn = e.args[1],
      args = e.args[2:end],
      # Separate positional and keyword args
      pos_args = filter(a -> !(a isa Expr && a.head == :kw), args),
      kw_args = filter(a -> a isa Expr && a.head == :kw, args),
      short = _expr_str(e)
    if length(short) + length(ind) <= 80
      print(io, "$(ind)$(short)")
    else
      # Multi-line format
      print(io, "$(ind)$(fn)(")
      let parts = vcat(map(_expr_str, pos_args), map(_kw_str, kw_args)),
          first_line = "$(fn)("
        for (i, p) in enumerate(parts)
          if i == 1
            print(io, p)
          else
            print(io, ",\n$(ind)  $(p)")
          end
        end
        print(io, ")")
      end
    end
  end
end

_kw_str(e::Expr) = "$(e.args[1])=$(_expr_str(e.args[2]))"

function _expr_str(e::Expr)
  if e.head == :call
    let fn = e.args[1],
        args = e.args[2:end],
        pos = filter(a -> !(a isa Expr && a.head == :kw), args),
        kw = filter(a -> a isa Expr && a.head == :kw, args),
        parts = vcat(map(_expr_str, pos), map(_kw_str, kw))
      "$(fn)($(join(parts, ", ")))"
    end
  elseif e.head == :(=)
    "$(_expr_str(e.args[1])) = $(_expr_str(e.args[2]))"
  elseif e.head == :kw
    "$(e.args[1])=$(_expr_str(e.args[2]))"
  elseif e.head == :vect
    "[$(join(map(_expr_str, e.args), ", "))]"
  elseif e.head == :tuple
    "($(join(map(_expr_str, e.args), ", ")))"
  elseif e.head == :ref
    "$(_expr_str(e.args[1]))[$(join(map(_expr_str, e.args[2:end]), ", "))]"
  elseif e.head == :.
    join(map(a -> a isa QuoteNode ? string(a.value) : _expr_str(a), e.args), ".")
  elseif e.head == :macrocall
    let macro_name = string(e.args[1])
      if macro_name == "@raw_str"
        "raw\"$(e.args[end])\""
      else
        string(e)
      end
    end
  elseif e.head == :using
    "using $(join(map(_expr_str, e.args), ", "))"
  else
    string(e)
  end
end

_expr_str(s::Symbol) = string(s)
_expr_str(x::Real) = string(meta_program(x))
_expr_str(x::Int) = string(x)
_expr_str(x::String) = repr(x)
_expr_str(x::Bool) = string(x)
_expr_str(x::QuoteNode) = string(x.value)
_expr_str(::Nothing) = "nothing"
_expr_str(x) = string(x)

# ─── Phase 5: Main Entry Point ───────────────────────────────────

function generate_khepri_code(output_path::String; b::RVT=revit)
  let model = introspect_model(b=b),
      raw_expr = model_to_expr(model),
      passes = [extract_levels,
                extract_families,
                add_backend_families(model),
                loop_rerolling,
                detect_level_repetition,
                add_header],
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

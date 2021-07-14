export
    revit,
    all_walls,
    all_floors,
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
      for dll in khepri_dlls
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
  encode(ns, Val(:int), c, v)
decode(ns::Val{:RVT}, t::Union{Val{:ElementId},Val{:Element},Val{:Level},Val{:FloorFamily}}, c::IO) =
  decode_or_error(ns, Val(:int), c, Int32(-1234))

@encode_decode_as(:RVT, Val{:Length}, Val{:double})


revit_api = @remote_functions :RVT """
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
public ElementId CreatePolygonalFloor(XYZ[] pts, ElementId levelId)
public ElementId CreatePolygonalRoof(XYZ[] pts, ElementId levelId, ElementId famId)
public ElementId CreatePathFloor(XYZ[] pts, double[] angles, ElementId levelId)
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
public ElementId CreateSplineWall(XYZ[] pts, ElementId baseLevelId, ElementId topLevelId, ElementId famId, bool closed)
public ElementId CreateSplineCurtainWall(XYZ[] pts, ElementId baseLevelId, ElementId topLevelId, ElementId famId, bool closed)
public Element CreateLineRailing(XYZ[] pts, ElementId baseLevelId, ElementId familyId)
public Element CreatePolygonRailing(XYZ[] pts, ElementId baseLevelId, ElementId familyId)
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
public void SetView(XYZ camera, XYZ target, double focal_length)
public void EnergyAnalysis()
"""

abstract type RVTKey end
const RVTId = Int32
const RVTIds = Vector{RVTId}
const RVTRef = GenericRef{RVTKey, RVTId}
const RVTRefs = Vector{RVTRef}
const RVTEmptyRef = EmptyRef{RVTKey, RVTId}
const RVTUniversalRef = UniversalRef{RVTKey, RVTId}
const RVTNativeRef = NativeRef{RVTKey, RVTId}
const RVTUnionRef = UnionRef{RVTKey, RVTId}
const RVTSubtractionRef = SubtractionRef{RVTKey, RVTId}
const RVT = SocketBackend{RVTKey, RVTId}
const RVTVoidId = RVTId(-1)

KhepriBase.void_ref(b::RVT) = RVTNativeRef(RVTVoidId)

KhepriBase.has_boolean_ops(::Type{RVT}) = HasBooleanOps{true}()

#
KhepriBase.before_connecting(b::RVT) =
  check_plugin()
KhepriBase.after_connecting(b::RVT) =
  begin
    # C:\\ProgramData\\Autodesk\\RVT 2017\\Libraries\\US Metric\\
    set_backend_family(default_wall_family(), revit, revit_system_family())
    set_backend_family(default_window_family(), revit, revit_system_family())
    set_backend_family(default_slab_family(), revit, revit_system_family())
    set_backend_family(default_column_family(), revit, revit_file_family(
          revit_library_path("Imperial Library", raw"../US Metric/Structural Columns/Concrete/M_Concrete-Rectangular-Column.rfa"),
          ["b"=>f->f.profile.dx, "h"=>f->f.profile.dy]))
    set_backend_family(default_beam_family(), revit, revit_file_family(
          revit_library_path("Imperial Library", raw"../US Metric/Structural Framing/Wood/M_Timber.rfa"),
          ["b"=>f->f.profile.dx, "d"=>f->f.profile.dy]))
    set_backend_family(default_truss_bar_family(), revit, revit_file_family(
          revit_library_path("Imperial Library", raw"../US Metric/Structural Framing/Steel/M_W-Wide Flange.rfa")))
    set_backend_family(default_truss_node_family(), revit, revit_file_family(
          revit_library_path("Imperial Library", raw"../US Metric/Structural Framing/Steel/M_W-Wide Flange.rfa")))
  #=
    #set_backend_family(default_column_family(), unity, unity_material_family("Materials/Concrete/Concrete2"))
    #set_backend_family(default_door_family(), unity, unity_material_family("Materials/Wood/InteriorWood2"))

    =#
    set_backend_family(default_panel_family(), revit, revit_system_family())
  end

const revit = RVT("Revit", revit_port, revit_api)

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
    instance_ref::Parameter{RVTId}
end

revit_system_family(family_map=(), instance_map=()) =
    RevitSystemFamily(
        Dict(family_map...),
        Dict(instance_map...),
        Parameter(RVTId(0))) # instead of RVTVoidId.  We need to think this carefully.

backend_get_family_ref(b::RVT, f::Family, rvtf::RevitSystemFamily) =
  begin
    if rvtf.instance_ref()===RVTVoidId
      let param_map = rvtf.family_map,
          params = keys(param_map)
        rvtf.instance_ref(
            @remote(b, FamilyElement(
                0,
                collect(keys),
                [param_map[param](f) for param in params])))
      end
    end
    rvtf.instance_ref()
  end

struct RevitFileFamily <: RevitFamily
    path::String
    family_map::Dict{String, Function}
    instance_map::Dict{String, Function}
    family_ref::Parameter{RVTId}
    instance_ref::Parameter{RVTId}
end

revit_file_family(path, family_map=(), instance_map=()) =
    RevitFileFamily(
        path,
        Dict(family_map...),
        Dict(instance_map...),
        Parameter(RVTVoidId),
        Parameter(RVTVoidId))

backend_get_family_ref(b::RVT, f::Family, rvtf::RevitFileFamily) =
  begin
    if true #rvtf.family_ref()===RVTVoidId
      rvtf.family_ref(@remote(b, LoadFamily(rvtf.path)))
    end
    if true #rvtf.instance_ref()===RVTVoidId
      let param_map = rvtf.family_map,
          params = keys(param_map)
        rvtf.instance_ref(
            @remote(b, FamilyElement(
                rvtf.family_ref(),
                collect(params),
                [param_map[param](f) for param in params])))
      end
    end
    rvtf.instance_ref()
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

realize(b::RVT, s::EmptyShape) =
  RVTEmptyRef()
realize(b::RVT, s::UniversalShape) =
  RVTUniversalRef()


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
  begin
    @remote(b, CreatePolygonalFloor(convert(ClosedPolygonalPath, contour).vertices, ref(b, level).value))
    # we are not using the family yet
    # ref(b, s.family))
  end

create_slab_opening(b::RVT, contour::ClosedPolygonalPath, slab_r) =
  @remote(b, CreatePolygonalOpening(convert(ClosedPolygonalPath, contour).vertices, slab_r))

create_slab_opening(b::RVT, contour::ClosedPath, slab_r) =
  let (locs, arcs) = locs_and_arcs(contour)
    @remote(b, CreatePathOpening(locs, arcs, slab_r))
  end

locs_and_arcs(arc::ArcPath) =
    ([arc.center + vpol(arc.radius, arc.start_angle)],
     [arc.amplitude])

locs_and_arcs(circle::CircularPath) =
    let (locs1, arcs1) = locs_and_arcs(arc_path(circle.center, circle.radius, 0, pi))
        (locs2, arcs2) = locs_and_arcs(arc_path(circle.center, circle.radius, pi, pi))
        ([locs1..., locs2...], [arcs1..., arcs2...])
    end

KhepriBase.b_slab(b::RVT, contour::ClosedPath, level, family) =
  let (locs, arcs) = locs_and_arcs(contour)
    @remote(b, CreatePathFloor(locs, arcs, ref(b, level).value))
    # we are not using the family yet
    # ref(b, s.family))
  end

KhepriBase.b_roof(b::RVT, contour::ClosedPath, level, family) =
  let (locs, arcs) = locs_and_arcs(contour)
    @remote(b, CreatePathRoof(locs, arcs, ref(b, level).value, family))
  end

#Beams are aligned along the top axis.
KhepriBase.b_beam(b::RVT, c, h, angle, family) =
  @remote(b, CreateBeam(c, add_z(c, h), angle, realize(b, family)))

KhepriBase.b_column(b::RVT, cb, angle, bottom_level, top_level, family) =
  @remote(b, CreateColumn(cb, realize(b, bottom_level), realize(b, top_level), realize(b, family)))

#Columns are aligned along the center axis.
KhepriBase.b_free_column(b::RVT, cb, h, angle, family) =
  let ct = in_world(add_z(cb, h)),
      cb = in_world(cb),
      lb = @remote(b, FindOrCreateLevelAtElevation(cb.z)),
      lt = @remote(b, FindOrCreateLevelAtElevation(ct.z))
    @remote(b, CreateColumnPoints(cb, ct, lb, lt, realize(b, family)))
  end

KhepriBase.realize_wall_no_openings(b::RVT, s::Wall) =
  # Revit also considers unconnected walls. These have a top level with id -1
  if ref(b, s.top_level).value == RVTVoidId
      @remote(b, CreateUnconnectedLineWall(
          convert(OpenPolygonalPath, s.path).vertices,
          ref(b, s.bottom_level).value,
          s.top_level.height - s.bottom_level.height,
          realize(b, s.family)))
  else
      @remote(b, CreateLineWall(
          convert(OpenPolygonalPath, s.path).vertices,
          ref(b, s.bottom_level).value,
          ref(b, s.top_level).value,
          realize(b, s.family)))
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
      params = keys(param_map)
    @remote(b, InsertWindow(
        s.loc.x,
        s.loc.y,
        ref(b, s.wall).value,
        backend_get_family_ref(b, s.family, rvtf),
        collect(params),
        [param_map[param](s.family) for param in params]))
  end

backend_add_door(b::RVT, w::Wall, loc::Loc, family::DoorFamily) = finish_this()
backend_add_window(b::RVT, w::Wall, loc::Loc, family::WindowFamily) =
    let d = window(w, loc, family=family)
        push!(w.windows, d)
        if realized(w) && ! realized(d)
            realize(b, d)
        end
        w
    end

realize(b::RVT, s::TrussNode) =
  @remote(b, CreateBeam(s.p, add_x(s.p, 0.1), 0, realize(b, s.family)))

realize(b::RVT, s::TrussBar) =
  @remote(b, CreateBeam(s.p0, s.p1, s.angle, realize(b, s.family)))

############################################
# Select New Family ...
# Choose Metric Generic Model


# Revit does not use materials!
KhepriBase.material_ref(b::RVT, m::Material) = nothing


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

#
unite_ref(b::RVT, r0::RVTNativeRef, r1::RVTNativeRef) =
    ensure_ref(b, @remote(b, Union(r0.value, r1.value)))

intersect_ref(b::RVT, r0::RVTNativeRef, r1::RVTNativeRef) =
    ensure_ref(b, @remote(b, Intersection(r0.value, r1.value)))

subtract_ref(b::RVT, r0::RVTNativeRef, r1::RVTNativeRef) =
    ensure_ref(b, @remote(b, Subtraction(r0.value, r1.value)))

unite_refs(b::RVT, refs::Vector{<:RVTRef}) =
    RVTUnionRef(tuple(refs...))

realize(b::RVT, s::IntersectionShape) =
  let r = foldl((r0,r1)->intersect_ref(b,r0,r1), map(ref, s.shapes),
                init=RVTUniversalRef())
    mark_deleted(s.shapes)
    r
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
  @remote(b, SetView(camera, target, lens))

KhepriBase.b_get_view(b::RVT) =
  @remote(b, ViewCamera()), @remote(b, ViewTarget()), @remote(b, ViewLens(c))

zoom_extents(b::RVT) = @remote(b, ZoomExtents())

view_top(b::RVT) =
    @remote(b, ViewTop())

KhepriBase.b_delete_all_refs(b::RVT) =
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
        backend=b, ref=LazyRef(b, RVTNativeRef(r)))

unconnected_level(h::Real, b::RVT) =
    level(h, backend=b, ref=LazyRef(b, RVTNativeRef(RVTVoidId)))

all_Elements(b::RVT) =
    [element_from_ref(r, b) for r in @remote(b, DocElements())]

all_walls(b::RVT) =
    [wall_from_ref(r, b) for r in @remote(b, DocWalls())]
all_walls_at_level(level::Level, b::RVT) =
    [wall_from_ref(r, b) for r in @remote(b, DocWallsAtLevel(ref(level).value))]

wall_from_ref(r, b::RVT) =
    begin
        path = convert(Path, @remote(b, LineWallVertices(r)))
        bottom_level_id = @remote(b, ElementLevel(r))
        top_level_id = @remote(b, WallTopLevel(r))
        bottom_level = level_from_ref(bottom_level_id, b)
        top_level = top_level_id == RVTVoidId ?
                        unconnected_level(bottom_level.height + @remote(b, WallHeight(r)), b) :
                        level_from_ref(top_level_id, b)
        wall(path,
             bottom_level=bottom_level,
             top_level=top_level,
             backend=b,
             ref=LazyRef(b, RVTNativeRef(r)))
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

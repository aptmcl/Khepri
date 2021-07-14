export autocad

#=
We need to ensure the AutoCAD plugin is properly installed.
For AutoCAD, there are a few places where plugins can be installed:

A plug-in can be deployed by placing it in one of the ApplicationPlugins or ApplicationAddins folders on a local drive.

General Installation folder
%PROGRAMFILES%\Autodesk\ApplicationPlugins
All Users Profile folders
%ALLUSERSPROFILE%\Autodesk\ApplicationPlugins
User Profile folders
%APPDATA%\Autodesk\ApplicationPlugins

When the SECURELOAD system variable is set to 1 or 2,
the program is restricted to loading and executing files that contain code from trusted locations;
trusted locations are specified by the TRUSTEDPATHS system variable.

=#


# This only needs to be done when the AutoCAD plugin is updated

julia_khepri = dirname(dirname(abspath(@__FILE__)))

upgrade_plugin(; advance_major_version=false, advance_minor_version=true, phase="Debug") =
  let # 1. The dlls are updated in VisualStudio after compilation of the plugin, and they are stored in the folder.
      dlls = ["KhepriBase.dll", "KhepriAutoCAD.dll"]
      # 2. Depending on whether we are in Debug mode or Release mode,
      development_phase = phase # "Release"
      # 3. the dlls are located in a folder
      dlls_folder = joinpath("bin", "x64", development_phase)
      # 4. contained inside the Plugins folder, which has a specific location regarding this file itself
      plugin_folder = joinpath(dirname(dirname(dirname(dirname(abspath(@__FILE__))))), "Plugins", "KhepriAutoCAD", "KhepriAutoCAD")
      # 5. Besides the dlls, we also need the bundle folder
      bundle_name = "Khepri.bundle"
      bundle_dll_folder = joinpath(bundle_name, "Contents")
      # 6. which is contained in the Plugins folder
      bundle_path = joinpath(plugin_folder, bundle_name)
      # 11. Update major or minor version
      if advance_major_version || advance_minor_version
          bundle_xml = joinpath(bundle_path, "PackageContents.xml")
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
      for dll in dlls
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

dlls = ["KhepriBase.dll", "KhepriAutoCAD.dll"]
bundle_name = "Khepri.bundle"
bundle_dll_folder = joinpath(bundle_name, "Contents")
xml_name = "PackageContents.xml"
bundle_xml = joinpath(bundle_name, xml_name)
local_plugins = joinpath(dirname(dirname(abspath(@__FILE__))), "Plugin")
local_khepri_plugin = joinpath(local_plugins, bundle_name)
local_khepri_plugin_dll_folder = joinpath(local_plugins, bundle_dll_folder)

env(name) = Sys.iswindows() ? ENV[name] : ""

autocad_general_plugins = joinpath(dirname(env("CommonProgramFiles")), "Autodesk", "ApplicationPlugins")
autocad_allusers_plugins = joinpath(env("ALLUSERSPROFILE"), "Autodesk", "ApplicationPlugins")
autocad_user_plugins = joinpath(env("APPDATA"), "Autodesk", "ApplicationPlugins")
autocad_khepri_plugin = joinpath(autocad_user_plugins, bundle_name)
autocad_khepri_plugin_dll_folder = joinpath(autocad_user_plugins, bundle_dll_folder)

autocad_version(path) =
  let doc = readxml(path),
      app_pkg = findfirst("//ApplicationPackage", doc)
    VersionNumber(map(s -> parse(Int, s), split(app_pkg["AppVersion"], '.'))...)
  end

update_plugin() =
  let local_path_xml = joinpath(local_khepri_plugin, xml_name)
      autocad_path_xml = joinpath(autocad_khepri_plugin, xml_name)
    # Do we have the bundle folder?
    isdir(autocad_khepri_plugin) || mkpath(autocad_khepri_plugin)
    isdir(autocad_khepri_plugin_dll_folder) || mkpath(autocad_khepri_plugin_dll_folder)
    # Must we upgrade?
    need_upgrade = ! isfile(autocad_path_xml) || autocad_version(autocad_path_xml) < autocad_version(local_path_xml)
    if need_upgrade
      # remove first to avoid loosing the local file
      #isfile(autocad_path_xml) && rm(autocad_path_xml)
      cp(local_path_xml, autocad_path_xml, force=true)
      for dll in dlls
        let path = joinpath("Contents", dll),
            local_path = joinpath(local_khepri_plugin, path),
            autocad_path = joinpath(autocad_khepri_plugin, path)
            # remove first to avoid loosing the local file
            #isfile(autocad_path_xml) && rm(autocad_path_xml)
            cp(local_path, autocad_path, force=true)
        end
      end
    end
  end

checked_plugin = false

check_plugin() =
  begin
    global checked_plugin
    if ! checked_plugin
      @info("Checking AutoCAD plugin...")
      for i in 1:10
        try
          update_plugin()
          @info("done.")
          checked_plugin = true
          return
        catch exc
          if isa(exc, Base.IOError) && i < 10
            @error("The AutoCAD plugin is outdated! Please, close AutoCAD.")
            sleep(5)
          else
            throw(exc)
          end
        end
      end
    end
  end

#
const autocad_template = Parameter(abspath(@__DIR__, "../Plugin/KhepriTemplate.dwt"))

start_autocad() =
  run(`cmd /c cd "$(dirname(autocad_template()))" \&\& $(basename(autocad_template()))`, wait=false)




# ACAD is a subtype of CS
parse_signature(::Val{:ACAD}, sig::T) where {T} = parse_signature(Val(:CS), sig)
encode(::Val{:ACAD}, t::Val{T}, c::IO, v) where {T} = encode(Val(:CS), t, c, v)
decode(::Val{:ACAD}, t::Val{T}, c::IO) where {T} = decode(Val(:CS), t, c)

# We need some additional Encoders
@encode_decode_as(:ACAD, Val{:Entity}, Val{:address})
@encode_decode_as(:ACAD, Val{:ObjectId}, Val{:address})
@encode_decode_as(:ACAD, Val{:BIMLevel}, Val{:size})
@encode_decode_as(:ACAD, Val{:FloorFamily}, Val{:size})
@encode_decode_as(:ACAD, Val{:Material}, Val{:long})

encode(::Val{:ACAD}, ::Union{Val{:Point3d},Val{:Vector3d}}, c::IO, p) =
  encode(Val(:CS), Val(:double3), c, raw_point(p))
decode(::Val{:ACAD}, ::Val{:Point3d}, c::IO) =
  xyz(decode(Val(:CS), Val(:double3), c)..., world_cs)
decode(::Val{:ACAD}, ::Val{:Vector3d}, c::IO) =
  vxyz(decode(Val(:CS), Val(:double3), c)..., world_cs)

encode(ns::Val{:ACAD}, ::Val{:Frame3d}, c::IO, v) = begin
  encode(ns, Val(:Point3d), c, v)
  t = v.cs.transform
  encode(Val(:CS), Val(:double3), c, (t[1,1], t[2,1], t[3,1]))
  encode(Val(:CS), Val(:double3), c, (t[1,2], t[2,2], t[3,2]))
  encode(Val(:CS), Val(:double3), c, (t[1,3], t[2,3], t[3,3]))
end

decode(ns::Val{:ACAD}, ::Val{:Frame3d}, c::IO) =
  u0(cs_from_o_vx_vy_vz(
      decode(ns, Val(:Point3d), c),
      decode(ns, Val(:Vector3d), c),
      decode(ns, Val(:Vector3d), c),
      decode(ns, Val(:Vector3d), c)))

# AutoCAD's colors do not support the alpha channel
encode(ns::Val{:ACAD}, ::Val{:Color}, c::IO, v) =
  begin
    encode(ns, Val(:byte), c, floor(UInt8, v.r*255))
    encode(ns, Val(:byte), c, floor(UInt8, v.g*255))
    encode(ns, Val(:byte), c, floor(UInt8, v.b*255))
  end
decode(ns::Val{:ACAD}, ::Val{:Color}, c::IO) =
  let r = decode(ns, Val(:byte), c),
      g = decode(ns, Val(:byte), c),
      b = decode(ns, Val(:byte), c)
    RGB(r/255, g/255, b/255)
  end


acad_api = @remote_functions :ACAD """
public Entity QuadStrip(Point3d[] bpts, Point3d[] tpts, int smoothLevel, ObjectId matId)
public Entity ClosedQuadStrip(Point3d[] bpts, Point3d[] tpts, int smoothLevel, ObjectId matId)
public Entity Mesh(Point3d[] pts, int[][] faces, int smoothLevel, ObjectId matId)
public Entity NGon(Point3d[] pts, Point3d pivot, int smoothLevel, ObjectId matId)
public Entity SurfacePolygon(Point3d[] pts, ObjectId matId)
public Entity SurfacePolygonWithHoles(Point3d[] outer, Point3d[][] inners, ObjectId matId)
public Entity RegionWithHoles(Point3d[][] ptss, bool[] smooths, ObjectId matId)
public Entity PrismWithHoles(Point3d[][] ptss, bool[] smooths, Vector3d dir, ObjectId matId)
public void SetLengthUnit(String unit)
public void SetView(Point3d position, Point3d target, double lens, bool perspective, string style)
public void View(Point3d position, Point3d target, double lens)
public void ViewTop()
public Point3d ViewCamera()
public Point3d ViewTarget()
public double ViewLens()
public ObjectId GetMaterialNamed(String Name)
public ObjectId CreateMaterialNamed(String name, String textureMapPath, double uScale, double vScale, double uOffset, double vOffset, int projection, int uTiling, int vTiling, Color diffuseColor, double refractionIndex, double opacity, double reflectivity, double translucence, int illuminationModel)
public ObjectId CreateColoredMaterialNamed(String name, Color color, double reflectivity, double translucence)
public void SetSkyFromDateLocation(DateTime date, double latitude, double longitude, double meridian, double elevation)
public byte Sync()
public byte Disconnect()
public ObjectId Copy(ObjectId id)
public Entity Point(Point3d p)
public Point3d PointPosition(Entity ent)
public Entity PolyLine(Point3d[] pts)
public Point3d[] LineVertices(ObjectId id)
public Entity Spline(Point3d[] pts)
public Entity InterpSpline(Point3d[] pts, Vector3d tan0, Vector3d tan1)
public Entity ClosedPolyLine(Point3d[] pts)
public Entity ClosedSpline(Point3d[] pts)
public Entity InterpClosedSpline(Point3d[] pts)
public Point3d[] SplineInterpPoints(Entity ent)
public Vector3d[] SplineTangents(Entity ent)
public Entity Circle(Point3d c, Vector3d n, double r)
public Point3d CircleCenter(Entity ent)
public Vector3d CircleNormal(Entity ent)
public double CircleRadius(Entity ent)
public Entity Ellipse(Point3d c, Vector3d n, Vector3d majorAxis, double radiusRatio)
public Entity Arc(Point3d c, Vector3d n, double radius, double startAngle, double endAngle)
public Point3d ArcCenter(Entity ent)
public Vector3d ArcNormal(Entity ent)
public double ArcRadius(Entity ent)
public double ArcStartAngle(Entity ent)
public double ArcEndAngle(Entity ent)
public ObjectId JoinCurves(ObjectId[] ids)
public Entity Text(string str, Point3d corner, Vector3d vx, Vector3d vy, double height)
public Entity SurfaceFromCurve(Entity curve, ObjectId matId)
public Entity SurfaceCircle(Point3d c, Vector3d n, double r, ObjectId matId)
public Entity SurfaceEllipse(Point3d c, Vector3d n, Vector3d majorAxis, double radiusRatio, ObjectId matId)
public Entity SurfaceArc(Point3d c, Vector3d n, double radius, double startAngle, double endAngle, ObjectId matId)
public Entity SurfaceClosedPolyLine(Point3d[] pts, ObjectId matId)
public ObjectId[] SurfaceFromCurves(ObjectId[] ids, ObjectId matId)
public ObjectId[] CurvesFromSurface(ObjectId id)
public Entity Sphere(Point3d c, double r, ObjectId mat)
public Entity Torus(Point3d c, Vector3d vz, double majorRadius, double minorRadius, ObjectId matId)
public Entity ConeFrustum(Point3d bottom, double base_radius, Point3d top, double top_radius, ObjectId matId)
public Entity Cylinder(Point3d bottom, double radius, Point3d top, ObjectId matId)
public Entity Cone(Point3d bottom, double radius, Point3d top, ObjectId matId)
public Entity Box(Frame3d frame, double dx, double dy, double dz, ObjectId matId)
public Entity CenteredBox(Frame3d frame, double dx, double dy, double dz, ObjectId matId)
public ObjectId IrregularPyramid(Point3d[] pts, Point3d apex, ObjectId matId)
public ObjectId IrregularPyramidFrustum(Point3d[] bpts, Point3d[] tpts, ObjectId matId)
public ObjectId Thicken(ObjectId obj, double thickness)
public ObjectId NurbSurfaceFrom(ObjectId id)
public ObjectId Extrude(ObjectId profileId, Vector3d dir)
public ObjectId Sweep(ObjectId pathId, ObjectId profileId, double rotation, double scale)
public ObjectId Loft(ObjectId[] profilesIds, ObjectId[] guidesIds, bool ruled, bool closed)
public ObjectId Unite(ObjectId objId0, ObjectId objId1)
public ObjectId Intersect(ObjectId objId0, ObjectId objId1)
public ObjectId Subtract(ObjectId objId0, ObjectId objId1)
public void Slice(ObjectId id, Point3d p, Vector3d n)
public ObjectId Revolve(ObjectId profileId, Point3d p, Vector3d n, double startAngle, double amplitude)
public void Transform(ObjectId id, Frame3d frame)
public void Move(ObjectId id, Vector3d v)
public void Scale(ObjectId id, Point3d p, double s)
public void Rotate(ObjectId id, Point3d p, Vector3d n, double a)
public ObjectId Mirror(ObjectId id, Point3d p, Vector3d n, bool copy)
public Point3d[] BoundingBox(ObjectId[] ids)
public void ZoomExtents()
public ObjectId CreateLayer(string name, bool active, byte r, byte g, byte b)
public void SetLayerColor(ObjectId id, byte r, byte g, byte b)
public void SetShapeColor(ObjectId id, byte r, byte g, byte b)
public ObjectId CurrentLayer()
public void SetCurrentLayer(ObjectId id)
public ObjectId ShapeLayer(ObjectId objId)
public void SetShapeLayer(ObjectId objId, ObjectId layerId)
public void SetSystemVariableInt(string name, int value)
public int Command(string cmd)
public void DisableUpdate()
public void EnableUpdate()
public bool IsPoint(Entity e)
public bool IsCircle(Entity e)
public bool IsPolyLine(Entity e)
public bool IsSpline(Entity e)
public bool IsInterpSpline(Entity e)
public bool IsClosedPolyLine(Entity e)
public bool IsClosedSpline(Entity e)
public bool IsInterpClosedSpline(Entity e)
public bool IsEllipse(Entity e)
public bool IsArc(Entity e)
public bool IsText(Entity e)
public byte ShapeCode(ObjectId id)
public BIMLevel FindOrCreateLevelAtElevation(double elevation)
public BIMLevel UpperLevel(BIMLevel currentLevel, double addedElevation)
public double GetLevelElevation(BIMLevel level)
public FloorFamily FloorFamilyInstance(double totalThickness, double coatingThickness)
public Entity LightweightPolyLine(Point2d[] pts, double[] angles, double elevation)
public Entity SurfaceLightweightPolyLine(Point2d[] pts, double[] angles, double elevation)
public ObjectId CreatePathFloor(Point2d[] pts, double[] angles, BIMLevel level, FloorFamily family)
public ObjectId CreateBlockFromShapes(String baseName, ObjectId[] ids)
public ObjectId CreateBlockInstance(ObjectId id, Frame3d frame)
public ObjectId CreateInstanceFromBlockNamed(String name, Frame3d frame)
public ObjectId CreateInstanceFromBlockNamedAtRotated(String name, Point3d c, double angle)
public ObjectId CreateRectangularTableFamily(double length, double width, double height, double top_thickness, double leg_thickness)
public ObjectId Table(Point3d c, double angle, ObjectId family)
public ObjectId CreateChairFamily(double length, double width, double height, double seat_height, double thickness)
public ObjectId Chair(Point3d c, double angle, ObjectId family)
public ObjectId CreateRectangularTableAndChairsFamily(ObjectId tableFamily, ObjectId chairFamily, double tableLength, double tableWidth, int chairsOnTop, int chairsOnBottom, int chairsOnRight, int chairsOnLeft, double spacing)
public ObjectId TableAndChairs(Point3d c, double angle, ObjectId family)
public ObjectId CreateAlignedDimension(Point3d p0, Point3d p1, Point3d p, double scale, String mark)
public String TextString(Entity ent)
public Point3d TextPosition(Entity ent)
public double TextHeight(Entity ent)
public String MTextString(Entity ent)
public Point3d MTextPosition(Entity ent)
public double MTextHeight(Entity ent)
public void SaveAs(String pathname, String format)
public double[] CurveDomain(Entity ent)
public double CurveLength(Entity ent)
public Frame3d CurveFrameAt(Entity ent, double t)
public Frame3d CurveFrameAtLength(Entity ent, double l)
public Point3d[] CurvePointsAt(Entity ent, double[] ts)
public Vector3d[] CurveTangentsAt(Entity ent, double[] ts)
public Vector3d[] CurveNormalsAt(Entity ent, double[] ts)
public Vector3d RegionNormal(Entity ent)
public Point3d RegionCentroid(Entity ent)
public double[] SurfaceDomain(Entity ent)
public Frame3d SurfaceFrameAt(Entity ent, double u, double v)
public Entity MeshFromGrid(int m, int n, Point3d[] pts, bool closedM, bool closedN)
public int[] PolygonMeshData(Entity e)
public Point3dCollection MeshVertices(ObjectId id)
public Entity SurfaceFromGrid(int m, int n, Point3d[] pts, bool closedM, bool closedN, int level, ObjectId matId)
public Entity SolidFromGrid(int m, int n, Point3d[] pts, bool closedM, bool closedN, int level, double thickness, ObjectId matId)
public void DeleteAll()
public void DeleteAllInLayer(ObjectId layerId)
public void Delete(ObjectId id)
public void DeleteMany(ObjectId[] ids)
public Entity SpotLight(Point3d position, double hotspot, double falloff, Point3d target)
public Entity IESLight(String webFile, Point3d position, Point3d target, Vector3d rotation)
public Point3d[] GetPosition(string prompt)
public ObjectId[] GetPoint(string prompt)
public ObjectId[] GetPoints(string prompt)
public ObjectId[] GetCurve(string prompt)
public ObjectId[] GetCurves(string prompt)
public ObjectId[] GetSurface(string prompt)
public ObjectId[] GetSurfaces(string prompt)
public ObjectId[] GetSolid(string prompt)
public ObjectId[] GetSolids(string prompt)
public ObjectId[] GetShape(string prompt)
public ObjectId[] GetShapes(string prompt)
public ObjectId[] GetPreSelectedShapes()
public long GetHandleFromShape(Entity e)
public ObjectId GetShapeFromHandle(long h)
public void RegisterForChanges(ObjectId id)
public void UnregisterForChanges(ObjectId id)
public ObjectId[] ChangedShape()
public void DetectCancel()
public void UndetectCancel()
public bool WasCanceled()
public ObjectId[] GetAllShapes()
public ObjectId[] GetAllShapesInLayer(ObjectId layerId)
public void SelectShapes(ObjectId[] ids)
public void Render(int width, int height, string path, int levels, double exposure)
"""

abstract type ACADKey end
const ACADId = Int64
const ACADIds = Vector{ACADId}
const ACADRef = GenericRef{ACADKey, ACADId}
const ACADRefs = Vector{ACADRef}
const ACADEmptyRef = EmptyRef{ACADKey, ACADId}
const ACADUniversalRef = UniversalRef{ACADKey, ACADId}
const ACADNativeRef = NativeRef{ACADKey, ACADId}
const ACADUnionRef = UnionRef{ACADKey, ACADId}
const ACADSubtractionRef = SubtractionRef{ACADKey, ACADId}
const ACAD = SocketBackend{ACADKey, ACADId}

KhepriBase.before_connecting(b::ACAD) = check_plugin()
KhepriBase.after_connecting(b::ACAD) =
  begin
    set_material(autocad, material_metal, "Steel - Polished")
    set_material(autocad, material_glass, "Clear")
    set_material(autocad, material_wood, "Plywood - New")
    set_material(autocad, material_concrete, "Flat - Broom Gray")
    set_material(autocad, material_plaster, "Fine - White")
    set_material(autocad, material_grass, "Green")
  end

const autocad = ACAD("AutoCAD", autocad_port, acad_api)

KhepriBase.void_ref(b::ACAD) =
  ACADNativeRef(-1)

# Primitives
KhepriBase.b_point(b::ACAD, p) =
  @remote(b, Point(p))

KhepriBase.b_line(b::ACAD, ps, mat) =
  @remote(b, PolyLine(ps))

KhepriBase.b_polygon(b::ACAD, ps, mat) =
  @remote(b, ClosedPolyLine(ps))

KhepriBase.b_spline(b::ACAD, ps, v0, v1, interpolator, mat) =
  if (v0 == false) && (v1 == false)
    #@remote(b, Spline(s.points))
    @remote(b, InterpSpline(
                     ps,
                     ps[2]-ps[1],
                     ps[end]-ps[end-1]))
  elseif (v0 != false) && (v1 != false)
    @remote(b, InterpSpline(ps, v0, v1))
  else
    @remote(b, InterpSpline(
                     ps,
                     v0 == false ? ps[2]-ps[1] : v0,
                     v1 == false ? ps[end-1]-ps[end] : v1))
  end

KhepriBase.b_closed_spline(b::ACAD, ps, mat) =
  @remote(b, InterpClosedSpline(ps))

KhepriBase.b_circle(b::ACAD, c, r, mat) =
  @remote(b, Circle(c, vz(1, c.cs), r))

KhepriBase.b_arc(b::ACAD, c, r, α, Δα, mat) =
  if r == 0
    @remote(b, Point(c))
  elseif Δα == 0
    @remote(b, Point(c + vpol(r, α, c.cs)))
  elseif abs(Δα) >= 2*pi
    @remote(b, Circle(c, vz(1, c.cs), r))
  else
	  let β = α + amplitude
  	  if β > α
  	  	@remote(b, Arc(c, vx(1, c.cs), vy(1, c.cs), r, α, β))
  	  else
  	  	@remote(b, Arc(c, vx(1, c.cs), vy(1, c.cs), r, β, α))
  	  end
    end
  end

b_ellipse() =
  @remote(b, Ellipse(center, vz(1, center.cs), radius_x, radius_y))

KhepriBase.b_trig(b::ACAD, p1, p2, p3, mat) =
  @remote(b, Mesh([p1, p2, p3], [[0, 1, 2, 2]], 0, mat))

KhepriBase.b_quad(b::ACAD, p1, p2, p3, p4, mat) =
	@remote(b, Mesh([p1, p2, p3, p4], [[0, 1, 2, 3]], 0, mat))

KhepriBase.b_ngon(b::ACAD, ps, pivot, smooth, mat) =
	@remote(b, NGon(ps, pivot, smooth ? 3 : 0, mat))

KhepriBase.b_quad_strip(b::ACAD, ps, qs, smooth, mat) =
  @remote(b, QuadStrip(ps, qs, smooth ? 3 : 0, mat))

KhepriBase.b_quad_strip_closed(b::ACAD, ps, qs, smooth, mat) =
  @remote(b, ClosedQuadStrip(ps, qs, smooth ? 3 : 0, mat))

KhepriBase.b_surface_polygon(b::ACAD, ps, mat) =
  #@remote(b, SurfacePolygon(ps, mat)) because it cretes BSubMesh and we prefer Regions
  @remote(b, SurfaceClosedPolyLine(ps, mat))

KhepriBase.b_surface_polygon_with_holes(b::ACAD, ps, qss, mat) =
  @remote(b, RegionWithHoles([ps, qss...], falses(1 + length(qss)), mat))

KhepriBase.b_surface_closed_spline(b::ACAD, ps, mat) =
  @remote(b, SurfaceFromCurves([@remote(b, InterpClosedSpline(path.vertices))]))

KhepriBase.b_surface_circle(b::ACAD, c, r, mat) =
  @remote(b, SurfaceCircle(c, vz(1, c.cs), r, mat))

KhepriBase.b_surface_arc(b::ACAD, c, r, α, Δα, mat) =
    if r == 0
        @remote(b, Point(c))
    elseif Δα == 0
        @remote(b, Point(c + vpol(r, α, c.cs)))
    elseif abs(Δα) >= 2*pi
        @remote(b, SurfaceCircle(c, vz(1, c.cs), r))
    else
        β = α + Δα
        if β > α
            @remote(b, SurfaceFromCurves(
                [@remote(b, Arc(c, vz(1, c.cs), r, α, β)),
                 @remote(b, PolyLine([add_pol(c, r, β), add_pol(c, r, α)]))]))
        else
            @remote(b, SurfaceFromCurves(
                [@remote(b, Arc(c, vz(1, c.cs), r, β, α)),
                 @remote(b, PolyLine([add_pol(c, r, α), add_pol(c, r, β)]))]))
        end
    end

realize(b::ACAD, s::SurfaceEllipse) =
  if s.radius_x > s.radius_y
    @remote(b, SurfaceEllipse(s.center, vz(1, s.center.cs), vxyz(s.radius_x, 0, 0, s.center.cs), s.radius_y/s.radius_x))
  else
    @remote(b, SurfaceEllipse(s.center, vz(1, s.center.cs), vxyz(0, s.radius_y, 0, s.center.cs), s.radius_x/s.radius_y))
  end

KhepriBase.b_generic_prism(b::ACAD, bs, smooth, v, bmat, tmat, smat) =
  @remote(b, PrismWithHoles([bs], [smooth], v, tmat))

KhepriBase.b_generic_prism_with_holes(b::ACAD, bs, smooth, bss, smooths, v, bmat, tmat, smat) =
  @remote(b, PrismWithHoles([bs, bss...], [smooth, smooths...], v, tmat))

KhepriBase.b_pyramid_frustum(b::ACAD, bs, ts, bmat, tmat, smat) =
  @remote(b, IrregularPyramidFrustum(bs, ts, smat))

KhepriBase.b_pyramid(b::ACAD, bs, t, bmat, smat) =
  @remote(b, IrregularPyramid(bs, t, smat))

KhepriBase.b_cylinder(b::ACAD, cb, r, h, bmat, tmat, smat) =
  @remote(b, Cylinder(cb, r, add_z(cb, h), smat))

KhepriBase.b_box(b::ACAD, c, dx, dy, dz, mat) =
  @remote(b, Box(c, dx, dy, dz, mat))

KhepriBase.b_sphere(b::ACAD, c, r, mat) =
  @remote(b, Sphere(c, r, mat))

KhepriBase.b_cone(b::ACAD, cb, r, h, bmat, smat) =
  @remote(b, Cone(add_z(cb, h), r, cb, smat))

KhepriBase.b_cone_frustum(b::ACAD, cb, rb, h, rt, bmat, tmat, smat) =
  @remote(b, ConeFrustum(cb, rb, cb + vz(h, cb.cs), rt, smat))

KhepriBase.b_torus(b::ACAD, c, ra, rb, mat) =
  @remote(b, Torus(c, vz(1, c.cs), ra, rb, mat))

# Materials

KhepriBase.b_get_material(b::ACAD, ref) =
  get_autocad_material(b, ref)

get_autocad_material(b, ref::Nothing) =
  void_ref(b)

get_autocad_material(b, ref::AbstractString) =
  @remote(b, GetMaterialNamed(ref))

KhepriBase.b_new_material(b::ACAD, path, color, specularity, roughness, transmissivity, transmitted_specular) =
  @remote(b, CreateColoredMaterialNamed(path, color, specularity, transmissivity))

const MaterialProjection = (InheritProjection=0, Planar=1, Box=2, Cylinder=3, Sphere=4)
const MaterialTiling = (InheritTiling=0, Tile=1, Crop=2, Clamp=3, Mirror=4)
const MaterialIlluminationModel = (BlinnShader=0, MetalShader=1)

Base.@kwdef struct AutoCADBasicMaterial
  name::String
  u_scale::Float64=1.0
  v_scale::Float64=1.0
  u_offset::Float64=0.0
  v_offset::Float64=0.0
  projection::Int=MaterialProjection.Box
  u_tiling::Int=MaterialTiling.Tile
  v_tiling::Int=MaterialTiling.Tile
  diffuse_color::RGB=rgb(1,0,0)
  diffuse_blend::Float64=1.0
  diffuse_blend_map_source::String=""
  blend_color::RGB=rgb(1,0,0)
  blend_blend::Float64=1.0
  blend_blend_map_source::String=""
  refraction_index::Float64=2.0
  opacity::Float64=0.1
  reflectivity::Float64=0.5
  translucence::Float64=0.0
  illumination_model::Int=MaterialIlluminationModel.BlinnShader
end

export autocad_basic_material
autocad_basic_material = AutoCADBasicMaterial

get_autocad_material(b, m::AutoCADBasicMaterial) =
  @remote(b, CreateMaterialNamed(
    m.name,
    m.texture_path,
    m.u_scale,
    m.v_scale,
    m.u_offset,
    m.v_offset,
    m.projection,
    m.u_tiling,
    m.v_tiling,
    m.diffuse_color,
    m.diffuse_map_source,
    m.bump_map_source,
    m.refraction_index,
    m.opacity,
    m.reflectivity,
    m.translucence,
    m.illumination_model))

#=

Default families

=#

abstract type ACADFamily <: Family end

struct ACADLayerFamily <: ACADFamily
  name::String
  color::RGB
  ref::Parameter{Any}
end

acad_layer_family(name, color::RGB=rgb(1,1,1)) =
  ACADLayerFamily(name, color, Parameter{Any}(nothing))

backend_get_family_ref(b::ACAD, f::Family, af::ACADLayerFamily) =
  backend_create_layer(b, af.name, true, af.color)

backend_fill_curves(b::ACAD, refs::ACADIds) = @remote(b, SurfaceFromCurves(refs))
backend_fill_curves(b::ACAD, ref::ACADId) = @remote(b, SurfaceFromCurves([ref]))
backend_stroke_unite(b::ACAD, refs) = @remote(b, JoinCurves(refs))

realize(b::ACAD, s::EmptyShape) =
  ACADEmptyRef()
realize(b::ACAD, s::UniversalShape) =
  ACADUniversalRef()

realize(b::ACAD, s::Ellipse) =
  if s.radius_x > s.radius_y
    @remote(b, Ellipse(s.center, vz(1, s.center.cs), vxyz(s.radius_x, 0, 0, s.center.cs), s.radius_y/s.radius_x))
  else
    @remote(b, Ellipse(s.center, vz(1, s.center.cs), vxyz(0, s.radius_y, 0, s.center.cs), s.radius_x/s.radius_y))
  end
realize(b::ACAD, s::EllipticArc) =
  error("Finish this")

realize(b::ACAD, s::Surface) =
  let #ids = map(r->@remote(b, NurbSurfaceFrom(r)), @remote(b, SurfaceFromCurves(collect_ref(s.frontier))))
      ids = @remote(b, SurfaceFromCurves(collect_ref(s.frontier)))
    foreach(mark_deleted, s.frontier)
    ids
  end
backend_surface_boundary(b::ACAD, s::Shape2D) =
    map(c -> backend_shape_from_ref(b, r), @remote(b, CurvesFromSurface(ref(s).value)))

# Iterating over curves and surfaces


old_backend_map_division(b::ACAD, f::Function, s::Shape1D, n::Int) =
  let r = ref(s).value,
      (t1, t2) = @remote(b, CurveDomain(r))
    map_division(t1, t2, n) do t
      f(@remote(b, CurveFrameAt(r, t)))
    end
  end

# For low level access:

backend_map_division(b::ACAD, f::Function, s::Shape1D, n::Int) =
  let r = ref(s).value,
      (t1, t2) = @remote(b, CurveDomain(r)),
      ti = division(t1, t2, n),
      ps = @remote(b, CurvePointsAt(r, ti)),
      ts = @remote(b, CurveTangentsAt(r, ti)),
      #ns = @remote(b, CurveNormalsAt(r, ti)),
      frames = rotation_minimizing_frames(@remote(b, CurveFrameAt(r, t1)), ps, ts)
    map(f, frames)
  end

#=
rotation_minimizing_frames(u0, xs, ts) =
  let ri = in_world(vy(1, u0.cs)),
      new_frames = [loc_from_o_vx_vy(xs[1], ri, cross(ts[1], ri))]
    for i in 1:length(xs)-1
      let xi = xs[i],
          xii = xs[i+1],
          ti = ts[i],
          tii = ts[i+1],
          v1 = xii - xi,
          c1 = dot(v1, v1),
          ril = ri - v1*(2/c1*dot(v1,ri)),
          til = ti - v1*(2/c1*dot(v1,ti)),
          v2 = tii - til,
          c2 = dot(v2, v2),
          rii = ril - v2*(2/c2*dot(v2, ril)),
          sii = cross(tii, rii),
          uii = loc_from_o_vx_vy(xii, rii, sii)
        push!(new_frames, uii)
        ri = rii
      end
    end
    new_frames
  end
=#

#


backend_surface_domain(b::ACAD, s::Shape2D) =
    tuple(@remote(b, SurfaceDomain(ref(s).value))...)

backend_map_division(b::ACAD, f::Function, s::Shape2D, nu::Int, nv::Int) =
    let conn = connection(b)
        r = ref(s).value
        (u1, u2, v1, v2) = @remote(b, SurfaceDomain(r))
        map_division(u1, u2, nu) do u
            map_division(v1, v2, nv) do v
                f(@remote(b, SurfaceFrameAt(r, u, v)))
            end
        end
    end

# The previous method cannot be applied to meshes in AutoCAD, which are created by surface_grid

backend_map_division(b::ACAD, f::Function, s::SurfaceGrid, nu::Int, nv::Int) =
let conn = connection(b)
    r = ref(s).value
    (u1, u2, v1, v2) = @remote(b, SurfaceDomain(r))
    map_division(u1, u2, nu) do u
        map_division(v1, v2, nv) do v
            f(@remote(b, SurfaceFrameAt(r, u, v)))
        end
    end
end

b_text(b::ACAD, str, p, size, mat) =
  @remote(b, Text(str, p, vx(1, p.cs), vy(1, p.cs), size))

backend_right_cuboid(b::ACAD, cb, width, height, h, material) =
  @remote(b, CenteredBox(cb, width, height, h))

backend_extrusion(b::ACAD, s::Shape, v::Vec) =
    and_mark_deleted(b,
        map_ref(s) do r
            @remote(b, Extrude(r, v))
        end,
        s)

backend_sweep(b::ACAD, path::Shape, profile::Shape, rotation::Real, scale::Real) =
  and_mark_deleted(b,
    map_ref(profile) do profile_r
      map_ref(path) do path_r
        @remote(b, Sweep(path_r, profile_r, rotation, scale))
      end
  end, [profile, path])

b_sweep(b::ACAD, path, profile, rotation, scale, mat) =
  and_mark_deleted(b,
    map_ref(profile) do profile_r
      map_ref(path) do path_r
        @remote(b, Sweep(path_r, profile_r, rotation, scale))
      end
  end, [profile, path])

backend_revolve_point(b::ACAD, profile::Shape, p::Loc, n::Vec, start_angle::Real, amplitude::Real) =
  realize(b, arc(loc_from_o_vz(p, n), distance(profile, p), start_angle, amplitude))
backend_revolve_curve(b::ACAD, profile::Shape, p::Loc, n::Vec, start_angle::Real, amplitude::Real) =
  acad_revolution(b, profile, p, n, start_angle, amplitude)
backend_revolve_surface(b::ACAD, profile::Shape, p::Loc, n::Vec, start_angle::Real, amplitude::Real) =
  acad_revolution(b, profile, p, n, start_angle, amplitude)

acad_revolution(b::ACAD, profile::Shape, p::Loc, n::Vec, start_angle::Real, amplitude::Real) =
  and_delete_shape(
    map_ref(profile) do r
      @remote(b, Revolve(r, p, n, start_angle, amplitude))
    end,
    profile)

backend_loft_curves(b::ACAD, profiles::Shapes, rails::Shapes, ruled::Bool, closed::Bool) =
  and_delete_shapes(@remote(b, Loft(
                             collect_ref(profiles),
                             collect_ref(rails),
                             ruled, closed)),
                    vcat(profiles, rails))

backend_loft_surfaces(b::ACAD, profiles::Shapes, rails::Shapes, ruled::Bool, closed::Bool) =
    backend_loft_curves(b, profiles, rails, ruled, closed)

backend_loft_curve_point(b::ACAD, profile::Shape, point::Shape) =
    and_delete_shapes(@remote(b, Loft(
                               vcat(collect_ref(profile), collect_ref(point)),
                               [],
                               true, false)),
                      [profile, point])

backend_loft_surface_point(b::ACAD, profile::Shape, point::Shape) =
    backend_loft_curve_point(b, profile, point)

unite_ref(b::ACAD, r0::ACADNativeRef, r1::ACADNativeRef) =
    ensure_ref(b, @remote(b, Unite(r0.value, r1.value)))

intersect_ref(b::ACAD, r0::ACADNativeRef, r1::ACADNativeRef) =
    ensure_ref(b, @remote(b, Intersect(r0.value, r1.value)))

subtract_ref(b::ACAD, r0::ACADNativeRef, r1::ACADNativeRef) =
    ensure_ref(b, @remote(b, Subtract(r0.value, r1.value)))

slice_ref(b::ACAD, r::ACADNativeRef, p::Loc, v::Vec) =
    (@remote(b, Slice(r.value, p, v)); r)

slice_ref(b::ACAD, r::ACADUnionRef, p::Loc, v::Vec) =
    ACADUnionRef(map(r->slice_ref(b, r, p, v), r.values))

unite_refs(b::ACAD, refs::Vector{<:ACADRef}) =
    ACADUnionRef(tuple(refs...))

realize(b::ACAD, s::IntersectionShape) =
  let r = foldl(intersect_ref(b), map(ref, s.shapes),
                init=ACADUniversalRef())
    mark_deleted(b, s.shapes)
    r
  end

realize(b::ACAD, s::Slice) =
  slice_ref(b, ref(s.shape), s.p, s.n)

realize(b::ACAD, s::Move) =
  let r = map_ref(b, s.shape) do r
            @remote(b, Move(r, s.v))
            r
          end
    mark_deleted(b, s.shape)
    r
  end

realize(b::ACAD, s::Transform) =
  let r = map_ref(b, s.shape) do r
            @remote(b, Transform(r, s.xform))
            r
          end
    mark_deleted(b, s.shape)
    r
  end

realize(b::ACAD, s::Scale) =
  let r = map_ref(b, s.shape) do r
            @remote(b, Scale(r, s.p, s.s))
            r
          end
    mark_deleted(b, s.shape)
    r
  end

realize(b::ACAD, s::Rotate) =
  let r = map_ref(b, s.shape) do r
            @remote(b, Rotate(r, s.p, s.v, s.angle))
            r
          end
    mark_deleted(b, s.shape)
    r
  end

realize(b::ACAD, s::Mirror) =
  and_mark_deleted(b, map_ref(s.shape) do r
                    @remote(b, Mirror(r, s.p, s.n, false))
                   end,
                   s.shape)

realize(b::ACAD, s::UnionMirror) =
  let r0 = ref(b, s.shape),
      r1 = map_ref(b, s.shape) do r
            @remote(b, Mirror(r, s.p, s.n, true))
          end
    UnionRef((r0,r1))
  end
#=
KhepriBase.b_surface_grid(b::ACAD, ptss, closed_u, closed_v, smooth_u, smooth_v, mat) =
  let (nu, nv) = size(ptss)
    smooth_u && smooth_v ?
      # Autocad does not allow us to distinguish smoothness along different dimensions
      @remote(b, SurfaceFromGrid(nv, nu, reshape(ptss,:), closed_v, closed_u, 2, mat)) :
      (smooth_u ?
        vcat([@remote(b, SurfaceFromGrid(nu, 2, reshape(permutedims(ptss[:,i:i+1]),:), closed_u, false, 2, mat))
              for i in 1:nv-1],
             closed_v ?
               [@remote(b, SurfaceFromGrid(nu, 2, reshape(permutedims(ptss[:,[end,1]]),:), closed_u, false, 2, mat))] :
               []) :
        (smooth_v ?
          vcat([@remote(b, SurfaceFromGrid(2, nv, reshape(permutedims(ptss[i:i+1,:]),:), false, closed_v, 2, mat))
                for i in 1:nu-1],
               closed_u ?
                 [@remote(b, SurfaceFromGrid(2, nv, reshape(permutedims(ptss[[end,1],:]),:), false, closed_v, 2, mat))] :
                 []) :
          @remote(b, SurfaceFromGrid(nu, nv, reshape(permutedims(ptss),:), closed_u, closed_v, 0, mat))))
  end
=#
KhepriBase.b_surface_grid(b::ACAD, ptss, closed_u, closed_v, smooth_u, smooth_v, mat) =
  let (nu, nv) = size(ptss)
    smooth_u && smooth_v ?
      # Autocad does not allow us to distinguish smoothness along different dimensions
      @remote(b, SurfaceFromGrid(nu, nv, reshape(permutedims(ptss),:), closed_u, closed_v, 2, mat)) :
      (smooth_u ?
        vcat([@remote(b, SurfaceFromGrid(nu, 2, reshape(permutedims(ptss[:,i:i+1]),:), closed_u, false, 2, mat))
              for i in 1:nv-1],
             closed_v ?
               [@remote(b, SurfaceFromGrid(nu, 2, reshape(permutedims(ptss[:,[end,1]]),:), closed_u, false, 2, mat))] :
               []) :
        (smooth_v ?
          vcat([@remote(b, SurfaceFromGrid(2, nv, reshape(permutedims(ptss[i:i+1,:]),:), false, closed_v, 2, mat))
                for i in 1:nu-1],
               closed_u ?
                 [@remote(b, SurfaceFromGrid(2, nv, reshape(permutedims(ptss[[end,1],:]),:), false, closed_v, 2, mat))] :
                 []) :
          @remote(b, SurfaceFromGrid(nu, nv, reshape(permutedims(ptss),:), closed_u, closed_v, 0, mat))))
  end

realize(b::ACAD, s::Thicken) =
  and_mark_deleted(b,
    map_ref(b, s.shape) do r
      @remote(b, Thicken(r, s.thickness))
    end,
    s.shape)

# backend_frame_at
backend_frame_at(b::ACAD, s::Circle, t::Real) = add_pol(s.center, s.radius, t)

backend_frame_at(b::ACAD, c::Shape1D, t::Real) = @remote(b, CurveFrameAt(ref(c).value, t))

#backend_frame_at(b::ACAD, s::Surface, u::Real, v::Real) =
    #What should we do with v?
#    backend_frame_at(b, s.frontier[1], u)

#backend_frame_at(b::ACAD, s::SurfacePolygon, u::Real, v::Real) =

backend_frame_at(b::ACAD, s::Shape2D, u::Real, v::Real) = @remote(b, SurfaceFrameAt(ref(s).value, u, v))

# BIM
realize(b::ACAD, f::TableFamily) =
    @remote(b, CreateRectangularTableFamily(f.length, f.width, f.height, f.top_thickness, f.leg_thickness))
realize(b::ACAD, f::ChairFamily) =
    @remote(b, CreateChairFamily(f.length, f.width, f.height, f.seat_height, f.thickness))
realize(b::ACAD, f::TableChairFamily) =
    @remote(b, CreateRectangularTableAndChairsFamily(
        realize(b, f.table_family), realize(b, f.chair_family),
        f.table_family.length, f.table_family.width,
        f.chairs_top, f.chairs_bottom, f.chairs_right, f.chairs_left,
        f.spacing))

KhepriBase.b_table(b::ACAD, c, angle, family) =
    @remote(b, Table(c, angle, realize(b, family)))

KhepriBase.b_chair(b::ACAD, c, angle, family) =
    @remote(b, Chair(c, angle, realize(b, family)))

KhepriBase.b_table_and_chairs(b::ACAD, c, angle, family) =
    @remote(b, TableAndChairs(c, angle, realize(b, family)))

############################################

# KhepriBase.b_bounding_box(b::ACAD, shapes::Shapes) =
#   @remote(b, BoundingBox(collect_ref(shapes)))

KhepriBase.b_set_view(b::ACAD, camera::Loc, target::Loc, lens::Real, aperture::Real) =
  @remote(b, View(camera, target, lens))

KhepriBase.b_get_view(b::ACAD) =
  @remote(b, ViewCamera()), @remote(b, ViewTarget()), @remote(b, ViewLens())

# Only AutoCAD supports this
# zoom_extents(b::ACAD) = @remote(b, ZoomExtents())

# Only AutoCAD supports this
KhepriBase.b_set_view_top(b::ACAD) = @remote(b, ViewTop())

KhepriBase.b_realistic_sky(b::ACAD, date, latitude, longitude, elevation, meridian, turbidity, withsun) =
  @remote(b, SetSkyFromDateLocation(date, latitude, longitude, meridian, elevation))


KhepriBase.b_all_refs(b::ACAD) =
  @remote(b, GetAllShapes())

KhepriBase.b_delete_refs(b::ACAD, rs::Vector{ACADId}) =
  @remote(b, DeleteMany(rs))

KhepriBase.b_delete_ref(b::ACAD, r::ACADId) =
  @remote(b, Delete(r))

KhepriBase.b_delete_all_refs(b::ACAD) =
  @remote(b, DeleteAll())

backend_set_length_unit(b::ACAD, unit::String) = @remote(b, SetLengthUnit(unit))

# Dimensions

const ACADDimensionStyles = Dict(:architectural => "_ARCHTICK", :mechanical => "")

backend_dimension(b::ACAD, p0::Loc, p1::Loc, p::Loc, scale::Real, style::Symbol) =
    @remote(b, CreateAlignedDimension(p0, p1, p,
        scale,
        ACADDimensionStyles[style]))

backend_dimension(b::ACAD, p0::Loc, p1::Loc, sep::Real, scale::Real, style::Symbol) =
    let v = p1 - p0
        angle = pol_phi(v)
        dimension(p0, p1, add_pol(p0, sep, angle + pi/2), scale, style, b)
    end

# Layers

KhepriBase.b_current_layer(b::ACAD) =
  @remote(b, CurrentLayer())

KhepriBase.b_current_layer(b::ACAD, layer) =
  @remote(b, SetCurrentLayer(layer))

KhepriBase.b_layer(b::ACAD, name, active, color) =
  let to255(x) = round(UInt8, x*255)
    @remote(b, CreateLayer(name, true, to255(red(color)), to255(green(color)), to255(blue(color))))
  end

KhepriBase.b_delete_all_shapes_in_layer(b::ACAD, layer) =
  @remote(b, DeleteAllInLayer(layer))

switch_to_layer(to, b::ACAD) =
    if to != from
      set_layer_active(to, true)
      set_layer_active(from, false)
      current_layer(to)
    end

# Blocks

realize(b::ACAD, s::Block) =
    @remote(b, CreateBlockFromShapes(s.name, collect_ref(s.shapes)))

realize(b::ACAD, s::BlockInstance) =
    @remote(b, CreateBlockInstance(
        collect_ref(s.block)[1],
        center_scaled_cs(s.loc, s.scale, s.scale, s.scale)))

#=

# Manual process
@time for i in 1:1000 for r in 1:10 circle(x(i*10), r) end end

# Create block...
Khepri.create_block("Foo", [circle(radius=r) for r in 1:10])

# ...and instantiate it
@time for i in 1:1000 Khepri.instantiate_block("Foo", x(i*10), 0) end

=#

# Lights
KhepriBase.b_pointlight(b::ACAD, loc::Loc, color::RGB, range::Real, intensity::Real) =
  # HACK: Fix this
  @remote(b, SpotLight(loc, intensity, range, loc+vz(-1)))

KhepriBase.b_spotlight(b::ACAD, loc::Loc, dir::Vec, hotspot::Real, falloff::Real) =
    @remote(b, SpotLight(loc, hotspot, falloff, loc + dir))

KhepriBase.b_ieslight(b::ACAD, file::String, loc::Loc, dir::Vec, alpha::Real, beta::Real, gamma::Real) =
    @remote(b, IESLight(file, loc, loc + dir, vxyz(alpha, beta, gamma)))

# User Selection

KhepriBase.b_shape_from_ref(b::ACAD, r) =
  let code = @remote(b, ShapeCode(r)),
      ref = DynRefs(b=>ACADNativeRef(r))
    if code == 1 # Point
        point(@remote(b, PointPosition(r)),
              ref=ref)
    elseif code == 2
        circle(loc_from_o_vz(@remote(b, CircleCenter(r)), @remote(b, CircleNormal(r))),
               @remote(b, CircleRadius(r)),
               ref=ref)
    elseif 3 <= code <= 6
        line(@remote(b, LineVertices(r)),
             ref=ref)
    elseif code == 7
        let tans = @remote(b, SplineTangents(r))
            if length(tans[1]) < 1e-20 && length(tans[2]) < 1e-20
                closed_spline(@remote(b, SplineInterpPoints(r))[1:end-1],
                              ref=ref)
            else
                spline(@remote(b, SplineInterpPoints(r)), tans[1], tans[2],
                       ref=ref)
            end
        end
    elseif code == 9
        let start_angle = mod(@remote(b, ArcStartAngle(r)), 2pi),
            end_angle = mod(@remote(b, ArcEndAngle(r)), 2pi)
            arc(loc_from_o_vz(@remote(b, ArcCenter(r)), @remote(b, ArcNormal(r))),
                @remote(b, ArcRadius(r)), start_angle, mod(end_angle - start_angle, 2pi),
                ref=ref)
        #=    if end_angle > start_angle
                arc(maybe_loc_from_o_vz(@remote(b, ArcCenter(r)), @remote(b, ArcNormal(r))),
                    @remote(b, ArcRadius(r)), start_angle, end_angle - start_angle,
                    ref=ref)
            else
                arc(maybe_loc_from_o_vz(@remote(b, ArcCenter(r)), @remote(b, ArcNormal(r))),
                    @remote(b, ArcRadius(r)), end_angle, start_angle - end_angle,
                    ref=ref)
            end=#
        end
    elseif code == 10
        let str = @remote(b, TextString(r)),
            height = @remote(b, TextHeight(r)),
            loc = @remote(b, TextPosition(r))
            text(str, loc, height, ref=ref)
        end
    elseif code == 11
        let str = @remote(b, MTextString(r)),
            height = @remote(b, MTextHeight(r)),
            loc = @remote(b, MTextPosition(r))
            text(str, loc, height, ref=ref)
        end
    elseif code == 16
        let pts = @remote(b, MeshVertices(r)),
            (type, n, m, n_closed, m_closed) = @remote(b, PolygonMeshData(r))
            surface_grid(reshape(pts, (n, m)), n_closed == 1, m_closed == 1, ref=ref)
        end
    elseif 12 <= code <= 14
        surface(Shapes1D[], ref=ref)
    elseif 103 <= code <= 106
        polygon(@remote(b, LineVertices(r)),
                ref=ref)
    elseif code == 107
        closed_spline(@remote(b, SplineInterpPoints(r))[1:end-1],
                      ref=ref)
    else
        #unknown(ref=ref)
        unknown(r, ref=ref) # To force copy
        #error("Unknown shape with code $(code)")
    end
  end
#

#=
In case we need to realize an Unknown shape, we just copy it
=#

realize(b::ACAD, s::Unknown) =
    @remote(b, Copy(s.baseref))



KhepriBase.b_select_position(b::ACAD, prompt::String) =
  begin
    @info "$(prompt) on the $(b) backend."
    let ans = @remote(b, GetPosition(prompt))
      length(ans) > 0 ? ans[1] : nothing
    end
  end

KhepriBase.b_select_positions(b::ACAD, prompt::String) =
  let sel() =
    let p = select_position(prompt, b)
      if isnothing(p)
        []
      else
        [p, sel()...]
      end
    end
    sel()
  end

# HACK: The next operations should receive a set of shapes to avoid re-creating already existing shapes

KhepriBase.b_select_point(b::ACAD, prompt::String) =
  select_one_with_prompt(prompt, b, @get_remote b GetPoint)
KhepriBase.b_select_points(b::ACAD, prompt::String) =
  select_many_with_prompt(prompt, b, @get_remote b GetPoints)

KhepriBase.b_select_curve(b::ACAD, prompt::String) =
  select_one_with_prompt(prompt, b, @get_remote b GetCurve)
KhepriBase.b_select_curves(b::ACAD, prompt::String) =
  select_many_with_prompt(prompt, b, @get_remote b GetCurves)

KhepriBase.b_select_surface(b::ACAD, prompt::String) =
  select_one_with_prompt(prompt, b, @get_remote b GetSurface)
KhepriBase.b_select_surfaces(b::ACAD, prompt::String) =
  select_many_with_prompt(prompt, b, @get_remote b GetSurfaces)

KhepriBase.b_select_solid(b::ACAD, prompt::String) =
  select_one_with_prompt(prompt, b, @get_remote b GetSolid)
KhepriBase.b_select_solids(b::ACAD, prompt::String) =
  select_many_with_prompt(prompt, b, @get_remote b GetSolids)

KhepriBase.b_select_shape(b::ACAD, prompt::String) =
  select_one_with_prompt(prompt, b, @get_remote b GetShape)
KhepriBase.b_select_shapes(b::ACAD, prompt::String) =
  select_many_with_prompt(prompt, b, @get_remote b GetShapes)

backend_captured_shape(b::ACAD, handle) =
  backend_shape_from_ref(b, @remote(b, GetShapeFromHandle(handle)))
backend_captured_shapes(b::ACAD, handles) =
  map(handles) do handle
      backend_shape_from_ref(b, @remote(b, GetShapeFromHandle(handle)))
  end

backend_generate_captured_shape(b::ACAD, s::Shape) =
    println("captured_shape(autocad, $(@remote(b, GetHandleFromShape(ref(s).value))))")
backend_generate_captured_shapes(b::ACAD, ss::Shapes) =
  begin
    print("captured_shapes(autocad, [")
    for s in ss
      print(@remote(b, GetHandleFromShape(ref(s).value)))
      print(", ")
    end
    println("])")
  end

# Register for notification

backend_register_shape_for_changes(b::ACAD, s::Shape) =
    let conn = connection(b)
        @remote(b, RegisterForChanges(ref(s).value))
        @remote(b, DetectCancel())
        s
    end

backend_unregister_shape_for_changes(b::ACAD, s::Shape) =
    let conn = connection(b)
        @remote(b, UnregisterForChanges(ref(s).value))
        @remote(b, UndetectCancel())
        s
    end

backend_waiting_for_changes(b::ACAD, s::Shape) =
    ! @remote(b, WasCanceled())

backend_changed_shape(b::ACAD, ss::Shapes) =
    let conn = connection(b)
        changed = []
        while length(changed) == 0 && ! @remote(b, WasCanceled())
            changed =  @remote(b, ChangedShape())
            sleep(0.1)
        end
        if length(changed) > 0
            backend_shape_from_ref(b, changed[1])
        else
            nothing
        end
    end


# HACK: This should be filtered on the plugin, not here.
b_all_shapes(b::ACAD) =
  Shape[backend_shape_from_ref(b, r)
        for r in filter(r -> @remote(b, ShapeCode(r)) != 0, @remote(b, GetAllShapes()))]

backend_all_shapes_in_layer(b::ACAD, layer) =
  Shape[backend_shape_from_ref(b, r) for r in @remote(b, GetAllShapesInLayer(layer))]

backend_highlight_shape(b::ACAD, s::Shape) =
  @remote(b, SelectShapes(collect_ref(s)))

backend_highlight_shapes(b::ACAD, ss::Shapes) =
  @remote(b, SelectShapes(collect_ref(ss)))

backend_pre_selected_shapes_from_set(ss::Shapes) =
  length(ss) == 0 ? [] : pre_selected_shapes_from_set(ss, backend(ss[1]))

# HACK: This must be implemented for all backends
backend_pre_selected_shapes_from_set(ss::Shapes, b::Backend) = []

backend_pre_selected_shapes_from_set(b::ACAD, ss::Shapes) =
  let refs = map(id -> @remote(b, GetHandleFromShape(id)), @remote(b, GetPreSelectedShapes()))
    filter(s -> @remote(b, GetHandleFromShape(ref(s).value)) in refs, ss)
  end
backend_disable_update(b::ACAD) =
  @remote(b, DisableUpdate())

backend_enable_update(b::ACAD) =
  @remote(b, EnableUpdate())

# Render

#render exposure: [-3, +3] -> [-6, 21]
convert_render_exposure(b::ACAD, v::Real) = -4.05*v + 8.8
#render quality: [-1, +1] -> [+1, +50]
convert_render_quality(b::ACAD, v::Real) = round(Int, 25.5 + 24.5*v)

KhepriBase.b_render_view(b::ACAD, path::String) =
    @remote(b, Render(
               render_width(), render_height(),
               path,
               convert_render_quality(b, render_quality()),
               convert_render_exposure(b, render_exposure())))

export mentalray_render_view
mentalray_render_view(name::String) =
    let b = autocad
        @remote(b, SetSystemVariableInt("SKYSTATUS", 2)) # skystatus:background-and-illumination
        @remote(b, Command("._-render P _R $(render_width()) $(render_height()) _yes $(prepare_for_saving_file(render_pathname(name)))\n"))
    end

backend_save_as(b::ACAD, pathname::String, format::String) =
    @remote(b, SaveAs(pathname, format))


export autocad_command
autocad_command(s::String) =
  @remote(autocad, Command("$(s)\n"))

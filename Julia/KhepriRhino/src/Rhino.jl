export rhino

# Coordinate convention: Rhino uses right-handed Z-up, same as Khepri.
# No axis transforms needed.

### PLugin
#=
Whenever the plugin is updated, run this function and commit the plugin files.
upgrade_plugin()
=#

julia_khepri = dirname(dirname(abspath(@__FILE__)))

dlls = ["KhepriBase.dll", "KhepriRhinoceros.rhp"]
local_plugin = joinpath(dirname(dirname(abspath(@__FILE__))), "Plugin")

upgrade_plugin() =
  let plugin_folder = joinpath(dirname(dirname(dirname(dirname(abspath(@__FILE__))))), "Plugins", "KhepriRhinoceros", "KhepriRhinoceros", "bin"),
      local_folder = joinpath(julia_khepri, "Plugin")
    copy_plugin_files!(dlls, plugin_folder, local_folder)
  end

##############################################
# We need some additional Encoders
# RH is a subtype of CS
parse_signature(::Val{:RH}, sig::T) where {T} = parse_signature(Val(:CS), sig)
encode(::Val{:RH}, t::Val{T}, c::IO, v) where {T} = encode(Val(:CS), t, c, v)
decode(::Val{:RH}, t::Val{T}, c::IO) where {T} = decode(Val(:CS), t, c)

# CLR name mapping for signature validation: MatId is a C# using alias for System.Int32
KhepriBase.clr_name(::Val{:RH}, name::AbstractString) =
  name == "MatId" ? "Int32" : clr_name(name)

# We need some additional Encoders
@encode_decode_as(:RH, Val{:Options}, Val{:Dict})
@encode_decode_as(:RH, Val{:Brep}, Val{:Guid})
@encode_decode_as(:RH, Val{:RhinoObject}, Val{:Guid})

encode(::Val{:RH}, t::Union{Val{:Point3d},Val{:Vector3d}}, c::IO, p) =
  encode(Val(:CS), Val(:double3), c, raw_point(p))
decode(::Val{:RH}, t::Val{:Point3d}, c::IO) =
  xyz(decode(Val(:CS), Val(:double3), c)..., world_cs)
decode(::Val{:RH}, t::Val{:Vector3d}, c::IO) =
  vxyz(decode(Val(:CS), Val(:double3), c)..., world_cs)

encode(ns::Val{:RH}, t::Val{:Plane}, c::IO, p) =
  let o = in_world(p),
      x = in_world(vx(1, p.cs)),
      y = in_world(vy(1, p.cs))
    encode(ns, Val(:Point3d), c, o)
    encode(ns, Val(:Vector3d), c, x)
    encode(ns, Val(:Vector3d), c, y)
  end
decode(ns::Val{:RH}, t::Val{:Plane}, c::IO) =
  loc_from_o_vx_vy(
    decode(ns, Val(:Point3d), c),
    decode(ns, Val(:Vector3d), c),
    decode(ns, Val(:Vector3d), c))

rhino_api = @remote_api :RH """
public void RunScript(string script)
public void SetView(Point3d position, Point3d target, double lens)
public void SetViewDisplayMode(string mode)
public void SetViewTop()
public void ViewSize(int width, int height)
public Point3d ViewCamera()
public Point3d ViewTarget()
public double ViewLens()
public string DefaultMaterialsFolder()
public MatId LoadRenderMaterialFromPath(string path)
public MatId CreateMaterial(string name, Color diffuse, Color specular, Color ambient, Color emission, Color reflection, double reflectivity, double reflectionGlossiness, double refractionIndex, double transparency)
public Guid Point(Point3d p)
public Point3d PointPosition(Guid ent)
public Guid PolyLine(Point3d[] pts)
public Point3d[] LineVertices(RhinoObject id)
public Guid Spline(Point3d[] pts)
public Guid SplineTangents(Point3d[] pts, Vector3d start, Vector3d end)
public Guid BezierCurve(Point3d[][] controlPoints, bool closed, MatId mat)
public Guid BSplineCurve(Point3d[] controlPoints, int degree, double[] knots, bool closed, MatId mat)
public Guid NurbsCurve(Point3d[] controlPoints, int degree, double[] knots, double[] weights, bool closed, MatId mat)
public Guid ClosedPolyLine(Point3d[] pts)
public Guid ClosedSpline(Point3d[] pts)
public Guid Circle(Point3d c, Vector3d n, double r)
public Point3d CircleCenter(RhinoObject obj)
public Vector3d CircleNormal(RhinoObject obj)
public double CircleRadius(RhinoObject obj)
public Guid Ellipse(Plane p, double radiusX, double radiusY)
public Plane EllipsePlane(RhinoObject obj)
public double EllipseRadiusX(RhinoObject obj)
public double EllipseRadiusY(RhinoObject obj)
public Guid Arc(Plane p, double radius, double startAngle, double endAngle)
public Point3d ArcCenter(RhinoObject obj)
public Vector3d ArcNormal(RhinoObject obj)
public double ArcRadius(RhinoObject obj)
public double ArcStartAngle(RhinoObject obj)
public double ArcEndAngle(RhinoObject obj)
public Point3d[] CurveSamplePoints(RhinoObject obj, int samples)
public Point3d CurveClosestPoint(RhinoObject obj, Point3d point)
public double CurveClosestParameter(RhinoObject obj, Point3d point)
public Point3d[] CurveCurveClosestPoints(RhinoObject obj0, RhinoObject obj1)
public double[] CurveCurveClosestParameters(RhinoObject obj0, RhinoObject obj1)
public Point3d BrepClosestPoint(RhinoObject obj, Point3d point)
public int CurvePointClassification(RhinoObject obj, Point3d point, double tolerance)
public int BrepPointClassification(RhinoObject obj, Point3d point, double tolerance)
public Guid Text(string str, Plane p, double height, string fontName, bool bold, bool italic)
public Guid JoinCurves(Guid[] objs)
public Guid Mesh(Point3d[] pts, int[][] faces, MatId mat)
public Guid NGon(Point3d[] pts, Point3d pivot, bool smooth, MatId mat)
public Guid SurfaceFrom(Guid[] ids, MatId mat)
public Guid SurfaceFromCurvesPoints(Point3d[][] ptss, bool[] smooths, MatId mat)
public Guid SurfaceCircle(Point3d c, Vector3d n, double r, MatId mat)
public Guid SurfaceEllipse(Plane p, double radiusX, double radiusY, MatId mat)
public Guid SurfaceArc(Plane p, double radius, double startAngle, double endAngle, MatId mat)
public Guid SurfaceClosedPolyLine(Point3d[] pts, MatId mat)
public Guid Sphere(Point3d c, double r, MatId mat)
public Guid Torus(Point3d c, Vector3d vz, double majorRadius, double minorRadius, MatId mat)
public Guid Cylinder(Point3d bottom, double radius, Point3d top, MatId mat)
public Guid Cone(Point3d bottom, double radius, Point3d top, MatId mat)
public Guid ConeFrustum(Point3d bottom, double bottom_radius, Point3d top, double top_radius, MatId mat)
public Guid Box(Point3d corner, Vector3d vx, Vector3d vy, double dx, double dy, double dz, MatId mat)
public Guid XYCenteredBox(Point3d corner, Vector3d vx, Vector3d vy, double dx, double dy, double dz, MatId mat)
public Guid IrregularPyramid(Point3d[] pts, Point3d apex, MatId mat)
public Guid IrregularPyramidFrustum(Point3d[] bpts, Point3d[] tpts, MatId mat)
public Guid PrismWithHoles(Point3d[][] ptss, bool[] smooths, Vector3d dir, MatId mat)
public Guid SurfaceFromGrid(int nU, int nV, Point3d[] pts, bool closedU, bool closedV, int degreeU, int degreeV, MatId mat)
public Guid BezierSurface(Point3d[] controlPoints, int nU, int nV, bool closedU, bool closedV, MatId mat)
public Guid BSplineSurface(Point3d[] controlPoints, int nU, int nV, int degreeU, int degreeV, double[] knotsU, double[] knotsV, bool closedU, bool closedV, MatId mat)
public Guid NurbsSurface(Point3d[] controlPoints, int nU, int nV, int degreeU, int degreeV, double[] knotsU, double[] knotsV, double[] weights, bool closedU, bool closedV, MatId mat)
public Brep[] Thicken(RhinoObject obj, double thickness)
public double[] CurveDomain(RhinoObject obj)
public double CurveLength(RhinoObject obj)
public Plane CurveFrameAt(RhinoObject obj, double t)
public Plane CurveFrameAtLength(RhinoObject obj, double l)
public double[] SurfaceDomain(RhinoObject obj)
public Plane SurfaceFrameAt(RhinoObject obj, double u, double v)
public Point3d[] BoundingBox(RhinoObject[] ids)
public Brep Extrusion(RhinoObject obj, Vector3d dir)
public Brep[] SweepPathProfile(RhinoObject path, RhinoObject profile, double rotation, double scale)
public Brep Revolve(RhinoObject profile, Point3d p, Vector3d n, double startAngle, double amplitude)
public Brep Loft(RhinoObject[] profiles, RhinoObject[] rails, bool ruled, bool closed)
public Guid[] Unite(RhinoObject[]objs)
public Guid[] Intersect(RhinoObject obj0, RhinoObject obj1)
public Guid[] Subtract(RhinoObject obj0, RhinoObject obj1)
public Point3d[] CurveCurveIntersectionPoints(RhinoObject obj0, RhinoObject obj1, double tolerance)
public Point3d[][] CurveCurveIntersectionPolylines(RhinoObject obj0, RhinoObject obj1, double tolerance, int samples)
public Point3d[] CurveBrepIntersectionPoints(RhinoObject curveObj, RhinoObject brepObj, double tolerance)
public Point3d[][] CurveBrepIntersectionPolylines(RhinoObject curveObj, RhinoObject brepObj, double tolerance, int samples)
public Point3d[] BrepBrepIntersectionPoints(RhinoObject obj0, RhinoObject obj1, double tolerance)
public Point3d[][] BrepBrepIntersectionPolylines(RhinoObject obj0, RhinoObject obj1, double tolerance, int samples)
public Guid[] Slice(RhinoObject obj, Point3d p, Vector3d n)
public Guid Move(Guid id, Vector3d v)
public Guid Scale(Guid id, Point3d p, double s)
public Guid Rotate(Guid id, Point3d p, Vector3d n, double a)
public Guid Mirror(Guid id, Point3d p, Vector3d n, bool copy)
public Guid ImportOBJ(string path, Point3d origin, Vector3d vx, Vector3d vy, Vector3d vz)
public bool IsPoint(RhinoObject e)
public bool IsCircle(RhinoObject e)
public bool IsPolyLine(RhinoObject e)
public bool IsSpline(RhinoObject e)
public bool IsClosedPolyLine(RhinoObject e)
public bool IsClosedSpline(RhinoObject e)
public bool IsEllipse(RhinoObject e)
public bool IsArc(RhinoObject e)
public bool IsText(RhinoObject e)
public byte ShapeCode(RhinoObject id)
public Guid ClosedPathCurveArray(Point3d[] pts, double[] angles)
public Brep[] PathWall(RhinoObject obj, double lThickness, double rThickness, double height)
public Brep[] BaseRectangularTable(double length, double width, double height, double top_thickness, double leg_thickness)
public int CreateRectangularTableFamily(double length, double width, double height, double top_thickness, double leg_thickness)
public Guid Table(Point3d c, double angle, int family)
public Brep[] BaseChair(double length, double width, double height, double seat_height, double thickness)
public int CreateChairFamily(double length, double width, double height, double seat_height, double thickness)
public Guid Chair(Point3d c, double angle, int family)
public GeometryBase[] BaseRectangularTableAndChairs(int tableFamily, int chairFamily, double tableLength, double tableWidth, int chairsOnTop, int chairsOnBottom, int chairsOnRight, int chairsOnLeft, double spacing)
public int CreateRectangularTableAndChairsFamily(int tableFamily, int chairFamily, double tableLength, double tableWidth, int chairsOnTop, int chairsOnBottom, int chairsOnRight, int chairsOnLeft, double spacing)
public Guid TableAndChairs(Point3d c, double angle, int family)
public Guid CreateLayer(String name, bool visible, Color color)
public Guid CurrentLayer()
public void SetCurrentLayer(Guid id)
public void SetLayerVisible(Guid id, bool visible)
public void SetLayerTransparency(Guid layerId, double opacity)
public String LayerName(Guid id)
public Color LayerColor(Guid id)
public bool LayerVisible(Guid id)
public Guid ShapeLayer(RhinoObject objId)
public void SetShapeLayer(RhinoObject objId, Guid layerId)
public void SetLayerMaterial(Guid layerId, int materialIndex)
public Point3d[] CurvePointsAt(RhinoObject obj, double[] ts)
public Vector3d[] CurveTangentsAt(RhinoObject obj, double[] ts)
public Vector3d[] CurveNormalsAt(RhinoObject obj, double[] ts)
public int DeleteAll()
public int DeleteAllInLayer(Guid id)
public void Delete(Guid id)
public void DeleteMany(Guid[] ids)
public void Select(Guid id)
public void SelectMany(Guid[] ids)
public void Highlight(RhinoObject o)
public void Unhighlight(RhinoObject o)
public void UnhighlightAll()
public Guid Clone(RhinoObject e)
public Point3d[] GetPosition(string prompt)
public Guid[] GetPoint(string prompt)
public Guid[] GetPoints(string prompt)
public Guid[] GetCurve(string prompt)
public Guid[] GetCurves(string prompt)
public Guid[] GetSurface(string prompt)
public Guid[] GetSurfaces(string prompt)
public Guid[] GetSolid(string prompt)
public Guid[] GetSolids(string prompt)
public Guid[] GetShape(string prompt)
public Guid[] GetShapes(string prompt)
public Guid[] GetAllShapes()
public Guid[] GetAllShapesInLayer(Guid id)
public Guid CreateLeaderDimension(String text, Point3d p0, Point3d p1, double scale, String mark, Options props)
public Guid CreateDiametricDimension(String text, Plane c, Point3d p, Point3d pdim, double scale, String mark, Options props)
public Guid CreateAngularDimension(String text, Plane p, Point3d p0, Point3d p1, Point3d ptdim, double scale, String mark, Options props) {
public void SunLight(DateTime dt, double latitude, double longitude, int meridian, float turbidity, bool hasSun)
public Guid PointLight(Point3d p, Color c, double power)
public Guid SpotLight(Point3d position, double hotspot, double falloff, Point3d target)
public Guid IESLight(string webFile, Point3d position, Point3d target, Vector3d rotation)
public void EnableGrasshopperSolver()
public void DisableGrasshopperSolver()
public void RunGrasshopperSolver()
public void Render(int width, int height, int quality, string path)
public void RenderLoadHDRiEnvironment(string name, string path)
public void RenderUseHDRiEnvironment(string name, double rotation)
public void ClayRenderBlack(string env, double rotation, int width, int height, int quality, string path)
public void ClayRenderWhite(string env, double rotation, int width, int height, int quality, string path)
public void SetBackgroundHDRi(string path, double angle)
public void SaveView(int width, int height, string path)
public void ZoomExtents()
"""
#public Guid CreateAngularDimension(string text, Plane p, double radius, double startAngle, double endAngle, double scale, double offset, Options props)

#=
public byte Sync()
public byte Disconnect()
public Entity InterpSpline(Point3d[] pts, Vector3d tan0, Vector3d tan1)
public Entity InterpClosedSpline(Point3d[] pts)
public Guid SurfaceFromCurve(Entity curve)
public Guid IrregularPyramidMesh(Point3d[] pts, Point3d apex)
public Entity SolidFromGrid(int m, int n, Point3d[] pts, bool closedM, bool closedN, int level, double thickness)
public Guid NurbSurfaceFrom(ObjectId id)
public double[] SurfaceDomain(Entity ent)
public Frame3d SurfaceFrameAt(Entity ent, double u, double v)
public Guid Sweep(ObjectId pathId, ObjectId profileId, double rotation, double scale)
public Guid Loft(ObjectId[] profilesIds, ObjectId[] guidesIds, bool ruled, bool closed)
public Guid Revolve(ObjectId profileId, Point3d p, Vector3d n, double startAngle, double amplitude)
public Point3d[] GetPoint(string prompt)
public void ZoomExtents()
public void SetSystemVariableInt(string name, int value)
public int Command(string cmd)
public void DisableUpdate()
public void EnableUpdate()
public BIMLevel FindOrCreateLevelAtElevation(double elevation)
public BIMLevel UpperLevel(BIMLevel currentLevel, double addedElevation)
public double GetLevelElevation(BIMLevel level)
public Entity MeshFromGrid(int m, int n, Point3d[] pts, bool closedM, bool closedN)

public FloorFamily FloorFamilyInstance(double totalThickness, double coatingThickness)
public Entity LightweightPolyLine(Point2d[] pts, double[] angles, double elevation)
public Entity SurfaceLightweightPolyLine(Point2d[] pts, double[] angles, double elevation)
public ObjectId CreatePathFloor(Point2d[] pts, double[] angles, BIMLevel level, FloorFamily family)
=#


abstract type RHKey end
const RHId = Guid
const RHRef = GenericRef{RHKey, RHId}
const RHRefs = Vector{RHRef}
const RHNativeRef = NativeRef{RHKey, RHId}
const RHNativeRefs = NativeRefs{RHKey, RHId}
const RH = SocketBackend{RHKey, RHId}

KhepriBase.shape_storage_type(::Type{RH}) = RemoteShapeStorage()

KhepriBase.void_ref(::RH) = 0 % UInt128

KhepriBase.failed_connecting(b::RH) =
  begin
	@info("Please, ensure Khepri's Rhinoceros plugin is installed.")
  	@info("Go to Rhinoceros: Tools->Options->Plug-ins->Install")
  	@info("Location: $(joinpath(local_plugin, dlls[2]))")
  end

KhepriBase.after_connecting(b::RH) =
  let mat_folder = @remote(b, DefaultMaterialsFolder()),
  	  m = match(r".+?Rhinoceros\\(.+?)\\Localization", mat_folder)
  	if m === nothing
	    error("Unrecognized Rhino materials folder: $(mat_folder)")
  	else
	    let v = VersionNumber(m[1])
	      if v >= v"6.0"
		  	# Apparently, materials are not yet working in Rhino 6!!!!
	        set_material(RH, material_metal, rhino_default_material(raw"Metal\Matte\Matte Silver"))
	        set_material(RH, material_glass, rhino_default_material(raw"Glass\Clear Glass"))
	        set_material(RH, material_wood, rhino_default_material(raw"Wood\Pear polished"))
	        set_material(RH, material_concrete, rhino_default_material(raw"Ceramics\Stoneware"))
	        set_material(RH, material_plaster, rhino_default_material(raw"White Matte"))
	        set_material(RH, material_grass, rhino_default_material(raw"Textures\Grass"))
	      elseif v >= v"5.0"
            set_material(RH, material_metal, rhino_default_material(raw"Metal\Silver"))
            set_material(RH, material_glass, rhino_default_material(raw"Transparent\Glass"))
            set_material(RH, material_wood, rhino_default_material(raw"Wood\Scots Pine"))
            set_material(RH, material_concrete, rhino_default_material(raw"Stone\Granite"))
            set_material(RH, material_plaster, rhino_default_material(raw"White Matte"))
            set_material(RH, material_grass, rhino_default_material(raw"Special\Grass"))
	      else
	        error("Unrecognized Rhino version: ")
	      end
	    end
    end
  end

const rhino = RH("Rhino", rhino_port, rhino_api)

KhepriBase.has_boolean_ops(::Type{RH}) = HasBooleanOps{false}()
KhepriBase.curve_geometry_capabilities(::Type{RH}) =
  CurveGeometryCapabilities{true,true,true,true,true}()
KhepriBase.surface_geometry_capabilities(::Type{RH}) =
  SurfaceGeometryCapabilities{true,true,true,false}()
KhepriBase.backend(::RHRef) = rhino

# Primitives
KhepriBase.b_point(b::RH, p, mat) =
  @remote(b, Point(p))

KhepriBase.b_line(b::RH, ps, mat) =
  @remote(b, PolyLine(ps))

KhepriBase.b_polygon(b::RH, ps, mat) =
  @remote(b, ClosedPolyLine(ps))

KhepriBase.b_spline(b::RH, ps, v0, v1, mat) =
  if (v0 == false) && (v1 == false)
    @remote(b, Spline(ps))
  elseif (v0 != false) && (v1 != false)
    @remote(b, SplineTangents(ps, v0, v1))
  else
    @remote(b, SplineTangents(ps,
                 v0 == false ? ps[2]-ps[1] : v0,
                 v1 == false ? ps[end-1]-ps[end] : v1))
  end

KhepriBase.b_closed_spline(b::RH, ps, mat) =
  @remote(b, ClosedSpline(ps))

KhepriBase.b_bezier_curve(b::RH, path::BezierPath, mat) =
  @remote(b, BezierCurve([seg.control_points for seg in path.spans],
                         is_closed_path(path),
                         mat))

KhepriBase.b_bspline_curve(b::RH, path::BSplinePath{Closed,false}, mat) where {Closed} =
  @remote(b, BSplineCurve(path.control_points,
                          path.degree,
                          path.knots,
                          is_closed_path(path),
                          mat))

KhepriBase.b_nurbs_curve(b::RH, path::NurbsPath, mat) =
  @remote(b, NurbsCurve(path.control_points,
                        path.degree,
                        path.knots,
                        path.weights,
                        is_closed_path(path),
                        mat))

KhepriBase.b_circle(b::RH, c, r, mat) =
  @remote(b, Circle(c, vz(1, c.cs), r))

KhepriBase.b_arc(b::RH, c, r, α, Δα, mat) =
  if r == 0
    @remote(b, Point(c))
  elseif Δα == 0
    @remote(b, Point(c + vpol(r, α, c.cs)))
  elseif abs(Δα) >= 2*pi
    @remote(b, Circle(c, vz(1, c.cs), r))
  else
	let β = α + Δα
  	  if β > α
  	  	@remote(b, Arc(c, r, α, β))
  	  else
  	  	@remote(b, Arc(c, r, β, α))
  	  end
    end
  end

KhepriBase.b_ellipse(b::RH, c, rx, ry, mat) =
  @remote(b, Ellipse(c, rx, ry))

#=
Rhino supports meshes and nurbs surfaces. Meshes are more efficient... but 
many operations, such as boolean operations, sweep, extrusion, etc., need 
surfaces (or polysurfaces).
This means that although we might implement trigs and quads using meshes, 
that is not what Rhino would give us if we were creating 3D objects by hand.
Therefore, we will use meshes as a fallback but most of the surface and solids
stuff needs Rhino's surfaces and polysurfaces.
=#

KhepriBase.b_trig(b::RH, p1, p2, p3, mat) =
  @remote(b, Mesh([p1, p2, p3], [[0, 1, 2, 2]], mat))

KhepriBase.b_quad(b::RH, p1, p2, p3, p4, mat) =
 	@remote(b, Mesh([p1, p2, p3, p4], [[0, 1, 2, 2], [0, 2, 3, 3]], mat))

KhepriBase.b_ngon(b::RH, ps, pivot, smooth, mat) =
 	@remote(b, NGon(ps, pivot, smooth, mat))

############################################################
# Second tier: surfaces

KhepriBase.b_surface_rectangle(b::RH, c, dx, dy, mat) =
  @remote(b, SurfaceClosedPolyLine([c, add_x(c, dx), add_xy(c, dx, dy), add_y(c, dy), c], mat))

KhepriBase.b_surface_regular_polygon(b::RH, edges, c, r, angle, inscribed, mat) =
  b_surface_polygon(b, regular_polygon_vertices(edges, c, r, angle, inscribed), mat)

KhepriBase.b_surface_polygon(b::RH, ps, mat) =
  @remote(b, SurfaceClosedPolyLine([ps...,ps[1]], mat))

KhepriBase.b_surface_polygon_with_holes(b::RH, ps, qss, mat) =
  @remote(b, SurfaceFromCurvesPoints([ps, qss...], falses(1 + length(qss)), mat))

KhepriBase.b_surface_circle(b::RH, c, r, mat) =
	@remote(b, SurfaceCircle(c, vz(1, c.cs), r, mat))

KhepriBase.b_surface_arc(b::RH, c, r, α, Δα, mat) =
  @remote(b, SurfaceArc(c, r, α, α + Δα, mat))

KhepriBase.b_surface_ellipse(b::RH, c, rx, ry, mat) =
   @remote(b, SurfaceEllipse(c, rx, ry, mat))

KhepriBase.b_surface(b::RH, frontier::Shapes, mat) =
  and_mark_deleted(b, @remote(b, SurfaceFrom(ref_values(b, frontier), mat)), frontier)


KhepriBase.b_surface_grid(b::RH, ptss, closed_u, closed_v, smooth_u, smooth_v, mat) =
  let (nu, nv) = size(ptss),
      order(n) = min(2*ceil(Int,n/16) + 1, 5)
    @remote(b, SurfaceFromGrid(nu, nv,
                               reshape(permutedims(ptss), :),
                               closed_u, closed_v,
                               smooth_u ? order(nu) : 1,
                               smooth_v ? order(nv) : 1,
							   mat))
  end

rhino_surface_points(s::TensorProductSurface) =
  reshape(permutedims(s.control_points), :)

rhino_surface_weights(s::BSplineSurface) =
  isnothing(s.weights) ? Float64[] : reshape(permutedims(s.weights), :)

KhepriBase.b_bezier_surface(b::RH, s::BezierSurface{ClosedU,ClosedV}, mat) where {ClosedU,ClosedV} =
  let (nu, nv) = size(s.control_points)
    @remote(b, BezierSurface(rhino_surface_points(s), nu, nv,
                             ClosedU,
                             ClosedV,
                             mat))
  end

KhepriBase.b_bspline_surface(b::RH, s::BSplineSurface{ClosedU,ClosedV,false}, mat) where {ClosedU,ClosedV} =
  let (nu, nv) = size(s.control_points)
    @remote(b, BSplineSurface(rhino_surface_points(s), nu, nv,
                              s.degree_u, s.degree_v,
                              s.knots_u, s.knots_v,
                              ClosedU, ClosedV,
                              mat))
  end

KhepriBase.b_nurbs_surface(b::RH, s::BSplineSurface{ClosedU,ClosedV,true}, mat) where {ClosedU,ClosedV} =
  let (nu, nv) = size(s.control_points)
    @remote(b, NurbsSurface(rhino_surface_points(s), nu, nv,
                            s.degree_u, s.degree_v,
                            s.knots_u, s.knots_v,
                            rhino_surface_weights(s),
                            ClosedU, ClosedV,
                            mat))
  end

const RH_GEOMETRY_INTERSECTION_SAMPLES = 64
const RHIntersectionSurface = Union{PlaneSurface,Region,BezierSurface,BSplineSurface,TrimmedSurface{PlaneSurface}}

rhino_temp_refs(refs::AbstractVector) = collect(refs)
rhino_temp_refs(ref) = RHId[ref]

function rhino_delete_temp_refs(b::RH, refs...)
  all_refs = RHId[]
  for ref in refs
    append!(all_refs, rhino_temp_refs(ref))
  end
  isempty(all_refs) || KhepriBase.b_delete_refs(b, all_refs)
end

function rhino_collinear_points(pts, tol)
  length(pts) <= 2 && return true
  p0 = in_world(pts[1])
  p1 = in_world(pts[end])
  dx, dy, dz = p1.x - p0.x, p1.y - p0.y, p1.z - p0.z
  denom = max(sqrt(dx^2 + dy^2 + dz^2), tol)
  all(pts[2:end-1]) do p
    q = in_world(p)
    qx, qy, qz = q.x - p0.x, q.y - p0.y, q.z - p0.z
    cx, cy, cz = qy * dz - qz * dy, qz * dx - qx * dz, qx * dy - qy * dx
    sqrt(cx^2 + cy^2 + cz^2) / denom <= tol
  end
end

rhino_polyline_curve(pts, tol) =
  rhino_collinear_points(pts, tol) ? line_path(pts[1], pts[end]) : polygonal_path(Loc[pts...])

function rhino_intersection_set(a, b, points, polylines, opts; curve_kind::Symbol=:section)
  elements = IntersectionElement[]
  for p in points
    push!(elements, PointIntersection(p; kind=:transversal))
  end
  for pts in polylines
    length(pts) >= 2 || continue
    push!(elements, CurveIntersection(rhino_polyline_curve(pts, opts.tolerance); kind=curve_kind))
  end
  IntersectionSet(a, b, elements; tolerance=opts.tolerance,
                  method=:backend, exactness=:toleranced)
end

KhepriBase.supports_geometry_operation(::RH, op::Symbol, ::Path, ::Path) =
  op in (:intersections, :section, :closest_points)
KhepriBase.supports_geometry_operation(::RH, op::Symbol, ::Path, ::RHIntersectionSurface) =
  op in (:intersections, :section)
KhepriBase.supports_geometry_operation(::RH, op::Symbol, ::RHIntersectionSurface, ::Path) =
  op in (:intersections, :section)
KhepriBase.supports_geometry_operation(::RH, op::Symbol, ::RHIntersectionSurface, ::RHIntersectionSurface) =
  op in (:intersections, :section)
KhepriBase.supports_geometry_operation(::RH, op::Symbol, ::Loc, ::Path) =
  op in (:project, :closest_points)
KhepriBase.supports_geometry_operation(::RH, op::Symbol, ::Path, ::Loc) =
  op in (:closest_points, :classify)
KhepriBase.supports_geometry_operation(::RH, op::Symbol, ::Loc, ::RHIntersectionSurface) =
  op in (:project, :closest_points)
KhepriBase.supports_geometry_operation(::RH, op::Symbol, ::RHIntersectionSurface, ::Loc) =
  op in (:closest_points, :classify)

function KhepriBase.b_intersections(b::RH, a::Path, c::Path, opts::GeometryOperationOptions)
  ar = KhepriBase.b_stroke(b, a, KhepriBase.void_ref(b))
  cr = KhepriBase.b_stroke(b, c, KhepriBase.void_ref(b))
  try
    points = @remote(b, CurveCurveIntersectionPoints(ar, cr, opts.tolerance))
    polylines = @remote(b, CurveCurveIntersectionPolylines(ar, cr, opts.tolerance, RH_GEOMETRY_INTERSECTION_SAMPLES))
    rhino_intersection_set(a, c, points, polylines, opts; curve_kind=:overlap)
  finally
    rhino_delete_temp_refs(b, ar, cr)
  end
end

function KhepriBase.b_intersections(b::RH, curve::Path, surface::SurfaceGeometry, opts::GeometryOperationOptions)
  cr = KhepriBase.b_stroke(b, curve, KhepriBase.void_ref(b))
  sr = KhepriBase.b_surface(b, surface, KhepriBase.void_ref(b))
  try
    points = @remote(b, CurveBrepIntersectionPoints(cr, sr, opts.tolerance))
    polylines = @remote(b, CurveBrepIntersectionPolylines(cr, sr, opts.tolerance, RH_GEOMETRY_INTERSECTION_SAMPLES))
    rhino_intersection_set(curve, surface, points, polylines, opts; curve_kind=:overlap)
  finally
    rhino_delete_temp_refs(b, cr, sr)
  end
end

function KhepriBase.b_intersections(b::RH, surface::SurfaceGeometry, curve::Path, opts::GeometryOperationOptions)
  cr = KhepriBase.b_stroke(b, curve, KhepriBase.void_ref(b))
  sr = KhepriBase.b_surface(b, surface, KhepriBase.void_ref(b))
  try
    points = @remote(b, CurveBrepIntersectionPoints(cr, sr, opts.tolerance))
    polylines = @remote(b, CurveBrepIntersectionPolylines(cr, sr, opts.tolerance, RH_GEOMETRY_INTERSECTION_SAMPLES))
    rhino_intersection_set(surface, curve, points, polylines, opts; curve_kind=:overlap)
  finally
    rhino_delete_temp_refs(b, cr, sr)
  end
end

function KhepriBase.b_intersections(b::RH, a::SurfaceGeometry, c::SurfaceGeometry, opts::GeometryOperationOptions)
  ar = KhepriBase.b_surface(b, a, KhepriBase.void_ref(b))
  cr = KhepriBase.b_surface(b, c, KhepriBase.void_ref(b))
  try
    points = @remote(b, BrepBrepIntersectionPoints(ar, cr, opts.tolerance))
    polylines = @remote(b, BrepBrepIntersectionPolylines(ar, cr, opts.tolerance, RH_GEOMETRY_INTERSECTION_SAMPLES))
    rhino_intersection_set(a, c, points, polylines, opts; curve_kind=:section)
  finally
    rhino_delete_temp_refs(b, ar, cr)
  end
end

function KhepriBase.b_section(b::RH, a, c, opts::GeometryOperationOptions)
  r = KhepriBase.b_intersections(b, a, c, opts)
  IntersectionSet(a, c, IntersectionElement[e for e in r.elements if e isa CurveIntersection];
                  tolerance=r.tolerance, method=r.method, exactness=r.exactness)
end

function KhepriBase.b_project_geometry(b::RH, p::Loc, target::Path, opts::GeometryOperationOptions)
  tr = KhepriBase.b_stroke(b, target, KhepriBase.void_ref(b))
  try
    projected = @remote(b, CurveClosestPoint(tr, p))
    t = @remote(b, CurveClosestParameter(tr, p))
    ProjectionResult(p, target, projected, (target=t,), distance(p, projected),
                     :backend, :toleranced)
  finally
    rhino_delete_temp_refs(b, tr)
  end
end

function KhepriBase.b_project_geometry(b::RH, p::Loc, target::SurfaceGeometry, opts::GeometryOperationOptions)
  tr = KhepriBase.b_surface(b, target, KhepriBase.void_ref(b))
  try
    projected = @remote(b, BrepClosestPoint(tr, p))
    ProjectionResult(p, target, projected, (;), distance(p, projected),
                     :backend, :toleranced)
  finally
    rhino_delete_temp_refs(b, tr)
  end
end

function KhepriBase.b_closest_points(b::RH, p::Loc, target::Path, opts::GeometryOperationOptions)
  proj = KhepriBase.b_project_geometry(b, p, target, opts)
  ClosestPointsResult(p, proj.geometry, nothing, get(proj.parameters, :target, nothing),
                      proj.distance, proj.method, proj.exactness)
end

KhepriBase.b_closest_points(b::RH, target::Path, p::Loc, opts::GeometryOperationOptions) =
  let r = KhepriBase.b_closest_points(b, p, target, opts)
    ClosestPointsResult(r.second, r.first, r.second_parameter, r.first_parameter,
                        r.distance, r.method, r.exactness)
  end

function KhepriBase.b_closest_points(b::RH, p::Loc, target::SurfaceGeometry, opts::GeometryOperationOptions)
  proj = KhepriBase.b_project_geometry(b, p, target, opts)
  ClosestPointsResult(p, proj.geometry, nothing, nothing,
                      proj.distance, proj.method, proj.exactness)
end

KhepriBase.b_closest_points(b::RH, target::SurfaceGeometry, p::Loc, opts::GeometryOperationOptions) =
  let r = KhepriBase.b_closest_points(b, p, target, opts)
    ClosestPointsResult(r.second, r.first, r.second_parameter, r.first_parameter,
                        r.distance, r.method, r.exactness)
  end

function KhepriBase.b_closest_points(b::RH, a::Path, c::Path, opts::GeometryOperationOptions)
  ar = KhepriBase.b_stroke(b, a, KhepriBase.void_ref(b))
  cr = KhepriBase.b_stroke(b, c, KhepriBase.void_ref(b))
  try
    pts = @remote(b, CurveCurveClosestPoints(ar, cr))
    params = @remote(b, CurveCurveClosestParameters(ar, cr))
    ClosestPointsResult(pts[1], pts[2], params[1], params[2],
                        distance(pts[1], pts[2]), :backend, :toleranced)
  finally
    rhino_delete_temp_refs(b, ar, cr)
  end
end

function KhepriBase.b_classify_geometry(b::RH, path::Path, p::Loc, opts::GeometryOperationOptions)
  pr = KhepriBase.b_stroke(b, path, KhepriBase.void_ref(b))
  try
    @remote(b, CurvePointClassification(pr, p, opts.tolerance)) == 1 ? :on : :outside
  finally
    rhino_delete_temp_refs(b, pr)
  end
end

function KhepriBase.b_classify_geometry(b::RH, surface::SurfaceGeometry, p::Loc, opts::GeometryOperationOptions)
  sr = KhepriBase.b_surface(b, surface, KhepriBase.void_ref(b))
  try
    code = @remote(b, BrepPointClassification(sr, p, opts.tolerance))
    code == 1 ? :inside : code == 2 ? :boundary : :outside
  finally
    rhino_delete_temp_refs(b, sr)
  end
end

KhepriBase.b_surface_mesh(b::RH, vertices, faces, mat) =
  let ensure_4(v) = length(v) == 4 ? v : [v..., v[3]]
    @remote(b, Mesh(vertices, map(face->ensure_4(face.-1), faces), mat))
  end

# OBJ/MTL file import — uses Rhino's native import via ImportOBJ API.
KhepriBase.b_mesh_obj_fmt(b::RH, obj_name, transform) =
  let path = abspath(obj_file_path(obj_name)),
      t = transform.cs.transform,
      origin = xyz(t[1,4], t[2,4], t[3,4]),
      vx = vxyz(t[1,1], t[2,1], t[3,1]),
      vy = vxyz(t[1,2], t[2,2], t[3,2]),
      vz = vxyz(t[1,3], t[2,3], t[3,3])
    @remote(b, ImportOBJ(path, origin, vx, vy, vz))
  end

############################################################
# Third tier: solids

KhepriBase.b_solidify(b::RH, refs) = refs
  

# PrismWithHoles creates a closed solid with one material applied to all
# faces. Use smat (the side material) — bmat/tmat are top/bottom caps that
# fall through as `nothing` from the default b_extruded_curve(::CircularPath)
# fallback in KhepriBase, which then crashes the MatId encoder. Matches the
# AutoCAD convention.
KhepriBase.b_generic_prism(b::RH, bs, smooth, v, bmat, tmat, smat) =
  @remote(b, PrismWithHoles([bs], [smooth], v, smat))

KhepriBase.b_generic_prism_with_holes(b::RH, bs, smooth, bss, smooths, v, bmat, tmat, smat) =
  @remote(b, PrismWithHoles([bs, bss...], [smooth, smooths...], v, smat))

#= IrregularPyramidFrustum is a single-material native solid: it applies one
material to the whole frustum. The conventional representative for a
single-material solid is the side material `smat`, matching AutoCAD
(b_pyramid_frustum -> smat), Unity, and Revit, and the KhepriBase fallback
`b_generic_pyramid_frustum`, where the side faces (b_quad_strip_closed) take
`smat`. Previously this passed `tmat`, making the same frustum render with a
different face material on Rhino than on every other backend. =#
KhepriBase.b_pyramid_frustum(b::RH, bs, ts, bmat, tmat, smat) =
  @remote(b, IrregularPyramidFrustum(bs, ts, smat))

KhepriBase.b_pyramid(b::RH, bs, t, bmat, smat) =
  @remote(b, IrregularPyramid(bs, t, smat))

KhepriBase.b_cylinder(b::RH, c, r, h, bmat, tmat, smat) =
  isnothing(bmat) || isnothing(tmat) ?
    vcat(@remote(b, Extrusion(b_circle(b, c, r, smat), vz(h, c.cs))),
         isnothing(bmat) ? [] : b_surface_circle(b, c, r, bmat),
         isnothing(tmat) ? [] : b_surface_circle(b, add_z(c, h), r, tmat)) :
  @remote(b, Cylinder(c, r, add_z(c, h), smat))

KhepriBase.b_cuboid(b::RH, pb0, pb1, pb2, pb3, pt0, pt1, pt2, pt3, mat) =
  b_pyramid_frustum(b, [pb0, pb1, pb2, pb3], [pt0, pt1, pt2, pt3], mat, mat, mat)

KhepriBase.b_box(b::RH, c, dx, dy, dz, mat) =
  @remote(b, Box(c, vx(1, c.cs), vy(1, c.cs), dx, dy, dz, mat))

KhepriBase.b_sphere(b::RH, c, r, mat) =
	@remote(b, Sphere(c, r, mat))

KhepriBase.b_cone(b::RH, cb, r, h, bmat, smat) =
  @remote(b, Cone(add_z(cb, h), r, cb, smat))

KhepriBase.b_cone_frustum(b::RH, cb, rb, h, rt, bmat, tmat, smat) =
  @remote(b, ConeFrustum(cb, rb, cb + vz(h, cb.cs), rt, smat))

KhepriBase.b_text(b::RH, str, c, size, mat) =
  @remote(b, Text(str, c, size, "ISOCP", false, false))

## Materials
# To encode materials, we use a Guid but convert it to an int,
# taking into consideration that Guid(int) = int + 1
encode(ns::Val{:RH}, t::Val{:MatId}, c::IO, v) =
  encode(ns, Val(:int), c, v%Int32 - 1)
decode(ns::Val{:RH}, t::Val{:MatId}, c::IO) =
  (decode(ns, Val(:int), c) + 1)%Guid

KhepriBase.b_get_material(b::RH, path::String) =
  @remote(b, LoadRenderMaterialFromPath(path))

struct RhinoDefaultMaterial
  name::String
end

export rhino_default_material
rhino_default_material = RhinoDefaultMaterial

KhepriBase.b_get_material(b::RH, mat::RhinoDefaultMaterial) =
  b_get_material(b, joinpath(@remote(b, DefaultMaterialsFolder()), mat.name*".rmtl"))

# Rhino's RMI exposes `CreateMaterial` (legacy diffuse / specular / ambient /
# emission / reflection / reflectivity / glossiness / refraction-index /
# transparency), not the `new_material` referenced before this fix. Map PBR
# parameters to legacy approximations: metallic → reflectivity (the 0..1
# strength of the specular reflection), roughness → 1 - glossiness,
# transmission → transparency, emission_color → emission. Specular/clearcoat
# are folded into the reflection magnitude. This is a coarse mapping but
# yields plausible visual output and unblocks the b_material code path.
KhepriBase.b_material(b::RH, name, base_color, metallic, roughness, specular,
                           ior, transmission, transmission_roughness,
                           clearcoat, clearcoat_roughness,
                           emission_color, emission_strength) =
  let diffuse = convert(RGBA, base_color),
      black = RGBA(0.0, 0.0, 0.0, 1.0),
      reflection = diffuse,                 # tint reflections with base color (metallic look)
      reflectivity = clamp(metallic + clearcoat * 0.5, 0.0, 1.0),
      glossiness = clamp(1.0 - roughness, 0.0, 1.0),
      emission = convert(RGBA, emission_color)
    @remote(b, CreateMaterial(name, diffuse, diffuse, black, emission, reflection,
                              reflectivity, glossiness, ior, transmission))
  end

KhepriBase.b_plastic_material(b::RH, name, color, roughness) =
  let c = convert(RGBA, color),
      black = RGBA(0.0, 0.0, 0.0, 1.0)
    @remote(b, CreateMaterial(name, c, c, black, black, black,
                              0.0, 1.0 - roughness, 1.4, 0.0))
  end

KhepriBase.b_metal_material(b::RH, name, color, roughness, ior) =
  let c = convert(RGBA, color),
      black = RGBA(0.0, 0.0, 0.0, 1.0)
    @remote(b, CreateMaterial(name, c, c, black, black, c,
                              1.0, 1.0 - roughness, ior, 0.0))
  end

KhepriBase.b_glass_material(b::RH, name, color, roughness, ior) =
  let c = convert(RGBA, color),
      black = RGBA(0.0, 0.0, 0.0, 1.0)
    @remote(b, CreateMaterial(name, c, c, black, black, c,
                              0.5, 1.0 - roughness, ior, 0.9))
  end

KhepriBase.b_mirror_material(b::RH, name, color) =
  let c = convert(RGBA, color),
      black = RGBA(0.0, 0.0, 0.0, 1.0)
    @remote(b, CreateMaterial(name, black, black, black, black, c,
                              1.0, 1.0, 1.0, 0.0))
  end

b_map_division(b::RH, f::Function, s::Shape1D, n::Int) =
  let conn = connection(b),
      r = ref_value(b, s),
      (t1, t2) = @remote(b, CurveDomain(r)),
      ti = division(t1, t2, n),
      ps = @remote(b, CurvePointsAt(r, ti)),
      ts = @remote(b, CurveTangentsAt(r, ti)),
      #ns = ACADCurveNormalsAt(conn, r, ti),
      frames = rotation_minimizing_frames(@remote(b, CurveFrameAt(r, t1)), ps, ts)
    map(f, frames)
  end

b_surface_domain(b::RH, s::Shape2D) =
    tuple(@remote(b, SurfaceDomain(ref(b, s).value))...)

b_map_division(b::RH, f::Function, s::Shape2D, nu::Int, nv::Int) =
    let conn = connection(b)
        r = ref_value(b, s)
        (u1, u2, v1, v2) = @remote(b, SurfaceDomain(r))
        map_division(u1, u2, nu) do u
            map_division(v1, v2, nv) do v
                f(@remote(b, SurfaceFrameAt(r, u, v)))
            end
        end
    end

KhepriBase.b_torus(b::RH, c, ra, rb, mat) =
  @remote(b, Torus(c, vz(1, c.cs), ra, rb, mat))

KhepriBase.b_extruded_curve(b::RH, s::Shape1D, v, cb, mat) =
  and_mark_deleted(b,
      map_ref(b, s) do r
          @remote(b, Extrusion(r, v))
      end,
      s)

KhepriBase.b_extruded_surface(b::RH, s::Shape2D, v, cb, mat) =
   and_mark_deleted(b,
      map_ref(b, s) do r
          @remote(b, Extrusion(r, v))
      end,
      s)

# Region-profile extrusion produces a closed Brep (solid) directly from
# Rhino's Extrusion of a Region entity, instead of the default in
# KhepriBase/Backend.jl that decomposes outer/inner curves and surface caps
# (a multi-Brep assembly that downstream CSG cannot consume).
#
# `cb` is the base location of the extrusion. Callers (e.g. `b_column`,
# `b_beam`, `b_slab`) pass a profile centered at the world origin plus the
# target position in `cb`; the profile itself carries no XY/Z offset. We
# must apply `path_on(profile, cb)` before realizing the curve, otherwise
# every extruded primitive collapses onto the world origin regardless of
# the requested location. The default Region implementation in Backend.jl
# makes the same move on its top/bottom caps; this override mirrors that
# contract.
KhepriBase.b_extruded_surface(b::RH, profile::Region, v, cb, mat) =
  let curve_mat = material_ref(b, default_curve_material()),
      r = b_realize_path(b, path_on(profile, cb), curve_mat)
    @remote(b, Extrusion(r, v))
  end
KhepriBase.b_extruded_surface(b::RH, profile::Region, v, cb, bmat, tmat, smat) =
  b_extruded_surface(b, profile, v, cb, smat)
KhepriBase.b_extruded_curve(b::RH, profile::Region, v, cb, mat) =
  b_extruded_surface(b, profile, v, cb, mat)

#
#KhepriBase.b_sweep_curve(b::RH, path::Path, profile::Path, rotation, scale, mat) =

rhino_sweep(b, path, profile, rotation, scale, mat) =
  and_mark_deleted(b,
    map_ref(b, profile) do profile_r
        map_ref(b, path) do path_r
          @remote(b, SweepPathProfile(path_r, profile_r, rotation, scale))
        end
      end,
    [path, profile])

KhepriBase.b_swept_curve(b::RH, path::Shape1D, profile::Shape1D, rotation, scale, mat) =
  rhino_sweep(b, path, profile, rotation, scale, mat)
KhepriBase.b_swept_surface(b::RH, path::Shape1D, profile::Shape2D, rotation, scale, mat) =
  rhino_sweep(b, path, profile, rotation, scale, mat)

# Path-typed overload: when the user passes raw Path objects (e.g.,
# closed_spline_path(...)) instead of constructing Shape1D wrappers, realize
# the paths first and call the plugin's SweepPathProfile directly. Without
# this, dispatch falls through to a default that tries `convert(Shape, path)`
# and fails.
KhepriBase.b_swept_curve(b::RH, path::Path, profile::Path, rotation, scale, mat) =
  let curve_mat = material_ref(b, default_curve_material()),
      path_r = b_realize_path(b, path, curve_mat),
      profile_r = b_realize_path(b, profile, curve_mat)
    @remote(b, SweepPathProfile(path_r, profile_r, rotation, scale))
  end

# Loft-to-point: emit profile + endpoint as cross-sections to Rhino's Loft
# with ruled=true / closed=false (the apex is a degenerate cross-section).
# The default b_loft_curve_point in KhepriBase has wrong arity (3 args, no
# mat) and references an undefined `mat` symbol — broken for any backend
# called via the high-level `loft(curve, point)`.
KhepriBase.b_loft_curve_point(b::RH, profile, point, mat) =
  and_delete_shapes(
    @remote(b, Loft(vcat(ref_values(b, profile), ref_values(b, point)),
                    UInt128[], true, false)),
    [profile, point])

# Surface-to-point loft: Rhino's Loft plugin rejects closed-Brep cross-sections,
# so realize the surface's boundary path as a curve, loft that to the point.
# Result is the conical lateral surface (top cap is implicit at the apex; the
# bottom surface, if needed, is left as the original profile).
KhepriBase.b_loft_surface_point(b::RH, profile, point, mat) =
  let curve_mat = material_ref(b, default_curve_material()),
      boundary_r = b_realize_path(b, shape_path(profile), curve_mat)
    and_delete_shapes(
      @remote(b, Loft(vcat([boundary_r], ref_values(b, point)),
                      UInt128[], true, false)),
      [profile, point])
  end

#=
Native revolve via the plugin's `Revolve` (Rhino.jl line 219, C# line 1560 of
KhepriRhinoceros/Primitives.cs). Without these overrides the default in
KhepriBase/Backend.jl converts the input to a Path (`convert(Path, profile)`),
which for a Surface with spline frontiers produces an OpenSplinePath whose
`path_length` is undefined — surfacing as `MethodError: no method matching
path_length(::OpenSplinePath)` for aula08_barril and friends. The pattern
mirrors AutoCAD's `acad_revolve` (KhepriAutoCAD/src/AutoCAD.jl:892): walk the
existing Shape refs via `map_ref` for Shape inputs, realize the path via
`b_realize_path` for Region inputs.

Note: AutoCAD's RevolveWithMaterial flips the sign of `amplitude` to match
its rotation convention; Rhino's Revolve uses the same sign as Khepri, so
the override passes `amplitude` through unchanged. (The original commented-
out `realize(b::RH, s::Revolve)` at line 680 confirmed this.)
=#
# Only override for Shape inputs. Region inputs fall through to the default
# `b_revolved_*(b::Backend, ...)` which decomposes outer + inner paths and
# revolves each via b_surface_grid — that path correctly handles a Region
# with hole (e.g. `revolve_region_with_hole`), whereas the C# plugin's
# `Revolve(profile, ...)` with a Region-as-Brep input throws "Index outside
# bounds of array" for the inner-loop branch (Primitives.cs:1604-1608).
KhepriBase.b_revolved_point(b::RH, profile::Union{Loc,Point,Shape0D}, p, n, start_angle, amplitude, mat) =
  b_arc(b, loc_from_o_vz(p, n), distance(point_position(profile), p), start_angle, amplitude, mat)
KhepriBase.b_revolved_curve(b::RH, profile::Shape, p, n, start_angle, amplitude, mat) =
  rhino_revolve(b, profile, p, n, start_angle, amplitude, mat)
KhepriBase.b_revolved_surface(b::RH, profile::Shape, p, n, start_angle, amplitude, mat) =
  rhino_revolve(b, profile, p, n, start_angle, amplitude, mat)

rhino_revolve(b::RH, profile::Shape, p, n, start_angle, amplitude, mat) =
  and_delete_shape(
    map_ref(b, profile) do r
      @remote(b, Revolve(r, p, n, start_angle, amplitude))
    end,
    profile)

KhepriBase.b_subtract_ref(b::RH, s, r) =
  @remote(b, Subtract(s, r))

KhepriBase.b_intersect_ref(b::RH, s, r) =
  @remote(b, Intersect(s, r))

KhepriBase.b_unite_refs(b::RH, rs) =
  @remote(b, Unite(rs))

# JoinCurves merges curve refs into a single curve (used by
# b_stroke(::PathSequence) via b_stroke_unite). Default b_stroke_unite would
# call b_unite_refs (above) which is a Brep boolean-union and rejects curve
# inputs.
KhepriBase.b_stroke_unite(b::RH, refs, mat) =
  length(refs) == 1 ? refs[1] : @remote(b, JoinCurves(refs))

KhepriBase.b_slice_ref(b::RH, r, p, v) =
  @remote(b, Slice(r, p, v))

realize(b::RH, s::Move) =
  and_mark_deleted(b,
	  map_ref(b, s.shape) do r
      @remote(b, Move(r, s.v))
      r
    end,
    s.shape)

realize(b::RH, s::Scale) =
  and_mark_deleted(b,
    map_ref(b, s.shape) do r
      @remote(b, Scale(r, s.p, s.s))
      r
    end,
	  s.shape)

realize(b::RH, s::Rotate) =
  and_mark_deleted(b,
  	map_ref(b, s.shape) do r
      @remote(b, Rotate(r, s.p, s.v, s.angle))
      r
	  end,
	  s.shape)

realize(b::RH, s::Mirror) =
  and_mark_deleted(b, 
    map_ref(b, s.shape) do r
      @remote(b, Mirror(r, s.p, s.n, false))
    end,
    s.shape)
  
realize(b::RH, s::Thicken) =
  and_mark_deleted(b,
    map_ref(b, s.shape) do r
      @remote(b, Thicken(r, s.thickness))
    end,
    s.shape)

# BIM

# Families

realize(b::RH, f::TableFamily) =
    let bf = get(f.implemented_as, typeof(b), nothing)
      isnothing(bf) ?
        @remote(b, CreateRectangularTableFamily(f.length, f.width, f.height, f.top_thickness, f.leg_thickness)) :
        b_get_family_ref(b, f, bf)
    end
realize(b::RH, f::ChairFamily) =
    let bf = get(f.implemented_as, typeof(b), nothing)
      isnothing(bf) ?
        @remote(b, CreateChairFamily(f.length, f.width, f.height, f.seat_height, f.thickness)) :
        b_get_family_ref(b, f, bf)
    end
realize(b::RH, f::TableChairFamily) =
    let bf = get(f.implemented_as, typeof(b), nothing)
      isnothing(bf) ?
        @remote(b, CreateRectangularTableAndChairsFamily(
            family_ref(b, f.table_family), family_ref(b, f.chair_family),
            f.table_family.length, f.table_family.width,
            f.chairs_top, f.chairs_bottom, f.chairs_right, f.chairs_left,
            f.spacing)) :
        b_get_family_ref(b, f, bf)
    end

KhepriBase.b_table(b::RH, c, angle, family) =
    @remote(b, Table(c, angle, family_ref(b, family)))

KhepriBase.b_chair(b::RH, c, angle, family) =
    @remote(b, Chair(c, angle, family_ref(b, family)))

KhepriBase.b_table_and_chairs(b::RH, c, angle, family) =
    @remote(b, TableAndChairs(c, angle, family_ref(b, family)))

# Lights
KhepriBase.b_pointlight(b::RH, loc, energy, color) =
  @remote(b, PointLight(loc, color, energy))



# Dimensioning

no_props = Dict()
base_props = Dict("TextHeight"=>Float64(0.2))
base_props = Dict("DimensionScale"=>Float64(0.2))
label_props = merge(base_props)
angular_props = merge(base_props)
diametric_props = merge(base_props)

KhepriBase.b_labels(b::RH, p, data, mat) =
  [with(current_layer, layer(mat)) do
    @remote(b, CreateLeaderDimension(txt, p, p+vpol(scale, ϕ), scale, mark, label_props))
   end
   for ((; txt, mat, scale), ϕ, mark)
     in zip(data,
            division(-π/4, 7π/4, length(data), false),
            Iterators.flatten((Iterators.repeated("_DOT", 1), Iterators.repeated("_NONE"))))]

#
KhepriBase.b_radii_illustration(b::RH, c, rs, rs_txts, mats, mat) =
  [with(current_layer, layer(mat)) do
    @remote(b, CreateDiametricDimension(r_txt, c, c+vpol(r, ϕ), c+vpol(0.1, ϕ+pi/2), default_annotation_scale(), "", diametric_props))
   end
   for (r, r_txt, ϕ, mat) in zip(rs, rs_txts, division(π/6, 2π+π/6, length(rs), false), mats)]

# Maybe merge the texts when the radii are the same.
KhepriBase.b_vectors_illustration(b::RH, p, a, rs, rs_txts, mats, mat) =
  [with(current_layer, layer(mat)) do
    @remote(b, CreateDiametricDimension(r_txt, p, p+vpol(r, a), p+vpol(0.1, a+pi/2), default_annotation_scale(), "", diametric_props))
   end
   for (r, r_txt, mat) in zip(rs, rs_txts, mats)]

KhepriBase.b_angles_illustration(b::RH, c, rs, ss, as, r_txts, s_txts, a_txts, mats, mat) =
  let refs = new_refs(b),
      maxr = maximum(rs),
      n = length(rs),
      ars = division(0.2maxr, 0.7maxr, n, false),
      idxs = sortperm(as),
      (rs, ss, as, r_txts, s_txts, a_txts) = (rs[idxs], ss[idxs], as[idxs], r_txts[idxs], s_txts[idxs], a_txts[idxs])
    for (r, ar, s, a, r_txt, s_txt, a_txt, mat) in zip(rs, ars, ss, as, r_txts, s_txts, a_txts, mats)
      with(current_layer, layer(mat)) do
        if !(r ≈ 0.0)
          if !(s ≈ 0.0)
          #  push!(refs, @remote(b, CreateAngularDimension(s_txt, c, ar, 0, s, default_annotation_scale(), 5, no_props)))
            push!(refs, @remote(b, CreateAngularDimension(s_txt, c, c+vpol(0.8*ar, 0), c+vpol(0.8*ar, s), c+vpol(ar, s/2), default_annotation_scale(), "", angular_props)))
          end
          if !(a ≈ 0.0)
          #  push!(refs, @remote(b, CreateAngularDimension(a_txt, c, ar, s, s + a, default_annotation_scale(), 5, no_props)))
          push!(refs, @remote(b, CreateAngularDimension(a_txt, c, c+vpol(0.5*ar, s), c+vpol(0.5*ar, s + a), c+vpol(ar, s+a/2), default_annotation_scale(), "", angular_props)))
          else
            #push!(refs, @remote(b, CreateDiametricDimension(r_txt, c, c+vpol(maxr, s + a), 0.0, default_annotation_scale(), "")))
          end
        end
        #push!(refs, @remote(b, CreateDiametricDimension(r_txt, c, c+vpol(maxr, s + a), 0.0, default_annotation_scale(), "", diametric_props)))
      end
    end
    refs
  end

KhepriBase.b_arcs_illustration(b::RH, c, rs, ss, as, r_txts, s_txts, a_txts, mats, mat) =
  let refs = new_refs(b),
      maxr = maximum(rs),
      n = length(rs),
      ars = division(0.2maxr, 0.7maxr, n, false),
      idxs = sortperm(ss),
      (rs, ss, as, r_txts, s_txts, a_txts) = (rs[idxs], ss[idxs], as[idxs], r_txts[idxs], s_txts[idxs], a_txts[idxs])
    for (i, r, ar, s, a, r_txt, s_txt, a_txt, mat) in zip(1:n, rs, ars, ss, as, r_txts, s_txts, a_txts, mats)
      with(current_layer, layer(mat)) do
        if !(r ≈ 0.0)
          if !(s ≈ 0.0) && ((i == 1) || !(s ≈ ss[i-1] + as[i-1]))
            push!(refs, @remote(b, CreateAngularDimension(s_txt, c, c+vpol(0.8*ar, 0), c+vpol(0.8*ar, s), c+vpol(ar, s/2), default_annotation_scale(), "", angular_props)))
          end
          if !(a ≈ 0.0)
            push!(refs, @remote(b, CreateAngularDimension(a_txt, c, c+vpol(0.8*ar, s), c+vpol(0.8*ar, s + a), c+vpol(ar, s+a/2), default_annotation_scale(), "", angular_props)))
          end
          #push!(refs, @remote(b, CreateDiametricDimension(r_txt, c, c+vpol(maxr, s + a), 0.0, default_annotation_scale(), "", diametric_props)))
        end
      end
    end
    refs
  end

KhepriBase.b_spotlight(b::RH, loc, dir, hotspot, falloff) =
  @remote(b, SpotLight(loc, hotspot, falloff, loc + dir))

KhepriBase.b_ieslight(b::RH, file, loc, dir, alpha, beta, gamma) =
  @remote(b, IESLight(file, loc, loc + dir, vxyz(alpha, beta, gamma)))

KhepriBase.b_arealight(b::RH, loc, dir, size, energy, color) =
  @remote(b, PointLight(loc, color, energy))

############################################

# `bounding_box(shapes)` dispatches to `b_bounding_box` (Shapes.jl). The C#
# `BoundingBox(RhinoObject[])` returns the {min, max} corners; return them as a
# (min, max) Loc tuple, matching KhepriUnreal's convention.
KhepriBase.b_bounding_box(b::RH, shapes::Shapes) =
  let pts = @remote(b, BoundingBox(ref_values(b, shapes)))
    (pts[1], pts[2])
  end

KhepriBase.b_set_view(b::RH, camera, target, lens, aperture) =
  @remote(b, SetView(camera, target, lens))

KhepriBase.b_get_view(b::RH) =
  @remote(b, ViewCamera()), @remote(b, ViewTarget()), @remote(b, ViewLens())

KhepriBase.b_zoom_extents(b::RH) =
  @remote(b, ZoomExtents())

KhepriBase.b_set_view_top(b::RH) =
  @remote(b, SetViewTop())

KhepriBase.b_set_view_size(b::RH, width, height) =
  @remote(b, ViewSize(width, height))

KhepriBase.b_setup_raw_view(b::RH) = begin
  b_set_view_size(b, render_width(), render_height())
  b_view_settings(b; visual_style=:shaded)
end

# Rhino display modes: Wireframe, Shaded, Rendered, Ghosted, XRay, Technical, Artistic, Pen
const rhino_display_modes = Dict(
  :wireframe => "Wireframe",
  :shaded => "Shaded",
  :rendered => "Rendered",
  :realistic => "Rendered",
  :ghosted => "Ghosted",
  :xray => "XRay",
  :technical => "Technical",
  :artistic => "Artistic",
  :pen => "Pen")

KhepriBase.b_view_settings(b::RH; visual_style::Symbol=:shaded, display_mode::Symbol=visual_style) =
  let mode = get(rhino_display_modes, display_mode) do
        error("Unknown Rhino display mode: $display_mode. Options: $(join(keys(rhino_display_modes), ", "))")
      end
    @remote(b, SetViewDisplayMode(mode))
  end

KhepriBase.b_delete_refs(b::RH, refs::Vector{RHId}) =
  @remote(b, DeleteMany(refs))

KhepriBase.b_existing_shape_refs(::RemoteShapeStorage, b::RH) =
  @remote(b, GetAllShapes())

KhepriBase.b_delete_all_shape_refs(b::RH) =
  @remote(b, DeleteAll())

KhepriBase.b_highlight_ref(b::RH, r::RHId) =
  @remote(b, Highlight(r))

KhepriBase.b_unhighlight_ref(b::RH, r::RHId) =
  @remote(b, Unhighlight(r))

KhepriBase.b_unhighlight_all_refs(b::RH) =
  @remote(b, UnhighlightAll())

# Layers
KhepriBase.b_current_layer_ref(b::RH) =
  @remote(b, CurrentLayer())

KhepriBase.b_current_layer_ref(b::RH, layer) =
  @remote(b, SetCurrentLayer(layer))

KhepriBase.b_layer(b::RH, name, visible, color) =
  @remote(b, CreateLayer(name, visible, color))

KhepriBase.b_delete_all_shapes_in_layer(b::RH, layer) =
  @remote(b, DeleteAllInLayer(layer))

KhepriBase.b_set_layer_material(b::RH, layer_ref, mat_ref) =
  @remote(b, SetLayerMaterial(layer_ref, mat_ref))

KhepriBase.b_set_layer_visible(b::RH, layer, visible) =
  @remote(b, SetLayerVisible(layer, visible))
KhepriBase.b_set_layer_opacity(b::RH, layer, opacity) =
  @remote(b, SetLayerTransparency(layer, opacity))

KhepriBase.b_create_layer_from_ref_value(b::RH, r) =
  let name = @remote(b, LayerName(r)),
      c = @remote(b, LayerColor(r)),
      visible = @remote(b, LayerVisible(r))
    layer(name, visible, rgb(c.r, c.g, c.b))
  end

# Like AutoCAD: b_shape_from_ref delegates to the caching reconstruction path
# (get_or_create_shape_from_ref_value -> b_create_shape_from_ref_value) so the single
# implementation below serves both captured_shape replay and selection of untraced shapes.
KhepriBase.b_shape_from_ref(b::RH, r) = get_or_create_shape_from_ref_value(b, r)

KhepriBase.b_create_shape_from_ref_value(b::RH, r) =
  let code = @remote(b, ShapeCode(r))
    if code == 1
      point(@remote(b, PointPosition(r)))
    elseif code == 2
      circle(loc_from_o_vz(@remote(b, CircleCenter(r)), @remote(b, CircleNormal(r))),
             @remote(b, CircleRadius(r)))
    elseif 3 <= code <= 6
      line(@remote(b, LineVertices(r)))
    elseif code == 7
      spline(@remote(b, CurveSamplePoints(r, 16)))
    elseif code == 8
      ellipse(@remote(b, EllipsePlane(r)),
              @remote(b, EllipseRadiusX(r)),
              @remote(b, EllipseRadiusY(r)))
    elseif code == 9
      let start_angle = mod(@remote(b, ArcStartAngle(r)), 2pi),
          end_angle = mod(@remote(b, ArcEndAngle(r)), 2pi)
        arc(loc_from_o_vz(@remote(b, ArcCenter(r)), @remote(b, ArcNormal(r))),
            @remote(b, ArcRadius(r)), start_angle, mod(end_angle - start_angle, 2pi))
      end
    elseif 103 <= code <= 106
      polygon(@remote(b, LineVertices(r)))
    elseif code == 107
      closed_spline(@remote(b, CurveSamplePoints(r, 16))[1:end-1])
    elseif code == 40
      # FIXME: frontier is missing
      surface(frontier=[])
    elseif code == 41
      surface(frontier=[])
    elseif code == 81
      sphere()
    elseif code == 82
      cylinder()
    elseif code == 83
      cone()
    elseif code == 84
      torus()
    else
      error("Unknown shape")
    end
  end

#

KhepriBase.b_select_position(b::RH, prompt::String) =
  begin
    @info "$(prompt) on the $(b) backend."
    let ans = @remote(b, GetPosition(prompt))
      length(ans) > 0 ? ans[1] : nothing
    end
  end

KhepriBase.b_select_positions(b::RH, prompt::String) =
  let ps = Loc[]
      p = nothing
    @info "$(prompt) on the $(b) backend."
    while ((p = @remote(b, GetPosition(prompt)) |> length)) > 0
        push!(ps, p...)
    end
    ps
  end

# HACK: The next operations should receive a set of shapes to avoid re-creating already existing shapes

KhepriBase.b_select_point(b::RH, prompt::String) =
  select_one_with_prompt(prompt, b, @get_remote b GetPoint)
KhepriBase.b_select_points(b::RH, prompt::String) =
  select_many_with_prompt(prompt, b, @get_remote b GetPoints)

KhepriBase.b_select_curve(b::RH, prompt::String) =
  select_one_with_prompt(prompt, b, @get_remote b GetCurve)
KhepriBase.b_select_curves(b::RH, prompt::String) =
  select_many_with_prompt(prompt, b, @get_remote b GetCurves)

KhepriBase.b_select_surface(b::RH, prompt::String) =
  select_one_with_prompt(prompt, b, @get_remote b GetSurface)
KhepriBase.b_select_surfaces(b::RH, prompt::String) =
  select_many_with_prompt(prompt, b, @get_remote b GetSurfaces)

KhepriBase.b_select_solid(b::RH, prompt::String) =
  select_one_with_prompt(prompt, b, @get_remote b GetSolid)
KhepriBase.b_select_solids(b::RH, prompt::String) =
  select_many_with_prompt(prompt, b, @get_remote b GetSolids)

KhepriBase.b_select_shape(b::RH, prompt::String) =
  select_one_with_prompt(prompt, b, @get_remote b GetShape)
KhepriBase.b_select_shapes(b::RH, prompt::String) =
  select_many_with_prompt(prompt, b, @get_remote b GetShapes)

KhepriBase.captured_shape(b::RH, handle) =
  b_shape_from_ref(b, handle)
#
KhepriBase.captured_shapes(b::RH, handles) =
  map(handles) do handle
      b_shape_from_ref(b, handle)
  end

b_generate_captured_shape(b::RH, s::Shape) =
    println("captured_shape(rhino, $(ref(b, s).value))")
b_generate_captured_shapes(b::RH, ss::Shapes) =
  begin
    print("captured_shapes(rhino, [")
    for s in ss
      print(ref(b, s).value)
      print(", ")
    end
    println("])")
  end

KhepriBase.b_all_shapes_in_layer(b::RH, layer) =
  Shape[get_or_create_shape_from_ref_value(b, r) for r in @remote(b, GetAllShapesInLayer(layer))]

# Khepri render quality ranges from -1 to 1
# Rhino render quality ranges from 0 to 3
# -- shot_view: fast viewport capture (no ray-tracing) --
KhepriBase.b_shot_view(b::RH, path::String) =
  @remote(b, SaveView(render_width(), render_height(), path))

KhepriBase.b_render_and_save_view(b::RH, path::String) =
  let kind = render_kind()
    if kind == :realistic
      let quality = round(Int, (render_quality() + 1)*3/2)
        @remote(b, Render(render_width(), render_height(), quality, path))
      end
    else
      @remote(b, RenderLoadHDRiEnvironment("KhepriStudio", joinpath(@__DIR__, "KhepriStudio.renv")))
      let (camera, target) = (@remote(b, ViewCamera()), @remote(b, ViewTarget())),
          rot = 11π/6 + π/2 - (camera - target).ϕ
        if render_kind() == :white
          @remote(b, ClayRenderWhite("KhepriStudio", rot, render_width(), render_height(), 3, path))
        elseif render_kind() == :black
          @remote(b, ClayRenderBlack("KhepriStudio", rot, render_width(), render_height(), 3, path))
        else
          error("Unknown render kind $kind")
        end
      end
    end
  end

#=
BIM families for Rhino
=#

abstract type RhinoFamily <: Family end

struct RhinoLayerFamily <: RhinoFamily
  name::String
  visible::Bool
  color::RGB
  ref::IdDict{Backend, Any}
end

rhino_layer_family(name, color::RGB=rgb(1,1,1); visible::Bool=true) =
  RhinoLayerFamily(name, visible, color, IdDict{Backend, Any}())

b_get_family_ref(b::RH, f::Family, af::RhinoLayerFamily) =
  b_layer(b, af.name, af.visible, af.color)

KhepriBase.b_realistic_sky(b::RH, date, latitude, longitude, elevation, meridian, turbidity, sun) =
  @remote(b, SunLight(date, latitude, longitude, meridian, turbidity, true))

export run_grasshopper_solver
run_grasshopper_solver() =
  @remote(rhino, RunGrasshopperSolver())

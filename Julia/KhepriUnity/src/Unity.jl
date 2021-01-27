export unity, fast_unity,
       unity_material_family

#
# UNI is a subtype of CS
parse_signature(::Val{:Unity}, sig::T) where {T} = parse_signature(Val(:CS), sig)
encode(::Val{:Unity}, t::Val{T}, c::IO, v) where {T} = encode(Val(:CS), t, c, v)
decode(::Val{:Unity}, t::Val{T}, c::IO) where {T} = decode(Val(:CS), t, c)

# We need some additional Encoders
@encode_decode_as(:Unity, Val{:GameObject}, Val{:size})
@encode_decode_as(:Unity, Val{:Material}, Val{:size})
@encode_decode_as(:Unity, Val{:Color}, Val{:RGB})

encode(::Val{:Unity}, t::Val{:Vector3}, c::IO, p) =
  encode(Val(:CS), Val(:float3), c, raw_point(p)[[1,3,2]])
decode(::Val{:Unity}, t::Val{:Vector3}, c::IO) =
  xyz(decode(Val(:CS), Val(:float3), c)[[1,3,2]]..., world_cs)

#=
encode_Quaternion(c::IO, pv::Union{XYZ, VXYZ}) =
  let tr = pv.cs.transform
    for i in 1:3
      for j in 1:3
        encode_float(c, tr[i,j])
      end
    end
  end
=#

unity_api = @remote_functions :Unity """
public GameObject Trig(Vector3 p0, Vector3 p1, Vector3 p2, Material material)
public GameObject Quad(Vector3 p0, Vector3 p1, Vector3 p2, Vector3 p3, Material material)
public GameObject NGon(Vector3[] ps, Vector3 q, bool smooth, Material material)
public GameObject QuadStrip(Vector3[] ps, Vector3[] qs, bool smooth, bool closed, Material material)
public void SetApplyMaterials(bool apply)
public void SetApplyColliders(bool apply)
public GameObject SurfacePolygon(Vector3[] ps)
public GameObject SurfacePolygonNamed(String name, Vector3[] ps, Material material)
public GameObject SurfacePolygonWithMaterial(Vector3[] ps, Material material)
public GameObject SurfacePolygonWithHolesNamed(string name, Vector3[] contour, Vector3[][] holes, Material material)
public GameObject SurfacePolygonWithHolesWithMaterial(Vector3[] contour, Vector3[][] holes, Material material)
public GameObject SurfacePolygonWithHoles(Vector3[] contour, Vector3[][] holes)
public GameObject SurfaceMeshNamed(String name, Vector3[] vertices, int[] triangles, Material material)
public GameObject SurfaceMeshWithMaterial(Vector3[] vertices, int[] triangles, Material material)
public GameObject SurfaceMesh(Vector3[] vertices, int[] triangles)
public GameObject Text(string txt, Vector3 position, Vector3 vx, Vector3 vy, string fontName, int fontSize)
public GameObject Sphere(Vector3 center, float radius)
public GameObject SphereWithMaterial(Vector3 center, float radius, Material material)
public GameObject PyramidWithMaterial(Vector3[] ps, Vector3 q, Material material)
public GameObject Pyramid(Vector3[] ps, Vector3 q)
public GameObject PyramidFrustum(Vector3[] ps, Vector3[] qs)
public GameObject PyramidFrustumWithMaterial(Vector3[] ps, Vector3[] qs, Material material)
public GameObject ExtrudedContour(Vector3[] contour, bool smoothContour, Vector3[][] holes, bool[] smoothHoles, Vector3 v, Material material)
public GameObject RightCuboid(Vector3 position, Vector3 vx, Vector3 vy, float dx, float dy, float dz, float angle)
public GameObject RightCuboidWithMaterial(Vector3 position, Vector3 vx, Vector3 vy, float dx, float dy, float dz, float angle, Material material)
public GameObject BoxWithMaterial(Vector3 position, Vector3 vx, Vector3 vy, float dx, float dy, float dz, Material material)
public GameObject Box(Vector3 position, Vector3 vx, Vector3 vy, float dx, float dy, float dz)
public GameObject Cylinder(Vector3 bottom, float radius, Vector3 top)
public GameObject CylinderWithMaterial(Vector3 bottom, float radius, Vector3 top, Material material)
public GameObject Unite(GameObject s0, GameObject s1)
public GameObject Intersect(GameObject s0, GameObject s1)
public GameObject Subtract(GameObject s0, GameObject s1)
public void SubtractFrom(GameObject s0, GameObject s1)
public GameObject Canonicalize(GameObject s)
public void Move(GameObject s, Vector3 v)
public void Scale(GameObject s, Vector3 p, float scale)
public void Rotate(GameObject s, Vector3 p, Vector3 n, float a)
public GameObject SurfaceFromGrid(int m, int n, Vector3[] pts, bool closedM, bool closedN, int level)
public GameObject LoadResource(String name)
public Material LoadMaterial(String name)
public Material CurrentMaterial()
public void SetCurrentMaterial(Material material)
public GameObject InstantiateResource(GameObject family, Vector3 pos, Vector3 vx, Vector3 vy, float scale)
public GameObject InstantiateBIMElement(GameObject family, Vector3 pos, float angle)
public GameObject Window(Vector3 position, Quaternion rotation, float dx, float dy, float dz)
public GameObject Shelf(Vector3 position, int rowLength, int lineLength, float cellWidth, float cellHeight, float cellDepth)
public GameObject Slab(Vector3[] contour, Vector3[][] holes, float h, Material material)
public GameObject BeamRectSection(Vector3 position, Vector3 vx, Vector3 vy, float dx, float dy, float dz, float angle, Material material)
public GameObject BeamCircSection(Vector3 bot, float radius, Vector3 top, Material material)
public GameObject Panel(Vector3[] pts, Vector3 n, Material material)
public void SetView(Vector3 position, Vector3 target, float lens)
public Vector3 ViewCamera()
public Vector3 ViewTarget()
public float ViewLens()
public void DeleteAll()
public void DeleteMany(GameObject[] objs)
public GameObject CreateParent(String name, bool active)
public GameObject CurrentParent()
public GameObject SetCurrentParent(GameObject newParent)
public void SetActive(GameObject obj, bool state)
public void DeleteAllInParent(GameObject parent)
public void SwitchToParent(GameObject newParent)
public int SetMaxNonInteractiveRequests(int n)
public void SetNonInteractiveRequests()
public void SetInteractiveRequests()
public GameObject CreateBlockInstance(GameObject block, Vector3 position, Vector3 vx, Vector3 vy, float scale)
public GameObject CreateBlockFromShapes(String name, GameObject[] objs)
public GameObject PointLight(Vector3 position, Color color, float range, float intensity)
public Point3d[] GetPosition(string prompt)
public ObjectId[] GetPoint(string prompt)
public ObjectId[] GetCurve(string prompt)
public ObjectId[] GetSurface(string prompt)
public ObjectId[] GetSolid(string prompt)
public ObjectId[] GetShape(string prompt)
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
public void SetResolution(int width, int height)
public void ScreenShot(String path)
public void SelectGameObjects(GameObject[] objs)
public void StartSelectingGameObject()
public void StartSelectingGameObjects()
public bool EndedSelectingGameObjects()
public int[] SelectedGameObjectsIds(bool existing)
public void SetSun(float altitude, float azimuth)
public string GetRenderResolution()
public float GetCurrentFPS()
public int GetViewTriangleCount()
public int GetViewVertexCount()
public String ShapeType(GameObject s)
public Vector3 SphereCenter(GameObject s)
public float SphereRadius(GameObject s)
"""

abstract type UnityKey end
const UnityId = Int32
const UnityRef = GenericRef{UnityKey, UnityId}
const UnityRefs = Vector{UnityRef}
const UnityEmptyRef = EmptyRef{UnityKey, UnityId}
const UnityNativeRef = NativeRef{UnityKey, UnityId}
const UnityUnionRef = UnionRef{UnityKey, UnityId}
const UnitySubtractionRef = SubtractionRef{UnityKey, UnityId}
const Unity = SocketBackend{UnityKey, UnityId}

KhepriBase.void_ref(b::Unity) = UnityNativeRef(-1)

create_Unity_connection() = connect_to("Unity", unity_port)

const unity = Unity(LazyParameter(TCPSocket, create_Unity_connection), unity_api)

# Traits
#has_boolean_ops(::Type{Unity}) = HasBooleanOps{true}()
KhepriBase.backend_name(b::Unity) = "Unity"
KhepriBase.has_boolean_ops(::Type{Unity}) = HasBooleanOps{false}()
KhepriBase.backend(::UnityRef) = Unity

(backend::Unity)(; apply_materials=true, apply_colliders=true) =
  begin
    @remote(backend, SetApplyMaterials(apply_materials))
    @remote(backend, SetApplyColliders(apply_colliders))
    backend
  end
#
# Primitives
#=
KhepriBase.b_point(b::Unity, p) =
  @remote(b, Point(p))

KhepriBase.b_line(b::Unity, ps, mat) =
  @remote(b, PolyLine(ps))

KhepriBase.b_polygon(b::Unity, ps, mat) =
  @remote(b, ClosedPolyLine(ps))

KhepriBase.b_spline(b::Unity, ps, v0, v1, interpolator, mat) =
  if (v0 == false) && (v1 == false)
    @remote(b, Spline(ps))
  elseif (v0 != false) && (v1 != false)
    @remote(b, SplineTangents(ps, v0, v1))
  else
    @remote(b, SplineTangents(ps,
                 v0 == false ? ps[2]-ps[1] : v0,
                 v1 == false ? ps[end-1]-ps[end] : v1))
  end

KhepriBase.b_closed_spline(b::Unity, ps, mat) =
  @remote(b, ClosedSpline(ps))

KhepriBase.b_circle(b::Unity, c, r, mat) =
  @remote(b, Circle(c, vz(1, c.cs), r))

KhepriBase.b_arc(b::Unity, c, r, α, Δα, mat) =
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
  @remote(b, Ellipse(s.center, vz(1, s.center.cs), s.radius_x, s.radius_y))
=#

KhepriBase.b_trig(b::Unity, p1, p2, p3, mat) =
  @remote(b, Trig(p1, p2, p3, mat))

KhepriBase.b_quad(b::Unity, p1, p2, p3, p4, mat) =
 	@remote(b, Quad(p1, p2, p3, p4, mat))

KhepriBase.b_ngon(b::Unity, ps, pivot, smooth, mat) =
 	@remote(b, NGon(ps, pivot, smooth, mat))

KhepriBase.b_quad_strip(b::Unity, ps, qs, smooth, mat) =
  @remote(b, QuadStrip(ps, qs, smooth, false, mat))

KhepriBase.b_quad_strip_closed(b::Unity, ps, qs, smooth, mat) =
  @remote(b, QuadStrip(ps, qs, smooth, true, mat))

############################################################
# Second tier: surfaces

KhepriBase.b_surface_polygon(b::Unity, ps, mat) =
  @remote(b, SurfacePolygonWithMaterial(ps, mat))

KhepriBase.b_surface_polygon_with_holes(b::Unity, ps, qss, mat) =
  @remote(b, SurfacePolygonWithHolesWithMaterial(ps, qss, mat))

#=

KhepriBase.b_surface_arc(b::Unity, c, r, α, Δα, mat) =
  @remote(b, SurfaceArc(c, vx(1, c.cs), vy(1, c.cs), r, α, α + Δα, mat))

KhepriBase.b_surface_grid(b::Unity, ptss, closed_u, closed_v, smooth_u, smooth_v, interpolator, mat) =
  let (nu, nv) = size(ptss),
      order(n) = min(2*ceil(Int,n/16) + 1, 5)
    @remote(b, SurfaceFromGrid(nu, nv,
                               reshape(permutedims(ptss), :),
                               closed_u, closed_v,
                               smooth_u ? order(nu) : 1,
                               smooth_v ? order(nv) : 1,
							   mat))
  end
#
backend_surface_grid(b::Unity, points, closed_u, closed_v, smooth_u, smooth_v) =
  # we create two surfaces to have normals on both sides
  let ptss = points,
      s1 = size(ptss,1),
      s2 = size(ptss,2),
      refs = UnityId[]
    if smooth_u && smooth_v
      push!(refs, @remote(b, SurfaceFromGrid(s2, s1, reshape(ptss,:), closed_u, closed_v, 2)))
    elseif smooth_u
      for i in 1:(closed_v ? s1 : s1-1)
        push!(refs, @remote(b, SurfaceFromGrid(s2, 2, reshape(ptss[[i,i%s1+1],:],:), closed_u, false, 2)))
      end
    elseif smooth_v
      for i in 1:(closed_u ? s2 : s2-1)
        push!(refs, @remote(b, SurfaceFromGrid(2, s1, reshape(ptss[:,[i,i%s1+1]],:), false, closed_v, 2)))
      end
    else
      for i in 1:(closed_v ? s1 : s1-1)
        for j in 1:(closed_u ? s2 : s2-1)
          push!(refs, @remote(b, SurfaceFromGrid(2, 2, reshape(ptss[[i,i%s1+1],[j,j%s2+1]],:), false, false, 2)))
        end
      end
    end
    refs
  end

backend_surface_mesh(b::Unity, vertices, faces) =
  @remote(b, SurfaceMesh(vertices, vcat(faces...)))

# This is wrong, for sure!
b_surface_ellipse(b::Unity, c, rx, ry) =
   @remote(b, SurfaceEllipse(c, vz(1, c.cs), rx, ry))
=#
############################################################
# Third tier: solids

KhepriBase.b_generic_prism(b::Unity, bs, smooth, v, bmat, tmat, smat) =
	@remote(b, ExtrudedContour(bs, smooth, [], [], v, tmat))

KhepriBase.b_generic_prism_with_holes(b::Unity, bs, smooth, bss, smooths, v, bmat, tmat, smat) =
  @remote(b, ExtrudedContour(bs, smooth, bss, smooths, v, tmat))

KhepriBase.b_pyramid_frustum(b::Unity, bs, ts, bmat, tmat, smat) =
  @remote(b, PyramidFrustumWithMaterial(bs, ts, smat))

KhepriBase.b_pyramid(b::Unity, bs, t, bmat, smat) =
  @remote(b, PyramidWithMaterial(bs, t, smat))

KhepriBase.b_cylinder(b::Unity, c, r, h, bmat, tmat, smat) =
  @remote(b, CylinderWithMaterial(c, r, c + vz(h, c.cs), smat))

KhepriBase.b_box(b::Unity, c, dx, dy, dz, mat) =
  @remote(b, BoxWithMaterial(c, vx(1, c.cs), vy(1, c.cs), dx, dy, dz, mat))

KhepriBase.b_sphere(b::Unity, c, r, mat) =
	@remote(b, SphereWithMaterial(c, r, mat))

# Materials

KhepriBase.b_get_material(b::Unity, ref) =
  get_unity_material(b, ref)

get_unity_material(b, n::Nothing) =
  void_ref(b)
get_unity_material(b, path::String) =
  @remote(b, LoadMaterial(path))


realize(b::Unity, s::EmptyShape) =
  UnityEmptyRef()
realize(b::Unity, s::UniversalShape) =
  UnityUniversalRef()

fast_unity() =
  begin
    @remote(unity, SetApplyMaterials(false))
    @remote(unity, SetApplyColliders(false))
  end

slow_unity() =
  begin
    @remote(unity, SetApplyMaterials(true))
    @remote(unity, SetApplyColliders(true))
  end
#=
realize(b::Unity, s::SurfaceCircle) =
  @remote(b, SurfacePolygon(regular_polygon_vertices(64, s.center, s.radius, 0, true)))
realize(b::Unity, s::SurfaceArc) =
    #@remote(b, SurfaceArc(s.center, vz(1, s.center.cs), s.radius, s.start_angle, s.start_angle + s.amplitude))
    if s.radius == 0
        @remote(b, Point(s.center))
    elseif s.amplitude == 0
        @remote(b, Point(s.center + vpol(s.radius, s.start_angle, s.center.cs)))
    elseif abs(s.amplitude) >= 2*pi
        @remote(b, SurfaceCircle(s.center, vz(1, s.center.cs), s.radius))
    else
        end_angle = s.start_angle + s.amplitude
        if end_angle > s.start_angle
            @remote(b, SurfaceFromCurves(connection(b),
                [@remote(b, Arc(s.center, vz(1, s.center.cs), s.radius, s.start_angle, end_angle)),
                 @remote(b, PolyLine([add_pol(s.center, s.radius, end_angle),
                                              add_pol(s.center, s.radius, s.start_angle)]))])
        else
            @remote(b, SurfaceFromCurves(connection(b),
                [@remote(b, Arc(s.center, vz(1, s.center.cs), s.radius, end_angle, s.start_angle),
                 @remote(b, PolyLine([add_pol(s.center, s.radius, s.start_angle)),
                                              add_pol(s.center, s.radius, end_angle)]))])
        end
    end

#realize(b::Unity, s::SurfaceElliptic_Arc) = @remote(b, Circle(connection(b),
#realize(b::Unity, s::SurfaceEllipse) = @remote(b, Circle(connection(b),
realize(b::Unity, s::Surface) =
  let #ids = map(r->@remote(b, NurbSurfaceFrom(connection(b),r), @remote(b, SurfaceFromCurves(collect_ref(s.frontier))))
      ids = @remote(b, SurfaceFromCurves(collect_ref(s.frontier)))
    foreach(mark_deleted, s.frontier)
    ids
  end
backend_surface_boundary(b::Unity, s::Shape2D) =
    map(shape_from_ref, @remote(b, CurvesFromSurface(ref(s).value)))
# Iterating over curves and surfaces

Unity"public double[] CurveDomain(Entity ent)"
Unity"public double CurveLength(Entity ent)"
Unity"public Frame3d CurveFrameAt(Entity ent, double t)"
Unity"public Frame3d CurveFrameAtLength(Entity ent, double l)"

backend_map_division(b::Unity, f::Function, s::Shape1D, n::Int) =
  let (t1, t2) = curve_domain(s)
    map_division(t1, t2, n) do t
      f(frame_at(s, t))
    end
  end
Unity"public Vector3d RegionNormal(Entity ent)"
Unity"public Point3d RegionCentroid(Entity ent)"
Unity"public double[] SurfaceDomain(Entity ent)"
Unity"public Frame3d SurfaceFrameAt(Entity ent, double u, double v)"

backend_surface_domain(b::Unity, s::Shape2D) =
    tuple(@remote(b, SurfaceDomain(ref(s).value)...))

backend_map_division(b::Unity, f::Function, s::Shape2D, nu::Int, nv::Int) =
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

backend_map_division(b::Unity, f::Function, s::SurfaceGrid, nu::Int, nv::Int) =
    let (u1, u2, v1, v2) = @remote(b, SurfaceDomain(r))
        map_division(u1, u2, nu) do u
            map_division(v1, v2, nv) do v
                f(@remote(b, SurfaceFrameAt(r, u, v)))
            end
        end
    end
=#



realize(b::Unity, s::Text) =
  @remote(b, Text(s.str, s.corner, vz(-1, s.corner.cs), vy(1, s.corner.cs), "Fonts/Inconsolata-Regular", s.height))

backend_right_cuboid(b::Unity, cb, width, height, h, angle, material) =
  isnothing(material) ?
    @remote(b, RightCuboid(cb, vz(1, cb.cs), vx(1, cb.cs), height, width, h, angle)) :
    @remote(b, RightCuboidWithMaterial(cb, vz(1, cb.cs), vx(1, cb.cs), height, width, h, angle, material))

#=
backend_extrusion(b::Unity, s::Shape, v::Vec) =
    and_mark_deleted(
        map_ref(s) do r
            @remote(b, Extrude(r, v))
        end,
        s)

backend_sweep(b::Unity, path::Shape, profile::Shape, rotation::Real, scale::Real) =
  map_ref(profile) do profile_r
    map_ref(path) do path_r
      @remote(b, Sweep(path_r, profile_r, rotation, scale))
    end
  end

realize(b::Unity, s::Revolve) =
  and_delete_shape(
    map_ref(s.profile) do r
      @remote(b, Revolve(r, s.p, s.n, s.start_angle, s.amplitude))
    end,
    s.profile)

backend_loft_curves(b::Unity, profiles::Shapes, rails::Shapes, ruled::Bool, closed::Bool) =
  and_delete_shapes(UnityLoft(connection(b),
                             collect_ref(profiles),
                             collect_ref(rails),
                             ruled, closed),
                    vcat(profiles, rails))

            MAYBE USE THIS
            ruled_surface(s1, s2) =
                let pts1 = map_division(in_world, s1, 20),
                    pts2 = map_division(in_world, s2, 20)
                  iterate_quads((p0, p1, p2, p3)->(surface_polygon([p0,p1,p3]), surface_polygon([p1,p2,p3])),
                                [pts1, pts2])
                end

            ruled_surface(s1, s2)


backend_loft_surfaces(b::Unity, profiles::Shapes, rails::Shapes, ruled::Bool, closed::Bool) =
    backend_loft_curves(b, profiles, rails, ruled, closed)

backend_loft_curve_point(b::Unity, profile::Shape, point::Shape) =
    and_delete_shapes(UnityLoft(connection(b),
                               vcat(collect_ref(profile), collect_ref(point)),
                               [],
                               true, false),
                      [profile, point])

backend_loft_surface_point(b::Unity, profile::Shape, point::Shape) =
    backend_loft_curve_point(b, profile, point)

=#






###
unite_ref(b::Unity, r0::UnityNativeRef, r1::UnityNativeRef) =
    ensure_ref(b, @remote(b, Unite(r0.value, r1.value)))

intersect_ref(b::Unity, r0::UnityNativeRef, r1::UnityNativeRef) =
    ensure_ref(b, @remote(b, Intersect(r0.value, r1.value)))

subtract_ref(b::Unity, r0::UnityNativeRef, r1::UnityNativeRef) =
    let r = @remote(b, Subtract(r0.value, r1.value))
      @remote(b, DeleteMany([r0.value, r1.value]))
      r
    end

#=
subtract_ref(b::Unity, r0::UnityNativeRef, r1::UnityNativeRef) =
    begin
      @remote(b, SubtractFrom(r0.value, r1.value))
      r0.value
    end
=#

#=
slice_ref(b::Unity, r::UnityNativeRef, p::Loc, v::Vec) =
    (@remote(b, Slice(r.value, p, v); r))

slice_ref(b::Unity, r::UnityUnionRef, p::Loc, v::Vec) =
    map(r->slice_ref(b, r, p, v), r.values)

=#
unite_refs(b::Unity, refs::Vector{<:UnityRef}) =
    UnityUnionRef(tuple(refs...))

#
realize(b::Unity, s::UnionShape) =
  let r = foldl((r0,r1)->unite_ref(b,r0,r1), map(ref, s.shapes),
                init=UnityEmptyRef())
    delete_shapes(s.shapes)
    #@remote(b, Canonicalize(r.value))
    r
  end

realize(b::Unity, s::IntersectionShape) =
  let r = foldl((r0,r1)->intersect_ref(b,r0,r1), map(ref, s.shapes),
                init=UnityUniversalRef())
    delete_shapes(s.shapes)
    r
  end

realize(b::Unity, s::Slice) =
  slice_ref(b, ref(s.shape), s.p, s.n)





realize(b::Unity, s::Move) =
  let r = map_ref(s.shape) do r
            @remote(b, Move(r, s.v))
            r
          end
    mark_deleted(s.shape)
    r
  end
#=
realize(b::Unity, s::Transform) =
  let r = map_ref(s.shape) do r
            @remote(b, Transform(r, s.xform))
            r
          end
    mark_deleted(s.shape)
    r
  end
=#
realize(b::Unity, s::Scale) =
  let r = map_ref(s.shape) do r
            @remote(b, Scale(r, s.p, s.s))
            r
          end
    mark_deleted(s.shape)
    r
  end

realize(b::Unity, s::Rotate) =
  let r = map_ref(s.shape) do r
            @remote(b, Rotate(r, s.p, s.v, s.angle))
            r
          end
    mark_deleted(s.shape)
    r
  end

#=
realize(b::Unity, s::Mirror) =
  and_delete_shape(map_ref(s.shape) do r
                    @remote(b, Mirror(r, s.p, s.n, false))
                   end,
                   s.shape)

realize(b::Unity, s::UnionMirror) =
  let r0 = ref(s.shape),
      r1 = map_ref(s.shape) do r
            @remote(b, Mirror(r, s.p, s.n, true))
          end
    UnionRef((r0,r1))
  end

realize(b::Unity, s::Thicken) =
  and_delete_shape(
    map_ref(s.shape) do r
      @remote(b, Thicken(r, s.thickness))
    end,
    s.shape)

# backend_frame_at
backend_frame_at(b::Unity, s::Circle, t::Real) = add_pol(s.center, s.radius, t)

backend_frame_at(b::Unity, c::Shape1D, t::Real) = @remote(b, CurveFrameAt(ref(c).value, t))

#backend_frame_at(b::Unity, s::Surface, u::Real, v::Real) =
    #What should we do with v?
#    backend_frame_at(b, s.frontier[1], u)

#backend_frame_at(b::Unity, s::SurfacePolygon, u::Real, v::Real) =

backend_frame_at(b::Unity, s::Shape2D, u::Real, v::Real) = @remote(b, SurfaceFrameAt(ref(s).value, u, v))

=#

# BIM








# Families

abstract type UnityFamily <: Family end

struct UnityMaterialFamily <: UnityFamily
  name::String
end

unity_material_family(name, pairs...) = UnityMaterialFamily(name)
backend_get_family_ref(b::Unity, f::Family, uf::UnityMaterialFamily) = @remote(b, LoadMaterial(uf.name))

struct UnityResourceFamily <: UnityFamily
  name::String
end

unity_resource_family(name, pairs...) = UnityResourceFamily(name)
backend_get_family_ref(b::Unity, f::Family, uf::UnityResourceFamily) = @remote(b, LoadResource(uf.name))

#=
set_backend_family(default_wall_family(), unity, unity_material_family("Default/Materials/Plaster"))
set_backend_family(default_slab_family(), unity, unity_material_family("Default/Materials/Concrete"))
set_backend_family(default_roof_family(), unity, unity_material_family("Default/Materials/Concrete"))
set_backend_family(default_beam_family(), unity, unity_material_family("Default/Materials/Aluminum"))
set_backend_family(default_column_family(), unity, unity_material_family("Default/Materials/Concrete"))
set_backend_family(default_door_family(), unity, unity_material_family("Default/Materials/Wood"))
set_backend_family(default_panel_family(), unity, unity_material_family("Default/Materials/Glass"))
set_backend_family(default_truss_node_family(), unity, unity_material_family("Default/Materials/Steel"))
set_backend_family(default_truss_bar_family(), unity, unity_material_family("Default/Materials/Steel"))
=#
set_backend_family(default_table_family(), unity, unity_resource_family("Default/Prefabs/Table"))
set_backend_family(default_chair_family(), unity, unity_resource_family("Default/Prefabs/Chair"))
set_backend_family(default_table_chair_family(), unity, unity_resource_family("Default/Prefabs/TableChair"))

#=
set_backend_family(default_curtain_wall_family().panel, unity, unity_material_family("Default/Materials/Glass"))
set_backend_family(default_curtain_wall_family().boundary_frame, unity, unity_material_family("Default/Materials/Steel"))
set_backend_family(default_curtain_wall_family().transom_frame, unity, unity_material_family("Default/Materials/Steel"))
set_backend_family(default_curtain_wall_family().mullion_frame, unity, unity_material_family("Default/Materials/Steel"))
=#

backend_rectangular_table(b::Unity, c, angle, family) =
    @remote(b, InstantiateBIMElement(family_ref(b, family), c, -angle))

backend_chair(b::Unity, c, angle, family) =
    @remote(b, InstantiateBIMElement(family_ref(b, family), c, -angle))

backend_rectangular_table_and_chairs(b::Unity, c, angle, family) =
    @remote(b, InstantiateBIMElement(family_ref(b, family), c, -angle))

############################################
#=
backend_bounding_box(b::Unity, shapes::Shapes) =
  @remote(b, BoundingBox(collect_ref(shapes)))
=#

KhepriBase.b_set_view(b::Unity, camera::Loc, target::Loc, lens::Real, aperture::Real) =
  let c = connection(b)
    @remote(b, SetView(camera, target, lens))
    interrupt_processing(c)
  end

KhepriBase.b_get_view(b::Unity) =
  (@remote(b, ViewCamera()), @remote(b, ViewTarget()), @remote(b, ViewLens()))

zoom_extents(b::Unity) = @remote(b, ZoomExtents())

view_top(b::Unity) = @remote(b, ViewTop())

KhepriBase.b_delete_all_refs(b::Unity) =
  @remote(b, DeleteAll())

backend_delete_shapes(b::Unity, shapes::Shapes) =
  @remote(b, DeleteMany(collect_ref(shapes)))

set_length_unit(unit::String, b::Unity) = nothing # Unused, for now

#=
# Dimensions

const UnityDimensionStyles = Dict(:architectural => "_ARCHTICK", :mechanical => "")

dimension(p0::Loc, p1::Loc, p::Loc, scale::Real, style::Symbol, b::Unity=current_backend()) =
    @remote(b, CreateAlignedDimension(p0, p1, p,
        scale,
        UnityDimensionStyles[style]))

dimension(p0::Loc, p1::Loc, sep::Real, scale::Real, style::Symbol, b::Unity=current_backend()) =
    let v = p1 - p0
        angle = pol_phi(v)
        dimension(p0, p1, add_pol(p0, sep, angle + pi/2), scale, style, b)
    end

=#

# Layers
# Experiment for multiple, simultaneous, alternative layers
# Layers

KhepriBase.b_current_layer(b::Unity) =
  @remote(b, CurrentParent())

KhepriBase.b_current_layer(b::Unity, layer) =
  @remote(b, SetCurrentParent(layer))

KhepriBase.b_layer(b::Unity, name, active, color) =
  let layer = @remote(b, CreateParent(name, active))
    @warn "Ignoring color in create_layer for Unity"
    #@remote(b, SetLayerColor(layer, color.r, color.g, color.b))
    layer
  end
#=
set_layer_active(layer::UnityLayer, status, b::Unity) =
  let c = connection(b)
    @remote(b, SetActive(layer, status))
    interrupt_processing(c)
  end
=#
KhepriBase.b_delete_all_shapes_in_layer(b::Unity, layer) =
  @remote(b, DeleteAllInParent(layer))

switch_to_layer(b::Unity, layer) =
  @remote(b, SwitchToParent(layer))

# To preserve interactiveness during background


preserving_interactiveness(f, b::Unity=current_backend()) =
  let prev = @remote(b, SetMaxNonInteractiveRequests(0))
    f()
    @remote(b, SetMaxNonInteractiveRequests(prev))
  end

# Experiment to speed up things

canonicalize_layer(b::Unity, layer) =
  @remote(b, Canonicalize(layer))

# Materials

UnityMaterial = Int32

current_material(b::Unity)::UnityMaterial =
  @remote(b, CurrentMaterial())

current_material(b::Unity, material::UnityMaterial) =
  @remote(b, SetCurrentMaterial(material))

# Blocks

realize(b::Unity, s::Block) =
  s.shapes == [] ?
    @remote(b, LoadResource(s.name)) :
    @remote(b, Canonicalize(@remote(b, CreateBlockFromShapes(s.name, collect_ref(s.shapes)))))

realize(b::Unity, s::BlockInstance) =
    @remote(b, CreateBlockInstance(
        ref(s.block).value,
        s.loc, vy(1, s.loc.cs), vz(1, s.loc.cs), s.scale))
#=

# Manual process
@time for i in 1:1000 for r in 1:10 circle(x(i*10), r) end end

# Create block...
Khepri.create_block("Foo", [circle(radius=r) for r in 1:10])

# ...and instantiate it
@time for i in 1:1000 Khepri.instantiate_block("Foo", x(i*10), 0) end

=#

# Lights

KhepriBase.b_pointlight(b::Unity, loc::Loc, color::RGB, range::Real, intensity::Real) =
    @remote(b, PointLight(loc, color, range, intensity))
#=
backend_spotlight(b::Unity, loc::Loc, dir::Vec, hotspot::Real, falloff::Real) =
    @remote(b, SpotLight(loc, hotspot, falloff, loc + dir))

backend_ieslight(b::Unity, file::String, loc::Loc, dir::Vec, alpha::Real, beta::Real, gamma::Real) =
    @remote(b, IESLight(file, loc, loc + dir, vxyz(alpha, beta, gamma)))

# User Selection
=#

shape_from_ref(r, b::Unity) =
  let idx = findfirst(s -> r in collect_ref(s), collected_shapes())
    if isnothing(idx)
      let kind = @remote(b, ShapeType(r))
        if kind == "Sphere"
          sphere(@remote(b, SphereCenter(r)), @remote(b, SphereRadius(r)),
                 backend=b, ref=LazyRef(b, UnityNativeRef(r)))
        else
          @warn "No shapes were previously collected (see in_shape_collection)"
          unknown(r, backend=b, ref=LazyRef(b, UnityNativeRef(r), 0, 0))
          #code = @remote(b, ShapeCode(r)),
          #ref = LazyRef(b, UnityNativeRef(r))
          #error("Unknown shape with code $(code)")
        end
      end
    else
      collected_shapes()[idx]
    end
  end
#
#=


select_position(prompt::String, b::Unity) =
  begin
    @info "$(prompt) on the $(b) backend."
    let ans = @remote(b, GetPosition(prompt))
      length(ans) > 0 && ans[1]
    end
  end

select_with_prompt(prompt::String, b::Backend, f::Function) =
  begin
    @info "$(prompt) on the $(b) backend."
    let ans = f(connection(b), prompt)
      length(ans) > 0 && shape_from_ref(ans[1], b)
    end
  end



# HACK: The next operations should receive a set of shapes to avoid re-creating already existing shapes

select_point(prompt::String, b::Unity) =
  select_with_prompt(prompt, b, UnityGetPoint)



select_curve(prompt::String, b::Unity) =
  select_with_prompt(prompt, b, UnityGetCurve)



select_surface(prompt::String, b::Unity) =
  select_with_prompt(prompt, b, UnityGetSurface)



select_solid(prompt::String, b::Unity) =
  select_with_prompt(prompt, b, UnityGetSolid)



select_shape(prompt::String, b::Unity) =
  select_with_prompt(prompt, b, UnityGetShape)




captured_shape(b::Unity, handle) =
  shape_from_ref(@remote(b, GetShapeFromHandle(handle)),
                 b)

generate_captured_shape(s::Shape, b::Unity) =
    println("captured_shape(autocad, $(@remote(b, GetHandleFromShape(ref(s).value)))"))

# Register for notification








register_for_changes(s::Shape, b::Unity) =
    negin
        @remote(b, RegisterForChanges(ref(s).value))
        @remote(b, DetectCancel())
        s
    end

unregister_for_changes(s::Shape, b::Unity) =
    begin
        @remote(b, UnregisterForChanges(ref(s).value))
        @remote(b, UndetectCancel())
        s
    end

waiting_for_changes(s::Shape, b::Unity) =
    ! @remote(b, WasCanceled())

changed_shape(ss::Shapes, b::Unity) =
    let changed = []
        while length(changed) == 0 && ! @remote(b, WasCanceled())
            changed =  @remote(b, ChangedShape())
            sleep(0.1)
        end
        if length(changed) > 0
            shape_from_ref(changed[1], b)
        else
            nothing
        end
    end




# HACK: This should be filtered on the plugin, not here.
all_shapes(b::Unity) =
  Shape[shape_from_ref(r, b)
        for r in filter(r -> @remote(b, ShapeCode(r) != 0, @remote(b, GetAllShapes())))]

all_shapes_in_layer(layer, b::Unity) =
  Shape[shape_from_ref(r, b) for r in @remote(b, GetAllShapesInLayer(layer))]

disable_update(b::Unity) =
  @remote(b, DisableUpdate())

enable_update(b::Unity) =
  @remote(b, EnableUpdate())

# Render

=#



#render exposure: [-3, +3] -> [-6, 21]
convert_render_exposure(b::Unity, v::Real) = -4.05*v + 8.8
#render quality: [-1, +1] -> [+1, +50]
convert_render_quality(b::Unity, v::Real) = round(Int, 25.5 + 24.5*v)

render_view(path::String, b::Unity) =
    let c = connection(b)
      @remote(b, SetResolution(render_width(), render_height()))
      interrupt_processing(c)
      @remote(b, ScreenShot(path))
      interrupt_processing(c)
      path
    end

highlight_shape(s::Shape, b::Unity) =
    @remote(b, SelectGameObjects(collect_ref(s)))

highlight_shapes(ss::Shapes, b::Unity) =
    @remote(b, SelectGameObjects(collect_ref(ss)))


KhepriBase.b_select_position(b::Unity, prompt) =
  begin
    @info "$(prompt) on the $(b) backend."
    @remote(b, StartSelectingPosition())
    let s = u0() # Means not found
      while s == u0()
        sleep(0.1)
        s = @remote(b, SelectedPosition())
      end
      s
    end
  end

selected_game_objects(b) =
  begin
    while ! @remote(b, EndedSelectingGameObjects())
      sleep(0.1)
    end
    @remote(b, SelectedGameObjectsIds(true))
  end

KhepriBase.b_select_shape(b::Unity, prompt::String) =
  select_one_with_prompt(prompt, b, (c, prompt) ->
    begin
      @remote(b, StartSelectingGameObject())
      selected_game_objects(b)
    end)

KhepriBase.b_select_shapes(b::Unity, prompt::String) =
  select_many_with_prompt(prompt, b, (c, prompt) ->
    begin
      @remote(b, StartSelectingGameObjects())
      selected_game_objects(b)
    end)

KhepriBase.b_realistic_sky(b::Unity, altitude, azimuth, turbidity, withsun) =
  @remote(b, SetSun(altitude, azimuth))

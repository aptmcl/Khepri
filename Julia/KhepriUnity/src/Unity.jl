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
const UnityNativeRef = NativeRef{UnityKey, UnityId}
const Unity = SocketBackend{UnityKey, UnityId}

KhepriBase.void_ref(b::Unity) = -1 % Int32

KhepriBase.before_connecting(b::Unity) = nothing #check_plugin()
KhepriBase.after_connecting(b::Unity) =
  begin
    set_material(unity, material_basic, "Default/Materials/White")
    set_material(unity, material_metal, "Default/Materials/Steel")
    set_material(unity, material_glass, "Default/Materials/Glass")
    set_material(unity, material_wood, "Default/Materials/Wood")
    set_material(unity, material_concrete, "Default/Materials/Concrete")
    set_material(unity, material_plaster, "Default/Materials/Plaster")
    set_material(unity, material_grass, "Default/Materials/Grass")
  end

const unity = Unity("Unity", unity_port, unity_api)

# Traits
#has_boolean_ops(::Type{Unity}) = HasBooleanOps{true}()
#KhepriBase.backend_name(b::Unity) = "Unity"
KhepriBase.has_boolean_ops(::Type{Unity}) = HasBooleanOps{false}()
#KhepriBase.backend(::UnityRef) = Unity

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

KhepriBase.b_spline(b::Unity, ps, v0, v1, mat) =
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
  # X<->Z
  @remote(b, BoxWithMaterial(c, vx(1, c.cs), vy(1, c.cs), dz, dy, dx, mat))

KhepriBase.b_sphere(b::Unity, c, r, mat) =
	@remote(b, SphereWithMaterial(c, r, mat))

# Materials

KhepriBase.b_get_material(b::Unity, path::String) =
  @remote(b, LoadMaterial(path))

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

realize(b::Unity, s::Text) =
  @remote(b, Text(s.str, s.corner, vz(-1, s.corner.cs), vy(1, s.corner.cs), "Fonts/Inconsolata-Regular", s.height))

backend_right_cuboid(b::Unity, cb, width, height, h, angle, material) =
  isnothing(material) ?
    @remote(b, RightCuboid(cb, vz(1, cb.cs), vx(1, cb.cs), height, width, h, angle)) :
    @remote(b, RightCuboidWithMaterial(cb, vz(1, cb.cs), vx(1, cb.cs), height, width, h, angle, material))

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

unite_refs(b::Unity, refs::Vector{<:UnityRef}) =
    UnityUnionRef(tuple(refs...))

#=
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
=#
realize(b::Unity, s::Slice) =
  slice_ref(b, ref(b, s.shape), s.p, s.n)


realize(b::Unity, s::Move) =
  let r = map_ref(b, s.shape) do r
            @remote(b, Move(r, s.v))
            r
          end
    mark_deleted(s.shape)
    r
  end
#=
realize(b::Unity, s::Transform) =
  let r = map_ref(b, s.shape) do r
            @remote(b, Transform(r, s.xform))
            r
          end
    mark_deleted(s.shape)
    r
  end
=#
realize(b::Unity, s::Scale) =
  let r = map_ref(b, s.shape) do r
            @remote(b, Scale(r, s.p, s.s))
            r
          end
    mark_deleted(s.shape)
    r
  end

realize(b::Unity, s::Rotate) =
  let r = map_ref(b, s.shape) do r
            @remote(b, Rotate(r, s.p, s.v, s.angle))
            r
          end
    mark_deleted(s.shape)
    r
  end

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

KhepriBase.b_set_view(b::Unity, camera::Loc, target::Loc, lens::Real, aperture::Real) =
  let c = connection(b)
    @remote(b, SetView(camera, target, lens))
    #interrupt_processing(c)
  end

KhepriBase.b_get_view(b::Unity) =
  (@remote(b, ViewCamera()), @remote(b, ViewTarget()), @remote(b, ViewLens()))

zoom_extents(b::Unity) = @remote(b, ZoomExtents())

view_top(b::Unity) = @remote(b, ViewTop())

KhepriBase.b_delete_refs(b::Unity, refs::Vector{UnityId}) =
  @remote(b, DeleteMany(refs))

KhepriBase.b_delete_all_refs(b::Unity) =
  @remote(b, DeleteAll())

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
    @remote(b, Canonicalize(@remote(b, CreateBlockFromShapes(s.name, collect_ref(b, s.shapes)))))

realize(b::Unity, s::BlockInstance) =
    @remote(b, CreateBlockInstance(
        ref(b, s.block).value,
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

KhepriBase.b_pointlight(b::Unity, loc::Loc, color::RGB, intensity::Real, range::Real) =
    @remote(b, PointLight(loc, color, range, intensity))
#=
backend_spotlight(b::Unity, loc::Loc, dir::Vec, hotspot::Real, falloff::Real) =
    @remote(b, SpotLight(loc, hotspot, falloff, loc + dir))

backend_ieslight(b::Unity, file::String, loc::Loc, dir::Vec, alpha::Real, beta::Real, gamma::Real) =
    @remote(b, IESLight(file, loc, loc + dir, vxyz(alpha, beta, gamma)))

# User Selection

shape_from_ref(r, b::Unity) =
  let idx = findfirst(s -> r in collect_ref(b, s), collected_shapes())
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
    @remote(b, SelectGameObjects(collect_ref(b, s)))

highlight_shapes(ss::Shapes, b::Unity) =
    @remote(b, SelectGameObjects(collect_ref(b, ss)))


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

    #=
KhepriBase.b_set_sun_orientation(b::Unity, altitude, azimuth) =
  @remote(b, SetSun(altitude, azimuth))
=#
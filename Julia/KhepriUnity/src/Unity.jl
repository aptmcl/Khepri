export unity, fast_unity,
       unity_material_family,
       unity_concept_mode, unity_analysis_mode,
       unity_showcase_mode, unity_advanced_mode,
       unity_enter_player_mode, unity_exit_player_mode

# Coordinate convention: Unity uses left-handed Y-up.
# Khepri uses right-handed Z-up. The Y-Z swap is done in encode/decode
# of Vector3 below: raw_point(p)[[1,3,2]] swaps Y and Z.

# UNI is a subtype of CS
parse_signature(::Val{:Unity}, sig::T) where {T} = parse_signature(Val(:CS), sig)
encode(::Val{:Unity}, t::Val{T}, c::IO, v) where {T} = encode(Val(:CS), t, c, v)
decode(::Val{:Unity}, t::Val{T}, c::IO) where {T} = decode(Val(:CS), t, c)

# We need some additional Encoders
@encode_decode_as(:Unity, Val{:GameObject}, Val{:size})
@encode_decode_as(:Unity, Val{:Material}, Val{:size})
@encode_decode_as(:Unity, Val{:Color}, Val{:RGB})
@encode_decode_as(:Unity, Val{:Goal_}, Val{:int})

encode(::Val{:Unity}, ::Val{:Vector3}, c::IO, p) =
  let r = world_raw(p)
    write(c, Float32(r[1]))  # X
    write(c, Float32(r[3]))  # Z → Unity Y
    write(c, Float32(r[2]))  # Y → Unity Z
  end
decode(::Val{:Unity}, ::Val{:Vector3}, c::IO) =
  let x = Float64(read(c, Float32)),
      y = Float64(read(c, Float32)),
      z = Float64(read(c, Float32))
    xyz(x, z, y, world_cs)  # Unity Y → Z, Unity Z → Y
  end

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

unity_api = @remote_api :Unity """
public GameObject Line(Vector3[] ps, Material material)
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
public GameObject BoxCompound(string name, Vector3[] centers, Vector3[] vxs, Vector3[] vys, float[] dxs, float[] dys, float[] dzs, Material material)
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
public Material CreateMaterial(String name, Color baseColor, float alpha, float metallic, float specular, float roughness, float ior, float transmission, float transmissionRoughness, float clearcoat, float clearcoatRoughness, Color emissionColor, float emissionStrength)
public Material CurrentMaterial()
public void SetCurrentMaterial(Material material)
public GameObject InstantiateResource(GameObject family, Vector3 pos, Vector3 vx, Vector3 vy, float scale)
public GameObject InstantiateBIMElement(GameObject family, Vector3 pos, float angle)
public GameObject Window(Vector3 position, Quaternion rotation, float dx, float dy, float dz)
public GameObject Shelf(Vector3 position, int rowLength, int lineLength, float cellWidth, float cellHeight, float cellDepth)
public GameObject Slab(Vector3[] contour, bool smoothContour, Vector3[][] holes, bool[] smoothHoles, float h, Material material)
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
public void SetParentOpacity(GameObject parent, float opacity)
public void SwitchToParent(GameObject newParent)
public int SetMaxNonInteractiveRequests(int n)
public void SetNonInteractiveRequests()
public void SetInteractiveRequests()
public GameObject CreateBlockInstance(GameObject block, Vector3 position, Vector3 vx, Vector3 vy, float scale)
public GameObject CreateBlockFromShapes(String name, GameObject[] objs)
public GameObject Solidify(GameObject[] parts)
public GameObject PointLight(Vector3 position, Color color, float range, float intensity)
public Point3d[] GetPosition(string prompt)
public ObjectId[] GetPoint(string prompt)
public ObjectId[] GetCurve(string prompt)
public ObjectId[] GetSurface(string prompt)
public ObjectId[] GetSolid(string prompt)
public void GetShape(string prompt)
public void GetShapes(string prompt)
public void SetResolution(int width, int height)
public void ViewSize(int width, int height)
public void ScreenShot(String path)
public void SelectGameObjects(GameObject[] objs)
public void DeselectGameObjects(GameObject[] objs)
public void DeselectAllGameObjects()
public void StartSelectingGameObject()
public void StartSelectingGameObjects()
public bool EndedSelectingGameObjects()
public int[] SelectedGameObjectsIds(bool existing)
public void SetSun(float altitude, float azimuth)
public String ShapeType(GameObject s)
public Vector3 GameObjectPosition(GameObject s)
public Vector3 SphereCenter(GameObject s)
public float SphereRadius(GameObject s)
public Vector3 BoxPosition(GameObject s)
public Vector3 BoxDimensions(GameObject s)
public Vector3 CylinderBottom(GameObject s)
public Vector3 CylinderTop(GameObject s)
public float CylinderRadius(GameObject s)
public void SetSimAgentSize(float radius, float height)
public void SetSimHSF(float relaxationTime, float maxSpeedCoef, float V, float sigma, float U, float R, float c, float phi)
public void SetSimNone()
public void SetVelGaussHSF(float mean, float stdDev, float min, float max)
public void SetVelUniformHSF(float min, float max)
public void SetVelHSF(float vel)
public int CreateSimGoal(Vector3 pos, Vector3 scale, float rot)
public void CreateSimAgent(Vector3 pos, float rot, int rgb, Goal_[] goals)
public void SpawnAgentsRect(int count, Vector3 center, float dx, float dz, float rot, int rgb, Goal_[] goals)
public void SpawnAgentsEllipse(int count, Vector3 center, float dx, float dz, float rot, int rgb, Goal_[] goals)
public void SpawnAgentsPolygon(int count, float h, int rgb, Goal_[] goals, Vector3[] vertices)
public void StartSimulation(float maxTime)
public void SetSimulationSpeed(float speed)
public bool IsSimulationFinished()
public bool WasSimulationSuccessful()
public float GetEvacuationTime()
public void ResetSimulation()
public void UpdateNavMesh()
public void SetSimRandSeed(int seed)
public void SetNavMeshArea(GameObject obj, int area)
public void SetTag(GameObject obj, String tag)
public void RunSimulation(float maxTime)
public void SetMode(int mode)
public void ConfigurePlayer(float flySpeed, float walkSpeed, float lookSpeed, float gravityMultiplier, float maxFallSpeed, float radius)
public void ConfigureHighlighting(int mode, float r, float g, float b, float width)
public void EnterPlayerMode()
public void ExitPlayerMode()
"""

#= These depend on the editor
public string GetRenderResolution()
public float GetCurrentFPS()
public int GetViewTriangleCount()
public int GetViewVertexCount()
=#
abstract type UnityKey end
const UnityId = Int32
const UnityRef = GenericRef{UnityKey, UnityId}
const UnityRefs = Vector{UnityRef}
const UnityNativeRef = NativeRef{UnityKey, UnityId}
const Unity = SocketBackend{UnityKey, UnityId}
# For users to be able to initialize each of the connections
export Unity

KhepriBase.void_ref(b::Unity) = -1 % Int32

KhepriBase.before_connecting(b::Unity) =
  @info """
  Connecting to Unity on port $(b.port)...
  If Unity is not running with Khepri, use:
    setup_unity()                              # Create new project
    setup_unity("/path/to/your/unity/project") # Install into existing project
  Then open the project in Unity and click 'Start Khepri'.
  """
KhepriBase.after_connecting(b::Unity) =
  set_default_materials()

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

KhepriBase.b_point(b::Unity, p, mat) = (println("Creating point $p with material $mat");
  b_sphere(b, p, 0.01, mat))

KhepriBase.b_line(b::Unity, ps, mat) =
  @remote(b, Line(ps, mat))

#=
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

#=
Fold a multi-surface emission (wall strips/end caps, slab top+bottom+
sides, etc.) into a single Unity GameObject with one MeshCollider.

`refs` is whatever `_b_wall_*_impl` and friends accumulate via
`new_refs(b)` + `collect_ref!`: a `Vector{UnityId}` of raw GameObject
ids. The C# `Solidify` operation combines those parts' meshes
(preserving per-material submeshes), attaches a single MeshCollider,
destroys the originals, and returns the new parent's id. We wrap the
result in a 1-element vector so callers that expect a refs collection
(e.g. `realize(b::Unity, w::Wall)`'s NavMesh tagging loop) keep
working unchanged.

A scalar `void_ref(b)` (returned by zero-length walls in
`_b_wall_no_openings_impl`) is passed through untouched — there is
nothing to solidify.

See also: `KhepriBase.b_solidify` default (`Backend.jl`), the wall
emitters that wrap their returned refs with `b_solidify`.
=#
KhepriBase.b_solidify(b::Unity, refs::AbstractVector) =
  isempty(refs) ? refs : UnityId[@remote(b, Solidify(refs))]

# Materials

set_default_materials() =
  begin
    set_material(Unity, material_curve, "Default/Materials/White")
    set_material(Unity, material_basic, "Default/Materials/White")
    set_material(Unity, material_metal, "Default/Materials/Steel")
    set_material(Unity, material_glass, "Default/Materials/Glass")
    set_material(Unity, material_wood, "Default/Materials/Wood")
    set_material(Unity, material_concrete, "Default/Materials/Concrete")
    set_material(Unity, material_plaster, "Default/Materials/Plaster")
    set_material(Unity, material_grass, "Default/Materials/Grass")
  end

KhepriBase.b_get_material(b::Unity, path::AbstractString) =
  @remote(b, LoadMaterial(path))

KhepriBase.b_material(b::Unity, name, base_color, metallic, roughness, specular,
                          ior, transmission, transmission_roughness,
                          clearcoat, clearcoat_roughness,
                          emission_color, emission_strength) =
  @remote(b, CreateMaterial(name, base_color, Float64(alpha(base_color)),
                            metallic, specular, roughness,
                            ior, transmission, transmission_roughness,
                            clearcoat, clearcoat_roughness,
                            emission_color, emission_strength))

KhepriBase.b_plastic_material(b::Unity, name, color, roughness) =
  @remote(b, CreateMaterial(name, color, Float64(alpha(color)),
                            0.0, 0.5, roughness,
                            1.5, 0.0, 0.0,
                            0.0, 0.0,
                            rgb(0,0,0), 0.0))

KhepriBase.b_metal_material(b::Unity, name, color, roughness, ior) =
  @remote(b, CreateMaterial(name, color, Float64(alpha(color)),
                            1.0, 0.5, roughness,
                            ior, 0.0, 0.0,
                            0.0, 0.0,
                            rgb(0,0,0), 0.0))

KhepriBase.b_glass_material(b::Unity, name, color, roughness, ior) =
  @remote(b, CreateMaterial(name, color, Float64(alpha(color)),
                            0.0, 0.5, roughness,
                            ior, 0.8, 0.0,
                            0.0, 0.0,
                            rgb(0,0,0), 0.0))

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

unity_concept_mode(b=top_backend()) = @remote(b, SetMode(0))
unity_analysis_mode(b=top_backend()) = @remote(b, SetMode(1))
unity_showcase_mode(b=top_backend()) = @remote(b, SetMode(2))
unity_advanced_mode(b=top_backend()) = @remote(b, SetMode(3))
unity_enter_player_mode(b=top_backend()) = @remote(b, EnterPlayerMode())
unity_exit_player_mode(b=top_backend()) = @remote(b, ExitPlayerMode())

KhepriBase.b_text(b::Unity, str, p, size, mat) =
  @remote(b, Text(str, p, vz(-1, p.cs), vy(1, p.cs), "Fonts/Inconsolata-Regular", size))

KhepriBase.b_labels(b::Unity, p, data, mat) =
  [@remote(b, Text(txt, p + vpol(0.2*scale, ϕ), vz(-1, p.cs), vy(1, p.cs), "Fonts/Inconsolata-Regular", scale))
   for ((; txt, mat, scale), ϕ) in zip(data, division(-π/4, 7π/4, length(data), false))]

KhepriBase.b_right_cuboid(b::Unity, cb, width, height, h, mat) =
  isnothing(mat) ?
    @remote(b, RightCuboid(cb, vz(1, cb.cs), vx(1, cb.cs), height, width, h, 0)) :
    @remote(b, RightCuboidWithMaterial(cb, vz(1, cb.cs), vx(1, cb.cs), height, width, h, 0, mat))

###
KhepriBase.b_unite_ref(b::Unity, s, r) =
    @remote(b, Unite(s, r))

KhepriBase.b_intersect_ref(b::Unity, s, r) =
    @remote(b, Intersect(s, r))

KhepriBase.b_subtract_ref(b::Unity, s, r) =
    let result = @remote(b, Subtract(s, r))
      @remote(b, DeleteMany([s, r]))
      result
    end
realize(b::Unity, s::Slice) =
  slice_ref(b, ref(b, s.shape), s.p, s.n)


realize(b::Unity, s::Move) =
  let r = map_ref(b, s.shape) do r
            @remote(b, Move(r, s.v))
            r
          end
    mark_deleted(b, s.shape)
    r
  end
#=
realize(b::Unity, s::Transform) =
  let r = map_ref(b, s.shape) do r
            @remote(b, Transform(r, s.xform))
            r
          end
    mark_deleted(b, s.shape)
    r
  end
=#
realize(b::Unity, s::Scale) =
  let r = map_ref(b, s.shape) do r
            @remote(b, Scale(r, s.p, s.s))
            r
          end
    mark_deleted(b, s.shape)
    r
  end

realize(b::Unity, s::Rotate) =
  let r = map_ref(b, s.shape) do r
            @remote(b, Rotate(r, s.p, s.v, s.angle))
            r
          end
    mark_deleted(b, s.shape)
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

KhepriBase.b_set_view_size(b::Unity, width, height) =
  @remote(b, ViewSize(width, height))

KhepriBase.b_delete_refs(b::Unity, refs::Vector{UnityId}) =
  @remote(b, DeleteMany(refs))

KhepriBase.b_delete_all_shape_refs(b::Unity) =
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

KhepriBase.b_current_layer_ref(b::Unity) =
  @remote(b, CurrentParent())

KhepriBase.b_current_layer_ref(b::Unity, layer) =
  @remote(b, SetCurrentParent(layer))

KhepriBase.b_layer(b::Unity, name, visible, color) =
  let layer = @remote(b, CreateParent(name, visible))
    @warn "Ignoring color in create_layer for Unity"
    #@remote(b, SetLayerColor(layer, color.r, color.g, color.b))
    layer
  end
KhepriBase.b_set_layer_visible(b::Unity, layer, visible) =
  @remote(b, SetActive(ref_value(b, layer), visible))
KhepriBase.b_set_layer_opacity(b::Unity, layer, opacity) =
  @remote(b, SetParentOpacity(ref_value(b, layer), convert(Float32, opacity)))
KhepriBase.b_create_layer_from_ref_value(b::Unity, r) =
  layer("Default")
KhepriBase.b_delete_all_shapes_in_layer(b::Unity, layer) =
  @remote(b, DeleteAllInParent(ref_value(b, layer)))

switch_to_layer(b::Unity, layer) =
  @remote(b, SwitchToParent(layer))

# To preserve interactiveness during background


preserving_interactiveness(f, b::Unity=current_backend()) =
  let prev = @remote(b, SetMaxNonInteractiveRequests(0))
    f()
    @remote(b, SetMaxNonInteractiveRequests(prev))
  end

with_delayed_update(f, b::Unity) =
  let prev = @remote(b, SetMaxNonInteractiveRequests(1000000))
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
    @remote(b, Canonicalize(@remote(b, CreateBlockFromShapes(s.name, ref_values(b, s.shapes)))))

realize(b::Unity, s::BlockInstance) =
    @remote(b, CreateBlockInstance(
        ref_value(b, s.block),
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

KhepriBase.b_ieslight(b::Unity, file, loc, dir, alpha, beta, gamma) =
    @remote(b, PointLight(loc, rgb(1, 1, 1), 10.0, 1500.0))

KhepriBase.b_arealight(b::Unity, loc, dir, size, energy, color) =
    @remote(b, PointLight(loc, color, 10.0, energy))
#=
backend_spotlight(b::Unity, loc::Loc, dir::Vec, hotspot::Real, falloff::Real) =
    @remote(b, SpotLight(loc, hotspot, falloff, loc + dir))

backend_ieslight(b::Unity, file::String, loc::Loc, dir::Vec, alpha::Real, beta::Real, gamma::Real) =
    @remote(b, IESLight(file, loc, loc + dir, vxyz(alpha, beta, gamma)))
=#

# User Selection

KhepriBase.b_shape_from_ref(b::Unity, r) =
  get_or_create_shape_from_ref_value(b, r)

KhepriBase.b_create_shape_from_ref_value(b::Unity, r) =
  let kind = @remote(b, ShapeType(r))
    if kind == "Sphere"
      sphere(@remote(b, SphereCenter(r)), @remote(b, SphereRadius(r)))
    elseif kind == "Box"
      let d = @remote(b, BoxDimensions(r))
        box(@remote(b, BoxPosition(r)), d.x, d.y, d.z)
      end
    elseif kind == "Cylinder"
      let bot = @remote(b, CylinderBottom(r)),
          top = @remote(b, CylinderTop(r))
        cylinder(bot, @remote(b, CylinderRadius(r)), top)
      end
    else
      unknown(r)
    end
  end

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

KhepriBase.b_highlight_refs(b::Unity, rs::Vector{UnityId}) =
  @remote(b, SelectGameObjects(rs))

KhepriBase.b_unhighlight_refs(b::Unity, rs::Vector{UnityId}) =
  @remote(b, DeselectGameObjects(rs))

KhepriBase.b_unhighlight_all_refs(b::Unity) =
  @remote(b, DeselectAllGameObjects())


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

# Deferred selection: GetShape/GetShapes are void RPCs that start selection;
# the result (int[] encoded as length + ids) is sent by SceneLoad when
# the user finishes clicking, similar to RunSimulation.
read_selected_ids(conn) =
  let n = read(conn, Int32)
    Int32[read(conn, Int32) for _ in 1:n]
  end

KhepriBase.b_select_shape(b::Unity, prompt::String) =
  select_one_with_prompt(prompt, b, (c, prompt) ->
    begin
      @remote(b, GetShape(prompt))
      read_selected_ids(c)
    end)

KhepriBase.b_select_shapes(b::Unity, prompt::String) =
  select_many_with_prompt(prompt, b, (c, prompt) ->
    begin
      @remote(b, GetShapes(prompt))
      read_selected_ids(c)
    end)

    #=
KhepriBase.b_set_sun_orientation(b::Unity, altitude, azimuth) =
  @remote(b, SetSun(altitude, azimuth))
=#

# ============================================================
# Agent-based simulation — b_* implementations for Unity
# ============================================================

# NavMesh tagging flag (Julia-side; zero cost when disabled)
const nav_mesh_tagging = Parameter{Bool}(false)

KhepriBase.b_enable_nav_mesh_tagging(b::Unity, enable) =
  nav_mesh_tagging(enable)

# area=0 is Walkable, area=1 is Not Walkable (Unity NavMesh area indices)
KhepriBase.b_set_nav_mesh_area(b::Unity, shape, area) =
  @remote(b, SetNavMeshArea(ref_value(b, shape), area))

set_tag(b::Unity, shape, tag) =
  @remote(b, SetTag(ref_value(b, shape), tag))

KhepriBase.b_update_nav_mesh(b::Unity) =
  @remote(b, UpdateNavMesh())

# Tag a vector of raw refs for NavMesh
tag_refs_nav_mesh(b::Unity, refs, area) =
  for r in (refs isa Vector ? refs : [refs])
    r != void_ref(b) && @remote(b, SetNavMeshArea(r, area))
  end

#=
==============================================================================
BIM box decomposition for KhepriUnity
==============================================================================

Walls, slabs, columns, beams and panels with rectangular geometry are
emitted as compound BoxColliders (one Unity Cube primitive per piece,
parented under a single GameObject) instead of going through the
default surface-decomposition + Solidify path that ends in a
non-convex MeshCollider. The motivating problem is that
`Physics.ClosestPoint` — used by the agent simulation and any
distance-to-obstacle query — refuses non-convex MeshColliders;
walls with openings, slabs with rectangular service shafts, etc.
all fall in that bucket today and silently fail those queries.

The decomposition only fires when the geometry trivially collapses to
boxes; anything more complex (smooth/curved walls, non-rectangular
slab outlines, multi-material BIM elements) falls back to the legacy
path so the visual result is preserved exactly. Multi-material walls
fall back because a Unity Cube has one shared material across all six
faces, so a per-face material distinction can't survive the box
collapse.

`_rectangle_obb` answers "is this closed path a rectangle, and if so
what frame does it have?" — used by slabs, panels and the rectangular-
profile beam/column path. `_decompose_segment_with_openings` is the
shared 1-D rectangle subtraction used by walls (and by slabs whose
inner holes are rectangles): given a [0, segment_length] × [0, height]
rectangle and a list of opening sub-rectangles inside it, return a
sweep of solid sub-rectangles.

The Unity-side BoxCompound RPC takes parallel arrays describing the
boxes' centres, frames and extents and spawns one Cube child per box
under a parent GameObject; the parent is what gets returned to Julia
as the wall/slab ref, mirroring the single-ref shape produced by
Solidify. Selection, Move, Rotate, DeleteMany and NavMesh tagging
all continue to operate on that parent.

See also: BoxCompound in Plugins/KhepriUnity/.../Primitives.cs and
SetNavMeshArea in the same file (which now also tags compound
children with the Obstacle tag for agent steering).
=#

#=
Tolerance for rectangle/perpendicularity tests during box detection.
1e-6 is two orders of magnitude looser than `coincidence_tolerance()`
(1e-10): authoring tools and offset() routines accumulate floating-
point drift that shows up well above 1e-10 in cross-product norms,
and a too-strict test would silently push everything down the
fall-through path. 1e-6 m on architectural geometry is sub-µm — far
below anything visually or physically meaningful.
=#
const _box_decomp_tolerance = 1e-6

#=
Returns (centre, vx, vy, dx, dy) when `path` describes an oriented
rectangle and `nothing` otherwise. (centre, vx, vy) is a frame on the
rectangle's plane with `vx` and `vy` unit vectors along its two edges;
dx, dy are the corresponding edge lengths.

`RectangularPath` is rectangular by construction (the type carries
corner + dx + dy directly) so we read the frame off its fields. For
`ClosedPolygonalPath` we accept exactly four vertices forming a
parallelogram with mutually perpendicular adjacent edges — that's the
rectangle test used everywhere downstream. Anything else (smooth
paths, polygons with more or fewer vertices, near-rectangles outside
tolerance) returns `nothing` and the BIM caller falls back to the
default path.

Why we test `dot(unitized(e0), unitized(e1))` instead of computing a
plane normal and projecting: dot is a scalar, dimensionless, and its
zero-test directly captures perpendicularity at the tolerance. A
normal-vector test would need to also defend against degenerate
vertices (collinear triples) which the parallelogram check already
rules out implicitly.
=#
_rectangle_obb(path::RectangularPath) =
  (centre = path.corner + vxy(path.dx/2, path.dy/2, path.corner.cs),
   vx = vx(1, path.corner.cs),
   vy = vy(1, path.corner.cs),
   dx = Float64(path.dx),
   dy = Float64(path.dy))
_rectangle_obb(path::ClosedPolygonalPath) =
  let vs = path.vertices
    if length(vs) != 4
      nothing
    else
      let e0 = vs[2] - vs[1],
          e1 = vs[3] - vs[2],
          e2 = vs[4] - vs[3],
          e3 = vs[1] - vs[4],
          n0 = norm(e0), n1 = norm(e1),
          n2 = norm(e2), n3 = norm(e3)
        if !(isapprox(n0, n2; atol=_box_decomp_tolerance) &&
             isapprox(n1, n3; atol=_box_decomp_tolerance))
          nothing
        elseif n0 < _box_decomp_tolerance || n1 < _box_decomp_tolerance
          nothing
        else
          let u0 = unitized(e0),
              u1 = unitized(e1)
            if abs(dot(u0, u1)) > _box_decomp_tolerance
              nothing
            else
              (centre = vs[1] + e0/2 + e1/2,
               vx = u0,
               vy = u1,
               dx = Float64(n0),
               dy = Float64(n1))
            end
          end
        end
      end
    end
  end

_linear_path_pieces(path::LinePath) = OpenPath[path]
_linear_path_pieces(path::Union{RectangularPath,PolygonalPath}) = path_pieces(path)
function _linear_path_pieces(path::CompositePath)
  pieces = OpenPath[]
  for piece in path.pieces
    subpieces = _linear_path_pieces(piece)
    isnothing(subpieces) && return nothing
    append!(pieces, subpieces)
  end
  pieces
end
_linear_path_pieces(path::Path) = nothing

_path_is_authored_linear(path::Path) = !isnothing(_linear_path_pieces(path))

function _closed_linear_path_vertices(path::Path)
  pieces = _linear_path_pieces(path)
  (isnothing(pieces) || isempty(pieces) || !is_closed_path(path)) && return nothing
  vertices = Loc[path_start(pieces[1])]
  append!(vertices, path_end.(pieces))
  coincident_path_location(vertices[1], vertices[end]) && pop!(vertices)
  vertices
end

_rectangle_obb(path::Path) =
  let vertices = _closed_linear_path_vertices(path)
    isnothing(vertices) ? nothing : _rectangle_obb(closed_polygonal_path(vertices))
  end

#=
True iff `path` is a single straight segment that we can fully
characterise as a (start, end) point pair. A two-vertex
`OpenPolygonalPath` qualifies; closed paths and multi-segment paths
do not, because the per-segment box decomposition handles them via
`subpaths` instead of via a single-shot rectangle frame.
=#
_is_straight_segment(path::OpenPolygonalPath) = length(path.vertices) == 2
_is_straight_segment(path::Path) =
  let pieces = _linear_path_pieces(path)
    !isnothing(pieces) && length(pieces) == 1
  end

#=
Decompose a segment-rectangle [0, seg_length] × [0, w_height] minus
a set of opening rectangles into a sweep of solid sub-rectangles.

`openings` is a vector of NamedTuples (s, e, b, t):
  s, e — opening's along-segment span [s, e] ⊆ [0, seg_length]
  b, t — opening's vertical span [b, t] ⊆ [0, w_height]
The list must be sorted by `s` and the openings must not overlap each
other along the segment axis (Khepri walls don't allow horizontally
overlapping doors/windows on the same segment).

Output: a vector of the same NamedTuple shape, each describing one
solid piece of the segment (full-height bays between openings, sills
below openings, lintels above openings).

The sweep: cursor walks left→right; for each opening we emit the
full-height bay strictly to its left if any, then the sill / lintel
above and below the opening, then advance the cursor past the
opening. After the last opening, emit a trailing full-height bay if
the cursor hasn't reached the segment end.

`b > 0` and `t < w_height` guards skip degenerate (zero-height) sills
and lintels — they would emit cubes of zero `dz`, which Unity rejects
as a degenerate mesh.
=#
_decompose_segment_with_openings(seg_length::Real, w_height::Real, openings) =
  let pieces = NamedTuple{(:s,:e,:b,:t),NTuple{4,Float64}}[],
      cursor = 0.0
    for op in openings
      if op.s > cursor
        push!(pieces, (s=cursor, e=op.s, b=0.0, t=Float64(w_height)))
      end
      if op.b > _box_decomp_tolerance
        push!(pieces, (s=op.s, e=op.e, b=0.0, t=Float64(op.b)))
      end
      if op.t < w_height - _box_decomp_tolerance
        push!(pieces, (s=op.s, e=op.e, b=Float64(op.t), t=Float64(w_height)))
      end
      cursor = max(cursor, Float64(op.e))
    end
    if cursor < seg_length - _box_decomp_tolerance
      push!(pieces, (s=cursor, e=Float64(seg_length), b=0.0, t=Float64(w_height)))
    end
    pieces
  end

#=
Build the (centre, vx, vy, dx, dy, dz) box description from a
segment-local rectangle (s, e, b, t) and the segment's frame.

`seg_p0` is the segment's start point already lifted to the wall's
base height — so the box centre's Z = seg_p0.z + (b+t)/2, no
further offset needed. `offset_perp` shifts the box centre off the
centerline by (l_thickness − r_thickness)/2 to honour asymmetric wall
thicknesses (the wall's `offset` field).

The (dx, dy, dz) returned correspond to (along-segment, perpendicular,
vertical) extents — encoded by the BoxCompound RPC into Unity's
local (height, thickness, length) order, which is the convention
b_box already uses (see the X<->Z swap there).
=#
_segment_piece_to_box(seg_p0::Loc, seg_axis::Vec, seg_perp::Vec,
                      piece, total_th::Real, offset_perp::Real) =
  let c_along = (piece.s + piece.e) / 2,
      c_vert  = (piece.b + piece.t) / 2,
      d_along = piece.e - piece.s,
      d_vert  = piece.t - piece.b,
      centre = seg_p0 + seg_axis*c_along + seg_perp*offset_perp + vz(c_vert, seg_p0.cs)
    (centre = centre,
     vx = seg_axis,
     vy = seg_perp,
     dx = Float64(d_along),
     dy = Float64(total_th),
     dz = Float64(d_vert))
  end

#=
Wall → list of box descriptions, or `nothing` if the wall doesn't fit
the box decomposition.

Takes the same primitive arguments as KhepriBase's `b_wall` so the
override is `b_wall(::Unity, ...)`-shaped and stays decoupled from the
`Wall` shape proxy: the decomposer never reaches into `w.path`,
`w.doors`, `w.bottom_level`, etc. — the realize chain in KhepriBase
extracts and lifts those for us before calling `b_wall`.

Falls through (returns `nothing`) when:
  * left/right/side materials differ — Unity Cube uses one material;
  * the chain resolver supplied face polylines (`l_face_path` /
    `r_face_path`) — those represent non-symmetric junction
    geometry that the simple OBB decomposition can't reproduce;
  * the centerline isn't a polygonal/rectangular path (i.e. it's
    smooth — arc walls, spline walls).

For a `RectangularPath` centerline (closed perimeter wall) we walk
its 4 segments via `subpaths`. Multi-segment polygonal walls work
the same way; corners between segments are not mitred — adjacent
boxes meet at the corner with a small in-thickness overlap inherited
from the centerline geometry, which is acceptable for collision
purposes and visually invisible at architectural scales.

`openings` is a `Vector{WallOpening}` carrying `path_position`,
`base_height`, `width`, `height` — the same struct the default
`b_wall` builds from doors+windows before dispatching.
=#
_wall_box_decomposition(w_path, w_height, family, offset, openings,
                        l_face_path, r_face_path) =
  if !(family.left_material === family.right_material === family.side_material) ||
     !isnothing(l_face_path) || !isnothing(r_face_path) ||
     !_path_is_authored_linear(w_path)
    nothing
  else
    let l_th = (1/2 + offset) * (family.thickness + family.left_coating_thickness),
        r_th = (1/2 - offset) * (family.thickness + family.right_coating_thickness),
        total_th = l_th + r_th,
        offset_perp = (l_th - r_th) / 2,
        ops_all = sort(
          [(s=Float64(op.path_position),
            e=Float64(op.path_position + op.width),
            b=Float64(op.base_height),
            t=Float64(op.base_height + op.height))
           for op in openings],
          by = o -> o.s),
        boxes = NamedTuple{(:centre,:vx,:vy,:dx,:dy,:dz),Tuple{Loc,Vec,Vec,Float64,Float64,Float64}}[],
        arclen = 0.0
      for seg in subpaths(w_path)
        let seg_p0 = path_start(seg),
            seg_p1 = path_end(seg),
            seg_length = norm(seg_p1 - seg_p0)
          if seg_length < _box_decomp_tolerance
            arclen += seg_length
            continue
          end
          let seg_axis = unitized(seg_p1 - seg_p0),
              seg_perp = unitized(cross(vz(1, seg_p0.cs), seg_axis)),
              seg_ops = sort(
                [(s=max(0.0, op.s - arclen),
                  e=min(seg_length, op.e - arclen),
                  b=op.b, t=op.t)
                 for op in ops_all
                 if op.s < arclen + seg_length - _box_decomp_tolerance &&
                    op.e > arclen + _box_decomp_tolerance],
                by = o -> o.s)
            for piece in _decompose_segment_with_openings(seg_length, w_height, seg_ops)
              push!(boxes, _segment_piece_to_box(seg_p0, seg_axis, seg_perp,
                                                 piece, total_th, offset_perp))
            end
          end
          arclen += seg_length
        end
      end
      isempty(boxes) ? nothing : boxes
    end
  end

#=
Slab → list of box descriptions, or `nothing`.

Decomposes a rectangular slab outline into a single box (no holes) or
into a list of boxes when all interior holes are rectangles parallel
to the outer rectangle's frame. The 1-D opening sweep used by walls
applies here too: project each rectangular hole onto the outer
rectangle's vx axis to get a list of (s, e, b, t) sub-rectangles on
the slab's plane, then sweep.

Slabs can have non-uniform top/bottom/side materials. Like walls,
the box collapse uses one material so we fall back when the three
differ. Falls back too when the outer outline isn't a rectangle or
any inner path isn't.

The slab thickness comes from `slab_family_thickness` and is applied
along the world-Z axis — slabs are always horizontal in KhepriBase.
The slab's bottom is at level_height + family_elevation, top at +
thickness above that.
=#
_slab_box_decomposition(b::Unity, region::Region, level, family) =
  if !(family.bottom_material === family.top_material === family.side_material)
    nothing
  else
    let outer = _rectangle_obb(outer_path(region))
      isnothing(outer) && return nothing
      let inners = inner_paths(region),
          inner_obbs = [_rectangle_obb(p) for p in inners]
        any(isnothing, inner_obbs) && return nothing
        # All inner rectangles must share the outer's frame (axis-aligned
        # in the slab's local coordinates) so we can flatten them into
        # 1-D opening intervals along the outer's vx axis. This catches
        # the common case (axis-aligned rectangular shafts) and rejects
        # rotated holes — which would need true 2-D rectangle subtraction
        # not implemented here.
        for io in inner_obbs
          if abs(dot(io.vx, outer.vx) - 1) > _box_decomp_tolerance ||
             abs(dot(io.vy, outer.vy) - 1) > _box_decomp_tolerance
            return nothing
          end
        end
        let thickness = slab_family_thickness(b, family),
            elevation = slab_family_elevation(b, family),
            slab_z_centre = level.height + elevation + thickness/2,
            # Project inner rectangles onto outer's local (along-vx, along-vy):
            # each inner becomes (s, e) along vx and (b, t) along vy where
            # (s, e, b, t) ∈ [0, dx] × [0, dy] of the outer rectangle.
            outer_corner = outer.centre - outer.vx*outer.dx/2 - outer.vy*outer.dy/2,
            holes = sort(
              [let local_centre = io.centre - outer_corner,
                   cs = dot(local_centre, outer.vx),
                   ct = dot(local_centre, outer.vy)
                 (s=cs - io.dx/2, e=cs + io.dx/2,
                  b=ct - io.dy/2, t=ct + io.dy/2)
               end for io in inner_obbs],
              by = h -> h.s),
            boxes = NamedTuple{(:centre,:vx,:vy,:dx,:dy,:dz),Tuple{Loc,Vec,Vec,Float64,Float64,Float64}}[]
          # Strip-sweep: along outer.vx axis, each "strip" is a vertical
          # column of width Δs spanning the full outer.dy. Holes split
          # each strip into top/bottom solid pieces. We linearly sweep
          # the outer rectangle as if it were a wall segment with the
          # hole rectangles as openings, then build a 3-D box per piece.
          for piece in _decompose_segment_with_openings(outer.dx, outer.dy, holes)
            let c_along = (piece.s + piece.e) / 2,
                c_perp  = (piece.b + piece.t) / 2,
                d_along = piece.e - piece.s,
                d_perp  = piece.t - piece.b,
                centre = outer_corner + outer.vx*c_along + outer.vy*c_perp +
                         vz(slab_z_centre - outer_corner.z, outer_corner.cs)
              push!(boxes, (centre=centre,
                            vx=outer.vx, vy=outer.vy,
                            dx=Float64(d_along), dy=Float64(d_perp),
                            dz=Float64(thickness)))
            end
          end
          isempty(boxes) ? nothing : boxes
        end
      end
    end
  end

#=
Panel → single box description, or `nothing`.

A panel is a region extruded by `family.thickness` along the region's
plane normal; when the region's outer path is a rectangle and no
inner paths are present, the panel is one OBB. We don't decompose
panels with holes; rectangle-with-rectangular-hole panels are
unusual enough that a fall-through to MeshCollider is acceptable.
=#
_panel_obb(profile::Region, family) =
  if !(family.left_material === family.right_material === family.side_material) ||
     !isempty(inner_paths(profile))
    nothing
  else
    let r = _rectangle_obb(outer_path(profile))
      isnothing(r) ? nothing :
      let n = planar_path_normal(outer_path(profile)),
          th = family.thickness
        (centre = r.centre,
         vx = r.vx, vy = r.vy,
         dx = Float64(r.dx), dy = Float64(r.dy), dz = Float64(th),
         normal = n)
      end
    end
  end

#=
Beam (and column / free-column via b_beam) → single box, or `nothing`.

`family_profile` is the cross-section in the beam's local XY plane
with extrusion along local +Z by `h`. When that profile is a
rectangle (the default `rectangular_profile` and `top_aligned_…`,
`bottom_aligned_…` profiles all return `RectangularPath`), the
beam is exactly a box. Circular and other profiles fall through;
circular beams already get a CapsuleCollider via the
`b_extruded_curve(::CircularPath)` shortcut in
KhepriBase/src/Backend.jl.

The beam frame at world space comes from `loc_from_o_phi(c, angle)`
exactly as `b_beam` builds it; we then reproject the rectangular
profile's centre into world coordinates to get the box centre.
=#
_beam_rect_obb(b::Unity, c::Loc, h::Real, angle::Real, family) =
  let prof = family_profile(b, family),
      r = _rectangle_obb(prof)
    isnothing(r) ? nothing :
    let frame = loc_from_o_phi(c, angle),
        # `r.centre` is in the profile's CS (centred at u0() for
        # the rectangular_profile family default); reproject into
        # the beam frame and lift by h/2 along the beam's local Z
        # to land at the beam's geometric centre.
        centre_local = r.centre,
        centre = frame +
                 vx(centre_local.x, frame.cs) +
                 vy(centre_local.y, frame.cs) +
                 vz(h/2, frame.cs),
        # Profile's vx/vy live in the profile's CS; convert into
        # the beam's frame by treating their (x, y) components as
        # offsets along (frame.vx, frame.vy).
        vxw = unitized(vx(r.vx.x, frame.cs) + vy(r.vx.y, frame.cs)),
        vyw = unitized(vx(r.vy.x, frame.cs) + vy(r.vy.y, frame.cs))
      (centre=centre, vx=vxw, vy=vyw,
       dx=Float64(r.dx), dy=Float64(r.dy), dz=Float64(h))
    end
  end

# Helper: emit a list of box descriptions as a single BoxCompound RPC.
_emit_box_compound(b::Unity, name::String, boxes, mat_ref) =
  @remote(b, BoxCompound(
    name,
    [box.centre for box in boxes],
    [box.vx     for box in boxes],
    [box.vy     for box in boxes],
    [box.dz     for box in boxes],   # X<->Z swap: see b_box convention
    [box.dy     for box in boxes],
    [box.dx     for box in boxes],
    mat_ref))

#=
Walls — overrides `b_wall` (the dispatcher KhepriBase calls after
realize() has already done the data extraction: lifted centerline,
height delta, opening list converted from doors+windows, optional
face polylines from the chain resolver).

When the box decomposition succeeds we emit a single BoxCompound
(one Unity Cube child per solid sub-rectangle of the wall) and tag
it for NavMesh as area=1 (NotWalkable, Obstacle). On fall-through
we re-enter the default `b_wall` body via `invoke` and tag whatever
refs it returns; the default path goes through Solidify and ends in
a MeshCollider as before.

Centralising NavMesh tagging here keeps `realize(::Wall)` generic —
no Unity-specific override of realize() is needed. Other backends'
b_wall overrides (or the default) continue to work unchanged.
=#
KhepriBase.b_wall(b::Unity, w_path, w_height, family, offset, openings;
                  l_face_path=nothing, r_face_path=nothing) =
  let boxes = _wall_box_decomposition(w_path, w_height, family, offset,
                                      openings, l_face_path, r_face_path)
    if isnothing(boxes)
      let refs = invoke(KhepriBase.b_wall,
                        Tuple{KhepriBase.Backend, Any, Any, Any, Any, Any},
                        b, w_path, w_height, family, offset, openings;
                        l_face_path=l_face_path, r_face_path=r_face_path)
        nav_mesh_tagging() && tag_refs_nav_mesh(b, refs, 1)
        refs
      end
    else
      let mat_ref = material_ref(b, family.right_material),
          ref = with_material_as_layer(b, family.right_material) do
            _emit_box_compound(b, "Wall", boxes, mat_ref)
          end
        nav_mesh_tagging() && tag_refs_nav_mesh(b, [ref], 1)
        UnityId[ref]
      end
    end
  end

#=
Slabs — overrides `b_slab` (KhepriBase's `realize(::Slab)` calls
this directly with `s.region`, `s.level`, `s.family`).

NavMesh area = 0 (Walkable). Same fall-through pattern as walls:
when box decomposition fails we invoke the default `b_slab` body
which extrudes the region and Solidifies it.
=#
KhepriBase.b_slab(b::Unity, profile, level, family) =
  let boxes = _slab_box_decomposition(b, profile, level, family)
    if isnothing(boxes)
      let refs = invoke(KhepriBase.b_slab,
                        Tuple{KhepriBase.Backend, Any, Any, Any},
                        b, profile, level, family)
        nav_mesh_tagging() && tag_refs_nav_mesh(b, refs, 0)
        refs
      end
    else
      let mat_ref = material_ref(b, family.top_material),
          ref = with_material_as_layer(b, family.top_material) do
            _emit_box_compound(b, "Slab", boxes, mat_ref)
          end
        nav_mesh_tagging() && tag_refs_nav_mesh(b, [ref], 0)
        UnityId[ref]
      end
    end
  end

#=
Roofs — KhepriBase's `realize(::Roof)` calls `b_roof` (whose default
delegates to `b_slab`). We override both paths: `_slab_box_decomposition`
handles the rectangular-region geometry the same way, with NavMesh
area = 0 (a roof is walkable from the top in Khepri's convention).
=#
KhepriBase.b_roof(b::Unity, profile, level, family) =
  let boxes = _slab_box_decomposition(b, profile, level, family)
    if isnothing(boxes)
      let refs = invoke(KhepriBase.b_roof,
                        Tuple{KhepriBase.Backend, Any, Any, Any},
                        b, profile, level, family)
        nav_mesh_tagging() && tag_refs_nav_mesh(b, refs, 0)
        refs
      end
    else
      let mat_ref = material_ref(b, family.top_material),
          ref = with_material_as_layer(b, family.top_material) do
            _emit_box_compound(b, "Roof", boxes, mat_ref)
          end
        nav_mesh_tagging() && tag_refs_nav_mesh(b, [ref], 0)
        UnityId[ref]
      end
    end
  end

# Beams (and columns / free-columns, which delegate to b_beam)
KhepriBase.b_beam(b::Unity, c::Loc, h::Real, angle::Real, family) =
  let obb = _beam_rect_obb(b, c, h, angle, family)
    if isnothing(obb)
      # Fall through to KhepriBase default body. Inlined rather than
      # delegated through dispatch so that this method itself doesn't
      # loop. Mirrors KhepriBase/src/Backend.jl:b_beam exactly: build
      # the angle-rotated frame, then extrude the family profile
      # along that frame's local Z by `h`.
      let frame = loc_from_o_phi(c, angle),
          mat = material_ref(b, family.material)
        with_material_as_layer(b, family.material) do
          b_extruded_surface(b, region(family_profile(b, family)),
                             vz(h, frame.cs), frame, mat, mat, mat)
        end
      end
    else
      let mat_ref = material_ref(b, family.material),
          ref = with_material_as_layer(b, family.material) do
            _emit_box_compound(b, "Beam", [obb], mat_ref)
          end
        UnityId[ref]
      end
    end
  end

# Panels
KhepriBase.b_panel(b::Unity, profile::Region, family) =
  let obb = _panel_obb(profile, family)
    if isnothing(obb)
      # Default path: extrude profile by family.thickness along its normal.
      # Mirrors KhepriBase's default b_panel implementation.
      let lmat = material_ref(b, family.left_material),
          rmat = material_ref(b, family.right_material),
          smat = material_ref(b, family.side_material),
          th = family.thickness,
          v = planar_path_normal(profile)
        b_extruded_surface(b, profile, v*th, u0(v.cs)+v*(th/-2),
                           lmat, rmat, smat)
      end
    else
      let mat_ref = material_ref(b, family.right_material),
          # Project the panel's normal-plane frame to a 3-D box frame.
          # The OBB returned by `_panel_obb` carries (vx, vy) in the
          # profile's plane plus a `normal` Vec; the box's third axis
          # is along that normal, so the centre offsets to mid-thickness
          # automatically (centre is already on the profile's plane).
          ref = with_material_as_layer(b, family.right_material) do
            _emit_box_compound(b, "Panel",
                               [(centre=obb.centre, vx=obb.vx, vy=obb.vy,
                                 dx=obb.dx, dy=obb.dy, dz=obb.dz)],
                               mat_ref)
          end
        UnityId[ref]
      end
    end
  end

# Agent size
KhepriBase.b_set_sim_agent_size(b::Unity, radius, height) =
  @remote(b, SetSimAgentSize(radius, height))

# Movement model
KhepriBase.b_set_sim_hsf(b::Unity, relaxation_time, max_speed_coef, V, sigma, U, R, c, phi) =
  @remote(b, SetSimHSF(relaxation_time, max_speed_coef, V, sigma, U, R, c, phi))

KhepriBase.b_set_sim_none(b::Unity) =
  @remote(b, SetSimNone())

# Velocity distribution
KhepriBase.b_set_vel_gauss_hsf(b::Unity, mean, std_dev, min_v, max_v) =
  @remote(b, SetVelGaussHSF(mean, std_dev, min_v, max_v))

KhepriBase.b_set_vel_uniform_hsf(b::Unity, min_v, max_v) =
  @remote(b, SetVelUniformHSF(min_v, max_v))

KhepriBase.b_set_vel_hsf(b::Unity, vel) =
  @remote(b, SetVelHSF(vel))

# Goals and agents
KhepriBase.b_create_sim_goal(b::Unity, pos, scale, rot) =
  @remote(b, CreateSimGoal(pos, scale, rot))

KhepriBase.b_create_sim_agent(b::Unity, pos, rot, goal_ids, color) =
  @remote(b, CreateSimAgent(pos, rot, color, goal_ids))

KhepriBase.b_spawn_agents_rect(b::Unity, count, center, dx, dz, rot, goal_ids, color) =
  @remote(b, SpawnAgentsRect(count, center, dx, dz, rot, color, goal_ids))

KhepriBase.b_spawn_agents_ellipse(b::Unity, count, center, dx, dz, rot, goal_ids, color) =
  @remote(b, SpawnAgentsEllipse(count, center, dx, dz, rot, color, goal_ids))

KhepriBase.b_spawn_agents_polygon(b::Unity, count, h, vertices, goal_ids, color) =
  @remote(b, SpawnAgentsPolygon(count, h, color, goal_ids, vertices))

# Simulation control
KhepriBase.b_start_simulation(b::Unity, max_time) =
  @remote(b, StartSimulation(max_time))

KhepriBase.b_set_simulation_speed(b::Unity, speed) =
  @remote(b, SetSimulationSpeed(speed))

KhepriBase.b_is_simulation_finished(b::Unity) =
  @remote(b, IsSimulationFinished())

KhepriBase.b_was_simulation_successful(b::Unity) =
  @remote(b, WasSimulationSuccessful())

KhepriBase.b_get_evacuation_time(b::Unity) =
  @remote(b, GetEvacuationTime())

KhepriBase.b_reset_simulation(b::Unity) =
  @remote(b, ResetSimulation())

KhepriBase.b_set_sim_rand_seed(b::Unity, seed) =
  @remote(b, SetSimRandSeed(seed))

# Blocking simulation: void RPC starts the sim, then we block
# reading the deferred result that Unity sends when the sim ends.
KhepriBase.b_run_simulation(b::Unity, max_time) =
  let conn = connection(b)
    @remote(b, RunSimulation(max_time))
    evac_time = read(conn, Float32)
    success = read(conn, UInt8) == 0x01
    (evacuation_time=evac_time, successful=success)
  end
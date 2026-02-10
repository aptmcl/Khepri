# KhepriUnreal - Unreal Engine Backend for Khepri
# Updated to match current KhepriBase architecture

export unreal, unreal_material_family, unreal_resource_family

using KhepriBase

#=============================================================================
 Encoding/Decoding - Unreal inherits from CPP
==============================================================================#

# Unreal is a subtype of CPP for parsing
parse_signature(::Val{:UE}, sig::T) where {T} = parse_signature(Val(:CPP), sig)

# Default encoding/decoding delegates to CPP
encode(::Val{:UE}, t::Val{T}, c::IO, v) where {T} = encode(Val(:CPP), t, c, v)
decode(::Val{:UE}, t::Val{T}, c::IO) where {T} = decode(Val(:CPP), t, c)

# Unreal-specific type encoders
@encode_decode_as(:UE, Val{:AActor}, Val{:size})
@encode_decode_as(:UE, Val{:UStaticMesh}, Val{:size})
@encode_decode_as(:UE, Val{:UMaterial}, Val{:size})

# Vector encoding
encode(ns::Val{:UE}, t::Vector{T}, c::IO, v) where {T} = begin
  sub = T()
  encode(ns, Val(:size), c, length(v))
  for e in v encode(ns, sub, c, e) end
end

decode(ns::Val{:UE}, t::Vector{T}, c::IO) where {T} = begin
  sub = T()
  len = decode(ns, Val(:size), c)
  [decode(ns, sub, c) for i in 1:len]
end

# Coordinate system conversion: Unreal uses left-handed CS
# We swap X and Y and scale by 100 (Unreal units)
encode(::Val{:UE}, t::Val{:FVector}, c::IO, p) =
  let (x, y, z) = raw_point(p)
    encode(Val(:CPP), Val(:float3), c, (y * 100, x * 100, z * 100))
  end

decode(::Val{:UE}, t::Val{:FVector}, c::IO) =
  let (y, x, z) = decode(Val(:CPP), Val(:float3), c)
    xyz(x / 100, y / 100, z / 100, world_cs)
  end

# Additional type mappings
@encode_decode_as(:UE, Val{:AActor_array}, Vector{Val{:AActor}})
@encode_decode_as(:UE, Val{:std__vector_double_}, Vector{Float64})
@encode_decode_as(:UE, Val{:FLinearColor}, Val{RGB})
@encode_decode_as(:UE, Val{:TArray_FVector_}, Vector{Val{:FVector}})
@encode_decode_as(:UE, Val{:TArray_AActor_}, Vector{Val{:AActor}})
@encode_decode_as(:UE, Val{:TArray_TArray_FVector__}, Vector{Vector{Val{:FVector}}})
@encode_decode_as(:UE, Val{:TArray_int32_}, Vector{Int32})
@encode_decode_as(:UE, Val{:TArray_TArray_int32__}, Vector{Vector{Int32}})

#=============================================================================
 Remote API Definition
==============================================================================#

unreal_api = @remote_api :UE """
public AActor Primitive::Sphere(FVector center, float radius)
public AActor Primitive::Box(FVector pos, FVector vx, FVector vy, FVector size)
public AActor Primitive::RightCuboid(FVector pos, FVector vx, FVector vy, float sx, float sy, float sz, float angle)
public AActor Primitive::Cylinder(FVector bottom, float radius, FVector top)
public AActor Primitive::Pyramid(TArray<FVector> ps, FVector q)
public AActor Primitive::PyramidFrustum(TArray<FVector> ps, TArray<FVector> q)
public AActor Primitive::PyramidFrustumWithMaterial(TArray<FVector> ps, TArray<FVector> q, UMaterial material)
public AActor Primitive::Slab(TArray<FVector> contour, TArray<TArray<FVector>> holes, float h, UMaterial material)
public AActor Primitive::CurrentParent()
public AActor Primitive::SetCurrentParent(AActor newParent)
public UMaterial Primitive::LoadMaterial(String name)
public UMaterial Primitive::CurrentMaterial()
public int Primitive::SetCurrentMaterial(UMaterial material)
public int Primitive::DeleteAll()
public UStaticMesh Primitive::LoadResource(String name)
public AActor Primitive::CreateBlockInstance(UStaticMesh mesh, FVector position, FVector vx, FVector vy, float scale)
public AActor Primitive::BeamRectSection(FVector position, FVector vx, FVector vy, float dx, float dy, float dz, float angle, UMaterial material)
public AActor Primitive::BeamCircSection(FVector bot, float radius, FVector top, UMaterial material)
public AActor Primitive::Panel(TArray<FVector> pts, FVector n, UMaterial material)
public AActor Primitive::InstantiateBIMElement(UStaticMesh family, FVector pos, float angle)
public AActor Primitive::Subtract(AActor ac1, AActor ac2)
public AActor Primitive::Unite(AActor ac1, AActor ac2)
public int Primitive::DeleteMany(TArray<AActor> acs)
public AActor Primitive::PointLight(FVector position, FLinearColor color, float range, float intensity)
public AActor Primitive::SetView(FVector position, FVector target, float lens, float aperture)
public FVector Primitive::ViewCamera()
public FVector Primitive::ViewTarget()
public float Primitive::ViewLens()
public int Primitive::RenderView(int width, int height, String name, String path, int frame)
public AActor Primitive::Spotlight(FVector position, FVector dir, FLinearColor color, float range, float intensity, float hotspot, float falloff)
public AActor Primitive::Triangle(FVector p1, FVector p2, FVector p3)
public AActor Primitive::Quad(FVector p1, FVector p2, FVector p3, FVector p4)
public AActor Primitive::NGon(TArray<FVector> pts, FVector pivot)
public AActor Primitive::QuadStrip(TArray<FVector> bottom, TArray<FVector> top, int smooth)
public AActor Primitive::SurfacePolygon(TArray<FVector> pts)
public AActor Primitive::SurfaceGrid(TArray<TArray<FVector>> pts, int closedU, int closedV, int smooth)
public AActor Primitive::Line(TArray<FVector> pts)
public AActor Primitive::ClosedLine(TArray<FVector> pts)
public AActor Primitive::Torus(FVector center, float majorRadius, float minorRadius, FVector normal)
public AActor Primitive::ConeFrustum(FVector base, float baseRadius, FVector top, float topRadius)
public AActor Primitive::SurfaceMesh(TArray<FVector> vertices, TArray<TArray<int32>> faces)
public AActor Primitive::Point(FVector position)
public AActor Primitive::Intersect(AActor ac1, AActor ac2)
public FVector Primitive::BoundingBoxMin(AActor ac)
public FVector Primitive::BoundingBoxMax(AActor ac)
public int Primitive::DisableUpdate()
public int Primitive::EnableUpdate()
"""

#=============================================================================
 Backend Type Definitions
==============================================================================#

abstract type UEKey end
const UEId = Int
const UEIds = Vector{UEId}
const UERef = GenericRef{UEKey, UEId}
const UERefs = Vector{UERef}
const UENativeRef = NativeRef{UEKey, UEId}
const UE = SocketBackend{UEKey, UEId}

# Void reference for empty results
KhepriBase.void_ref(b::UE) = -1

# Connection hooks
KhepriBase.before_connecting(b::UE) = nothing
KhepriBase.after_connecting(b::UE) = nothing

# Create the backend instance
const unreal = UE("Unreal", unreal_port, unreal_api)

#=============================================================================
 Tier 0 - Curves (Basic Geometry)
==============================================================================#

# Point - create a small sphere marker
KhepriBase.b_point(b::UE, p, mat) =
  @remote(b, Primitive__Point(p))

# Line - polyline through points
KhepriBase.b_line(b::UE, ps, mat) =
  @remote(b, Primitive__Line(collect(ps)))

# Polygon - closed polyline
KhepriBase.b_polygon(b::UE, ps, mat) =
  @remote(b, Primitive__ClosedLine(collect(ps)))

# Circle - approximated with polygon
KhepriBase.b_circle(b::UE, c, r, mat) =
  let n = 64,
      pts = [c + vpol(r, i * 2π / n, c.cs) for i in 0:n-1]
    @remote(b, Primitive__ClosedLine(pts))
  end

# Arc - approximated with polyline
KhepriBase.b_arc(b::UE, c, r, α, Δα, mat) =
  let n = max(8, round(Int, abs(Δα) / (π / 16))),
      pts = [c + vpol(r, α + i * Δα / n, c.cs) for i in 0:n]
    @remote(b, Primitive__Line(pts))
  end

# Spline - approximated with polyline (UE has native splines but need mesh for visibility)
KhepriBase.b_spline(b::UE, ps, v0, v1, mat) =
  @remote(b, Primitive__Line(collect(ps)))

KhepriBase.b_closed_spline(b::UE, ps, mat) =
  @remote(b, Primitive__ClosedLine(collect(ps)))

# Rectangle - 4 point closed line
KhepriBase.b_rectangle(b::UE, c, dx, dy, mat) =
  let pts = [c, c + vx(dx, c.cs), c + vxy(dx, dy, c.cs), c + vy(dy, c.cs)]
    @remote(b, Primitive__ClosedLine(pts))
  end

#=============================================================================
 Tier 1 - Triangles and Basic Surfaces
==============================================================================#

# Triangle - fundamental surface primitive
KhepriBase.b_trig(b::UE, p1, p2, p3, mat) =
  @remote(b, Primitive__Triangle(p1, p2, p3))

# Quad - two triangles
KhepriBase.b_quad(b::UE, p1, p2, p3, p4, mat) =
  @remote(b, Primitive__Quad(p1, p2, p3, p4))

# N-gon - fan triangulation to pivot
KhepriBase.b_ngon(b::UE, ps, pivot, smooth, mat) =
  @remote(b, Primitive__NGon(collect(ps), pivot))

# Quad strip - series of quads for surface generation
KhepriBase.b_quad_strip(b::UE, ps, qs, smooth, mat) =
  @remote(b, Primitive__QuadStrip(collect(ps), collect(qs), smooth ? 1 : 0))

KhepriBase.b_quad_strip_closed(b::UE, ps, qs, smooth, mat) =
  # Close the strip by adding first point at end
  let ps_closed = vcat(collect(ps), [first(ps)]),
      qs_closed = vcat(collect(qs), [first(qs)])
    @remote(b, Primitive__QuadStrip(ps_closed, qs_closed, smooth ? 1 : 0))
  end

# Surface polygon - filled polygon
KhepriBase.b_surface_polygon(b::UE, ps, mat) =
  @remote(b, Primitive__SurfacePolygon(collect(ps)))

#=============================================================================
 Tier 2 - Advanced Surfaces
==============================================================================#

# Surface grid - grid of points forming a surface
KhepriBase.b_surface_grid(b::UE, ptss, closed_u, closed_v, smooth_u, smooth_v, mat) =
  @remote(b, Primitive__SurfaceGrid(
    [collect(pts) for pts in ptss],
    closed_u ? 1 : 0,
    closed_v ? 1 : 0,
    (smooth_u || smooth_v) ? 1 : 0))

# Surface mesh - arbitrary vertex/face mesh
KhepriBase.b_surface_mesh(b::UE, verts, faces, mat) =
  @remote(b, Primitive__SurfaceMesh(
    collect(verts),
    [Int32.(collect(f)) for f in faces]))

# Surface circle - filled circle
KhepriBase.b_surface_circle(b::UE, c, r, mat) =
  let n = 64,
      pts = [c + vpol(r, i * 2π / n, c.cs) for i in 0:n-1]
    @remote(b, Primitive__SurfacePolygon(pts))
  end

# Surface arc - filled arc segment
KhepriBase.b_surface_arc(b::UE, c, r, α, Δα, mat) =
  let n = max(8, round(Int, abs(Δα) / (π / 16))),
      pts = vcat([c], [c + vpol(r, α + i * Δα / n, c.cs) for i in 0:n])
    @remote(b, Primitive__SurfacePolygon(pts))
  end

# Surface closed spline - filled closed spline as polygon
KhepriBase.b_surface_closed_spline(b::UE, ps, mat) =
  @remote(b, Primitive__SurfacePolygon(collect(ps)))

# Ellipse - approximated with closed polygon
KhepriBase.b_ellipse(b::UE, c, rx, ry, mat) =
  let n = 64,
      pts = [c + vxy(rx * cos(i * 2π / n), ry * sin(i * 2π / n), c.cs) for i in 0:n-1]
    @remote(b, Primitive__ClosedLine(pts))
  end

# Surface ellipse - filled ellipse
KhepriBase.b_surface_ellipse(b::UE, c, rx, ry, mat) =
  let n = 64,
      pts = [c + vxy(rx * cos(i * 2π / n), ry * sin(i * 2π / n), c.cs) for i in 0:n-1]
    @remote(b, Primitive__SurfacePolygon(pts))
  end

# Surface rectangle - filled rectangle
KhepriBase.b_surface_rectangle(b::UE, c, dx, dy, mat) =
  let pts = [c, c + vx(dx, c.cs), c + vxy(dx, dy, c.cs), c + vy(dy, c.cs)]
    @remote(b, Primitive__SurfacePolygon(pts))
  end

#=============================================================================
 Tier 3 - Solids
==============================================================================#

# Box
KhepriBase.b_box(b::UE, c, dx, dy, dz, mat) =
  @remote(b, Primitive__Box(c, vx(1, c.cs), vy(1, c.cs), xyz(dx, dy, dz, world_cs)))

# Sphere
KhepriBase.b_sphere(b::UE, c, r, mat) =
  @remote(b, Primitive__Sphere(c, r))

# Cylinder
KhepriBase.b_cylinder(b::UE, c, r, h, bmat, tmat, smat) =
  @remote(b, Primitive__Cylinder(c, r, c + vz(h, c.cs)))

# Cone - cylinder with top radius 0
KhepriBase.b_cone(b::UE, cb, r, h, bmat, smat) =
  @remote(b, Primitive__ConeFrustum(cb, r, cb + vz(h, cb.cs), 0.0))

# Cone frustum
KhepriBase.b_cone_frustum(b::UE, cb, rb, h, rt, bmat, tmat, smat) =
  @remote(b, Primitive__ConeFrustum(cb, rb, cb + vz(h, cb.cs), rt))

# Torus
KhepriBase.b_torus(b::UE, c, re, ri, mat) =
  @remote(b, Primitive__Torus(c, re, ri, vz(1, c.cs)))

# Pyramid
KhepriBase.b_pyramid(b::UE, bs, t, bmat, smat) =
  @remote(b, Primitive__Pyramid(collect(bs), t))

# Pyramid frustum
KhepriBase.b_pyramid_frustum(b::UE, bs, ts, bmat, tmat, smat) =
  @remote(b, Primitive__PyramidFrustum(collect(bs), collect(ts)))

# Cuboid - 8 corner version
KhepriBase.b_cuboid(b::UE, pb0, pb1, pb2, pb3, pt0, pt1, pt2, pt3, mat) =
  # Use pyramid frustum with 4-point base and top
  @remote(b, Primitive__PyramidFrustum([pb0, pb1, pb2, pb3], [pt0, pt1, pt2, pt3]))

# Right cuboid
KhepriBase.b_right_cuboid(b::UE, cb, width, height, h, mat) =
  @remote(b, Primitive__RightCuboid(cb, vz(1, cb.cs), vx(1, cb.cs), width, height, h, 0.0))

# Generic prism - pyramid frustum with same base and top
KhepriBase.b_generic_prism(b::UE, bs, smooth, v, bmat, tmat, smat) =
  let ts = [p + v for p in bs]
    @remote(b, Primitive__PyramidFrustum(collect(bs), ts))
  end

# Generic pyramid
KhepriBase.b_generic_pyramid(b::UE, bs, t, smooth, bmat, smat) =
  @remote(b, Primitive__Pyramid(collect(bs), t))

# Generic pyramid frustum
KhepriBase.b_generic_pyramid_frustum(b::UE, bs, ts, smooth, bmat, tmat, smat) =
  @remote(b, Primitive__PyramidFrustum(collect(bs), collect(ts)))

#=============================================================================
 Boolean Operations
==============================================================================#

# Unite two shapes
KhepriBase.b_unite_ref(b::UE, r1::UEId, r2::UEId) =
  @remote(b, Primitive__Unite(r1, r2))

# Subtract r2 from r1
KhepriBase.b_subtract_ref(b::UE, r1::UEId, r2::UEId) =
  @remote(b, Primitive__Subtract(r1, r2))

# Intersect two shapes
KhepriBase.b_intersect_ref(b::UE, r1::UEId, r2::UEId) =
  @remote(b, Primitive__Intersect(r1, r2))

# Legacy functions for compatibility
unite_ref(b::UE, r0::UENativeRef, r1::UENativeRef) =
  UENativeRef(@remote(b, Primitive__Unite(r0.value, r1.value)))

subtract_ref(b::UE, r0::UENativeRef, r1::UENativeRef) =
  UENativeRef(@remote(b, Primitive__Subtract(r0.value, r1.value)))

#=============================================================================
 Families
==============================================================================#

abstract type UEFamily <: Family end

struct UEMaterialFamily <: UEFamily
  name::String
  ref::Parameter{Any}
end

unreal_material_family(name, pairs...) =
  UEMaterialFamily(name, Parameter{Any}(nothing))

backend_get_family_ref(b::UE, f::Family, uf::UEMaterialFamily) =
  @remote(b, Primitive__LoadMaterial(uf.name))

struct UEResourceFamily <: UEFamily
  name::String
  parameter_map::Dict{Symbol,String}
  ref::Parameter{Any}
end

unreal_resource_family(name, pairs...) =
  UEResourceFamily(name, Dict(pairs...), Parameter{Any}(nothing))

backend_get_family_ref(b::UE, f::Family, uf::UEResourceFamily) =
  @remote(b, Primitive__LoadResource(uf.name))

#=============================================================================
 BIM Operations
==============================================================================#

# Tables and Chairs
backend_rectangular_table(b::UE, c, angle, family) =
  @remote(b, Primitive__InstantiateBIMElement(realize(b, family), c, -angle))

backend_chair(b::UE, c, angle, family) =
  @remote(b, Primitive__InstantiateBIMElement(realize(b, family), c, -angle))

# Slabs
backend_slab(b::UE, profile, holes, thickness, family) =
  let bot_vs = path_vertices(profile)
    @remote(b, Primitive__Slab(bot_vs, map(path_vertices, holes), thickness, realize(b, family)))
  end

# Beams
realize(b::UE, s::Beam) =
  let profile = s.family.profile,
      profile_u0 = profile.corner,
      c = add_xy(s.cb, profile_u0.x + profile.dx/2, profile_u0.y + profile.dy/2)
    @remote(b, Primitive__BeamRectSection(
      c, vz(1, c.cs), vx(1, c.cs),
      profile.dx, profile.dy, s.h, -s.angle,
      realize(b, s.family)))
  end

realize_beam_profile(b::UE, s::Union{Beam,FreeColumn,Column}, profile::CircularPath, cb::Loc, length::Real) =
  @remote(b, Primitive__BeamCircSection(
    cb,
    profile.radius,
    add_z(cb, length * support_z_fighting_factor),
    realize(b, s.family)))

realize_beam_profile(b::UE, s::Union{Beam,FreeColumn,Column}, profile::RectangularPath, cb::Loc, length::Real) =
  let profile_u0 = profile.corner,
      c = add_xy(cb, profile_u0.x + profile.dx/2, profile_u0.y + profile.dy/2)
    @remote(b, Primitive__BeamRectSection(
      c, vy(1, c.cs), vz(1, c.cs), profile.dy, profile.dx,
      length * support_z_fighting_factor,
      -s.angle,
      realize(b, s.family)))
  end

# Panels
realize(b::UE, s::Panel) =
  let verts = in_world.(s.vertices),
      n = vertices_normal(verts) * (s.family.thickness / 2)
    @remote(b, Primitive__Panel(
      map(p -> p - n, verts),
      n * 2,
      realize(b, s.family)))
  end

# Walls
backend_wall(b::UE, w_path, w_height, l_thickness, r_thickness, family) =
  path_length(w_path) < path_tolerance() ?
    void_ref(b) :
    let w_paths = subpaths(w_path),
        r_w_paths = subpaths(offset(w_path, -r_thickness)),
        l_w_paths = subpaths(offset(w_path, l_thickness)),
        w_height = w_height * wall_z_fighting_factor,
        material = realize(b, family),
        refs = UENativeRef[]
      for (w_seg_path, r_w_path, l_w_path) in zip(w_paths, r_w_paths, l_w_paths)
        let c_r_w_path = closed_path_for_height(r_w_path, w_height),
            c_l_w_path = closed_path_for_height(l_w_path, w_height)
          push!(refs, realize_pyramid_frustum(b, c_l_w_path, c_r_w_path, material))
        end
      end
      length(refs) == 1 ? refs[1] : refs
    end

realize_pyramid_frustum(b::UE, bot_path::Path, top_path::Path, material) =
  realize_pyramid_frustum(b, path_vertices(bot_path), path_vertices(top_path), material)

realize_pyramid_frustum(b::UE, bot_vs, top_vs, material) =
  UENativeRef(@remote(b, Primitive__PyramidFrustumWithMaterial(collect(bot_vs), collect(top_vs), material)))

# Curtain walls
backend_curtain_wall(b::UE, s, path::Path, bottom::Real, height::Real, thickness::Real, kind::Symbol) =
  backend_wall(b, translate(path, vz(bottom)), height, thickness, thickness, getproperty(s.family, kind))

#=============================================================================
 Blocks
==============================================================================#

realize(b::UE, s::Block) =
  @remote(b, Primitive__LoadResource(s.name))

realize(b::UE, s::BlockInstance) =
  @remote(b, Primitive__CreateBlockInstance(
    ref_value(b, s.block),
    s.loc, vx(1, s.loc.cs), vz(1, s.loc.cs), s.scale))

#=============================================================================
 Layers (Parent Hierarchy)
==============================================================================#

const UELayer = Int

current_layer(b::UE)::UELayer =
  @remote(b, Primitive__CurrentParent())

current_layer(layer::UELayer, b::UE) =
  @remote(b, Primitive__SetCurrentParent(layer))

#=============================================================================
 Materials
==============================================================================#

const UEMaterial = Int

current_material(b::UE)::UEMaterial =
  @remote(b, Primitive__CurrentMaterial())

current_material(material::UEMaterial, b::UE) =
  @remote(b, Primitive__SetCurrentMaterial(material))

get_material(name::String, b::UE) =
  @remote(b, Primitive__LoadMaterial(name))

#=============================================================================
 Lighting
==============================================================================#

backend_pointlight(b::UE, loc::Loc, color::RGB, range::Real, intensity::Real) =
  @remote(b, Primitive__PointLight(loc, color, range, intensity))

backend_spotlight(b::UE, loc::Loc, dir::Vec, color::RGB, range::Real, intensity::Real, hotspot::Real, falloff::Real) =
  @remote(b, Primitive__Spotlight(loc, dir, color, range, intensity, hotspot, falloff))

#=============================================================================
 View and Rendering
==============================================================================#

backend_set_view(b::UE, camera::Loc, target::Loc, lens::Real, aperture::Real) =
  @remote(b, Primitive__SetView(camera, target, lens, aperture))

backend_get_view(b::UE) =
  (@remote(b, Primitive__ViewCamera()),
   @remote(b, Primitive__ViewTarget()),
   @remote(b, Primitive__ViewLens()))

render_view(path::String, b::UE) =
  begin
    @remote(b, Primitive__RenderView(render_width(), render_height(), film_filename(), path, film_frame()))
    path
  end

#=============================================================================
 Bounding Box
==============================================================================#

backend_bounding_box(b::UE, shapes::Shapes) =
  let refs = ref_values(b, shapes),
      mins = [@remote(b, Primitive__BoundingBoxMin(r)) for r in refs],
      maxs = [@remote(b, Primitive__BoundingBoxMax(r)) for r in refs]
    (xyz(minimum(p -> p.x, mins), minimum(p -> p.y, mins), minimum(p -> p.z, mins)),
     xyz(maximum(p -> p.x, maxs), maximum(p -> p.y, maxs), maximum(p -> p.z, maxs)))
  end

#=============================================================================
 Batch Processing
==============================================================================#

KhepriBase.b_start_batch_processing(b::UE) =
  @remote(b, Primitive__DisableUpdate())

KhepriBase.b_stop_batch_processing(b::UE) =
  @remote(b, Primitive__EnableUpdate())

#=============================================================================
 Shape Management
==============================================================================#

backend_delete_all_shapes(b::UE) =
  @remote(b, Primitive__DeleteAll())

backend_delete_shapes(b::UE, shapes::Shapes) =
  @remote(b, Primitive__DeleteMany(ref_values(b, shapes)))

# KhepriUnreal - Unreal Engine Backend for Khepri
# Modern b_* architecture matching current KhepriBase

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
# We swap X and Y and scale by 100 (Unreal units are centimeters)
# ue_scale converts meters (Khepri) → centimeters (Unreal) for scalar distances
const ue_scale = 100.0

encode(::Val{:UE}, t::Val{:FVector}, c::IO, p) =
  let (x, y, z) = raw_point(p)
    encode(Val(:CPP), Val(:float3), c, (y * ue_scale, x * ue_scale, z * ue_scale))
  end

decode(::Val{:UE}, t::Val{:FVector}, c::IO) =
  let (y, x, z) = decode(Val(:CPP), Val(:float3), c)
    xyz(x / ue_scale, y / ue_scale, z / ue_scale, world_cs)
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
public AActor Primitive::Slab(TArray<FVector> contour, TArray<TArray<FVector>> holes, float h, UMaterial material)
public AActor Primitive::CurrentParent()
public AActor Primitive::SetCurrentParent(AActor newParent)
public UMaterial Primitive::LoadMaterial(String name)
public int Primitive::DeleteAll()
public int Primitive::DeleteAllShapes()
public int Primitive::DeleteMany(TArray<AActor> acs)
public int Primitive::DeleteRef(AActor actor)
public UStaticMesh Primitive::LoadResource(String name)
public AActor Primitive::CreateBlockInstance(UStaticMesh mesh, FVector position, FVector vx, FVector vy, float scale)
public AActor Primitive::BeamRectSection(FVector position, FVector vx, FVector vy, float dx, float dy, float dz, float angle, UMaterial material)
public AActor Primitive::BeamCircSection(FVector bot, float radius, FVector top, UMaterial material)
public AActor Primitive::Subtract(AActor ac1, AActor ac2)
public AActor Primitive::Unite(AActor ac1, AActor ac2)
public AActor Primitive::Intersect(AActor ac1, AActor ac2)
public AActor Primitive::PointLight(FVector position, FLinearColor color, float range, float intensity)
public AActor Primitive::SetView(FVector position, FVector target, float lens, float aperture)
public FVector Primitive::ViewCamera()
public FVector Primitive::ViewTarget()
public float Primitive::ViewLens()
public int Primitive::RenderView(int width, int height, String name, String path, int frame)
public int Primitive::ZoomExtents()
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
public FVector Primitive::BoundingBoxMin(AActor ac)
public FVector Primitive::BoundingBoxMax(AActor ac)
public int Primitive::DisableUpdate()
public int Primitive::EnableUpdate()
public UMaterial Primitive::CreateMaterial(float r, float g, float b, float a, float metallic, float specular, float roughness, float emissiveR, float emissiveG, float emissiveB, float emissionStrength)
public AActor Primitive::CreateParent(String name)
public int Primitive::HighlightRefs(TArray<AActor> actors)
public int Primitive::UnhighlightRefs(TArray<AActor> actors)
public int Primitive::UnhighlightAllRefs()
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

# View managed by Unreal editor
KhepriBase.view_type(::Type{UE}) = BackendView()

# Connection hooks
KhepriBase.before_connecting(b::UE) = nothing
KhepriBase.after_connecting(b::UE) = nothing

# Create the backend instance
const unreal = UE("Unreal", unreal_port, unreal_api)

#=============================================================================
 Tier 0 - Curves (Basic Geometry)
==============================================================================#

KhepriBase.b_point(b::UE, p, mat) =
  @remote(b, Primitive__Point(p))

KhepriBase.b_line(b::UE, ps, mat) =
  @remote(b, Primitive__Line(collect(ps)))

KhepriBase.b_polygon(b::UE, ps, mat) =
  @remote(b, Primitive__ClosedLine(collect(ps)))

KhepriBase.b_arc(b::UE, c, r, α, Δα, mat) =
  let n = max(8, round(Int, abs(Δα) / (π / 16))),
      pts = [c + vpol(r, α + i * Δα / n, c.cs) for i in 0:n]
    @remote(b, Primitive__Line(pts))
  end

KhepriBase.b_spline(b::UE, ps, v0, v1, mat) =
  @remote(b, Primitive__Line(collect(ps)))

KhepriBase.b_closed_spline(b::UE, ps, mat) =
  @remote(b, Primitive__ClosedLine(collect(ps)))

#=============================================================================
 Tier 1 - Triangles and Basic Surfaces
==============================================================================#

KhepriBase.b_trig(b::UE, p1, p2, p3, mat) =
  @remote(b, Primitive__Triangle(p1, p2, p3))

KhepriBase.b_quad(b::UE, p1, p2, p3, p4, mat) =
  @remote(b, Primitive__Quad(p1, p2, p3, p4))

KhepriBase.b_ngon(b::UE, ps, pivot, smooth, mat) =
  @remote(b, Primitive__NGon(collect(ps), pivot))

KhepriBase.b_quad_strip(b::UE, ps, qs, smooth, mat) =
  @remote(b, Primitive__QuadStrip(collect(ps), collect(qs), smooth ? 1 : 0))

KhepriBase.b_quad_strip_closed(b::UE, ps, qs, smooth, mat) =
  let ps_closed = vcat(collect(ps), [first(ps)]),
      qs_closed = vcat(collect(qs), [first(qs)])
    @remote(b, Primitive__QuadStrip(ps_closed, qs_closed, smooth ? 1 : 0))
  end

KhepriBase.b_surface_polygon(b::UE, ps, mat) =
  @remote(b, Primitive__SurfacePolygon(collect(ps)))

#=============================================================================
 Tier 2 - Advanced Surfaces
==============================================================================#

KhepriBase.b_surface_grid(b::UE, ptss, closed_u, closed_v, smooth_u, smooth_v, mat) =
  @remote(b, Primitive__SurfaceGrid(
    [collect(ptss[i,:]) for i in 1:size(ptss, 1)],
    closed_u ? 1 : 0,
    closed_v ? 1 : 0,
    (smooth_u || smooth_v) ? 1 : 0))

KhepriBase.b_surface_mesh(b::UE, verts, faces, mat) =
  @remote(b, Primitive__SurfaceMesh(
    collect(verts),
    [Int32.(collect(f)) for f in faces]))

KhepriBase.b_surface_closed_spline(b::UE, ps, mat) =
  @remote(b, Primitive__SurfacePolygon(collect(ps)))

#=============================================================================
 Tier 3 - Solids
==============================================================================#

KhepriBase.b_box(b::UE, c, dx, dy, dz, mat) =
  @remote(b, Primitive__Box(c, vx(1, c.cs), vy(1, c.cs), xyz(dx, dy, dz, world_cs)))

KhepriBase.b_sphere(b::UE, c, r, mat) =
  @remote(b, Primitive__Sphere(c, r * ue_scale))

KhepriBase.b_cylinder(b::UE, c, r, h, bmat, tmat, smat) =
  @remote(b, Primitive__Cylinder(c, r * ue_scale, c + vz(h, c.cs)))

KhepriBase.b_cone(b::UE, cb, r, h, bmat, smat) =
  @remote(b, Primitive__ConeFrustum(cb, r * ue_scale, cb + vz(h, cb.cs), 0.0))

KhepriBase.b_cone_frustum(b::UE, cb, rb, h, rt, bmat, tmat, smat) =
  @remote(b, Primitive__ConeFrustum(cb, rb * ue_scale, cb + vz(h, cb.cs), rt * ue_scale))

KhepriBase.b_torus(b::UE, c, re, ri, mat) =
  @remote(b, Primitive__Torus(c, re * ue_scale, ri * ue_scale, vz(1, c.cs)))

KhepriBase.b_cuboid(b::UE, pb0, pb1, pb2, pb3, pt0, pt1, pt2, pt3, mat) =
  @remote(b, Primitive__PyramidFrustum([pb0, pb1, pb2, pb3], [pt0, pt1, pt2, pt3]))

KhepriBase.b_right_cuboid(b::UE, cb, width, height, h, mat) =
  @remote(b, Primitive__RightCuboid(cb, vz(1, cb.cs), vx(1, cb.cs), width * ue_scale, height * ue_scale, h * ue_scale, 0.0))

KhepriBase.b_generic_pyramid(b::UE, bs, t, smooth, bmat, smat) =
  @remote(b, Primitive__Pyramid(collect(bs), t))

KhepriBase.b_generic_pyramid_frustum(b::UE, bs, ts, smooth, bmat, tmat, smat) =
  @remote(b, Primitive__PyramidFrustum(collect(bs), collect(ts)))

#=============================================================================
 Boolean Operations
==============================================================================#

KhepriBase.b_unite_ref(b::UE, r1::UEId, r2::UEId) =
  @remote(b, Primitive__Unite(r1, r2))

KhepriBase.b_subtract_ref(b::UE, r1::UEId, r2::UEId) =
  @remote(b, Primitive__Subtract(r1, r2))

KhepriBase.b_intersect_ref(b::UE, r1::UEId, r2::UEId) =
  @remote(b, Primitive__Intersect(r1, r2))

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

KhepriBase.b_slab(b::UE, profile::Region, level, family) =
  let cb = z(level_height(b, level) + slab_family_elevation(b, family)),
      mapped = path_on(profile, cb),
      bot_vs = path_vertices(outer_path(mapped)),
      holes_vs = [path_vertices(p) for p in inner_paths(mapped)]
    @remote(b, Primitive__Slab(bot_vs, holes_vs, slab_family_thickness(b, family) * ue_scale, family_ref(b, family)))
  end

KhepriBase.b_slab(b::UE, profile, level, family) =
  let cb = z(level_height(b, level) + slab_family_elevation(b, family)),
      mapped = path_on(profile, cb),
      bot_vs = path_vertices(mapped)
    @remote(b, Primitive__Slab(bot_vs, [], slab_family_thickness(b, family) * ue_scale, family_ref(b, family)))
  end

KhepriBase.b_beam(b::UE, c, h, angle, family) =
  let profile = family_profile(b, family)
    if profile isa RectangularPath
      let profile_u0 = profile.corner,
          c = add_xy(c, profile_u0.x + profile.dx/2, profile_u0.y + profile.dy/2)
        @remote(b, Primitive__BeamRectSection(
          c, vz(1, c.cs), vx(1, c.cs),
          profile.dx * ue_scale, profile.dy * ue_scale, h * ue_scale, -angle,
          family_ref(b, family)))
      end
    elseif profile isa CircularPath
      @remote(b, Primitive__BeamCircSection(
        c, profile.radius * ue_scale,
        add_z(c, h * support_z_fighting_factor),
        family_ref(b, family)))
    else
      let c = loc_from_o_phi(c, angle),
          mat = material_ref(b, family.material)
        b_extruded_surface(b, region(profile), vz(h, c.cs), c, mat, mat, mat)
      end
    end
  end

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

KhepriBase.b_current_layer_ref(b::UE) =
  @remote(b, Primitive__CurrentParent())

KhepriBase.b_current_layer_ref(b::UE, layer) =
  @remote(b, Primitive__SetCurrentParent(layer))

KhepriBase.b_layer(b::UE, name, active, color) =
  let layer = @remote(b, Primitive__CreateParent(name))
    @warn "Ignoring color and active in create_layer for Unreal"
    layer
  end

#=============================================================================
 Materials
==============================================================================#

KhepriBase.b_get_material(b::UE, path::AbstractString) =
  @remote(b, Primitive__LoadMaterial(path))

KhepriBase.b_new_material(b::UE, name, base_color, metallic, specular, roughness,
                           clearcoat, clearcoat_roughness, ior, transmission,
                           transmission_roughness, emission_color, emission_strength,
                           sheen_color, sheen_roughness,
                           anisotropy, anisotropy_direction,
                           ambient_occlusion, normal_map, bent_normal, clearcoat_normal,
                           post_lighting_color,
                           absorption, micro_thickness, thickness) =
  @remote(b, Primitive__CreateMaterial(
    red(base_color), green(base_color), blue(base_color), alpha(base_color),
    metallic, specular, roughness,
    red(emission_color), green(emission_color), blue(emission_color),
    emission_strength))

#=============================================================================
 Shape Management
==============================================================================#

KhepriBase.b_delete_ref(b::UE, r::UEId) =
  @remote(b, Primitive__DeleteRef(r))

KhepriBase.b_delete_refs(b::UE, rs::Vector{UEId}) =
  @remote(b, Primitive__DeleteMany(rs))

KhepriBase.b_delete_all_shape_refs(b::UE) =
  @remote(b, Primitive__DeleteAllShapes())

KhepriBase.b_delete_all(b::UE) =
  @remote(b, Primitive__DeleteAll())

#=============================================================================
 Selection / Highlighting
==============================================================================#

KhepriBase.b_highlight_refs(b::UE, rs::Vector{UEId}) =
  @remote(b, Primitive__HighlightRefs(rs))

KhepriBase.b_unhighlight_refs(b::UE, rs::Vector{UEId}) =
  @remote(b, Primitive__UnhighlightRefs(rs))

KhepriBase.b_unhighlight_all_refs(b::UE) =
  @remote(b, Primitive__UnhighlightAllRefs())

#=============================================================================
 Lighting
==============================================================================#

KhepriBase.b_pointlight(b::UE, loc, energy, color) =
  @remote(b, Primitive__PointLight(loc, color, 10.0 * ue_scale, energy))

KhepriBase.b_spotlight(b::UE, loc, dir, hotspot, falloff) =
  @remote(b, Primitive__Spotlight(loc, dir, rgb(1, 1, 1), 10.0 * ue_scale, 1500.0, hotspot, falloff))

#=============================================================================
 View and Rendering
==============================================================================#

KhepriBase.b_set_view(b::UE, camera::Loc, target::Loc, lens::Real, aperture::Real) =
  @remote(b, Primitive__SetView(camera, target, lens, aperture))

KhepriBase.b_get_view(b::UE) =
  (@remote(b, Primitive__ViewCamera()),
   @remote(b, Primitive__ViewTarget()),
   @remote(b, Primitive__ViewLens()))

KhepriBase.b_zoom_extents(b::UE) =
  @remote(b, Primitive__ZoomExtents())

KhepriBase.b_render_and_save_view(b::UE, path::String) =
  let dir = dirname(path),
      name = first(splitext(basename(path)))
    @remote(b, Primitive__RenderView(render_width(), render_height(), name, dir, 0))
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


export unreal
using KhepriBase
#=
=#

#=
julia_khepri = dirname(dirname(abspath(@__FILE__)))
=#

# Unreal is a subtype of CPP
parse_signature(::Val{:UE}, sig::AbstractString) =
  let func_name(name) = replace(name, ":" => "_"),
      type_name(name) = replace(name, r"[:<>]" => "_"),
      m = match(r"^ *(public|) *(\w+) *([\[\]]*) +((?:\w|:|<|>)+) *\( *(.*) *\)", sig),
      ret = type_name(m.captures[2]),
      array_level = count(c -> c=='[', something(m.captures[3], "")),
      name = m.captures[4],
      params = split(m.captures[5], r" *, *", keepempty=false),
      parse_c_decl(decl) =
        let m = match(r"^ *((?:\w|:|<|>)+) *([\[\]]*) *(\w+)$", decl)
          (type_name(m.captures[1]), count(c -> c=='[', something(m.captures[2], "")), Symbol(m.captures[3]))
        end
    (func_name(name), name, [parse_c_decl(decl) for decl in params], (ret, array_level))
  end

encode(::Val{:UE}, t::Val{T}, c::IO, v) where {T} = encode(Val(:CPP), t, c, v)
decode(::Val{:UE}, t::Val{T}, c::IO) where {T} = decode(Val(:CPP), t, c)

# We need some additional Encoders
@encode_decode_as(:UE, Val{:AActor}, Val{:size})
@encode_decode_as(:UE, Val{:UStaticMesh}, Val{:size})
@encode_decode_as(:UE, Val{:UMaterial}, Val{:size})

encode(ns::Val{:UE}, t::Vector{T}, c::IO, v) where {NS,T} = begin
  sub = T()
  encode(ns, Val(:size), c, length(v))
  for e in v encode(ns, sub, c, e) end
end
decode(ns::Val{:UE}, t::Vector{T}, c::IO) where {NS,T} = begin
  sub = T()
  len = decode(ns, Val(:size), c)
  [decode(ns, sub, c) for i in 1:len]
end

# Unreal uses a left-handed CS. We need to swap X and Y.
encode(::Val{:UE}, t::Val{:FVector}, c::IO, p) =
  let (x,y,z) = raw_point(p)
    encode(Val(:CPP), Val(:float3), c, (y*100, x*100, z*100))
  end
decode(::Val{:UE}, t::Val{:FVector}, c::IO) =
  let (y,x,z) = decode(Val(:CPP), Val(:float3), c)
    xyz(x/100, y/100, z/100, world_cs)
  end

#=
encode(ns::Val{:UE}, t::Val{:Frame3d}, c::IO, v) = begin
  encode(ns, Val(:Point3d), c, v)
  t = v.cs.transform
  encode(Val(:CS), Val(:double3), c, (t[1,1], t[2,1], t[3,1]))
  encode(Val(:CS), Val(:double3), c, (t[1,2], t[2,2], t[3,2]))
  encode(Val(:CS), Val(:double3), c, (t[1,3], t[2,3], t[3,3]))
end

decode(ns::Val{:UE}, t::Val{:Frame3d}, c::IO) =
  u0(cs_from_o_vx_vy_vz(
      decode(ns, Val(:Point3d), c),
      decode(ns, Val(:Vector3d), c),
      decode(ns, Val(:Vector3d), c),
      decode(ns, Val(:Vector3d), c)))
=#
#############################################

export unreal, fast_unreal,
       unreal_material_family

# We need some additional Encoders
@encode_decode_as(:UE, Val{:AActor_array}, Vector{Val{:AActor}})
@encode_decode_as(:UE, Val{:std__vector_double_}, Vector{Float64})
@encode_decode_as(:UE, Val{:FLinearColor}, Val{RGB})
@encode_decode_as(:UE, Val{:TArray_FVector_}, Vector{Val{:FVector}})
@encode_decode_as(:UE, Val{:TArray_AActor_}, Vector{Val{:AActor}})
@encode_decode_as(:UE, Val{:TArray_TArray_FVector__}, Vector{Vector{Val{:FVector}}})

abstract type UEKey end
const UEId = Int
const UEIds = Vector{UEId}
const UERef = GenericRef{UEKey, UEId}
const UERefs = Vector{UERef}
const UEEmptyRef = EmptyRef{UEKey, UEId}
const UEUniversalRef = UniversalRef{UEKey, UEId}
const UENativeRef = NativeRef{UEKey, UEId}
const UEUnionRef = UnionRef{UEKey, UEId}
const UESubtractionRef = SubtractionRef{UEKey, UEId}
const UE = SocketBackend{UEKey, UEId}

void_ref(b::UE) = UENativeRef(-1)

create_UE_connection() =
    begin
        #check_plugin()
        println("Trying to Connect")
        create_backend_connection("Unreal", 11010)
    end

unreal_functions = @remote_functions :UE """
public AActor Primitive::Sphere(FVector center, float radius)
public AActor Primitive::Box(FVector pos, FVector vx, FVector vy, FVector size)
public AActor Primitive::RightCuboid(FVector pos, FVector vx, FVector vy, float sx, float sy, float sz, float angle)
public AActor Primitive::Cylinder(FVector bottom, float radius, FVector top)
public AActor Primitive::Pyramid(TArray<FVector> ps, FVector q)
public AActor Primitive::PyramidFrustum(TArray<FVector> ps, TArray<FVector> q)
public AActor Primitive::PyramidFrustumWithMaterial(TArray<FVector> ps, TArray<FVector> q,UMaterial material)
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
public AActor Primitive::Chair(FVector pos, float angle)
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
public AActor Primitive::Spotlight(FVector position, FVector dir, FLinearColor color, float range, float intensity, float hotspot, float falloff);
"""

const unreal = UE(LazyParameter(TCPSocket, create_UE_connection),
                      unreal_functions)

backend_name(b::UE) = "Unreal"

realize(b::UE, s::EmptyShape) =
  UEEmptyRef()
realize(b::UE, s::UniversalShape) =
  UEUniversalRef()

#=

realize(b::UE, s::Point) =
  UnrealPoint(connection(b), s.position)
realize(b::UE, s::Line) =
  UnrealPolyLine(connection(b), s.vertices)
realize(b::UE, s::Spline) =
  if (s.v0 == false) && (s.v1 == false)
    #UnrealSpline(connection(b), s.points)
    UnrealInterpSpline(connection(b),
                     s.points,
                     s.points[2]-s.points[1],
                     s.points[end]-s.points[end-1])
  elseif (s.v0 != false) && (s.v1 != false)
    UnrealInterpSpline(connection(b), s.points, s.v0, s.v1)
  else
    UnrealInterpSpline(connection(b),
                     s.points,
                     s.v0 == false ? s.points[2]-s.points[1] : s.v0,
                     s.v1 == false ? s.points[end-1]-s.points[end] : s.v1)
  end
realize(b::UE, s::ClosedSpline) =
  UnrealInterpClosedSpline(connection(b), s.points)
realize(b::UE, s::Circle) =
  UnrealCircle(connection(b), s.center, vz(1, s.center.cs), s.radius)
realize(b::UE, s::Arc) =
  if s.radius == 0
    UnrealPoint(connection(b), s.center)
  elseif s.amplitude == 0
    UnrealPoint(connection(b), s.center + vpol(s.radius, s.start_angle, s.center.cs))
  elseif abs(s.amplitude) >= 2*pi
    UnrealCircle(connection(b), s.center, vz(1, s.center.cs), s.radius)
  else
    end_angle = s.start_angle + s.amplitude
    if end_angle > s.start_angle
      UnrealArc(connection(b), s.center, vz(1, s.center.cs), s.radius, s.start_angle, end_angle)
    else
      UnrealArc(connection(b), s.center, vz(1, s.center.cs), s.radius, end_angle, s.start_angle)
    end
  end

realize(b::UE, s::Ellipse) =
  if s.radius_x > s.radius_y
    UnrealEllipse(connection(b), s.center, vz(1, s.center.cs), vxyz(s.radius_x, 0, 0, s.center.cs), s.radius_y/s.radius_x)
  else
    UnrealEllipse(connection(b), s.center, vz(1, s.center.cs), vxyz(0, s.radius_y, 0, s.center.cs), s.radius_x/s.radius_y)
  end
realize(b::UE, s::EllipticArc) =
  error("Finish this")

realize(b::UE, s::Polygon) =
  UnrealClosedPolyLine(connection(b), s.vertices)
realize(b::UE, s::RegularPolygon) =
  UnrealClosedPolyLine(connection(b), regular_polygon_vertices(s.edges, s.center, s.radius, s.angle, s.inscribed))
realize(b::UE, s::Rectangle) =
  UnrealClosedPolyLine(
    connection(b),
    [s.corner,
     add_x(s.corner, s.dx),
     add_xy(s.corner, s.dx, s.dy),
     add_y(s.corner, s.dy)])
realize(b::UE, s::SurfaceCircle) =
  UnrealSurfaceCircle(connection(b), s.center, vz(1, s.center.cs), s.radius)
realize(b::UE, s::SurfaceArc) =
    #UnrealSurfaceArc(connection(b), s.center, vz(1, s.center.cs), s.radius, s.start_angle, s.start_angle + s.amplitude)
    if s.radius == 0
        UnrealPoint(connection(b), s.center)
    elseif s.amplitude == 0
        UnrealPoint(connection(b), s.center + vpol(s.radius, s.start_angle, s.center.cs))
    elseif abs(s.amplitude) >= 2*pi
        UnrealSurfaceCircle(connection(b), s.center, vz(1, s.center.cs), s.radius)
    else
        end_angle = s.start_angle + s.amplitude
        if end_angle > s.start_angle
            UnrealSurfaceFromCurves(connection(b),
                [UnrealArc(connection(b), s.center, vz(1, s.center.cs), s.radius, s.start_angle, end_angle),
                 UnrealPolyLine(connection(b), [add_pol(s.center, s.radius, end_angle),
                                              add_pol(s.center, s.radius, s.start_angle)])])
        else
            UnrealSurfaceFromCurves(connection(b),
                [UnrealArc(connection(b), s.center, vz(1, s.center.cs), s.radius, end_angle, s.start_angle),
                 UnrealPolyLine(connection(b), [add_pol(s.center, s.radius, s.start_angle),
                                              add_pol(s.center, s.radius, end_angle)])])
        end
    end

#realize(b::UE, s::SurfaceElliptic_Arc) = UnrealCircle(connection(b),
#realize(b::UE, s::SurfaceEllipse) = UnrealCircle(connection(b),

realize(b::UE, s::SurfacePolygon) =
  UnrealSurfacePolygon(connection(b), reverse(s.vertices))

backend_fill(b::UE, path::ClosedPolygonalPath) =
  UnrealSurfacePolygon(connection(b), path.vertices)

realize(b::UE, s::SurfaceRegularPolygon) =
  UnrealSurfaceClosedPolyLine(connection(b), regular_polygon_vertices(s.edges, s.center, s.radius, s.angle, s.inscribed))
realize(b::UE, s::SurfaceRectangle) =
  UnrealSurfaceClosedPolyLine(
    connection(b),
    [s.corner,
     add_x(s.corner, s.dx),
     add_xy(s.corner, s.dx, s.dy),
     add_y(s.corner, s.dy)])
realize(b::UE, s::Surface) =
  let #ids = map(r->UENurbSurfaceFrom(connection(b),r), UnrealSurfaceFromCurves(connection(b), collect_ref(s.frontier)))
      ids = UnrealSurfaceFromCurves(connection(b), collect_ref(s.frontier))
    foreach(mark_deleted, s.frontier)
    ids
  end
backend_surface_boundary(b::UE, s::Shape2D) =
    map(shape_from_ref, UnrealCurvesFromSurface(connection(b), ref(s).value))

backend_fill(b::UE, path::ClosedPathSequence) =
  backend_fill(b, convert(ClosedPolygonalPath, path))

# Iterating over curves and surfaces

backend_map_division(b::UE, f::Function, s::Shape1D, n::Int) =
  let (t1, t2) = curve_domain(s)
    map_division(t1, t2, n) do t
      f(frame_at(s, t))
    end
  end

Unreal"public Vector3d RegionNormal(Entity ent)"
Unreal"public Point3d RegionCentroid(Entity ent)"
Unreal"public double[] SurfaceDomain(Entity ent)"
Unreal"public Frame3d SurfaceFrameAt(Entity ent, double u, double v)"

backend_surface_domain(b::UE, s::Shape2D) =
    tuple(UnrealSurfaceDomain(connection(b), ref(s).value)...)

backend_map_division(b::UE, f::Function, s::Shape2D, nu::Int, nv::Int) =
    let conn = connection(b)
        r = ref(s).value
        (u1, u2, v1, v2) = UnrealSurfaceDomain(conn, r)
        map_division(u1, u2, nu) do u
            map_division(v1, v2, nv) do v
                f(UnrealSurfaceFrameAt(conn, r, u, v))
            end
        end
    end

# The previous method cannot be applied to meshes in AutoCAD, which are created by surface_grid

backend_map_division(b::UE, f::Function, s::SurfaceGrid, nu::Int, nv::Int) =
    let (u1, u2, v1, v2) = UnrealSurfaceDomain(conn, r)
        map_division(u1, u2, nu) do u
            map_division(v1, v2, nv) do v
                f(UnrealSurfaceFrameAt(conn, r, u, v))
            end
        end
    end

realize(b::UE, s::Text) =
  UnrealText(
    connection(b),
    s.str, s.corner, vz(-1, s.corner.cs), vy(1, s.corner.cs), "Fonts/Inconsolata-Regular", s.height)

backend_sphere(b::UE, c, r) =
  @remote(b, Primitive__Sphere(c, r))

realize(b::UE, s::Torus) =
  UnrealTorus(connection(b), s.center, vz(1, s.center.cs), s.re, s.ri)
=#

realize(b::UE, s::Cuboid) =
  @remote(b, Primitive__PyramidFrustum([s.b0, s.b1, s.b2, s.b3], [s.t0, s.t1, s.t2, s.t3]))

realize(b::UE, s::RegularPyramidFrustum) =
  @remote(b, Primitive__PyramidFrustum(
                regular_polygon_vertices(s.edges, s.cb, s.rb, s.angle, s.inscribed),
                regular_polygon_vertices(s.edges, add_z(s.cb, s.h), s.rt, s.angle, s.inscribed)))

realize(b::UE, s::RegularPyramid) =
  @remote(b, Primitive__Pyramid(regular_polygon_vertices(s.edges, s.cb, s.rb, s.angle, s.inscribed),
                                add_z(s.cb, s.h)))

realize(b::UE, s::IrregularPyramid) =
  @remote(b, Primitive__Pyramid(s.bs, s.t))

realize(b::UE, s::IrregularPyramidFrustum) =
  @remote(b, Primitive__PyramidFrustum(s.bs, s.ts))
#=
realize(b::UE, s::RegularPrism) =
  let bs = regular_polygon_vertices(s.edges, s.cb, s.r, s.angle, s.inscribed)
    UnrealPyramidFrustum(connection(b),
                        bs,
                        map(p -> add_z(p, s.h), bs))
  end

realize(b::UE, s::IrregularPyramidFrustum) =
    UnrealPyramidFrustum(connection(b), s.bs, s.ts)

realize(b::UE, s::IrregularPrism) =
  UnrealPyramidFrustum(connection(b),
                      s.bs,
                      map(p -> (p + s.v), s.bs))

unreal"public AActor RightCuboid(Vector3 position, Vector3 vx, Vector3 vy, float dx, float dy, float dz, float angle)"
=#
realize(b::UE, s::RightCuboid) =
  @remote(b, Primitive__RightCuboid(s.cb, vx(1, s.cb.cs), vy(1, s.cb.cs), s.h, s.width, s.height,s.angle))

realize(b::UE, s::Box) =
  @remote(b, Primitive__Box(s.c, vx(1, s.c.cs), vy(1, s.c.cs), xyz(s.dx, s.dy, s.dz, world_cs)))

#=
realize(b::UE, s::Cone) =
  @remote(b, Pyramid(regular_polygon_vertices(64, s.cb, s.r), add_z(s.cb, s.h)))

realize(b::UE, s::ConeFrustum) =
  UnrealPyramidFrustum(connection(b),
    regular_polygon_vertices(64, s.cb, s.rb),
    regular_polygon_vertic@remote(b, Primitive__Sphere(s.center, s.radius))es(64, s.cb + vz(s.h, s.cb.cs), s.rt))

unreal"public AActor Cylinder(Vector3 bottom, float radius, Vector3 top)"
=#
realize(b::UE, s::Cylinder) =
  @remote(b, Primitive__Cylinder(s.cb, s.r, s.cb + vz(s.h, s.cb.cs)))
#=
backend_extrusion(b::UE, s::Shape, v::Vec) =
    and_mark_deleted(
        map_ref(s) do r
            UnrealExtrude(connection(b), r, v)
        end,
        s)

backend_sweep(b::UE, path::Shape, profile::Shape, rotation::Real, scale::Real) =
  map_ref(profile) do profile_r
    map_ref(path) do path_r
      UnrealSweep(connection(b), path_r, profile_r, rotation, scale)
    end
  end

realize(b::UE, s::Revolve) =
  and_delete_shape(
    map_ref(s.profile) do r
      UnrealRevolve(connection(b), r, s.p, s.n, s.start_angle, s.amplitude)
    end,
    s.profile)

backend_loft_curves(b::UE, profiles::Shapes, rails::Shapes, ruled::Bool, closed::Bool) =
  and_delete_shapes(UnrealLoft(connection(b),
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


backend_loft_surfaces(b::UE, profiles::Shapes, rails::Shapes, ruled::Bool, closed::Bool) =
    backend_loft_curves(b, profiles, rails, ruled, closed)

backend_loft_curve_point(b::UE, profile::Shape, point::Shape) =
    and_delete_shapes(UnrealLoft(connection(b),
                               vcat(collect_ref(profile), collect_ref(point)),
                               [],
                               true, false),
                      [profile, point])

backend_loft_surface_point(b::UE, profile::Shape, point::Shape) =
    backend_loft_curve_point(b, profile, point)

=#

unite_ref(b::UE, r0::UENativeRef, r1::UENativeRef) =
    ensure_ref(b, @remote(b, Primitive__Unite(r0.value, r1.value)))
#=
intersect_ref(b::UE, r0::UENativeRef, r1::UENativeRef) =
    ensure_ref(b, UnrealIntersect(connection(b), r0.value, r1.value))
=#
subtract_ref(b::UE, r0::UENativeRef, r1::UENativeRef) =
let r = @remote(b, Primitive__Subtract(r0.value, r1.value))
  @remote(b, Primitive__DeleteMany([r0.value, r1.value]))
  r
end

#=
slice_ref(b::UE, r::UENativeRef, p::Loc, v::Vec) =
    (UnrealSlice(connection(b), r.value, p, v); r)

slice_ref(b::UE, r::UnrealUnionRef, p::Loc, v::Vec) =
    map(r->slice_ref(b, r, p, v), r.values)

unite_refs(b::UE, refs::Vector{<:UnrealRef}) =
    UnrealUnionRef(tuple(refs...))

#
realize(b::UE, s::UnionShape) =
  let r = foldl((r0,r1)->unite_ref(b,r0,r1), map(ref, s.shapes),
                init=UEEmptyRef())
    delete_shapes(s.shapes)
    #UnrealCanonicalize(connection(b), r.value)
    r
  end

realize(b::UE, s::IntersectionShape) =
  let r = foldl((r0,r1)->intersect_ref(b,r0,r1), map(ref, s.shapes),
                init=UnrealUniversalRef())
    delete_shapes(s.shapes)
    r
  end

realize(b::UE, s::Slice) =
  slice_ref(b, ref(s.shape), s.p, s.n)

unreal"public void Move(AActor s, Vector3 v)"
unreal"public void Scale(AActor s, Vector3 p, float scale)"
unreal"public void Rotate(AActor s, Vector3 p, Vector3 n, float a)"

realize(b::UE, s::Move) =
  let r = map_ref(s.shape) do r
            UnrealMove(connection(b), r, s.v)
            r
          end
    mark_deleted(s.shape)
    r
  end

realize(b::UE, s::Transform) =
  let r = map_ref(s.shape) do r
            UnrealTransform(connection(b), r, s.xform)
            r
          end
    mark_deleted(s.shape)
    r
  end

realize(b::UE, s::Scale) =
  let r = map_ref(s.shape) do r
            UnrealScale(connection(b), r, s.p, s.s)
            r
          end
    mark_deleted(s.shape)
    r
  end

realize(b::UE, s::Rotate) =
  let r = map_ref(s.shape) do r
            UnrealRotate(connection(b), r, s.p, s.v, s.angle)
            r
          end
    mark_deleted(s.shape)
    r
  end

realize(b::UE, s::Mirror) =
  and_delete_shape(map_ref(s.shape) do r
                    UnrealMirror(connection(b), r, s.p, s.n, false)
                   end,
                   s.shape)

realize(b::UE, s::UnionMirror) =
  let r0 = ref(s.shape),
      r1 = map_ref(s.shape) do r
            UnrealMirror(connection(b), r, s.p, s.n, true)
          end
    UnionRef((r0,r1))
  end

unreal"public AActor SurfaceFromGrid(int m, int n, Vector3[] pts, bool closedM, bool closedN, int level)"

realize(b::UE, s::SurfaceGrid) =
    UnrealSurfaceFromGrid(
        connection(b),
        size(s.points,1),
        size(s.points,2),
        reshape(s.points,:),
        s.closed_u,
        s.closed_v,
        2)

realize(b::UE, s::Thicken) =
  and_delete_shape(
    map_ref(s.shape) do r
      UnrealThicken(connection(b), r, s.thickness)
    end,
    s.shape)

# backend_frame_at
backend_frame_at(b::UE, s::Circle, t::Real) = add_pol(s.center, s.radius, t)

backend_frame_at(b::UE, c::Shape1D, t::Real) = UnrealCurveFrameAt(connection(b), ref(c).value, t)

#backend_frame_at(b::UE, s::Surface, u::Real, v::Real) =
    #What should we do with v?
#    backend_frame_at(b, s.frontier[1], u)

#backend_frame_at(b::UE, s::SurfacePolygon, u::Real, v::Real) =

backend_frame_at(b::UE, s::Shape2D, u::Real, v::Real) = UnrealSurfaceFrameAt(connection(b), ref(s).value, u, v)

=#

# BIM

# Families

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

unreal_resource_family(name, pairs...) = UEResourceFamily(name, Dict(pairs...), Parameter{Any}(nothing))
backend_get_family_ref(b::UE, f::Family, uf::UEResourceFamily) = @remote(b, Primitive__LoadResource(uf.name))


backend_rectangular_table(b::UE, c, angle, family) =
    @remote(b, Primitive__InstantiateBIMElement(realize(b, family), c, -angle))

backend_chair(b::UE, c, angle, family) =
    @remote(b, Primitive__InstantiateBIMElement(realize(b, family), c, -angle))
#=
backend_rectangular_table_and_chairs(b::Khepri.Unreal, c, angle, family) =
    UnrealInstantiateBIMElement(connection(b), realize(b, family), c, -angle)

unreal"public AActor Slab(Vector3[] contour, Vector3[][] holes, float h, Material material)"
=#
backend_slab(b::UE, profile, holes, thickness, family) =
  let bot_vs = path_vertices(profile)
    @remote(b, Primitive__Slab(bot_vs, map(path_vertices, holes), thickness,realize(b, family)))
  end

#=
unreal"public AActor BeamRectSection(Vector3 position, Vector3 vx, Vector3 vy, float dx, float dy, float dz, float angle, Material material)"
unreal"public AActor BeamCircSection(Vector3 bot, float radius, Vector3 top, Material material)"
=#
realize(b::UE, s::Beam) =
  let profile = s.family.profile
      profile_u0 = profile.corner
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
      add_z(cb, length*support_z_fighting_factor), #We reduce height just a bit to avoid Z-fighting
      realize(b, s.family)))

realize_beam_profile(b::UE, s::Union{Beam,FreeColumn,Column}, profile::RectangularPath, cb::Loc, length::Real) =
    let profile_u0 = profile.corner,
        c = add_xy(cb, profile_u0.x + profile.dx/2, profile_u0.y + profile.dy/2)
      @remote(b,  Primitive__BeamRectSection(
        c, vy(1, c.cs), vz(1, c.cs), profile.dy, profile.dx,
        length*support_z_fighting_factor,
        -s.angle,
        realize(b, s.family)))
    end

#=
unreal"public AActor Panel(Vector3[] pts, Vector3 n, Material material)"
=#
realize(b::UE, s::Panel) =
  let #p1 = s.vertices[1],
      #p2 = s.vertices[2],
      #p3 = s.vertices[3],
      #n = vz(s.family.thickness, cs_from_o_vx_vy(p1, p2-p1, p3-p1))
      verts = in_world.(s.vertices)
      n = vertices_normal(verts)*(s.family.thickness/2)
    @remote(b, Primitive__Panel(
      map(p -> p - n, verts),
      n*2,
      realize(b, s.family)))
  end

#
backend_wall(b::UE, w_path, w_height, l_thickness, r_thickness, family) =
  path_length(w_path) < path_tolerance() ?
    UEEmptyRef() :
    let w_paths = subpaths(w_path),
        r_w_paths = subpaths(offset(w_path, -r_thickness)),
        l_w_paths = subpaths(offset(w_path, l_thickness)),
        w_height = w_height*wall_z_fighting_factor,
        prevlength = 0,
        material = realize(b, family),
        refs = UENativeRef[]
      for (w_seg_path, r_w_path, l_w_path) in zip(w_paths, r_w_paths, l_w_paths)
        let currlength = prevlength + path_length(w_seg_path),
            c_r_w_path = closed_path_for_height(r_w_path, w_height),
            c_l_w_path = closed_path_for_height(l_w_path, w_height)
          push!(refs, realize_pyramid_frustum(b, c_l_w_path, c_r_w_path, material))
          prevlength = currlength
        end
      end
      refs
    end
realize_pyramid_frustum(b::UE, bot_path::Path, top_path::Path, material) =
  realize_pyramid_frustum(b, path_vertices(bot_path), path_vertices(top_path), material)
realize_pyramid_frustum(b::UE, bot_vs, top_vs, material) =
    UENativeRef(@remote(b, Primitive__PyramidFrustumWithMaterial(bot_vs, top_vs, material)))

#=
sweep_fractions(b, verts, height, l_thickness, r_thickness) =
  let p = add_z(verts[1], height/2),
      q = add_z(verts[2], height/2),
      (c, h) = position_and_height(p, q),
      thickness = r_thickness + l_thickness, # HACK THIS IS WRONG!
      s = UENativeRef(@remote(b, Primitive__RightCuboid(c, vz(1, c.cs), vx(1, c.cs), height, thickness, h, 0)))
    if length(verts) > 2
      (s, sweep_fractions(b, verts[2:end], height, l_thickness, r_thickness)...)
    else
      (s, )
    end
  end

backend_wall(b::UE, path, height, l_thickness, r_thickness, family) =
  path_length(path) < path_tolerance() ?
    UEEmptyRef() :
    begin
      @remote(b, Primitive__SetCurrentMaterial(realize(b, family)))
      backend_wall_path(
          b,
          path,
          height*0.999, #We reduce height just a bit to avoid Z-fighting
          l_thickness, r_thickness)
    end

backend_wall_path(b::UE, path::OpenPolygonalPath, height, l_thickness, r_thickness) =
    UEUnionRef(sweep_fractions(b, path.vertices, height, l_thickness, r_thickness))

backend_wall_path(b::UE, path::Path, height, l_thickness, r_thickness) =
    backend_wall_path(b, convert(OpenPolygonalPath, path), height, l_thickness, r_thickness)
=#
#=
#=
realize(b::Radiance, w::Wall) =
  let w_base_height = w.bottom_level.height,
      w_height = w.top_level.height - w_base_height,
      r_thickness = r_thickness(w),
      l_thickness = l_thickness(w),
      w_path = translate(w.path, vz(w_base_height)),
      w_paths = subpaths(w_path),
      r_w_paths = subpaths(offset(w_path, r_thickness)),
      l_w_paths = subpaths(offset(w_path, l_thickness)),
      openings = [w.doors..., w.windows...],
      prevlength = 0
    for (w_seg_path, r_w_path, l_w_path) in zip(w_paths, r_w_paths, l_w_paths)
      let currlength = prevlength + path_length(w_seg_path),
          c_r_w_path = closed_path_for_height(r_w_path, w_height),
          c_l_w_path = closed_path_for_height(l_w_path, w_height)
        realize_pyramid_fustrum(b, w, "wall", c_l_w_path, c_r_w_path, false)
        openings = filter(openings) do op
          if prevlength <= op.loc.x < currlength ||
             prevlength <= op.loc.x + op.family.width <= currlength # contained (at least, partially)
            let op_height = op.family.height,
                op_at_start = op.loc.x <= prevlength,
                op_at_end = op.loc.x + op.family.width >= currlength,
                op_path = subpath(w_path,
                                  max(prevlength, op.loc.x),
                                  min(currlength, op.loc.x + op.family.width)),
                r_op_path = offset(op_path, r_thickness),
                l_op_path = offset(op_path, l_thickness),
                fixed_r_op_path =
                  open_polygonal_path([path_start(op_at_start ? r_w_path : r_op_path),
                                       path_end(op_at_end ? r_w_path : r_op_path)]),
                fixed_l_op_path =
                  open_polygonal_path([path_start(op_at_start ? l_w_path : l_op_path),
                                       path_end(op_at_end ? l_w_path : l_op_path)]),
                c_r_op_path = closed_path_for_height(translate(fixed_r_op_path, vz(op.loc.y)), op_height),
                c_l_op_path = closed_path_for_height(translate(fixed_l_op_path, vz(op.loc.y)), op_height),
                idxs = closest_vertices_indexes(path_vertices(c_r_w_path), path_vertices(c_r_op_path))
              realize_pyramid_fustrum(b, w, "wall", c_r_op_path, c_l_op_path, false)
              c_r_w_path =
                closed_polygonal_path(
                  inject_polygon_vertices_at_indexes(path_vertices(c_r_w_path), path_vertices(c_r_op_path), idxs))
              c_l_w_path =
                closed_polygonal_path(
                  inject_polygon_vertices_at_indexes(path_vertices(c_l_w_path), path_vertices(c_l_op_path), idxs))
              # preserve if not totally contained
              ! (op.loc.x >= prevlength && op.loc.x + op.family.width <= currlength)
            end
          else
            true
          end
        end
        prevlength = currlength
        realize_polygon(b, w, "wall", c_l_w_path, false)
        realize_polygon(b, w, "wall", c_r_w_path, true)
      end
    end
    void_ref(b)
  end
=#
=#

backend_curtain_wall(b::UE, s, path::Path, bottom::Real, height::Real, thickness::Real, kind::Symbol) =
  backend_wall(b, translate(path, vz(bottom)), height, thickness, getproperty(s.family, kind))
############################################
#=
backend_bounding_box(b::UE, shapes::Shapes) =
  UEBoundingBox(connection(b), collect_ref(shapes))
=#
backend_set_view(b::UE, camera::Loc, target::Loc, lens::Real, aperture::Real) =
  let c = connection(b)
    @remote(b, Primitive__SetView(camera, target, lens,aperture))
  end

backend_get_view(b::UE) =
    (@remote(b, Primitive__ViewCamera()), @remote(b, Primitive__ViewTarget()), @remote(b, Primitive__ViewLens()))
#=
  zoom_extents(b::UE) = @remote(b, ZoomExtents())

  view_top(b::UE) = @remote(b, ViewTop())

unreal"public void DeleteAll()"
unreal"public void DeleteMany(AActor[] objs)"
=#
backend_delete_all_shapes(b::UE) = @remote(b, Primitive__DeleteAll())

backend_delete_shapes(b::UE, shapes::Shapes) =
    @remote(b, Primitive__DeleteMany(collect_ref(shapes)))
#=
set_length_unit(unit::String, b::UE) = nothing # Unused, for now

#=
# Dimensions

const UEDimensionStyles = Dict(:architectural => "_ARCHTICK", :mechanical => "")

dimension(p0::Loc, p1::Loc, p::Loc, scale::Real, style::Symbol, b::UE=current_backend()) =
    UECreateAlignedDimension(connection(b), p0, p1, p,
        scale,
        UEDimensionStyles[style])

dimension(p0::Loc, p1::Loc, sep::Real, scale::Real, style::Symbol, b::UE=current_backend()) =
    let v = p1 - p0
        angle = pol_phi(v)
        dimension(p0, p1, add_pol(p0, sep, angle + pi/2), scale, style, b)
    end

=#

# Layers
# Experiment for multiple, simultaneous, alternative layers
# Layers
unreal"public AActor CreateParent(String name)"
unreal"public AActor CurrentParent()"
unreal"public AActor SetCurrentParent(AActor newParent)"
unreal"public void SetActive(AActor obj, bool state)"
unreal"public void DeleteAllInParent(AActor parent)"
unreal"public void SwitchToParent(AActor newParent)"
=#
UELayer = Int

current_layer(b::UE)::UELayer =
  @remote(b, Primitive__CurrentParent())

current_layer(layer::UELayer, b::UE) =
  @remote(b, Primitive__SetCurrentParent(layer))
#=
create_layer(name::String, b::UE) =
  UECreateParent(connection(b), name)

set_layer_active(layer::UELayer, status, b::UE) =
  let c = connection(b)
    UESetActive(c, layer, status)
    interrupt_processing(c)
  end

delete_all_shapes_in_layer(layer::UELayer, b::UE) =
  UEDeleteAllInParent(connection(b), layer)

switch_to_layer(layer::UELayer, b::UE) =
  UESwitchToParent(connection(b), layer)

# Experiment to speed up things

canonicalize_layer(layer::UELayer, b::UE) =
  UECanonicalize(connection(b), layer)

# Materials
=#
UEMaterial = Int
#=
unreal"public Material LoadMaterial(String name)"
unreal"public void SetCurrentMaterial(Material material)"
unreal"public Material CurrentMaterial()"
=#
current_material(b::UE)::UEMaterial =
  @remote(b, Primitive__CurrentMaterial())

current_material(material::UEMaterial, b::UE) =
  @remote(b, Primitive__SetCurrentMaterial(material))

get_material(name::String, b::UE) =
  @remote(b, Primitive__LoadMaterial(name))

#=
# Blocks

unreal"public AActor CreateBlockInstance(AActor block, Vector3 position, Vector3 vx, Vector3 vy, float scale)"
unreal"public AActor CreateBlockFromShapes(String name, AActor[] objs)"
=#
realize(b::UE, s::Block) =
    @remote(b, Primitive__LoadResource(s.name))

realize(b::UE, s::BlockInstance) =
    @remote(b, Primitive__CreateBlockInstance(
        ref(s.block).value,
        s.loc, vx(1, s.loc.cs), vz(1, s.loc.cs), s.scale))
#=
#=
# Manual process
@time for i in 1:1000 for r in 1:10 circle(x(i*10), r) end end

# Create block...
Khepri.create_block("Foo", [circle(radius=r) for r in 1:10])

# ...and instantiate it
@time for i in 1:1000 Khepri.instantiate_block("Foo", x(i*10), 0) end

=#

# Lights
unreal"public AActor PointLight(Vector3 position, Color color, float range, float intensity)"
=#
backend_pointlight(b::UE, loc::Loc, color::RGB, range::Real, intensity::Real) =
    @remote(b, Primitive__PointLight(loc, color, range, intensity))

  backend_spotlightricardo(b::UE, loc::Loc,dir::Vec, color::RGB, range::Real, intensity::Real,hotspot::Real,falloff::Real) =
  @remote(b, Primitive__Spotlight( loc,dir,color,range,intensity, hotspot, falloff))
#=
backend_spotlight(b::UE, loc::Loc, dir::Vec, hotspot::Real, falloff::Real) =
      @remote(b, SpotLight( loc, hotspot, falloff, loc + dir))

backend_ieslight(b::UE, file::String, loc::Loc, dir::Vec, alpha::Real, beta::Real, gamma::Real) =
    UEIESLight(connection(b), file, loc, loc + dir, vxyz(alpha, beta, gamma))

#=
# User Selection
=#

shape_from_ref(r, b::UE) =
  let idx = findfirst(s -> r in collect_ref(s), collected_shapes())
    if isnothing(idx)
      let c = connection(b)
          unknown(r, backend=b, ref=LazyRef(b, UENativeRef(r), 0, 0))
          #code = UEShapeCode(c, r),
          #ref = LazyRef(b, UENativeRef(r))
          #error("Unknown shape with code $(code)")
      end
    else
      collected_shapes()[idx]
    end
  end
#
#=
UE"public Point3d[] GetPosition(string prompt)"

select_position(prompt::String, b::UE) =
  begin
    @info "$(prompt) on the $(b) backend."
    let ans = UEGetPosition(connection(b), prompt)
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

UE"public ObjectId[] GetPoint(string prompt)"

# HACK: The next operations should receive a set of shapes to avoid re-creating already existing shapes

select_point(prompt::String, b::UE) =
  select_with_prompt(prompt, b, UEGetPoint)

UE"public ObjectId[] GetCurve(string prompt)"

select_curve(prompt::String, b::UE) =
  select_with_prompt(prompt, b, UEGetCurve)

UE"public ObjectId[] GetSurface(string prompt)"

select_surface(prompt::String, b::UE) =
  select_with_prompt(prompt, b, UEGetSurface)

UE"public ObjectId[] GetSolid(string prompt)"

select_solid(prompt::String, b::UE) =
  select_with_prompt(prompt, b, UEGetSolid)

UE"public ObjectId[] GetShape(string prompt)"

select_shape(prompt::String, b::UE) =
  select_with_prompt(prompt, b, UEGetShape)

UE"public long GetHandleFromShape(Entity e)"
UE"public ObjectId GetShapeFromHandle(long h)"

captured_shape(b::UE, handle) =
  shape_from_ref(UEGetShapeFromHandle(connection(b), handle),
                 b)

generate_captured_shape(s::Shape, b::UE) =
    println("captured_shape(autocad, $(UEGetHandleFromShape(connection(b), ref(s).value)))")

# Register for notification

UE"public void RegisterForChanges(ObjectId id)"
UE"public void UnregisterForChanges(ObjectId id)"
UE"public ObjectId[] ChangedShape()"
UE"public void DetectCancel()"
UE"public void UndetectCancel()"
UE"public bool WasCanceled()"

register_for_changes(s::Shape, b::UE) =
    let conn = connection(b)
        UERegisterForChanges(conn, ref(s).value)
        UEDetectCancel(conn)
        s
    end

unregister_for_changes(s::Shape, b::UE) =
    let conn = connection(b)
        UEUnregisterForChanges(conn, ref(s).value)
        UEUndetectCancel(conn)
        s
    end

waiting_for_changes(s::Shape, b::UE) =
    ! UEWasCanceled(connection(b))

changed_shape(ss::Shapes, b::UE) =
    let conn = connection(b)
        changed = []
        while length(changed) == 0 && ! UEWasCanceled(conn)
            changed =  UEChangedShape(conn)
            sleep(0.1)
        end
        if length(changed) > 0
            shape_from_ref(changed[1], b)
        else
            nothing
        end
    end

UE"public ObjectId[] GetAllShapes()"
UE"public ObjectId[] GetAllShapesInLayer(ObjectId layerId)"

# HACK: This should be filtered on the plugin, not here.
all_shapes(b::UE) =
    let c = connection(b)
        Shape[shape_from_ref(r, b)
              for r in filter(r -> UEShapeCode(c, r) != 0, UEGetAllShapes(c))]
    end

all_shapes_in_layer(layer, b::UE) =
    let c = connection(b)
        Shape[shape_from_ref(r, b) for r in UEGetAllShapesInLayer(c, layer)]
    end

disable_update(b::UE) =
    UEDisableUpdate(connection(b))

enable_update(b::UE) =
    UEEnableUpdate(connection(b))
# Render

=#
unreal"public void SetResolution(int width, int height)"
unreal"public void ScreenShot(String path)"

#render exposure: [-3, +3] -> [-6, 21]
convert_render_exposure(b::UE, v::Real) = -4.05*v + 8.8
#render quality: [-1, +1] -> [+1, +50]
convert_render_quality(b::UE, v::Real) = round(Int, 25.5 + 24.5*v)
=#
render_view(path::String, b::UE) =
    begin
      @remote(b, Primitive__RenderView(render_width(), render_height(),film_filename(),path,film_frame()))
      path
    end
#=
unreal"public void SelectAActors(AActor[] objs)"

highlight_shape(s::Shape, b::UE) =
    UESelectAActors(connection(b), collect_ref(s))

highlight_shapes(ss::Shapes, b::UE) =
    UESelectAActors(connection(b), collect_ref(ss))


unreal"public void StartSelectingAActor()"
unreal"public int SelectedAActorId(bool existing)"

select_shape(prompt::String, b::UE) =
  select_one_with_prompt(prompt, b, (c, prompt) ->
    let s = -2 # Means not found
      UEStartSelectingAActor(c)
      while s == -2
        sleep(0.1)
        s = UESelectedAActorId(c, true)
      end
      [s]
    end)
=#

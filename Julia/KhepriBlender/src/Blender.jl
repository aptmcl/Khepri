# Blender
export blender

const blender_folder = Parameter("C:/Program Files/Blender Foundation/Blender 2.91/")
blender_cmd(cmd::AbstractString="blender.exe") = blender_folder() * cmd
const KhepriServerPath = Parameter(abspath(@__DIR__, "../../../Plugins/KhepriBlender/KhepriServer.py"))

start_blender() =
  run(detach(`$(blender_cmd()) --python $(KhepriServerPath())`), wait=false)

#=
sel = utils.selection_get()
                            bpy.ops.view3d.select(location=(event.mouse_region_x, event.mouse_region_y))
                            sel1 = utils.selection_get()
                            if sel[0] != sel1[0] and sel1[0].type != 'MESH':
                                object = sel1[0]
                                target_slot = sel1[0].active_material_index
                                ui_props.has_hit = True
                            utils.selection_set(sel)


def mouse_raycast(context, mx, my):
    r = context.region
    rv3d = context.region_data
    coord = mx, my

    # get the ray from the viewport and mouse
    view_vector = view3d_utils.region_2d_to_vector_3d(r, rv3d, coord)
    ray_origin = view3d_utils.region_2d_to_origin_3d(r, rv3d, coord)
    ray_target = ray_origin + (view_vector * 1000000000)

    vec = ray_target - ray_origin

    has_hit, snapped_location, snapped_normal, face_index, object, matrix = bpy.context.scene.ray_cast(
        bpy.context.view_layer, ray_origin, vec)

    # rote = mathutils.Euler((0, 0, math.pi))
    randoffset = math.pi
    if has_hit:
        snapped_rotation = snapped_normal.to_track_quat('Z', 'Y').to_euler()
        up = Vector((0, 0, 1))
        props = bpy.context.scene.blenderkit_models
        if props.randomize_rotation and snapped_normal.angle(up) < math.radians(10.0):
            randoffset = props.offset_rotation_amount + math.pi + (
                    random.random() - 0.5) * props.randomize_rotation_amount
        else:
            randoffset = props.offset_rotation_amount  # we don't rotate this way on walls and ceilings. + math.pi
        # snapped_rotation.z += math.pi + (random.random() - 0.5) * .2

    else:
        snapped_rotation = mathutils.Quaternion((0, 0, 0, 0)).to_euler()

    snapped_rotation.rotate_axis('Z', randoffset)

    return has_hit, snapped_location, snapped_normal, snapped_rotation, face_index, object, matrix

=#

# BLR is a subtype of Python
parse_signature(::Val{:BLR}, sig::T) where {T} = parse_signature(Val(:PY), sig)
encode(::Val{:BLR}, t::Val{T}, c::IO, v) where {T} = encode(Val(:PY), t, c, v)
decode(::Val{:BLR}, t::Val{T}, c::IO) where {T} = decode(Val(:PY), t, c)
encode(ns::Val{:BLR}, t::Tuple{T1,T2,T3}, c::IO, v) where {T1,T2,T3} =
  begin
    encode(ns, T1(), c, v[1])
    encode(ns, T2(), c, v[2])
    encode(ns, T3(), c, v[3])
  end
decode(ns::Val{:BLR}, t::Tuple{T1,T2,T3}, c::IO) where {T1,T2,T3} =
  (decode(ns, T1(), c),
   decode(ns, T2(), c),
   decode(ns, T3(), c))
#=
# We need some additional Encoders
@encode_decode_as(:BLR, Val{:Entity}, Val{:size})
@encode_decode_as(:BLR, Val{:ObjectId}, Val{:size})
@encode_decode_as(:BLR, Val{:BIMLevel}, Val{:size})
@encode_decode_as(:BLR, Val{:FloorFamily}, Val{:size})
=#
@encode_decode_as(:BLR, Val{:Id}, Val{:size})
@encode_decode_as(:BLR, Val{:MatId}, Val{:size})

encode(::Val{:BLR}, t::Union{Val{:Point3d},Val{:Vector3d}}, c::IO, p) =
  encode(Val(:PY), Val(:float3), c, raw_point(p))
decode(::Val{:BLR}, t::Val{:Point3d}, c::IO) =
  xyz(decode(Val(:PY), Val(:float3), c)..., world_cs)
decode(::Val{:BLR}, t::Val{:Vector3d}, c::IO) =
  vxyz(decode(Val(:PY), Val(:float3), c)..., world_cs)

encode(ns::Val{:BLR}, t::Val{:Frame3d}, c::IO, v) = begin
  encode(ns, Val(:Point3d), c, v)
  t = v.cs.transform
  encode(Val(:PY), Val(:float3), c, (t[1,1], t[2,1], t[3,1]))
  encode(Val(:PY), Val(:float3), c, (t[1,2], t[2,2], t[3,2]))
  encode(Val(:PY), Val(:float3), c, (t[1,3], t[2,3], t[3,3]))
end

decode(ns::Val{:BLR}, t::Val{:Frame3d}, c::IO) =
  u0(cs_from_o_vx_vy_vz(
      decode(ns, Val(:Point3d), c),
      decode(ns, Val(:Vector3d), c),
      decode(ns, Val(:Vector3d), c),
      decode(ns, Val(:Vector3d), c)))

blender_api = @remote_functions :BLR """
def delete_all_shapes()->None:
def delete_shape(name:Id)->None:
def get_material(name:str)->MatId:
def get_blenderkit_material(ref:str)->MatId:
def new_material(name:str, diffuse_color:RGBA, specularity:float, roughness:float)->MatId:
def mesh(verts:List[Point3d], edges:List[Tuple[int,int]], faces:List[List[int]], mat:MatId)->Id:
def objmesh(verts:List[Point3d], edges:List[Tuple[int,int]], faces:List[List[int]], smooth:bool, mat:MatId)->Id:
def trig(p1:Point3d, p2:Point3d, p3:Point3d, mat:MatId)->Id:
def quad(p1:Point3d, p2:Point3d, p3:Point3d, p4:Point3d, mat:MatId)->Id:
def quad_strip(ps:List[Point3d], qs:List[Point3d], smooth:bool, mat:MatId)->Id:
def quad_strip_closed(ps:List[Point3d], qs:List[Point3d], smooth:bool, mat:MatId)->Id:
def ngon(ps:List[Point3d], pivot:Point3d, smooth:bool, mat:MatId)->Id:
def polygon(ps:List[Point3d], mat:MatId)->Id:
def surface(pss:List[List[Point3d]], mat:MatId)->Id:
def cuboid(verts:List[Point3d], mat:MatId)->Id:
def pyramid_frustum(bs:List[Point3d], ts:List[Point3d], smooth:bool, bmat:MatId, tmat:MatId, smat:MatId)->Id:
def sphere(center:Point3d, radius:float, mat:MatId)->Id:
def cone_frustum(b:Point3d, br:float, t:Point3d, tr:float, bmat:MatId, tmat:MatId, smat:MatId)->Id:
def box(p:Point3d, vx:Vector3d, vy:Vector3d, dx:float, dy:float, dz:float, mat:MatId)->Id:
def text(txt:str, p:Point3d, vx:Vector3d, vy:Vector3d, size:float)->Id:
def set_view(camera:Point3d, target:Point3d, lens:float)->None:
def get_view()->Tuple[Point3d, Point3d, float]:
def set_camera_view(camera:Point3d, target:Point3d, lens:float)->None:
def area_light(p:Point3d, v:Vector3d, size:float, color:RGBA, strength:float)->Id:
def sun_light(p:Point3d, v:Vector3d)->Id:
def light(p:Point3d, type:str)->Id:
def camera_from_view()->None:
def set_render_size(width:int, height:int)->None:
def render_to_file(filepath:str)->None:
def cycles_renderer(samples:int, denoising:bool, motion_blur:bool, transparent:bool)->None:
"""

abstract type BLRKey end
const BLRId = Int64
const BLRIds = Vector{BLRId}
const BLRRef = NativeRef{BLRKey, BLRId}
const BLRRefs = Vector{BLRRef}
const BLREmptyRef = EmptyRef{BLRKey, BLRId}
const BLRUniversalRef = UniversalRef{BLRKey, BLRId}
const BLRUnionRef = UnionRef{BLRKey, BLRId}
const BLRSubtractionRef = SubtractionRef{BLRKey, BLRId}
const BLR = SocketBackend{BLRKey, BLRId}

create_blender_connection() =
  let port = blender_port,
		  backend = "Blender"
		for i in 1:10
    	try
      	return connect(port)
      catch e
        if i == 1
					@info("Starting $(backend).")
  				start_blender()
        	sleep(1)
				elseif i == 9
          throw(e)
				else
					sleep(1)
        end
      end
    end
	end

#const
blender = BLR(LazyParameter(TCPSocket, create_blender_connection), blender_api)

backend_name(::BLR) = "Blender"
KhepriBase.has_boolean_ops(::Type{BLR}) = HasBooleanOps{false}()


backend(::BLRRef) = blender
void_ref(b::BLR) = BLRRef(-1)

# Primitives
KhepriBase.b_trig(b::BLR, p1, p2, p3, mat) =
  @remote(b, trig(p1, p2, p3, mat))

KhepriBase.b_quad(b::BLR, p1, p2, p3, p4, mat) =
	@remote(b, quad(p1, p2, p3, p4, mat))

KhepriBase.b_ngon(b::BLR, ps, pivot, smooth, mat) =
	@remote(b, ngon(ps, pivot, smooth, mat))

KhepriBase.b_quad_strip(b::BLR, ps, qs, smooth, mat) =
  @remote(b, quad_strip(ps, qs, smooth, mat))

KhepriBase.b_quad_strip_closed(b::BLR, ps, qs, smooth, mat) =
  @remote(b, quad_strip_closed(ps, qs, smooth, mat))

KhepriBase.b_surface_polygon(b::BLR, ps, mat) =
  @remote(b, polygon(ps, mat))

KhepriBase.b_surface_polygon_with_holes(b::BLR, ps, qss, mat) =
  @remote(b, surface([ps, qss...], mat))

KhepriBase.b_generic_pyramid_frustum(b::BLR, bs, ts, smooth, bmat, tmat, smat) =
  @remote(b, pyramid_frustum(bs, ts, smooth, bmat, tmat, smat))

KhepriBase.b_cone(b::BLR, cb, r, h, bmat, smat) =
  @remote(b, cone_frustum(cb, r, add_z(cb, h), 0, bmat, bmat, smat))

KhepriBase.b_cone_frustum(b::BLR, cb, rb, h, rt, bmat, tmat, smat) =
    @remote(b, cone_frustum(cb, rb, add_z(cb, h), rt, bmat, tmat, smat))

KhepriBase.b_cylinder(b::BLR, cb, r, h, mat) =
  @remote(b, cone_frustum(cb, r, add_z(cb, h), r, mat, mat, mat))

KhepriBase.b_cuboid(b::BLR, pb0, pb1, pb2, pb3, pt0, pt1, pt2, pt3, mat) =
  @remote(b, cuboid([pb0, pb1, pb2, pb3, pt0, pt1, pt2, pt3], mat))

KhepriBase.b_sphere(b::BLR, c, r, mat) =
  @remote(b, sphere(c, r, mat))

# Materials

KhepriBase.b_get_material(b::BLR, ref) =
  get_blender_material(b, ref)

get_blender_material(b, ref::Nothing) = void_ref(b)

#=
Important source of materials:

1. Activate Blender's blenderkit addon:
https://www.blenderkit.com/get-blenderkit/

2. Browse BlenderKit's material database:
https://www.blenderkit.com/asset-gallery?query=category_subtree:material

3. Select material and copy reference, e.g.:
asset_base_id:ced25dc0-d461-42f7-aa03-85cb88f671a1 asset_type:material

4. Install material and retrive its id with:
b_get_material(blender, "asset_base_id:ced25dc0-d461-42f7-aa03-85cb88f671a1 asset_type:material")
=#

get_blender_material(b, ref::AbstractString) =
  startswith(ref, "asset_base_id") ?
    @remote(b, get_blenderkit_material(ref)) :
    @remote(b, get_material(ref))

KhepriBase.b_new_material(b::BLR, path, color, specularity, roughness, transmissivity, transmitted_specular) =
  @remote(b, new_material(path, convert(RGBA, color), specularity, roughness))

# BIM





#=
b_regular_pyramid_frustum(b, 32, cb, r, 0, h, r, true, mat, mat, mat)



backend_surface_polygon(b::BLR, vs::Locs) =
  @remote(b, mesh(vs, [], [collect(0:length(vs)-1)]))


=#
#=

Default families

=#
export blender_family_materials
blender_family_materials(m1, m2=m1, m3=m2, m4=m3) = (materials=(m1, m2, m3, m4), )


abstract type BLRFamily <: Family end

struct BLRLayerFamily <: BLRFamily
  name::String
  color::RGB
  ref::Parameter{Any}
end

blender_layer_family(name, color::RGB=rgb(1,1,1)) =
  BLRLayerFamily(name, color, Parameter{Any}(nothing))

backend_get_family_ref(b::BLR, f::Family, af::BLRLayerFamily) =
  nothing #backend_create_layer(b, af.name, true, af.color)

#=
#=
backend_stroke_color(b::BLR, path::Path, color::RGB) =
    let r = backend_stroke(b, path)
        @remote(b, SetShapeColor(r, color.r, color.g, color.b))
        r
    end

backend_stroke(b::BLR, path::CircularPath) =
    @remote(b, Circle(path.center, vz(1, path.center.cs), path.radius))
backend_stroke(b::BLR, path::RectangularPath) =
    let c = path.corner,
        dx = path.dx,
        dy = path.dy
        @remote(b, ClosedPolyLine([c, add_x(c, dx), add_xy(c, dx, dy), add_y(c, dy)]))
    end
backend_stroke(b::BLR, path::ArcPath) =
    backend_stroke_arc(b, path.center, path.radius, path.start_angle, path.amplitude)

backend_stroke(b::BLR, path::OpenPolygonalPath) =
  	@remote(b, PolyLine(path.vertices))
backend_stroke(b::BLR, path::ClosedPolygonalPath) =
    backend_polygon(b, path.vertices)
backend_polygon(b::BLR, vs::Locs) =
  @remote(b, ClosedPolyLine(vs))
backend_fill(b::BLR, path::ClosedPolygonalPath) =
    @remote(b, SurfaceClosedPolyLine(path.vertices))
backend_fill(b::BLR, path::RectangularPath) =
    let c = path.corner,
        dx = path.dx,
        dy = path.dy
        @remote(b, SurfaceClosedPolyLine([c, add_x(c, dx), add_xy(c, dx, dy), add_y(c, dy)]))
    end
backend_stroke(b::BLR, path::OpenSplinePath) =
  if (path.v0 == false) && (path.v1 == false)
    #@remote(b, Spline(path.vertices))
    @remote(b, InterpSpline(
                     path.vertices,
                     path.vertices[2]-path.vertices[1],
                     path.vertices[end]-path.vertices[end-1]))
  elseif (path.v0 != false) && (path.v1 != false)
    @remote(b, InterpSpline(path.vertices, path.v0, path.v1))
  else
    @remote(b, InterpSpline(
                     path.vertices,
                     path.v0 == false ? path.vertices[2]-path.vertices[1] : path.v0,
                     path.v1 == false ? path.vertices[end-1]-path.vertices[end] : path.v1))
  end
backend_stroke(b::BLR, path::ClosedSplinePath) =
    @remote(b, InterpClosedSpline(path.vertices))
backend_fill(b::BLR, path::ClosedSplinePath) =
    backend_fill_curves(b, @remote(b, InterpClosedSpline(path.vertices)))

backend_fill_curves(b::BLR, refs::BLRIds) = @remote(b, SurfaceFromCurves(refs))
backend_fill_curves(b::BLR, ref::BLRId) = @remote(b, SurfaceFromCurves([ref]))

backend_stroke_arc(b::BLR, center::Loc, radius::Real, start_angle::Real, amplitude::Real) =
  let p = in_world(add_pol(center, radius, start_angle)),
      c = in_world(center),
      alpha = pol_phi(p-c),
      end_angle = alpha + amplitude
    @remote(b, Arc(center, vz(1, center.cs), radius, alpha, end_angle))
  end
backend_stroke_unite(b::BLR, refs) = @remote(b, JoinCurves(refs))

=#
=#
realize(b::BLR, s::EmptyShape) =
  BLREmptyRef()
realize(b::BLR, s::UniversalShape) =
  BLRUniversalRef()
#=
realize(b::BLR, s::Point) =
  @remote(b, Point(s.position))
realize(b::BLR, s::Line) =
  @remote(b, PolyLine(s.vertices))
realize(b::BLR, s::Spline) = # This should be merged with opensplinepath
  if (s.v0 == false) && (s.v1 == false)
    #@remote(b, Spline(s.points))
    @remote(b, InterpSpline(
                     s.points,
                     s.points[2]-s.points[1],
                     s.points[end]-s.points[end-1]))
  elseif (s.v0 != false) && (s.v1 != false)
    @remote(b, InterpSpline(s.points, s.v0, s.v1))
  else
    @remote(b, InterpSpline(
                     s.points,
                     s.v0 == false ? s.points[2]-s.points[1] : s.v0,
                     s.v1 == false ? s.points[end-1]-s.points[end] : s.v1))
  end
realize(b::BLR, s::ClosedSpline) =
  @remote(b, InterpClosedSpline(s.points))
realize(b::BLR, s::Circle) =
  @remote(b, Circle(s.center, vz(1, s.center.cs), s.radius))
realize(b::BLR, s::Arc) =
  if s.radius == 0
    @remote(b, Point(s.center))
  elseif s.amplitude == 0
    @remote(b, Point(s.center + vpol(s.radius, s.start_angle, s.center.cs)))
  elseif abs(s.amplitude) >= 2*pi
    @remote(b, Circle(s.center, vz(1, s.center.cs), s.radius))
  else
    end_angle = s.start_angle + s.amplitude
    if end_angle > s.start_angle
      @remote(b, Arc(s.center, vz(1, s.center.cs), s.radius, s.start_angle, end_angle))
    else
      @remote(b, Arc(s.center, vz(1, s.center.cs), s.radius, end_angle, s.start_angle))
    end
  end

realize(b::BLR, s::Ellipse) =
  if s.radius_x > s.radius_y
    @remote(b, Ellipse(s.center, vz(1, s.center.cs), vxyz(s.radius_x, 0, 0, s.center.cs), s.radius_y/s.radius_x))
  else
    @remote(b, Ellipse(s.center, vz(1, s.center.cs), vxyz(0, s.radius_y, 0, s.center.cs), s.radius_x/s.radius_y))
  end
realize(b::BLR, s::EllipticArc) =
  error("Finish this")

realize(b::BLR, s::Polygon) =
  @remote(b, ClosedPolyLine(s.vertices))
realize(b::BLR, s::RegularPolygon) =
  @remote(b, ClosedPolyLine(regular_polygon_vertices(s.edges, s.center, s.radius, s.angle, s.inscribed)))
realize(b::BLR, s::Rectangle) =
  @remote(b, ClosedPolyLine(
    [s.corner,
     add_x(s.corner, s.dx),
     add_xy(s.corner, s.dx, s.dy),
     add_y(s.corner, s.dy)]))
realize(b::BLR, s::SurfaceCircle) =
  @remote(b, SurfaceCircle(s.center, vz(1, s.center.cs), s.radius))
realize(b::BLR, s::SurfaceArc) =
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
            @remote(b, SurfaceFromCurves(
                [@remote(b, Arc(s.center, vz(1, s.center.cs), s.radius, s.start_angle, end_angle)),
                 @remote(b, PolyLine([add_pol(s.center, s.radius, end_angle),
                                              add_pol(s.center, s.radius, s.start_angle)]))]))
        else
            @remote(b, SurfaceFromCurves(
                [@remote(b, Arc(s.center, vz(1, s.center.cs), s.radius, end_angle, s.start_angle)),
                 @remote(b, PolyLine([add_pol(s.center, s.radius, s.start_angle),
                                              add_pol(s.center, s.radius, end_angle)]))]))
        end
    end

realize(b::BLR, s::SurfaceEllipse) =
  if s.radius_x > s.radius_y
    @remote(b, SurfaceEllipse(s.center, vz(1, s.center.cs), vxyz(s.radius_x, 0, 0, s.center.cs), s.radius_y/s.radius_x))
  else
    @remote(b, SurfaceEllipse(s.center, vz(1, s.center.cs), vxyz(0, s.radius_y, 0, s.center.cs), s.radius_x/s.radius_y))
  end
=#

backend_surface_polygon(b::BLR, vs::Locs) =
  @remote(b, mesh(vs, [], [collect(0:length(vs)-1)], default_material))

#=
realize(b::BLR, s::Surface) =
  let #ids = map(r->@remote(b, NurbSurfaceFrom(r)), @remote(b, SurfaceFromCurves(collect_ref(s.frontier))))
      ids = @remote(b, SurfaceFromCurves(collect_ref(s.frontier)))
    foreach(mark_deleted, s.frontier)
    ids
  end
backend_surface_boundary(b::BLR, s::Shape2D) =
    map(c -> backend_shape_from_ref(b, r), @remote(b, CurvesFromSurface(ref(s).value)))

# Iterating over curves and surfaces


old_backend_map_division(b::BLR, f::Function, s::Shape1D, n::Int) =
  let r = ref(s).value,
      (t1, t2) = @remote(b, CurveDomain(r))
    map_division(t1, t2, n) do t
      f(@remote(b, CurveFrameAt(r, t)))
    end
  end

# For low level access:

backend_map_division(b::BLR, f::Function, s::Shape1D, n::Int) =
  let r = ref(s).value,
      (t1, t2) = @remote(b, CurveDomain(r)),
      ti = division(t1, t2, n),
      ps = @remote(b, CurvePointsAt(r, ti)),
      ts = @remote(b, CurveTangentsAt(r, ti)),
      #ns = @remote(b, CurveNormalsAt(r, ti)),
      frames = rotation_minimizing_frames(@remote(b, CurveFrameAt(r, t1)), ps, ts)
    map(f, frames)
  end
=#
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

#=
backend_surface_domain(b::BLR, s::Shape2D) =
    tuple(@remote(b, SurfaceDomain(ref(s).value))...)

backend_map_division(b::BLR, f::Function, s::Shape2D, nu::Int, nv::Int) =
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


backend_map_division(b::BLR, f::Function, s::SurfaceGrid, nu::Int, nv::Int) =
let conn = connection(b)
    r = ref(s).value
    (u1, u2, v1, v2) = @remote(b, SurfaceDomain(r))
    map_division(u1, u2, nu) do u
        map_division(v1, v2, nv) do v
            f(@remote(b, SurfaceFrameAt(r, u, v)))
        end
    end
end

realize(b::BLR, s::Text) =
  @remote(b, Text(
    s.str, s.corner, vx(1, s.corner.cs), vy(1, s.corner.cs), s.height))

realize(b::BLR, s::Torus) =
  @remote(b, Torus(s.center, vz(1, s.center.cs), s.re, s.ri))

backend_pyramid(b::BLR, bs::Locs, t::Loc) =
  @remote(b, IrregularPyramid(bs, t))
backend_pyramid_frustum(b::BLR, bs::Locs, ts::Locs) =
  @remote(b, IrregularPyramidFrustum(bs, ts))

backend_right_cuboid(b::BLR, cb, width, height, h, material) =
  @remote(b, CenteredBox(cb, width, height, h))
realize(b::BLR, s::Box) =
  @remote(b, Box(s.c, s.dx, s.dy, s.dz))
realize(b::BLR, s::Cone) =
  @remote(b, Cone(add_z(s.cb, s.h), s.r, s.cb))
realize(b::BLR, s::ConeFrustum) =
  @remote(b, ConeFrustum(s.cb, s.rb, s.cb + vz(s.h, s.cb.cs), s.rt))

backend_extrusion(b::BLR, s::Shape, v::Vec) =
    and_mark_deleted(b,
        map_ref(s) do r
            @remote(b, Extrude(r, v))
        end,
        s)

backend_sweep(b::BLR, path::Shape, profile::Shape, rotation::Real, scale::Real) =
  and_mark_deleted(b,
    map_ref(profile) do profile_r
      map_ref(path) do path_r
        @remote(b, Sweep(path_r, profile_r, rotation, scale))
      end
  end, [profile, path])

backend_revolve_point(b::BLR, profile::Shape, p::Loc, n::Vec, start_angle::Real, amplitude::Real) =
  realize(b, arc(loc_from_o_vz(p, n), distance(profile, p), start_angle, amplitude))
backend_revolve_curve(b::BLR, profile::Shape, p::Loc, n::Vec, start_angle::Real, amplitude::Real) =
  blender_revolution(b, profile, p, n, start_angle, amplitude)
backend_revolve_surface(b::BLR, profile::Shape, p::Loc, n::Vec, start_angle::Real, amplitude::Real) =
  blender_revolution(b, profile, p, n, start_angle, amplitude)

blender_revolution(b::BLR, profile::Shape, p::Loc, n::Vec, start_angle::Real, amplitude::Real) =
  and_delete_shape(
    map_ref(profile) do r
      @remote(b, Revolve(r, p, n, start_angle, amplitude))
    end,
    profile)

backend_loft_curves(b::BLR, profiles::Shapes, rails::Shapes, ruled::Bool, closed::Bool) =
  and_delete_shapes(@remote(b, Loft(
                             collect_ref(profiles),
                             collect_ref(rails),
                             ruled, closed)),
                    vcat(profiles, rails))

backend_loft_surfaces(b::BLR, profiles::Shapes, rails::Shapes, ruled::Bool, closed::Bool) =
    backend_loft_curves(b, profiles, rails, ruled, closed)

backend_loft_curve_point(b::BLR, profile::Shape, point::Shape) =
    and_delete_shapes(@remote(b, Loft(
                               vcat(collect_ref(profile), collect_ref(point)),
                               [],
                               true, false)),
                      [profile, point])

backend_loft_surface_point(b::BLR, profile::Shape, point::Shape) =
    backend_loft_curve_point(b, profile, point)

unite_ref(b::BLR, r0::BLRRef, r1::BLRRef) =
    ensure_ref(b, @remote(b, Unite(r0.value, r1.value)))

intersect_ref(b::BLR, r0::BLRRef, r1::BLRRef) =
    ensure_ref(b, @remote(b, Intersect(r0.value, r1.value)))

subtract_ref(b::BLR, r0::BLRRef, r1::BLRRef) =
    ensure_ref(b, @remote(b, Subtract(r0.value, r1.value)))

slice_ref(b::BLR, r::BLRRef, p::Loc, v::Vec) =
    (@remote(b, Slice(r.value, p, v)); r)

slice_ref(b::BLR, r::BLRUnionRef, p::Loc, v::Vec) =
    BLRUnionRef(map(r->slice_ref(b, r, p, v), r.values))

unite_refs(b::BLR, refs::Vector{<:BLRRef}) =
    BLRUnionRef(tuple(refs...))

realize(b::BLR, s::IntersectionShape) =
  let r = foldl(intersect_ref(b), map(ref, s.shapes),
                init=BLRUniversalRef())
    mark_deleted(b, s.shapes)
    r
  end

realize(b::BLR, s::Slice) =
  slice_ref(b, ref(s.shape), s.p, s.n)

realize(b::BLR, s::Move) =
  let r = map_ref(b, s.shape) do r
            @remote(b, Move(r, s.v))
            r
          end
    mark_deleted(b, s.shape)
    r
  end

realize(b::BLR, s::Transform) =
  let r = map_ref(b, s.shape) do r
            @remote(b, Transform(r, s.xform))
            r
          end
    mark_deleted(b, s.shape)
    r
  end

realize(b::BLR, s::Scale) =
  let r = map_ref(b, s.shape) do r
            @remote(b, Scale(r, s.p, s.s))
            r
          end
    mark_deleted(b, s.shape)
    r
  end

realize(b::BLR, s::Rotate) =
  let r = map_ref(b, s.shape) do r
            @remote(b, Rotate(r, s.p, s.v, s.angle))
            r
          end
    mark_deleted(b, s.shape)
    r
  end

realize(b::BLR, s::Mirror) =
  and_mark_deleted(b, map_ref(s.shape) do r
                    @remote(b, Mirror(r, s.p, s.n, false))
                   end,
                   s.shape)

realize(b::BLR, s::UnionMirror) =
  let r0 = ref(b, s.shape),
      r1 = map_ref(b, s.shape) do r
            @remote(b, Mirror(r, s.p, s.n, true))
          end
    UnionRef((r0,r1))
  end

backend_surface_grid(b::BLR, points, closed_u, closed_v, smooth_u, smooth_v) =
    @remote(b, SurfaceFromGrid(
        size(points,2),
        size(points,1),
        reshape(points,:),
        closed_u,
        closed_v,
        # Autocad does not allow us to distinguish smoothness along different dimensions
        smooth_u && smooth_v ? 2 : 0))

realize(b::BLR, s::Thicken) =
  and_mark_deleted(b,
    map_ref(b, s.shape) do r
      @remote(b, Thicken(r, s.thickness))
    end,
    s.shape)

# backend_frame_at
backend_frame_at(b::BLR, s::Circle, t::Real) = add_pol(s.center, s.radius, t)

backend_frame_at(b::BLR, c::Shape1D, t::Real) = @remote(b, CurveFrameAt(ref(c).value, t))

#backend_frame_at(b::BLR, s::Surface, u::Real, v::Real) =
    #What should we do with v?
#    backend_frame_at(b, s.frontier[1], u)

#backend_frame_at(b::BLR, s::SurfacePolygon, u::Real, v::Real) =

backend_frame_at(b::BLR, s::Shape2D, u::Real, v::Real) = @remote(b, SurfaceFrameAt(ref(s).value, u, v))

# BIM
realize(b::BLR, f::TableFamily) =
    @remote(b, CreateRectangularTableFamily(f.length, f.width, f.height, f.top_thickness, f.leg_thickness))
realize(b::BLR, f::ChairFamily) =
    @remote(b, CreateChairFamily(f.length, f.width, f.height, f.seat_height, f.thickness))
realize(b::BLR, f::TableChairFamily) =
    @remote(b, CreateRectangularTableAndChairsFamily(
        realize(b, f.table_family), realize(b, f.chair_family),
        f.table_family.length, f.table_family.width,
        f.chairs_top, f.chairs_bottom, f.chairs_right, f.chairs_left,
        f.spacing))

backend_rectangular_table(b::BLR, c, angle, family) =
    @remote(b, Table(c, angle, realize(b, family)))

backend_chair(b::BLR, c, angle, family) =
    @remote(b, Chair(c, angle, realize(b, family)))

backend_rectangular_table_and_chairs(b::BLR, c, angle, family) =
    @remote(b, TableAndChairs(c, angle, realize(b, family)))

backend_slab(b::BLR, profile, holes, thickness, family) =
  let slab(profile) = map_ref(b, r -> @remote(b, Extrude(r, vz(thickness))),
                              ensure_ref(b, backend_fill(b, profile))),
      main_body = slab(profile),
      holes_bodies = map(slab, holes)
    foldl((r0, r1)->subtract_ref(b, r0, r1), holes_bodies, init=main_body)
  end
=#
#=
realize_beam_profile(b::BLR, s::Union{Beam,FreeColumn,Column}, profile::CircularPath, cb::Loc, length::Real) =
  @remote(b, Cylinder(cb, profile.radius, add_z(cb, length)))

realize_beam_profile(b::BLR, s::Union{Beam,Column}, profile::RectangularPath, cb::Loc, length::Real) =
  let profile_u0 = profile.corner,
      c = add_xy(s.cb, profile_u0.x + profile.dx/2, profile_u0.y + profile.dy/2)
      # need to test whether it is rotation on center or on axis
      o = loc_from_o_phi(c, s.angle)
    @remote(b, CenteredBox(add_y(o, -profile.dy/2), profile.dx, profile.dy, length))
  end

#Columns are aligned along the center axis.
realize_beam_profile(b::BLR, s::FreeColumn, profile::RectangularPath, cb::Loc, length::Real) =
  let profile_u0 = profile.corner,
      c = add_xy(s.cb, profile_u0.x + profile.dx/2, profile_u0.y + profile.dy/2)
      # need to test whether it is rotation on center or on axis
      o = loc_from_o_phi(c, s.angle)
    @remote(b, CenteredBox(o, profile.dx, profile.dy, length))
  end
=#
#=
backend_wall(b::BLR, path, height, l_thickness, r_thickness, family) =
  @remote(b,
    Thicken(@remote(b,
      Extrude(backend_stroke(b, offset(path, (l_thickness - r_thickness)/2)),
              vz(height))),
      r_thickness + l_thickness))

backend_panel(b::BLR, bot::Locs, top::Locs, family) =
  @remote(b, IrregularPyramidFrustum(bot, top))

############################################

backend_bounding_box(b::BLR, shapes::Shapes) =
  @remote(b, BoundingBox(collect_ref(shapes)))

=#

KhepriBase.b_set_view(b::BLR, camera::Loc, target::Loc, lens::Real, aperture::Real) =
  begin
  	@remote(b, set_view(camera, target, lens))
  	@remote(b, set_camera_view(camera, target, lens))
  end

KhepriBase.b_get_view(b::BLR) =
  @remote(b, get_view())

backend_zoom_extents(b::BLR) = @remote(b, ZoomExtents())

backend_view_top(b::BLR) = @remote(b, ViewTop())

#=

backend_realistic_sky(b::BLR, date, latitude, longitude, meridian, turbidity, withsun) =
  @remote(b, SetSkyFromDateLocation(year(date), month(date), day(date),
                                    hour(date), minute(date),
                                    latitude, longitude, meridian))

=#
KhepriBase.b_delete_ref(b::BLR, r::BLRId) =
  @remote(b, delete_shape(r))

KhepriBase.b_delete_all_refs(b::BLR) =
  @remote(b, delete_all_shapes())
#=
backend_set_length_unit(b::BLR, unit::String) = @remote(b, SetLengthUnit(unit))

# Dimensions

const BLRDimensionStyles = Dict(:architectural => "_ARCHTICK", :mechanical => "")

backend_dimension(b::BLR, p0::Loc, p1::Loc, p::Loc, scale::Real, style::Symbol) =
    @remote(b, CreateAlignedDimension(p0, p1, p,
        scale,
        BLRDimensionStyles[style]))

backend_dimension(b::BLR, p0::Loc, p1::Loc, sep::Real, scale::Real, style::Symbol) =
    let v = p1 - p0
        angle = pol_phi(v)
        dimension(p0, p1, add_pol(p0, sep, angle + pi/2), scale, style, b)
    end

# Layers
backend_layer(b::BLR, name::String, active::Bool, color::RGB) =
  let to255(x) = round(UInt8, x*255)
    @remote(b, CreateLayer(name, true, to255(red(color)), to255(green(color)), to255(blue(color))))
  end

BLRLayer = Int

backend_current_layer(b::BLR)::BLRLayer =
  @remote(b, CurrentLayer())

backend_current_layer(b::BLR, layer::BLRLayer) =
  @remote(b, SetCurrentLayer(layer))

backend_create_layer(b::BLR, name::String, active::Bool, color::RGB) =
  let to255(x) = round(UInt8, x*255)
    @remote(b, CreateLayer(name, true, to255(red(color)), to255(green(color)), to255(blue(color))))
  end

backend_delete_all_shapes_in_layer(b::BLR, layer::BLRLayer) =
  @remote(b, DeleteAllInLayer(layer))

switch_to_layer(to, b::BLR) =
    if to != from
      set_layer_active(to, true)
      set_layer_active(from, false)
      current_layer(to)
    end

# Materials
BLRMaterial = Int

backend_current_material(b::BLR)::BLRMaterial =
  -1 #@remote(b, CurrentMaterial())

backend_current_material(b::BLR, material::BLRMaterial) =
  -1 #@remote(b, SetCurrentMaterial(material))

backend_get_material(b::BLR, name::String) =
  -1 #@remote(b, CreateMaterial(name))

# Blocks

realize(b::BLR, s::Block) =
    @remote(b, CreateBlockFromShapes(s.name, collect_ref(s.shapes)))

realize(b::BLR, s::BlockInstance) =
    @remote(b, CreateBlockInstance(
        collect_ref(s.block)[1],
        center_scaled_cs(s.loc, s.scale, s.scale, s.scale)))
=#
#=

# Manual process
@time for i in 1:1000 for r in 1:10 circle(x(i*10), r) end end

# Create block...
Khepri.create_block("Foo", [circle(radius=r) for r in 1:10])

# ...and instantiate it
@time for i in 1:1000 Khepri.instantiate_block("Foo", x(i*10), 0) end

=#
#=
# Lights
backend_pointlight(b::BLR, loc::Loc, color::RGB, range::Real, intensity::Real) =
  # HACK: Fix this
  @remote(b, SpotLight(loc, intensity, range, loc+vz(-1)))

backend_spotlight(b::BLR, loc::Loc, dir::Vec, hotspot::Real, falloff::Real) =
    @remote(b, SpotLight(loc, hotspot, falloff, loc + dir))

backend_ieslight(b::BLR, file::String, loc::Loc, dir::Vec, alpha::Real, beta::Real, gamma::Real) =
    @remote(b, IESLight(file, loc, loc + dir, vxyz(alpha, beta, gamma)))

# User Selection

backend_shape_from_ref(b::BLR, r) =
  let c = connection(b),
      code = @remote(b, ShapeCode(r)),
      ref = DynRefs(b=>BLRRef(r))
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
=#
#=
In case we need to realize an Unknown shape, we just copy it
=#
#=
realize(b::BLR, s::Unknown) =
    @remote(b, Copy(s.baseref))



backend_select_position(b::BLR, prompt::String) =
  begin
    @info "$(prompt) on the $(b) backend."
    let ans = @remote(b, GetPosition(prompt))
      length(ans) > 0 ? ans[1] : nothing
    end
  end

backend_select_positions(b::BLR, prompt::String) =
  let sel() =
    let p = select_position(prompt, b)
      if p == nothing
        []
      else
        [p, sel()...]
      end
    end
    sel()
  end


# HACK: The next operations should receive a set of shapes to avoid re-creating already existing shapes

backend_select_point(b::BLR, prompt::String) =
  select_one_with_prompt(prompt, b, @get_remote b GetPoint)
backend_select_points(b::BLR, prompt::String) =
  select_many_with_prompt(prompt, b, @get_remote b GetPoints)

backend_select_curve(b::BLR, prompt::String) =
  select_one_with_prompt(prompt, b, @get_remote b GetCurve)
backend_select_curves(b::BLR, prompt::String) =
  select_many_with_prompt(prompt, b, @get_remote b GetCurves)

backend_select_surface(b::BLR, prompt::String) =
  select_one_with_prompt(prompt, b, @get_remote b GetSurface)
backend_select_surfaces(b::BLR, prompt::String) =
  select_many_with_prompt(prompt, b, @get_remote b GetSurfaces)

backend_select_solid(b::BLR, prompt::String) =
  select_one_with_prompt(prompt, b, @get_remote b GetSolid)
backend_select_solids(b::BLR, prompt::String) =
  select_many_with_prompt(prompt, b, @get_remote b GetSolids)

backend_select_shape(b::BLR, prompt::String) =
  select_one_with_prompt(prompt, b, @get_remote b GetShape)
backend_select_shapes(b::BLR, prompt::String) =
  select_many_with_prompt(prompt, b, @get_remote b GetShapes)

backend_captured_shape(b::BLR, handle) =
  backend_shape_from_ref(b, @remote(b, GetShapeFromHandle(handle)))
backend_captured_shapes(b::BLR, handles) =
  map(handles) do handle
      backend_shape_from_ref(b, @remote(b, GetShapeFromHandle(handle)))
  end

backend_generate_captured_shape(b::BLR, s::Shape) =
    println("captured_shape(blender, $(@remote(b, GetHandleFromShape(ref(s).value))))")
backend_generate_captured_shapes(b::BLR, ss::Shapes) =
  begin
    print("captured_shapes(blender, [")
    for s in ss
      print(@remote(b, GetHandleFromShape(ref(s).value)))
      print(", ")
    end
    println("])")
  end

# Register for notification

backend_register_shape_for_changes(b::BLR, s::Shape) =
    let conn = connection(b)
        @remote(b, RegisterForChanges(ref(s).value))
        @remote(b, DetectCancel())
        s
    end

backend_unregister_shape_for_changes(b::BLR, s::Shape) =
    let conn = connection(b)
        @remote(b, UnregisterForChanges(ref(s).value))
        @remote(b, UndetectCancel())
        s
    end

backend_waiting_for_changes(b::BLR, s::Shape) =
    ! @remote(b, WasCanceled())

backend_changed_shape(b::BLR, ss::Shapes) =
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
backend_all_shapes(b::BLR) =
  Shape[backend_shape_from_ref(b, r)
        for r in filter(r -> @remote(b, ShapeCode(r)) != 0, @remote(b, GetAllShapes()))]

backend_all_shapes_in_layer(b::BLR, layer) =
  Shape[backend_shape_from_ref(b, r) for r in @remote(b, GetAllShapesInLayer(layer))]

backend_highlight_shape(b::BLR, s::Shape) =
  @remote(b, SelectShapes(collect_ref(s)))

backend_highlight_shapes(b::BLR, ss::Shapes) =
  @remote(b, SelectShapes(collect_ref(ss)))

backend_pre_selected_shapes_from_set(ss::Shapes) =
  length(ss) == 0 ? [] : pre_selected_shapes_from_set(ss, backend(ss[1]))

# HACK: This must be implemented for all backends
backend_pre_selected_shapes_from_set(ss::Shapes, b::Backend) = []

backend_pre_selected_shapes_from_set(b::BLR, ss::Shapes) =
  let refs = map(id -> @remote(b, GetHandleFromShape(id)), @remote(b, GetPreSelectedShapes()))
    filter(s -> @remote(b, GetHandleFromShape(ref(s).value)) in refs, ss)
  end
backend_disable_update(b::BLR) =
  @remote(b, DisableUpdate())

backend_enable_update(b::BLR) =
  @remote(b, EnableUpdate())

# Render

#render exposure: [-3, +3] -> [-6, 21]
convert_render_exposure(b::BLR, v::Real) = -4.05*v + 8.8
#render quality: [-1, +1] -> [+1, +50]
convert_render_quality(b::BLR, v::Real) = round(Int, 25.5 + 24.5*v)

=#

KhepriBase.b_render_view(b::BLR, path::String) =
  let (camera, target, lens) = @remote(b, get_view())
    @remote(b, set_camera_view(camera, target, lens))
    @remote(b, set_render_size(render_width(), render_height()))
    @remote(b, render_to_file(path))
  	@remote(b, cycles_renderer(100, true, false, false))
  end

#=

export blender_command
blender_command(s::String) =
  @remote(blender, Command("$(s)\n"))
=#

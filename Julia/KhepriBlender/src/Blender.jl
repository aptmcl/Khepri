# Blender
export blender

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
def find_or_create_collection(name:str, active:bool, color:RGBA)->str:
def get_current_collection()->str:
def set_current_collection(name:str)->None:
def delete_all_shapes_in_collection(name:str)->None:
def delete_all_shapes()->None:
def delete_shape(name:Id)->None:
def select_shape(name:Id)->None:
def deselect_shape(name:Id)->None:
def deselect_all_shapes()->None:
def get_material(name:str)->MatId:
def get_blenderkit_material(ref:str)->MatId:
def new_material(name:str, diffuse_color:RGBA, specularity:float, roughness:float)->MatId:
def line(ps:List[Point3d], closed:bool, mat:MatId)->Id:
def spline(ps:List[Point3d], closed:bool, mat:MatId)->Id:
def nurbs(order:int, ps:List[Point3d], closed:bool, mat:MatId)->Id:
def mesh(verts:List[Point3d], edges:List[Tuple[int,int]], faces:List[List[int]], mat:MatId)->Id:
def objmesh(verts:List[Point3d], edges:List[Tuple[int,int]], faces:List[List[int]], smooth:bool, mat:MatId)->Id:
def trig(p1:Point3d, p2:Point3d, p3:Point3d, mat:MatId)->Id:
def quad(p1:Point3d, p2:Point3d, p3:Point3d, p4:Point3d, mat:MatId)->Id:
def quad_strip(ps:List[Point3d], qs:List[Point3d], smooth:bool, mat:MatId)->Id:
def quad_strip_closed(ps:List[Point3d], qs:List[Point3d], smooth:bool, mat:MatId)->Id:
def ngon(ps:List[Point3d], pivot:Point3d, smooth:bool, mat:MatId)->Id:
def polygon(ps:List[Point3d], mat:MatId)->Id:
def polygon_with_holes(pss:List[List[Point3d]], mat:MatId)->Id:
def quad_surface(ps:List[Point3d], nu:int, nv:int, closed_u:bool, closed_v:bool, smooth:bool, mat:MatId)->Id:
def circle(c:Point3d, v:Vector3d, r:float, mat:MatId)->Id:
def cuboid(verts:List[Point3d], mat:MatId)->Id:
def pyramid_frustum(bs:List[Point3d], ts:List[Point3d], smooth:bool, bmat:MatId, tmat:MatId, smat:MatId)->Id:
def sphere(center:Point3d, radius:float, mat:MatId)->Id:
def cone_frustum(b:Point3d, br:float, t:Point3d, tr:float, bmat:MatId, tmat:MatId, smat:MatId)->Id:
def box(p:Point3d, vx:Vector3d, vy:Vector3d, dx:float, dy:float, dz:float, mat:MatId)->Id:
def text(txt:str, p:Point3d, vx:Vector3d, vy:Vector3d, size:float)->Id:
def area_light(p:Point3d, v:Vector3d, size:float, color:RGBA, strength:float)->Id:
def sun_light(p:Point3d, v:Vector3d)->Id:
def light(p:Point3d, type:str)->Id:
def camera_from_view()->None:
def set_view(camera:Point3d, target:Point3d, lens:float)->None:
def get_view()->Tuple[Point3d, Point3d, float]:
def set_camera_view(camera:Point3d, target:Point3d, lens:float)->None:
def set_render_size(width:int, height:int)->None:
def set_render_path(filepath:str)->None:
def default_renderer()->None:
def cycles_renderer(samples:int, denoising:bool, motion_blur:bool, transparent:bool)->None:
def set_sun(latitude:float, longitude:float, elevation:float, year:int, month:int, day:int, time:float, UTC_zone:float, use_daylight_savings:bool)->None:
def set_sky(turbidity:float)->None:
"""

abstract type BLRKey end
const BLRId = Union{Int32,String} # Although shapes and materials are ints, layers are strings
const BLRIds = Vector{BLRId}
const BLRRef = NativeRef{BLRKey, BLRId}
const BLRRefs = Vector{BLRRef}
const BLREmptyRef = EmptyRef{BLRKey, BLRId}
const BLRUniversalRef = UniversalRef{BLRKey, BLRId}
const BLRUnionRef = UnionRef{BLRKey, BLRId}
const BLRSubtractionRef = SubtractionRef{BLRKey, BLRId}
const BLR = SocketBackend{BLRKey, BLRId}

const KhepriServerPath = Parameter(abspath(@__DIR__, "KhepriServer.py"))
export headless_blender
const headless_blender = Parameter(false)
const starting_blender = Parameter(false)

start_blender() =
  starting_blender() ?
    sleep(1) : # Just wait a little longer
    let blender_cmd = Sys.iswindows() ?
      	  joinpath(readdir("C:/Program Files/Blender Foundation/", join=true)[1], "blender.exe") :
    	  "blender"
	  starting_blender(true)
      run(detach(headless_blender() ?
            `$(blender_cmd) -noaudio --background --python $(KhepriServerPath())` :
      	    `$(blender_cmd) --python $(KhepriServerPath())`),
    	  wait=false)
    end

KhepriBase.retry_connecting(b::BLR) =
  (@info("Starting $(b.name)."); start_blender(); sleep(2))

KhepriBase.after_connecting(b::BLR) =
  begin
	starting_blender(false)
	#set_material(blender, material_basic, )
	set_material(blender, material_metal, "asset_base_id:f1774cb0-b679-46b4-879e-e7223e2b4b5f asset_type:material")
	#set_material(blender, material_glass, "asset_base_id:ee2c0812-17f5-40d4-992c-68c5a66261d7 asset_type:material")
	set_material(blender, material_glass, "asset_base_id:ffa3c281-6184-49d8-b05e-8c6e9fe93e68 asset_type:material")
	set_material(blender, material_wood, "asset_base_id:d5097824-d5a1-4b45-ab5b-7b16bdc5a627 asset_type:material")
	#set_material(blender, material_concrete, "asset_base_id:0662b3bf-a762-435d-9407-e723afd5eafc asset_type:material")
	set_material(blender, material_concrete, "asset_base_id:df1161da-050c-4638-b376-38ced992ec18 asset_type:material")
	set_material(blender, material_plaster, "asset_base_id:c674137d-cfae-45f1-824f-e85dc214a3af asset_type:material")

	#set_material(blender, material_grass, "asset_base_id:97b171b4-2085-4c25-8793-2bfe65650266 asset_type:material")
	#set_material(blender, material_grass, "asset_base_id:7b05be22-6bed-4584-a063-d0e616ddea6a asset_type:material")
	set_material(blender, material_grass, "asset_base_id:b4be2338-d838-433b-9f0d-2aa9b97a0a8a asset_type:material")
  end

const blender = BLR("Blender", blender_port, blender_api)

KhepriBase.has_boolean_ops(::Type{BLR}) = HasBooleanOps{false}()

KhepriBase.backend(::BLRRef) = blender
KhepriBase.void_ref(b::BLR) = BLRRef(-1 % Int32)

# Primitives

KhepriBase.b_line(b::BLR, ps, mat) =
  @remote(b, line(ps, false, mat))

KhepriBase.b_polygon(b::BLR, ps, mat) =
	@remote(b, line(ps, true, mat))

KhepriBase.b_nurbs_curve(b::BLR, order, ps, knots, weights, closed, mat) =
  @remote(b, nurbs(order, ps, closed, mat))

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
  @remote(b, polygon_with_holes([ps, qss...], mat))

KhepriBase.b_surface_circle(b::BLR, c, r, mat) =
  @remote(b, circle(c, vz(1, c.cs), r, mat))

KhepriBase.b_surface_grid(b::BLR, ptss, closed_u, closed_v, smooth_u, smooth_v, mat) =
  let (nu, nv) = size(ptss)
	smooth_u && smooth_v ?
	  @remote(b, quad_surface(vcat(ptss...), nu, nv, closed_u, closed_v, true, mat)) :
	  smooth_u ?
	  	(closed_u ?
          vcat([b_quad_strip_closed(b, ptss[:,i], ptss[:,i+1], true, mat) for i in 1:nv-1],
	           closed_v ? [b_quad_strip_closed(b, ptss[:,end], ptss[:,1], true, mat)] : []) :
	      vcat([b_quad_strip(b, ptss[:,i], ptss[:,i+1], true, mat) for i in 1:nv-1],
	           closed_v ? [b_quad_strip(b, ptss[:,end], ptss[:,1], true, mat)] : [])) :
 	    (closed_v ?
           vcat([b_quad_strip_closed(b, ptss[i,:], ptss[i+1,:], smooth_v, mat) for i in 1:nu-1],
  	         	closed_u ? [b_quad_strip_closed(b, ptss[end,:], ptss[1,:], smooth_v, mat)] : []) :
  	       vcat([b_quad_strip(b, ptss[i,:], ptss[i+1,:], smooth_v, mat) for i in 1:nu-1],
  	          	closed_u ? [b_quad_strip(b, ptss[end,:], ptss[1,:], smooth_v, mat)] : []))
  end

KhepriBase.b_generic_pyramid_frustum(b::BLR, bs, ts, smooth, bmat, tmat, smat) =
  @remote(b, pyramid_frustum(bs, ts, smooth, bmat, tmat, smat))

KhepriBase.b_cone(b::BLR, cb, r, h, bmat, smat) =
  @remote(b, cone_frustum(cb, r, add_z(cb, h), 0, bmat, bmat, smat))

KhepriBase.b_cone_frustum(b::BLR, cb, rb, h, rt, bmat, tmat, smat) =
  @remote(b, cone_frustum(cb, rb, add_z(cb, h), rt, bmat, tmat, smat))

KhepriBase.b_cylinder(b::BLR, cb, r, h, bmat, tmat, smat) =
  @remote(b, cone_frustum(cb, r, add_z(cb, h), r, bmat, tmat, smat))

KhepriBase.b_cuboid(b::BLR, pb0, pb1, pb2, pb3, pt0, pt1, pt2, pt3, mat) =
  @remote(b, cuboid([pb0, pb1, pb2, pb3, pt0, pt1, pt2, pt3], mat))

KhepriBase.b_sphere(b::BLR, c, r, mat) =
  @remote(b, sphere(c, r, mat))

# Materials

KhepriBase.b_get_material(b::BLR, ref) =
  get_blender_material(b, ref)

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

get_blender_material(b, ref::Nothing) =
  void_ref(b)

get_blender_material(b, ref::AbstractString) =
  startswith(ref, "asset_base_id") ?
    @remote(b, get_blenderkit_material(ref)) :
    @remote(b, get_material(ref))

KhepriBase.b_new_material(b::BLR, path, color, specularity, roughness, transmissivity, transmitted_specular) =
  @remote(b, new_material(path, convert(RGBA, color), specularity, roughness))

# BIM

#=

Default families

=#
export blender_family_materials
blender_family_materials(m1, m2=m1, m3=m2, m4=m3) = (materials=(m1, m2, m3, m4), )

KhepriBase.b_layer(b::BLR, name, active, color) =
  @remote(b, find_or_create_collection(name, active, color))
KhepriBase.b_current_layer(b::BLR) =
  @remote(b, get_current_collection())
KhepriBase.b_current_layer(b::BLR, layer) =
  @remote(b, set_current_collection(layer))
KhepriBase.b_all_shapes_in_layer(b::BLR, layer) =
  @remote(b, all_shapes_in_collection(layer))
KhepriBase.b_delete_all_shapes_in_layer(b::BLR, layer) =
  @remote(b, delete_all_shapes_in_collection(layer))

realize(b::BLR, s::EmptyShape) =
  BLREmptyRef()
realize(b::BLR, s::UniversalShape) =
  BLRUniversalRef()

KhepriBase.b_set_view(b::BLR, camera::Loc, target::Loc, lens::Real, aperture::Real) =
  begin
  	@remote(b, set_view(camera, target, lens))
  	@remote(b, set_camera_view(camera, target, lens))
  end

KhepriBase.b_get_view(b::BLR) =
  @remote(b, get_view())

KhepriBase.b_zoom_extents(b::BLR) = @remote(b, ZoomExtents())

KhepriBase.b_set_view_top(b::BLR) = @remote(b, ViewTop())

KhepriBase.b_realistic_sky(b::BLR, date, latitude, longitude, elevation, meridian, turbidity, withsun) =
  begin
	@remote(b, set_sun(latitude, longitude, elevation, year(date), month(date), day(date), hour(date)+minute(date)/60, meridian, false))
	@remote(b, set_sky(turbidity)) #Add withsun
  end

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
KhepriBase.b_pointlight(b::BLR, loc::Loc, color::RGB, range::Real, intensity::Real) =
  # HACK: Fix this
  @remote(b, SpotLight(loc, intensity, range, loc+vz(-1)))

KhepriBase.b_spotlight(b::BLR, loc::Loc, dir::Vec, hotspot::Real, falloff::Real) =
    @remote(b, SpotLight(loc, hotspot, falloff, loc + dir))

KhepriBase.b_ieslight(b::BLR, file::String, loc::Loc, dir::Vec, alpha::Real, beta::Real, gamma::Real) =
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

=#

KhepriBase.b_highlight_ref(b::BLR, r::BLRId) =
  @remote(b, select_shape(r))

KhepriBase.b_unhighlight_ref(b::BLR, r::BLRId) =
  @remote(b, deselect_shape(r))

KhepriBase.b_unhighlight_all_refs(b::BLR) =
  @remote(b, deselect_all_shapes())
#=
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
    @remote(b, set_render_path(path))
  	@remote(b, cycles_renderer(200, true, false, false))
  end

#=

export blender_command
blender_command(s::String) =
  @remote(blender, Command("$(s)\n"))
=#

# Blender
export blender

#=
#To dribble Blender, do:

blender_exe_path = raw"C:\Program Files\Blender Foundation\Blender 3.6\blender.exe"
using OutputCollectors
oc = OutputCollector(`$blender_exe_path $["--python", joinpath(@__DIR__, "BlenderServer.py")]`, verbose=true)
=#

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

# A BlenderKit downloader:
#=
using HTTP
using JSON
using UUIDs
using Downloads

download_blenderkit_material(asset_ref, folder=tempdir()) =
  let (asset_base_id_str, asset_type_str) = split(asset_ref),
      asset_type = split(asset_type_str, ":")[2],
      reqstr = "?query=$asset_base_id_str+$asset_type_str+order:_score&addon_version=1.0.30",
      url = "https://www.blenderkit.com/api/v1/search/$reqstr",
      assets = JSON.parse(String(HTTP.get(url).body))["results"],
      asset = assets[end], # To jump over publicity&such
      file = filter(file -> file["fileType"] == "blend", asset["files"])[1],
      download_url = file["downloadUrl"],
      scene_uuid = string(UUIDs.uuid4()),
      data = JSON.parse(String(HTTP.get("$download_url?scene_uuid=$scene_uuid", ["User-agent"=>"Mozilla/5.0"]).body)),
      file_path = data["filePath"],
      output_path = joinpath(folder, asset["id"] * ".blend")
    if ! isfile(output_path)
      Downloads.download(file_path, output_path)
    end
    output_path
  end
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
def select_shapes(names:List[Id])->None:
def deselect_shapes(names:List[Id])->None:
def deselect_all_shapes()->None:
def selected_shapes(prompt:str)->List[Id]:
def get_material(name:str)->MatId:
def get_blenderkit_material(ref:str)->MatId:
def new_material(name:str, diffuse_color:RGBA, metallic:float, specular:float, roughness:float, clearcoat:float, clearcoat_roughness:float, ior:float, transmission:float, transmission_roughness:float, emission:RGBA, emission_strength:float)->MatId:
def new_metal_material(name:str, color:RGBA, roughness:float, ior:float)->MatId:
def new_glass_material(name:str, color:RGBA, roughness:float, ior:float)->MatId:
def new_mirror_material(name:str, color:RGBA)->MatId:
def line(ps:List[Point3d], closed:bool, mat:MatId)->Id:
def spline(ps:List[Point3d], closed:bool, mat:MatId)->Id:
def nurbs(order:int, ps:List[Point3d], closed:bool, mat:MatId)->Id:
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
def add_render_background(d:float, w:float, mat:MatId)->Id:
def default_renderer()->None:
def cycles_renderer(samples:int, denoising:bool, motion_blur:bool, transparent:bool, exposure:float)->None:
def freestylesvg_renderer(thickness:float, crease_angle:float)->None:
def clay_renderer(samples:int, denoising:bool, motion_blur:bool, transparent:bool)->None:
def set_sun(latitude:float, longitude:float, elevation:float, year:int, month:int, day:int, time:float, UTC_zone:float, use_daylight_savings:bool)->None:
def set_sky(turbidity:float)->None:
def set_sun_sky(sun_elevation:float, sun_rotation:float, turbidity:float, with_sun:bool)->None:
def set_max_repeated(n:Int)->Int:
def blender_cmd(expr:str)->None:
def set_hdri_background(hdri_path:str)->None:
def set_hdri_background_with_rotation(hdri_path:str, rotation:float)->None:
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

const KhepriServerPath = Parameter(abspath(@__DIR__, "BlenderServer.py"))
export headless_blender
const headless_blender = Parameter(false)
const starting_blender = Parameter(false)

start_blender() =
  starting_blender() ?
    sleep(1) : # Just wait a little longer
    let blender_cmd =
		  Sys.iswindows() ?
      	    joinpath(readdir("C:/Program Files/Blender Foundation/", join=true)[1], "blender.exe") :
  		    Sys.isapple() ?
		  	  "/Applications/Blender.app/Contents/MacOS/Blender" :
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
	set_material(blender, material_clay, b -> b_plastic_material(b, "Clay", rgb(0.9, 0.9, 0.9),	1.0))
  end

const blender = BLR("Blender", blender_port, blender_api)

KhepriBase.has_boolean_ops(::Type{BLR}) = HasBooleanOps{false}()

KhepriBase.backend(::BLRRef) = blender
KhepriBase.void_ref(b::BLR) = BLRRef(-1 % Int32)

# Primitives

KhepriBase.unite_ref(b::BLR, r0::BLRRef, r1::BLRRef) =
    ensure_ref(b, [r0.value, r1.value])

KhepriBase.b_line(b::BLR, ps, mat) =
  @remote(b, line(ps, false, mat))

KhepriBase.b_polygon(b::BLR, ps, mat) =
	@remote(b, line(ps, true, mat))

KhepriBase.b_spline(b::BLR, ps, v1, v2, mat) =
  # HACK: What about v1, v2
  @remote(b, nurbs(5, ps, false, mat))

KhepriBase.b_closed_spline(b::BLR, ps, mat) =
  @remote(b, nurbs(5, ps, true, mat))

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

KhepriBase.b_get_material(b::BLR, spec::AbstractString) =
  startswith(spec, "asset_base_id") ?
    @remote(b, get_blenderkit_material(spec)) :
    @remote(b, get_material(spec))

KhepriBase.b_get_material(b::BLR, spec::Function) = spec(b)

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

KhepriBase.b_new_material(b::BLR, name,
						  base_color,
						  metallic, specular, roughness,
	                 	  clearcoat, clearcoat_roughness,
						  ior,
						  transmission, transmission_roughness,
	                 	  emission_color,
						  emission_strength) =
  @remote(b, new_material(name,
  						  convert(RGBA, base_color),
						  metallic, specular, roughness,
  						  clearcoat, clearcoat_roughness,
  				  		  ior,
  				  		  transmission, transmission_roughness,
						  convert(RGBA, emission_color), emission_strength))

KhepriBase.b_plastic_material(b::BLR, name, color, roughness) =
  @remote(b, new_material(name, convert(RGBA, color), 0.0, 1.0, roughness, 0.0, 0.0, 1.4, 0.0, 0.0, RGBA(0.0, 0.0, 0.0, 1.0), 0.0))

KhepriBase.b_metal_material(b::BLR, name, color, roughness, ior) =
  @remote(b, new_metal_material(name, convert(RGBA, color), roughness, ior))

KhepriBase.b_glass_material(b::BLR, name, color, roughness, ior) =
  @remote(b, new_glass_material(name, convert(RGBA, color), roughness, ior))

KhepriBase.b_mirror_material(b::BLR, name, color) =
  @remote(b, new_mirror_material(name, convert(RGBA, color)))

#KhepriBase.b_translucent_material(b::BLR, name, diffuse, specular, roughness, reflect, transmit, bump_map)
#KhepriBase.b_substrate_material(name, diffuse, specular, roughness, bump_map)

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

#KhepriBase.b_set_view_top(b::BLR) = @remote(b, ViewTop())

KhepriBase.b_realistic_sky(b::BLR, altitude, azimuth, turbidity, sun) =
  @remote(b, set_sun_sky(deg2rad(altitude), deg2rad(azimuth), turbidity, sun))
  #set_sun(latitude, longitude, elevation, year(date), month(date), day(date), hour(date)+minute(date)/60, meridian, false))

KhepriBase.b_delete_ref(b::BLR, r::BLRId) =
  @remote(b, delete_shape(r))

KhepriBase.b_delete_all_refs(b::BLR) =
  @remote(b, delete_all_shapes())

##############

KhepriBase.b_highlight_ref(b::BLR, r::BLRId) =
  @remote(b, select_shape(r))

KhepriBase.b_unhighlight_ref(b::BLR, r::BLRId) =
  @remote(b, deselect_shape(r))

KhepriBase.b_highlight_refs(b::BLR, rs::BLRIds) =
  @remote(b, select_shapes(rs))

KhepriBase.b_unhighlight_refs(b::BLR, rs::BLRIds) =
  @remote(b, deselect_shapes(rs))

KhepriBase.b_unhighlight_all_refs(b::BLR) =
  @remote(b, deselect_all_shapes())


##############
KhepriBase.b_select_shape(b::BLR, prompt::String) =
  let get_it() = select_one_with_prompt(prompt, b, @get_remote b selected_shapes)
    @remote(b, deselect_all_shapes())
    let sh = get_it()
      while isnothing(sh)
        sleep(1)
        sh = get_it()
      end
      sh
    end
  end

#
KhepriBase.b_shape_from_ref(b::BLR, r) = begin
  error("Unknown shape with reference $r")
end
##############

# We have different renderers in Blender

with_render_setup(f, b, path) =
  let (camera, target, lens) = @remote(b, get_view())
    @remote(b, set_camera_view(camera, target, lens))
    @remote(b, set_render_size(render_width(), render_height()))
    @remote(b, set_render_path(path))
    f()
  end

KhepriBase.b_render_view(b::BLR, path::String) =
  with_render_setup(b, path) do
  	@remote(b, cycles_renderer(1200, true, false, false, render_exposure()))
  end

export render_svg
render_svg(b::BLR, path) =
  with_render_setup(b, path) do
    @remote(b, freestylesvg_renderer(1.0, 0.0))
  end

#=
with_clay_model(f, level::Real=0) =
  begin
  	with(f, default_material, material_clay)
	area_light
=#

KhepriBase.b_render_clay_view(b::BLR, path) =
  let (c, t, l) = get_view()
    with_render_setup(b, path) do
      @remote(b, set_hdri_background_with_rotation(joinpath(@__DIR__, "studio_small_05_4k.exr"), 2π - (c - t).ϕ))
      @remote(b, cycles_renderer(1200, true, false, true, render_exposure()))
    end
  end

#=
render_size(1920,1080)
#@remote(blender, add_render_background(0.1, 10000, b_plastic_material(b, "Black", rgb(0.0, 0.0, 0.0),	1.0)
start_film("SombrasTrans")
for α in division(0, 2pi, 128, false)
  @remote(blender, set_hdri_background_with_rotation(joinpath(@__DIR__, "studio_small_05_4k.exr"), α))
  save_film_frame()
end
KhepriBase.create_mp4_from_frames()
=#
export threejs, threejs_material, THR

import KhepriBase: closed_path_for_height, subtract_wall_paths, collect_ref!

# THR is a subtype of JS
parse_signature(::Val{:THR}, sig::T) where {T} = parse_signature(Val(:TS), sig)
encode(::Val{:THR}, t::Val{T}, c::IO, v) where {T} = encode(Val(:TS), t, c, v)
decode(::Val{:THR}, t::Val{T}, c::IO) where {T} = decode(Val(:TS), t, c)
encode(ns::Val{:THR}, t::Tuple{T1,T2,T3}, c::IO, v) where {T1,T2,T3} =
  begin
    encode(ns, T1(), c, v[1])
    encode(ns, T2(), c, v[2])
    encode(ns, T3(), c, v[3])
  end
decode(ns::Val{:THR}, t::Tuple{T1,T2,T3}, c::IO) where {T1,T2,T3} =
  (decode(ns, T1(), c),
   decode(ns, T2(), c),
   decode(ns, T3(), c))

@encode_decode_as(:THR, Val{:Float32}, Val{:float})
@encode_decode_as(:THR, Val{:Int32}, Val{:int})
@encode_decode_as(:THR, Val{:Bool}, Val{:bool})
@encode_decode_as(:THR, Val{:Id}, Val{:size})
@encode_decode_as(:THR, Val{:MatId}, Val{:size})
@encode_decode_as(:THR, Val{:GUIId}, Val{:size})
@encode_decode_as(:THR, Val{:Str}, Val{:String})

#@encode_decode_as(:THR, Val{:Request}, Val{:String})
@encode_decode_as(:THR, Val{:Request}, Val{:int})

encode(::Val{:THR}, t::Union{Val{:Point3d},Val{:Vector3d}}, c::IO, p) =
  encode(Val(:TS), Val(:float3), c, raw_point(p))
decode(::Val{:THR}, t::Val{:Point3d}, c::IO) =
  xyz(decode(Val(:TS), Val(:float3), c)..., world_cs)
decode(::Val{:THR}, t::Val{:Vector3d}, c::IO) =
  vxyz(decode(Val(:TS), Val(:float3), c)..., world_cs)

encode(::Val{:THR}, t::Union{Val{:Point2d},Val{:Vector2d}}, c::IO, p) =
  encode(Val(:TS), Val(:float2), c, raw_point(p))
decode(::Val{:THR}, t::Val{:Point2d}, c::IO) =
  xy(decode(Val(:TS), Val(:float2), c)..., world_cs)
decode(::Val{:THR}, t::Val{:Vector2d}, c::IO) =
  vxy(decode(Val(:TS), Val(:float2), c)..., world_cs)

encode(ns::Val{:THR}, t::Val{:Matrix4x4}, c::IO, p) = 
  let m = translated_cs(p.cs, p.x, p.y, p.z).transform
    encode(ns, Val(:float4), c, (m[1,1], m[1,2], m[1,3], m[1,4]))
    encode(ns, Val(:float4), c, (m[2,1], m[2,2], m[2,3], m[2,4]))
    encode(ns, Val(:float4), c, (m[3,1], m[3,2], m[3,3], m[3,4]))
    encode(ns, Val(:float4), c, (m[4,1], m[4,2], m[4,3], m[4,4]))
  end

encode(ns::Val{:THR}, t::Val{:Matrix4x4Y}, c::IO, p) =
  let m = translated_cs(p.cs, p.x, p.y, p.z).transform #*[1 0 0 0; 0 0 1 0; 0 1 0 0; 0 0 0 1]
    encode(ns, Val(:float4), c, (m[1,1], m[1,3], m[1,2], m[1,4]))
    encode(ns, Val(:float4), c, (m[2,1], m[2,3], m[2,2], m[2,4]))
    encode(ns, Val(:float4), c, (m[3,1], m[3,3], m[3,2], m[3,4]))
    encode(ns, Val(:float4), c, (m[4,1], m[4,3], m[4,2], m[4,4]))
  end

encode(ns::Val{:THR}, t::Val{:Frame3d}, c::IO, v) = begin
  encode(ns, Val(:Point3d), c, v)
  let t = v.cs.transform
    encode(Val(:TS), Val(:float3), c, (t[1,1], t[2,1], t[3,1]))
    encode(Val(:TS), Val(:float3), c, (t[1,2], t[2,2], t[3,2]))
    encode(Val(:TS), Val(:float3), c, (t[1,3], t[2,3], t[3,3]))
  end
end

decode(ns::Val{:THR}, t::Val{:Frame3d}, c::IO) =
  u0(cs_from_o_vx_vy_vz(
      decode(ns, Val(:Point3d), c),
      decode(ns, Val(:Vector3d), c),
      decode(ns, Val(:Vector3d), c),
      decode(ns, Val(:Vector3d), c)))

encode(ns::Val{:THR}, t::Val{:ArrayFloat32}, c::IO, v) =
  let a = [convert(Float32, t) for p in v for t in raw_point(p)]
    encode(ns, Val{:float}[], c, a)
  end
encode(ns::Val{:THR}, t::Val{:ArrayInt32}, c::IO, v) =
  let a = [convert(Int32, i) for i in v]
    encode(ns, Val{:int}[], c, a)
  end

# MeshPart: (vertices::Vector{Loc}, indices::Vector{Int32}, material_ref::Int32)
encode(ns::Val{:THR}, ::Val{:MeshPart}, c::IO, part) =
  let (vs, idxs, mat) = part
    encode(ns, Val(:ArrayFloat32), c, vs)
    encode(ns, Val(:ArrayInt32), c, idxs)
    encode(ns, Val(:Int32), c, mat)
  end

threejs_api = @remote_api :THR """
typedFunction("getOperationNamed", [Str, Str], Int32, (name: string, canonical: string) => {
typedFunction("delete", [Int32], None, (i: number) =>
typedFunction("deleteAll", [], None, () => {
typedFunction("createLayer", [Str], Int32, (name: string) => {
typedFunction("getCurrentLayer", [], Int32, () => {
typedFunction("setCurrentLayer", [Int32], None, (idx: number) => {
typedFunction("setLayerVisible", [Int32, Bool], None, (layer: THREE.Group, visible: boolean) => {
typedFunction("getLayerName", [Int32], Str, (layer: THREE.Group) => {
typedFunction("setLayerOpacity", [Int32, Float32], None, (layer: THREE.Group, opacity: number) => {
typedAsyncFunction("selectShape", [Str], [Int32], (prompt: string, cont: Function) => {
typedAsyncFunction("selectShapes", [Str], [Int32], (prompt: string, cont: Function) => {
typedAsyncFunction("selectPosition", [Str], [Point3d], (prompt: string, cont: Function) => {
typedFunction("addAnnotation", [Point3d, Str], Int32, (p: THREE.Vector3, txt: string) =>
typedFunction("deleteAnnotation", [Int32], None, (i: number) => 
typedFunction("guiCreate", [Str, Int32], GUIId, (title: string, kind: number) => {
typedFunction("guiAddFolder", [GUIId, Str, Bool], GUIId, (gui: GUI, title: string, closed: boolean) => {
typedFunction("guiRemove", [GUIId], None, (gui: GUI) => {
typedFunction("guiVisible", [GUIId, Bool], None, (gui: GUI, visible: boolean) => {
typedFunction("guiAddButton", [GUIId, Str, Int32], GUIId, (gui: GUI, name: string, request: number) => {
typedFunction("guiAddCheckbox", [GUIId, Str, Int32, Bool], GUIId, (gui: GUI, name: string, request: number, curr: boolean) => {
typedFunction("guiAddSlider", [GUIId, Str, Int32, Float32, Float32, Float32, Float32], GUIId, (gui: GUI, name: string, request: number, min: number, max: number, step: number, curr: number) => {
typedFunction("guiAddDropdown", [GUIId, Str, Int32, Dict, Int32], GUIId, (gui: GUI, name: string, request: number, options: any, curr: number) => {
typedFunction("guiAddLoadFileButton", [GUIId, Str, Request], GUIId, (gui: GUI, name: string, request: request) => {
typedFunction("gridHelper", [Int32, Int32, RGB, RGB], None, (size: number, divisions: number, colorCenterLine: THREE.Color, colorGrid: THREE.Color) => {
typedFunction("points", [[Point3d], MatId], Id, (vs: THREE.Vector3[], mat: THREE.Material) => {
typedFunction("line", [[Point3d], MatId], Id, (vs: THREE.Vector3[], mat: THREE.Material) => {
typedFunction("spline", [[Point3d], Bool, MatId], Id, (vs: THREE.Vector3[], closed: boolean, mat: THREE.Material) => {
typedFunction("arc", [Matrix4x4, Float32, Float32, Float32, MatId], Id, (m: THREE.Matrix4, r: number, start: number, finish: number, mat: THREE.Material) => {
typedFunction("arcRegion", [Matrix4x4, Float32, Float32, Float32, MatId], Id, (m: THREE.Matrix4, r: number, start: number, amplitude: number, mat: THREE.Material) => {
typedFunction("surfacePolygonWithHoles", [Matrix4x4, [Point2d], [[Point2d]], MatId], Id, (m: THREE.Matrix4, ps: THREE.Vector2[], qss: THREE.Vector2[][], mat: THREE.Material) => {
typedFunction("sphere", [Point3d, Float32, MatId], Id, (c: THREE.Vector3, r: number, mat: THREE.Material) => {
typedFunction("box", [Matrix4x4, Float32, Float32, Float32, MatId], Id, (m: THREE.Matrix4, dx: number, dy: number, dz: number, mat: THREE.Material) =>
typedFunction("torus", [Matrix4x4, Float32, Float32, MatId], Id, (m: THREE.Matrix4, re: number, ri: number, mat: THREE.Material) =>
typedFunction("cylinder", [Matrix4x4Y, Float32, Float32, Float32, Bool, MatId], Id, (m: THREE.Matrix4, rb: number, rt: number, h: number, open: boolean, mat: THREE.Material) =>
typedFunction("mesh", [ArrayFloat32, MatId], Id, (vs: Float32Array, mat: THREE.Material) => {
typedFunction("meshIndexed", [ArrayFloat32, ArrayInt32, MatId], Id, (vs: Float32Array, idxs: Int32Array, mat: THREE.Material) => {
typedFunction("quadStrip", [[Point3d], [Point3d], Bool, MatId], Id, (ps: THREE.Vector3[], qs: THREE.Vector3[], smooth: boolean, mat: THREE.Material) => {
typedFunction("surfaceGrid", [[[Point3d]], Bool, Bool, Bool, Bool, MatId], Id, (points: THREE.Vector3[][], uClosed: boolean, vClosed: boolean, uSmooth: boolean, vSmooth: boolean, mat: THREE.Material) => {    
typedFunction("extrudedSurface", [Matrix4x4, [Point2d], Bool, [[Point2d]], [Bool], Vector3d, MatId], Id, (m: THREE.Matrix4, ps: THREE.Vector2[], _smooth: boolean, qss: THREE.Vector2[][], _smoothHoles: boolean, v: THREE.Vector3, mat: THREE.Material) => {
typedFunction("meshObjFmt", [Str, Str, Matrix4x4], Id, (path: string, name: string, m: THREE.Matrix4) => {
typedFunction("MeshPhysicalMaterial", [Dict], MatId, (params: { [key: string]: any }) =>
typedFunction("MeshPbrMaterial", [Dict], MatId, (params: { [key: string]: any }) =>
typedFunction("MeshPhongMaterial", [Dict], MatId, (params: { [key: string]: any }) =>
typedFunction("MeshLambertMaterial", [Dict], MatId, (params: { [key: string]: any }) =>
typedFunction("LineBasicMaterial", [Dict], MatId, (params: { [key: string]: any }) =>
typedAsyncFunction("glTFMaterial", [Str], MatId, (path: string, cont: Function) =>
typedAsyncFunction("setEnvironment", [Str, Bool], None, (path: string, setBackground: boolean) =>
typedFunction("setView", [Point3d, Point3d, Float32, Float32], None, (position: THREE.Vector3, target: THREE.Vector3, lens: number, _aperture: number) => {
typedFunction("stopUpdate", [], None, () => {
typedFunction("startUpdate", [], None, () => {
typedAsyncFunction("showKMLCoordinatesFromFile", [], None, (cont: Function) => {
typedFunction("wall", [[Point3d], [Point3d], Float32, Bool, MatId, MatId, MatId], Id, (rightVs: THREE.Vector3[], leftVs: THREE.Vector3[], height: number, closed: boolean, rightMat: THREE.Material, leftMat: THREE.Material, sideMat: THREE.Material) => {
typedFunction("stair", [Point3d, Vector3d, Float32, Int32, Float32, Float32, Float32, Bool, MatId, MatId], Id, (basePoint: THREE.Vector3, direction: THREE.Vector3, bottomHeight: number, nSteps: number, riserHeight: number, treadDepth: number, width: number, hasRisers: boolean, treadMat: THREE.Material, riserMat: THREE.Material) => {
typedFunction("spiralStair", [Point3d, Float32, Float32, Float32, Bool, Float32, Int32, Float32, Float32, MatId], Id, (center: THREE.Vector3, radius: number, startAngle: number, includedAngle: number, clockwise: boolean, bottomHeight: number, nSteps: number, riserHeight: number, width: number, treadMat: THREE.Material) => {
typedFunction("groupedMesh", [[MeshPart]], Id, (parts: any[]) => {
typedFunction("wallWithOpenings", [[Point3d], [Point3d], [Point3d], Float32, Bool, [Float32], [Float32], [Float32], [Float32], MatId, MatId, MatId], Id, (rightVs: THREE.Vector3[], leftVs: THREE.Vector3[], centerVs: THREE.Vector3[], height: number, closed: boolean, opStarts: number[], opBaseHeights: number[], opWidths: number[], opHeights: number[], rightMat: THREE.Material, leftMat: THREE.Material, sideMat: THREE.Material) => {
typedFunction("railing", [[Point3d], Float32, Float32, Float32, Float32, MatId], Id, (pathVs: THREE.Vector3[], baseHeight: number, height: number, postSpacing: number, postRadius: number, mat: THREE.Material) => {
"""


# We will use WebSockets for Threejs

abstract type THRKey end
const THRId = Int32
const THRIds = Vector{THRId}
const THRRef = NativeRef{THRKey, THRId}
const THRRefs = Vector{THRRef}
const THR = WebSocketBackend{THRKey, THRId}


backend_name(b::THR) = b.name

register_handlers!(server=khepri_websocket_server()) =
  let files = ["index.html", "assets/index.js", "assets/index.css"],
      root = joinpath(@__DIR__, "..", "KhepriThree.js", "dist"),
      root_read_file(file) = http_response_with_file(joinpath(root, file)),
      router = server.router
    HTTP.register!(router, "GET", "/resources/**", request -> 
      let subpath = split(request.target, "/", keepempty=false)[2:end], # drop first 'resources'
          path = joinpath(subpath...)
        http_response_with_resource_file(path)
      end)
    for file in files
      HTTP.register!(router, "GET", "/$(file)", req -> root_read_file(file))
    end
    let idx = files[1]
      HTTP.register!(router, "GET", "/", req -> root_read_file(idx))
    end
    # Fallback
    HTTP.register!(router, "GET", "/{rest}", req -> 
      let rest = HTTP.getparams(req)["rest"]
        @warn "Unknown request for $rest"
        HTTP.Response(404, "File not found: $rest")
      end)
  end

#=
To speedup material selection, we will download and install automatically glTF files from Poly Haven
=#
#=
TO BE FINISHED!!!!
get_or_install_from ambient_cg(name) =
  let download_path = joinpath(homedir(), "Downloads", name*".zip")
    HTTP.download("https://ambientcg.com/get?file=$name_8K-JPG.zip",
                  download_path, update_period=Inf)
    
  =#

set_default_materials() =
  begin
    set_material(THR, material_point, b->threejs_line_material(b, RGB(1.0,1.0,1.0)))
    set_material(THR, material_curve, b->threejs_line_material(b, RGB(1.0,1.0,1.0)))
    set_material(THR, material_surface, b->threejs_material(b, RGB(0.9,0.1,0.1)))
    set_material(THR, material_basic, b->threejs_material(b, RGB(0.8,0.8,0.8)))
    set_material(THR, material_glass, b->threejs_glass_material(b, 0.3, RGB(0.8, 0.8, 1.0)))
	  set_material(THR, material_metal, b->threejs_metal_material(b, 0.4))
	  #set_material(THR, material_wood, b->threejs_material(b, RGB(169/255,122/255,87/255)))
	  set_material(THR, material_wood,
      b->threejs_glTF_material(b, "resources/materials/plywood/plywood_4k.gltf"))
	  set_material(THR, material_concrete, b->threejs_material(b, RGB(140/255,140/255,140/255)))
	  set_material(THR, material_plaster, b->threejs_plaster_material(b))
	  #set_material(THR, material_plaster, b->threejs_material(b, RGB(0.7,0.7,0.7)))
	  set_material(THR, material_grass, b->threejs_material(b, RGB(0.1,0.7,0.1)))
    #set_material(THR, default_annotation_material(), b->threejs_metal_material(b))
  end

KhepriBase.b_get_material(b::THR, f::Function) = f(b)

KhepriBase.has_boolean_ops(::Type{THR}) = HasBooleanOps{false}()

KhepriBase.void_ref(b::THR) = -1 % Int32

KhepriBase.b_material(b::THR, name, base_color, metallic, roughness, specular,
                       ior, transmission, transmission_roughness,
                       clearcoat, clearcoat_roughness,
                       emission_color, emission_strength) =
  @remote(b, MeshPhysicalMaterial(
    (color=convert(RGB, base_color),
     metalness=metallic,
     roughness=roughness,
     ior=ior,
     transmission=transmission,
     clearcoat=clearcoat,
     clearcoatRoughness=clearcoat_roughness,
     emissive=convert(RGB, emission_color),
     emissiveIntensity=emission_strength,
     side=2)))

threejs_material(b, color) =
  @remote(b, MeshLambertMaterial(
    (#"vertexColors" => 0,
     #"transparent" => false,
     #"opacity" => 1.0,
     #"depthTest" => true,
     #"linewidth" => 1.0,
     #"depthFunc" => 3,
     side=2,
     color=color,
     #color="0xAAAAAA",
     #"reflectivity" => 0.5,
     depthWrite=true
     )))


threejs_plaster_material(b) = 
  @remote(b, MeshPhysicalMaterial(
    (color=colorant"#F5F5F5",# Off-white plaster color
     roughness=0.8,         # High roughness for matte finish
     metalness=0.0,         # No metalness
     
     # Clearcoat properties for realistic surface variation
     clearcoat=0.1,         # Very subtle clearcoat layer
     clearcoatRoughness=0.3,# Rough clearcoat for plaster-like sheen
     
     # Sheen for subtle fabric-like reflection (plaster can have this)
     sheen=0.1,
     sheenRoughness=0.8,
     sheenColor=colorant"#F5F5F5",
     
     # Transmission and thickness for subsurface scattering effect
     transmission=0.01,      # Very slight subsurface scattering
     thickness=0.5,         # For the transmission effect
     
     # Iridescence for subtle color variation
     iridescence=0.1,     
     # Specular intensity control
     specularIntensity=0.2,
     specularColor=colorant"#FFFFFF")))

threejs_glass_material(b, opacity=0.3, color=RGB(1.0,1.0,1.0)) =
  @remote(b, MeshPhysicalMaterial(
    (color=color,           # Base color (white for clear glass)
     transmission=0.95,        # High transmission for transparency
     opacity=0.1,              # Low opacity (glass is mostly transparent)
     transparent=true,          # Enable transparency
     roughness=0.05,           # Very low roughness for smooth surface
     metalness=0.0,            # No metalness
     ior=1.52,                 # Index of refraction for glass (typical=1.52)
     # Clearcoat for additional reflectivity
     clearcoat=0.2,
     clearcoatRoughness=0.05,
     # Specular properties for sharp reflections
     specularIntensity=1.0,
     specularColor=color,
     # Reflection intensity
     reflectivity=0.5,
     # Thin-walled for flat glass panes
     thickness=0.1,            # Thickness affects transmission color
     # Attenuation for colored glass (slight blue tint for modern glass)
     attenuationColor=colorant"#ADD8E6",
     attenuationDistance=1.0)))

threejs_metal_material(b, roughness=0.0, color=RGB(0.9,0.9,0.9)) =
  @remote(b, MeshPhysicalMaterial(
    (metalness=1.0,
     roughness=roughness,
     side=2,
     color=color,
     depthWrite=true
    )))

threejs_line_material(b, color) =
  @remote(b, LineBasicMaterial(
    (color=color,
     #linewidth=2, Due to limitations of the OpenGL Core Profile with the WebGL renderer on most platforms linewidth will always be 1 regardless of the set value.
     #depthFunc=3,
     #depthTest=true,
     depthWrite=true,
     #stencilWrite=false,
     #stencilWriteMask=255,
     #stencilFunc=519,
     #stencilRef=0,
     #stencilFuncMask=255,
     #stencilFail=7680,
     #stencilZFail=7680,
     #stencilZPass=7680
   )))

threejs_glTF_material(b, path) =
  @remote(b, glTFMaterial(path))

# Texture wrapping
const THREE_RepeatWrapping = 1000;
const THREE_ClampToEdgeWrapping = 1001;
const THREE_MirroredRepeatWrapping = 1002;

glTF_material(name) =
  b->threejs_glTF_material(b, 
      "resources/materials/$(name)/$(name)_4k.gltf")

export marble_material, floor_material
const marble_material = material("Marble", THR=>glTF_material("marble_01"))
const floor_material = material("Floor", THR=>glTF_material("laminate_floor_02"))

# Primitives
KhepriBase.b_point(b::THR, p, mat) =
  @remote(b, points([p], mat))

KhepriBase.b_line(b::THR, ps, mat) = begin
  @remote(b, line(ps, mat))
end

KhepriBase.b_spline(b::THR, ps, v0, v1, mat) =
  if !(v0 isa Vec) && !(v1 isa Vec)
    @remote(b, spline(ps, false, mat))
  else
    @invoke b_spline(b::Backend, ps, v0, v1, mat)
  end

KhepriBase.b_closed_spline(b::THR, ps, mat) =
  @remote(b, spline(ps, true, mat))

KhepriBase.b_circle(b::THR, c, r, mat) =
  @remote(b, arc(c, r, 0, 2π, mat))

KhepriBase.b_arc(b::THR, c, r, α, Δα, mat) =
  if r == 0
    b_point(b, c, mat)
  elseif Δα == 0
    b_point(b, c + vpol(r, α, c.cs), mat)
  else
    let α = α - 2π*floor(α/2π),
        (r, α) = r < 0 ? (-r, α + π) : (r, α)
      abs(Δα) >= 2π ?
        @remote(b, arc(c, r, α, α + 2π*sign(Δα), mat)) :
        @remote(b, arc(c, r, α, α + Δα, mat))
    end
  end

KhepriBase.b_trig(b::THR, p1, p2, p3, mat) =
  @remote(b, meshIndexed([p1, p2, p3], [0,1,2], mat))

KhepriBase.b_quad(b::THR, p1, p2, p3, p4, mat) =
  @remote(b, meshIndexed([p1, p2, p3, p4], [0,1,2,2,3,0], mat))

function KhepriBase.b_ngon(b::THR, ps, pivot, smooth, mat)
  isempty(ps) && return void_ref(b)  # empty ring -> ps[end]/ps[1] would BoundsError
  if smooth # Threejs merges normals if indexed with repeated vertices
    let pts = [pivot, ps...],
        idxs = Int[],
        trig(a,b,c) = push!(idxs, a, b, c)
      for i in 1:size(ps,1)-1
        trig(0, i, i+1)
      end
	    trig(0, length(ps), 1)
      @remote(b, meshIndexed(pts, idxs, mat))
    end
  else
    let pts = Loc[]
      trig(a,b,c) = push!(pts, a, b, c)
      for i in 1:size(ps,1)-1
        trig(pivot, ps[i], ps[i+1])
      end
      trig(pivot, ps[end], ps[1])
      @remote(b, mesh(pts, mat))
    end
  end
end

KhepriBase.b_quad_strip(b::THR, ps, qs, smooth, mat) =
  @remote(b, quadStrip(ps, qs, smooth, mat))

# Threejs can cover polygons with holes
KhepriBase.b_surface_polygon(b::THR, ps, mat) =
  b_surface_polygon_with_holes(b, ps, [], mat)

KhepriBase.b_surface_polygon_with_holes(b::THR, ps, qss, mat) =
  let cs = cs_from_o_vz(vertices_center(ps), vertices_normal(ps)),
      naked(p) = xy(p.x, p.y, world_cs),
      to2D(vs) = [naked(in_cs(v, cs)) for v in vs]
    @remote(b, surfacePolygonWithHoles(u0(cs), 
      to2D(ps),
      [to2D(qs) for qs in qss],
      mat))
  end

KhepriBase.b_surface_circle(b::THR, c, r, mat) =
  @remote(b, arcRegion(c, r, 0, 2π, mat))

KhepriBase.b_surface_arc(b::THR, c, r, α, Δα, mat) =
  @remote(b, arcRegion(c, r, α, Δα, mat))

KhepriBase.b_surface_grid(b::THR, ptss, closed_u, closed_v, smooth_u, smooth_v, mat) =
  let ptss = maybe_interpolate_grid(ptss, smooth_u, smooth_v)
    @remote(b, surfaceGrid(eachrow(ptss), closed_u, closed_v, smooth_u, smooth_v, mat))
  end

KhepriBase.b_cone(b::THR, cb, r, h, bmat, smat) =
  @remote(b, cylinder(add_z(cb, h/2), r, 0, h, false, smat))

KhepriBase.b_cone_frustum(b::THR, cb, rb, h, rt, bmat, tmat, smat) =
  @remote(b, cylinder(add_z(cb, h/2), rb, rt, h, false, smat))

KhepriBase.b_cylinder(b::THR, cb, r, h, bmat, tmat, smat) =
  @remote(b, cylinder(add_z(cb, h/2), r, r, h, false, smat))

KhepriBase.b_box(b::THR, c, dx, dy, dz, mat) =
    @remote(b, box(add_xyz(c, dx/2, dy/2, dz/2), dx, dy, dz, mat))

KhepriBase.b_sphere(b::THR, c, r, mat) =
  @remote(b, sphere(c, r, mat))

KhepriBase.b_torus(b::THR, c, ra, rb, mat) =
  @remote(b, torus(c, ra, rb, mat))


KhepriBase.b_extruded_surface(b::THR, profile::Region, v, cb, bmat, tmat, smat) =
  let outer = outer_path(profile),
      inners = inner_paths(profile),
      vw = in_world(v)
    if iszero(vw.x) && iszero(vw.y) # Z-axis extrusion: use cb directly
      @remote(b, extrudedSurface(cb,
                                 path_vertices(outer),
                                 is_smooth_path(outer),
                                 [path_vertices(inner) for inner in inners],
                                 [is_smooth_path(inner) for inner in inners],
                                 v,
                                 tmat))
    else # Arbitrary direction: rotate CS so extrusion aligns with local Z
      let cs = cs_from_o_vz(cb, v),
          naked(p) = xy(p.x, p.y, world_cs),
          to2D(path) = [naked(in_cs(p, cs)) for p in path_vertices(path)]
        @remote(b, extrudedSurface(u0(cs),
                                   to2D(outer),
                                   is_smooth_path(outer),
                                   [to2D(inner) for inner in inners],
                                   [is_smooth_path(inner) for inner in inners],
                                   vz(norm(v)),
                                   tmat))
      end
    end
  end

# BIM operations — native implementations to reduce WebSocket traffic

# Geometry helpers for groupedMesh: return (vertices::Vector{Loc}, indices::Vector{Int32}, mat_ref::Int32)

quad_strip_mesh_part(ps, qs, mat) =
  let n = length(ps),
      vs = [p for pair in zip(ps, qs) for p in pair],
      idxs = Int32[idx for i in 0:n-2 for idx in (2i, 2i+2, 2i+1, 2i+2, 2i+3, 2i+1)]
    (vs, idxs, mat)
  end

quad_strip_closed_mesh_part(ps, qs, mat) =
  quad_strip_mesh_part([ps..., ps[1]], [qs..., qs[1]], mat)

polygon_mesh_part(ps, mat) =
  let idxs = Int32[idx for k in 1:length(ps)-2 for idx in (0, k, k+1)]
    (collect(ps), idxs, mat)
  end

strip_mesh_part(path1, path2, mat) =
  let v1s = path_vertices(path1),
      v2s = path_vertices(path2)
    is_closed_path(path1) && is_closed_path(path2) ?
      quad_strip_closed_mesh_part(v1s, v2s, mat) :
      quad_strip_mesh_part(v1s, v2s, mat)
  end

KhepriBase.b_wall_no_openings(b::THR, w_path, w_height, l_thickness, r_thickness, lmat, rmat, smat) =
  path_length(w_path) < coincidence_tolerance() ? void_ref(b) :
  let r_vs = path_vertices(offset(w_path, -r_thickness)),
      l_vs = path_vertices(offset(w_path, l_thickness)),
      h = Float32(w_height * wall_z_fighting_factor),
      closed = is_closed_path(w_path)
    @remote(b, wall(r_vs, l_vs, h, closed,
                    material_ref(b, rmat), material_ref(b, lmat), material_ref(b, smat)))
  end

KhepriBase.b_wall_with_openings(b::THR, w_path, w_height, l_thickness, r_thickness, lmat, rmat, smat, openings) =
  path_length(w_path) < coincidence_tolerance() ? void_ref(b) :
  let w_paths = subpaths(w_path),
      r_w_paths = subpaths(offset(w_path, -r_thickness)),
      l_w_paths = subpaths(offset(w_path, l_thickness)),
      w_height = w_height * wall_z_fighting_factor,
      prevlength = 0,
      smat_ref = material_ref(b, smat),
      lmat_ref = material_ref(b, lmat),
      rmat_ref = material_ref(b, rmat),
      parts = [],
      refs = new_refs(b)
    for (w_seg_path, r_w_path, l_w_path) in zip(w_paths, r_w_paths, l_w_paths)
      let currlength = prevlength + path_length(w_seg_path),
          c_r_w_path = closed_path_for_height(r_w_path, w_height),
          c_l_w_path = closed_path_for_height(l_w_path, w_height),
          r_vs = path_vertices(r_w_path),
          l_vs = path_vertices(l_w_path),
          r_top = map(p -> p + vz(w_height), r_vs),
          l_top = map(p -> p + vz(w_height), l_vs)
        push!(parts, quad_strip_mesh_part(r_top, l_top, smat_ref))
        if !is_closed_path(w_path)
          push!(parts, polygon_mesh_part([r_vs[1], r_top[1], l_top[1], l_vs[1]], smat_ref))
          push!(parts, polygon_mesh_part([l_vs[end], l_top[end], r_top[end], r_vs[end]], smat_ref))
        end
        openings = filter(openings) do op
          if prevlength <= op.path_position < currlength ||
             prevlength <= op.path_position + op.width <= currlength
            let op_height = op.height,
                op_at_start = op.path_position <= prevlength,
                op_at_end = op.path_position + op.width >= currlength,
                op_path = subpath(w_path,
                                  max(prevlength, op.path_position),
                                  min(currlength, op.path_position + op.width)),
                r_op_path = offset(op_path, -r_thickness),
                l_op_path = offset(op_path,  l_thickness),
                fixed_r_op_path =
                  open_polygonal_path([path_start(op_at_start ? r_w_path : r_op_path),
                                       path_end(op_at_end ? r_w_path : r_op_path)]),
                fixed_l_op_path =
                  open_polygonal_path([path_start(op_at_start ? l_w_path : l_op_path),
                                       path_end(op_at_end ? l_w_path : l_op_path)]),
                r_op_translated = translate(fixed_r_op_path, vz(op.base_height)),
                l_op_translated = translate(fixed_l_op_path, vz(op.base_height)),
                c_r_op_path = closed_path_for_height(r_op_translated, op_height),
                c_l_op_path = closed_path_for_height(l_op_translated, op_height),
                r_jacket = op.base_height < coincidence_tolerance() ?
                  let ps = path_vertices(r_op_translated)
                    open_polygonal_path([ps[1], ps[1]+vz(op_height), ps[end]+vz(op_height), ps[end]])
                  end : c_r_op_path,
                l_jacket = op.base_height < coincidence_tolerance() ?
                  let ps = path_vertices(l_op_translated)
                    open_polygonal_path([ps[1], ps[1]+vz(op_height), ps[end]+vz(op_height), ps[end]])
                  end : c_l_op_path
              push!(parts, strip_mesh_part(reverse(r_jacket), reverse(l_jacket), smat_ref))
              c_r_w_path, c_l_w_path = subtract_wall_paths(b, c_r_w_path, c_l_w_path, c_r_op_path, c_l_op_path)
              !(op.path_position >= prevlength && op.path_position + op.width <= currlength)
            end
          else
            true
          end
        end
        prevlength = currlength
        collect_ref!(refs, b_surface(b, reverse(c_l_w_path), lmat_ref))
        collect_ref!(refs, b_surface(b, c_r_w_path, rmat_ref))
      end
    end
    collect_ref!(refs, @remote(b, groupedMesh(parts)))
    refs
  end

KhepriBase.b_railing(b::THR, path, level, host, family) =
  let h = Float32(family.height),
      base = Float32(level_height(b, level)),
      mat = material_ref(b, family.material),
      vs = path_vertices(path)
    @remote(b, railing(map(in_world, vs), base, h,
                       Float32(family.post_spacing), Float32(0.025), mat))
  end

KhepriBase.b_stair(b::THR, base_point, direction, bottom_level, top_level, family) =
  let bottom_h = level_height(b, bottom_level),
      top_h = level_height(b, top_level),
      total_h = top_h - bottom_h,
      n_steps = Int32(round(total_h / family.riser_height)),
      riser_h = Float32(total_h / n_steps)
    @remote(b, stair(in_world(base_point), unitized(direction),
                     Float32(bottom_h), n_steps, riser_h,
                     Float32(family.tread_depth), Float32(family.width),
                     family.has_risers,
                     material_ref(b, family.tread_material),
                     material_ref(b, family.riser_material)))
  end

KhepriBase.b_spiral_stair(b::THR, center, radius, start_angle, included_angle,
                           clockwise, bottom_level, top_level, family) =
  let bottom_h = level_height(b, bottom_level),
      top_h = level_height(b, top_level),
      total_h = top_h - bottom_h,
      n_steps = Int32(round(total_h / family.riser_height)),
      riser_h = Float32(total_h / n_steps)
    @remote(b, spiralStair(in_world(center), Float32(radius),
                           Float32(start_angle), Float32(included_angle),
                           clockwise, Float32(bottom_h), n_steps, riser_h,
                           Float32(family.width),
                           material_ref(b, family.tread_material)))
  end

KhepriBase.b_mesh_obj_fmt(b::THR, obj_name, transform) =
  let dir = dirname(obj_name),
      name = basename(obj_name),
      path = dir == "" ? "resources/models/obj/" : "resources/models/obj/$dir/"
    @remote(b, meshObjFmt(path, name, transform))
  end

## ─────────────────────────────────────────────────────────────────────
##  OBJ/MTL Backend Families — backward compatibility
##
##  OBJ family types and transform functions are now defined in
##  KhepriBase (OBJFamily, OBJFileFamily, obj_family). These aliases
##  preserve backward compatibility for existing user code.
## ─────────────────────────────────────────────────────────────────────

export threejs_obj_family

const ThreeJSObjFamily = OBJFamily
const ThreeJSObjFileFamily = OBJFileFamily
const threejs_obj_family = obj_family

measure_box(; xlength = 20, ylength = 10, zlength = 5) =
  let cyl_r = 0.01,
      sph_r = 0.05
    cylinder(x(0), cyl_r, x(xlength))
    for i in 1:xlength
      sphere(xyz(i,0,0), sph_r)
    end
    cylinder(x(0), cyl_r, y(ylength))
    for i in 1:ylength
      sphere(xyz(0,i,0), sph_r)
    end
    cylinder(x(0), cyl_r, z(zlength))
    for i in 1:zlength
      sphere(xyz(0,0,i), sph_r)
    end
  end

KhepriBase.b_set_environment(b::THR, env_name, set_background) =
  @remote(b, setEnvironment("resources/environments/$env_name", set_background))

KhepriBase.b_set_view(b::THR, camera, target, lens, aperture) =
  @remote(b, setView(camera, target, lens, aperture))

KhepriBase.b_delete_ref(b::THR, r::THRId) =
  @remote(b, delete(r))

KhepriBase.b_delete_all_shape_refs(b::THR) =
  @remote(b, deleteAll())

# Layers
KhepriBase.b_layer(b::THR, name, visible, color) = @remote(b, createLayer(name))
KhepriBase.b_current_layer_ref(b::THR) = @remote(b, getCurrentLayer())
KhepriBase.b_current_layer_ref(b::THR, layer) = @remote(b, setCurrentLayer(layer))
KhepriBase.b_create_layer_from_ref_value(b::THR, r) =
  layer(@remote(b, getLayerName(r)))
KhepriBase.b_set_layer_visible(b::THR, layer, visible) =
  @remote(b, setLayerVisible(ref_value(b, layer), visible))
KhepriBase.b_set_layer_opacity(b::THR, layer, opacity) =
  @remote(b, setLayerOpacity(ref_value(b, layer), convert(Float32, opacity)))
KhepriBase.b_delete_all_shapes_in_layer(b::THR, layer) =
  @warn "KhepriThreejs: per-layer shape deletion not supported; use delete_all_shapes() instead"

# Selection
KhepriBase.b_select_position(b::THR, prompt) =
  let ans = @remote(b, selectPosition(prompt))
    length(ans) > 0 ? ans[1] : nothing
  end
KhepriBase.b_select_positions(b::THR, prompt) =
  @remote(b, selectPosition(prompt))
KhepriBase.b_select_point(b::THR, prompt) =
  select_one_with_prompt(prompt, b, @get_remote b selectShape)
KhepriBase.b_select_points(b::THR, prompt) =
  select_many_with_prompt(prompt, b, @get_remote b selectShapes)
KhepriBase.b_select_curve(b::THR, prompt) =
  select_one_with_prompt(prompt, b, @get_remote b selectShape)
KhepriBase.b_select_curves(b::THR, prompt) =
  select_many_with_prompt(prompt, b, @get_remote b selectShapes)
KhepriBase.b_select_surface(b::THR, prompt) =
  select_one_with_prompt(prompt, b, @get_remote b selectShape)
KhepriBase.b_select_surfaces(b::THR, prompt) =
  select_many_with_prompt(prompt, b, @get_remote b selectShapes)
KhepriBase.b_select_solid(b::THR, prompt) =
  select_one_with_prompt(prompt, b, @get_remote b selectShape)
KhepriBase.b_select_solids(b::THR, prompt) =
  select_many_with_prompt(prompt, b, @get_remote b selectShapes)
KhepriBase.b_select_shape(b::THR, prompt) =
  select_one_with_prompt(prompt, b, @get_remote b selectShape)
KhepriBase.b_select_shapes(b::THR, prompt) =
  select_many_with_prompt(prompt, b, @get_remote b selectShapes)

####################################################
KhepriBase.b_labels(b::THR, p, data, mat) =
  [@remote(b, addAnnotation(p, txt)) #p+vpol(0.2*scale, ϕ), txt))
   for ((; txt, mat, scale), ϕ) in zip(data, division(-π/4, 7π/4, length(data), false))]

KhepriBase.b_start_batch_processing(b::THR) = @remote(b, stopUpdate())

KhepriBase.b_stop_batch_processing(b::THR) = @remote(b, startUpdate())

export gui_create, 
       gui_add_folder, 
       gui_visible,
       gui_add_button, 
       add_gui_button, 
       gui_add_slider, 
       gui_add_dropdown, 
       gui_add_checkbox

KhepriBase.b_gui_create(b::THR, name) = 
  @remote(b, guiCreate(name, 1))

KhepriBase.b_gui_add_folder(b::THR, gui, name, closed) = 
  @remote(b, guiAddFolder(gui, name, closed))

KhepriBase.b_gui_remove(b::THR, gui) = 
  @remote(b, guiRemove(gui))

KhepriBase.b_gui_visible(b::THR, gui, isvisible) =
  @remote(b, guiVisible(gui, isvisible))

KhepriBase.b_gui_add_button(b::THR, gui, name, handler) = 
  @remote(b, guiAddButton(gui, name, register_handler(b, name, handler)))

KhepriBase.b_gui_add_checkbox(b::THR, gui, name, curr, handler) = 
  @remote(b, guiAddCheckbox(gui, name, register_handler(b, name, handler), curr))

KhepriBase.b_gui_add_slider(b::THR, gui, name, min, max, step, curr, handler) = 
  @remote(b, guiAddSlider(gui, name, register_handler(b, name, handler), min, max, step, curr))

KhepriBase.b_gui_add_dropdown(b::THR, gui, name, options, curr, handler) = 
  @remote(b, guiAddDropdown(gui, name, register_handler(b, name, handler), options, curr))

KhepriBase.b_gui_add_slider_parameter(b::THR, gui, name, min, max, step, parameter) =
  b_gui_add_slider(b, gui, name, min, max, step, parameter(), update_parameter_handler(parameter))

KhepriBase.b_gui_add_button_load_file(b::THR, gui, name, handler) = 
  @remote(b, guiAddLoadFileButton(gui, name, register_handler(b, name, handler)))


export grid_helper, dark_grid_helper, light_grid_helper
grid_helper(size, divisions, color_line, color_grid; backend=current_backend()) =
  @remote(backend, gridHelper(size, divisions, color_line, color_grid))

dark_grid_helper(; backend=current_backend()) =
  grid_helper(1000, 1000, RGB(0.25, 0.25, 0.25), RGB(0.125, 0.125, 0.125); backend)
light_grid_helper(; backend=current_backend()) =
  grid_helper(1000, 1000, RGB(0.75, 0.75, 0.75), RGB(0.875, 0.875, 0.875); backend)

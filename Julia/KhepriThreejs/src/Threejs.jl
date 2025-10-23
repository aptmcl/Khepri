export threejs, threejs_material
       
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
  t = v.cs.transform
  encode(Val(:TS), Val(:float3), c, (t[1,1], t[2,1], t[3,1]))
  encode(Val(:TS), Val(:float3), c, (t[1,2], t[2,2], t[3,2]))
  encode(Val(:TS), Val(:float3), c, (t[1,3], t[2,3], t[3,3]))
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

threejs_api = @remote_api :THR """
typedFunction("getOperationNamed", [Str], Int32, (name: string) => {
typedFunction("delete", [Int32], None, (i: number) =>
typedFunction("deleteAll", [], None, () => {
typedFunction("addAnnotation", [Point3d, Str], Int32, (p: THREE.Vector3, txt: string) =>
typedFunction("deleteAnnotation", [Int32], None, (i: number) => 
typedFunction("guiCreate", [Str, Int32], GUIId, (title: string, kind: number) => {
typedFunction("guiAddFolder", [GUIId, Str], GUIId, (gui: GUI, title: string) =>
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
typedFunction("mesh", [ArrayFloat32, MatId], Id, (vs: Float32Array, _idxs: Int32Array, mat: THREE.Material) => {
typedFunction("meshIndexed", [ArrayFloat32, ArrayInt32, MatId], Id, (vs: Float32Array, idxs: Int32Array, mat: THREE.Material) => {
typedFunction("quadStrip", [[Point3d], [Point3d], Bool, MatId], Id, (ps: THREE.Vector3[], qs: THREE.Vector3[], smooth: boolean, mat: THREE.Material) => {
typedFunction("surfaceGrid", [[[Point3d]], Bool, Bool, Bool, Bool, MatId], Id, (points: THREE.Vector3[][], uClosed: boolean, vClosed: boolean, uSmooth: boolean, vSmooth: boolean, mat: THREE.Material) => {    
typedFunction("extrudedSurface", [Matrix4x4, [Point2d], Bool, [[Point2d]], [Bool], Vector3d, MatId], Id, (m: THREE.Matrix4, ps: THREE.Vector2[], _smooth: boolean, qss: THREE.Vector2[][], _smoothHoles: boolean, v: THREE.Vector3, mat: THREE.Material) => {
typedFunction("meshObjFmt", [Str, Str, Matrix4x4], Id, (path: string, name: string, m: THREE.Matrix4) => {
typedFunction("MeshPhysicalMaterial", [Dict], MatId, (params: { [key: string]: any }) =>
typedFunction("MeshStandardMaterial", [Dict], MatId, (params: { [key: string]: any }) =>
typedFunction("MeshPhongMaterial", [Dict], MatId, (params: { [key: string]: any }) =>
typedFunction("MeshLambertMaterial", [Dict], MatId, (params: { [key: string]: any }) =>
typedFunction("LineBasicMaterial", [Dict], MatId, (params: { [key: string]: any }) =>
typedAsyncFunction("glTFMaterial", [Str], MatId, (path: string, cont: Function) =>
typedAsyncFunction("setEnvironment", [Str, Bool], None, (path: string, setBackground: boolean) =>
typedFunction("setView", [Point3d, Point3d, Float32, Float32], None, (position: THREE.Vector3, target: THREE.Vector3, lens: number, _aperture: number) => {
typedFunction("stopUpdate", [], None, () => {
typedFunction("startUpdate", [], None, () => {
typedAsyncFunction("showKMLCoordinatesFromFile", [], None, (cont: Function) => {
"""


# We will use WebSockets for Threejs

abstract type THRKey end
const THRId = Int32
const THRIds = Vector{THRId}
const THRRef = NativeRef{THRKey, THRId}
const THRRefs = Vector{THRRef}
const THR = WebSocketBackend{THRKey, THRId}


backend_name(b::THR) = b.name

const content_type_header = Dict(
  "html"=>"text/html",
  "js"  =>"application/javascript",
  "css" =>"text/css",
  "png" =>"image/png",
  "jpg" =>"image/jpeg",
  "jpeg"=>"image/jpeg",
  "obj" =>"text/plain",
  "mtl" =>"text/plain",
  "hdr" =>"image/hdr",
  "gltf"=>"model/gltf+json",
  "glb" =>"model/gltf-binary",
  "bin" =>"application/octet-stream",
  )

get_file_content_type(path) =
  ["Content-Type" => content_type_header[splitext(path)[2][2:end]]] # splitext gives (root, .ext)

function KhepriBase.start_connection(b::THR)
    let files = ["index.html", "assets/index.js", "assets/index.css"],
      root = joinpath(@__DIR__, "..", "KhepriThree.js", "dist"),
      #files = ["index.html", "style.css", "main.min.js", "main.js"],
      #root = joinpath(@__DIR__, "..", "Threejs", "dist"),
      read_file(file) = open(s -> read(s, String), joinpath(root, file))
    global router = HTTP.Router()
    # Handler for resources
    HTTP.register!(router, "GET", "/resources/**", request -> 
      let subpath = split(request.target, "/", keepempty=false)[2:end], # drop first 'resources'
          path = joinpath(resources_pathname, subpath...)
        println("Request for resource file: $path")
        HTTP.Response(200, 
                      get_file_content_type(path),
                      open(s -> read(s, String), path))
      end)
    #=
    HTTP.register!(router, "GET", "/resources/models/{fmt}/{path}/{name}", req -> 
      let params = HTTP.getparams(req),
          fmt = params["fmt"],
          path = params["path"],
          name = params["name"],
          filename = joinpath(models_pathname, fmt, path, name)
        println("Request for model file: $filename")
        HTTP.Response(200, get_file_content_type(name), open(s -> read(s, String), filename))
      end)
    HTTP.register!(router, "GET", "/resources/environments/{name}", req -> 
      let params = HTTP.getparams(req),
          name = params["name"],
          filename = joinpath(environments_pathname, name)
        println("Request for environment file: $filename")
        HTTP.Response(200, get_file_content_type(name), open(s -> read(s, String), filename))
      end)
    =#
    for file in files
      HTTP.register!(router, "GET", "/$(file)", req -> HTTP.Response(200, get_file_content_type(file), read_file(file)))
    end
    let idx = files[1]
      HTTP.register!(router, "GET", "/", req -> HTTP.Response(200, get_file_content_type(idx), read_file(idx)))
    end
    # Fallback
    HTTP.register!(router, "GET", "/{rest}", req -> 
      let rest = HTTP.getparams(req)["rest"]
        error("Requested unregistered '$rest'")
      end)
    let connection = nothing
      global server = HTTP.listen!(b.host, b.port) do http
                   if HTTP.WebSockets.isupgrade(http.message)
                       HTTP.WebSockets.upgrade(http) do websocket
                           connection = websocket
                           wait()
                       end
                   else
                      println("HTTP request for $(http.message.target)")
                      HTTP.streamhandler(router)(http)
                   end
                 end
      # Let's wait for the first connection
      while isnothing(connection)
        @info "Khepri started on URL:http://$(b.host):$(b.port)"
        sleep(5)
      end
      WebSocketConnection(server, router, connection)
    end
  end
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
      b->threejs_glTF_material(b, "/resources/materials/plywood/plywood_4k.gltf"))
	  set_material(THR, material_concrete, b->threejs_material(b, RGB(140/255,140/255,140/255)))
	  set_material(THR, material_plaster, b->threejs_plaster_material(b))
	  #set_material(THR, material_plaster, b->threejs_material(b, RGB(0.7,0.7,0.7)))
	  set_material(THR, material_grass, b->threejs_material(b, RGB(0.1,0.7,0.1)))
    #set_material(THR, default_annotation_material(), b->threejs_metal_material(b))
  end



KhepriBase.b_get_material(b::THR, f::Function) = f(b)

const threejs = THR("Threejs", "0.0.0.0" #="127.0.0.1"=#, threejs_port, threejs_api)

KhepriBase.has_boolean_ops(::Type{THR}) = HasBooleanOps{false}()

KhepriBase.backend(::THRRef) = threejs
KhepriBase.void_ref(b::THR) = -1 % Int32

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

old_threejs_glass_material(b, opacity=0.3, color=RGB(0.95,0.95,1.0)) =
  @remote(b, MeshPhysicalMaterial(
    (#"vertexColors" => 0,
     transparent=true,
     opacity=opacity,
     #"depthTest" => true,
     #"linewidth" => 1.0,
     #"depthFunc" => 3,
     side=2,
     color=color,
     reflectivity=0.1,
     depthWrite=false
    )))

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

old_threejs_metal_material(b, roughness=0.5, color=RGB(0.9,0.9,0.9)) =
  @remote(b, MeshStandardMaterial(
    (#metalness=1.0,
     roughness=roughness,
     side=2,
     color=color,
     depthWrite=true
    )))

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
#=
KhepriBase.b_polygon(b::THR, ps, mat) =
	@remote(b, line(ps, true, mat))
=#
KhepriBase.b_spline(b::THR, ps, v1, v2, mat) =
  # TODO: Implement proper spline with tangent vectors v1, v2
  # For now, using Catmull-Rom spline without tangent constraints
  @remote(b, spline(ps, false, mat))

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

KhepriBase.b_ngon(b::THR, ps, pivot, smooth, mat) =
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

KhepriBase.b_quad_strip(b::THR, ps, qs, smooth, mat) =
  @remote(b, quadStrip(ps, qs, smooth, mat))

#=
KhepriBase.b_quad_strip_closed(b::THR, ps, qs, smooth, mat) =
  @remote(b, quad_strip_closed(ps, qs, smooth, mat))

=#
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

#=
KhepriBase.b_generic_pyramid_frustum(b::THR, bs, ts, smooth, bmat, tmat, smat) =
  @remote(b, pyramid_frustum(bs, ts, smooth, bmat, tmat, smat))
=#
KhepriBase.b_cone(b::THR, cb, r, h, bmat, smat) =
  @remote(b, cylinder(add_z(cb, h/2), r, 0, h, false, smat))

KhepriBase.b_cone_frustum(b::THR, cb, rb, h, rt, bmat, tmat, smat) =
  @remote(b, cylinder(add_z(cb, h/2), rb, rt, h, false, smat))

KhepriBase.b_cylinder(b::THR, cb, r, h, bmat, tmat, smat) =
  @remote(b, cylinder(add_z(cb, h/2), r, r, h, false, smat))
#=
KhepriBase.b_cuboid(b::THR, pb0, pb1, pb2, pb3, pt0, pt1, pt2, pt3, mat) =
  @remote(b, cuboid([pb0, pb1, pb2, pb3, pt0, pt1, pt2, pt3], mat))
=#
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
    iszero(vw.x) && iszero(vw.y) ? # ThreeJS can extrude a surface along Z
    	@remote(b, extrudedSurface(cb, 
                                 path_vertices(outer),
                                 is_smooth_path(outer),
                                 [path_vertices(inner) for inner in inners],
                                 [is_smooth_path(inner) for inner in inners],
                                 v,
                                 tmat)) : # use the default implementation
      @invoke b_extruded_surface(b::Backend, profile::Region, v, cb, bmat, tmat, smat)
  end

KhepriBase.b_mesh_obj_fmt(b::THR, obj_name, base) =
  @remote(b, meshObjFmt("resources/models/obj/$obj_name/", obj_name, base))

measure_box(; xlength = 20, ylength = 10, zlength = 5) =
  let cyl_r = 0.01,
      sph_r = 0.05
    cylinder(x(0), 0.01, x(xlength))
    for i in 1:xlength
      sphere(xyz(i,0,0), 0.05)
    end
    cylinder(x(0), 0.01, y(ylength))
    for i in 1:ylength
      sphere(xyz(0,i,0), 0.05)
    end
    cylinder(x(0), 0.01, z(zlength))
    for i in 1:zlength
      sphere(xyz(0,0,i), 0.05)
    end
  end

KhepriBase.b_set_environment(b::THR, env_name, set_background) =
  @remote(b, setEnvironment("resources/environments/$env_name", set_background))

KhepriBase.b_set_view(b::THR, camera, target, lens, aperture) =
  @remote(b, setView(camera, target, lens, aperture))

KhepriBase.b_zoom_extents(b::THR) = 
  @remote(b, zoomExtents())
 
KhepriBase.b_delete_ref(b::THR, r::THRId) =
  @remote(b, delete(r))

KhepriBase.b_delete_all_shape_refs(b::THR) =
  @remote(b, deleteAll())
#=
#=

backend_stroke(b::THR, path::OpenSplinePath) =
  if (path.v0 == false) && (path.v1 == false)
    add_object(b, threejs_line(path_frames(path), line_material(b)))
  elseif (path.v0 != false) && (path.v1 != false)
    @remote(b, InterpSpline(path.vertices, path.v0, path.v1))
  else
    @remote(b, InterpSpline(
                     path.vertices,
                     path.v0 == false ? path.vertices[2]-path.vertices[1] : path.v0,
                     path.v1 == false ? path.vertices[end-1]-path.vertices[end] : path.v1))
  end
backend_stroke(b::THR, path::ClosedSplinePath) =
    add_object(b, threejs_line(path_frames(path), line_material(b)))
backend_fill(b::THR, path::ClosedSplinePath) =
    add_object(b, threejs_surface_polygon(path_frames(path), material(b)))

#=
smooth_pts(pts) = in_world.(path_frames(open_spline_path(pts)))

=#

# Layers
current_layer(b::THR) =
  b.layer

current_layer(layer, b::THR) =
  b.layer = layer

backend_create_layer(b::THR, name::String, active::Bool, color::RGB) =
  begin
    @assert active
    thr_layer(name, color)
  end

#=
create_ground_plane(shapes, material=default_THR_ground_material()) =
  if shapes == []
    error("No shapes selected for analysis. Use add-THR-shape!.")
  else
    let (p0, p1) = bounding_box(union(shapes)),
        (center, ratio) = (quad_center(p0, p1, p2, p3),
                  distance(p0, p4)/distance(p0, p2));
     ratio == 0 ?
      error("Couldn"t compute height. Use add-THR-shape!.") :
      let pts = map(p -> intermediate_loc(center, p, ratio*10), [p0, p1, p2, p3]);
         create_surface_layer(pts, 0, ground_layer(), material)
        end
       end
  end
        w = max(floor_extra_factor()*distance(p0, p1), floor_extra_width())
        with(current_layer,floor_layer()) do
          box(xyz(min(p0.x, p1.x)-w, min(p0.y, p1.y)-w, p0.z-1-floor_distance()),
              xyz(max(p0.x, p1.x)+w, max(p0.y, p1.y)+w, p0.z-0-floor_distance()))
        end
      end
    end

=#

=#
=#
####################################################
# HACK!!! FIX THIS!
KhepriBase.b_labels(b::THR, p, data, mat) = []
  #=
  [@remote(b, addAnnotation(p+vpol(0.2*scale, ϕ), txt))
   for ((; txt, mat, scale), ϕ) in zip(data, division(-π/4, 7π/4, length(data), false))]
   =#

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

KhepriBase.b_gui_add_folder(b::THR, gui, name) = 
  @remote(b, guiAddFolder(gui, name))

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
grid_helper(size, divisions, color_line, color_grid) =
  @remote(threejs, gridHelper(size, divisions, color_line, color_grid))

dark_grid_helper() =
  grid_helper(1000, 1000, RGB(0.25, 0.25, 0.25), RGB(0.125, 0.125, 0.125))
light_grid_helper() =
  grid_helper(1000, 1000, RGB(0.75, 0.75, 0.75), RGB(0.875, 0.875, 0.875))

#=
handle_backend_requests(b=current_backend()[1]) =
  let 
  

=#

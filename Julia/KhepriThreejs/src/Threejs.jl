export threejs, threejs_material
       
# THR is a subtype of JS
parse_signature(::Val{:THR}, sig::T) where {T} = parse_signature(Val(:JS), sig)
encode(::Val{:THR}, t::Val{T}, c::IO, v) where {T} = encode(Val(:JS), t, c, v)
decode(::Val{:THR}, t::Val{T}, c::IO) where {T} = decode(Val(:JS), t, c)
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

encode(::Val{:THR}, t::Union{Val{:Point3d},Val{:Vector3d}}, c::IO, p) =
  encode(Val(:JS), Val(:float3), c, raw_point(p))
decode(::Val{:THR}, t::Val{:Point3d}, c::IO) =
  xyz(decode(Val(:JS), Val(:float3), c)..., world_cs)
decode(::Val{:THR}, t::Val{:Vector3d}, c::IO) =
  vxyz(decode(Val(:JS), Val(:float3), c)..., world_cs)

encode(::Val{:THR}, t::Union{Val{:Point2d},Val{:Vector2d}}, c::IO, p) =
  encode(Val(:JS), Val(:float2), c, raw_point(p))
decode(::Val{:THR}, t::Val{:Point2d}, c::IO) =
  xy(decode(Val(:JS), Val(:float2), c)..., world_cs)
decode(::Val{:THR}, t::Val{:Vector2d}, c::IO) =
  vxy(decode(Val(:JS), Val(:float2), c)..., world_cs)

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
  encode(Val(:JS), Val(:float3), c, (t[1,1], t[2,1], t[3,1]))
  encode(Val(:JS), Val(:float3), c, (t[1,2], t[2,2], t[3,2]))
  encode(Val(:JS), Val(:float3), c, (t[1,3], t[2,3], t[3,3]))
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
typedFunction("points", [[Point3d], MatId], Id, (vs, mat) => {
typedFunction("line", [[Point3d], MatId], Id, (vs, mat) => {
typedFunction("spline", [[Point3d], Bool, MatId], Id, (vs, closed, mat) => {
typedFunction("arc", [Matrix4x4, Float32, Float32, Float32, MatId], Id, (m, r, start, finish, mat) => {
typedFunction("arcRegion", [Matrix4x4Y, Float32, Float32, Float32, MatId], Id, (m, r, start, amplitude, mat) => {
typedFunction("surfacePolygonWithHoles", [Matrix4x4, [Point2d], [[Point2d]], MatId], Id, (m, ps, qss, mat) => {
typedFunction("sphere", [Point3d, Float32, MatId], Id, (c, r, mat) => {
typedFunction("box", [Matrix4x4, Float32, Float32, Float32, MatId], Id, (m, dx, dy, dz, mat) => {
typedFunction("torus", [Matrix4x4, Float32, Float32, MatId], Id, (m, re, ri, mat) => {
typedFunction("cylinder", [Matrix4x4Y, Float32, Float32, Float32, MatId], Id, (m, rb, rt, h, mat) => {
typedFunction("mesh", [ArrayFloat32, MatId], Id, (vs, idxs, mat) => {
typedFunction("meshIndexed", [ArrayFloat32, ArrayInt32, MatId], Id, (vs, idxs, mat) => {
typedFunction("delete", [Int32], None, (i) => delMesh(i));
typedFunction("deleteAll", [], None, () => delAllMeshes());
typedFunction("setView", [Point3d, Point3d, Float32, Float32], None, (position, target, lens, aperture) => {
typedFunction("MeshPhysicalMaterial", [Dict], MatId, (params) => 
typedFunction("MeshStandardMaterial", [Dict], MatId, (params) => 
typedFunction("MeshPhongMaterial", [Dict], MatId, (params) => 
typedFunction("MeshLambertMaterial", [Dict], MatId, (params) =>
typedFunction("LineBasicMaterial", [Dict], MatId, (params) => 
typedFunction("addAnnotation", [Point3d, Str], Int32, (p, txt) => addSprite(p, "", txt));
typedFunction("deleteAnnotation", [Int32], None, (i) => delSprite(i));
typedFunction("zoomExtents", [], None, () => {
typedFunction("stopUpdate", [], None, () => 
typedFunction("startUpdate", [], None, () => {
typedFunction("guiCreate", [Str, Int32], GUIId, (title, kind) => {    
typedFunction("guiAddFolder", [GUIId, Str], GUIId, (gui, title) =>
typedFunction("guiAddButton", [GUIId, Str, Str], None, (gui, name, request) => {
typedFunction("guiAddCheckbox", [GUIId, Str, Str, Bool], None, (gui, name, request, curr) => {
typedFunction("guiAddSlider", [GUIId, Str, Str, Float32, Float32, Float32, Float32], None, (gui, name, request, min, max, step, curr) => {
typedFunction("guiAddDropdown", [GUIId, Str, Str, Dict, Int32], None, (gui, name, request, options, curr) => {
typedFunction("gridHelper", [Int32, Int32, RGB, RGB], None, (size, divisions, colorCenterLine, colorGrid) => {
"""
# We will use WebSockets for Threejs

abstract type THRKey end
const THRId = Int32
const THRIds = Vector{THRId}
const THRRef = NativeRef{THRKey, THRId}
const THRRefs = Vector{THRRef}
const THR = WebSocketBackend{THRKey, THRId}


backend_name(b::THR) = b.name

KhepriBase.start_connection(b::THR) =
  let files = ["index.html", "style.css", "main.min.js", "main.js"],
      root = joinpath(@__DIR__, "..", "Threejs", "dist"),
      read_file(file) = open(s -> read(s, String), joinpath(root, file)),
      router = HTTP.Router()
    for file in files
      HTTP.register!(router, "GET", "/$(file)", req -> HTTP.Response(200, read_file(file)))
    end
    HTTP.register!(router, "GET", "/", req -> HTTP.Response(200, read_file("index.html")))
    let connections = Set{HTTP.WebSockets.WebSocket}(),
        server = HTTP.listen!(b.host, b.port) do http
                   if HTTP.WebSockets.isupgrade(http.message)
                       HTTP.WebSockets.upgrade(http) do websocket
                           push!(connections, websocket)
                           wait()
                       end
                   else
                       HTTP.streamhandler(router)(http)
                   end
                 end
      # Let's wait for the first connection
      while isempty(connections)
        @info "Khepri started on URL:http://$(b.host):$(b.port)"
        sleep(5)
      end
      WebSocketConnection(server, router, connections)
    end
  end

set_default_materials() =
  begin
    set_material(THR, material_point, b->threejs_line_material(b, RGB(1.0,1.0,1.0)))
    set_material(THR, material_curve, b->threejs_line_material(b, RGB(1.0,1.0,1.0)))
    set_material(THR, material_surface, b->threejs_material(b, RGB(0.9,0.1,0.1)))
    set_material(THR, material_basic, b->threejs_material(b, RGB(0.8,0.8,0.8)))
    set_material(THR, material_glass, b->threejs_glass_material(b))
	  set_material(THR, material_metal, b->threejs_metal_material(b))
	  set_material(THR, material_wood, b->threejs_material(b, RGB(169/255,122/255,87/255)))
	  set_material(THR, material_concrete, b->threejs_material(b, RGB(140/255,140/255,140/255)))
	  set_material(THR, material_plaster, b->threejs_material(b, RGB(0.7,0.7,0.7)))
	  set_material(THR, material_grass, b->threejs_material(b, RGB(0.1,0.7,0.1)))
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

threejs_glass_material(b, opacity=0.3, color=RGB(0.95,0.95,1.0)) =
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
threejs_metal_material(b, roughness=0.5, color=RGB(0.9,0.9,0.9)) =
  @remote(b, MeshStandardMaterial(
    (#metalness=1.0,
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
  # This only works for convex polygons
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

#=
KhepriBase.b_quad_strip(b::THR, ps, qs, smooth, mat) =
  @remote(b, quad_strip(ps, qs, smooth, mat))

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
#=
KhepriBase.b_surface_grid(b::THR, ptss, closed_u, closed_v, smooth_u, smooth_v, mat) =
  let (nu, nv) = size(ptss)
	  smooth_u && smooth_v ?
	    @remote(b, quad_surface(vcat(ptss...), nu, nv, closed_u, closed_v, true, mat)) :
	    smooth_u ?
	    	(closed_u ?
          vcat([b_quad_strip_closed(b, ptss[:,i], ptss[:,i+1], true, mat) for i in 1:nv-1]...,
	             closed_v ? [b_quad_strip_closed(b, ptss[:,end], ptss[:,1], true, mat)] : new_refs(b)) :
	        vcat([b_quad_strip(b, ptss[:,i], ptss[:,i+1], true, mat) for i in 1:nv-1]...,
	             closed_v ? [b_quad_strip(b, ptss[:,end], ptss[:,1], true, mat)] : new_refs(b))) :
 	      (closed_v ?
             vcat([b_quad_strip_closed(b, ptss[i,:], ptss[i+1,:], smooth_v, mat) for i in 1:nu-1],
    	         	closed_u ? [b_quad_strip_closed(b, ptss[end,:], ptss[1,:], smooth_v, mat)] : new_refs(b)) :
    	       vcat([b_quad_strip(b, ptss[i,:], ptss[i+1,:], smooth_v, mat) for i in 1:nu-1],
    	          	closed_u ? [b_quad_strip(b, ptss[end,:], ptss[1,:], smooth_v, mat)] : new_refs(b)))
  end

KhepriBase.b_generic_pyramid_frustum(b::THR, bs, ts, smooth, bmat, tmat, smat) =
  @remote(b, pyramid_frustum(bs, ts, smooth, bmat, tmat, smat))
=#
KhepriBase.b_cone(b::THR, cb, r, h, bmat, smat) =
  @remote(b, cylinder(add_z(cb, h/2), r, 0, h, smat))

KhepriBase.b_cone_frustum(b::THR, cb, rb, h, rt, bmat, tmat, smat) =
  @remote(b, cylinder(add_z(cb, h/2), rb, rt, h, smat))

KhepriBase.b_cylinder(b::THR, cb, r, h, bmat, tmat, smat) =
  @remote(b, cylinder(add_z(cb, h/2), r, r, h, smat))
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

#=



function find_open_port(host, default_port, max_retries)
    for port in default_port:(default_port + max_retries)
        server = try
            listen(host, port)
        catch e
            if e isa Base.IOError
                continue
            end
        end
        close(server)
        # It is *possible* that a race condition could occur here, in which
        # some other process grabs the given port in between the close() above
        # and the open() below. But it's unlikely and would not be terribly
        # damaging (the user would just have to call open() again).
        return port
    end
end

function start_server(core::CoreVisualizer)
    asset_files = ["index.html", "main.min.js", "main.js"]

    read_asset(file) = open(s -> read(s, String), joinpath(VIEWER_ROOT, file))

    router = HTTP.Router()
    for file in asset_files
        HTTP.register!(router, "GET", "/$(file)",
                       req -> HTTP.Response(200, read_asset(file)))
    end
    HTTP.register!(router, "GET", "/",
                   req -> HTTP.Response(200, read_asset("index.html")))

    server = HTTP.listen!(core.host, core.port) do http
        if HTTP.WebSockets.isupgrade(http.message)
            HTTP.WebSockets.upgrade(http) do websocket
                push!(core.connections, websocket)
                send_scene(core.tree, websocket)
                wait()
            end
        else
            HTTP.streamhandler(router)(http)
        end
    end
    @info "MeshCat server started. You can open the visualizer by visiting the following URL in your browser:\n$(url(core))"
    return server
end

function close_server!(core::CoreVisualizer)
    if !isnothing(core.server) && isopen(core.server)
        HTTP.close(core.server)
        @info "MeshCat server closed."
    end
end

function url(core::CoreVisualizer)
    "http://$(core.host):$(core.port[])"
end

function Base.wait(core::CoreVisualizer)
    while isempty(core.connections)
        sleep(0.5)
    end
end

"""
    vis = Visualizer()

Construct a new MeshCat visualizer instance.

Useful methods:

    vis[:group1] # get a new visualizer representing a sub-tree of the scene
    setobject!(vis, geometry) # set the object shown by this visualizer's sub-tree of the scene
    settransform!(vis, tform) # set the transformation of this visualizer's sub-tree of the scene
    setvisible!(vis, false) # hide this part of the scene
"""
struct Visualizer <: AbstractVisualizer
    core::CoreVisualizer
    path::Path
end

Visualizer() = Visualizer(CoreVisualizer(), ["threejs"])

"""
$(TYPEDSIGNATURES)

Wait until at least one browser has connected to the
visualizer's server. This is useful in scripts to delay
execution until the browser window has opened.
"""
Base.wait(v::Visualizer) = wait(v.core)

# IJuliaCell(vis::Visualizer; kw...) = iframe(vis.core; kw...)

Base.show(io::IO, v::Visualizer) = print(io, "MeshCat Visualizer with path $(v.path) at $(url(v.core))")

    
js_quaternion(m::AbstractMatrix) = js_quaternion(RotMatrix(SMatrix{3, 3, eltype(m)}(m)))
function js_quaternion(q::QuatRotation)
    w, x, y, z = params(q)
    return [x, y, z, w]
end
js_quaternion(::UniformScaling) = js_quaternion(QuatRotation(1., 0., 0., 0.))
js_quaternion(r::Rotation) = js_quaternion(QuatRotation(r))
js_quaternion(tform::Transformation) = js_quaternion(transform_deriv(tform, SVector(0., 0, 0)))

function js_scaling(tform::AbstractAffineMap)
    m = transform_deriv(tform, SVector(0., 0, 0))
    SVector(norm(SVector(m[1, 1], m[2, 1], m[3, 1])),
            norm(SVector(m[1, 2], m[2, 2], m[3, 2])),
            norm(SVector(m[1, 3], m[2, 3], m[3, 3])))
end

js_position(t::Transformation) = convert(Vector, t(SVector(0., 0, 0)))


struct DisplayedVisualizer
    core::CoreVisualizer
end


DisplayedVisualizer(vis::Visualizer) = DisplayedVisualizer(vis.core)

url(c::DisplayedVisualizer) = url(c.core)

"""
Render a MeshCat visualizer inline in Jupyter, Juno, or VSCode.

If this is the last command in a Jupyter notebook cell, then the
visualizer should show up automatically in the corresponding output
cell.

If this is run from the Juno console, then the visualizer should show
up in the Juno plot pane. Likewise if this is run from VSCode with
the julia-vscode extension, then the visualizer should show up in the
Julia Plots pane.
"""
render(vis::Visualizer) = render(vis.core)
render(core::CoreVisualizer) = DisplayedVisualizer(core)

@deprecate IJuliaCell(v::Visualizer) render(v)

function Base.show(io::IO,
        ::Union{MIME"text/html", MIME"juliavscode/html"},
        frame::DisplayedVisualizer)
    wait_for_server(frame.core)
    print(io, """
    <div style="height: 500px; width: 100%; overflow-x: auto; overflow-y: hidden; resize: both">
    <iframe src="$(url(frame))" style="width: 100%; height: 100%; border: none"></iframe>
    </div>
""")
end

function Base.show(io::IO,
        ::MIME"application/prs.juno.plotpane+html",
        d::DisplayedVisualizer)
    wait_for_server(d.core)
    print(io, """
    <div style="height: 100%; width: 100%; overflow-x: auto; overflow-y: hidden; resize: both">
    <iframe src="$(url(d.core))" style="width: 100%; height: 100%; border: none"></iframe>
    </div>
    """)
end

function _create_command(data::Vector{UInt8})
    return """
fetch("data:application/octet-binary;base64,$(base64encode(data))")
    .then(res => res.arrayBuffer())
    .then(buffer => viewer.handle_command_bytearray(new Uint8Array(buffer)));
    """
end

"""
Extract a single HTML document containing the entire MeshCat scene,
including all geometries, properties, and animations, as well as all
required javascript assets. The resulting HTML document should render
correctly after you've exited Julia, and even if you have no internet
access.
"""
static_html(vis::Visualizer) = static_html(vis.core)

function static_html(core::CoreVisualizer)
    viewer_commands = String[]

    foreach(core.tree) do node
        if node.object !== nothing
            push!(viewer_commands, _create_command(node.object));
        end
        if node.transform !== nothing
            push!(viewer_commands, _create_command(node.transform));
        end
        for data in values(node.properties)
            push!(viewer_commands, _create_command(data));
        end
    end

    return """
        <!DOCTYPE html>
        <html>
            <head> <meta charset=utf-8> <title>MeshCat</title> </head>
            <body>
                <div id="threejs-pane">
                </div>
                <script>
                    $(open(s -> read(s, String), joinpath(VIEWER_ROOT, "main.min.js")))
                </script>
                <script>
                    var viewer = Khepri.init(document.getElementById("threejs-pane"));
                    $(join(viewer_commands, '\n'))
                </script>
                 <style>
                    body {margin: 0; }
                    #threejs-pane {
                        width: 100vw;
                        height: 100vh;
                        overflow: hidden;
                    }
                </style>
                <script id="embedded-json"></script>
            </body>
        </html>
    """
end

struct StaticVisualizer
    core::CoreVisualizer
end

"""
Render a static version of the visualizer, suitable for embedding
and offline use. The embedded visualizer includes all geometries,
properties, and animations which have been added to the scene, baked
into a single HTML document. This document also includes the full
compressed MeshCat javascript source files, so it should render
properly even after you've exited Julia and even if you have no
internet access.

To get access to the raw static HTML representation, see `static_html`
"""
render_static(vis::Visualizer, args...; kw...) = render_static(vis.core)

render_static(core::CoreVisualizer) = StaticVisualizer(core)


_srcdoc_escape(x) = replace(replace(x, '&' => "&amp;"), '\"' => "&quot;")

function static_iframe_wrapper(html)
    id = uuid1()
    return """
        <div style="height: 500px; width: 100%; overflow-x: auto; overflow-y: hidden; resize: both">
        <iframe id="$id"
         style="width: 100%; height: 100%; border: none"
         srcdoc="$(_srcdoc_escape(html))">
        </iframe>
        </div>
    """
end

function Base.show(io::IO,
        ::Union{MIME"text/html", MIME"juliavscode/html"},
        static_vis::StaticVisualizer)
    print(io, static_iframe_wrapper(static_html(static_vis.core)))
end

using Sockets: connect
"""
Open the visualizer. By default, this will launch your default web browser
pointing to the visualizer's URL.
"""
Base.open(vis::Visualizer, args...; kw...) = open(vis.core, args...; kw...)

function wait_for_server(core::CoreVisualizer, timeout=100)
    interval = 0.25
    socket = nothing
    for i in range(0, timeout, step=interval)
        try
            socket = connect(core.host, core.port)
            sleep(interval)
            break
        catch e
            if e isa Base.IOError
                sleep(interval)
            end
        end
    end
    if socket === nothing
        error("Could not establish a connection to the visualizer.")
    else
        close(socket)
    end
end

function Base.open(core::CoreVisualizer; start_browser::Bool = true)
    wait_for_server(core)
    start_browser && open_url(url(core))
end

function open_url(url)
    try
        if Sys.iswindows()
            run(`cmd.exe /C "start $url"`)
        elseif Sys.isapple()
            run(`open $url`)
        elseif Sys.islinux()
            run(`xdg-open $url`)
        end
    catch e
        println("Could not open browser automatically: $e")
        println("Please open the following URL in your browser:")
        println(url)
    end
end


function setup_integrations()
    @require Electron="a1bb12fb-d4d1-54b4-b10a-ee7951ef7ad3" begin
        function Base.open(core::CoreVisualizer, w::Electron.Application)
            Electron.Window(w, Electron.URI(url(core)))
            w
        end
    end

    @require WebIO="0f1e0344-ec1d-5b48-a673-e5cf874b6c29" begin
        WebIO.render(vis::Visualizer) = WebIO.render(vis.core)

        WebIO.render(core::CoreVisualizer) = WebIO.render(MeshCat.render(core))
    end
end
                
end


threejs_object(type, geom, material, p=u0(world_cs)) =
  (metadata=threejs_metadata(),
   geometries=[geom],
   materials=[material],
   object=(uuid=string(uuid1()),
           type=type,
           geometry=geom.uuid,
           material=material.uuid,
           matrix=threejs_transform(p)))

threejs_object_y(type, geom, material, p=u0(world_cs)) =
(metadata=threejs_metadata(),
 geometries=[geom],
 materials=[material],
 object=(uuid=string(uuid1()),
         type=type,
         geometry=geom.uuid,
         material=material.uuid,
         matrix=threejs_transform_y(p)))
         
threejs_object_2D(type, geom, shapes, material) =
 (metadata=threejs_metadata(),
  shapes=shapes,
  geometries=[geom],
  materials=[material],
  object=(uuid=string(uuid1()),
          type=type,
          geometry=geom.uuid,
          material=material.uuid,
          matrix=(1, 0, 0, 0,
                  0, 0, 1, 0,
                  0, 1, 0, 0,
                  0, 0, 0, 1)))

threejs_object_shapes(type, geom, shapes, material, p=u0(world_cs)) =
 (metadata=threejs_metadata(),
  shapes=shapes,
  geometries=[geom],
  materials=[material],
  object=(uuid=string(uuid1()),
          type=type,
          geometry=geom.uuid,
          material=material.uuid,
          matrix=(translated_cs(p.cs, p.x, p.y, p.z).transform*[1 0 0 0; 0 0 1 0; 0 1 0 0; 0 0 0 1])[:])) # threejs_transform(p))) #(1, 0, 0, 0, 0, 1, 0, 0, 0, 0,-1, 0, 0, 0, 0, 1)))


threejs_buffer_geometry_attributes_position(vertices) =
  (itemSize=3,
   type="Float32Array",
   array=convert(Vector{Float32}, reduce(vcat, threejs_point.(vertices))))

threejs_line(vertices, material) =
  let geom = (uuid=string(uuid1()),
              type="BufferGeometry",
              data=(
                attributes=(
                  position=threejs_buffer_geometry_attributes_position(vertices),),))
    threejs_object("Line", geom, material)
  end

#=
Three.js uses 2D locations and 3D locations
=#

abstract type Meshcat2D end

convert(::Type{Meshcat2D}, p::Loc) = (cx(p),cy(p))
threejs_2d(p::Loc) = let z =  @assert(abs(cz(p)) < 1e-10); (cx(p),cy(p)) end
threejs_3d(p::Loc) = (cx(p),cy(p),cz(p))
threejs_line_curve_2d(v1::Loc, v2::Loc) =
  (type="LineCurve", v1=threejs_2d(v1), v2=threejs_2d(v2))
threejs_line_curve_3d(v1::Loc, v2::Loc) =
  (type="LineCurve3", v1=threejs_3d(v1), v2=threejs_3d(v2))

#=
Three.js provides a hierarchy of curves.
Curve - Abstract
2D curves:
  ArcCurve
  CubicBezierCurve
  EllipseCurve
  LineCurve
  QuadraticBezierCurve
  SplineCurve
3D curves:
  CatmullRomCurve3
  CubicBezierCurve3
  LineCurve3
  QuadraticBezierCurve3
Sequences:
  CurvePath - Abstract
    Path
      Shape
=#
abstract type MeshcatCurve end
abstract type MeshcatCurve2D <: MeshcatCurve end
abstract type MeshcatCurve3D <: MeshcatCurve end
abstract type MeshcatCurvePath <: MeshcatCurve end
abstract type MeshcatPath <: MeshcatCurvePath end
abstract type MeshcatShape <: MeshcatPath end

abstract type MeshcatCurves end

threejs_curve(path) = convert(MeshcatCurve, path)
convert(::Type{MeshcatCurve}, p::CircularPath) =
  (type="EllipseCurve",
   aX=cx(p.center), aY=cy(p.center),
   xRadius=p.radius, yRadius=p.radius,
   aStartAngle=0, aEndAngle=2π,
   aClockwise=false,
   aRotation=0)
convert(::Type{MeshcatCurve}, p::OpenPolygonalPath) =
  let ps = path_vertices(p)
    length(ps) == 2 ?
      threejs_line_curve_2d(ps[1], ps[2]) :
      convert(MeshcatPath, p)
  end

threejs_path(path) = convert(MeshcatPath, path)
convert(::Type{MeshcatPath}, path) =
  (type="Path",
   curves=threejs_curves(path),
   autoclose=false,
   currentPoint=(0,0))

threejs_curves(path) = convert(MeshcatCurves, path)
convert(::Type{MeshcatCurves}, path) =
  [threejs_curve(path)]
convert(::Type{MeshcatCurves}, vs::Locs) =
  [threejs_line_curve_2d(v1, v2)
   for (v1,v2) in zip(vs, circshift(vs, -1))]
convert(::Type{MeshcatCurves}, p::Union{RectangularPath, ClosedPolygonalPath}) =
  convert(MeshcatCurves, path_vertices(p))

threejs_shape(path) = convert(MeshcatShape, path)
convert(::Type{MeshcatShape}, p::Region) =
  (uuid=string(uuid1()),
   type="Shape",
   curves=threejs_curves(p.paths[1]),
   autoclose=false,
   currentPoint=(0,0),
   holes=threejs_path.(p.paths[2:end]))
convert(::Type{MeshcatShape}, p::Path) =
  (uuid=string(uuid1()),
   type="Shape",
   curves=threejs_curves(p),
   autoclose=false,
   currentPoint=(0,0),
   holes=[])

threejs_surface_2d(path, material, p=u0(world_cs)) =
  let shape = threejs_shape(path),
      geom = (uuid=string(uuid1()),
              type="ShapeGeometry",
              shapes=[shape.uuid],
              curveSegments=64)
    threejs_object_shapes("Mesh", geom, [shape], material, p)
  end

threejs_surface_polygon(vertices, material) =
  let n = length(vertices)
    n <= 4 ?
      threejs_mesh_index(vertices, n < 4 ? [(0,1,2)] : [(0,1,2),(2,3,0)], material) :
      let ps = in_world.(vertices),
          n = vertices_normal(ps),
          cs = cs_from_o_vz(ps[1], n),
          vs = [in_cs(v, cs) for v in vertices]
        threejs_surface_2d(closed_polygonal_path(vs), material, u0(cs))
      end
  end


threejs_circle_mesh(center, radius, start_angle, amplitude, material) =
  let geom = (uuid=string(uuid1()),
              type="CircleGeometry",
              radius=radius,
              segments=64,
              thetaStart=start_angle,
              thetaLength=amplitude),
      cs = cs_from_o_vz(center, vx(-1, center.cs))
    threejs_object("Mesh", geom, material, u0(cs))
  end

threejs_extrusion_z(profile, h, material, p=u0(world_cs)) =
  let shape = threejs_shape(profile),
      geom = (uuid=string(uuid1()),
              type="ExtrudeGeometry",
              shapes=[shape.uuid],
              options=(
                #steps=2,
                depth=-h,
                bevelEnabled=false,
                #bevelThickness=1,
                #bevelSize=1,
                #bevelOffset=0,
                #bevelSegments=1,
                #extrudePath=threejs_path(path),
                curveSegments=64
                ))
    threejs_object_shapes("Mesh", geom, [shape], material, p)
  end

threejs_faces(si, sj, closed_u, closed_v) =
  let idx(i,j) = (i-1)*sj+(j-1),
      idxs = [],
      quad(a,b,c,d) = (push!(idxs, (a, b, d)); push!(idxs, (d, b, c)))
    for i in 1:si-1
      for j in 1:sj-1
        quad(idx(i,j), idx(i+1,j), idx(i+1,j+1), idx(i,j+1))
      end
      if closed_v
        quad(idx(i,sj), idx(i+1,sj), idx(i+1,1), idx(i,1))
      end
    end
    if closed_u
      for j in 1:sj-1
        quad(idx(si,j), idx(1,j), idx(1,j+1), idx(si,j+1))
      end
      if closed_v
        quad(idx(si,sj), idx(1,sj), idx(1,1), idx(si,1))
      end
    end
    idxs
  end

=#

KhepriBase.b_set_view(b::THR, camera, target, lens, aperture) =
  @remote(b, setView(camera, target, lens, aperture))

KhepriBase.b_zoom_extents(b::THR) = 
  @remote(b, zoomExtents())
 
KhepriBase.b_delete_ref(b::THR, r::THRId) =
  @remote(b, delete(r))

KhepriBase.b_delete_all_refs(b::THR) =
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
KhepriBase.b_labels(b::THR, p, data, mat) =
  [@remote(b, addAnnotation(p+vpol(0.2*scale, ϕ), txt))
   for ((; txt, mat, scale), ϕ) in zip(data, division(-π/4, 7π/4, length(data), false))]

KhepriBase.b_start_batch_processing(b::THR) = @remote(b, stopUpdate())

KhepriBase.b_stop_batch_processing(b::THR) = @remote(b, startUpdate())

export gui_create, gui_add_folder, gui_add_button, add_gui_button, gui_add_slider, gui_add_dropdown, gui_add_checkbox

gui_create(name, kind=1) = 
  @remote(threejs, guiCreate(name, kind))

gui_add_folder(gui, name) = 
  @remote(threejs, guiAddFolder(gui, name))

gui_add_button(gui, name, handler) = 
  let request_str = "/api/"*randstring()
    register_handler(threejs, "GET", request_str, req -> (handler(); HTTP.Response(200, "0")))
    @remote(threejs, guiAddButton(gui, name, request_str))
  end

request_parameters(req) =
  HTTP.queryparams(HTTP.URI(HTTP.Messages.getfield(req, :target)))

gui_add_checkbox(gui, name, curr, handler) = 
  let request_str = "/api/"*randstring()
    register_handler(threejs, "GET", request_str, req -> (handler(request_parameters(req)); HTTP.Response(200, "0")))
    @remote(threejs, guiAddCheckbox(gui, name, request_str, curr))
  end

gui_add_slider(gui, name, min, max, step, curr, handler) = 
  let request_str = "/api/"*randstring()
    register_handler(threejs, "GET", request_str, req -> (handler(request_parameters(req)); HTTP.Response(200, "0")))
    @remote(threejs, guiAddSlider(gui, name, request_str, min, max, step, curr))
  end


gui_add_dropdown(gui, name, options, curr, handler) = 
  let request_str = "/api/"*randstring()
    register_handler(threejs, "GET", request_str, req -> (handler(request_parameters(req)); HTTP.Response(200, "0")))
    @remote(threejs, guiAddDropdown(gui, name, request_str, options, curr))
  end

export grid_helper, dark_grid_helper, light_grid_helper
grid_helper(size, divisions, color_line, color_grid) =
  @remote(threejs, gridHelper(size, divisions, color_line, color_grid))

dark_grid_helper() =
  grid_helper(1000, 1000, RGB(0.25, 0.25, 0.25), RGB(0.125, 0.125, 0.125))
light_grid_helper() =
  grid_helper(1000, 1000, RGB(0.75, 0.75, 0.75), RGB(0.875, 0.875, 0.875))
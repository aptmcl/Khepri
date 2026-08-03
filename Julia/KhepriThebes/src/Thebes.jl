# KhepriThebes - 3D visualization backend using Thebes.jl and Luxor.jl
#
# Thebes provides 3D→2D perspective projection
# Luxor provides 2D vector graphics rendering (PNG, SVG, PDF)

export thebes, TBS, ThebesBackend
export reset_thebes, preview_thebes, save_thebes

# ============================================================================
# Displayable File Types for VSCode Integration
# ============================================================================

# These types enable Julia/VSCode to display rendered images inline
export ThebesSVGFile, ThebesPNGFile, ThebesPDFFile

struct ThebesSVGFile
  path::String
end

struct ThebesPNGFile
  path::String
end

struct ThebesPDFFile
  path::String
end

# Display SVG directly in VSCode
Base.show(io::IO, ::MIME"image/svg+xml", f::ThebesSVGFile) =
  write(io, read(f.path))

# Display PNG directly in VSCode
Base.show(io::IO, ::MIME"image/png", f::ThebesPNGFile) =
  write(io, read(f.path))

# Display PDF as SVG in VSCode (requires pdftocairo)
Base.show(io::IO, ::MIME"application/pdf", f::ThebesPDFFile) =
  write(io, read(f.path))

# ============================================================================
# Backend Type Definitions
# ============================================================================

# ============================================================================
# Scene Storage for Retained Mode Rendering
# ============================================================================

# Scene items represent deferred drawing operations
abstract type SceneItem end

# Primitives (stroke only)
struct ScenePoint <: SceneItem
  p::Loc
  mat::Any
end

struct SceneLine <: SceneItem
  ps::Vector{Loc}
  mat::Any
end

struct ScenePolygon <: SceneItem
  ps::Vector{Loc}
  mat::Any
end

struct SceneSpline <: SceneItem
  ps::Vector{Loc}
  closed::Bool
  mat::Any
end

# Surfaces (filled)
struct SceneTrig <: SceneItem
  p1::Loc
  p2::Loc
  p3::Loc
  mat::Any
end

struct SceneQuad <: SceneItem
  p1::Loc
  p2::Loc
  p3::Loc
  p4::Loc
  mat::Any
end

struct SceneSurfacePolygon <: SceneItem
  ps::Vector{Loc}
  mat::Any
end

# 3D Objects (stored as Thebes.Object)
struct SceneObject <: SceneItem
  obj::Thebes.Object
  mat::Any
end

# Text
struct SceneText <: SceneItem
  str::String
  p::Loc
  size::Float64
  mat::Any
end

@defbackend Thebes TBS begin
  id_type = Int
  void_ref = 0
  view_type = FrontendView()
  drawing::Union{Nothing, Drawing} = nothing
  view::View = default_view()
  stroke_color::RGBA = rgba(0, 0, 0, 1)
  fill_color::RGBA = rgba(1, 1, 1, 1)
  background_color::RGBA = rgba(1, 1, 1, 1)
  edge_stroke_width::Float64 = 0.1
  edge_stroke_color::RGBA = rgba(1, 1, 1, 1)
  output_format::Symbol = :svg
  scene::Vector{SceneItem} = SceneItem[]
  next_id::Int = 1
  scene_dirty::Bool = false
end
const thebes = TBS()

function next_ref!(b::TBS)
  id = b.next_id
  b.next_id += 1
  id
end

# ============================================================================
# Material Support
# ============================================================================

# Extract color from a material reference
# The mat parameter can be:
# - Nothing -> use default color
# - RGBA -> use directly
# - RGB -> convert to RGBA
# - Any type with a base_color field (e.g., PbrMaterial) -> extract base_color
# - Other (e.g., Int void_ref) -> nothing (triggers fallback to fill_color)
function extract_color(mat)
  if isnothing(mat)
    nothing
  elseif mat isa RGBA
    mat
  elseif mat isa RGB
    RGBA(red(mat), green(mat), blue(mat), 1.0)
  elseif hasfield(typeof(mat), :base_color)
    # PbrMaterial and similar proxies have base_color
    mat.base_color
  else
    nothing
  end
end

# Apply color to Luxor
apply_luxor_color!(::Nothing) = nothing  # Keep current color

function apply_luxor_color!(color::RGBA)
  Luxor.setcolor(red(color), green(color), blue(color), alpha(color))
end

# Apply fill color from material, falling back to backend default
function apply_fill_color!(b::TBS, mat)
  color = extract_color(mat)
  if isnothing(color)
    apply_luxor_color!(b.fill_color)
  else
    apply_luxor_color!(color)
  end
end

# Apply stroke color from material, falling back to backend default
function apply_stroke_color!(b::TBS, mat)
  color = extract_color(mat)
  if isnothing(color)
    apply_luxor_color!(b.stroke_color)
  else
    apply_luxor_color!(color)
  end
end

# Material creation — Thebes represents materials as RGBA colors
KhepriBase.b_material(b::TBS, name, base_color, metallic, roughness, specular) =
  isnothing(base_color) ? nothing : extract_color(base_color)

KhepriBase.b_plastic_material(b::TBS, name, color, roughness) = extract_color(color)
KhepriBase.b_metal_material(b::TBS, name, color, roughness, ior) = extract_color(color)
KhepriBase.b_glass_material(b::TBS, name, color, roughness, ior) = extract_color(color)
KhepriBase.b_mirror_material(b::TBS, name, color) = extract_color(color)

# Default RGBA colors for predefined BIM material names.
# When a MaterialInLayer has no backend-specific spec, Thebes uses the layer
# name to pick a sensible color so that BIM elements are visible.
const thebes_default_material_colors = Dict{String, RGBA}(
  "Concrete" => rgba(0.65, 0.65, 0.65, 1.0),
  "Plaster"  => rgba(0.9, 0.85, 0.8, 1.0),
  "Glass"    => rgba(0.7, 0.85, 0.95, 0.5),
  "Metal"    => rgba(0.7, 0.7, 0.75, 1.0),
  "Wood"     => rgba(0.55, 0.35, 0.2, 1.0),
  "Grass"    => rgba(0.3, 0.55, 0.2, 1.0),
  "Clay"     => rgba(0.76, 0.5, 0.3, 1.0),
  "Points"   => rgba(0.0, 0.0, 0.0, 1.0),
  "Curves"   => rgba(0.0, 0.0, 0.0, 1.0),
  "Surfaces" => rgba(0.7, 0.7, 0.7, 1.0),
  "Basic"    => rgba(0.7, 0.7, 0.7, 1.0),
)
const thebes_default_material_color = rgba(0.7, 0.7, 0.7, 1.0)

# Override b_layer_material for Thebes: when a MaterialInLayer has no
# backend-specific data (spec is nothing), derive the color from the
# layer name.  This ensures BIM elements are visible without requiring
# explicit backend material configuration.
KhepriBase.b_layer_material(b::TBS, layer, spec) =
  if isnothing(spec)
    layer isa BasicLayer ?
      get(thebes_default_material_colors, layer.name, thebes_default_material_color) :
      thebes_default_material_color
  else
    b_get_material(b, spec)
  end


# ============================================================================
# Bounding Box Computation (On-Demand)
# ============================================================================

# Extend bbox arrays with a single point
function extend_bbox_point!(bbox_min, bbox_max, p::Loc)
  wp = in_world(p)
  bbox_min[1] = min(bbox_min[1], wp.x)
  bbox_min[2] = min(bbox_min[2], wp.y)
  bbox_min[3] = min(bbox_min[3], wp.z)
  bbox_max[1] = max(bbox_max[1], wp.x)
  bbox_max[2] = max(bbox_max[2], wp.y)
  bbox_max[3] = max(bbox_max[3], wp.z)
end

# Extend bbox with multiple points
function extend_bbox_points!(bbox_min, bbox_max, ps)
  for p in ps
    extend_bbox_point!(bbox_min, bbox_max, p)
  end
end

# Extend bbox with a Thebes Object's vertices
function extend_bbox_object!(bbox_min, bbox_max, obj::Thebes.Object)
  for v in obj.vertices
    bbox_min[1] = min(bbox_min[1], v.x)
    bbox_min[2] = min(bbox_min[2], v.y)
    bbox_min[3] = min(bbox_min[3], v.z)
    bbox_max[1] = max(bbox_max[1], v.x)
    bbox_max[2] = max(bbox_max[2], v.y)
    bbox_max[3] = max(bbox_max[3], v.z)
  end
end

# Compute bounding box for a single scene item
function extend_bbox_item!(bbox_min, bbox_max, item::ScenePoint)
  extend_bbox_point!(bbox_min, bbox_max, item.p)
end

function extend_bbox_item!(bbox_min, bbox_max, item::SceneLine)
  extend_bbox_points!(bbox_min, bbox_max, item.ps)
end

function extend_bbox_item!(bbox_min, bbox_max, item::ScenePolygon)
  extend_bbox_points!(bbox_min, bbox_max, item.ps)
end

function extend_bbox_item!(bbox_min, bbox_max, item::SceneSpline)
  extend_bbox_points!(bbox_min, bbox_max, item.ps)
end

function extend_bbox_item!(bbox_min, bbox_max, item::SceneTrig)
  extend_bbox_point!(bbox_min, bbox_max, item.p1)
  extend_bbox_point!(bbox_min, bbox_max, item.p2)
  extend_bbox_point!(bbox_min, bbox_max, item.p3)
end

function extend_bbox_item!(bbox_min, bbox_max, item::SceneQuad)
  extend_bbox_point!(bbox_min, bbox_max, item.p1)
  extend_bbox_point!(bbox_min, bbox_max, item.p2)
  extend_bbox_point!(bbox_min, bbox_max, item.p3)
  extend_bbox_point!(bbox_min, bbox_max, item.p4)
end

function extend_bbox_item!(bbox_min, bbox_max, item::SceneSurfacePolygon)
  extend_bbox_points!(bbox_min, bbox_max, item.ps)
end

function extend_bbox_item!(bbox_min, bbox_max, item::SceneObject)
  extend_bbox_object!(bbox_min, bbox_max, item.obj)
end

function extend_bbox_item!(bbox_min, bbox_max, item::SceneText)
  extend_bbox_point!(bbox_min, bbox_max, item.p)
end

# Compute bounding box from all scene items (on-demand)
function compute_scene_bbox(b::TBS)
  bbox_min = [Inf, Inf, Inf]
  bbox_max = [-Inf, -Inf, -Inf]
  for item in b.scene
    extend_bbox_item!(bbox_min, bbox_max, item)
  end
  (bbox_min, bbox_max)
end

# Check if computed bounding box is valid
bbox_valid(bbox_min, bbox_max) = all(isfinite, bbox_min) && all(isfinite, bbox_max)

# Get bounding box center from min/max
function bbox_center(bbox_min, bbox_max)
  xyz((bbox_min[1] + bbox_max[1]) / 2,
      (bbox_min[2] + bbox_max[2]) / 2,
      (bbox_min[3] + bbox_max[3]) / 2)
end

# Get bounding box diagonal size from min/max
function bbox_size(bbox_min, bbox_max)
  sqrt((bbox_max[1] - bbox_min[1])^2 +
       (bbox_max[2] - bbox_min[2])^2 +
       (bbox_max[3] - bbox_min[3])^2)
end

# ============================================================================
# Drawing Management
# ============================================================================

# Get file extension for output format
format_extension(fmt::Symbol) =
  fmt == :svg ? ".svg" :
  fmt == :pdf ? ".pdf" :
  fmt == :png ? ".png" :
  ".svg"  # default

# Infer format from file extension
extension_to_format(ext::String) =
  let e = lowercase(ext)
    e == ".svg" ? :svg :
    e == ".pdf" ? :pdf :
    e == ".png" ? :png :
    :svg  # default
  end

# Lazy initialization of Luxor Drawing
function ensure_drawing(b::TBS)
  if isnothing(b.drawing)
    w, h = render_size()
    ext = format_extension(b.output_format)
    temppath = tempname() * ext
    b.drawing = Drawing(w, h, temppath)
    Luxor.origin()
    # Apply background color
    bg = b.background_color
    Luxor.background(red(bg), green(bg), blue(bg))
    # Apply default stroke color
    apply_luxor_color!(b.stroke_color)
    # Set up Thebes camera from view
    update_thebes_camera(b)
  end
  b.drawing
end

# Set output format before drawing (must be called before creating shapes)
export set_thebes_format!
function set_thebes_format!(fmt::Symbol, b::TBS=thebes)
  if !isnothing(b.drawing)
    @warn "Drawing already started. Format change will take effect after reset_thebes()."
  end
  b.output_format = fmt
end
set_thebes_format!(path::String, b::TBS=thebes) =
  set_thebes_format!(extension_to_format(splitext(path)[2]), b)

# Set edge stroke for 3D objects (width=0 disables edges)
export set_thebes_edge_stroke!
function set_thebes_edge_stroke!(width::Real, b::TBS=thebes)
  b.edge_stroke_width = Float64(width)
end
function set_thebes_edge_stroke!(width::Real, color::RGBA, b::TBS=thebes)
  b.edge_stroke_width = Float64(width)
  b.edge_stroke_color = color
end

# Update Thebes camera from the view settings
# Maps Khepri's camera model (lens focal length) to Thebes' perspective parameter
function update_thebes_camera(b::TBS)
  cam = b.view.camera
  tgt = b.view.target
  lens = b.view.lens

  # Get world coordinates of camera and target
  cam_w = in_world(cam)
  tgt_w = in_world(tgt)

  # Compute up point for Thebes
  # Thebes defines "up" as the direction from eyepoint to uppoint
  # So uppoint = eyepoint + up_direction
  # If looking straight up/down (view direction ~parallel to Z), use X as up reference
  dir = tgt_w - cam_w
  up_dir = abs(dir.x) < 0.01 && abs(dir.y) < 0.01 ? vx(1) : vz(1)
  up_pt = cam_w + up_dir

  # Set eyepoint first, then uppoint, then centerpoint
  # Thebes validates that uppoint != centerpoint when setting either one,
  # so we must ensure uppoint is set to a valid value before setting centerpoint
  Thebes.eyepoint(cam_w.x, cam_w.y, cam_w.z)
  Thebes.uppoint(up_pt.x, up_pt.y, up_pt.z)
  Thebes.centerpoint(tgt_w.x, tgt_w.y, tgt_w.z)

  # Map Khepri's lens (focal length in mm) to Thebes' perspective parameter
  #
  # Khepri uses a 35mm full-frame camera model:
  #   - Sensor width = 36mm
  #   - tan(fov/2) = (sensor_half_width) / lens = 18 / lens
  #
  # Thebes projection formula:
  #   screen_coord = (perspective / r) * world_offset
  #   where r = distance along view direction
  #
  # For objects at the edge of the field of view:
  #   world_offset = r * tan(fov/2)
  #   screen_coord = half_screen_width (edge of screen)
  #
  # Therefore:
  #   half_screen_width = (perspective / r) * r * tan(fov/2)
  #   half_screen_width = perspective * tan(fov/2)
  #   perspective = half_screen_width / tan(fov/2)
  #   perspective = (screen_width / 2) / (18 / lens)
  #   perspective = screen_width * lens / 36
  #
  w, h = render_size()
  perspective_val = w * lens / 36.0

  Thebes.perspective(perspective_val)
end

# Reset the backend for a new drawing
function reset_thebes(b::TBS=thebes)
  if !isnothing(b.drawing)
    try
      Luxor.finish()
    catch
    end
  end
  b.drawing = nothing
  empty!(b.scene)
  b.next_id = 1
  b.scene_dirty = false
  b
end

KhepriBase.b_delete_ref(b::TBS, r::ThebesId) =
  b.scene_dirty = true

KhepriBase.b_delete_all_shape_refs(b::TBS) =
  begin
    reset_thebes(b)
    empty!(b.refs.shapes)
    nothing
  end

function rebuild_scene!(b::TBS)
  empty!(b.scene)
  b.next_id = 1
  b.scene_dirty = false
  let shapes = collect(keys(b.refs.shapes))
    empty!(b.refs.shapes)
    for s in shapes
      force_realize(b, s)
    end
  end
end

# Layer operations (no-op — Thebes does not support layers)
KhepriBase.b_layer(b::TBS, name, visible, color) = BasicLayer(name, visible, color)
KhepriBase.b_current_layer_ref(b::TBS) = nothing
KhepriBase.b_current_layer_ref(b::TBS, layer) = nothing
KhepriBase.b_delete_all_shapes_in_layer(b::TBS, layer) = nothing

# Zoom extents - adjust camera to fit all objects in view
KhepriBase.b_zoom_extents(b::TBS) =
  let (bbox_min, bbox_max) = compute_scene_bbox(b)
    if bbox_valid(bbox_min, bbox_max)
      let center = bbox_center(bbox_min, bbox_max),
          size = bbox_size(bbox_min, bbox_max),
          # Position camera at a 45° angle from the center, at a distance
          # proportional to the bounding box size (factor of 1.5 for margin)
          dist = max(size * 1.5, 10.0),
          camera = center + vxyz(dist * 0.6, dist * 0.6, dist * 0.5)
        b.view.camera = camera
        b.view.target = center
      end
    end
  end

# ============================================================================
# Coordinate Conversion
# ============================================================================

# Convert Khepri Loc to Thebes Point3D
to_pt3d(p::Loc) =
  let wp = in_world(p)
    Point3D(wp.x, wp.y, wp.z)
  end

# Convert multiple points
to_pt3ds(ps) = [to_pt3d(p) for p in ps]

# ============================================================================
# Camera Control
# ============================================================================

export set_thebes_camera

# Convenience function to set camera (uses standard set_view underneath)
function set_thebes_camera(b::TBS, camera::Loc, target::Loc)
  b.view.camera = camera
  b.view.target = target
  # If drawing exists, update Thebes camera
  if !isnothing(b.drawing)
    update_thebes_camera(b)
  end
end

# ============================================================================
# Primitive Drawing Operations (Retained Mode)
# ============================================================================

KhepriBase.b_point(b::TBS, p, mat) =
  (push!(b.scene, ScenePoint(p, mat)); next_ref!(b))

KhepriBase.b_line(b::TBS, ps, mat) =
  (push!(b.scene, SceneLine(collect(ps), mat)); next_ref!(b))

KhepriBase.b_polygon(b::TBS, ps, mat) =
  (push!(b.scene, ScenePolygon(collect(ps), mat)); next_ref!(b))

KhepriBase.b_spline(b::TBS, ps, v0, v1, mat) =
  (push!(b.scene, SceneSpline(collect(ps), false, mat)); next_ref!(b))

KhepriBase.b_closed_spline(b::TBS, ps, mat) =
  (push!(b.scene, SceneSpline(collect(ps), true, mat)); next_ref!(b))

KhepriBase.b_circle(b::TBS, c, r, mat) =
  let n = 64,
      pts = [c + vpol(r, i * 2π / n) for i in 0:n-1]
    push!(b.scene, ScenePolygon(pts, mat))
    next_ref!(b)
  end

KhepriBase.b_arc(b::TBS, c, r, α, Δα, mat) =
  let n = max(8, round(Int, abs(Δα) / (π/16))),
      pts = [c + vpol(r, α + i * Δα / n) for i in 0:n]
    push!(b.scene, SceneLine(pts, mat))
    next_ref!(b)
  end

KhepriBase.b_rectangle(b::TBS, c, dx, dy, mat) =
  let pts = [c, c + vx(dx), c + vxy(dx, dy), c + vy(dy)]
    push!(b.scene, ScenePolygon(pts, mat))
    next_ref!(b)
  end

# ============================================================================
# Surface Operations (Retained Mode - filled shapes)
# ============================================================================

KhepriBase.b_trig(b::TBS, p1, p2, p3, mat) =
  (push!(b.scene, SceneTrig(p1, p2, p3, mat)); next_ref!(b))

KhepriBase.b_quad(b::TBS, p1, p2, p3, p4, mat) =
  (push!(b.scene, SceneQuad(p1, p2, p3, p4, mat)); next_ref!(b))

KhepriBase.b_surface_polygon(b::TBS, ps, mat) =
  (push!(b.scene, SceneSurfacePolygon(collect(ps), mat)); next_ref!(b))

KhepriBase.b_surface_circle(b::TBS, c, r, mat) =
  let n = 64,
      pts = [c + vpol(r, i * 2π / n) for i in 0:n-1]
    push!(b.scene, SceneSurfacePolygon(pts, mat))
    next_ref!(b)
  end

KhepriBase.b_surface_arc(b::TBS, c, r, α, Δα, mat) =
  let n = max(8, round(Int, abs(Δα) / (π/16))),
      pts = [c, [c + vpol(r, α + i * Δα / n) for i in 0:n]...]
    push!(b.scene, SceneSurfacePolygon(pts, mat))
    next_ref!(b)
  end

# ============================================================================
# 3D Solid Operations (Retained Mode - using Thebes native objects)
# ============================================================================

# Transform a local point (x, y, z) through a location's coordinate system to world
# The location `loc` defines both position and orientation via its coordinate system
# Local Z-axis of `loc` typically points along the shape's axis (for cylinders, cones, etc.)
function local_to_world_pt3d(loc::Loc, x::Real, y::Real, z::Real)
  wp = in_world(loc + vxyz(x, y, z, loc.cs))
  Point3D(wp.x, wp.y, wp.z)
end

# Helper to create Thebes Object for a box
# Note: box uses corner position, orientation follows the coordinate system
function make_box_object(c, dx, dy, dz)
  # Box vertices in local coordinates (corner at origin, extends in +x, +y, +z)
  vertices = [
    local_to_world_pt3d(c, 0, 0, 0),
    local_to_world_pt3d(c, dx, 0, 0),
    local_to_world_pt3d(c, dx, dy, 0),
    local_to_world_pt3d(c, 0, dy, 0),
    local_to_world_pt3d(c, 0, 0, dz),
    local_to_world_pt3d(c, dx, 0, dz),
    local_to_world_pt3d(c, dx, dy, dz),
    local_to_world_pt3d(c, 0, dy, dz)
  ]
  faces = [
    [1, 4, 3, 2],  # bottom
    [5, 6, 7, 8],  # top
    [1, 2, 6, 5],  # front
    [2, 3, 7, 6],  # right
    [3, 4, 8, 7],  # back
    [4, 1, 5, 8]   # left
  ]
  Thebes.make((vertices, faces), "box")
end

# Helper to create Thebes Object for a sphere
# Sphere is centered at c, so orientation doesn't matter much
function make_sphere_object(c, r)
  n_lat = 16
  n_lon = 24

  vertices = Point3D[]
  push!(vertices, local_to_world_pt3d(c, 0, 0, -r))
  for i in 1:n_lat-1
    θ = π * i / n_lat
    z = -r * cos(θ)
    ring_r = r * sin(θ)
    for j in 0:n_lon-1
      φ = 2π * j / n_lon
      push!(vertices, local_to_world_pt3d(c, ring_r * cos(φ), ring_r * sin(φ), z))
    end
  end
  push!(vertices, local_to_world_pt3d(c, 0, 0, r))

  faces = Vector{Int}[]
  for j in 0:n_lon-1
    push!(faces, [1, 2 + ((j+1) % n_lon), 2 + j])
  end
  for i in 0:n_lat-3
    for j in 0:n_lon-1
      v1 = 2 + i * n_lon + j
      v2 = 2 + i * n_lon + ((j+1) % n_lon)
      v3 = 2 + (i+1) * n_lon + ((j+1) % n_lon)
      v4 = 2 + (i+1) * n_lon + j
      push!(faces, [v1, v2, v3, v4])
    end
  end
  north_pole = length(vertices)
  base = north_pole - n_lon
  for j in 0:n_lon-1
    push!(faces, [base + j, base + ((j+1) % n_lon), north_pole])
  end

  Thebes.make((vertices, faces), "sphere")
end

# Helper to create Thebes Object for a cylinder
# cb defines both position and orientation - local Z-axis is the cylinder axis
function make_cylinder_object(cb, r, h)
  n = 24
  vertices = Point3D[]
  # Bottom center
  push!(vertices, local_to_world_pt3d(cb, 0, 0, 0))
  # Bottom ring
  for i in 0:n-1
    θ = 2π * i / n
    push!(vertices, local_to_world_pt3d(cb, r * cos(θ), r * sin(θ), 0))
  end
  # Top center
  push!(vertices, local_to_world_pt3d(cb, 0, 0, h))
  # Top ring
  for i in 0:n-1
    θ = 2π * i / n
    push!(vertices, local_to_world_pt3d(cb, r * cos(θ), r * sin(θ), h))
  end

  faces = Vector{Int}[]
  # Bottom cap
  for i in 0:n-1
    push!(faces, [1, 2 + ((i+1) % n), 2 + i])
  end
  # Side faces
  top_center = n + 2
  for i in 0:n-1
    v1 = 2 + i
    v2 = 2 + ((i+1) % n)
    v3 = top_center + 1 + ((i+1) % n)
    v4 = top_center + 1 + i
    push!(faces, [v1, v2, v3, v4])
  end
  # Top cap
  for i in 0:n-1
    push!(faces, [top_center, top_center + 1 + i, top_center + 1 + ((i+1) % n)])
  end

  Thebes.make((vertices, faces), "cylinder")
end

# Helper to create Thebes Object for a cone
# cb defines both position and orientation - local Z-axis is the cone axis
function make_cone_object(cb, r, h)
  n = 24
  vertices = Point3D[]
  # Base center
  push!(vertices, local_to_world_pt3d(cb, 0, 0, 0))
  # Base ring
  for i in 0:n-1
    θ = 2π * i / n
    push!(vertices, local_to_world_pt3d(cb, r * cos(θ), r * sin(θ), 0))
  end
  # Apex
  push!(vertices, local_to_world_pt3d(cb, 0, 0, h))

  faces = Vector{Int}[]
  # Base cap
  for i in 0:n-1
    push!(faces, [1, 2 + ((i+1) % n), 2 + i])
  end
  # Side faces
  apex = n + 2
  for i in 0:n-1
    push!(faces, [2 + i, 2 + ((i+1) % n), apex])
  end

  Thebes.make((vertices, faces), "cone")
end

# Helper to create Thebes Object for a torus
# c defines both position and orientation - local Z-axis is the torus axis
function make_torus_object(c, re, ri)
  n_major = 24
  n_minor = 12

  vertices = Point3D[]
  for i in 0:n_major-1
    θ = 2π * i / n_major
    cx = re * cos(θ)
    cy = re * sin(θ)
    for j in 0:n_minor-1
      φ = 2π * j / n_minor
      x = cx + ri * cos(φ) * cos(θ)
      y = cy + ri * cos(φ) * sin(θ)
      z = ri * sin(φ)
      push!(vertices, local_to_world_pt3d(c, x, y, z))
    end
  end

  faces = Vector{Int}[]
  for i in 0:n_major-1
    for j in 0:n_minor-1
      v1 = i * n_minor + j + 1
      v2 = i * n_minor + ((j+1) % n_minor) + 1
      v3 = ((i+1) % n_major) * n_minor + ((j+1) % n_minor) + 1
      v4 = ((i+1) % n_major) * n_minor + j + 1
      # Reverse winding order for outward-facing normals
      push!(faces, [v1, v4, v3, v2])
    end
  end

  Thebes.make((vertices, faces), "torus")
end

# Helper to create Thebes Object for a cone frustum
# cb defines both position and orientation - local Z-axis is the frustum axis
function make_cone_frustum_object(cb, rb, h, rt)
  n = 24
  vertices = Point3D[]
  # Bottom center
  push!(vertices, local_to_world_pt3d(cb, 0, 0, 0))
  # Bottom ring
  for i in 0:n-1
    θ = 2π * i / n
    push!(vertices, local_to_world_pt3d(cb, rb * cos(θ), rb * sin(θ), 0))
  end
  # Top center
  push!(vertices, local_to_world_pt3d(cb, 0, 0, h))
  # Top ring
  for i in 0:n-1
    θ = 2π * i / n
    push!(vertices, local_to_world_pt3d(cb, rt * cos(θ), rt * sin(θ), h))
  end

  faces = Vector{Int}[]
  # Bottom cap
  for i in 0:n-1
    push!(faces, [1, 2 + ((i+1) % n), 2 + i])
  end
  # Side faces
  top_center = n + 2
  for i in 0:n-1
    v1 = 2 + i
    v2 = 2 + ((i+1) % n)
    v3 = top_center + 1 + ((i+1) % n)
    v4 = top_center + 1 + i
    push!(faces, [v1, v2, v3, v4])
  end
  # Top cap
  for i in 0:n-1
    push!(faces, [top_center, top_center + 1 + i, top_center + 1 + ((i+1) % n)])
  end

  Thebes.make((vertices, faces), "frustum")
end

# Helper to create Thebes Object for a pyramid frustum (two polygon bases)
function make_pyramid_frustum_object(bs, ts)
  n = length(bs)
  # Vertices: bottom polygon (1..n), then top polygon (n+1..2n)
  vertices = vcat([to_pt3d(p) for p in bs], [to_pt3d(p) for p in ts])

  faces = Vector{Int}[]
  # Bottom face (reverse order for outward normal pointing down)
  push!(faces, collect(n:-1:1))
  # Top face (normal order for outward normal pointing up)
  push!(faces, collect(n+1:2n))
  # Side faces (quads connecting bottom to top)
  for i in 1:n
    next_i = i % n + 1
    # Bottom vertices: i, next_i
    # Top vertices: n+i, n+next_i
    push!(faces, [i, next_i, n + next_i, n + i])
  end

  Thebes.make((vertices, faces), "pyramid_frustum")
end

# Helper to create Thebes Object for a pyramid
function make_pyramid_object(cbs, ct)
  vertices = [to_pt3d(p) for p in cbs]
  push!(vertices, to_pt3d(ct))

  n = length(cbs)
  apex_idx = n + 1

  faces = Vector{Int}[]
  # Base face (reverse order for outward normal pointing down)
  push!(faces, collect(n:-1:1))
  # Side faces
  for i in 1:n
    next_i = i % n + 1
    push!(faces, [i, next_i, apex_idx])
  end

  Thebes.make((vertices, faces), "pyramid")
end

# Box
KhepriBase.b_box(b::TBS, c, dx, dy, dz, mat) =
  (push!(b.scene, SceneObject(make_box_object(c, dx, dy, dz), mat)); next_ref!(b))

# Cuboid (8 corner points version)
function make_cuboid_object(pb0, pb1, pb2, pb3, pt0, pt1, pt2, pt3)
  vertices = [to_pt3d(pb0), to_pt3d(pb1), to_pt3d(pb2), to_pt3d(pb3),
              to_pt3d(pt0), to_pt3d(pt1), to_pt3d(pt2), to_pt3d(pt3)]
  # Vertices: 1=pb0, 2=pb1, 3=pb2, 4=pb3, 5=pt0, 6=pt1, 7=pt2, 8=pt3
  faces = [
    [1, 4, 3, 2],  # bottom (outward normal -Z)
    [5, 6, 7, 8],  # top (outward normal +Z)
    [1, 2, 6, 5],  # front
    [2, 3, 7, 6],  # right
    [3, 4, 8, 7],  # back
    [4, 1, 5, 8]   # left
  ]
  Thebes.make((vertices, faces), "cuboid")
end

KhepriBase.b_cuboid(b::TBS, pb0, pb1, pb2, pb3, pt0, pt1, pt2, pt3, mat) =
  (push!(b.scene, SceneObject(make_cuboid_object(pb0, pb1, pb2, pb3, pt0, pt1, pt2, pt3), mat)); next_ref!(b))

# Sphere
KhepriBase.b_sphere(b::TBS, c, r, mat) =
  (push!(b.scene, SceneObject(make_sphere_object(c, r), mat)); next_ref!(b))

# Cylinder
KhepriBase.b_cylinder(b::TBS, cb, r, h, mat) =
  (push!(b.scene, SceneObject(make_cylinder_object(cb, r, h), mat)); next_ref!(b))

# Cone
KhepriBase.b_cone(b::TBS, cb, r, h, mat) =
  (push!(b.scene, SceneObject(make_cone_object(cb, r, h), mat)); next_ref!(b))

# Torus
KhepriBase.b_torus(b::TBS, c, re, ri, mat) =
  (push!(b.scene, SceneObject(make_torus_object(c, re, ri), mat)); next_ref!(b))

# Frustum (truncated cone)
KhepriBase.b_cone_frustum(b::TBS, cb, rb, h, rt, mat) =
  (push!(b.scene, SceneObject(make_cone_frustum_object(cb, rb, h, rt), mat)); next_ref!(b))

# Pyramid - override both signatures to ensure make_pyramid_object is used
KhepriBase.b_pyramid(b::TBS, cbs, ct, mat) =
  (push!(b.scene, SceneObject(make_pyramid_object(cbs, ct), mat)); next_ref!(b))

# Override generic pyramid to use our optimized implementation with correct winding
KhepriBase.b_generic_pyramid(b::TBS, bs, t, smooth, bmat, smat) =
  (push!(b.scene, SceneObject(make_pyramid_object(bs, t), bmat)); next_ref!(b))

# Override generic pyramid frustum
KhepriBase.b_generic_pyramid_frustum(b::TBS, bs, ts, smooth, bmat, tmat, smat) =
  (push!(b.scene, SceneObject(make_pyramid_frustum_object(bs, ts), bmat)); next_ref!(b))

# ============================================================================
# Text (Retained Mode)
# ============================================================================

KhepriBase.b_text(b::TBS, str, p, size, mat) =
  (push!(b.scene, SceneText(str, p, Float64(size), mat)); next_ref!(b))

# ============================================================================
# Rendering (Retained Mode)
# ============================================================================

# Render a single scene item to the current Luxor drawing
function render_scene_item!(b::TBS, item::ScenePoint)
  pin(to_pt3d(item.p), gfunction=(p3, p2) -> begin
    Luxor.circle(p2, 2, :fill)
  end)
end

function render_scene_item!(b::TBS, item::SceneLine)
  pin(to_pt3ds(item.ps), gfunction=(p3s, p2s) -> begin
    Luxor.poly(p2s, :stroke, close=false)
  end)
end

function render_scene_item!(b::TBS, item::ScenePolygon)
  pin(to_pt3ds(item.ps), gfunction=(p3s, p2s) -> begin
    Luxor.poly(p2s, :stroke, close=true)
  end)
end

function render_scene_item!(b::TBS, item::SceneSpline)
  pin(to_pt3ds(item.ps), gfunction=(p3s, p2s) -> begin
    if length(p2s) >= 3
      Luxor.prettypoly(p2s, :stroke, close=item.closed)
    else
      Luxor.poly(p2s, :stroke, close=item.closed)
    end
  end)
end

function render_scene_item!(b::TBS, item::SceneTrig)
  pin(to_pt3ds([item.p1, item.p2, item.p3]), gfunction=(p3s, p2s) -> begin
    apply_fill_color!(b, item.mat)
    Luxor.poly(p2s, :fill, close=true)
  end)
end

function render_scene_item!(b::TBS, item::SceneQuad)
  pin(to_pt3ds([item.p1, item.p2, item.p3, item.p4]), gfunction=(p3s, p2s) -> begin
    apply_fill_color!(b, item.mat)
    Luxor.poly(p2s, :fill, close=true)
  end)
end

function render_scene_item!(b::TBS, item::SceneSurfacePolygon)
  pin(to_pt3ds(item.ps), gfunction=(p3s, p2s) -> begin
    apply_fill_color!(b, item.mat)
    Luxor.poly(p2s, :fill, close=true)
  end)
end

function render_scene_item!(b::TBS, item::SceneObject)
  # Use material color or default gray
  color = extract_color(item.mat)
  if isnothing(color)
    color = b.fill_color
  end
  # Custom colored rendering with shading
  Thebes.sortfaces!(item.obj)
  edge_width = b.edge_stroke_width
  edge_color = b.edge_stroke_color
  Luxor.@layer begin
    for face in item.obj.faces
      Luxor.@layer begin
        vertices = item.obj.vertices[face]
        sn = Thebes.surfacenormal(vertices)
        ang = Thebes.anglebetweenvectors(sn, Thebes.eyepoint())
        brightness = Luxor.rescale(ang, 0, π, 1, 0.3)
        Luxor.setcolor(
          red(color) * brightness,
          green(color) * brightness,
          blue(color) * brightness,
          alpha(color))
        Thebes.pin(vertices, gfunction=(p3, p2) -> begin
          Luxor.poly(p2, :fill)
          if edge_width > 0
            Luxor.setcolor(red(edge_color), green(edge_color), blue(edge_color), alpha(edge_color))
            Luxor.setline(edge_width)
            Luxor.poly(p2, :stroke, close=true)
          end
        end)
      end
    end
  end
end

function render_scene_item!(b::TBS, item::SceneText)
  pin(to_pt3d(item.p), gfunction=(p3, p2) -> begin
    Luxor.fontsize(item.size * 10)
    Luxor.text(item.str, p2)
  end)
end

# Render all scene items to a new Luxor drawing
function render_scene!(b::TBS)
  if b.scene_dirty
    rebuild_scene!(b)
  end

  if isempty(b.scene)
    @warn "No shapes to render. Create some shapes first."
    return false
  end

  # Compute scene bounding box for proper perspective scaling
  bbox_min, bbox_max = compute_scene_bbox(b)

  # Create new drawing
  w, h = render_size()
  ext = format_extension(b.output_format)
  temppath = tempname() * ext
  b.drawing = Drawing(w, h, temppath)
  Luxor.origin()

  # Apply background color
  bg = b.background_color
  Luxor.background(red(bg), green(bg), blue(bg))

  # Apply default stroke color
  apply_luxor_color!(b.stroke_color)

  # Set up Thebes camera from view settings (camera, target, lens)
  update_thebes_camera(b)

  # Render all scene items
  for item in b.scene
    render_scene_item!(b, item)
  end

  true
end

# Default to SVG for render output
KhepriBase.b_render_pathname(b::TBS, name::String) =
  path_replace_suffix(render_default_pathname(name), format_extension(b.output_format))

# Implement b_render_and_save_view to render scene and save
KhepriBase.b_render_and_save_view(b::TBS, path) =
  begin
    # Render scene to drawing
    if !render_scene!(b)
      return path
    end

    requested_fmt = extension_to_format(splitext(path)[2])
    current_fmt = extension_to_format(splitext(b.drawing.filename)[2])

    Luxor.finish()

    if requested_fmt != current_fmt
      @warn "Drawing was created as $(uppercase(string(current_fmt))). " *
            "Saving as $(uppercase(string(current_fmt))) instead of requested $(uppercase(string(requested_fmt))). " *
            "Use set_thebes_format!(:$requested_fmt) before creating shapes to change format."
      path = splitext(path)[1] * format_extension(current_fmt)
    end

    cp(b.drawing.filename, path, force=true)
    @info "Saved to: $path"
    b.drawing = nothing

    # Return a displayable file type for VSCode integration
    actual_fmt = extension_to_format(splitext(path)[2])
    actual_fmt == :svg ? ThebesSVGFile(path) :
    actual_fmt == :png ? ThebesPNGFile(path) :
    actual_fmt == :pdf ? ThebesPDFFile(path) :
    ThebesSVGFile(path)  # default
  end

# ============================================================================
# shot_view / raw_view
# ============================================================================

# raw_view: SVG output (Luxor's native vector format) — exact text comparison
KhepriBase.b_raw_pathname(b::TBS, name) =
  with(render_ext, ".svg") do
    render_default_pathname(name)
  end

KhepriBase.b_raw_view(b::TBS, path) =
  begin
    saved_format = b.output_format
    b.output_format = :svg
    try
      if !render_scene!(b)
        return path
      end
      Luxor.finish()
      cp(b.drawing.filename, path, force=true)
      b.drawing = nothing
    finally
      b.output_format = saved_format
    end
    path
  end

# shot_view: PNG output — default b_render_and_save_view already works

# ============================================================================
# Convenience Functions
# ============================================================================

# Preview the current scene
function preview_thebes(b::TBS=thebes)
  if render_scene!(b)
    Luxor.finish()
    Luxor.preview()
    b.drawing = nothing
  end
end

# Save the current scene to a file
# Format is inferred from the filename extension
# Returns a displayable file type for VSCode integration
function save_thebes(path::String, b::TBS=thebes)
  # Render scene to drawing
  if !render_scene!(b)
    return path
  end

  requested_fmt = extension_to_format(splitext(path)[2])
  current_fmt = extension_to_format(splitext(b.drawing.filename)[2])

  if requested_fmt != current_fmt
    @warn "Drawing was created as $(uppercase(string(current_fmt))). " *
          "Saving as $(uppercase(string(current_fmt))) instead of requested $(uppercase(string(requested_fmt))). " *
          "Use set_thebes_format!(:$requested_fmt) before creating shapes to change format."
    path = splitext(path)[1] * format_extension(current_fmt)
  end

  Luxor.finish()
  cp(b.drawing.filename, path, force=true)
  @info "Saved to: $path"
  b.drawing = nothing

  # Return a displayable file type for VSCode integration
  actual_fmt = extension_to_format(splitext(path)[2])
  actual_fmt == :svg ? ThebesSVGFile(path) :
  actual_fmt == :png ? ThebesPNGFile(path) :
  actual_fmt == :pdf ? ThebesPDFFile(path) :
  ThebesSVGFile(path)  # default
end

# [Geometry & Interop](@id geometry)

Beyond BIM elements, KhepriRevit supports pure geometry primitives, boolean
operations, views, rendering, and IFC interoperability.

## Geometry Primitives

KhepriRevit implements all standard Khepri geometry operations:

### Solid Primitives

```julia
# Box
box(corner_point, dx, dy, dz)

# Sphere
sphere(center, radius)

# Cylinder
cylinder(bottom_center, radius, height)

# Cone
cone(bottom_center, radius, height)

# Cone frustum (truncated cone)
cone_frustum(bottom_center, bottom_radius, height, top_radius)

# Pyramid frustum
pyramid_frustum(bottom_vertices, top_vertices)
```

All primitives use the local coordinate system for orientation. For example,
a cylinder's axis is `vz(1, cb.cs)` — the Z-axis of the bottom center's
coordinate system.

### Extruded Contours

```julia
extrude(path, direction)
```

Extruded contours support:
- Smooth and faceted contour outlines
- Holes (inner paths)
- Arbitrary extrusion vectors

The implementation uses `ExtrudedContour(contour_vertices, smooth_contour,
hole_vertices, smooth_holes, direction_vector)`.

### Surface Grids

```julia
surface_grid(points_matrix, closed_u, closed_v)
```

Creates a surface from a grid of points via
`SurfaceFromGrid(m, n, points, closed_m, closed_n, level)`.

## Boolean Operations

KhepriRevit declares `HasBooleanOps{true}`, which enables KhepriBase's implicit
boolean operation path. This means standard Khepri boolean operations work:

```julia
# Union
union(shape1, shape2)

# Intersection
intersection(shape1, shape2)

# Subtraction
subtraction(shape1, shape2)
```

The Revit plugin provides `Union`, `Intersection`, and `Subtraction` operations
that work on `ElementId` pairs.

!!! note
    The direct `unite_ref`/`intersect_ref`/`subtract_ref` methods are
    currently commented out in the source. Boolean operations work through
    KhepriBase's implicit boolean path via `HasBooleanOps{true}`.

## Views and Rendering

### Setting the View

```julia
set_view(camera_position, target_position, lens=50)
```

Realized via `SetView(camera, target, width, height, lens)` where `width` and
`height` come from `render_width()` and `render_height()`.

### Getting the Current View

```julia
get_view()
```

Returns `(camera, target, lens)` by querying `GetCamera()`, `GetTarget()`, and
`GetLens()` from Revit.

### Rendering

```julia
render_view("output_path")
```

Saves a rendered view to the specified path via `RenderView(path)`.

### Additional View Operations

```julia
# Zoom to fit all elements
zoom_extents(revit)

# Switch to top view
view_top(revit)
```

## IFC Interoperability

KhepriRevit provides three functions for IFC workflow:

### Converting IFC to RVT

```julia
convert_ifc_file(path)
```

Converts an IFC file to Revit's `.rvt` format using Revit's built-in IFC
importer.

### Loading an RVT File

```julia
load_rvt_file(path)
```

Opens a `.rvt` file in the current Revit session.

### Convert and Load

```julia
convert_and_load_ifc_file(path)
```

Convenience function that converts an IFC file to `.rvt` and then loads the
result. The `.rvt` file is created in the same directory as the IFC file with
the same base name.

## Querying Existing Documents

KhepriRevit can read elements from existing Revit documents:

```julia
# Get all levels
levels = all_levels(revit)

# Get all walls
walls = all_walls(revit)

# Get walls at a specific level
walls_at_level = all_walls_at_level(my_level, revit)

# Get all elements
elements = all_elements(revit)

# Get all floors
floors = all_floors(revit)
```

### Wall Reconstruction

`all_walls` reconstructs full Khepri `Wall` objects from Revit data:

1. Queries wall vertices via `LineWallVertices` → converts to a `Path`
2. Queries the bottom level via `ElementLevel` → creates a Khepri `Level`
3. Queries the top level via `WallTopLevel`:
   - If valid → creates a connected `Level`
   - If `-1` (void) → creates an unconnected level using the wall height from
     `WallHeight`

### Element Selection

```julia
# Highlight an element in Revit
highlight_element(element_id)

# Get currently selected elements
selected = get_selected_elements()
```

## Deleting Elements

```julia
delete_all_shapes()
```

Removes all elements from the Revit document via `DeleteAllElements()`.

## Known Limitations

- **Materials are not supported**: The Revit backend does not use Khepri's
  material system. The `material_ref` function is commented out. Elements use
  whatever material is defined in their Revit family type.

- **Spline paths are not supported**: Walls, curtain walls, slabs, and roofs
  can only use paths composed of lines and arcs. Spline paths throw an error.

- **`backend_add_door` is not implemented**: Doors must be specified as part of
  the wall's openings, not added after wall creation.

- **Some family parameters require `to_feet` conversion**: Whether a parameter
  needs conversion depends on how the specific Revit family defines its
  parameters. See the [Families](@ref families) page.

- **Table and chair families are commented out**: The `TableFamily`,
  `ChairFamily`, and `TableChairFamily` realizations exist in the source but
  are disabled.

- **Named geometry variants**: Some geometry operations have `Named` variants
  (e.g., `ConeFrustumNamed`, `PyramidFrustumNamed`, `ExtrudedContourNamed`)
  that accept a name parameter and material ID. These are available through the
  remote API but not all are exposed through standard Khepri operations.

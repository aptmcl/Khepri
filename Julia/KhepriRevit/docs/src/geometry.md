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

## OBJ Export from Family Files

KhepriRevit can extract the graphical representation (mesh geometry and
materials) from Revit family files (`.rfa`) and save them as standard
[Wavefront OBJ](https://en.wikipedia.org/wiki/Wavefront_.obj_file) files with
accompanying MTL material libraries.

This is useful for:
- Previewing family geometry in external tools (Blender, MeshLab, etc.)
- Using Revit family meshes in non-Revit rendering pipelines
- Archiving family geometry in an open, portable format

### Exporting a Single Family

```julia
export_family_to_obj(family_path, obj_path)
```

Opens the `.rfa` file, extracts all mesh geometry at Fine detail level, and
writes an OBJ file (with an accompanying `.mtl` file in the same directory).

- **`family_path`**: Absolute path to the `.rfa` file. Use
  [`revit_library_path`](@ref) to resolve library-relative paths.
- **`obj_path`**: Output path for the `.obj` file. The `.mtl` file is created
  alongside it with the same base name.

Vertex coordinates are converted from Revit's internal units (feet) to meters.
Each face in the OBJ is assigned a material group (`usemtl`) corresponding to
the Revit material applied to that face. The MTL file contains diffuse color
(`Kd`) and transparency (`d`) properties for each material.

```julia
# Export a sink family from the Metric Library
export_family_to_obj(
  revit_library_path("Metric Library",
    raw"Plumbing\Architectural\Fixtures\Sinks\M_Sink Vanity-Square.rfa"),
  raw"C:\Export\sink.obj")
# Produces: C:\Export\sink.obj and C:\Export\sink.mtl

# Export a custom family file
export_family_to_obj(
  raw"C:\MyFamilies\Custom-Column.rfa",
  raw"C:\Export\custom_column.obj")
```

### Exporting All Instantiated Families from a Model

```julia
export_all_families_to_obj(folder_path)
```

Iterates over all family instances in the currently loaded Revit document,
identifies the unique families that are actually used, and exports each one as
an OBJ + MTL pair into the specified folder.

- **`folder_path`**: Path to the output directory. Created automatically if it
  does not exist.

The output files are named after the Revit family name (with spaces and
path-separator characters replaced by underscores). Each unique family is
exported only once, regardless of how many instances exist in the model.

!!! note
    Only **loadable families** (those backed by `.rfa` files) that appear as
    `FamilyInstance` elements are exported. **System families** (walls, floors,
    roofs, ceilings) are not included, as they do not have standalone `.rfa`
    geometry definitions.

```julia
# Load a Revit model
load_rvt_file(raw"C:\Projects\Building.rvt")

# Export all instantiated families to a folder
export_all_families_to_obj(raw"C:\Export\families")
# Produces files like:
#   C:\Export\families\M_Concrete-Rectangular-Column.obj
#   C:\Export\families\M_Concrete-Rectangular-Column.mtl
#   C:\Export\families\M_Instance-Window-Fixed.obj
#   C:\Export\families\M_Instance-Window-Fixed.mtl
#   C:\Export\families\M_Sink_Vanity-Square.obj
#   C:\Export\families\M_Sink_Vanity-Square.mtl
#   ...
```

### OBJ Format Details

The exported files follow the standard Wavefront OBJ/MTL specification:

- **Vertices** (`v`): Coordinates in meters (converted from Revit's internal
  feet).
- **Normals** (`vn`): Per-triangle face normals, computed from cross products.
- **Faces** (`f`): Triangulated; each face references vertex and normal indices
  in the format `v//vn`.
- **Material groups** (`usemtl`): Faces are grouped by their Revit material.
  Faces with no assigned material use a `default` material (light gray).
- **MTL properties**: Diffuse color (`Kd`) from the Revit material's `Color`,
  and dissolve/transparency (`d`) from the material's `Transparency` property.
  Illumination model is set to `illum 2` (diffuse + specular).

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

# Get all walls (including doors and windows)
walls = all_walls(revit)

# Get walls at a specific level
walls_at_level = all_walls_at_level(my_level, revit)

# Get all elements
elements = all_elements(revit)

# Get all floors, columns, beams, ceilings
floors = all_floors(revit)
columns = all_columns(revit)
beams = all_beams(revit)
ceilings = all_ceilings(revit)

# Get all doors and windows (as HostedElementInfo with host wall ID)
doors = all_doors(revit)
windows = all_windows(revit)
```

For full model introspection and code generation from an existing Revit
document, see [Code Generation](@ref codegen).

### Wall Reconstruction

`all_walls` reconstructs full Khepri `Wall` objects from Revit data:

1. Queries wall geometry — supports three path types:
   - **Line walls** via `LineWallVertices` → `OpenPolygonalPath`
   - **Arc walls** via `ArcWallCenter`/`ArcWallRadius`/`ArcWallAngles` →
     `ArcPath` (center, radius, start/end angles in local coordinate system)
   - **Curtain walls** are detected via `WallIsCurtainWall` and created as
     `CurtainWall` shapes
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

- **Doors and windows**: Doors and windows can be added to walls as
  part of the wall's openings (via `wall_with_openings`). The `loc`
  parameter uses wall-relative coordinates: `loc.x` is the distance along
  the wall, `loc.y` is the sill height.

- **Some family parameters require `to_feet` conversion**: Whether a parameter
  needs conversion depends on how the specific Revit family defines its
  parameters. See the [Families](@ref families) page.

- **Named geometry variants**: Some geometry operations have `Named` variants
  (e.g., `ConeFrustumNamed`, `PyramidFrustumNamed`, `ExtrudedContourNamed`)
  that accept a name parameter and material ID. These are available through the
  remote API but not all are exposed through standard Khepri operations.

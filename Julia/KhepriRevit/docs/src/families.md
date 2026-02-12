# [Families](@id families)

The family system is the most important part of using KhepriRevit effectively.
Revit organizes all building elements into **families** — parametric templates
that define an element's geometry, behavior, and available parameters. Khepri
bridges this concept through `set_backend_family`, which maps Khepri's
backend-agnostic families to Revit-specific family configurations.

## Family Types Overview

Revit has three family types, each represented by a Khepri struct:

| Type | Struct | Use Case | Revit Concept |
|------|--------|----------|---------------|
| System Family | [`RevitSystemFamily`](@ref) | Built-in types: walls, slabs, roofs, floors, ceilings, pipes | Types defined by Revit itself — not loadable from files |
| File Family | [`RevitFileFamily`](@ref) | Loadable `.rfa` files: columns, beams, windows, doors, furniture, fixtures | Loadable families — `.rfa` files from Revit's library or custom-created |
| In-Place Family | [`RevitInPlaceFamily`](@ref) | Unique project-specific elements | Reserved for future use — not yet implemented |

## RevitSystemFamily

```julia
revit_system_family(family_map=(), instance_map=(), location_transform=(f, p)->p)
```

System families are Revit's built-in types. They cannot be loaded from external
files — they are part of the Revit project template. Walls, slabs, roofs,
ceilings, and railings are all system families.

### Parameters

- **`family_map`**: Pairs of `"RevitParamName" => f -> expression` that extract
  values from the Khepri family `f` to set Revit **family type** parameters.
  These define the type variant (e.g., wall thickness).

- **`instance_map`**: Same format, but for **instance** parameters — values set
  per-placement rather than per-type.

- **`location_transform`**: A function `(family, position) -> adjusted_position`
  that adjusts the placement coordinates. Used when Revit's insertion point
  convention differs from Khepri's (e.g., doors insert at center but Khepri
  specifies the edge).

### How It Works

When a shape using a system family is realized:

1. `family_ref(b, family)` calls `backend_get_family_ref(b, family, rvtf)`
2. If the family type hasn't been resolved yet, the `family_map` parameters are
   collected and sent to Revit via `FamilyElement(0, param_names, param_values)`
   — the `0` signals a system family lookup
3. Revit returns an `ElementId` for the resolved family type
4. The result is cached in `rvtf.instance_ref` for reuse

### Example

The default door family shifts the insertion point by half the door width,
because Revit expects doors positioned at their center:

```julia
set_backend_family(
  default_door_family(),
  revit,
  revit_system_family(
    [],   # no family_map
    [],   # no instance_map
    (f, p) -> p + vx(f.width/2, p.cs)))  # shift by half width
```

## RevitFileFamily

```julia
revit_file_family(path, family_map=(), instance_map=(), location_transform=(f, p)->p)
```

File families are loaded from `.rfa` files — Revit's loadable family format.
Columns, beams, windows, doors, furniture, and plumbing fixtures typically use
file families.

### Parameters

- **`path`**: Absolute path to the `.rfa` file. Use [`revit_library_path`](@ref)
  to resolve paths relative to Revit's installed library.

- **`family_map`**: Maps Revit **type parameter** names to functions that extract
  values from the Khepri family. These define the parametric dimensions of the
  family type (e.g., column width `"b"` and height `"h"`).

- **`instance_map`**: Maps Revit **instance parameter** names. Used when
  parameters are set per-placement (e.g., window `"Width"` and `"Height"`).

- **`location_transform`**: Adjusts placement coordinates, same as for system
  families.

### Resolution Pipeline

When a shape using a file family is realized:

1. `family_ref(b, family)` calls `backend_get_family_ref(b, family, rvtf)`
2. The `.rfa` file is loaded via `LoadFamily(rvtf.path)` — Revit returns the
   family's `ElementId`
3. A specific **family type** is created via
   `FamilyElement(family_ref, param_names, param_values)` using the `family_map`
   parameter mappings
4. Revit creates (or finds) a type with those parameter values and returns its
   `ElementId`

!!! note
    The family is re-loaded on every realization (the caching checks are
    currently bypassed with `if true`). This ensures parameter changes are
    always picked up, but may have a small performance cost.

### Example

The default column family loads a concrete rectangular column and maps Khepri's
profile dimensions to Revit's `"b"` (width) and `"h"` (height) parameters:

```julia
set_backend_family(
  default_column_family(),
  revit,
  revit_file_family(
    revit_library_path("Metric Library",
      raw"Structural Columns\Concrete\M_Concrete-Rectangular-Column.rfa"),
    ["b" => f -> f.profile.dx, "h" => f -> f.profile.dy]))
```

## Library Path Resolution

```julia
revit_library_path(root, path)
```

Resolves a path relative to Revit's installed content library. The `root`
argument specifies which library branch to use.

### Arguments

- **`root`**: The library root — typically `"Metric Library"` or
  `"Imperial Library"`.
- **`path`**: The relative path within that library to the `.rfa` file.

### Usage

```julia
# Metric column
revit_library_path("Metric Library",
  raw"Structural Columns\Concrete\M_Concrete-Rectangular-Column.rfa")

# Metric window
revit_library_path("Metric Library",
  raw"Windows\M_Instance-Window-Fixed.rfa")

# Imperial beam
revit_library_path("Imperial Library",
  raw"Structural Framing\Wood\Lumber.rfa")
```

!!! warning "Use raw strings for Windows paths"
    Always use `raw"..."` for the path argument to avoid backslash escaping
    issues. Without `raw`, `\M` or `\S` would be interpreted as escape
    sequences.

The function calls `InstalledLibraryPath(root)` on the connected Revit instance
to get the actual library base path, then joins it with the relative path. This
means paths adapt automatically to different Revit installations and versions.

## [Default Family Mappings](@id default-families)

These mappings are registered automatically in `after_connecting` when the Revit
backend is activated. They define how standard Khepri families map to Revit
families.

### System Families (No `.rfa` File)

| Khepri Family | Notes |
|---------------|-------|
| `default_wall_family()` | Default wall type from the project template |
| `default_curtain_wall_family()` | Default curtain wall type |
| `default_slab_family()` | Default floor type |
| `default_panel_family()` | Default panel type |
| `default_ceiling_family()` | Default ceiling type |
| `default_railing_family()` | Default railing type |
| `default_ramp_family()` | Default ramp type |
| `default_stair_family()` | Default stair type |
| `default_stair_landing_family()` | Default stair landing type |
| `default_door_family()` | Default door; `location_transform` shifts by `f.width/2` |

### File Families (Loadable `.rfa`)

| Khepri Family | `.rfa` Path | Parameter Mapping |
|---------------|-------------|-------------------|
| `default_window_family()` | `Windows\M_Instance-Window-Fixed.rfa` | `instance_map`: `"Width" => f->f.width*to_feet`, `"Height" => f->f.height*to_feet`; `location_transform`: shift by `f.width/2` |
| `default_column_family()` | `Structural Columns\Concrete\M_Concrete-Rectangular-Column.rfa` | `family_map`: `"b" => f->f.profile.dx`, `"h" => f->f.profile.dy` |
| `default_beam_family()` | `Structural Framing\Wood\M_Timber.rfa` | `family_map`: `"b" => f->f.profile.dx`, `"d" => f->f.profile.dy` |
| `default_truss_bar_family()` | `Structural Framing\Steel\M_W-Wide Flange.rfa` | none |
| `default_truss_node_family()` | `Structural Framing\Steel\M_W-Wide Flange.rfa` | none |
| `default_toilet_family()` | `Plumbing\Architectural\Fixtures\Water Closets\M_Toilet-Domestic-3D.rfa` | `location_transform`: rotate 90° + shift Y by -0.12 |
| `default_closet_family()` | `Furniture\Storage\M_Shelving.rfa` | none |
| `default_sink_family()` | `Plumbing\Architectural\Fixtures\Sinks\M_Sink Vanity-Square.rfa` | `location_transform`: rotate 90° |

All file family paths are relative to the `"Metric Library"` root and are
resolved via [`revit_library_path`](@ref).

## Unit Conversion: `to_feet`

The constant `to_feet ≈ 3.28084` converts meters to feet. Most Revit plugin
operations accept SI values directly (the plugin handles conversion internally),
but **some family parameters require explicit conversion**.

The key distinction:
- **`family_map` parameters** typically use Revit's internal parameter units
  (meters for structural families like columns and beams) — no conversion needed
- **`instance_map` parameters** for windows use Revit's display units (feet) —
  multiply by `to_feet`

```julia
# Column family_map: values in meters (no conversion)
"b" => f -> f.profile.dx
"h" => f -> f.profile.dy

# Window instance_map: values in feet (explicit conversion)
"Width"  => f -> f.width * to_feet
"Height" => f -> f.height * to_feet
```

!!! tip
    If a family parameter produces elements with incorrect dimensions, try
    toggling the `to_feet` conversion. The need for conversion depends on how
    the specific Revit family defines its parameters.

## Customization Examples

### Changing the Default Column to a Steel I-Beam

```julia
set_backend_family(
  default_column_family(),
  revit,
  revit_file_family(
    revit_library_path("Metric Library",
      raw"Structural Columns\Steel\M_W-Wide Flange-Column.rfa"),
    ["bf" => f -> f.profile.dx, "d" => f -> f.profile.dy]))
```

Here `"bf"` (flange width) and `"d"` (depth) are the Revit parameter names for
the W-shape family. You need to check the `.rfa` file's parameter names in
Revit's Family Editor to find the correct names.

### Using a Custom `.rfa` File for Windows

```julia
set_backend_family(
  default_window_family(),
  revit,
  revit_file_family(
    raw"C:\MyFamilies\Custom-Casement-Window.rfa",
    [],  # no family_map (type params)
    ["Width" => f -> f.width * to_feet, "Height" => f -> f.height * to_feet],
    (f, p) -> p + vx(f.width/2, p.cs)))
```

Custom `.rfa` files use an absolute path instead of `revit_library_path`.

### Mapping Additional Parameters

To add flange width mapping to a beam family:

```julia
set_backend_family(
  default_beam_family(),
  revit,
  revit_file_family(
    revit_library_path("Metric Library",
      raw"Structural Framing\Steel\M_W-Wide Flange.rfa"),
    ["bf" => f -> f.profile.dx,    # flange width
     "d"  => f -> f.profile.dy,    # depth
     "tf" => f -> 0.015,           # flange thickness (fixed)
     "tw" => f -> 0.010]))         # web thickness (fixed)
```

### Creating a Per-Element Family Override

You can override the family for individual elements:

```julia
# Define a specific column family
steel_col = column_family(profile=rectangular_profile(0.3, 0.3))
set_backend_family(steel_col, revit, revit_file_family(
  revit_library_path("Metric Library",
    raw"Structural Columns\Steel\M_W-Wide Flange-Column.rfa"),
  ["bf" => f -> f.profile.dx, "d" => f -> f.profile.dy]))

# Use it for specific columns
column(xy(0, 0), family=steel_col)
column(xy(5, 0), family=steel_col)

# Other columns still use the default
column(xy(10, 0))  # uses default_column_family()
```

## Finding Revit Parameter Names

To customize family mappings, you need to know the Revit parameter names for
your `.rfa` file. There are several ways to find them:

1. **Revit Family Editor**: Open the `.rfa` file → Family Types dialog → lists
   all parameters with their names
2. **Revit Properties Panel**: Place an instance → select it → the Properties
   panel shows instance and type parameters
3. **Revit API**: Use `Element.Parameters` to enumerate programmatically

The parameter names used in `family_map` and `instance_map` must match exactly
(case-sensitive) the names shown in Revit.

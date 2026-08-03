# [Code Generation](@id codegen)

KhepriRevit can introspect an existing Revit model and generate a portable
Khepri Julia script that recreates it. This is useful for capturing existing
Revit designs as parametric Khepri programs.

## Quick Start

```julia
using KhepriRevit

# Connect to Revit (must be running with the Khepri plugin loaded)
# Then generate code from the current document:
generate_khepri_code("my_building.jl")
```

This produces a `.jl` file containing levels, families, backend mappings,
element calls (walls, floors, columns, beams, ceilings), and model groups
that reproduce the Revit model.

### Sample Output

```julia
# Auto-generated Khepri code from Revit model
# Generated on: 2026-03-08T14:30:00
using KhepriRevit

level_0 = level(0.0)
level_1 = level(3.5)

wall_basic_wall_generic_200mm = wall_family()
set_backend_family(wall_basic_wall_generic_200mm, revit, revit_system_family())

column_m_round_column_450mm = column_family()
set_backend_family(column_m_round_column_450mm, revit,
  revit_file_family(raw"C:\ProgramData\...\M_Round Column.rfa"))

wall(xy(0.0, 0.0), xy(10.0, 0.0),
  level=level_0, top_level=level_1,
  family=wall_basic_wall_generic_200mm)

for x in 0.0:5.0:10.0
  for y in 0.0:5.0:10.0
    column(xyz(x, y, 0.0), level=level_0, top_level=level_1,
      family=column_m_round_column_450mm)
  end
end
```

## Pipeline Architecture

The pipeline has five phases, each a pure function:

1. **Introspect** (`introspect_model`) — queries Revit for all elements and
   their family metadata, returns a NamedTuple of Khepri shapes
2. **Meta-program** (`model_to_expr`) — converts each shape to a Julia `Expr`
   AST node via `meta_program`
3. **Transform** — a sequence of `Expr → Expr` passes that clean up and
   compress the raw AST
4. **Print** (`expr_to_string`) — pretty-prints the final `Expr` to Julia
   source code with section-aware formatting
5. **Write** — saves the string to a file

`generate_khepri_code` orchestrates all phases:

```julia
function generate_khepri_code(output_path; b=revit)
  model = introspect_model(b=b)
  raw_expr = model_to_expr(model)
  passes = [extract_levels,
            extract_families,
            add_backend_families(model),
            loop_rerolling,
            detect_level_repetition,
            add_header]
  refined_expr = foldl((e, pass) -> pass(e), passes, init=raw_expr)
  code = expr_to_string(refined_expr)
  write(output_path, code)
end
```

The pipeline design was inspired by the multi-pass code generation approach
described in Tomás Grelha da Cunha's thesis on Khepri model introspection.

## Using Individual Pipeline Stages

Each stage can be called independently for inspection or debugging.

### Phase 1: Introspection

```julia
model = introspect_model(b=revit)
```

Returns a NamedTuple with fields:

| Field      | Element type      | Revit queries used                      |
|:-----------|:------------------|:----------------------------------------|
| `levels`   | `Level`           | `DocLevels`                             |
| `walls`    | `Wall`            | `DocWalls`, `DocDoors`, `DocWindows`    |
| `floors`   | `Slab`            | `DocFloors`, `FloorBoundaryVertices`    |
| `columns`  | `Column`          | `DocColumns`, `ColumnLocation`          |
| `beams`    | `Beam`            | `DocBeams`, `BeamLocation`              |
| `ceilings` | `Ceiling`         | `DocCeilings`, `CeilingBoundaryVertices`|
| `groups`   | `NamedTuple`      | `DocGroups`, `GroupMemberIds`, `GroupLocation`|

Walls include any hosted doors and windows, attached as `w.doors` and
`w.windows`. Family metadata (name, type, system vs. file, path) is
collected per element and stored in a side-channel for use by later passes.

Elements that belong to Revit model groups are excluded from the individual
element queries (walls, floors, etc.) and instead introspected as part of
their group. The `groups` field contains a list of group types, each with
its member shapes and instance locations.

### Phase 2: Model to Expr

```julia
raw_expr = model_to_expr(model)
```

Iterates over all shapes in the model and calls `meta_program` on each,
producing Julia AST nodes. For example, a wall becomes:

```julia
:(wall(xy(0.0, 0.0), xy(10.0, 0.0), level=level(0.0), top_level=level(3.5),
       family=wall_family()))
```

Walls with doors or windows produce `wall_with_openings(...)` calls instead.
Family expressions are registered in a side-channel (`_family_expr_meta`)
so that later passes can map them to Revit-specific families.

### Phase 3: Transform Passes

Each pass is an `Expr → Expr` function applied in sequence via `foldl`:

- **`extract_levels`** — finds all `level(h)` calls, deduplicates by height,
  and replaces them with named variables (`level_0`, `level_1`, ...) sorted
  by height.

- **`extract_families`** — finds all `*_family()` calls, deduplicates them,
  and extracts them into named variables using Revit metadata for descriptive
  names (e.g., `wall_basic_wall_generic_200mm`).

- **`add_backend_families(model)`** — inserts `set_backend_family` calls after
  each family assignment, mapping the Khepri family to its Revit-specific
  counterpart (`revit_system_family()` or `revit_file_family(path)`).

- **`loop_rerolling`** — detects repeated shape calls that form 1D or 2D grid
  patterns and compresses them into `for` loops with range expressions.

- **`detect_level_repetition`** — (planned) detects identical floor plans
  repeated across levels and compresses them into a level loop. Currently a
  no-op.

- **`add_header`** — prepends a `using KhepriRevit` statement and date
  comments.

### Phase 4: Pretty-Printing

```julia
code = expr_to_string(refined_expr)
```

Produces formatted Julia source code with:
- 2-space indentation
- 80-character line wrapping (long calls break across lines)
- Blank lines between sections (header, levels, families, elements)

## Transform Passes in Detail

### Loop Rerolling

The loop rerolling pass detects sequences of 4+ structurally similar shape
calls where only leaf values (numbers, coordinates) vary, and converts them
into `for` loops.

**1D example** — 5 columns along a line:

Before:
```julia
column(xyz(0.0, 0.0, 0.0), ...)
column(xyz(3.0, 0.0, 0.0), ...)
column(xyz(6.0, 0.0, 0.0), ...)
column(xyz(9.0, 0.0, 0.0), ...)
column(xyz(12.0, 0.0, 0.0), ...)
```

After:
```julia
for x in 0.0:3.0:12.0
  column(xyz(x, 0.0, 0.0), ...)
end
```

**2D example** — 9 columns in a 3×3 grid:

Before:
```julia
column(xyz(0.0, 0.0, 0.0), ...)
column(xyz(0.0, 5.0, 0.0), ...)
column(xyz(0.0, 10.0, 0.0), ...)
column(xyz(5.0, 0.0, 0.0), ...)
column(xyz(5.0, 5.0, 0.0), ...)
column(xyz(5.0, 10.0, 0.0), ...)
column(xyz(10.0, 0.0, 0.0), ...)
column(xyz(10.0, 5.0, 0.0), ...)
column(xyz(10.0, 10.0, 0.0), ...)
```

After:
```julia
for x in 0.0:5.0:10.0
  for y in 0.0:5.0:10.0
    column(xyz(x, y, 0.0), ...)
  end
end
```

The algorithm:
1. Groups consecutive calls with the same function name and argument count
2. Uses `expr_diff` to find which AST positions vary between calls
3. For 1 varying position → tries 1D range; for 2 → tries 2D nested grid
4. Values must form an arithmetic progression (uniform spacing) to become a
   range expression; otherwise they become an explicit vector `[v1, v2, ...]`

### Level and Family Extraction

**Level extraction** finds every `level(height)` expression in the AST,
collects unique heights, sorts them, and assigns variables `level_0`,
`level_1`, etc. All occurrences are then replaced by the variable name.

**Family extraction** does the same for `*_family()` calls. Variable names
are derived from Revit metadata collected during introspection:

```
category_familyName_typeName
```

For example, `wall_family()` from a "Basic Wall : Generic - 200mm" element
becomes `wall_basic_wall_generic_200mm`.

**Backend family mapping** inserts a `set_backend_family` call immediately
after each family assignment. System families (built into Revit) use
`revit_system_family()`; file-based families use
`revit_file_family(raw"path")`.

## Generated Code Structure

The output file has five sections, separated by blank lines:

1. **Header** — comment lines and `using KhepriRevit`
2. **Levels** — `level_N = level(height)` assignments, sorted by height
3. **Families** — `fam_var = *_family()` assignments, each followed by its
   `set_backend_family` call
4. **Elements** — shape calls (`wall`, `slab`, `column`, `beam`, `ceiling`,
   `wall_with_openings`) and `for` loops from rerolling
5. **Groups** — factory function definitions, `group()` assignments, and
   `group_instance()` placements

## AST Utilities

The pipeline provides general-purpose `Expr` manipulation functions:

- `map_expr(f, e)` — bottom-up map over an Expr tree; applies `f` to every
  node after recursing into children
- `collect_exprs(pred, e)` — collect all sub-expressions matching a predicate
- `expr_diff(e1, e2)` — structural comparison returning a list of
  `(path, val1, val2)` triples where `path` is a vector of arg indices
- `expr_replace_at(e, path, val)` — replace the value at a given path in an
  Expr tree

## Extending the Pipeline

To add a new transform pass:

1. Define a function `my_pass(e::Expr) :: Expr`
2. Add it to the `passes` list in `generate_khepri_code` at the desired
   position

To add support for a new element type (e.g., ramps):

1. Implement `all_ramps(b)` to query Revit
2. Add `meta_program` methods for the new shape type (in KhepriBase or locally)
3. Add the new shapes to `introspect_model` and `model_to_expr`
4. Update `extract_families` if the element has a family

## Model Groups

Revit model groups (repeated collections of elements placed at multiple
locations) are mapped to Khepri's `group`/`group_instance` abstraction.

### How Groups Are Introspected

1. All Revit `Group` elements are queried via `DocGroups`
2. Member element IDs are collected via `GroupMemberIds` and excluded from
   individual element queries (walls, floors, etc.) to avoid duplication
3. Groups are deduplicated by `GroupTypeId` — only one representative
   instance per group type is introspected for its member shapes
4. Each group type records: member shapes (with doors/windows attached to
   walls), and all instance locations

### Generated Code Pattern

For each group type, three constructs are emitted:

```julia
# 1. Factory function: creates member shapes at group-relative coordinates
function group_entrance_factory()
  wall(open_polygonal_path([xyz(0.0, 0.0, 0.0), xyz(5.0, 0.0, 0.0)]),
    level=level_0, family=wall_basic_wall_generic_200mm)
  slab(...)
end

# 2. Group definition: stores the factory for later instantiation
group_entrance = group("group_entrance", factory=group_entrance_factory)

# 3. Instances: one per Revit group instance location
group_instance(group_entrance, xyz(10.0, 5.0, 0.0))
group_instance(group_entrance, xyz(25.0, 5.0, 0.0))
```

Member coordinates are translated to be relative to the first instance
location (which becomes the group's origin). Each `group_instance` call
re-creates the member shapes at the specified location via the factory
function.

### Backend Realization

- **Revit**: Since Revit doesn't expose a programmatic group creation API,
  `Group` realize is a no-op and each `GroupInstance` re-invokes the factory
  function within a translated coordinate system, creating independent copies
  of the member shapes at each instance location.
- **AutoCAD/Unity** (via `Block`/`BlockInstance`): Backends with native
  block/group support can implement `realize(b, s::Group)` to create a block
  definition from the member shapes, and `realize(b, s::GroupInstance)` to
  instantiate it.

### The `group`/`group_instance` Abstraction

Defined in KhepriBase as `@defproxy` types:

```julia
@defproxy(group, Shape0D, name::String="Group", shapes::Shapes=Shape[],
          factory::Union{Function,Nothing}=nothing)
@defproxy(group_instance, Shape0D, group::Group=required(), loc::Loc=u0())
```

- `name`: descriptive identifier (derived from Revit's `GroupType.Name`)
- `shapes`: collected member shapes (may be empty when using factory-based
  instantiation)
- `factory`: zero-argument function that creates member shapes when called;
  used by backends without native group support to re-create shapes at each
  instance location
- `loc`: world-space location for the group instance

## Limitations

- `detect_level_repetition` is not yet implemented (returns input unchanged)
- Family parameters (thickness, width, material) are not extracted from Revit;
  families are created with default parameters and rely on `set_backend_family`
  to map them back to the correct Revit type
- Only element types with existing `*_from_ref` helpers are introspected
  (levels, walls, floors, columns, beams, ceilings, doors, windows, groups)
- Curtain walls are detected but generated as regular `wall()` calls with a
  `curtain_wall_family()`
- Roofs and stairs are not yet introspected

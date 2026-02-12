# [BIM Elements](@id elements)

This page documents how Khepri BIM elements are realized in Revit. Each element
maps to specific Revit API calls through the `b_*` backend operations.

## Path Handling

Many Revit elements (walls, slabs, roofs, curtain walls) are defined by paths.
Revit can only handle **lines and arcs** — not splines. The `locs_and_arcs`
function converts Khepri paths to Revit's point-and-angle representation:

| Khepri Path Type | Conversion |
|------------------|------------|
| `OpenPolygonalPath` | Points with zero angles (straight segments) |
| `ClosedPolygonalPath` | Points with zero angles (straight segments) |
| `ArcPath` | Start and end points with the arc amplitude angle |
| `CircularPath` | Two antipodal points with two π angles (two semicircles) |
| `SplinePath` | **Not supported** — throws an error |

For composite paths containing both line and arc segments, `locs_and_arcs`
decomposes them into the point+angle format that Revit expects.

## Levels

Levels are fundamental to Revit's BIM model. Every floor, wall, column, and
stair references a level.

```julia
# Create a level at elevation 3.0 meters
my_level = level(3.0)

# Levels are realized on demand
wall(xy(0, 0), xy(10, 0), bottom_level=my_level)
```

Levels are realized via `FindOrCreateLevelAtElevation(elevation)` — if a level
already exists at that elevation, it is reused.

## Horizontal Elements

### Slabs (Floors)

Slabs support three path types through multiple dispatch:

```julia
# Polygonal slab
slab(closed_polygonal_path([xy(0,0), xy(10,0), xy(10,8), xy(0,8)]))

# Rectangular slab
slab(rectangular_path(xy(0, 0), 10, 8))

# Curved slab (arcs and lines)
slab(some_closed_path_with_arcs)
```

- **Polygonal paths** → `CreatePolygonalFloor(vertices, level_id)`
- **Rectangular paths** → converted to vertices, then `CreatePolygonalFloor`
- **Other closed paths** → decomposed via `locs_and_arcs` into
  `CreatePathFloor(points, angles, level_id)`

**Regions with holes**: When a `Region` is passed (an outer path with inner
paths), the outer path creates the slab, then each inner path creates an
opening via `CreatePolygonalOpening` or `CreatePathOpening`.

### Roofs

```julia
roof(closed_path, level=some_level)
```

Roofs are created via `CreatePathRoof(points, angles, level_id, family_id)`.
The path is always decomposed through `locs_and_arcs`.

### Ceilings

```julia
ceiling(closed_path, level=some_level)
```

Similar to slabs, ceilings support polygonal, rectangular, and general closed
paths:

- **Polygonal** → `CreatePolygonalCeiling(vertices, level_id)`
- **Rectangular** → converted to vertices, then `CreatePolygonalCeiling`
- **Other closed paths** → `CreatePathCeiling(points, angles, level_id)`

Regions are also supported — the outer path creates the ceiling, then inner
paths are ignored (only the outer boundary is used).

## Vertical Elements

### Walls

Walls are one of the most complex elements in Revit. KhepriRevit distinguishes
between **connected** and **unconnected** walls:

```julia
# Connected wall (spans between two levels)
wall(xy(0, 0), xy(10, 0),
     bottom_level=level(0),
     top_level=level(3))

# Unconnected wall (specified by height, no top level)
wall(xy(0, 0), xy(10, 0),
     bottom_level=level(0),
     top_level=unconnected_level(3))
```

- **Connected walls** (top level has a valid ElementId): Created via
  `CreateLineWall(vertices, base_level_id, top_level_id, family_id)`
- **Unconnected walls** (top level id = -1): Created via
  `CreateUnconnectedLineWall(vertices, base_level_id, height, family_id)`

The wall path is converted to an `OpenPolygonalPath` for realization.

**Walls with openings**: After the wall is created, doors and windows are
realized individually. Each opening calls its own `realize` method that inserts
it into the host wall.

!!! warning "Curved walls"
    Revit only supports walls made of **lines and arcs**. Spline walls are not
    supported and will throw an error. The commented-out `CreateSplineWall`
    API confirms this limitation.

### Curtain Walls

```julia
curtain_wall(path, bottom_level=level(0), top_level=level(3))
```

Created via `CreatePathCurtainWall(points, angles, base_level, top_level,
family_id, is_structural)`. The path is decomposed via `locs_and_arcs`.

Like regular walls, curtain walls do **not** support spline paths.

### Doors

```julia
door(wall_element, location, family=my_door_family)
```

Doors are inserted into host walls via
`InsertDoor(delta_from_start, delta_from_ground, host, family_id)`:

- `delta_from_start`: distance along the wall from its start point (X component
  of the transformed location)
- `delta_from_ground`: height above the wall's base level (Y component)
- `host`: the wall element reference

The door's location is adjusted by the family's `location_transform` — by
default, this shifts by half the door width to convert from Khepri's
edge-referenced position to Revit's center-referenced insertion.

!!! note
    `backend_add_door` is not yet implemented (calls `finish_this()`). Doors
    must be specified as part of the wall's openings list.

### Windows

```julia
window(wall_element, location, family=my_window_family)
```

Windows are inserted via
`InsertWindow(delta_from_start, delta_from_ground, host, family_id, param_names, param_values)`:

- Same positioning as doors (delta from start, delta from ground, host wall)
- Additionally passes **instance parameters** from the family's `instance_map`
  — this is how window `Width` and `Height` are set

The default window family uses `instance_map` with explicit `to_feet` conversion:
```julia
"Width"  => f -> f.width * to_feet
"Height" => f -> f.height * to_feet
```

Windows can be added to existing walls:
```julia
backend_add_window(revit, wall_element, location, window_family)
```

## Structural Elements

### Columns

Columns come in two variants:

```julia
# Level-based column (between two levels)
column(xy(5, 5), bottom_level=level(0), top_level=level(3))
```

Created via `CreateColumn(location, base_level_id, top_level_id, family_id)`.

```julia
# Free-standing column (between two points)
free_column(xyz(5, 5, 0), 3.0)
```

Created via `CreateColumnPoints(bottom_point, top_point, bottom_level,
top_level, family_id)`. Levels are automatically found or created at the
Z elevations of the bottom and top points.

The default column family is a metric concrete rectangular column with `"b"`
(width) and `"h"` (height) parameter mappings.

### Beams

```julia
beam(point, height, angle=0)
```

Created via `CreateBeam(p0, p1, rotation_angle, family_id)` where `p0` is the
start point and `p1 = p0 + (0, 0, height)`. Beams are **aligned along the top
axis**.

The default beam family is metric timber with `"b"` (width) and `"d"` (depth)
parameter mappings.

### Trusses

Truss elements use two types:

- **`TrussBar`**: Created as a beam via `CreateBeam(p0, p1, angle, family_id)`
- **`TrussNode`**: Created as a small beam stub via
  `CreateBeam(p, p + (0.1, 0, 0), 0, family_id)`

Both default to the metric steel W-Wide Flange family.

## Circulation Elements

### Railings

Railings support three path types:

```julia
# Line railing (open path)
railing(open_polygonal_path([xy(0,0), xy(5,0), xy(5,3)]),
        level=my_level)

# Polygon railing (closed path)
railing(closed_polygonal_path([xy(0,0), xy(5,0), xy(5,3), xy(0,3)]),
        level=my_level)

# Host-attached railing (attached to a slab, ramp, or stair)
railing(some_path, host=my_slab)
```

- **Open polygonal** → `CreateLineRailing(vertices, level_id, family_id)`
- **Closed polygonal** → `CreatePolygonRailing(vertices, level_id, family_id)`
- **Host-attached** → `InsertRailing(host_ref, family_id)`

### Ramps

```julia
ramp(path, bottom_level=level(0), top_level=level(1))
```

Created via `CreateRamp(p0, p1, width, thickness, base_level_id, base_offset,
top_offset)`. The path's start and end points define the ramp geometry;
`width` and `thickness` come from the family.

### Stairs

**Straight stairs**:
```julia
stair(base_point, direction, bottom_level=level(0), top_level=level(3))
```

Created via `CreateStraightStair(base_point, direction, width, base_level_id,
top_level_id, family_id)`.

**Spiral stairs**:
```julia
spiral_stair(center, radius, start_angle, included_angle,
             clockwise=false, bottom_level=level(0), top_level=level(3))
```

Created via `CreateSpiralStair(center, radius, start_angle, included_angle,
clockwise, width, base_level_id, top_level_id, family_id)`.

### Stair Landings

Stair landings are delegated to `b_slab` — they are created as floor slabs
at the specified level.

## Fixtures

Fixtures (toilets, closets, sinks) are placed on host elements (typically
slabs) with a location and direction:

```julia
# All use CreateElementLocDirOnHost(location, direction, host, family_id)
toilet(location, host=my_slab)
closet(location, host=my_slab)
sink(location, host=my_slab)
```

Each fixture family has a `location_transform` that adjusts the position and
rotation:

| Fixture | Transform |
|---------|-----------|
| Toilet | Rotate 90° via `loc_from_o_phi(c, π/2)`, shift Y by -0.12 |
| Closet | No transform |
| Sink | Rotate 90° via `loc_from_o_phi(c, π/2)` |

The direction vector is always `vx(1, c.cs)` in the fixture's coordinate
system.

```@meta
CurrentModule = KhepriRevit
```

# KhepriRevit

KhepriRevit is a Khepri backend for [Autodesk Revit](https://www.autodesk.com/products/revit),
enabling parametric BIM modeling from Julia. It communicates with Revit through
a C# plugin over TCP, giving you programmatic access to Revit's full BIM
capabilities — walls, slabs, roofs, columns, beams, doors, windows, and more —
using the same Khepri code that works with every other backend.

## Architecture

KhepriRevit is a **SocketBackend** using the `:RVT` protocol (which extends the
`:CS` binary protocol). Julia acts as the TCP server; the Revit C# plugin
connects as a client on port 11001.

| Property | Value |
|----------|-------|
| Backend type | `SocketBackend{RVTKey, Int64}` |
| Reference IDs | `Int64` — Revit `ElementId` values |
| Protocol | `:RVT` (extends `:CS` binary) |
| Default port | `11001` |
| Coordinate system | Right-handed Z-up (same as Khepri — no transforms needed) |
| Units | Khepri uses SI (meters); Revit uses feet internally |
| Boolean ops | Full CSG support (`HasBooleanOps{true}`) |

### Unit Conversion

Khepri works in SI units (meters). Revit's internal unit system uses feet. The
constant `to_feet ≈ 3.28084` handles conversion where needed. Most plugin
operations accept SI values directly, but some family parameters (notably window
`Width` and `Height`) require explicit conversion — see the
[Families](@ref families) page for details.

## Quick Start

```julia
using KhepriRevit
using KhepriBase

# Activate the Revit backend
backend(revit)

# Create a level and some BIM elements
wall(xy(0, 0), xy(10, 0))
wall(xy(10, 0), xy(10, 8))
slab(rectangular_path(xy(0, 0), 10, 8))
column(xy(5, 4))
```

This requires Revit running with the Khepri plugin installed and listening on
TCP port 11001. See [Setup](@ref setup) for installation instructions.

## Key Features

- **BIM-native families**: Three family types — [`RevitSystemFamily`](@ref) for
  built-in types (walls, slabs), [`RevitFileFamily`](@ref) for loadable `.rfa`
  files (columns, windows), and [`RevitInPlaceFamily`](@ref) (reserved for
  future use). See [Families](@ref families).

- **Level management**: Automatic level creation at specified elevations via
  `FindOrCreateLevelAtElevation`.

- **Boolean operations**: Full CSG support — union, intersection, subtraction.

- **IFC interoperability**: Import and convert IFC files with
  [`convert_ifc_file`](@ref) and [`load_rvt_file`](@ref).

- **BIM elements**: Walls, floors, roofs, ceilings, doors, windows, columns,
  beams, curtain walls, railings, ramps, stairs, and plumbing fixtures.
  See [BIM Elements](@ref elements).

- **Geometry primitives**: Box, sphere, cone, cylinder, pyramid, extruded
  contours, surface grids. See [Geometry & Interop](@ref geometry).

- **Document querying**: Read existing Revit models with [`all_walls`](@ref),
  [`all_floors`](@ref), `all_levels`, and `all_elements`.

## Documentation

```@contents
Pages = ["setup.md", "families.md", "elements.md", "geometry.md"]
Depth = 2
```

## API Reference

```@index
```

```@autodocs
Modules = [KhepriRevit]
```

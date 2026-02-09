```@meta
CurrentModule = KhepriRevit
```

# KhepriRevit

A Khepri backend for [Autodesk Revit](https://www.autodesk.com/products/revit), communicating via a C# plugin over TCP (port 11001).

## Architecture

KhepriRevit is a **SocketBackend** using the `:CS` (C#) binary protocol. It targets Revit's BIM-native workflow with levels, system families, and loadable families.

- **Backend type**: `SocketBackend{RVTKey, Int64}`
- **Reference IDs**: `Int64` (Revit ElementId values)
- **Coordinate system**: Right-handed Z-up (no transforms needed)
- **Unit conversion**: Internal `to_feet` constant (≈3.28084) for Revit's imperial unit system

## Key Features

- **BIM-native families**: Three family types — `RevitSystemFamily` (walls, slabs), `RevitFileFamily` (loadable `.rfa`), and `RevitInPlaceFamily`
- **Level management**: Elevation-based level creation and assignment
- **Boolean operations**: Full CSG support (`HasBooleanOps{true}`)
- **IFC interoperability**: Import/export via `convert_ifc_file()` and `load_rvt_file()`
- **BIM elements**: Walls, floors, roofs, doors, windows, columns, beams, railings, fixtures

## Setup

```julia
using KhepriRevit
using KhepriBase

backend(revit)

# Standard Khepri operations work transparently
wall(xy(0, 0), xy(10, 0))
slab(rectangular_path(xy(0, 0), 10, 8))
```

Requires Revit with the Khepri C# plugin installed and listening on TCP port 11001.

## Dependencies

- **KhepriBase**: Core Khepri functionality
- **Sockets**: TCP communication

```@index
```

```@autodocs
Modules = [KhepriRevit]
```

```@meta
CurrentModule = KhepriAutoCAD
```

# KhepriAutoCAD

A Khepri backend for [AutoCAD](https://www.autodesk.com/products/autocad), communicating via a C# plugin over TCP (port 11000).

## Architecture

KhepriAutoCAD is a **SocketBackend** using the `:CS` (C#) binary protocol. The Julia side sends geometry and material commands to a C# plugin running inside AutoCAD's process space.

- **Backend type**: `SocketBackend{ACADKey, Int64}`
- **Reference IDs**: `Int64` (AutoCAD object handles)
- **Coordinate system**: Right-handed Z-up (no transforms needed)

## Key Features

- **190+ remote API calls**: Full geometry, materials, layers, rendering, BIM, and annotation support
- **Dimension styles**: Architectural (`_ARCHTICK`) and mechanical dimension formats
- **Material system**: Fine-grained control via `AutoCADBasicMaterial` with projection and tiling modes
- **BIM elements**: Walls, floors, doors, windows, tables, chairs
- **User selection**: Interactive pick of positions, points, curves, surfaces, and solids
- **Plugin auto-update**: Automatic deployment of C# plugin DLLs
- **SHX fonts**: Optional SHX text rendering via the `use_shx` parameter

## Setup

```julia
using KhepriAutoCAD
using KhepriBase

backend(autocad)

# Geometry works through standard Khepri API
sphere(xyz(0, 0, 0), 5)
```

Requires AutoCAD with the Khepri C# plugin installed and listening on TCP port 11000.

## Dependencies

- **KhepriBase**: Core Khepri functionality
- **Sockets**: TCP communication

```@index
```

```@autodocs
Modules = [KhepriAutoCAD]
```

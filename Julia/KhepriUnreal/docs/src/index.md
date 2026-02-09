```@meta
CurrentModule = KhepriUnreal
```

# KhepriUnreal

A Khepri backend for [Unreal Engine](https://www.unrealengine.com/), communicating via a C++ plugin over TCP (port 11010).

## Architecture

KhepriUnreal is a **SocketBackend** using the `:CPP` (C++) binary protocol. It handles Unreal's left-handed coordinate system with an X-Y swap and 100x scale factor (Unreal uses centimeters).

- **Backend type**: `SocketBackend{UEKey, Int}`
- **Reference IDs**: `Int` (Unreal actor/component IDs)
- **Coordinate transform**: X-Y swap with 100x scale — Khepri `(x, y, z)` becomes Unreal `(y*100, x*100, z*100)`
- **CSG support**: `UEUnionRef` and `UESubtractionRef` for boolean operations via BSP

## Key Features

- **Material and resource families**: `UEMaterialFamily` for material paths, `UEResourceFamily` for static mesh loading with parameter maps
- **CSG via BSP**: Boolean union and subtraction through Unreal's BSP system
- **BIM elements**: Walls, slabs, beams, panels, tables, chairs via `InstantiateBIMElement`
- **Fast mode**: `fast_unreal()` for optimized bulk geometry transfer
- **Lighting**: Point lights and spotlights with physically-based parameters

## Setup

```julia
using KhepriUnreal
using KhepriBase

backend(unreal)

sphere(xyz(0, 0, 0), 5)
```

Requires Unreal Engine with the Khepri C++ plugin installed and listening on TCP port 11010.

## Dependencies

- **KhepriBase**: Core Khepri functionality
- **Sockets**: TCP communication

```@index
```

```@autodocs
Modules = [KhepriUnreal]
```

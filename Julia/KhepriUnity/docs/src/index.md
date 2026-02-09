```@meta
CurrentModule = KhepriUnity
```

# KhepriUnity

A Khepri backend for the [Unity](https://unity.com/) game engine, communicating via a C# plugin over TCP (port 11002).

## Architecture

KhepriUnity is a **SocketBackend** using the `:CS` (C#) binary protocol. It handles Unity's left-handed Y-up coordinate system by swapping Y and Z axes when encoding geometry.

- **Backend type**: `SocketBackend{UnityKey, Int32}`
- **Reference IDs**: `Int32` (Unity game object instance IDs)
- **Coordinate transform**: Y-Z swap — Khepri `(x, y, z)` becomes Unity `(x, z, y)`
- **Boolean operations**: Disabled (`HasBooleanOps{false}`)

## Key Features

- **170+ remote API calls**: Full geometry, materials, lighting, and simulation support
- **NavMesh integration**: Walkable/non-walkable area tagging via `nav_mesh_tagging` parameter
- **Evacuation simulation**: Built-in pedestrian simulation and analysis
- **Material families**: `UnityMaterialFamily` mapping to Unity material paths
- **Fast mode**: `fast_unity()` for optimized bulk geometry transfer
- **Game objects**: Direct creation and manipulation of Unity GameObjects

## Setup

```julia
using KhepriUnity
using KhepriBase

backend(unity)

sphere(xyz(0, 0, 0), 5)
```

Requires Unity with the Khepri C# plugin installed and listening on TCP port 11002.

## Dependencies

- **KhepriBase**: Core Khepri functionality
- **Sockets**: TCP communication

```@index
```

```@autodocs
Modules = [KhepriUnity]
```

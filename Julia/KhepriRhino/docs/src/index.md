```@meta
CurrentModule = KhepriRhino
```

# KhepriRhino

A Khepri backend for [Rhinoceros 3D](https://www.rhino3d.com/), communicating via a C# plugin over TCP (port 12000).

## Architecture

KhepriRhino is a **SocketBackend** using the `:CS` (C#) binary protocol. Shape references use GUIDs (`UInt128`) rather than integer IDs, matching Rhino's native object identity model.

- **Backend type**: `SocketBackend{RHKey, Guid}`
- **Reference IDs**: `Guid` (UInt128, matching Rhino's GUID system)
- **Shape storage**: `RemoteShapeStorage` (shapes tracked in Rhino, not Julia)
- **Boolean operations**: Disabled (`HasBooleanOps{false}`)

## Key Features

- **NURBS and mesh geometry**: Full support for both representations
- **Material library**: Version-aware loading from Rhino's built-in material folders (Rhino 5 vs 6+)
- **Grasshopper integration**: Enable/disable/run the Grasshopper solver from Julia
- **Rendering modes**: Realistic, clay (white/black variants), HDRi environments
- **Lighting**: Point lights, spotlights, IES photometric lights, and area lights (approximated as point lights)
- **Layer families**: Layer management via `RhinoLayerFamily`
- **Sweep and thickening**: Advanced surface operations

## Setup

```julia
using KhepriRhino
using KhepriBase

backend(rhino)

# Standard Khepri operations
sphere(xyz(0, 0, 0), 5)
```

Requires Rhino with the Khepri C# plugin installed and listening on TCP port 12000.

## Dependencies

- **KhepriBase**: Core Khepri functionality
- **Sockets**: TCP communication

```@index
```

```@autodocs
Modules = [KhepriRhino]
```

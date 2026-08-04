```@meta
CurrentModule = KhepriBlender
```

# KhepriBlender

A Khepri backend for [Blender](https://www.blender.org/), communicating via a Python plugin over TCP (port 11003).

## Architecture

KhepriBlender is a **SocketBackend** using the `:PY` (Python) binary protocol. Julia sends commands to a Python server script (`KhepriServer.py`) running inside Blender's embedded Python interpreter.

- **Backend type**: `SocketBackend{BLRKey, Union{Int32, String}}`
- **Reference IDs**: `Int32` for shapes/materials, `String` for layers/collections
- **Coordinate system**: Right-handed Z-up (no transforms needed)

## Key Features

- **Multiple renderers**: Eevee (default), Cycles (path tracing), Freestyle SVG output, clay render
- **BlenderKit materials**: Integration with Blender's material add-on via `blender_family_materials()`
- **Headless mode**: Batch processing when `headless_blender()` is enabled
- **HDRI environments**: Environment map support for realistic lighting
- **SVG export**: Freestyle-based vector output via `render_svg()`
- **Auto-launch**: `start_blender()` can locate and launch Blender automatically

## Setup

```julia
using KhepriBlender
using KhepriBase

backend(blender)

sphere(xyz(0, 0, 0), 5)
render_view("output")
```

Requires Blender with the `KhepriServer.py` plugin running. Set `headless_blender(true)` for batch mode.

## Dependencies

- **KhepriBase**: Core Khepri functionality
- **Sockets**: TCP communication

```@index
```

```@autodocs
Modules = [KhepriBlender]
```

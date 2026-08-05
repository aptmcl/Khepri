```@meta
CurrentModule = Khepri
```

# Khepri

Khepri is the main entry point for the Khepri architectural design framework.
It re-exports [KhepriAutoCAD](https://aptmcl.github.io/Khepri/KhepriAutoCAD/stable),
providing access to all Khepri geometry, BIM, and backend operations with
AutoCAD as the default backend.

## Quick Start

```julia
using Khepri

# All KhepriBase + KhepriAutoCAD functionality is available
backend(autocad)
box(xyz(0, 0, 0), 5, 5, 5)
```

## Switching Backends

To use a different backend, replace `using Khepri` with the specific backend
package:

```julia
using KhepriRevit    # For Autodesk Revit
using KhepriBlender  # For Blender
using KhepriRhino    # For Rhinoceros
using KhepriUnity    # For Unity
```

## Package Index

All packages live in the [aptmcl/Khepri monorepo](https://github.com/aptmcl/Khepri)
under `Julia/`.

### Core
- [KhepriBase](https://aptmcl.github.io/Khepri/KhepriBase/stable) — Geometry, coordinates, backend abstraction, shape proxies
- [KhepriLibrary](https://aptmcl.github.io/Khepri/KhepriLibrary/stable) — Reusable building components

### CAD/BIM Backends
- [KhepriAutoCAD](https://aptmcl.github.io/Khepri/KhepriAutoCAD/stable) — Autodesk AutoCAD
- [KhepriRevit](https://aptmcl.github.io/Khepri/KhepriRevit/stable) — Autodesk Revit
- [KhepriBlender](https://aptmcl.github.io/Khepri/KhepriBlender/stable) — Blender
- [KhepriRhino](https://aptmcl.github.io/Khepri/KhepriRhino/stable) — Rhinoceros
- [KhepriGrasshopper](https://aptmcl.github.io/Khepri/KhepriGrasshopper/stable) — Grasshopper
- [KhepriUnity](https://aptmcl.github.io/Khepri/KhepriUnity/stable) — Unity
- [KhepriUnreal](https://aptmcl.github.io/Khepri/KhepriUnreal/stable) — Unreal Engine

### Visualization Backends
- [KhepriThreejs](https://aptmcl.github.io/Khepri/KhepriThreejs/stable) — Three.js
- [KhepriThebes](https://aptmcl.github.io/Khepri/KhepriThebes/stable) — Thebes.jl (pure-Julia 3D)

### Drawing and Rendering
- [KhepriTikZ](https://aptmcl.github.io/Khepri/KhepriTikZ/stable) — TikZ/LaTeX
- [KhepriSVG](https://aptmcl.github.io/Khepri/KhepriSVG/stable) — SVG
- [KhepriPOVRay](https://aptmcl.github.io/Khepri/KhepriPOVRay/stable) — POV-Ray
- [KhepriIllustrator](https://aptmcl.github.io/Khepri/KhepriIllustrator/stable) — Adobe Illustrator

### Analysis
- [Frame4DD](https://aptmcl.github.io/Khepri/Frame4DD/stable) — Frame analysis (Frame3DD port)
- [KhepriFrame4DD](https://aptmcl.github.io/Khepri/KhepriFrame4DD/stable) — Structural analysis backend

```@index
```

```@autodocs
Modules = [Khepri]
```

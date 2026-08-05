# Khepri

Khepri is an algorithmic design tool that integrates design, analysis, and optimization.

You describe a design once, in Julia, and Khepri realizes it in whichever
application you point it at — a CAD system, a BIM authoring tool, a renderer, a
game engine, or a LaTeX figure.

## The idea

The same Khepri program produces an equivalent design in every backend. Only the
`using` line changes:

```julia
using KhepriAutoCAD    # or KhepriRhino, KhepriBlender, KhepriUnity, KhepriTikZ, ...

sphere(xyz(0, 0, 0), 5)
box(xyz(10, 0, 0), 5, 5, 5)
surface_polygon(xyz(0, 0, 0), xyz(5, 0, 0), xyz(2.5, 5, 0))
```

Geometry, materials, views and rendering are expressed against one backend-agnostic
API, so a model can be drafted in a fast viewer, rendered for presentation, and
handed to a BIM tool for documentation without being rewritten. That portability is
the project's central design constraint, not a convenience layer added later.

## Packages

| Package | What it does |
| --- | --- |
| **KhepriBase** | Core library: geometry, materials, levels and families, the backend protocol. Every other package depends on it. |
| **Khepri** | Umbrella entry point for Khepri users. |
| KhepriAutoCAD | Backend for [AutoCAD](https://www.autodesk.com/products/autocad), over a C# plugin. |
| KhepriRevit | Backend for [Autodesk Revit](https://www.autodesk.com/products/revit), over a C# plugin. |
| KhepriRhino | Backend for [Rhinoceros 3D](https://www.rhino3d.com/), over a C# plugin. |
| KhepriGrasshopper | Integration with [Grasshopper](https://www.grasshopper3d.com/), Rhino's visual programming environment. |
| KhepriBlender | Backend for [Blender](https://www.blender.org/), over a Python plugin. |
| KhepriUnity | Backend for the [Unity](https://unity.com/) engine, over a C# plugin. |
| KhepriUnreal | Backend for [Unreal Engine](https://www.unrealengine.com/), over a C++ plugin. |
| KhepriPOVRay | Ray-traced rendering via [POV-Ray](http://www.povray.org/). |
| KhepriThreejs | 3D visualization in the browser via Three.js. |
| KhepriTikZ | Generates TikZ for standalone figures or inclusion in LaTeX documents. |
| KhepriThebes | Pure-Julia SVG rendering, built on Thebes.jl and Luxor.jl. |
| KhepriSVG | Direct SVG output; generates the figures in this repository's documentation. |
| KhepriIllustrator | Step-by-step visual tracing of the evaluation of a Khepri program. |
| KhepriLibrary | Reusable parametric building components. |
| KhepriFrame4DD | Structural analysis backend, built on Frame4DD. |
| Frame4DD | Static and dynamic structural analysis of 2D and 3D frames. Pure Julia, no Khepri dependency. |

## Installation

### Cloning on Windows

Some paths in this repository exceed Windows' historical 260-character
limit. Enable long-path support in Git before cloning:

```
git config --global core.longpaths true
```

Without it, `git clone` aborts mid-checkout with `Filename too long`
errors.

Five packages are in the General registry:

```julia
using Pkg
Pkg.add("KhepriAutoCAD")     # also: Khepri, KhepriBase, KhepriIllustrator, KhepriTikZ
```

The rest are not yet registered and install from this repository:

```julia
using Pkg
Pkg.add(url = "https://github.com/aptmcl/Khepri", subdir = "Julia/KhepriRhino")
```

Backends that drive an external application also need that application's plugin.
KhepriAutoCAD, KhepriRevit, KhepriRhino and KhepriGrasshopper ship theirs with the
Julia package; the rest are set up as their own documentation describes. Plugin
sources live under `Plugins/`.

## Repository layout

```
Julia/      the Julia packages above
Plugins/    plugin sources for the host applications
              KhepriAutoCAD, KhepriRevit, KhepriRhinoceros, KhepriGrasshopper  (C#)
              KhepriUnity (C#), KhepriUnreal (C++), KhepriBase (shared)
VSCode/     editor integration: khepriide, vsckhepri
```

These lived in separate repositories until 2026 and were consolidated here with
their histories intact, so `git log` and `git blame` reach back through the move.
The per-package repositories remain archived and read-only; versions registered
before the move continue to resolve from them.

## Documentation

Each package publishes its own site at
`https://aptmcl.github.io/Khepri/<Package>/`. Sources are under
`Julia/<Package>/docs/`.

## Contributing

CI builds only the packages a change affects, worked out from the dependency graph:
a change under `Julia/KhepriBase` rebuilds everything, a change to a single backend
rebuilds that backend alone. Packages are tested on Windows against Julia 1.12 and
nightly.

Tests that need a host application are gated behind environment variables
(`KHEPRI_RHINO_TESTS`, `KHEPRI_AUTOCAD_TESTS`, and similar) and are skipped unless
that application is present, so a normal test run needs none of them.

## License

MIT. See [LICENSE](LICENSE).

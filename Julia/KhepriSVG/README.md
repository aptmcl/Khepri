# KhepriSVG

A Khepri backend that emits SVG directly.

Like every Khepri backend it implements the `b_*` operations from
[KhepriBase](../KhepriBase), so the same program that drives AutoCAD or Blender
produces a vector drawing instead:

```julia
using KhepriSVG

sphere(xyz(0, 0, 0), 5)
box(xyz(10, 0, 0), 5, 5, 5)
```

It writes plain SVG with no external renderer, no host application and no binary
dependencies, which makes it suited to generating figures as part of a build.
That is its main use here: `Julia/KhepriBase/docs/scripts/` renders 51 of the 156
figures in KhepriBase's documentation with it.

[KhepriThebes](../KhepriThebes) also produces SVG, via Thebes.jl and Luxor.jl,
with 3D projection and richer styling. KhepriSVG is the smaller, more direct
path — it has four dependencies and no drawing library underneath it.

## Installation

KhepriSVG is not in the General registry. It installs from this repository:

```julia
using Pkg
Pkg.add(url = "https://github.com/aptmcl/Khepri", subdir = "Julia/KhepriSVG")
```

## Documentation

KhepriSVG publishes no documentation site. The backend-agnostic API it implements
is documented in [KhepriBase](https://aptmcl.github.io/Khepri/KhepriBase/), and
`Julia/KhepriBase/docs/scripts/` shows it in use.

## License

MIT, as part of the [Khepri](https://github.com/aptmcl/Khepri) monorepo. See
[LICENSE](../../LICENSE).

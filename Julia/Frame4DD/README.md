# Frame4DD

Static and dynamic structural analysis of 2D and 3D frames and trusses.

Frame4DD is a programmatic reimplementation of
[Frame3DD](https://frame3dd.sourceforge.net/) (Henri P. Gavin, Duke University)
with a pure Julia API — models are built and solved in memory, with no file I/O.

- Static analysis of 2D and 3D frames and trusses
- Geometric nonlinearity, via P-delta effects with Newton–Raphson iteration
- Modal analysis: natural frequencies and mode shapes

It depends only on `LinearAlgebra`, `SparseArrays` and `PrecompileTools`, and has
no dependency on Khepri. [KhepriFrame4DD](../KhepriFrame4DD) wraps it as a Khepri
backend, so a design expressed in Khepri can be analysed structurally without
leaving Julia.

## Installation

Frame4DD is not in the General registry. It installs from this repository:

```julia
using Pkg
Pkg.add(url = "https://github.com/aptmcl/Khepri", subdir = "Julia/Frame4DD")
```

Installing `KhepriFrame4DD` the same way brings it in as a dependency.

## Documentation

Sources are under `docs/`; `Frame4DD` does not publish a site of its own. The
tutorials in [KhepriFrame4DD's documentation](https://aptmcl.github.io/Khepri/KhepriFrame4DD/)
exercise it end to end — a planar truss, a Warren bridge, a space truss tower and
a truss grid deck — and are the fastest way to see what it does.

## License

MIT, as part of the [Khepri](https://github.com/aptmcl/Khepri) monorepo. See
[LICENSE](../../LICENSE).

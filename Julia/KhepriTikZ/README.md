# KhepriTikZ

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://aptmcl.github.io/KhepriTikZ.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://aptmcl.github.io/KhepriTikZ.jl/dev)
[![Build Status](https://github.com/aptmcl/KhepriTikZ.jl/workflows/CI/badge.svg)](https://github.com/aptmcl/KhepriTikZ.jl/actions)
[![Coverage](https://codecov.io/gh/aptmcl/KhepriTikZ.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/aptmcl/KhepriTikZ.jl)

KhepriTikZ is a Khepri backend that generates TikZ code for standalone visualization or inclusion in LaTeX documents.

## Installation

Install with the Julia package manager [Pkg](https://pkgdocs.julialang.org/):

```jl
pkg> add KhepriTikZ  # Press ']' to enter the Pkg REPL mode.
```
or
```jl
julia> using Pkg; Pkg.add("KhepriTikZ")
```

## Usage

```jl
using KhepriTikZ

arrow(p, ρ, α, σ, β) =
  let p_1 = p + vpol(ρ,α),
      p_2 = p_1 + vpol(σ, α + π + β)
      p_3 = p_1 + vpol(σ, α + π - β)
    line(p, p_1, p_2, p_3,p_1)
  end

delete_all_shapes()
arrow(xy(0,0), 4, π/4, 2, π/8)
render_view()
```

The result shows in the Plots pane, as follows:

<img src="./assets/Arrow.svg" width=600>

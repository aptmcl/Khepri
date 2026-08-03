# KhepriIllustrator

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://aptmcl.github.io/Khepri/KhepriIllustrator/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://aptmcl.github.io/Khepri/KhepriIllustrator/dev)
[![Build Status](https://github.com/aptmcl/Khepri/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/aptmcl/Khepri/actions/workflows/ci.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/aptmcl/Khepri/branch/main/graph/badge.svg?flag=KhepriIllustrator)](https://codecov.io/gh/aptmcl/Khepri)

KhepriIllustrator generates a schematic explanation of a Khepri program.

## Installation

Install with the Julia package manager [Pkg](https://pkgdocs.julialang.org/):

```jl
pkg> add KhepriIllustrator  # Press ']' to enter the Pkg REPL mode.
```
or
```jl
julia> using Pkg; Pkg.add("KhepriIllustrator")
```

## Usage

```jl
using KhepriIllustrator
using KhepriTikZ # A backend is needed to visualize the output

@illustrator arrow(p, ρ, α, σ, β) =
  let p_1 = p + vpol(ρ,α),
      p_2 = p_1 + vpol(σ, α + π + β)
      p_3 = p_1 + vpol(σ, α + π - β)
    line(p, p_1, p_2, p_3,p_1)
  end

delete_all_shapes()
@illustrator arrow(xy(0,0), 4, π/4, 2, π/8)
render_view()
```

The result, using the KhepriTikZ backend, shows in the Plots pane, as follows:

<img src="./assets/Arrow.svg" width=600>

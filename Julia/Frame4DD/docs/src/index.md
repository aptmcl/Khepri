# Frame4DD.jl

A Julia package for static and dynamic structural analysis of 2D and 3D frames
and trusses. Frame4DD is a programmatic reimplementation of
[Frame3DD](https://frame3dd.sourceforge.net/) (Henri P. Gavin, Duke University)
with a pure Julia API — no file I/O required.

## Features

- Static analysis of 2D and 3D frames and trusses
- Geometric nonlinearity (P-delta effects via Newton-Raphson iteration)
- Modal analysis (natural frequencies and mode shapes)
- Seven load types: gravity, concentrated, uniform, trapezoidal, internal point,
  temperature, and prescribed displacements
- Shear deformation corrections (Timoshenko beam theory)
- Automatic dense/sparse solver selection based on problem size

## Installation

Frame4DD is not registered in the Julia General registry. To use it, activate
the project directly:

```julia
using Pkg
Pkg.activate("/path/to/Frame4DD")
using Frame4DD
```

## Quick Start

A minimal example — a cantilever beam with a tip load:

```julia
using Frame4DD

# Create a model
model = Model()

# Two nodes: fixed end at origin, free end at x=100
add_node!(model, 0.0, 0.0, 0.0)
add_node!(model, 100.0, 0.0, 0.0)

# Cross-section and material
sec = Section(10.0, 5.0, 5.0, 50.0, 100.0, 100.0)  # Ax, Asy, Asz, Jx, Iy, Iz
mat = Material(29000.0, 11500.0, 7.33e-7)             # E, G, density

# One frame element connecting the two nodes
add_element!(model, 1, 2, sec, mat)

# Fix all 6 DOFs at node 1
fix_node!(model, 1; dx=true, dy=true, dz=true, rx=true, ry=true, rz=true)

# Apply a downward point load at node 2
lc = add_load_case!(model)
add_nodal_load!(lc, 2; fy=-10.0)

# Solve
results = solve(model)

# Read results
D = results.load_cases[1].displacements
node2_dy = D[2*6 - 4]  # DOF 8 = node 2, y-displacement
println("Tip deflection: ", node2_dy)
```

See the [Tutorial](@ref) for more complete examples.

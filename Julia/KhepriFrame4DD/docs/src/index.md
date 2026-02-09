```@meta
CurrentModule = KhepriFrame4DD
```

# KhepriFrame4DD

A Julia-native structural analysis backend for Khepri, using the [Frame4DD](https://github.com/aptmcl/Frame4DD.jl) package for finite element truss analysis.

## Architecture

KhepriFrame4DD is a **LazyBackend** — it accumulates truss nodes and bars during design, then solves the full structural model when analysis is requested. Unlike KhepriFrame3DD, this backend calls Frame4DD as a pure Julia library (no external binary).

- **Backend type**: `LazyBackend{FR4DDKey, Any}`
- **Analysis engine**: Julia `Frame4DD` package (direct API calls)
- **Node merging**: Duplicate nodes at the same location are automatically merged

## Key Features

- **Circular tube geometry**: Automatic calculation of cross-section properties (Ax, Asy, Asz, Jxx, Iyy, Izz) from outer radius and wall thickness
- **Truss bar families**: Configurable material properties (elastic modulus E, shear modulus G, density d)
- **Load cases**: Point loads at nodes, optional self-weight via gravitational acceleration
- **Displacement queries**: Per-node displacement vectors after analysis

## Usage

```julia
using KhepriFrame4DD
using KhepriBase

backend(frame4dd)

# Define a truss bar family
family = frame4dd_circular_tube_truss_bar_family(
  frame4dd_circular_tube_truss_bar_geometry(0.05, 0.003),
  E=210e9, G=81e9, p=0.0, d=7850.0)

# Create truss geometry, then analyze
truss_analysis(vz(-1e4))
```

## Dependencies

- **KhepriBase**: Core Khepri functionality
- **Frame4DD**: Julia structural analysis solver

```@index
```

```@autodocs
Modules = [KhepriFrame4DD]
```

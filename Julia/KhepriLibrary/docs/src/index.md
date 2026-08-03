```@meta
CurrentModule = KhepriLibrary
```

# KhepriLibrary

A library of reusable parametric building components for Khepri, providing ready-made architectural elements that work across all backends.

## Architecture

KhepriLibrary is a pure Khepri package — it uses only standard KhepriBase functions, so all components work with any backend (AutoCAD, Revit, Blender, etc.).

## Key Features

### Test Cell

The `test_cell` function creates a simple parametric building cell with:

- **Configurable dimensions**: length, depth, height (default 8×6×3 m)
- **Wall/slab/roof thickness**: Independent thickness parameters
- **Window-to-wall ratio**: Automatic centered window placement
- **Standard families**: Uses `with_slab_family`, `with_wall_family`, `with_window_family`, `with_roof_family`

## Usage

```julia
using KhepriLibrary
using KhepriBase

# Default test cell
test_cell()

# Custom dimensions
test_cell(location=xyz(20, 0, 0), length=12, depth=8, height=4,
          wall_thickness=0.2, window_to_wall_ratio=0.6)
```

## Dependencies

- **KhepriBase**: Core Khepri functionality

```@index
```

```@autodocs
Modules = [KhepriLibrary]
```

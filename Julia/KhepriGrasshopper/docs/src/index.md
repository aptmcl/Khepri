```@meta
CurrentModule = KhepriGrasshopper
```

# KhepriGrasshopper

A Khepri integration for [Grasshopper](https://www.grasshopper3d.com/), the visual programming environment for Rhino. Enables Julia-defined parametric components inside Grasshopper canvases.

## Architecture

KhepriGrasshopper works via a .NET plugin (`KhepriGrasshopper.gha`) that embeds Julia inside Grasshopper through P/Invoke. Julia functions are compiled into Grasshopper components with typed input/output parameters.

- **Plugin**: C# DLL deployed to Grasshopper's Libraries folder
- **Macro system**: `@ghdef` macro defines type-safe Grasshopper parameters
- **Expression parsing**: `kgh_forms()` parses Julia code fragments for input/output declarations

## Key Features

- **Type-safe I/O parameters**: `GHNumber`, `GHString`, `GHBoolean`, `GHPoint`, `GHInteger`, `GHVector`, `GHPath`, `GHAny` — plus plural variants for list inputs
- **`@ghdef` macro**: Generates constructor functions that produce Grasshopper parameter descriptors
- **Input/Output syntax**: `a < Number("radius")` for inputs, `result > Number()` for outputs
- **`create_kgh_function`**: Converts a Julia function body with I/O declarations into a callable Grasshopper component
- **Shape collection**: Automatically tracks shapes created during component execution

## Usage

```julia
using KhepriGrasshopper

# Define a Grasshopper component
create_kgh_function("MyComponent", """
  r < Number("radius")
  h < Number("height")
  cylinder(u0(), r, h)
  v > Number()
  v = π * r^2 * h
""")
```

## Dependencies

- **KhepriBase**: Core Khepri functionality
- **Rhino + Grasshopper**: Host environment with KhepriGrasshopper.gha plugin

```@index
```

```@autodocs
Modules = [KhepriGrasshopper]
```

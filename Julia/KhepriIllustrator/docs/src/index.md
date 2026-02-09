```@meta
CurrentModule = KhepriIllustrator
```

# KhepriIllustrator

A visualization overlay for Khepri that provides step-by-step evaluation tracing of Julia expressions, intended for pedagogical illustration of computational design processes.

## Architecture

KhepriIllustrator consists of three components:

- **JuliaReader**: Parses Julia source text into expressions, handling multi-line and incomplete inputs
- **JuliaEvaluator**: Environment-based evaluator with lexical scoping, supporting assignment, function calls, and control flow
- **IllustratedOps**: Hooks into Khepri operations to capture and visualize each step

## Key Features

- **Julia expression reader**: `julia_read()` parses from IO streams or strings, with `push_string`/`pop_string` for buffered input
- **`@jl_str` macro**: String literal syntax for parsing Julia expressions at compile time
- **Environment-based evaluation**: `Binding` and `Environment` structs with lexical scoping and parent chain lookup
- **Name resolution fallback**: Unresolved names fall back to `KhepriBase` and `Main` modules
- **Compound assignment**: Supports `+=`, `-=`, `*=`, `/=` operations

## Usage

```julia
using KhepriIllustrator

# Parse a Julia expression
expr = julia_read(IOBuffer("sphere(xyz(0,0,0), 5)"))

# Create an evaluation environment
env = create_initial_environment(:r => 5.0, :h => 10.0)
```

## Dependencies

- **KhepriBase**: Core Khepri functionality
- **Test**: Julia standard library (used internally)

```@index
```

```@autodocs
Modules = [KhepriIllustrator]
```

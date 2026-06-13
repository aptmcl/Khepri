# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KhepriThreejs is a Khepri backend that renders 3D geometry in a browser via Three.js. Julia acts as a WebSocket server; the browser client connects and receives binary-encoded draw commands.

## Build & Test Commands

```bash
# Run Julia tests (encoding round-trips, no browser needed)
cd KhepriThreejs && julia --project -e "using Pkg; Pkg.test()"

# Build the TypeScript frontend (required before first use)
cd KhepriThreejs/KhepriThree.js && npm install && npm run build

# Dev server with hot reload
cd KhepriThreejs/KhepriThree.js && npm run dev

# Lint TypeScript
cd KhepriThreejs/KhepriThree.js && npx eslint src/

# Julia REPL for interactive development
cd KhepriThreejs && julia --project
```

## Architecture

### Two-part system

1. **Julia package** (`src/`) — WebSocket backend implementing KhepriBase's `b_*` operations
2. **TypeScript frontend** (`KhepriThree.js/`) — Vite + Three.js app that renders commands received over WebSocket

### Communication flow

```
Julia: sphere(xyz(0,0,0), 5)
  → KhepriBase.b_sphere(b::THR, ...)
  → @remote(b, sphere(...))
  → Binary-encode operation name + args via WebSocket
  → TypeScript: registered typedFunction("sphere", ...) executes in Three.js scene
```

### Key types and naming

- `THRKey` — abstract backend key type
- `THRId = Int32` — reference type for Three.js objects
- `THR = WebSocketBackend{THRKey, THRId}` — the backend type
- Backend alias convention: type `THR`, instance `threejs`

### Binary protocol

Encoding/decoding uses KhepriBase's `encode`/`decode` with namespace `Val(:THR)`, delegating to `Val(:TS)` for primitives. Custom encodings handle `Point3d`, `Vector3d`, `Matrix4x4`, `Frame3d`, and array types. The TypeScript side mirrors this with `Type<T>` classes and `IODataView`.

### Remote API definition

`threejs_api` in `src/Threejs.jl` uses `@remote_api :THR` with inline TypeScript signatures. Each entry maps a Julia remote call to a TypeScript `typedFunction`/`typedAsyncFunction`. Adding a new operation requires:
1. Adding the signature to the `@remote_api` block in `Threejs.jl`
2. Implementing the function body in `KhepriThree.js/src/main.ts`

### Frontend structure

- `KhepriThree.js/src/main.ts` — All Three.js rendering logic, RPC dispatch, scene management
- `KhepriThree.js/dist/` — Built output served by Julia's HTTP handler
- Vite config disables minification and uses stable asset names (no hashes)

### Julia module initialization

`__init__()` in `KhepriThreejs.jl`:
- Sets default material mappings (glass, metal, wood, concrete, etc.)
- Registers HTTP routes to serve the frontend from `KhepriThree.js/dist/`
- Registers `"threejs"` as a WebSocket backend initializer

### Materials

Materials are created via `@remote` calls to Three.js material constructors (`MeshPhysicalMaterial`, `MeshLambertMaterial`, etc.). Default mappings are set in `set_default_materials()`. The `glTF_material` helper loads PBR materials from `resources/materials/`.

### No boolean ops

`has_boolean_ops(::Type{THR}) = HasBooleanOps{false}()` — CSG operations fall back to KhepriBase's mesh-based emulation.

## Shipping Checklist

After modifying TypeScript source:
1. Run `npm run build` in `KhepriThree.js/`
2. Commit both `src/main.ts` changes and `dist/` output

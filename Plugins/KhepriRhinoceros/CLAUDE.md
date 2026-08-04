# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KhepriRhinoceros is a **Rhinoceros 3D plugin** (`.rhp`) that serves as the Rhino backend for the Khepri algorithmic design system. It receives geometry commands from a Julia frontend over a TCP socket (port 12000) and translates them into RhinoCommon API calls.

This is part of the larger Khepri ecosystem where **the same user code must produce equivalent designs across all backends** (Rhino, AutoCAD, Revit, TikZ, etc.). Only the `using KhepriXXX` line changes.

## Build

- **IDE**: Visual Studio (solution file: `KhepriRhinoceros.sln`)
- **Target**: .NET Framework 4.8.1
- **Build configurations**: `Debug64|AnyCPU` (primary), `Debug32`, `Release`
- **Output**: The post-build step renames `KhepriRhinoceros.dll` to `KhepriRhinoceros.rhp` in `KhepriRhinoceros/bin/`
- **Dependency**: References the sibling project `../../KhepriBase/KhepriBase/KhepriBase.csproj` (shared channel/RMI infrastructure)
- **External dependency**: `RhinoCommon.dll` from `C:\Program Files\Rhino 6\System\` (set as Private=False, not copied)
- **No tests** are present in this repository

## Architecture

### Communication Protocol (TCP/RMI)

The Julia frontend connects via TCP to `127.0.0.1:12000`. The protocol uses a custom binary RMI system:

1. **`KhepriBase.Channel`** (in KhepriBase) — Provides binary serialization primitives: `rInt32`/`wInt32`, `rDouble`/`wDouble`, `rString`/`wString`, `rGuid`/`wGuid`, etc. Convention: `r` = read, `w` = write, `e` = error handler.
2. **`Channel.cs`** — Extends `KhepriBase.Channel` with Rhino-specific types: `rPoint3d`/`wPoint3d`, `rVector3d`, `rPlane`, `rRhinoObject`, `wBrep`, etc.
3. **`KhepriRhinocerosChannel.cs`** (in KhepriBase namespace) — The `KhepriChannel` class manages the RMI dispatch loop. Operations are looked up by name via `RMIfy.RMIFor()`, stored in a list, and called by index. `readAndExecute()` reads an operation index, invokes it on the main thread via `sync.Invoke()`, and flushes.
4. **`KhepriRhinocerosCommand.cs`** — The Rhino command `Khepri` that starts the TCP server. Uses idle-loop polling: `AcceptClient` waits for connections, `HandleClient` reads and executes operations. Uses `Processor<Channel, Primitives>` from KhepriBase.
5. **`KhepriRhinocerosPlugIn.cs`** — Auto-starts the `Khepri` command when Rhino loads (via `RhinoApp.Idle` event).

### Primitives (the core API)

**`Primitives.cs`** (~2050 lines) contains all geometry operations exposed to Julia. Methods are discovered by the RMI system via reflection. Key categories:

- **Basic shapes**: `Point`, `PolyLine`, `Spline`, `Circle`, `Ellipse`, `Arc`, `Text`
- **Surfaces**: `SurfaceCircle`, `SurfaceEllipse`, `SurfaceClosedPolyLine`, `SurfaceFromGrid`, `SurfaceFromCurves`
- **Solids**: `Sphere`, `Cylinder`, `Cone`, `ConeFrustum`, `Box`, `XYCenteredBox`, `Torus`, `IrregularPyramid`, `IrregularPyramidFrustum`, `PrismWithHoles`
- **Booleans**: `Unite`, `Intersect`, `Subtract`, `Slice` (with tolerance retry from 1e-5 down to 1e-3)
- **Transforms**: `Move`, `Scale`, `Rotate`, `Mirror`, `Clone`
- **Sweeps/Extrusions**: `Extrusion`, `SweepPathProfile`, `SolidSweepPathProfile`, `PathWall`
- **Curve/Surface queries**: `CurveDomain`, `CurveLength`, `CurveFrameAt`, `SurfaceDomain`, `SurfaceFrameAt`, `Thicken`
- **Materials**: `CreateMaterial`, `LoadRenderMaterialFromPath`, `SetMaterial` — uses `MatId` (alias for `int`) indexing into `renderMaterials` list
- **Rendering**: `Render`, `SaveView`, `SetView`, `View`, `ViewCamera`, `ViewTarget`, `RenderLoadHDRiEnvironment`, `SunLight`, `PointLight`
- **Layers**: `CreateLayer`, `CurrentLayer`, `SetCurrentLayer`, `SetLayerVisible`, `DeleteAllInLayer`
- **BIM furniture**: `BaseRectangularTable`, `BaseChair`, `CreateRectangularTableFamily`, `CreateChairFamily`, `BaseRectangularTableAndChairs` — uses Rhino instance definitions
- **Illustrations**: `CreateLeaderDimension`, `CreateDiametricDimension`, `CreateAngularDimension`
- **Grasshopper**: `EnableGrasshopperSolver`, `DisableGrasshopperSolver`, `RunGrasshopperSolver`
- **Interactive**: `GetPosition`, `GetPoint`, `GetCurve`, `GetSurface`, `GetShape`, `GetAllShapes`
- **Shape introspection**: `ShapeCode`, `BoundingBox`, `IsPoint`, `IsCircle`, `IsPolyLine`, etc.

### Material System

Materials use an index-based system: `renderMaterials` is a `List<RenderMaterial>`, and `MatId` (aliased as `int`) indexes into it. `-1` means no material. The `Add(geometry, mat)` overloads handle attaching materials to newly created objects.

### Key Patterns

- **`AndDelete<R>`** — Helper that deletes source objects after a derived result is computed (common in boolean/sweep operations)
- **`SingletonElement<R>`** — Asserts an array has exactly one element and returns it
- **Boolean tolerance retry** — `Unite`, `Intersect`, `Subtract` all retry with decreasing tolerance (1e-5, 1e-4, 1e-3)
- **Thread marshaling** — All Rhino operations run on the UI thread via `sync.Invoke()` in `KhepriChannel`

## Code Style

- C# with .NET Framework conventions
- Opening braces on the same line
- Heavy use of LINQ for geometry transformations
- Commented-out Python code in `Primitives.cs` serves as reference from the original Rhino Python backend
- Commented-out AutoCAD code serves as reference for porting

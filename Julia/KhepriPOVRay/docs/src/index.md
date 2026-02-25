```@meta
CurrentModule = KhepriPOVRay
```

# KhepriPOVRay

A Khepri backend for [POV-Ray](http://www.povray.org/), producing ray-traced renderings from Khepri scenes.

## Architecture

KhepriPOVRay is an **IOBackend** -- geometry and materials are serialized to a POV-Ray scene file (`.pov`) which is then rendered by the POV-Ray engine.

- **Backend type**: `IOBackend{POVRayKey, POVRayId, Int}` (aliased as `POVRay`)
- **Singleton instance**: `povray`
- **Reference IDs**: `Int` (sequential primitive counter)
- **Coordinate system**: Right-handed Z-up (matches Khepri, no transforms needed)
- **Output format**: POV-Ray scene description language (`.pov`)

## Key Features

- **Scene description generation**: Spheres, boxes, cylinders, cones, prisms, mesh2 surfaces, polygon surfaces
- **Material system**: POV-Ray textures via `povray_definition` and `povray_include`, plus automatic PBR-to-POVRay mapping
- **Predefined materials**: Stone, metal, wood, glass textures from POV-Ray include libraries
- **Lighting**: Point lights, IES lights (approximated), and area lights (approximated)
- **Rendering pipeline**: Automatic POV-Ray invocation with configurable resolution and quality
- **Image analysis**: `rendered_image_area` for post-render analysis of rendered images

## Setup

```julia
using KhepriPOVRay
using KhepriBase

backend(povray)

# Standard Khepri operations
sphere(xyz(0, 0, 0), 5)
set_view(xyz(20, 20, 10), xyz(0, 0, 0))
render_view("my_scene")
```

Requires POV-Ray installed on the system.

## POV-Ray Material Helpers

| Constructor | Description |
|-------------|-------------|
| `povray_material(name; gray, red, green, blue, specularity, roughness)` | Custom texture definition |
| `povray_definition(name, kind, body)` | Inline POV-Ray texture/material definition |
| `povray_include(filename, kind, name)` | Reference to POV-Ray include library texture |

### Predefined Materials

| Material | POV-Ray Source |
|----------|---------------|
| `povray_stone` | `stones2.inc` / `T_Stone35` |
| `povray_metal` | `textures.inc` / `Chrome_Metal` |
| `povray_wood` | `woods.inc` / `T_Wood10` |
| `povray_glass` | `textures.inc` / `M_Glass` |
| `povray_concrete` | Custom granite-based texture |
| `povray_neutral` | Flat gray (0.3) texture |

### Backend-Specific Materials

```julia
mat = standard_material(
  base_color=rgba(0.5, 0.3, 0.2, 1),
  data=BackendParameter(
    POVRay => povray_include("woods.inc", "texture", "T_Wood10")))
```

## Lighting Support

| Light Type | Implementation |
|------------|---------------|
| `pointlight` | Native POV-Ray `light_source` |
| `ieslight` | Approximated as point light |
| `arealight` | Approximated as point light |

## Dependencies

- **KhepriBase**: Core Khepri functionality

```@index
```

```@autodocs
Modules = [KhepriPOVRay]
```

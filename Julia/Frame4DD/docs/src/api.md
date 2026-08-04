# API Reference

## Model Construction

```@docs
Model
add_node!
add_element!
fix_node!
```

## Load Cases

```@docs
add_load_case!
set_gravity!
add_nodal_load!
add_uniform_load!
add_trapezoidal_load!
add_point_load!
add_temperature_load!
add_prescribed_displacement!
```

## Mass

```@docs
add_node_mass!
add_element_extra_mass!
```

## Solving

```@docs
solve
```

## Types

### Geometry and Materials

```@docs
Node
Material
Section
FrameElement
```

### Options

```@docs
AnalysisOptions
ModalOptions
VerticalAxis
ZVertical
YVertical
EigenMethod
SubspaceJacobi
Stodola
```

### Loads

```@docs
GravityLoad
ConcentratedLoad
UniformLoad
TrapezoidalLoad
InternalPointLoad
TemperatureLoad
PrescribedDisplacement
```

### Results

```@docs
AnalysisResults
LoadCaseResults
ModalResults
```

### Other

```@docs
LoadCase
NodeMass
ElementExtraMass
DOFMask
```

# Internals

These are internal functions not part of the public API. They are documented
here for developers and contributors.

## Coordinate Transformation

```@docs
Frame4DD.coord_trans
Frame4DD.build_transformation_matrix
Frame4DD.atma!
Frame4DD.local_to_global!
```

## Element Matrices

```@docs
Frame4DD.elastic_K
Frame4DD.geometric_K
Frame4DD.element_length
Frame4DD.lumped_M
Frame4DD.consistent_M
```

## Assembly

```@docs
Frame4DD.dof_indices
Frame4DD.assemble_K
Frame4DD.assemble_M
Frame4DD.assemble_forces!
```

## Load Processing

```@docs
Frame4DD.compute_gravity_eqf!
Frame4DD.compute_uniform_eqf!
Frame4DD.compute_trapezoidal_eqf!
Frame4DD.compute_point_load_eqf!
Frame4DD.compute_temperature_eqf!
Frame4DD.local_to_global_eqf!
```

## Solver

```@docs
Frame4DD.build_dof_masks
Frame4DD.solve_partitioned
Frame4DD.frame_element_force!
Frame4DD.element_end_forces!
Frame4DD.equilibrium_error
Frame4DD.compute_reaction_forces
Frame4DD.penalize_restrained_dofs!
```

## Modal Analysis

```@docs
Frame4DD.modal_solve
Frame4DD.subspace_iteration
Frame4DD.stodola_method
```

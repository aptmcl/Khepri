# [Tutorial](@id Tutorial)

This tutorial walks through three progressively complex examples:

1. A 2D planar truss
2. A 3D frame with multiple load cases
3. Modal analysis of a 3D structure

## Concepts

Every analysis follows the same workflow:

1. Create a [`Model`](@ref) with [`AnalysisOptions`](@ref)
2. Define geometry: [`add_node!`](@ref), [`add_element!`](@ref)
3. Apply restraints: [`fix_node!`](@ref)
4. Define load cases: [`add_load_case!`](@ref), then add loads
5. Call [`solve`](@ref) to get [`AnalysisResults`](@ref)
6. Read displacements, reactions, and element forces from the results

### Degrees of Freedom

Each node has 6 degrees of freedom (DOFs), numbered sequentially:

| DOF | Direction | Index for node `n` |
|-----|-----------|-------------------|
| dx  | Translation X | `6(n-1) + 1` |
| dy  | Translation Y | `6(n-1) + 2` |
| dz  | Translation Z | `6(n-1) + 3` |
| rx  | Rotation X    | `6(n-1) + 4` |
| ry  | Rotation Y    | `6(n-1) + 5` |
| rz  | Rotation Z    | `6(n-1) + 6` |

For a truss analysis, you still use frame elements — there is no separate truss
element type. A truss is simply a frame where the bending stiffness is small
relative to the axial stiffness, and rotational DOFs are unconstrained.

### Coordinate Systems

Loads on nodes (`add_nodal_load!`, `add_prescribed_displacement!`) use **global**
coordinates. Distributed loads on elements (`add_uniform_load!`,
`add_trapezoidal_load!`, `add_point_load!`, `add_temperature_load!`) use **local
element** coordinates:

- Local x: along the element axis (from node1 to node2)
- Local y and z: perpendicular to the element, determined by the roll angle and
  the vertical axis convention

The default vertical axis is Z (`ZVertical`). Use
`AnalysisOptions(vertical=YVertical)` to switch.

### Element End Forces

Element forces in [`LoadCaseResults`](@ref) are stored as an `nE × 12` matrix.
Each row contains the 12 local end forces for one element:

| Column | Force | Description |
|--------|-------|-------------|
| 1  | Nx1  | Axial force at node 1 |
| 2  | Vy1  | Shear y at node 1 |
| 3  | Vz1  | Shear z at node 1 |
| 4  | Mx1  | Torsion at node 1 |
| 5  | My1  | Bending moment y at node 1 |
| 6  | Mz1  | Bending moment z at node 1 |
| 7  | Nx2  | Axial force at node 2 |
| 8  | Vy2  | Shear y at node 2 |
| 9  | Vz2  | Shear z at node 2 |
| 10 | Mx2  | Torsion at node 2 |
| 11 | My2  | Bending moment y at node 2 |
| 12 | Mz2  | Bending moment z at node 2 |

Sign convention: positive axial force is compression at node 1 (pushes into the
element). Nx1 = -Nx2 for a pure axial member.

---

## Example 1: 2D Planar Truss

A Warren truss with 7 bottom-chord nodes and 5 top-chord nodes:

```
    8---9---10--11--12        y
   /|\ |\ /|\ |\ /|         |
  / | \|/ \| \|/ \|          +--x
 1--2--3---4---5---6---7
```

Bottom chord at y=0, top chord at y=120. Nodes spaced 120 apart in x.
Pin support at node 1 (fixed dx, dy), roller at node 7 (fixed dy).

```julia
using Frame4DD

model = Model()

# Bottom chord nodes (y = 0)
for i in 0:6
  add_node!(model, 120.0 * i, 0.0, 0.0)
end

# Top chord nodes (y = 120)
for i in 1:5
  add_node!(model, 120.0 * i, 120.0, 0.0)
end

# Cross-section and material (steel)
sec = Section(10.0, 1.0, 1.0, 1.0, 1.0, 1.0)
mat = Material(29000.0, 11500.0, 7.33e-7)

# Bottom chord: 1-2, 2-3, ..., 6-7
for i in 1:6
  add_element!(model, i, i + 1, sec, mat)
end

# Top chord: 8-9, 9-10, 10-11, 11-12
for i in 8:11
  add_element!(model, i, i + 1, sec, mat)
end

# Diagonals and verticals
diags = [
  (1,8), (2,8), (2,9), (3,9), (3,10),
  (4,10), (4,11), (5,11), (5,12), (6,12), (6,7)
]
for (n1, n2) in diags
  add_element!(model, n1, n2, sec, mat)
end

# Supports
fix_node!(model, 1; dx=true, dy=true, dz=true, rx=true, ry=true, rz=true)
fix_node!(model, 7; dy=true, dz=true, rx=true, ry=true, rz=true)

# Load case: vertical loads on bottom chord
lc = add_load_case!(model)
add_nodal_load!(lc, 2; fy=-10.0)
add_nodal_load!(lc, 3; fy=-20.0)
add_nodal_load!(lc, 4; fy=-20.0)
add_nodal_load!(lc, 5; fy=-10.0)

# Solve
results = solve(model)

# --- Read results ---

lc1 = results.load_cases[1]

# Displacements at node 4 (midspan)
D = lc1.displacements
node4_dx = D[6*3 + 1]  # DOF 19
node4_dy = D[6*3 + 2]  # DOF 20
println("Node 4 displacement: dx = $node4_dx, dy = $node4_dy")

# Reactions at supports
R = lc1.reactions
println("Node 1 reactions: Fx = $(R[1]), Fy = $(R[2])")
println("Node 7 reactions: Fy = $(R[6*6 + 2])")

# Axial forces in elements (column 1 of element_forces)
Q = lc1.element_forces
for i in 1:size(Q, 1)
  println("Element $i: axial force = $(round(Q[i, 1], digits=4))")
end

# Equilibrium residual (should be near machine epsilon)
println("RMS residual: $(lc1.rms_residual)")
```

## Example 2: 3D Frame with Multiple Load Cases

A 3D inverted pyramid: one free node at the top connected to four fixed base
nodes. Three load cases demonstrate different load types.

```julia
using Frame4DD

model = Model(options=AnalysisOptions(
  shear=true,        # include shear deformation
  geometric=true,    # include P-delta effects (Newton-Raphson)
))

# Node 1: free top node at (0, 0, 120)
add_node!(model, 0.0, 0.0, 120.0; r=0.1)  # r = rigid end zone radius

# Nodes 2-5: fixed base nodes
add_node!(model, -100.0, 0.0, 0.0)
add_node!(model, 100.0, 0.0, 0.0)
add_node!(model, 0.0, -100.0, 0.0)
add_node!(model, 0.0, 100.0, 0.0)

# Cross-section and material
sec = Section(100.0, 60.0, 60.0, 600.0, 200.0, 200.0)
mat = Material(29000.0, 11500.0, 7.33e-7)

# Four elements connecting node 1 to each base node
for n2 in [2, 3, 4, 5]
  add_element!(model, 1, n2, sec, mat)
end

# Fix all base nodes
for n in [2, 3, 4, 5]
  fix_node!(model, n; dx=true, dy=true, dz=true, rx=true, ry=true, rz=true)
end

# --- Load Case 1: Gravity + Concentrated Loads ---
lc1 = add_load_case!(model)
set_gravity!(lc1, 0.0, 0.0, -386.4)
add_nodal_load!(lc1, 1; fx=10.0, fy=-20.0, fz=-30.0, mx=100.0)

# --- Load Case 2: Distributed + Temperature ---
lc2 = add_load_case!(model)
set_gravity!(lc2, 0.0, 0.0, -386.4)

# Uniform load on element 1 (local y and z, force/length)
add_uniform_load!(lc2, 1; uy=1.0, uz=1.5)

# Trapezoidal load on element 2
# Linearly varying in local y from 0 to 100, intensity -0.1 to -0.2
# and in local z from 50 to 150, intensity 0.1 to 0.5
add_trapezoidal_load!(lc2, 2;
  yx1=0.0, yx2=100.0, wy1=-0.1, wy2=-0.2,
  zx1=50.0, zx2=150.0, wz1=0.1, wz2=0.5)

# Temperature load on element 3
add_temperature_load!(lc2, 3;
  alpha=5.5e-6,         # thermal expansion coefficient
  hy=10.0, hz=10.0,     # section depths
  ty_pos=10.0, ty_neg=-10.0,  # temp change at +y and -y fibers
  tz_pos=10.0, tz_neg=-10.0)  # temp change at +z and -z fibers

# --- Load Case 3: Internal Point Loads ---
lc3 = add_load_case!(model)
set_gravity!(lc3, 0.0, 0.0, -386.4)

# Point load at distance a=78.1 from node 1 on elements 1 and 4
add_point_load!(lc3, 1; px=5.0, py=-8.0, pz=-12.0, a=78.1)
add_point_load!(lc3, 4; px=5.0, py=-8.0, pz=-12.0, a=78.1)

# Solve all load cases
results = solve(model)

# --- Read results ---

for (i, lc_result) in enumerate(results.load_cases)
  D = lc_result.displacements
  println("Load case $i:")
  println("  Node 1 displacements:")
  println("    dx = $(D[1]), dy = $(D[2]), dz = $(D[3])")
  println("    rx = $(D[4]), ry = $(D[5]), rz = $(D[6])")
  println("  RMS residual: $(lc_result.rms_residual)")
end
```

### Prescribed Displacements

You can impose known displacements at restrained DOFs. The node must first be
fixed with [`fix_node!`](@ref), then the displacement value is set in the load
case:

```julia
# Fix node 1 in y-direction
fix_node!(model, 1; dy=true)

# In a load case, prescribe dy = -1.0 at node 1
lc = add_load_case!(model)
add_prescribed_displacement!(lc, 1; dy=-1.0)
```

The solver first applies the prescribed displacement, then solves for the
remaining unknowns. The reaction at that DOF reflects the force required to
maintain the prescribed displacement.

## Example 3: Modal Analysis

To compute natural frequencies and mode shapes, pass a [`ModalOptions`](@ref) to
[`AnalysisOptions`](@ref):

```julia
using Frame4DD

model = Model(options=AnalysisOptions(
  shear=true,
  geometric=true,
  modal=ModalOptions(
    6;                       # number of modes to compute
    method=SubspaceJacobi,   # or Stodola
    lumped=true,             # lumped mass matrix (false = consistent)
    tol=1e-9,                # convergence tolerance
    shift=0.0,               # eigenvalue shift
  ),
))

# Geometry (same pyramid as Example 2)
add_node!(model, 0.0, 0.0, 120.0; r=0.1)
add_node!(model, -100.0, 0.0, 0.0)
add_node!(model, 100.0, 0.0, 0.0)
add_node!(model, 0.0, -100.0, 0.0)
add_node!(model, 0.0, 100.0, 0.0)

sec = Section(100.0, 60.0, 60.0, 600.0, 200.0, 200.0)
mat = Material(29000.0, 11500.0, 7.33e-7)

for n2 in [2, 3, 4, 5]
  add_element!(model, 1, n2, sec, mat)
end
for n in [2, 3, 4, 5]
  fix_node!(model, n; dx=true, dy=true, dz=true, rx=true, ry=true, rz=true)
end

# Add lumped mass at the free node
add_node_mass!(model, 1; mass=1.0, Ixx=100.0, Iyy=100.0, Izz=100.0)

# At least one load case is required
lc = add_load_case!(model)
set_gravity!(lc, 0.0, 0.0, -386.4)
add_nodal_load!(lc, 1; fx=10.0, fy=-20.0, fz=-30.0)

# Solve
results = solve(model)

# --- Modal results ---

modal = results.modal
println("Structural mass: $(modal.structural_mass)")
println("Total mass:      $(modal.total_mass)")
println()
for (i, f) in enumerate(modal.frequencies)
  println("Mode $i: $(round(f, digits=3)) Hz")
end

# Mode shapes: modal.mode_shapes is a DoF × nModes matrix
# Each column is one mode shape vector
phi1 = modal.mode_shapes[:, 1]
println("\nMode 1 shape at node 1: ", phi1[1:6])
```

### Eigensolver Methods

Two methods are available via [`EigenMethod`](@ref):

- **`SubspaceJacobi`** (default): Subspace iteration with Jacobi rotation for
  the reduced eigenproblem. Computes all requested modes simultaneously. Good
  for problems where many modes are needed.
- **`Stodola`**: Inverse iteration with deflation. Computes one mode at a time.
  Can be more robust for problems with closely spaced eigenvalues.

### Extra Masses

You can add non-structural mass to nodes or elements:

```julia
# Lumped mass at a node (mass + rotational inertias)
add_node_mass!(model, 1; mass=1.0, Ixx=100.0, Iyy=100.0, Izz=100.0)

# Extra distributed mass on an element
add_element_extra_mass!(model, 3; mass=0.5)
```

These masses are included in both the static gravity loads and the mass matrix
for modal analysis.

## Analysis Options

The [`AnalysisOptions`](@ref) struct controls the analysis:

```julia
AnalysisOptions(
  shear=false,            # shear deformation (Timoshenko beam)
  geometric=false,        # geometric nonlinearity (P-delta)
  vertical=ZVertical,     # vertical axis: ZVertical or YVertical
  tol=1e-9,               # Newton-Raphson convergence tolerance
  modal=nothing,          # nothing, or ModalOptions(...)
  sparse_threshold=200,   # use sparse solver when DoF > this value
)
```

The `sparse_threshold` controls automatic solver selection. Below the threshold,
dense LAPACK routines are used (lower overhead for small problems). Above it,
sparse CHOLMOD is used (dramatically faster for large problems). The default of
200 is a good general choice.

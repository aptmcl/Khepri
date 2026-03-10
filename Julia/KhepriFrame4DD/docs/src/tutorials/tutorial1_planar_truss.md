# Tutorial 1: Planar Truss Analysis

This tutorial introduces structural truss analysis with KhepriFrame4DD by building
and analyzing a **Pratt truss** — the most common roof/bridge truss pattern. You will
learn how to define supports, cross-sections, geometry, loads, and interpret results
including displacements, reaction forces, and element axial forces.

*Inspired by Autodesk Robot Structural Analysis Tutorial 1 (Frame 2D Design).*

## Setting Up

Load the KhepriFrame4DD backend, which registers the Frame4DD structural solver
as a Khepri backend:

```@example tut1
using KhepriFrame4DD
backend(frame4dd)
delete_all_shapes()
nothing # hide
```

## Support Conditions

Truss nodes can be **free** (no constraints) or **supported** (some degrees of
freedom are fixed). Each node has 6 degrees of freedom — 3 translations
(`ux`, `uy`, `uz`) and 3 rotations (`rx`, `ry`, `rz`).

Common support types for trusses:

| Support | Translations fixed | Rotations fixed | Typical use |
|---------|-------------------|-----------------|-------------|
| **Fixed** | `ux, uy, uz` | `rx, ry, rz` | Rigid connection (all 6 DOFs) |
| **Pinned** | `ux, uy, uz` | none | Standard truss support |
| **Free** | none | none | Loaded joints |

We define support families using `truss_node_family_element`:

```@example tut1
fixed = truss_node_family_element(
  default_truss_node_family(),
  support=truss_node_support(ux=true, uy=true, uz=true, rx=true, ry=true, rz=true))

pinned = truss_node_family_element(
  default_truss_node_family(),
  support=truss_node_support(ux=true, uy=true, uz=true))

free = truss_node_family_element(default_truss_node_family())
nothing # hide
```

For our Pratt truss, we use a **fixed** support at the left end (all 6 DOFs
constrained) and a **pinned** support at the right end (translations only).
Since truss bars transmit only axial forces, the rotational constraints at the
fixed support have no practical effect — both supports are equivalent to
structural pins for a truss.

## Cross-Sections

Truss bars use **circular tube** cross-sections defined by outer radius and wall
thickness. The default steel material has:
- Elastic modulus E = 210 GPa
- Shear modulus G = 81 GPa
- Density d = 7701 kg/m³

```@example tut1
bar_family = truss_bar_family_element(
  default_truss_bar_family(),
  radius=0.03,
  inner_radius=0.025)
nothing # hide
```

This defines a tube with outer radius 30 mm and inner radius 25 mm (wall thickness
5 mm). Frame4DD automatically computes the section properties:
- Cross-section area: ``A_x = \pi(R_o^2 - R_i^2)``
- Moments of inertia: ``I_{yy} = I_{zz} = \frac{\pi}{4}(R_o^4 - R_i^4)``
- Torsional constant: ``J_{xx} = \frac{\pi}{2}(R_o^4 - R_i^4)``

## Truss Geometry

A **Pratt truss** has parallel top and bottom chords, vertical members, and
diagonals that slope toward the center. Our truss spans 12 m with 6 bays of
2 m each and a height of 2 m.

```
    2     4     6     8    10
    o-----o-----o-----o-----o        ← top chord (z = 2 m)
   /|    /|    /|    /|    /|\
  / |   / |   / |   / |   / | \
 /  |  /  |  /  |  /  |  /  |  \
o---o-----o-----o-----o-----o---o   ← bottom chord (z = 0)
1   3     5     7     9    11  12
▣                               △
fixed                        pinned
```

Build the nodes — bottom chord at z = 0, top chord at z = 2:

```@example tut1
span = 12.0
n_bays = 6
bay = span / n_bays
height = 2.0

# Bottom chord: 7 nodes at x = 0, 2, 4, ..., 12
bottom_pts = [xyz(i * bay, 0, 0) for i in 0:n_bays]

# Top chord: 5 nodes at x = 2, 4, ..., 10 (no nodes above supports)
top_pts = [xyz(i * bay, 0, height) for i in 1:(n_bays-1)]

# Create nodes with support conditions
truss_node(bottom_pts[1], fixed)            # left support (fixed)
for p in bottom_pts[2:end-1]
  truss_node(p, free)                       # interior bottom nodes
end
truss_node(bottom_pts[end], pinned)         # right support (pinned)
for p in top_pts
  truss_node(p, free)                       # top chord nodes
end

println("Nodes: $(length(bottom_pts) + length(top_pts))")
```

Now connect the bars — bottom chord, top chord, verticals, and diagonals:

```@example tut1
# Bottom chord bars
for i in 1:(length(bottom_pts)-1)
  truss_bar(bottom_pts[i], bottom_pts[i+1], 0, bar_family)
end

# Top chord bars
for i in 1:(length(top_pts)-1)
  truss_bar(top_pts[i], top_pts[i+1], 0, bar_family)
end

# Verticals (from bottom interior nodes to corresponding top nodes)
for i in 1:length(top_pts)
  truss_bar(bottom_pts[i+1], top_pts[i], 0, bar_family)
end

# Diagonals — left half slope right, right half slope left (Pratt pattern)
mid = div(n_bays, 2)
# Left half: diagonals from bottom-left to top-right
for i in 1:mid
  truss_bar(bottom_pts[i], top_pts[i], 0, bar_family)
end
# Right half: diagonals from bottom-right to top-left
for i in mid:(n_bays-1)
  truss_bar(bottom_pts[i+2], top_pts[i], 0, bar_family)
end

n_bars = (length(bottom_pts)-1) + (length(top_pts)-1) + length(top_pts) + (n_bays - 1)
println("Bars: $n_bars")
```

## Applying Loads and Running Analysis

We apply a uniform downward load of 10 kN to each free node. The `truss_analysis`
function takes a **load vector** applied to every non-supported node:

```@example tut1
results = truss_analysis(vz(-10000), false, Dict())
nothing # hide
```

We can visualize the truss using KhepriThebes, a pure-Julia SVG renderer.
Nodes are drawn as spheres and bars as cylinders:

```@example tut1
using KhepriThebes
img_dir = joinpath(dirname(dirname(pathof(KhepriFrame4DD))), "docs", "src", "tutorials", "images")
mkpath(img_dir)
backend(thebes)
delete_all_shapes()
set_view(xyz(6, -20, 5), xyz(6, 0, 1))
green_mat = standard_material(base_color=rgba(0.2, 0.7, 0.2, 1))
for nd in frame4dd.truss_node_data
  sphere(nd.loc, 0.15, material=green_mat)
end
for bar in frame4dd.truss_bar_data
  cylinder(bar.node1.loc, 0.05, bar.node2.loc, material=green_mat)
end
with(render_dir, img_dir) do
  with(render_kind_dir, ".") do
    render_view("tut1_structure")
  end
end
```

```@example tut1
backend(frame4dd)
nothing # hide
```

The solver:
1. Assembles the global stiffness matrix from all element contributions
2. Applies boundary conditions (fixed DOFs)
3. Adds nodal loads (10 kN downward on each free node)
4. Solves the linear system ``[K]\{u\} = \{F\}``
5. Computes reaction forces and element end forces

## Displacement Results

The `node_displacement_function` returns a closure that maps any `TrussNodeData`
to its displacement vector:

```@example tut1
disp = node_displacement_function(results)

println("Node displacements (mm):")
println("─" ^ 50)
for nd in frame4dd.truss_node_data
  d = disp(nd)
  label = truss_node_is_supported(nd) ? " (support)" : ""
  println("  Node $(nd.id) at $(nd.loc): " *
          "dx=$(round(d.x*1000, digits=3)), " *
          "dy=$(round(d.y*1000, digits=3)), " *
          "dz=$(round(d.z*1000, digits=3))$label")
end
```

The **maximum displacement** is a key design metric:

```@example tut1
max_d = max_displacement(results)
println("Maximum displacement: $(round(max_d * 1000, digits=3)) mm")
println("Span/deflection ratio: $(round(span / max_d, digits=0))")
```

A common design criterion is span/deflection > 300. If our ratio is too low,
we need stiffer sections or a deeper truss.

## Reaction Forces

The `reaction_forces` function returns a dictionary mapping supported node IDs
to their reaction force vectors:

```@example tut1
reactions = reaction_forces(results)

println("Reaction forces (kN):")
println("─" ^ 50)
for (id, r) in sort(collect(reactions), by=first)
  println("  Node $id: " *
          "Rx=$(round(r.x/1000, digits=2)) kN, " *
          "Ry=$(round(r.y/1000, digits=2)) kN, " *
          "Rz=$(round(r.z/1000, digits=2)) kN")
end
```

We can verify **static equilibrium** — the sum of reactions must equal the total
applied load:

```@example tut1
n_free = count(!truss_node_is_supported, frame4dd.truss_node_data)
total_applied = n_free * 10000  # 10 kN per free node

total_rz = sum(r.z for r in values(reactions))
total_rx = sum(r.x for r in values(reactions))

println("Total applied load (downward): $(total_applied / 1000) kN")
println("Total vertical reaction: $(round(total_rz / 1000, digits=2)) kN")
println("Total horizontal reaction: $(round(total_rx / 1000, digits=2)) kN")
println("Equilibrium check: ΣFz error = $(round(abs(total_rz - total_applied), digits=6)) N")
```

Both supports are pinned (all translations fixed), so horizontal reactions may
appear at either end to maintain equilibrium.

## Element Axial Forces

The `element_axial_forces` function returns the axial force in each bar.
**Positive values indicate tension**, negative indicate **compression**:

```@example tut1
forces = element_axial_forces(results)

println("Element axial forces (kN):")
println("─" ^ 60)
for (i, bar) in enumerate(frame4dd.truss_bar_data)
  f = forces[i]
  state = f > 100 ? "TENSION" : (f < -100 ? "COMPRESSION" : "~zero")
  println("  Bar $i ($(bar.node1.id)→$(bar.node2.id)): " *
          "N = $(round(f/1000, digits=2)) kN  [$state]")
end
```

In a Pratt truss under gravity-like loads:
- **Bottom chord**: tension (positive)
- **Top chord**: compression (negative)
- **Verticals**: compression near supports, tension near midspan
- **Diagonals**: alternating tension/compression

## Visualizing Deformation

KhepriFrame4DD includes a built-in deformation visualization that works with any
Khepri visualization backend. Using `show_truss_deformation`, the original structure
is shown in green and the deformed shape (amplified) in red:

```julia
using KhepriAutoCAD  # or KhepriThebes, KhepriMakie, etc.
show_truss_deformation(results, autocad, factor=200)
```

For a text-based comparison, we can show the deformed node positions directly:

```@example tut1
disp = node_displacement_function(results)
factor = 200

println("Deformed positions (factor=$(factor)×):")
println("─" ^ 50)
for nd in frame4dd.truss_node_data
  d = disp(nd) * factor
  p = nd.loc
  println("  Node $(nd.id): ($(round(p.x + d.x, digits=3)), " *
          "$(round(p.y + d.y, digits=3)), " *
          "$(round(p.z + d.z, digits=3)))")
end
```

We can overlay the deformed shape (red) on the original structure (green):

```@example tut1
backend(thebes)
delete_all_shapes()
set_view(xyz(6, -20, 5), xyz(6, 0, 1))
green_mat = standard_material(base_color=rgba(0.2, 0.7, 0.2, 1))
red_mat = standard_material(base_color=rgba(0.8, 0.2, 0.2, 1))
disp = node_displacement_function(results, frame4dd)
factor = 200
for nd in frame4dd.truss_node_data
  sphere(nd.loc, 0.15, material=green_mat)
end
for bar in frame4dd.truss_bar_data
  cylinder(bar.node1.loc, 0.05, bar.node2.loc, material=green_mat)
end
for nd in frame4dd.truss_node_data
  d = disp(nd) * factor
  sphere(nd.loc + d, 0.15, material=red_mat)
end
for bar in frame4dd.truss_bar_data
  d1 = disp(bar.node1) * factor
  d2 = disp(bar.node2) * factor
  cylinder(bar.node1.loc + d1, 0.05, bar.node2.loc + d2, material=red_mat)
end
with(render_dir, img_dir) do
  with(render_kind_dir, ".") do
    render_view("tut1_deformation")
  end
end
```

```@example tut1
backend(frame4dd)
nothing # hide
```

## Self-Weight Analysis

Real structures must carry their own weight. Re-run the analysis with
`self_weight=true`:

```@example tut1
delete_all_shapes()
backend(frame4dd)

# Recreate the same truss geometry
bottom_pts = [xyz(i * bay, 0, 0) for i in 0:n_bays]
top_pts = [xyz(i * bay, 0, height) for i in 1:(n_bays-1)]

truss_node(bottom_pts[1], fixed)
for p in bottom_pts[2:end-1]; truss_node(p, free); end
truss_node(bottom_pts[end], pinned)
for p in top_pts; truss_node(p, free); end

for i in 1:(length(bottom_pts)-1)
  truss_bar(bottom_pts[i], bottom_pts[i+1], 0, bar_family)
end
for i in 1:(length(top_pts)-1)
  truss_bar(top_pts[i], top_pts[i+1], 0, bar_family)
end
for i in 1:length(top_pts)
  truss_bar(bottom_pts[i+1], top_pts[i], 0, bar_family)
end
mid = div(n_bays, 2)
for i in 1:mid
  truss_bar(bottom_pts[i], top_pts[i], 0, bar_family)
end
for i in mid:(n_bays-1)
  truss_bar(bottom_pts[i+2], top_pts[i], 0, bar_family)
end

# Analysis with external loads + self-weight
results_sw = truss_analysis(vz(-10000), true, Dict())
max_sw = max_displacement(results_sw)

println("Without self-weight: $(round(max_d * 1000, digits=3)) mm")
println("With self-weight:    $(round(max_sw * 1000, digits=3)) mm")
println("Self-weight adds:    $(round((max_sw - max_d) / max_d * 100, digits=1))%")
```

## Parametric Study: Section Size

One advantage of programmatic modeling is easy parametric studies. Let's see how
the tube radius affects stiffness:

```@example tut1
println("Radius (mm) | Max displacement (mm) | Span/deflection")
println("─" ^ 55)

for r in [0.02, 0.025, 0.03, 0.04, 0.05]
  delete_all_shapes()
  backend(frame4dd)

  fam = truss_bar_family_element(
    default_truss_bar_family(),
    radius=r,
    inner_radius=r - 0.005)

  bottom_pts = [xyz(i * bay, 0, 0) for i in 0:n_bays]
  top_pts = [xyz(i * bay, 0, height) for i in 1:(n_bays-1)]

  truss_node(bottom_pts[1], fixed)
  for p in bottom_pts[2:end-1]; truss_node(p, free); end
  truss_node(bottom_pts[end], pinned)
  for p in top_pts; truss_node(p, free); end

  for i in 1:(length(bottom_pts)-1)
    truss_bar(bottom_pts[i], bottom_pts[i+1], 0, fam)
  end
  for i in 1:(length(top_pts)-1)
    truss_bar(top_pts[i], top_pts[i+1], 0, fam)
  end
  for i in 1:length(top_pts)
    truss_bar(bottom_pts[i+1], top_pts[i], 0, fam)
  end
  mid = div(n_bays, 2)
  for i in 1:mid
    truss_bar(bottom_pts[i], top_pts[i], 0, fam)
  end
  for i in mid:(n_bays-1)
    truss_bar(bottom_pts[i+2], top_pts[i], 0, fam)
  end

  res = truss_analysis(vz(-10000))
  md = max_displacement(res)
  println("  $(round(r*1000, digits=0))          | " *
          "$(round(md*1000, digits=3))               | " *
          "$(round(span/md, digits=0))")
end
```

Increasing the tube radius dramatically increases stiffness (displacement scales
roughly as ``1/r^3`` for thin-walled tubes).

## Limitations vs. Robot Structural Analysis

| Robot Feature | KhepriFrame4DD Status | Possible Extension |
|---|---|---|
| I-beam / HEA / IPE sections | Only circular tubes | Add rectangular/I-section geometry calculators |
| Bending moment diagrams | N/A for trusses | Element end forces available in solver |
| Distributed loads on bars | Solver supports, wrapper doesn't expose | Expose `Frame4DD.add_uniform_load!` |
| Steel design code checks | Not available | Future: Eurocode 3 / AISC verification |
| Interactive graphical model editor | Programmatic only | Khepri's strength is parametric scripting |

## Summary

In this tutorial you learned to:
1. Define support conditions (fixed, pinned, free)
2. Create tube cross-sections with specified radius and wall thickness
3. Build a Pratt truss from parametric geometry
4. Run a structural analysis with nodal loads
5. Extract and interpret displacements, reaction forces, and axial forces
6. Verify static equilibrium from reaction forces
7. Include self-weight effects
8. Perform parametric studies by varying section properties

The next tutorial builds on these skills with a Warren truss bridge under multiple
load scenarios.

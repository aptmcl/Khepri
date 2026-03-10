# Tutorial 2: Warren Truss Bridge with Multiple Load Scenarios

This tutorial builds a **Warren truss bridge** using a parametric generator function,
then analyzes it under four different load scenarios — dead load, self-weight,
midspan point load, and lateral wind. You will learn to compare results across
scenarios, visualize axial force distributions, and perform a parametric study
on truss depth.

*Inspired by Autodesk Robot Structural Analysis Tutorial 2 (Building Design).*

## Setting Up

```@example tut2
using KhepriFrame4DD
nothing # hide
```

## Parametric Warren Truss

A **Warren truss** has diagonal members alternating in orientation, forming a
zig-zag pattern without vertical members. This is structurally efficient and
commonly used in bridge design.

```
  1     2     3     4     5     6     7     8     9    10
  o─────o─────o─────o─────o─────o─────o─────o─────o─────o    ← top chord
 / \   / \   / \   / \   / \   / \   / \   / \   / \   / \
/   \ /   \ /   \ /   \ /   \ /   \ /   \ /   \ /   \ /   \
o─────o─────o─────o─────o─────o─────o─────o─────o─────o─────o ← bottom chord
▣                                                            △
fixed                                                     pinned
```

We define a reusable function that generates the complete Warren truss:

```@example tut2
function warren_truss(n_bays, bay_length, height;
                      bar_fam=nothing, fixed_fam=nothing,
                      pinned_fam=nothing, free_fam=nothing)
  # Default families
  if bar_fam === nothing
    bar_fam = truss_bar_family_element(
      default_truss_bar_family(), radius=0.03, inner_radius=0.025)
  end
  if fixed_fam === nothing
    fixed_fam = truss_node_family_element(
      default_truss_node_family(),
      support=truss_node_support(ux=true, uy=true, uz=true, rx=true, ry=true, rz=true))
  end
  if pinned_fam === nothing
    pinned_fam = truss_node_family_element(
      default_truss_node_family(),
      support=truss_node_support(ux=true, uy=true, uz=true))
  end
  if free_fam === nothing
    free_fam = truss_node_family_element(default_truss_node_family())
  end

  span = n_bays * bay_length

  # Bottom chord nodes: n_bays + 1 nodes
  bottom = [xyz(i * bay_length, 0, 0) for i in 0:n_bays]
  # Top chord nodes: at midpoints of each bay
  top = [xyz((i + 0.5) * bay_length, 0, height) for i in 0:(n_bays-1)]

  # Create nodes
  truss_node(bottom[1], fixed_fam)
  for p in bottom[2:end-1]
    truss_node(p, free_fam)
  end
  truss_node(bottom[end], pinned_fam)
  for p in top
    truss_node(p, free_fam)
  end

  # Bottom chord bars
  for i in 1:(length(bottom)-1)
    truss_bar(bottom[i], bottom[i+1], 0, bar_fam)
  end
  # Top chord bars
  for i in 1:(length(top)-1)
    truss_bar(top[i], top[i+1], 0, bar_fam)
  end
  # Diagonals: each top node connects to two adjacent bottom nodes
  for i in 1:length(top)
    truss_bar(bottom[i], top[i], 0, bar_fam)
    truss_bar(top[i], bottom[i+1], 0, bar_fam)
  end

  (bottom=bottom, top=top)
end
nothing # hide
```

Generate a 10-bay Warren truss, 30 m span, 2 m height:

```@example tut2
backend(frame4dd)
delete_all_shapes()
pts = warren_truss(10, 3.0, 2.0)

println("Bridge geometry:")
println("  Span: 30 m")
println("  Height: 2 m")
println("  Bottom chord nodes: $(length(pts.bottom))")
println("  Top chord nodes: $(length(pts.top))")
println("  Total nodes: $(length(pts.bottom) + length(pts.top))")
n_bars = (length(pts.bottom)-1) + (length(pts.top)-1) + 2*length(pts.top)
println("  Total bars: $n_bars")
```

## Scenario 1: Uniform Dead Load

Apply a uniform 5 kN downward load to all free nodes, representing the bridge deck
and permanent fixtures:

```@example tut2
results_dead = truss_analysis(vz(-5000))
max_dead = max_displacement(results_dead)
println("Scenario 1 — Dead load (5 kN/node):")
println("  Max displacement: $(round(max_dead * 1000, digits=3)) mm")
println("  Span/deflection: $(round(30.0 / max_dead, digits=0))")
```

### Visualizing the Bridge

```@example tut2
using KhepriThebes
img_dir = joinpath(dirname(dirname(pathof(KhepriFrame4DD))), "docs", "src", "tutorials", "images")
mkpath(img_dir)
backend(thebes)
delete_all_shapes()
set_view(xyz(15, -40, 8), xyz(15, 0, 1))
green_mat = standard_material(base_color=rgba(0.2, 0.7, 0.2, 1))
for nd in frame4dd.truss_node_data
  sphere(nd.loc, 0.2, material=green_mat)
end
for bar in frame4dd.truss_bar_data
  cylinder(bar.node1.loc, 0.06, bar.node2.loc, material=green_mat)
end
with(render_dir, img_dir) do
  with(render_kind_dir, ".") do
    render_view("tut2_structure")
  end
end
```

```@example tut2
backend(frame4dd)
nothing # hide
```

## Scenario 2: Self-Weight Only

Re-create the truss and analyze under self-weight only (no external loads):

```@example tut2
delete_all_shapes()
backend(frame4dd)
warren_truss(10, 3.0, 2.0)

results_sw = truss_analysis(vz(0), true, Dict())
max_sw = max_displacement(results_sw)
println("Scenario 2 — Self-weight only:")
println("  Max displacement: $(round(max_sw * 1000, digits=3)) mm")
println("  Span/deflection: $(round(30.0 / max_sw, digits=0))")
```

## Scenario 3: Midspan Point Load

A heavy vehicle or concentrated load at the bridge midspan (x = 15 m). We apply
50 kN at the midspan bottom-chord node:

```@example tut2
delete_all_shapes()
backend(frame4dd)
warren_truss(10, 3.0, 2.0)

midspan_pt = xyz(15.0, 0, 0)
results_point = truss_analysis(vz(0), false, Dict(vz(-50000) => [midspan_pt]))
max_point = max_displacement(results_point)
println("Scenario 3 — 50 kN midspan point load:")
println("  Max displacement: $(round(max_point * 1000, digits=3)) mm")
println("  Span/deflection: $(round(30.0 / max_point, digits=0))")
```

## Scenario 4: Lateral Wind Load

Wind applies horizontal forces to the top chord nodes. We model a 2 kN horizontal
force on each top chord node:

```@example tut2
delete_all_shapes()
backend(frame4dd)
warren_truss(10, 3.0, 2.0)

results_wind = truss_analysis(vx(2000))
max_wind = max_displacement(results_wind)
println("Scenario 4 — Lateral wind (2 kN/node horizontal):")
println("  Max displacement: $(round(max_wind * 1000, digits=3)) mm")
```

## Results Comparison

```@example tut2
println("╔══════════════════════════════════════════════════╗")
println("║       Load Scenario Comparison (30 m span)      ║")
println("╠═══════════════════════╦════════════╦═════════════╣")
println("║ Scenario              ║ Max disp.  ║ Span/defl.  ║")
println("╠═══════════════════════╬════════════╬═════════════╣")
for (name, md) in [("Dead load (5 kN)", max_dead),
                    ("Self-weight",       max_sw),
                    ("Midspan 50 kN",     max_point),
                    ("Lateral wind 2 kN", max_wind)]
  d_mm = round(md * 1000, digits=2)
  ratio = round(30.0 / md, digits=0)
  println("║ $(rpad(name, 22))║ $(lpad("$d_mm mm", 10)) ║ $(lpad(ratio, 11)) ║")
end
println("╚═══════════════════════╩════════════╩═════════════╝")
```

## Reaction Forces Comparison

```@example tut2
# Re-run dead load scenario for reaction analysis
delete_all_shapes()
backend(frame4dd)
warren_truss(10, 3.0, 2.0)
results_dead = truss_analysis(vz(-5000))

reactions_dead = reaction_forces(results_dead)
println("Dead load reactions:")
for (id, r) in sort(collect(reactions_dead), by=first)
  println("  Node $id: Rx=$(round(r.x/1000, digits=2)) kN, " *
          "Rz=$(round(r.z/1000, digits=2)) kN")
end

# Midspan point load reactions
delete_all_shapes()
backend(frame4dd)
warren_truss(10, 3.0, 2.0)
results_point = truss_analysis(vz(0), false, Dict(vz(-50000) => [xyz(15.0, 0, 0)]))

reactions_point = reaction_forces(results_point)
println("\nMidspan point load reactions:")
for (id, r) in sort(collect(reactions_point), by=first)
  println("  Node $id: Rx=$(round(r.x/1000, digits=2)) kN, " *
          "Rz=$(round(r.z/1000, digits=2)) kN")
end
```

For the symmetric midspan load, both supports should carry approximately equal
vertical reactions (25 kN each for a 50 kN load).

## Axial Force Distribution

Understanding which members are in tension vs. compression is essential for
design. Let's examine the dead load case:

```@example tut2
forces_dead = element_axial_forces(results_dead)

# Categorize bars by type based on their geometry
println("Axial forces by member type (dead load):")
println("─" ^ 60)

for (i, bar) in enumerate(frame4dd.truss_bar_data)
  f = forces_dead[i]
  # Determine bar type from node positions
  z1 = bar.node1.loc.z
  z2 = bar.node2.loc.z
  bar_type = if z1 ≈ z2 && z1 ≈ 0
    "bottom"
  elseif z1 ≈ z2 && z1 > 0
    "top   "
  else
    "diag  "
  end
  state = f > 100 ? "T" : (f < -100 ? "C" : "~")
  println("  Bar $(lpad(i, 2)) ($bar_type, $(bar.node1.id)→$(bar.node2.id)): " *
          "$(lpad(round(f/1000, digits=2), 8)) kN  [$state]")
end
```

For a Warren truss under uniform load:
- **Bottom chord** members are in **tension** (T), increasing toward midspan
- **Top chord** members are in **compression** (C), increasing toward midspan
- **Diagonals** alternate between tension and compression

## Parametric Study: Truss Depth

The depth (height) of a truss critically affects its stiffness. Deeper trusses
are stiffer because the chord forces decrease (larger moment arm) and the
overall moment of inertia increases.

```@example tut2
println("Height (m) | Max disp. (mm) | Span/defl. | Max axial (kN)")
println("─" ^ 60)

for h in [1.0, 1.5, 2.0, 2.5, 3.0, 4.0]
  delete_all_shapes()
  backend(frame4dd)
  warren_truss(10, 3.0, h)

  res = truss_analysis(vz(-5000))
  md = max_displacement(res)
  af = element_axial_forces(res)
  max_force = maximum(abs, af)

  println("  $(rpad(h, 10)) | " *
          "$(lpad(round(md * 1000, digits=2), 14)) | " *
          "$(lpad(round(30.0 / md, digits=0), 10)) | " *
          "$(lpad(round(max_force / 1000, digits=1), 13))")
end
```

Observations:
- Doubling the truss depth approximately halves the maximum chord force
- Displacement decreases dramatically with depth (roughly proportional to ``1/h^2``)
- Diminishing returns beyond a certain depth, and taller trusses use more material
  in longer diagonal members

## Deformation Visualization

For visualization with any Khepri backend (AutoCAD, Thebes, Makie, etc.):

```julia
using KhepriAutoCAD  # or any visualization backend
show_truss_deformation(results_dead, autocad, factor=200)
```

Text-based deformation summary for our dead load case:

```@example tut2
delete_all_shapes()
backend(frame4dd)
warren_truss(10, 3.0, 2.0)
results_dead = truss_analysis(vz(-5000))

disp = node_displacement_function(results_dead)

println("Bottom chord vertical deflections (dead load):")
println("─" ^ 45)
for nd in frame4dd.truss_node_data
  if nd.loc.z ≈ 0
    d = disp(nd)
    println("  x = $(rpad(round(nd.loc.x, digits=1), 5)) m: " *
            "δz = $(round(d.z * 1000, digits=3)) mm")
  end
end
```

The deflection profile should follow a parabolic shape, with maximum deflection
at midspan — consistent with beam bending theory.

The deformed shape (red) overlaid on the original structure (green):

```@example tut2
backend(thebes)
delete_all_shapes()
set_view(xyz(15, -40, 8), xyz(15, 0, 1))
green_mat = standard_material(base_color=rgba(0.2, 0.7, 0.2, 1))
red_mat = standard_material(base_color=rgba(0.8, 0.2, 0.2, 1))
disp = node_displacement_function(results_dead, frame4dd)
factor = 200
for nd in frame4dd.truss_node_data
  sphere(nd.loc, 0.2, material=green_mat)
end
for bar in frame4dd.truss_bar_data
  cylinder(bar.node1.loc, 0.06, bar.node2.loc, material=green_mat)
end
for nd in frame4dd.truss_node_data
  d = disp(nd) * factor
  sphere(nd.loc + d, 0.2, material=red_mat)
end
for bar in frame4dd.truss_bar_data
  d1 = disp(bar.node1) * factor
  d2 = disp(bar.node2) * factor
  cylinder(bar.node1.loc + d1, 0.06, bar.node2.loc + d2, material=red_mat)
end
with(render_dir, img_dir) do
  with(render_kind_dir, ".") do
    render_view("tut2_deformation")
  end
end
```

```@example tut2
backend(frame4dd)
nothing # hide
```

## Limitations vs. Robot Structural Analysis

| Robot Feature | KhepriFrame4DD Status | Possible Extension |
|---|---|---|
| Seismic/modal analysis | Solver supports modal analysis | Expose `ModalOptions`/`ModalResults` |
| Load combinations (ULS/SLS) | Single load case at a time | Support multiple load cases (solver already can) |
| Floor/deck plate elements | Not available | Future: panel elements |
| Automatic meshing | Manual node/bar creation | Future: mesh generators |
| Moving load analysis | Not available | Sweep point loads across span |

## Summary

In this tutorial you learned to:
1. Create a parametric truss generator function for reuse
2. Model a Warren truss bridge with proper supports
3. Analyze multiple load scenarios: dead, self-weight, point, and lateral loads
4. Compare results across scenarios using displacements and reactions
5. Examine axial force distributions to identify critical members
6. Study the effect of truss depth on structural performance

The next tutorial extends to 3D with a space truss tower.

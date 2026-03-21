# Tutorial 4: Flat Truss Grid (Space Frame Deck)

This tutorial models a **space-frame deck** — a flat structure made of two
parallel grids of bars connected by verticals and diagonals. This is a truss
analogue of a plate element, commonly used for large-span roofs, exhibition
halls, and stadiums. You will learn about tributary area load distribution,
compare results with analytical plate solutions, and study mesh convergence.

*Inspired by Autodesk Robot Structural Analysis Tutorial 4 (Plate Design).*

## Setting Up

```@example tut4
using KhepriFrame4DD
nothing # hide
```

## Space Frame Deck Generator

A space frame deck consists of:
- **Bottom chord grid**: rectangular grid of bars at z = 0
- **Top chord grid**: matching grid at z = depth
- **Verticals**: connecting corresponding top and bottom nodes
- **Diagonals**: connecting each bottom node to its 4 neighboring top nodes

```
  Top view:                    Side view:
  o───o───o───o───o            o───o───o───o───o  ← top (z = depth)
  │ × │ × │ × │ × │            │ / │ / │ / │ / │
  o───o───o───o───o            o───o───o───o───o  ← bottom (z = 0)
  │ × │ × │ × │ × │
  o───o───o───o───o
  │ × │ × │ × │ × │
  o───o───o───o───o
```

```@example tut4
function space_frame_deck(Lx, Ly, depth, nx, ny;
                          bar_fam=nothing, pinned_fam=nothing, free_fam=nothing)
  if bar_fam === nothing
    bar_fam = truss_bar_family_element(
      default_truss_bar_family(), radius=0.03, inner_radius=0.025)
  end
  if pinned_fam === nothing
    pinned_fam = truss_node_family_element(
      default_truss_node_family(),
      support=truss_node_support(ux=true, uy=true, uz=true))
  end
  if free_fam === nothing
    free_fam = truss_node_family_element(default_truss_node_family())
  end

  dx = Lx / nx
  dy = Ly / ny

  # Helper to check if a bottom node is on the edge (simply supported)
  is_edge(i, j) = (i == 0 || i == nx || j == 0 || j == ny)

  # Create bottom chord nodes
  bottom = Matrix{Any}(undef, nx+1, ny+1)
  for i in 0:nx, j in 0:ny
    p = xyz(i * dx, j * dy, 0)
    fam = is_edge(i, j) ? pinned_fam : free_fam
    truss_node(p, fam)
    bottom[i+1, j+1] = p
  end

  # Create top chord nodes (all free)
  top = Matrix{Any}(undef, nx+1, ny+1)
  for i in 0:nx, j in 0:ny
    p = xyz(i * dx, j * dy, depth)
    truss_node(p, free_fam)
    top[i+1, j+1] = p
  end

  # Bottom chord grid bars
  for i in 1:nx, j in 0:ny
    truss_bar(bottom[i, j+1], bottom[i+1, j+1], 0, bar_fam)
  end
  for i in 0:nx, j in 1:ny
    truss_bar(bottom[i+1, j], bottom[i+1, j+1], 0, bar_fam)
  end

  # Top chord grid bars
  for i in 1:nx, j in 0:ny
    truss_bar(top[i, j+1], top[i+1, j+1], 0, bar_fam)
  end
  for i in 0:nx, j in 1:ny
    truss_bar(top[i+1, j], top[i+1, j+1], 0, bar_fam)
  end

  # Verticals
  for i in 0:nx, j in 0:ny
    truss_bar(bottom[i+1, j+1], top[i+1, j+1], 0, bar_fam)
  end

  # Diagonals: connect each bottom node to neighboring top nodes
  for i in 1:nx, j in 1:ny
    truss_bar(bottom[i, j],     top[i+1, j+1], 0, bar_fam)
    truss_bar(bottom[i+1, j+1], top[i, j],     0, bar_fam)
  end

  (bottom=bottom, top=top, dx=dx, dy=dy, nx=nx, ny=ny)
end
nothing # hide
```

Build an 8 m × 6 m deck with 0.5 m depth and 1 m grid spacing:

```@example tut4
backend(frame4dd)
delete_all_shapes()
deck = space_frame_deck(8.0, 6.0, 0.5, 8, 6)

n_nodes = length(frame4dd.truss_nodes)
n_bars = length(frame4dd.truss_bars)
println("Space frame deck:")
println("  Dimensions: 8 m × 6 m × 0.5 m deep")
println("  Grid spacing: $(deck.dx) m × $(deck.dy) m")
println("  Nodes: $n_nodes")
println("  Bars: $n_bars")
```

## Edge Supports

The deck is **simply supported** on all edges — every bottom-chord node on the
perimeter has its translations fixed:

```@example tut4
n_supported = count(truss_node_is_supported, frame4dd.truss_node_data)
n_edge = 2 * (deck.nx + deck.ny)  # perimeter nodes (not counting corners twice)
println("Supported nodes: $n_supported")
println("Perimeter nodes: $(2*(deck.nx + 1) + 2*(deck.ny - 1))")
```

## Tributary Area Loads

To simulate a uniform surface load (e.g., 5 kN/m²), we must convert the
distributed pressure to equivalent point loads using **tributary areas**.

Each interior node "collects" load from the surrounding grid cells:
- Interior node: ``F = q \times \Delta x \times \Delta y``
- Edge node: ``F = q \times \frac{\Delta x}{2} \times \Delta y`` (or similar)
- Corner node: ``F = q \times \frac{\Delta x}{2} \times \frac{\Delta y}{2}``

```@example tut4
q = 5000.0  # 5 kN/m² surface load

# Compute tributary area for each bottom chord node
# Only apply load to non-supported (interior) nodes
point_loads = Dict{Any, Vector{Any}}()
for i in 0:deck.nx, j in 0:deck.ny
  # Tributary widths in x and y
  wx = if i == 0 || i == deck.nx
    deck.dx / 2
  else
    deck.dx
  end
  wy = if j == 0 || j == deck.ny
    deck.dy / 2
  else
    deck.dy
  end

  F = q * wx * wy
  p = deck.bottom[i+1, j+1]
  load = vz(-F)
  if haskey(point_loads, load)
    push!(point_loads[load], p)
  else
    point_loads[load] = [p]
  end
end

total_load = q * 8.0 * 6.0
println("Uniform load: $(q/1000) kN/m²")
println("Total load on deck: $(total_load/1000) kN")
println("Tributary load groups: $(length(point_loads))")
```

## Analysis

```@example tut4
results = truss_analysis(vz(0), false, point_loads)
max_d = max_displacement(results)
println("Maximum displacement: $(round(max_d * 1000, digits=3)) mm")
```

### Visualizing the Deck

```@example tut4
using KhepriThebes
img_dir = joinpath(dirname(dirname(pathof(KhepriFrame4DD))), "docs", "src", "tutorials", "images")
mkpath(img_dir)
backend(thebes)
delete_all_shapes()
set_view(xyz(15, 15, 10), xyz(4, 3, 0.25))
green_mat = material(base_color=rgba(0.2, 0.7, 0.2, 1))
for nd in frame4dd.truss_node_data
  sphere(nd.loc, 0.08, material=green_mat)
end
for bar in frame4dd.truss_bar_data
  cylinder(bar.node1.loc, 0.02, bar.node2.loc, material=green_mat)
end
with(render_dir, img_dir) do
  with(render_kind_dir, ".") do
    render_view("tut4_structure")
  end
end
```

```@example tut4
backend(frame4dd)
nothing # hide
```

## Displacement Map

We display the vertical displacement of each bottom-chord node as a grid,
showing the bowl-shaped deflection pattern:

```@example tut4
disp = node_displacement_function(results)

println("Vertical displacement map (mm) — bottom chord nodes:")
println("y\\x ", join([lpad(round(i * deck.dx, digits=0), 7) for i in 0:deck.nx]))
println("─" ^ (8 + 7 * (deck.nx + 1)))

for j in deck.ny:-1:0
  row = []
  for i in 0:deck.nx
    # Find the node at this grid position
    nd = nothing
    target = xyz(i * deck.dx, j * deck.dy, 0)
    for n in frame4dd.truss_node_data
      if n.loc.x ≈ target.x && n.loc.y ≈ target.y && n.loc.z ≈ 0.0
        nd = n
        break
      end
    end
    if nd !== nothing
      d = disp(nd)
      push!(row, lpad(round(d.z * 1000, digits=2), 7))
    else
      push!(row, lpad("?", 7))
    end
  end
  println(lpad(round(j * deck.dy, digits=0), 3), " ", join(row))
end
```

The displacement pattern should be symmetric and bowl-shaped, with maximum
deflection at the center — matching the behavior of a simply-supported plate.

The deformed deck (red) overlaid on the original structure (green):

```@example tut4
backend(thebes)
delete_all_shapes()
set_view(xyz(15, 15, 10), xyz(4, 3, 0.25))
green_mat = material(base_color=rgba(0.2, 0.7, 0.2, 1))
red_mat = material(base_color=rgba(0.8, 0.2, 0.2, 1))
disp = node_displacement_function(results, frame4dd)
factor = 500
for nd in frame4dd.truss_node_data
  sphere(nd.loc, 0.08, material=green_mat)
end
for bar in frame4dd.truss_bar_data
  cylinder(bar.node1.loc, 0.02, bar.node2.loc, material=green_mat)
end
for nd in frame4dd.truss_node_data
  d = disp(nd) * factor
  sphere(nd.loc + d, 0.08, material=red_mat)
end
for bar in frame4dd.truss_bar_data
  d1 = disp(bar.node1) * factor
  d2 = disp(bar.node2) * factor
  cylinder(bar.node1.loc + d1, 0.02, bar.node2.loc + d2, material=red_mat)
end
with(render_dir, img_dir) do
  with(render_kind_dir, ".") do
    render_view("tut4_deformation")
  end
end
```

```@example tut4
backend(frame4dd)
nothing # hide
```

## Analytical Comparison: Navier Plate Solution

For a simply-supported rectangular plate under uniform load, the **Navier
solution** gives the center deflection:

```math
w_{max} = \frac{16 q}{\pi^6 D} \sum_{m=1,3,5,...} \sum_{n=1,3,5,...}
\frac{1}{mn \left(\frac{m^2}{a^2} + \frac{n^2}{b^2}\right)^2}
```

where ``D = \frac{E h^3}{12(1-\nu^2)}`` is the plate flexural rigidity.

For our truss grid, we can estimate an equivalent plate stiffness. This is an
**approximation** — the space frame is not a continuous plate, but the comparison
shows how well the truss grid mimics plate behavior:

```@example tut4
a, b = 8.0, 6.0  # plate dimensions
E_steel = 210e9
ν = 0.3

# Equivalent plate thickness from the truss grid's bending stiffness
# For a space frame with depth d, chord area A, and spacing s:
#   D ≈ E * A * d² / (2 * s)
# This is approximate and depends on the topology
A_chord = π * (0.03^2 - 0.025^2)  # tube Ro=30mm, Ri=25mm
d_depth = 0.5
s_spacing = 1.0
D_equiv = E_steel * A_chord * d_depth^2 / (2 * s_spacing)

# Navier series (first 20 terms)
w_navier = sum(1.0 / (m * n * (m^2/a^2 + n^2/b^2)^2)
               for m in 1:2:39 for n in 1:2:39)
w_navier *= 16 * q / (π^6 * D_equiv)

println("Analytical comparison (Navier plate solution):")
println("  Equivalent plate rigidity D ≈ $(round(D_equiv, digits=0)) N·m")
println("  Navier center deflection:  $(round(w_navier * 1000, digits=3)) mm")
println("  Truss grid center deflection: $(round(max_d * 1000, digits=3)) mm")
println("  Ratio (truss/Navier): $(round(max_d / w_navier, digits=2))")
```

!!! note
    The ratio may differ significantly from 1.0 because the equivalent plate
    rigidity formula is approximate. The truss grid has discrete load paths
    while a plate has continuous stress distribution. Finer grids converge
    toward the plate solution.

## Mesh Refinement Study

A key question in structural modeling: how fine must the grid be? Let's run the
same deck with different grid spacings and observe convergence:

```@example tut4
println("Grid    | Nodes | Bars  | Center δ (mm) | Relative")
println("─" ^ 58)

mesh_results = Float64[]
for (nx, ny) in [(4, 3), (8, 6), (16, 12)]
  delete_all_shapes()
  backend(frame4dd)
  dk = space_frame_deck(8.0, 6.0, 0.5, nx, ny)

  # Apply tributary area loads
  pl = Dict{Any, Vector{Any}}()
  for i in 0:nx, j in 0:ny
    wx = (i == 0 || i == nx) ? dk.dx/2 : dk.dx
    wy = (j == 0 || j == ny) ? dk.dy/2 : dk.dy
    F = q * wx * wy
    p = dk.bottom[i+1, j+1]
    load = vz(-F)
    if haskey(pl, load)
      push!(pl[load], p)
    else
      pl[load] = [p]
    end
  end

  res = truss_analysis(vz(0), false, pl)
  md = max_displacement(res)
  push!(mesh_results, md)
  n_n = length(frame4dd.truss_nodes)
  n_b = length(frame4dd.truss_bars)

  rel = length(mesh_results) == 1 ? "—" : "$(round(md / mesh_results[1], digits=3))"

  println("  $(nx)×$(ny)  | $(lpad(n_n, 5)) | $(lpad(n_b, 5)) | " *
          "$(lpad(round(md*1000, digits=3), 13)) | $(lpad(rel, 8))")
end
```

As the grid is refined, the displacement converges. The coarsest grid may
significantly underestimate deflection because it has too few load paths.

## Self-Weight

Space frames can be heavy. Let's see how self-weight affects the total deflection:

```@example tut4
delete_all_shapes()
backend(frame4dd)
deck = space_frame_deck(8.0, 6.0, 0.5, 8, 6)

# Recompute tributary loads
point_loads_sw = Dict{Any, Vector{Any}}()
for i in 0:deck.nx, j in 0:deck.ny
  wx = (i == 0 || i == deck.nx) ? deck.dx/2 : deck.dx
  wy = (j == 0 || j == deck.ny) ? deck.dy/2 : deck.dy
  F = q * wx * wy
  p = deck.bottom[i+1, j+1]
  load = vz(-F)
  if haskey(point_loads_sw, load)
    push!(point_loads_sw[load], p)
  else
    point_loads_sw[load] = [p]
  end
end

results_with_sw = truss_analysis(vz(0), true, point_loads_sw)
max_with_sw = max_displacement(results_with_sw)

println("Deflection without self-weight: $(round(max_d * 1000, digits=3)) mm")
println("Deflection with self-weight:    $(round(max_with_sw * 1000, digits=3)) mm")
println("Self-weight contribution:       $(round((max_with_sw - max_d) / max_d * 100, digits=1))%")
```

## Axial Forces in the Grid

In a space frame deck under downward load, the force distribution follows the
**bending analogy**:
- **Top chord**: compression (analogous to the compression zone in a bent beam)
- **Bottom chord**: tension (analogous to the tension zone)
- **Verticals and diagonals**: carry shear forces

```@example tut4
delete_all_shapes()
backend(frame4dd)
deck = space_frame_deck(8.0, 6.0, 0.5, 8, 6)
point_loads_af = Dict{Any, Vector{Any}}()
for i in 0:deck.nx, j in 0:deck.ny
  wx = (i == 0 || i == deck.nx) ? deck.dx/2 : deck.dx
  wy = (j == 0 || j == deck.ny) ? deck.dy/2 : deck.dy
  F = q * wx * wy
  p = deck.bottom[i+1, j+1]
  load = vz(-F)
  if haskey(point_loads_af, load)
    push!(point_loads_af[load], p)
  else
    point_loads_af[load] = [p]
  end
end
results_af = truss_analysis(vz(0), false, point_loads_af)

forces = element_axial_forces(results_af)

# Categorize bars
top_forces = Float64[]
bottom_forces = Float64[]
vertical_forces = Float64[]
diagonal_forces = Float64[]

for (i, bar) in enumerate(frame4dd.truss_bar_data)
  z1 = bar.node1.loc.z
  z2 = bar.node2.loc.z
  f = forces[i]
  if z1 ≈ z2 ≈ 0.0
    push!(bottom_forces, f)
  elseif z1 ≈ z2 ≈ 0.5
    push!(top_forces, f)
  elseif bar.node1.loc.x ≈ bar.node2.loc.x && bar.node1.loc.y ≈ bar.node2.loc.y
    push!(vertical_forces, f)
  else
    push!(diagonal_forces, f)
  end
end

println("Axial force summary by member type:")
println("─" ^ 55)
for (name, fs) in [("Bottom chord", bottom_forces),
                    ("Top chord", top_forces),
                    ("Verticals", vertical_forces),
                    ("Diagonals", diagonal_forces)]
  if !isempty(fs)
    println("  $name ($(length(fs)) members):")
    println("    Min: $(round(minimum(fs)/1000, digits=2)) kN")
    println("    Max: $(round(maximum(fs)/1000, digits=2)) kN")
    println("    Avg: $(round(sum(fs)/length(fs)/1000, digits=2)) kN")
  end
end
```

The results confirm the bending analogy:
- Bottom chord members are predominantly in **tension** (positive forces)
- Top chord members are predominantly in **compression** (negative forces)
- Forces are largest at the center of the deck and decrease toward the edges

## Reaction Forces

```@example tut4
reactions = reaction_forces(results_af)

# Show reactions on one edge (y = 0)
println("Reactions along y=0 edge:")
println("─" ^ 40)
for (id, r) in sort(collect(reactions), by=first)
  nd = frame4dd.truss_node_data[id]
  if nd.loc.y ≈ 0.0 && nd.loc.z ≈ 0.0
    println("  x=$(rpad(round(nd.loc.x, digits=1), 5)): " *
            "Rz=$(round(r.z/1000, digits=2)) kN")
  end
end

total_Rz = sum(r.z for r in values(reactions))
println("\nTotal vertical reaction: $(round(total_Rz/1000, digits=1)) kN")
println("Total applied load:     $(round(q * 8.0 * 6.0 / 1000, digits=1)) kN")
```

The reaction distribution along the edges mirrors the shear force distribution
in a plate — larger reactions at the center of each edge, smaller at the corners.

## Visualization

For 3D visualization of the space frame deck:

```julia
using KhepriAutoCAD  # or KhepriMakie, KhepriThebes, etc.
show_truss_deformation(results, autocad, factor=500,
  deformation_color=rgb(1, 0, 0),
  no_deformation_color=rgb(0.8, 0.8, 0.8))
```

The deformed shape should show a smooth bowl-shaped pattern, confirming the
plate-like behavior of the truss grid.

## Limitations vs. Robot Structural Analysis

| Robot Feature | KhepriFrame4DD Status | Possible Extension |
|---|---|---|
| Continuum plate/shell elements | Truss grid approximation only | Future: FE plate elements |
| Shell stress resultants (Mx, My, Mxy) | Axial forces only | Derive from chord forces |
| Reinforcement design | Not available | Future: EC2 module |
| Adaptive mesh refinement | Manual grid refinement | Future: automatic refinement |
| Post-processing contour plots | Text-based output | Use Makie for color maps |

## Summary

In this tutorial you learned to:
1. Create a parametric space-frame deck generator with two-chord grid topology
2. Compute tributary area loads from a uniform surface pressure
3. Analyze the deck and display a displacement map
4. Compare results with the Navier analytical plate solution
5. Study mesh convergence by varying grid density
6. Examine the bending analogy in space frame axial forces
7. Interpret edge reaction distributions

## Series Summary

Across the four tutorials you have covered:

| Tutorial | Structure | Key Concepts |
|----------|-----------|-------------|
| 1. Planar Truss | Pratt truss, 12 m span | Supports, sections, loads, displacements, reactions, axial forces |
| 2. Warren Bridge | Warren truss, 30 m span | Parametric generation, multiple load scenarios, force distribution |
| 3. Space Tower | 3D tower, 12 m tall | 3D analysis, drift ratio, stress checks, buckling |
| 4. Truss Grid | Space frame deck, 8×6 m | Tributary areas, plate analogy, mesh convergence |

These tutorials demonstrate KhepriFrame4DD's capabilities for truss analysis
while following a pedagogical arc from simple 2D trusses to complex 3D space
structures.

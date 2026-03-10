# Tutorial 3: 3D Space Truss Tower

This tutorial moves from 2D to **3D analysis** by building a space truss tower —
a common structural form for transmission towers, observation platforms, and
industrial structures. You will learn to model 3D geometry with bracing patterns,
apply combined vertical and lateral loads, and perform approximate stress checks.

*Inspired by Autodesk Robot Structural Analysis Tutorial 3 (Frame 3D Design).*

## Setting Up

```@example tut3
using KhepriFrame4DD
nothing # hide
```

## Parametric Tower Generator

Our tower has a **square base** with corner columns connected by horizontal braces
and face diagonals at each level, plus horizontal cross-bracing for torsional
stiffness.

```
        Level 4 (top) ─── z = 12 m
        ┌───┐
        │ × │  ← horizontal cross-brace
        └───┘
        │   │
        │ ╲ │  ← face diagonals
        │ ╱ │
        │   │
        ┌───┐
        │ × │  Level 3 ─── z = 9 m
        └───┘
        │   │
        │   │
        ┌───┐
        │ × │  Level 2 ─── z = 6 m
        └───┘
        │   │
        │   │
        ┌───┐
        │ × │  Level 1 ─── z = 3 m
        └───┘
        │   │
        │   │
        ╔═══╗
        ║   ║  Level 0 (base) ─── z = 0
        ╚═══╝
        △ △ △ △  (all 4 corners pinned)
```

```@example tut3
function truss_tower(base_size, height, n_levels;
                     bar_fam=nothing, pinned_fam=nothing, free_fam=nothing)
  if bar_fam === nothing
    bar_fam = truss_bar_family_element(
      default_truss_bar_family(), radius=0.04, inner_radius=0.035)
  end
  if pinned_fam === nothing
    pinned_fam = truss_node_family_element(
      default_truss_node_family(),
      support=truss_node_support(ux=true, uy=true, uz=true))
  end
  if free_fam === nothing
    free_fam = truss_node_family_element(default_truss_node_family())
  end

  half = base_size / 2
  level_height = height / n_levels

  # Corner offsets (counter-clockwise from +x, +y)
  corners = [vxy(half, half), vxy(-half, half),
             vxy(-half, -half), vxy(half, -half)]

  # Generate nodes at each level
  levels = []
  for lev in 0:n_levels
    z = lev * level_height
    fam = lev == 0 ? pinned_fam : free_fam
    pts = [xyz(c.x, c.y, z) for c in corners]
    for p in pts
      truss_node(p, fam)
    end
    push!(levels, pts)
  end

  # Connect bars
  for lev in 1:(n_levels+1)
    pts = levels[lev]
    # Horizontal braces at this level
    for i in 1:4
      j = mod1(i + 1, 4)
      truss_bar(pts[i], pts[j], 0, bar_fam)
    end
    # Horizontal cross-braces (diagonals in plan)
    truss_bar(pts[1], pts[3], 0, bar_fam)
    truss_bar(pts[2], pts[4], 0, bar_fam)

    if lev > 1
      prev = levels[lev - 1]
      for i in 1:4
        # Vertical columns
        truss_bar(prev[i], pts[i], 0, bar_fam)
        # Face diagonals (X-bracing on each face)
        j = mod1(i + 1, 4)
        truss_bar(prev[i], pts[j], 0, bar_fam)
        truss_bar(prev[j], pts[i], 0, bar_fam)
      end
    end
  end

  levels
end
nothing # hide
```

Build a tower: 4 m × 4 m base, 12 m tall, 4 levels:

```@example tut3
backend(frame4dd)
delete_all_shapes()
levels = truss_tower(4.0, 12.0, 4)

n_nodes = length(frame4dd.truss_nodes)
n_bars = length(frame4dd.truss_bars)
println("Tower geometry:")
println("  Base: 4 m × 4 m")
println("  Height: 12 m")
println("  Levels: 4 (at 3 m spacing)")
println("  Nodes: $n_nodes")
println("  Bars: $n_bars")
```

## 3D Geometry Summary

The tower has distinct structural member types:

```@example tut3
# Count members by type
is_horizontal(bar) = bar.node1.loc.z ≈ bar.node2.loc.z
is_vertical(bar) = bar.node1.loc.x ≈ bar.node2.loc.x && bar.node1.loc.y ≈ bar.node2.loc.y && !is_horizontal(bar)

n_horizontals = count(is_horizontal, frame4dd.truss_bar_data)
n_verticals = count(is_vertical, frame4dd.truss_bar_data)
n_diagonals = length(frame4dd.truss_bar_data) - n_horizontals - n_verticals

println("Member types:")
println("  Vertical columns: $n_verticals")
println("  Horizontal braces: $n_horizontals (includes cross-braces)")
println("  Face diagonals: $n_diagonals")
```

## Vertical Dead Load

Apply a 20 kN downward load to all top-level nodes (simulating equipment,
platform, antenna, etc.):

```@example tut3
top_pts = levels[end]
results_vert = truss_analysis(vz(0), false,
  Dict(vz(-20000) => top_pts))

max_vert = max_displacement(results_vert)
println("Vertical load (20 kN per top node):")
println("  Max displacement: $(round(max_vert * 1000, digits=3)) mm")
println("  Height/deflection: $(round(12.0 / max_vert, digits=0))")
```

### Visualizing the Tower

```@example tut3
using KhepriThebes
img_dir = joinpath(dirname(dirname(pathof(KhepriFrame4DD))), "docs", "src", "tutorials", "images")
mkpath(img_dir)
backend(thebes)
delete_all_shapes()
set_view(xyz(15, 15, 20), xyz(0, 0, 6))
green_mat = standard_material(base_color=rgba(0.2, 0.7, 0.2, 1))
for nd in frame4dd.truss_node_data
  sphere(nd.loc, 0.15, material=green_mat)
end
for bar in frame4dd.truss_bar_data
  cylinder(bar.node1.loc, 0.04, bar.node2.loc, material=green_mat)
end
with(render_dir, img_dir) do
  with(render_kind_dir, ".") do
    render_view("tut3_structure")
  end
end
```

```@example tut3
backend(frame4dd)
nothing # hide
```

## Combined Loading: Vertical + Lateral Wind

Wind loads on a tower are critical for design. We apply both vertical loads on
the top and horizontal wind loads on all windward-face nodes:

```@example tut3
delete_all_shapes()
backend(frame4dd)
levels = truss_tower(4.0, 12.0, 4)

# Wind loads on nodes at y = +2 (windward face), increasing with height
wind_loads = Dict{Any, Vector{Any}}()
top_pts = levels[end]
for (lev_idx, pts) in enumerate(levels)
  z = (lev_idx - 1) * 3.0
  if z > 0  # no wind at ground level (it's fixed)
    wind_force = 3000 * (z / 12.0)  # 3 kN at top, linearly decreasing
    for p in pts
      if p.y > 0  # windward face (y > 0)
        load = vy(wind_force)
        if haskey(wind_loads, load)
          push!(wind_loads[load], p)
        else
          wind_loads[load] = [p]
        end
      end
    end
  end
end

# Merge vertical loads on top nodes with wind loads
point_loads = merge(wind_loads, Dict(vz(-20000) => top_pts))
results_combined = truss_analysis(vz(0), false, point_loads)

max_combined = max_displacement(results_combined)
println("Combined loading (vertical + wind):")
println("  Max displacement: $(round(max_combined * 1000, digits=3)) mm")
```

## 3D Displacement Analysis

In 3D, we need to examine displacements in all three directions. Lateral drift
(horizontal displacement at the top) is a key design criterion for towers:

```@example tut3
disp = node_displacement_function(results_combined)

println("Displacements by level (combined loading):")
println("─" ^ 65)
println("Level | z (m) | δx (mm)  | δy (mm)  | δz (mm)  | Total (mm)")
println("─" ^ 65)

for (lev_idx, pts) in enumerate(levels)
  z = (lev_idx - 1) * 3.0
  # Average displacement of corner nodes at this level
  disps = [disp(nd) for nd in frame4dd.truss_node_data
           if nd.loc.z ≈ z]
  if !isempty(disps)
    avg_dx = sum(d.x for d in disps) / length(disps)
    avg_dy = sum(d.y for d in disps) / length(disps)
    avg_dz = sum(d.z for d in disps) / length(disps)
    total = sqrt(avg_dx^2 + avg_dy^2 + avg_dz^2)
    println("  $(lpad(lev_idx-1, 2))   | $(rpad(round(z, digits=0), 5)) | " *
            "$(lpad(round(avg_dx*1000, digits=2), 8)) | " *
            "$(lpad(round(avg_dy*1000, digits=2), 8)) | " *
            "$(lpad(round(avg_dz*1000, digits=2), 8)) | " *
            "$(lpad(round(total*1000, digits=2), 9))")
  end
end
```

The **drift ratio** (lateral displacement / height) is limited to H/200 for
serviceability:

```@example tut3
# Find maximum lateral displacement at top
top_disps = [disp(nd) for nd in frame4dd.truss_node_data
             if nd.loc.z ≈ 12.0]
max_lateral = maximum(sqrt(d.x^2 + d.y^2) for d in top_disps)
println("Maximum lateral drift at top: $(round(max_lateral * 1000, digits=2)) mm")
println("Drift ratio: H/$(round(12.0 / max_lateral, digits=0))")
println("Limit H/200: $(round(12.0 / 200 * 1000, digits=1)) mm")
println("Status: $(max_lateral < 12.0/200 ? "OK" : "EXCEEDS LIMIT")")
```

## Reaction Forces

With 4 base supports, the reaction distribution shows how the tower transfers
loads to the foundation:

```@example tut3
reactions = reaction_forces(results_combined)

println("Base reactions (combined loading):")
println("─" ^ 55)
for (id, r) in sort(collect(reactions), by=first)
  nd = frame4dd.truss_node_data[id]
  println("  Node $id at ($(nd.loc.x), $(nd.loc.y)): " *
          "Rx=$(round(r.x/1000, digits=2)), " *
          "Ry=$(round(r.y/1000, digits=2)), " *
          "Rz=$(round(r.z/1000, digits=2)) kN")
end
total_Rx = sum(r.x for r in values(reactions))
total_Ry = sum(r.y for r in values(reactions))
total_Rz = sum(r.z for r in values(reactions))
println("─" ^ 55)
println("  Totals: Rx=$(round(total_Rx/1000, digits=2)), " *
        "Ry=$(round(total_Ry/1000, digits=2)), " *
        "Rz=$(round(total_Rz/1000, digits=2)) kN")
```

Under combined loading, the windward supports carry more vertical load (due to
overturning moment) while the leeward supports may experience uplift (negative Rz).

## Axial Forces and Approximate Stress Check

For a preliminary design check, we compute axial stress
``\sigma = N / A`` and compare it to the yield stress:

```@example tut3
forces = element_axial_forces(results_combined)

# Cross-section area for the tube (Ro=40mm, Ri=35mm)
Ro_tower = 0.04
Ri_tower = 0.035
A = π * (Ro_tower^2 - Ri_tower^2)
σ_yield = 250e6  # 250 MPa for S250 steel

println("Section area: $(round(A * 1e6, digits=1)) mm²")
println("Yield stress: $(round(σ_yield / 1e6, digits=0)) MPa")
println()

# Find most stressed members
max_tension_idx = argmax(forces)
max_compression_idx = argmin(forces)

println("Most stressed members:")
println("─" ^ 55)

for (label, idx) in [("Max tension", max_tension_idx),
                      ("Max compression", max_compression_idx)]
  bar = frame4dd.truss_bar_data[idx]
  f = forces[idx]
  σ = abs(f) / A
  util = σ / σ_yield * 100
  println("  $label:")
  println("    Bar $idx ($(bar.node1.id)→$(bar.node2.id))")
  println("    Force: $(round(f/1000, digits=2)) kN")
  println("    Stress: $(round(σ/1e6, digits=1)) MPa")
  println("    Utilization: $(round(util, digits=1))%")
end
```

!!! note "Approximate Check Only"
    This stress check considers axial forces only. A complete design verification
    would include buckling checks for compression members (Euler critical load),
    connection design, and code-specific safety factors.

## Buckling Check for Compression Members

For slender compression members, buckling governs before material yield. The
**Euler critical load** for a pinned-pinned column is:

```math
N_{cr} = \frac{\pi^2 E I}{L^2}
```

```@example tut3
E = 210e9  # Young's modulus
# Moment of inertia for circular tube (Ro=40mm, Ri=35mm)
I = π/4 * (Ro_tower^4 - Ri_tower^4)

println("Buckling check for compression members:")
println("─" ^ 60)

let n_failing = 0
  for (i, bar) in enumerate(frame4dd.truss_bar_data)
    f = forces[i]
    if f < -100  # compression member
      L = norm(bar.node2.loc - bar.node1.loc)
      N_cr = π^2 * E * I / L^2
      ratio = abs(f) / N_cr
      if ratio > 0.5  # flag members above 50% of critical load
        n_failing += 1
        println("  Bar $i (L=$(round(L, digits=2)) m): " *
                "N=$(round(f/1000, digits=1)) kN, " *
                "N_cr=$(round(N_cr/1000, digits=1)) kN, " *
                "ratio=$(round(ratio*100, digits=1))%")
      end
    end
  end
  if n_failing == 0
    println("  All compression members below 50% of Euler critical load.")
  end
end
```

## Parametric Study: Base Width vs. Height Ratio

The aspect ratio of the tower affects lateral stiffness. We vary the base size
while keeping height constant:

```@example tut3
println("Base (m) | Height/Base | Max lateral (mm) | Drift ratio")
println("─" ^ 60)

for base in [2.0, 3.0, 4.0, 5.0, 6.0]
  delete_all_shapes()
  backend(frame4dd)
  levels = truss_tower(base, 12.0, 4)

  # Same combined loading pattern
  top_pts = levels[end]
  wind_loads = Dict{Any, Vector{Any}}()
  for (lev_idx, pts) in enumerate(levels)
    z = (lev_idx - 1) * 3.0
    if z > 0
      wind_force = 3000 * (z / 12.0)
      for p in pts
        if p.y > base/4  # windward face
          load = vy(wind_force)
          if haskey(wind_loads, load)
            push!(wind_loads[load], p)
          else
            wind_loads[load] = [p]
          end
        end
      end
    end
  end
  point_loads = merge(wind_loads, Dict(vz(-20000) => top_pts))
  res = truss_analysis(vz(0), false, point_loads)

  disp_fn = node_displacement_function(res)
  top_disps = [disp_fn(nd) for nd in frame4dd.truss_node_data
               if nd.loc.z ≈ 12.0]
  max_lat = maximum(sqrt(d.x^2 + d.y^2) for d in top_disps)

  ratio = round(12.0 / base, digits=1)
  println("  $(rpad(base, 8)) | $(lpad(ratio, 11)) | " *
          "$(lpad(round(max_lat*1000, digits=2), 16)) | " *
          "H/$(round(12.0 / max_lat, digits=0))")
end
```

A wider base dramatically improves lateral stiffness by increasing the
overturning resistance (longer lever arm for the base reactions).

## 3D Visualization

The deformed tower (red) overlaid on the original structure (green) under
combined vertical + wind loading:

```@example tut3
delete_all_shapes()
backend(frame4dd)
levels = truss_tower(4.0, 12.0, 4)
top_pts = levels[end]
wind_loads = Dict{Any, Vector{Any}}()
for (lev_idx, pts) in enumerate(levels)
  z = (lev_idx - 1) * 3.0
  if z > 0
    wind_force = 3000 * (z / 12.0)
    for p in pts
      if p.y > 0
        load = vy(wind_force)
        if haskey(wind_loads, load)
          push!(wind_loads[load], p)
        else
          wind_loads[load] = [p]
        end
      end
    end
  end
end
point_loads = merge(wind_loads, Dict(vz(-20000) => top_pts))
results_combined = truss_analysis(vz(0), false, point_loads)

backend(thebes)
delete_all_shapes()
set_view(xyz(15, 15, 20), xyz(0, 0, 6))
green_mat = standard_material(base_color=rgba(0.2, 0.7, 0.2, 1))
red_mat = standard_material(base_color=rgba(0.8, 0.2, 0.2, 1))
disp = node_displacement_function(results_combined, frame4dd)
factor = 100
for nd in frame4dd.truss_node_data
  sphere(nd.loc, 0.15, material=green_mat)
end
for bar in frame4dd.truss_bar_data
  cylinder(bar.node1.loc, 0.04, bar.node2.loc, material=green_mat)
end
for nd in frame4dd.truss_node_data
  d = disp(nd) * factor
  sphere(nd.loc + d, 0.15, material=red_mat)
end
for bar in frame4dd.truss_bar_data
  d1 = disp(bar.node1) * factor
  d2 = disp(bar.node2) * factor
  cylinder(bar.node1.loc + d1, 0.04, bar.node2.loc + d2, material=red_mat)
end
with(render_dir, img_dir) do
  with(render_kind_dir, ".") do
    render_view("tut3_deformation")
  end
end
```

```@example tut3
backend(frame4dd)
nothing # hide
```

Multiple viewpoints help understand 3D behavior — front view shows lateral drift,
side view shows any torsional effects, and top view shows plan displacement.

## Limitations vs. Robot Structural Analysis

| Robot Feature | KhepriFrame4DD Status | Possible Extension |
|---|---|---|
| Moment-resistant connections | Pin-jointed only | Frame4DD solver supports frame elements |
| Steel design codes (EC3/AISC) | Manual stress check only | Future: code compliance module |
| Non-linear analysis | Linear elastic only | Future: geometric non-linearity |
| Foundation design | Reactions only | Export reactions for foundation software |
| Dynamic/seismic analysis | Solver supports modal | Expose `ModalOptions`/`ModalResults` |

## Summary

In this tutorial you learned to:
1. Create a parametric 3D truss tower generator with multi-level bracing
2. Model combined vertical + height-dependent wind loads using `point_loads`
3. Analyze 3D displacements and separate lateral drift from vertical deflection
4. Check the drift ratio against serviceability limits
5. Perform approximate axial stress checks and compute utilization ratios
6. Evaluate Euler buckling for compression members
7. Study the effect of base-to-height ratio on lateral performance

The next tutorial models a flat space-frame deck — a truss grid that approximates
plate behavior.

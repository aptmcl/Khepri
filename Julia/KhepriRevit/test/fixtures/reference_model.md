# Canonical Revit reference model — `reference_model.rvt`

This spec defines the small Revit model used by the **live round-trip oracle** (Ring C,
gated behind `KHEPRI_REVIT_TESTS=1`) for the BIM→ABIM introspection/codegen pipeline. It is the
Revit-side counterpart of the headless in-memory model in
`KhepriBase/test/test_codegen.jl :: reference_model()`.

A human authors `reference_model.rvt` once in Revit to match the contents below, then stores it
alongside this file. The oracle: open it in Revit with the KhepriRevit plugin → `generate_khepri_code`
→ (a) re-run the emitted `.jl` on a fresh Revit and re-introspect (structural compare), and
(b) run it on KhepriThreejs and visually confirm fidelity (the dual-backend check).

## Required contents (one small model exercising every code path)

| # | Element(s) | Why it's here (pipeline path exercised) |
|---|---|---|
| 1 | **3 levels** at 0, 3, 6 m | `extract_levels` dedup + sort → `level_0/1/2` |
| 2 | **Rectangular room, 4 walls** on level 0, of **2 distinct wall types**; ≥1 wall spans two levels | wall introspection; `extract_families` dedup (2 wall-family vars); system-family branch |
| 3 | **1 loadable door + 1 loadable window** on one wall | `meta_program(Wall)` opening path → `add_door`/`add_window`; file-family (`.rfa`) branch; door/window dimension fidelity (Phase 3a) |
| 4 | **Regular column grid ≥ 4×3** of one column type | `loop_rerolling` 2-D grid (currently a known limitation — see `test_codegen.jl`); column base/top level; column rotation (Phase 3a) |
| 5 | **5 collinear columns** at regular spacing, apart from the grid | `loop_rerolling` 1-D (`_try_reroll_1d` → range) |
| 6 | **Exactly 3 columns** elsewhere | asserts the ≥4 threshold rejects rerolling |
| 7 | **≥1 horizontal structural beam** | beam-orientation canary — collapses to ~zero height pre-Phase-3a (`beam(p0,h)` vertical form) |
| 8 | **1 slab per level** + one slab with the **same boundary vertices in a different order** | slab introspection; `_dedup_slabs` |
| 9 | **1 ceiling + 1 roof** (flat) | boundary-vertex introspection |
| 10 | **1 stair + 1 railing** | base/top-level handling; `RVTVoidId` fallback |
| 11 | **≥2 loadable furniture/fixtures — a sink and a chair** | cross-backend dual family: `.rfa` (Revit) **and** extracted OBJ/MTL (KhepriThreejs) via `set_backend_family` (Milestone 2) |
| 12 | **1 in-place / generic-model element** with no clean parametric family | `obj_model(...)` mesh-fallback canary (Milestone 2, Phase 6) |
| 13 | **1 group** with ≥2 placed instances | `translate_xyz_expr`, factory emission, `group_instance` |
| 14 | *(optional)* **1 curtain wall** | `is_curtain_wall` branch (skips door/window attachment) |

## Expected element-count manifest

The oracle compares these exact counts after re-introspection (see `reference_model.manifest.toml`,
authored to match the `.rvt` above). Counts are the oracle-of-record; a mismatch is a hard fail.

```toml
# reference_model.manifest.toml  (author to match the .rvt)
levels            = 3
walls             = 4        # + 1 if the optional curtain wall is included
wall_types        = 2
doors             = 1
windows           = 1
columns           = 20       # 12 (4x3 grid) + 5 (collinear) + 3 (threshold)
beams             = 1
slabs             = 4        # 3 real (one per level) + 1 duplicate-order (deduped to 3 on introspection)
ceilings          = 1
roofs             = 1
stairs            = 1
railings          = 1
loadable_fixtures = 2        # sink, chair
inplace_elements  = 1        # obj_model fallback
groups            = 1
group_instances   = 2
```

## Notes

- Keep the model **minimal**: every element above earns its place by exercising a distinct code path.
  Do not add incidental content that inflates the golden without covering a new path.
- The headless `reference_model()` in `test_codegen.jl` is intentionally a *subset* (levels, walls
  with an opening, a column grid, one slab) — it locks the backend-independent codegen core in CI.
  This `.rvt` is the fuller, Revit-dependent superset for the live oracle.
- When Milestone-2 (cross-backend families) lands, item 11's generated code must produce, per fixture,
  both `set_backend_family(f, revit, revit_file_family(raw"…​.rfa"))` and
  `set_backend_family(f, threejs, obj_family("…"))`, and the KhepriThreejs render must show the
  extracted furniture mesh (not a placeholder box).

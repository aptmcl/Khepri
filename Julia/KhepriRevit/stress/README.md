# Khepri BIM->AD Stress Suite (GSG model ladder)

Round-trip stress tests for the Revit introspection/codegen pipeline: for each
corpus model, introspect it into an AD (algorithmic design) program, rebuild
that program into a blank Revit project, re-introspect, and compare summaries
of the source and rebuilt models.

## Usage

```bash
cd Julia/stress
./run_corpus.sh list        # show corpus entries
./run_corpus.sh gsg04       # run one model
./run_corpus.sh all         # run the whole ladder
```

Requirements: Windows Revit 2024 at `C:\Program Files\Autodesk\Revit 2024`,
the Khepri Revit plugin installed (listens on port 11001, ~40-80s after
launch), Windows Julia (`julia --project='@v1.12'`) with KhepriRevit dev'd.
Run from WSL; the script drives Revit/powershell through interop. Revit is
killed at the end of the run even on failure (EXIT trap) — do not run while
you have unsaved Revit work open.

## Two-launch design

Introspection and rebuild NEVER share a Revit session (introspect + clear +
rebuild in one session is unsafe). Per model:

1. **Launch A (introspect)** — Revit opens a disposable `%TEMP%` copy of the
   `.rvt`. `_stress_introspect.jl` introspects the model, writes
   `summary_src.txt` (via `KhepriBase.model_summary`/`write_summary`) and
   generates the AD program `generated.jl` (with OBJ export for fallback
   meshes).
2. **Launch B (rebuild)** — Revit opens the blank template
   `KhepriRevit/Plugin/KhepriTemplate.rte`. `_stress_rebuild.jl` first checks
   a blank-doc safety guard (aborts unless walls<=15, floors==0, columns==0),
   then evaluates `generated.jl` statement by statement (skipping `using`;
   `obj_model` calls count as `mesh_noop`; per-statement errors are deduped
   and counted, not fatal), re-introspects the rebuilt model into
   `summary_rebuilt.txt` and `generated2.jl` (no OBJ export), and compares
   summaries with
   `KhepriBase.compare_summaries(src, rebuilt; allow=[:template_levels, :stair_railings])`.

Per-model outputs land in `results/<key>/`: `introspect.log`, `rebuild.log`,
`generated.jl`, `generated2.jl`, `summary_src.txt`, `summary_rebuilt.txt`,
`report.txt`.

## PASS / FAIL / WARN

- **PASS** — every compared metric matched within tolerance (or was covered
  by an `allow` rule). The rebuild's `report.txt` ends in `VERDICT: PASS` and
  the model row shows `PASS`.
- **FAIL** — either launch A failed (`FAIL-introspect`: introspection or
  codegen raised), or launch B failed (`FAIL-rebuild`: safety guard tripped,
  a fatal error, or `compare_summaries` produced at least one `FAIL ` line —
  e.g. wrong element counts, wall length / slab area outside tolerance,
  missing levels).
- **WARN** — advisory lines inside `report.txt` that never fail the run.
  Notably `count.fallback_meshes` differences are always WARN: launch B
  re-introspects without OBJ export, so mesh counts are expected to drift.
- **SKIP** — corpus entry has `skip = true` (stages GSG_10..GSG_13 only add
  views/annotations, which the AD pipeline does not round-trip).

`allow` semantics used by the driver:

- `:template_levels` — the blank template ships Level 1/Level 2, so the
  rebuilt model may contain up to 2 extra levels whose elevations are not in
  the source; more than that, or source levels missing, still FAIL.
- `:stair_railings` — Revit auto-generates railings when stairs are built,
  so the rebuilt railing count may exceed the source by up to 2 per source
  stair.

## Adding models

Append a `[models.<key>]` section to `corpus.toml`:

```toml
[models.mymodel]
path = 'C:\path\to\MyModel.rvt'
description = 'What this stage adds'
skip = false            # true to keep it listed but not run
# reason = '...'        # required only when skip = true
```

`corpus.toml` is hand-parsed by `run_corpus.sh` (awk/sed): keep one
`key = value` field per line, single-quoted literal strings for Windows
paths, and no inline comments on value lines.

## Caveat: summary API contract

The Julia scripts code strictly against the summary API provided by
`KhepriBase/src/Summary.jl` (developed separately). If comparisons behave
unexpectedly, check that the installed KhepriBase implements this exact
contract:

### Summary format contract (plain text, line-oriented, hand-rolled — no new package deps)

```
count.<category> = <int>              # categories: levels, walls, curtain_walls, floors, ceilings, roofs, columns, beams, doors, windows, stairs, railings, fixtures, groups, group_instances, fallback_meshes
level_elevations = v1,v2,...          # sorted ascending, rounded to 3 decimals
total_wall_length = <float>           # sum of path_length over non-curtain walls, 3 decimals
total_slab_area = <float>             # best-effort shoelace area of floor slabs (outer loop minus holes), 3 decimals
bbox = x0,y0,z0,x1,y1,z1              # from wall path vertices + slab vertices + column/fixture locations; omit line if no geometry
```

### API contract (module KhepriBase, file `KhepriBase/src/Summary.jl`)

```
model_summary(model) -> Dict{String,Any}          # keys exactly as the line format: "count.walls" => Int, "level_elevations" => Vector{Float64}, "total_wall_length" => Float64, "total_slab_area" => Float64, "bbox" => NTuple{6,Float64} (absent key if none)
summary_string(s::Dict) -> String                 # canonical serialization, keys sorted
write_summary(path::AbstractString, s::Dict)
read_summary(path::AbstractString) -> Dict{String,Any}
compare_summaries(src::Dict, rebuilt::Dict; allow=Symbol[], count_tol=Dict{String,Int}(), length_rtol=0.01, area_rtol=0.05, elev_atol=0.002) -> NamedTuple{(:ok,:lines),Tuple{Bool,Vector{String}}}
  # lines: human-readable verdict lines, each prefixed "PASS "/"FAIL "/"WARN ". ok = no FAIL lines.
  # allow semantics: :template_levels — the rebuilt model may contain UP TO 2 extra levels whose elevations are not in src (the blank Revit template ships Level 1/Level 2); excess levels beyond that, or missing src levels, still FAIL. :stair_railings — rebuilt railing count may exceed src by up to 2 per src stair (Revit auto-generates stair railings). count.fallback_meshes differences are always WARN, never FAIL (rebuild re-introspection typically runs without OBJ export).
```

## Known residual diffs (as of 2026-07-18, GSG tutorial)

`tutorial` currently reports VERDICT: PASS with three allowed WARNs (one blank-template
level, two stair-auto-generated railings). Previously-failing diffs and their fixes, kept
here as provenance for the comparator's tolerances:

- **Arc walls mirrored/wrapped** — C# ArcFromPointsAngle bulged the sagitta on the wrong
  side of the chord AND passed the midpoint to Arc.Create in the endpoint slot (the XYZ
  overload is (end1, end2, pointOnArc)), so arc curtain walls rebuilt mirrored or as the
  315-degree complement. Both fixed in Primitives.cs.
- **Fixtures one level-height low** — Revit's NewFamilyInstance(XYZ, symbol, Level, ...)
  measures the point's Z from the level; fixture_from_ref now emits level-relative z and
  the KhepriBase b_family_element default lifts by the level height on every backend.
- **Stacked walls double-read** — DocWalls now excludes stacked-wall members (claimed via
  their parent), which also removed the phantom unconnected-top pseudo-levels.

The remaining bbox slack (~0.5 m in z-min) is the source model's terrain-adjacent content
that legitimately does not rebuild (mesh fallback is a no-op on Revit).

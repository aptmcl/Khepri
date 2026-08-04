# Headless per-element conformance: replay the generated program on the
# MeasureBackend (KhepriBase's default lowering — the code path mesh backends
# execute) and compare each realized shape against the introspection-time
# ground-truth ledger (independent Revit bbox queries, SI).
#
#   julia --project _conformance.jl <generated.jl> <ledger.tsv> <report.txt>
#
# Matching is per category by nearest bbox-center; tolerances are deliberately
# loose where Revit's bboxes carry known noise (door swings ~0.3 m). The report
# is ADVISORY (per the testing plan): a per-category matrix plus worst offenders,
# with a final CONFORMANCE: OK/WARN line for the harness log. Unmatched ledger
# rows mean dropped/misplaced elements; unmatched measured rows are usually
# multi-instance group copies (the ledger holds one representative per group
# type) and are reported as such.
using KhepriBase

length(ARGS) == 3 || (println("usage: _conformance.jl gen ledger report"); exit(2))
gen_path, ledger_path, report_path = ARGS

# Category-specific matching tolerances (m): centroid distance, per-axis size delta.
# Doors/windows/fixtures absorb Revit bbox noise (swing/handles); walls/slabs are
# tighter but allow join trimming.
const TOL = Dict(
  "Wall" => (0.6, 0.7), "Slab" => (0.4, 0.6), "Roof" => (0.4, 0.6),
  "Ceiling" => (0.4, 0.6), "FamilyElement" => (0.5, 0.7),
  "Door" => (0.7, 0.9), "Window" => (0.7, 0.9),
  "Stair" => (1.2, 2.0), "Railing" => (0.8, 1.5))
tol_for(cat) = get(TOL, cat, (0.6, 0.8))

struct LRow
  cat::String
  id::Int
  level::Float64
  cmin::NTuple{3, Float64}
  cmax::NTuple{3, Float64}
end
center(r::LRow) = ((r.cmin[1] + r.cmax[1]) / 2, (r.cmin[2] + r.cmax[2]) / 2,
                   (r.cmin[3] + r.cmax[3]) / 2)
sizes(r::LRow) = (r.cmax[1] - r.cmin[1], r.cmax[2] - r.cmin[2], r.cmax[3] - r.cmin[3])

ledger = LRow[]
for (i, line) in enumerate(eachline(ledger_path))
  i == 1 && continue
  let f = split(line, '\t')
    length(f) >= 9 || continue
    push!(ledger, LRow(f[1], parse(Int, f[2]),
                       something(tryparse(Float64, f[3]), NaN),
                       (parse(Float64, f[4]), parse(Float64, f[5]), parse(Float64, f[6])),
                       (parse(Float64, f[7]), parse(Float64, f[8]), parse(Float64, f[9]))))
  end
end

# Replay. Bind `threejs` to the measure backend so the generated program's
# guarded obj_family mappings register on it (fixtures realize as their real
# meshes, not placeholder boxes).
cd(dirname(abspath(gen_path)))
b = measure_backend()
env = Module(gensym(:Conformance))
Core.eval(env, :(using KhepriBase))
Core.eval(env, :(threejs = $b))
stmt_rows = measured_statements(read(basename(gen_path), String); b=b, env=env)
errors = [(r.index, first(replace(string(r.expr), r"\s+" => " "), 70),
           first(sprint(showerror, r.error), 120))
          for r in stmt_rows if r.error !== nothing]

# `placeholder`: a FamilyElement whose family has no OBJ mapping realizes as a
# 1 m box — its SIZE is meaningless; match those by position only.
shape_rows = [(cat=String(typeof(r.shape).name.name), m=r.measurement,
               placeholder=(r.shape isa KhepriBase.FamilyElement &&
                            !(KhepriBase.maybe_backend_family(b, r.shape.family) isa KhepriBase.OBJFamily)))
              for r in measured_shapes(b)
              if r.measurement.n_trigs > 0 &&
                 !(typeof(r.shape).name.name in (:Group, :GroupInstance))]

mcenter(m) = ((cx(m.aabb_min) + cx(m.aabb_max)) / 2, (cy(m.aabb_min) + cy(m.aabb_max)) / 2,
              (cz(m.aabb_min) + cz(m.aabb_max)) / 2)
msizes(m) = (cx(m.aabb_max) - cx(m.aabb_min), cy(m.aabb_max) - cy(m.aabb_min),
             cz(m.aabb_max) - cz(m.aabb_min))
d3(a, c) = sqrt(sum((a .- c) .^ 2))

cats = sort(unique(vcat([r.cat for r in ledger], [r.cat for r in shape_rows])))
open(report_path, "w") do io
  println(io, "# Per-element conformance: generated program (MeasureBackend replay) vs Revit ledger")
  println(io, "# generated: $gen_path")
  println(io, "# ledger:    $ledger_path  ($(length(ledger)) rows)")
  println(io)
  if !isempty(errors)
    println(io, "REPLAY ERRORS ($(length(errors))):")
    for (i, snip, err) in errors[1:min(10, length(errors))]
      println(io, "  stmt $i: $snip -> $err")
    end
    println(io)
  end
  n_warn = 0
  # Doors/windows/fixtures that introspection degrades to per-element obj_model
  # fallbacks land in the ObjModel category with positionally-exact geometry — let
  # those ledger rows borrow from a shared ObjModel pool instead of reporting the
  # element as dropped. The pool is consumed across categories.
  obj_rows = [r for r in shape_rows if r.cat == "ObjModel"]
  obj_used = falses(length(obj_rows))
  for cat in cats
    lrows = [r for r in ledger if r.cat == cat]
    srows = [r for r in shape_rows if r.cat == cat]
    (isempty(lrows) && isempty(srows)) && continue
    if isempty(lrows)
      println(io, "$cat: ledger=$(length(lrows)) measured=$(length(srows))  [coverage-only: no counterpart]")
      continue
    end
    let (tp, ts) = tol_for(cat),
        free = trues(length(srows)),
        can_borrow = cat in ("Door", "Window", "FamilyElement"),
        matched = 0, borrowed = 0, worst = Tuple{Float64, Int, Int}[],
        unmatched_l = Int[]
      for (i, lr) in enumerate(lrows)
        let lc = center(lr),
            # Door/Window ledger bboxes are inflated on the wall-normal axis by swing
            # arcs and opening symbols (observed up to 2 m) — drop the single worst
            # axis for those and gate on the remaining two (width + height are real).
            size_ok = sr -> let ds = sort([abs.(msizes(sr.m) .- sizes(lr))...])
              (cat in ("Door", "Window") ? ds[2] : ds[3]) <= ts
            end,
            # All free candidates (own category + borrowable meshes) by distance; take
            # the NEAREST one that passes the size gate — nearest-only pairing stranded
            # elements whose closest neighbor was a different, size-incompatible shape.
            cands = sort!(vcat(
              [(d3(mcenter(srows[j].m), lc), :own, j) for j in 1:length(srows) if free[j]],
              can_borrow ?
                [(d3(mcenter(obj_rows[j].m), lc), :obj, j)
                 for j in 1:length(obj_rows) if !obj_used[j]] : Tuple{Float64,Symbol,Int}[]);
              by = first),
            hit = false
          for (d, kind, j) in cands
            d <= tp || break
            let sr = kind == :own ? srows[j] : obj_rows[j]
              if (kind == :own && sr.placeholder) || size_ok(sr)
                kind == :own ? (free[j] = false) : (obj_used[j] = true; borrowed += 1)
                matched += 1
                push!(worst, (d, lr.id, j))
                hit = true
                break
              end
            end
          end
          hit || push!(unmatched_l, lr.id)
        end
      end
      sort!(worst; by = first, rev = true)
      let frac = matched / length(lrows),
          status = frac >= 0.9 && isempty(unmatched_l) ? "OK" : "WARN"
        status == "WARN" && (n_warn += 1)
        println(io, "$cat: ledger=$(length(lrows)) measured=$(length(srows)) matched=$matched ",
                borrowed > 0 ? "(incl. $borrowed via obj-mesh fallbacks) " : "",
                "max_center_delta=", isempty(worst) ? "-" : string(round(worst[1][1], digits=3)),
                "  [$status]")
        isempty(unmatched_l) ||
          println(io, "  unmatched ledger ids (dropped/misplaced): ",
                  join(unmatched_l[1:min(12, length(unmatched_l))], ", "),
                  length(unmatched_l) > 12 ? " …" : "")
        let extra = count(free)
          extra > 0 &&
            println(io, "  unmatched measured: $extra (multi-instance group copies or extras)")
        end
      end
    end
  end
  println(io)
  println(io, isempty(errors) && n_warn == 0 ? "CONFORMANCE: OK" :
              "CONFORMANCE: WARN ($(n_warn) categories flagged, $(length(errors)) replay errors)")
end
println(read(report_path, String))

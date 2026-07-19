# Launch B: rebuild the generated AD program into a blank template project,
# re-introspect, and compare summaries against the source model.
# ENV: KHEPRI_STRESS_GEN            (Windows path of the generated program to run)
#      KHEPRI_STRESS_SUMMARY_SRC    (summary of the source model, from launch A)
#      KHEPRI_STRESS_SUMMARY_REBUILT (summary of the rebuilt model, written here)
#      KHEPRI_STRESS_REPORT         (verdict/report file, written here)
#      KHEPRI_STRESS_GEN2           (second-generation program, written here)
using KhepriRevit
import KhepriRevit.KhepriBase

fail(msg) = (println("STRESS-FAIL: ", msg); flush(stdout); exit(1))

try
  gen_path = ENV["KHEPRI_STRESS_GEN"]
  src_summary_path = ENV["KHEPRI_STRESS_SUMMARY_SRC"]
  rebuilt_summary_path = ENV["KHEPRI_STRESS_SUMMARY_REBUILT"]
  report_path = ENV["KHEPRI_STRESS_REPORT"]
  gen2_path = ENV["KHEPRI_STRESS_GEN2"]

  # Safety guard: never rebuild into a document that already holds a model.
  let nw = length(all_walls(revit)), nf = length(all_floors(revit)), nc = length(all_columns(revit))
    println("pre-rebuild: walls=$nw floors=$nf columns=$nc")
    (nw <= 15 && nf == 0 && nc == 0) ||
      fail("active doc is not blank (walls=$nw floors=$nf columns=$nc)")
  end

  println("=== rebuilding (statement-by-statement) ===")
  flush(stdout)
  stats =
    let _ = cd(dirname(gen_path)),  # anchor @__DIR__ in eval'd statements at the program's home
    src = read(gen_path, String),
        exprs = Meta.parseall(src).args,
        ok = 0, failed = 0, meshes = 0,
        errs = Dict{String,Int}(),
        # statement → created Revit ids ledger: when a failure-processing sacrifice
        # or rollback names an element id, rebuild_ids.tsv maps it straight back to
        # the generated-program line that created it.
        ids_io = open(joinpath(dirname(gen_path), "rebuild_ids.tsv"), "w"),
        seen_refs = Set{Any}(),
        last_line = 0
      for e in exprs
        e isa LineNumberNode && (last_line = e.line; continue)
        e isa Expr && e.head == :using && continue
        is_mesh = e isa Expr && e.head == :call && e.args[1] == :obj_model
        try
          Core.eval(Main, e)
          is_mesh ? (meshes += 1) : (ok += 1)
        catch ex
          failed += 1
          let msg = first(sprint(showerror, ex), 140)
            errs[msg] = get(errs, msg, 0) + 1
          end
        end
        let ids = Any[]
          for (_, rf) in revit.refs.shapes
            if !(rf in seen_refs)
              push!(seen_refs, rf)
              append!(ids, try KhepriBase.ref_values(revit, rf) catch; [] end)
            end
          end
          isempty(ids) || println(ids_io, last_line, "\t", join(ids, ","))
        end
      end
      close(ids_io)
      (ok=ok, meshes=meshes, failed=failed, errs=errs)
    end
  println("REBUILD: ok=$(stats.ok) mesh_noop=$(stats.meshes) failed=$(stats.failed)")
  for (m, n) in sort(collect(stats.errs), by=last, rev=true)
    println("  [$(n)x] $m")
  end
  flush(stdout)

  println("=== re-introspecting rebuilt model ===")
  model2 = KhepriRevit.introspect_model(b=revit)
  s2 = KhepriBase.model_summary(model2)
  KhepriBase.write_summary(rebuilt_summary_path, s2)
  generate_khepri_code(gen2_path; export_obj=false)
  println("re-introspected: $gen2_path")
  flush(stdout)

  length_rtol = parse(Float64, get(ENV, "KHEPRI_STRESS_LENGTH_RTOL", "0.01"))
  r = KhepriBase.compare_summaries(KhepriBase.read_summary(src_summary_path),
                                   KhepriBase.read_summary(rebuilt_summary_path);
                                   allow=[:template_levels, :stair_railings],
                                   length_rtol=length_rtol)
  open(report_path, "w") do io
    println(io, "rebuild: ok=$(stats.ok) mesh_noop=$(stats.meshes) failed=$(stats.failed)")
    for (m, n) in sort(collect(stats.errs), by=last, rev=true)
      println(io, "  [$(n)x] $m")
    end
    foreach(l -> println(io, l), r.lines)
    println(io, r.ok ? "VERDICT: PASS" : "VERDICT: FAIL")
  end
  foreach(println, r.lines)
  flush(stdout)
  if r.ok
    println("STRESS-PASS")
    flush(stdout)
    exit(0)
  else
    fail("summary mismatch (see $report_path)")
  end
catch e
  fail(first(sprint(showerror, e), 300))
end

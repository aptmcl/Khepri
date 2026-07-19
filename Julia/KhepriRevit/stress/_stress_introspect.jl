# Launch A: introspect a disposable copy of a GSG .rvt, write its summary,
# and generate the AD program for the rebuild launch.
# ENV: KHEPRI_STRESS_GEN (Windows path for generated.jl),
#      KHEPRI_STRESS_SUMMARY (Windows path for summary_src.txt).
using KhepriRevit
import KhepriRevit.KhepriBase

fail(msg) = (println("STRESS-FAIL: ", msg); flush(stdout); exit(1))

try
  let gen_path = ENV["KHEPRI_STRESS_GEN"],
      summary_path = ENV["KHEPRI_STRESS_SUMMARY"],
      # introspect once for the summary; generate_khepri_code re-introspects
      # internally, which is acceptable.
      model = KhepriRevit.introspect_model(b=revit),
      s = KhepriBase.model_summary(model)
    println("SOURCE COUNTS:")
    for (k, v) in sort!(collect(filter(p -> startswith(first(p), "count."), s)), by=first)
      println("  $k = $v")
    end
    flush(stdout)
    KhepriBase.write_summary(summary_path, s)
    # Level name → elevation table (heights alone cannot distinguish named storeys, e.g. for
    # selective execution of "Piso 1" only).
    let lvl_path = joinpath(dirname(summary_path), "levels.txt")
      open(lvl_path, "w") do io
        for r in KhepriBase.@remote(revit, DocLevels())
          println(io, KhepriBase.@remote(revit, ElementName(r)), " = ",
                  KhepriBase.@remote(revit, GetLevelElevation(r)))
        end
      end
      println("levels written: $lvl_path")
    end
    println("summary written: $summary_path")
    # Ground-truth LEDGER: one row per introspected element (via the ref registry —
    # everything a reader ref!'d, group representatives included), with the element's
    # independently-queried world bbox in SI. Consumed by the headless conformance
    # replay (stress/_conformance.jl) to verify per-element position/size after the
    # generated program is realized on the MeasureBackend.
    let ledger_path = joinpath(dirname(summary_path), "ledger.tsv"),
        lvl_of = sh -> try
          hasproperty(sh, :level) ? sh.level.height :
          hasproperty(sh, :bottom_level) ? sh.bottom_level.height : NaN
        catch
          NaN
        end
      open(ledger_path, "w") do io
        println(io, "category	id	level	minx	miny	minz	maxx	maxy	maxz")
        for (sh, r) in revit.refs.shapes
          let ids = try KhepriBase.ref_values(revit, r) catch; [] end
            isempty(ids) && continue
            let id = ids[1]
              id isa Integer && id > 0 || continue
              let bmin = try KhepriBase.@remote(revit, BoundingBoxMin(id)) catch; nothing end
                bmin === nothing && continue
                let bmax = KhepriBase.@remote(revit, BoundingBoxMax(id))
                  println(io, typeof(sh).name.name, "	", id, "	", lvl_of(sh), "	",
                          cx(bmin), "	", cy(bmin), "	", cz(bmin), "	",
                          cx(bmax), "	", cy(bmax), "	", cz(bmax))
                end
              end
            end
          end
        end
      end
      # Doors/windows are not ref!'d shapes — append their rows from the hosted-
      # element scans (ids + independent bboxes), so the conformance report can
      # match the replayed Door/Window meshes too.
      open(ledger_path, "a") do io
        for (cat, infos) in (("Door", KhepriRevit.all_doors(revit)),
                             ("Window", KhepriRevit.all_windows(revit)))
          for inf in infos
            let bmin = try KhepriBase.@remote(revit, BoundingBoxMin(inf.ref)) catch; nothing end
              bmin === nothing && continue
              let bmax = KhepriBase.@remote(revit, BoundingBoxMax(inf.ref))
                println(io, cat, "\t", inf.ref, "\t", NaN, "\t",
                        cx(bmin), "\t", cy(bmin), "\t", cz(bmin), "\t",
                        cx(bmax), "\t", cy(bmax), "\t", cz(bmax))
              end
            end
          end
        end
      end
      println("ledger written: $ledger_path")
    end
    generate_khepri_code(gen_path)
    println("generated: $gen_path")
    println("STRESS-OK")
    flush(stdout)
  end
catch e
  fail(first(sprint(showerror, e), 300))
end

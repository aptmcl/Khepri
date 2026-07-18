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
    generate_khepri_code(gen_path)
    println("generated: $gen_path")
    println("STRESS-OK")
    flush(stdout)
  end
catch e
  fail(first(sprint(showerror, e), 300))
end

# Probe the T4 (moradia) stair 1139346: why does StairRunPaths return no runs?
# Discriminates: legacy sketch-based stair (GetStairsRuns empty) vs group-member
# enumeration issue vs wrong element kind. Also dumps the params/geometry needed
# to design a faithful fallback emission.
using KhepriRevit
import KhepriRevit.KhepriBase
const KB = KhepriRevit.KhepriBase

b = revit
r = 1139346
show_try(tag, f) =
  try
    println(tag, ": ", f())
  catch e
    println(tag, ": ERROR ", first(sprint(showerror, e), 120))
  end

show_try("runs (StairRunPaths)", () -> length(KB.@remote(b, StairRunPaths(r))))
show_try("landings", () -> length(KB.@remote(b, StairLandingBoundaries(r))))
show_try("riser_h", () -> KB.@remote(b, StairRiserHeight(r)))
show_try("tread_d", () -> KB.@remote(b, StairTreadDepth(r)))
show_try("width", () -> KB.@remote(b, StairWidth(r)))
show_try("physical bbox", () ->
  let pb = KB.@remote(b, PhysicalBoundingBox(r))
    length(pb) == 2 ?
      string(map(x -> round(x, digits=3), (cx(pb[1]), cy(pb[1]), cz(pb[1])))) * " .. " *
      string(map(x -> round(x, digits=3), (cx(pb[2]), cy(pb[2]), cz(pb[2])))) : "EMPTY"
  end)
println("PROBE-OK")

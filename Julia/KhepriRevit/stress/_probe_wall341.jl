# Micro-repro for the T3 line-341 band wall that dies with the unresolvable
# "top of the Wall is lower than the base of the Wall" at commit. Recreates the
# stacked pair (drywall 3.26..5.70 + concrete band 5.70..6.32 on the same plan
# segment) in stages, printing the surviving wall count and bboxes after each,
# so the failing interaction is pinned to a stage.
using KhepriRevit
import KhepriRevit.KhepriBase
const KB = KhepriRevit.KhepriBase

b = revit
stage(n) =
  let ws = KB.@remote(b, DocWalls())
    println("stage $n: walls=", length(ws))
    for w in ws
      let lo = KB.@remote(b, BoundingBoxMin(w)), hi = KB.@remote(b, BoundingBoxMax(w))
        println("  wall z ", round(cz(lo), digits=2), "..", round(cz(hi), digits=2))
      end
    end
    flush(stdout)
  end

l1 = level(3.2599999)
l2 = level(2 * 3.2599999)

# Stage 1: the band wall ALONE (base_offset 2.44, top_offset -0.2).
w2 = wall(open_polygonal_path([xy(-18.236361, -75.014865), xy(-16.036361, -75.014865)]),
          bottom_level=l1, top_level=l2, base_offset=2.4399999, top_offset=-0.19999999)
stage(1)

# Stage 2: add the collinear wall below it (top_offset -0.82, same segment).
w1 = wall(open_polygonal_path([xy(-18.236361, -75.014865), xy(-16.111361, -75.014865)]),
          bottom_level=l1, top_level=l2, top_offset=-0.81999997)
stage(2)

println("PROBE-OK")

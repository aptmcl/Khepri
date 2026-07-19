# Probe the GSG footprint roof 147722: sketch curves + per-edge slope flags.
using KhepriRevit
import KhepriRevit.KhepriBase
const KB = KhepriRevit.KhepriBase
b = revit
r = 147722
rows = KB.@remote(b, RoofFootprintInfo(r))
println("rows = ", length(rows))
for row in rows
  println("  edge (", round(row[1]*0.3048, digits=3), ",", round(row[2]*0.3048, digits=3),
          ") -> (", round(row[4]*0.3048, digits=3), ",", round(row[5]*0.3048, digits=3),
          ") z=", round(row[3]*0.3048, digits=3),
          " defines=", row[7], " slope=", round(row[8], digits=4))
end
println("level = ", KB.@remote(b, RoofLevel(r)))
pb = KB.@remote(b, PhysicalBoundingBox(r))
length(pb) == 2 && println("physbbox z ", round(cz(pb[1]), digits=3), "..", round(cz(pb[2]), digits=3))
th = KB.@remote(b, HostObjTypeThickness(r))
println("thickness = ", th)
println("PROBE-OK")

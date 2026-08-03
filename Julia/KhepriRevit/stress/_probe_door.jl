# Probe door 1146262 (T4 Door-Opening): compare HostedElementPosition's result with
# PhysicalBoundingBox and the host wall's curve, to see which estimator the RPC used.
using KhepriRevit
import KhepriRevit.KhepriBase
const KB = KhepriRevit.KhepriBase

b = revit
r = 1146262
pos = KB.@remote(b, HostedElementPosition(r))
println("pos = ", pos)
pb = KB.@remote(b, PhysicalBoundingBox(r))
length(pb) == 2 &&
  println("physical bbox = ", (cx(pb[1]), cy(pb[1]), cz(pb[1])), " .. ",
          (cx(pb[2]), cy(pb[2]), cz(pb[2])))
host = KB.@remote(b, HostWallId(r))
println("host wall = ", host)
dims = KB.@remote(b, DoorWindowDimensions(r))
println("dims = ", dims)
println("PROBE-OK")

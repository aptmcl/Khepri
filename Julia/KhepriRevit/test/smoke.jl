# Interactive smoke test for KhepriRevit family-handling fixes.
#
# Run from a Julia REPL with the project active:
#   cd Julia/KhepriRevit
#   julia.exe --project
#   julia> include("test/smoke.jl")
#
# Output streams to the REPL, so each step is visible; pause after each to
# verify in Revit.

using KhepriRevit, KhepriBase

println("== Connecting to Revit ==")
backend(revit)
n0 = length(@remote(revit, DocElements()))
println("Doc has $n0 elements at start")

println("\n== System families ==")
default_level(level(0))
w = wall(open_polygonal_path([xy(0,0), xy(5,0)]),
         bottom_level=level(0), top_level=level(3))
println("  wall:        ", ref_values(revit, w))
s = slab(closed_polygonal_path([xy(6,0), xy(11,0), xy(11,4), xy(6,4)]),
         level=level(0))
println("  slab:        ", ref_value(revit, s))
c = ceiling(closed_polygonal_path([xy(12,0), xy(15,0), xy(15,3), xy(12,3)]),
            level=level(3))
println("  ceiling:     ", ref_value(revit, c))
p = panel(rectangular_path(xy(16,0), 2, 1))
println("  panel:       ", ref_value(revit, p))

println("\n== Columns and beams ==")
fam = column_family(profile=rectangular_profile(0.5, 0.5))
c1 = column(xy(0, 6), bottom_level=level(0), top_level=level(3), family=fam)
c2 = column(xy(2, 6), bottom_level=level(0), top_level=level(3), family=fam)
println("  col1:        ", ref_value(revit, c1))
println("  col2:        ", ref_value(revit, c2))
println("  same type?   ",
        @remote(revit, ElementTypeName(ref_value(revit, c1))) ==
        @remote(revit, ElementTypeName(ref_value(revit, c2))))
b = beam(xy(4, 6), 3.0, π/6)
println("  beam:        ", ref_value(revit, b),
        ", rotation=", round(@remote(revit, BeamRotation(ref_value(revit, b))); digits=3))

println("\n== Door/window instance_map ==")
w2 = wall(open_polygonal_path([xy(20,0), xy(28,0)]),
          bottom_level=level(0), top_level=level(3))
ref_values(revit, w2)
d = door(w2, xy(2.0, 0.0))
wn = window(w2, xy(5.0, 0.0))
println("  door:        ", ref_value(revit, d),
        ", dims=", @remote(revit, DoorWindowDimensions(ref_value(revit, d))))
println("  window:      ", ref_value(revit, wn),
        ", dims=", @remote(revit, DoorWindowDimensions(ref_value(revit, wn))))

println("\n== Multi-segment wall + opening on second segment ==")
w3 = wall(open_polygonal_path([xy(30,0), xy(35,0), xy(35,4)]),
          bottom_level=level(0), top_level=level(3))
ref_values(revit, w3)
d2 = door(w3, xy(2.0, 0.0))   # segment 1, local 2.0
wn2 = window(w3, xy(6.0, 0.0)) # segment 2, local 1.0
println("  door host:   ", @remote(revit, HostWallId(ref_value(revit, d2))))
println("  window host: ", @remote(revit, HostWallId(ref_value(revit, wn2))))
println("  different? (should be true): ",
        @remote(revit, HostWallId(ref_value(revit, d2))) !=
        @remote(revit, HostWallId(ref_value(revit, wn2))))

println("\n== RevitInPlaceFamily fails fast ==")
fam_inplace = column_family()
set_backend_family(fam_inplace, revit, RevitInPlaceFamily(Dict{Symbol,String}(), IdDict{KhepriBase.Backend, Any}()))
err = try
  c_bad = column(xy(40,0), bottom_level=level(0), top_level=level(3), family=fam_inplace)
  ref_value(revit, c_bad)
  nothing
catch e; e end
println("  error message: ", err === nothing ? "<NO ERROR>" : sprint(showerror, err))

println("\n== Casement window split-param (skipped if .rfa missing) ==")
rel = raw"Windows\M_Casement-Double.rfa"
casement_path = try; revit_library_path("Metric Library", rel); catch; nothing; end
if casement_path !== nothing && isfile(casement_path)
  fam_cas = window_family(width=1.2, height=1.4)
  set_backend_family(fam_cas, revit, revit_casement_window_family(
    casement_path,
    width = f -> to_revit(f.width),
    sill  = f -> to_revit(0.95)))
  w4 = wall(open_polygonal_path([xy(45,0), xy(53,0)]),
            bottom_level=level(0), top_level=level(3))
  ref_values(revit, w4)
  cw1 = window(w4, xy(2.0, 0.0), family=fam_cas)
  cw2 = window(w4, xy(5.0, 0.0), family=fam_cas)
  println("  casement#1:    ", ref_value(revit, cw1))
  println("  casement#2:    ", ref_value(revit, cw2))
  println("  same type?     ",
          @remote(revit, ElementTypeName(ref_value(revit, cw1))) ==
          @remote(revit, ElementTypeName(ref_value(revit, cw2))))
else
  println("  M_Casement-Double.rfa not found in Metric Library; skipped")
end

n1 = length(@remote(revit, DocElements()))
println("\n== Done ==")
println("Doc element count: $n0 → $n1 (delta = $(n1 - n0))")

# Micro-probe: does the RVT b_family_element mirror-parity path work? Place the
# same .rfa twice on a blank template — once with a plain (proper) loc, once with
# the improper cs a mirrored T3 cabinet emits — then read back FamilyInstanceFlips
# and the physical bboxes. Expect Mirrored=false / true and reflected bbox centers.
using KhepriRevit
import KhepriRevit.KhepriBase
const KB = KhepriRevit.KhepriBase

b = revit
rfa = raw"C:\Users\aml\Vault\AML\Projects\Khepri\Julia\KhepriRevit\stress\results\moradia3\khepri_obj_models\Furniture_Cabinet_File_Lateral_2-Drawer.rfa"
lvl = level(0.0)

fam = family_element_family("cab_probe")
set_backend_family(fam, revit, revit_file_family(rfa))

s1 = family_element(xy(0.0, 0.0), 0.0, lvl, fam)
s2 = family_element(loc_from_o_vx_vy(xy(10.0, 0.0), vxy(1.0, 0.0), vxy(0.0, -1.0)),
                    0.0, lvl, fam)

for (tag, s) in (("proper", s1), ("mirrored", s2))
  let r = KB.ref_value(b, s),
      fl = KB.@remote(b, FamilyInstanceFlips(r)),
      pb = KB.@remote(b, PhysicalBoundingBox(r))
    println(tag, ": flips=", fl,
            length(pb) == 2 ?
              " bbox=(" * string(round(cx(pb[1]), digits=3)) * "," *
              string(round(cy(pb[1]), digits=3)) * ")..(" *
              string(round(cx(pb[2]), digits=3)) * "," *
              string(round(cy(pb[2]), digits=3)) * ")" : " bbox=EMPTY")
  end
end
println("PROBE-OK")

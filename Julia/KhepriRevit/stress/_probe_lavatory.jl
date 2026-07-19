# Micro-probe: rebuild the GSG wall-hung lavatory placement (tilted face-based
# frame) on the blank template with a host wall, and read back the instance's
# LocationPoint + physical bbox — isolates where the mounting z is lost.
using KhepriRevit
import KhepriRevit.KhepriBase
const KB = KhepriRevit.KhepriBase

b = revit
lvl0 = level(0.0)
lvl1 = level(3.0)
w = wall(open_polygonal_path([xy(0.0, -3.0), xy(0.0, 3.0)]),
         bottom_level=lvl0, top_level=lvl1)

rfa = raw"C:\Users\aml\Vault\AML\Projects\Khepri\Julia\KhepriRevit\stress\results\tutorial\khepri_obj_models\American_Standard_-_Wheelchair_Users_Lavatory_-_9140.013.rfa"
fam = family_element_family("lav_probe")
set_backend_family(fam, revit, revit_file_family(rfa))

# The GSG frame: BasisX along the wall (+y), BasisY up, BasisZ = wall normal (+x);
# anchor at mounting height z=0.8636 on the wall face.
s = family_element(loc_from_o_vx_vy(xyz(0.05, 0.0, 0.8636), vxyz(0, 1, 0), vxyz(0, 0, 1)),
                   0.0, lvl0, fam)

r = KB.ref_value(b, s)
println("ref = ", r)
loc = KB.@remote(b, FamilyInstanceLocation(r))
println("LP = ", (cx(loc), cy(loc), cz(loc)))
pb = KB.@remote(b, PhysicalBoundingBox(r))
length(pb) == 2 &&
  println("physbbox = ", map(x -> round(x, digits=3), (cx(pb[1]), cy(pb[1]), cz(pb[1]))),
          " .. ", map(x -> round(x, digits=3), (cx(pb[2]), cy(pb[2]), cz(pb[2]))))
tt = KB.@remote(b, FamilyInstanceTotalTransform(r))
println("T = ", map(x -> round(x, digits=3), tt))
println("PROBE-OK")

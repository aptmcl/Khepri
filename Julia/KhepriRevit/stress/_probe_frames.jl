# Frame probe: for the fixture families whose mirrored placements defeat offline
# reconstruction, dump per instance: LocationPoint, the FULL GetTotalTransform
# (basis columns + origin), flip flags, and the world bbox. Offline solving then
# pins (a) whether LocationPoint == TotalTransform.Origin for face-based families
# and (b) how Revit proper-izes the reported basis of mirrored instances.
# NOTE: T origin/basis come back as raw doubles (Revit internal FEET); lp/bbox go
# through the wire's XYZ conversion (meters).
using KhepriRevit
import KhepriRevit.KhepriBase

const TARGETS = ["Furniture_Cabinet_File_Lateral_2-Drawer",
                 "M_Upper Cabinet-Single Door-Wall",
                 "Furniture_Bed_3",
                 "sink pousar Note 40x40"]

let out = raw"C:\Users\aml\Vault\AML\Projects\Khepri\Julia\KhepriRevit\stress\results\moradia3\probe_frames.txt",
    b = revit,
    refs = vcat(KhepriBase.@remote(b, DocFurniture()),
                KhepriBase.@remote(b, DocPlumbingFixtures()),
                KhepriBase.@remote(b, DocCasework()),
                KhepriBase.@remote(b, DocGenericModels()),
                KhepriBase.@remote(b, DocSpecialtyEquipment()))
  open(out, "w") do io
    for r in refs
      let fam = KhepriBase.@remote(b, ElementFamilyName(r))
        any(t -> occursin(t, fam), TARGETS) || continue
        let typ = KhepriBase.@remote(b, ElementTypeName(r)),
            lp = KhepriBase.@remote(b, FamilyInstanceLocation(r)),
            tt = KhepriBase.@remote(b, FamilyInstanceTotalTransform(r)),
            fl = KhepriBase.@remote(b, FamilyInstanceFlips(r)),
            bmin = KhepriBase.@remote(b, BoundingBoxMin(r)),
            bmax = KhepriBase.@remote(b, BoundingBoxMax(r))
          println(io, "id=", r, " fam=", fam, ":", typ)
          println(io, "  flips=", fl)
          println(io, "  lp=", (cx(lp), cy(lp), cz(lp)))
          println(io, "  T=", tt)
          println(io, "  bbox=", (cx(bmin), cy(bmin), cz(bmin)), " .. ",
                  (cx(bmax), cy(bmax), cz(bmax)))
        end
      end
    end
  end
  println("probe written: ", out)
  println("STRESS-OK")
end

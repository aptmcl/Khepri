module KhepriPOVRay
using KhepriBase

# functions that need specialization
include(khepribase_interface_file())
include("POVRay.jl")

function __init__()
  set_material(povray, material_basic, povray_neutral)
  set_material(povray, material_metal, povray_metal)
  set_material(povray, material_glass, povray_glass)
  set_material(povray, material_wood, povray_wood)
  set_material(povray, material_concrete, povray_material("Concrete", gray=0.3))
  set_material(povray, material_plaster, povray_material("InteriorWall70", gray=0.7))

  add_current_backend(povray)
end
end

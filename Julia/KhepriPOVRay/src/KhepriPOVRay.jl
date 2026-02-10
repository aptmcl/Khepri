module KhepriPOVRay
using KhepriBase

# functions that need specialization
include(khepribase_interface_file())
include("POVRay.jl")

function __init__()
  set_material(POVRay, material_basic, povray_neutral)
  set_material(POVRay, material_metal, povray_metal)
  set_material(POVRay, material_glass, povray_glass)
  set_material(POVRay, material_grass, povray_grass)
  set_material(POVRay, material_wood, povray_wood)
  set_material(POVRay, material_clay, povray_material("Clay", gray=0.5))
  set_material(POVRay, material_concrete, povray_material("Concrete", gray=0.3))
  set_material(POVRay, material_plaster, povray_material("InteriorWall70", gray=0.7))

  add_current_backend(povray)
end
end

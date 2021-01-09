module KhepriAutoCAD
using KhepriBase
using Sockets

# functions that need specialization
include(khepribase_interface_file())

using EzXML
include("AutoCAD.jl")

function __init__()
  set_material(autocad, material_metal, "Steel - Polished")
  set_material(autocad, material_glass, "Clear")
  set_material(autocad, material_wood, "Plywood - New")
  set_material(autocad, material_concrete, "Flat - Broom Gray")
  set_material(autocad, material_plaster, "Fine - White")
  set_material(autocad, material_grass, "Green")

  add_current_backend(autocad)
end

end

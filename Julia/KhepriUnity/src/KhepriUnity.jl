module KhepriUnity
using KhepriBase
using Sockets

# functions that need specialization
include(khepribase_interface_file())

include("Unity.jl")

function __init__()
  set_material(unity, material_basic, "Default/Materials/White")
  set_material(unity, material_metal, "Default/Materials/Steel")
  set_material(unity, material_glass, "Default/Materials/Glass")
  set_material(unity, material_wood, "Default/Materials/Wood")
  set_material(unity, material_concrete, "Default/Materials/Concrete")
  set_material(unity, material_plaster, "Default/Materials/Plaster")
  set_material(unity, material_grass, "Default/Materials/Grass")

  add_current_backend(unity)
end
end

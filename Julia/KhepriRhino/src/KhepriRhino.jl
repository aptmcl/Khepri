module KhepriRhino
using KhepriBase
using Sockets

# functions that need specialization
include(khepribase_interface_file())

include("Rhino.jl")

function __init__()
  set_material(rhino, material_metal, rhino_default_material(raw"Metal\Silver"))
  set_material(rhino, material_glass, rhino_default_material(raw"Transparent\Glass"))
  set_material(rhino, material_wood, rhino_default_material(raw"Wood\Scots Pine"))
  set_material(rhino, material_concrete, rhino_default_material(raw"Stone\Granite"))
  set_material(rhino, material_plaster, rhino_default_material(raw"White Matte"))
  set_material(rhino, material_grass, rhino_default_material(raw"Special\Grass"))

  add_current_backend(rhino)
end
end

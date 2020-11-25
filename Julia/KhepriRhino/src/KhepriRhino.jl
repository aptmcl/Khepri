module KhepriRhino
using KhepriBase
using Sockets

# functions that need specialization
include(khepribase_interface_file())

include("Rhino.jl")

function __init__()
  set_backend_family(default_wall_family(), rhino, rhino_layer_family("Wall"))
  set_backend_family(default_slab_family(), rhino, rhino_layer_family("Slab"))
  set_backend_family(default_roof_family(), rhino, rhino_layer_family("Roof"))
  set_backend_family(default_beam_family(), rhino, rhino_layer_family("Beam"))
  set_backend_family(default_column_family(), rhino, rhino_layer_family("Column"))
  set_backend_family(default_door_family(), rhino, rhino_layer_family("Door"))
  set_backend_family(default_panel_family(), rhino, rhino_layer_family("Panel"))

  set_backend_family(default_table_family(), rhino, rhino_layer_family("Table"))
  set_backend_family(default_chair_family(), rhino, rhino_layer_family("Chair"))
  set_backend_family(default_table_chair_family(), rhino, rhino_layer_family("TableChairs"))

  set_backend_family(default_curtain_wall_family(), rhino, rhino_layer_family("CurtainWall"))
  set_backend_family(default_curtain_wall_family().panel, rhino, rhino_layer_family("CurtainWall-Panel"))
  set_backend_family(default_curtain_wall_family().boundary_frame, rhino, rhino_layer_family("CurtainWall-Boundary"))
  set_backend_family(default_curtain_wall_family().transom_frame, rhino, rhino_layer_family("CurtainWall-Transom"))
  set_backend_family(default_curtain_wall_family().mullion_frame, rhino, rhino_layer_family("CurtainWall-Mullion"))
  #current_backend(rhino)

  set_backend_family(default_truss_node_family(), rhino, rhino_layer_family("TrussNodes"))
  set_backend_family(default_truss_bar_family(), rhino, rhino_layer_family("TrussBars"))

  add_current_backend(rhino)
end
end

module KhepriBlender
using KhepriBase
using Sockets

# functions that need specialization
include(khepribase_interface_file())
include("Blender.jl")

function __init__()
  set_default_materials()
  #add_current_backend(blender)
  add_socket_backend_init_function("Blender", (conn) -> BLR("Blender", blender_port, conn, blender_api))
end
end

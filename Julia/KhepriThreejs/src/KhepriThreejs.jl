module KhepriThreejs
using KhepriBase
using Colors
import HTTP
using Random

# functions that need specialization
include(khepribase_interface_file())
include("Threejs.jl")


# We need assets, such as toilets, furniture, trees, etc.
# These can be in different formats, but we will start with the
# OBJ/MTL format

function __init__()
  set_default_materials()
  register_handlers!()
  add_websocket_backend_init_function("threejs", conn -> THR("Threejs", conn, threejs_api))
  #add_current_backend(threejs)
end
end
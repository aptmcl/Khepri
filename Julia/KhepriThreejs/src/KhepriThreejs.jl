module KhepriThreejs
using KhepriBase
using Colors
import HTTP
using Random

# functions that need specialization
include(khepribase_interface_file())
include("Threejs.jl")


# Assets (toilets, furniture, doors, windows, etc.) are supported via
# ThreeJSObjFileFamily — see the OBJ/MTL Backend Families section in
# Threejs.jl. Use threejs_obj_family() and set_backend_family() to
# register OBJ models as backend implementations for Khepri families.

function __init__()
  set_default_materials()
  register_handlers!()
  add_websocket_backend_init_function("threejs", conn -> THR("Threejs", conn, threejs_api))
  #add_current_backend(threejs)
end
end
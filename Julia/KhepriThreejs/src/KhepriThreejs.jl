module KhepriThreejs
using KhepriBase
#using Colors
import HTTP
using Random

# functions that need specialization
include(khepribase_interface_file())
include("Threejs.jl")

function __init__()
  set_default_materials()
  add_current_backend(threejs)
end
end
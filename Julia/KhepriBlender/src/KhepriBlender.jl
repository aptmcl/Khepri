module KhepriBlender
using KhepriBase
using Sockets

# functions that need specialization
include(khepribase_interface_file())
include("Blender.jl")

function __init__()
  add_current_backend(blender)
end
end

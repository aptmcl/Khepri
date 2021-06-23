module KhepriRhino
using KhepriBase
using Sockets

# functions that need specialization
include(khepribase_interface_file())

include("Rhino.jl")

function __init__()
  add_current_backend(rhino)
end
end

module KhepriThebes
using KhepriBase
using Thebes
import Luxor
using Luxor: Drawing  # Only import Drawing, not conflicting names like box, circle

# functions that need specialization
include(khepribase_interface_file())

include("Thebes.jl")

function __init__()
  add_current_backend(thebes)
end
end

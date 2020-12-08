module KhepriTikZ
using KhepriBase

# functions that need specialization
include(khepribase_interface_file())

include("TikZ.jl")

function __init__()
  add_current_backend(tikz)
end

end

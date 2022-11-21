module KhepriTikZ
using KhepriBase
using Latexify

# functions that need specialization
include(khepribase_interface_file())

include("TikZ.jl")

function __init__()
  add_current_backend(tikz)
  set_view_top()
end

end

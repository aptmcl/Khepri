module KhepriSVG
using KhepriBase

# functions that need specialization
include(khepribase_interface_file())

include("SVG.jl")

function __init__()
  add_current_backend(svg)
  set_view_top()
end

end

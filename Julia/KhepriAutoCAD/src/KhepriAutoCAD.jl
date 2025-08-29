module KhepriAutoCAD
using KhepriBase
using Sockets
using EzXML

# functions that need specialization
include(khepribase_interface_file())
include("AutoCAD.jl")

function __init__()
  set_default_materials()
  add_current_backend(autocad)
end

end

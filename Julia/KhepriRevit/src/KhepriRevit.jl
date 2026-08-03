module KhepriRevit
using KhepriBase
using Sockets
using EzXML
using Dates

# functions that need specialization
include(khepribase_interface_file())
include("Revit.jl")

function __init__()
  add_current_backend(revit)
end
end

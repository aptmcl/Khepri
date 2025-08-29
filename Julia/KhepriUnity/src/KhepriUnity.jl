module KhepriUnity
using KhepriBase
using Sockets

# functions that need specialization
include(khepribase_interface_file())

include("Unity.jl")

function __init__()
   #add_current_backend(unity)
   set_default_materials()
   add_client_backend_init_function("Unity", (conn) -> Unity("Unity", unity_port, conn, unity_api))
end
end

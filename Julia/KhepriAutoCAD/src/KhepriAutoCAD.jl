module KhepriAutoCAD
using Reexport
@reexport using KhepriBase
using Dates
using ColorTypes
using Sockets

# resolve conflicts
using KhepriBase:
    XYZ,
    Text

# functions that need specialization
import Base:
    show
import KhepriBase:
    backend_name,
    #void_ref,
    realize,
    parse_signature,
    encode,
    decode,
    backend_render_view,
    backend_realistic_sky

using EzXML
include("AutoCAD.jl")
end

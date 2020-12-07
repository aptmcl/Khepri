module KhepriRevit
using KhepriBase
using Sockets

# functions that need specialization
include(khepribase_interface_file())

include("Revit.jl")

function __init__()
  # C:\\ProgramData\\Autodesk\\RVT 2017\\Libraries\\US Metric\\

  set_backend_family(default_wall_family(), revit, revit_system_family())
  set_backend_family(default_window_family(), revit, revit_system_family())
  #=
  set_backend_family(default_slab_family(), revit, revit_system_family())
  set_backend_family(default_beam_family(), revit, revit_file_family(
        @remote(revit, InstalledLibraryPath(connection(revit)), "Structural Framing\\Wood\\M_Timber.rfa")),
        :width=>"b", :height=>"d"))
  #set_backend_family(default_column_family(), unity, unity_material_family("Materials/Concrete/Concrete2"))
  #set_backend_family(default_door_family(), unity, unity_material_family("Materials/Wood/InteriorWood2"))

  =#
  set_backend_family(default_panel_family(), revit, revit_system_family())

  add_current_backend(revit)
end
end

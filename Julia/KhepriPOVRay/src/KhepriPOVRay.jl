module KhepriPOVRay
using KhepriBase

# functions that need specialization
include(khepribase_interface_file())
include("POVRay.jl")

function __init__()
  set_backend_family(default_wall_family(), povray,
    povray_wall_family(povray_material("InteriorWall70", gray=0.7)))
  set_backend_family(default_slab_family(), povray,
    povray_slab_family(povray_material("GenericFloor20", gray=0.2), povray_material("GenericCeiling80", gray=0.8)))
  set_backend_family(default_roof_family(), povray,
    povray_roof_family(povray_material("GenericFloor20", gray=0.2), povray_material("GenericCeiling30", gray=0.3)))
  set_backend_family(default_beam_family(), povray, povray_material_family(povray_metal))
  set_backend_family(default_column_family(), povray, povray_material_family(povray_metal))
  set_backend_family(default_door_family(), povray, povray_material_family(povray_wood))
  set_backend_family(default_panel_family(), povray, povray_material_family(povray_glass))
  set_backend_family(default_table_family(), povray, povray_material_family(povray_wood))
  set_backend_family(default_chair_family(), povray, povray_material_family(povray_wood))
  set_backend_family(default_table_chair_family(), povray, povray_material_family(povray_wood))
  set_backend_family(default_truss_node_family(), povray, povray_material_family(povray_metal))
  set_backend_family(default_truss_bar_family(), povray, povray_material_family(povray_metal))
end
end

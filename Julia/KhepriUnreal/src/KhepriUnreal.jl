module KhepriUnreal
using KhepriBase
using Sockets

# functions that need specialization
include(khepribase_interface_file())
include("Unreal.jl")

function __init__()
  set_backend_family(default_wall_family(), unreal, unreal_material_family("/Game/StarterContent/Materials/M_Basic_Wall.M_Basic_Wall"))
  set_backend_family(default_slab_family(), unreal, unreal_material_family("/Game/StarterContent/Materials/M_Concrete_Tiles.M_Concrete_Tiles"))
  set_backend_family(default_roof_family(), unreal, unreal_material_family("/Game/StarterContent/Materials/M_Concrete_Tiles.M_Concrete_Tiles"))
  set_backend_family(default_beam_family(), unreal, unreal_material_family("/Game/StarterContent/Materials/M_Metal_Steel.M_Metal_Steel"))
  set_backend_family(default_column_family(), unreal, unreal_material_family("/Game/StarterContent/Materials/M_Concrete_Tiles.M_Concrete_Tiles"))
  set_backend_family(default_door_family(), unreal, unreal_material_family("/Game/StarterContent/Materials/M_Wood_Oak.M_Wood_Oak"))
  set_backend_family(default_panel_family(), unreal, unreal_material_family("/Game/StarterContent/Materials/M_Glass.M_Glass"))
  set_backend_family(default_table_family(), unreal, unreal_resource_family("/Game/FreeFurniturePack/Meshes/SM_Modern_Table.SM_Modern_Table"))
  set_backend_family(default_chair_family(), unreal, unreal_resource_family("/Game/FreeFurniturePack/Meshes/SM_Modern_Chair_1.SM_Modern_Chair_1"))
  #set_backend_family(default_table_chair_family(), unreal, unreal_resource_family("Prefabs/TablesChairs/ModernTableChair/ModernTableChair"))

  set_backend_family(default_curtain_wall_family().panel, unreal,
    unreal_material_family("/Game/StarterContent/Materials/M_Glass.M_Glass"))
  set_backend_family(default_curtain_wall_family().boundary_frame, unreal,
      unreal_material_family("/Game/StarterContent/Materials/M_Metal_Steel.M_Metal_Steel"))
  set_backend_family(default_curtain_wall_family().transom_frame, unreal,
    unreal_material_family("/Game/StarterContent/Materials/M_Metal_Steel.M_Metal_Steel"))
  set_backend_family(default_curtain_wall_family().mullion_frame, unreal,
    unreal_material_family("/Game/StarterContent/Materials/M_Metal_Steel.M_Metal_Steel"))
end

end

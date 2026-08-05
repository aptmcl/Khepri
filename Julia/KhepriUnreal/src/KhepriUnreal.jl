module KhepriUnreal
using KhepriBase
using Sockets

# functions that need specialization
include(khepribase_interface_file())
include("Unreal.jl")

function __init__()
  add_current_backend(unreal)
  # Use engine default materials that work without paid asset packs
  set_backend_family(default_wall_family(), unreal,
    unreal_material_family("/Engine/EngineMaterials/DefaultMaterial.DefaultMaterial"))
  set_backend_family(default_slab_family(), unreal,
    unreal_material_family("/Engine/EngineMaterials/DefaultMaterial.DefaultMaterial"))
  set_backend_family(default_roof_family(), unreal,
    unreal_material_family("/Engine/EngineMaterials/DefaultMaterial.DefaultMaterial"))
  set_backend_family(default_beam_family(), unreal,
    unreal_material_family("/Engine/EngineMaterials/DefaultMaterial.DefaultMaterial"))
  set_backend_family(default_column_family(), unreal,
    unreal_material_family("/Engine/EngineMaterials/DefaultMaterial.DefaultMaterial"))
  set_backend_family(default_door_family(), unreal,
    unreal_material_family("/Engine/EngineMaterials/DefaultMaterial.DefaultMaterial"))
  set_backend_family(default_panel_family(), unreal,
    unreal_material_family("/Engine/EngineMaterials/DefaultMaterial.DefaultMaterial"))

  #=
  No furniture registrations on the DEFAULT families. They were inert
  before the b_family_instance seam existed (nothing placed a
  UEResourceFamily), and activating them would capture every user
  family: the delegation walk falls back to the default family, so
  `table(family=table_family(length=5))` would place an engine Cube
  and discard the dimensions — while the same script honors them on
  every other backend. Register per family instead:
    set_backend_family(my_table_family, unreal,
                       unreal_resource_family("/Game/MyTable"))
  =#

  set_backend_family(default_curtain_wall_family().panel, unreal,
    unreal_material_family("/Engine/EngineMaterials/DefaultMaterial.DefaultMaterial"))
  set_backend_family(default_curtain_wall_family().boundary_frame, unreal,
    unreal_material_family("/Engine/EngineMaterials/DefaultMaterial.DefaultMaterial"))
  set_backend_family(default_curtain_wall_family().transom_frame, unreal,
    unreal_material_family("/Engine/EngineMaterials/DefaultMaterial.DefaultMaterial"))
  set_backend_family(default_curtain_wall_family().mullion_frame, unreal,
    unreal_material_family("/Engine/EngineMaterials/DefaultMaterial.DefaultMaterial"))
end

end

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

  # Table and chair families use resource loading (static meshes)
  # These use engine primitives as fallbacks; users should override with project assets
  set_backend_family(default_table_family(), unreal,
    unreal_resource_family("/Engine/BasicShapes/Cube.Cube"))
  set_backend_family(default_chair_family(), unreal,
    unreal_resource_family("/Engine/BasicShapes/Cube.Cube"))

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

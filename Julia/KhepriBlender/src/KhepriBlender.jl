module KhepriBlender
using KhepriBase
using Sockets

# functions that need specialization
include(khepribase_interface_file())
include("Blender.jl")

function __init__()
  set_material(blender, material_metal, "asset_base_id:f1774cb0-b679-46b4-879e-e7223e2b4b5f asset_type:material")
  #set_material(blender, material_glass, "asset_base_id:ee2c0812-17f5-40d4-992c-68c5a66261d7 asset_type:material")
  set_material(blender, material_glass, "asset_base_id:ffa3c281-6184-49d8-b05e-8c6e9fe93e68 asset_type:material")
  set_material(blender, material_wood, "asset_base_id:d5097824-d5a1-4b45-ab5b-7b16bdc5a627 asset_type:material")
  #set_material(blender, material_concrete, "asset_base_id:0662b3bf-a762-435d-9407-e723afd5eafc asset_type:material")
  set_material(blender, material_concrete, "asset_base_id:df1161da-050c-4638-b376-38ced992ec18 asset_type:material")
  #set_material(blender, material_grass, "asset_base_id:97b171b4-2085-4c25-8793-2bfe65650266 asset_type:material")
  #set_material(blender, material_grass, "asset_base_id:7b05be22-6bed-4584-a063-d0e616ddea6a asset_type:material")
  set_material(blender, material_grass, "asset_base_id:b4be2338-d838-433b-9f0d-2aa9b97a0a8a asset_type:material")
  set_family(blender, default_slab_family(), blender_family_materials(material_concrete))
  set_family(blender, default_wall_family(), blender_family_materials(material_concrete))
#=  set_backend_family(default_wall_family(), blender, blender_layer_family("Wall"))
  set_backend_family(default_slab_family(), blender, blender_layer_family("Slab"))
  set_backend_family(default_roof_family(), blender, blender_layer_family("Roof"))
  set_backend_family(default_beam_family(), blender, blender_layer_family("Beam"))
=#
  set_family(blender, default_beam_family(), blender_family_materials(material_concrete))
  set_family(blender, default_column_family(), blender_family_materials(material_concrete))
  #set_backend_family(default_door_family(), blender, blender_layer_family("Door"))
  set_family(blender, default_panel_family(), blender_family_materials(material_glass))
#=
  set_backend_family(default_table_family(), blender, blender_layer_family("Table"))
  set_backend_family(default_chair_family(), blender, blender_layer_family("Chair"))
  set_backend_family(default_table_chair_family(), blender, blender_layer_family("TableChairs"))
=#
  set_family(blender, default_curtain_wall_family(), blender_family_materials(material_metal))
  set_family(blender, default_curtain_wall_family().panel, blender_family_materials(material_glass))
  set_family(blender, default_curtain_wall_family().boundary_frame, blender_family_materials(material_metal))
  set_family(blender, default_curtain_wall_family().transom_frame, blender_family_materials(material_metal))
  set_family(blender, default_curtain_wall_family().mullion_frame, blender_family_materials(material_metal))

#=
  set_backend_family(default_truss_node_family(), blender, blender_layer_family("TrussNode"))
  set_backend_family(default_truss_bar_family(), blender, blender_layer_family("TrussBar"))

  set_backend_family(fixed_truss_node_family, blender, blender_layer_family("FixedTrussNode"))
  set_backend_family(free_truss_node_family, blender, blender_layer_family("FreeTrussNode"))
  #use_family_in_layer(b::ACAD) = true

  =#
  add_current_backend(blender)
end
end

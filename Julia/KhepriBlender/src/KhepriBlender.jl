module KhepriBlender
using KhepriBase
using Sockets

# functions that need specialization
include(khepribase_interface_file())
include("Blender.jl")

function __init__()
  #set_material(blender, material_basic, )
  set_material(blender, material_metal, "asset_base_id:f1774cb0-b679-46b4-879e-e7223e2b4b5f asset_type:material")
  #set_material(blender, material_glass, "asset_base_id:ee2c0812-17f5-40d4-992c-68c5a66261d7 asset_type:material")
  set_material(blender, material_glass, "asset_base_id:ffa3c281-6184-49d8-b05e-8c6e9fe93e68 asset_type:material")
  set_material(blender, material_wood, "asset_base_id:d5097824-d5a1-4b45-ab5b-7b16bdc5a627 asset_type:material")
  #set_material(blender, material_concrete, "asset_base_id:0662b3bf-a762-435d-9407-e723afd5eafc asset_type:material")
  set_material(blender, material_concrete, "asset_base_id:df1161da-050c-4638-b376-38ced992ec18 asset_type:material")
  set_material(blender, material_plaster, "asset_base_id:c674137d-cfae-45f1-824f-e85dc214a3af asset_type:material")

  #set_material(blender, material_grass, "asset_base_id:97b171b4-2085-4c25-8793-2bfe65650266 asset_type:material")
  #set_material(blender, material_grass, "asset_base_id:7b05be22-6bed-4584-a063-d0e616ddea6a asset_type:material")
  set_material(blender, material_grass, "asset_base_id:b4be2338-d838-433b-9f0d-2aa9b97a0a8a asset_type:material")

  add_current_backend(blender)
end
end

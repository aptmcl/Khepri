# KhepriUnreal tests — Unreal Engine SocketBackend via C++ plugin
#
# Tests cover module loading, type system, backend configuration,
# family types, and modern b_* API. Actual Unreal operations
# require a running Unreal editor with the Khepri C++ plugin.

using KhepriUnreal
using KhepriBase
using Test

@testset "KhepriUnreal.jl" begin

  @testset "Type system" begin
    @test isdefined(KhepriUnreal, :UEKey)
    @test KhepriUnreal.UEId === Int
    @test isdefined(KhepriUnreal, :UERef)
    @test isdefined(KhepriUnreal, :UENativeRef)
    @test KhepriUnreal.UE === SocketBackend{KhepriUnreal.UEKey, Int}
  end

  @testset "Backend initialization" begin
    @test unreal isa KhepriBase.Backend
    @test KhepriBase.backend_name(unreal) == "Unreal"
    @test KhepriBase.void_ref(unreal) === -1
    @test KhepriBase.view_type(KhepriUnreal.UE) isa KhepriBase.BackendView
  end

  @testset "Family types" begin
    @test isdefined(KhepriUnreal, :UEFamily)
    @test KhepriUnreal.UEFamily <: KhepriBase.Family
    @test isdefined(KhepriUnreal, :UEMaterialFamily)
    @test KhepriUnreal.UEMaterialFamily <: KhepriUnreal.UEFamily
    @test isdefined(KhepriUnreal, :UEResourceFamily)
    @test KhepriUnreal.UEResourceFamily <: KhepriUnreal.UEFamily

    # Constructor functions
    mf = unreal_material_family("TestMat")
    @test mf isa KhepriUnreal.UEMaterialFamily
    @test mf.name == "TestMat"

    rf = unreal_resource_family("TestRes", :key => "value")
    @test rf isa KhepriUnreal.UEResourceFamily
    @test rf.name == "TestRes"
    @test rf.parameter_map[:key] == "value"
  end

  @testset "Modern b_* methods exist" begin
    # Verify that key b_* methods are defined for the UE backend type
    UE = KhepriUnreal.UE

    # Tier 0 - Curves
    @test hasmethod(KhepriBase.b_point, Tuple{UE, Any, Any})
    @test hasmethod(KhepriBase.b_line, Tuple{UE, Any, Any})
    @test hasmethod(KhepriBase.b_polygon, Tuple{UE, Any, Any})
    @test hasmethod(KhepriBase.b_circle, Tuple{UE, Any, Any, Any})

    # Tier 1 - Surfaces
    @test hasmethod(KhepriBase.b_trig, Tuple{UE, Any, Any, Any, Any})
    @test hasmethod(KhepriBase.b_quad, Tuple{UE, Any, Any, Any, Any, Any})
    @test hasmethod(KhepriBase.b_surface_polygon, Tuple{UE, Any, Any})

    # Tier 3 - Solids
    @test hasmethod(KhepriBase.b_box, Tuple{UE, Any, Any, Any, Any, Any})
    @test hasmethod(KhepriBase.b_sphere, Tuple{UE, Any, Any, Any})
    @test hasmethod(KhepriBase.b_cylinder, Tuple{UE, Any, Any, Any, Any, Any, Any})

    # Boolean operations
    @test hasmethod(KhepriBase.b_unite_ref, Tuple{UE, Int, Int})
    @test hasmethod(KhepriBase.b_subtract_ref, Tuple{UE, Int, Int})
    @test hasmethod(KhepriBase.b_intersect_ref, Tuple{UE, Int, Int})

    # Deletion
    @test hasmethod(KhepriBase.b_delete_ref, Tuple{UE, Int})
    @test hasmethod(KhepriBase.b_delete_refs, Tuple{UE, Vector{Int}})
    @test hasmethod(KhepriBase.b_delete_all_shape_refs, Tuple{UE})

    # Layers
    @test hasmethod(KhepriBase.b_current_layer_ref, Tuple{UE})
    @test hasmethod(KhepriBase.b_current_layer_ref, Tuple{UE, Any})
    @test hasmethod(KhepriBase.b_layer, Tuple{UE, Any, Any, Any})

    # Materials
    @test hasmethod(KhepriBase.b_get_material, Tuple{UE, AbstractString})
    @test hasmethod(KhepriBase.b_new_material, Tuple{UE, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any})

    # Highlighting
    @test hasmethod(KhepriBase.b_highlight_refs, Tuple{UE, Vector{Int}})
    @test hasmethod(KhepriBase.b_unhighlight_refs, Tuple{UE, Vector{Int}})
    @test hasmethod(KhepriBase.b_unhighlight_all_refs, Tuple{UE})

    # View
    @test hasmethod(KhepriBase.b_set_view, Tuple{UE, Any, Any, Any, Any})
    @test hasmethod(KhepriBase.b_get_view, Tuple{UE})

    # Batch processing
    @test hasmethod(KhepriBase.b_start_batch_processing, Tuple{UE})
    @test hasmethod(KhepriBase.b_stop_batch_processing, Tuple{UE})

    # BIM
    @test hasmethod(KhepriBase.b_table, Tuple{UE, Any, Any, Any, Any, Any, Any, Any})
    @test hasmethod(KhepriBase.b_chair, Tuple{UE, Any, Any, Any, Any, Any, Any, Any})
    @test hasmethod(KhepriBase.b_slab, Tuple{UE, Any, Any, Any})
    @test hasmethod(KhepriBase.b_wall, Tuple{UE, Any, Any, Any, Any, Any})
  end

  @testset "No legacy backend_* functions" begin
    # Verify that old naming convention is gone
    @test !isdefined(KhepriUnreal, :backend_rectangular_table)
    @test !isdefined(KhepriUnreal, :backend_chair)
    @test !isdefined(KhepriUnreal, :backend_slab)
    @test !isdefined(KhepriUnreal, :backend_wall)
    @test !isdefined(KhepriUnreal, :backend_curtain_wall)
    @test !isdefined(KhepriUnreal, :backend_pointlight)
    @test !isdefined(KhepriUnreal, :backend_spotlight)
    @test !isdefined(KhepriUnreal, :backend_set_view)
    @test !isdefined(KhepriUnreal, :backend_get_view)
    @test !isdefined(KhepriUnreal, :backend_delete_all_shapes)
    @test !isdefined(KhepriUnreal, :backend_delete_shapes)
  end

  @testset "Exported functions" begin
    @test isdefined(KhepriUnreal, :unreal)
    @test isdefined(KhepriUnreal, :unreal_material_family)
    @test isdefined(KhepriUnreal, :unreal_resource_family)
  end
end

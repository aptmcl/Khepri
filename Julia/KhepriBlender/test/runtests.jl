# KhepriBlender tests — Blender SocketBackend via Python plugin
#
# Tests cover module loading, type system, backend configuration,
# and exported helpers. Actual Blender operations require a running
# Blender instance with the KhepriServer Python plugin.

using KhepriBlender
using KhepriBase
using Test

@testset "KhepriBlender.jl" begin

  @testset "Type system" begin
    @test isdefined(KhepriBlender, :BLRKey)
    @test KhepriBlender.BLRId === Union{Int32, String}
    @test KhepriBlender.BLR === SocketBackend{KhepriBlender.BLRKey, Union{Int32, String}}
  end

  @testset "Backend initialization" begin
    @test blender isa KhepriBase.Backend
    @test KhepriBase.backend_name(blender) == "Blender"
    @test KhepriBase.void_ref(blender) === Int32(-1)
  end

  @testset "Configuration parameters" begin
    @test KhepriBlender.headless_blender isa KhepriBase.Parameter
    @test headless_blender() isa Bool
  end

  @testset "Exported helpers" begin
    @test isdefined(KhepriBlender, :start_blender)
    @test isdefined(KhepriBlender, :blender_family_materials)
    # blender_family_materials creates a named tuple with 4 materials
    mats = blender_family_materials("mat1")
    @test mats isa NamedTuple
    @test haskey(mats, :materials)
    @test length(mats.materials) == 4
    @test all(==( "mat1"), mats.materials)

    # With distinct materials
    mats2 = blender_family_materials("a", "b", "c", "d")
    @test mats2.materials == ("a", "b", "c", "d")
  end
end

# KhepriUnreal tests — Unreal Engine SocketBackend via C++ plugin
#
# Tests cover module loading, type system, backend configuration,
# family types, and CSG ref type aliases. Actual Unreal operations
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
    @test isdefined(KhepriUnreal, :UEUnionRef)
    @test isdefined(KhepriUnreal, :UESubtractionRef)
    @test KhepriUnreal.UE === SocketBackend{KhepriUnreal.UEKey, Int}
  end

  @testset "Backend initialization" begin
    @test unreal isa KhepriBase.Backend
    @test KhepriBase.backend_name(unreal) == "Unreal"
    @test KhepriBase.void_ref(unreal) === -1
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

  @testset "Exported functions" begin
    @test isdefined(KhepriUnreal, :fast_unreal)
  end
end

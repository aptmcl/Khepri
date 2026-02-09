# KhepriUnity tests — Unity SocketBackend via C# plugin
#
# Tests cover module loading, type system, backend configuration,
# family types, and NavMesh parameter. Actual Unity operations
# require a running Unity editor with the Khepri C# plugin.

using KhepriUnity
using KhepriBase
using Test

@testset "KhepriUnity.jl" begin

  @testset "Type system" begin
    @test isdefined(KhepriUnity, :UnityKey)
    @test KhepriUnity.UnityId === Int32
    @test isdefined(KhepriUnity, :UnityRef)
    @test isdefined(KhepriUnity, :UnityNativeRef)
    @test KhepriUnity.Unity === SocketBackend{KhepriUnity.UnityKey, Int32}
  end

  @testset "Backend initialization" begin
    @test unity isa KhepriBase.Backend
    @test KhepriBase.backend_name(unity) == "Unity"
    @test KhepriBase.void_ref(unity) === Int32(-1)
  end

  @testset "Boolean operations disabled" begin
    @test KhepriBase.has_boolean_ops(KhepriUnity.Unity) isa KhepriBase.HasBooleanOps{false}
  end

  @testset "Family types" begin
    @test isdefined(KhepriUnity, :UnityFamily)
    @test KhepriUnity.UnityFamily <: KhepriBase.Family
    @test isdefined(KhepriUnity, :UnityMaterialFamily)
    @test KhepriUnity.UnityMaterialFamily <: KhepriUnity.UnityFamily

    # unity_material_family constructor
    mf = unity_material_family("Default/Materials/Steel")
    @test mf isa KhepriUnity.UnityMaterialFamily
    @test mf.name == "Default/Materials/Steel"
  end

  @testset "NavMesh tagging parameter" begin
    @test KhepriUnity.nav_mesh_tagging isa KhepriBase.Parameter
    @test KhepriUnity.nav_mesh_tagging() isa Bool
  end

  @testset "Exported functions" begin
    @test isdefined(KhepriUnity, :fast_unity)
  end
end

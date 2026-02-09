# KhepriRevit tests — Revit SocketBackend via C# plugin
#
# Tests cover module loading, type system, backend configuration,
# unit conversion constants, and family types. Actual Revit
# operations require a running Revit instance with the Khepri plugin.

using KhepriRevit
using KhepriBase
using Test

@testset "KhepriRevit.jl" begin

  @testset "Type system" begin
    @test isdefined(KhepriRevit, :RVTKey)
    @test KhepriRevit.RVTId === Int64
    @test isdefined(KhepriRevit, :RVTNativeRef)
    @test KhepriRevit.RVT === SocketBackend{KhepriRevit.RVTKey, Int64}
  end

  @testset "Backend initialization" begin
    @test revit isa KhepriBase.Backend
    @test KhepriBase.backend_name(revit) == "Revit"
    @test KhepriBase.void_ref(revit) === Int64(-1)
    @test KhepriRevit.RVTVoidId === Int64(-1)
  end

  @testset "Unit conversion" begin
    @test KhepriRevit.to_feet ≈ 3.28084 atol=1e-5
  end

  @testset "Configuration parameters" begin
    @test KhepriRevit.revit_template isa KhepriBase.Parameter
  end

  @testset "Family types" begin
    @test isdefined(KhepriRevit, :RevitFamily)
    @test KhepriRevit.RevitFamily <: KhepriBase.Family
    @test isdefined(KhepriRevit, :RevitSystemFamily)
    @test KhepriRevit.RevitSystemFamily <: KhepriRevit.RevitFamily
    @test isdefined(KhepriRevit, :RevitFileFamily)
    @test KhepriRevit.RevitFileFamily <: KhepriRevit.RevitFamily
    @test isdefined(KhepriRevit, :RevitInPlaceFamily)
    @test KhepriRevit.RevitInPlaceFamily <: KhepriRevit.RevitFamily
  end

  @testset "Boolean operations" begin
    @test KhepriBase.has_boolean_ops(KhepriRevit.RVT) isa KhepriBase.HasBooleanOps{true}
  end
end

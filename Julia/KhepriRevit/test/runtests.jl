# KhepriRevit tests — Revit SocketBackend via C# plugin
#
# Tests cover module loading, type system, backend configuration,
# unit conversion constants, and family types. Actual Revit
# operations require a running Revit instance with the Khepri plugin.

using KhepriRevit
using KhepriBase
using KhepriBase: SocketBackend
using Test

include(joinpath(pkgdir(KhepriBase), "test", "BackendTestScaffolding.jl"))
using .BackendTestScaffolding

@testset "KhepriRevit.jl" begin

  @testset "RPC Conformance (static)" begin
    run_rpc_conformance_tests(revit, joinpath(dirname(pathof(KhepriRevit))))
  end

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

  @testset "Family construction" begin
    sf = KhepriRevit.revit_system_family()
    @test sf isa KhepriRevit.RevitSystemFamily
    @test isempty(sf.family_map)
    @test isempty(sf.instance_map)
    @test !hasfield(KhepriRevit.RevitSystemFamily, :instance_ref)

    ff = KhepriRevit.revit_file_family("/tmp/test.rfa")
    @test ff isa KhepriRevit.RevitFileFamily
    @test ff.path == "/tmp/test.rfa"
    @test isempty(ff.family_map)
    @test isempty(ff.instance_map)
    @test !hasfield(KhepriRevit.RevitFileFamily, :family_ref)
    @test !hasfield(KhepriRevit.RevitFileFamily, :instance_ref)

    sf2 = KhepriRevit.revit_system_family(
      ["b"=>f->1.0], ["h"=>f->2.0], (f, p)->p)
    @test length(sf2.family_map) == 1
    @test length(sf2.instance_map) == 1
  end

  @testset "Boolean operations" begin
    @test KhepriBase.has_boolean_ops(KhepriRevit.RVT) isa KhepriBase.HasBooleanOps{true}
  end

  # Headless golden tests for the backend-agnostic BIM→Julia codegen pipeline (KhepriBase/CodeGen.jl),
  # driven through the Revit family/module hooks so the golden matches real KhepriRevit output.
  include(joinpath(dirname(pathof(KhepriBase)), "..", "test", "test_codegen.jl"))

  # Live family-placement tests run against a real Revit instance. They are
  # gated on KHEPRI_REVIT_TESTS=1 so the static suite above stays cheap and
  # cross-platform; sibling backends (KhepriAutoCAD, KhepriRhino) use the
  # same convention. The harness assumes Windows + Revit + the Khepri plugin.
  if gate_enabled("KHEPRI_REVIT_TESTS")
    require_windows("KhepriRevit live")
    # verbose=true prints a summary line for each nested @testset as it
    # completes, instead of buffering everything until the outermost one
    # finishes. This makes it possible to tell where the suite is in real
    # time, and to see how far we got if a later test hangs the connection.
    @testset verbose=true "Live Revit (FamilyTests)" begin
      include("FamilyTests.jl")
    end
  end
end

hook_arity_guard(KhepriRevit)

# KhepriRhino tests — Rhino SocketBackend via C# plugin
#
# Tests cover module loading, type system, backend configuration,
# GUID-based references, and material/family types. Actual Rhino
# operations require a running Rhino instance with the Khepri plugin.

using KhepriRhino
using KhepriBase
using Test

@testset "KhepriRhino.jl" begin

  @testset "Type system" begin
    @test isdefined(KhepriRhino, :RHKey)
    @test KhepriRhino.RHId === KhepriBase.Guid  # UInt128
    @test isdefined(KhepriRhino, :RHRef)
    @test isdefined(KhepriRhino, :RHNativeRef)
    @test KhepriRhino.RH === SocketBackend{KhepriRhino.RHKey, KhepriBase.Guid}
  end

  @testset "Backend initialization" begin
    @test rhino isa KhepriBase.Backend
    @test KhepriBase.backend_name(rhino) == "Rhino"
    @test KhepriBase.void_ref(rhino) === UInt128(0)
  end

  @testset "Shape storage and boolean ops" begin
    @test KhepriBase.shape_storage_type(KhepriRhino.RH) isa KhepriBase.RemoteShapeStorage
    @test KhepriBase.has_boolean_ops(KhepriRhino.RH) isa KhepriBase.HasBooleanOps{false}
  end

  @testset "Material types" begin
    @test isdefined(KhepriRhino, :RhinoDefaultMaterial)
    @test KhepriRhino.rhino_default_material === KhepriRhino.RhinoDefaultMaterial
  end

  @testset "Family types" begin
    @test isdefined(KhepriRhino, :RhinoFamily)
    @test KhepriRhino.RhinoFamily <: KhepriBase.Family
    @test isdefined(KhepriRhino, :RhinoLayerFamily)
    @test KhepriRhino.RhinoLayerFamily <: KhepriRhino.RhinoFamily
  end

  # Visual regression tests (require running Rhino with Khepri plugin on Windows)
  if get(ENV, "KHEPRI_RHINO_TESTS", "0") == "1"
    if !Sys.iswindows()
      error("Rhino visual tests require Windows. Run these tests from a native Windows Julia installation.")
    end
    @testset "Visual Regression (Rhino)" begin
      include(joinpath(dirname(pathof(KhepriBase)), "..", "test", "VisualTests.jl"))
      using .VisualTests

      run_visual_tests(rhino,
        golden_dir = joinpath(@__DIR__, "golden"),
        reset! = () -> begin
          delete_all_shapes()
          backend(rhino)
        end,
        compare = pixel_diff_compare,
        skip = Symbol[]
      )
    end
  end
end

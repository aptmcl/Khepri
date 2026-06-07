# KhepriRhino tests — Rhino SocketBackend via C# plugin
#
# Tests cover module loading, type system, backend configuration,
# GUID-based references, and material/family types. Actual Rhino
# operations require a running Rhino instance with the Khepri plugin.

using KhepriRhino
using KhepriBase
using KhepriBase: SocketBackend
using Test

@testset "KhepriRhino.jl" begin

  @testset "RPC Conformance (static)" begin
    # Every @remote/@get_remote RPC the adapter calls must be declared in its
    # @remote_api block. Catches the undeclared-RPC crash class at CI, with no
    # live CAD connection (reads getfield(rhino, :remote) + parses source).
    include(joinpath(dirname(pathof(KhepriBase)), "..", "test", "RPCConformanceTests.jl"))
    using .RPCConformanceTests
    run_rpc_conformance_tests(rhino, joinpath(dirname(pathof(KhepriRhino))))
  end

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

  @testset "Exact geometry capabilities" begin
    @test KhepriBase.supports_exact_interpolating_spline_curves(KhepriRhino.RH)
    @test KhepriBase.supports_exact_bezier_curves(KhepriRhino.RH)
    @test KhepriBase.supports_exact_bspline_curves(KhepriRhino.RH)
    @test KhepriBase.supports_exact_nurbs_curves(KhepriRhino.RH)
    @test KhepriBase.supports_exact_polycurves(KhepriRhino.RH)
    @test KhepriBase.supports_exact_bezier_surfaces(KhepriRhino.RH)
    @test KhepriBase.supports_exact_bspline_surfaces(KhepriRhino.RH)
    @test KhepriBase.supports_exact_nurbs_surfaces(KhepriRhino.RH)
    @test !KhepriBase.supports_exact_trimmed_surfaces(KhepriRhino.RH)
  end

  @testset "Backend geometry mapping" begin
    report = KhepriBase.backend_geometry_mapping(rhino)
    @test report.import_mapping.storage == :remote_refs
    @test report.import_mapping.all_shapes
    @test report.import_mapping.create_shape
    @test report.operations.closest_points_path_path
    @test report.operations.project_point_surface
    @test report.operations.classify_region_point
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

  @testset "Light & render RPCs declared in rhino_api (SOCKETBK-3/4)" begin
    api = KhepriRhino.rhino_api
    # b_spotlight/b_ieslight call these; they were missing from the @remote_api
    # block, so every spot/IES light crashed with a NamedTuple field error.
    @test :SpotLight in keys(api)
    @test :IESLight in keys(api)
    # the non-realistic (clay) render path calls RenderLoadHDRiEnvironment, which
    # must be declared (matching the plugin); the two stale names must be gone.
    @test :RenderLoadHDRiEnvironment in keys(api)
    @test !(:RenderLoadKhepriEnvironment in keys(api))
    @test !(:RenderLoadEnvironment in keys(api))
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
        setup_backend = () -> begin
          delete_all_shapes()
          backend(rhino)
        end,
        reset! = () -> begin
          delete_all_shapes()
          backend(rhino)
        end,
        compare = pixel_diff_compare,
        skip = Symbol[]
      )
    end
  end

  # Combinatorial stress tests (require running Rhino with Khepri plugin on
  # Windows). Distinct from visual regression: rather than comparing rendered
  # output, these exercise hundreds of argument combinations per modeling
  # operation and assert that the backend tolerates them without error. The
  # produced shapes remain visible in Rhino after the run for manual
  # inspection — each test occupies a unique grid slot.
  if get(ENV, "KHEPRI_RHINO_STRESS_TESTS", "0") == "1"
    if !Sys.iswindows()
      error("Rhino stress tests require Windows. Run these tests from a native Windows Julia installation.")
    end
    @testset "Stress (Rhino)" begin
      include(joinpath(dirname(pathof(KhepriBase)), "..", "test", "BackendStressTests.jl"))
      using .BackendStressTests

      run_stress_tests(rhino,
        reset! = () -> begin
          delete_all_shapes()
          backend(rhino)
        end,
        verify = :envelope,
        skip = Symbol[])
    end
  end

  if get(ENV, "KHEPRI_RHINO_EXACT_GEOMETRY_TESTS", "0") == "1"
    if !Sys.iswindows()
      error("Rhino exact geometry tests require Windows. Run these tests from a native Windows Julia installation.")
    end
    @testset "Exact Geometry (Rhino)" begin
      include(joinpath(dirname(pathof(KhepriBase)), "..", "test", "ExactGeometrySmokeTests.jl"))
      using .ExactGeometrySmokeTests

      delete_all_shapes()
      backend(rhino)
      run_exact_geometry_smoke_tests(rhino)
    end
  end
end

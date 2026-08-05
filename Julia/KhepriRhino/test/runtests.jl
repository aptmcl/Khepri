# KhepriRhino tests — Rhino SocketBackend via C# plugin
#
# Tests cover module loading, type system, backend configuration,
# GUID-based references, and material/family types. Actual Rhino
# operations require a running Rhino instance with the Khepri plugin.

using KhepriRhino
using KhepriBase
using KhepriBase: SocketBackend
using Test

include(joinpath(pkgdir(KhepriBase), "test", "BackendTestScaffolding.jl"))
using .BackendTestScaffolding

@testset "KhepriRhino.jl" begin

  @testset "RPC Conformance (static)" begin
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
  if gate_enabled("KHEPRI_RHINO_TESTS")
    require_windows("Rhino visual")
    @testset "Visual Regression (Rhino)" begin
      # No setup_backend override: the default setup_raw_view(b) path exercises
      # b_setup_raw_view(::RH) (src/Rhino.jl), which an override would bypass.
      run_visual_tests(rhino,
        golden_dir = joinpath(@__DIR__, "golden"),
        # Rhino's boolean Unite fails for this scene's union (NOTOK "Union
        # failed: could not add result to document", live-verified
        # 2026-08-05) — a geometry-kernel limitation for its coincident
        # faces, not a harness issue. Unblock: fix Primitives.Unite in
        # Plugins/KhepriRhinoceros (e.g. tolerant boolean or piecewise
        # fallback) and re-mint.
        skip_tests = ["abobadasRomanas"],
        reset! = () -> begin
          delete_all_shapes()
          backend(rhino)
        end,
        compare = pixel_diff_compare,
        backend_module = KhepriRhino,
        skip = Symbol[]
      )
    end
  end

  # Wire benchmark (requires running Rhino): guards the socket loop against
  # performance regressions — Rhino is the most sensitive host (a batching
  # collapse costs one ~66 ms RhinoApp.Idle tick per op).
  if gate_enabled("KHEPRI_RHINO_BENCH")
    require_windows("Rhino bench")
    run_wire_benchmark(rhino)
  end

  # Combinatorial stress tests (require running Rhino with Khepri plugin on
  # Windows). The produced shapes remain visible in Rhino after the run for
  # manual inspection.
  if gate_enabled("KHEPRI_RHINO_STRESS_TESTS")
    require_windows("Rhino stress")
    @testset "Stress (Rhino)" begin
      run_stress_tests(rhino,
        reset! = () -> begin
          delete_all_shapes()
          backend(rhino)
        end,
        verify = :envelope,
        skip = stress_skip_from_env())
    end
  end

  if gate_enabled("KHEPRI_RHINO_EXACT_GEOMETRY_TESTS")
    require_windows("Rhino exact geometry")
    @testset "Exact Geometry (Rhino)" begin
      delete_all_shapes()
      backend(rhino)
      run_exact_geometry_smoke_tests(rhino)
    end
  end
end

hook_arity_guard(KhepriRhino)

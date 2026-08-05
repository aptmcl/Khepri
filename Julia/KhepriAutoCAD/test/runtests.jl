# KhepriAutoCAD tests — AutoCAD SocketBackend via C# plugin
#
# Tests cover module loading, type system, backend configuration,
# and pure-Julia constants/helpers. Actual AutoCAD operations
# require a running AutoCAD instance with the Khepri plugin.

using KhepriAutoCAD
using KhepriBase: SocketBackend
using Test

include(joinpath(pkgdir(KhepriBase), "test", "BackendTestScaffolding.jl"))
using .BackendTestScaffolding

@testset "KhepriAutoCAD.jl" begin

  @testset "RPC Conformance (static)" begin
    run_rpc_conformance_tests(autocad, joinpath(dirname(pathof(KhepriAutoCAD))))
  end

  @testset "Type system" begin
    @test isdefined(KhepriAutoCAD, :ACADKey)
    @test KhepriAutoCAD.ACADId === Int64
    @test isdefined(KhepriAutoCAD, :ACADRef)
    @test isdefined(KhepriAutoCAD, :ACADNativeRef)
    @test KhepriAutoCAD.ACAD === SocketBackend{KhepriAutoCAD.ACADKey, Int64}
  end

  @testset "Backend initialization" begin
    @test autocad isa KhepriBase.Backend
    @test KhepriBase.backend_name(autocad) == "AutoCAD"
    @test KhepriBase.void_ref(autocad) === Int64(-1)
  end

  @testset "Configuration parameters" begin
    @test KhepriAutoCAD.autocad_template isa KhepriBase.Parameter
    @test KhepriAutoCAD.use_shx isa KhepriBase.Parameter
    @test use_shx() isa Bool
  end

  @testset "Dimension styles" begin
    d = KhepriAutoCAD.ACADDimensionStyles
    @test d isa Dict
    @test haskey(d, :architectural)
    @test haskey(d, :mechanical)
    @test d[:architectural] == "_ARCHTICK"
  end

  @testset "Render helpers" begin
    @test KhepriAutoCAD.acad_neutral_exposure == 13.0
    @test KhepriAutoCAD.convert_render_exposure(autocad, -3) ≈ 21
    @test KhepriAutoCAD.convert_render_exposure(autocad, 0) ≈ KhepriAutoCAD.acad_neutral_exposure
    @test KhepriAutoCAD.convert_render_exposure(autocad, 3) ≈ -6
    @test KhepriAutoCAD.convert_render_quality(autocad, -1) == 1
    @test KhepriAutoCAD.convert_render_quality(autocad, 1) == 50

    @test KhepriAutoCAD.acad_visual_style_name(:wireframe) == "Wireframe"
    @test KhepriAutoCAD.acad_visual_style_name(:arctic) == "ShadesOfGray"
    @test KhepriAutoCAD.acad_visual_style_name(:technical) == "Hidden"
    @test KhepriAutoCAD.acad_visual_style_name(:ghosted) == "X-Ray"
    @test_throws ErrorException KhepriAutoCAD.acad_visual_style_name(:bogus)

    @test KhepriAutoCAD.acad_autodesk_root() == raw"C:\Program Files\Autodesk"
    @test KhepriAutoCAD.acad_environment_file_candidate(raw"C:\Env", "studio.hdr") == raw"C:\Env\studio.hdr"
    @test KhepriAutoCAD.acad_environment_dir_candidate(KhepriAutoCAD.acad_autodesk_root(), "AutoCAD 2025") ==
          raw"C:\Program Files\Autodesk\AutoCAD 2025\Environments"

    profile = KhepriAutoCAD.acad_render_profile(:white, 12, 1.5)
    @test profile.level == 12
    @test profile.rotation_mode == :view
    @test profile.exposure == 1.5
    @test profile.default_visual_style == :arctic

    opts = KhepriBase.RenderViewOptions(kind=:white)
    @test KhepriAutoCAD.acad_effective_render_visual_style(opts, profile) == :arctic
    opts = KhepriBase.RenderViewOptions(kind=:white, visual_style=:wireframe)
    @test KhepriAutoCAD.acad_effective_render_visual_style(opts, profile) == :wireframe
    @test_throws ErrorException KhepriAutoCAD.acad_render_profile(:black, 12, 1.5)
  end

  @testset "Material named tuples" begin
    mp = KhepriAutoCAD.MaterialProjection
    @test mp.InheritProjection == 0
    @test mp.Planar == 1
    @test mp.Box == 2
    @test mp.Cylinder == 3
    @test mp.Sphere == 4

    mt = KhepriAutoCAD.MaterialTiling
    @test mt.InheritTiling == 0
    @test mt.Tile == 1
    @test mt.Crop == 2
    @test mt.Clamp == 3
    @test mt.Mirror == 4
  end

  @testset "Exact geometry capabilities" begin
    @test KhepriBase.supports_exact_interpolating_spline_curves(KhepriAutoCAD.ACAD)
    @test KhepriBase.supports_exact_bezier_curves(KhepriAutoCAD.ACAD)
    @test KhepriBase.supports_exact_bspline_curves(KhepriAutoCAD.ACAD)
    @test KhepriBase.supports_exact_nurbs_curves(KhepriAutoCAD.ACAD)
    @test KhepriBase.supports_exact_polycurves(KhepriAutoCAD.ACAD)
    @test KhepriBase.supports_exact_bezier_surfaces(KhepriAutoCAD.ACAD)
    @test KhepriBase.supports_exact_bspline_surfaces(KhepriAutoCAD.ACAD)
    @test KhepriBase.supports_exact_nurbs_surfaces(KhepriAutoCAD.ACAD)
    @test !KhepriBase.supports_exact_trimmed_surfaces(KhepriAutoCAD.ACAD)
  end

  @testset "AutoCADBasicMaterial maps to CreateMaterialNamed (SOCKETBK-8)" begin
    # b_get_material(::ACAD, ::AutoCADBasicMaterial) feeds these struct fields to
    # CreateMaterialNamed's 15 parameters. A prior bug referenced three fields that
    # do not exist (texture_path / diffuse_map_source / bump_map_source) and passed
    # 17 args, so any AutoCADBasicMaterial crashed on resolution. Guard that every
    # field the call maps is real and that the specialized method is selected.
    M = KhepriAutoCAD.AutoCADBasicMaterial
    for f in (:name, :diffuse_blend_map_source, :u_scale, :v_scale, :u_offset, :v_offset,
              :projection, :u_tiling, :v_tiling, :diffuse_color, :refraction_index,
              :opacity, :reflectivity, :translucence, :illumination_model)
      @test hasfield(M, f)
    end
    T = SocketBackend{KhepriAutoCAD.ACADKey, Int64}
    @test which(KhepriBase.b_get_material, (T, M)).module === KhepriAutoCAD
  end

  # Visual regression tests (require running AutoCAD with Khepri plugin on Windows)
  if gate_enabled("KHEPRI_AUTOCAD_TESTS")
    require_windows("AutoCAD visual")
    @testset "Visual Regression (AutoCAD)" begin
      setup_test_view(autocad)
      try
        run_visual_tests(autocad,
          golden_dir = joinpath(@__DIR__, "golden"),
          reset! = () -> begin
            delete_all_shapes()
            backend(autocad)
          end,
          # 1280x720, not the 1920x1080 default: SaveView captures the real
          # viewport, and a viewport of the full screen size can never exist
          # (window chrome must fit too) — the old 225x56 golden set died on
          # exactly this. 720p fits any modern display with room for chrome.
          width = 1280,
          height = 720,
          compare = pixel_diff_compare,
          backend_module = KhepriAutoCAD,
          skip = Symbol[])
      finally
        teardown_test_view(autocad)
      end
    end
  end

  # Wire benchmark (requires running AutoCAD): guards the socket loop against
  # performance regressions — batching collapses only show against a live app.
  if gate_enabled("KHEPRI_AUTOCAD_BENCH")
    require_windows("AutoCAD bench")
    run_wire_benchmark(autocad)
  end

  # Combinatorial stress tests (require running AutoCAD with Khepri plugin on Windows)
  if gate_enabled("KHEPRI_AUTOCAD_STRESS_TESTS")
    require_windows("AutoCAD stress")
    @testset "Stress (AutoCAD)" begin
      run_stress_tests(autocad,
        reset! = () -> begin
          delete_all_shapes()
          backend(autocad)
        end,
        verify = :envelope,
        skip = stress_skip_from_env())
    end
  end

  if gate_enabled("KHEPRI_AUTOCAD_EXACT_GEOMETRY_TESTS")
    require_windows("AutoCAD exact geometry")
    @testset "Exact Geometry (AutoCAD)" begin
      delete_all_shapes()
      backend(autocad)
      run_exact_geometry_smoke_tests(autocad)
    end
  end
end

hook_arity_guard(KhepriAutoCAD)

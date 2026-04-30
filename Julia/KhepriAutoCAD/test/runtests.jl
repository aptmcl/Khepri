# KhepriAutoCAD tests — AutoCAD SocketBackend via C# plugin
#
# Tests cover module loading, type system, backend configuration,
# and pure-Julia constants/helpers. Actual AutoCAD operations
# require a running AutoCAD instance with the Khepri plugin.

using KhepriAutoCAD
using KhepriBase: SocketBackend
using Test

@testset "KhepriAutoCAD.jl" begin

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

  # Visual regression tests (require running AutoCAD with Khepri plugin on Windows)
  if get(ENV, "KHEPRI_AUTOCAD_TESTS", "0") == "1"
    if !Sys.iswindows()
      error("AutoCAD visual tests require Windows. Run these tests from a native Windows Julia installation.")
    end
    @testset "Visual Regression (AutoCAD)" begin
      include(joinpath(dirname(pathof(KhepriBase)), "..", "test", "VisualTests.jl"))
      using .VisualTests

      setup_test_view(autocad)
      try
        run_visual_tests(autocad,
          golden_dir = joinpath(@__DIR__, "golden"),
          reset! = () -> begin
            delete_all_shapes()
            backend(autocad)
          end,
          compare = pixel_diff_compare,
          skip = Symbol[])
      finally
        teardown_test_view(autocad)
      end
    end
  end

  # Combinatorial stress tests (require running AutoCAD with Khepri plugin on
  # Windows). Distinct from visual regression: rather than comparing rendered
  # output, these exercise hundreds of argument combinations per modeling
  # operation and assert that the backend tolerates them without error. The
  # produced shapes remain visible in AutoCAD after the run for manual
  # inspection — each test occupies a unique grid slot.
  if get(ENV, "KHEPRI_AUTOCAD_STRESS_TESTS", "0") == "1"
    if !Sys.iswindows()
      error("AutoCAD stress tests require Windows. Run these tests from a native Windows Julia installation.")
    end
    @testset "Stress (AutoCAD)" begin
      include(joinpath(dirname(pathof(KhepriBase)), "..", "test", "BackendStressTests.jl"))
      using .BackendStressTests

      run_stress_tests(autocad,
        reset! = () -> begin
          delete_all_shapes()
          backend(autocad)
        end,
        verify = :envelope,
        skip = Symbol[])
    end
  end
end

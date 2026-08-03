# KhepriThebes tests - Tests for Thebes/Luxor 3D visualization backend

using KhepriThebes
using KhepriBase
using Thebes: Point3D
using Test

@testset "KhepriThebes.jl" begin

  @testset "Backend initialization" begin
    @testset "thebes backend exists" begin
      @test thebes isa KhepriBase.Backend
    end

    @testset "backend_name" begin
      @test KhepriBase.backend_name(thebes) == "Thebes"
    end

    @testset "void_ref" begin
      vr = KhepriBase.void_ref(thebes)
      @test vr === 0
    end

    @testset "has refs field" begin
      @test hasproperty(thebes, :refs)
      @test thebes.refs isa KhepriBase.References
    end

    @testset "has transaction field" begin
      @test hasproperty(thebes, :transaction)
    end

    @testset "has drawing field" begin
      @test hasproperty(thebes, :drawing)
    end

    @testset "has view field" begin
      @test hasproperty(thebes, :view)
      @test thebes.view isa KhepriBase.View
    end
  end

  @testset "Type system" begin
    @testset "ThebesKey type exists" begin
      @test isdefined(KhepriThebes, :ThebesKey)
    end

    @testset "ThebesId type exists" begin
      @test isdefined(KhepriThebes, :ThebesId)
      @test KhepriThebes.ThebesId === Int
    end

    @testset "ThebesRef type exists" begin
      @test isdefined(KhepriThebes, :ThebesRef)
    end

    @testset "ThebesNativeRef type exists" begin
      @test isdefined(KhepriThebes, :ThebesNativeRef)
    end

    @testset "TBS is alias for ThebesBackend" begin
      @test KhepriThebes.TBS === KhepriThebes.ThebesBackend
    end
  end

  @testset "Coordinate conversion" begin
    @testset "to_pt3d function exists" begin
      @test isdefined(KhepriThebes, :to_pt3d)
    end

    @testset "to_pt3ds function exists" begin
      @test isdefined(KhepriThebes, :to_pt3ds)
    end

    @testset "to_pt3d converts Loc to Point3D" begin
      p = xyz(1, 2, 3)
      p3d = KhepriThebes.to_pt3d(p)
      @test p3d isa Point3D
      @test p3d.x == 1
      @test p3d.y == 2
      @test p3d.z == 3
    end
  end

  @testset "Drawing management" begin
    @testset "ensure_drawing function exists" begin
      @test isdefined(KhepriThebes, :ensure_drawing)
    end

    @testset "reset_thebes function exists" begin
      @test isdefined(KhepriThebes, :reset_thebes)
    end

    @testset "reset_thebes clears drawing" begin
      reset_thebes()
      @test isnothing(thebes.drawing)
    end
  end

  @testset "Camera control" begin
    @testset "set_thebes_camera function exists" begin
      @test isdefined(KhepriThebes, :set_thebes_camera)
    end

    @testset "set_thebes_camera updates camera" begin
      new_cam = xyz(50, 50, 50)
      new_target = xyz(0, 0, 0)
      set_thebes_camera(thebes, new_cam, new_target)
      @test thebes.view.camera == new_cam
      @test thebes.view.target == new_target
    end
  end

  @testset "Visualization functions" begin
    @testset "preview_thebes function exists" begin
      @test isdefined(KhepriThebes, :preview_thebes)
    end

    @testset "save_thebes function exists" begin
      @test isdefined(KhepriThebes, :save_thebes)
    end
  end

  @testset "Output format" begin
    @testset "default format is SVG" begin
      reset_thebes()
      @test thebes.output_format == :svg
    end

    @testset "set_thebes_format! changes format" begin
      reset_thebes()
      set_thebes_format!(:png)
      @test thebes.output_format == :png
      set_thebes_format!(:svg)  # restore default
    end

    @testset "format_extension works" begin
      @test KhepriThebes.format_extension(:svg) == ".svg"
      @test KhepriThebes.format_extension(:png) == ".png"
      @test KhepriThebes.format_extension(:pdf) == ".pdf"
    end

    @testset "extension_to_format works" begin
      @test KhepriThebes.extension_to_format(".svg") == :svg
      @test KhepriThebes.extension_to_format(".png") == :png
      @test KhepriThebes.extension_to_format(".pdf") == :pdf
      @test KhepriThebes.extension_to_format(".SVG") == :svg  # case insensitive
    end
  end

  @testset "Material support" begin
    @testset "extract_color from RGBA" begin
      c = KhepriThebes.extract_color(rgba(1.0, 0.5, 0.0, 1.0))
      @test c isa RGBA
      @test red(c) == 1.0
      @test green(c) == 0.5
    end

    @testset "extract_color from Nothing" begin
      c = KhepriThebes.extract_color(nothing)
      @test isnothing(c)
    end

    @testset "extract_color from object with base_color" begin
      # Create a simple struct to test base_color extraction
      # This mimics how pbr_material works
      struct TestMaterial
        base_color::RGBA
      end
      mat = TestMaterial(rgba(0.8, 0.2, 0.1, 1.0))
      c = KhepriThebes.extract_color(mat)
      @test c isa RGBA
      @test red(c) ≈ 0.8
      @test green(c) ≈ 0.2
      @test blue(c) ≈ 0.1
    end

    @testset "b_trig with RGBA color" begin
      reset_thebes()
      color = rgba(1.0, 0.0, 0.0, 1.0)
      KhepriBase.b_trig(thebes, xy(0, 0), xy(1, 0), xy(0.5, 1), color)
      # With retained mode, shapes are stored in scene, not drawn immediately
      @test !isempty(thebes.scene)
    end
  end

  @testset "Shape creation (integration)" begin
    reset_thebes()
    backend(thebes)

    @testset "b_point adds to scene" begin
      reset_thebes()
      @test isempty(thebes.scene)
      KhepriBase.b_point(thebes, xy(0, 0), KhepriBase.void_ref(thebes))
      @test !isempty(thebes.scene)
    end

    @testset "b_line works" begin
      reset_thebes()
      KhepriBase.b_line(thebes, [xy(0, 0), xy(1, 1)], KhepriBase.void_ref(thebes))
      @test !isempty(thebes.scene)
    end

    @testset "b_polygon works" begin
      reset_thebes()
      KhepriBase.b_polygon(thebes, [xy(0, 0), xy(1, 0), xy(0.5, 1)], KhepriBase.void_ref(thebes))
      @test !isempty(thebes.scene)
    end

    @testset "b_circle works" begin
      reset_thebes()
      KhepriBase.b_circle(thebes, xy(0, 0), 5.0, KhepriBase.void_ref(thebes))
      @test !isempty(thebes.scene)
    end

    @testset "b_trig works" begin
      reset_thebes()
      KhepriBase.b_trig(thebes, xy(0, 0), xy(1, 0), xy(0.5, 1), KhepriBase.void_ref(thebes))
      @test !isempty(thebes.scene)
    end

    @testset "b_surface_polygon works" begin
      reset_thebes()
      KhepriBase.b_surface_polygon(thebes, [xy(0, 0), xy(1, 0), xy(1, 1), xy(0, 1)], KhepriBase.void_ref(thebes))
      @test !isempty(thebes.scene)
    end
  end

  @testset "standard_material rendering" begin
    reset_thebes()
    backend(thebes)
    delete_all_shapes()

    red_mat = standard_material("RedMat", rgba(1, 0, 0, 1))
    sphere(u0(), 5, material=red_mat)

    path = tempname() * ".svg"
    save_thebes(path)
    svg = read(path, String)
    rm(path, force=true)

    # Luxor renders fills as rgb(XX%, 0%, 0%) for red materials.
    # Verify the SVG contains red-only fills (nonzero red, zero green/blue).
    @test occursin("fill", svg)
    @test occursin(r"fill=\"rgb\(\d+\.\d+%, 0%, 0%\)\"", svg)
  end

  # Clean up
  reset_thebes()

  # Visual regression tests
  @testset "Visual Regression (Thebes)" begin
    include(joinpath(dirname(pathof(KhepriBase)), "..", "test", "VisualTests.jl"))
    using .VisualTests

    #=
    Some scenes produce non-deterministic SVG output between runs (path
    ordering varies — likely due to dict-iteration order or Z-sort tie-
    breaking on coplanar faces). They pass once a golden is captured but
    fail subsequent runs even with no code change. Skip them under
    text_compare; revisit when Thebes either canonicalises path output or
    when this test framework supports a pixel/perceptual comparator.
    =#
    nondeterministic_skip = [
      "florCirculosExtrudidos",
      "abrigoEsfericoTubos",
      "predioSinusoidal",
      "corrimaoCaracol",
    ]
    run_visual_tests(thebes,
      golden_dir = joinpath(@__DIR__, "golden"),
      reset! = () -> begin
        reset_thebes()
        delete_all_shapes()
        backend(thebes)
      end,
      compare = text_compare,
      skip = [:csg],
      skip_tests = nondeterministic_skip,
    )
  end

  # Conformance tests
  @testset "Backend Conformance (Thebes)" begin
    include(joinpath(dirname(pathof(KhepriBase)), "..", "test", "BackendConformanceTests.jl"))
    using .BackendConformanceTests

    run_conformance_tests(thebes,
      reset! = () -> begin
        reset_thebes()
        delete_all_shapes()
        backend(thebes)
      end,
      skip = Symbol[]
    )
  end
end

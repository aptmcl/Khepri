# KhepriBlender tests — Blender SocketBackend via Python plugin
#
# Tests cover module loading, type system, backend configuration,
# and exported helpers. Actual Blender operations require a running
# Blender instance with the KhepriServer Python plugin.

using KhepriBlender
using KhepriBase
using KhepriBase: SocketBackend
using Test

@testset "KhepriBlender.jl" begin

  @testset "Type system" begin
    @test isdefined(KhepriBlender, :BLRKey)
    @test KhepriBlender.BLRId === Union{Int32, String}
    @test KhepriBlender.BLR === SocketBackend{KhepriBlender.BLRKey, Union{Int32, String}}
  end

  @testset "Backend initialization" begin
    @test blender isa KhepriBase.Backend
    @test KhepriBase.backend_name(blender) == "Blender"
    @test KhepriBase.void_ref(blender) === Int32(-1)
  end

  @testset "Configuration parameters" begin
    @test KhepriBlender.headless_blender isa KhepriBase.Parameter
    @test headless_blender() isa Bool
  end

  @testset "Exported helpers" begin
    @test isdefined(KhepriBlender, :start_blender)
    @test isdefined(KhepriBlender, :blender_family_materials)
    # blender_family_materials creates a named tuple with 4 materials
    mats = blender_family_materials("mat1")
    @test mats isa NamedTuple
    @test haskey(mats, :materials)
    @test length(mats.materials) == 4
    @test all(==( "mat1"), mats.materials)

    # With distinct materials
    mats2 = blender_family_materials("a", "b", "c", "d")
    @test mats2.materials == ("a", "b", "c", "d")
  end

  @testset "Visual-style API" begin
    # Canonical vocabulary is populated (from KhepriBase).
    @test :arctic in canonical_visual_styles
    @test :realistic in canonical_visual_styles

    # Every canonical style maps to a Blender renderer (no lookup errors).
    for s in canonical_visual_styles
      @test haskey(KhepriBlender.blender_visual_style_renderers, s)
    end
    @test KhepriBlender.blender_visual_style_renderers[:realistic] === :cycles
    @test KhepriBlender.blender_visual_style_renderers[:shaded]    === :eevee
    @test KhepriBlender.blender_visual_style_renderers[:arctic]    === :clay
    @test KhepriBlender.blender_visual_style_renderers[:technical] === :freestyle
    @test KhepriBlender.blender_visual_style_renderers[:pen]       === :freestyle
    @test KhepriBlender.blender_visual_style_renderers[:wireframe] === :freestyle

    # Samples dial: quality=0 gives per-renderer baseline; ±1 scales by 16.
    @test KhepriBlender.blender_samples_for_quality(0.0, :cycles) == 1024
    @test KhepriBlender.blender_samples_for_quality(0.0, :eevee)  == 64
    @test KhepriBlender.blender_samples_for_quality(0.0, :clay)   == 256
    @test KhepriBlender.blender_samples_for_quality(-1.0, :eevee) == 4
    @test KhepriBlender.blender_samples_for_quality(1.0, :clay)   == 256 * 16

    # Method dispatch: the 3-arg b_render_and_save_view(BLR, ...) is registered.
    m3 = methods(KhepriBase.b_render_and_save_view,
                 (KhepriBlender.BLR, String, KhepriBase.RenderViewOptions))
    @test length(m3) >= 1
  end

  @testset "headless_blender default" begin
    # On Linux (including WSL) and non-macOS non-Windows hosts, default to headless
    # so `using KhepriBlender; render_view(...)` works without a display server.
    if !Sys.iswindows() && !Sys.isapple()
      @test headless_blender() == true
    else
      @test headless_blender() == false
    end
  end

  # Combinatorial stress tests (require Blender to connect to Julia's
  # khepri_socket_server). Unlike AutoCAD/Rhino which Julia connects out to,
  # Blender is the client: `using KhepriBlender` registers an init-function
  # and starts the socket server; `start_blender()` launches Blender which
  # connects in. The connected backend is then the top_backend(), not the
  # static `blender` constant.
  if get(ENV, "KHEPRI_BLENDER_STRESS_TESTS", "0") == "1"
    @testset "Stress (Blender)" begin
      include(joinpath(dirname(pathof(KhepriBase)), "..", "test", "BackendStressTests.jl"))
      using .BackendStressTests

      start_blender()
      # Wait up to 30s for Blender to connect.
      let connected_b = nothing, deadline = time() + 30
        while time() < deadline
          let bs = KhepriBase.current_backends()
            if !isempty(bs)
              connected_b = first(bs)
              break
            end
          end
          sleep(0.5)
        end
        connected_b === nothing &&
          error("Blender failed to connect within 30s. Check start_blender() output.")
        run_stress_tests(connected_b,
          reset! = () -> begin
            delete_all_shapes()
            backend(connected_b)
          end,
          verify = :envelope,
          skip = Symbol[])
      end
    end
  end
end

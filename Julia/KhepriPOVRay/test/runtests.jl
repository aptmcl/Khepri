# KhepriPOVRay tests - Tests for POV-Ray scene file generation

using KhepriPOVRay
using KhepriBase
using Test

include(joinpath(pkgdir(KhepriBase), "test", "BackendTestScaffolding.jl"))
using .BackendTestScaffolding

get_povray_output(b) = io_output(b)
clear_povray_buffer!(b) = clear_io!(b)

@testset "KhepriPOVRay.jl" begin

  @testset "Backend initialization" begin
    @testset "povray backend exists" begin
      @test povray isa KhepriBase.LocalBackend
    end

    @testset "backend_name" begin
      @test KhepriBase.backend_name(povray) == "POVRay"
    end

    @testset "void_ref" begin
      vr = KhepriBase.void_ref(povray)
      @test vr === -1
    end
  end

  @testset "POV-Ray MIME type output" begin
    @testset "location output" begin
      io = IOBuffer()
      p = xyz(1, 2, 3)
      show(io, KhepriPOVRay.MIMEPOVRay(), p)
      output = String(take!(io))
      # POV-Ray swaps y and z: <x, z, y>
      @test occursin("<", output)
      @test occursin(">", output)
      @test occursin("1", output)
    end

    @testset "RGB color output" begin
      io = IOBuffer()
      c = rgb(1.0, 0.5, 0.0)
      show(io, KhepriPOVRay.MIMEPOVRay(), c)
      output = String(take!(io))
      @test occursin("rgb", output)
      @test occursin("<", output)
    end
  end

  @testset "Backend drawing operations" begin
    @testset "b_sphere" begin
      clear_povray_buffer!(povray)
      KhepriBase.b_sphere(povray, xyz(0, 0, 0), 5.0, nothing)
      output = get_povray_output(povray)
      @test occursin("sphere", output)
      @test occursin("5", output)
    end

    @testset "b_box" begin
      clear_povray_buffer!(povray)
      KhepriBase.b_box(povray, xyz(0, 0, 0), 10.0, 5.0, 3.0, nothing)
      output = get_povray_output(povray)
      @test occursin("box", output)
    end

    @testset "b_cylinder" begin
      clear_povray_buffer!(povray)
      KhepriBase.b_cylinder(povray, xyz(0, 0, 0), 3.0, 10.0, nothing, nothing, nothing)
      output = get_povray_output(povray)
      @test occursin("cylinder", output) || occursin("cone", output)
    end

    @testset "b_cylinder capless: `open` precedes the texture" begin
      # POV-Ray's grammar requires OBJECT_FLAGS (`open`) right after the
      # radius, BEFORE object modifiers like `texture`. Emitting it after
      # the texture is a parse error ("No matching } in cylinder").
      clear_povray_buffer!(povray)
      KhepriBase.b_cylinder(povray, u0(), 1.0, 2.0, nothing, nothing,
                            KhepriPOVRay.POVRayDefinition("TMat", "texture", "{ pigment { color rgb 1 } }"))
      out = get_povray_output(povray)
      @test occursin("open", out)
      @test occursin("texture", out)
      @test first(findfirst("open", out)) < first(findfirst("texture", out))
    end

    @testset "b_trig" begin
      clear_povray_buffer!(povray)
      KhepriBase.b_trig(povray, xyz(0, 0, 0), xyz(1, 0, 0), xyz(0, 1, 0), nothing)
      output = get_povray_output(povray)
      @test occursin("triangle", output)
    end

    @testset "b_cone" begin
      clear_povray_buffer!(povray)
      KhepriBase.b_cone(povray, xyz(0, 0, 0), 3.0, 10.0, nothing, nothing)
      output = get_povray_output(povray)
      @test occursin("cone", output)
    end

    @testset "b_torus" begin
      clear_povray_buffer!(povray)
      KhepriBase.b_torus(povray, xyz(0, 0, 0), 10.0, 3.0, nothing)
      output = get_povray_output(povray)
      @test occursin("torus", output)
    end
  end

  @testset "Surface operations" begin
    @testset "b_surface_polygon" begin
      clear_povray_buffer!(povray)
      KhepriBase.b_surface_polygon(povray, [xyz(0, 0, 0), xyz(1, 0, 0), xyz(1, 1, 0), xyz(0, 1, 0)], nothing)
      output = get_povray_output(povray)
      @test length(output) > 0
    end

    @testset "b_surface_circle" begin
      clear_povray_buffer!(povray)
      KhepriBase.b_surface_circle(povray, xyz(0, 0, 0), 5.0, nothing)
      output = get_povray_output(povray)
      @test occursin("disc", output)
    end
  end

  @testset "View and rendering" begin
    @testset "povray has view field" begin
      @test hasfield(typeof(povray), :view)
    end

    @testset "povray has render_env field" begin
      @test hasproperty(povray, :render_env)
    end

    @testset "render_pathname function" begin
      path = KhepriBase.b_render_pathname(povray, "test")
      @test path isa String
      @test occursin("test", path)
    end
  end

  @testset "POV-Ray specific helpers" begin
    @testset "write_povray_param" begin
      io = IOBuffer()
      KhepriPOVRay.write_povray_param(io, "test_param", 5.0)
      output = String(take!(io))
      @test occursin("test_param", output)
      @test occursin("5", output)
    end

    @testset "write_povray_call" begin
      io = IOBuffer()
      KhepriPOVRay.write_povray_call(io, "translate", "<1, 2, 3>")
      output = String(take!(io))
      @test occursin("translate", output)
    end
  end

end

# ── Visual regression tests ──────────────────────────────────────────

#=
POV-Ray's remaining gaps are EXPLICIT skips with named unblock conditions,
not @test_broken: a broken-forever test asserts nothing and can never flip.
Verified 2026-08-05 by stub-probing the three missing hooks — these lists
are the complete gap.

CSG: objects are streamed to the buffer as SDL text and refs are bare -1
(see the has_boolean_ops comment in src/POVRay.jl), so nothing remains to
wrap in a native difference{}/intersection{} block. Unblock condition: a
ref-model refactor (#declare obj_N per object, refs as identifiers, final
assembly at save time) — it would flip all 15 scenes and requires a
reviewed regold of every golden, since it rewrites the text of every
emitted object.
=#
unimplemented_subtract_ref = [
  "csg_subtraction", "banheira", "abobadasRomanas", "cascasPerfuradas",
  "coberturaTubos", "coberturaTubos2", "coberturaTubos3",
  # These five arrive via slice(), whose default b_slice_ref subtracts a
  # half-space prism through b_subtract_ref.
  "tetraedroEvol", "duploTetraedro", "octahedro", "octaedroEstrelado",
  "calotaEsferica",
]
unimplemented_intersect_ref = [
  "csg_intersection", "cilindrosUniaoInterseccao", "csg_compound",
]

# The enclosing testset matters: without it the first failing scene's
# testset finish throws, aborting every later scene and suppressing the
# missing-sidecar summary (TikZ wraps its run the same way).
@testset "Visual Regression (POVRay)" begin
  run_visual_tests(povray,
    golden_dir = joinpath(@__DIR__, "golden"),
    reset! = () -> begin clear_io!(povray); delete_all_shapes(); backend(povray) end,
    compare = text_compare,
    # HEAVY_TESSELLATION_SCENES: these two minted 23 MB and 9.5 MB of
    # unreviewable tessellation output and were evicted (TestingStrategy.md
    # §8 step 0); they return once parse-and-measure validation can vouch
    # for artifacts of that size.
    skip_tests = vcat(unimplemented_subtract_ref,
                      unimplemented_intersect_ref,
                      HEAVY_TESSELLATION_SCENES),
  )
end

hook_arity_guard(KhepriPOVRay)

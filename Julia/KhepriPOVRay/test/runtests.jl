# KhepriPOVRay tests - Tests for POV-Ray scene file generation

using KhepriPOVRay
using KhepriBase
using Test

# Helper to get the output from the backend's IOBuffer
function get_povray_output(b)
  io = KhepriBase.connection(b)
  String(take!(io))
end

# Helper to clear the backend's buffer
function clear_povray_buffer!(b)
  io = KhepriBase.connection(b)
  take!(io)
  nothing
end

@testset "KhepriPOVRay.jl" begin

  @testset "Backend initialization" begin
    @testset "povray backend exists" begin
      @test povray isa KhepriBase.IOBackend
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
      @test hasfield(typeof(povray), :render_env)
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

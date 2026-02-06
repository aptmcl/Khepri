using Frame4DD
using Test

@testset "Input Validation" begin

  @testset "add_node!" begin
    m = Model()
    @test add_node!(m, 0.0, 0.0, 0.0) == 1
    @test_throws ArgumentError add_node!(m, 0.0, 0.0, 0.0; r=-1.0)
  end

  @testset "add_element!" begin
    m = Model()
    add_node!(m, 0.0, 0.0, 0.0)
    add_node!(m, 1.0, 0.0, 0.0)
    sec = Section(10.0, 5.0, 5.0, 1.0, 1.0, 1.0)
    mat = Material(29000.0, 11500.0, 7.33e-7)
    @test add_element!(m, 1, 2, sec, mat) == 1
    # Out-of-range nodes
    @test_throws ArgumentError add_element!(m, 0, 2, sec, mat)
    @test_throws ArgumentError add_element!(m, 1, 3, sec, mat)
    # Self-connecting
    @test_throws ArgumentError add_element!(m, 1, 1, sec, mat)
    # Coincident nodes
    add_node!(m, 0.0, 0.0, 0.0)  # node 3 = same as node 1
    @test_throws ArgumentError add_element!(m, 1, 3, sec, mat)
  end

  @testset "fix_node!" begin
    m = Model()
    add_node!(m, 0.0, 0.0, 0.0)
    fix_node!(m, 1; dx=true)
    @test_throws ArgumentError fix_node!(m, 0; dx=true)
    @test_throws ArgumentError fix_node!(m, 2; dx=true)
  end

  @testset "add_nodal_load!" begin
    lc = LoadCase()
    @test_throws ArgumentError add_nodal_load!(lc, 0; fx=10.0)
  end

  @testset "add_uniform_load!" begin
    lc = LoadCase()
    @test_throws ArgumentError add_uniform_load!(lc, 0; ux=1.0)
  end

  @testset "add_trapezoidal_load!" begin
    lc = LoadCase()
    @test_throws ArgumentError add_trapezoidal_load!(lc, 0)
  end

  @testset "add_point_load!" begin
    lc = LoadCase()
    @test_throws ArgumentError add_point_load!(lc, 0; px=1.0)
    @test_throws ArgumentError add_point_load!(lc, 1; px=1.0, a=-1.0)
  end

  @testset "add_temperature_load!" begin
    lc = LoadCase()
    @test_throws ArgumentError add_temperature_load!(lc, 0)
  end

  @testset "add_prescribed_displacement!" begin
    lc = LoadCase()
    @test_throws ArgumentError add_prescribed_displacement!(lc, 0; dx=1.0)
  end

  @testset "add_node_mass!" begin
    m = Model()
    add_node!(m, 0.0, 0.0, 0.0)
    @test_throws ArgumentError add_node_mass!(m, 0; mass=1.0)
    @test_throws ArgumentError add_node_mass!(m, 2; mass=1.0)
    @test_throws ArgumentError add_node_mass!(m, 1; mass=-1.0)
  end

  @testset "add_element_extra_mass!" begin
    m = Model()
    add_node!(m, 0.0, 0.0, 0.0)
    add_node!(m, 1.0, 0.0, 0.0)
    sec = Section(10.0, 5.0, 5.0, 1.0, 1.0, 1.0)
    mat = Material(29000.0, 11500.0, 7.33e-7)
    add_element!(m, 1, 2, sec, mat)
    @test_throws ArgumentError add_element_extra_mass!(m, 0; mass=1.0)
    @test_throws ArgumentError add_element_extra_mass!(m, 2; mass=1.0)
    @test_throws ArgumentError add_element_extra_mass!(m, 1; mass=-1.0)
  end

  @testset "solve validation" begin
    m = Model()
    # No nodes
    add_node!(m, 0.0, 0.0, 0.0)
    sec = Section(10.0, 5.0, 5.0, 1.0, 1.0, 1.0)
    mat = Material(29000.0, 11500.0, 7.33e-7)
    # Only 1 node
    @test_throws ArgumentError solve(m)

    add_node!(m, 1.0, 0.0, 0.0)
    # No elements
    @test_throws ArgumentError solve(m)

    add_element!(m, 1, 2, sec, mat)
    # No load cases
    @test_throws ArgumentError solve(m)

    lc = add_load_case!(m)
    add_nodal_load!(lc, 2; fy=-10.0)
    # No restraints
    @test_throws ArgumentError solve(m)
  end
end

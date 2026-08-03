using Frame4DD
using Test

"""
Build Example A: 2D truss, 12 nodes, 21 elements, 2 load cases.
Units: kips, inches.
"""
function build_example_A()
  model = Model(options=AnalysisOptions(shear=false, geometric=false))

  # Nodes
  add_node!(model, 0.0, 0.0, 0.0)      # 1
  add_node!(model, 120.0, 0.0, 0.0)     # 2
  add_node!(model, 240.0, 0.0, 0.0)     # 3
  add_node!(model, 360.0, 0.0, 0.0)     # 4
  add_node!(model, 480.0, 0.0, 0.0)     # 5
  add_node!(model, 600.0, 0.0, 0.0)     # 6
  add_node!(model, 720.0, 0.0, 0.0)     # 7
  add_node!(model, 120.0, 120.0, 0.0)   # 8
  add_node!(model, 240.0, 120.0, 0.0)   # 9
  add_node!(model, 360.0, 120.0, 0.0)   # 10
  add_node!(model, 480.0, 120.0, 0.0)   # 11
  add_node!(model, 600.0, 120.0, 0.0)   # 12

  # Restraints
  fix_node!(model, 1; dx=true, dy=true, dz=true, rx=true, ry=true)
  fix_node!(model, 2; dz=true, rx=true, ry=true)
  fix_node!(model, 3; dz=true, rx=true, ry=true)
  fix_node!(model, 4; dz=true, rx=true, ry=true)
  fix_node!(model, 5; dz=true, rx=true, ry=true)
  fix_node!(model, 6; dz=true, rx=true, ry=true)
  fix_node!(model, 7; dy=true, dz=true, rx=true, ry=true)
  fix_node!(model, 8; dx=true, dz=true, rx=true, ry=true)
  fix_node!(model, 9; dz=true, rx=true, ry=true)
  fix_node!(model, 10; dz=true, rx=true, ry=true)
  fix_node!(model, 11; dz=true, rx=true, ry=true)
  fix_node!(model, 12; dz=true, rx=true, ry=true)

  # Element properties (all identical)
  sec = Section(10.0, 1.0, 1.0, 1.0, 1.0, 0.01)
  mat = Material(29000.0, 11500.0, 7.33e-7)

  # Elements (21 total)
  # Bottom chord
  add_element!(model, 1, 2, sec, mat)   # 1
  add_element!(model, 2, 3, sec, mat)   # 2
  add_element!(model, 3, 4, sec, mat)   # 3
  add_element!(model, 4, 5, sec, mat)   # 4
  add_element!(model, 5, 6, sec, mat)   # 5
  add_element!(model, 6, 7, sec, mat)   # 6
  # Verticals / diagonals
  add_element!(model, 1, 8, sec, mat)   # 7
  add_element!(model, 2, 8, sec, mat)   # 8
  add_element!(model, 2, 9, sec, mat)   # 9
  add_element!(model, 3, 9, sec, mat)   # 10
  add_element!(model, 4, 9, sec, mat)   # 11
  add_element!(model, 4, 10, sec, mat)  # 12
  add_element!(model, 4, 11, sec, mat)  # 13
  add_element!(model, 5, 11, sec, mat)  # 14
  add_element!(model, 6, 11, sec, mat)  # 15
  add_element!(model, 6, 12, sec, mat)  # 16
  add_element!(model, 7, 12, sec, mat)  # 17
  # Top chord
  add_element!(model, 8, 9, sec, mat)   # 18
  add_element!(model, 9, 10, sec, mat)  # 19
  add_element!(model, 10, 11, sec, mat) # 20
  add_element!(model, 11, 12, sec, mat) # 21

  # Load Case 1: Concentrated loads + prescribed displacement
  lc1 = add_load_case!(model)
  add_nodal_load!(lc1, 2; fy=-10.0)
  add_nodal_load!(lc1, 3; fy=-20.0)
  add_nodal_load!(lc1, 4; fy=-20.0)
  add_nodal_load!(lc1, 5; fy=-10.0)
  add_nodal_load!(lc1, 6; fy=-20.0)
  add_prescribed_displacement!(lc1, 8; dx=0.1)

  # Load Case 2: Horizontal loads + temperature + prescribed displacements
  lc2 = add_load_case!(model)
  add_nodal_load!(lc2, 3; fx=20.0)
  add_nodal_load!(lc2, 4; fx=10.0)
  add_nodal_load!(lc2, 5; fx=20.0)
  add_temperature_load!(lc2, 10; alpha=6e-12, hy=5.0, hz=5.0,
    ty_pos=10.0, ty_neg=10.0, tz_pos=10.0, tz_neg=10.0)
  add_temperature_load!(lc2, 13; alpha=6e-12, hy=5.0, hz=5.0,
    ty_pos=15.0, ty_neg=15.0, tz_pos=15.0, tz_neg=15.0)
  add_temperature_load!(lc2, 15; alpha=6e-12, hy=5.0, hz=5.0,
    ty_pos=17.0, ty_neg=17.0, tz_pos=17.0, tz_neg=17.0)
  add_prescribed_displacement!(lc2, 1; dy=-1.0)
  add_prescribed_displacement!(lc2, 8; dx=0.1)

  return model
end

"""
Build Example B: pyramid-shaped frame, 5 nodes, 4 elements, 3 load cases + modal.
Units: N, mm, metric tons.
"""
function build_example_B()
  modal = ModalOptions(6; method=SubspaceJacobi, lumped=false, tol=1e-9, shift=0.0)
  model = Model(options=AnalysisOptions(shear=true, geometric=true, tol=1e-9, modal=modal))

  # Nodes
  add_node!(model, 0.0, 0.0, 1000.0)     # 1 (apex, free)
  add_node!(model, -1200.0, -900.0, 0.0)  # 2
  add_node!(model, 1200.0, -900.0, 0.0)   # 3
  add_node!(model, 1200.0, 900.0, 0.0)    # 4
  add_node!(model, -1200.0, 900.0, 0.0)   # 5

  # Restraints (all base nodes fully fixed)
  fix_node!(model, 2; dx=true, dy=true, dz=true, rx=true, ry=true, rz=true)
  fix_node!(model, 3; dx=true, dy=true, dz=true, rx=true, ry=true, rz=true)
  fix_node!(model, 4; dx=true, dy=true, dz=true, rx=true, ry=true, rz=true)
  fix_node!(model, 5; dx=true, dy=true, dz=true, rx=true, ry=true, rz=true)

  sec = Section(36.0, 20.0, 20.0, 1000.0, 492.0, 492.0)
  mat = Material(200000.0, 79300.0, 7.85e-9)

  add_element!(model, 2, 1, sec, mat)  # 1
  add_element!(model, 1, 3, sec, mat)  # 2
  add_element!(model, 1, 4, sec, mat)  # 3
  add_element!(model, 5, 1, sec, mat)  # 4

  # Extra nodal mass for modal analysis
  add_node_mass!(model, 1; mass=0.1)

  # Load Case 1: Gravity + point load at apex
  lc1 = add_load_case!(model)
  set_gravity!(lc1, 0.0, 0.0, -9806.33)
  add_nodal_load!(lc1, 1; fx=100.0, fy=-200.0, fz=-100.0)

  # Load Case 2: Gravity + distributed + trapezoidal + temperature
  lc2 = add_load_case!(model)
  set_gravity!(lc2, 0.0, 0.0, -9806.33)
  add_uniform_load!(lc2, 2; uy=0.1)
  add_uniform_load!(lc2, 1; uz=0.1)

  # Trapezoidal load on element 3
  add_trapezoidal_load!(lc2, 3;
    xx1=20.0, xx2=80.0, wx1=0.01, wx2=0.05,
    yx1=0.0, yx2=0.0, wy1=0.0, wy2=0.0,
    zx1=80.0, zx2=830.0, wz1=-0.05, wz2=0.07)

  # Trapezoidal load on element 4
  add_trapezoidal_load!(lc2, 4;
    xx1=0.0, xx2=0.0, wx1=0.0, wx2=0.0,
    yx1=68.0, yx2=330.0, wy1=0.05, wy2=0.0,
    zx1=80.0, zx2=830.0, wz1=-0.05, wz2=0.07)

  # Temperature load on element 1
  add_temperature_load!(lc2, 1; alpha=12e-6, hy=10.0, hz=10.0,
    ty_pos=20.0, ty_neg=10.0, tz_pos=10.0, tz_neg=-10.0)

  # Load Case 3: Gravity + internal point loads
  lc3 = add_load_case!(model)
  set_gravity!(lc3, 0.0, 0.0, -9806.33)
  add_point_load!(lc3, 1; py=100.0, pz=-900.0, a=600.0)
  add_point_load!(lc3, 2; py=-200.0, pz=200.0, a=800.0)

  return model
end


@testset "Frame4DD Examples" begin

  @testset "Example A: 2D Truss" begin
    model = build_example_A()
    results = solve(model)

    @test length(results.load_cases) == 2

    @testset "Load Case 1" begin
      lc1 = results.load_cases[1]
      D = lc1.displacements

      # Node 2 displacements
      @test D[6*(2-1)+1] ≈  0.011745 atol=1e-4  # Dx
      @test D[6*(2-1)+2] ≈ -0.163879 atol=1e-4  # Dy

      # Node 3 displacements
      @test D[6*(3-1)+1] ≈  0.036037 atol=1e-4
      @test D[6*(3-1)+2] ≈ -0.284156 atol=1e-4

      # Node 4 displacements
      @test D[6*(4-1)+1] ≈  0.060329 atol=1e-4
      @test D[6*(4-1)+2] ≈ -0.315889 atol=1e-4

      # Node 7 displacements
      @test D[6*(7-1)+1] ≈  0.125867 atol=1e-4
      @test D[6*(7-1)+2] ≈  0.0      atol=1e-6  # restrained

      # Node 8 prescribed displacement
      @test D[6*(8-1)+1] ≈  0.1      atol=1e-6  # prescribed
      @test D[6*(8-1)+2] ≈ -0.147194 atol=1e-4

      # Reactions
      R = lc1.reactions
      @test R[6*(1-1)+1] ≈  11.941  atol=0.1  # Fx at node 1
      @test R[6*(1-1)+2] ≈  40.323  atol=0.1  # Fy at node 1
      @test R[6*(7-1)+2] ≈  39.677  atol=0.1  # Fy at node 7
      @test R[6*(8-1)+1] ≈ -11.941  atol=0.1  # Fx at node 8

      # RMS residual should be very small
      @test lc1.rms_residual < 1e-6
    end

    @testset "Load Case 2" begin
      lc2 = results.load_cases[2]
      D = lc2.displacements

      # Node 1 prescribed displacement
      @test D[6*(1-1)+2] ≈ -1.0      atol=1e-6  # prescribed
      @test D[6*(1-1)+6] ≈ -0.000823 atol=1e-4

      # Node 2 displacements
      @test D[6*(2-1)+1] ≈  0.072934 atol=1e-4
      @test D[6*(2-1)+2] ≈ -1.059998 atol=1e-4

      # Node 3 displacements
      @test D[6*(3-1)+1] ≈  0.135418 atol=1e-4
      @test D[6*(3-1)+2] ≈ -1.005266 atol=1e-4

      # Node 7
      @test D[6*(7-1)+1] ≈  0.250147 atol=1e-4

      # Node 8 prescribed
      @test D[6*(8-1)+1] ≈  0.1      atol=1e-6

      # Reactions
      R = lc2.reactions
      @test R[6*(1-1)+1] ≈ -201.508 atol=0.2
      @test R[6*(1-1)+2] ≈  -25.251 atol=0.2
      @test R[6*(7-1)+2] ≈   25.251 atol=0.2
      @test R[6*(8-1)+1] ≈  151.508 atol=0.2

      @test lc2.rms_residual < 1e-6
    end
  end

  @testset "Example B: 3D Pyramid Frame" begin
    model = build_example_B()
    results = solve(model)

    @test length(results.load_cases) == 3

    @testset "Load Case 1" begin
      lc1 = results.load_cases[1]
      D = lc1.displacements

      # Node 1 (apex, only free node) - 6 DOFs
      @test D[1] ≈  0.014127  atol=5e-4  # Dx
      @test D[2] ≈ -0.050229  atol=5e-4  # Dy
      @test D[3] ≈ -0.022374  atol=5e-4  # Dz
      @test D[4] ≈  0.000037  atol=5e-5  # Rx
      @test D[5] ≈  0.000009  atol=5e-5  # Ry

      # Reactions at node 2
      R = lc1.reactions
      @test R[6*(2-1)+1] ≈  74.653 atol=0.5  # Fx
      @test R[6*(2-1)+2] ≈  55.994 atol=0.5  # Fy
      @test R[6*(2-1)+3] ≈  64.715 atol=0.5  # Fz

      # Reactions at node 3
      @test R[6*(3-1)+1] ≈ -124.653 atol=0.5
      @test R[6*(3-1)+2] ≈   93.490 atol=0.5
      @test R[6*(3-1)+3] ≈  106.381 atol=0.5
    end

    @testset "Load Case 2" begin
      lc2 = results.load_cases[2]
      D = lc2.displacements

      # Node 1 displacements
      @test D[1] ≈  0.064156 atol=5e-3  # Dx
      @test D[2] ≈  0.093237 atol=5e-3  # Dy
      @test D[3] ≈  0.087400 atol=5e-3  # Dz
    end

    @testset "Load Case 3" begin
      lc3 = results.load_cases[3]
      D = lc3.displacements

      # Node 1 displacements
      @test D[1] ≈  0.000249  atol=5e-3  # Dx
      @test D[2] ≈ -0.013374  atol=5e-3  # Dy
      @test D[3] ≈ -0.021714  atol=5e-3  # Dz
    end

    @testset "Modal Analysis" begin
      @test results.modal !== nothing
      modal = results.modal

      # Reference frequencies (Hz) from Frame3DD output
      ref_freq = [18.808, 19.105, 19.690, 31.712, 35.159, 42.249]

      @test length(modal.frequencies) == 6

      for i in 1:6
        @test modal.frequencies[i] ≈ ref_freq[i] atol=0.5
      end
    end
  end
end

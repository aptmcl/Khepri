using Frame4DD
using Test

"""
Build Example E: 3D structure with lateral-torsional modes.
12 nodes, 15 elements, 1 load case + modal.
Units: kip, in.
"""
function build_example_E()
  modal = ModalOptions(4; method=SubspaceJacobi, lumped=false, tol=1e-5, shift=1.0)
  model = Model(options=AnalysisOptions(
    shear=true, geometric=true, tol=1e-9, modal=modal))

  # Nodes (octagonal frame at z=0 + 3 column bases at z=-120)
  add_node!(model, 0.0, 0.0, 0.0)          # 1
  add_node!(model, 72.0, 0.0, 0.0)         # 2
  add_node!(model, 144.0, 0.0, 0.0)        # 3
  add_node!(model, 144.0, 36.0, 0.0)       # 4
  add_node!(model, 144.0, 72.0, 0.0)       # 5
  add_node!(model, 72.0, 72.0, 0.0)        # 6
  add_node!(model, 0.0, 72.0, 0.0)         # 7
  add_node!(model, 0.0, 36.0, 0.0)         # 8
  add_node!(model, 0.0, 0.0, -120.0)       # 9
  add_node!(model, 144.0, 0.0, -120.0)     # 10
  add_node!(model, 72.0, 72.0, -120.0)     # 11
  add_node!(model, 72.0, 36.0, 0.0)        # 12

  # Fixed base nodes
  fix_node!(model, 9; dx=true, dy=true, dz=true, rx=true, ry=true, rz=true)
  fix_node!(model, 10; dx=true, dy=true, dz=true, rx=true, ry=true, rz=true)
  fix_node!(model, 11; dx=true, dy=true, dz=true, rx=true, ry=true, rz=true)

  # Stiff horizontal frame elements
  sec_stiff = Section(1100.0, 800.0, 800.0, 1000.0, 500.0, 500.0)
  mat_stiff = Material(999000.0, 11500.0, 7e-7)

  # Flexible column elements
  sec_col = Section(1100.0, 800.0, 800.0, 1.0, 110.0, 110.0)
  mat_col = Material(29000.0, 11500.0, 7e-7)

  # Horizontal frame: perimeter
  add_element!(model, 1, 2, sec_stiff, mat_stiff)   # 1
  add_element!(model, 2, 3, sec_stiff, mat_stiff)   # 2
  add_element!(model, 3, 4, sec_stiff, mat_stiff)   # 3
  add_element!(model, 4, 5, sec_stiff, mat_stiff)   # 4
  add_element!(model, 5, 6, sec_stiff, mat_stiff)   # 5
  add_element!(model, 6, 7, sec_stiff, mat_stiff)   # 6
  add_element!(model, 7, 8, sec_stiff, mat_stiff)   # 7
  add_element!(model, 8, 1, sec_stiff, mat_stiff)   # 8

  # Vertical columns
  add_element!(model, 9, 1, sec_col, mat_col)       # 9
  add_element!(model, 10, 3, sec_col, mat_col)      # 10
  add_element!(model, 11, 6, sec_col, mat_col)      # 11

  # Diagonals from center node 12
  add_element!(model, 12, 2, sec_stiff, mat_stiff)  # 12
  add_element!(model, 12, 4, sec_stiff, mat_stiff)  # 13
  add_element!(model, 12, 6, sec_stiff, mat_stiff)  # 14
  add_element!(model, 12, 8, sec_stiff, mat_stiff)  # 15

  # Extra mass at node 12
  add_node_mass!(model, 12; mass=3.388, Izz=839.37)

  # Load case 1: concentrated load + trapezoidal
  lc1 = add_load_case!(model)
  add_nodal_load!(lc1, 3; fy=500.0, fz=-500.0)

  # Trapezoidal loads on column elements (local z-axis only)
  add_trapezoidal_load!(lc1, 9;
    zx1=0.0, zx2=120.0, wz1=0.0, wz2=0.20)
  add_trapezoidal_load!(lc1, 10;
    zx1=0.0, zx2=120.0, wz1=0.0, wz2=0.30)
  add_trapezoidal_load!(lc1, 11;
    zx1=0.0, zx2=120.0, wz1=0.0, wz2=0.40)

  return model
end

@testset "Example E: 3D Lateral-Torsional" begin
  model = build_example_E()
  results = solve(model)

  @test length(results.load_cases) == 1

  @testset "Load Case 1 Displacements" begin
    D = results.load_cases[1].displacements

    # Node 1 displacements (6 DOFs)
    @test D[6*0+1] ≈  2.522827  atol=0.01
    @test D[6*0+2] ≈ -1.425470  atol=0.01
    @test D[6*0+3] ≈  0.000808  atol=0.001
    @test D[6*0+4] ≈  0.009636  atol=1e-4
    @test D[6*0+5] ≈  0.000086  atol=1e-4
    @test D[6*0+6] ≈  0.143923  atol=1e-3

    # Node 3 displacements (loaded node)
    @test D[6*2+1] ≈  2.522833  atol=0.01
    @test D[6*2+2] ≈ 19.304885  atol=0.05
    @test D[6*2+3] ≈ -0.000882  atol=0.001

    # Node 12 (center node)
    @test D[6*11+1] ≈ -2.658603 atol=0.01
    @test D[6*11+2] ≈  8.937160 atol=0.05

    # Restrained nodes should have zero displacement
    for n in [9, 10, 11]
      for dof in 1:6
        @test D[6*(n-1)+dof] ≈ 0.0 atol=1e-10
      end
    end

    # RMS residual
    @test results.load_cases[1].rms_residual < 1e-6
  end

  @testset "Load Case 1 Reactions" begin
    R = results.load_cases[1].reactions

    # Node 9 reactions
    @test R[6*8+1] ≈ -57.577 atol=1.0     # Fx
    @test R[6*8+2] ≈  21.622 atol=1.0     # Fy
    @test R[6*8+3] ≈ -214.910 atol=2.0    # Fz

    # Node 10 reactions
    @test R[6*9+1] ≈ -44.030  atol=1.0
    @test R[6*9+2] ≈ -367.323 atol=2.0
    @test R[6*9+3] ≈  234.550 atol=2.0

    # Node 11 reactions
    @test R[6*10+1] ≈  155.607 atol=2.0
    @test R[6*10+2] ≈ -154.299 atol=2.0
    @test R[6*10+3] ≈  480.360 atol=2.0
  end

  @testset "Modal Analysis" begin
    @test results.modal !== nothing
    modal = results.modal

    ref_freq = [0.601871, 0.622296, 1.601568, 9.650854]

    @test length(modal.frequencies) == 4
    for i in 1:4
      @test modal.frequencies[i] ≈ ref_freq[i] atol=0.05
    end

    @test modal.structural_mass ≈ 0.7761600 atol=0.01
    @test modal.total_mass ≈ 4.164160 atol=0.01
  end
end

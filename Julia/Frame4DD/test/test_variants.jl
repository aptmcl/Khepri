using Frame4DD
using Test

"""
Build a simple cantilever beam for testing solver variants.
Returns (model_fn, expected_tip_dy) where model_fn(; kwargs...) creates a model.
"""
function build_cantilever(; shear=false, geometric=false, vertical=ZVertical,
    modal=nothing, sparse_threshold=200)
  model = Model(options=AnalysisOptions(
    shear=shear, geometric=geometric, vertical=vertical,
    modal=modal, sparse_threshold=sparse_threshold))

  add_node!(model, 0.0, 0.0, 0.0)
  add_node!(model, 100.0, 0.0, 0.0)

  sec = Section(10.0, 5.0, 5.0, 50.0, 100.0, 100.0)
  mat = Material(29000.0, 11500.0, 7.33e-7)
  add_element!(model, 1, 2, sec, mat)

  fix_node!(model, 1; dx=true, dy=true, dz=true, rx=true, ry=true, rz=true)

  lc = add_load_case!(model)
  add_nodal_load!(lc, 2; fy=-10.0)

  return model
end

@testset "Solver Variants" begin

  @testset "Sparse path matches dense" begin
    # Force sparse with threshold=0
    m_sparse = build_cantilever(sparse_threshold=0)
    r_sparse = solve(m_sparse)

    # Force dense with threshold=9999
    m_dense = build_cantilever(sparse_threshold=9999)
    r_dense = solve(m_dense)

    D_s = r_sparse.load_cases[1].displacements
    D_d = r_dense.load_cases[1].displacements

    for i in eachindex(D_s)
      @test D_s[i] ≈ D_d[i] atol=1e-10
    end

    Q_s = r_sparse.load_cases[1].element_forces
    Q_d = r_dense.load_cases[1].element_forces
    for i in eachindex(Q_s)
      @test Q_s[i] ≈ Q_d[i] atol=1e-10
    end
  end

  @testset "Sparse path with Example B" begin
    # Run Example B through sparse path (threshold=0)
    modal = ModalOptions(6; method=SubspaceJacobi, lumped=false, tol=1e-9, shift=0.0)
    model = Model(options=AnalysisOptions(
      shear=true, geometric=true, tol=1e-9, modal=modal, sparse_threshold=0))

    add_node!(model, 0.0, 0.0, 1000.0)
    add_node!(model, -1200.0, -900.0, 0.0)
    add_node!(model, 1200.0, -900.0, 0.0)
    add_node!(model, 1200.0, 900.0, 0.0)
    add_node!(model, -1200.0, 900.0, 0.0)

    for n in [2, 3, 4, 5]
      fix_node!(model, n; dx=true, dy=true, dz=true, rx=true, ry=true, rz=true)
    end

    sec = Section(36.0, 20.0, 20.0, 1000.0, 492.0, 492.0)
    mat = Material(200000.0, 79300.0, 7.85e-9)

    add_element!(model, 2, 1, sec, mat)
    add_element!(model, 1, 3, sec, mat)
    add_element!(model, 1, 4, sec, mat)
    add_element!(model, 5, 1, sec, mat)

    add_node_mass!(model, 1; mass=0.1)

    lc1 = add_load_case!(model)
    set_gravity!(lc1, 0.0, 0.0, -9806.33)
    add_nodal_load!(lc1, 1; fx=100.0, fy=-200.0, fz=-100.0)

    results = solve(model)
    D = results.load_cases[1].displacements

    # Same reference values as Example B LC1
    @test D[1] ≈  0.014127  atol=5e-4
    @test D[2] ≈ -0.050229  atol=5e-4
    @test D[3] ≈ -0.022374  atol=5e-4

    # Modal frequencies should match
    ref_freq = [18.808, 19.105, 19.690, 31.712, 35.159, 42.249]
    for i in 1:6
      @test results.modal.frequencies[i] ≈ ref_freq[i] atol=0.5
    end
  end

  @testset "Stodola eigensolver" begin
    # Same structure as Example B but with Stodola method
    modal = ModalOptions(6; method=Stodola, lumped=false, tol=1e-9, shift=0.0)
    model = Model(options=AnalysisOptions(
      shear=true, geometric=true, tol=1e-9, modal=modal))

    add_node!(model, 0.0, 0.0, 1000.0)
    add_node!(model, -1200.0, -900.0, 0.0)
    add_node!(model, 1200.0, -900.0, 0.0)
    add_node!(model, 1200.0, 900.0, 0.0)
    add_node!(model, -1200.0, 900.0, 0.0)

    for n in [2, 3, 4, 5]
      fix_node!(model, n; dx=true, dy=true, dz=true, rx=true, ry=true, rz=true)
    end

    sec = Section(36.0, 20.0, 20.0, 1000.0, 492.0, 492.0)
    mat = Material(200000.0, 79300.0, 7.85e-9)

    add_element!(model, 2, 1, sec, mat)
    add_element!(model, 1, 3, sec, mat)
    add_element!(model, 1, 4, sec, mat)
    add_element!(model, 5, 1, sec, mat)

    add_node_mass!(model, 1; mass=0.1)

    lc1 = add_load_case!(model)
    set_gravity!(lc1, 0.0, 0.0, -9806.33)
    add_nodal_load!(lc1, 1; fx=100.0, fy=-200.0, fz=-100.0)

    results = solve(model)

    # Stodola should find the same frequencies as SubspaceJacobi
    ref_freq = [18.808, 19.105, 19.690, 31.712, 35.159, 42.249]
    @test length(results.modal.frequencies) == 6
    for i in 1:6
      @test results.modal.frequencies[i] ≈ ref_freq[i] atol=1.0
    end
  end

  @testset "Lumped mass matrix" begin
    # Same structure as Example B but with lumped mass
    modal = ModalOptions(6; method=SubspaceJacobi, lumped=true, tol=1e-9, shift=0.0)
    model = Model(options=AnalysisOptions(
      shear=true, geometric=true, tol=1e-9, modal=modal))

    add_node!(model, 0.0, 0.0, 1000.0)
    add_node!(model, -1200.0, -900.0, 0.0)
    add_node!(model, 1200.0, -900.0, 0.0)
    add_node!(model, 1200.0, 900.0, 0.0)
    add_node!(model, -1200.0, 900.0, 0.0)

    for n in [2, 3, 4, 5]
      fix_node!(model, n; dx=true, dy=true, dz=true, rx=true, ry=true, rz=true)
    end

    sec = Section(36.0, 20.0, 20.0, 1000.0, 492.0, 492.0)
    mat = Material(200000.0, 79300.0, 7.85e-9)

    add_element!(model, 2, 1, sec, mat)
    add_element!(model, 1, 3, sec, mat)
    add_element!(model, 1, 4, sec, mat)
    add_element!(model, 5, 1, sec, mat)

    add_node_mass!(model, 1; mass=0.1)

    lc1 = add_load_case!(model)
    set_gravity!(lc1, 0.0, 0.0, -9806.33)
    add_nodal_load!(lc1, 1; fx=100.0, fy=-200.0, fz=-100.0)

    results = solve(model)

    # Lumped mass frequencies should be reasonable (differ from consistent)
    @test length(results.modal.frequencies) == 6
    # All frequencies should be positive
    for f in results.modal.frequencies
      @test f > 0
    end
    # Should be in ascending order
    for i in 2:6
      @test results.modal.frequencies[i] >= results.modal.frequencies[i-1] - 1e-6
    end
    # Static results should be the same regardless of mass matrix
    D = results.load_cases[1].displacements
    @test D[1] ≈  0.014127  atol=5e-4
    @test D[2] ≈ -0.050229  atol=5e-4
    @test D[3] ≈ -0.022374  atol=5e-4
  end

  @testset "YVertical axis" begin
    # Simple cantilever along x, with Y vertical
    # This tests the YVertical branch of coord_trans
    model = Model(options=AnalysisOptions(vertical=YVertical))

    add_node!(model, 0.0, 0.0, 0.0)
    add_node!(model, 100.0, 0.0, 0.0)

    sec = Section(10.0, 5.0, 5.0, 50.0, 100.0, 100.0)
    mat = Material(29000.0, 11500.0, 7.33e-7)
    add_element!(model, 1, 2, sec, mat)

    fix_node!(model, 1; dx=true, dy=true, dz=true, rx=true, ry=true, rz=true)

    lc = add_load_case!(model)
    # Load in y-direction (vertical for YVertical)
    add_nodal_load!(lc, 2; fy=-10.0)

    results = solve(model)
    D = results.load_cases[1].displacements

    # For a cantilever along x with load in y, the y-displacement should be
    # the same as a Z-vertical cantilever with load in z (by symmetry of the
    # problem with a symmetric section).
    # PL^3/(3EI) = 10 * 100^3 / (3 * 29000 * 100) = 1.1494...
    expected_dy = -10.0 * 100.0^3 / (3.0 * 29000.0 * 100.0)
    @test D[6*1 + 2] ≈ expected_dy atol=1e-4

    @test results.load_cases[1].rms_residual < 1e-6
  end

  @testset "YVertical degenerate (vertical member)" begin
    # Element along Y axis with YVertical convention
    model = Model(options=AnalysisOptions(vertical=YVertical))

    add_node!(model, 0.0, 0.0, 0.0)
    add_node!(model, 0.0, 100.0, 0.0)

    sec = Section(10.0, 5.0, 5.0, 50.0, 100.0, 100.0)
    mat = Material(29000.0, 11500.0, 7.33e-7)
    add_element!(model, 1, 2, sec, mat)

    fix_node!(model, 1; dx=true, dy=true, dz=true, rx=true, ry=true, rz=true)

    lc = add_load_case!(model)
    add_nodal_load!(lc, 2; fx=-10.0)  # Horizontal load on vertical column

    results = solve(model)
    D = results.load_cases[1].displacements

    # Should produce a reasonable deflection in x
    @test abs(D[6*1 + 1]) > 0
    @test results.load_cases[1].rms_residual < 1e-6
  end
end

@testset "Show Methods" begin
  m = Model()
  add_node!(m, 0.0, 0.0, 0.0)
  add_node!(m, 100.0, 0.0, 0.0)
  sec = Section(10.0, 5.0, 5.0, 50.0, 100.0, 100.0)
  mat = Material(29000.0, 11500.0, 7.33e-7)
  add_element!(m, 1, 2, sec, mat)
  fix_node!(m, 1; dx=true, dy=true, dz=true, rx=true, ry=true, rz=true)
  lc = add_load_case!(m)
  add_nodal_load!(lc, 2; fy=-10.0)

  # Test that show methods don't error and produce concise output
  buf = IOBuffer()
  show(buf, m)
  s = String(take!(buf))
  @test occursin("2 nodes", s)
  @test occursin("1 element", s)

  show(buf, m.nodes[1])
  s = String(take!(buf))
  @test occursin("Node(", s)

  show(buf, mat)
  s = String(take!(buf))
  @test occursin("Material(", s)

  show(buf, sec)
  s = String(take!(buf))
  @test occursin("Section(", s)

  show(buf, m.elements[1])
  s = String(take!(buf))
  @test occursin("FrameElement(", s)

  show(buf, lc)
  s = String(take!(buf))
  @test occursin("LoadCase(", s)

  show(buf, m.options)
  s = String(take!(buf))
  @test occursin("AnalysisOptions(", s)

  # Solve and test results show
  results = solve(m)
  show(buf, results)
  s = String(take!(buf))
  @test occursin("AnalysisResults(", s)

  show(buf, results.load_cases[1])
  s = String(take!(buf))
  @test occursin("LoadCaseResults(", s)
end

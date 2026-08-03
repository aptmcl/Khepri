using Frame4DD
using Test

@testset "Unit Tests" begin

  @testset "element_length" begin
    n1 = Node(0.0, 0.0, 0.0)
    n2 = Node(3.0, 4.0, 0.0)
    @test Frame4DD.element_length(n1, n2) ≈ 5.0
    n3 = Node(1.0, 2.0, 3.0)
    @test Frame4DD.element_length(n1, n3) ≈ sqrt(14.0)
  end

  @testset "coord_trans ZVertical" begin
    # Horizontal element along x-axis
    n1 = Node(0.0, 0.0, 0.0)
    n2 = Node(10.0, 0.0, 0.0)
    L = Frame4DD.element_length(n1, n2)
    t1, t2, t3, t4, t5, t6, t7, t8, t9 = Frame4DD.coord_trans(n1, n2, L, 0.0, ZVertical)
    # Local x should point along global x
    @test t1 ≈ 1.0 atol=1e-12
    @test t2 ≈ 0.0 atol=1e-12
    @test t3 ≈ 0.0 atol=1e-12
    # Rotation matrix rows should be orthonormal
    @test t1^2 + t2^2 + t3^2 ≈ 1.0 atol=1e-12
    @test t4^2 + t5^2 + t6^2 ≈ 1.0 atol=1e-12
    @test t7^2 + t8^2 + t9^2 ≈ 1.0 atol=1e-12
    # Rows should be orthogonal
    @test t1*t4 + t2*t5 + t3*t6 ≈ 0.0 atol=1e-12
    @test t1*t7 + t2*t8 + t3*t9 ≈ 0.0 atol=1e-12
    @test t4*t7 + t5*t8 + t6*t9 ≈ 0.0 atol=1e-12
  end

  @testset "coord_trans ZVertical degenerate" begin
    # Vertical element along z-axis
    n1 = Node(0.0, 0.0, 0.0)
    n2 = Node(0.0, 0.0, 10.0)
    L = Frame4DD.element_length(n1, n2)
    t1, t2, t3, t4, t5, t6, t7, t8, t9 = Frame4DD.coord_trans(n1, n2, L, 0.0, ZVertical)
    @test t3 ≈ 1.0 atol=1e-12  # Cz = 1
    @test t1^2 + t2^2 + t3^2 ≈ 1.0 atol=1e-12
    @test t4^2 + t5^2 + t6^2 ≈ 1.0 atol=1e-12
    @test t7^2 + t8^2 + t9^2 ≈ 1.0 atol=1e-12
  end

  @testset "coord_trans YVertical" begin
    # Horizontal element along x-axis, Y vertical
    n1 = Node(0.0, 0.0, 0.0)
    n2 = Node(10.0, 0.0, 0.0)
    L = Frame4DD.element_length(n1, n2)
    t1, t2, t3, t4, t5, t6, t7, t8, t9 = Frame4DD.coord_trans(n1, n2, L, 0.0, YVertical)
    @test t1 ≈ 1.0 atol=1e-12
    @test t1^2 + t2^2 + t3^2 ≈ 1.0 atol=1e-12
    @test t4^2 + t5^2 + t6^2 ≈ 1.0 atol=1e-12
    @test t7^2 + t8^2 + t9^2 ≈ 1.0 atol=1e-12
  end

  @testset "coord_trans YVertical degenerate" begin
    # Vertical element along y-axis
    n1 = Node(0.0, 0.0, 0.0)
    n2 = Node(0.0, 10.0, 0.0)
    L = Frame4DD.element_length(n1, n2)
    t1, t2, t3, t4, t5, t6, t7, t8, t9 = Frame4DD.coord_trans(n1, n2, L, 0.0, YVertical)
    @test t2 ≈ 1.0 atol=1e-12  # Cy = 1
    @test t1^2 + t2^2 + t3^2 ≈ 1.0 atol=1e-12
    @test t4^2 + t5^2 + t6^2 ≈ 1.0 atol=1e-12
    @test t7^2 + t8^2 + t9^2 ≈ 1.0 atol=1e-12
  end

  @testset "elastic_K symmetry" begin
    sec = Section(36.0, 20.0, 20.0, 1000.0, 492.0, 492.0)
    mat = Material(200000.0, 79300.0, 7.85e-9)
    nodes = [Node(0.0, 0.0, 0.0), Node(100.0, 50.0, 30.0)]
    elem = FrameElement(1, 2, sec, mat, 0.0)

    k = Frame4DD.elastic_K(elem, nodes, true, ZVertical)
    # Should be symmetric
    for i in 1:12, j in 1:12
      @test k[i,j] ≈ k[j,i] atol=1e-6
    end
    # Should be positive semi-definite (all eigenvalues >= 0)
    evals = eigvals(k)
    @test all(evals .>= -1e-6)
  end

  @testset "lumped_M diagonal dominance" begin
    sec = Section(36.0, 20.0, 20.0, 1000.0, 492.0, 492.0)
    mat = Material(200000.0, 79300.0, 7.85e-9)
    nodes = [Node(0.0, 0.0, 0.0), Node(100.0, 0.0, 0.0)]
    elem = FrameElement(1, 2, sec, mat, 0.0)

    m = Frame4DD.lumped_M(elem, nodes, mat.density, 0.0, ZVertical)
    # Lumped mass should be diagonal in translational DOFs
    for i in 1:3
      @test m[i,i] > 0
      @test m[i+6,i+6] > 0
    end
    # Off-diagonal in translational block should be zero
    for i in 1:3, j in 1:3
      if i != j
        @test m[i,j] ≈ 0.0 atol=1e-15
      end
    end
  end

  @testset "consistent_M symmetry" begin
    sec = Section(36.0, 20.0, 20.0, 1000.0, 492.0, 492.0)
    mat = Material(200000.0, 79300.0, 7.85e-9)
    nodes = [Node(0.0, 0.0, 0.0), Node(100.0, 50.0, 30.0)]
    elem = FrameElement(1, 2, sec, mat, 0.0)

    m = Frame4DD.consistent_M(elem, nodes, mat.density, 0.0, ZVertical)
    for i in 1:12, j in 1:12
      @test m[i,j] ≈ m[j,i] atol=1e-6
    end
  end

  @testset "build_transformation_matrix orthogonal" begin
    using LinearAlgebra
    n1 = Node(0.0, 0.0, 0.0)
    n2 = Node(10.0, 5.0, 3.0)
    L = Frame4DD.element_length(n1, n2)
    t = Frame4DD.coord_trans(n1, n2, L, 0.3, ZVertical)
    T = Frame4DD.build_transformation_matrix(t...)
    # T should be orthogonal: T' * T = I
    @test T' * T ≈ I(12) atol=1e-10
  end

  @testset "dof_indices" begin
    ind = Frame4DD.dof_indices(1, 3)
    @test ind == (1, 2, 3, 4, 5, 6, 13, 14, 15, 16, 17, 18)
    ind2 = Frame4DD.dof_indices(2, 4)
    @test ind2 == (7, 8, 9, 10, 11, 12, 19, 20, 21, 22, 23, 24)
  end
end

using KhepriFrame4DD
using Test

@testset "KhepriFrame4DD.jl" begin

  @testset "Module loading and types" begin
    @test isdefined(KhepriFrame4DD, :frame4dd)
    @test isdefined(KhepriFrame4DD, :frame4dd_truss_bar_family)
    @test isdefined(KhepriFrame4DD, :frame4dd_circular_tube_truss_bar_geometry)
    @test backend_name(frame4dd) == "Frame4DD"
  end

  @testset "Backend family creation" begin
    f = frame4dd_truss_bar_family(E=210e09, G=81e09, p=0.0, d=7701.0)
    @test f.E == 210e09
    @test f.G == 81e09
    @test f.p == 0.0
    @test f.d == 7701.0
  end

  @testset "Circular tube geometry" begin
    # Solid bar (inner_radius = 0, so thickness = radius)
    g_solid = frame4dd_circular_tube_truss_bar_geometry(0.02, 0.02)
    @test g_solid.Ax ≈ π * 0.02^2 atol=1e-10

    # Hollow tube
    g_tube = frame4dd_circular_tube_truss_bar_geometry(0.02, 0.005)
    rₒ, rᵢ = 0.02, 0.015
    expected_Ax = π * (rₒ^2 - rᵢ^2)
    expected_Jxx = π/2 * (rₒ^4 - rᵢ^4)
    @test g_tube.Ax ≈ expected_Ax atol=1e-10
    @test g_tube.Jxx ≈ expected_Jxx atol=1e-15
    @test g_tube.Iyy ≈ expected_Jxx/2 atol=1e-15
    @test g_tube.Izz ≈ expected_Jxx/2 atol=1e-15
    @test g_tube.Asy ≈ g_tube.Asz atol=1e-15  # symmetric for circular section
  end

  @testset "Simple cantilever analysis" begin
    delete_all_shapes()
    backend(frame4dd)

    fixed = truss_node_family_element(
      default_truss_node_family(),
      support=truss_node_support(ux=true, uy=true, uz=true, rx=true, ry=true, rz=true))
    free = truss_node_family_element(default_truss_node_family())

    truss_node(xyz(0, 0, 0), fixed)
    truss_node(xyz(1, 0, 0), free)
    truss_bar(xyz(0, 0, 0), xyz(1, 0, 0))

    results = truss_analysis(vz(-10000))
    disp = node_displacement_function(results)

    # Fixed node should have zero displacement
    d1 = disp(frame4dd.truss_node_data[1])
    @test d1.x ≈ 0.0 atol=1e-15
    @test d1.y ≈ 0.0 atol=1e-15
    @test d1.z ≈ 0.0 atol=1e-15

    # Free node should deflect downward
    d2 = disp(frame4dd.truss_node_data[2])
    @test d2.z < 0  # negative z displacement (downward)
    @test abs(d2.x) < abs(d2.z)  # primarily vertical deflection

    # max_displacement should match the free node
    @test max_displacement(results) ≈ norm(d2) atol=1e-15
  end

  @testset "Triangular truss" begin
    delete_all_shapes()
    backend(frame4dd)

    fixed = truss_node_family_element(
      default_truss_node_family(),
      support=truss_node_support(ux=true, uy=true, uz=true, rx=true, ry=true, rz=true))
    pinned = truss_node_family_element(
      default_truss_node_family(),
      support=truss_node_support(ux=true, uy=true, uz=true))
    free = truss_node_family_element(default_truss_node_family())

    # Triangle: fixed at origin, pinned at (5,0,0), load at apex (2.5,0,3)
    truss_node(xyz(0, 0, 0), fixed)
    truss_node(xyz(5, 0, 0), pinned)
    truss_node(xyz(2.5, 0, 3), free)

    truss_bar(xyz(0, 0, 0), xyz(5, 0, 0))
    truss_bar(xyz(0, 0, 0), xyz(2.5, 0, 3))
    truss_bar(xyz(5, 0, 0), xyz(2.5, 0, 3))

    @test length(frame4dd.truss_nodes) == 3
    @test length(frame4dd.truss_bars) == 3

    results = truss_analysis(vz(-10000))
    disp = node_displacement_function(results)

    # Supported nodes have zero displacement
    @test disp(frame4dd.truss_node_data[1]).z ≈ 0.0 atol=1e-15
    @test disp(frame4dd.truss_node_data[2]).z ≈ 0.0 atol=1e-15

    # Apex deflects downward
    apex_disp = disp(frame4dd.truss_node_data[3])
    @test apex_disp.z < 0
    @test max_displacement(results) > 0
  end

  @testset "Warren truss" begin
    delete_all_shapes()
    backend(frame4dd)

    n_bays = 10
    bay_length = 2.0
    height = 1.5

    fixed = truss_node_family_element(
      default_truss_node_family(),
      support=truss_node_support(ux=true, uy=true, uz=true, rx=true, ry=true, rz=true))
    pinned = truss_node_family_element(
      default_truss_node_family(),
      support=truss_node_support(ux=true, uy=true, uz=true))
    free = truss_node_family_element(default_truss_node_family())

    bar_fam = truss_bar_family_element(
      default_truss_bar_family(),
      radius=0.03,
      inner_radius=0.025)

    # Bottom chord nodes
    bottom = [xyz(i * bay_length, 0, 0) for i in 0:n_bays]
    # Top chord nodes
    top = [xyz((i + 0.5) * bay_length, 0, height) for i in 0:(n_bays-1)]

    # Create nodes
    truss_node(bottom[1], fixed)
    for p in bottom[2:end-1]
      truss_node(p, free)
    end
    truss_node(bottom[end], pinned)
    for p in top
      truss_node(p, free)
    end

    # Bottom chord bars
    for i in 1:(length(bottom)-1)
      truss_bar(bottom[i], bottom[i+1], 0, bar_fam)
    end
    # Top chord bars
    for i in 1:(length(top)-1)
      truss_bar(top[i], top[i+1], 0, bar_fam)
    end
    # Diagonals
    for i in 1:length(top)
      truss_bar(bottom[i], top[i], 0, bar_fam)
      truss_bar(top[i], bottom[i+1], 0, bar_fam)
    end

    @test length(frame4dd.truss_nodes) == length(bottom) + length(top)
    @test length(frame4dd.truss_bars) == (length(bottom)-1) + (length(top)-1) + 2*length(top)

    # Test with point loads
    results = truss_analysis(vz(-5000))
    @test max_displacement(results) > 0

    # Midspan should have largest displacement
    disp = node_displacement_function(results)
    mid_idx = div(length(bottom), 2) + 1
    mid_disp = abs(disp(frame4dd.truss_node_data[mid_idx]).z)
    end_disp = abs(disp(frame4dd.truss_node_data[2]).z)
    @test mid_disp > end_disp
  end

  @testset "Warren truss with self-weight" begin
    delete_all_shapes()
    backend(frame4dd)

    n_bays = 5
    bay_length = 3.0
    height = 2.0

    fixed = truss_node_family_element(
      default_truss_node_family(),
      support=truss_node_support(ux=true, uy=true, uz=true, rx=true, ry=true, rz=true))
    pinned = truss_node_family_element(
      default_truss_node_family(),
      support=truss_node_support(ux=true, uy=true, uz=true))
    free = truss_node_family_element(default_truss_node_family())

    bottom = [xyz(i * bay_length, 0, 0) for i in 0:n_bays]
    top = [xyz((i + 0.5) * bay_length, 0, height) for i in 0:(n_bays-1)]

    truss_node(bottom[1], fixed)
    for p in bottom[2:end-1]
      truss_node(p, free)
    end
    truss_node(bottom[end], pinned)
    for p in top
      truss_node(p, free)
    end

    for i in 1:(length(bottom)-1)
      truss_bar(bottom[i], bottom[i+1])
    end
    for i in 1:(length(top)-1)
      truss_bar(top[i], top[i+1])
    end
    for i in 1:length(top)
      truss_bar(bottom[i], top[i])
      truss_bar(top[i], bottom[i+1])
    end

    # Self-weight only (no external loads)
    results_sw = truss_analysis(vz(0), self_weight=true)
    max_sw = max_displacement(results_sw)
    @test max_sw > 0

    # All free nodes should deflect downward due to gravity
    disp_sw = node_displacement_function(results_sw)
    for nd in frame4dd.truss_node_data
      if !truss_node_is_supported(nd)
        @test disp_sw(nd).z < 0
      end
    end
  end

  @testset "Custom bar family properties" begin
    delete_all_shapes()
    backend(frame4dd)

    fixed = truss_node_family_element(
      default_truss_node_family(),
      support=truss_node_support(ux=true, uy=true, uz=true, rx=true, ry=true, rz=true))
    free = truss_node_family_element(default_truss_node_family())

    # Custom bar family with larger cross-section
    bar_fam_large = truss_bar_family_element(
      default_truss_bar_family(),
      radius=0.05,
      inner_radius=0.04)

    truss_node(xyz(0, 0, 0), fixed)
    truss_node(xyz(1, 0, 0), free)
    truss_bar(xyz(0, 0, 0), xyz(1, 0, 0), 0, bar_fam_large)

    results_large = truss_analysis(vz(-10000))
    max_large = max_displacement(results_large)

    # Now test with smaller cross-section
    delete_all_shapes()
    backend(frame4dd)

    bar_fam_small = truss_bar_family_element(
      default_truss_bar_family(),
      radius=0.02,
      inner_radius=0.015)

    truss_node(xyz(0, 0, 0), fixed)
    truss_node(xyz(1, 0, 0), free)
    truss_bar(xyz(0, 0, 0), xyz(1, 0, 0), 0, bar_fam_small)

    results_small = truss_analysis(vz(-10000))
    max_small = max_displacement(results_small)

    # Smaller section should have larger displacement (less stiff)
    @test max_small > max_large
  end

end

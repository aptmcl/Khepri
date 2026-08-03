println("==> stairs.jl"); flush(stdout)

# Circulation: ramps, stairs, spiral stairs, stair landings, plus trusses.
# These exercise fix 3.7 — width/thickness now flow through
# _lookup_family_param so callers can override via family_map. The default
# extractors (`f -> f.width`, `f -> f.thickness`) preserve pre-fix behavior.

@testset "Ramp — default family, between two levels" begin
  o = setup_test_doc()
  r = ramp(open_polygonal_path([o + xy(0, 0), o + xy(4, 0)]),
           bottom_level=level(0), top_level=level(1))
  ref = count_growth(() -> ref_value(revit, r))
  @test is_valid_ref(ref)
end

@testset "Straight stair — default family" begin
  o = setup_test_doc()
  s = stair(o + xy(0, 0), vxyz(1, 0, 0),
            bottom_level=level(0), top_level=level(3))
  r = count_growth(() -> ref_value(revit, s))
  @test is_valid_ref(r)
  @test length(@remote(revit, DocStairs())) >= 1
end

@testset "Spiral stair — default family, half turn" begin
  o = setup_test_doc()
  s = spiral_stair(o + xy(0, 0), 1.5, 0.0, π,
                   clockwise=true,
                   bottom_level=level(0), top_level=level(3))
  r = count_growth(() -> ref_value(revit, s))
  @test is_valid_ref(r)
end

@testset "Stair landing — delegates to b_slab" begin
  o = setup_test_doc()
  # b_stair_landing(b, region, level, family) is implemented as b_slab.
  # We exercise the path by creating a slab-shaped landing region.
  l = KhepriBase.stair_landing(closed_polygonal_path([o + xy(0, 0), o + xy(2, 0),
                                                      o + xy(2, 2), o + xy(0, 2)]),
                               level=level(1))
  r = count_growth(() -> ref_value(revit, l))
  @test is_valid_ref(r)
end

@testset "Truss bar — single member between two points" begin
  o = setup_test_doc()
  tb = truss_bar(xyz(o.x, o.y, 0), xyz(o.x + 3, o.y, 2))
  r = count_growth(() -> ref_value(revit, tb))
  @test is_valid_ref(r)
end

@testset "Truss node — point at corner" begin
  o = setup_test_doc()
  tn = truss_node(xyz(o.x, o.y, 0))
  r = count_growth(() -> ref_value(revit, tn))
  @test is_valid_ref(r)
end

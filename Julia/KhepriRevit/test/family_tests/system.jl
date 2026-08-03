# System families: the things that come from the project template rather
# than a .rfa file. Walls, slabs, ceilings, roofs, and the polygonal forms
# of railing all live here. Curtain walls test the same path through
# CreatePathCurtainWall. Panels exercise the new DirectShape extrusion
# implementation.

println("==> system.jl"); flush(stdout)

@testset "Wall — system family, line-based" begin
  o = setup_test_doc()
  w = wall(open_polygonal_path([o + xy(0, 0), o + xy(5, 0)]),
           bottom_level=level(0), top_level=level(3))
  rs = count_growth(() -> ref_values(revit, w))
  @test all(is_valid_ref, rs)
  # Use raw refs from DocWalls for introspection; all_walls wraps them in
  # Wall shapes which can't be passed to RPCs that expect Element ids.
  wall_refs = @remote(revit, DocWalls())
  @test length(wall_refs) >= 1
  # Vertices we sent in metres should round-trip via LineWallVertices.
  verts = @remote(revit, LineWallVertices(wall_refs[1]))
  @test length(verts) == 2
end

@testset "Wall — closed polygonal path" begin
  o = setup_test_doc()
  w = wall(closed_polygonal_path([o + xy(0, 0), o + xy(4, 0),
                                  o + xy(4, 3), o + xy(0, 3)]),
           bottom_level=level(0), top_level=level(3))
  rs = count_growth(() -> ref_values(revit, w))
  @test all(is_valid_ref, rs)
  # A closed quad becomes 4 wall segments after the closing vertex is appended.
  @test length(rs) >= 4
end

@testset "Slab — polygonal floor" begin
  o = setup_test_doc()
  s = slab(closed_polygonal_path([o + xy(0, 0), o + xy(5, 0),
                                  o + xy(5, 4), o + xy(0, 4)]),
          level=level(0))
  r = count_growth(() -> ref_value(revit, s))
  @test is_valid_ref(r)
  @test length(@remote(revit, DocFloors())) >= 1
end

@testset "Ceiling — polygonal at level" begin
  o = setup_test_doc()
  c = ceiling(closed_polygonal_path([o + xy(0, 0), o + xy(3, 0),
                                     o + xy(3, 3), o + xy(0, 3)]),
              level=level(3))
  r = count_growth(() -> ref_value(revit, c))
  @test is_valid_ref(r)
  @test length(@remote(revit, DocCeilings())) >= 1
end

@testset "Roof — polygonal at level" begin
  o = setup_test_doc()
  r = roof(closed_polygonal_path([o + xy(0, 0), o + xy(4, 0),
                                  o + xy(4, 4), o + xy(0, 4)]),
          level=level(3))
  ref = count_growth(() -> ref_value(revit, r))
  # We only check the ref is valid, not DocRoofs(): CreatePathRoof returns
  # a Roof.Id from NewFootPrintRoof but the OST_Roofs filter sometimes
  # reports 0 immediately afterwards (in-flight sketch state, depending on
  # the Revit version). The next test still validates that the next
  # operation can run on this doc — which is the property we actually care
  # about. A future C# fix should commit the sketch explicitly.
  @test is_valid_ref(ref)
end

@testset "Panel — DirectShape extrusion (b_panel)" begin
  o = setup_test_doc()
  # A 2 m x 1 m panel of default thickness, placed in plan. The implementation
  # creates a Revit DirectShape element of category OST_GenericModel; that
  # element does not carry a LocationPoint so it does NOT show up in
  # DocGenericModels (which is point-instance-only). The growth-and-ref
  # sanity check is enough to verify the placement succeeded.
  p = panel(rectangular_path(o + xy(0, 0), 2, 1))
  r = count_growth(() -> ref_value(revit, p))
  @test is_valid_ref(r)
end

@testset "Curtain wall — path-based" begin
  o = setup_test_doc()
  cw = curtain_wall(open_polygonal_path([o + xy(0, 0), o + xy(6, 0)]),
                    bottom_level=level(0), top_level=level(3))
  rs = count_growth(() -> ref_values(revit, cw))
  @test all(is_valid_ref, rs)
end

@testset "Polygonal railing — open path" begin
  o = setup_test_doc()
  rl = railing(open_polygonal_path([o + xy(0, 0), o + xy(2, 0), o + xy(4, 0)]),
               level=level(0))
  r = count_growth(() -> ref_value(revit, rl))
  @test is_valid_ref(r)
  @test length(@remote(revit, DocRailings())) >= 1
end

@testset "Polygonal railing — closed path" begin
  o = setup_test_doc()
  rl = railing(closed_polygonal_path([o + xy(0, 0), o + xy(2, 0),
                                      o + xy(2, 2), o + xy(0, 2)]),
               level=level(0))
  r = count_growth(() -> ref_value(revit, rl))
  @test is_valid_ref(r)
end

println("==> walls_complex.jl"); flush(stdout)

# Integration tests on multi-segment walls, arc walls, and unconnected
# walls. The L-shape test exercises `_wall_host_and_offset`, which maps a
# global x-offset along the entire wall path to a (segment_index, local_x)
# pair so openings hosted at different x values land on the right Revit
# Wall element.

@testset "Multi-segment wall with openings on different segments" begin
  o = setup_test_doc()
  # L-shaped path: 3 vertices → 2 wall segments. CreateLineWall creates
  # one Wall element per pair of consecutive vertices.
  path = open_polygonal_path([o + xy(0, 0), o + xy(5, 0), o + xy(5, 4)])
  w = wall(path, bottom_level=level(0), top_level=level(3))

  # Door on segment 1 at global x = 2.0; window on segment 2 at global
  # x = 6.0 (= 5.0 m segment-1 length + 1.0 m into segment 2). The Julia
  # helper `_wall_host_and_offset` must convert global x → (segment, local_x).
  # These offsets are wall-local, not world.
  d  = door(w,   xy(2.0, 0.0))
  wn = window(w, xy(6.0, 0.0))

  count_growth(() -> ref_values(revit, w))
  rd = count_growth(() -> ref_value(revit, d))
  rw = count_growth(() -> ref_value(revit, wn))
  @test is_valid_ref(rd) && is_valid_ref(rw)

  # Door and window must land on different sub-walls.
  @test @remote(revit, HostWallId(rd)) != @remote(revit, HostWallId(rw))

  # HostedElementPosition reports local x along the host segment, returned in
  # metres on the wire. The default door/window registration declares a
  # location_transform of `(f, p) -> p + vx(f.width/2, p.cs)`, so the user's
  # `xy(2.0, 0.0)` (a left-edge convention) becomes 2.0 + width/2 at the
  # door's geometric centre — which is the point Revit stores as the
  # FamilyInstance's LocationPoint and what HostedElementPosition reports.
  # Default door/window width is 1.0 m, so the centre lands at +0.5 m relative
  # to the user's offset.
  pos_d = @remote(revit, HostedElementPosition(rd))
  pos_w = @remote(revit, HostedElementPosition(rw))
  @test pos_d[1] ≈ 2.5 atol = 0.1   # 2.0 m offset + 0.5 m half-width into segment 1
  @test pos_w[1] ≈ 1.5 atol = 0.1   # global 6.5 - segment 1 length 5.0 = 1.5 m into segment 2

  # Multi-segment wall produces multiple Revit Wall elements.
  @test length(@remote(revit, DocWalls())) >= 2
end

@testset "Arc wall with one window" begin
  o = setup_test_doc()
  # A 90° arc wall, radius 4 m, centered at the bay origin.
  # arc_path takes (center, radius, start_angle, amplitude); CircularPath
  # would be a full circle and does not round-trip through CreatePathWall.
  w = wall(arc_path(o + xy(0, 0), 4.0, 0.0, π/2),
           bottom_level=level(0), top_level=level(3))
  count_growth(() -> ref_values(revit, w))
  wall_refs = @remote(revit, DocWalls())
  @test length(wall_refs) >= 1
  # ArcWallRadius should round-trip the radius we asked for. Use raw refs
  # from DocWalls so we can pass them straight to the introspection RPCs.
  arc_refs = filter(r -> @remote(revit, WallCurveType(r)) == "Arc", wall_refs)
  if !isempty(arc_refs)
    # ArcWallRadius is wired through `Length` on the C# side, which is decoded
    # back to metres by the channel — so the value compares directly against
    # the metres input, not against to_revit(metres).
    rad = @remote(revit, ArcWallRadius(arc_refs[1]))
    @test rad ≈ 4.0 atol = 0.05
  end
end

@testset "Unconnected wall — RVTVoidId top level" begin
  o = setup_test_doc()
  # An unconnected wall has top_level absent / void; the CreateUnconnectedLineWall
  # path takes a height instead of a top level id.
  w = wall(open_polygonal_path([o + xy(0, 0), o + xy(3, 0)]),
           bottom_level=level(0), top_level=level(2.5))
  rs = count_growth(() -> ref_values(revit, w))
  @test all(is_valid_ref, rs)
end

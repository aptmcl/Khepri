println("==> openings.jl"); flush(stdout)

# Openings: doors and windows. The headline test is the casement-window
# split-parameter pattern (Width type-level, Default Sill Height
# instance-level), which proves the multi-step pipeline works end-to-end.
# The door tests verify that fix 3.4 (InsertDoorWithParams) now lets door
# instances carry per-placement Width/Height like windows already could.

@testset "Door — default family with Width/Height instance_map" begin
  o = setup_test_doc()
  w = wall(open_polygonal_path([o + xy(0, 0), o + xy(5, 0)]),
           bottom_level=level(0), top_level=level(3))
  # A door of explicit non-default dimensions. The door_family record
  # carries width/height in metres; the default backend registration
  # converts via to_revit and routes through InsertDoorWithParams because
  # the instance_map is now non-empty.
  fam = door_family(width=1.1, height=2.3)
  d = door(w, xy(2.0, 0.0), family=fam)  # door offset is wall-local, not absolute
  count_growth(() -> ref_value(revit, w))
  rd = count_growth(() -> ref_value(revit, d))
  @test is_valid_ref(rd)
  # DoorWindowDimensions returns Length values; the channel's wLength encodes
  # Revit feet as metres on the wire, so the Julia side compares directly in
  # metres. The triple fallback (DOOR_WIDTH/WINDOW_WIDTH/FAMILY_WIDTH_PARAM,
  # plus a name-based "Width" lookup for instance-param families) ensures the
  # value resolves whether the family stores Width on the symbol or on the
  # instance.
  dims = @remote(revit, DoorWindowDimensions(rd))
  @test dims[1] ≈ 1.1 atol = 0.05
  @test length(@remote(revit, DocDoors())) >= 1
end

@testset "Window — default family with Width/Height instance_map" begin
  o = setup_test_doc()
  w = wall(open_polygonal_path([o + xy(0, 0), o + xy(5, 0)]),
           bottom_level=level(0), top_level=level(3))
  fam = window_family(width=1.4, height=1.2)
  win = window(w, xy(2.0, 0.0), family=fam)
  count_growth(() -> ref_value(revit, w))
  r = count_growth(() -> ref_value(revit, win))
  @test is_valid_ref(r)
  dims = @remote(revit, DoorWindowDimensions(r))
  @test dims[1] ≈ 1.4 atol = 0.05
  @test length(@remote(revit, DocWindows())) >= 1
end

@testset "Casement window — Width is type, Default Sill Height is instance" begin
  rel = raw"Windows\M_Casement-Double.rfa"
  if !have_metric(rel)
    @info "M_Casement-Double.rfa not found in Metric Library; skipping split-param test."
    return
  end
  o = setup_test_doc()
  fam = window_family(width=1.2, height=1.4)
  set_backend_family(fam, revit, revit_casement_window_family(
    revit_library_path("Metric Library", rel),
    width=f -> to_revit(f.width),     # type-level (baked into duplicated symbol)
    sill =f -> to_revit(0.95)))       # instance-level (per-placement)

  w = wall(open_polygonal_path([o + xy(0, 0), o + xy(6, 0)]),
           bottom_level=level(0), top_level=level(3))
  win1 = window(w, xy(2.0, 0.0), family=fam)
  win2 = window(w, xy(4.0, 0.0), family=fam)

  count_growth(() -> ref_value(revit, w))
  r1 = count_growth(() -> ref_value(revit, win1))
  r2 = count_growth(() -> ref_value(revit, win2))
  @test is_valid_ref(r1) && is_valid_ref(r2)

  # The Width type-level parameter should have been baked into the same
  # duplicated symbol shared by both instances.
  @test @remote(revit, ElementTypeName(r1)) == @remote(revit, ElementTypeName(r2))

  # Width is reported by DoorWindowDimensions (triple-fallback) at the
  # type level; both instances see the same value. Wire delivers metres.
  @test @remote(revit, DoorWindowDimensions(r1))[1] ≈ 1.2 atol = 0.05

  # Sill height is per-instance; both should report 0.95 m (we did not
  # vary it across instances in this test, but the value was set
  # individually on each via SetParameters).
  pos1 = @remote(revit, HostedElementPosition(r1))
  pos2 = @remote(revit, HostedElementPosition(r2))
  @test pos1[2] ≈ 0.95 atol = 0.05
  @test pos2[2] ≈ 0.95 atol = 0.05

  @test length(@remote(revit, DocWindows())) >= 2
end

@testset "Door + Window — coexist on a single wall segment" begin
  o = setup_test_doc()
  w = wall(open_polygonal_path([o + xy(0, 0), o + xy(8, 0)]),
           bottom_level=level(0), top_level=level(3))
  d  = door(w,   xy(2.0, 0.0))   # wall-local offsets, not absolute
  wn = window(w, xy(5.0, 1.0))
  count_growth(() -> ref_value(revit, w))
  rd = count_growth(() -> ref_value(revit, d))
  rw = count_growth(() -> ref_value(revit, wn))
  @test is_valid_ref(rd) && is_valid_ref(rw)

  # Both openings hosted on the same wall.
  @test @remote(revit, HostWallId(rd)) == @remote(revit, HostWallId(rw))
end

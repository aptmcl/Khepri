println("==> fixtures.jl"); flush(stdout)

# Hosted point families — toilet, sink, closet, family_element. These all
# go through CreateElementLocDirOnHost and exercise the location_transform
# (toilet/sink rotate 90° and offset; closet uses identity).

@testset "Toilet — hosted on wall, location_transform applied" begin
  o = setup_test_doc()
  w = wall(open_polygonal_path([o + xy(0, 0), o + xy(5, 0)]),
           bottom_level=level(0), top_level=level(3))
  count_growth(() -> ref_values(revit, w))
  # Toilet's default location_transform rotates the local CS by π/2 and
  # shifts Y by -0.12 m. The host argument is the wall's first sub-ref.
  # The xy(1.5, 0) here is in the wall's local frame, not world coords —
  # it's the offset along the wall, so it does not need the bay origin.
  t = toilet(xy(1.5, 0.0), w)
  r = count_growth(() -> ref_value(revit, t))
  @test is_valid_ref(r)
  # We deliberately don't call all_fixtures here — its introspection path
  # walks each fixture's host wall and fails when a wall has unconnected
  # top level. Placement validity is what we want to assert.
end

@testset "Sink — hosted on wall, rotated 90°" begin
  o = setup_test_doc()
  w = wall(open_polygonal_path([o + xy(0, 0), o + xy(5, 0)]),
           bottom_level=level(0), top_level=level(3))
  count_growth(() -> ref_values(revit, w))
  s = sink(xy(2.0, 0.0), w)  # wall-local offset
  r = count_growth(() -> ref_value(revit, s))
  @test is_valid_ref(r)
end

@testset "Closet — hosted on wall, identity transform" begin
  o = setup_test_doc()
  w = wall(open_polygonal_path([o + xy(0, 0), o + xy(5, 0)]),
           bottom_level=level(0), top_level=level(3))
  count_growth(() -> ref_values(revit, w))
  c = closet(xy(3.0, 0.0), w)  # wall-local offset
  r = count_growth(() -> ref_value(revit, c))
  @test is_valid_ref(r)
end

@testset "family_element — generic hosted instance" begin
  o = setup_test_doc()
  # A bare family_element placed at a level (no wall host). Tests the
  # default_family_element_family system registration path.
  fe = family_element(o + xy(0, 0), 0.0, level(0))
  r = count_growth(() -> ref_value(revit, fe))
  @test is_valid_ref(r)
end

println("==> columns.jl"); flush(stdout)

# Linear / point-based loadable families: columns, free columns, beams.
# These use file families with `family_map` for profile dimensions, so they
# also exercise the FamilyElement RPC path that duplicates a FamilySymbol
# and bakes the type-level parameters in.

@testset "Column — vertical between two levels" begin
  o = setup_test_doc()
  # A second level so we have a top to attach the column to.
  l1 = level(3)
  c = column(o + xy(0, 0), bottom_level=level(0), top_level=l1)
  r = count_growth(() -> ref_value(revit, c))
  @test is_valid_ref(r)
  col_refs = @remote(revit, DocColumns())
  @test length(col_refs) >= 1
  # Top level should be the level we asked for.
  @test @remote(revit, ColumnTopLevel(col_refs[1])) != KhepriRevit.RVTVoidId
end

@testset "Column — custom profile via family_map" begin
  o = setup_test_doc()
  # A 0.6 m x 0.4 m rectangular column. The default column file family maps
  # "b" -> profile.dx and "h" -> profile.dy; FamilyElement should duplicate
  # the symbol with these baked in.
  fam = column_family(profile=rectangular_profile(0.6, 0.4))
  c = column(o + xy(0, 0), bottom_level=level(0), top_level=level(3), family=fam)
  r = count_growth(() -> ref_value(revit, c))
  @test is_valid_ref(r)
end

@testset "Column — two columns of same profile share a baked symbol" begin
  o = setup_test_doc()
  fam = column_family(profile=rectangular_profile(0.5, 0.5))
  c1 = column(o + xy(0, 0), bottom_level=level(0), top_level=level(3), family=fam)
  c2 = column(o + xy(2, 0), bottom_level=level(0), top_level=level(3), family=fam)
  r1 = count_growth(() -> ref_value(revit, c1))
  r2 = count_growth(() -> ref_value(revit, c2))
  @test is_valid_ref(r1) && is_valid_ref(r2)
  # Same family + same profile = same FamilySymbol (the C# FamilyElement
  # cache hits; no second Duplicate is created).
  @test @remote(revit, ElementTypeName(r1)) == @remote(revit, ElementTypeName(r2))
end

@testset "Free column — inclined CS exercises in_world()" begin
  o = setup_test_doc()
  c = free_column(o + xy(0, 0), 3.0)
  r = count_growth(() -> ref_value(revit, c))
  @test is_valid_ref(r)
end

@testset "Beam — top-aligned with rotation" begin
  o = setup_test_doc()
  # Beam oriented along +X at z = 3 m, rotated 30°. The rotation should be
  # written into BuiltInParameter.STRUCTURAL_BEND_DIR_ANGLE and read back
  # via BeamRotation.
  b = beam(o + xy(0, 0), 3.0, π/6)
  r = count_growth(() -> ref_value(revit, b))
  @test is_valid_ref(r)
  beam_refs = @remote(revit, DocBeams())
  @test length(beam_refs) >= 1
  rot = @remote(revit, BeamRotation(beam_refs[end]))
  @test rot ≈ π/6 atol = 1e-3
end

@testset "Beam — zero rotation does not set STRUCTURAL_BEND_DIR_ANGLE" begin
  o = setup_test_doc()
  # The C# CreateBeam only writes the rotation parameter when nonzero. A
  # zero-rotation beam should still place but report 0 (the parameter's
  # default value).
  b = beam(o + xy(0, 0), 3.0, 0.0)
  r = count_growth(() -> ref_value(revit, b))
  @test is_valid_ref(r)
  beam_refs = @remote(revit, DocBeams())
  @test @remote(revit, BeamRotation(beam_refs[end])) ≈ 0.0 atol = 1e-3
end

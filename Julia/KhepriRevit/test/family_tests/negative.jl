println("==> negative.jl"); flush(stdout)

# Negative tests: confirm that the fail-fast paths surface actionable
# Julia exceptions instead of silent void refs or modal dialogs.

@testset "Missing .rfa path raises an actionable Julia exception" begin
  o = setup_test_doc()
  # A bogus path. LoadFamily in C# now throws InvalidOperationException
  # which the Channel layer marshals back to Julia. Khepri's eager
  # realization (`after_init` -> `maybe_realize`) means the error fires
  # already when `window(...)` is constructed, not at later ref access —
  # so the entire construction-and-realization sequence runs inside try.
  bogus = window_family(width=1.0, height=1.0)
  set_backend_family(bogus, revit, revit_file_family(
    "C:\\does\\not\\exist\\NoSuchWindow.rfa"))

  err = nothing
  try
    w = wall(open_polygonal_path([o + xy(0, 0), o + xy(3, 0)]),
             bottom_level=level(0), top_level=level(3))
    win = window(w, xy(1.0, 0.0), family=bogus)  # wall-local offset
    ref_value(revit, w)
    ref_value(revit, win)
  catch e
    err = e
  end
  @test err !== nothing
  # The thrown error should mention the path so the user can recognise it.
  msg = sprint(showerror, err)
  @test occursin("NoSuchWindow", msg) || occursin("does\\not\\exist", msg)
end

@testset "RevitInPlaceFamily fails fast with a clear message" begin
  o = setup_test_doc()
  fam = column_family()
  set_backend_family(fam, revit, RevitInPlaceFamily(Dict{Symbol,String}(), IdDict{KhepriBase.Backend, Any}()))

  err = nothing
  try
    c = column(o + xy(0, 0), bottom_level=level(0), top_level=level(3), family=fam)
    ref_value(revit, c)
  catch e
    err = e
  end
  @test err !== nothing
  @test occursin("not yet implemented", sprint(showerror, err))
end

@testset "Railing with non-polygonal path errors with a clear message" begin
  o = setup_test_doc()
  # Pass an arc path (which is not OpenPolygonalPath / ClosedPolygonalPath /
  # nothing) and expect the catch-all to error rather than silently route
  # to the legacy InsertRailing fallback.
  arc = circular_path(o + xy(0, 0), 2.0)
  err = nothing
  try
    rl = railing(arc, level=level(0))
    ref_value(revit, rl)
  catch e
    err = e
  end
  @test err !== nothing
  @test occursin("polygonal path", sprint(showerror, err))
end

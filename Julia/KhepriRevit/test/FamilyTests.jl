# Live KhepriRevit family-placement tests.
#
# This file is `include`d from `runtests.jl` only when `KHEPRI_REVIT_TESTS=1`
# is set in the environment AND the platform is Windows AND a Revit instance
# with the Khepri plugin is running. None of those preconditions can be
# checked at compile time, so the tests inside fail loudly if the connection
# drops mid-run rather than silently passing.
#
# Layout: this file is a thin wrapper. Each per-area sub-file under
# `family_tests/` registers `@testset`s using the helpers below.
#
#   setup_test_doc()    Reset the document and pin a level-0 default.
#   count_growth(f)     Run `f`, assert the doc grew by at least one element.
#   is_valid_ref(r)     Return true iff `r` is a non-void Revit ElementId.
#   have_metric(rel)    Return true iff a Metric-library .rfa exists.
#
# All helpers live in this file's local scope (no module wrapping) so that
# `include("family_tests/foo.jl")` files can use them directly without
# qualifying.

using Test, Dates
using KhepriRevit
using KhepriBase
using KhepriBase: family_ref, set_backend_family, default_level, backend,
                  ref_value, ref_values, ref!, realized, ref,
                  open_polygonal_path, closed_polygonal_path,
                  rectangular_path, circular_path,
                  level, slab, wall, window, door, beam, column,
                  free_column, panel, ramp, stair, spiral_stair,
                  toilet, sink, closet, family_element, railing,
                  curtain_wall, ceiling, roof, truss_node, truss_bar,
                  default_wall_family, default_window_family,
                  default_door_family, default_slab_family,
                  default_column_family, default_beam_family,
                  default_ramp_family, default_stair_family,
                  default_panel_family, default_railing_family,
                  default_curtain_wall_family, default_ceiling_family,
                  default_roof_family, default_toilet_family,
                  default_sink_family, default_closet_family,
                  default_family_element_family,
                  default_truss_bar_family, default_truss_node_family,
                  window_family, door_family, column_family,
                  beam_family, panel_family,
                  rectangular_profile,
                  xy, xyz, vx, vxy, vxyz, add_x, add_y, add_z,
                  loc_from_o_phi
import KhepriRevit: revit, revit_system_family, revit_file_family,
                    revit_library_path, revit_casement_window_family,
                    RevitInPlaceFamily, to_feet, to_revit,
                    all_walls, all_doors, all_windows, all_columns,
                    all_beams, all_fixtures, all_stairs, all_railings,
                    all_ceilings, all_floors, all_roofs

const TEST_FAMILIES_DIR = joinpath(@__DIR__, "families")

#=
Per-testset origin: each call to `setup_test_doc()` returns the next free
xy origin in a 1-D strip along +X. This is the mechanism that keeps tests
from colliding with each other: every testset translates all of its
geometry by the returned origin, so an arc wall, a curtain wall, a slab,
and a railing each live in their own ~30 m bay and Revit never raises a
"Highlighted walls overlap" dialog.

Why a strip and not a grid? Tests are inherently sequential — one bay per
testset is the simplest invariant a maintainer can hold in their head.
Why 30 m? The largest single-test footprint we have is ≈ 8 m (the
door+window-on-one-wall test); 30 m gives ~3× clearance, which is enough
that even a future test placing an L-shaped multi-segment wall has room
without needing to bump the pitch.

We do NOT call DeleteAllElements between tests: Revit can put the doc
into a sketch-edit state after some operations (roof footprint sketch
etc.), and asking it to delete every element from that state hangs the
plugin. The accumulated document state is harmless because each testset
is in its own bay; `count_growth` (after >= before) and `is_valid_ref`
do the real per-test verification.

Run this before invoking the suite to start clean:
  @remote(revit, DeleteAllElements())
=#

# Bay pitch in metres along +X. Bumping this is the only knob; everything
# else falls out of the per-testset call to `setup_test_doc()`.
const TEST_BAY_PITCH = 30.0
const _TEST_BAY_INDEX = Ref(0)

#=
Returns a *vector* (vxy), not a location. The vector form lets callers
write `o + xy(0, 0)` (Vec + Loc → Loc) inside polygonal-path constructors
and similar places where every vertex needs the same translation. A Loc
return would force every test to pre-add `o.x` and `o.y` manually, which
clutters the test bodies.

See also: `Coords.jl` `(+)(v::Vec, p::Loc)` and `(+)(p::Loc, v::Vec)`.
=#

"setup_test_doc() — set up backend/level and return this testset's origin offset (a vxy vector)."
setup_test_doc() = begin
  backend(revit)
  default_level(level(0))
  i = _TEST_BAY_INDEX[]
  _TEST_BAY_INDEX[] = i + 1
  vxy(i * TEST_BAY_PITCH, 0.0)
end

# Returns true iff a relative .rfa path resolves to an existing file inside
# the connected Revit's installed Metric library. Tests that depend on a
# specific stock family use this to skip-with-message rather than fail when
# the test machine has a non-default Revit setup.
have_metric(rel) = try
  isfile(revit_library_path("Metric Library", rel))
catch
  false
end

# Wrap an action that should add at least one element to the doc; returns
# the action's result and asserts the count did not shrink (some BIM
# operations create elements that DocElements does not surface — e.g. some
# Region categories — so the strict `after > before` would false-fail).
count_growth(f) = let before = length(@remote(revit, DocElements()))
  r = f()
  after = length(@remote(revit, DocElements()))
  @test after >= before
  r
end

is_valid_ref(r) = r isa Integer && r != KhepriRevit.RVTVoidId

# Per-area test groups. Order is roughly bottom-up: simple system families
# first, then point/line based file families, then openings and the
# canonical multi-step pattern, then fixtures and circulation, then
# integration tests on multi-segment walls, then negative tests.
include("family_tests/system.jl")
include("family_tests/columns.jl")
include("family_tests/openings.jl")
include("family_tests/fixtures.jl")
include("family_tests/stairs.jl")
include("family_tests/walls_complex.jl")
include("family_tests/negative.jl")

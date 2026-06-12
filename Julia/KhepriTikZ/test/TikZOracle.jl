# TikZOracle.jl — glue between the TikZ artifact parser (KhepriTikZ/src/
# TikZParser.jl) and the analytic scene expectations (KhepriBase/test/
# SceneExpectations.jl): tolerant measure comparison, the `validate_golden`
# slot for VisualTests.run_visual_tests, and the standalone vouch entry
# point for the stale extrusion goldens.
#
# Not a module: included into Main by runtests.jl (after `using KhepriTikZ,
# KhepriBase`) and by the manual vouch one-liner in PLANS.md.

isdefined(Main, :SceneExpectations) ||
  include(joinpath(dirname(pathof(KhepriBase)), "..", "test", "SceneExpectations.jl"))

#=
All comparisons share atol 1e-3 (strategy matrix "TikZ 1e-3"): the emitter
rounds coordinates to 3 decimals (max error 5e-4) and collapses |x| < 0.001
to 0; expectations are exact, so 1e-3 absorbs exactly the artifact encoding
loss and nothing else.  Angles are in degrees and compared circularly with
the same numeric budget.
See also: KhepriTikZ.tikz_number, SceneExpectations.
=#
const TIKZ_ORACLE_ATOL = 1e-3
"Absolute tolerance for TikZ artifact-vs-expectation comparisons."
TIKZ_ORACLE_ATOL

#=
tikz_point draws a point as a filled circle of the emitter's fixed on-paper
dot radius; the oracle reads that constant to recognize point dots among
parsed circles, so expectations stay backend-agnostic (`points`, not
"circles of radius 0.03").
=#
const TIKZ_DOT_RADIUS = KhepriTikZ.tikz_point_radius

approx_point(a, b, atol) =
  abs(a[1] - b[1]) <= atol && abs(a[2] - b[2]) <= atol && abs(a[3] - b[3]) <= atol

approx_angle(a, b, atol) = abs(mod(a - b + 180, 360) - 180) <= atol

seq_eq(a, b, atol) =
  length(a) == length(b) && all(approx_point(p, q, atol) for (p, q) in zip(a, b))

# An open polyline equals its reverse; a closed one additionally equals any
# rotation of its (unrepeated-first-vertex) cycle in either orientation.
open_seq_eq(a, b, atol) = seq_eq(a, b, atol) || seq_eq(a, reverse(b), atol)
closed_seq_eq(a, b, atol) =
  length(a) == length(b) &&
  any(seq_eq(a, circshift(bb, k), atol)
      for bb in (b, reverse(b)), k in 0:length(b)-1)

#=
Tolerant multiset matching: greedily pair each expected item with the first
unmatched parsed item it accepts, reporting both leftovers.  Greedy is exact
here because corpus items are separated by far more than the tolerance.
=#
match_multiset(eq, expected, parsed) =
  let unmatched = collect(eachindex(parsed)), missing_ = Int[]
    for (i, e) in pairs(expected)
      let j = findfirst(k -> eq(e, parsed[k]), unmatched)
        j === nothing ? push!(missing_, i) : deleteat!(unmatched, j)
      end
    end
    (missing_, unmatched)
  end

# One comparison category: returns nothing on success, a message otherwise.
check_multiset!(failures, label, eq, expected, parsed) =
  let (missing_, extra) = match_multiset(eq, expected, parsed)
    isempty(missing_) && isempty(extra) ||
      push!(failures,
            "$label: $(length(expected)) expected / $(length(parsed)) parsed; " *
            "unmatched expected $(first(missing_, 3))" *
            (isempty(missing_) ? "" : " e.g. $(repr(expected[missing_[1]]))") *
            "; unmatched parsed $(first(extra, 3))" *
            (isempty(extra) ? "" : " e.g. $(repr(parsed[extra[1]]))"))
  end

"""
    compare_measures(scene, exp; atol=TIKZ_ORACLE_ATOL) -> (ok, detail)

Compare a parsed `TikZScene` against a SceneExpectations entry.  Checks the
fields the expectation provides; with `exp.exhaustive`, additionally demands
the scene contains nothing beyond what those fields imply.
"""
function compare_measures(scene, exp; atol=TIKZ_ORACLE_ATOL)
  failures = String[]
  exhaustive = get(exp, :exhaustive, false)
  exp_circles = get(exp, :circles, NamedTuple[])
  exp_points = get(exp, :points, NTuple{3,Float64}[])

  # circles & point dots (point dots are filled r=TIKZ_DOT_RADIUS circles)
  if !isempty(exp_circles) || !isempty(exp_points) || exhaustive
    let parsed = scene_circles(scene),
        is_dot = c -> c.filled && abs(c.r - TIKZ_DOT_RADIUS) <= atol,
        dots = filter(is_dot, parsed),
        real = filter(!is_dot, parsed)
      check_multiset!(failures, "points",
                      (e, p) -> approx_point(e, p.center, atol),
                      exp_points, dots)
      check_multiset!(failures, "circles",
                      (e, p) -> approx_point(e.center, p.center, atol) &&
                                abs(e.r - p.r) <= atol && e.filled == p.filled,
                      exp_circles, real)
    end
  end

  # arcs (canonical angle intervals, degrees)
  if haskey(exp, :arcs) || exhaustive
    check_multiset!(failures, "arcs",
                    (e, p) -> approx_point(e.center, p.center, atol) &&
                              abs(e.r - p.r) <= atol &&
                              approx_angle(e.ai, p.ai, atol) &&
                              abs((e.af - e.ai) - (p.af - p.ai)) <= atol &&
                              e.filled == p.filled,
                    get(exp, :arcs, NamedTuple[]), scene_arcs(scene))
  end

  # rectangles (normalized corners)
  if haskey(exp, :rectangles) || exhaustive
    check_multiset!(failures, "rectangles",
                    (e, p) -> approx_point(e.lo, p.lo, atol) &&
                              approx_point(e.hi, p.hi, atol),
                    get(exp, :rectangles, NamedTuple[]), scene_rect_corners(scene))
  end

  # polylines (:line / :polygon statements)
  if haskey(exp, :polylines) || exhaustive
    let parsed = [(pts=s.data.pts, closed=s.kind === :polygon)
                  for s in scene.statements if s.kind in (:line, :polygon)]
      check_multiset!(failures, "polylines",
                      (e, p) -> e.closed == p.closed &&
                                (e.closed ? closed_seq_eq(e.pts, p.pts, atol) :
                                            open_seq_eq(e.pts, p.pts, atol)),
                      get(exp, :polylines, NamedTuple[]), parsed)
    end
  end

  # splines (control points verbatim; curve shape is Tier 3)
  if haskey(exp, :splines) || exhaustive
    let spline_kinds = (:spline, :closed_spline, :hobby_closed_spline,
                        :hobby_spline, :bezier),
        parsed = [(pts=s.data.pts, kind=s.kind)
                  for s in scene.statements if s.kind in spline_kinds]
      check_multiset!(failures, "splines",
                      (e, p) -> e.kind == p.kind && seq_eq(e.pts, p.pts, atol),
                      get(exp, :splines, NamedTuple[]), parsed)
    end
  end

  # nodes (text anchors)
  if haskey(exp, :nodes) || exhaustive
    let parsed = [(anchor=s.data.anchor, text=s.data.text)
                  for s in scene.statements if s.kind === :node]
      check_multiset!(failures, "nodes",
                      (e, p) -> e.text == p.text && approx_point(e.anchor, p.anchor, atol),
                      get(exp, :nodes, NamedTuple[]), parsed)
    end
  end

  # distinct vertex set of polyline-like statements
  if haskey(exp, :vertex_set)
    let parsed = collect(vertex_set(scene))
      check_multiset!(failures, "vertex_set",
                      (e, p) -> approx_point(e, p, atol),
                      exp.vertex_set, parsed)
    end
  end

  # every-vertex-on-a-circle (vouch measure)
  if haskey(exp, :on_circles)
    let (; r, centers) = exp.on_circles,
        on_some = v -> any(abs(v[3] - c[3]) <= atol &&
                           abs(hypot(v[1] - c[1], v[2] - c[2]) - r) <= atol
                           for c in centers),
        vs = scene_vertices(scene),
        off = count(!on_some, vs)
      off == 0 ||
        push!(failures, "on_circles: $off of $(length(vs)) vertices lie on none " *
                        "of the $(length(centers)) analytic circles")
    end
  end

  # AABB over statement coordinate points
  if haskey(exp, :aabb)
    let bb = scene_aabb(scene)
      approx_point(exp.aabb.lo, bb.lo, atol) && approx_point(exp.aabb.hi, bb.hi, atol) ||
        push!(failures, "aabb: expected $(exp.aabb), parsed $bb")
    end
  end

  # explicit statement counts (e.g. triangle decomposition arity)
  if haskey(exp, :counts)
    let counts = scene_counts(scene)
      for (k, v) in pairs(exp.counts)
        get(counts, k, 0) == v ||
          push!(failures, "counts: expected $k = $v, parsed $(get(counts, k, 0))")
      end
    end
  end

  #=
  Exhaustiveness: the expectation lists everything the scene may contain, so
  the scene's per-kind statement counts must equal the counts the listed
  measures imply (plus any explicit `counts` entries).  This is what turns
  "all expected items were found" into "and nothing else is there".
  =#
  if exhaustive
    let derived = Dict{Symbol,Int}()
      add!(k, n) = n == 0 || (derived[k] = get(derived, k, 0) + n)
      add!(:circle, length(exp_circles) + length(exp_points))
      add!(:arc, length(get(exp, :arcs, ())))
      add!(:rectangle, length(get(exp, :rectangles, ())))
      add!(:node, length(get(exp, :nodes, ())))
      for pl in get(exp, :polylines, ())
        add!(pl.closed ? :polygon : :line, 1)
      end
      for sp in get(exp, :splines, ())
        add!(sp.kind, 1)
      end
      for (k, v) in pairs(get(exp, :counts, (;)))
        add!(k, v)
      end
      let actual = scene_counts(scene)
        derived == actual ||
          push!(failures, "exhaustive counts: expected $derived, parsed $actual")
      end
    end
  end

  isempty(failures) ?
    (true, "all measures match (atol=$atol): " *
           join(["$k=$v" for (k, v) in sort(collect(scene_counts(scene)), by=first)], ", ")) :
    (false, join(failures, " | "))
end

"""
    validate_tikz_golden(name, category, path)

`validate_golden` slot for VisualTests (and the always-on Tier-1 testset):
`nothing` when scene `name` has no expectation, otherwise
`(ok, "tikz-parse:v1", detail)`.  Parser/oracle exceptions are reported as
a failed validation rather than thrown, per the mint_golden! contract.
"""
validate_tikz_golden(name, category, path) =
  SceneExpectations.tikz_parseable(name) ?
    try
      let scene = parse_tikz(path),
          (ok, detail) = compare_measures(scene, SceneExpectations.expected(name))
        (ok, "tikz-parse:v1", detail)
      end
    catch e
      (false, "tikz-parse:v1", "exception: $(sprint(showerror, e))")
    end :
    nothing

"""
    vouch_tikz_golden(name, golden_dir)

Standalone assessment of a (possibly stale) golden against its analytic
expectation — informs the pending human regold decision, never regolds.
Returns `(name, ok, method, detail)`; `ok === nothing` means no sound
oracle exists for the scene (recorded honestly).
"""
vouch_tikz_golden(name, golden_dir) =
  let path = joinpath(golden_dir, "$name.tex"),
      exp = SceneExpectations.expected(name)
    if exp === nothing
      let counts = try
            join(["$k=$v" for (k, v) in sort(collect(scene_counts(parse_tikz(path))), by=first)], ", ")
          catch e
            "parse failed: $(sprint(showerror, e))"
          end
        (name=name, ok=nothing, method="tikz-parse:v1",
         detail="not analytically vouchable (spline-sampled triangulation has " *
                "no closed-form vertex set); artifact parses as: $counts")
      end
    else
      try
        let (ok, detail) = compare_measures(parse_tikz(path), exp)
          (name=name, ok=ok, method="tikz-parse:v1", detail=detail)
        end
      catch e
        (name=name, ok=false, method="tikz-parse:v1",
         detail="exception: $(sprint(showerror, e))")
      end
    end
  end

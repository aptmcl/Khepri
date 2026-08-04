#=
Live verification of AutoCAD spline geometry against Khepri's canonical curve.

Prerequisites:
  1. AutoCAD running with the Khepri plugin >= 1.192 loaded (restart AutoCAD
     after upgrade_plugin() so InterpSplineNoTangents and the cubic-order
     InterpSpline are available).
  2. Run:  julia --project=Julia/KhepriAutoCAD Julia/KhepriAutoCAD/test/verify_splines.jl

For each case this script draws the native AutoCAD spline, samples it densely
through CurvePointsAt, and measures its distance to the canonical curve
(open_spline_bezier_path -- the same curve location_at/sweeps follow and that
every other backend draws). It also compares end-tangent directions, which is
the direct regression check for the end-of-spline wiggle (a reversed tangent
shows up as a dot product near -1).

Interpretation:
  - tangent cases should agree to well under 1% of the curve size; a large
    deviation means AutoCAD's clamped fit uses a different tangent magnitude
    heuristic and open_spline_tangents scaling should be revisited.
  - the no-tangent case measures how far AutoCAD's own natural end conditions
    are from the canonical (not-a-knot) interpolant. If END DOT is ~1 but the
    deviation is visually meaningful, switch the b_spline no-tangent branch to
    pass canonical tangents explicitly (see the comment on b_spline in
    AutoCAD.jl).
=#
using KhepriAutoCAD
using KhepriAutoCAD.KhepriBase:
  open_spline_bezier_path, open_spline_tangents, in_world, distance, unitized, world_cs
const KB = KhepriAutoCAD.KhepriBase

bernstein(cps, τ) =
  let (p0, p1, p2, p3) = Tuple(cps),
      s = 1 - τ
    xyz(s^3*p0.x + 3s^2*τ*p1.x + 3s*τ^2*p2.x + τ^3*p3.x,
        s^3*p0.y + 3s^2*τ*p1.y + 3s*τ^2*p2.y + τ^3*p3.y,
        s^3*p0.z + 3s^2*τ*p1.z + 3s*τ^2*p2.z + τ^3*p3.z,
        world_cs)
  end

canonical_samples(ps, v0, v1, n_per_span=200) =
  [bernstein(span.control_points, τ)
   for span in open_spline_bezier_path(ps, v0, v1).spans
   for τ in range(0, 1, length=n_per_span)]

dist_to_polyline(p, qs) = minimum(distance(p, q) for q in qs)

vdot(a, b) = sum(a.raw[1:3] .* b.raw[1:3])

function check(name, ps, v0, v1)
  b = autocad
  ent = KB.b_spline(b, ps, v0, v1, nothing)
  (t_lo, t_hi) = KB.@remote(b, CurveDomain(ent))
  ts = collect(range(t_lo, t_hi, length=200))
  native = KB.@remote(b, CurvePointsAt(ent, ts))
  native_tans = KB.@remote(b, CurveTangentsAt(ent, [t_lo, t_hi]))
  canon = canonical_samples(ps, v0, v1)
  (ct0, ct1) = open_spline_tangents(ps, v0, v1)
  size_ref = maximum(distance(in_world(ps[1]), in_world(p)) for p in ps)
  devs = [dist_to_polyline(p, canon) for p in native]
  d0 = vdot(unitized(native_tans[1]), unitized(ct0))
  d1 = vdot(unitized(native_tans[2]), unitized(ct1))
  ok = maximum(devs) < 0.01 * size_ref && d0 > 0.99 && d1 > 0.99
  println(rpad(name, 34),
          " max dev = ", rpad(round(maximum(devs), sigdigits=3), 10),
          " (", round(100 * maximum(devs) / size_ref, sigdigits=2), "% of size)",
          "  START DOT = ", round(d0, digits=4),
          "  END DOT = ", round(d1, digits=4),
          "  ", ok ? "PASS" : "CHECK")
  ok
end

delete_all_shapes()
results = [
  check("repro, no tangents", [xy(0, 0), xy(10, -4), xy(20, 0)], false, false),
  check("repro, both tangents", [xy(0, 0), xy(10, -4), xy(20, 0)], vxy(1, 0), vxy(1, 1)),
  check("repro, start tangent only", [xy(0, 0), xy(10, -4), xy(20, 0)], vxy(1, 0), false),
  check("repro, end tangent only", [xy(0, 0), xy(10, -4), xy(20, 0)], false, vxy(1, 1)),
  check("5-point, no tangents", [xy(0, 0), xy(1, 2), xy(3, 1), xy(5, 3), xy(7, 0)], false, false),
  check("3D, no tangents", [xyz(0, 0, 0), xyz(2, 3, 1), xyz(5, 2, 3), xyz(8, 0, 2)], false, false),
]
println(all(results) ? "ALL PASS" : "SOME CASES NEED ATTENTION (see above)")

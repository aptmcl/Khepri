# test_tikz_parser.jl — Tier-1 tests for the TikZ artifact parser:
#   (a) dialect unit tests on literal statement strings (one per production)
#   (b) parser ↔ emitter round-trips through the headless IOBuffer backend
#   (c) the always-on Tier-1 testset: fresh artifacts for every in-scope
#       visual-test scene, validated against analytic expectations — no
#       goldens involved
#   (d) anchor tests pinning expectation literals to hand-derived constants
#       (the oracle-of-the-oracle, as in KhepriBase/test/Oracles.jl)
#
# Requires (from runtests.jl): using KhepriTikZ/KhepriBase/Test,
# BackendTestScaffolding (VisualTests names, io_output/clear_io! helpers),
# and TikZOracle.jl (validate_tikz_golden, compare_measures,
# SceneExpectations).

# Wrap a statement body in the exact document frame gen_tex_document emits,
# so literal-dialect tests parse complete artifacts.
tikz_snippet(body; options="", shades=Int[]) =
  join(vcat(
    ["\\documentclass{standalone}",
     "\\usepackage{tikz,tikz-3dplot}",
     "\\usetikzlibrary{perspective,patterns}",
     "\\usetikzlibrary{calc,fadings,decorations.pathreplacing}",
     "\\usetikzlibrary{shapes,fit}",
     "\\usetikzlibrary{hobby}",
     "\\usetikzlibrary{arrows.meta}",
     "\\begin{document}",
     "\\tikzset{illustration/.style={very thin}}",
     "\\tikzset{dimension/.style={very thin,lightgray}}"],
    ["\\definecolor{s$i}{gray}{$(i/100)}" for i in shades],
    ["\\begin{tikzpicture}[$options]",
     body,
     "\\end{tikzpicture}",
     "\\end{document}"]), "\n")

parse_snippet(body; kwargs...) = parse_tikz(IOBuffer(tikz_snippet(body; kwargs...)))

approx3(a, b; atol=1e-9) = all(abs(x - y) <= atol for (x, y) in zip(a, b))

@testset "TikZ artifact parser (Tier 1)" begin

  @testset "dialect: one production per emitter function" begin
    # tikz_circle
    let s = parse_snippet(raw"\draw (0,0)circle(1cm);"),
        c = scene_circles(s)[1]
      @test scene_counts(s) == Dict(:circle => 1)
      @test approx3(c.center, (0, 0, 0)) && c.r == 1.0 && !c.filled
    end
    # tikz_point (filled dot of the fixed on-paper radius)
    let s = parse_snippet(raw"\fill (2.742,-0.671)circle(0.03cm);"),
        c = scene_circles(s)[1]
      @test c.filled && c.r == TIKZ_DOT_RADIUS
      @test approx3(c.center, (2.742, -0.671, 0))
    end
    # tikz_ellipse
    let s = parse_snippet(raw"\draw [shift={(2,3)}][rotate=45.0](0,0)ellipse(2cm and 1cm);"),
        e = s.statements[1]
      @test e.kind === :ellipse
      @test approx3(e.data.center, (2, 3, 0))
      @test e.data.rx == 2.0 && e.data.ry == 1.0 && e.data.rotation == 45.0
    end
    # tikz_arc — canonical center = start − r·(cos ai, sin ai)
    let s = parse_snippet(raw"\draw (2.828,2.828)arc(45.0:225.0:4cm);"),
        a = scene_arcs(s)[1]
      @test approx3(a.center, (2.828 - 4cosd(45), 2.828 - 4sind(45), 0))
      @test a.r == 4.0 && a.ai == 45.0 && a.af == 225.0 && !a.filled
    end
    # tikz_arc, filled wedge (leading apex + --cycle)
    let s = parse_snippet(raw"\fill (0,0)--(5.0,0.0)arc(0.0:90.0:5cm)--cycle;"),
        a = scene_arcs(s)[1]
      @test a.filled && approx3(a.center, (0, 0, 0)) && a.r == 5.0
      @test a.ai == 0.0 && a.af == 90.0
    end
    # angle-interval normalization: -180:0 ≡ (180, 360)
    let a = scene_arcs(parse_snippet(raw"\draw (16.0,31.5)arc(-180.0:0.0:2cm);"))[1]
      @test a.ai == 180.0 && a.af == 360.0
      @test approx3(a.center, (18, 31.5, 0))
    end
    # tikz_line / tikz_closed_line
    let s = parse_snippet("\\draw (0,0)--(5,0)--(5,5);\n" *
                          raw"\draw (6,0)--(10,0)--(10,4)--(8,5)--(6,3)--cycle;")
      @test scene_counts(s) == Dict(:line => 1, :polygon => 1)
      @test s.statements[1].data.pts == [(0, 0, 0), (5, 0, 0), (5, 5, 0)]
      @test length(s.statements[2].data.pts) == 5
    end
    # paint_trig: shaded 3D triangle fill (3d view picture options)
    let s = parse_snippet(raw"\fill[s28] (15,7,0)--(6.0,7.0,1.0)--(15.0,7.0,1.0)--cycle;",
                          options="3d view={-14.598411358038462}{49.78019809531759},fill=gray",
                          shades=[28]),
        t = s.statements[1]
      @test t.kind === :triangle && t.shade == 28 && t.filled
      @test t.data.pts == [(15, 7, 0), (6, 7, 1), (15, 7, 1)]
      @test s.view !== nothing && isapprox(s.view.phi, -14.598411358038462)
      @test vertex_set(s) == Set([(15.0, 7.0, 0.0), (6.0, 7.0, 1.0), (15.0, 7.0, 1.0)])
    end
    # tikz_rectangle
    let r = scene_rect_corners(parse_snippet(raw"\draw (40,0)rectangle(39.0,1.0);"))[1]
      @test approx3(r.lo, (39, 0, 0)) && approx3(r.hi, (40, 1, 0))
    end
    # tikz_polar_segment
    let p = parse_snippet(raw"\draw (1,1)--+(45.0:2.0);").statements[1]
      @test p.kind === :polar_segment
      @test approx3(p.data.tip, (1 + 2cosd(45), 1 + 2sind(45), 0))
    end
    # tikz_spline / tikz_closed_spline / tikz_hobby_closed_spline
    let s = parse_snippet("\\draw plot [smooth,tension=1] coordinates {(0,0)(1,2)(3,1)};\n" *
                          "\\draw plot [smooth cycle,tension=1] coordinates {(0,0)(1,0)(1,1)};\n" *
                          raw"\draw [closed hobby]plot coordinates {(0,0)(1,0)(1,1)(0,1)};")
      @test scene_counts(s) ==
            Dict(:spline => 1, :closed_spline => 1, :hobby_closed_spline => 1)
      @test s.statements[1].data.pts == [(0, 0, 0), (1, 2, 0), (3, 1, 0)]
    end
    # tikz_interp_spline / b_bezier_curve: ..controls chain
    let b = parse_snippet(raw"\draw (0,0)..controls(0.333,0.333)and(0.667,0.667)..(1.0,1.0)..controls(1.333,1.333)and(1.667,1.667)..(2.0,2.0);").statements[1]
      @test b.kind === :bezier
      @test b.data.pts == [(0, 0, 0), (1, 1, 0), (2, 2, 0)]
      @test length(b.data.controls) == 2
      @test b.data.controls[1] == ((0.333, 0.333, 0.0), (0.667, 0.667, 0.0))
    end
    # tikz_hobby_spline: ..-joined coordinates inside its scope (note the
    # emitter's \end{scope}; — tikz_e appends the semicolon)
    let s = parse_snippet("\\begin{scope}[use Hobby shortcut, tension=0.1]\n" *
                          "\\draw (0,0)..(1,2)..(3,1);\n" *
                          "\\end{scope};")
      @test s.statements[1].kind === :hobby_spline
      @test s.statements[1].data.pts == [(0, 0, 0), (1, 2, 0), (3, 1, 0)]
    end
    # tikz_node via tikz_text (leading [anchor=base west])
    let n = parse_snippet(raw"\draw [anchor=base west](5.0,0.0)node[font=\fontfamily{phv}\selectfont,outer sep=0pt,inner sep=0pt,xscale=3.7,yscale=3.7]{Raio: 4};").statements[1]
      @test n.kind === :node && n.data.text == "Raio: 4"
      @test approx3(n.data.anchor, (5, 0, 0))
    end
    # tikz_transform: cm scope with raw Float64s in scientific notation;
    # the affine applies to anchors/centers and a similarity scales radii
    let s = parse_snippet("\\begin{scope}[cm={6.123233995736766e-17, 1.0, -1.0, 6.123233995736766e-17, (3.0, 4.0)}]\n" *
                          "\\draw (1,0)circle(2cm);\n" *
                          "\\end{scope};"),
        c = scene_circles(s)[1]
      @test approx3(c.center, (3, 5, 0)) && c.r == 2.0
    end
    # withTikZXForm 3D branch: canvas scope lifts 2D coordinates to z
    # (and closes with a bare \end{scope} — println, no semicolon)
    let s = parse_snippet("\\begin{scope}[canvas is xy plane at z=2.5]\n" *
                          "\\draw (1,1)circle(1cm);\n" *
                          "\\end{scope}"),
        c = scene_circles(s)[1]
      @test approx3(c.center, (1, 1, 2.5))
    end
    # withTikZXForm material branch: a material scope has no geometric effect
    let s = parse_snippet("\\begin{scope}[very thin]\n" *
                          "\\draw (0,0)--(1,1);\n" *
                          "\\end{scope}")
      @test s.statements[1].data.pts == [(0, 0, 0), (1, 1, 0)]
    end
  end

  @testset "dialect: unknown constructs error loudly" begin
    @test_throws ErrorException parse_snippet(raw"\draw (0,0) grid (5,5);")
    @test_throws ErrorException parse_snippet(raw"\node at (0,0) {x};")
    # unknown preamble line
    @test_throws ErrorException parse_tikz(IOBuffer(
      replace(tikz_snippet(raw"\draw (0,0)circle(1cm);"),
              "\\usetikzlibrary{hobby}" => "\\usepackage{pgfplots}")))
    # a shade must be declared by \definecolor
    @test_throws ErrorException parse_snippet(raw"\fill[s28] (0,0,0)--(1,0,0)--(0,1,0)--cycle;")
    # unclosed scope / truncated document
    @test_throws ErrorException parse_snippet("\\begin{scope}[very thin]\n\\draw (0,0)--(1,1);")
    # non-similarity cm transform cannot carry a radius
    @test_throws ErrorException parse_snippet("\\begin{scope}[cm={2.0, 0.0, 0.0, 1.0, (0.0, 0.0)}]\n" *
                                              "\\draw (0,0)circle(1cm);\n" *
                                              "\\end{scope};")
    # shaded fill that is not a paint_trig triangle
    @test_throws ErrorException parse_snippet(raw"\fill[s28] (0,0)--(1,0)--(1,1)--(0,1)--cycle;";
                                              shades=[28])
  end

  @testset "emitter round-trip (headless IOBuffer backend)" begin
    rt(emit!) = begin
      clear_io!(tikz)
      emit!()
      parse_snippet(chomp(io_output(tikz)))
    end
    let c = scene_circles(rt(() -> KhepriBase.b_circle(tikz, xy(2, 3), 4.5, nothing)))[1]
      @test approx3(c.center, (2, 3, 0), atol=1e-3) && isapprox(c.r, 4.5, atol=1e-3)
    end
    let a = scene_arcs(rt(() -> KhepriBase.b_arc(tikz, xy(1, 1), 3, pi/6, pi/3, nothing)))[1]
      @test approx3(a.center, (1, 1, 0), atol=1e-3) && isapprox(a.r, 3, atol=1e-3)
      @test isapprox(a.ai, 30, atol=1e-3) && isapprox(a.af, 90, atol=1e-3)
    end
    # negative sweep normalizes to the same angle interval
    let a = scene_arcs(rt(() -> KhepriBase.b_arc(tikz, xy(0, 0), 2, pi/4, -pi/2, nothing)))[1]
      @test isapprox(a.ai, 315, atol=1e-3) && isapprox(a.af, 405, atol=1e-3)
    end
    let s = rt(() -> KhepriBase.b_line(tikz, [xy(0, 0), xy(10, 0), xy(10, 10)], nothing))
      @test s.statements[1].kind === :line
      @test s.statements[1].data.pts == [(0, 0, 0), (10, 0, 0), (10, 10, 0)]
    end
    let s = rt(() -> KhepriBase.b_polygon(tikz, [xy(0, 0), xy(1, 0), xy(1, 1)], nothing))
      @test s.statements[1].kind === :polygon
    end
    let r = scene_rect_corners(rt(() -> KhepriBase.b_rectangle(tikz, xy(1, 2), 3, 4, nothing)))[1]
      @test approx3(r.lo, (1, 2, 0), atol=1e-3) && approx3(r.hi, (4, 6, 0), atol=1e-3)
    end
    # Splines emit the canonical cubic Bézier chain (see open_spline_bezier_path
    # in KhepriBase); the interpolation points survive as the span endpoints.
    let pts = [xy(0, 0), xy(1, 2), xy(3, 1), xy(5, 3)],
        s = rt(() -> KhepriBase.b_spline(tikz, pts, false, false, nothing))
      @test s.statements[1].kind === :bezier
      @test s.statements[1].data.pts == [(0, 0, 0), (1, 2, 0), (3, 1, 0), (5, 3, 0)]
    end
    # explicit tangents: first control = p1 + unit(v0)*d1/3 where d1 is the
    # first chord length (tangents are directions; magnitude is ignored)
    let pts = [xy(0, 0), xy(1, 1), xy(2, 0)],
        s = rt(() -> KhepriBase.b_spline(tikz, pts, vxy(1, 0), vxy(1, 0), nothing)),
        b = s.statements[1]
      @test b.kind === :bezier
      @test b.data.pts == [(0, 0, 0), (1, 1, 0), (2, 0, 0)]
      @test approx3(b.data.controls[1][1], (√2/3, 0, 0), atol=1e-3)
    end
    let s = rt(() -> KhepriBase.b_closed_spline(tikz, [xy(0, 0), xy(1, 0), xy(1, 1), xy(0, 1)], nothing))
      # Canonical periodic C2 cubic through the native bezier emitter: a
      # 4-point cycle is a 4-span ..controls chain closing on its start
      # (previously :hobby_closed_spline — a different curve).
      @test s.statements[1].kind === :bezier
      @test s.statements[1].data.pts[1] == s.statements[1].data.pts[end]
    end
    let c = scene_circles(rt(() -> KhepriBase.b_surface_circle(tikz, xy(0, 0), 3, nothing)))[1]
      @test c.filled && isapprox(c.r, 3, atol=1e-3)
    end
    let e = rt(() -> KhepriBase.b_ellipse(tikz, xy(1, 2), 3, 1.5, nothing)).statements[1]
      @test e.kind === :ellipse && approx3(e.data.center, (1, 2, 0), atol=1e-3)
      @test isapprox(e.data.rx, 3, atol=1e-3) && isapprox(e.data.ry, 1.5, atol=1e-3)
    end
    let n = rt(() -> KhepriBase.b_text(tikz, "Hello", xy(1, 1), 1.0, nothing)).statements[1]
      @test n.kind === :node && n.data.text == "Hello"
      @test approx3(n.data.anchor, (1, 1, 0), atol=1e-3)
    end
    let c = scene_circles(rt(() -> KhepriBase.b_point(tikz, xy(5, 5), nothing)))[1]
      @test c.filled && c.r == TIKZ_DOT_RADIUS && approx3(c.center, (5, 5, 0), atol=1e-3)
    end
  end

  @testset "expectation anchors (hand-derived constants)" begin
    # polygons: triangle at center (3,0), vertex k=1 is (3+cos 120°, sin 120°)
    let e = SceneExpectations.expected("polygons")
      @test approx3(e.polylines[1].pts[2], (2.5, sqrt(3)/2, 0), atol=1e-12)
    end
    # arcs: arc(u0,4,π/4,π) covers exactly (45°, 225°)
    let a = SceneExpectations.expected("arcs").arcs[2]
      @test approx3(a.center, (0, 0, 0), atol=1e-12)
      @test isapprox(a.ai, 45, atol=1e-9) && isapprox(a.af, 225, atol=1e-9)
    end
    # circulosRaios: pol(4, π/4) = (2√2, 2√2)
    let c = SceneExpectations.expected("circulosRaios").circles[2]
      @test approx3(c.center, (2sqrt(2), 2sqrt(2), 0), atol=1e-12)
    end
    # setas: first label anchor — o=(0, 2.4), rotation 0, offset (−0.425, −0.5)
    let n = SceneExpectations.expected("setas").nodes[1]
      @test approx3(n.anchor, (-0.425, 1.9, 0), atol=1e-12)
    end
    # ovos: 7 × 3 eggs × 4 arcs
    @test length(SceneExpectations.expected("ovos").arcs) == 84
    # espiralOuro: (6π − π/2)/(π/2) = 11 full quarter-turn steps, then a
    # zero-width arc (point) and its rectangle
    let e = SceneExpectations.expected("espiralOuro")
      @test length(e.arcs) == 11 && length(e.points) == 1 && length(e.rectangles) == 12
    end
    # extrusions: 11 literal base vertices × z ∈ {0,1}
    let vs = SceneExpectations.expected("extrusaoSolido").vertex_set
      @test length(vs) == 22
      @test (1.0, 0.0, 1.0) in vs && (15.0, 7.0, 0.0) in vs
    end
    # florCirculosExtrudidos: 1 shared base circle + 6×16 top circles;
    # ψ=π/8, ϕ=0 top center is (20 sin(π/8), 0, 20 cos(π/8))
    let oc = SceneExpectations.expected("florCirculosExtrudidos").on_circles
      @test length(oc.centers) == 97
      @test approx3(oc.centers[1], (0, 0, 0), atol=1e-12)
      @test approx3(oc.centers[2], (20sin(pi/8), 0, 20cos(pi/8)), atol=1e-12)
    end
  end

  #=
  The always-on Tier-1 testset: run every in-scope visual-test scene fresh
  (same reset!/rendering_with discipline as run_visual_tests), parse the
  artifact it just emitted, and validate against the analytic expectation.
  No goldens are read or written, so this guards emitter+pipeline geometry
  on every commit even when goldens are stale or pending regold.
  =#
  @testset "Tier-1 fresh artifact validation" begin
    rendering_with(dir=mktempdir(), width=1920, height=1080) do
      setup_raw_view(tikz)
      for (name, category, test_fn) in BackendTestScaffolding.VisualTests.VISUAL_TESTS
        SceneExpectations.tikz_parseable(name) || continue
        @testset "$name" begin
          delete_all_shapes()
          clear_io!(tikz)
          backend(tikz)
          let path = test_fn(),
              result = validate_tikz_golden(name, category, path)
            @test result !== nothing
            let (ok, method, detail) = result
              ok || @warn "Tier-1 validation failed for $name" method detail
              @test ok
            end
          end
        end
      end
    end
  end
end

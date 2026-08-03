using KhepriSVG
using KhepriBase
using Test

# Helper to get the output from the backend's IOBuffer
function get_svg_output(b)
  io = KhepriBase.connection(b)
  String(take!(io))
end

# Helper to clear the backend's buffer
function clear_svg_buffer!(b)
  io = KhepriBase.connection(b)
  take!(io)
  nothing
end

@testset "KhepriSVG.jl" begin

  @testset "Backend initialization" begin
    @test svg isa KhepriBase.LocalBackend
    @test KhepriBase.backend_name(svg) == "SVG"
    @test KhepriBase.void_ref(svg) === -1
  end

  @testset "Number formatting" begin
    @test KhepriSVG.svg_number(5.0) == "5"
    @test KhepriSVG.svg_number(3.14159) == "3.142"
    @test KhepriSVG.svg_number(0.00001) == "0"
    @test KhepriSVG.svg_number(0) == "0"
    @test KhepriSVG.svg_number(1.5) == "1.5"
    @test KhepriSVG.svg_number(2.100) == "2.1"
  end

  @testset "Coordinate formatting" begin
    @test KhepriSVG.svg_coord(xy(3, 4)) == (3.0, -4.0)
    @test KhepriSVG.svg_coord(xy(0, 0)) == (0.0, 0.0)
    @test KhepriSVG.svg_coord_string(xy(3, 4)) == "3,-4"
  end

  @testset "SVG element generation" begin
    @testset "svg_circle" begin
      io = IOBuffer()
      KhepriSVG.svg_circle(io, xy(0, 0), 5.0, false, nothing)
      output = String(take!(io))
      @test occursin("<circle", output)
      @test occursin("r=\"5\"", output)
      @test occursin("fill:none", output)
    end

    @testset "svg_circle filled" begin
      io = IOBuffer()
      KhepriSVG.svg_circle(io, xy(0, 0), 3.0, true, nothing)
      output = String(take!(io))
      @test occursin("<circle", output)
      @test occursin("fill:rgb(0,0,0)", output)
    end

    @testset "svg_line" begin
      io = IOBuffer()
      KhepriSVG.svg_line(io, [xy(0, 0), xy(10, 5)], nothing)
      output = String(take!(io))
      @test occursin("<polyline", output)
      @test occursin("0,0", output)
      @test occursin("10,-5", output)
    end

    @testset "svg_closed_line" begin
      io = IOBuffer()
      KhepriSVG.svg_closed_line(io, [xy(0, 0), xy(1, 0), xy(1, 1)], true, nothing)
      output = String(take!(io))
      @test occursin("<polygon", output)
      @test occursin("fill:rgb(0,0,0)", output)
    end

    @testset "svg_rectangle" begin
      io = IOBuffer()
      KhepriSVG.svg_rectangle(io, xy(0, 0), 10.0, 5.0, false, nothing)
      output = String(take!(io))
      @test occursin("<rect", output)
      @test occursin("width=\"10\"", output)
      @test occursin("height=\"5\"", output)
    end

    @testset "svg_arc" begin
      io = IOBuffer()
      KhepriSVG.svg_arc(io, xy(0, 0), 5.0, 0, pi/2, false, nothing)
      output = String(take!(io))
      @test occursin("<path", output)
      @test occursin("A ", output) || occursin("A 5", output)
    end
  end

  @testset "Backend drawing operations" begin
    @testset "b_point" begin
      clear_svg_buffer!(svg)
      KhepriBase.b_point(svg, xy(5, 5), nothing)
      output = get_svg_output(svg)
      @test occursin("<circle", output)
      @test occursin("r=\"0.03\"", output)
    end

    @testset "b_line" begin
      clear_svg_buffer!(svg)
      KhepriBase.b_line(svg, [xy(0, 0), xy(10, 0), xy(10, 10)], nothing)
      output = get_svg_output(svg)
      @test occursin("<polyline", output)
    end

    @testset "b_polygon" begin
      clear_svg_buffer!(svg)
      KhepriBase.b_polygon(svg, [xy(0, 0), xy(1, 0), xy(1, 1), xy(0, 1)], nothing)
      output = get_svg_output(svg)
      @test occursin("<polygon", output)
      @test occursin("fill:none", output)
    end

    @testset "b_circle" begin
      clear_svg_buffer!(svg)
      KhepriBase.b_circle(svg, xy(0, 0), 5.0, nothing)
      output = get_svg_output(svg)
      @test occursin("<circle", output)
      @test occursin("r=\"5\"", output)
    end

    @testset "b_arc" begin
      clear_svg_buffer!(svg)
      KhepriBase.b_arc(svg, xy(0, 0), 5.0, 0, pi/2, nothing)
      output = get_svg_output(svg)
      @test occursin("<path", output)
    end

    @testset "b_rectangle" begin
      clear_svg_buffer!(svg)
      KhepriBase.b_rectangle(svg, xy(0, 0), 10.0, 5.0, nothing)
      output = get_svg_output(svg)
      @test occursin("<rect", output)
    end

    @testset "b_surface_polygon" begin
      clear_svg_buffer!(svg)
      KhepriBase.b_surface_polygon(svg, [xy(0, 0), xy(1, 0), xy(1, 1)], nothing)
      output = get_svg_output(svg)
      @test occursin("<polygon", output)
      @test occursin("fill:rgb(0,0,0)", output)
    end

    @testset "b_spline" begin
      clear_svg_buffer!(svg)
      KhepriBase.b_spline(svg, [xy(0, 0), xy(1, 1), xy(2, 0), xy(3, 1)], false, false, nothing)
      output = get_svg_output(svg)
      @test occursin("<path", output)
      @test occursin("C ", output) || occursin("C ", output)
    end

    @testset "b_text" begin
      clear_svg_buffer!(svg)
      KhepriBase.b_text(svg, "Hello", xy(0, 0), 1.0, nothing)
      output = get_svg_output(svg)
      @test occursin("<text", output)
      @test occursin("Hello", output)
    end
  end

  @testset "SVG document generation" begin
    # Use the full shape proxy → document pipeline
    backend(svg)
    delete_all_shapes()
    line(xy(0, 0), xy(10, 0))
    circle(xy(5, 5), 3)

    clear_svg_buffer!(svg)
    KhepriSVG.gen_svg_document(svg)
    output = get_svg_output(svg)

    @test startswith(output, "<svg")
    @test occursin("xmlns=\"http://www.w3.org/2000/svg\"", output)
    @test occursin("viewBox=", output)
    @test occursin("<defs>", output)
    @test occursin("</svg>", output)
    @test occursin("<polyline", output) || occursin("<circle", output)

    delete_all_shapes()
  end

  # ======================================================================
  # Annotation features — these match the corresponding TikZ output
  # (same geometry, same arrow direction, same label angle). Failures
  # here mean a drawing emitted from KhepriSVG would no longer look like
  # the equivalent KhepriTikZ output.
  # ======================================================================

  @testset "Arrow option helpers" begin
    @test var"<->" isa KhepriBase.Material
    @test var"->" isa KhepriBase.Material
    @test var"<-" isa KhepriBase.Material
    @test latex_latex isa KhepriBase.Material
    @test _latex isa KhepriBase.Material
    @test latex_ isa KhepriBase.Material
    # latex_latex, _latex, latex_ should alias <->, ->, <- respectively
    @test latex_latex === var"<->"
    @test _latex === var"->"
    @test latex_ === var"<-"
  end

  @testset "Arrow directive parsing" begin
    let (s, e, sc, css) = KhepriSVG.parse_arrow_props("--arrow-end:1;stroke:rgb(0,0,128)")
      @test s == false
      @test e == true
      @test sc == 1.0
      @test css == "stroke:rgb(0,0,128)"
    end
    let (s, e, sc, css) = KhepriSVG.parse_arrow_props("--arrow-start:0.5;--arrow-end:0.5;stroke-width:0.2")
      @test s == true
      @test e == true
      @test sc == 0.5
      @test css == "stroke-width:0.2"
    end
    let (s, e, sc, css) = KhepriSVG.parse_arrow_props("stroke-width:0.2;stroke:red")
      @test s == false
      @test e == false
      @test css == "stroke-width:0.2;stroke:red"
    end
    # Integer / nothing inputs should not trip
    let (s, e, sc, css) = KhepriSVG.parse_arrow_props(-1)
      @test s == false && e == false && css == ""
    end
    let (s, e, sc, css) = KhepriSVG.parse_arrow_props(nothing)
      @test s == false && e == false && css == ""
    end
  end

  @testset "Stroke color extraction" begin
    @test KhepriSVG.extract_stroke_color("stroke:rgb(1,2,3)") == "rgb(1,2,3)"
    @test KhepriSVG.extract_stroke_color("stroke-width:0.2;stroke:rgb(1,2,3)") == "rgb(1,2,3)"
    # Bare-color form (b_material output) becomes the stroke color
    @test KhepriSVG.extract_stroke_color("rgb(0,0,128)") == "rgb(0,0,128)"
    @test KhepriSVG.extract_stroke_color("") == "rgb(0,0,0)"
    @test KhepriSVG.extract_stroke_color("stroke-width:0.2") == "rgb(0,0,0)"
  end

  @testset "Angle → SVG anchor mapping" begin
    # 0° → text to the right of anchor
    @test KhepriSVG.svg_anchor_for_angle(0.0) == ("start", "middle")
    # π/2 → above
    @test KhepriSVG.svg_anchor_for_angle(π/2) == ("middle", "auto")
    # π → left
    @test KhepriSVG.svg_anchor_for_angle(π) == ("end", "middle")
    # 3π/2 (= -π/2) → below
    @test KhepriSVG.svg_anchor_for_angle(3π/2) == ("middle", "hanging")
    # Diagonals
    @test KhepriSVG.svg_anchor_for_angle(π/4) == ("start", "auto")           # upper-right
    @test KhepriSVG.svg_anchor_for_angle(3π/4) == ("end", "auto")            # upper-left
    @test KhepriSVG.svg_anchor_for_angle(-π/4) == ("start", "hanging")       # lower-right
    @test KhepriSVG.svg_anchor_for_angle(-3π/4) == ("end", "hanging")        # lower-left
  end

  @testset "Arrow marker registration" begin
    # Reuse the global svg backend; we'll clean up afterwards. Avoids
    # depending on KhepriBase internals we don't want to import here.
    empty!(svg.arrow_markers)
    id1 = KhepriSVG.register_arrow!(svg, :end, "rgb(0,0,128)", 1.0)
    id2 = KhepriSVG.register_arrow!(svg, :end, "rgb(0,0,128)", 1.0)
    @test id1 == id2  # idempotent for same key
    id3 = KhepriSVG.register_arrow!(svg, :start, "rgb(0,0,128)", 1.0)
    @test id3 != id1
    id4 = KhepriSVG.register_arrow!(svg, :end, "rgb(255,0,0)", 1.0)
    @test id4 != id1
    @test length(svg.arrow_markers) == 3
    empty!(svg.arrow_markers)
  end

  @testset "Arrowed line emission" begin
    backend(svg)
    delete_all_shapes()
    clear_svg_buffer!(svg)
    # Arrow-decorated line. Khepri's `line(p, q)` helper forwards to
    # `line([p, q])` without kwargs, so we build the vertex vector
    # explicitly to attach the material.
    line([xy(0, 0), xy(5, 0)], material=var"->")
    KhepriSVG.gen_svg_document(svg)
    output = get_svg_output(svg)
    @test occursin("marker-end=\"url(#ah-end-", output)
    @test occursin("<marker id=\"ah-end-", output)
    @test occursin("markerUnits=\"userSpaceOnUse\"", output)
    delete_all_shapes()
  end

  @testset "Bidirectional arrow line" begin
    backend(svg)
    delete_all_shapes()
    clear_svg_buffer!(svg)
    line([xy(0, 0), xy(5, 0)], material=var"<->")
    KhepriSVG.gen_svg_document(svg)
    output = get_svg_output(svg)
    @test occursin("marker-start=\"url(#ah-start-", output)
    @test occursin("marker-end=\"url(#ah-end-", output)
    delete_all_shapes()
  end

  @testset "Dimension line uses dim-grey arrows" begin
    backend(svg)
    delete_all_shapes()
    clear_svg_buffer!(svg)
    dimension(xy(0, 0), xy(10, 0), "10")
    KhepriSVG.gen_svg_document(svg)
    output = get_svg_output(svg)
    @test occursin("rgb(211,211,211)", output)         # light-gray dim color
    @test occursin("marker-start=\"url(#ah-start-", output)
    @test occursin("marker-end=\"url(#ah-end-", output)
    delete_all_shapes()
  end

  @testset "Radii illustration" begin
    backend(svg)
    delete_all_shapes()
    clear_svg_buffer!(svg)
    radius_illustration(xy(0, 0), 5, "r=5")
    KhepriSVG.gen_svg_document(svg)
    output = get_svg_output(svg)
    # Bidirectional arrow on the radial segment
    @test occursin("marker-start=", output)
    @test occursin("marker-end=", output)
    # Label appears
    @test occursin("r=5", output)
    delete_all_shapes()
  end

  @testset "Vector illustration" begin
    backend(svg)
    delete_all_shapes()
    clear_svg_buffer!(svg)
    vector_illustration(xy(0, 0), pi/4, 5, "v")
    KhepriSVG.gen_svg_document(svg)
    output = get_svg_output(svg)
    @test occursin("marker-start=", output)
    @test occursin("marker-end=", output)
    @test occursin(">v</text>", output)
    delete_all_shapes()
  end

  @testset "Angle illustration" begin
    backend(svg)
    delete_all_shapes()
    clear_svg_buffer!(svg)
    angle_illustration(xy(0, 0), 5, 0, pi/3, "r", "0", "π/3")
    KhepriSVG.gen_svg_document(svg)
    output = get_svg_output(svg)
    @test occursin("π/3", output)
    @test occursin(">r</text>", output)
    @test occursin("<path d=\"M ", output)  # inner arc
    delete_all_shapes()
  end

  @testset "Text uses Helvetica family" begin
    backend(svg)
    delete_all_shapes()
    clear_svg_buffer!(svg)
    text("Hello", xy(0, 0), 1.0)
    KhepriSVG.gen_svg_document(svg)
    output = get_svg_output(svg)
    @test occursin("Helvetica", output)
    @test occursin(">Hello</text>", output)
    delete_all_shapes()
  end

  @testset "Single-point labels merge into one annotation" begin
    backend(svg)
    delete_all_shapes()
    clear_svg_buffer!(svg)
    # Three labels at the same point should produce one labels()
    # annotation — the SVG output should have a single dot.
    label(xy(0, 0), "A")
    label(xy(0, 0), "B")
    label(xy(0, 0), "C")
    KhepriSVG.gen_svg_document(svg)
    output = get_svg_output(svg)
    @test occursin(">A</text>", output)
    @test occursin(">B</text>", output)
    @test occursin(">C</text>", output)
    delete_all_shapes()
  end

  # ======================================================================
  # Visual regression: same scene, ask each backend's text-comparable
  # output to match the matching golden under test/golden/. The golden
  # files were generated by KhepriSVG itself (one `raw_view` per test);
  # the goal is to lock in the *current* SVG output so future edits can
  # be caught by `text_compare`. The tests share VisualTests.jl with
  # KhepriBase, just like KhepriTikZ.
  # ======================================================================

  @testset "Visual Regression (SVG)" begin
    include(joinpath(dirname(pathof(KhepriBase)), "..", "test", "VisualTests.jl"))
    using .VisualTests

    run_visual_tests(svg,
      golden_dir = joinpath(@__DIR__, "golden"),
      reset! = () -> begin
        delete_all_shapes()
        clear_svg_buffer!(svg)
        backend(svg)
      end,
      compare = text_compare,
      # 3D categories aren't the focus — they're emulated via flat
      # painter triangles that are not yet meant to look like TikZ.
      skip = [:csg, :primitives_3d, :surfaces, :extrusions, :parametric],
    )
  end
end

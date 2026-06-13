export tikz,
       tikz_output,
       tikz_output_and_reset

take(out::IO) =
  let contents = String(take!(out))
    print(out, contents)
    contents
 end

tikz_e(out::IO, arg) =
  begin
    print(out, arg)
    println(out, ";")
  end

export use_wireframe
use_wireframe = Parameter(false)

tikz_options(out::IO, options::Nothing) =
  nothing
tikz_options(out::IO, options::String) =
  print(out, "[$(options)]")
tikz_options(out::IO, options::Integer) =
  nothing  # Ignore void_ref integer values

#=
Wireframe is, by design, an *outline-only* rendering mode: it shows the edges
of every shape and paints no faces. We honour that with a single coordinated
policy split across the two TikZ levels that can introduce a fill:

  * path level (here, `tikz_draw`): a "filled" path is emitted as `\fill`
    only when we are NOT in wireframe mode; in wireframe mode it degrades to
    `\draw`, i.e. just the outline. This is intentional, not a missing case --
    a filled `surface_polygon` in wireframe mode SHOULD render as its boundary.

  * picture level (`wireframe_picture_fill_option`): the surrounding
    `tikzpicture` only sets the default `fill=gray` colour when NOT in
    wireframe mode, so even the `\fill` paths that 3D solids emit (via
    `paint_trig`, which always fills) have somewhere to take their colour from.

Keeping the rule in these two named places -- and nowhere else -- is the whole
point: earlier copies of the picture-level string lived in dead `tikz_set_view`
helpers and drifted.

See also: wireframe_picture_fill_option, use_wireframe, paint_trig.
=#
tikz_draw(out::IO, filled=false) =
  print(out, filled && ! use_wireframe() ? "\\fill " : "\\draw ")

"""
    wireframe_picture_fill_option()

Picture-level `tikzpicture` option that supplies the default face colour, or
the empty string in wireframe mode (where no faces are painted). Single source
of truth for the picture-level half of the wireframe-fill policy documented on
`tikz_draw`.
"""
wireframe_picture_fill_option() =
  use_wireframe() ? "" : ",fill=gray"

tikz_number(out::IO, x::Real) =
  isinteger(x) ?
    print(out, x) :
    (abs(x) < 0.001 ?
      print(out, 0) :
      print(out, round(x*1000.0)/1000.0))

tikz_number_string(x::Real) =
  sprint(tikz_number, x)


tikz_deg_string(x) =
  tikz_number_string(rad2deg(x))

tikz_cm(out::IO, x::Real) = begin
  tikz_number(out, x)
  print(out, "cm")
end

tikz_2d_coord(out::IO, c::Loc) =
  let c = in_world(c)
    print(out, "(")
    tikz_number(out, c.x)
    print(out, ",")
    tikz_number(out, c.y)
    print(out, ")")
  end

tikz_vpol_coord(out::IO, c::VPol) =
  let c = in_world(c)
    print(out, "(")
    tikz_number(out, rad2deg(c.ϕ))
    print(out, ":")
    tikz_number(out, c.ρ)
    print(out, ")")
  end

tikz_3d_coord(out::IO, c::Loc) =
  let c = in_world(c)
    print(out, "(")
    tikz_number(out, c.x)
    print(out, ",")
    tikz_number(out, c.y)
    print(out, ",")
    tikz_number(out, c.z)
    print(out, ")")
  end
#
tikz_coord(out::IO, c::Loc) =
  let c = in_world(c)
    print(out, "(")
    tikz_number(out, c.x)
    print(out, ",")
    tikz_number(out, c.y)
    if !iszero(c.z)
      print(out, ",")
      tikz_number(out, c.z)
    end
    print(out, ")")
  end


tikz_pgfpoint(out::IO, c::Loc) =
  let c = in_world(c)
    if ! iszero(c.z)
      print(out, "\\pgfpointxyz{")
      tikz_cm(out, c.x)
      print(out, "}{")
      tikz_cm(out, c.y)
      print(out, "}{")
      tikz_cm(out, c.z)
      print(out, "}")
    else
      print(out, "\\pgfpoint{")
      tikz_cm(out, c.x)
      print(out, "}{")
      tikz_cm(out, c.y)
      print(out, "}")
    end
  end

tikz_circle(out::IO, c::Loc, r::Real, filled::Bool=false, options=nothing) =
  begin
    tikz_draw(out, filled)
    tikz_options(out, options)
    tikz_coord(out, c)
    print(out, "circle(")
    tikz_cm(out, r)
    tikz_e(out, ")")
  end

#=
A TikZ point is drawn as a tiny filled circle. Its radius is given in TikZ
canvas centimetres (`tikz_cm` appends "cm"), i.e. on-paper size, independent of
the model's world scale, so points stay a fixed legible size rather than
shrinking or growing with the drawing. 0.03 cm (0.3 mm) reads as a dot yet stays
visible at typical print resolutions. Override if points look too heavy or too
faint for a given page scale.
See also: tikz_point, tikz_circle, tikz_cm.
=#
"On-paper radius, in TikZ centimetres, of the filled dot drawn for a point."
const tikz_point_radius = 0.03

tikz_point(out::IO, c::Loc, options=nothing) =
  tikz_circle(out, c, tikz_point_radius, true, options)

tikz_ellipse(out::IO, c::Loc, r0::Real, r1::Real, fi::Real, filled=false, options=nothing) =
  begin
    tikz_draw(out, filled)
    tikz_options(out, options)
    print(out, "[shift={")
    tikz_coord(out, c)
    print(out, "}]")
    print(out, "[rotate=")
    tikz_number(out, rad2deg(fi))
    print(out, "]")
    print(out, "(0,0)")
    print(out, "ellipse(")
    tikz_cm(out, r0)
    print(out, " and ")
    tikz_cm(out, r1)
    tikz_e(out, ")")
  end

tikz_arc(out::IO, c::Loc, r::Real, ai::Real, af::Real, filled::Bool, options=nothing) =
  begin
    tikz_draw(out, filled)
    tikz_options(out, options)
    if filled
      tikz_coord(out, c)
      print(out, "--")
    end
    tikz_coord(out, c+vpol(r, ai))
    print(out, "arc(")
    tikz_number(out, rad2deg(ai))
    print(out, ":")
    tikz_number(out, rad2deg(ai > af ? af+2*pi : af))
    print(out, ":")
    tikz_cm(out, r)
    print(out, ")")
    if filled
      tikz_e(out, "--cycle")
    else
      println(out, ";")
    end
  end

tikz_maybe_arc(out::IO, c::Loc, r::Real, ai::Real, da::Real, filled::Bool, options=nothing) =
  if iszero(r)
    tikz_point(out, c, options)
  elseif iszero(da)
    tikz_point(out, c + vpol(r, ai), options)
  #elseif abs(da) >= 2*pi # Some options (e.g., arraws) only make sense for arcs
  #  tikz_circle(out, c, r, filled, options)
  else
    let af = ai + da
      if af > ai
        tikz_arc(out, c, r, ai, af, filled, options)
      else
        tikz_arc(out, c, r, af, ai, filled, options)
      end
    end
  end

tikz_line(out::IO, pts::Locs, options=nothing) =
  begin
    tikz_draw(out, false)
    tikz_options(out, options)
    tikz_coord(out, first(pts))
    for pt in Iterators.drop(pts, 1)
      print(out, "--")
      tikz_coord(out, pt)
    end
    println(out, ";")
  end

tikz_polar_segment(out::IO, p::Loc, v::VPol, options) =
  begin
    tikz_draw(out, false)
    tikz_options(out, options)
    tikz_coord(out, p)
    print(out, "--+")
    tikz_vpol_coord(out, v)
    println(out, ";")
  end

tikz_dimension(out::IO, p::Loc, q::Loc, text::AbstractString) =
  begin
    error("Bum")
    print(out, "\\dimline{")
    tikz_coord(out, p)
    print(out, "}{")
    tikz_coord(out, q)
    print(out, "}{;")
    print(out, text)
    println(out, "};")
  end

tikz_dim_line(out::IO, p::Loc, q::Loc, text::AbstractString, outside) =
  begin
    print(out, "\\draw[dimension,latex-latex]")
    tikz_coord(out, p)
    print(out, "--")
    tikz_coord(out, q)
    println(out, "node[very near end=0.95,auto=left]{$text};")
  end

tikz_node(out::IO, p, txt, options) =
  begin
    tikz_draw(out)
    tikz_coord(out, p)
    print(out, "node")
    tikz_options(out, options)
    print(out, "{")
    print(out, txt)
    tikz_e(out, "}")
  end

tikz_dim_arc(out::IO, c, r, ai, da, r_text, da_text) =
  da ≈ 0.0 || r ≈ 0.0 ?
    nothing :
    let f = random_range(0.2, 0.5)
      tikz_line(out, [c, c+vpol(r*f, ai)], "dimension")
      tikz_line(out, [c, c+vpol(r, ai + da)], "latex-latex,dimension")
      tikz_maybe_arc(out, c, r*f, ai, da, false, "latex-latex,dimension")
      tikz_node(out, intermediate_loc(c, c + vpol(r, ai + da)), r_text, "dimension")
      tikz_node(out, c + vpol(r*(f+0.05), ai + da/2), da_text, "dimension")
    end

tikz_closed_line(out::IO, pts::Locs, filled::Bool=false, options=nothing) =
  begin
    tikz_draw(out, filled)
    tikz_options(out, options)
    for pt in pts
      tikz_coord(out, pt)
      print(out, "--")
    end
    tikz_e(out, "cycle")
  end

tikz_closed_lines(out::IO, ptss, filled::Bool=false, options=nothing) =
  begin
    tikz_draw(out, filled)
    tikz_options(out, options)
    for pts in ptss
      for pt in pts
        tikz_coord(out, pt)
        print(out, "--")
      end
      print(out, "cycle ")
    end
    println(out, ";")
  end

tikz_spline(out::IO, pts::Locs, filled::Bool=false) =
  begin
    tikz_draw(out, filled)
    print(out, "plot [smooth,tension=1] coordinates {")
    for pt in pts
      tikz_coord(out, pt)
    end
    tikz_e(out, "}")
  end

tikz_closed_spline(out::IO, pts::Locs, filled::Bool=false) =
  begin
    tikz_draw(out, filled)
    print(out, "plot [smooth cycle,tension=1] coordinates {")
    for pt in pts
      tikz_coord(out, pt)
    end
    tikz_e(out, "}")
  end

# HACK we need to handle the starting and ending vectors
tikz_hobby_spline(out::IO, pts::Locs, filled::Bool=false) =
  begin
    print(out, "\\begin{scope}")
    println(out, "[use Hobby shortcut, tension=0.1]")
    tikz_draw(out, false)
    tikz_coord(out, first(pts))
    for pt in Iterators.drop(pts, 1)
      print(out, "..")
      tikz_coord(out, pt)
    end
    println(out, ";")
    tikz_e(out, "\\end{scope}")
#=
    tikz_draw(out, filled)
    print(out, "[hobby, tension=0.1]")
    print(out, "plot coordinates {")
    for pt in pts
      tikz_coord(out, pt)
    end
    tikz_e(out, "}")=#
  end

# HACK we need to handle the starting and ending vectors
tikz_hobby_closed_spline(out::IO, pts::Locs, filled::Bool=false) =
  begin
    tikz_draw(out, filled)
    print(out, "[closed hobby]")
    print(out, "plot coordinates {")
    for pt in pts
      tikz_coord(out, pt)
    end
    tikz_e(out, "}")
  end

#=
TikZ has no Hermite/Catmull-Rom curve primitive, but it draws cubic Béziers
natively with `(p0) .. controls (c1) and (c2) .. (p1)`. We render an interpolating
spline (a point list plus Khepri's two end tangents) as a chain of such segments
via the Catmull-Rom construction: the velocity at an interior point Pi is
(P_{i+1} − P_{i−1})/2, and segment Pi→P_{i+1} carries controls
c1 = Pi + T_i/3 and c2 = P_{i+1} − T_{i+1}/3 — the unique cubic whose endpoint
derivatives equal those velocities. Khepri's b_spline convention makes v0 the
forward tangent at the start and v1 the *outgoing* tangent at the end (its
auto-derived value is ps[end-1]-ps[end]), so we set T_1 = v0 and T_n = −v1, which
reduces to the natural Catmull-Rom end tangents when no explicit tangents are
given. The result is a smooth analytic curve, not a sampled polyline.
See also: tikz_spline (tangent-free smooth plot), b_spline, b_bezier_curve.
=#
tikz_interp_spline(out::IO, ps::Locs, v0, v1, options=nothing) =
  let n = length(ps),
      ts = [i == 1 ? v0 :
            i == n ? -v1 :
            (ps[i + 1] - ps[i - 1]) / 2
            for i in 1:n]
    tikz_draw(out, false)
    tikz_options(out, options)
    tikz_coord(out, ps[1])
    for i in 1:n - 1
      print(out, "..controls")
      tikz_coord(out, ps[i] + ts[i] / 3)
      print(out, "and")
      tikz_coord(out, ps[i + 1] - ts[i + 1] / 3)
      print(out, "..")
      tikz_coord(out, ps[i + 1])
    end
    println(out, ";")
  end

tikz_rectangle(out::IO, p::Loc, w::Real, h::Real, filled::Bool=false) =
  begin
    tikz_draw(out, filled)
    tikz_coord(out, p)
    print(out, "rectangle")
    tikz_coord(out, add_xy(p, w, h))
    println(out, ";")
  end

#=
Khepri text height `h` is a world-space cap height, but a TikZ `node` is sized
by a unitless `xscale`/`yscale` applied to the selected family's default 10 pt
glyphs (here Helvetica/Arial, `\fontfamily{phv}`). This empirical factor converts
a unit model height into the scale that makes an Arial glyph's cap height equal
`h`, reproducing AutoCAD's default-font text sizing. It is a pure ratio (the
model-height units cancel), tuned so that `h == 1` yields cap height 1 in the
same units `tikz_coord` emits. Re-tune only if the default font family changes,
since a different typeface has a different cap-height-to-em ratio.
See also: tikz_text, tikz_point_radius.
=#
"Unitless xscale/yscale factor mapping a Khepri text height to Arial cap height."
const tikz_arial_glyph_scale = 3.7

tikz_text(out::IO, txt, p::Loc, h::Real) =
  let (scale_x, scale_y) = (tikz_arial_glyph_scale*h, tikz_arial_glyph_scale*h)
    tikz_draw(out)
    print(out, "[anchor=base west]")
    tikz_coord(out, p)
    print(out, "node[font=\\fontfamily{phv}\\selectfont,outer sep=0pt,inner sep=0pt")
    print(out, ",xscale=")
    tikz_number(out, scale_x)
    print(out, ",yscale=")
    tikz_number(out, scale_y)
    print(out, "]{")
    print(out, txt)
    tikz_e(out, "}")
  end

tikz_color(c) =
  join(vcat(c.alpha ≈ 1.0 ?
              [] :
              ["opacity=$(tikz_number_string(c.alpha))"],
            c.r ≈ 1.0 && c.g ≈ 1.0 && c.b ≈ 1.0 ?
              [] :
              ["color={rgb,1:red,$(tikz_number_string(c.r));green,$(tikz_number_string(c.g));blue,$(tikz_number_string(c.b))}"]),
       ",")

tikz_transform(out::IO, f::Function, c::Loc) =
  let m = c.cs.transform,
      t = in_world(c),
      a = m[1,1], b = m[2,1], c = m[1,2], d = m[2,2],
      tx = t.x, ty = t.y
    print(out, "\\begin{scope}")
    println(out, "[cm={$a, $b, $c, $d, ($tx, $ty)}]")
    f(out)
    tikz_e(out, "\\end{scope}")
  end

# NOTE: the live view pipeline is gen_tex_document -> gen_tikz_picture, which
# wraps the commands and (via wireframe_picture_fill_option) applies the
# wireframe-fill policy. The former tikz_set_view / tikz_set_view_top helpers
# duplicated that picture wrapper, were never called, and re-implemented the
# fill option string by hand; they have been removed so the policy lives in one
# place. See gen_tikz_picture and wireframe_picture_fill_option.

#=
  \begin{tikzpicture}
  \begin{axis}[view={135}{45},axis equal image,scale=4,hide axis
=#
#

@defbackend TikZ TikZ begin
  id_type = Any
  void_ref = -1
  view_type = FrontendView()
  parent = LocalBackend
  mixin(local_shapes)
  mixin(render_state)
  mixin(io)
  view::View = top_view()
  triangles::Vector{Any} = Any[]
  used_shades::Set{Int} = Set{Int}()
end

const tikz = TikZ(view=top_view())

export tikz_option
tikz_option(str) = material(str, TikZ=>str)

export very_thin, thin, thick, very_thick
very_thin = tikz_option("very thin")
thin = tikz_option("thin")
thick = tikz_option("thick")
very_thick = tikz_option("very thick")

export var"<->", var"->", var"<-", latex_latex, latex_, _latex
var"<->" = tikz_option("<->")
var"->" = tikz_option("->")
var"<-" = tikz_option("<-")
latex_latex = tikz_option("latex-latex")
_latex = tikz_option("-latex")
latex_ = tikz_option("latex-")

KhepriBase.merge_backend_materials(b::TikZ, m1::String, m2::String) =
  join(union(split(m1, ","), split(m2, ",")), ",")


#=
b_layer_material overrides KhepriBase's layer-aware generic
(Shapes.jl: b_layer_material(b, layer, spec)). The macro-generated
realize(::MaterialInLayer) calls THAT generic with the realized layer
(a BasicLayer, carrying .color) and the backend spec. The previous name
b_get_material(b, layer, spec) matched no generic at all, so this 3-arg
method was unreachable: every layer colour fell through to the 2-arg
b_get_material(b, spec) default and collapsed to void_ref, i.e. TikZ
layer colouring was dead code.

The default-white test must be approximate. Layer colours are Float
channels; a colour that only rounds to white (e.g. 1 - eps) fails an
exact ==rgba(1,1,1,1) and would emit a spurious near-white scope. The
per-channel ≈ 1 here mirrors tikz_color's own ≈ 1.0 channel suppression,
so a default-white layer yields void_ref (no \begin{scope} emitted).
=#
KhepriBase.b_layer_material(b::TikZ, layer, spec) =
  let c = layer.color
    (c.r ≈ 1 && c.g ≈ 1 && c.b ≈ 1 && c.alpha ≈ 1) ?
      void_ref(b) :
      tikz_color(c)
  end
  
# 2-arg material resolution for an explicit nothing spec (PbrMaterial
# with no backend override). Distinct from the layer-aware
# b_layer_material above; kept so b_get_material(b, nothing) -> void_ref.
KhepriBase.b_get_material(b::TikZ, spec::Nothing) = void_ref(b)

KhepriBase.b_material(b::TikZ, name, base_color) =
  tikz_color(base_color)

KhepriBase.after_connecting(b::TikZ) =
  begin
    set_material()
	#set_material(blender, material_grass, "asset_base_id:97b171b4-2085-4c25-8793-2bfe65650266 asset_type:material")
	#set_material(blender, material_grass, "asset_base_id:7b05be22-6bed-4584-a063-d0e616ddea6a asset_type:material")
  end

withTikZXForm(f, b, c, mat) =
  let out = connection(b),
      mat = mat isa Integer ? nothing : mat  # Ignore void_ref integer values
    if b.view.is_top_view
      if is_world_cs(c.cs) && isnothing(mat)
        f(out, c)
      elseif isnothing(mat)
        tikz_transform(out,
          out -> f(out, u0(world_cs)),
          c)
      else
        println(out, "\\begin{scope}[$mat]")
        withTikZXForm(f, b, c, nothing)
        println(out, "\\end{scope}")
      end
    elseif is_world_cs(c.cs)
      # Don't transform latex println(out, "\\begin{scope}[canvas is xy plane at z=$(c.z),transform shape]")
      println(out, "\\begin{scope}[canvas is xy plane at z=$(c.z)$(isnothing(mat) ? "" : ",$mat")]")
      f(out, xy(c.x, c.y, world_cs))
      println(out, "\\end{scope}")
    else
      error("Unfinished!!!")
    end
  end

KhepriBase.b_point(b::TikZ, p, mat) =
  tikz_point(connection(b), p, mat)

KhepriBase.b_line(b::TikZ, ps, mat) =
  isempty(ps) ? void_ref(b) : tikz_line(connection(b), ps, mat)

KhepriBase.b_polygon(b::TikZ, ps, mat) =
  isempty(ps) ? void_ref(b) : tikz_closed_line(connection(b), ps, false, mat)

function KhepriBase.b_spline(b::TikZ, ps, v0, v1, mat)
  length(ps) < 2 && return void_ref(b)  # a spline needs >= 2 control points (ps[2]/ps[end-1] below)
  if (v0 == false) && (v1 == false)
    #tikz_hobby_spline(connection(b), ps, false)
    tikz_spline(connection(b), ps, false)
  elseif (v0 != false) && (v1 != false)
    tikz_interp_spline(connection(b), ps, v0, v1)
  else
    tikz_interp_spline(connection(b),
                     ps,
                     v0 == false ? ps[2] - ps[1] : v0,
                     v1 == false ? ps[end-1] - ps[end] : v1)
  end
end

KhepriBase.b_closed_spline(b::TikZ, ps, mat) =
  tikz_hobby_closed_spline(connection(b), ps)

#=
A Khepri BezierPath is a chain of BezierSpans (each a control-point list). A cubic
span (4 control points) maps one-to-one onto TikZ's native cubic-Bézier syntax
`(p0) .. controls (c1) and (c2) .. (p3)`, so we emit it directly rather than
sampling the curve to a polyline. Spans of other degrees have no native TikZ form,
so we defer the whole path to the KhepriBase sampled default. All spans share one
`\draw`, so they join seamlessly.
See also: tikz_interp_spline, b_spline.
=#
KhepriBase.b_bezier_curve(b::TikZ, path::BezierPath, mat) =
  all(seg -> length(seg.control_points) == 4, path.spans) ?
    let out = connection(b)
      tikz_draw(out, false)
      tikz_coord(out, path.spans[1].control_points[1])
      for seg in path.spans
        cps = seg.control_points
        print(out, "..controls")
        tikz_coord(out, cps[2])
        print(out, "and")
        tikz_coord(out, cps[3])
        print(out, "..")
        tikz_coord(out, cps[4])
      end
      println(out, ";")
      void_ref(b)
    end :
    invoke(KhepriBase.b_bezier_curve,
           Tuple{KhepriBase.Backend, KhepriBase.BezierPath, Any}, b, path, mat)

KhepriBase.b_circle(b::TikZ, c, r, mat) =
  withTikZXForm(b, c, mat) do out, cc
    tikz_circle(out, cc, r)
  end

# A Khepri ellipse carries its rotation in c.cs, which withTikZXForm already
# applies, so we draw it at the local origin with angle 0 via TikZ's native
# `ellipse(rx and ry)` instead of the default 64-point Hobby-spline sampling.
KhepriBase.b_ellipse(b::TikZ, c, rx, ry, mat) =
  withTikZXForm(b, c, mat) do out, cc
    tikz_ellipse(out, cc, rx, ry, 0, false)
  end

KhepriBase.b_arc(b::TikZ, c, r, α, Δα, mat) =
  withTikZXForm(b, c, mat) do out, cc
    tikz_maybe_arc(out, cc, r, α, Δα, false, mat)
  end

KhepriBase.b_rectangle(b::TikZ, c, dx, dy, mat) =
  withTikZXForm(b, c, mat) do out, cc
    tikz_rectangle(out, cc, dx, dy)
  end

# KhepriBase.b_trig(b::TikZ, p1, p2, p3, mat) =
#   tikz_closed_line(connection(b), [p1, p2, p3], true)

#
# KhepriBase.b_trig(b::TikZ, p1, p2, p3, mat) =
#   let io = connection(b)
#     println(io, raw"\addplot3[patch,table/row sep=\\,patch table={")
#     println(io, "0 1 2 \\")
#     println(io, raw")}] table [row sep=\\] {")
#      x y z c\\
#      0 1 0 0\\
#      0 0 -1 0\\
#      -1 0 0 0\\
#      0 0 1 0\\
#      1 0 0 0\\
#     };
#
# KhepriBase.b_quad(b::TikZ, p1, p2, p3, p4, mat) =
#   tikz_closed_line(connection(b), [p1, p2, p3, p4], true)

# KhepriBase.b_trig(b::TikZ, p1, p2, p3, mat) =
#   let io = connection(b)
#     print(io, raw"\addplot3[patch,shader=interp] coordinates {")
#     tikz_3d_coord(io, p1)
#     tikz_3d_coord(io, p2)
#     tikz_3d_coord(io, p3)
#     println(io, "};")
#   end

# surfaces need to be saved so that they can be sorted
KhepriBase.b_trig(b::TikZ, p1, p2, p3, mat) =
  begin
    push!(b.triangles, (p1, p2, p3, mat))
    nothing
  end

# To better map to TikZ, we also provide a non-portable specialized version of TikZ paths
#=
KhepriBase.@defshape(Shape1D, tikz_path, args::Vector=[])
tikz_path(arg, args...) = tikz_path([arg, args...])

struct TikZNode
  p1::Loc
  p2::Loc
  label::String
  options::String
end

macro n_str(label)
  :($label, $options)
end

tikz_path([x(1),x(2), n"sin(x)", "below"),
=#


paint_trig(b::TikZ, (p1, p2, p3, mat)) =
  let n = try trig_normal(p1, p2, p3) catch; return end,
      io = connection(b),
      v = rotate_vector(b.view.target - b.view.camera, vz(1), pi/4),
      α = round(Int, angle_between(n, v)/pi*100)
    push!(b.used_shades, α)
    print(io, "\\fill[s$(α)] ")
    #print(io, "\\fill[gray, opacity=$α] ")
    tikz_3d_coord(io, p1)
    print(io, "--")
    tikz_3d_coord(io, p2)
    print(io, "--")
    tikz_3d_coord(io, p3)
    println(io, "--cycle;")
  #end
end

#KhepriBase.b_quad(b::TikZ, p1, p2, p3, p4, mat) =
  #tikz_closed_line(connection(b), [p1, p2, p3, p4])
  # let io = connection(b)
  #   print(io, raw"\addplot3[patch,shader=interp] coordinates {")
  #   tikz_3d_coord(io, p1)
  #   tikz_3d_coord(io, p2)
  #   tikz_3d_coord(io, p3)
  #   tikz_3d_coord(io, p4)
  #   println(io, "};")
  # end

KhepriBase.b_surface_polygon(b::TikZ, ps, mat) =
  tikz_closed_line(connection(b), ps, true, mat)

# Filled conics render as native TikZ vector fills (\fill circle/arc/ellipse) —
# exact, compact output — but only in the 2D top view. TikZ has no depth buffer,
# so in a 3D view the backend paints faces back-to-front from the collected
# b.triangles list (paint_trig); a single native \fill would not take part in
# that ordering and could occlude incorrectly. There we keep the KhepriBase
# triangulated default (via invoke), which feeds the depth-sorted pipeline.
# See also: paint_trig, b_surface_polygon, tikz_circle, tikz_ellipse.
KhepriBase.b_surface_circle(b::TikZ, c, r, mat) =
  b.view.is_top_view ?
    withTikZXForm(b, c, mat) do out, cc
      tikz_circle(out, cc, r, true)
    end :
    invoke(KhepriBase.b_surface_circle,
           Tuple{KhepriBase.Backend, Any, Any, Any}, b, c, r, mat)

KhepriBase.b_surface_arc(b::TikZ, c, r, α, Δα, mat) =
  b.view.is_top_view ?
    withTikZXForm(b, c, mat) do out, cc
      tikz_maybe_arc(out, cc, r, α, Δα, true)
    end :
    invoke(KhepriBase.b_surface_arc,
           Tuple{KhepriBase.Backend, Any, Any, Any, Any, Any}, b, c, r, α, Δα, mat)

KhepriBase.b_surface_ellipse(b::TikZ, c, rx, ry, mat) =
  b.view.is_top_view ?
    withTikZXForm(b, c, mat) do out, cc
      tikz_ellipse(out, cc, rx, ry, 0, true)
    end :
    invoke(KhepriBase.b_surface_ellipse,
           Tuple{KhepriBase.Backend, Any, Any, Any, Any}, b, c, rx, ry, mat)

#= Native holed fill needs TikZ's even-odd rule to clear the inner loops; until
   that is wired up we keep the triangulated KhepriBase default, which renders
   holes geometrically.
KhepriBase.b_surface_polygon_with_holes(b::TikZ, ps, qss, mat) =
  tikz_closed_lines(connection(b), [ps, qss...], true)
=#
# realize(b::TikZ, s::Ellipse) =
#   withTikZXForm(b, s.center, mat) do out, c
#     tikz_ellipse(out, c, s.radius_x, s.radius_y, 0, false)
#   end
#
# realize(b::TikZ, s::SurfaceEllipse) =
#   withTikZXForm(b, s.center, mat) do out, c
#     tikz_ellipse(out, c, s.radius_x, s.radius_y, 0, true)
#   end
#
# realize(b::TikZ, s::EllipticArc) =
#   error("Finish this")

#realize(b::TikZ, s::SurfaceElliptic_Arc) = TikZCircle(connection(b),

# KhepriBase.b_surface_rectangle(b::TikZ, c, dx, dy, mat) =
#   withTikZXForm(b, c, mat) do out, cc
#     tikz_rectangle(out, cc, dx, dy, true)
#   end

KhepriBase.b_text(b::TikZ, str, p, size, mat) =
  #invoke(b_text, Tuple{Backend, Any, Any, Any, Any}, b, str, p, size, mat)
  withTikZXForm(b, p, mat) do out, c
    tikz_text(out, str, c, size)
  end

KhepriBase.b_dim_line(b::TikZ, p, q, tv, str, size, outside, mat) =
  #invoke(b_dim_line, Tuple{Backend, Any, Any, Any, Any, Any, Any, Any}, b, p, q, tv, str, size, outside, mat)
  tikz_dim_line(connection(b), p, q, str, outside)

KhepriBase.b_ext_line(b::TikZ, p, q, mat) =
  tikz_line(connection(b), [p, q], "illustration")

KhepriBase.b_arc_dimension(b::TikZ, c, r, α, Δα, rstr, Δstr, size, offset, mat) =
  #= The do-block parameter shadows the outer center on purpose: withTikZXForm
     hands us the LOCAL-frame anchor (the origin of the surrounding TikZ cm/canvas
     scope) when a transform or material scope is active, and the unchanged outer
     center otherwise. Drawing with the outer center inside that scope would let
     tikz_coord emit absolute world coordinates that the scope then transforms a
     second time. Binding the parameter as `c` keeps every coordinate below in the
     frame the scope expects (same convention as b_vectors_illustration). =#
  withTikZXForm(b, c, mat) do out, c
    tikz_dim_arc(out, c, r, α, Δα, rstr, Δstr)
  end


# realize(b::TikZ, s::SurfaceGrid) =
#   invoke(realize, Tuple{Backend, SurfaceGrid}, b, s)
  # let n = size(s.points,1),
  #     m = size(s.points,2)
  #   for i in 1:n
  #     tikz_hobby_spline(connection(b), s.points[i,:], false)
  #   end
  #   for j in 1:m
  #     tikz_hobby_spline(connection(b), s.points[:,j], false)
  #   end
  # end

# Illustrations
texify(expr::String) = expr
texify(expr) = latexify(expr)

KhepriBase.b_labels(b::TikZ, p, data, mat) =
  withTikZXForm(b, p, mat) do out, c
    tikz_node(out, c, "",
        "fill,circle,outer sep=0,inner sep=0,minimum size=2pt,illustration,$(tikz_color(material_color(data[1].mat))),"*
        join(["label={[scale=$scale,illustration,$(tikz_color(material_color(mat)))]$ϕ:$(texify(txt))}"
              for ((; txt, mat, scale), ϕ) in zip(data, division(-45, 315, length(data), false))], ","))
  end

node_spec(color, scale, angle, txt) =
  "outer sep=0,inner sep=0,label={[scale=$scale,outer sep=0,inner sep=0,illustration,$color]$(tikz_deg_string(angle)):$(texify(txt))}"

arrow_spec(color, scale, left, right) =
  "illustration,"*(left ? "{Latex[scale=$scale]}" : "")*"-"*(right ? "{Latex[scale=$scale]}" : "")*","*color

KhepriBase.b_radii_illustration(b::TikZ, c, rs, rs_txts, mats, mat) =
  #= Shadow the outer center: withTikZXForm passes the local-frame anchor of the
     surrounding TikZ scope, so every coordinate below must be expressed relative
     to it (same convention as b_vectors_illustration). =#
  withTikZXForm(b, c, mat) do out, c
    for (r,r_txt,ϕ,mat) in zip(rs, rs_txts, division(π/6, 2π+π/6, length(rs), false), mats)
      color = tikz_color(material_color(mat))
      tikz_polar_segment(out, c, vpol(r, ϕ), arrow_spec(color, default_annotation_scale(), true, true))
      tikz_node(out, intermediate_loc(c, c + vpol(r, ϕ)), "", node_spec(color, default_annotation_scale(), ϕ+π/2, r_txt))
    end
  end

KhepriBase.b_vectors_illustration(b::TikZ, p, a, rs, rs_txts, mats, mat) =
  withTikZXForm(b, p, mat) do out, c
    for (r, r_txt, mat) in zip(rs, rs_txts, mats)
      color = tikz_color(material_color(mat))
      tikz_polar_segment(out, c, vpol(r, a), arrow_spec(color, default_annotation_scale(), true, true))
      tikz_node(out, intermediate_loc(c, c + vpol(r, a)), "", node_spec(color, default_annotation_scale(), a-π/2, r_txt))
    end
  end

KhepriBase.b_angles_illustration(b::TikZ, c, rs, ss, as, r_txts, s_txts, a_txts, mats, mat) =
  #= Shadow the outer center: withTikZXForm passes the local-frame anchor of the
     surrounding TikZ scope, so every coordinate below must be expressed relative
     to it (same convention as b_vectors_illustration). =#
  withTikZXForm(b, c, mat) do out, c
    let maxr = maximum(rs),
        n = length(rs),
        ars = division(0.2maxr, 0.7maxr, n, false),
        idxs = sortperm(as),
        (rs, ss, as, r_txts, s_txts, a_txts, mats) = (rs[idxs], ss[idxs], as[idxs], r_txts[idxs], s_txts[idxs], a_txts[idxs], mats[idxs])
      for (r, ar, s, a, r_txt, s_txt, a_txt, mat) in zip(rs, ars, ss, as, r_txts, s_txts, a_txts, mats)
        color = tikz_color(material_color(mat))
        tikz_params = "illustration,"*color
        if !(r ≈ 0.0)
          if !(s ≈ 0.0)
            tikz_polar_segment(out, c, vpol(ar, 0), tikz_params)
            tikz_maybe_arc(out, c, ar, 0, s, false, arrow_spec(color, default_annotation_scale(), false, true))
            tikz_node(out, c + vpol(ar, s/2), "", node_spec(color, default_annotation_scale(), s/2, s_txt))
          end
          if !(a ≈ 0.0)
            tikz_polar_segment(out, c, vpol(ar, s), tikz_params)
            tikz_polar_segment(out, c, vpol(r, s + a), arrow_spec(color, default_annotation_scale(), false, true))
            if (ar > r)
              tikz_polar_segment(out, c + vpol(r, s + a), vpol(ar-r, s + a), "dashed,$tikz_params")
            end
            (a > 0.0) ?
              tikz_maybe_arc(out, c, ar, s, a, false, arrow_spec(color, default_annotation_scale(), false, true)) :
              tikz_maybe_arc(out, c, ar, s, a, false, arrow_spec(color, default_annotation_scale(), true, false))
            tikz_node(out, c + vpol(ar, s + a/2), "", node_spec(color, default_annotation_scale(), s + a/2, a_txt))
          else
            tikz_polar_segment(out, c, vpol(maxr, a), arrow_spec(color, default_annotation_scale(), false, true))
          end
        end
        tikz_node(out, intermediate_loc(c, c + vpol(maxr, s + a)), "", node_spec(color, default_annotation_scale(), s + a - π/2, r_txt))
      end
    end
  end

KhepriBase.b_arcs_illustration(b::TikZ, c, rs, ss, as, r_txts, s_txts, a_txts, mats, mat) =
  #= Shadow the outer center: withTikZXForm passes the local-frame anchor of the
     surrounding TikZ scope, so every coordinate below must be expressed relative
     to it (same convention as b_vectors_illustration). =#
  withTikZXForm(b, c, mat) do out, c
    let maxr = maximum(rs),
        n = length(rs),
        ars = division(0.2maxr, 0.7maxr, n, false),
        idxs = sortperm(ss),
        (rs, ss, as, r_txts, s_txts, a_txts, mats) = (rs[idxs], ss[idxs], as[idxs], r_txts[idxs], s_txts[idxs], a_txts[idxs], mats[idxs])
      for (i, r, ar, s, a, r_txt, s_txt, a_txt, mat) in zip(1:n, rs, ars, ss, as, r_txts, s_txts, a_txts, mats)
        color = tikz_color(material_color(mat))
        tikz_params = "illustration,"*color
        if !(r ≈ 0.0)
          if !(s ≈ 0.0) && ((i == 1) || !(s ≈ ss[i-1] + as[i-1]))
            tikz_line(out, [c, c+vpol(ar, 0)], tikz_params)
            tikz_maybe_arc(out, c, ar, 0, s, false, arrow_spec(color, default_annotation_scale(), false, true))
            tikz_node(out, c + vpol(ar, s/2), "", node_spec(color, default_annotation_scale(), s/2, s_txt))
          end
          if !(a ≈ 0.0)
            #let ar = ((i == 1) || !(s ≈ ss[i-1] + as[i-1])) ? ar : ars[i-1]
            tikz_line(out, [c, c+vpol(r, s)], tikz_params)
            tikz_line(out, [c, c+vpol(r, s + a)], arrow_spec(color, default_annotation_scale(), false, true))
            tikz_maybe_arc(out, c, ar, s, a, false, arrow_spec(color, default_annotation_scale(), false, true))
            tikz_node(out, c + vpol(ar, s + a/2), "", node_spec(color, default_annotation_scale(), s + a/2, a_txt))
          end
          tikz_node(out, intermediate_loc(c, c + vpol(r, s + a)), "", node_spec(color, default_annotation_scale(), s + a - π/2, r_txt))
        end
      end
    end
  end

#
is_illustration(s) =
  is_labels(s) ||
  is_vectors_illustration(s) ||
  is_radii_illustration(s) ||
  is_angles_illustration(s) ||
  is_arcs_illustration(s)

sort_illustrations!(b::TikZ) =
  # WHERE IS PARTITION????
  let illustrations = filter(is_illustration, b.shapes),
      non_illustrations = filter(s->! is_illustration(s), b.shapes)
    b.shapes = KhepriBase.Proxy[non_illustrations..., illustrations...]
  end

# For extra non-portable stuff
export add_tikz
add_tikz(str) =
  println(connection(tikz), str)
###
# Dimensioning

#backend_dimension(b::TikZ, pa, pb, sep, scale, style) =
#  tikz_dimension(connection(b), pa, pb, )

#=openpdf()
      pdfname = makepdf(latex)
      if Sys.iswindows()
          command = `cmd /K start \"\" $pdfname`
          run(command)
      else
          run(`open $pdfname`)
      end
      pdfname
  end
=#

#=
To generate the actual TikZ code, we need two different things:
1. For existing LaTeX documents we want to "inject" just a tikzpicture.
2. For imediate viewing, we want to generate a standalone document and maybe convert it to SVG.
=#

gen_tex_document(b) =
  let out = connection(b)
    # Generate tikzpicture content to a temporary buffer so we know which shades are used
    empty!(b.used_shades)
    saved_io = b.io
    content_buf = IOBuffer()
    b.io = content_buf
    gen_tikz_picture(b)
    b.io = saved_io
    content = String(take!(content_buf))
    # Now write the full document with only the shades actually used
    println(out, raw"\documentclass{standalone}")
    println(out, raw"\usepackage{tikz,tikz-3dplot}")
    println(out, raw"\usetikzlibrary{perspective,patterns}")
    println(out, raw"\usetikzlibrary{calc,fadings,decorations.pathreplacing}")
    println(out, raw"\usetikzlibrary{shapes,fit}")
    println(out, raw"\usetikzlibrary{hobby}")
    println(out, raw"\usetikzlibrary{arrows.meta}")
    println(out, raw"\begin{document}")
    println(out, raw"\tikzset{illustration/.style={very thin}}")
    println(out, raw"\tikzset{dimension/.style={very thin,lightgray}}")
    for i in sort!(collect(b.used_shades))
      println(out, "\\definecolor{s$(i)}{gray}{$(round(i/100, digits=2))}")
    end
    print(out, content)
    println(out, raw"\end{document}")
  end

gen_tikz_picture(b::TikZ) =
  let out = connection(b), 
      v = b.view.target - b.view.camera,
      options = b.view.is_top_view ?
        "" :
        "3d view={$(rad2deg(sph_phi(v))-90)}{$(rad2deg(sph_psi(v))-90)}$(wireframe_picture_fill_option())"
    println(out, "\\begin{tikzpicture}[$options]")
    gen_tikz_commands(b)
    # Outline
    # println(out, "\\draw (current bounding box.north east)--(current bounding box.north west)--(current bounding box.south west)--(current bounding box.south east)--cycle;")
    println(out, "\\end{tikzpicture}")
  end

gen_tikz_commands(b::TikZ) =
  begin
    empty!(b.triangles)
    sort_illustrations!(b)
    realize_shapes(b)
    painter_sorter!(b.triangles, b.view.camera)
    for tri in b.triangles
      paint_trig(b, tri)
    end
  end

painter_sorter!(trigs, camera) =
  sort!(trigs, lt=(t2, t1)->distance(trig_center(t1[1:end-1]...), camera)<distance(trig_center(t2[1:end-1]...), camera))

# HACK THESE NEED TO BE FINISHED. They were used to help generate drawings for the book.
#=
tikz_output(options="", b=tikz) =
  gen_tikz_picture(b)


tikz_output_and_reset(options="") =
  let b = tikz,
      out = tikz_output(options)
    b_delete_all_shapes(b)
    b.view.lens = 0 # Reset the lens
    out
  end

tikz_set_view_top(out::IO, options) =
  let contents = String(take(out)),
      out = IOBuffer()
    println(out, "\\begin{tikzpicture}[$options]")
    print(out, contents)
    println(out, "\\end{tikzpicture}")
    String(take!(out))
  end
=#

#=
export visualize_tikz
visualize_tikz(name="Test") =
  with(render_kind_dir, "TikZ",
       render_ext, ".tex") do
    process_tikz(prepare_for_saving_file(render_pathname(name)))
    @info "Tex file: $(render_pathname(name))"
  end
=#

KhepriBase.b_render_pathname(::TikZ, name) =
  with(render_ext, ".pdf") do
    render_default_pathname(name)
  end

KhepriBase.b_render_and_save_view(b::TikZ, path) =
  let texpath = path_replace_suffix(path, ".tex"),
      prev_io = b.io
    open(texpath, "w") do out
      b.io = out
      try
        gen_tex_document(b)
      finally
        b.io = prev_io
      end
    end
    to_pdf(texpath)
    #to_dvi(texpath)
  end

# raw_view: .tex source output (skip PDF compilation) — exact text comparison
KhepriBase.b_raw_pathname(::TikZ, name) =
  with(render_ext, ".tex") do
    render_default_pathname(name)
  end

KhepriBase.b_raw_view(b::TikZ, path) =
  let prev_io = b.io
    open(path, "w") do out
      b.io = out
      try
        gen_tex_document(b)
      finally
        b.io = prev_io
      end
    end
    path
  end

export use_external_viewer
const use_external_viewer = Parameter(false)

to_pdf(texpath) =
  PDFFile(to_from(".pdf", texpath, "lualatex") do lualatex, path, pdfpath
    cd(dirname(path)) do
      let texname = basename(path),
          pdfname = path_replace_suffix(texname, ".pdf")
        @static if Sys.islinux()
          for i in 1:2
            run(`$lualatex -shell-escape -halt-on-error $texname`, wait=true)
          end
          run(`xdg-open $pdfname`)
        elseif Sys.isapple()
          error("Can't handle MacOS yet")
        elseif Sys.iswindows()
          let texify = Sys.which("texify")
            if isnothing(texify)
              error("Could not find texify. Do you have MikTeX installed?")
            else
              try
                run(pipeline(use_external_viewer() ?
                              `$(texify) --pdf --engine=luatex --run-viewer $(texname)` :
                              `$(texify) --pdf --engine=luatex $(texname)`,
                             devnull),
                    wait=true)
              catch e
                error("Could not process $texname to generate $pdfname.")
              end
            end
          end
        else
          error("Unknown operating system")
        end
      end
    end
  end)

to_dvi(texpath) =
  DVIFile(to_from(".dvi", texpath, "lualatex") do lualatex, path, dvipath
    cd(dirname(path)) do
      let texname = basename(path)
        @static if Sys.islinux()
          for i in 1:2
            run(`$lualatex -shell-escape -halt-on-error --output-format=dvi $texname`, wait=true)
          end
        elseif Sys.isapple()
          error("Can't handle MacOS yet")
        elseif Sys.iswindows()
          run(pipeline(`$(lualatex) --output-format=dvi $(texname)`, devnull), wait=true)
        else
          error("Unknown operating system")
        end
      end
    end
  end)

#=
  let pathname = abspath(repr(b)*"-"*Dates.format(now(), dateformat"Y-m-d-H-M-S-s")*".svg")
    write(io, read(b_save_view(b, mime, pathname)))
  end

b_save_view(b::Backend, mime::MIME"image/svg+xml", name) =

=#

export svg

# ============================================================
# Number and coordinate formatting
# ============================================================

svg_number(x::Real) =
  isinteger(x) ?
    string(Int(x)) :
    (abs(x) < 0.001 ?
      "0" :
      let s = string(round(x * 1000.0) / 1000.0)
        # strip trailing zeros after decimal point
        contains(s, '.') ? rstrip(rstrip(s, '0'), '.') : s
      end)

svg_coord(c) =
  let c = in_world(c)
    (c.x, -c.y)
  end

svg_coord_string(c) =
  let (x, y) = svg_coord(c)
    "$(svg_number(x)),$(svg_number(y))"
  end

svg_points_string(ps) =
  join([svg_coord_string(p) for p in ps], " ")

# XML attribute escaping
svg_escape(s::AbstractString) =
  replace(replace(replace(replace(replace(s,
    "&" => "&amp;"),
    "<" => "&lt;"),
    ">" => "&gt;"),
    "\"" => "&quot;"),
    "'" => "&apos;")

# ============================================================
# Color and material system
# ============================================================

svg_rgb(c) =
  "rgb($(round(Int, c.r * 255)),$(round(Int, c.g * 255)),$(round(Int, c.b * 255)))"

# Material color value: bare CSS color, no property prefix.
# svg_style applies it as fill: or stroke: depending on context.
svg_color_value(c) =
  c.alpha ≈ 1.0 ? svg_rgb(c) : "$(svg_rgb(c));opacity:$(svg_number(c.alpha))"

# Pre-formatted fill/stroke strings for annotation functions
svg_fill_color(c) =
  c.alpha ≈ 1.0 ? "fill:$(svg_rgb(c))" : "fill:$(svg_rgb(c));fill-opacity:$(svg_number(c.alpha))"

svg_stroke_color(c) =
  c.alpha ≈ 1.0 ? "stroke:$(svg_rgb(c))" : "stroke:$(svg_rgb(c));stroke-opacity:$(svg_number(c.alpha))"

# Build a style string for a shape.
# mat is either void (Integer/nothing/""), a bare color value from b_material
# (e.g. "rgb(255,0,0)"), or an explicit CSS property string from annotations
# (e.g. "stroke:rgb(0,0,0);stroke-width:0.2").
svg_style(mat, filled) =
  if mat isa Integer || isnothing(mat) || mat == ""
    filled ? "fill:rgb(0,0,0);stroke:none" : "fill:none;stroke:rgb(0,0,0)"
  elseif startswith(mat, "fill:") || startswith(mat, "stroke:") || startswith(mat, "stroke-")
    # Already a CSS property string -- pass through, ensuring fill/stroke defaults
    filled ? "$(mat);stroke:none" : "fill:none;$(mat)"
  else
    # Bare color value from b_material -- apply as fill or stroke
    filled ? "fill:$(mat);stroke:none" : "fill:none;stroke:$(mat)"
  end

# Emit style= attribute, or nothing if empty
svg_style_attr(mat, filled) =
  let s = svg_style(mat, filled)
    isempty(s) ? "" : " style=\"$s\""
  end

# ============================================================
# Backend declaration
# ============================================================

@defbackend SVG SVG begin
  id_type = Any
  void_ref = -1
  view_type = FrontendView()
  parent = LocalBackend
  mixin(local_shapes)
  mixin(render_state)
  mixin(io)
  view::View = top_view()
  triangles::Vector{Any} = Any[]
  #= Per-color/scale arrow-marker registry.
     SVG <marker> elements have a fixed fill, so each (kind, color, scale)
     triple needs its own marker definition. We accumulate the set of
     markers actually used while shapes are realized, then emit them under
     <defs> in gen_svg_document. Keeping it on the backend (not a global)
     means concurrent SVG instances do not clobber each other's defs.
     See also: register_arrow!, emit_arrow_markers. =#
  arrow_markers::Dict{Tuple{Symbol,String,Float64},String} =
    Dict{Tuple{Symbol,String,Float64},String}()
end

const svg = SVG(view=top_view())

# ============================================================
# Material handling
# ============================================================

export svg_option
svg_option(str) = material(str, SVG=>str)

#= Pre-set thicknesses, calibrated to look like TikZ's `very thin`,
   `thin`, `thick`, `very thick` (0.2, 0.4, 0.8, 1.2 pt) at typical
   render sizes. We pin them to pixel-space with
   `vector-effect:non-scaling-stroke` so a 1-pixel stroke stays
   1-pixel regardless of how zoomed the drawing's viewBox is —
   matching TikZ's behaviour, where `pt` units are absolute.

   See also: _illustration_stroke_css. =#
export very_thin, thin, thick, very_thick
very_thin  = svg_option("stroke-width:0.5;vector-effect:non-scaling-stroke")
thin       = svg_option("stroke-width:1;vector-effect:non-scaling-stroke")
thick      = svg_option("stroke-width:2;vector-effect:non-scaling-stroke")
very_thick = svg_option("stroke-width:3;vector-effect:non-scaling-stroke")

#= Arrow-direction options.

   These are surfaced both as the TikZ-style spellings (`<->`, `->`, `<-`)
   and the LaTeX-arrow names (`latex_latex`, `_latex`, `latex_`) so user
   code that targets either backend reads the same. They are encoded as
   CSS custom properties so they ride through `merge_backend_materials`
   and survive composition with stroke-width / color materials.

   See also: parse_arrow_props, register_arrow!. =#
export var"<->", var"->", var"<-", latex_latex, _latex, latex_
var"<->" = svg_option("--arrow-start:1;--arrow-end:1")
var"->"  = svg_option("--arrow-end:1")
var"<-"  = svg_option("--arrow-start:1")
latex_latex = var"<->"
_latex      = var"->"
latex_      = var"<-"

# Sentinel light-gray color used for dimension lines / text — matches
# TikZ's `dimension/.style={very thin,lightgray}`.
const _dim_color = "rgb(211,211,211)"

#= Default annotation-marker scale. TikZ uses `Latex[scale=...]` with
   `default_annotation_scale()`; we mirror that. The numeric default also
   sets the visual size of the arrow head: 0.4 user units long (roughly
   4mm in cm-scaled drawings) at scale=1.0. See emit_arrow_markers. =#
default_svg_arrow_size() = 0.4 * default_annotation_scale()

#= Strip arrow directives (`--arrow-start:N`, `--arrow-end:N`) out of a CSS
   material string, returning `(arrow_start, arrow_end, scale, css)`. The
   numeric value of the directive (e.g. `1.5`) is interpreted as a marker
   scale multiplier — matching TikZ's `Latex[scale=...]`. Non-arrow
   segments are preserved verbatim and rejoined by `;`.

   Empty / Integer / nothing inputs return `(false, false, 1.0, "")`. =#
parse_arrow_props(mat) =
  let arrow_start = false, arrow_end = false, scale = 1.0,
      remaining = String[]
    if mat isa AbstractString
      for seg in split(mat, ";")
        seg = strip(seg)
        isempty(seg) && continue
        if startswith(seg, "--arrow-start")
          arrow_start = true
          if contains(seg, ":")
            let v = strip(split(seg, ":"; limit=2)[2])
              isempty(v) || (scale = something(tryparse(Float64, v), scale))
            end
          end
        elseif startswith(seg, "--arrow-end")
          arrow_end = true
          if contains(seg, ":")
            let v = strip(split(seg, ":"; limit=2)[2])
              isempty(v) || (scale = something(tryparse(Float64, v), scale))
            end
          end
        else
          push!(remaining, String(seg))
        end
      end
    end
    (arrow_start, arrow_end, scale, join(remaining, ";"))
  end

#= Read the stroke color out of a CSS string. Falls back to bare-color form
   (a segment without `:`, the convention used by `b_material`) before
   defaulting to black. The result is what arrow-marker fills inherit, so
   getting this right keeps line and arrow head visually unified. =#
extract_stroke_color(css::AbstractString) =
  let bare = ""
    for seg in split(css, ";")
      seg = strip(seg)
      isempty(seg) && continue
      if !contains(seg, ":")
        bare = String(seg)
      else
        (k, v) = split(seg, ":"; limit=2)
        strip(k) == "stroke" && return String(strip(v))
      end
    end
    isempty(bare) ? "rgb(0,0,0)" : bare
  end
extract_stroke_color(_) = "rgb(0,0,0)"

#= Register an arrow marker for `(kind, color, scale)`, returning its DOM
   id. Stable across calls within one document so the same triple yields
   the same id (and is emitted only once under <defs>). =#
register_arrow!(b::SVG, kind::Symbol, color::AbstractString, scale::Real=1.0) =
  let key = (kind, String(color), Float64(scale))
    get!(b.arrow_markers, key) do
      "ah-$(kind)-$(length(b.arrow_markers))"
    end
  end

#= Build `marker-start`/`marker-end` XML attributes for a stroke. `b` is
   needed so we can register the markers used; returns "" when no arrows
   are requested. =#
marker_attrs(b::SVG, arrow_start::Bool, arrow_end::Bool, scale::Real, color::AbstractString) =
  let parts = String[]
    arrow_start && push!(parts, " marker-start=\"url(#$(register_arrow!(b, :start, color, scale)))\"")
    arrow_end   && push!(parts, " marker-end=\"url(#$(register_arrow!(b, :end, color, scale)))\"")
    join(parts)
  end

KhepriBase.merge_backend_materials(b::SVG, m1::String, m2::String) =
  let props1 = Dict(split(p, ":"; limit=2) for p in split(m1, ";") if contains(p, ":")),
      props2 = Dict(split(p, ":"; limit=2) for p in split(m2, ";") if contains(p, ":"))
    join(["$k:$v" for (k, v) in merge(props1, props2)], ";")
  end

KhepriBase.b_get_material(b::SVG, layer, spec) =
  let c = layer.color
    c == rgba(1,1,1,1) ?
      void_ref(b) :
      svg_color_value(c)
  end

KhepriBase.b_get_material(b::SVG, spec::Nothing) = void_ref(b)

KhepriBase.b_material(b::SVG, name, base_color) =
  svg_color_value(base_color)

KhepriBase.after_connecting(b::SVG) =
  set_material()

# ============================================================
# SVG shape emitters
# ============================================================

svg_point(out::IO, c, mat) =
  let (x, y) = svg_coord(c)
    println(out, "<circle cx=\"$(svg_number(x))\" cy=\"$(svg_number(y))\" r=\"0.03\"$(svg_style_attr(mat, true))/>")
  end

svg_line(out::IO, ps, mat) =
  println(out, "<polyline points=\"$(svg_points_string(ps))\"$(svg_style_attr(mat, false))/>")

svg_closed_line(out::IO, ps, filled, mat) =
  println(out, "<polygon points=\"$(svg_points_string(ps))\"$(svg_style_attr(mat, filled))/>")

svg_circle(out::IO, c, r, filled, mat) =
  let (x, y) = svg_coord(c)
    println(out, "<circle cx=\"$(svg_number(x))\" cy=\"$(svg_number(y))\" r=\"$(svg_number(r))\"$(svg_style_attr(mat, filled))/>")
  end

svg_arc(out::IO, c, r, ai, da, filled, mat) =
  if iszero(r) || iszero(da)
    svg_point(out, iszero(da) && !iszero(r) ? c + vpol(r, ai) : c, mat)
  else
    let (cx, cy) = svg_coord(c),
        # Start and end points in world coords, then SVG coords
        sp = c + vpol(r, ai),
        ep = c + vpol(r, ai + da),
        (sx, sy) = svg_coord(sp),
        (ex, ey) = svg_coord(ep),
        large_arc = abs(da) > pi ? 1 : 0,
        # Y-negation inverts sweep direction
        sweep = da > 0 ? 0 : 1
      if filled
        println(out, "<path d=\"M $(svg_number(cx)),$(svg_number(cy)) L $(svg_number(sx)),$(svg_number(sy)) A $(svg_number(r)),$(svg_number(r)) 0 $large_arc,$sweep $(svg_number(ex)),$(svg_number(ey)) Z\"$(svg_style_attr(mat, true))/>")
      else
        println(out, "<path d=\"M $(svg_number(sx)),$(svg_number(sy)) A $(svg_number(r)),$(svg_number(r)) 0 $large_arc,$sweep $(svg_number(ex)),$(svg_number(ey))\"$(svg_style_attr(mat, false))/>")
      end
    end
  end

svg_rectangle(out::IO, c, dx, dy, filled, mat) =
  let (x, y) = svg_coord(c),
      # In SVG Y-down: rectangle goes from (x, y-dy) with height dy
      ry = y - dy
    println(out, "<rect x=\"$(svg_number(x))\" y=\"$(svg_number(ry))\" width=\"$(svg_number(dx))\" height=\"$(svg_number(dy))\"$(svg_style_attr(mat, filled))/>")
  end

# ============================================================
# Splines: Catmull-Rom → cubic Bezier
# ============================================================

# Convert Catmull-Rom control points to cubic Bezier path data
# For segment P[i]→P[i+1], control points are:
#   CP1 = P[i] + (P[i+1] - P[i-1]) / 6
#   CP2 = P[i+1] - (P[i+2] - P[i]) / 6
svg_spline(out::IO, ps, closed, mat) =
  let n = length(ps)
    n < 2 && return
    if n == 2
      svg_line(out, ps, mat)
      return
    end
    parts = String[]
    push!(parts, let (x, y) = svg_coord(ps[1]); "M $(svg_number(x)),$(svg_number(y))" end)
    for i in 1:n-1
      let p_prev = i == 1 ? (closed ? ps[n] : ps[1]) : ps[i-1],
          p_curr = ps[i],
          p_next = ps[i+1],
          p_next2 = i == n-1 ? (closed ? ps[1] : ps[n]) : ps[i+2],
          # Tangent-based control points
          pw = in_world(p_prev), cw = in_world(p_curr), nw = in_world(p_next), n2w = in_world(p_next2),
          cp1x = cw.x + (nw.x - pw.x) / 6.0,
          cp1y = -(cw.y + (nw.y - pw.y) / 6.0),
          cp2x = nw.x - (n2w.x - cw.x) / 6.0,
          cp2y = -(nw.y - (n2w.y - cw.y) / 6.0),
          (ex, ey) = svg_coord(p_next)
        push!(parts, "C $(svg_number(cp1x)),$(svg_number(cp1y)) $(svg_number(cp2x)),$(svg_number(cp2y)) $(svg_number(ex)),$(svg_number(ey))")
      end
    end
    if closed
      # Add closing segment from last point back to first
      let p_prev = ps[n-1],
          p_curr = ps[n],
          p_next = ps[1],
          p_next2 = ps[2],
          pw = in_world(p_prev), cw = in_world(p_curr), nw = in_world(p_next), n2w = in_world(p_next2),
          cp1x = cw.x + (nw.x - pw.x) / 6.0,
          cp1y = -(cw.y + (nw.y - pw.y) / 6.0),
          cp2x = nw.x - (n2w.x - cw.x) / 6.0,
          cp2y = -(nw.y - (n2w.y - cw.y) / 6.0),
          (ex, ey) = svg_coord(p_next)
        push!(parts, "C $(svg_number(cp1x)),$(svg_number(cp1y)) $(svg_number(cp2x)),$(svg_number(cp2y)) $(svg_number(ex)),$(svg_number(ey))")
      end
      push!(parts, "Z")
    end
    println(out, "<path d=\"$(join(parts, " "))\"$(svg_style_attr(mat, closed))/>")
  end

# Hermite spline with endpoint tangent vectors → cubic Bezier
svg_hermite_spline(out::IO, ps, v0, v1, mat) =
  let n = length(ps)
    n < 2 && return
    if n == 2
      # Single cubic Bezier segment with Hermite tangents
      let (sx, sy) = svg_coord(ps[1]),
          (ex, ey) = svg_coord(ps[2]),
          v0w = in_world(v0), v1w = in_world(v1),
          p0w = in_world(ps[1]), p1w = in_world(ps[2]),
          cp1x = p0w.x + v0w.x / 3.0,
          cp1y = -(p0w.y + v0w.y / 3.0),
          cp2x = p1w.x - v1w.x / 3.0,
          cp2y = -(p1w.y - v1w.y / 3.0)
        println(out, "<path d=\"M $(svg_number(sx)),$(svg_number(sy)) C $(svg_number(cp1x)),$(svg_number(cp1y)) $(svg_number(cp2x)),$(svg_number(cp2y)) $(svg_number(ex)),$(svg_number(ey))\"$(svg_style_attr(mat, false))/>")
      end
    else
      # Use Catmull-Rom for interior, override first/last tangents
      parts = String[]
      push!(parts, let (x, y) = svg_coord(ps[1]); "M $(svg_number(x)),$(svg_number(y))" end)
      for i in 1:n-1
        let p_curr = ps[i],
            p_next = ps[i+1],
            cw = in_world(p_curr), nw = in_world(p_next),
            # First segment: use v0 as tangent at start
            # Last segment: use v1 as tangent at end
            # Interior: Catmull-Rom
            t0 = if i == 1
                   in_world(v0)
                 else
                   let pw = in_world(ps[i-1])
                     vxyz(nw.x - pw.x, nw.y - pw.y, nw.z - pw.z)
                   end
                 end,
            t1 = if i == n-1
                   in_world(v1)
                 else
                   let n2w = in_world(ps[i+2])
                     vxyz(n2w.x - cw.x, n2w.y - cw.y, n2w.z - cw.z)
                   end
                 end,
            cp1x = cw.x + t0.x / 6.0,
            cp1y = -(cw.y + t0.y / 6.0),
            cp2x = nw.x - t1.x / 6.0,
            cp2y = -(nw.y - t1.y / 6.0),
            (ex, ey) = svg_coord(p_next)
          push!(parts, "C $(svg_number(cp1x)),$(svg_number(cp1y)) $(svg_number(cp2x)),$(svg_number(cp2y)) $(svg_number(ex)),$(svg_number(ey))")
        end
      end
      println(out, "<path d=\"$(join(parts, " "))\"$(svg_style_attr(mat, false))/>")
    end
  end

# ============================================================
# Text
# ============================================================

#= Stack of font-family fallbacks, mirroring TikZ's `\fontfamily{phv}`
   (Helvetica). Listing two real names plus `sans-serif` covers macOS
   (Helvetica), most Windows / Linux installs (Arial), and the generic
   fallback so headless renderers still pick a metrically-similar face. =#
const _font_family = "Helvetica,Arial,sans-serif"

#= Cap-height conversion factor. TikZ achieves "size = h cm cap height"
   with `xscale=3.7*h` on the default 10pt font. SVG `font-size` is the
   em-size, and Helvetica/Arial cap-height is ≈ 0.71 of em-size, so to
   produce a cap-height of `h` user units we set `font-size = h / 0.71`
   ≈ `h * 1.4`. This keeps annotated drawings visually comparable across
   the two backends without forcing the caller to know about font
   metrics. Override with an explicit `font-size:` in the material if a
   different convention is desired. =#
const _cap_to_em = 1.4

#= TikZ-equivalent label/text anchoring. TikZ's `anchor=base west` puts
   the baseline-left corner of the glyph box at the coordinate; the SVG
   defaults (`text-anchor=start`, `dominant-baseline=alphabetic`) are
   already that, so we don't need explicit attributes for the default
   case. We DO emit them when an angle-based label override is in play,
   so that pre-existing `style=` material strings cannot drift the anchor
   away from what the caller asked for. =#
svg_text(out::IO, str, c, size, mat) =
  let (x, y) = svg_coord(c),
      style_parts = String["font-family:$(_font_family)",
                           "font-size:$(svg_number(size * _cap_to_em))"]
    if !(mat isa Integer) && !isnothing(mat) && mat != ""
      push!(style_parts, mat)
    end
    println(out, "<text x=\"$(svg_number(x))\" y=\"$(svg_number(y))\" style=\"$(join(style_parts, ";"))\">$(svg_escape(string(str)))</text>")
  end

#= Map a label angle (radians, measured CCW from +x in the DATA frame)
   to SVG (text-anchor, dominant-baseline) attributes. TikZ's
   `label={ANGLE:TEXT}` places the text on the side of the anchor
   pointed at by ANGLE; we want SVG's anchor/baseline to put the text
   box "outside" the anchor in the same direction.

   Decision is made on the components (cosϕ, sinϕ) so the diagonal
   quadrants (e.g. -45° → bottom-right) all collapse to (start,
   hanging) without enumerating cases. The 0.3 tolerance widens the
   cardinal axes (where one component is 0) just enough that "almost
   horizontal" still picks `middle` baseline rather than wobbling
   between `auto`/`hanging`.

   Note: svg_coord negates y, so "above in data" (sin ϕ > 0) becomes
   "smaller y in SVG", which is exactly where `dominant-baseline=auto`
   (the alphabetic baseline) places ascending glyphs. =#
svg_anchor_for_angle(ϕ::Real) =
  let cosa = cos(ϕ), sina = sin(ϕ),
      tol = 0.3
    horiz = cosa >  tol ? "start" :
            cosa < -tol ? "end"   :
            "middle"
    vert  = sina >  tol ? "auto"    :
            sina < -tol ? "hanging" :
            "middle"
    (horiz, vert)
  end

#= Place a label at angle `ϕ` from anchor `p`, mimicking TikZ's
   `node[label={[scale=s,...]ϕ:txt}]`. The text is offset away from `p`
   by a small distance proportional to `scale` so it does not overlap
   geometry, and anchored so the side facing `p` aligns with `p`.

   See also: svg_anchor_for_angle. =#
const _label_offset_factor = 0.15  # user units per (size*scale)

svg_label_at_angle(out::IO, p, ϕ::Real, txt, scale::Real, color_css::AbstractString="") =
  let size = 0.3 * scale,                              # default illustration size
      offset = (0.3 + _label_offset_factor) * scale,
      anchor_p = p + vpol(offset, ϕ),
      (x, y) = svg_coord(anchor_p),
      (ha, va) = svg_anchor_for_angle(ϕ),
      parts = String["font-family:$(_font_family)",
                     "font-size:$(svg_number(size * _cap_to_em))"]
    isempty(color_css) || push!(parts, color_css)
    println(out,
      "<text x=\"$(svg_number(x))\" y=\"$(svg_number(y))\" ",
      "text-anchor=\"$ha\" dominant-baseline=\"$va\" ",
      "style=\"$(join(parts, ";"))\">$(svg_escape(string(txt)))</text>")
  end

# ============================================================
# Dimension lines and annotations
# ============================================================

#= Stroke style for illustration / dimension lines. TikZ's
   `illustration/.style={very thin}` and `dimension/.style={very thin,
   lightgray}` put a fixed-pt thickness on the line regardless of the
   drawing's zoom. SVG's stroke-width scales with the viewBox by
   default, which is why a stroke-width of 0.2 in a 10-unit viewBox
   renders dramatically thicker than the same line in a 100-unit
   viewBox. We pin the stroke to user-output pixel space with
   `vector-effect="non-scaling-stroke"` and pick a small absolute
   pixel width (`1.5`), which produces visually-consistent thin lines
   no matter what the user's drawing extent ends up being.

   See also: _illustration_stroke_css, _dim_stroke_css. =#
const _stroke_pixels = 1.5

#= Stroke fragment used by every illustration / dim emitter — colour is
   parameterised so callers can request a specific hue. =#
_illustration_stroke_css(color::AbstractString) =
  "stroke:$color;stroke-width:$(_stroke_pixels);vector-effect:non-scaling-stroke"

#= Dimension line with light-gray styling and double-headed arrow.
   Mirrors TikZ's `\draw[dimension,latex-latex] p--q node[...]{txt}`.
   The label sits very near the `q` end (`very near end=0.95` in TikZ);
   we anchor it slightly past the line end and use the line's own
   direction to pick `text-anchor`/`dominant-baseline`, so the label
   pivots around the line endpoint rather than overlapping it. =#
svg_dim_line(b::SVG, p, q, str) =
  let out = connection(b),
      (px, py) = svg_coord(p),
      (qx, qy) = svg_coord(q),
      ms = register_arrow!(b, :start, _dim_color),
      me = register_arrow!(b, :end, _dim_color),
      # Label angle in the data frame (pol_phi works on a vector)
      v = q - p,
      ϕ = pol_phi(v),
      label_anchor = intermediate_loc(p, q, 0.95)
    println(out, "<line x1=\"$(svg_number(px))\" y1=\"$(svg_number(py))\" x2=\"$(svg_number(qx))\" y2=\"$(svg_number(qy))\" style=\"$(_illustration_stroke_css(_dim_color))\" marker-start=\"url(#$ms)\" marker-end=\"url(#$me)\"/>")
    svg_label_at_angle(out, label_anchor, ϕ + π/2, str, default_annotation_scale(),
                       "fill:$(_dim_color)")
  end

#= IO-level polar-segment emitter — keeps backwards compatibility with
   tests that import `svg_polar_segment(io, p, v, mat)`. Use the
   `b::SVG` overload below when arrow markers are needed. =#
svg_polar_segment(out::IO, p, v, mat) =
  let ep = p + v,
      (px, py) = svg_coord(p),
      (ex, ey) = svg_coord(ep)
    println(out, "<line x1=\"$(svg_number(px))\" y1=\"$(svg_number(py))\" x2=\"$(svg_number(ex))\" y2=\"$(svg_number(ey))\"$(svg_style_attr(mat, false))/>")
  end

#= Backend-aware polar segment that honours arrow directives in `mat`.
   Strips `--arrow-start`/`--arrow-end` props, registers the requested
   markers in the colour given by `mat`'s stroke, and emits the line
   with the right `marker-*` attributes. =#
svg_polar_segment(b::SVG, p, v, mat) =
  let out = connection(b),
      ep = p + v,
      (px, py) = svg_coord(p),
      (ex, ey) = svg_coord(ep),
      (as, ae, scale, css) = parse_arrow_props(mat),
      color = extract_stroke_color(css),
      attrs = marker_attrs(b, as, ae, scale, color)
    println(out, "<line x1=\"$(svg_number(px))\" y1=\"$(svg_number(py))\" x2=\"$(svg_number(ex))\" y2=\"$(svg_number(ey))\"$(svg_style_attr(css, false))$attrs/>")
  end

#= Backend-aware straight line that honours arrow directives — the
   illustration code uses this for radial / extension segments. =#
svg_arrow_line(b::SVG, ps, mat) =
  let out = connection(b),
      (as, ae, scale, css) = parse_arrow_props(mat),
      color = extract_stroke_color(css),
      attrs = marker_attrs(b, as, ae, scale, color)
    println(out, "<polyline points=\"$(svg_points_string(ps))\"$(svg_style_attr(css, false))$attrs/>")
  end

#= Backend-aware arc that honours arrow directives. SVG `marker-end`
   on an arc places the marker at the arc's end-point, oriented along
   the arc tangent — matching TikZ's `(c)arc(α:β:r)` with `-{Latex}`. =#
svg_arrow_arc(b::SVG, c, r, ai, da, mat) =
  let out = connection(b),
      (as, ae, scale, css) = parse_arrow_props(mat),
      color = extract_stroke_color(css),
      attrs = marker_attrs(b, as, ae, scale, color)
    if iszero(r) || iszero(da)
      svg_point(out, iszero(da) && !iszero(r) ? c + vpol(r, ai) : c, css)
    else
      let sp = c + vpol(r, ai),
          ep = c + vpol(r, ai + da),
          (sx, sy) = svg_coord(sp),
          (ex, ey) = svg_coord(ep),
          large_arc = abs(da) > π ? 1 : 0,
          sweep = da > 0 ? 0 : 1
        println(out, "<path d=\"M $(svg_number(sx)),$(svg_number(sy)) A $(svg_number(r)),$(svg_number(r)) 0 $large_arc,$sweep $(svg_number(ex)),$(svg_number(ey))\"$(svg_style_attr(css, false))$attrs/>")
      end
    end
  end

#= Generic centred text used inside illustration helpers. Kept distinct
   from `svg_text` (which is `b_text`'s emitter) because illustration
   labels in the existing TikZ output are ALWAYS positioned via TikZ's
   `label={ANGLE:TEXT}` mechanism — never at the bare anchor — so we
   only use this when callers truly want a centred glyph (e.g.
   intermediate label of a vector). =#
svg_node(out::IO, p, txt, mat) =
  let (x, y) = svg_coord(p),
      style_parts = String["font-family:$(_font_family)",
                           "font-size:$(svg_number(0.3 * _cap_to_em))"]
    if !(mat isa Integer) && !isnothing(mat) && mat != ""
      push!(style_parts, mat)
    end
    println(out, "<text x=\"$(svg_number(x))\" y=\"$(svg_number(y))\" text-anchor=\"middle\" dominant-baseline=\"central\" style=\"$(join(style_parts, ";"))\">$(svg_escape(string(txt)))</text>")
  end

# ============================================================
# Coordinate transform wrapper
# ============================================================

withSVGXForm(f, b, c, mat) =
  let out = connection(b),
      mat = mat isa Integer ? nothing : mat
    if b.view.is_top_view
      if is_world_cs(c.cs)
        # World CS: inner emitters apply mat via svg_style, no wrapper needed
        f(out, c)
      else
        # Non-world CS: apply coordinate system transform
        let m = c.cs.transform,
            t = in_world(c),
            a = m[1,1], b_val = m[2,1], c_val = m[1,2], d = m[2,2],
            tx = t.x, ty = -t.y
          # SVG matrix with Y-negation folded in
          println(out, "<g transform=\"matrix($(svg_number(a)),$(svg_number(-b_val)),$(svg_number(-c_val)),$(svg_number(d)),$(svg_number(tx)),$(svg_number(ty)))\">")
          f(out, u0(world_cs))
          println(out, "</g>")
        end
      end
    else
      # Non-top view: for now, treat as top view (3D deferred)
      f(out, c)
    end
  end

# ============================================================
# Backend operations
# ============================================================

KhepriBase.b_point(b::SVG, p, mat) =
  svg_point(connection(b), p, mat)

#= b_line forwards to the arrow-aware emitter so that user-attached
   arrow materials (`<->`, `->`, `<-`) on a plain `line(...)` show up
   in the SVG. When `mat` carries no arrow directives this is
   equivalent to the bare `svg_line(out, ps, mat)` path. =#
KhepriBase.b_line(b::SVG, ps, mat) =
  svg_arrow_line(b, ps, mat)

KhepriBase.b_polygon(b::SVG, ps, mat) =
  svg_closed_line(connection(b), ps, false, mat)

KhepriBase.b_spline(b::SVG, ps, v0, v1, mat) =
  if (v0 == false) && (v1 == false)
    svg_spline(connection(b), ps, false, mat)
  else
    let v0 = v0 == false ? ps[2] - ps[1] : v0,
        v1 = v1 == false ? ps[end-1] - ps[end] : v1
      svg_hermite_spline(connection(b), ps, v0, v1, mat)
    end
  end

KhepriBase.b_closed_spline(b::SVG, ps, mat) =
  svg_spline(connection(b), ps, true, mat)

KhepriBase.b_circle(b::SVG, c, r, mat) =
  withSVGXForm(b, c, mat) do out, cc
    svg_circle(out, cc, r, false, mat)
  end

KhepriBase.b_arc(b::SVG, c, r, α, Δα, mat) =
  withSVGXForm(b, c, mat) do out, cc
    svg_arc(out, cc, r, α, Δα, false, mat)
  end

KhepriBase.b_rectangle(b::SVG, c, dx, dy, mat) =
  withSVGXForm(b, c, mat) do out, cc
    svg_rectangle(out, cc, dx, dy, false, mat)
  end

KhepriBase.b_surface_polygon(b::SVG, ps, mat) =
  svg_closed_line(connection(b), ps, true, mat)

KhepriBase.b_surface_circle(b::SVG, c, r, mat) =
  withSVGXForm(b, c, mat) do out, cc
    svg_circle(out, cc, r, true, mat)
  end

KhepriBase.b_surface_arc(b::SVG, c, r, α, Δα, mat) =
  withSVGXForm(b, c, mat) do out, cc
    svg_arc(out, cc, r, α, Δα, true, mat)
  end

KhepriBase.b_surface_rectangle(b::SVG, c, dx, dy, mat) =
  withSVGXForm(b, c, mat) do out, cc
    svg_rectangle(out, cc, dx, dy, true, mat)
  end

# Store triangles for painter's algorithm (3D, Phase 3)
KhepriBase.b_trig(b::SVG, p1, p2, p3, mat) =
  begin
    push!(b.triangles, (p1, p2, p3, mat))
    nothing
  end

KhepriBase.b_text(b::SVG, str, p, size, mat) =
  withSVGXForm(b, p, mat) do out, cc
    svg_text(out, str, cc, size, mat)
  end

KhepriBase.b_dim_line(b::SVG, p, q, tv, str, size, outside, mat) =
  svg_dim_line(b, p, q, str)

KhepriBase.b_ext_line(b::SVG, p, q, mat) =
  let (px, py) = svg_coord(p),
      (qx, qy) = svg_coord(q)
    # Use illustration-style stroke (very thin, like TikZ's
    # `illustration/.style={very thin}`) to match dim-line ext lines
    println(connection(b), "<line x1=\"$(svg_number(px))\" y1=\"$(svg_number(py))\" x2=\"$(svg_number(qx))\" y2=\"$(svg_number(qy))\" style=\"$(_illustration_stroke_css("rgb(0,0,0)"))\"/>")
  end

#= Arc dimension — TikZ uses `tikz_dim_arc` which draws:
     1. Short radial reference at (c → c+vpol(r*f, α))
     2. Full radial with arrow at (c → c+vpol(r, α+Δα)), bidirectional
     3. Curved arrow on the inner arc, bidirectional
     4. Label at midpoint of full radial (radius value)
     5. Label at midpoint of arc (amplitude value)

   We mirror that semantics here, using dimension-grey + arrows. =#
KhepriBase.b_arc_dimension(b::SVG, c, r, α, Δα, rstr, Δstr, size, offset, mat) =
  Δα ≈ 0.0 || r ≈ 0.0 ?
    nothing :
    withSVGXForm(b, c, mat) do out, cc
      #= Inner-arc fraction `f` controls how far along the radius the
         labelled arc is drawn. 0.35 mirrors the TikZ default range
         (0.2..0.5); a constant keeps golden output deterministic. =#
      let f = 0.35,
          dim_css = _illustration_stroke_css(_dim_color),
          arrow_css = "$(dim_css);--arrow-start:$(default_annotation_scale());--arrow-end:$(default_annotation_scale())",
          dim_fill = "fill:$(_dim_color)"
        # Short reference radius
        svg_line(out, [cc, cc + vpol(r * f, α)], dim_css)
        # Full radius with arrows on both ends — gives the radius dimension
        svg_arrow_line(b, [cc, cc + vpol(r, α + Δα)], arrow_css)
        # Inner arc with bidirectional arrows — gives the angle dimension
        svg_arrow_arc(b, cc, r * f, α, Δα, arrow_css)
        # Labels: the radius along the long radial, the amplitude near the inner arc
        svg_label_at_angle(out, intermediate_loc(cc, cc + vpol(r, α + Δα)),
                           α + Δα + π/2, rstr, default_annotation_scale(), dim_fill)
        svg_label_at_angle(out, cc + vpol(r * f, α + Δα/2),
                           α + Δα/2, Δstr, default_annotation_scale(), dim_fill)
      end
    end

# ============================================================
# Bounding-box contribution for annotations
# ============================================================

#= Annotations (vectors_illustration / radii_illustration / etc.) carry
   geometric positions that the user clearly wants visible — yet
   `shapes_bbox` doesn't see them, because `shape_locs(::Annotation)`
   defaults to `Loc[]`. The result is an SVG viewBox that crops out
   the very labels we just drew. We extend `shape_locs` for every
   illustration type so the world-space bbox now spans the enveloping
   circles of each annotation.

   These overrides are local to KhepriSVG so we don't change
   bbox/zoom behaviour for backends that handle annotation extents
   their own way (TikZ defers to LaTeX's automatic `tikzpicture`
   bounding box, for instance). =#

#= Text contributes a width-aware bbox so labels at the edges of the
   drawing don't get cropped out of the viewBox. KhepriBase's
   `b_text_size` uses the built-in glyph metrics to give a sensible
   pixel rectangle for any string, so we use it directly. =#
KhepriBase.shape_locs(s::KhepriBase.Text) =
  let p = s.corner, h = s.height
    (minx, maxx, miny, maxy) = KhepriBase.b_text_size(svg, s.str, h, nothing)
    [add_xy(p, minx, miny), add_xy(p, maxx, maxy)]
  end

# Helpers — each annotation defines its centre + max radius.
_radial_locs(c, r) =
  [add_x(c, r), add_x(c, -r), add_y(c, r), add_y(c, -r)]

# Fallback — annotations without an explicit override contribute no
# locs (matches the default Shape behaviour).
KhepriBase.shape_locs(::KhepriBase.Annotation) = Loc[]

KhepriBase.shape_locs(s::KhepriBase.Dimension) =
  [s.from, s.to]

KhepriBase.shape_locs(s::KhepriBase.ArcDimension) =
  isnothing(s.center) ? Loc[] : _radial_locs(s.center, s.radius)

KhepriBase.shape_locs(s::KhepriBase.RadiiIllustration) =
  isempty(s.radii) ? Loc[] : _radial_locs(s.center, maximum(s.radii))

KhepriBase.shape_locs(s::KhepriBase.VectorsIllustration) =
  isempty(s.radii) ? Loc[] :
    let rmax = maximum(s.radii), p = s.start, a = s.angle
      # The line goes from p to p+vpol(rmax, a) — return the line endpoints
      # so the bbox contains both.
      [p, p + vpol(rmax, a)]
    end

KhepriBase.shape_locs(s::KhepriBase.AnglesIllustration) =
  isempty(s.radii) ? Loc[] : _radial_locs(s.center, maximum(s.radii))

KhepriBase.shape_locs(s::KhepriBase.ArcsIllustration) =
  isempty(s.radii) ? Loc[] : _radial_locs(s.center, maximum(s.radii))

KhepriBase.shape_locs(s::KhepriBase.Labels) =
  # Radial reach of the dot + label fan. 0.5 is the label radius
  # consistent with svg_label_at_angle's default offset.
  _radial_locs(s.p, 0.5)

# ============================================================
# Illustration functions
# ============================================================

is_illustration(s) =
  is_labels(s) ||
  is_vectors_illustration(s) ||
  is_radii_illustration(s) ||
  is_angles_illustration(s) ||
  is_arcs_illustration(s)

sort_illustrations!(b::SVG) =
  let illustrations = filter(is_illustration, b.shapes),
      non_illustrations = filter(s -> !is_illustration(s), b.shapes)
    b.shapes = KhepriBase.Proxy[non_illustrations..., illustrations...]
  end

#= Labels — a marker dot at the anchor point with one or more text
   labels arranged radially around it. Mirrors TikZ's
     `\draw (p) node[fill,circle,...,label={[...]ϕ:txt}, ...]{};`
   which places each label at angle `ϕ` outside the dot. We use the
   same `division(-45, 315, n, false)` to spread labels evenly. =#
KhepriBase.b_labels(b::SVG, p, data, mat) =
  withSVGXForm(b, p, mat) do out, c
    let dot_color = svg_fill_color(material_color(data[1].mat))
      svg_point(out, c, dot_color)
      for ((; txt, mat, scale), ϕ_deg) in zip(data, division(-45, 315, length(data), false))
        let ϕ = deg2rad(ϕ_deg),
            color = svg_fill_color(material_color(mat))
          svg_label_at_angle(out, c, ϕ, txt, scale, color)
        end
      end
    end
  end

#= Radii illustration — N radial arrows from the centre, each carrying
   a length label perpendicular to the radial.

   TikZ does:
     \draw[illustration,Latex-Latex,color]( c )--+(ϕ:r);
     \node[label={[...,illustration,color]ϕ+π/2:r_txt}](mid){};
   so each segment is bidirectional-arrowed and the label sits on the
   `ϕ+π/2` side of the segment midpoint. We match exactly. =#
KhepriBase.b_radii_illustration(b::SVG, c, rs, rs_txts, mats, mat) =
  withSVGXForm(b, c, mat) do out, cc
    for (r, r_txt, ϕ, m) in zip(rs, rs_txts, division(π/6, 2π+π/6, length(rs), false), mats)
      let scale = default_annotation_scale(),
          color = svg_rgb(material_color(m)),
          fill_css = "fill:$color",
          stroke_css = "$(_illustration_stroke_css(color));--arrow-start:$scale;--arrow-end:$scale"
        svg_polar_segment(b, cc, vpol(r, ϕ), stroke_css)
        svg_label_at_angle(out, intermediate_loc(cc, cc + vpol(r, ϕ)),
                           ϕ + π/2, r_txt, scale, fill_css)
      end
    end
  end

#= Vectors illustration — N arrows from a common origin in the same
   direction (different lengths). TikZ places the label at `a-π/2`
   (perpendicular to the vector, on its right). =#
KhepriBase.b_vectors_illustration(b::SVG, p, a, rs, rs_txts, mats, mat) =
  withSVGXForm(b, p, mat) do out, c
    for (r, r_txt, m) in zip(rs, rs_txts, mats)
      let scale = default_annotation_scale(),
          color = svg_rgb(material_color(m)),
          fill_css = "fill:$color",
          stroke_css = "$(_illustration_stroke_css(color));--arrow-start:$scale;--arrow-end:$scale"
        svg_polar_segment(b, c, vpol(r, a), stroke_css)
        svg_label_at_angle(out, intermediate_loc(c, c + vpol(r, a)),
                           a - π/2, r_txt, scale, fill_css)
      end
    end
  end

#= Angles illustration — for each (r, s, a) triple draw the start radial
   from 0 to s, the bounding radials at angles s and s+a, and an inner
   arc from s..s+a with arrow at the end. Label placement uses the
   exact same angles as TikZ's `b_angles_illustration` (KhepriTikZ
   TikZ.jl ~L705): in TikZ, `label={ANGLE:TXT}` puts the text at angle
   ANGLE around the anchor, so passing the bisector angle `s/2`
   already places the text outward of the inner arc. We pass the same
   angles to `svg_label_at_angle`, which translates them through
   svg_anchor_for_angle into the matching SVG anchor/baseline.

   When ar > r (inner arc reaches past the geometric radius) TikZ
   inserts a dashed extension; we do the same.

   See the TikZ reference (KhepriTikZ/src/TikZ.jl `b_angles_illustration`)
   for the exact angle/anchor recipe — diverging from it produces visibly
   different label placements. =#
KhepriBase.b_angles_illustration(b::SVG, c, rs, ss, as, r_txts, s_txts, a_txts, mats, mat) =
  withSVGXForm(b, c, mat) do out, cc
    let maxr = maximum(rs),
        n = length(rs),
        ars = division(0.2maxr, 0.7maxr, n, false),
        idxs = sortperm(as),
        (rs, ss, as, r_txts, s_txts, a_txts, mats) = (rs[idxs], ss[idxs], as[idxs], r_txts[idxs], s_txts[idxs], a_txts[idxs], mats[idxs]),
        scale = default_annotation_scale()
      for (r, ar, s, a, r_txt, s_txt, a_txt, m) in zip(rs, ars, ss, as, r_txts, s_txts, a_txts, mats)
        let color = svg_rgb(material_color(m)),
            fill_css = "fill:$color",
            base_css = _illustration_stroke_css(color),
            arrow_css = "$base_css;--arrow-end:$scale"
          if !(r ≈ 0.0)
            if !(s ≈ 0.0)
              svg_polar_segment(b, cc, vpol(ar, 0), base_css)
              svg_arrow_arc(b, cc, ar, 0, s, arrow_css)
              svg_label_at_angle(out, cc + vpol(ar, s/2), s/2, s_txt, scale, fill_css)
            end
            if !(a ≈ 0.0)
              svg_polar_segment(b, cc, vpol(ar, s), base_css)
              svg_polar_segment(b, cc, vpol(r, s + a), arrow_css)
              if ar > r
                #= Dashed extension when the inner arc reaches past r,
                   so the labelled inner arc visually connects to the
                   outer radial — same trick TikZ uses. Dash values
                   are in stroke-width units (so 4,2 with our 1.5px
                   stroke ≈ 6px on, 3px off — visible at typical
                   render sizes). =#
                svg_arrow_line(b, [cc + vpol(r, s + a), cc + vpol(ar, s + a)],
                               "$base_css;stroke-dasharray:4,2")
              end
              svg_arrow_arc(b, cc, ar, s, a, arrow_css)
              svg_label_at_angle(out, cc + vpol(ar, s + a/2), s + a/2, a_txt, scale, fill_css)
            else
              svg_polar_segment(b, cc, vpol(maxr, a), arrow_css)
            end
          end
          svg_label_at_angle(out, intermediate_loc(cc, cc + vpol(maxr, s + a)),
                             s + a - π/2, r_txt, scale, fill_css)
        end
      end
    end
  end

#= Arcs illustration — like angles, but each arc is drawn with its own
   matching radius (no inner-arc trick). TikZ sorts by `ss` so labels
   stack predictably. =#
KhepriBase.b_arcs_illustration(b::SVG, c, rs, ss, as, r_txts, s_txts, a_txts, mats, mat) =
  withSVGXForm(b, c, mat) do out, cc
    let maxr = maximum(rs),
        n = length(rs),
        ars = division(0.2maxr, 0.7maxr, n, false),
        idxs = sortperm(ss),
        (rs, ss, as, r_txts, s_txts, a_txts, mats) = (rs[idxs], ss[idxs], as[idxs], r_txts[idxs], s_txts[idxs], a_txts[idxs], mats[idxs]),
        scale = default_annotation_scale()
      for (i, r, ar, s, a, r_txt, s_txt, a_txt, m) in zip(1:n, rs, ars, ss, as, r_txts, s_txts, a_txts, mats)
        let color = svg_rgb(material_color(m)),
            fill_css = "fill:$color",
            base_css = _illustration_stroke_css(color),
            arrow_css = "$base_css;--arrow-end:$scale"
          if !(r ≈ 0.0)
            #= Skip the leading 0..s segment when it overlaps with the
               previous arc's tail — matches TikZ's `(i==1) || !(s ≈
               ss[i-1] + as[i-1])` test. =#
            if !(s ≈ 0.0) && ((i == 1) || !(s ≈ ss[i-1] + as[i-1]))
              svg_arrow_line(b, [cc, cc + vpol(ar, 0)], base_css)
              svg_arrow_arc(b, cc, ar, 0, s, arrow_css)
              svg_label_at_angle(out, cc + vpol(ar, s/2), s/2, s_txt, scale, fill_css)
            end
            if !(a ≈ 0.0)
              svg_arrow_line(b, [cc, cc + vpol(r, s)], base_css)
              svg_arrow_line(b, [cc, cc + vpol(r, s + a)], arrow_css)
              svg_arrow_arc(b, cc, ar, s, a, arrow_css)
              svg_label_at_angle(out, cc + vpol(ar, s + a/2), s + a/2, a_txt, scale, fill_css)
            end
            svg_label_at_angle(out, intermediate_loc(cc, cc + vpol(r, s + a)),
                               s + a - π/2, r_txt, scale, fill_css)
          end
        end
      end
    end
  end

# ============================================================
# SVG document generation
# ============================================================

#= Emit one <marker> per (kind, color, scale) triple registered while
   shapes were realized.  The marker is a Latex-style filled triangle —
   geometry chosen to roughly match TikZ's `Latex[scale=...]` arrow head:
     - Length L = 0.4 * scale  (≈ 4mm at scale=1 for cm-scaled drawings)
     - Width  W = 0.28 * scale (≈ 0.7 of length, like TikZ's default)

   `markerUnits="userSpaceOnUse"` keeps the arrow size invariant under
   stroke-width changes (TikZ's `Latex` is also size-invariant), so a
   `very thin` line and a `very thick` line carry visually-identical
   arrows. The fill is bound to the registered colour so each line type
   gets a colour-matched arrow.

   refX is positioned so the marker tip lands exactly on the path
   endpoint — the apex of the triangle is at (L,W/2) for end markers and
   at (0,W/2) for start markers. =#
svg_arrow_markers(out::IO, b::SVG) =
  for ((kind, color, scale), id) in b.arrow_markers
    let L = 0.4 * scale,
        W = 0.28 * scale,
        cy = W / 2
      if kind == :end
        println(out, "<marker id=\"$id\" markerUnits=\"userSpaceOnUse\" markerWidth=\"$(svg_number(L))\" markerHeight=\"$(svg_number(W))\" refX=\"$(svg_number(L))\" refY=\"$(svg_number(cy))\" orient=\"auto\"><path d=\"M0,0 L$(svg_number(L)),$(svg_number(cy)) L0,$(svg_number(W)) Z\" fill=\"$color\" stroke=\"none\"/></marker>")
      else
        println(out, "<marker id=\"$id\" markerUnits=\"userSpaceOnUse\" markerWidth=\"$(svg_number(L))\" markerHeight=\"$(svg_number(W))\" refX=\"0\" refY=\"$(svg_number(cy))\" orient=\"auto\"><path d=\"M$(svg_number(L)),0 L0,$(svg_number(cy)) L$(svg_number(L)),$(svg_number(W)) Z\" fill=\"$color\" stroke=\"none\"/></marker>")
      end
    end
  end

#= shapes_bbox iterates `b.refs.shapes`; annotations live in
   `b.refs.annotations` and are not included. For SVG we explicitly
   want them in the viewBox (otherwise illustration callouts and
   labels get cropped off). We compute a combined bbox by walking
   both ref dictionaries through the same `shape_locs` pipeline that
   shapes_bbox uses, then return the union.

   See also: shape_locs(::RadiiIllustration) etc. above. =#
svg_shapes_bbox(b::SVG) =
  let bmin = [Inf, Inf, Inf],
      bmax = [-Inf, -Inf, -Inf]
    fold_locs!(s) =
      for loc in KhepriBase.shape_locs(s)
        let wp = in_world(loc)
          bmin[1] = min(bmin[1], wp.x)
          bmin[2] = min(bmin[2], wp.y)
          bmin[3] = min(bmin[3], wp.z)
          bmax[1] = max(bmax[1], wp.x)
          bmax[2] = max(bmax[2], wp.y)
          bmax[3] = max(bmax[3], wp.z)
        end
      end
    for s in keys(b.refs.shapes)
      fold_locs!(s)
    end
    for s in keys(b.refs.annotations)
      fold_locs!(s)
    end
    (bmin, bmax)
  end

gen_svg_document(b::SVG) =
  let out = connection(b)
    # Realize shapes to a temporary buffer first, since both the marker
    # registry AND the bounding box depend on what the realization
    # produces.
    empty!(b.triangles)
    empty!(b.arrow_markers)
    sort_illustrations!(b)
    saved_io = b.io
    content_buf = IOBuffer()
    b.io = content_buf
    realize_shapes(b)
    # Paint 3D triangles (painter's algorithm)
    painter_sorter!(b.triangles, b.view.camera)
    for tri in b.triangles
      paint_trig(b, tri)
    end
    b.io = saved_io
    content = String(take!(content_buf))
    # Compute bounding box (covers shapes AND annotations)
    (bmin, bmax) = svg_shapes_bbox(b)
    margin = 0.5
    if all(isfinite, bmin) && all(isfinite, bmax)
      let minx = bmin[1] - margin,
          # Y-negation: SVG min-y is -(bmax.y)
          miny = -bmax[2] - margin,
          w = (bmax[1] - bmin[1]) + 2 * margin,
          h = (bmax[2] - bmin[2]) + 2 * margin,
          # Default stroke-width: ~1px at rendered size
          sw = w / render_width()
        println(out, """<svg xmlns="http://www.w3.org/2000/svg" width="$(render_width())" height="$(render_height())" viewBox="$(svg_number(minx)) $(svg_number(miny)) $(svg_number(w)) $(svg_number(h))">""")
        println(out, "<defs>")
        svg_arrow_markers(out, b)
        println(out, "</defs>")
        println(out, "<g stroke-width=\"$(svg_number(sw))\">")
        print(out, content)
        println(out, "</g>")
      end
    else
      println(out, """<svg xmlns="http://www.w3.org/2000/svg" width="$(render_width())" height="$(render_height())">""")
      println(out, "<defs>")
      svg_arrow_markers(out, b)
      println(out, "</defs>")
      print(out, content)
    end
    println(out, "</svg>")
  end

painter_sorter!(trigs, camera) =
  sort!(trigs, lt=(t2, t1) -> distance(trig_center(t1[1:end-1]...), camera) < distance(trig_center(t2[1:end-1]...), camera))

paint_trig(b::SVG, (p1, p2, p3, mat)) =
  let n = try trig_normal(p1, p2, p3) catch; return end,
      out = connection(b),
      v = rotate_vector(b.view.target - b.view.camera, vz(1), pi/4),
      shade = round(Int, angle_between(n, v) / pi * 100) / 100,
      gray = round(Int, shade * 255),
      (x1, y1) = svg_coord(p1),
      (x2, y2) = svg_coord(p2),
      (x3, y3) = svg_coord(p3)
    println(out, "<polygon points=\"$(svg_number(x1)),$(svg_number(y1)) $(svg_number(x2)),$(svg_number(y2)) $(svg_number(x3)),$(svg_number(y3))\" style=\"fill:rgb($gray,$gray,$gray);stroke:none\"/>")
  end

# ============================================================
# Rendering pipeline
# ============================================================

struct SVGFile
  path::String
end
Base.show(io::IO, ::MIME"image/svg+xml", f::SVGFile) =
  write(io, read(f.path))

KhepriBase.b_render_pathname(::SVG, name) =
  with(render_ext, ".svg") do
    render_default_pathname(name)
  end

KhepriBase.b_render_and_save_view(b::SVG, path) =
  let prev_io = b.io
    open(path, "w") do out
      b.io = out
      try
        gen_svg_document(b)
      finally
        b.io = prev_io
      end
    end
    SVGFile(path)
  end

KhepriBase.b_raw_pathname(::SVG, name) =
  with(render_ext, ".svg") do
    render_default_pathname(name)
  end

KhepriBase.b_raw_view(b::SVG, path) =
  let prev_io = b.io
    open(path, "w") do out
      b.io = out
      try
        gen_svg_document(b)
      finally
        b.io = prev_io
      end
    end
    path
  end

# Escape hatch for raw SVG insertion
export add_svg
add_svg(str) =
  println(connection(svg), str)

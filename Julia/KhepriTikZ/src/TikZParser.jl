#=
TikZParser.jl — a Tier-1 "parse and measure" oracle for the TikZ emitter.

This parser reads a `.tex` artifact PRODUCED BY THIS PACKAGE'S EMITTER
(src/TikZ.jl) back into geometric measures: vertex sets, circle centers and
radii, arc parameters, rectangle corners, spline control points, statement
counts and bounding boxes.  Tests compare those measures against analytic,
hand-derived expectations (KhepriBase/test/SceneExpectations.jl) — never
against emitter output — per Docs/TestingStrategy.md step 4.

It is DELIBERATELY coupled to the emitter's exact dialect and errors loudly
on anything it does not recognize.  That coupling is the point: when the
emitter drifts, the parser breaks visibly instead of silently measuring the
wrong thing.  Do not generalize it into a TikZ parser.

Grammar table — every production names the emitter function that writes it:

  Document level (gen_tex_document):
    \documentclass{standalone} … \end{document}    fixed preamble/postamble
    \definecolor{sNN}{gray}{G}                     shade declarations
    \begin{tikzpicture}[OPTS]                      gen_tikz_picture
      OPTS = "" (top view) | "3d view={A}{B}[,fill=gray]"
             (fill=gray absent in wireframe mode — wireframe_picture_fill_option)

  Scopes:
    \begin{scope}[cm={a, b, c, d, (tx, ty)}]       tikz_transform (raw Float64,
                                                   scientific notation possible)
    \begin{scope}[canvas is xy plane at z=Z[,MAT]] withTikZXForm (3D branch)
    \begin{scope}[use Hobby shortcut, tension=0.1] tikz_hobby_spline
    \begin{scope}[MAT]                             withTikZXForm (material branch)
    \end{scope}  and  \end{scope};                 both occur: withTikZXForm
                                                   uses println, tikz_transform
                                                   uses tikz_e (adds ";") —
                                                   encode reality, accept both.

  Statements ("\draw "/"\fill " from tikz_draw, "\fill[sNN] " from paint_trig,
  each ± option groups [..], each one full line ending ";"):
    COORDcircle(Rcm)                               tikz_circle / tikz_point
    [shift={COORD}][rotate=A](0,0)ellipse(Xcm and Ycm)  tikz_ellipse
    (COORD--)?COORDarc(AI:AF:Rcm)(--cycle)?        tikz_arc via tikz_maybe_arc
                                                   (leading COORD-- + --cycle
                                                   only when filled: wedge)
    COORD(--COORD)*                                tikz_line
    COORD--COORD--…--cycle                         tikz_closed_line; with [sNN]
                                                   and 3 vertices: paint_trig
    COORDrectangleCOORD                            tikz_rectangle
    COORD--+(PHI:RHO)                              tikz_polar_segment
    plot [smooth,tension=1] coordinates {…}        tikz_spline
    plot [smooth cycle,tension=1] coordinates {…}  tikz_closed_spline
    [closed hobby]plot coordinates {…}             tikz_hobby_closed_spline
    COORD(..controlsCOORDandCOORD..COORD)+         tikz_interp_spline /
                                                   b_bezier_curve
    COORD(..COORD)+                                tikz_hobby_spline (in scope)
    COORDnode[OPTS]{TXT}                           tikz_node / tikz_text
                                                   (tikz_text prefixes the
                                                   statement with
                                                   [anchor=base west])

Coordinates are world space: the top-view emitter applies no global transform
(tikz_coord prints in_world x,y rounded to 3 decimals) and 3D-view triangle
coordinates are raw world xyz (the `3d view` projection happens at LaTeX
compile time).  The only transform work is applying `cm=` scope affines
forward to enclosed 2D coordinates; `canvas is xy plane at z=Z` lifts 2D
coordinates to that z.  See also: tikz_number (the 3-decimal rounding that
sets the 1e-3 comparison tolerance), SceneExpectations, TikZOracle.
=#

export parse_tikz, TikZScene, TikZStatement,
       scene_counts, scene_vertices, vertex_set,
       scene_circles, scene_arcs, scene_rect_corners, scene_aabb

#=
One numeric regex covers both of the emitter's number dialects: 3-decimal
rounded coordinates ("0", "5.0", "3.142") and raw Float64s in scope options
("6.123233995736766e-17").  Numbers never carry spaces, so this cannot
over-consume into the next token.
See also: tikz_number, tikz_transform.
=#
const TIKZ_NUM = "[-+]?(?:\\d+(?:\\.\\d+)?|\\.\\d+)(?:[eE][-+]?\\d+)?"
"Regex fragment matching one emitter-formatted number."
TIKZ_NUM

#=
A parsed statement, in world space.  `kind` is one of :circle, :ellipse,
:arc, :line, :polygon, :triangle, :rectangle, :polar_segment, :spline,
:closed_spline, :hobby_closed_spline, :hobby_spline, :bezier, :node.
`filled` records \fill vs \draw; `shade` the sNN gray index (paint_trig
triangles only); `options` the raw option groups; `data` the kind-specific
geometry (already transformed through enclosing scopes).
=#
struct TikZStatement
  kind::Symbol
  filled::Bool
  shade::Union{Int,Nothing}
  options::Vector{String}
  data::NamedTuple
end
"One emitter statement (a single \\draw/\\fill line) in world coordinates."
TikZStatement

struct TikZScene
  picture_options::String
  view::Union{Nothing,NamedTuple}   # (phi, psi) of "3d view", nothing = top
  shades::Dict{Int,Float64}         # declared \definecolor{sNN} grays
  statements::Vector{TikZStatement}
end
"A parsed TikZ artifact: picture options, shade table, world-space statements."
TikZScene

# ── Low-level cursor over one line ─────────────────────────────────────

mutable struct LineCursor
  s::String
  i::Int
  lineno::Int
end

rest(c::LineCursor) = SubString(c.s, c.i)
at_end(c::LineCursor) = c.i > ncodeunits(c.s)

parse_error(c::LineCursor, msg) =
  error("TikZ parse error (line $(c.lineno)): $msg in: $(c.s)")

take_lit!(c::LineCursor, lit) =
  startswith(rest(c), lit) ? (c.i += ncodeunits(lit); true) : false

expect_lit!(c::LineCursor, lit) =
  take_lit!(c, lit) || parse_error(c, "expected \"$lit\" at column $(c.i)")

# Anchored regex match at the cursor; advances on success, nothing otherwise.
take_re!(c::LineCursor, re::Regex) =
  let m = match(re, rest(c))
    m === nothing ? nothing : (c.i += ncodeunits(m.match); m)
  end

const NUM_AT = Regex("^($TIKZ_NUM)")

take_num!(c::LineCursor) =
  let m = take_re!(c, NUM_AT)
    m === nothing ? parse_error(c, "expected a number") : parse(Float64, m[1])
  end

# (x,y) or (x,y,z).  Returns (x, y, z-or-nothing): a missing z is NOT the
# same as z = 0 until scope context (canvas plane) is applied.
take_coord!(c::LineCursor) =
  begin
    expect_lit!(c, "(")
    let x = take_num!(c)
      expect_lit!(c, ",")
      let y = take_num!(c)
        if take_lit!(c, ",")
          let z = take_num!(c)
            expect_lit!(c, ")")
            (x, y, z)
          end
        else
          expect_lit!(c, ")")
          (x, y, nothing)
        end
      end
    end
  end

# One [...] option group (emitter option groups never contain ']').
take_opt_group!(c::LineCursor) =
  let m = take_re!(c, r"^\[([^\]]*)\]")
    m === nothing ? nothing : String(m[1])
  end

# ── Scopes ─────────────────────────────────────────────────────────────

#=
Scope effects, applied innermost-first when a coordinate is materialized:
  :cm        2D affine (a,b,c,d,tx,ty): (x,y) ↦ (a·x+c·y+tx, b·x+d·y+ty)
  :canvas    z-plane lift: a 2D coordinate inside acquires z = Z
  :material  no geometric effect (withTikZXForm material branch)
  :hobby     no geometric effect (tikz_hobby_spline wrapper)
The emitter never nests cm scopes or mixes them with canvas scopes, but the
fold below composes correctly if it ever does.
=#
struct TikZScope
  kind::Symbol
  data::NamedTuple
end

const CM_SCOPE_RE =
  Regex("^cm=\\{($TIKZ_NUM), ($TIKZ_NUM), ($TIKZ_NUM), ($TIKZ_NUM), \\(($TIKZ_NUM), ($TIKZ_NUM)\\)\\}\$")
const CANVAS_SCOPE_RE =
  Regex("^canvas is xy plane at z=($TIKZ_NUM)(?:,(.+))?\$")

parse_scope(opts, lineno) =
  let m = match(CM_SCOPE_RE, opts)
    if m !== nothing
      let (a, b, c, d, tx, ty) = ntuple(i -> parse(Float64, m[i]), 6)
        TikZScope(:cm, (a=a, b=b, c=c, d=d, tx=tx, ty=ty))
      end
    elseif (m = match(CANVAS_SCOPE_RE, opts); m !== nothing)
      TikZScope(:canvas, (z=parse(Float64, m[1]), mat=m[2]))
    elseif opts == "use Hobby shortcut, tension=0.1"
      TikZScope(:hobby, (;))
    elseif !isempty(opts)
      # withTikZXForm wraps statements in a bare material scope; the material
      # is an arbitrary backend string ("very thin", "color={…}", …), so any
      # other non-empty option string is accepted as one.
      TikZScope(:material, (mat=opts,))
    else
      error("TikZ parse error (line $lineno): empty scope options")
    end
  end

# World point of a parsed coordinate under the active scopes (innermost last
# in `scopes`; applied innermost-first).
world_point(scopes, (x, y, z)) =
  begin
    for s in Iterators.reverse(scopes)
      if s.kind === :cm
        z === nothing ||
          error("TikZ parse error: 3D coordinate inside a cm scope is not part of the emitter dialect")
        (; a, b, c, d, tx, ty) = s.data
        (x, y) = (a*x + c*y + tx, b*x + d*y + ty)
      elseif s.kind === :canvas && z === nothing
        z = s.data.z
      end
    end
    (x, y, z === nothing ? 0.0 : z)
  end

#=
Radii and angles only survive a cm scope when it is an orientation-preserving
similarity (rotation + uniform scale): TikZ would render a circle under a
shear as an ellipse, so measuring it as a circle would be a lie.  The check
demands orthogonal equal-norm columns and positive determinant; anything else
errors (plan decision: "non-similarity cm on a radius → error").  Returns the
(scale, rotation-degrees) the scopes apply.
=#
scope_similarity(scopes) =
  let scale = 1.0, rot = 0.0
    for s in scopes
      if s.kind === :cm
        (; a, b, c, d) = s.data
        let n1 = hypot(a, b), n2 = hypot(c, d), tol = 1e-9 * max(n1, n2, 1.0)
          (abs(n1 - n2) <= tol && abs(a*c + b*d) <= tol && a*d - b*c > 0) ||
            error("TikZ parse error: cm scope is not an orientation-preserving similarity; cannot transform a radius/angle")
          scale *= n1
          rot += atand(b, a)
        end
      end
    end
    (scale, rot)
  end

# ── Statement bodies ───────────────────────────────────────────────────

#=
After "\draw"/"\fill", the emitter writes option groups in three places:
attached ("\fill[s28] " — paint_trig), after the separating space
("\draw [anchor=base west](…" — tikz_text), or chained
("[shift={…}][rotate=…]" — tikz_ellipse).  Consuming any mix of groups and
single spaces before the body covers all three without listing each layout.
=#
take_lead_options!(c::LineCursor) =
  let opts = String[]
    while !at_end(c)
      if take_lit!(c, " ")
        nothing
      else
        let g = take_opt_group!(c)
          g === nothing ? break : push!(opts, g)
        end
      end
    end
    opts
  end

shade_of(opts) =
  let i = findfirst(o -> match(r"^s(\d+)$", o) !== nothing, opts)
    i === nothing ? nothing : parse(Int, match(r"^s(\d+)$", opts[i])[1])
  end

take_plot_coords!(c::LineCursor, scopes) =
  begin
    expect_lit!(c, "coordinates {")
    let pts = NTuple{3,Float64}[]
      while !take_lit!(c, "}")
        push!(pts, world_point(scopes, take_coord!(c)))
      end
      expect_lit!(c, ";")
      at_end(c) || parse_error(c, "trailing text after plot")
      pts
    end
  end

#=
Arc parameters: the emitter draws from the start point with TikZ's
`arc(AI:AF:R)`, so the center is recovered as start − R·(cos AI, sin AI) —
the "canonical center" the plan calls for.  Angles and radius are de-rotated
/ de-scaled out of any similarity scopes so the measure is world space.
=#
finish_arc!(c::LineCursor, scopes, wedge_apex, start_raw, filled) =
  begin
    expect_lit!(c, "arc(")
    let ai = take_num!(c)
      expect_lit!(c, ":")
      let af = take_num!(c)
        expect_lit!(c, ":")
        let r = take_num!(c)
          expect_lit!(c, "cm)")
          let closed = take_lit!(c, "--cycle")
            expect_lit!(c, ";")
            at_end(c) || parse_error(c, "trailing text after arc")
            (closed || wedge_apex !== nothing) && !(closed && wedge_apex !== nothing) &&
              parse_error(c, "arc wedge must have both a leading center and --cycle")
            let (scale, rot) = scope_similarity(scopes),
                start = world_point(scopes, start_raw),
                (aiw, afw) = (ai + rot, af + rot),
                rw = r * scale,
                center = (start[1] - rw*cosd(aiw), start[2] - rw*sind(aiw), start[3])
              TikZStatement(:arc, filled, nothing, String[],
                            (center=center, r=rw, ai=aiw, af=afw, start=start,
                             apex=wedge_apex === nothing ? nothing :
                                    world_point(scopes, wedge_apex)))
            end
          end
        end
      end
    end
  end

parse_statement(line, lineno, scopes, shades) =
  let c = LineCursor(line, 1, lineno),
      filled = if take_lit!(c, "\\fill")
        true
      elseif take_lit!(c, "\\draw")
        false
      else
        parse_error(c, "unrecognized statement")
      end,
      opts = take_lead_options!(c),
      shade = shade_of(opts)
    shade === nothing || haskey(shades, shade) ||
      parse_error(c, "shade s$shade used but not declared by \\definecolor")
    if take_lit!(c, "plot [smooth,tension=1] ")
      TikZStatement(:spline, filled, shade, opts, (pts=take_plot_coords!(c, scopes),))
    elseif take_lit!(c, "plot [smooth cycle,tension=1] ")
      TikZStatement(:closed_spline, filled, shade, opts, (pts=take_plot_coords!(c, scopes),))
    elseif take_lit!(c, "plot ")
      "closed hobby" in opts || parse_error(c, "bare plot without [closed hobby] option")
      TikZStatement(:hobby_closed_spline, filled, shade, opts, (pts=take_plot_coords!(c, scopes),))
    elseif startswith(rest(c), "(")
      let p1 = take_coord!(c)
        if take_lit!(c, "circle(")
          let r = take_num!(c)
            expect_lit!(c, "cm);")
            at_end(c) || parse_error(c, "trailing text after circle")
            let (scale, _) = scope_similarity(scopes)
              TikZStatement(:circle, filled, shade, opts,
                            (center=world_point(scopes, p1), r=r*scale))
            end
          end
        elseif take_lit!(c, "ellipse(")
          let rx = take_num!(c)
            expect_lit!(c, "cm and ")
            let ry = take_num!(c)
              expect_lit!(c, "cm);")
              at_end(c) || parse_error(c, "trailing text after ellipse")
              p1 == (0.0, 0.0, nothing) ||
                parse_error(c, "ellipse body must be anchored at (0,0)")
              # tikz_ellipse positions via [shift={(x,y)}][rotate=A] options.
              let sh = findfirst(o -> startswith(o, "shift={"), opts),
                  ro = findfirst(o -> startswith(o, "rotate="), opts),
                  shm = sh === nothing ? nothing :
                          match(Regex("^shift=\\{\\(($TIKZ_NUM),($TIKZ_NUM)(?:,($TIKZ_NUM))?\\)\\}\$"), opts[sh]),
                  rom = ro === nothing ? nothing :
                          match(Regex("^rotate=($TIKZ_NUM)\$"), opts[ro])
                (sh === nothing) == (shm === nothing) && (ro === nothing) == (rom === nothing) ||
                  parse_error(c, "malformed ellipse shift/rotate options")
                let cen = shm === nothing ? (0.0, 0.0, nothing) :
                            (parse(Float64, shm[1]), parse(Float64, shm[2]),
                             shm[3] === nothing ? nothing : parse(Float64, shm[3])),
                    ang = rom === nothing ? 0.0 : parse(Float64, rom[1]),
                    (scale, rot) = scope_similarity(scopes)
                  TikZStatement(:ellipse, filled, shade, opts,
                                (center=world_point(scopes, cen),
                                 rx=rx*scale, ry=ry*scale, rotation=ang + rot))
                end
              end
            end
          end
        elseif take_lit!(c, "rectangle")
          let p2 = take_coord!(c)
            expect_lit!(c, ";")
            at_end(c) || parse_error(c, "trailing text after rectangle")
            TikZStatement(:rectangle, filled, shade, opts,
                          (c0=world_point(scopes, p1), c1=world_point(scopes, p2)))
          end
        elseif take_lit!(c, "node")
          let nopts = take_opt_group!(c)
            expect_lit!(c, "{")
            let m = take_re!(c, r"^(.*)\};$")
              m === nothing && parse_error(c, "unterminated node text")
              at_end(c) || parse_error(c, "trailing text after node")
              TikZStatement(:node, filled, shade, opts,
                            (anchor=world_point(scopes, p1), text=String(m[1]),
                             node_options=nopts === nothing ? "" : nopts))
            end
          end
        elseif startswith(rest(c), "arc(")
          finish_arc!(c, scopes, nothing, p1, filled)
        elseif take_lit!(c, "--+(")
          let phi = take_num!(c)
            expect_lit!(c, ":")
            let rho = take_num!(c)
              expect_lit!(c, ");")
              at_end(c) || parse_error(c, "trailing text after polar segment")
              let (scale, rot) = scope_similarity(scopes),
                  o = world_point(scopes, p1),
                  (phiw, rhow) = (phi + rot, rho * scale)
                TikZStatement(:polar_segment, filled, shade, opts,
                              (origin=o, phi=phiw, rho=rhow,
                               tip=(o[1] + rhow*cosd(phiw), o[2] + rhow*sind(phiw), o[3])))
              end
            end
          end
        elseif take_lit!(c, "..controls")
          # tikz_interp_spline / b_bezier_curve: chained cubic Bézier segments.
          let pts = [p1], ctrls = NTuple{2,NTuple{3,Float64}}[]
            while true
              let c1 = take_coord!(c)
                expect_lit!(c, "and")
                let c2 = take_coord!(c)
                  expect_lit!(c, "..")
                  push!(ctrls, (world_point(scopes, c1), world_point(scopes, c2)))
                  push!(pts, take_coord!(c))
                end
              end
              take_lit!(c, "..controls") || break
            end
            expect_lit!(c, ";")
            at_end(c) || parse_error(c, "trailing text after bezier chain")
            TikZStatement(:bezier, filled, shade, opts,
                          (pts=[world_point(scopes, p) for p in pts], controls=ctrls))
          end
        elseif startswith(rest(c), "..")
          # tikz_hobby_spline body: coordinates joined by "..".
          let pts = [p1]
            while take_lit!(c, "..")
              push!(pts, take_coord!(c))
            end
            expect_lit!(c, ";")
            at_end(c) || parse_error(c, "trailing text after hobby spline")
            TikZStatement(:hobby_spline, filled, shade, opts,
                          (pts=[world_point(scopes, p) for p in pts],))
          end
        elseif startswith(rest(c), "--")
          # Wedge (filled arc), polyline, or closed polyline.
          if filled && match(Regex("^--\\($TIKZ_NUM,$TIKZ_NUM(?:,$TIKZ_NUM)?\\)arc\\("), rest(c)) !== nothing
            expect_lit!(c, "--")
            finish_arc!(c, scopes, p1, take_coord!(c), filled)
          else
            let pts = [p1], closed = false
              while take_lit!(c, "--")
                if take_lit!(c, "cycle")
                  closed = true
                  break
                end
                push!(pts, take_coord!(c))
              end
              expect_lit!(c, ";")
              at_end(c) || parse_error(c, "trailing text after polyline")
              let wpts = [world_point(scopes, p) for p in pts]
                if shade !== nothing
                  # paint_trig only ever emits shaded 3-vertex cycles.
                  closed && length(wpts) == 3 ||
                    parse_error(c, "shaded fill must be a 3-vertex cycle (paint_trig)")
                  TikZStatement(:triangle, filled, shade, opts, (pts=wpts,))
                else
                  TikZStatement(closed ? :polygon : :line, filled, shade, opts,
                                (pts=wpts,))
                end
              end
            end
          end
        else
          parse_error(c, "unrecognized statement body after coordinate")
        end
      end
    else
      parse_error(c, "unrecognized statement body")
    end
  end

# ── Document level ─────────────────────────────────────────────────────

# The exact preamble gen_tex_document writes, minus the \definecolor lines
# (which carry data and are parsed separately).
const PREAMBLE_LINES = Set([
  raw"\documentclass{standalone}",
  raw"\usepackage{tikz,tikz-3dplot}",
  raw"\usetikzlibrary{perspective,patterns}",
  raw"\usetikzlibrary{calc,fadings,decorations.pathreplacing}",
  raw"\usetikzlibrary{shapes,fit}",
  raw"\usetikzlibrary{hobby}",
  raw"\usetikzlibrary{arrows.meta}",
  raw"\begin{document}",
  raw"\tikzset{illustration/.style={very thin}}",
  raw"\tikzset{dimension/.style={very thin,lightgray}}",
])

const DEFINECOLOR_RE = Regex("^\\\\definecolor\\{s(\\d+)\\}\\{gray\\}\\{($TIKZ_NUM)\\}\$")
const BEGIN_PICTURE_RE = r"^\\begin\{tikzpicture\}\[(.*)\]$"
const VIEW_OPTIONS_RE =
  Regex("^3d view=\\{($TIKZ_NUM)\\}\\{($TIKZ_NUM)\\}(,fill=gray)?\$")
const BEGIN_SCOPE_RE = r"^\\begin\{scope\}\[(.*)\]$"

"""
    parse_tikz(path_or_io) -> TikZScene

Parse a `.tex` artifact written by this package's emitter into world-space
measures.  Errors loudly on any line or statement body outside the emitter's
dialect.
"""
parse_tikz(path::AbstractString) = open(parse_tikz, path)
function parse_tikz(io::IO)
  scene_options = nothing
  view = nothing
  shades = Dict{Int,Float64}()
  statements = TikZStatement[]
  scopes = TikZScope[]
  state = :preamble
  for (lineno, raw_line) in enumerate(eachline(io))
    line = chomp(raw_line)
    isempty(line) && state === :done && continue
    if state === :preamble
      if line in PREAMBLE_LINES
        nothing
      elseif (m = match(DEFINECOLOR_RE, line); m !== nothing)
        shades[parse(Int, m[1])] = parse(Float64, m[2])
      elseif (m = match(BEGIN_PICTURE_RE, line); m !== nothing)
        scene_options = String(m[1])
        if !isempty(scene_options)
          let vm = match(VIEW_OPTIONS_RE, scene_options)
            vm === nothing &&
              error("TikZ parse error (line $lineno): unrecognized tikzpicture options: $scene_options")
            view = (phi=parse(Float64, vm[1]), psi=parse(Float64, vm[2]))
          end
        end
        state = :body
      else
        error("TikZ parse error (line $lineno): unrecognized preamble line: $line")
      end
    elseif state === :body
      if (m = match(BEGIN_SCOPE_RE, line); m !== nothing)
        push!(scopes, parse_scope(String(m[1]), lineno))
      elseif line == "\\end{scope}" || line == "\\end{scope};"
        isempty(scopes) &&
          error("TikZ parse error (line $lineno): \\end{scope} without open scope")
        pop!(scopes)
      elseif line == "\\end{tikzpicture}"
        isempty(scopes) ||
          error("TikZ parse error (line $lineno): unclosed scope at \\end{tikzpicture}")
        state = :postamble
      else
        push!(statements, parse_statement(line, lineno, scopes, shades))
      end
    elseif state === :postamble
      line == "\\end{document}" ||
        error("TikZ parse error (line $lineno): expected \\end{document}, got: $line")
      state = :done
    else # :done
      isempty(line) ||
        error("TikZ parse error (line $lineno): content after \\end{document}: $line")
    end
  end
  state === :done ||
    error("TikZ parse error: truncated document (ended in state $state)")
  TikZScene(scene_options, view, shades, statements)
end

# ── Measures ───────────────────────────────────────────────────────────

"Statement counts by kind, e.g. Dict(:circle => 5, :node => 3)."
scene_counts(scene::TikZScene) =
  let d = Dict{Symbol,Int}()
    for s in scene.statements
      d[s.kind] = get(d, s.kind, 0) + 1
    end
    d
  end

"All vertices of polyline-like statements (:line/:polygon/:triangle), in order."
scene_vertices(scene::TikZScene) =
  [p for s in scene.statements
     if s.kind in (:line, :polygon, :triangle)
     for p in s.data.pts]

#=
The emitter rounds coordinates to 3 decimals, so identical world vertices
parse to bit-identical Float64 triples; exact Set dedup is sound and the
1e-3 matching tolerance lives in the comparison, not here.
=#
"Distinct vertices of polyline-like statements, as a Set of (x,y,z) triples."
vertex_set(scene::TikZScene) = Set(scene_vertices(scene))

"Circles as (center, r, filled) tuples (includes the r=0.03 point dots)."
scene_circles(scene::TikZScene) =
  [(center=s.data.center, r=s.data.r, filled=s.filled)
   for s in scene.statements if s.kind === :circle]

#=
Arc measures are angle-interval canonical: the interval start is normalized
into [0, 360) with the same width, so an emitter (-180:0) arc and an
expectation (180,360) arc compare equal — they are the same point set.
See also: finish_arc! (center recovery), SceneExpectations arc entries.
=#
"Arcs as canonical (center, r, ai, af, filled), ai normalized to [0,360)."
scene_arcs(scene::TikZScene) =
  [let aiw = mod(s.data.ai, 360)
     (center=s.data.center, r=s.data.r, ai=aiw, af=aiw + (s.data.af - s.data.ai),
      filled=s.filled)
   end
   for s in scene.statements if s.kind === :arc]

"Rectangles as normalized ((xmin,ymin,z), (xmax,ymax,z)) corner pairs."
scene_rect_corners(scene::TikZScene) =
  [let (c0, c1) = (s.data.c0, s.data.c1)
     (lo=(min(c0[1], c1[1]), min(c0[2], c1[2]), min(c0[3], c1[3])),
      hi=(max(c0[1], c1[1]), max(c0[2], c1[2]), max(c0[3], c1[3])))
   end
   for s in scene.statements if s.kind === :rectangle]

# Every world coordinate a statement mentions (no radius extents): vertices,
# centers, anchors, control points, corners, arc start points.
statement_points(s::TikZStatement) =
  s.kind in (:line, :polygon, :triangle, :spline, :closed_spline,
             :hobby_closed_spline, :hobby_spline) ? s.data.pts :
  s.kind === :bezier ? vcat(s.data.pts, [c for cc in s.data.controls for c in cc]) :
  s.kind === :circle ? [s.data.center] :
  s.kind === :ellipse ? [s.data.center] :
  s.kind === :arc ? [s.data.center, s.data.start] :
  s.kind === :rectangle ? [s.data.c0, s.data.c1] :
  s.kind === :polar_segment ? [s.data.origin, s.data.tip] :
  s.kind === :node ? [s.data.anchor] :
  error("statement_points: unhandled kind $(s.kind)")

#=
The AABB measure is defined over the coordinate POINTS statements mention
(above) — it does not inflate circles/arcs by their radii.  That makes it a
weak but exactly hand-derivable measure: expectations can compute the same
quantity from their own literals without re-deriving curve extrema.
=#
"AABB over all statement coordinate points, as (lo, hi) (x,y,z) triples."
scene_aabb(scene::TikZScene) =
  let pts = [p for s in scene.statements for p in statement_points(s)]
    isempty(pts) && error("scene_aabb: empty scene")
    (lo=(minimum(p[1] for p in pts), minimum(p[2] for p in pts), minimum(p[3] for p in pts)),
     hi=(maximum(p[1] for p in pts), maximum(p[2] for p in pts), maximum(p[3] for p in pts)))
  end

export thebes

take(out::IO) =
  let contents = String(take!(out))
    print(out, contents)
    contents
 end

thebes_e(out::IO, arg) =
  begin
    print(out, arg)
    println(out, ";")
  end

export use_wireframe
use_wireframe = Parameter(false)

thebes_draw(out::IO, filled=false) =
  print(out, filled && ! use_wireframe() ? "\\fill " : "\\draw ")

thebes_number(out::IO, x::Real) =
  isinteger(x) ?
    print(out, x) :
    (abs(x) < 0.0001 ?
      print(out, 0) :
      print(out, round(x*10000.0)/10000.0))

thebes_cm(out::IO, x::Real) = begin
  thebes_number(out, x)
  print(out, "cm")
end

thebes_2d_coord(out::IO, c::Loc) =
  let c = in_world(c)
    print(out, "(")
    thebes_number(out, c.x)
    print(out, ",")
    thebes_number(out, c.y)
    print(out, ")")
  end

thebes_3d_coord(out::IO, c::Loc) =
  let c = in_world(c)
    print(out, "(")
    thebes_number(out, c.x)
    print(out, ",")
    thebes_number(out, c.y)
    print(out, ",")
    thebes_number(out, c.z)
    print(out, ")")
  end
#
thebes_coord(out::IO, c::Loc) =
  let c = in_world(c)
    print(out, "(")
    thebes_number(out, c.x)
    print(out, ",")
    thebes_number(out, c.y)
    if !iszero(c.z)
      print(out, ",")
      thebes_number(out, c.z)
    end
    print(out, ")")
  end


thebes_pgfpoint(out::IO, c::Loc) =
  let c = in_world(c)
    if ! iszero(c.z)
      error("Can't handle 3D coords")
    end
    print(out, "\\pgfpoint{")
    thebes_cm(out, c.x)
    print(out, "}{")
    thebes_cm(out, c.y)
    print(out, "}")
  end

thebes_circle(out::IO, c::Loc, r::Real, filled::Bool=false) =
  begin
    thebes_draw(out, filled)
    thebes_coord(out, c)
    print(out, "circle(")
    thebes_cm(out, r)
    thebes_e(out, ")")
  end

thebes_point(out::IO, c::Loc) =
  thebes_circle(out, c, 0.01, true)

thebes_ellipse(out::IO, c::Loc, r0::Real, r1::Real, fi::Real, filled=false) =
  begin
    thebes_draw(out, filled)
    print(out, "[shift={")
    thebes_coord(out, c)
    print(out, "}]")
    print(out, "[rotate=")
    thebes_number(out, rad2deg(fi))
    print(out, "]")
    print(out, "(0,0)")
    print(out, "ellipse(")
    thebes_cm(out, r0)
    print(out, " and ")
    thebes_cm(out, r1)
    thebes_e(out, ")")
  end

thebes_arc(out::IO, c::Loc, r::Real, ai::Real, af::Real, filled=false) =
  begin
    thebes_draw(out, filled)
    if filled
      thebes_coord(out, c)
      print(out, "--")
    end
    thebes_coord(out, c+vpol(r, ai))
    print(out, "arc(")
    thebes_number(out, rad2deg(ai))
    print(out, ":")
    thebes_number(out, rad2deg(ai > af ? af+2*pi : af))
    print(out, ":")
    thebes_cm(out, r)
    print(out, ")")
    if filled
      thebes_e(out, "--cycle")    end
    println(out, ";")
  end

thebes_maybe_arc(out::IO, c::Loc, r::Real, ai::Real, da::Real, filled=false) =
  if iszero(r)
    thebes_point(out, c)
  elseif iszero(da)
    thebes_point(out, c + vpol(r, ai))
  elseif abs(da) >= 2*pi
    thebes_circle(out, c, r, filled)
  else
    let af = ai + da
      if af > ai
        thebes_arc(out, c, r, ai, af, filled)
      else
        thebes_arc(out, c, r, af, ai, filled)
      end
    end
  end

thebes_line(out::IO, pts::Locs, options::String="") =
  begin
    thebes_draw(out, false)
    print(out, options)
    thebes_coord(out, first(pts))
    for pt in Iterators.drop(pts, 1)
      print(out, "--")
      thebes_coord(out, pt)
    end
    println(out, ";")
  end

thebes_dimension(out::IO, p::Loc, q::Loc, text::AbstractString) =
  begin
    print(out, "\\dimline{")
    thebes_coord(out, p)
    print(out, "}{")
    thebes_coord(out, q)
    print(out, "}{;")
    print(out, text)
    println(out, "};")
  end

thebes_dim_line(out::IO, p::Loc, q::Loc, text::AbstractString, outside) =
  begin
    print(out, "\\draw[fill=black,latex-latex, very thin]")
    thebes_coord(out, p)
    print(out, "--")
    thebes_coord(out, q)
    println(out, "node[midway,auto=left]{$text};")
  end

thebes_closed_line(out::IO, pts::Locs, filled::Bool=false) =
  begin
    thebes_draw(out, filled)
    for pt in pts
      thebes_coord(out, pt)
      print(out, "--")
    end
    thebes_e(out, "cycle")
  end

thebes_closed_lines(out::IO, ptss, filled::Bool=false) =
  begin
    thebes_draw(out, filled)
    for pts in ptss
      for pt in pts
        thebes_coord(out, pt)
        print(out, "--")
      end
      print(out, "cycle ")
    end
    println(out, ";")
  end

thebes_spline(out::IO, pts::Locs, filled::Bool=false) =
  begin
    thebes_draw(out, filled)
    print(out, "plot [smooth,tension=1] coordinates {")
    for pt in pts
      thebes_coord(out, pt)
    end
    thebes_e(out, "}")
  end

thebes_closed_spline(out::IO, pts::Locs, filled::Bool=false) =
  begin
    thebes_draw(out, filled)
    print(out, "plot [smooth cycle,tension=1] coordinates {")
    for pt in pts
      thebes_coord(out, pt)
    end
    thebes_e(out, "}")
  end

# HACK we need to handle the starting and ending vectors
thebes_hobby_spline(out::IO, pts::Locs, filled::Bool=false) =
  begin
    print(out, "\\begin{scope}")
    println(out, "[use Hobby shortcut, tension=0.1]")
    thebes_draw(out, false)
    thebes_coord(out, first(pts))
    for pt in Iterators.drop(pts, 1)
      print(out, "..")
      thebes_coord(out, pt)
    end
    println(out, ";")
    thebes_e(out, "\\end{scope}")
#=
    thebes_draw(out, filled)
    print(out, "[hobby, tension=0.1]")
    print(out, "plot coordinates {")
    for pt in pts
      thebes_coord(out, pt)
    end
    thebes_e(out, "}")=#
  end

# HACK we need to handle the starting and ending vectors
thebes_hobby_closed_spline(out::IO, pts::Locs, filled::Bool=false) =
  begin
    thebes_draw(out, filled)
    print(out, "[closed hobby]")
    print(out, "plot coordinates {")
    for pt in pts
      thebes_coord(out, pt)
    end
    thebes_e(out, "}")
  end

thebes_rectangle(out::IO, p::Loc, w::Real, h::Real, filled::Bool=false) =
  begin
    thebes_draw(out, filled)
    thebes_coord(out, p)
    print(out, "rectangle")
    thebes_coord(out, add_xy(p, w, h))
    println(out, ";")
  end

# Assuming default Arial font for AutoCAD
thebes_text(out::IO, txt, p::Loc, h::Real) =
  let (scale_x, scale_y) = (3.7*h, 3.7*h)
    thebes_draw(out)
    print(out, "[anchor=base west]")
    thebes_coord(out, p)
    print(out, "node[font=\\fontfamily{phv}\\selectfont,outer sep=0pt,inner sep=0pt")
    print(out, ",xscale=")
    thebes_number(out, scale_x)
    print(out, ",yscale=")
    thebes_number(out, scale_y)
    print(out, "]{")
    print(out, txt)
    thebes_e(out, "}")
  end

thebes_transform(out::IO, f::Function, c::Loc) =
  let m = c.cs.transform,
      t = in_world(c),
      a = m[1,1], b = m[2,1], c = m[1,2], d = m[2,2],
      tx = t.x, ty = t.y
    print(out, "\\begin{scope}")
    println(out, "[cm={$a, $b, $c, $d, ($tx, $ty)}]")
    f(out)
    thebes_e(out, "\\end{scope}")
  end

# thebes_set_view(out::IO, view, options) =
#   let v = view.camera - view.target,
#       contents = String(take(out)),
#       out = IOBuffer()
#     print(out, "\\tdplotsetmaincoords{")
#     thebes_number(out, rad2deg(sph_psi(v)))
#     print(out, "}{")
#     thebes_number(out, rad2deg(sph_phi(v))+90)
#     println(out, "}")
#     println(out, "\\begin{thebespicture}[tdplot_main_coords$(use_wireframe() ? "" : ",fill=gray")$(options=="" ? "" : ",")$options]") #)opacity=0.2")]")
#     print(out, contents)
#     println(out, "\\end{thebespicture}")
#     String(take!(out))
#   end

#=
thebes_set_view(out::IO, camera::Loc, target::Loc, lens::Real) =
  let v = camera - target,
      contents = String(take(out)),
      out = IOBuffer()
    println(out, raw"\begin{thebespicture}")
    #println(out, "\\begin{axis}[view={$(rad2deg(sph_phi(v))+90)}{$(rad2deg(sph_psi(v)))},axis equal image,hide axis,colormap/blackwhite]")
    println(out, "\\begin{axis}[axis equal image,hide axis,colormap/blackwhite]")
    print(out, contents)
    println(out, raw"\end{axis}")
    println(out, raw"\end{thebespicture}")
    String(take!(out))
  end
=#

thebes_set_view(out::IO, view, options) =
  let v = view.target - view.camera,
      contents = String(take(out)),
      out = IOBuffer()
    println(out, "\\begin{thebespicture}[3d view={$(rad2deg(sph_phi(v))+90)}{$(rad2deg(sph_psi(v)))}$(use_wireframe() ? "" : ",fill=gray")$(options=="" ? "" : ",")$options]") #)opacity=0.2")]")
    print(out, contents)
    println(out, "\\end{thebespicture}")
    String(take!(out))
  end



thebes_set_view_top(out::IO, options) =
  let contents = String(take(out)),
      out = IOBuffer()
    println(out, "\\begin{thebespicture}[$options]")
    print(out, contents)
    println(out, "\\end{thebespicture}")
    String(take!(out))
  end

#=
  \begin{thebespicture}
  \begin{axis}[view={135}{45},axis equal image,scale=4,hide axis
=#
#

abstract type ThebesKey end
const ThebesId = Nothing
const ThebesIds = Vector{ThebesId}
const ThebesRef = GenericRef{ThebesKey, ThebesId}
const ThebesRefs = Vector{ThebesRef}
const ThebesEmptyRef = EmptyRef{ThebesKey, ThebesId}
const ThebesUniversalRef = UniversalRef{ThebesKey, ThebesId}
const ThebesNativeRef = NativeRef{ThebesKey, ThebesId}
const ThebesUnionRef = UnionRef{ThebesKey, ThebesId}
const ThebesSubtractionRef = SubtractionRef{ThebesKey, ThebesId}


@kwdef mutable struct ThebesBackend <: Backend{ThebesKey, ThebesId}
  target::Drawing=Drawing(render_size()...)
  refs::References{ThebesKey, ThebesId}=References{ThebesKey, ThebesId}()
end

const Thebes = ThebesBackend

KhepriBase.realization_type(::Type{Thebes}) = EagerRealization()

KhepriBase.void_ref(b::Thebes) = ThebesNativeRef(nothing)
KhepriBase.connection(b::Thebes) = b.target

const thebes = Thebes()

KhepriBase.backend_name(b::Thebes) = "Thebes"

KhepriBase.b_point(b::Thebes, p, mat) =
  thebes_pgfpoint(connection(b), p)

KhepriBase.b_line(b::Thebes, ps, mat) =
  pin(map(to_thebes_ptm, ps), gfunction=(p3, p2) -> begin
    poly(p2, close=false)
    strokepath()
  end)

KhepriBase.b_polygon(b::Thebes, ps, mat) =
  thebes_closed_line(connection(b), ps)

KhepriBase.b_spline(b::Thebes, ps, v0, v1, mat) =
  if (v0 == false) && (v1 == false)
    #thebes_hobby_spline(connection(b), ps, false)
    thebes_spline(connection(b), ps, false)
  elseif (v0 != false) && (v1 != false)
    ThebesInterpSpline(connection(b), ps, v0, v1)
  else
    ThebesInterpSpline(connection(b),
                     ps,
                     v0 == false ? ps[2] - ps[1] : v0,
                     v1 == false ? ps[end-1] - ps[end] : v1)
  end

KhepriBase.b_closed_spline(b::Thebes, ps, mat) =
  thebes_hobby_closed_spline(connection(b), ps)

KhepriBase.b_circle(b::Thebes, c, r, mat) =
  withThebesXForm(connection(b), c) do out, cc
    thebes_circle(out, cc, r)
  end

KhepriBase.b_arc(b::Thebes, c, r, α, Δα, mat) =
  withThebesXForm(connection(b), c) do out, cc
    thebes_maybe_arc(out, cc, r, α, Δα, false)
  end

KhepriBase.b_rectangle(b::Thebes, c, dx, dy, mat) =
  withThebesXForm(connection(b), c) do out, cc
    thebes_rectangle(out, cc, dx, dy)
  end

# KhepriBase.b_trig(b::Thebes, p1, p2, p3, mat) =
#   thebes_closed_line(connection(b), [p1, p2, p3], true)

#
# KhepriBase.b_trig(b::Thebes, p1, p2, p3, mat) =
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
# KhepriBase.b_quad(b::Thebes, p1, p2, p3, p4, mat) =
#   thebes_closed_line(connection(b), [p1, p2, p3, p4], true)

# KhepriBase.b_trig(b::Thebes, p1, p2, p3, mat) =
#   let io = connection(b)
#     print(io, raw"\addplot3[patch,shader=interp] coordinates {")
#     thebes_3d_coord(io, p1)
#     thebes_3d_coord(io, p2)
#     thebes_3d_coord(io, p3)
#     println(io, "};")
#   end

# surfaces need to be saved so that they can be sorted
KhepriBase.b_trig(b::Thebes, p1, p2, p3, mat) =
  begin
    push!(b.extra, (p1, p2, p3, mat))
    nothing
  end

paint_trig(b::Thebes, (p1, p2, p3, mat)) =
  let io = connection(b),
      #c = trig_center(p1, p2, p3),
      n = trig_normal(p1, p2, p3),
      v = rotate_vector(b.view.target - b.view.camera, vz(1), pi/4),
      α = round(Int, angle_between(n, v)/pi*100)
    #if α > 0.5
    print(io, "\\fill[black!$(α)!white] ")
    #print(io, "\\fill[gray, opacity=$α] ")
    thebes_3d_coord(io, p1)
    print(io, "--")
    thebes_3d_coord(io, p2)
    print(io, "--")
    thebes_3d_coord(io, p3)
    println(io, "--cycle;")
  #end
end

KhepriBase.b_quad(b::Thebes, p1, p2, p3, p4, mat) =
  invoke(b_quad, Tuple{Backend, Any, Any, Any, Any, Any}, b, p1, p2, p3, p4, mat)
  # let io = connection(b)
  #   print(io, raw"\addplot3[patch,shader=interp] coordinates {")
  #   thebes_3d_coord(io, p1)
  #   thebes_3d_coord(io, p2)
  #   thebes_3d_coord(io, p3)
  #   thebes_3d_coord(io, p4)
  #   println(io, "};")
  # end

KhepriBase.b_surface_polygon(b::Thebes, ps, mat) =
  thebes_closed_line(connection(b), ps, true)
  #=

KhepriBase.b_surface_polygon_with_holes(b::Thebes, ps, qss, mat) =
  thebes_closed_lines(connection(b), [ps, qss...], true)

KhepriBase.b_surface_circle(b::Thebes, c, r, mat) =
  withThebesXForm(connection(b), c) do out, cc
    thebes_circle(out, cc, r, true)
  end

KhepriBase.b_surface_arc(b::Thebes, c, r, α, Δα, mat) =
  withThebesXForm(connection(b), c) do out, cc
    thebes_maybe_arc(out, cc, r, α, Δα, true)
  end
=#
# realize(b::Thebes, s::Ellipse) =
#   withThebesXForm(connection(b), s.center) do out, c
#     thebes_ellipse(out, c, s.radius_x, s.radius_y, 0, false)
#   end
#
# realize(b::Thebes, s::SurfaceEllipse) =
#   withThebesXForm(connection(b), s.center) do out, c
#     thebes_ellipse(out, c, s.radius_x, s.radius_y, 0, true)
#   end
#
# realize(b::Thebes, s::EllipticArc) =
#   error("Finish this")

#realize(b::Thebes, s::SurfaceElliptic_Arc) = ThebesCircle(connection(b),

# KhepriBase.b_surface_rectangle(b::Thebes, c, dx, dy, mat) =
#   withThebesXForm(connection(b), c) do out, cc
#     thebes_rectangle(out, cc, dx, dy, true)
#   end

KhepriBase.b_text(b::Thebes, str, p, size, mat) =
  #invoke(b_text, Tuple{Backend, Any, Any, Any, Any}, b, str, p, size, mat)
  withThebesXForm(connection(b), p) do out, c
    thebes_text(out, str, c, size)
  end

KhepriBase.b_dim_line(b::Thebes, p, q, tv, str, size, outside, mat) =
  #invoke(b_dim_line, Tuple{Backend, Any, Any, Any, Any, Any, Any, Any}, b, p, q, tv, str, size, outside, mat)
  thebes_dim_line(connection(b), p, q, str, outside)

KhepriBase.b_ext_line(b::Thebes, p, q, mat) =
  thebes_line(connection(b), [p, q], "[very thin]")

# realize(b::Thebes, s::SurfaceGrid) =
#   invoke(realize, Tuple{Backend, SurfaceGrid}, b, s)
  # let n = size(s.points,1),
  #     m = size(s.points,2)
  #   for i in 1:n
  #     thebes_hobby_spline(connection(b), s.points[i,:], false)
  #   end
  #   for j in 1:m
  #     thebes_hobby_spline(connection(b), s.points[:,j], false)
  #   end
  # end

# For extra non-portable stuff
export add_thebes
add_thebes(str) =
  println(connection(thebes), str)
###
# Dimensioning

#backend_dimension(b::Thebes, pa, pb, sep, scale, style) =
#  thebes_dimension(connection(b), pa, pb, )

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

process_thebes(path) =
  let contents = thebes_output(),
      path = path_replace_suffix(path, ".tex"),
      pdfpath = path_replace_suffix(path, ".pdf")
    rm(pdfpath, force=true)
    open(path, "w") do out
      println(out, raw"\documentclass{standalone}")
      println(out, raw"\usepackage{thebes}")
      println(out, raw"\usethebeslibrary{perspective,patterns}")
      println(out, raw"\usethebeslibrary{calc,fadings,decorations.pathreplacing}")
      println(out, raw"\usethebeslibrary{shapes,fit}")
      println(out, raw"\usethebeslibrary{hobby}")
      #println(out, raw"\usepackage{pgfplots}")
      #println(out, raw"\pgfplotsset{compat=1.17}")
      #println(out, raw"\usepackage{thebes-3dplot}")
      println(out, raw"\begin{document}")
      println(out, contents)
      println(out, raw"\end{document}")
    end
    # cd(dirname(path)) do
    #   output = read(`$(miktex_cmd()) -shell-escape -halt-on-error $(path)`, String)
    #   occursin("Error:", output) && println(output)
    # end
    cd(dirname(path)) do
      run(`$(miktex_cmd("texify")) --pdf --engine=luatex --run-viewer $(path)`, wait=true)
      #output = read(`$(miktex_cmd("texify")) --run-viewer $(path)`, String)
      #occursin("Error:", output) && println(output)
    end
  end

export visualize_thebes
visualize_thebes(name="Test") =
  with(render_kind_dir, "Thebes",
       render_ext, ".tex") do
    process_thebes(prepare_for_saving_file(render_pathname(name)))
    @info "Tex file: $(render_pathname(name))"
  end

KhepriBase.b_render_pathname(b::Thebes, name::String) =
  path_replace_suffix(render_pathname(name), ".pdf")

KhepriBase.b_render_view(b::Thebes, path) =
  process_thebes(path)

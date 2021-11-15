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

tikz_draw(out::IO, filled=false) =
  print(out, filled && ! use_wireframe() ? "\\fill " : "\\draw ")

tikz_number(out::IO, x::Real) =
  isinteger(x) ?
    print(out, x) :
    (abs(x) < 0.0001 ?
      print(out, 0) :
      print(out, round(x*10000.0)/10000.0))

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
      error("Can't handle 3D coords")
    end
    print(out, "\\pgfpoint{")
    tikz_cm(out, c.x)
    print(out, "}{")
    tikz_cm(out, c.y)
    print(out, "}")
  end

tikz_circle(out::IO, c::Loc, r::Real, filled::Bool=false) =
  begin
    tikz_draw(out, filled)
    tikz_coord(out, c)
    print(out, "circle(")
    tikz_cm(out, r)
    tikz_e(out, ")")
  end

tikz_point(out::IO, c::Loc) =
  tikz_circle(out, c, 0.01, true)

tikz_ellipse(out::IO, c::Loc, r0::Real, r1::Real, fi::Real, filled=false) =
  begin
    tikz_draw(out, filled)
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

tikz_arc(out::IO, c::Loc, r::Real, ai::Real, af::Real, filled=false) =
  begin
    tikz_draw(out, filled)
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
      tikz_e(out, "--cycle")    end
    println(out, ";")
  end

tikz_maybe_arc(out::IO, c::Loc, r::Real, ai::Real, da::Real, filled=false) =
  if iszero(r)
    tikz_point(out, c)
  elseif iszero(da)
    tikz_point(out, c + vpol(r, ai))
  elseif abs(da) >= 2*pi
    tikz_circle(out, c, r, filled)
  else
    let af = ai + da
      if af > ai
        tikz_arc(out, c, r, ai, af, filled)
      else
        tikz_arc(out, c, r, af, ai, filled)
      end
    end
  end

tikz_line(out::IO, pts::Locs, options::String="") =
  begin
    tikz_draw(out, false)
    print(out, options)
    tikz_coord(out, first(pts))
    for pt in Iterators.drop(pts, 1)
      print(out, "--")
      tikz_coord(out, pt)
    end
    println(out, ";")
  end

tikz_dimension(out::IO, p::Loc, q::Loc, text::AbstractString) =
  begin
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
    print(out, "\\draw[fill=black,latex-latex, very thin]")
    tikz_coord(out, p)
    print(out, "--")
    tikz_coord(out, q)
    println(out, "node[midway,auto=left]{$text};")
  end

tikz_closed_line(out::IO, pts::Locs, filled::Bool=false) =
  begin
    tikz_draw(out, filled)
    for pt in pts
      tikz_coord(out, pt)
      print(out, "--")
    end
    tikz_e(out, "cycle")
  end

tikz_closed_lines(out::IO, ptss, filled::Bool=false) =
  begin
    tikz_draw(out, filled)
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

tikz_rectangle(out::IO, p::Loc, w::Real, h::Real, filled::Bool=false) =
  begin
    tikz_draw(out, filled)
    tikz_coord(out, p)
    print(out, "rectangle")
    tikz_coord(out, add_xy(p, w, h))
    println(out, ";")
  end

# Assuming default Arial font for AutoCAD
tikz_text(out::IO, txt, p::Loc, h::Real) =
  let (scale_x, scale_y) = (3.7*h, 3.7*h)
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

tikz_set_view(out::IO, view, options) =
  let v = view.camera - view.target,
      contents = String(take(out)),
      out = IOBuffer()
    print(out, "\\tdplotsetmaincoords{")
    tikz_number(out, rad2deg(sph_psi(v)))
    print(out, "}{")
    tikz_number(out, rad2deg(sph_phi(v))+90)
    println(out, "}")
    println(out, "\\begin{tikzpicture}[tdplot_main_coords$(use_wireframe() ? "" : ",fill=gray")$(options=="" ? "" : ",")$options]") #)opacity=0.2")]")
    print(out, contents)
    println(out, "\\end{tikzpicture}")
    String(take!(out))
  end

#=
tikz_set_view(out::IO, camera::Loc, target::Loc, lens::Real) =
  let v = camera - target,
      contents = String(take(out)),
      out = IOBuffer()
    println(out, raw"\begin{tikzpicture}")
    #println(out, "\\begin{axis}[view={$(rad2deg(sph_phi(v))+90)}{$(rad2deg(sph_psi(v)))},axis equal image,hide axis,colormap/blackwhite]")
    println(out, "\\begin{axis}[axis equal image,hide axis,colormap/blackwhite]")
    print(out, contents)
    println(out, raw"\end{axis}")
    println(out, raw"\end{tikzpicture}")
    String(take!(out))
  end
=#

tikz_set_view_top(out::IO, options) =
  let contents = String(take(out)),
      out = IOBuffer()
    println(out, "\\begin{tikzpicture}[$options]")
    print(out, contents)
    println(out, "\\end{tikzpicture}")
    String(take!(out))
  end

#=
  \begin{tikzpicture}
  \begin{axis}[view={135}{45},axis equal image,scale=4,hide axis
=#
#

abstract type TikZKey end
const TikZId = Nothing
const TikZIds = Vector{TikZId}
const TikZRef = GenericRef{TikZKey, TikZId}
const TikZRefs = Vector{TikZRef}
const TikZEmptyRef = EmptyRef{TikZKey, TikZId}
const TikZUniversalRef = UniversalRef{TikZKey, TikZId}
const TikZNativeRef = NativeRef{TikZKey, TikZId}
const TikZUnionRef = UnionRef{TikZKey, TikZId}
const TikZSubtractionRef = SubtractionRef{TikZKey, TikZId}
const TikZ = IOBufferBackend{TikZKey, TikZId, Nothing}

KhepriBase.void_ref(b::TikZ) = TikZNativeRef(nothing)

const tikz = TikZ(view=View(xyz(10,10,10), xyz(0,0,0), 0, 0))

KhepriBase.backend_name(b::TikZ) = "TikZ"

tikz_output(options="") =
  let b = tikz
    realize_shapes(b)
    b.view.lens == 0 ?
      tikz_set_view_top(connection(b), options) :
      tikz_set_view(connection(b), b.view, options)
  end

tikz_output_and_reset(options="") =
  let b = tikz,
      out = tikz_output(options)
    b_delete_all_refs(b)
    b.view.lens = 0 # Reset the lens
    out
  end

withTikZXForm(f, out, c) =
  if is_world_cs(c.cs)
    f(out, c)
  else
    tikz_transform(out,
      out -> f(out, u0(world_cs)),
      c)
   end

KhepriBase.b_delete_all_refs(b::TikZ) =
  truncate(connection(b), 0)

KhepriBase.b_point(b::TikZ, p) =
  tikz_pgfpoint(connection(b), p)

KhepriBase.b_line(b::TikZ, ps, mat) =
  tikz_line(connection(b), ps)

KhepriBase.b_polygon(b::TikZ, ps, mat) =
  tikz_closed_line(connection(b), ps)

KhepriBase.b_spline(b::TikZ, ps, v0, v1, interpolator, mat) =
  if (v0 == false) && (v1 == false)
    #tikz_hobby_spline(connection(b), ps, false)
    tikz_spline(connection(b), ps, false)
  elseif (v0 != false) && (v1 != false)
    TikZInterpSpline(connection(b), ps, v0, v1)
  else
    TikZInterpSpline(connection(b),
                     ps,
                     v0 == false ? ps[2] - ps[1] : v0,
                     v1 == false ? ps[end-1] - ps[end] : v1)
  end

KhepriBase.b_closed_spline(b::TikZ, ps, mat) =
  tikz_hobby_closed_spline(connection(b), ps)

KhepriBase.b_circle(b::TikZ, c, r, mat) =
  withTikZXForm(connection(b), c) do out, cc
    tikz_circle(out, cc, r)
  end

KhepriBase.b_arc(b::TikZ, c, r, α, Δα, mat) =
  withTikZXForm(connection(b), c) do out, cc
    tikz_maybe_arc(out, cc, r, α, Δα, false)
  end

KhepriBase.b_rectangle(b::TikZ, c, dx, dy, mat) =
  withTikZXForm(connection(b), c) do out, cc
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

KhepriBase.b_trig(b::TikZ, p1, p2, p3, mat) =
  let io = connection(b)
    print(io, raw"\addplot3[patch,shader=interp] coordinates {")
    tikz_3d_coord(io, p1)
    tikz_3d_coord(io, p2)
    tikz_3d_coord(io, p3)
    println(io, "};")
  end

KhepriBase.b_quad(b::TikZ, p1, p2, p3, p4, mat) =
  invoke(b_quad, Tuple{Backend, Any, Any, Any, Any, Any}, b, p1, p2, p3, p4, mat)
  # let io = connection(b)
  #   print(io, raw"\addplot3[patch,shader=interp] coordinates {")
  #   tikz_3d_coord(io, p1)
  #   tikz_3d_coord(io, p2)
  #   tikz_3d_coord(io, p3)
  #   tikz_3d_coord(io, p4)
  #   println(io, "};")
  # end

KhepriBase.b_surface_polygon(b::TikZ, ps, mat) =
  tikz_closed_line(connection(b), ps, true)
  #=

KhepriBase.b_surface_polygon_with_holes(b::TikZ, ps, qss, mat) =
  tikz_closed_lines(connection(b), [ps, qss...], true)

KhepriBase.b_surface_circle(b::TikZ, c, r, mat) =
  withTikZXForm(connection(b), c) do out, cc
    tikz_circle(out, cc, r, true)
  end

KhepriBase.b_surface_arc(b::TikZ, c, r, α, Δα, mat) =
  withTikZXForm(connection(b), c) do out, cc
    tikz_maybe_arc(out, cc, r, α, Δα, true)
  end
=#
# realize(b::TikZ, s::Ellipse) =
#   withTikZXForm(connection(b), s.center) do out, c
#     tikz_ellipse(out, c, s.radius_x, s.radius_y, 0, false)
#   end
#
# realize(b::TikZ, s::SurfaceEllipse) =
#   withTikZXForm(connection(b), s.center) do out, c
#     tikz_ellipse(out, c, s.radius_x, s.radius_y, 0, true)
#   end
#
# realize(b::TikZ, s::EllipticArc) =
#   error("Finish this")

#realize(b::TikZ, s::SurfaceElliptic_Arc) = TikZCircle(connection(b),

# KhepriBase.b_surface_rectangle(b::TikZ, c, dx, dy, mat) =
#   withTikZXForm(connection(b), c) do out, cc
#     tikz_rectangle(out, cc, dx, dy, true)
#   end

KhepriBase.b_text(b::TikZ, str, p, size, mat) =
  #invoke(b_text, Tuple{Backend, Any, Any, Any, Any}, b, str, p, size, mat)
  withTikZXForm(connection(b), p) do out, c
    tikz_text(out, str, c, size)
  end

KhepriBase.b_dim_line(b::TikZ, p, q, tv, str, size, outside, mat) =
  #invoke(b_dim_line, Tuple{Backend, Any, Any, Any, Any, Any, Any, Any}, b, p, q, tv, str, size, outside, mat)
  tikz_dim_line(connection(b), p, q, str, outside)

KhepriBase.b_ext_line(b::TikZ, p, q, mat) =
  tikz_line(connection(b), [p, q], "[very thin]")

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
const miktex_folder = Parameter("C:/Users/aml/AppData/Local/Programs/MiKTeX/miktex/bin/x64/")
miktex_cmd(cmd::AbstractString="pdflatex") = miktex_folder() * cmd

process_tikz(path) =
  let contents = tikz_output(),
      path = path_replace_suffix(path, ".tex"),
      pdfpath = path_replace_suffix(path, ".pdf")
    rm(pdfpath, force=true)
    open(path, "w") do out
      println(out, raw"\documentclass{standalone}")
      println(out, raw"\usepackage{tikz}")
      println(out, raw"\usetikzlibrary{patterns}")
      println(out, raw"\usetikzlibrary{calc,fadings,decorations.pathreplacing}")
      println(out, raw"\usetikzlibrary{shapes,fit}")
      println(out, raw"\usetikzlibrary{hobby}")
      #println(out, raw"\usepackage{pgfplots}")
      #println(out, raw"\pgfplotsset{compat=1.17}")
      println(out, raw"\usepackage{tikz-3dplot}")
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

export visualize_tikz
visualize_tikz(name="Test") =
  with(render_kind_dir, "TikZ",
       render_ext, ".tex") do
    process_tikz(prepare_for_saving_file(render_pathname(name)))
    @info "Tex file: $(render_pathname(name))"
  end

KhepriBase.b_render_pathname(b::TikZ, name::String) =
  path_replace_suffix(render_pathname(name), ".pdf")

KhepriBase.b_render_view(b::TikZ, path) =
  process_tikz(path)

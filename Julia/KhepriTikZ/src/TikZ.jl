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

tikz_draw(out::IO, filled=false) =
  print(out, filled && ! use_wireframe() ? "\\fill " : "\\draw ")

tikz_number(out::IO, x::Real) =
  isinteger(x) ?
    print(out, x) :
    (abs(x) < 0.0001 ?
      print(out, 0) :
      print(out, round(x*10000.0)/10000.0))

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

tikz_point(out::IO, c::Loc, options=nothing) =
  tikz_circle(out, c, 0.03, true, options)

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
      tikz_e(out, "--cycle")    end
    println(out, ";")
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

# tikz_set_view(out::IO, view, options) =
#   let v = view.camera - view.target,
#       contents = String(take(out)),
#       out = IOBuffer()
#     print(out, "\\tdplotsetmaincoords{")
#     tikz_number(out, rad2deg(sph_psi(v)))
#     print(out, "}{")
#     tikz_number(out, rad2deg(sph_phi(v))+90)
#     println(out, "}")
#     println(out, "\\begin{tikzpicture}[tdplot_main_coords$(use_wireframe() ? "" : ",fill=gray")$(options=="" ? "" : ",")$options]") #)opacity=0.2")]")
#     print(out, contents)
#     println(out, "\\end{tikzpicture}")
#     String(take!(out))
#   end

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

tikz_set_view(out::IO, view, options) =
  let v = view.target - view.camera,
      contents = String(take(out)),
      out = IOBuffer()
    println(out, "\\begin{tikzpicture}[3d view={$(rad2deg(sph_phi(v))-90)}{$(rad2deg(sph_psi(v))-90)}$(use_wireframe() ? "" : ",fill=gray")$(options=="" ? "" : ",")$options]") #)opacity=0.2")]")
    print(out, contents)
    println(out, "\\end{tikzpicture}")
    String(take!(out))
  end



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
const TikZNativeRef = NativeRef{TikZKey, TikZId}
const TikZ = IOBufferBackend{TikZKey, TikZId, Vector}

KhepriBase.void_ref(b::TikZ) = nothing

const tikz = TikZ(view=top_view(), extra=[])

KhepriBase.backend_name(b::TikZ) = "TikZ"

export tikz_option
tikz_option(str) = material(str, tikz=>str)

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


KhepriBase.b_get_material(b::TikZ, layer, spec) =
  let c = layer.color
    c == rgba(1,1,1,1) ?
      void_ref(b) : 
      tikz_color(c)
  end
  
KhepriBase.b_get_material(b::TikZ, spec::Nothing) = void_ref(b)

KhepriBase.after_connecting(b::TikZ) =
  begin
    set_material()
	#set_material(blender, material_grass, "asset_base_id:97b171b4-2085-4c25-8793-2bfe65650266 asset_type:material")
	#set_material(blender, material_grass, "asset_base_id:7b05be22-6bed-4584-a063-d0e616ddea6a asset_type:material")
  end



tikz_output(options="") =
  let b = tikz
    b.cached = false
    truncate(connection(b), 0)
    empty!(b.extra)
    sort_illustrations!(b)
    realize_shapes(b)
    painter_sorter!(b.extra, b.view.camera)
    for tri in b.extra
      paint_trig(b, tri)
    end
    b.view.is_top_view ?
      tikz_set_view_top(connection(b), options) :
      tikz_set_view(connection(b), b.view, options)
  end

painter_sorter!(trigs, camera) =
  sort!(trigs, lt=(t2, t1)->distance(trig_center(t1[1:end-1]...), camera)<distance(trig_center(t2[1:end-1]...), camera))


tikz_output_and_reset(options="") =
  let b = tikz,
      out = tikz_output(options)
    b_delete_all_shapes(b)
    b.view.lens = 0 # Reset the lens
    out
  end

withTikZXForm(f, b, c, mat) =
  let out = connection(b)
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
  tikz_line(connection(b), ps, mat)

KhepriBase.b_polygon(b::TikZ, ps, mat) =
  tikz_closed_line(connection(b), ps, false, mat)

KhepriBase.b_spline(b::TikZ, ps, v0, v1, mat) =
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
  withTikZXForm(b, c, mat) do out, cc
    tikz_circle(out, cc, r)
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
    push!(b.extra, (p1, p2, p3, mat))
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
  let io = connection(b),
      #c = trig_center(p1, p2, p3),
      n = trig_normal(p1, p2, p3),
      v = rotate_vector(b.view.target - b.view.camera, vz(1), pi/4),
      α = round(Int, angle_between(n, v)/pi*100)
    #if α > 0.5
    print(io, "\\fill[white!$(α)!black] ")
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
  #=

KhepriBase.b_surface_polygon_with_holes(b::TikZ, ps, qss, mat) =
  tikz_closed_lines(connection(b), [ps, qss...], true)

KhepriBase.b_surface_circle(b::TikZ, c, r, mat) =
  withTikZXForm(b, c, mat) do out, cc
    tikz_circle(out, cc, r, true)
  end

KhepriBase.b_surface_arc(b::TikZ, c, r, α, Δα, mat) =
  withTikZXForm(b, c, mat) do out, cc
    tikz_maybe_arc(out, cc, r, α, Δα, true)
  end
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
  withTikZXForm(b, c, mat) do out, cc
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

process_tex(path) =
  cd(dirname(path)) do
    let texname = basename(path)
      @static if Sys.islinux()
        try
          for i in 1:2
            run(`lualatex -shell-escape -halt-on-error $texname`, wait=true)
          end
          run(`xdg-open $(path_replace_suffix(texname, ".pdf"))`)
        catch e
          error("Could not process the generated .tex file. Do you have lualatex installed?")
        end
      elseif Sys.isapple()
        error("Can't handle MacOS yet")
      elseif Sys.iswindows()
        let miktex_texify = normpath(joinpath(ENV["APPDATA"], "..", "Local", "Programs", "MiKTeX", "miktex", "bin", "x64", "texify"))
          try
            run(tikz_as_png() ?
                  `$(miktex_texify) --pdf --engine=luatex $(texname)` :
                  `$(miktex_texify) --pdf --engine=luatex --run-viewer $(texname)`,
                wait=true)
          catch e
            error("Could not process the generated .tex file. Do you have MikTeX installed?")
          end
        end
      else
        error("Unknown operating system")
      end
    end
  end


export tikz_as_png
const tikz_as_png = Parameter(false)

process_tikz(path) =
  let contents = tikz_output(),
      path = path_replace_suffix(path, ".tex")
    open(path, "w") do out
      println(out, tikz_as_png() ?
                     raw"\documentclass[convert={density=300,outext=.png}]{standalone}" :
                     raw"\documentclass{standalone}")
      println(out, raw"\usepackage{tikz,tikz-3dplot}")
      println(out, raw"\usetikzlibrary{perspective,patterns}")
      println(out, raw"\usetikzlibrary{calc,fadings,decorations.pathreplacing}")
      println(out, raw"\usetikzlibrary{shapes,fit}")
      println(out, raw"\usetikzlibrary{hobby}")
      #println(out, raw"\usepackage{pgfplots}")
      #println(out, raw"\pgfplotsset{compat=1.17}")
      #println(out, raw"\usepackage{tikz-3dplot}")
      println(out, raw"\begin{document}")
      #println(out, raw"\tikzset{illustration/.style={ultra thin,blue!50}}")
      println(out, raw"\tikzset{illustration/.style={ultra thin}}")
      println(out, raw"\tikzset{dimension/.style={very thin,lightgray}}")
      println(out, contents)
      println(out, raw"\end{document}")
    end
    process_tex(path)
    println(path)
  end

export visualize_tikz
visualize_tikz(name="Test") =
  with(render_kind_dir, "TikZ",
       render_ext, ".tex") do
    process_tikz(prepare_for_saving_file(render_pathname(name)))
    @info "Tex file: $(render_pathname(name))"
  end

KhepriBase.b_render_pathname(::TikZ, name) = 
  with(render_ext, tikz_as_png() ? ".png" : ".pdf") do
    render_default_pathname(name)
  end

KhepriBase.b_render_and_save_view(b::TikZ, path) =
  process_tikz(path)

# Illustrations
KhepriBase.b_textify(b::TikZ, expr) = latexify(expr)

KhepriBase.b_labels(b::TikZ, p, strs, mats, mat) =
  withTikZXForm(b, p, mat) do out, c
    tikz_node(out, c, "",
      "fill,circle,outer sep=0,inner sep=0,minimum size=2pt,illustration,$(tikz_color(mats[1].layer.color)),"*
      join(["label={[illustration,$(tikz_color(mat.layer.color))]$ϕ:$str}"
            for (str,ϕ,mat) in zip(strs, division(-45, 315, length(strs), false), mats)], ","))
  end

KhepriBase.b_radii_illustration(b::TikZ, c, rs, rs_txts, mats, mat) =
  withTikZXForm(b, c, mat) do out, cc
    for (r,r_txt,ϕ,mat) in zip(rs, rs_txts, division(π/6, 2π+π/6, length(rs), false), mats)
      color = tikz_color(mat.layer.color)
      tikz_polar_segment(out, c, vpol(r, ϕ), "latex-latex,illustration,$color")
      tikz_node(out, intermediate_loc(c, c + vpol(r, ϕ)), "", 
        "outer sep=0,inner sep=0,label={[outer sep=0,inner sep=0,illustration,$color]$(tikz_deg_string(ϕ+π/2)):$r_txt}")
    end
  end

KhepriBase.b_vectors_illustration(b::TikZ, p, a, rs, rs_txts, mats, mat) =
  withTikZXForm(b, p, mat) do out, c
    for (r, r_txt, mat) in zip(rs, rs_txts, mats)
      color = tikz_color(mat.layer.color)
      tikz_polar_segment(out, c, vpol(r, a), "latex-latex,illustration,$color")
      tikz_node(out, intermediate_loc(c, c + vpol(r, a)), "", "outer sep=0,inner sep=0,label={[illustration,$color]$(tikz_deg_string(a-π/2)):$r_txt}")
    end
  end

KhepriBase.b_angles_illustration(b::TikZ, c, rs, ss, as, r_txts, s_txts, a_txts, mats, mat) =
  withTikZXForm(b, c, mat) do out, cc
    let maxr = maximum(rs),
        n = length(rs),
        ars = division(0.2maxr, 0.7maxr, n, false),
        idxs = sortperm(as),
        (rs, ss, as, r_txts, s_txts, a_txts, mats) = (rs[idxs], ss[idxs], as[idxs], r_txts[idxs], s_txts[idxs], a_txts[idxs], mats[idxs])
      for (r, ar, s, a, r_txt, s_txt, a_txt, mat) in zip(rs, ars, ss, as, r_txts, s_txts, a_txts, mats)
        color = tikz_color(mat.layer.color)
        if !(r ≈ 0.0)
          if !(s ≈ 0.0)
            tikz_polar_segment(out, c, vpol(ar, 0), "illustration,$color")
            tikz_maybe_arc(out, c, ar, 0, s, false, "-latex,illustration,$color")
            tikz_node(out, c + vpol(ar, s/2), "", "outer sep=0,inner sep=0,label={[outer sep=0,inner sep=0,illustration,$color]$(tikz_deg_string(s/2)):$s_txt}")
          end
          if !(a ≈ 0.0)
            tikz_polar_segment(out, c, vpol(ar, s), "illustration,$color")
            tikz_polar_segment(out, c, vpol(r, s + a), "-latex,illustration,$color")
            if (ar > r)
              tikz_polar_segment(out, pol(r, s + a), vpol(ar-r, s + a), "dashed,illustration,$color")
            end
            (a > 0.0) ?
              tikz_maybe_arc(out, c, ar, s, a, false, "-latex,illustration,$color") :
              tikz_maybe_arc(out, c, ar, s, a, false, "latex-,illustration,$color")
            tikz_node(out, c + vpol(ar, s + a/2), "", "outer sep=0,inner sep=0,label={[outer sep=0,inner sep=0,illustration,$color]$(tikz_deg_string(s + a/2)):$a_txt}")
          else
            tikz_polar_segment(out, c, vpol(maxr, a), "-latex,illustration,$color")
          end
        end
        tikz_node(out, intermediate_loc(c, c + vpol(maxr, s + a)), "", "label={[outer sep=0,inner sep=0,illustration,$color]$(tikz_deg_string(s + a - π/2)):$r_txt}")
      end
    end
  end

KhepriBase.b_arcs_illustration(b::TikZ, c, rs, ss, as, r_txts, s_txts, a_txts, mats, mat) =
  withTikZXForm(b, c, mat) do out, cc
    let maxr = maximum(rs),
        n = length(rs),
        ars = division(0.2maxr, 0.7maxr, n, false),
        idxs = sortperm(ss),
        (rs, ss, as, r_txts, s_txts, a_txts, mats) = (rs[idxs], ss[idxs], as[idxs], r_txts[idxs], s_txts[idxs], a_txts[idxs], mats[idxs])
      for (i, r, ar, s, a, r_txt, s_txt, a_txt, mat) in zip(1:n, rs, ars, ss, as, r_txts, s_txts, a_txts, mats)
        color = tikz_color(mat.layer.color)
        if !(r ≈ 0.0)
          if !(s ≈ 0.0) && ((i == 1) || !(s ≈ ss[i-1] + as[i-1]))
            tikz_line(out, [c, c+vpol(ar, 0)], "illustration,$color")
            tikz_maybe_arc(out, c, ar, 0, s, false, "-latex,illustration,$color")
            tikz_node(out, c + vpol(ar, s/2), "", "outer sep=0,inner sep=0,label={[outer sep=0,inner sep=0,illustration,$color]$(tikz_deg_string(s/2)):$s_txt}")
          end
          if !(a ≈ 0.0)
            #let ar = ((i == 1) || !(s ≈ ss[i-1] + as[i-1])) ? ar : ars[i-1]
            tikz_line(out, [c, c+vpol(r, s)], "illustration,$color")
            tikz_line(out, [c, c+vpol(r, s + a)], "-latex,illustration,$color")
            tikz_maybe_arc(out, c, ar, s, a, false, "-latex,illustration,$color")
            tikz_node(out, c + vpol(ar, s + a/2), "", "outer sep=0,inner sep=0,label={[outer sep=0,inner sep=0,illustration,$color]$(tikz_deg_string(s + a/2)):$a_txt}")
          end
          tikz_node(out, intermediate_loc(c, c + vpol(r, s + a)), "",           
          "outer sep=0,inner sep=0,label={[outer sep=0,inner sep=0,illustration,$color]$(tikz_deg_string(s + a - π/2)):$r_txt}")
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
    b.shapes = Shape[non_illustrations..., illustrations...]
  end

# The Illustration part

annotations = create_layer("annotations")

illustrate_ang(a::Real, p::XYZ, ai::Real, key::String) =
    if a ≈ 0.0
        println("angle = 0")
    else
        let r = random_range(1.0, 4.0)
            p1 = p+vpol(r, ai) # point at the beggining of the arc for angle line
            p2 = p+vpol(r,ai+a) # point at the end of the arc for angle line
            pm = p+vpol(.6r,ai+a/2) # point for text
            pfa = p+vpol(r/2,ai+a) # middle point on segment at the end of the arc for arc arrow
            a_op(ang) = a>=0 ? -ang : +ang # choose arrow direction acoording to angle sign
            p1a = pfa + vpol(.1r, ai+a + a_op(pi/4))
            p2a = pfa + vpol(.1r, ai+a + a_op(3pi/4))
            with(current_layer, annotations) do
                line(p1, p, p2) # angle line
                line(p1a, pfa, p2a) # arrow head
                text(key, pm, 0.2)
                arc(p, r/2, ai, a)
            end
        end
    end

arrow_head_pts(p,q) =
    let d = abs(distance(p, q))
        ap = pol_phi(q-p)-pi/2 # angle perpendicular
        q1 = q + vpol(.1d, ap - pi/4) # arrow head point 1
        q2 = q + vpol(.1d, ap - 3pi/4) # arrow head point 2
        [q1, q, q2]
    end

illustrate_dist(p, q, key) =
    let ap = pol_phi(q-p)-pi/2 # angle perpendicular
        dp = pol_rho(q-p)*0.1 # distance for text
        pm = intermediate_loc(p,q) # middle point between p and q
        with(current_layer, annotations) do
            line(p, q)
            line(arrow_head_pts(p, q)...)
            text(key, pm+vpol(dp, ap), 0.2)
        end
    end # illustration coincident (arrow)

illustrate_vxy_point = KhepriBase.Parameter(false) # TO DO CHANGE FUNCTION SIGNATUREs TO INCLUDE P_STR, and if statent for point
illustrate_vpol_point = KhepriBase.Parameter(false) # TO DO CHANGE FUNCTION SIGNATURE TO INCLUDE P_STR
illustrate_arc_center = KhepriBase.Parameter(false)
illustrate_circ_center = KhepriBase.Parameter(true)
illustrate_circ_circ = KhepriBase.Parameter(false)
illustrate_reg_poly_center = KhepriBase.Parameter(false)
illustrate_rect_corner = KhepriBase.Parameter(false)

include_illustrate_points = KhepriBase.Parameter(true)
include_illustrate_vectors = KhepriBase.Parameter(true)
include_illustrate_arcs = KhepriBase.Parameter(true)
include_illustrate_circles = KhepriBase.Parameter(true)
include_illustrate_regular_polygons = KhepriBase.Parameter(true)
include_illustrate_rectangles = KhepriBase.Parameter(true)

include_illustrate_vpol() = KhepriBase.Parameter(true)
include_illustrate_vxyz() = KhepriBase.Parameter(true)

include_illustrate_bindings() = KhepriBase.Parameter(true)

# AML
# Colors
reds = [
  rgb(255/255, 197/255, 100/255), # Tangerine Orange
  rgb(255/255, 128/255, 128/255), # Samon Red
  rgb(222/255, 145/255, 122/255), # Light Brown
  rgb(240/255, 131/255, 162/255)] # Bubble Gum Pink

greens = [
  rgb(165/255, 223/255, 130/255), # Light Olive Green
  rgb(203/255, 238/255, 098/255), # Lime Green
  rgb(153/255, 239/255, 147/255), # Emerald Green
  rgb(098/255, 230/255, 206/255)] # Jade Green

blues = [
  rgb(130/255, 173/255, 253/255), # Light Blue Purple hint
  rgb(113/255, 219/255, 243/255), # Celestial Blue
  rgb(106/255, 186/255, 236/255), # Light Blue Green hint
  rgb(093/255, 133/255, 185/255)] # Dark Blue

purples = [
  rgb(195/255, 142/255, 220/255), # Dark/Old Pink
  rgb(128/255, 128/255, 255/255), # Lilac Blue
  rgb(123/255, 110/255, 202/255), # Dark Purple
  rgb(179/255, 172/255, 252/255)] # lilac Light Purple

# only one color set
# illustration_colors = blues
# illustration_colors = greens
# illustration_colors = purples
# illustration_colors = reds

# mixed set
illustration_colors = vcat([[blues[i], purples[i], reds[i], greens[i]] for i in eachindex(blues)]...)

with_recursive_illustration(f) = begin
  #println(illustrations_stack)
  let last = isempty(illustrations_stack) ? nothing : illustrations_stack[end],
      recursive_level = length(illustrations_stack),
      funcs = unique(illustrations_stack),
      func_idx = something(findfirst(==(last), funcs), 1),
      opacities = [1.0,0.7,0.55,0.4,0.2,0.05],
      opacity = opacities[min(max(recursive_level, 1), length(opacities))],
      #opacity = 1.0/max(recursive_level, 1),
      color = rgba(illustration_colors[(func_idx-1)%(length(illustration_colors))+1], opacity),
      #color = rgba(illustration_colors[1], opacity),
      opacity_material = material_in_layer(layer("illustration_$(func_idx)_$(opacity)", true, color))
      #opacity_material = material_in_layer(layer("opacity_$(opacity)", true, rgba(opacity, 0.0, 0.5, opacity)))
    #println("current_recursive_level:", current_recursive_level(), "  Opacity:", opacity)
    #println(illustrations_stack, " ", last, " ", recursive_level, " ", idx, " ", opacity_material)
    with(default_annotation_material, opacity_material, 
         #default_material, opacity_material, 
         #default_curve_material, opacity_material, 
         #default_point_material, opacity_material
         ) do
      f()
    end
  end
end

#
illustrate_binding(name, init) =
  if init isa Loc
    label(init, name)
  elseif init isa Locs
    for (i, p) in enumerate(init)
      illustrate_binding(:($name[$i]), p)
    end
  end

is_op_call(op, expr) =
  expr isa Expr && expr.head == :call && expr.args[1] == op

illustrate(f::typeof(+), (p_expr, v_expr), p::Union{X,XY,Pol}, v::Union{VPol}) =
  with_recursive_illustration() do
    let (ρ, ϕ) = is_op_call(:vpol, v_expr) ? v_expr.args[2:3] :
                   v_expr isa Symbol ? (Symbol(v_expr, "_ρ"), Symbol(v_expr, "_ϕ")) :
                   (:⊕, :⊗)
      label(p, p_expr)
      #dimension(p, p+v, ρ, size=0.1, offset=0)
      angle_illustration(p, pol_rho(v), 0, pol_phi(v), ρ, :0, ϕ)
    end
  end

illustrate(f::typeof(+), (p_expr, v_expr), p::Union{X,XY,Pol}, v::Union{VXY}) =
  with_recursive_illustration() do
    let (x, y) = is_op_call(:vxy, v_expr) ? v_expr.args[2:3] :
                   is_op_call(:vy, v_expr) ? (:dummy, v_expr.args[2]) :
                     v_expr isa Symbol ?
                       (cx(v) ≈ 0.0 || cy(v) ≈ 0.0) ?
                         (v_expr, v_expr) :
                           (Symbol(v_expr, "_x"), Symbol(v_expr, "_y")) :
                           (:⊕, :⊗)
      label(p, p_expr)
      cx(v) ≈ 0.0 ? nothing : vector_illustration(p, 0, cx(v), x)
      cy(v) ≈ 0.0 ? nothing : vector_illustration(p+vx(cx(v)), π/2, cy(v), y)
    end
  end

illustrate(f::typeof(+), (p_expr, v_expr), p::Union{X,XY,Pol}, v::Union{VX}) =
  with_recursive_illustration() do
    let d = v_expr isa Expr && v_expr.head == :call && v_expr.args[1] == :vx ?
                   v_expr.args[2] :
                   v_expr isa Symbol ? v_expr :
                   :⊗
      label(p, p_expr)
      vector_illustration(p, 0, cx(v), d)
    end
  end

illustrate(f::typeof(-), (p_expr, v_expr), p::Union{X,XY,Pol}, v::Union{VPol}) =
  with_recursive_illustration() do
    let (ρ, ϕ) = is_op_call(:vpol, v_expr) ? v_expr.args[2:3] :
                   v_expr isa Symbol ? (Symbol(v_expr, "_ρ"), Symbol(v_expr, "_ϕ")) :
                   (:⊕, :⊗)
      label(p, p_expr)
      #dimension(p, p+v, ρ, size=0.1, offset=0)
      angle_illustration(p, pol_rho(v), 0, pol_phi(v), ρ, :0, ϕ)
    end
  end

illustrate(f::typeof(-), (p_expr, v_expr), p::Union{X,XY,Pol}, v::Union{VXY}) =
  with_recursive_illustration() do
    let (x, y) = is_op_call(:vxy, v_expr) ? v_expr.args[2:3] :
                   is_op_call(:vy, v_expr) ? (:dummy, v_expr.args[2]) :
                     v_expr isa Symbol ?
                       (cx(v) ≈ 0.0 || cy(v) ≈ 0.0) ?
                         (v_expr, v_expr) :
                           (Symbol(v_expr, "_x"), Symbol(v_expr, "_y")) :
                           (:⊕, :⊗)
      label(p, p_expr)
      cx(v) ≈ 0.0 ? nothing : vector_illustration(p, π, cx(v), x)
      cy(v) ≈ 0.0 ? nothing : vector_illustration(p-vx(cx(v)), -π/2, cy(v), y)
    end
  end

illustrate(f::typeof(-), (p_expr, v_expr), p::Union{X,XY,Pol}, v::Union{VX}) =
  with_recursive_illustration() do
    let d = v_expr isa Expr && v_expr.head == :call && v_expr.args[1] == :vx ?
                   v_expr.args[2] :
                   v_expr isa Symbol ? v_expr :
                   :⊗
      label(p, p_expr)
      vector_illustration(p, π, cx(v), d)
    end
  end


illustrate(f::typeof(pol), (ρ_expr, ϕ_expr), ρ::Real, ϕ::Real) =
  illustrate(+, (:(x(0)), :(vpol($ρ_expr, $ϕ_expr))), u0(), vpol(ρ, ϕ))

illustrate(f::typeof(line), exprs, args...) =
  illustrate_vertices(exprs, args...)

  #=
illustrate_vertices(args...) = begin println(args)
  # if the first arg is an array, the second is the corresponding expression, and let's try to be clever
  if length(args) == 2 && args[1] isa Vector
    let (pts, expr) = (args[1], args[2])
      if expr isa Expr && expr.head === :vect # OK, we have the vector of expressions
        let nsplats = count(is_splat, expr.args)
          if nsplats == 0 # no splats
            illustrate_vertices(pts..., expr.args...)
          elseif nsplats == 1 # just one splat
            let splat_length = length(pts) - length(expr.args) + 1
              illustrate_vertices(pts..., vcat([(is_splat(e) ? [:($(e.args[1])[$i]) for i in 1:splat_length] : [e]) for e in expr.args]...)...)
            end
          else 
            error("Can't handle more than one splat")
          end
        end
      elseif expr isa Symbol # only one expression, is it just a symbol?
        illustrate_vertices(pts..., [:($expr[$i]) for i in 1:length(pts)]...)
      else # something else
        #HACK: what should we do?
        #error("Can't handle line($(args...)")
        illustrate_vertices(pts..., [:(λ[$i]) for i in 1:length(pts)]...)
      end
    end
  else
    with_recursive_illustration() do
      # half of ps are locations (or vectors of locations) and the other half are expressions (possibly using splat)
      let n = length(args)÷2,
          ps = args[1:n],
          ps_exprs = args[n+1:end]
        for (p, p_expr) in zip(ps, ps_exprs)
          if p isa Vector
            @assert(is_splat(p_expr))
            for (pi, i) in zip(p, 1:length(p))
              label(pi, :($(p_expr.args[1])[$i]))
            end
          else
            label(p, p_expr)
          end
        end
      end
    end
  end
end
=#

illustrate_vertices_labels(expr, pts) =
  expr isa Symbol ?
    for (p, i) in zip(pts, 1:length(pts))
      label(p, :($expr[$i]))
    end :
    for (p, i) in zip(pts, 1:length(pts))
      label(p, :(λ[$i]))
    end

#=
line(p1, p2, p3) -> illustrate(line, p1, p2, p3, :p1, :p2, :p3)
line([p1, p2, p3]) -> illustrate(line, p1, p2, p3, :p1, :p2, :p3)
line(ps) -> illustrate(line, ps, :ps[1], :ps[2], :ps[3])
line([ps..., p]) -> illustrate(line, [ps...,p], :ps[1], :ps[2], :ps[3], :p)
line([ps..., qs...]) -> illustrate(line, [ps..., qs...], :ps[1], :ps[2], :ps[??], :qs[])
line([ps..., qs...]) -> illustrate(line, [ps..., qs...], :[ps...,qs...][1], :[ps...,qs...][2], :[ps...,qs...][3])
=#

illustrate_vertices(exprs, pts...) =
  # if there is just one pt, it must be an array of pts 
  if length(pts) == 1
    @assert pts[1] isa Vector # Otherwise, it must be just one location, which does not make sense.
    @assert length(exprs) == 1 # and it was produced by a single expression (e.g., a variable, a vector, an array comprehension)
    let (pts, expr) = (pts[1], exprs[1])
      if is_vect(expr) # We have the vector of expressions
        let nsplats = count(is_splat, expr.args)
          if nsplats == 0 # no splats
            illustrate_vertices(expr.args, pts...)
          elseif nsplats == 1 # just one splat
            let splat_length = length(pts) - length(expr.args) + 1
              illustrate_vertices(vcat([(is_splat(e) ? [:($(e.args[1])[$i]) for i in 1:splat_length] : [e]) for e in expr.args]...), 
                                  pts...)
            end
          else 
            error("Can't illustrate vector with more than one splat")
          end
        end
      elseif is_comprehension(expr)
        with_recursive_illustration() do
          illustrate_vertices_labels(expr.args[1].args[1], pts)
        end
      else
        with_recursive_illustration() do
          illustrate_vertices_labels(expr, pts)
        end
      end
    end
  else
    with_recursive_illustration() do
      for (pt, expr) in zip(pts, exprs)
        if is_splat(expr)
          @assert pt isa Vector
          illustrate_vertices_labels(expr.args[1], pt)
        else
          label(pt, expr)
        end
      end
    end
  end

illustrate(f::typeof(closed_line), exprs, args...) =
  illustrate_vertices(exprs, args...)

illustrate(f::typeof(spline), exprs, args...) =
  illustrate_vertices(exprs, args...)

illustrate(f::typeof(closed_spline), exprs, args...) =
  illustrate_vertices(exprs, args...)

illustrate(f::typeof(polygon), exprs, args...) =
  illustrate_vertices(exprs, args...)

illustrate(f::typeof(circle), (c_expr, r_expr), c::Loc, r::Real) =
  if include_illustrate_circles()
    with_recursive_illustration() do
      label(c, c_expr)
      radius_illustration(c, r, r_expr)
    end
  end

illustrate(f::typeof(circle), (c_expr,), c::Loc) =
  illustrate(f, (c_expr, :(1)), c, 1)

illustrate(f::typeof(circle), ()) =
  illustrate(f, (:(x(0)),), x(0))

illustrate(f::typeof(regular_polygon), ()) =
  illustrate(f, (:(3),), 3)

illustrate(f::typeof(regular_polygon), (n_expr,), n::Int) =
  illustrate(f, (n_expr, :(x(0))), n, x(0))

illustrate(f::typeof(regular_polygon), (n_expr, c_expr), n::Int, c::Loc) =
  illustrate(f, (n_expr, c_expr, :(1)), n, c, 1)

illustrate(f::typeof(regular_polygon), (n_expr, c_expr, r_expr), n::Int, c::Loc, r::Real) =
  illustrate(f, (n_expr, c_expr, r_expr, :(0)), n, c, r, 0)

illustrate(f::typeof(regular_polygon), (n_expr, c_expr, r_expr, a_expr), n::Int, c::Loc, r::Real, a::Real) =
  illustrate(f, (n_expr, c_expr, r_expr, a_expr, :(true)), n, c, r, a, true)

illustrate(f::typeof(regular_polygon), (n_expr, c_expr, r_expr, a_expr, inscribed_expr), n::Int, c::Loc, r::Real, a::Real, inscribed::Bool) =
  inscribed ? 
    illustrate(+, (c_expr, :(vpol($r_expr, $a_expr))), c, vpol(r, a)) :
    illustrate(+, (c_expr, :(vpol($r_expr, $(a == 0 ? :(π/($n)) : :($a_expr + π/($n)))))), c::Loc, vpol(r, a + π/n))



illustrate(f::typeof(arc), (c_e, ρ_e, α_e, Δα_e), c::Loc, ρ::Real, α::Real, Δα::Real) =
  with_recursive_illustration() do
    label(c, c_e)
    #dimension(c, c+vpol(ρ, α), ρ_e, size=0.1, offset=0)
    arc_illustration(c, ρ, α, Δα, ρ_e, α_e, Δα_e)
  end

illustrate(f::typeof(point), (p_expr,), p::Loc) =
  with_recursive_illustration() do
    label(p, p_expr)
  end


illustrate(f::typeof(intermediate_loc), (p_expr, q_expr), p::Loc, q::Loc) =
  let m = intermediate_loc(p, q)
    with_recursive_illustration() do
      label(p, p_expr)
      label(q, q_expr)
      vector_illustration(p, (m-p).ϕ, distance(p, m), " ")
      vector_illustration(q, (m-q).ϕ, distance(m, q), " ")
    end
  end
  
illustrate(f::typeof(intermediate_loc), (p_expr, q_expr, factor_expr), p::Loc, q::Loc, factor::Real) =
  let m = intermediate_loc(p, q, factor)
    with_recursive_illustration() do
      label(p, p_expr)
      label(q, q_expr)
      factor_expr isa Number ?
        vector_illustration(p, (m-p).ϕ, distance(p, m), :($factor*($q_expr - $p_expr))) :
        vector_illustration(p, (m-p).ϕ, distance(p, m), :($factor_expr*($q_expr - $p_expr)))
      vector_illustration(q, (m-q).ϕ, distance(m, q), " ")
    end
  end
# We need to complement the automatic illustrations with manual ones.

with_annotation_material(f) =
  with(f, default_curve_material, material_in_layer(layer("illustration_1_1.0", true, rgba(illustration_colors[1], 1.0))))

macro illustrator_plus(body)
  :(without_illustration(()->with_annotation_material(()->$body)))
end

export with_annotation_material, @illustrator_plus
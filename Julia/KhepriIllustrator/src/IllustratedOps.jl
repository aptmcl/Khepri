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

illustrate_xyz(p, key) =
    let p1 = p+vpol(0.4,-pi/3) # point for text
        with(current_layer, annotations) do
            point(p)
            text(key, p1, 0.2)
        end
    end


illustrate_length(p::XYZ, q::XYZ, key::String) =
    let ap = pol_phi(q-p)-pi/2 # angle perpendicular
        dp = pol_rho(q-p)*0.1 # distance for text
        pm = intermediate_loc(p,q) # middle point between p and q
        with(current_layer, annotations) do
            line(p, p+vpol(dp,ap), q+vpol(dp,ap), q)
            text(key, pm+vpol(2dp, ap), 0.2)
        end
    end # dimention away from line

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

illustrate_vxy(p, x, y, key_x, key_y) =
    let q = p+vxy(x,y)
        dp = pol_rho(q-p)*0.1 # distance for text
        with(current_layer, annotations) do
            line(p, p+vx(x), q)
            line(arrow_head_pts(p+vx(x), q)...)
            text(key_x, p+vxy(x/2, -dp), 0.2) # x coordinate
            text(key_y, p+vxy(x+dp, y/2), 0.2) # y coordinate
        end
    end # (Arrow)

illustrate_vx(p, x, key) =
    let q = p+vx(x)
        dp = pol_rho(q-p)*0.1 # distance for text
        pm = intermediate_loc(p,q) # middle point between p and q
        with(current_layer, annotations) do
            line(p, q)
            line(arrow_head_pts(p, q)...)
            text(key, pm+vy(dp), 0.2)
        end
    end # (Arrow)

illustrate_vy(p, y, key) =
    let q = p+vy(y)
        dp = pol_rho(q-p)*0.1 # distance for text
        pm = intermediate_loc(p,q) # middle point between p and q
        with(current_layer, annotations) do
            line(p, q)
            line(arrow_head_pts(p, q)...)
            text(key, pm+vx(dp), 0.2)
        end
    end # (Arrow)

curved_arrow_head_pts(p, rho, alpha) =
    let q = p+vpol(rho, alpha) # end of arc
        a_op(ang) = alpha>=0 ? -ang : +ang # where to turn the arrow head?
        q1 = q + vpol(.1rho, alpha + a_op(pi/4)) # arrow head point 1
        q2 = q + vpol(.1rho, alpha + a_op(3pi/4)) # arrow head point 2
        [q1, q, q2]
    end

illustrate_vpol_point = KhepriBase.Parameter(false) # TO DO CHANGE FUNCTION SIGNATURE TO INCLUDE P_STR

illustrate_vpol(p, rho, alpha, rho_str, alpha_str) =
    let r = random_range(0.2, 0.6)*rho # random value for arc placement (avoid colisions)
        p1 = p+vpol(r, 0) # point at the begining of the arc
        p2 = p+vpol(r, alpha) # point at the end of the arc
        pm = p+vpol(1.1*r, alpha/2) # middle arc point for text
        if alpha ≈ 0.0
            println("angle = 0")
        else
            with(current_layer, annotations) do
                line(p1, p) # first segment on vx()
                line(curved_arrow_head_pts(p, r, alpha)...) # arrow head
                text(alpha_str, pm, 0.2)
                arc(p, r, 0, alpha)
            end
        end

        q = p+vpol(rho, alpha) # end of segment
        ap = pol_phi(q-p)-pi/2 # angle perpendicular
        dp = pol_rho(q-p)*0.1 # distance for text
        pm = intermediate_loc(p,q)  # middle point between p and q
        with(current_layer, annotations) do
            line(p, q)
            line(arrow_head_pts(p, q)...)
            text(rho_str, pm+vpol(-dp, ap), 0.2)
        end
    end # (Arrow with angle)

illustrate_radius(p, r, r_str) =
    illustrate_dist(p, p+vx(r), r_str)

illustrate_radius(p, r, ang, r_str) =
    #illustrate_dist(p, p+vpol(r, ang), r_str)
    dimension(p, p+vpol(r, ang), r_str, offset=0)

illustrate_arc_center = KhepriBase.Parameter(false)

illustrate_arc(p, r, ai, amp, p_str, r_str, ai_str, amp_str) =
    begin
        illustrate_ang(ai, p, 0, ai_str)
        illustrate_ang(amp, p, ai, amp_str)
        illustrate_radius(p, r, ai+amp/2, r_str)
        illustrate_arc_center() ? illustrate_xyz(p, p_str) : nothing
    end

illustrate_circ_center = KhepriBase.Parameter(true)
illustrate_circ_circ = KhepriBase.Parameter(false)

illustrate_circle(p, r, p_str, r_str) =
    begin
        illustrate_radius(p, r, pi/8, r_str)
        illustrate_circ_center() ? illustrate_xyz(p, p_str) : nothing
        illustrate_circ_circ() ?
            with(current_layer, annotations) do; circle(p, r); end :
                nothing
    end

illustrate_reg_poly_center = KhepriBase.Parameter(false)

illustrate_reg_poly(n, p, r, ai, p_str, r_str, ai_str) =
    begin
        with(current_layer, annotations) do; circle(p, r); end
        illustrate_vpol(p, r, ai, r_str, ai_str)
        illustrate_reg_poly_center() ? illustrate_xyz(p, p_str) : nothing
    end

illustrate_rect_corner = KhepriBase.Parameter(false)

illustrate_rectangle(p, dx, dy, p_str, dx_str, dy_str) =
    begin
        illustrate_length(p, p+vx(dx), dx_str)
        illustrate_length(p+vy(dy), p, dy_str)
        illustrate_rect_corner() ? illustrate_xyz(p, p_str) : nothing

    end


# ---------------------- multiple dispatch/overload illustrate
# not sure if we're gonna need this

illustrate(a::Any) = nothing
#illustrate(a::ang, p::XYZ, ai::Real, key::String) = illustrate_ang(float(a), p, ai, key)
illustrate(p::XYZ, key::String) = illustrate_xyz(p, key)
#illustrate(d::dist, p::XYZ, a::Real, key::String) = illustrate_dist(d, p, a, key)
illustrate(p::XYZ, q::XYZ, key::String) = illustrate_dist(p, q, key)
illustrate(v::VXYZ, key::String) = nothing
#=
illustrate(p::XYZH, key::String) =
    begin
       illustrate(p.p, key)
       p.h == [] ? nothing :
        let q = p.p - p.h[end]
            illustrate(p.p, q, "$(p.h[end])")
            illustrate(XYZH(q, p.h[1:end-1]), key)
        end
    end
=#

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
      opacity = 1.0/max(recursive_level, 1),
      color = rgba(illustration_colors[(func_idx-1)%(length(illustration_colors))+1], opacity),
      #color = rgba(illustration_colors[1], opacity),
      opacity_material = material(layer("illustration_$(func_idx)_$(opacity)", true, color))
      #opacity_material = material(layer("opacity_$(opacity)", true, rgba(opacity, 0.0, 0.5, opacity)))
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
illustrate_bindings(names, inits) =
  if current_recursive_level() <= recursive_levels_limit()
    with_recursive_illustration() do
      for (name, init) in zip(names, inits)
        if init isa Loc
          label(init, textify(name))
        end
      end
    end
  end

is_op_call(op, expr) =
  expr isa Expr && expr.head == :call && expr.args[1] == op

illustrate(f::typeof(+), p::Union{X,XY,Pol}, v::Union{VPol}, p_expr, v_expr) =
  with_recursive_illustration() do
    let (ρ, ϕ) = is_op_call(:vpol, v_expr) ? v_expr.args[2:3] :
                   v_expr isa Symbol ? (Symbol(v_expr, "_ρ"), Symbol(v_expr, "_ϕ")) :
                   (:⊕, :⊗)
      label(p, textify(p_expr))
      #dimension(p, p+v, textify(ρ), size=0.1, offset=0)
      angle_illustration(p, pol_rho(v), 0, pol_phi(v), textify(ρ), textify(0), textify(ϕ))
    end
  end

#
illustrate(f::typeof(+), p::Union{X,XY,Pol}, v::Union{VXY}, p_expr, v_expr) =
  with_recursive_illustration() do
    let (x, y) = is_op_call(:vxy, v_expr) ? v_expr.args[2:3] :
                   is_op_call(:vy, v_expr) ? (:dummy, v_expr.args[2]) :
                     v_expr isa Symbol ?
                       (cx(v) ≈ 0.0 || cy(v) ≈ 0.0) ?
                         (v_expr, v_expr) :
                           (Symbol(v_expr, "_x"), Symbol(v_expr, "_y")) :
                           (:⊕, :⊗)
      label(p, textify(p_expr))
      cx(v) ≈ 0.0 ? nothing : KhepriBase.vector_illustration(p, 0, cx(v), textify(x))
      cy(v) ≈ 0.0 ? nothing : KhepriBase.vector_illustration(p+vx(cx(v)), π/2, cy(v), textify(y))
    end
  end
#
illustrate(f::typeof(+), p::Union{X,XY,Pol}, v::Union{VX}, p_expr, v_expr) =
  with_recursive_illustration() do
    let d = v_expr isa Expr && v_expr.head == :call && v_expr.args[1] == :vx ?
                   v_expr.args[2] :
                   v_expr isa Symbol ? v_expr :
                   :⊗
      label(p, textify(p_expr))
      KhepriBase.vector_illustration(p, 0, cx(v), textify(d))
    end
  end

#
illustrate(f::typeof(pol), ρ, ϕ, ρ_expr, ϕ_expr) =
  illustrate(+, u0(), vpol(ρ, ϕ), :(u0()), :(vpol($ρ_expr, $ϕ_expr)))


#=
line(p1, p2, p3) -> illustrate(line, p1, p2, p3, :p1, :p2, :p3)
line([p1, p2, p3]) -> illustrate(line, p1, p2, p3, :p1, :p2, :p3)
line(ps) -> illustrate(line, ps, :ps[1], :ps[2], :ps[3])
line([ps..., p]) -> illustrate(line, [ps...,p], :ps[1], :ps[2], :ps[3], :p)
line([ps..., qs...]) -> illustrate(line, [ps...,qs...], :ps[1], :ps[2], :ps[??], :qs[])
line([ps..., qs...]) -> illustrate(line, [ps...,qs...], :[ps...,qs...][1], :[ps...,qs...][2], :[ps...,qs...][3])
=#

illustrate(f::typeof(line), args...) =
  # if the first arg is an array, the second is the corresponding expression, and let's try to be clever
  if length(args) > 0 && args[1] isa Vector
    let (pts, expr) = (args[1], args[2])
      if expr isa Expr && expr.head === :vect # OK, we have the vector of expressions
        let nsplats = count(is_splat, expr.args)
          if nsplats == 0 # no splats
            illustrate(f, pts..., expr.args...)
          elseif nsplats == 1 # just one splat
            let splat_length = length(pts) - length(expr.args) + 1
              illustrate(f, pts..., vcat([(is_splat(e) ? [:($(e.args[1])[$i]) for i in 1:splat_length] : [e]) for e in expr.args]...)...)
            end
          else 
            error("Can't handle more than one splat")
          end
        end
      elseif expr isa Symbol # only one expression, is it just a symbol?
        illustrate(f, pts..., [:($expr[$i]) for i in 1:length(pts)]...)
      else # something else
        #HACK: what should we do?
        #error("Can't handle line($(args...)")
        illustrate(f, pts..., [:(λ[$i]) for i in 1:length(pts)]...)
      end
    end
  else
    with_recursive_illustration() do
      # half of ps are locations, the other half are expressions
      let n = length(args)÷2,
          ps = args[1:n],
          ps_exprs = args[n+1:end]
        for (p, p_expr) in zip(ps, ps_exprs)
            label(p, textify(p_expr))
        end
      end
    end
  end

illustrate(f::typeof(circle), c, r, c_expr, r_expr) =
  if include_illustrate_circles()
    with_recursive_illustration() do
      label(c, textify(c_expr))
      radius_illustration(c, r, textify(r_expr))
    end
  end

illustrate(f::typeof(regular_polygon), n, c, r, a, n_expr, c_expr, r_expr, a_expr) =
  illustrate(+, c, vpol(r, a), c_expr, :(vpol($r_expr, $a_expr)))

illustrate(f::typeof(arc), c, ρ, α, Δα, c_e, ρ_e, α_e, Δα_e) =
  with_recursive_illustration() do
    label(c, textify(c_e))
    #dimension(c, c+vpol(ρ, α), textify(ρ_e), size=0.1, offset=0)
    arc_illustration(c, ρ, α, Δα, textify(ρ_e), textify(α_e), textify(Δα_e))
  end

illustrate(f::typeof(point), p, p_expr) =
  with_recursive_illustration() do
    label(p, textify(p_expr))
  end


illustrate(f::typeof(intermediate_loc), p, q, p_expr, q_expr) =
  let m = intermediate_loc(p, q)
    with_recursive_illustration() do
      label(p, textify(p_expr))
      label(q, textify(q_expr))
      vector_illustration(p, (m-p).ϕ, distance(p, m), " ")
      vector_illustration(q, (m-q).ϕ, distance(m, q), " ")
    end
  end
  
illustrate(f::typeof(intermediate_loc), p, q, factor, p_expr, q_expr, f_expr) =
  let m = intermediate_loc(p, q, factor)
    with_recursive_illustration() do
      label(p, textify(p_expr))
      label(q, textify(q_expr))
      factor isa Number ?
        vector_illustration(p, (m-p).ϕ, distance(p, m), "f=$(factor)") :
          vector_illustration(p, (m-p).ϕ, distance(p, m), textify(f_expr)*"=$(factor)")
      vector_illustration(q, (m-q).ϕ, distance(m, q), " ")
    end
  end
# We need to complement the automatic illustrations with manual ones.

with_annotation_material(f) =
  with(f, default_curve_material, material(layer("illustration_1_1.0", true, rgba(illustration_colors[1], 1.0))))

macro extra_illustrations(body)
  :(with_annotation_material(()->$body))
end

export with_annotation_material, @extra_illustrations
"""
    compute_gravity_eqf!(eqF_mech, model, lc_idx)

Compute equivalent nodal forces from gravity loads for all elements.
Forces are in global coordinates, added to eqF_mech[elem_idx, 1:12].
"""
function compute_gravity_eqf!(eqF_mech::Matrix{Float64}, model::Model, lc::LoadCase)
  gx = lc.gravity.gx
  gy = lc.gravity.gy
  gz = lc.gravity.gz

  if gx == 0.0 && gy == 0.0 && gz == 0.0
    return
  end

  vertical = model.options.vertical

  for (ei, elem) in enumerate(model.elements)
    n1 = model.nodes[elem.node1]
    n2 = model.nodes[elem.node2]
    L = element_length(n1, n2)
    p = deg2rad(elem.roll)
    d = elem.material.density
    Ax = elem.section.Ax

    t1, t2, t3, t4, t5, t6, t7, t8, t9 = coord_trans(n1, n2, L, p, vertical)

    # translational gravity forces (global coords, half to each end)
    eqF_mech[ei, 1] += d * Ax * L * gx / 2.0
    eqF_mech[ei, 2] += d * Ax * L * gy / 2.0
    eqF_mech[ei, 3] += d * Ax * L * gz / 2.0

    # moment terms at node 1
    eqF_mech[ei, 4] += d * Ax * L * L / 12.0 *
      ((-t4*t8 + t5*t7) * gy + (-t4*t9 + t6*t7) * gz)
    eqF_mech[ei, 5] += d * Ax * L * L / 12.0 *
      ((-t5*t7 + t4*t8) * gx + (-t5*t9 + t6*t8) * gz)
    eqF_mech[ei, 6] += d * Ax * L * L / 12.0 *
      ((-t6*t7 + t4*t9) * gx + (-t6*t8 + t5*t9) * gy)

    # translational gravity forces at node 2
    eqF_mech[ei, 7] += d * Ax * L * gx / 2.0
    eqF_mech[ei, 8] += d * Ax * L * gy / 2.0
    eqF_mech[ei, 9] += d * Ax * L * gz / 2.0

    # moment terms at node 2 (opposite sign)
    eqF_mech[ei, 10] += d * Ax * L * L / 12.0 *
      ((t4*t8 - t5*t7) * gy + (t4*t9 - t6*t7) * gz)
    eqF_mech[ei, 11] += d * Ax * L * L / 12.0 *
      ((t5*t7 - t4*t8) * gx + (t5*t9 - t6*t8) * gz)
    eqF_mech[ei, 12] += d * Ax * L * L / 12.0 *
      ((t6*t7 - t4*t9) * gx + (t6*t8 - t5*t9) * gy)
  end
end

"""
    local_to_global_eqf!(eqF, ei, Nx1,Vy1,Vz1,Mx1,My1,Mz1, Nx2,Vy2,Vz2,Mx2,My2,Mz2, t)

Transform local equivalent end forces to global and add to eqF[ei, :].
Uses {F} = [T]'{Q} where T is the rotation matrix.
"""
function local_to_global_eqf!(eqF::Matrix{Float64}, ei::Int,
    Nx1, Vy1, Vz1, Mx1, My1, Mz1,
    Nx2, Vy2, Vz2, Mx2, My2, Mz2,
    t1, t2, t3, t4, t5, t6, t7, t8, t9)
  eqF[ei, 1]  += Nx1*t1 + Vy1*t4 + Vz1*t7
  eqF[ei, 2]  += Nx1*t2 + Vy1*t5 + Vz1*t8
  eqF[ei, 3]  += Nx1*t3 + Vy1*t6 + Vz1*t9
  eqF[ei, 4]  += Mx1*t1 + My1*t4 + Mz1*t7
  eqF[ei, 5]  += Mx1*t2 + My1*t5 + Mz1*t8
  eqF[ei, 6]  += Mx1*t3 + My1*t6 + Mz1*t9
  eqF[ei, 7]  += Nx2*t1 + Vy2*t4 + Vz2*t7
  eqF[ei, 8]  += Nx2*t2 + Vy2*t5 + Vz2*t8
  eqF[ei, 9]  += Nx2*t3 + Vy2*t6 + Vz2*t9
  eqF[ei, 10] += Mx2*t1 + My2*t4 + Mz2*t7
  eqF[ei, 11] += Mx2*t2 + My2*t5 + Mz2*t8
  eqF[ei, 12] += Mx2*t3 + My2*t6 + Mz2*t9
end

"""
    compute_uniform_eqf!(eqF_mech, model, lc)

Compute equivalent nodal forces from uniform distributed loads.
Loads are in local element coordinates.
"""
function compute_uniform_eqf!(eqF_mech::Matrix{Float64}, model::Model, lc::LoadCase)
  vertical = model.options.vertical

  for ul in lc.uniform_loads
    n = ul.element
    elem = model.elements[n]
    n1 = model.nodes[elem.node1]
    n2 = model.nodes[elem.node2]
    L = element_length(n1, n2)
    Le = L - n1.r - n2.r
    p = deg2rad(elem.roll)

    t1, t2, t3, t4, t5, t6, t7, t8, t9 = coord_trans(n1, n2, L, p, vertical)

    # Fixed-end beam forces in local coordinates
    Nx1 = Nx2 = ul.ux * Le / 2.0
    Vy1 = Vy2 = ul.uy * Le / 2.0
    Vz1 = Vz2 = ul.uz * Le / 2.0
    Mx1 = Mx2 = 0.0
    My1 = -ul.uz * Le * Le / 12.0; My2 = -My1
    Mz1 =  ul.uy * Le * Le / 12.0; Mz2 = -Mz1

    local_to_global_eqf!(eqF_mech, n,
      Nx1, Vy1, Vz1, Mx1, My1, Mz1,
      Nx2, Vy2, Vz2, Mx2, My2, Mz2,
      t1, t2, t3, t4, t5, t6, t7, t8, t9)
  end
end

"""
    compute_trapezoidal_eqf!(eqF_mech, model, lc)

Compute equivalent nodal forces from trapezoidal distributed loads.
Uses 4th-order polynomial integration with shear deformation corrections.
"""
function compute_trapezoidal_eqf!(eqF_mech::Matrix{Float64}, model::Model, lc::LoadCase)
  vertical = model.options.vertical
  do_shear = model.options.shear

  for wl in lc.trapezoidal_loads
    n = wl.element
    elem = model.elements[n]
    n1 = model.nodes[elem.node1]
    n2 = model.nodes[elem.node2]
    Ln = element_length(n1, n2)
    Le = Ln - n1.r - n2.r
    p = deg2rad(elem.roll)

    E = elem.material.E
    G = elem.material.G
    Asy = elem.section.Asy
    Asz = elem.section.Asz
    Iy = elem.section.Iy
    Iz = elem.section.Iz

    if do_shear
      Ksy = 12.0 * E * Iz / (G * Asy * Le * Le)
      Ksz = 12.0 * E * Iy / (G * Asz * Le * Le)
    else
      Ksy = Ksz = 0.0
    end

    t1, t2, t3, t4, t5, t6, t7, t8, t9 = coord_trans(n1, n2, Ln, p, vertical)

    # x-axis trapezoidal loads (along the frame element length)
    x1 = wl.xx1; x2 = wl.xx2; w1 = wl.wx1; w2 = wl.wx2
    Nx1 = (3.0*(w1+w2)*Ln*(x2-x1) - (2.0*w2+w1)*x2^2 + (w2-w1)*x2*x1 + (2.0*w1+w2)*x1^2) / (6.0*Ln)
    Nx2 = (-(2.0*w1+w2)*x1^2 + (2.0*w2+w1)*x2^2 - (w2-w1)*x1*x2) / (6.0*Ln)

    # y-axis trapezoidal loads
    x1 = wl.yx1; x2 = wl.yx2; w1 = wl.wy1; w2 = wl.wy2

    R1o = ((2.0*w1+w2)*x1^2 - (w1+2.0*w2)*x2^2 +
           3.0*(w1+w2)*Ln*(x2-x1) - (w1-w2)*x1*x2) / (6.0*Ln)
    R2o = ((w1+2.0*w2)*x2^2 + (w1-w2)*x1*x2 -
           (2.0*w1+w2)*x1^2) / (6.0*Ln)

    f01 = (3.0*(w2+4.0*w1)*x1^4 - 3.0*(w1+4.0*w2)*x2^4 -
           15.0*(w2+3.0*w1)*Ln*x1^3 + 15.0*(w1+3.0*w2)*Ln*x2^3 -
           3.0*(w1-w2)*x1*x2*(x1^2+x2^2) +
           20.0*(w2+2.0*w1)*Ln^2*x1^2 - 20.0*(w1+2.0*w2)*Ln^2*x2^2 +
           15.0*(w1-w2)*Ln*x1*x2*(x1+x2) -
           3.0*(w1-w2)*x1^2*x2^2 - 20.0*(w1-w2)*Ln^2*x1*x2) / 360.0

    f02 = (3.0*(w2+4.0*w1)*x1^4 - 3.0*(w1+4.0*w2)*x2^4 -
           3.0*(w1-w2)*x1*x2*(x1^2+x2^2) -
           10.0*(w2+2.0*w1)*Ln^2*x1^2 + 10.0*(w1+2.0*w2)*Ln^2*x2^2 -
           3.0*(w1-w2)*x1^2*x2^2 + 10.0*(w1-w2)*Ln^2*x1*x2) / 360.0

    Mz1 = -(4.0*f01 + 2.0*f02 + Ksy*(f01-f02)) / (Ln^2*(1.0+Ksy))
    Mz2 = -(2.0*f01 + 4.0*f02 - Ksy*(f01-f02)) / (Ln^2*(1.0+Ksy))

    Vy1 = R1o + Mz1/Ln + Mz2/Ln
    Vy2 = R2o - Mz1/Ln - Mz2/Ln

    # z-axis trapezoidal loads
    x1 = wl.zx1; x2 = wl.zx2; w1 = wl.wz1; w2 = wl.wz2

    R1o = ((2.0*w1+w2)*x1^2 - (w1+2.0*w2)*x2^2 +
           3.0*(w1+w2)*Ln*(x2-x1) - (w1-w2)*x1*x2) / (6.0*Ln)
    R2o = ((w1+2.0*w2)*x2^2 + (w1-w2)*x1*x2 -
           (2.0*w1+w2)*x1^2) / (6.0*Ln)

    f01 = (3.0*(w2+4.0*w1)*x1^4 - 3.0*(w1+4.0*w2)*x2^4 -
           15.0*(w2+3.0*w1)*Ln*x1^3 + 15.0*(w1+3.0*w2)*Ln*x2^3 -
           3.0*(w1-w2)*x1*x2*(x1^2+x2^2) +
           20.0*(w2+2.0*w1)*Ln^2*x1^2 - 20.0*(w1+2.0*w2)*Ln^2*x2^2 +
           15.0*(w1-w2)*Ln*x1*x2*(x1+x2) -
           3.0*(w1-w2)*x1^2*x2^2 - 20.0*(w1-w2)*Ln^2*x1*x2) / 360.0

    f02 = (3.0*(w2+4.0*w1)*x1^4 - 3.0*(w1+4.0*w2)*x2^4 -
           3.0*(w1-w2)*x1*x2*(x1^2+x2^2) -
           10.0*(w2+2.0*w1)*Ln^2*x1^2 + 10.0*(w1+2.0*w2)*Ln^2*x2^2 -
           3.0*(w1-w2)*x1^2*x2^2 + 10.0*(w1-w2)*Ln^2*x1*x2) / 360.0

    My1 = (4.0*f01 + 2.0*f02 + Ksz*(f01-f02)) / (Ln^2*(1.0+Ksz))
    My2 = (2.0*f01 + 4.0*f02 - Ksz*(f01-f02)) / (Ln^2*(1.0+Ksz))

    Vz1 = R1o - My1/Ln - My2/Ln
    Vz2 = R2o + My1/Ln + My2/Ln

    Mx1 = Mx2 = 0.0

    local_to_global_eqf!(eqF_mech, n,
      Nx1, Vy1, Vz1, Mx1, My1, Mz1,
      Nx2, Vy2, Vz2, Mx2, My2, Mz2,
      t1, t2, t3, t4, t5, t6, t7, t8, t9)
  end
end

"""
    compute_point_load_eqf!(eqF_mech, model, lc)

Compute equivalent nodal forces from internal point loads.
Uses Hermitian interpolation with shear deformation corrections.
"""
function compute_point_load_eqf!(eqF_mech::Matrix{Float64}, model::Model, lc::LoadCase)
  vertical = model.options.vertical
  do_shear = model.options.shear

  for pl in lc.point_loads
    n = pl.element
    elem = model.elements[n]
    n1 = model.nodes[elem.node1]
    n2 = model.nodes[elem.node2]
    Ln = element_length(n1, n2)
    Le = Ln - n1.r - n2.r
    p_roll = deg2rad(elem.roll)

    E = elem.material.E
    G = elem.material.G
    Asy = elem.section.Asy
    Asz = elem.section.Asz
    Iy = elem.section.Iy
    Iz = elem.section.Iz

    if do_shear
      Ksy = 12.0 * E * Iz / (G * Asy * Le * Le)
      Ksz = 12.0 * E * Iy / (G * Asz * Le * Le)
    else
      Ksy = Ksz = 0.0
    end

    t1, t2, t3, t4, t5, t6, t7, t8, t9 = coord_trans(n1, n2, Ln, p_roll, vertical)

    a = pl.a
    b = Ln - a

    Nx1 = pl.px * a / Ln
    Nx2 = pl.px * b / Ln

    # NOTE: Vy uses Ksz and Vz uses Ksy here, matching Frame3DD's C code exactly.
    # This convention differs from the elastic stiffness matrix (where Vy uses Ksy)
    # but is only observable for asymmetric sections (Iy != Iz or Asy != Asz).
    Vy1 = (1.0/(1.0+Ksz)) * pl.py * b^2 * (3.0*a + b) / Ln^3 +
           (Ksz/(1.0+Ksz)) * pl.py * b / Ln
    Vy2 = (1.0/(1.0+Ksz)) * pl.py * a^2 * (3.0*b + a) / Ln^3 +
           (Ksz/(1.0+Ksz)) * pl.py * a / Ln

    Vz1 = (1.0/(1.0+Ksy)) * pl.pz * b^2 * (3.0*a + b) / Ln^3 +
           (Ksy/(1.0+Ksy)) * pl.pz * b / Ln
    Vz2 = (1.0/(1.0+Ksy)) * pl.pz * a^2 * (3.0*b + a) / Ln^3 +
           (Ksy/(1.0+Ksy)) * pl.pz * a / Ln

    Mx1 = Mx2 = 0.0

    My1 = -(1.0/(1.0+Ksy)) * pl.pz * a * b^2 / Ln^2 -
            (Ksy/(1.0+Ksy)) * pl.pz * a * b / (2.0*Ln)
    My2 =  (1.0/(1.0+Ksy)) * pl.pz * a^2 * b / Ln^2 +
            (Ksy/(1.0+Ksy)) * pl.pz * a * b / (2.0*Ln)

    Mz1 =  (1.0/(1.0+Ksz)) * pl.py * a * b^2 / Ln^2 +
            (Ksz/(1.0+Ksz)) * pl.py * a * b / (2.0*Ln)
    Mz2 = -(1.0/(1.0+Ksz)) * pl.py * a^2 * b / Ln^2 -
            (Ksz/(1.0+Ksz)) * pl.py * a * b / (2.0*Ln)

    local_to_global_eqf!(eqF_mech, n,
      Nx1, Vy1, Vz1, Mx1, My1, Mz1,
      Nx2, Vy2, Vz2, Mx2, My2, Mz2,
      t1, t2, t3, t4, t5, t6, t7, t8, t9)
  end
end

"""
    compute_temperature_eqf!(eqF_temp, model, lc)

Compute equivalent nodal forces from temperature loads.
Temperature loads go into a separate eqF_temp array.
"""
function compute_temperature_eqf!(eqF_temp::Matrix{Float64}, model::Model, lc::LoadCase)
  vertical = model.options.vertical

  for tl in lc.temperature_loads
    n = tl.element
    elem = model.elements[n]
    n1 = model.nodes[elem.node1]
    n2 = model.nodes[elem.node2]
    L = element_length(n1, n2)
    p = deg2rad(elem.roll)

    E = elem.material.E
    Ax = elem.section.Ax
    Iy = elem.section.Iy
    Iz = elem.section.Iz

    alpha = tl.alpha
    hy = tl.hy
    hz = tl.hz

    t1, t2, t3, t4, t5, t6, t7, t8, t9 = coord_trans(n1, n2, L, p, vertical)

    # Mean temperature for axial force
    mean_temp = 0.25 * (tl.ty_pos + tl.ty_neg + tl.tz_pos + tl.tz_neg)

    Nx2 = alpha * mean_temp * E * Ax
    Nx1 = -Nx2
    Vy1 = Vy2 = Vz1 = Vz2 = 0.0
    Mx1 = Mx2 = 0.0

    # Differential bending
    My1 = (alpha / hz) * (tl.tz_neg - tl.tz_pos) * E * Iy
    My2 = -My1
    Mz1 = (alpha / hy) * (tl.ty_pos - tl.ty_neg) * E * Iz
    Mz2 = -Mz1

    local_to_global_eqf!(eqF_temp, n,
      Nx1, Vy1, Vz1, Mx1, My1, Mz1,
      Nx2, Vy2, Vz2, Mx2, My2, Mz2,
      t1, t2, t3, t4, t5, t6, t7, t8, t9)
  end
end

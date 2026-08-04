"""
    lumped_M(elem, nodes, d, EMs, vertical)

Compute the 12×12 lumped mass matrix for a frame element in global coordinates.

`d` is the material density, `EMs` is the extra element mass.
Returns a 12×12 Matrix{Float64}.
"""
function lumped_M(elem::FrameElement, nodes::Vector{Node}, d::Float64, EMs::Float64, vertical::VerticalAxis)
  n1 = nodes[elem.node1]
  n2 = nodes[elem.node2]
  L = element_length(n1, n2)
  p = deg2rad(elem.roll)

  Ax = elem.section.Ax
  J = elem.section.Jx
  Iy = elem.section.Iy
  Iz = elem.section.Iz

  t1, t2, t3, t4, t5, t6, t7, t8, t9 = coord_trans(n1, n2, L, p, vertical)

  m = zeros(12, 12)

  # translational mass at each end (rotatory inertia of extra mass is neglected)
  t = (d * Ax * L + EMs) / 2.0
  ry = d * Iy * L / 2.0
  rz = d * Iz * L / 2.0
  po = d * L * J / 2.0  # polar inertia (assumes simple cross-section)

  m[1,1] = m[2,2] = m[3,3] = m[7,7] = m[8,8] = m[9,9] = t

  m[4,4]  = m[10,10] = po*t1*t1 + ry*t4*t4 + rz*t7*t7
  m[5,5]  = m[11,11] = po*t2*t2 + ry*t5*t5 + rz*t8*t8
  m[6,6]  = m[12,12] = po*t3*t3 + ry*t6*t6 + rz*t9*t9

  m[4,5] = m[5,4] = m[10,11] = m[11,10] = po*t1*t2 + ry*t4*t5 + rz*t7*t8
  m[4,6] = m[6,4] = m[10,12] = m[12,10] = po*t1*t3 + ry*t4*t6 + rz*t7*t9
  m[5,6] = m[6,5] = m[11,12] = m[12,11] = po*t2*t3 + ry*t5*t6 + rz*t8*t9

  return m
end

"""
    consistent_M(elem, nodes, d, EMs, vertical)

Compute the 12×12 consistent mass matrix for a frame element in global coordinates.
Does not include shear deformations.

`d` is the material density, `EMs` is the extra element mass.
Returns a 12×12 Matrix{Float64}.
"""
function consistent_M(elem::FrameElement, nodes::Vector{Node}, d::Float64, EMs::Float64, vertical::VerticalAxis)
  n1 = nodes[elem.node1]
  n2 = nodes[elem.node2]
  L = element_length(n1, n2)
  p = deg2rad(elem.roll)

  Ax = elem.section.Ax
  J = elem.section.Jx
  Iy = elem.section.Iy
  Iz = elem.section.Iz

  t1, t2, t3, t4, t5, t6, t7, t8, t9 = coord_trans(n1, n2, L, p, vertical)

  m = zeros(12, 12)

  t = d * Ax * L
  ry = d * Iy
  rz = d * Iz
  po = d * J * L

  m[1,1]  = m[7,7]   = t / 3.0
  m[2,2]  = m[8,8]   = 13.0*t/35.0 + 6.0*rz/(5.0*L)
  m[3,3]  = m[9,9]   = 13.0*t/35.0 + 6.0*ry/(5.0*L)
  m[4,4]  = m[10,10] = po / 3.0
  m[5,5]  = m[11,11] = t*L*L/105.0 + 2.0*L*ry/15.0
  m[6,6]  = m[12,12] = t*L*L/105.0 + 2.0*L*rz/15.0

  m[5,3]  = m[3,5]   = -11.0*t*L/210.0 - ry/10.0
  m[6,2]  = m[2,6]   =  11.0*t*L/210.0 + rz/10.0
  m[7,1]  = m[1,7]   =  t / 6.0

  m[8,6]  = m[6,8]   =  13.0*t*L/420.0 - rz/10.0
  m[9,5]  = m[5,9]   = -13.0*t*L/420.0 + ry/10.0
  m[10,4] = m[4,10]  =  po / 6.0
  m[11,3] = m[3,11]  =  13.0*t*L/420.0 - ry/10.0
  m[12,2] = m[2,12]  = -13.0*t*L/420.0 + rz/10.0

  m[11,9] = m[9,11]  =  11.0*t*L/210.0 + ry/10.0
  m[12,8] = m[8,12]  = -11.0*t*L/210.0 - rz/10.0

  m[8,2]  = m[2,8]   =  9.0*t/70.0 - 6.0*rz/(5.0*L)
  m[9,3]  = m[3,9]   =  9.0*t/70.0 - 6.0*ry/(5.0*L)
  m[11,5] = m[5,11]  = -L*L*t/140.0 - ry*L/30.0
  m[12,6] = m[6,12]  = -L*L*t/140.0 - rz*L/30.0

  # rotatory inertia of extra beam mass is neglected
  for i in 1:3
    m[i,i] += 0.5 * EMs
  end
  for i in 7:9
    m[i,i] += 0.5 * EMs
  end

  local_to_global!(m, t1, t2, t3, t4, t5, t6, t7, t8, t9)

  return m
end

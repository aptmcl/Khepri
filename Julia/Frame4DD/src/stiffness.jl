"""
    elastic_K(elem, nodes, shear, vertical)

Compute the 12×12 elastic stiffness matrix for a frame element in global coordinates.

Returns a 12×12 Matrix{Float64}.
"""
function elastic_K(elem::FrameElement, nodes::Vector{Node}, shear::Bool, vertical::VerticalAxis)
  n1 = nodes[elem.node1]
  n2 = nodes[elem.node2]
  L = element_length(n1, n2)
  Le = L - n1.r - n2.r
  p = deg2rad(elem.roll)

  E = elem.material.E
  G = elem.material.G
  Ax = elem.section.Ax
  Asy = elem.section.Asy
  Asz = elem.section.Asz
  J = elem.section.Jx
  Iy = elem.section.Iy
  Iz = elem.section.Iz

  t1, t2, t3, t4, t5, t6, t7, t8, t9 = coord_trans(n1, n2, L, p, vertical)

  k = zeros(12, 12)

  if shear
    Ksy = 12.0 * E * Iz / (G * Asy * Le * Le)
    Ksz = 12.0 * E * Iy / (G * Asz * Le * Le)
  else
    Ksy = Ksz = 0.0
  end

  k[1,1]  = k[7,7]   = E * Ax / Le
  k[2,2]  = k[8,8]   = 12.0 * E * Iz / (Le^3 * (1.0 + Ksy))
  k[3,3]  = k[9,9]   = 12.0 * E * Iy / (Le^3 * (1.0 + Ksz))
  k[4,4]  = k[10,10] = G * J / Le
  k[5,5]  = k[11,11] = (4.0 + Ksz) * E * Iy / (Le * (1.0 + Ksz))
  k[6,6]  = k[12,12] = (4.0 + Ksy) * E * Iz / (Le * (1.0 + Ksy))

  k[5,3]  = k[3,5]   = -6.0 * E * Iy / (Le^2 * (1.0 + Ksz))
  k[6,2]  = k[2,6]   =  6.0 * E * Iz / (Le^2 * (1.0 + Ksy))
  k[7,1]  = k[1,7]   = -k[1,1]

  k[12,8] = k[8,12]  = k[8,6]  = k[6,8]  = -k[6,2]
  k[11,9] = k[9,11]  = k[9,5]  = k[5,9]  = -k[5,3]
  k[10,4] = k[4,10]  = -k[4,4]
  k[11,3] = k[3,11]  =  k[5,3]
  k[12,2] = k[2,12]  =  k[6,2]

  k[8,2]  = k[2,8]   = -k[2,2]
  k[9,3]  = k[3,9]   = -k[3,3]
  k[11,5] = k[5,11]  = (2.0 - Ksz) * E * Iy / (Le * (1.0 + Ksz))
  k[12,6] = k[6,12]  = (2.0 - Ksy) * E * Iz / (Le * (1.0 + Ksy))

  local_to_global!(k, t1, t2, t3, t4, t5, t6, t7, t8, t9)

  return k
end

"""
    geometric_K(elem, nodes, T_axial, shear, vertical)

Compute the 12×12 geometric stiffness matrix for a frame element in global coordinates.

`T_axial` is the axial tension force (positive = tension).
Returns a 12×12 Matrix{Float64}.
"""
function geometric_K(elem::FrameElement, nodes::Vector{Node}, T_axial::Float64, shear::Bool, vertical::VerticalAxis)
  n1 = nodes[elem.node1]
  n2 = nodes[elem.node2]
  L = element_length(n1, n2)
  Le = L - n1.r - n2.r
  p = deg2rad(elem.roll)

  E = elem.material.E
  G = elem.material.G
  Ax = elem.section.Ax
  Asy = elem.section.Asy
  Asz = elem.section.Asz
  J = elem.section.Jx
  Iy = elem.section.Iy
  Iz = elem.section.Iz

  t1, t2, t3, t4, t5, t6, t7, t8, t9 = coord_trans(n1, n2, L, p, vertical)

  kg = zeros(12, 12)
  T = T_axial

  if shear
    Ksy = 12.0 * E * Iz / (G * Asy * Le * Le)
    Ksz = 12.0 * E * Iy / (G * Asz * Le * Le)
    Dsy = (1 + Ksy)^2
    Dsz = (1 + Ksz)^2
  else
    Ksy = Ksz = 0.0
    Dsy = Dsz = 1.0
  end

  kg[1,1]  = kg[7,7]   = 0.0  # T/L (set to 0 in original)
  kg[2,2]  = kg[8,8]   = T / L * (1.2 + 2.0 * Ksy + Ksy^2) / Dsy
  kg[3,3]  = kg[9,9]   = T / L * (1.2 + 2.0 * Ksz + Ksz^2) / Dsz
  kg[4,4]  = kg[10,10] = T / L * J / Ax
  kg[5,5]  = kg[11,11] = T * L * (2.0/15.0 + Ksz/6.0 + Ksz^2/12.0) / Dsz
  kg[6,6]  = kg[12,12] = T * L * (2.0/15.0 + Ksy/6.0 + Ksy^2/12.0) / Dsy

  kg[1,7]  = kg[7,1]   = 0.0  # -T/L (set to 0 in original)

  kg[5,3]  = kg[3,5]   = kg[11,3] = kg[3,11] = -T / 10.0 / Dsz
  kg[9,5]  = kg[5,9]   = kg[11,9] = kg[9,11] =  T / 10.0 / Dsz
  kg[6,2]  = kg[2,6]   = kg[12,2] = kg[2,12] =  T / 10.0 / Dsy
  kg[8,6]  = kg[6,8]   = kg[12,8] = kg[8,12] = -T / 10.0 / Dsy

  kg[4,10] = kg[10,4]  = -kg[4,4]

  kg[8,2]  = kg[2,8]   = -T / L * (1.2 + 2.0 * Ksy + Ksy^2) / Dsy
  kg[9,3]  = kg[3,9]   = -T / L * (1.2 + 2.0 * Ksz + Ksz^2) / Dsz

  kg[11,5] = kg[5,11]  = -T * L * (1.0/30.0 + Ksz/6.0 + Ksz^2/12.0) / Dsz
  kg[12,6] = kg[6,12]  = -T * L * (1.0/30.0 + Ksy/6.0 + Ksy^2/12.0) / Dsy

  local_to_global!(kg, t1, t2, t3, t4, t5, t6, t7, t8, t9)

  return kg
end

"""
    element_length(n1, n2)

Compute the distance between two nodes.
"""
function element_length(n1::Node, n2::Node)
  dx = n2.x - n1.x
  dy = n2.y - n1.y
  dz = n2.z - n1.z
  return sqrt(dx^2 + dy^2 + dz^2)
end

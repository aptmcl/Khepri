using LinearAlgebra: norm

"""
    coord_trans(n1_pos, n2_pos, L, p, vertical)

Compute the 3×3 rotation matrix (direction cosines) for a frame element.

Returns a 3×3 matrix R where rows are the local x, y, z axes expressed in
global coordinates. The local x-axis points from node 1 to node 2.

`p` is the roll angle in radians.
"""
function coord_trans(n1_pos::Node, n2_pos::Node, L, p, vertical::VerticalAxis)
  Cx = (n2_pos.x - n1_pos.x) / L
  Cy = (n2_pos.y - n1_pos.y) / L
  Cz = (n2_pos.z - n1_pos.z) / L

  Cp = cos(p)
  Sp = sin(p)

  t1 = t2 = t3 = t4 = t5 = t6 = t7 = t8 = t9 = 0.0

  if vertical == ZVertical
    if abs(Cz) == 1.0
      t3 = Cz
      t4 = -Cz * Sp
      t5 = Cp
      t7 = -Cz * Cp
      t8 = -Sp
    else
      den = sqrt(1.0 - Cz * Cz)
      t1 = Cx
      t2 = Cy
      t3 = Cz
      t4 = (-Cx * Cz * Sp - Cy * Cp) / den
      t5 = (-Cy * Cz * Sp + Cx * Cp) / den
      t6 = Sp * den
      t7 = (-Cx * Cz * Cp + Cy * Sp) / den
      t8 = (-Cy * Cz * Cp - Cx * Sp) / den
      t9 = Cp * den
    end
  else  # YVertical
    if abs(Cy) == 1.0
      t2 = Cy
      t4 = -Cy * Cp
      t6 = Sp
      t7 = Cy * Sp
      t9 = Cp
    else
      den = sqrt(1.0 - Cy * Cy)
      t1 = Cx
      t2 = Cy
      t3 = Cz
      t4 = (-Cx * Cy * Cp - Cz * Sp) / den
      t5 = den * Cp
      t6 = (-Cy * Cz * Cp + Cx * Sp) / den
      t7 = (Cx * Cy * Sp - Cz * Cp) / den
      t8 = -den * Sp
      t9 = (Cy * Cz * Sp + Cx * Cp) / den
    end
  end

  return (t1, t2, t3, t4, t5, t6, t7, t8, t9)
end

"""
    build_transformation_matrix(t1..t9)

Build the 12×12 block-diagonal transformation matrix from 3×3 rotation.
"""
function build_transformation_matrix(t1, t2, t3, t4, t5, t6, t7, t8, t9)
  T = zeros(12, 12)
  for i in 0:3
    base = 3i
    T[base+1, base+1] = t1
    T[base+1, base+2] = t2
    T[base+1, base+3] = t3
    T[base+2, base+1] = t4
    T[base+2, base+2] = t5
    T[base+2, base+3] = t6
    T[base+3, base+1] = t7
    T[base+3, base+2] = t8
    T[base+3, base+3] = t9
  end
  return T
end

"""
    atma!(m, t1..t9)

In-place coordinate transformation: m = T' * m * T, where T is the 12×12
block-diagonal transformation matrix built from direction cosines t1..t9.

This implements the ATMA routine from Frame3DD. The finite node radius
effect on the transformation is not implemented (commented out in the
original C code as well).
"""
function atma!(m::Matrix{Float64}, t1, t2, t3, t4, t5, t6, t7, t8, t9)
  T = build_transformation_matrix(t1, t2, t3, t4, t5, t6, t7, t8, t9)

  # m = T' * m * T
  ma = m * T
  m .= T' * ma

  # enforce symmetry
  for i in 1:12
    for j in (i+1):12
      avg = 0.5 * (m[i,j] + m[j,i])
      m[i,j] = avg
      m[j,i] = avg
    end
  end

  return m
end

"""
    local_to_global!(k, t1..t9)

Transform a 12×12 local element matrix to global coordinates using
T' * k * T, then enforce symmetry. Modifies k in-place.
"""
function local_to_global!(k::Matrix{Float64}, t1, t2, t3, t4, t5, t6, t7, t8, t9)
  atma!(k, t1, t2, t3, t4, t5, t6, t7, t8, t9)
end

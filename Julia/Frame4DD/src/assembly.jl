"""
    dof_indices(node1, node2)

Return the 12 global DOF indices for a frame element connecting node1 and node2.
"""
function dof_indices(node1::Int, node2::Int)
  i1 = 6 * (node1 - 1)
  i2 = 6 * (node2 - 1)
  return (i1+1, i1+2, i1+3, i1+4, i1+5, i1+6,
          i2+1, i2+2, i2+3, i2+4, i2+5, i2+6)
end

"""
    assemble_K(model, Q, shear, geom)

Assemble the global stiffness matrix. Returns dense or sparse depending on
problem size vs `model.options.sparse_threshold`.
"""
function assemble_K(model::Model, Q::Matrix{Float64}, shear::Bool, geom::Bool)
  DoF = 6 * length(model.nodes)
  if DoF > model.options.sparse_threshold
    assemble_K_sparse(model, Q, shear, geom, DoF)
  else
    assemble_K_dense(model, Q, shear, geom, DoF)
  end
end

function assemble_K_dense(model::Model, Q::Matrix{Float64}, shear::Bool, geom::Bool, DoF::Int)
  vertical = model.options.vertical
  K = zeros(DoF, DoF)

  for (i, elem) in enumerate(model.elements)
    k = elastic_K(elem, model.nodes, shear, vertical)

    if geom
      T_axial = -Q[i, 1]
      kg = geometric_K(elem, model.nodes, T_axial, shear, vertical)
      k .+= kg
    end

    ind = dof_indices(elem.node1, elem.node2)
    for l in 1:12
      ii = ind[l]
      for ll in 1:12
        jj = ind[ll]
        K[ii, jj] += k[l, ll]
      end
    end
  end

  return K
end

function assemble_K_sparse(model::Model, Q::Matrix{Float64}, shear::Bool, geom::Bool, DoF::Int)
  nE = length(model.elements)
  vertical = model.options.vertical

  nnz_est = nE * 144
  Is = Vector{Int}(undef, nnz_est)
  Js = Vector{Int}(undef, nnz_est)
  Vs = Vector{Float64}(undef, nnz_est)

  pos = 0
  for (i, elem) in enumerate(model.elements)
    k = elastic_K(elem, model.nodes, shear, vertical)

    if geom
      T_axial = -Q[i, 1]
      kg = geometric_K(elem, model.nodes, T_axial, shear, vertical)
      k .+= kg
    end

    ind = dof_indices(elem.node1, elem.node2)
    for l in 1:12
      ii = ind[l]
      for ll in 1:12
        jj = ind[ll]
        pos += 1
        Is[pos] = ii
        Js[pos] = jj
        Vs[pos] = k[l, ll]
      end
    end
  end

  return sparse(Is, Js, Vs, DoF, DoF)
end

"""
    assemble_M(model, lumped)

Assemble the global mass matrix. Returns dense or sparse depending on
problem size vs `model.options.sparse_threshold`.
"""
function assemble_M(model::Model, lumped_flag::Bool)
  DoF = 6 * length(model.nodes)
  if DoF > model.options.sparse_threshold
    assemble_M_sparse(model, lumped_flag, DoF)
  else
    assemble_M_dense(model, lumped_flag, DoF)
  end
end

function assemble_M_dense(model::Model, lumped_flag::Bool, DoF::Int)
  nE = length(model.elements)
  vertical = model.options.vertical
  M = zeros(DoF, DoF)

  elem_extra_mass = zeros(nE)
  for em in model.element_extra_masses
    elem_extra_mass[em.element] += em.mass
  end

  for (i, elem) in enumerate(model.elements)
    d = elem.material.density
    EMs = elem_extra_mass[i]

    if lumped_flag
      m = lumped_M(elem, model.nodes, d, EMs, vertical)
    else
      m = consistent_M(elem, model.nodes, d, EMs, vertical)
    end

    ind = dof_indices(elem.node1, elem.node2)
    for l in 1:12
      ii = ind[l]
      for ll in 1:12
        jj = ind[ll]
        M[ii, jj] += m[l, ll]
      end
    end
  end

  for nm in model.node_masses
    base = 6 * (nm.node - 1)
    M[base+1, base+1] += nm.mass
    M[base+2, base+2] += nm.mass
    M[base+3, base+3] += nm.mass
    M[base+4, base+4] += nm.Ixx
    M[base+5, base+5] += nm.Iyy
    M[base+6, base+6] += nm.Izz
  end

  return M
end

function assemble_M_sparse(model::Model, lumped_flag::Bool, DoF::Int)
  nE = length(model.elements)
  vertical = model.options.vertical

  elem_extra_mass = zeros(nE)
  for em in model.element_extra_masses
    elem_extra_mass[em.element] += em.mass
  end

  nnz_est = nE * 144 + length(model.node_masses) * 6
  Is = Vector{Int}(undef, nnz_est)
  Js = Vector{Int}(undef, nnz_est)
  Vs = Vector{Float64}(undef, nnz_est)

  pos = 0
  for (i, elem) in enumerate(model.elements)
    d = elem.material.density
    EMs = elem_extra_mass[i]

    if lumped_flag
      m = lumped_M(elem, model.nodes, d, EMs, vertical)
    else
      m = consistent_M(elem, model.nodes, d, EMs, vertical)
    end

    ind = dof_indices(elem.node1, elem.node2)
    for l in 1:12
      ii = ind[l]
      for ll in 1:12
        jj = ind[ll]
        pos += 1
        Is[pos] = ii
        Js[pos] = jj
        Vs[pos] = m[l, ll]
      end
    end
  end

  for nm in model.node_masses
    base = 6 * (nm.node - 1)
    for (offset, mass_val) in enumerate((nm.mass, nm.mass, nm.mass, nm.Ixx, nm.Iyy, nm.Izz))
      pos += 1
      Is[pos] = base + offset
      Js[pos] = base + offset
      Vs[pos] = mass_val
    end
  end

  return sparse(Is[1:pos], Js[1:pos], Vs[1:pos], DoF, DoF)
end

"""
    assemble_forces!(F_mech, F_temp, eqF_mech, eqF_temp, model, lc)

Process all load types for a load case, building equivalent element forces
and global force vectors.
"""
function assemble_forces!(F_mech::Vector{Float64}, F_temp::Vector{Float64},
    eqF_mech::Matrix{Float64}, eqF_temp::Matrix{Float64},
    model::Model, lc::LoadCase)
  nE = length(model.elements)
  DoF = 6 * length(model.nodes)

  F_mech .= 0.0
  F_temp .= 0.0
  eqF_mech .= 0.0
  eqF_temp .= 0.0

  # Gravity loads (applied to all elements)
  compute_gravity_eqf!(eqF_mech, model, lc)

  # Uniform distributed loads
  compute_uniform_eqf!(eqF_mech, model, lc)

  # Trapezoidal distributed loads
  compute_trapezoidal_eqf!(eqF_mech, model, lc)

  # Internal point loads
  compute_point_load_eqf!(eqF_mech, model, lc)

  # Temperature loads
  compute_temperature_eqf!(eqF_temp, model, lc)

  # Concentrated nodal loads (directly into F_mech)
  for nl in lc.nodal_loads
    base = 6 * (nl.node - 1)
    F_mech[base+1] += nl.fx
    F_mech[base+2] += nl.fy
    F_mech[base+3] += nl.fz
    F_mech[base+4] += nl.mx
    F_mech[base+5] += nl.my
    F_mech[base+6] += nl.mz
  end

  # Scatter element equivalent forces to global vectors
  for n in 1:nE
    elem = model.elements[n]
    n1 = elem.node1
    n2 = elem.node2
    for i in 1:6
      F_mech[6*(n1-1)+i] += eqF_mech[n, i]
    end
    for i in 7:12
      F_mech[6*(n2-1)+i-6] += eqF_mech[n, i]
    end
    for i in 1:6
      F_temp[6*(n1-1)+i] += eqF_temp[n, i]
    end
    for i in 7:12
      F_temp[6*(n2-1)+i-6] += eqF_temp[n, i]
    end
  end
end

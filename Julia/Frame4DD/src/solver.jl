using LinearAlgebra: cholesky, Symmetric, norm, dot

"""
    build_dof_masks(model)

Build boolean vectors `q` (free DOFs) and `r` (restrained DOFs).
Returns `(q, r)` as BitVectors of length DoF.
"""
function build_dof_masks(model::Model)
  DoF = 6 * length(model.nodes)
  q = trues(DoF)   # free
  r = falses(DoF)  # restrained

  for (node, mask) in model.restraints
    base = 6 * (node - 1)
    for i in 1:6
      if mask[i]
        q[base+i] = false
        r[base+i] = true
      end
    end
  end

  return q, r
end

"""
    solve_partitioned(K, F, q, r, Dp)

Solve the partitioned system:
  K_qq * D_q = F_q - K_qr * D_r
  R_r = K_rr * D_r + K_rq * D_q - F_r

Returns `(D, R, rms_resid)`.
"""
function solve_partitioned(K, F::Vector{Float64},
    q::BitVector, r::BitVector, Dp::Vector{Float64})
  DoF = length(F)
  D = zeros(DoF)
  R = zeros(DoF)

  free_idx = findall(q)
  rest_idx = findall(r)

  # Set prescribed displacements
  D[rest_idx] .= Dp[rest_idx]

  K_qq = K[free_idx, free_idx]
  K_qr = K[free_idx, rest_idx]
  F_q = F[free_idx]
  D_r = D[rest_idx]

  # RHS = F_q - K_qr * D_r
  rhs = F_q - K_qr * D_r

  # Solve using Cholesky (dispatches to CHOLMOD for sparse)
  C = cholesky(Symmetric(K_qq))
  D_q = C \ rhs
  D[free_idx] .= D_q

  # Compute reactions: R_r = K[rest,:] * D - F[rest]
  KD = K * D
  R[rest_idx] .= KD[rest_idx] .- F[rest_idx]

  # RMS residual
  dF_free = F[free_idx] .- KD[free_idx]
  rms_resid = norm(dF_free) / max(norm(F_q), 1e-30)

  return D, R, rms_resid
end

"""
    frame_element_force(elem, nodes, D, eqF_temp, eqF_mech, shear, geom, vertical)

Compute the 12 local end forces for a single frame element.
Port of frame_element_force() from frame3dd.c.
"""
function frame_element_force!(s::Vector{Float64}, elem::FrameElement, nodes::Vector{Node},
    D::Vector{Float64}, eqF_temp_row::AbstractVector{Float64},
    eqF_mech_row::AbstractVector{Float64}, shear::Bool, geom::Bool,
    vertical::VerticalAxis)
  n1_node = nodes[elem.node1]
  n2_node = nodes[elem.node2]
  L = element_length(n1_node, n2_node)
  Le = L - n1_node.r - n2_node.r
  p = deg2rad(elem.roll)

  E = elem.material.E
  G = elem.material.G
  Ax = elem.section.Ax
  Asy = elem.section.Asy
  Asz = elem.section.Asz
  J = elem.section.Jx
  Iy = elem.section.Iy
  Iz = elem.section.Iz

  t1, t2, t3, t4, t5, t6, t7, t8, t9 = coord_trans(n1_node, n2_node, L, p, vertical)

  n1 = 6 * (elem.node1 - 1)
  n2 = 6 * (elem.node2 - 1)

  d1  = D[n1+1]; d2  = D[n1+2]; d3  = D[n1+3]
  d4  = D[n1+4]; d5  = D[n1+5]; d6  = D[n1+6]
  d7  = D[n2+1]; d8  = D[n2+2]; d9  = D[n2+3]
  d10 = D[n2+4]; d11 = D[n2+5]; d12 = D[n2+6]

  if shear
    Ksy = 12.0 * E * Iz / (G * Asy * Le * Le)
    Ksz = 12.0 * E * Iy / (G * Asz * Le * Le)
    Dsy = (1 + Ksy)^2
    Dsz = (1 + Ksz)^2
  else
    Ksy = Ksz = 0.0
    Dsy = Dsz = 1.0
  end

  s .= 0.0

  # Axial force
  s[1] = -(Ax*E/Le) * ((d7-d1)*t1 + (d8-d2)*t2 + (d9-d3)*t3)

  T = geom ? -s[1] : 0.0

  # Shear in local y
  s[2] = -(12.0*E*Iz/(Le^3*(1.0+Ksy)) +
           T/L*(1.2+2.0*Ksy+Ksy^2)/Dsy) *
          ((d7-d1)*t4 + (d8-d2)*t5 + (d9-d3)*t6) +
         (6.0*E*Iz/(Le^2*(1.0+Ksy)) + T/10.0/Dsy) *
          ((d4+d10)*t7 + (d5+d11)*t8 + (d6+d12)*t9)

  # Shear in local z
  s[3] = -(12.0*E*Iy/(Le^3*(1.0+Ksz)) +
           T/L*(1.2+2.0*Ksz+Ksz^2)/Dsz) *
          ((d7-d1)*t7 + (d8-d2)*t8 + (d9-d3)*t9) -
         (6.0*E*Iy/(Le^2*(1.0+Ksz)) + T/10.0/Dsz) *
          ((d4+d10)*t4 + (d5+d11)*t5 + (d6+d12)*t6)

  # Torsion
  s[4] = -(G*J/Le) * ((d10-d4)*t1 + (d11-d5)*t2 + (d12-d6)*t3)

  # Bending about local y at node 1
  s[5] = (6.0*E*Iy/(Le^2*(1.0+Ksz)) + T/10.0/Dsz) *
          ((d7-d1)*t7 + (d8-d2)*t8 + (d9-d3)*t9) +
         ((4.0+Ksz)*E*Iy/(Le*(1.0+Ksz)) +
          T*L*(2.0/15.0+Ksz/6.0+Ksz^2/12.0)/Dsz) *
          (d4*t4 + d5*t5 + d6*t6) +
         ((2.0-Ksz)*E*Iy/(Le*(1.0+Ksz)) -
          T*L*(1.0/30.0+Ksz/6.0+Ksz^2/12.0)/Dsz) *
          (d10*t4 + d11*t5 + d12*t6)

  # Bending about local z at node 1
  s[6] = -(6.0*E*Iz/(Le^2*(1.0+Ksy)) + T/10.0/Dsy) *
          ((d7-d1)*t4 + (d8-d2)*t5 + (d9-d3)*t6) +
         ((4.0+Ksy)*E*Iz/(Le*(1.0+Ksy)) +
          T*L*(2.0/15.0+Ksy/6.0+Ksy^2/12.0)/Dsy) *
          (d4*t7 + d5*t8 + d6*t9) +
         ((2.0-Ksy)*E*Iz/(Le*(1.0+Ksy)) -
          T*L*(1.0/30.0+Ksy/6.0+Ksy^2/12.0)/Dsy) *
          (d10*t7 + d11*t8 + d12*t9)

  s[7]  = -s[1]
  s[8]  = -s[2]
  s[9]  = -s[3]
  s[10] = -s[4]

  # Bending about local y at node 2
  s[11] = (6.0*E*Iy/(Le^2*(1.0+Ksz)) + T/10.0/Dsz) *
           ((d7-d1)*t7 + (d8-d2)*t8 + (d9-d3)*t9) +
          ((4.0+Ksz)*E*Iy/(Le*(1.0+Ksz)) +
           T*L*(2.0/15.0+Ksz/6.0+Ksz^2/12.0)/Dsz) *
           (d10*t4 + d11*t5 + d12*t6) +
          ((2.0-Ksz)*E*Iy/(Le*(1.0+Ksz)) -
           T*L*(1.0/30.0+Ksz/6.0+Ksz^2/12.0)/Dsz) *
           (d4*t4 + d5*t5 + d6*t6)

  # Bending about local z at node 2
  s[12] = -(6.0*E*Iz/(Le^2*(1.0+Ksy)) + T/10.0/Dsy) *
            ((d7-d1)*t4 + (d8-d2)*t5 + (d9-d3)*t6) +
           ((4.0+Ksy)*E*Iz/(Le*(1.0+Ksy)) +
            T*L*(2.0/15.0+Ksy/6.0+Ksy^2/12.0)/Dsy) *
            (d10*t7 + d11*t8 + d12*t9) +
           ((2.0-Ksy)*E*Iz/(Le*(1.0+Ksy)) -
            T*L*(1.0/30.0+Ksy/6.0+Ksy^2/12.0)/Dsy) *
            (d4*t7 + d5*t8 + d6*t9)

  # Transform fixed-end forces from global to local and subtract
  f1  = eqF_temp_row[1]  + eqF_mech_row[1]
  f2  = eqF_temp_row[2]  + eqF_mech_row[2]
  f3  = eqF_temp_row[3]  + eqF_mech_row[3]
  f4  = eqF_temp_row[4]  + eqF_mech_row[4]
  f5  = eqF_temp_row[5]  + eqF_mech_row[5]
  f6  = eqF_temp_row[6]  + eqF_mech_row[6]
  f7  = eqF_temp_row[7]  + eqF_mech_row[7]
  f8  = eqF_temp_row[8]  + eqF_mech_row[8]
  f9  = eqF_temp_row[9]  + eqF_mech_row[9]
  f10 = eqF_temp_row[10] + eqF_mech_row[10]
  f11 = eqF_temp_row[11] + eqF_mech_row[11]
  f12 = eqF_temp_row[12] + eqF_mech_row[12]

  # {Q} = [T]{f} — rotate global fixed-end forces to local and subtract
  s[1]  -= (f1*t1  + f2*t2  + f3*t3)
  s[2]  -= (f1*t4  + f2*t5  + f3*t6)
  s[3]  -= (f1*t7  + f2*t8  + f3*t9)
  s[4]  -= (f4*t1  + f5*t2  + f6*t3)
  s[5]  -= (f4*t4  + f5*t5  + f6*t6)
  s[6]  -= (f4*t7  + f5*t8  + f6*t9)

  s[7]  -= (f7*t1  + f8*t2  + f9*t3)
  s[8]  -= (f7*t4  + f8*t5  + f9*t6)
  s[9]  -= (f7*t7  + f8*t8  + f9*t9)
  s[10] -= (f10*t1 + f11*t2 + f12*t3)
  s[11] -= (f10*t4 + f11*t5 + f12*t6)
  s[12] -= (f10*t7 + f11*t8 + f12*t9)

  return s
end

"""
    element_end_forces!(Q, model, D, eqF_temp, eqF_mech, shear, geom)

Compute end forces for all elements.
"""
function element_end_forces!(Q::Matrix{Float64}, model::Model, D::Vector{Float64},
    eqF_temp::Matrix{Float64}, eqF_mech::Matrix{Float64},
    shear::Bool, geom::Bool)
  vertical = model.options.vertical
  s = zeros(12)  # reusable buffer

  for (m, elem) in enumerate(model.elements)
    frame_element_force!(s, elem, model.nodes, D,
      view(eqF_temp, m, :), view(eqF_mech, m, :),
      shear, geom, vertical)
    Q[m, :] .= s
  end
end

"""
    equilibrium_error(F, K, D, q)

Compute the relative equilibrium error: ||dF_q|| / ||F_q||
where dF = F - K*D at free DOFs.
"""
function equilibrium_error(F::Vector{Float64}, K,
    D::Vector{Float64}, q::BitVector)
  free_idx = findall(q)

  KD = K * D
  ss_dF = 0.0
  ss_F = 0.0
  for i in free_idx
    dfi = F[i] - KD[i]
    ss_dF += dfi * dfi
    ss_F += F[i] * F[i]
  end

  return sqrt(ss_dF) / sqrt(max(ss_F, 1e-30))
end

"""
    compute_reaction_forces(F, K, D, r)

Compute reaction forces: R(r) = [K(r,:)] * {D} - F(r)
"""
function compute_reaction_forces(F::Vector{Float64}, K,
    D::Vector{Float64}, r::BitVector)
  DoF = length(F)
  R = zeros(DoF)
  rest_idx = findall(r)
  KD = K * D
  R[rest_idx] .= KD[rest_idx] .- F[rest_idx]
  return R
end

"""
    solve(model::Model)

Main solve entry point. Orchestrates:
1. Validate model
2. Assemble loads for each load case
3. Solve each load case (with NR iteration if geometric)
4. Modal analysis if requested
5. Return AnalysisResults
"""
function solve(model::Model)
  nN = length(model.nodes)
  nE = length(model.elements)
  nL = length(model.load_cases)
  DoF = 6 * nN

  nN >= 2 || throw(ArgumentError("Model must have at least 2 nodes, got $nN"))
  nE >= 1 || throw(ArgumentError("Model must have at least 1 element, got $nE"))
  nL >= 1 || throw(ArgumentError("Model must have at least 1 load case, got $nL"))
  !isempty(model.restraints) || throw(ArgumentError("Model must have at least one restrained node"))

  shear = model.options.shear
  geom = model.options.geometric
  tol = model.options.tol
  vertical = model.options.vertical

  q, r = build_dof_masks(model)

  Q = zeros(nE, 12)

  lc_results = LoadCaseResults[]

  for (lc_idx, lc) in enumerate(model.load_cases)
    # Initialize
    D = zeros(DoF)
    R = zeros(DoF)
    Q .= 0.0

    # Assemble loads
    F_mech = zeros(DoF)
    F_temp = zeros(DoF)
    eqF_mech = zeros(nE, 12)
    eqF_temp = zeros(nE, 12)

    assemble_forces!(F_mech, F_temp, eqF_mech, eqF_temp, model, lc)

    # Build prescribed displacement vector
    Dp = zeros(DoF)
    for pd in lc.prescribed_displacements
      base = 6 * (pd.node - 1)
      Dp[base+1] = pd.dx
      Dp[base+2] = pd.dy
      Dp[base+3] = pd.dz
      Dp[base+4] = pd.rx
      Dp[base+5] = pd.ry
      Dp[base+6] = pd.rz
    end

    # Assemble elastic stiffness (Q=0 initially, so no geometric contribution)
    K = assemble_K(model, Q, shear, false)

    # First apply temperature loads only, if there are any
    has_temp = !isempty(lc.temperature_loads)
    if has_temp
      dD_temp, dR_temp, _ = solve_partitioned(K, F_temp, q, r, zeros(DoF))
      for i in 1:DoF
        if q[i]
          D[i] += dD_temp[i]
        end
      end
      for i in 1:DoF
        if r[i]
          R[i] += dR_temp[i]
        end
      end

      if geom
        element_end_forces!(Q, model, D, eqF_temp, eqF_mech, shear, geom)
        K = assemble_K(model, Q, shear, true)
      end
    end

    # Then apply mechanical loads
    has_mech = !isempty(lc.nodal_loads) || !isempty(lc.uniform_loads) ||
               !isempty(lc.trapezoidal_loads) || !isempty(lc.point_loads) ||
               !isempty(lc.prescribed_displacements) ||
               lc.gravity.gx != 0 || lc.gravity.gy != 0 || lc.gravity.gz != 0
    if has_mech
      # Set prescribed displacements for this solve
      dD_mech_dp = zeros(DoF)
      for i in 1:DoF
        if r[i]
          dD_mech_dp[i] = Dp[i]
        end
      end

      dD_mech, dR_mech, _ = solve_partitioned(K, F_mech, q, r, dD_mech_dp)
      for i in 1:DoF
        if q[i]
          D[i] += dD_mech[i]
        else
          D[i] = Dp[i]
        end
      end
      for i in 1:DoF
        if r[i]
          R[i] += dR_mech[i]
        end
      end
    end

    # Combine F = F_temp + F_mech
    F = F_temp .+ F_mech

    # Element end forces
    element_end_forces!(Q, model, D, eqF_temp, eqF_mech, shear, geom)

    # Equilibrium error
    K = assemble_K(model, Q, shear, geom)
    error_val = equilibrium_error(F, K, D, q)

    # Newton-Raphson iteration for geometric nonlinearity
    if geom
      error_val = 1.0
      iter = 0
      free_idx = findall(q)

      while error_val > tol && iter < 500
        iter += 1

        K = assemble_K(model, Q, shear, true)
        error_val = equilibrium_error(F, K, D, q)

        if error_val <= tol
          break
        end

        # Compute dF = F - K*D at free DOFs
        KD = K * D
        dF_q = F[free_idx] .- KD[free_idx]

        # Solve for increment (sparse Cholesky)
        K_qq = K[free_idx, free_idx]
        C = cholesky(Symmetric(K_qq))
        dD_q = C \ dF_q

        for (idx_i, gi) in enumerate(free_idx)
          D[gi] += dD_q[idx_i]
        end

        element_end_forces!(Q, model, D, eqF_temp, eqF_mech, shear, true)
      end

      # Recompute reactions for geometric nonlinear case
      R = compute_reaction_forces(F, K, D, r)
    end

    # Final equilibrium error
    K = assemble_K(model, Q, shear, geom)
    rms_resid = equilibrium_error(F, K, D, q)

    push!(lc_results, LoadCaseResults(copy(D), copy(R), copy(Q), rms_resid))
  end

  # Modal analysis
  modal_result = nothing
  if model.options.modal !== nothing
    modal_opts = model.options.modal

    nM = modal_opts.num_modes
    nM_calc = max(nM + 8, 2 * nM)
    lumped_flag = modal_opts.lumped

    # Reassemble K (with geometric stiffness from last load case if applicable)
    K = assemble_K(model, Q, shear, geom)
    M = assemble_M(model, lumped_flag)

    # Compute structural and total mass
    struct_mass = 0.0
    for elem in model.elements
      n1 = model.nodes[elem.node1]
      n2 = model.nodes[elem.node2]
      L = element_length(n1, n2)
      struct_mass += elem.material.density * elem.section.Ax * L
    end
    total_mass = struct_mass
    for nm in model.node_masses
      total_mass += nm.mass
    end
    for em in model.element_extra_masses
      total_mass += em.mass
    end

    # Penalize restrained DOFs
    traceK = 0.0
    traceM = 0.0
    for j in 1:DoF
      if !r[j]
        traceK += K[j, j]
        traceM += M[j, j]
      end
    end

    penalize_restrained_dofs!(K, r, traceK * 1e4)
    penalize_restrained_dofs!(M, r, traceM)
    if K isa SparseMatrixCSC
      dropzeros!(K)
      dropzeros!(M)
    end

    # Solve eigenvalue problem
    frequencies, mode_shapes = modal_solve(K, M, DoF, nM_calc,
      modal_opts.tol, modal_opts.shift, modal_opts.method)

    # Keep only requested number of modes
    frequencies = frequencies[1:min(nM, length(frequencies))]
    mode_shapes = mode_shapes[:, 1:min(nM, size(mode_shapes, 2))]

    modal_result = ModalResults(frequencies, mode_shapes, total_mass, struct_mass)
  end

  return AnalysisResults(lc_results, modal_result)
end

"""
    penalize_restrained_dofs!(A, r, penalty_diag)

Zero all entries in restrained rows/columns and set diagonal to penalty value.
Operates efficiently on sparse CSC matrices.
"""
function penalize_restrained_dofs!(A::SparseMatrixCSC, r::BitVector, penalty_diag::Float64)
  n = size(A, 1)
  rest_set = BitSet(findall(r))
  rv = rowvals(A)
  nz = nonzeros(A)

  for col in 1:n
    for idx in nzrange(A, col)
      row = rv[idx]
      if row in rest_set || col in rest_set
        nz[idx] = 0.0
      end
    end
  end

  for i in rest_set
    A[i, i] = penalty_diag
  end
end

function penalize_restrained_dofs!(A::Matrix{Float64}, r::BitVector, penalty_diag::Float64)
  n = size(A, 1)
  for i in 1:n
    if r[i]
      A[i, i] = penalty_diag
      for j in (i+1):n
        A[j, i] = A[i, j] = 0.0
        end
    end
  end
end

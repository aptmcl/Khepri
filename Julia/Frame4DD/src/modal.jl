using LinearAlgebra: cholesky, Symmetric, eigen, norm, tr, ldlt

"""
    modal_solve(K, M, n, nM_calc, tol, shift, method)

Solve the generalized eigenvalue problem K*V = w*M*V.

Returns `(frequencies, mode_shapes)` where frequencies are in Hz
and mode_shapes is n × nM_calc.
"""
function modal_solve(K, M, n::Int, nM_calc::Int, tol::Float64, shift::Float64,
    method::EigenMethod)
  if method == SubspaceJacobi
    w, V, iter = subspace_iteration(K, M, n, nM_calc, tol, shift)
  else
    w, V, iter = stodola_method(K, M, n, nM_calc, tol, shift)
  end

  # Convert eigenvalues to frequencies: f = sqrt(w) / (2π)
  frequencies = [sqrt(abs(wk)) / (2π) for wk in w]

  return frequencies, V
end

"""
    subspace_iteration(K, M, n, m, tol, shift)

Find the lowest m eigenvalues and eigenvectors using subspace/Jacobi iteration.
Port of subspace() from eig.c. Works with both dense and sparse K, M.
"""
function subspace_iteration(K_orig, M_orig, n::Int, m::Int, tol::Float64, shift::Float64)
  m = min(m, n)

  # Shift: K = K_orig + shift * M_orig (creates new matrix with correct sparsity)
  K = K_orig + shift * M_orig

  # Factorize shifted K (dispatches to CHOLMOD for sparse)
  K_fact = cholesky(Symmetric(K))

  # Initial guess based on K[i,i]/M[i,i] ratios
  d = [K_orig[i,i] / max(M_orig[i,i], 1e-30) for i in 1:n]

  # Sort and pick m indices with smallest ratios
  idx = sortperm(d)
  if length(idx) > m
    idx = idx[1:m]
  end

  V = zeros(n, m)
  for k in 1:m
    V[idx[k], k] = 1.0
    # Add small perturbation to neighboring DOFs
    off1 = idx[k] + 1
    off2 = idx[k] + 2
    if off1 <= n
      V[off1, k] = 0.2
    end
    if off2 <= n
      V[off2, k] = 0.2
    end
  end

  w = zeros(m)
  modes = max(div(m, 2), m - 8)
  modes = clamp(modes, 1, m)

  Kb = zeros(m, m)
  Mb_sub = zeros(m, m)
  Xb = zeros(n, m)

  w_old = 0.0
  error = 1.0
  iter = 0

  # Pre-compute K_sym for matrix-vector products
  K_sym = Symmetric(K)

  while error > tol && iter < 1000
    # K * Xb = M * V  →  Xb = K^{-1} * M * V
    for k in 1:m
      v = M_orig * V[:, k]
      Xb[:, k] = K_fact \ v
    end

    # Kb = Xb' * K * Xb  (using shifted K)
    KXb = K_sym * Xb
    mul!(Kb, Xb', KXb)

    # Mb = Xb' * M * Xb
    MXb = M_orig * Xb
    mul!(Mb_sub, Xb', MXb)

    # Solve reduced eigenproblem
    Kb_sym = Symmetric(0.5 .* (Kb .+ Kb'))
    Mb_sym = Symmetric(0.5 .* (Mb_sub .+ Mb_sub'))

    eig_result = eigen(Kb_sym, Mb_sym)
    w_sub = eig_result.values
    Qb_sub = eig_result.vectors

    # V = Xb * Qb
    mul!(V, Xb, Qb_sub)

    # Sort eigenvalues (ascending)
    perm = sortperm(w_sub)
    w .= w_sub[perm]
    V .= V[:, perm]

    # Check convergence on middle eigenvalue
    if w[modes] != 0.0
      error = abs(w[modes] - w_old) / abs(w[modes])
    end
    w_old = w[modes]

    iter += 1
  end

  # Unshift eigenvalues
  for k in 1:m
    if w[k] > shift
      w[k] = w[k] - shift
    else
      w[k] = shift - w[k]
    end
  end

  # Sort final results
  perm = sortperm(w)
  w .= w[perm]
  V .= V[:, perm]

  return w, V, iter
end

"""
    stodola_method(K, M, n, m, tol, shift)

Find the lowest m eigenvalues and eigenvectors using the Stodola method
(inverse iteration with deflation). Works with both dense and sparse K, M.
Avoids precomputing the dense K^{-1}*M matrix by solving on the fly.
"""
function stodola_method(K_orig, M_orig, n::Int, m::Int, tol::Float64, shift::Float64)
  m = min(m, n)

  # Shift: K = K_orig + shift * M
  K = K_orig + shift * M_orig

  # Factorize K (sparse Cholesky via CHOLMOD if sparse)
  K_fact = cholesky(Symmetric(K))

  # Approximate diagonal of K^{-1}*M for initial guess selection
  d_diag = [M_orig[i,i] / max(abs(K[i,i]), 1e-30) for i in 1:n]

  w = zeros(m)
  V = zeros(n, m)

  # Temp vectors for matrix-vector products
  Mu = zeros(n)
  Ku = zeros(n)

  total_iter = 0

  for k in 1:m
    # Initial guess: DOF with largest d_diag not yet used
    u = zeros(n)
    used_dofs = Set{Int}()
    for kk in 1:(k-1)
      _, idx = findmax(abs.(V[:, kk]))
      push!(used_dofs, idx)
    end

    # Find the DOF with largest d_diag among unused
    best_val = -Inf
    best_idx = 1
    for i in 1:n
      if d_diag[i] > best_val && !(i in used_dofs)
        best_val = d_diag[i]
        best_idx = i
      end
    end
    u[best_idx] = 1.0
    if best_idx + 1 <= n
      u[best_idx + 1] = 1e-4
    end

    # Mass-normalize
    mul!(Mu, M_orig, u)
    vMv = dot(u, Mu)
    u ./= sqrt(abs(vMv))

    # Purge lower modes
    for j in 1:(k-1)
      mul!(Mu, M_orig, u)
      c_j = dot(V[:, j], Mu)
      u .-= c_j .* V[:, j]
    end
    mul!(Mu, M_orig, u)
    vMv = dot(u, Mu)
    u ./= sqrt(abs(vMv))

    mul!(Ku, K, u)
    RQ = dot(u, Ku)
    RQold = 0.0

    local_iter = 0
    v = zeros(n)
    while true
      # v = K^{-1} * M * u  (sparse solve, no precomputed D)
      mul!(Mu, M_orig, u)
      v .= K_fact \ Mu

      # Mass-normalize
      mul!(Mu, M_orig, v)
      vMv = dot(v, Mu)
      v ./= sqrt(abs(vMv))

      # Purge lower modes
      for j in 1:(k-1)
        mul!(Mu, M_orig, v)
        c_j = dot(V[:, j], Mu)
        v .-= c_j .* V[:, j]
      end
      mul!(Mu, M_orig, v)
      vMv = dot(v, Mu)
      u .= v ./ sqrt(abs(vMv))

      RQold = RQ
      mul!(Ku, K, u)
      RQ = dot(u, Ku)
      total_iter += 1
      local_iter += 1

      if local_iter > 1000
        break
      end

      if abs(RQ - RQold) / max(abs(RQ), 1e-30) <= tol
        break
      end
    end

    mul!(Mu, M_orig, v)
    V[:, k] = v ./ sqrt(abs(dot(v, Mu)))

    mul!(Ku, K, u)
    w_k = dot(u, Ku)
    if w_k > shift
      w[k] = w_k - shift
    else
      w[k] = shift - w_k
    end
  end

  # Sort eigenvalues
  perm = sortperm(w)
  w .= w[perm]
  V .= V[:, perm]

  return w, V, total_iter
end

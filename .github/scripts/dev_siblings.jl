# Develop the in-repo Khepri packages that a package transitively depends on.
#
# Replaces the per-package CI step
#     julia --project=@. -e 'using Pkg; Pkg.develop(url="https://github.com/aptmcl/KhepriBase.jl")'
# which fetched the sibling from a repository that is now archived, and so tested
# the sibling's default branch rather than the sibling commit in this checkout.
#
# The closure matters: Khepri declares only KhepriAutoCAD, so a one-level walk
# would leave KhepriBase resolving from the registry -- defeating the fan-out in
# exactly the case it exists for.
#
# Only the TOML stdlib and the public Pkg API are used. Pkg.Types.read_project is
# internal and has no stability guarantee on nightly, which this runs on.
#
# Usage, from the repository root:
#   julia --project=Julia/<Pkg>      .github/scripts/dev_siblings.jl <Pkg>
#   julia --project=Julia/<Pkg>/docs .github/scripts/dev_siblings.jl <Pkg> --with-self

using Pkg
using TOML

const ROOT = "Julia"

khepri_deps(pkg) =
  let f = joinpath(ROOT, pkg, "Project.toml")
    isfile(f) || return String[]
    [d for d in keys(get(TOML.parsefile(f), "deps", Dict{String,Any}()))
       if startswith(d, "Khepri") && isdir(joinpath(ROOT, d))]
  end

closure(pkg) =
  let seen = Set{String}(), todo = khepri_deps(pkg)
    while !isempty(todo)
      d = pop!(todo)
      d in seen && continue
      push!(seen, d)
      append!(todo, khepri_deps(d))
    end
    sort!(collect(seen))
  end

isempty(ARGS) && error("usage: dev_siblings.jl <Package> [--with-self]")

let pkg = ARGS[1],
    with_self = length(ARGS) > 1 && ARGS[2] == "--with-self",
    paths = [joinpath(ROOT, d) for d in closure(pkg)]
  isdir(joinpath(ROOT, pkg)) || error("no such package: $(joinpath(ROOT, pkg))")
  with_self && pushfirst!(paths, joinpath(ROOT, pkg))
  if isempty(paths)
    @info "no in-repo Khepri packages to develop" package = pkg
  else
    @info "developing in-repo packages" package = pkg paths
    Pkg.develop([PackageSpec(path = p) for p in paths])
  end
end

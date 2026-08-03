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

# Any dependency that is present in this repository, NOT merely the ones named
# Khepri*. KhepriFrame4DD depends on Frame4DD -- a plain Julia solver with no
# Khepri in its name and no entry in the General registry -- so a Khepri-only
# filter would leave it unresolvable and the package unbuildable.
in_repo_deps(f) =
  isfile(f) ?
    [d for d in keys(get(TOML.parsefile(f), "deps", Dict{String,Any}()))
       if isdir(joinpath(ROOT, d))] :
    String[]

pkg_deps(pkg) = in_repo_deps(joinpath(ROOT, pkg, "Project.toml"))

closure(roots) =
  let seen = Set{String}(), todo = collect(roots)
    while !isempty(todo)
      d = pop!(todo)
      d in seen && continue
      push!(seen, d)
      append!(todo, pkg_deps(d))
    end
    sort!(collect(seen))
  end

isempty(ARGS) && error("usage: dev_siblings.jl <Package> [--with-self]")

let pkg = ARGS[1],
    with_self = length(ARGS) > 1 && ARGS[2] == "--with-self",
    # A docs environment may name in-repo packages the package itself does not
    # depend on -- KhepriFrame4DD's docs render with a backend it has no runtime
    # dependency on. Those are unregistered, so they must be developed by path or
    # Pkg.instantiate fails on the docs environment.
    roots = vcat(pkg_deps(pkg),
                 with_self ? in_repo_deps(joinpath(ROOT, pkg, "docs", "Project.toml")) : String[]),
    paths = [joinpath(ROOT, d) for d in closure(roots) if d != pkg]
  isdir(joinpath(ROOT, pkg)) || error("no such package: $(joinpath(ROOT, pkg))")
  with_self && pushfirst!(paths, joinpath(ROOT, pkg))
  if isempty(paths)
    @info "no in-repo Khepri packages to develop" package = pkg
  else
    @info "developing in-repo packages" package = pkg paths
    Pkg.develop([PackageSpec(path = p) for p in paths])
  end
end

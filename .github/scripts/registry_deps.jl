# Load a package with ALL of its dependencies resolved from the registry.
#
# Carried over from the `registry-deps` job of the per-package ci.yml, re-pointed
# from pwd() to Julia/<Pkg> and rewritten to use the TOML stdlib rather than the
# internal Pkg.Types.read_project.
#
# This job deliberately does NOT develop the siblings. Every other job does, which
# means nothing else ever loads a package against its own declared compat bounds --
# the resolution a registry user actually gets. KhepriAutoCAD v1.5.0 failed
# AutoMerge for exactly that reason: it called KhepriBase.curve_geometry_capabilities,
# absent from the registered 0.8.0 that a bound of "0.8" resolved to, while CI
# stayed green against master.
#
# Only meaningful for packages that are in the General registry; the caller
# restricts the matrix accordingly.
#
# Usage, from the repository root:
#   julia .github/scripts/registry_deps.jl <Pkg>

using Pkg
using TOML

isempty(ARGS) && error("usage: registry_deps.jl <Package>")

let pkg = ARGS[1],
    dir = abspath(joinpath("Julia", pkg))
  isdir(dir) || error("no such package: $dir")
  let project = TOML.parsefile(joinpath(dir, "Project.toml")),
      name = project["name"],
      uuid = Base.UUID(project["uuid"])
    Pkg.activate(mktempdir())
    Pkg.develop(path = dir)
    for (_, p) in Pkg.dependencies()
      if p.name !== nothing && p.name != name && startswith(p.name, "Khepri")
        @info "resolved from registry" package = p.name version = p.version
      end
    end
    Base.require(Base.PkgId(uuid, name))
    @info "loaded with registry-resolved dependencies" package = name
  end
end

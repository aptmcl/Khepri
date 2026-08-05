using Documenter
using Frame4DD

makedocs(
  sitename = "Frame4DD.jl",
  modules = [Frame4DD],
  pages = [
    "Home" => "index.md",
    "Tutorial" => "tutorial.md",
    "API Reference" => "api.md",
    "Internals" => "internals.md",
  ],
  format = Documenter.HTML(
    prettyurls = false,
    canonical = "https://aptmcl.github.io/Khepri/Frame4DD/stable",
    edit_link = "main",
  ),
  repo = Documenter.Remotes.GitHub("aptmcl", "Khepri"),
)

#=
build_docs.sh expects every package's make.jl to deploy itself; without
this block the Frame4DD docs built in CI and silently never deployed.
=#
deploydocs(
  repo = "github.com/aptmcl/Khepri.git",
  devbranch = "main",
  dirname = "Frame4DD",
  tag_prefix = "Frame4DD-",
)

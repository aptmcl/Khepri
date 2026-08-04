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
  ),
)

using KhepriRevit
using Documenter

makedocs(;
    modules=[KhepriRevit],
    authors="António Menezes Leitão <antonio.menezes.leitao@gmail.com>",
    repo=Documenter.Remotes.GitHub("aptmcl", "Khepri"),
    sitename="KhepriRevit.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://aptmcl.github.io/Khepri/KhepriRevit/stable",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Setup" => "setup.md",
        "Families" => "families.md",
        "BIM Elements" => "elements.md",
        "Geometry & Interop" => "geometry.md",
        "Code Generation" => "codegen.md",
    ],
)

deploydocs(;
    repo="github.com/aptmcl/Khepri.git",
    devbranch="main",
    dirname="KhepriRevit",
    tag_prefix="KhepriRevit-",
)

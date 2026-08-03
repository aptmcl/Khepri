using KhepriAutoCAD
using Documenter

makedocs(;
    modules=[KhepriAutoCAD],
    authors="António Menezes Leitão <antonio.menezes.leitao@gmail.com>",
    repo=Documenter.Remotes.GitHub("aptmcl", "Khepri"),
    sitename="KhepriAutoCAD.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://aptmcl.github.io/Khepri/KhepriAutoCAD/stable",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/aptmcl/Khepri.git",
    devbranch="main",
    dirname="KhepriAutoCAD",
    tag_prefix="KhepriAutoCAD-",
)

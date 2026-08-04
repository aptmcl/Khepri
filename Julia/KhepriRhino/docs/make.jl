using KhepriRhino
using Documenter

makedocs(;
    modules=[KhepriRhino],
    authors="António Menezes Leitão <antonio.menezes.leitao@gmail.com>",
    repo=Documenter.Remotes.GitHub("aptmcl", "Khepri"),
    sitename="KhepriRhino.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://aptmcl.github.io/Khepri/KhepriRhino/stable",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/aptmcl/Khepri.git",
    devbranch="main",
    dirname="KhepriRhino",
    tag_prefix="KhepriRhino-",
)

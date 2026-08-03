using KhepriUnity
using Documenter

makedocs(;
    modules=[KhepriUnity],
    authors="António Menezes Leitão <antonio.menezes.leitao@gmail.com>",
    repo=Documenter.Remotes.GitHub("aptmcl", "Khepri"),
    sitename="KhepriUnity.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://aptmcl.github.io/Khepri/KhepriUnity/stable",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/aptmcl/Khepri.git",
    devbranch="main",
    dirname="KhepriUnity",
    tag_prefix="KhepriUnity-",
)

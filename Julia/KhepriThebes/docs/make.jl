using KhepriThebes
using Documenter

DocMeta.setdocmeta!(KhepriThebes, :DocTestSetup, :(using KhepriThebes); recursive=true)

makedocs(;
    modules=[KhepriThebes],
    authors="António Menezes Leitão <antonio.menezes.leitao@gmail.com>",
    repo=Documenter.Remotes.GitHub("aptmcl", "Khepri"),
    sitename="KhepriThebes.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://aptmcl.github.io/Khepri/KhepriThebes/stable",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/aptmcl/Khepri.git",
    devbranch="main",
    dirname="KhepriThebes",
    tag_prefix="KhepriThebes-",
)

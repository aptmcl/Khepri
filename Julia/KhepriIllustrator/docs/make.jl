using KhepriIllustrator
using Documenter

DocMeta.setdocmeta!(KhepriIllustrator, :DocTestSetup, :(using KhepriIllustrator); recursive=true)

makedocs(;
    modules=[KhepriIllustrator],
    authors="António Menezes Leitão <antonio.menezes.leitao@gmail.com>",
    repo=Documenter.Remotes.GitHub("aptmcl", "Khepri"),
    sitename="KhepriIllustrator.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://aptmcl.github.io/Khepri/KhepriIllustrator/stable",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/aptmcl/Khepri.git",
    devbranch="main",
    dirname="KhepriIllustrator",
    tag_prefix="KhepriIllustrator-",
)

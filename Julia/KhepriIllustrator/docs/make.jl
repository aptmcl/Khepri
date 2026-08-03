using KhepriIllustrator
using Documenter

DocMeta.setdocmeta!(KhepriIllustrator, :DocTestSetup, :(using KhepriIllustrator); recursive=true)

makedocs(;
    modules=[KhepriIllustrator],
    authors="António Menezes Leitão <antonio.menezes.leitao@gmail.com>",
    repo="https://github.com/aptmcl/KhepriIllustrator.jl/blob/{commit}{path}#{line}",
    sitename="KhepriIllustrator.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://aptmcl.github.io/KhepriIllustrator.jl",
        edit_link="master",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/aptmcl/KhepriIllustrator.jl",
    devbranch="master",
)

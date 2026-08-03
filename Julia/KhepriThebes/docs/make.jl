using KhepriThebes
using Documenter

DocMeta.setdocmeta!(KhepriThebes, :DocTestSetup, :(using KhepriThebes); recursive=true)

makedocs(;
    modules=[KhepriThebes],
    authors="António Menezes Leitão <antonio.menezes.leitao@gmail.com>",
    repo="https://github.com/aptmcl/KhepriThebes.jl/blob/{commit}{path}#{line}",
    sitename="KhepriThebes.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://aptmcl.github.io/KhepriThebes.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/aptmcl/KhepriThebes.jl",
    devbranch="main",
)

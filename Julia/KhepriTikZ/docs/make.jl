using KhepriTikZ
using Documenter

makedocs(;
    modules=[KhepriTikZ],
    authors="António Menezes Leitão <antonio.menezes.leitao@gmail.com>",
    repo="https://github.com/aptmcl/KhepriTikZ.jl/blob/{commit}{path}#L{line}",
    sitename="KhepriTikZ.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://aptmcl.github.io/KhepriTikZ.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/aptmcl/KhepriTikZ.jl",
    devbranch="master",
)

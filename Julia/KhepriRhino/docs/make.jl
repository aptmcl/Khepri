using KhepriRhino
using Documenter

makedocs(;
    modules=[KhepriRhino],
    authors="António Menezes Leitão <antonio.menezes.leitao@gmail.com>",
    repo="https://github.com/aptmcl/KhepriRhino.jl/blob/{commit}{path}#L{line}",
    sitename="KhepriRhino.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://aptmcl.github.io/KhepriRhino.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/aptmcl/KhepriRhino.jl",
    devbranch="master",
)

using KhepriUnity
using Documenter

makedocs(;
    modules=[KhepriUnity],
    authors="António Menezes Leitão <antonio.menezes.leitao@gmail.com>",
    repo="https://github.com/aptmcl/KhepriUnity.jl/blob/{commit}{path}#L{line}",
    sitename="KhepriUnity.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://aptmcl.github.io/KhepriUnity.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/aptmcl/KhepriUnity.jl",
)

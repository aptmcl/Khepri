using KhepriUnreal
using Documenter

makedocs(;
    modules=[KhepriUnreal],
    authors="António Menezes Leitão <antonio.menezes.leitao@gmail.com>",
    repo="https://github.com/aptmcl/KhepriUnreal.jl/blob/{commit}{path}#L{line}",
    sitename="KhepriUnreal.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://aptmcl.github.io/KhepriUnreal.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/aptmcl/KhepriUnreal.jl",
)

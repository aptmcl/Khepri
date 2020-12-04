using KhepriBlender
using Documenter

makedocs(;
    modules=[KhepriBlender],
    authors="António Menezes Leitão <antonio.menezes.leitao@gmail.com>",
    repo="https://github.com/aptmcl/KhepriBlender.jl/blob/{commit}{path}#L{line}",
    sitename="KhepriBlender.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://aptmcl.github.io/KhepriBlender.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/aptmcl/KhepriBlender.jl",
)

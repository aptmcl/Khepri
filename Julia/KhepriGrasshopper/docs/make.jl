using KhepriGrasshopper
using Documenter

makedocs(;
    modules=[KhepriGrasshopper],
    authors="António Menezes Leitão <antonio.menezes.leitao@gmail.com>",
    repo="https://github.com/aptmcl/KhepriGrasshopper.jl/blob/{commit}{path}#L{line}",
    sitename="KhepriGrasshopper.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://aptmcl.github.io/KhepriGrasshopper.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/aptmcl/KhepriGrasshopper.jl",
)

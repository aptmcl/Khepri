using KhepriAutoCAD
using Documenter

makedocs(;
    modules=[KhepriAutoCAD],
    authors="António Menezes Leitão <antonio.menezes.leitao@gmail.com>",
    repo="https://github.com/aptmcl/KhepriAutoCAD.jl/blob/{commit}{path}#L{line}",
    sitename="KhepriAutoCAD.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://aptmcl.github.io/KhepriAutoCAD.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/aptmcl/KhepriAutoCAD.jl",
)

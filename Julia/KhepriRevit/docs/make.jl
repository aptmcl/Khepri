using KhepriRevit
using Documenter

makedocs(;
    modules=[KhepriRevit],
    authors="António Menezes Leitão <antonio.menezes.leitao@gmail.com>",
    repo="https://github.com/aptmcl/KhepriRevit.jl/blob/{commit}{path}#L{line}",
    sitename="KhepriRevit.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://aptmcl.github.io/KhepriRevit.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Setup" => "setup.md",
        "Families" => "families.md",
        "BIM Elements" => "elements.md",
        "Geometry & Interop" => "geometry.md",
    ],
)

deploydocs(;
    repo="github.com/aptmcl/KhepriRevit.jl",
    devbranch="master",
)

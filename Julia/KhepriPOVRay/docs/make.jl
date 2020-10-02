using KhepriPOVRay
using Documenter

makedocs(;
    modules=[KhepriPOVRay],
    authors="António Menezes Leitão <antonio.menezes.leitao@gmail.com>",
    repo="https://github.com/aptmcl/KhepriPOVRay.jl/blob/{commit}{path}#L{line}",
    sitename="KhepriPOVRay.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://aptmcl.github.io/KhepriPOVRay.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/aptmcl/KhepriPOVRay.jl",
)

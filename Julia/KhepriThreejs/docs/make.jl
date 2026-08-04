using KhepriThreejs
using Documenter

DocMeta.setdocmeta!(KhepriThreejs, :DocTestSetup, :(using KhepriThreejs); recursive=true)

makedocs(;
    modules=[KhepriThreejs],
    authors="António Menezes Leitão <antonio.menezes.leitao@gmail.com>",
    sitename="KhepriThreejs.jl",
    format=Documenter.HTML(;
        canonical="https://aptmcl.github.io/KhepriThreejs.jl",
        edit_link="master",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/aptmcl/KhepriThreejs.jl",
    devbranch="master",
)

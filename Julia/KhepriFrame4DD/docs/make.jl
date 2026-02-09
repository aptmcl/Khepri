using KhepriFrame4DD
using Documenter

DocMeta.setdocmeta!(KhepriFrame4DD, :DocTestSetup, :(using KhepriFrame4DD); recursive=true)

makedocs(;
    modules=[KhepriFrame4DD],
    authors="António Menezes Leitão <antonio.menezes.leitao@gmail.com>",
    sitename="KhepriFrame4DD.jl",
    format=Documenter.HTML(;
        canonical="https://aptmcl.github.io/KhepriFrame4DD.jl",
        edit_link="master",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/aptmcl/KhepriFrame4DD.jl",
    devbranch="master",
)

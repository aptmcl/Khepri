using KhepriThreejs
using Documenter

DocMeta.setdocmeta!(KhepriThreejs, :DocTestSetup, :(using KhepriThreejs); recursive=true)

makedocs(;
    modules=[KhepriThreejs],
    authors="António Menezes Leitão <antonio.menezes.leitao@gmail.com>",
    sitename="KhepriThreejs.jl",
    format=Documenter.HTML(;
        canonical="https://aptmcl.github.io/Khepri/KhepriThreejs/stable",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/aptmcl/Khepri.git",
    devbranch="main",
    dirname="KhepriThreejs",
    tag_prefix="KhepriThreejs-",
)

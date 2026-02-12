using KhepriLibrary
using Documenter

makedocs(;
    modules=[KhepriLibrary],
    authors="António Menezes Leitão <antonio.menezes.leitao@gmail.com>",
    repo="https://github.com/aptmcl/KhepriLibrary.jl/blob/{commit}{path}#L{line}",
    sitename="KhepriLibrary.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://aptmcl.github.io/KhepriLibrary.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/aptmcl/KhepriLibrary.jl",
    devbranch="master",
)

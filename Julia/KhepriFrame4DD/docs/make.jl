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
        "Tutorials" => [
            "Tutorial 1: Planar Truss" => "tutorials/tutorial1_planar_truss.md",
            "Tutorial 2: Warren Truss Bridge" => "tutorials/tutorial2_warren_bridge.md",
            "Tutorial 3: Space Truss Tower" => "tutorials/tutorial3_space_truss_tower.md",
            "Tutorial 4: Truss Grid Deck" => "tutorials/tutorial4_truss_grid_deck.md",
        ],
    ],
)

deploydocs(;
    repo="github.com/aptmcl/KhepriFrame4DD.jl",
    devbranch="master",
)

#=
We need material properties for structural analysis
=#

using DataFrames
using CSV

mats = DataFrame(CSV.File(joinpath(@__DIR__, "MaterialProperties.csv")))

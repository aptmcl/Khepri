using Test
using LinearAlgebra

@testset "Frame4DD" begin
  include("test_validation.jl")
  include("test_unit.jl")
  include("test_variants.jl")
  include("test_examples.jl")
  include("test_example_E.jl")
end

# KhepriLibrary tests — Reusable building component library
#
# Tests cover module loading, exported functions, and function
# signature verification for the test_cell parametric building.

using KhepriLibrary
using Test

@testset "KhepriLibrary.jl" begin

  @testset "Module loading" begin
    @test isdefined(KhepriLibrary, :test_cell)
  end

  @testset "test_cell is exported and callable" begin
    @test test_cell isa Function
    # Verify the method accepts keyword arguments (uses ... splat)
    m = first(methods(test_cell))
    kwds = Base.kwarg_decl(m)
    @test !isempty(kwds)
    # test_cell accepts keyword args via slurp; verify it's callable with them
    @test hasmethod(test_cell, Tuple{})
  end
end

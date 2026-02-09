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
    # Verify the method accepts keyword arguments
    m = first(methods(test_cell))
    @test :location in Base.kwarg_decl(m)
    @test :length in Base.kwarg_decl(m)
    @test :depth in Base.kwarg_decl(m)
    @test :height in Base.kwarg_decl(m)
    @test :wall_thickness in Base.kwarg_decl(m)
    @test :slab_thickness in Base.kwarg_decl(m)
  end
end

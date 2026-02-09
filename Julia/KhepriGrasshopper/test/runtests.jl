# KhepriGrasshopper tests — Grasshopper visual programming integration
#
# Tests cover module loading, GH type constructors, parameter formatting,
# IO function registry, and helper functions. Actual Grasshopper operations
# require Rhino/Grasshopper with the KhepriGrasshopper plugin.

using KhepriGrasshopper
using KhepriBase
using Test

@testset "KhepriGrasshopper.jl" begin

  @testset "GH type constructors" begin
    @test isdefined(KhepriGrasshopper, :GHNumber)
    @test isdefined(KhepriGrasshopper, :GHString)
    @test isdefined(KhepriGrasshopper, :GHBoolean)
    @test isdefined(KhepriGrasshopper, :GHPoint)
    @test isdefined(KhepriGrasshopper, :GHInteger)
    @test isdefined(KhepriGrasshopper, :GHVector)
    @test isdefined(KhepriGrasshopper, :GHPath)
    @test isdefined(KhepriGrasshopper, :GHAny)
  end

  @testset "Parameter formatting" begin
    # GHNumber with description returns [type, description, short, message, value]
    result = KhepriGrasshopper.GHNumber("radius")
    @test result isa Vector
    @test length(result) == 5
    @test result[1] == "Number"
    @test result[2] == "radius"

    # GHNumber with value returns same structure
    result2 = KhepriGrasshopper.GHNumber(3.14)
    @test result2[1] == "Number"
    @test result2[5] == 3.14

    # GHString default
    result3 = KhepriGrasshopper.GHString("label")
    @test result3[1] == "String"
    @test result3[2] == "label"

    # GHBoolean default
    result4 = KhepriGrasshopper.GHBoolean(true)
    @test result4[1] == "Boolean"
    @test result4[5] == true
  end

  @testset "IO function name registry" begin
    @test KhepriGrasshopper.kgh_io_function_names isa Vector{Symbol}
    @test !isempty(KhepriGrasshopper.kgh_io_function_names)
    @test :Number in KhepriGrasshopper.kgh_io_function_names
    @test :String in KhepriGrasshopper.kgh_io_function_names
    @test :Boolean in KhepriGrasshopper.kgh_io_function_names
    @test :Point in KhepriGrasshopper.kgh_io_function_names
  end

  @testset "is_kgh_io_function_name predicate" begin
    @test KhepriGrasshopper.is_kgh_io_function_name(:Number) == true
    @test KhepriGrasshopper.is_kgh_io_function_name(:String) == true
    @test KhepriGrasshopper.is_kgh_io_function_name(:NonExistent) == false
  end

  @testset "in_gh helper" begin
    @test KhepriGrasshopper.in_gh(:Number) === :GHNumber
    @test KhepriGrasshopper.in_gh(:String) === :GHString
    @test KhepriGrasshopper.in_gh(:Foo) === :GHFoo
  end

  @testset "kgh_forms parser" begin
    forms = KhepriGrasshopper.kgh_forms("1 + 2")
    @test !isempty(forms)
    @test forms[1] == :(1 + 2)

    forms2 = KhepriGrasshopper.kgh_forms("x = 1\ny = 2")
    @test length(forms2) == 2
  end
end

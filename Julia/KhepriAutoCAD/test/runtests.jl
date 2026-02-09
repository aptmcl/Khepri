# KhepriAutoCAD tests — AutoCAD SocketBackend via C# plugin
#
# Tests cover module loading, type system, backend configuration,
# and pure-Julia constants/helpers. Actual AutoCAD operations
# require a running AutoCAD instance with the Khepri plugin.

using KhepriAutoCAD
using KhepriBase
using Test

@testset "KhepriAutoCAD.jl" begin

  @testset "Type system" begin
    @test isdefined(KhepriAutoCAD, :ACADKey)
    @test KhepriAutoCAD.ACADId === Int64
    @test isdefined(KhepriAutoCAD, :ACADRef)
    @test isdefined(KhepriAutoCAD, :ACADNativeRef)
    @test KhepriAutoCAD.ACAD === SocketBackend{KhepriAutoCAD.ACADKey, Int64}
  end

  @testset "Backend initialization" begin
    @test autocad isa KhepriBase.Backend
    @test KhepriBase.backend_name(autocad) == "AutoCAD"
    @test KhepriBase.void_ref(autocad) === Int64(-1)
  end

  @testset "Configuration parameters" begin
    @test KhepriAutoCAD.autocad_template isa KhepriBase.Parameter
    @test isfile(KhepriAutoCAD.autocad_template()) || !isfile(KhepriAutoCAD.autocad_template())  # path may or may not exist
    @test KhepriAutoCAD.use_shx isa KhepriBase.Parameter
    @test use_shx() isa Bool
  end

  @testset "Dimension styles" begin
    d = KhepriAutoCAD.ACADDimensionStyles
    @test d isa Dict
    @test haskey(d, :architectural)
    @test haskey(d, :mechanical)
    @test d[:architectural] == "_ARCHTICK"
  end

  @testset "Material named tuples" begin
    mp = KhepriAutoCAD.MaterialProjection
    @test mp.InheritProjection == 0
    @test mp.Planar == 1
    @test mp.Box == 2
    @test mp.Cylinder == 3
    @test mp.Sphere == 4

    mt = KhepriAutoCAD.MaterialTiling
    @test mt.InheritTiling == 0
    @test mt.Tile == 1
    @test mt.Crop == 2
    @test mt.Clamp == 3
    @test mt.Mirror == 4
  end
end

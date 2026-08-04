using Test
using KhepriBase
using KhepriThreejs

# Access internal geometry helpers
const quad_strip_mesh_part = KhepriThreejs.quad_strip_mesh_part
const quad_strip_closed_mesh_part = KhepriThreejs.quad_strip_closed_mesh_part
const polygon_mesh_part = KhepriThreejs.polygon_mesh_part
const strip_mesh_part = KhepriThreejs.strip_mesh_part

@testset "BIM Geometry Helpers" begin
  @testset "quad_strip_mesh_part" begin
    # 2-point strip: 2 vertices on each edge → 1 quad → 2 triangles → 6 indices
    ps = [xyz(0, 0, 0), xyz(1, 0, 0)]
    qs = [xyz(0, 0, 1), xyz(1, 0, 1)]
    (vs, idxs, mat) = quad_strip_mesh_part(ps, qs, Int32(0))
    @test length(vs) == 4  # 2 pairs interleaved
    @test length(idxs) == 6  # 2 triangles
    @test mat == Int32(0)
    # Verify index bounds
    @test all(0 .<= idxs .< length(vs))
  end

  @testset "quad_strip_mesh_part 3 points" begin
    # 3-point strip: 3+3 vertices interleaved → 2 quads → 4 triangles → 12 indices
    ps = [xyz(0, 0, 0), xyz(1, 0, 0), xyz(2, 0, 0)]
    qs = [xyz(0, 1, 0), xyz(1, 1, 0), xyz(2, 1, 0)]
    (vs, idxs, mat) = quad_strip_mesh_part(ps, qs, Int32(1))
    @test length(vs) == 6  # 3 pairs
    @test length(idxs) == 12  # 4 triangles
    @test all(0 .<= idxs .< length(vs))
  end

  @testset "quad_strip_closed_mesh_part" begin
    # 3 points closed → wraps to 4 points → 3 quads → 18 indices
    ps = [xyz(0, 0, 0), xyz(1, 0, 0), xyz(1, 1, 0)]
    qs = [xyz(0, 0, 1), xyz(1, 0, 1), xyz(1, 1, 1)]
    (vs, idxs, mat) = quad_strip_closed_mesh_part(ps, qs, Int32(2))
    @test length(vs) == 8  # (3+1) pairs
    @test length(idxs) == 18  # 3 quads × 6 indices
    @test all(0 .<= idxs .< length(vs))
  end

  @testset "polygon_mesh_part triangle" begin
    ps = [xyz(0, 0, 0), xyz(1, 0, 0), xyz(0, 1, 0)]
    (vs, idxs, mat) = polygon_mesh_part(ps, Int32(0))
    @test length(vs) == 3
    @test length(idxs) == 3  # 1 triangle
    @test idxs == Int32[0, 1, 2]
  end

  @testset "polygon_mesh_part quad" begin
    ps = [xyz(0, 0, 0), xyz(1, 0, 0), xyz(1, 1, 0), xyz(0, 1, 0)]
    (vs, idxs, mat) = polygon_mesh_part(ps, Int32(0))
    @test length(vs) == 4
    @test length(idxs) == 6  # 2 triangles: (0,1,2), (0,2,3)
    @test idxs == Int32[0, 1, 2, 0, 2, 3]
  end

  @testset "polygon_mesh_part pentagon" begin
    ps = [xyz(cos(a), sin(a), 0) for a in range(0, 2π, length=6)[1:5]]
    (vs, idxs, mat) = polygon_mesh_part(ps, Int32(0))
    @test length(vs) == 5
    @test length(idxs) == 9  # 3 triangles
  end

  @testset "strip_mesh_part open paths" begin
    p1 = open_polygonal_path([xyz(0,0,0), xyz(1,0,0)])
    p2 = open_polygonal_path([xyz(0,0,1), xyz(1,0,1)])
    (vs, idxs, mat) = strip_mesh_part(p1, p2, Int32(0))
    @test length(vs) == 4
    @test length(idxs) == 6
  end

  @testset "strip_mesh_part closed paths" begin
    p1 = closed_polygonal_path([xyz(0,0,0), xyz(1,0,0), xyz(1,1,0)])
    p2 = closed_polygonal_path([xyz(0,0,1), xyz(1,0,1), xyz(1,1,1)])
    (vs, idxs, mat) = strip_mesh_part(p1, p2, Int32(0))
    @test length(vs) == 8  # closed: 3+1 pairs
    @test length(idxs) == 18  # 3 quads
  end
end

@testset "MeshPart Encoding" begin
  @testset "single MeshPart round-trip" begin
    vs = [xyz(0,0,0), xyz(1,0,0), xyz(0,1,0)]
    idxs = Int32[0, 1, 2]
    mat = Int32(7)
    part = (vs, idxs, mat)

    io = IOBuffer()
    KhepriThreejs.encode(Val(:THR), Val(:MeshPart), io, part)
    # Verify bytes were written (ArrayFloat32: 4+3*3*4=40, ArrayInt32: 4+3*4=16, Int32: 4 = 60 total)
    @test position(io) == 60
  end

  @testset "Vector{MeshPart} encoding" begin
    parts = [
      ([xyz(0,0,0), xyz(1,0,0), xyz(0,1,0)], Int32[0, 1, 2], Int32(1)),
      ([xyz(0,0,0), xyz(1,0,0), xyz(1,1,0), xyz(0,1,0)], Int32[0, 1, 2, 0, 2, 3], Int32(2)),
    ]

    io = IOBuffer()
    # Vector encode uses an instance as type descriptor, matching how @remote dispatches
    KhepriThreejs.encode(Val(:THR), Val{:MeshPart}[Val(:MeshPart)], io, parts)
    @test position(io) > 0
  end
end

@testset "Remote API Parsing" begin
  @testset "BIM operations registered" begin
    api = KhepriThreejs.threejs_api
    # The API is a NamedTuple; BIM op names should be present as fields
    @test hasproperty(api, :wall)
    @test hasproperty(api, :stair)
    @test hasproperty(api, :spiralStair)
    @test hasproperty(api, :groupedMesh)
    @test hasproperty(api, :wallWithOpenings)
    @test hasproperty(api, :railing)
  end
end

@testset "Float32 array encoding" begin
  # wallWithOpenings sends [Float32] arrays for opening specs
  io = IOBuffer()
  vals = Float32[1.5, 0.0, 1.0, 2.1]
  KhepriThreejs.encode(Val(:THR), Val{:Float32}[Val(:Float32)], io, vals)
  data = take!(io)
  buf = IOBuffer(data)
  n = read(buf, Int32)
  @test n == 4
  decoded = [read(buf, Float32) for _ in 1:n]
  @test decoded ≈ vals
end

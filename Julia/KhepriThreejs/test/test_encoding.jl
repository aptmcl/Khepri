using Test

@testset "Encoding/Decoding" begin
    # Primitive types (delegated to TS)
    @testset "Primitives" begin
        io = IOBuffer()
        KhepriThreejs.encode(Val(:THR), Val(:int), io, Int32(42))
        seekstart(io)
        @test KhepriThreejs.decode(Val(:THR), Val(:int), io) == Int32(42)

        io = IOBuffer()
        KhepriThreejs.encode(Val(:THR), Val(:float), io, Float32(3.14))
        seekstart(io)
        @test KhepriThreejs.decode(Val(:THR), Val(:float), io) ≈ Float32(3.14)

        io = IOBuffer()
        KhepriThreejs.encode(Val(:THR), Val(:bool), io, true)
        seekstart(io)
        @test KhepriThreejs.decode(Val(:THR), Val(:bool), io) == true

        io = IOBuffer()
        KhepriThreejs.encode(Val(:THR), Val(:String), io, "Hello Khepri")
        seekstart(io)
        @test KhepriThreejs.decode(Val(:THR), Val(:String), io) == "Hello Khepri"
    end

    @testset "Geometry Types" begin
        # Point3d
        p = xyz(1.0, 2.0, 3.0)
        io = IOBuffer()
        KhepriThreejs.encode(Val(:THR), Val(:Point3d), io, p)
        seekstart(io)
        decoded_p = KhepriThreejs.decode(Val(:THR), Val(:Point3d), io)
        @test decoded_p.x ≈ 1.0
        @test decoded_p.y ≈ 2.0
        @test decoded_p.z ≈ 3.0

        # Vector3d
        v = vxyz(4.0, 5.0, 6.0)
        io = IOBuffer()
        KhepriThreejs.encode(Val(:THR), Val(:Vector3d), io, v)
        seekstart(io)
        decoded_v = KhepriThreejs.decode(Val(:THR), Val(:Vector3d), io)
        @test decoded_v.x ≈ 4.0
        @test decoded_v.y ≈ 5.0
        @test decoded_v.z ≈ 6.0

        # Point2d
        p2 = xy(7.0, 8.0)
        io = IOBuffer()
        KhepriThreejs.encode(Val(:THR), Val(:Point2d), io, p2)
        seekstart(io)
        decoded_p2 = KhepriThreejs.decode(Val(:THR), Val(:Point2d), io)
        @test decoded_p2.x ≈ 7.0
        @test decoded_p2.y ≈ 8.0

        # Vector2d
        v2 = vxy(9.0, 10.0)
        io = IOBuffer()
        KhepriThreejs.encode(Val(:THR), Val(:Vector2d), io, v2)
        seekstart(io)
        decoded_v2 = KhepriThreejs.decode(Val(:THR), Val(:Vector2d), io)
        @test decoded_v2.x ≈ 9.0
        @test decoded_v2.y ≈ 10.0
    end

    @testset "Frames" begin
        # Frame3d
        # Use a frame constructed from origin and vectors to ensure it's not just world_cs
        frame = u0(cs_from_o_vx_vy_vz(xyz(1,2,3), vxyz(1,0,0), vxyz(0,1,0), vxyz(0,0,1)))

        io = IOBuffer()
        KhepriThreejs.encode(Val(:THR), Val(:Frame3d), io, frame)
        seekstart(io)
        decoded_frame = KhepriThreejs.decode(Val(:THR), Val(:Frame3d), io)

        # Check origin
        @test decoded_frame.x ≈ 1.0
        @test decoded_frame.y ≈ 2.0
        @test decoded_frame.z ≈ 3.0

        # Check transform (identity in this case for rotation part)
        t = decoded_frame.cs.transform
        @test t[1,1] ≈ 1.0
        @test t[2,2] ≈ 1.0
        @test t[3,3] ≈ 1.0
    end
end

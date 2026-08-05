# Khepri meta-package tests.
#
# The package's entire contract is `@reexport using KhepriAutoCAD`: a user who
# writes `using Khepri` must get the full Khepri API, a registered (but not
# connected!) AutoCAD default backend, and the ability to point the same code
# at any other backend. Everything here runs headless against the MockBackend —
# a geometry operation must never reach the default autocad backend, whose
# reconnect loop blocks for ~80 s before erroring.

using Khepri
#=
import, not using, and introspection names KhepriBase-qualified: the point
of this suite is that USER-visible names resolve through Khepri alone, so
nothing else may contribute bindings for them. (TestMockBackend.jl below
does `using KhepriBase` internally, which is why the qualification — not
the import — is what actually keeps the exercised names Khepri's.)
=#
import KhepriBase
using Test

include(joinpath(pkgdir(KhepriBase), "test", "TestMockBackend.jl"))

@testset "Khepri.jl" begin

  @testset "reexport surface" begin
    # THE meta-package test: everything KhepriAutoCAD exports, Khepri exports.
    @test isempty(setdiff(names(KhepriAutoCAD), names(Khepri)))
    # Spot-check the names user scripts live on.
    for n in (:sphere, :box, :cylinder, :line, :circle, :surface_polygon,
              :xyz, :material, :current_backend, :backend, :with,
              :delete_all_shapes, :autocad)
      @test isdefined(Khepri, n)
    end
  end

  @testset "default backend registered but not connected" begin
    # __init__ must register autocad as the default AND must not have tried
    # to connect at load time (connecting requires a live AutoCAD).
    @test any(b -> b === KhepriAutoCAD.autocad, KhepriBase.current_backends())
    @test KhepriAutoCAD.autocad.connection === missing
  end

  @testset "backend switching" begin
    let m1 = MockBackend(), m2 = MockBackend()
      KhepriBase.with(KhepriBase.current_backends, (m1,)) do
        @test KhepriBase.top_backend() === m1
        backend(m2)
        @test KhepriBase.top_backend() === m2
      end
      # The with-block restored the default.
      @test any(b -> b === KhepriAutoCAD.autocad, KhepriBase.current_backends())
    end
  end

  @testset "a design runs headless through Khepri-exported names" begin
    with_mock_backend() do b
      sphere(xyz(0, 0, 0), 1)
      box(xyz(3, 0, 0), 1, 1, 1)
      cylinder(xyz(6, 0, 0), 0.5, 2)
      surface_polygon(xyz(0, 3, 0), xyz(2, 3, 0), xyz(1, 5, 0))
      let stats = mock_geometry_stats(b)
        @test stats.triangles > 0
      end
    end
  end

end

# KhepriLibrary tests — Reusable building component library
#
# Executes test_cell headless against KhepriBase's MockBackend and checks
# the geometry it produces.

using KhepriLibrary
using KhepriBase
using Test

# Same mock backend KhepriBase's own runtests includes (KhepriBase/test/runtests.jl)
include(joinpath(pkgdir(KhepriBase), "test", "TestMockBackend.jl"))

@testset "KhepriLibrary.jl" begin

  @testset "Module loading" begin
    @test isdefined(KhepriLibrary, :test_cell)
    @test test_cell isa Function
  end

  @testset "test_cell builds headless with the roof at the wall top" begin
    let b = mock_backend()
      reset_mock_backend!(b)
      # No family registration needed: test_cell's with_window_family on a bare
      # MockBackend is exactly the element -> template -> default(element) cycle
      # that used to recurse forever in KhepriBase's family delegation, so this
      # test doubles as the regression test for that fix (BIM.jl seen-set walk).
      with(current_backend, b) do
        let r = test_cell(height=5)
          # The roof must sit at the height keyword, not at the positional default
          @test r.level.height == 5
          let walls = all_walls(b)
            @test length(walls) == 1
            @test walls[1].top_level.height == 5
            @test r.level.height == walls[1].top_level.height
          end
          @test mock_geometry_stats(b).triangles > 0
        end
      end
    end
  end

end

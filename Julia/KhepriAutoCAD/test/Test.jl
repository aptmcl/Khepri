using Test
using KhepriAutoCAD



@testset "Boolean Operations" begin
  @test is_sphere(sphere())
  @test is_united(union(sphere(), sphere(x(1))))
  @test is_intersected(intersection(sphere(), sphere(x(1))))
end



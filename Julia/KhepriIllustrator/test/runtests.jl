# KhepriIllustrator tests — Julia reader, evaluator, and illustrated operations
#
# Tests cover the JuliaReader (push/pop string, julia_read, @jl_str),
# JuliaEvaluator (Binding, Environment), and module loading.

using KhepriIllustrator
using Test

@testset "KhepriIllustrator.jl" begin

  @testset "JuliaReader" begin
    @testset "julia_read on IOBuffer" begin
      expr = KhepriIllustrator.julia_read(IOBuffer("1 + 2"))
      @test expr == :(1 + 2)
    end

    @testset "julia_read parses first expression" begin
      expr = KhepriIllustrator.julia_read(IOBuffer("x * y z"))
      @test expr == :(x * y)
    end

    @testset "push_string / pop_string" begin
      # Ensure clean state
      KhepriIllustrator.pushed_string[] = nothing

      KhepriIllustrator.push_string("hello")
      @test KhepriIllustrator.is_string_pushed()
      result = KhepriIllustrator.pop_string()
      @test result == "hello"
      @test !KhepriIllustrator.is_string_pushed()
    end

    @testset "push_string error on double push" begin
      KhepriIllustrator.pushed_string[] = nothing
      KhepriIllustrator.push_string("first")
      @test_throws ErrorException KhepriIllustrator.push_string("second")
      # Clean up
      KhepriIllustrator.pushed_string[] = nothing
    end

    @testset "@jl_str macro" begin
      expr = jl"x + y"
      @test expr == :(x + y)
    end
  end

  @testset "JuliaEvaluator" begin
    @testset "Binding struct" begin
      b = KhepriIllustrator.make_binding(:x, 42)
      @test KhepriIllustrator.binding_name(b) === :x
      @test KhepriIllustrator.binding_value(b) == 42
      KhepriIllustrator.set_binding_value!(b, 99)
      @test KhepriIllustrator.binding_value(b) == 99
    end

    @testset "Environment" begin
      env = KhepriIllustrator.create_initial_environment(:x => 1, :y => 2)
      @test env isa KhepriIllustrator.Environment
      @test isnothing(env.parent)
      @test length(env.bindings) == 2
    end

    @testset "augment_environment" begin
      parent = KhepriIllustrator.create_initial_environment(:x => 1)
      child = KhepriIllustrator.augment_environment([:y], [2], parent)
      @test child.parent === parent
      @test length(child.bindings) == 1
      @test KhepriIllustrator.binding_name(child.bindings[1]) === :y
    end

    @testset "get_environment_binding" begin
      env = KhepriIllustrator.create_initial_environment(:x => 42)
      b = KhepriIllustrator.get_environment_binding(:x, env)
      @test KhepriIllustrator.binding_value(b) == 42
    end

    @testset "define_name! and update_name!" begin
      env = KhepriIllustrator.create_initial_environment()
      KhepriIllustrator.define_name!(:z, 100, env)
      b = KhepriIllustrator.get_environment_binding(:z, env)
      @test KhepriIllustrator.binding_value(b) == 100

      KhepriIllustrator.update_name!(:z, 200, env)
      @test KhepriIllustrator.binding_value(b) == 200
    end
  end
end

# Self-test for the b_* hook arity-conformance guard
# (see BackendHookConformanceTests.jl for why the guard exists).

include("BackendHookConformanceTests.jl")
using .BackendHookConformanceTests

#=
Scratch module holding a deliberately wrong-arity hook method. The backend
type is never instantiated; only the method table matters. KhepriBase
dispatches b_sphere(b, c, r, mat) — the 2-positional method below is exactly
the dead-code shape the guard must flag.
=#
module HookConformanceWrongArityScratch
  using KhepriBase
  struct ScratchKey end
  struct ScratchBackend <: KhepriBase.Backend{ScratchKey, Int} end
  KhepriBase.b_sphere(b::ScratchBackend, c) = 0
end

@testset "Hook arity conformance guard" begin
  #=
  Positive control: every b_* method the test suite defines at top level
  (MockBackend, MinimalTriangleBackend, RecordingExactBackend, ...) lives in
  Main, so a clean pass over Main proves the reference backends conform.
  =#
  @testset "reference backends pass clean" begin
    @test isempty(hook_arity_violations(@__MODULE__))
    run_hook_conformance(@__MODULE__)
  end

  @testset "wrong-arity method is flagged" begin
    let violations = hook_arity_violations(HookConformanceWrongArityScratch)
      @test length(violations) == 1
      @test violations[1].name === :b_sphere
      @test violations[1].backend_arities == ["2"]
      @test "4" in violations[1].khepribase_arities
    end
  end

  # Vararg handling: a Vararg method must count as matching any arity at or
  # above its minimum (both directions).
  @testset "vararg arities intersect" begin
    let fixed(n) = (arity = n, isva = false),
        va(n) = (arity = n, isva = true),
        isect = BackendHookConformanceTests.arities_intersect
      @test isect(fixed(3), va(2))
      @test !isect(fixed(1), va(2))
      @test isect(va(2), fixed(3))
      @test !isect(va(4), fixed(3))
      @test isect(va(5), va(1))
    end
  end

  @testset "ignore skips a hook by name" begin
    @test isempty(hook_arity_violations(HookConformanceWrongArityScratch;
                                        ignore=[:b_sphere]))
  end

  #=
  KhepriBase-internal backends are the guard's residual blind spot: their
  methods live in KhepriBase and therefore join the reference arity set, so
  a wrong arity there both escapes detection AND legitimizes the same dead
  arity in real backends. Pin the historical instance directly: every
  MeasureBackend b_realistic_sky method must carry an arity some generic
  (::Backend first argument) method of the hook also carries. The original
  bug was a 9-slot Measure no-op no caller could ever reach.
  =#
  @testset "Measure b_realistic_sky arities match the generic contract" begin
    let f = KhepriBase.b_realistic_sky,
        arity(m) = BackendHookConformanceTests.method_arity(m),
        first_arg(m) = fieldtypes(m.sig)[2],
        generic = [arity(m) for m in methods(f) if first_arg(m) === KhepriBase.Backend],
        measure = [m for m in methods(f) if first_arg(m) === KhepriBase.MeasureBackend]
      @test !isempty(measure)
      for m in measure
        @test any(g -> BackendHookConformanceTests.arities_intersect(arity(m), g), generic)
      end
    end
  end
end

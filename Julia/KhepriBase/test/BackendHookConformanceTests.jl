#=
BackendHookConformanceTests.jl — arity-conformance guard for b_* backend hooks

A backend method whose positional arity matches no KhepriBase-side arity of
the same hook compiles cleanly and is simply never dispatched: 4-arg
b_table/b_chair methods, a 7-arg Blender b_spotlight, and a 9-slot Measure
b_realistic_sky no-op all shipped as dead code while the frontends called
other arities. This guard makes that class of bug a test failure: for every
function owned by KhepriBase whose name starts with `b_`, each method a
backend module defines must have a positional arity that intersects the set
of arities KhepriBase itself defines for that hook (a KhepriBase-side
definition or caller of that arity exists). Vararg methods match any arity
at or above their minimum.

Usage in a backend's test suite:

    include(joinpath(dirname(pathof(KhepriBase)), "..", "test",
                     "BackendHookConformanceTests.jl"))
    using .BackendHookConformanceTests
    run_hook_conformance(MyBackendModule)

`ignore` skips hooks with a deliberate arity extension the backend dispatches
itself (rare — justify each entry with a comment at the call site).
=#
module BackendHookConformanceTests

using KhepriBase
using Test

export run_hook_conformance, hook_arity_violations

#=
Positional arity of a method, excluding the function slot. For a Vararg
method, `arity` is the minimum (Method.nargs counts the vararg slot as one
parameter, so two slots — function + vararg — are excluded).
=#
method_arity(m::Method) = (arity = Int(m.nargs) - (m.isva ? 2 : 1), isva = m.isva)

describe_arity(a) = a.isva ? ">=$(a.arity)" : string(a.arity)

# Two arity specs intersect when some call arity satisfies both.
arities_intersect(a, b) =
  a.isva ?
    (b.isva || b.arity >= a.arity) :
    (b.isva ? a.arity >= b.arity : a.arity == b.arity)

#=
Every generic function owned by KhepriBase whose name starts with `b_`,
deduplicated by function object (aliases such as `b_closed_line = b_polygon`
bind two names to one function).
=#
khepribase_b_functions() =
  let seen = Base.IdSet{Function}(),
      fs = Function[]
    for name in sort!(collect(names(KhepriBase; all=true)))
      startswith(string(name), "b_") || continue
      isdefined(KhepriBase, name) || continue
      let f = getglobal(KhepriBase, name)
        (f isa Function && parentmodule(f) === KhepriBase && !(f in seen)) || continue
        push!(seen, f)
        push!(fs, f)
      end
    end
    fs
  end

"""
    hook_arity_violations(backend_module; ignore=Symbol[])

For each KhepriBase-owned `b_*` function, find the methods `backend_module`
defines whose positional arity intersects no arity of the methods defined
outside `backend_module`. Returns a vector of
`(name, method, backend_arities, khepribase_arities)` named tuples.
"""
hook_arity_violations(backend_module::Module; ignore::Vector{Symbol}=Symbol[]) =
  let violations = @NamedTuple{name::Symbol, method::Method,
                               backend_arities::Vector{String},
                               khepribase_arities::Vector{String}}[]
    for f in khepribase_b_functions()
      nameof(f) in ignore && continue
      let ms = collect(methods(f)),
          backend_ms = [m for m in ms if m.module === backend_module],
          outside = [method_arity(m) for m in ms if m.module !== backend_module]
        isempty(backend_ms) && continue
        for m in backend_ms
          any(o -> arities_intersect(method_arity(m), o), outside) ||
            push!(violations,
                  (name = nameof(f),
                   method = m,
                   backend_arities = map(describe_arity ∘ method_arity, backend_ms),
                   khepribase_arities = map(describe_arity, outside)))
        end
      end
    end
    violations
  end

"""
    run_hook_conformance(backend_module; ignore=Symbol[])

Assert (via `@test`) that every `b_*` hook method `backend_module` defines is
dispatchable from KhepriBase. Each violation fails one `@test` whose recorded
value carries the hook name, the backend's arity list, and KhepriBase's.
"""
run_hook_conformance(backend_module::Module; ignore::Vector{Symbol}=Symbol[]) =
  @testset "b_* hook arity conformance: $(nameof(backend_module))" begin
    let violations = hook_arity_violations(backend_module; ignore=ignore)
      for v in violations
        @error "b_* hook arity mismatch — this method can never be dispatched" hook=v.name method=v.method backend_arities=v.backend_arities khepribase_arities=v.khepribase_arities
        # The failure's "Evaluated:" line shows the whole named tuple:
        # hook name, dead method, and both arity lists.
        @test v === nothing
      end
      isempty(violations) && @test true
    end
  end

end # module

# BackendTestScaffolding.jl — the one include a backend test suite needs.
#
# Before this module existed, thirteen runtests.jl files carried copy-pasted
# scaffolding: the IOBuffer capture helpers were triplicated, the hook-arity
# trailer was duplicated twelve times, the wait-for-backend loop had drifted
# into four mutually inconsistent variants, and KHEPRI_STRESS_SKIP was parsed
# in three suites while silently dead in the other three stress runners. One
# home for the helpers, and an include + re-export of the shared test modules,
# shrinks each package's share to a one-line include plus short calls.
#
# Deliberately depends ONLY on Test + KhepriBase (+ stdlib Sockets) — the same
# constraint VisualTests.jl documents: this file runs inside every backend's
# test target, so a new dependency here is a new test dependency for 13
# packages.
#
# Usage, from a backend's test/runtests.jl:
#   include(joinpath(pkgdir(KhepriBase), "test", "BackendTestScaffolding.jl"))
#   using .BackendTestScaffolding
module BackendTestScaffolding

using Test
using KhepriBase
# Reached through KhepriBase (which carries it as a regular dep) so this file
# adds no test-target dependency to the 13 packages that include it — same
# trick VisualTests.jl uses for Dates.
const Sockets = KhepriBase.Sockets

# The shared test modules, included once here so packages stop carrying the
# include+using pairs (VisualTests was included in six suites, the stress and
# conformance modules in six and seven). Their exported names are re-exported
# below, so `using .BackendTestScaffolding` is all a suite needs.
include("VisualTests.jl")
include("BackendStressTests.jl")
include("RPCConformanceTests.jl")
include("BackendHookConformanceTests.jl")
include("BackendConformanceTests.jl")
include("ExactGeometrySmokeTests.jl")
using .VisualTests
using .BackendStressTests
using .RPCConformanceTests
using .BackendHookConformanceTests
using .BackendConformanceTests
using .ExactGeometrySmokeTests

for m in (VisualTests, BackendStressTests, RPCConformanceTests,
          BackendHookConformanceTests, BackendConformanceTests,
          ExactGeometrySmokeTests)
  for n in names(m)
    n === nameof(m) && continue
    @eval export $n
  end
end

export gate_enabled, require_windows, io_output, clear_io!,
       stress_skip_from_env, wait_until, wait_for_connected_backend,
       wait_for_port, launch_detached, kill_by_image, hook_arity_guard,
       run_wire_benchmark

"Is the given test gate (e.g. \"KHEPRI_RHINO_TESTS\") switched on?"
gate_enabled(var) = get(ENV, var, "0") == "1"

"Error out of a gated block that only makes sense on Windows (live CAD apps)."
require_windows(what) =
  Sys.iswindows() || error("$(what) tests require Windows (the live application only runs there).")

# IO-backend output capture. The IOBackend connection IS an IOBuffer; these
# were triplicated as get_tikz_output/clear_tikz_buffer! (and svg/povray
# clones) with byte-identical bodies.
"Drain and return everything the IO backend has written so far."
io_output(b) = String(take!(KhepriBase.connection(b)))
"Discard everything the IO backend has written so far."
clear_io!(b) = (take!(KhepriBase.connection(b)); nothing)

"""
Parse KHEPRI_STRESS_SKIP (comma-separated category names) into the `skip`
argument for run_stress_tests. Every stress runner must route through this —
three of the six previously hard-coded `Symbol[]`, silently ignoring the env
var their sibling suites advertised.
"""
stress_skip_from_env(default=Symbol[]) =
  let s = get(ENV, "KHEPRI_STRESS_SKIP", "")
    isempty(s) ? default : Symbol.(strip.(split(s, ',')))
  end

"""
    wait_until(pred; timeout=900.0, interval=0.5, timeout_env=nothing, what="backend")

Poll `pred()` until it returns a non-`nothing`/non-`false` value and return
it, or `nothing` on timeout. When `timeout_env` names an environment
variable, its value (seconds) overrides `timeout` — the knob cold-cache CI
hosts need (the four hand-rolled copies of this loop had drifted to 30 s /
60 s / 900 s-env / 900 s-env with different poll intervals).
"""
wait_until(pred; timeout=900.0, interval=0.5, timeout_env=nothing, what="backend") =
  let limit = isnothing(timeout_env) ? timeout :
                let s = get(ENV, timeout_env, ""),
                    v = tryparse(Float64, s)
                  if !isempty(s) && isnothing(v)
                    # A typo like "1m" must be self-diagnosing, not a bare
                    # ArgumentError from deep inside a testset — and it must
                    # not abort a block whose external app already launched.
                    @warn "Ignoring unparsable $(timeout_env)=$(repr(s)) — expected seconds as a number; using default" default=timeout
                  end
                  something(v, timeout)
                end,
      deadline = time() + limit
    while time() < deadline
      let r = pred()
        (r === nothing || r === false) || return r
      end
      sleep(interval)
    end
    nothing
  end

"""
Wait for a remote app to register itself with the Julia-side socket server
(the Unity/Blender/Threejs pattern) and return the connected backend. `hint`
is appended to the error, typically naming the log file to check.
"""
wait_for_connected_backend(; hint="", kwargs...) =
  let b = wait_until(; what="connected backend", kwargs...) do
        let bs = KhepriBase.current_backends()
          isempty(bs) ? nothing : first(bs)
        end
      end
    b === nothing && error("Backend never connected to the Khepri socket server within timeout. $(hint)")
    b
  end

"""
Wait for a TCP listener on `port` (the Unreal pattern — the app is the
server). Returns `true`; errors with `hint` on timeout.
"""
wait_for_port(port; interval=2.0, hint="", kwargs...) =
  let ok = wait_until(; interval, what="port $(port)", kwargs...) do
        try
          close(Sockets.connect(port))
          true
        catch
          nothing
        end
      end
    ok === nothing && error("No listener appeared on port $(port) within timeout. $(hint)")
    true
  end

"Launch an external application detached, output discarded (it has its own log)."
launch_detached(cmd) = run(pipeline(cmd, stdout=devnull, stderr=devnull), wait=false)

"""
Best-effort teardown of an external app by image name (Windows taskkill).
`wait_gone=true` blocks (bounded) until no such process remains — needed
when the caller may relaunch the app immediately, since a fire-and-forget
kill races the next launch on the port and any file locks.
"""
kill_by_image(name; wait_gone=false) =
  try
    run(`taskkill /F /IM $(name)`, wait=wait_gone)
    if wait_gone
      wait_until(; timeout=30.0, interval=0.5, what="$(name) exit") do
        success(`tasklist /FI "IMAGENAME eq $(name)" /NH`) &&
          !occursin(name, read(`tasklist /FI "IMAGENAME eq $(name)" /NH`, String)) ?
          true : nothing
      end
    end
  catch
  end

"""
    run_wire_benchmark(b; ops=300, min_ops_per_second=100.0, max_median_ms=10.0)

Measure live RPC throughput against a connected socket backend and FAIL when
it degrades past the thresholds. Exists because socket-loop changes have
shipped performance regressions before (a batching collapse costs one host
idle tick per op — ~66 ms in Rhino — and only shows up against a live app,
which CI never runs). Run it whenever the C# Processor/Channel layer or a
plugin's loop integration changes.

Reports a burst benchmark (ops/s + per-RPC median/p95/max via
KhepriBase.rpc_timing) and a large-frame time (a 5000-point polyline).
Baseline on the reference machine, 2026-08-05, AutoCAD 2025: 867 ops/s,
median 0.39 ms, large frame 38.7 ms. The default thresholds are an order of
magnitude looser — they catch collapses, not noise.
"""
run_wire_benchmark(b; ops=300, min_ops_per_second=100.0, max_median_ms=10.0) =
  @testset "Wire benchmark" begin
    KhepriBase.with(KhepriBase.current_backend, b) do
      KhepriBase.delete_all_shapes()
      # Warm-up: compile the RPC path before timing it.
      for i in 1:10
        KhepriBase.sphere(KhepriBase.xyz(Float64(i), 0.0, 0.0), 0.2)
      end
      KhepriBase.delete_all_shapes()
      empty!(KhepriBase.rpc_times)
      KhepriBase.reset_rpc_count!()
      local wall
      KhepriBase.with(KhepriBase.rpc_timing, true) do
        let t = time()
          for i in 1:ops
            KhepriBase.sphere(KhepriBase.xyz(Float64(i % 30), Float64(i ÷ 30), 0.0), 0.2)
          end
          wall = time() - t
        end
      end
      isempty(KhepriBase.rpc_times) &&
        error("wire benchmark recorded no RPC times — did the backend connect?")
      let ts = sort(copy(KhepriBase.rpc_times)),
          med = ts[cld(length(ts), 2)],
          p95 = ts[max(1, ceil(Int, 0.95 * length(ts)))],
          rate = KhepriBase.rpc_count[] / wall
        @info "wire benchmark" backend = KhepriBase.backend_name(b) ops_per_second = round(rate, digits=1) median_ms = round(med, digits=2) p95_ms = round(p95, digits=2) max_ms = round(maximum(ts), digits=2)
        @test rate >= min_ops_per_second
        @test med <= max_median_ms
      end
      empty!(KhepriBase.rpc_times)
      KhepriBase.with(KhepriBase.rpc_timing, true) do
        KhepriBase.line([KhepriBase.xyz(Float64(i) / 100, sin(Float64(i) / 10), 0.0) for i in 1:5000])
      end
      @info "large frame (5000-pt line)" ms = round(KhepriBase.rpc_times[end], digits=1)
      KhepriBase.delete_all_shapes()
    end
  end

"""
    hook_arity_guard(backend_module)

Guard against silently-dead b_* methods: every hook method a backend defines
must have a positional arity KhepriBase actually dispatches — see
BackendHookConformanceTests.jl's header for the shipped bugs that motivated
this (4-arg table/chair trio, 7-arg Blender spotlight, 9-slot Measure sky).
Call as the LAST line of a backend's runtests.jl.
"""
hook_arity_guard(backend_module) =
  @testset "Hook arity conformance" begin
    run_hook_conformance(backend_module)
  end

end # module

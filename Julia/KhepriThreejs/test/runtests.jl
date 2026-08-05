using KhepriThreejs
using KhepriBase
using Test

include(joinpath(pkgdir(KhepriBase), "test", "BackendTestScaffolding.jl"))
using .BackendTestScaffolding

#= KhepriThreejs exports no static backend instance to probe: a THR is only
   constructed when a browser opens a WebSocket (KhepriThreejs.__init__
   registers `conn -> THR("Threejs", conn, threejs_api)` per connection), and
   WebSocketBackend's `websocket` field cannot be faked without a live
   HTTP.WebSockets.WebSocket. The RPC-conformance check needs only the
   declared-RPC NamedTuple and a backend name, so we hand it a minimal
   stand-in Backend carrying `threejs_api` directly — its keys are exactly
   the keys of a real instance's `:remote` field. =#
struct THRConformanceProbe <: KhepriBase.Backend{KhepriThreejs.THRKey, KhepriThreejs.THRId}
    remote::NamedTuple
end
KhepriBase.backend_name(::THRConformanceProbe) = "Threejs"

@testset "KhepriThreejs.jl" begin
    @testset "RPC Conformance (static)" begin
        # Every @remote/@get_remote RPC the adapter calls must be declared in
        # the @remote_api block. Catches the undeclared-RPC crash class at CI,
        # with no browser/WebSocket (parses source + reads threejs_api keys).
        run_rpc_conformance_tests(THRConformanceProbe(KhepriThreejs.threejs_api),
                                  joinpath(dirname(pathof(KhepriThreejs))))
    end

    include("test_encoding.jl")
    include("test_bim.jl")

    #=
    Combinatorial stress tests. Threejs is a WebSocketBackend — `using
    KhepriThreejs` only registers an HTTP/WS init handler; the actual `THR`
    backend instance is created when a browser navigates to the Khepri HTTP
    server, downloads `index.html`, and opens a WebSocket back to
    `ws://<host>/threejs`. So the test runner has to:

      1. Start the Khepri WebSocket server (LazyParameter — first access
         spawns it on port 12346 by default).
      2. Launch a browser pointed at `http://localhost:12346/`. Chrome with
         `--headless=new` is enough for the geometry-construction RPCs to
         execute (Three.js `Mesh` objects are pure data — no WebGL context
         needed for the dispatch, only for the render frame).
      3. Wait for the WebSocket connection to bind a backend in
         `KhepriBase.current_backends()`.
      4. Run the stress suite against that backend.
      5. Kill the browser process on the way out.

    Windows-only (the Chrome path is hard-coded for the CI host).
    Toggle with `KHEPRI_THREEJS_STRESS_TESTS=1`.
    =#
    if gate_enabled("KHEPRI_THREEJS_STRESS_TESTS")
        require_windows("Threejs stress")
        @testset "Stress (Threejs)" begin
            chrome = raw"C:\Program Files\Google\Chrome\Application\chrome.exe"
            isfile(chrome) || error("Chrome not found at $chrome")

            # Force the WebSocket server up so the browser has something to
            # connect to. Subsequent accesses are no-ops (LazyParameter).
            KhepriBase.khepri_websocket_server()
            url = "http://localhost:$(KhepriBase.default_khepri_websocket_server_port())/"

            # Use a unique --user-data-dir so we don't fight an existing Chrome
            # session for the profile lock. `--remote-debugging-port` is not
            # needed; --headless=new is enough.
            user_data = mktempdir(prefix="khepri_threejs_chrome_")
            chrome_proc = launch_detached(`$chrome --headless=new --disable-gpu
                                          --no-first-run --no-default-browser-check
                                          --user-data-dir=$user_data
                                          $url`)

            try
                connected_b = wait_for_connected_backend(
                    timeout=60.0, timeout_env="KHEPRI_THREEJS_BOOT_TIMEOUT",
                    hint="Is Chrome blocking the page?")

                run_stress_tests(connected_b,
                    reset! = () -> begin
                        delete_all_shapes()
                        backend(connected_b)
                    end,
                    verify = :envelope,
                    skip = stress_skip_from_env())
            finally
                # Kill our own Chrome via its Process handle — kill_by_image
                # would take down the user's browser session too.
                try
                    kill(chrome_proc)
                catch
                end
                # Best-effort cleanup of the temp profile
                try
                    rm(user_data; recursive=true, force=true)
                catch
                end
            end
        end
    end
end

hook_arity_guard(KhepriThreejs)

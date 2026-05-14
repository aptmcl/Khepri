using KhepriThreejs
using KhepriBase
using Test

@testset "KhepriThreejs.jl" begin
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

    Skipped on non-Windows (Chrome path is hard-coded for the CI host).
    Toggle with `KHEPRI_THREEJS_STRESS_TESTS=1`.
    =#
    if get(ENV, "KHEPRI_THREEJS_STRESS_TESTS", "0") == "1"
        if !Sys.iswindows()
            error("Threejs stress tests require Windows (Chrome path hard-coded). " *
                  "Set up an equivalent launcher and re-enable.")
        end
        @testset "Stress (Threejs)" begin
            include(joinpath(dirname(pathof(KhepriBase)), "..", "test", "BackendStressTests.jl"))
            using .BackendStressTests

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
            chrome_proc = run(pipeline(`$chrome --headless=new --disable-gpu
                                       --no-first-run --no-default-browser-check
                                       --user-data-dir=$user_data
                                       $url`,
                                       stdout=devnull, stderr=devnull),
                              wait=false)

            try
                connected_b = nothing
                let deadline = time() + 60
                    while time() < deadline
                        let bs = KhepriBase.current_backends()
                            if !isempty(bs)
                                connected_b = first(bs)
                                break
                            end
                        end
                        sleep(0.5)
                    end
                end
                connected_b === nothing &&
                    error("Threejs failed to connect within 60s — is Chrome blocking the page?")

                # Optional category skip via comma-separated env var, e.g.
                # `KHEPRI_STRESS_SKIP=curves,surfaces` to focus on a subset.
                skip = let s = get(ENV, "KHEPRI_STRESS_SKIP", "")
                    isempty(s) ? Symbol[] : Symbol.(strip.(split(s, ',')))
                end

                run_stress_tests(connected_b,
                    reset! = () -> begin
                        delete_all_shapes()
                        backend(connected_b)
                    end,
                    verify = :envelope,
                    skip = skip)
            finally
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

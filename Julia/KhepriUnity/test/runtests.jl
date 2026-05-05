# KhepriUnity tests — Unity SocketBackend via C# plugin
#
# Tests cover module loading, type system, backend configuration,
# family types, and NavMesh parameter. Actual Unity operations
# require a running Unity editor with the Khepri C# plugin.

using KhepriUnity
using KhepriBase
using KhepriBase: SocketBackend
using Test

@testset "KhepriUnity.jl" begin

  @testset "Type system" begin
    @test isdefined(KhepriUnity, :UnityKey)
    @test KhepriUnity.UnityId === Int32
    @test isdefined(KhepriUnity, :UnityRef)
    @test isdefined(KhepriUnity, :UnityNativeRef)
    @test KhepriUnity.Unity === SocketBackend{KhepriUnity.UnityKey, Int32}
  end

  @testset "Backend initialization" begin
    @test unity isa KhepriBase.Backend
    @test KhepriBase.backend_name(unity) == "Unity"
    @test KhepriBase.void_ref(unity) === Int32(-1)
  end

  @testset "Boolean operations disabled" begin
    @test KhepriBase.has_boolean_ops(KhepriUnity.Unity) isa KhepriBase.HasBooleanOps{false}
  end

  @testset "Family types" begin
    @test isdefined(KhepriUnity, :UnityFamily)
    @test KhepriUnity.UnityFamily <: KhepriBase.Family
    @test isdefined(KhepriUnity, :UnityMaterialFamily)
    @test KhepriUnity.UnityMaterialFamily <: KhepriUnity.UnityFamily

    # unity_material_family constructor
    mf = unity_material_family("Default/Materials/Steel")
    @test mf isa KhepriUnity.UnityMaterialFamily
    @test mf.name == "Default/Materials/Steel"
  end

  @testset "NavMesh tagging parameter" begin
    @test KhepriUnity.nav_mesh_tagging isa KhepriBase.Parameter
    @test KhepriUnity.nav_mesh_tagging() isa Bool
  end

  @testset "Exported functions" begin
    @test isdefined(KhepriUnity, :fast_unity)
  end

  #=
  Combinatorial stress tests. KhepriUnity follows the standard Khepri pattern
  (CLAUDE.md: "Julia acts as server, plugins as clients"):

    1. `using KhepriUnity` registers a socket-backend init for "Unity" via
       `add_socket_backend_init_function`, which also boots
       `khepri_socket_server` (port 12345 by default).
    2. The Unity-side script (`SceneLoad.cs`, `I_am_the_server = false`) connects
       OUT to that port once Play mode engages, sends the handshake string
       "Unity", and KhepriBase instantiates a `Unity` backend bound to that
       socket. The fresh backend lands in `KhepriBase.current_backends()` —
       distinct from the unconnected module-global `unity` singleton.
    3. Stress tests run against the connected backend (mirrors the Threejs
       runner — the global `unity`/`threejs` are placeholders, the real backend
       is the one that registered itself on connect).

  Unity is launched in `-batchmode` to suppress the modal "project version
  mismatch" dialog that otherwise blocks `-executeMethod`. The
  `KhepriAutoRunner.AutoStartListener` editor script
  (Plugins/KhepriUnity/Assets/Khepri/Editor/KhepriAutoRunner.cs), invoked via
  `-executeMethod`, opens BlankScene, sets `khepri.startKhepriOnLoad = true`,
  and calls `EditorApplication.EnterPlaymode()`. From there the existing
  edit→play→connect flow takes over.

  Toggle with `KHEPRI_UNITY_STRESS_TESTS=1`. Skipped on non-Windows.

  Caveat: in batch mode the Unity Editor's main loop ticks much less
  aggressively than the headed editor, so command throughput is low and the
  full suite can take 30+ min, with periodic stalls when Unity yields to its
  asset-import / indexing background jobs. We've also observed isolated
  primitives (e.g. extrude_circle_oblique_*) returning `nothing` instead of an
  Int32 ref, which surfaces as a Julia MethodError in `run_one_test`. Set a
  test-level skip via `KHEPRI_STRESS_SKIP=extrusion` if that category is the
  blocker for your run.
  =#
  if get(ENV, "KHEPRI_UNITY_STRESS_TESTS", "0") == "1"
    if !Sys.iswindows()
      error("Unity stress tests require Windows (Unity.exe path hard-coded).")
    end
    @testset "Stress (Unity)" begin
      include(joinpath(dirname(pathof(KhepriBase)), "..", "test", "BackendStressTests.jl"))
      using .BackendStressTests

      # Unity 6000.4.0f1 is required: the project's Packages/manifest.json
      # references com.unity.test-framework@1.6.0 and several modules that
      # only exist in Unity 6.x; older editors exit with "Project has invalid
      # dependencies". Combined with `-batchmode` below, the version dialog is
      # suppressed and Play-mode entry succeeds.
      unity_exe = get(ENV, "KHEPRI_UNITY_EXE",
                      raw"C:\Program Files\Unity\Hub\Editor\6000.4.0f1\Editor\Unity.exe")
      isfile(unity_exe) || error("Unity not found at $unity_exe (override with KHEPRI_UNITY_EXE)")

      project_path = abspath(joinpath(@__DIR__, "..", "..", "..", "Plugins", "KhepriUnity"))
      isdir(project_path) || error("KhepriUnity project not found at $project_path")

      # Use a unique filename per run. Unity's logger and the Licensing Client
      # keep handles open with deny-delete sharing for some time after the
      # editor exits, which makes a fixed filename racy across consecutive runs.
      log_file = tempname() * "_khepri_unity.log"

      # Force the Khepri socket server up so Unity has something to dial into.
      # `using KhepriUnity` already registered the init function; this just
      # ensures the listening task is alive before we launch the editor.
      KhepriBase.ensure_khepri_socket_server_running()

      # `-batchmode` is required to suppress the modal "project version
      # mismatch" dialog (the project pins 6000.4.0f1 but we use 2022.3 by
      # default); without it `-executeMethod` never fires. `-batchmode` still
      # permits Play mode under `EditorApplication.EnterPlaymode()` — only the
      # interactive UI dialogs are suppressed. `-nographics` is omitted because
      # Khepri's primitives need a working GfxDevice to instantiate Mesh objects.
      @info "Launching Unity with auto-runner..." unity_exe project_path log_file
      unity_proc = run(pipeline(`$unity_exe
                                -batchmode
                                -projectPath $project_path
                                -executeMethod KhepriAutoRunner.AutoStartListener
                                -logFile $log_file`,
                                stdout=devnull, stderr=devnull),
                       wait=false)

      try
        # Wait up to 15 minutes for Unity to enter Play mode and dial in.
        # Unity's first-time project load + asset import + Play mode entry can
        # take 10+ minutes on a cold cache (script compilation + library
        # rebuild). Subsequent launches are 30–60 s. Override with
        # KHEPRI_UNITY_BOOT_TIMEOUT (seconds).
        connected_b = nothing
        let deadline = time() + parse(Float64, get(ENV, "KHEPRI_UNITY_BOOT_TIMEOUT", "900"))
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
          error("Unity never connected to Khepri socket server within timeout. " *
                "Check $log_file for editor startup failures.")

        skip_cats = let s = get(ENV, "KHEPRI_STRESS_SKIP", "")
          isempty(s) ? Symbol[] : Symbol.(strip.(split(s, ',')))
        end

        run_stress_tests(connected_b,
          reset! = () -> begin
            delete_all_shapes()
            backend(connected_b)
          end,
          verify = :envelope,
          skip = skip_cats)
      finally
        try
          run(`taskkill /F /IM Unity.exe`, wait=false)
        catch
        end
      end
    end
  end
end

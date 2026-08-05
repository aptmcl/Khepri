# KhepriUnreal tests — Unreal Engine SocketBackend via C++ plugin
#
# Tests cover module loading, type system, backend configuration,
# family types, and modern b_* API. Actual Unreal operations
# require a running Unreal editor with the Khepri C++ plugin.

using KhepriUnreal
using KhepriBase
using KhepriBase: SocketBackend
using Test

include(joinpath(pkgdir(KhepriBase), "test", "BackendTestScaffolding.jl"))
using .BackendTestScaffolding

#=
Shared editor-session scaffolding for the gated live blocks (visual + stress):
launch UnrealEditor with the plugin project, wait for its Khepri listener, run
the block, and always tear the editor down. UE first-time shader compile + DDC
build can take 10+ minutes on a cold cache; subsequent launches are 30-60 s —
hence the generous default, overridable with KHEPRI_UNREAL_BOOT_TIMEOUT.
=#
with_unreal_editor(f) =
  let ue_exe = get(ENV, "KHEPRI_UNREAL_EXE",
                   raw"C:\Program Files\Epic Games\UE_5.7\Engine\Binaries\Win64\UnrealEditor.exe"),
      uproject = abspath(joinpath(@__DIR__, "..", "..", "..", "Plugins", "KhepriUnreal", "KhepriUnreal.uproject")),
      log_file = joinpath(tempdir(), "khepri_unreal_runner.log")
    isfile(ue_exe) || error("UnrealEditor not found at $ue_exe (override with KHEPRI_UNREAL_EXE)")
    isfile(uproject) || error("KhepriUnreal.uproject not found at $uproject")
    isfile(log_file) && rm(log_file; force=true)
    @info "Launching UnrealEditor..." ue_exe uproject log_file
    #=
    ExecCmds pin down the two frame-history-dependent effects that made
    captures drift between editor sessions (8 of 57 scenes on 2026-08-05):
    TAA/TSR accumulate jitter history across frames, and auto-exposure
    adapts from recent view state — neither is reproducible in a fresh
    session. FXAA is per-frame deterministic; fixed exposure removes the
    adaptation. Test sessions only — a user's editor is untouched.
    =#
    launch_detached(`$ue_exe $uproject -log -ABSLOG=$log_file -ExecCmds="r.AntiAliasingMethod 1, r.DefaultFeature.AutoExposure 0"`)
    try
      wait_for_port(KhepriBase.unreal_port;
                    timeout=900.0, timeout_env="KHEPRI_UNREAL_BOOT_TIMEOUT",
                    hint="Check $log_file for editor startup failures.")
      # A previous gated block's editor session may have left the backend
      # holding a dead socket; discard it so the first RPC reconnects to
      # THIS editor instead of dying on the stale connection.
      KhepriBase.reset_backend(unreal)
      #=
      Warm-up: the first draws after editor boot block on shader
      compilation, which starves the image-write queue past the per-capture
      wait — on 2026-08-05 exactly the first three scenes of an otherwise
      clean mint produced empty captures. Take throwaway screenshots until
      one lands complete, so the suite's first real capture starts from a
      warm renderer.
      =#
      let warmup = joinpath(mktempdir(), "warmup.png")
        for _ in 1:10
          KhepriBase.b_render_and_save_view(unreal, warmup)
          isfile(warmup) && filesize(warmup) > 12 && break
        end
      end
      f()
    finally
      # wait_gone: a fire-and-forget kill can race the NEXT editor launch
      # (two editors contending for the port and the project lock).
      kill_by_image("UnrealEditor.exe"; wait_gone=true)
      KhepriBase.reset_backend(unreal)
    end
  end

@testset "KhepriUnreal.jl" begin

  @testset "RPC Conformance (static)" begin
    # Every @remote/@get_remote RPC the adapter calls must be declared in its
    # @remote_api block. Catches the undeclared-RPC crash class at CI, with no
    # live CAD connection (reads getfield(unreal, :remote) + parses source).
    run_rpc_conformance_tests(unreal, joinpath(dirname(pathof(KhepriUnreal))))
  end

  @testset "Type system" begin
    @test isdefined(KhepriUnreal, :UEKey)
    @test KhepriUnreal.UEId === Int
    @test isdefined(KhepriUnreal, :UERef)
    @test isdefined(KhepriUnreal, :UENativeRef)
    @test KhepriUnreal.UE === SocketBackend{KhepriUnreal.UEKey, Int}
  end

  @testset "Backend initialization" begin
    @test unreal isa KhepriBase.Backend
    @test KhepriBase.backend_name(unreal) == "Unreal"
    @test KhepriBase.void_ref(unreal) === -1
    @test KhepriBase.view_type(KhepriUnreal.UE) isa KhepriBase.BackendView
  end

  @testset "Family types" begin
    @test isdefined(KhepriUnreal, :UEFamily)
    @test KhepriUnreal.UEFamily <: KhepriBase.Family
    @test isdefined(KhepriUnreal, :UEMaterialFamily)
    @test KhepriUnreal.UEMaterialFamily <: KhepriUnreal.UEFamily
    @test isdefined(KhepriUnreal, :UEResourceFamily)
    @test KhepriUnreal.UEResourceFamily <: KhepriUnreal.UEFamily

    # Constructor functions
    mf = unreal_material_family("TestMat")
    @test mf isa KhepriUnreal.UEMaterialFamily
    @test mf.name == "TestMat"

    rf = unreal_resource_family("TestRes")
    @test rf isa KhepriUnreal.UEResourceFamily
    @test rf.name == "TestRes"
    @test rf.scale == 1.0
    @test unreal_resource_family("TestRes"; scale=2.5).scale == 2.5
    # Unsupported parameters raise instead of being swallowed.
    @test_throws MethodError unreal_resource_family("TestRes", :key => "value")
  end

  @testset "Modern b_* methods exist" begin
    # Verify that key b_* methods are defined for the UE backend type
    UE = KhepriUnreal.UE

    # Tier 0 - Curves
    @test hasmethod(KhepriBase.b_point, Tuple{UE, Any, Any})
    @test hasmethod(KhepriBase.b_line, Tuple{UE, Any, Any})
    @test hasmethod(KhepriBase.b_polygon, Tuple{UE, Any, Any})
    @test hasmethod(KhepriBase.b_circle, Tuple{UE, Any, Any, Any})

    # Tier 1 - Surfaces
    @test hasmethod(KhepriBase.b_trig, Tuple{UE, Any, Any, Any, Any})
    @test hasmethod(KhepriBase.b_quad, Tuple{UE, Any, Any, Any, Any, Any})
    @test hasmethod(KhepriBase.b_surface_polygon, Tuple{UE, Any, Any})

    # Tier 3 - Solids
    @test hasmethod(KhepriBase.b_box, Tuple{UE, Any, Any, Any, Any, Any})
    @test hasmethod(KhepriBase.b_sphere, Tuple{UE, Any, Any, Any})
    @test hasmethod(KhepriBase.b_cylinder, Tuple{UE, Any, Any, Any, Any, Any, Any})

    # Boolean operations
    @test hasmethod(KhepriBase.b_unite_ref, Tuple{UE, Int, Int})
    @test hasmethod(KhepriBase.b_subtract_ref, Tuple{UE, Int, Int})
    @test hasmethod(KhepriBase.b_intersect_ref, Tuple{UE, Int, Int})

    # Deletion
    @test hasmethod(KhepriBase.b_delete_ref, Tuple{UE, Int})
    @test hasmethod(KhepriBase.b_delete_refs, Tuple{UE, Vector{Int}})
    @test hasmethod(KhepriBase.b_delete_all_shape_refs, Tuple{UE})

    # Layers
    @test hasmethod(KhepriBase.b_current_layer_ref, Tuple{UE})
    @test hasmethod(KhepriBase.b_current_layer_ref, Tuple{UE, Any})
    @test hasmethod(KhepriBase.b_layer, Tuple{UE, Any, Any, Any})

    # Materials
    @test hasmethod(KhepriBase.b_get_material, Tuple{UE, AbstractString})
    @test hasmethod(KhepriBase.b_material, Tuple{UE, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any})

    # Highlighting
    @test hasmethod(KhepriBase.b_highlight_refs, Tuple{UE, Vector{Int}})
    @test hasmethod(KhepriBase.b_unhighlight_refs, Tuple{UE, Vector{Int}})
    @test hasmethod(KhepriBase.b_unhighlight_all_refs, Tuple{UE})

    # View
    @test hasmethod(KhepriBase.b_set_view, Tuple{UE, Any, Any, Any, Any})
    @test hasmethod(KhepriBase.b_get_view, Tuple{UE})

    # Batch processing
    @test hasmethod(KhepriBase.b_start_batch_processing, Tuple{UE})
    @test hasmethod(KhepriBase.b_stop_batch_processing, Tuple{UE})

    # BIM
    @test hasmethod(KhepriBase.b_table, Tuple{UE, Any, Any, Any, Any, Any, Any, Any})
    @test hasmethod(KhepriBase.b_chair, Tuple{UE, Any, Any, Any, Any, Any, Any, Any})
    @test hasmethod(KhepriBase.b_slab, Tuple{UE, Any, Any, Any})
    @test hasmethod(KhepriBase.b_wall, Tuple{UE, Any, Any, Any, Any, Any})
  end

  @testset "No legacy backend_* functions" begin
    # Verify that old naming convention is gone
    @test !isdefined(KhepriUnreal, :backend_rectangular_table)
    @test !isdefined(KhepriUnreal, :backend_chair)
    @test !isdefined(KhepriUnreal, :backend_slab)
    @test !isdefined(KhepriUnreal, :backend_wall)
    @test !isdefined(KhepriUnreal, :backend_curtain_wall)
    @test !isdefined(KhepriUnreal, :backend_pointlight)
    @test !isdefined(KhepriUnreal, :backend_spotlight)
    @test !isdefined(KhepriUnreal, :backend_set_view)
    @test !isdefined(KhepriUnreal, :backend_get_view)
    @test !isdefined(KhepriUnreal, :backend_delete_all_shapes)
    @test !isdefined(KhepriUnreal, :backend_delete_shapes)
  end

  @testset "Exported functions" begin
    @test isdefined(KhepriUnreal, :unreal)
    @test isdefined(KhepriUnreal, :unreal_material_family)
    @test isdefined(KhepriUnreal, :unreal_resource_family)
  end

  #=
  Combinatorial stress tests. Unreal is a SocketBackend that needs:
    1. UnrealEditor open on the KhepriUnreal project
       (Plugins/KhepriUnreal/KhepriUnreal.uproject).
    2. The Khepri C++ plugin's `FKhepriServer` listening on `unreal_port`
       (11010). `FKhepriModule::StartupModule()`
       (Plugins/KhepriUnreal/Plugins/Khepri/Source/Khepri/Private/KhepriModule.cpp)
       calls `Server->StartServer()` unconditionally, so simply launching the
       editor on the project is enough — no PIE required.

  We launch UnrealEditor in standalone mode (not -game), wait for the port to
  open, run the suite, and `taskkill` UE on cleanup.

  Prerequisite: the Khepri C++ plugin's `UnrealEditor-Khepri.dll` and the
  game-module `UnrealEditor-KhepriUnreal.dll` must match the engine version
  pinned in `KhepriUnreal.uproject`. If you see
  `LogPluginManager: Error: Plugin 'Khepri' failed to load`
  with `GetLastError=193` in the editor log, rebuild via
  `Engine\Build\BatchFiles\Build.bat KhepriUnrealEditor Win64 Development
  -Project=…\KhepriUnreal.uproject` from a Visual Studio Developer Command
  Prompt (the bundled UBT may also need its `XmlConfigCache-…\.bin` purged
  from `%LOCALAPPDATA%\UnrealEngine\` if it complains about an
  EndOfStreamException reading the cache).

  Toggle with `KHEPRI_UNREAL_STRESS_TESTS=1`. Skipped on non-Windows.
  =#
  if gate_enabled("KHEPRI_UNREAL_STRESS_TESTS")
    require_windows("Unreal stress")
    @testset "Stress (Unreal)" begin
      with_unreal_editor() do
        run_stress_tests(unreal,
          reset! = () -> begin
            delete_all_shapes()
            backend(unreal)
          end,
          verify = :envelope,
          skip = stress_skip_from_env())
      end
    end
  end

  #=
  Visual regression against the shared 78-scene corpus, mirroring Rhino's
  wiring (live app + pixel_diff_compare). Gated: needs a Windows machine
  with the Unreal editor. Goldens mint at 960x540 — a quarter of the
  default golden weight per regold; the pre-2026-08 full-size goldens were
  never compared by any harness and were deleted when this block landed
  (regold sessions re-mint from scratch).
  =#
  #=
  Unreal's gaps, live-verified 2026-08-05, all rooted in missing CSG:
  b_unite raises the deliberate "does not support the CSG boolean 'unite'"
  BackendError, while the subtract/intersect/slice paths crash earlier with
  a map_ref MethodError (KhepriBase's b_subtracted/b_intersected/b_slice
  closures over refs the backend cannot map) — same gap, worse error.
  Unblock condition: real boolean ops in the Unreal plugin (or KhepriBase
  mesh-level CSG fallbacks); the map_ref crash deserves the clean
  unsupported-error treatment regardless.
  =#
  unreal_csg_unsupported = [
    # clean 'unite' BackendError
    "csg_union", "cilindrosUniaoInterseccao", "predioCircularSinB",
    "folios", "poligonosRecursivos", "abobadasRomanas",
    # map_ref MethodError via b_subtracted
    "csg_subtraction", "banheira", "cascasPerfuradas",
    "coberturaTubos", "coberturaTubos2", "coberturaTubos3",
    # map_ref MethodError via b_intersected
    "csg_intersection", "csg_compound",
    # map_ref MethodError via b_slice
    "tetraedroEvol", "duploTetraedro", "octahedro", "octaedroEstrelado",
    "calotaEsferica",
  ]
  # Distinct bug: an RPC in this scene's realization returns nothing where
  # Int32 is expected (convert(Int32, nothing) MethodError) — needs live
  # debugging in KhepriUnreal's extrusion path.
  unreal_broken_scenes = ["florCirculosExtrudidos"]
  #=
  NO GOLDENS ARE COMMITTED for Unreal yet: editor-viewport renders are not
  session-deterministic at pixel_diff_compare's tolerances. Capture itself
  is reliable (direct Viewport->Draw consumption; a full 57-scene run takes
  ~2.5 min with zero dropped captures), and FXAA + fixed exposure are
  pinned at launch — but consecutive fresh-session pairs still drift on a
  VARYING subset (5, then 19 scenes, mostly borderline 2D/planar renders
  crossing the 1% differing-pixel budget). Until the varying render state
  is pinned (or capture moves to a deterministic offscreen path), a local
  gated run mints a per-session baseline and verifies WITHIN the session;
  committing any baseline would manufacture false cross-session
  regressions.
  =#

  if gate_enabled("KHEPRI_UNREAL_TESTS")
    require_windows("Unreal visual")
    @testset "Visual Regression (Unreal)" begin
      with_unreal_editor() do
        run_visual_tests(unreal,
          golden_dir = joinpath(@__DIR__, "golden"),
          reset! = () -> begin
            delete_all_shapes()
            backend(unreal)
          end,
          width = 960,
          height = 540,
          compare = pixel_diff_compare,
          backend_module = KhepriUnreal,
          skip_tests = vcat(unreal_csg_unsupported, unreal_broken_scenes))
      end
    end
  end
end

hook_arity_guard(KhepriUnreal)

#=
The C++ plugin validates each operation's canonical signature at registration
(FKhepriServer::HandleProvideOperation), against a hand-maintained table of
literals in KhepriPrimitives.cpp. This test cross-checks every literal against
the authoritative Julia side (unreal_api's info.canonical), so table drift is
a red test here instead of a "Signature mismatch" NOTOK at runtime — or,
worse, a rubber-stamp that lets real drift through. Runs headless in CI: it
only reads the C++ source, which lives in this monorepo. When the plugin
sources are not present (e.g. a registry install of just this package), there
is nothing to check against and the testset is skipped.
=#
@testset "C++ canonical-signature table matches unreal_api" begin
  cpp = normpath(joinpath(@__DIR__, "..", "..", "..",
                          "Plugins", "KhepriUnreal", "Plugins", "Khepri",
                          "Source", "Khepri", "Private", "KhepriPrimitives.cpp"))
  if isfile(cpp)
    let src = read(cpp, String),
        # Server.RegisterOperation(TEXT("name"), TEXT("canonical"), handler)
        registered = Dict(m.captures[1] => m.captures[2]
                          for m in eachmatch(r"RegisterOperation\(TEXT\(\"([^\"]+)\"\),\s*TEXT\(\"([^\"]*)\"\)", src))
      @test !isempty(registered)
      # The handshake op is registered in the server, not declared in unreal_api.
      @test registered["KhepriBuildStamp"] == "String()"
      for (name, info) in pairs(KhepriUnreal.unreal_api)
        @test haskey(registered, info.remote_name)
        if haskey(registered, info.remote_name)
          @test registered[info.remote_name] == info.canonical
        end
      end
      # Registered-but-undeclared ops must opt out of validation explicitly
      # (empty canonical) or match some declaration; a nonempty canonical for
      # an op Julia never declares cannot be checked and would rot silently.
      let declared = Set(info.remote_name for (_, info) in pairs(KhepriUnreal.unreal_api))
        for (name, canon) in registered
          name == "KhepriBuildStamp" && continue
          if !(name in declared)
            @test canon == ""
          end
        end
      end
    end
  else
    @info "Skipping canonical cross-check: plugin sources not present" cpp
  end
end

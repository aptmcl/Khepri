# KhepriUnreal tests — Unreal Engine SocketBackend via C++ plugin
#
# Tests cover module loading, type system, backend configuration,
# family types, and modern b_* API. Actual Unreal operations
# require a running Unreal editor with the Khepri C++ plugin.

using KhepriUnreal
using KhepriBase
using KhepriBase: SocketBackend
using Test

@testset "KhepriUnreal.jl" begin

  @testset "RPC Conformance (static)" begin
    # Every @remote/@get_remote RPC the adapter calls must be declared in its
    # @remote_api block. Catches the undeclared-RPC crash class at CI, with no
    # live CAD connection (reads getfield(unreal, :remote) + parses source).
    include(joinpath(dirname(pathof(KhepriBase)), "..", "test", "RPCConformanceTests.jl"))
    using .RPCConformanceTests
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

    rf = unreal_resource_family("TestRes", :key => "value")
    @test rf isa KhepriUnreal.UEResourceFamily
    @test rf.name == "TestRes"
    @test rf.parameter_map[:key] == "value"
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
  if get(ENV, "KHEPRI_UNREAL_STRESS_TESTS", "0") == "1"
    if !Sys.iswindows()
      error("Unreal stress tests require Windows (UnrealEditor.exe path hard-coded).")
    end
    @testset "Stress (Unreal)" begin
      include(joinpath(dirname(pathof(KhepriBase)), "..", "test", "BackendStressTests.jl"))
      using .BackendStressTests
      using Sockets

      ue_exe = get(ENV, "KHEPRI_UNREAL_EXE",
                   raw"C:\Program Files\Epic Games\UE_5.7\Engine\Binaries\Win64\UnrealEditor.exe")
      isfile(ue_exe) || error("UnrealEditor not found at $ue_exe (override with KHEPRI_UNREAL_EXE)")

      uproject = abspath(joinpath(@__DIR__, "..", "..", "..", "Plugins", "KhepriUnreal", "KhepriUnreal.uproject"))
      isfile(uproject) || error("KhepriUnreal.uproject not found at $uproject")

      log_file = joinpath(tempdir(), "khepri_unreal_runner.log")
      isfile(log_file) && rm(log_file; force=true)

      @info "Launching UnrealEditor..." ue_exe uproject log_file
      ue_proc = run(pipeline(`$ue_exe $uproject -log -ABSLOG=$log_file`,
                             stdout=devnull, stderr=devnull),
                    wait=false)

      try
        # Wait up to 15 minutes for the listener. UE first-time shader
        # compile + DDC build can take 10+ minutes on a cold cache (Slate
        # icon caching alone takes ~2 min observed); subsequent launches
        # are 30–60 s. Override with KHEPRI_UNREAL_BOOT_TIMEOUT (seconds).
        port_ready = false
        let deadline = time() + parse(Float64, get(ENV, "KHEPRI_UNREAL_BOOT_TIMEOUT", "900"))
          while time() < deadline
            try
              Sockets.connect(KhepriBase.unreal_port) |> close
              port_ready = true
              break
            catch
              sleep(2.0)
            end
          end
        end
        port_ready || error("Unreal listener never opened on port $(KhepriBase.unreal_port). " *
                            "Check $log_file for editor startup failures.")

        skip_cats = let s = get(ENV, "KHEPRI_STRESS_SKIP", "")
          isempty(s) ? Symbol[] : Symbol.(strip.(split(s, ',')))
        end

        run_stress_tests(unreal,
          reset! = () -> begin
            delete_all_shapes()
            backend(unreal)
          end,
          verify = :envelope,
          skip = skip_cats)
      finally
        try
          run(`taskkill /F /IM UnrealEditor.exe`, wait=false)
        catch
        end
      end
    end
  end
end

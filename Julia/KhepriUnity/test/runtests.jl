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
  Pure Julia tests for the BIM box-decomposition introduced to give walls,
  slabs, columns, beams and panels primitive BoxColliders instead of
  non-convex MeshColliders (which Physics.ClosestPoint refuses).

  These tests exercise the decomposition functions directly — no Unity
  connection needed — to verify (a) the rectangular cases produce the
  expected count of boxes with correct dimensions, and (b) the
  fall-through cases (multi-material, smooth paths) return `nothing`.

  See `Julia/KhepriUnity/src/Unity.jl` "BIM box decomposition" section.
  =#
  @testset "BIM box decomposition" begin
    using KhepriUnity: _rectangle_obb, _wall_box_decomposition,
                      _slab_box_decomposition, _panel_obb, _beam_rect_obb,
                      _decompose_segment_with_openings

    @testset "_rectangle_obb" begin
      let r = _rectangle_obb(rectangular_path(xy(0,0), 4, 3))
        @test r isa NamedTuple
        @test r.dx ≈ 4
        @test r.dy ≈ 3
        @test r.centre ≈ xy(2, 1.5)
      end
      let r = _rectangle_obb(closed_polygonal_path([xy(0,0), xy(4,0), xy(4,3), xy(0,3)]))
        @test r isa NamedTuple
        @test r.dx ≈ 4
        @test r.dy ≈ 3
      end
      # Not a rectangle (parallelogram): non-perpendicular edges
      @test isnothing(_rectangle_obb(closed_polygonal_path([xy(0,0), xy(4,0), xy(5,3), xy(1,3)])))
      # Wrong vertex count
      @test isnothing(_rectangle_obb(closed_polygonal_path([xy(0,0), xy(4,0), xy(4,3)])))
      # Smooth path falls through
      @test isnothing(_rectangle_obb(circular_path(xy(0,0), 1.0)))
    end

    @testset "_decompose_segment_with_openings" begin
      # No openings: one full-height bay
      let pieces = _decompose_segment_with_openings(5.0, 3.0, [])
        @test length(pieces) == 1
        @test pieces[1] == (s=0.0, e=5.0, b=0.0, t=3.0)
      end
      # One window in the middle (sill below, lintel above, bays left & right)
      let pieces = _decompose_segment_with_openings(
            5.0, 3.0,
            [(s=2.0, e=3.0, b=1.0, t=2.0)])
        @test length(pieces) == 4
        # Left bay
        @test (s=0.0, e=2.0, b=0.0, t=3.0) in pieces
        # Sill
        @test (s=2.0, e=3.0, b=0.0, t=1.0) in pieces
        # Lintel
        @test (s=2.0, e=3.0, b=2.0, t=3.0) in pieces
        # Right bay
        @test (s=3.0, e=5.0, b=0.0, t=3.0) in pieces
      end
      # Door (touches floor — no sill emitted, so 3 pieces)
      let pieces = _decompose_segment_with_openings(
            5.0, 3.0,
            [(s=2.0, e=3.0, b=0.0, t=2.0)])
        @test length(pieces) == 3
        @test !any(p -> p.b == 0 && p.t == 2 && p.s == 2 && p.e == 3, pieces)  # no sill
      end
    end

    # Helper: convert a Wall into the primitive args b_wall receives,
    # mirroring the body of KhepriBase.realize(::HasBooleanOps{false}, b, w).
    wall_args(w) = let lift = vz(w.bottom_level.height),
                       w_path = translate(w.path, lift),
                       w_height = w.top_level.height - w.bottom_level.height,
                       l_face = isnothing(w.left_face_path)  ? nothing : translate(w.left_face_path,  lift),
                       r_face = isnothing(w.right_face_path) ? nothing : translate(w.right_face_path, lift),
                       openings = [KhepriBase.WallOpening(op.loc.x, op.loc.y, op.family.width, op.family.height)
                                   for op in [w.doors..., w.windows...]]
      (w_path, w_height, w.family, w.offset, openings, l_face, r_face)
    end

    @testset "Wall: single straight, no openings" begin
      let w = wall(open_polygonal_path([xy(0,0), xy(5,0)]),
                   level(0), level(3))
        let boxes = _wall_box_decomposition(wall_args(w)...)
          @test boxes isa Vector
          @test length(boxes) == 1
          @test boxes[1].dx ≈ 5     # along
          @test boxes[1].dz ≈ 3     # height
          # default thickness 0.2, no offset → total thickness 0.2
          @test boxes[1].dy ≈ 0.2
        end
      end
    end

    @testset "Wall: single straight, one window" begin
      let w = wall(open_polygonal_path([xy(0,0), xy(5,0)]),
                   level(0), level(3))
        # add a window 1 m wide, 1 m tall, centred at x=2.5, base 1 m up
        add_window(w, xy(2, 1))
        let boxes = _wall_box_decomposition(wall_args(w)...)
          @test boxes isa Vector
          # left bay + sill + lintel + right bay = 4
          @test length(boxes) == 4
        end
      end
    end

    @testset "Wall: multi-segment polygonal" begin
      let w = wall(open_polygonal_path([xy(0,0), xy(5,0), xy(5,5)]),
                   level(0), level(3))
        let boxes = _wall_box_decomposition(wall_args(w)...)
          @test boxes isa Vector
          # 2 segments, 1 box per segment (no openings) → 2 boxes
          @test length(boxes) == 2
        end
      end
    end

    @testset "Wall: smooth path falls through" begin
      let w = wall(circular_path(xy(0,0), 5),
                   level(0), level(3))
        @test isnothing(_wall_box_decomposition(wall_args(w)...))
      end
    end

    @testset "Wall: multi-material falls through" begin
      let fam = KhepriBase.wall_family_element(default_wall_family(),
                                               left_material=material_glass,
                                               right_material=material_concrete),
          w = wall(open_polygonal_path([xy(0,0), xy(5,0)]),
                   level(0), level(3), fam)
        @test isnothing(_wall_box_decomposition(wall_args(w)...))
      end
    end

    @testset "Slab: rectangular, no holes" begin
      let s = slab(rectangular_path(xy(0,0), 5, 4), level(0))
        let boxes = _slab_box_decomposition(unity, s.region, s.level, s.family)
          @test boxes isa Vector
          @test length(boxes) == 1
          @test boxes[1].dx ≈ 5
          @test boxes[1].dy ≈ 4
          # Default slab_family thickness = 0.2 m
          @test boxes[1].dz ≈ 0.2
        end
      end
    end

    @testset "Slab: rectangular with one rectangular hole" begin
      let s = slab(region(rectangular_path(xy(0,0), 10, 10),
                          rectangular_path(xy(4,4), 2, 2)),
                   level(0))
        let boxes = _slab_box_decomposition(unity, s.region, s.level, s.family)
          @test boxes isa Vector
          # Strip-sweep splits along x: left strip [0,4], hole strip [4,6]
          # split into two boxes (sill+lintel), right strip [6,10] = 4 boxes.
          @test length(boxes) == 4
        end
      end
    end

    @testset "Panel: rectangular profile" begin
      let p = panel(region(rectangular_path(xy(0,0), 2, 3)))
        let obb = _panel_obb(p.region, p.family)
          @test obb isa NamedTuple
          @test obb.dx ≈ 2
          @test obb.dy ≈ 3
          # Default panel thickness 0.02 m
          @test obb.dz ≈ 0.02
        end
      end
    end

    @testset "Beam: rectangular profile (default)" begin
      let bm = beam(xyz(0,0,0), 3.0, 0.0, default_beam_family())
        let obb = _beam_rect_obb(unity, bm.cb, bm.h, bm.angle, bm.family)
          @test obb isa NamedTuple
          @test obb.dz ≈ 3.0
          # Default beam profile is top_aligned_rectangular_profile(1, 2)
          @test obb.dx ≈ 1
          @test obb.dy ≈ 2
        end
      end
    end

    @testset "Beam: circular profile falls through" begin
      let fam = KhepriBase.beam_family_element(default_beam_family(),
                                               profile=circular_path(u0(), 0.1)),
          bm = beam(xyz(0,0,0), 3.0, 0.0, fam)
        @test isnothing(_beam_rect_obb(unity, bm.cb, bm.h, bm.angle, bm.family))
      end
    end
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

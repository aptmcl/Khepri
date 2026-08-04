#=
Live end-to-end validation of the visual_style pipeline for KhepriBlender.

Architecture (matches `init_client_server("Blender", 0)` in BlenderServer.py):

  1. `using KhepriBlender` registers an init function for "Blender" socket
     connections, which starts khepri_socket_server on port 12345.
  2. `start_blender()` spawns `blender --background --python BlenderServer.py`.
     Inside Blender, the Python plugin connects out to localhost:12345 and
     identifies as "Blender".
  3. The Khepri server-side accept loop creates a fresh BLR backend bound to
     the live socket and registers it via `add_global_backend`, after which
     `top_backend()` returns it.
  4. The user's script must wait for the connection to land before issuing
     any geometry calls; `wait_for_connected_backend` below does that.

Renders the same primitive scene as the Mitsuba live test in three styles
that complete quickly on Blender 4.0 + CPU (no OpenImageDenoiser):

  :shaded     — Eevee real-time rasteriser (~1 s).
  :technical  — Freestyle SVG line renderer (~2 s).
  :pen        — Freestyle SVG with tighter strokes (~2 s).

The slower :realistic (Cycles) and :arctic (Cycles + clay) styles work via
the same code path but take much longer on CPU; uncomment SLOW_STYLES below
to include them.

Outputs land in `$(tempdir())/khepri_blender_visual_style/`.
=#

using KhepriBlender
using KhepriBase
using Sockets
using Printf

const FAST_STYLES = (:shaded,)                # Eevee: ~1 s on CPU
const SLOW_STYLES = (:realistic, :arctic)      # Cycles: many seconds on CPU
# :technical / :pen use Freestyle, which needs a viewport context that does
# not exist in `blender --background`; Blender 4.x's Freestyle modifier API
# disconnects the Khepri socket on render. Re-enable once we either run with
# a virtual X server (xvfb-run) or migrate to LineART (the Grease-Pencil
# replacement that does work headless).
const STYLES = (FAST_STYLES..., SLOW_STYLES...)

function wait_for_connected_backend(timeout_s)
  deadline = time() + timeout_s
  while time() < deadline
    for b in KhepriBase.current_backends()
      if b isa KhepriBase.SocketBackend && KhepriBase.backend_name(b) == "Blender"
        return b
      end
    end
    sleep(0.5)
  end
  error("No Blender backend connected within $(timeout_s)s")
end

function build_scene(b)
  # Wipe Blender's startup mesh objects (default Cube) so renders only show
  # what we explicitly create. The default Light and Camera stay; the
  # Light is repurposed below.
  @remote(b, blender_cmd("[bpy.data.objects.remove(o, do_unlink=True) for o in list(bpy.data.objects) if o.type == 'MESH']"))
  # Replace the default 1000 W point light with a strong sun-style light
  # appropriate for an open architectural scene. Cycles also pulls indirect
  # illumination from the procedural sky world we install in cycles_renderer.
  @remote(b, blender_cmd("setattr(bpy.data.objects['Light'].data, 'type', 'SUN')"))
  @remote(b, blender_cmd("setattr(bpy.data.objects['Light'].data, 'energy', 2.0)"))
  @remote(b, blender_cmd("setattr(bpy.data.objects['Light'], 'location', (0.0, 0.0, 30.0))"))
  @remote(b, blender_cmd("setattr(bpy.data.objects['Light'], 'rotation_euler', (0.5, 0.2, 0.7))"))
  # Same scene as the KhepriMitsuba live test so the two renders can be
  # compared side-by-side. A concrete ground plane gives the metal surface
  # something non-trivial to reflect; without it Cycles produces a flat
  # bright look that betrays the metallic-sky-only reflection.
  surface_polygon([xyz(-50, -50, 0), xyz(50, -50, 0), xyz(50, 50, 0), xyz(-50, 50, 0)];
                  material=KhepriBase.material_concrete)
  sphere(xyz(0, 0, 5), 5)
  box(xyz(-12, -2.5, 0), 5, 5, 5, material=KhepriBase.material_metal)
  box(xyz(7, -2.5, 0), 5, 5, 5, material=KhepriBase.material_glass)
  set_view(xyz(25, 25, 15), xyz(0, 0, 2))
end

function render_all_styles(outdir)
  mkpath(outdir)
  println("starting Blender (headless=", headless_blender(), ") ...")
  start_blender()
  println("waiting for Blender to register ...")
  b = wait_for_connected_backend(45)
  KhepriBase.add_current_backend(b)
  println("connected: ", b, "; building scene ...")
  build_scene(b)
  # Quick diagnostic: confirm each mesh has the right material assigned.
  @remote(b, blender_cmd("open('/tmp/blr_objs.txt','w').write(repr([(o.name, o.type, [m.name if m else '-' for m in (o.data.materials if o.type=='MESH' else [])]) for o in bpy.context.scene.objects]))"))
  sleep(0.5)
  println("objs+mats: ", read("/tmp/blr_objs.txt", String))
  with(KhepriBase.render_dir, outdir) do
    with(KhepriBase.render_kind_dir, ".") do
      # Sanity baseline: direct bpy.ops render with the current scene state.
      println("baseline: direct bpy.ops render ...")
      base_path = joinpath(outdir, "0_baseline.png")
      @remote(b, set_render_size(320, 240))
      @remote(b, set_render_path(base_path))
      @remote(b, blender_cmd("bpy.ops.render.render(write_still=True, use_viewport=False)"))
      println("  baseline size=", filesize(base_path))

      for style in STYLES
        path = joinpath(outdir, "demo_$(style).png")
        # Realistic needs real samples to show materials properly; q=0
        # gives Cycles 1024 spp, Eevee 64, Clay 256. On CPU, Cycles at 1024
        # spp ~30 s for this scene. Other styles stay at q=-0.25.
        q = style === :realistic ? 0.0 : -0.25
        print("rendering ", style, " (q=", q, ") → ", path, " ... ")
        t = @elapsed render_view("demo_$(style)", b;
                                 visual_style = style,
                                 width  = 640,
                                 height = 480,
                                 quality = q)
        @printf "%.1fs\n" t
      end
    end
  end
end

let outdir = joinpath(tempdir(), "khepri_blender_visual_style")
  rm(outdir, force=true, recursive=true)
  render_all_styles(outdir)
  println("\nDone. Open the images in $outdir to compare styles.")
end

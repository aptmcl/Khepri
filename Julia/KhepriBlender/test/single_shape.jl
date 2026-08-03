# Minimal end-to-end check: Khepri server accepts a Blender connection,
# user-side code resolves to the live backend via top_backend(), and a single
# sphere actually shows up in a render.
#
# Architecture (matches BlenderServer.py: init_client_server("Blender", 0)):
#   1. `using KhepriBlender` registers an init-function for "Blender" socket
#      connections, which starts khepri_socket_server on port 12345.
#   2. start_blender() spawns `blender --background --python BlenderServer.py`.
#      Inside Blender, the Python script connects out to localhost:12345,
#      sends "Blender", and waits for RPCs.
#   3. The Khepri server-side accept loop creates a new BLR backend bound to
#      the live socket and registers it via add_global_backend, after which
#      `top_backend()` returns it.
#   4. The user's script must wait for the connection to land before issuing
#      any geometry calls.

using KhepriBlender
using KhepriBase
using Sockets

function wait_for_connected_backend(timeout_s)
  deadline = time() + timeout_s
  while time() < deadline
    bs = KhepriBase.current_backends()
    for b in bs
      if b isa KhepriBase.SocketBackend && KhepriBase.backend_name(b) == "Blender"
        return b
      end
    end
    sleep(0.5)
  end
  error("No Blender backend connected within $(timeout_s)s")
end

function run()
  outdir = joinpath(tempdir(), "khepri_blender_single")
  mkpath(outdir)
  println("starting Blender (it will connect to Khepri server on 12345) ...")
  start_blender()
  println("waiting for Blender to register itself ...")
  b = wait_for_connected_backend(45)
  println("Blender backend registered: ", b)
  KhepriBase.add_current_backend(b)
  println("creating sphere via top_backend = ", KhepriBase.top_backend())
  s = sphere(xyz(0, 0, 0), 5)
  println("ref count after sphere = ", length(b.refs.shapes))
  println("before set_view:")
  @remote(b, blender_cmd("open('/tmp/bo1.txt','w').write(repr([(o.name, o.type, list(o.location)) for o in bpy.context.scene.objects]))"))
  sleep(1); println(read("/tmp/bo1.txt", String))
  set_view(xyz(20, 20, 15), xyz(0, 0, 0))
  println("after set_view:")
  @remote(b, blender_cmd("open('/tmp/bo2.txt','w').write(repr([(o.name, o.type, list(o.location)) for o in bpy.context.scene.objects]))"))
  sleep(1); println(read("/tmp/bo2.txt", String))
  println("scene.camera = ")
  @remote(b, blender_cmd("open('/tmp/bo3.txt','w').write('camera=' + (bpy.context.scene.camera.name if bpy.context.scene.camera else 'None') + '; loc=' + repr(list(bpy.context.scene.camera.location) if bpy.context.scene.camera else None))"))
  sleep(1); println(read("/tmp/bo3.txt", String))
  println("camera rotation_euler:")
  @remote(b, blender_cmd("open('/tmp/cam.txt','w').write('rot=' + repr(list(bpy.context.scene.camera.rotation_euler)) + '; loc=' + repr(list(bpy.context.scene.camera.location)))"))
  sleep(1); println(read("/tmp/cam.txt", String))
  with(KhepriBase.render_dir, outdir) do
    with(KhepriBase.render_kind_dir, ".") do
      # Test 1: direct bpy.ops (known good)
      println("Test 1: direct bpy.ops ...")
      direct_path = joinpath(outdir, "1_direct.png")
      @remote(b, set_render_size(320, 240))
      @remote(b, set_render_path(direct_path))
      @remote(b, blender_cmd("bpy.ops.render.render(write_still=True, use_viewport=False)"))
      println("  size=", filesize(direct_path))

      # Test 2: Khepri's eevee_renderer directly (no get_view/set_camera_view)
      println("Test 2: eevee_renderer ...")
      eevee_path = joinpath(outdir, "2_eevee.png")
      @remote(b, set_render_path(eevee_path))
      @remote(b, eevee_renderer(64, 0.0))
      println("  size=", filesize(eevee_path))

      # Test 3: cycles_renderer directly
      println("Test 3: cycles_renderer (small samples) ...")
      cyc_path = joinpath(outdir, "3_cycles.png")
      @remote(b, set_render_path(cyc_path))
      @remote(b, cycles_renderer(8, false, false, false, 0.0))
      println("  size=", filesize(cyc_path))

      # Test 4: get_view then set_camera_view, see if it breaks anything
      println("Test 4: get_view + set_camera_view + eevee ...")
      gv_path = joinpath(outdir, "4_gv_set_eevee.png")
      cv = @remote(b, get_view())
      println("  got view: ", cv)
      @remote(b, set_camera_view(cv...))
      @remote(b, set_render_path(gv_path))
      @remote(b, eevee_renderer(64, 0.0))
      println("  size=", filesize(gv_path))

      # Test 5: full b_render_and_save_view via Khepri's render_view (explicit backend)
      println("Test 5: Khepri render_view explicit b ...")
      println("  top_backend = ", KhepriBase.top_backend(), " same as b? ", KhepriBase.top_backend() === b)
      render_view("5_render_view", b;
                  visual_style=:shaded, width=320, height=240, quality=-1.0)
      r5 = joinpath(outdir, "5_render_view.png")
      println("  size=", isfile(r5) ? filesize(r5) : "missing")

      # Test 6: same but using top_backend default (no explicit b)
      println("Test 6: Khepri render_view default backend ...")
      render_view("6_render_view";
                  visual_style=:shaded, width=320, height=240, quality=-1.0)
      r6 = joinpath(outdir, "6_render_view.png")
      println("  size=", isfile(r6) ? filesize(r6) : "missing")
    end
  end
  println("done; ", outdir)
end

run()

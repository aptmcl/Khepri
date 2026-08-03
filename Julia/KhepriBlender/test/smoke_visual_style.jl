#=
Quick smoke test of the headless KhepriBlender pipeline.

Renders a tiny scene at 320×240, lowest quality, in three fast styles only:

  :shaded     — Eevee (~1 s).
  :technical  — Freestyle SVG (~few s).
  :pen        — Freestyle SVG (~few s).

The slow styles (:realistic / :arctic, both Cycles on CPU when GPU is
unavailable, and especially without OpenImageDenoiser) are exercised by the
companion `live_visual_style.jl` script, which can take minutes per frame on
this hardware. This smoke test is the right thing to run after editing the
backend; it validates the connection and renderer plumbing in seconds.
=#

using KhepriBlender
using KhepriBase
using Printf

const SMOKE_STYLES = (:shaded, :technical, :pen)

function build_smoke_scene()
  delete_all_shapes()
  # Wipe Blender's startup scene (default cube/camera/light) too so renders
  # only show what we explicitly added.
  @remote(blender, blender_cmd("[bpy.data.objects.remove(o, do_unlink=True) for o in list(bpy.data.objects) if o.type == 'MESH']"))
  s = sphere(xyz(0, 0, 5), 5)
  b1 = box(xyz(-12, -2.5, 0), 5, 5, 5)
  b2 = box(xyz(7, -2.5, 0), 5, 5, 5)
  println("created: sphere=$(s), box1=$(b1), box2=$(b2)")
  set_view(xyz(25, 25, 15), xyz(0, 0, 2))
  nothing
end

function smoke_test(outdir)
  mkpath(outdir)
  println("starting Blender (headless=", headless_blender(), ") ...")
  start_blender()
  println("connected. building scene ...")
  build_smoke_scene()
  with(KhepriBase.render_dir, outdir) do
    with(KhepriBase.render_kind_dir, ".") do
      for style in SMOKE_STYLES
        path = joinpath(outdir, "smoke_$(style).png")
        print("rendering ", style, " → ", path, " ... ")
        t = @elapsed render_view("smoke_$(style)";
                                 visual_style = style,
                                 width  = 320,
                                 height = 240,
                                 quality = -1.0)
        @printf "%.1fs\n" t
      end
    end
  end
end

let outdir = joinpath(tempdir(), "khepri_blender_smoke")
  smoke_test(outdir)
  println("\nSmoke test done. Open the images in $outdir")
end

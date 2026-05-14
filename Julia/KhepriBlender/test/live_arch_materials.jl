#=
Live material-library comparison for KhepriBlender.

Renders one sphere per canonical architectural material on a concrete
ground, using Cycles with the procedural Nishita sky world configured by
`ensure_default_world()`. Writes PNGs to
`$(tempdir())/khepri_arch_materials_blender/`.

Same camera and scene as `Julia/KhepriMitsuba/test/live_arch_materials.jl`,
so the two sets of thumbnails can be placed side-by-side to validate that
Khepri's canonical materials produce visually comparable output across the
two backends.
=#

using KhepriBlender
using KhepriBase
using Sockets
using Printf

const MATERIALS = (
  material_basic,
  material_metal,
  material_glass,
  material_wood,
  material_concrete,
  material_plaster,
  material_grass,
  material_clay,
)

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

function one_shot_scene(b, mat)
  # Rebuild the scene for each material. We have to clear both sides of the
  # Khepri↔Blender divide:
  #  - Blender side: delete MESH objects only (keep Light and Camera).
  #    `delete_all_shapes` would wipe those too because it iterates every
  #    collection's objects indiscriminately.
  #  - Julia side: empty `b.refs.shapes` so Khepri doesn't hold references
  #    to meshes that no longer exist.
  @remote(b, blender_cmd("[bpy.data.objects.remove(o, do_unlink=True) for o in list(bpy.data.objects) if o.type == 'MESH']"))
  empty!(b.refs.shapes)
  # Ensure there's a sun light. If the previous iteration already set it up
  # as a SUN, this is a cheap no-op.
  @remote(b, blender_cmd("setattr(bpy.data.objects['Light'].data, 'type', 'SUN')"))
  @remote(b, blender_cmd("setattr(bpy.data.objects['Light'].data, 'energy', 2.0)"))
  @remote(b, blender_cmd("setattr(bpy.data.objects['Light'], 'rotation_euler', (0.5, 0.2, 0.7))"))
  surface_polygon([xyz(-50, -50, 0), xyz(50, -50, 0), xyz(50, 50, 0), xyz(-50, 50, 0)];
                  material=material_concrete)
  sphere(xyz(0, 0, 5), 5, material=mat)
  set_view(xyz(18, 18, 12), xyz(0, 0, 4))
  # Force Blender to refresh its view-layer / depsgraph so Cycles sees the
  # newly-linked meshes. Without this, geometry added earlier in the script
  # can render-as-missing if the previous iteration left stale depsgraph
  # state. Also re-link orphan meshes into the active collection, which
  # otherwise end up un-linked when delete_all_shapes tears down the Julia
  # side-of-the-fence without a corresponding objects.link on recreation.
  @remote(b, blender_cmd("(bpy.context.view_layer.update(), [bpy.context.scene.collection.objects.link(o) for o in bpy.data.objects if o.type=='MESH' and not o.users_collection])"))
end

function render_material(b, mat, outdir)
  one_shot_scene(b, mat)
  # Full scene dump to file so we can inspect whether the sphere is actually
  # visible to the renderer.
  @remote(b, blender_cmd("open('/tmp/mat_scene.txt','w').write(repr([(o.name, o.type, list(o.location), list(o.scale), list(o.dimensions) if o.type=='MESH' else None, [c.name for c in o.users_collection]) for o in bpy.context.scene.objects]))"))
  sleep(0.2)
  scene = read("/tmp/mat_scene.txt", String)
  mat_name = lowercase(mat.name)
  path = joinpath(outdir, "$(mat_name).png")
  print("  ", rpad(mat_name, 12), " (refs=", length(b.refs.shapes), ") → ")
  t = @elapsed render_view("$(mat_name)", b;
                           visual_style = :realistic,
                           width = 320, height = 240,
                           quality = -0.25,
                           exposure = -0.5)   # keep hue saturation from being
                                              # washed out by the bright sky
  @printf "%.1fs\n    %s\n" t scene
end

let outdir = joinpath(tempdir(), "khepri_arch_materials_blender")
  rm(outdir, force=true, recursive=true)
  mkpath(outdir)
  println("starting Blender (headless=", headless_blender(), ") ...")
  start_blender()
  b = wait_for_connected_backend(45)
  KhepriBase.add_current_backend(b)
  println("connected: ", b)
  with(KhepriBase.render_dir, outdir) do
    with(KhepriBase.render_kind_dir, ".") do
      for m in MATERIALS
        render_material(b, m, outdir)
      end
    end
  end
  println("\nDone. Thumbnails in $outdir")
end

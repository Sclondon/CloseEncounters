"""Renders models/<name>.glb from four sides (front three-quarter, back three-quarter, the right side,
and from above), to check how a model's parts are laid out after building it. Run by
tools/look_models.sh; by hand:
  blender -b --factory-startup --python tools/look_models.py -- <out dir> <name> [<name> ...]
The models face -y in Blender (the door, the front), so "front" looks at them from -y."""
import bpy, math, os, sys
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
out, names = args[0], args[1:]
here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.makedirs(out, exist_ok=True)
for name in names:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(here, "models", name + ".glb"))
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    lo = Vector((min(min((o.matrix_world @ Vector(c)).x for c in o.bound_box) for o in objs),
                 min(min((o.matrix_world @ Vector(c)).y for c in o.bound_box) for o in objs),
                 min(min((o.matrix_world @ Vector(c)).z for c in o.bound_box) for o in objs)))
    hi = Vector((max(max((o.matrix_world @ Vector(c)).x for c in o.bound_box) for o in objs),
                 max(max((o.matrix_world @ Vector(c)).y for c in o.bound_box) for o in objs),
                 max(max((o.matrix_world @ Vector(c)).z for c in o.bound_box) for o in objs)))
    mid = (lo + hi) * 0.5
    size = max((hi - lo).length, 0.5)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x = 360
    scene.render.resolution_y = 360
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("w")
    scene.world = world
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = size * 1.1
    views = {"front": (-0.7, -1.0, 0.55), "back": (0.7, 1.0, 0.55), "side": (1.0, 0.0, 0.15), "top": (0.0, -0.01, 1.0)}
    for view, d in views.items():
        cam.location = mid + Vector(d).normalized() * size * 3.0
        cam.rotation_euler = (mid - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(out, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)
    print("looked at", name, "size", tuple(round(v, 2) for v in (hi - lo)))

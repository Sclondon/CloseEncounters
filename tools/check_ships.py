"""Checks the ships' models for the faults that are easy to miss by eye:
  - LOOSE: a part that touches no other part (left floating off the hull)
  - DOME GAP: where the canopy's rim stands clear of the hull under it (glass not seated)
  - REACH: how far the hull reaches from the pilot (the game draws anything over 4 m from the ship
    that stands between it and the camera see-through, in a checker that flickers)
Run by hand:
  blender -b --factory-startup --python tools/check_ships.py -- <name> [<name> ...]
It builds just those models (as build_models.py does with CE_ONLY) and prints what it finds."""
import bpy, bmesh, math, os, sys
from mathutils import Vector
from mathutils.bvhtree import BVHTree

names = sys.argv[sys.argv.index("--") + 1:]
os.environ["CE_ONLY"] = ",".join(names)
HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, "build_models.py"), encoding="utf-8").read().replace("\nmain()\n", "\n")
g = {"__file__": os.path.join(HERE, "build_models.py"), "__name__": "build_models"}
exec(compile(src, "build_models.py", "exec"), g)

found = {}
real_join = g["join"]


def _tree(o):
    m = o.matrix_world
    return BVHTree.FromPolygons([m @ v.co for v in o.data.vertices], [p.vertices[:] for p in o.data.polygons])


def checking_join(name, parts):
    parts = list(g["_flat"](parts))
    bpy.context.view_layer.update()
    trees = [_tree(p) for p in parts]
    loose = []
    for i, p in enumerate(parts):
        touches = any(trees[i].overlap(trees[j]) for j in range(len(parts)) if j != i)
        # (a part inside another touches nothing, but is hidden, not floating: test its middle)
        if not touches and len(parts) > 1:
            mid = p.matrix_world @ (sum((Vector(c) for c in p.bound_box), Vector()) / 8.0)
            inside = False
            for j, q in enumerate(parts):
                if j == i:
                    continue
                lo = q.matrix_world @ Vector(q.bound_box[0]); hi = q.matrix_world @ Vector(q.bound_box[6])
                if all(min(lo[k], hi[k]) <= mid[k] <= max(lo[k], hi[k]) for k in range(3)):
                    inside = True
            if not inside:
                loose.append("%s at (%.2f, %.2f, %.2f)" % (p.data.materials[0].name if p.data.materials else "?", *mid))
    found.setdefault(name, []).extend(loose)
    return real_join(name, parts)


g["join"] = checking_join
bpy.ops.wm.read_factory_settings(use_empty=True)
for build in g["BUILDERS"]:
    if getattr(build, "__name__", "") not in names:
        continue
    root = build()
    bpy.context.view_layer.update()
    print("== %s" % root.name)
    for k, v in found.items():
        for l in v:
            print("   LOOSE in %s: %s" % (k, l))
    found.clear()
    tree = _tree(root)
    reach = max((root.matrix_world @ v.co).length for v in root.data.vertices)
    reach_flat = max(Vector(((root.matrix_world @ v.co).x, (root.matrix_world @ v.co).y)).length for v in root.data.vertices)
    print("   REACH %.2f m (flat %.2f), size %s" % (reach, reach_flat, tuple(round(d, 2) for d in root.dimensions)))
    for dome in [c for c in root.children if c.name.startswith("dome")]:
        vs = [dome.matrix_world @ v.co for v in dome.data.vertices]
        base = min(v.z for v in vs)
        rim = [v for v in vs if v.z < base + 0.01]
        worst = 0.0
        for v in rim:
            out = Vector((v.x, v.y, 0)).normalized() if Vector((v.x, v.y)).length > 1e-4 else Vector((1, 0, 0))
            p = Vector((v.x, v.y, base)) + out * 0.02
            hit = tree.ray_cast(p + Vector((0, 0, 0.001)), Vector((0, 0, -1)), 5.0)
            up = tree.ray_cast(p, Vector((0, 0, 1)), 0.3)
            gap = 9.9 if hit[0] is None else (p.z - hit[0].z)
            if up[0] is not None:
                gap = 0.0
            worst = max(worst, gap)
        print("   DOME r %.2f base z %.2f at (%.2f, %.2f): worst gap under its rim %.2f m%s" % (
            max(Vector((v.x - dome.matrix_world.translation.x, v.y - dome.matrix_world.translation.y)).length for v in rim), base,
            dome.matrix_world.translation.x, dome.matrix_world.translation.y, worst, "  <-- NOT SEATED" if worst > 0.04 else ""))

# Builds every model in Close Encounters except the alien (who is built in code, as in Cryptlins).
#
#   blender -b --factory-startup --python tools/build_models.py
#
# Saves art/models.blend (every model laid out in a row, to open and edit) and one models/<name>.glb
# each. Models are low-poly and flat-coloured: Godot swaps each material for its own PS1 shader with
# the same colour, so a material's colour (and emission, for lights) is all that matters. A material
# named "shirt" or "walls" is tinted per copy in the game. Every model stands on the ground at its
# origin and faces -Y (which is +Z in Godot).

import bpy
import math
import os
import random

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
MODELS = os.path.join(ROOT, "models")
ART = os.path.join(ROOT, "art")

COLOURS = {
    "hide": (0.92, 0.9, 0.85), "spot": (0.08, 0.07, 0.07), "pink": (0.95, 0.62, 0.62),
    "horn": (0.9, 0.86, 0.72), "wool": (0.95, 0.94, 0.88), "black": (0.06, 0.06, 0.07),
    "red": (0.75, 0.12, 0.1), "yellow": (0.95, 0.75, 0.15), "white": (0.95, 0.95, 0.92), "rust": (0.45, 0.22, 0.12), "orange": (0.95, 0.45, 0.1), "cabbage": (0.6, 0.78, 0.45), "melon": (0.12, 0.32, 0.12), "melon_light": (0.45, 0.68, 0.3), "melon_flesh": (0.92, 0.22, 0.25), "melon_rind": (0.85, 0.92, 0.7), "fish_body": (0.5, 0.58, 0.5), "fish_belly": (0.9, 0.85, 0.75), "hwy_green": (0.1, 0.42, 0.22),
    "skin": (0.92, 0.7, 0.55), "denim": (0.22, 0.32, 0.6), "shirt": (0.8, 0.3, 0.25), "blush": (0.95, 0.55, 0.55),
    "straw": (0.88, 0.76, 0.42), "boot": (0.25, 0.16, 0.1), "hair": (0.3, 0.2, 0.12),
    "tyre": (0.08, 0.08, 0.08), "hub": (0.6, 0.6, 0.58), "glass": (0.35, 0.45, 0.55),
    "paint": (0.2, 0.45, 0.75), "olive": (0.3, 0.36, 0.2), "olive_dark": (0.2, 0.24, 0.13),
    "gun": (0.15, 0.15, 0.15), "tractor": (0.8, 0.15, 0.1), "barn": (0.62, 0.12, 0.1),
    "trim": (0.95, 0.93, 0.88), "roof": (0.3, 0.3, 0.33), "walls": (0.92, 0.9, 0.82),
    "wood": (0.5, 0.34, 0.2), "wood_dark": (0.32, 0.2, 0.12), "metal": (0.62, 0.64, 0.68),
    "metal_dark": (0.32, 0.34, 0.38), "cloak_cloth": (0.35, 0.32, 0.6), "leaf": (0.2, 0.42, 0.18), "leaf_dark": (0.12, 0.3, 0.14),
    "bark": (0.35, 0.24, 0.15), "hay": (0.85, 0.72, 0.35), "sack": (0.72, 0.6, 0.4),
    "jet": (0.5, 0.55, 0.58), "door": (0.4, 0.25, 0.15),
    # The West
    "cactus": (0.3, 0.5, 0.25), "cactus_light": (0.42, 0.58, 0.3), "fruit": (0.85, 0.3, 0.45), "sage": (0.3, 0.38, 0.24),
    "rock": (0.45, 0.42, 0.38), "talus": (0.7, 0.36, 0.2), "strata1": (0.8, 0.28, 0.1), "strata2": (0.9, 0.44, 0.18),
    "strata3": (0.68, 0.22, 0.08), "mesa_top": (0.5, 0.4, 0.22), "tower": (0.4, 0.36, 0.3), "tower_talus": (0.38, 0.36, 0.33),
    "mountain": (0.42, 0.4, 0.4), "snow": (0.95, 0.96, 1.0), "aspen_bark": (0.9, 0.88, 0.82), "aspen_leaf": (0.95, 0.72, 0.18),
    "pinyon": (0.18, 0.32, 0.18), "adobe": (0.78, 0.58, 0.4), "door_blue": (0.2, 0.45, 0.65), "chili": (0.8, 0.12, 0.08),
    "chrome": (0.78, 0.8, 0.84), "horse": (0.48, 0.3, 0.18), "mane": (0.15, 0.1, 0.08), "bison": (0.3, 0.2, 0.12),
    "bison_dark": (0.18, 0.12, 0.08), "longhorn": (0.8, 0.62, 0.42), "coyote": (0.6, 0.52, 0.4), "logs": (0.48, 0.32, 0.18),
    "stone": (0.5, 0.48, 0.46), "camp": (0.95, 0.5, 0.1), "rv_stripe": (0.55, 0.3, 0.15), "felt": (0.4, 0.28, 0.16),
    "orb_shell": (0.62, 0.6, 0.58),
    "bear": (0.22, 0.14, 0.09), "goat": (0.92, 0.9, 0.84), "elk": (0.5, 0.36, 0.22), "elk_dark": (0.28, 0.18, 0.1),
    "antler": (0.82, 0.76, 0.6), "pronghorn": (0.75, 0.52, 0.3), "rabbit": (0.6, 0.5, 0.4), "roadrunner": (0.35, 0.3, 0.25),
    "crow": (0.06, 0.06, 0.08), "hawk": (0.45, 0.3, 0.18), "hawk_light": (0.85, 0.78, 0.65), "pole": (0.36, 0.25, 0.16),
    "insulator": (0.4, 0.7, 0.6), "sasquatch": (0.3, 0.2, 0.13), "sasquatch_face": (0.18, 0.13, 0.1),
    "satellite": (0.75, 0.75, 0.7), "panel": (0.12, 0.18, 0.4), "gold": (1.0, 0.78, 0.2),
    "stone_pale": (0.78, 0.76, 0.7), "dome_green": (0.35, 0.6, 0.5), "water": (0.15, 0.3, 0.45),
    "awning": (0.75, 0.15, 0.12), "wheat_head": (0.92, 0.75, 0.3), "corn_leaf": (0.35, 0.55, 0.2), "corn_cob": (0.95, 0.82, 0.3),
    "pumpkin": (0.95, 0.5, 0.08), "hill": (0.3, 0.38, 0.2), "asphalt": (0.13, 0.13, 0.15),
    "brick": (0.55, 0.3, 0.22), "police_blue": (0.15, 0.25, 0.55), "concrete": (0.6, 0.6, 0.58), "hangar": (0.45, 0.48, 0.42),
    "transformer": (0.5, 0.55, 0.5), "hazard": (0.95, 0.75, 0.1),
    "regolith": (0.58, 0.57, 0.55), "regolith_dark": (0.4, 0.4, 0.4), "canvas_a": (0.95, 0.4, 0.3), "canvas_b": (0.95, 0.9, 0.8),
    "chrome_leg": (0.75, 0.77, 0.8), "drink": (0.35, 0.95, 0.5), "umbrella": (1.0, 0.5, 0.75), "black_hull": (0.09, 0.09, 0.11), "hull_edge": (0.2, 0.2, 0.24),
    "cooler_red": (0.8, 0.12, 0.1), "cooler_white": (0.93, 0.93, 0.9), "beer": (0.66, 0.38, 0.12), "beer_green": (0.22, 0.6, 0.28), "can_red": (0.85, 0.15, 0.15), "can_silver": (0.8, 0.82, 0.86), "beer_cap": (0.9, 0.75, 0.25),
    "ice": (0.8, 0.92, 1.0), "radio_body": (0.12, 0.12, 0.14), "radio_trim": (0.7, 0.72, 0.75), "speaker": (0.05, 0.05, 0.05),
    "moon_pale": (0.82, 0.81, 0.78), "moon_dark": (0.44, 0.43, 0.42),
    "cloak_dark": (0.2, 0.18, 0.4), "gold_dark": (0.72, 0.5, 0.1), "copper": (0.78, 0.42, 0.18),
}
GLOWS = {
    "window": ((1.0, 0.85, 0.45), 2.0), "siren_red": ((1.0, 0.1, 0.1), 3.0),
    "siren_blue": ((0.15, 0.35, 1.0), 3.0), "lights": ((1.0, 0.9, 0.4), 3.0),
    "lights_under": ((0.5, 1.0, 0.6), 3.0), "headlight": ((1.0, 0.95, 0.8), 2.0),
    "flame": ((1.0, 0.55, 0.15), 3.0), "neon": ((1.0, 0.35, 0.6), 3.0),
    "light_red": ((1.0, 0.2, 0.15), 3.0), "light_blue": ((0.3, 0.5, 1.0), 3.0), "light_white": ((1.0, 1.0, 0.95), 3.0),
    "light_amber": ((1.0, 0.65, 0.2), 3.0), "meteor_glow": ((0.4, 1.0, 0.5), 2.5), "pod_glow": ((0.4, 1.0, 0.5), 2.5), "spark": ((0.5, 0.8, 1.0), 3.0), "orb_glow": ((1.0, 0.6, 0.25), 2.0), "crystal": ((0.5, 0.28, 0.85), 0.55), "neon_pink": ((1.0, 0.3, 0.6), 2.5), "neon_blue": ((0.3, 0.7, 1.0), 2.5), "screen_glow": ((0.75, 0.85, 1.0), 1.3), "jelly": ((0.95, 0.28, 0.62), 0.3), "jelly_glow": ((0.6, 0.9, 1.0), 2.0),
    "foo_glow": ((0.85, 0.22, 0.03), 2.5), "booth_sign": ((0.75, 0.88, 1.0), 2.0), "clock_face": ((1.0, 0.95, 0.8), 1.3),
    "sign": ((1.0, 0.85, 0.55), 1.2),
    "laser_glow": ((1.0, 0.3, 0.42), 3.0),
}

_mats = {}


def mat(name):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    if name in GLOWS:
        c, strength = GLOWS[name]
        bsdf.inputs["Base Color"].default_value = (*c, 1.0)
        bsdf.inputs["Emission Color"].default_value = (*c, 1.0)
        bsdf.inputs["Emission Strength"].default_value = strength
    else:
        bsdf.inputs["Base Color"].default_value = (*COLOURS[name], 1.0)
    bsdf.inputs["Roughness"].default_value = 1.0
    m.diffuse_color = bsdf.inputs["Base Color"].default_value
    _mats[name] = m
    return m


def _done(obj, m):
    obj.data.materials.append(mat(m))
    return obj


def box(size, at, m, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=at, rotation=rot)
    o = bpy.context.object
    # (a big flat slab low on the ground, a lot or a runway, cut into a grid of about 3 m: the world
    # bends by each corner, and one left whole sags under the ground between its far corners)
    if size[2] < 0.7 and at[2] - size[2] * 0.5 < 0.5 and max(size[0], size[1]) > 3.5:
        import bmesh
        bm = bmesh.new()
        bm.from_mesh(o.data)
        for axis, length in ((0, size[0]), (1, size[1])):
            n = int(math.ceil(length / 3.0))
            for k in range(1, n):
                normal = (1, 0, 0) if axis == 0 else (0, 1, 0)
                co = [0.0, 0.0, 0.0]
                co[axis] = -0.5 + k / n
                bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=co, plane_no=normal)
        bm.to_mesh(o.data)
        bm.free()
    o.scale = size
    return _done(o, m)


def ball(size, at, m, segs=8, rings=5, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=0.5, location=at, rotation=rot)
    o = bpy.context.object
    o.scale = size
    return _done(o, m)


def drum(radius, depth, at, m, sides=8, rot=(0, 0, 0), top=None):
    if top is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=depth, location=at, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=radius, radius2=top, depth=depth, location=at, rotation=rot)
    return _done(bpy.context.object, m)


def rod(radius, a, b, m, sides=6):
    """A drum running from point `a` to point `b` (a strut that meets what it holds)"""
    from mathutils import Vector
    a, b = Vector(a), Vector(b)
    rot = Vector((0, 0, 1)).rotation_difference(b - a).to_euler()
    return drum(radius, (b - a).length, (a + b) / 2, m, sides, tuple(rot))


def cone(radius, depth, at, m, sides=6, rot=(0, 0, 0)):
    return drum(radius, depth, at, m, sides, rot, top=0.0)


def wheel(radius, width, at, m="tyre"):
    return [drum(radius, width, at, m, 8, (0, math.pi / 2, 0)),
            drum(radius * 0.5, width + 0.02, at, "hub", 6, (0, math.pi / 2, 0))]


def gable(w, d, h, at, m):
    """A roof: a prism w wide (X), d deep (Y), h high, its eaves at `at`."""
    mesh = bpy.data.meshes.new("gable")
    x, y = w / 2, d / 2
    verts = [(-x, -y, 0), (x, -y, 0), (0, -y, h), (-x, y, 0), (x, y, 0), (0, y, h)]
    faces = [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
    mesh.from_pydata(verts, [], faces)
    o = bpy.data.objects.new("gable", mesh)
    bpy.context.collection.objects.link(o)
    o.location = at
    return _done(o, m)


def join(name, parts):
    parts = [p for p in _flat(parts)]
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    o.data.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    # (every part was placed about the model's foot, though the origin is the first part's: see attach)
    return o


def attach(part, body):
    """Hangs `part` (a moving part, placed about the model's foot) on `body`, where it was put: a joined
    body's origin is its first part's, not the foot, so a plain parenting would shift it by that"""
    bpy.context.view_layer.update()
    part.parent = body
    part.matrix_parent_inverse = body.matrix_world.inverted()


def _flat(items):
    for i in items:
        if isinstance(i, (list, tuple)):
            yield from _flat(i)
        else:
            yield i


# ---------------------------------------------------------------- animals

def cow():
    p = [box((0.9, 1.7, 0.8), (0, 0, 1.05), "hide")]
    p += [box((0.5, 0.55, 0.5), (0, -1.0, 1.3), "hide"), box((0.42, 0.22, 0.32), (0, -1.33, 1.15), "pink")]
    for s in (-1, 1):
        p.append(cone(0.06, 0.25, (0.2 * s, -0.95, 1.62), "horn", rot=(0, 0.6 * s, 0)))
        p.append(box((0.22, 0.08, 0.12), (0.34 * s, -0.92, 1.42), "hide"))
        p.append(box((0.08, 0.06, 0.08), (0.14 * s, -1.28, 1.42), "spot"))
        for y in (-0.62, 0.62):
            p.append(box((0.2, 0.2, 0.65), (0.3 * s, y, 0.33), "hide"))
            p.append(box((0.21, 0.21, 0.1), (0.3 * s, y, 0.05), "spot"))
    p += [box((0.92, 0.5, 0.42), (0, -0.2, 1.2), "spot"), box((0.6, 0.4, 0.5), (0.18, 0.5, 1.12), "spot"),
          box((0.3, 0.3, 0.15), (0, 0.4, 0.6), "pink"), box((0.06, 0.06, 0.7), (0, 0.88, 0.95), "hide", (0.3, 0, 0)),
          box((0.1, 0.1, 0.14), (0, 0.98, 0.58), "spot")]
    return join("cow", p)


def pig():
    p = [box((0.6, 1.0, 0.55), (0, 0, 0.55), "pink"), box((0.46, 0.4, 0.42), (0, -0.6, 0.62), "pink"),
         drum(0.12, 0.1, (0, -0.83, 0.58), "pink", 6, (math.pi / 2, 0, 0))]
    for s in (-1, 1):
        p.append(box((0.14, 0.04, 0.16), (0.16 * s, -0.66, 0.9), "pink", (0.4, 0, 0)))
        p.append(box((0.06, 0.04, 0.06), (0.12 * s, -0.8, 0.72), "spot"))
        for y in (-0.32, 0.32):
            p.append(box((0.14, 0.14, 0.3), (0.2 * s, y, 0.15), "pink"))
    p.append(drum(0.06, 0.04, (0, 0.53, 0.7), "pink", 6, (math.pi / 2, 0, 0)))
    return join("pig", p)


def sheep():
    p = []
    for x, y, z in [(0, 0, 0.75), (0.2, 0.3, 0.8), (-0.2, 0.3, 0.8), (0.2, -0.3, 0.8), (-0.2, -0.3, 0.8), (0, 0, 0.98)]:
        p.append(ball((0.6, 0.65, 0.5), (x, y, z), "wool"))
    p += [box((0.3, 0.36, 0.36), (0, -0.62, 0.95), "black"), ball((0.4, 0.3, 0.2), (0, -0.55, 1.15), "wool")]
    for s in (-1, 1):
        p.append(box((0.18, 0.06, 0.08), (0.22 * s, -0.55, 1.0), "black"))
        p.append(box((0.06, 0.04, 0.06), (0.09 * s, -0.81, 1.0), "white"))
        for y in (-0.3, 0.3):
            p.append(box((0.1, 0.1, 0.5), (0.2 * s, y, 0.25), "black"))
    return join("sheep", p)


def chicken():
    p = [ball((0.36, 0.48, 0.36), (0, 0, 0.36), "white"), ball((0.22, 0.22, 0.24), (0, -0.2, 0.6), "white"),
         box((0.04, 0.1, 0.1), (0, -0.2, 0.75), "red"), box((0.03, 0.05, 0.08), (0, -0.32, 0.53), "red"),
         cone(0.04, 0.1, (0, -0.34, 0.6), "yellow", 4, (math.pi / 2, 0, 0)),
         box((0.2, 0.16, 0.22), (0, 0.24, 0.48), "white", (0.5, 0, 0))]
    for s in (-1, 1):
        p.append(box((0.03, 0.03, 0.2), (0.08 * s, 0, 0.1), "yellow"))
        p.append(box((0.04, 0.3, 0.2), (0.18 * s, 0.03, 0.38), "white"))
        p.append(box((0.03, 0.02, 0.04), (0.06 * s, -0.3, 0.64), "black"))
    return join("chicken", p)


# ---------------------------------------------------------------- people

def figure(name, hat, cowboy=False):
    """A person in October Valley's blocky style (after the 8 Bit Evil Returns sprites): a big head
    with bar eyes and blush, a short body, stubby legs; boxes measured in sprite pixels of `px`,
    about 1.5 m tall. A farmer has overalls and a straw hat, a cowboy a felt hat and a bandana."""
    px = 0.068

    def bx(x, y, z, m, mirror=False):
        out = [box(((x[1] - x[0]) * px, (y[1] - y[0]) * px, (z[1] - z[0]) * px),
                   ((x[0] + x[1]) / 2 * px, (y[0] + y[1]) / 2 * px, (z[0] + z[1]) / 2 * px), m)]
        if mirror:
            out += bx((-x[1], -x[0]), y, z, m)
        return out
    p = []
    p += bx((1.3, 2.7), (-0.7, 0.7), (0.8, 7), "denim", True)
    p += bx((1.2, 2.8), (-2.0, 0.8), (0, 1.1), "boot", True)
    p += bx((-3, 3), (-1.6, 1.6), (6.8, 8.5), "denim")
    p += bx((-3, 3), (-1.7, 1.7), (8.5, 13.5), "shirt")
    p += bx((-1.5, 1.5), (-1.2, 1.2), (13.5, 14.6), "skin")
    p += bx((-4, 4), (-3.5, 3.5), (15.2, 19.6), "skin")
    p += bx((-3.3, 3.3), (-3.2, 3.2), (14.4, 15.2), "skin")
    p += bx((1.0, 2.0), (-3.62, -3.4), (15.8, 18.2), "black", True)
    p += bx((2.9, 3.9), (-3.58, -3.4), (15.3, 16.1), "blush", True)
    p += bx((3.0, 4.4), (-0.8, 0.8), (9.6, 13.4), "shirt", True)
    p += bx((3.1, 4.3), (-0.7, 0.7), (8.4, 9.6), "skin", True)
    if cowboy:
        p += [drum(6.8 * px, 0.5 * px, (0, 0, 19.9 * px), "felt", 10), drum(4.3 * px, 2.8 * px, (0, 0, 21.4 * px), "felt", 8, top=3.6 * px)]
        p += bx((-3.1, 3.1), (-1.9, 1.7), (12.4, 13.6), "chili")
        p += bx((-4.3, 4.3), (1.6, 3.8), (16.0, 19.6), "hair")
    elif hat:
        p += [drum(6.2 * px, 0.5 * px, (0, 0, 19.9 * px), "straw", 10), drum(4.3 * px, 2.4 * px, (0, 0, 21.2 * px), "straw", 8)]
        # (overalls: a bib and two straps over the shirt)
        p += bx((-2.2, 2.2), (-1.85, -1.6), (8.5, 12.4), "denim")
        p += bx((1.4, 2.2), (-1.85, 1.85), (12.4, 13.5), "denim", True)
        p += bx((-4.3, 4.3), (1.6, 3.8), (16.0, 19.6), "hair")
    else:
        p += bx((-4.3, 4.3), (-3.8, 3.8), (19.6, 20.8), "hair")
        p += bx((-4.3, 4.3), (1.6, 3.8), (16.0, 19.6), "hair")
        p += bx((3.6, 4.3), (-1.2, 1.6), (17.0, 19.6), "hair", True)
        p += bx((-4.3, 4.3), (-3.8, -3.3), (18.8, 19.6), "hair")
    return join(name, p)


def scarecrow():
    p = [box((0.1, 0.1, 2.0), (0, 0.05, 1.0), "wood"), box((1.5, 0.08, 0.08), (0, 0.05, 1.45), "wood"),
         box((0.44, 0.24, 0.6), (0, 0, 1.3), "shirt"), box((1.3, 0.16, 0.16), (0, 0, 1.45), "shirt"),
         ball((0.36, 0.34, 0.4), (0, 0, 1.85), "sack"),
         drum(0.36, 0.04, (0, 0, 2.04), "straw", 10), drum(0.16, 0.24, (0, 0, 2.14), "straw", 6, top=0.1),
         box((0.24, 0.1, 0.2), (0, 0, 0.92), "denim")]
    for s in (-1, 1):
        p.append(box((0.06, 0.02, 0.06), (0.08 * s, -0.17, 1.9), "black"))
        p.append(cone(0.08, 0.2, (0.72 * s, 0, 1.45), "straw", 5, (0, math.pi / 2 * s, 0)))
    return join("scarecrow", p)


# ---------------------------------------------------------------- vehicles

def car_body(name, paint, length=4.0, extra=()):
    p = [box((1.7, length, 0.6), (0, 0, 0.6), paint), box((1.5, length * 0.5, 0.5), (0, 0.15, 1.15), paint),
         box((1.52, length * 0.46, 0.36), (0, 0.15, 1.15), "glass")]
    for s in (-1, 1):
        for y in (-length * 0.32, length * 0.32):
            p += wheel(0.36, 0.26, (0.82 * s, y, 0.36))
        p.append(box((0.3, 0.05, 0.14), (0.55 * s, -length / 2, 0.7), "headlight"))
        p.append(box((0.3, 0.05, 0.12), (0.55 * s, length / 2, 0.7), "red"))
    p += list(extra)
    return join(name, p)


def car():
    return car_body("car", "paint")


def police_car():
    extra = [box((1.72, 1.2, 0.58), (0, 0.0, 0.62), "white"), box((0.5, 0.3, 0.14), (-0.3, 0.15, 1.47), "siren_red"),
             box((0.5, 0.3, 0.14), (0.3, 0.15, 1.47), "siren_blue")]
    return car_body("police_car", "black", 4.2, extra)


def pickup():
    p = [box((1.8, 4.6, 0.7), (0, 0, 0.75), "red"), box((1.6, 1.4, 0.65), (0, -0.55, 1.4), "red"),
         box((1.62, 1.3, 0.4), (0, -0.55, 1.42), "glass"), box((1.5, 2.0, 0.1), (0, 1.15, 1.1), "wood_dark")]
    for s in (-1, 1):
        for y in (-1.5, 1.5):
            p += wheel(0.42, 0.3, (0.88 * s, y, 0.42))
        p.append(box((0.3, 0.05, 0.14), (0.6 * s, -2.3, 0.85), "headlight"))
    return join("pickup", p)


def tractor():
    p = [box((1.0, 2.2, 0.8), (0, -0.4, 1.05), "tractor"), box((1.2, 1.0, 0.25), (0, 0.6, 1.1), "tractor"),
         box((0.5, 0.4, 0.1), (0, 0.6, 1.4), "black"), box((0.5, 0.08, 0.5), (0, 0.85, 1.6), "black"),
         drum(0.07, 1.0, (0.3, -0.9, 1.9), "black", 6), box((0.7, 0.05, 0.25), (0, -1.52, 1.05), "headlight")]
    for s in (-1, 1):
        p += wheel(0.85, 0.45, (0.85 * s, 0.6, 0.85))
        p += wheel(0.45, 0.3, (0.65 * s, -1.2, 0.45))
    return join("tractor", p)


def jeep():
    p = [box((1.7, 3.8, 0.7), (0, 0, 0.8), "olive"), box((1.6, 0.06, 0.6), (0, -0.5, 1.45), "glass", (0.3, 0, 0)),
         box((1.7, 0.6, 0.12), (0, -1.6, 0.85), "olive_dark"), drum(0.08, 1.0, (0, 0.6, 1.6), "gun", 6),
         box((0.3, 0.9, 0.22), (0, 0.4, 2.1), "gun"), drum(0.05, 0.9, (0, -0.4, 2.12), "gun", 6, (math.pi / 2, 0, 0)),
         box((0.5, 0.06, 0.4), (0, 0.0, 2.15), "olive_dark")]
    for s in (-1, 1):
        for y in (-1.25, 1.25):
            p += wheel(0.45, 0.32, (0.88 * s, y, 0.45))
        p.append(box((0.24, 0.05, 0.14), (0.55 * s, -1.9, 1.0), "headlight"))
    return join("jeep", p)


def tank():
    hull = [box((2.6, 5.4, 0.9), (0, 0, 0.95), "olive"), box((2.2, 1.0, 0.5), (0, -2.6, 0.8), "olive", (0.5, 0, 0))]
    for s in (-1, 1):
        hull.append(box((0.6, 5.8, 0.8), (1.45 * s, 0, 0.45), "tyre"))
        for y in (-2.0, -1.0, 0.0, 1.0, 2.0):
            hull.append(drum(0.32, 0.62, (1.45 * s, y, 0.42), "metal_dark", 8, (0, math.pi / 2, 0)))
    body = join("tank", hull)
    tur = [drum(1.1, 0.7, (0, 0.2, 1.75), "olive", 8), box((1.6, 1.8, 0.5), (0, 0.4, 1.75), "olive"),
           drum(0.12, 3.2, (0, -2.2, 1.8), "olive_dark", 6, (math.pi / 2, 0, 0)), drum(0.3, 0.2, (0.4, 0.8, 2.15), "olive_dark", 6)]
    turret = join("turret", tur)
    attach(turret, body)
    return body


def jet():
    p = [drum(0.55, 9.0, (0, 0, 0), "jet", 8, (math.pi / 2, 0, 0)), cone(0.55, 1.8, (0, -5.4, 0), "jet", 8, (-math.pi / 2, 0, 0)),
         box((1.0, 1.4, 0.4), (0, -2.6, 0.45), "glass"), drum(0.5, 0.4, (0, 4.6, 0), "flame", 8, (math.pi / 2, 0, 0))]
    wing = bpy.data.meshes.new("wing")
    wing.from_pydata([(0, -1.5, 0), (5.2, 1.6, 0), (5.2, 2.4, 0), (0, 3.0, 0), (0, -1.5, 0.12), (5.2, 1.6, 0.12), (5.2, 2.4, 0.12), (0, 3.0, 0.12)],
                     [], [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)])
    for s in (-1, 1):
        o = bpy.data.objects.new("wing", wing.copy())
        bpy.context.collection.objects.link(o)
        o.scale = (s, 1, 1)
        o.location = (0, 0, -0.1)
        p.append(_done(o, "jet"))
        p.append(box((0.08, 1.4, 1.6), (0.7 * s, 3.4, 0.9), "jet", (0, 0.4 * s, 0)))
    return join("jet", p)


# ---------------------------------------------------------------- things about the farm

def hay_bale():
    return join("hay_bale", [drum(0.65, 1.2, (0, 0, 0.65), "hay", 10, (0, math.pi / 2, 0))])


def outhouse():
    p = [box((1.2, 1.2, 2.1), (0, 0, 1.05), "wood"), box((1.4, 1.4, 0.12), (0, 0, 2.15), "wood_dark", (0.12, 0, 0)),
         box((0.8, 0.05, 1.7), (0, -0.61, 0.9), "door"), box((0.16, 0.06, 0.2), (0, -0.64, 1.55), "window")]
    return join("outhouse", p)


def barn():
    p = [box((8.0, 10.0, 5.0), (0, 0, 2.5), "barn"), gable(8.6, 10.4, 3.4, (0, 0, 5.0), "roof"),
         box((3.0, 0.1, 3.4), (0, -5.0, 1.7), "barn"), box((3.1, 0.12, 0.2), (0, -5.03, 3.4), "trim"),
         box((0.2, 0.12, 3.4), (-1.5, -5.03, 1.7), "trim"), box((0.2, 0.12, 3.4), (1.5, -5.03, 1.7), "trim"),
         box((3.2, 0.12, 0.2), (0, -5.03, 1.7), "trim", (0, 0.85, 0)), box((3.2, 0.12, 0.2), (0, -5.03, 1.7), "trim", (0, -0.85, 0)),
         box((1.2, 0.1, 1.0), (0, -5.05, 5.3), "window")]
    return join("barn", p)


def farmhouse():
    """A two-storey farmhouse with a porch wrapped round its front (-Y) and both sides: a deck, a
    roof on posts, railings, and the door in the middle of the front"""
    p = [box((7.0, 6.0, 5.6), (0, 0, 2.8), "walls"), gable(7.6, 6.6, 2.6, (0, 0, 5.6), "roof"),
         box((0.8, 0.8, 1.8), (2.0, 1.5, 7.4), "brick"), box((1.0, 0.1, 2.0), (0, -3.0, 1.0), "door"),
         box((9.6, 8.0, 0.25), (0, -0.8, 0.12), "wood"), box((9.8, 8.2, 0.14), (0, -0.8, 2.75), "roof")]
    for x in (-4.65, -2.3, 2.3, 4.65):
        p.append(box((0.16, 0.16, 2.6), (x, -4.65, 1.4), "trim"))
    for y in (-2.0, 0.6, 3.05):
        for x in (-4.65, 4.65):
            p.append(box((0.16, 0.16, 2.6), (x, y, 1.4), "trim"))
    # (railings: along the front either side of the steps, and down both sides)
    for x0, x1 in ((-4.65, -0.9), (0.9, 4.65)):
        p.append(box((x1 - x0, 0.08, 0.08), ((x0 + x1) / 2, -4.65, 1.0), "trim"))
    for x in (-4.65, 4.65):
        p.append(box((0.08, 7.7, 0.08), (x, -0.8, 1.0), "trim"))
    for x in (-2.2, 2.2):
        p.append(box((1.0, 0.1, 1.0), (x, -3.02, 1.7), "window"))
        p.append(box((1.0, 0.1, 1.0), (x, -3.02, 4.3), "window"))
    for y in (-1.4, 1.4):
        for z in (1.7, 4.3):
            p.append(box((0.1, 0.9, 0.9), (3.52, y, z), "window"))
            p.append(box((0.1, 0.9, 0.9), (-3.52, y, z), "window"))
    return join("farmhouse", p)


def storefront():
    """A small-town main street shop: two storeys behind a tall false front with a sign across the
    top, a big lit shop window and a door at the front (-Y), and a striped awning over the pavement"""
    p = [box((6.0, 7.0, 6.0), (0, 0, 3.0), "walls"), box((6.2, 0.3, 7.8), (0, -3.5, 3.9), "walls"),
         box((6.5, 0.45, 0.3), (0, -3.6, 7.8), "trim"), box((4.6, 0.12, 1.0), (0, -3.72, 6.7), "sign"),
         box((3.2, 0.12, 1.9), (-0.9, -3.7, 1.35), "window"), box((1.0, 0.12, 2.2), (2.1, -3.7, 1.1), "door"),
         box((6.3, 1.8, 0.12), (0, -4.5, 2.9), "awning", (0.28, 0, 0)), box((6.3, 0.06, 0.4), (0, -5.35, 2.55), "awning")]
    for x in (-2.0, 0.0, 2.0):
        p.append(box((1.0, 0.12, 1.2), (x, -3.7, 4.7), "window"))
    return join("storefront", p)


def clock_tower():
    """A town's clock tower: brick, a lit clock face on each side near the top, a belfry and a
    pointed roof"""
    p = [box((3.2, 3.2, 12.0), (0, 0, 6.0), "brick"), box((3.7, 3.7, 0.4), (0, 0, 12.2), "trim"),
         box((2.8, 2.8, 2.6), (0, 0, 13.7), "brick"), box((3.3, 3.3, 0.3), (0, 0, 15.1), "trim"),
         cone(2.6, 3.6, (0, 0, 17.0), "roof", 4, (0, 0, math.pi / 4)), box((1.2, 1.2, 0.3), (0, 0, 0.15), "stone")]
    for a in range(4):
        r = a * math.pi / 2
        dx, dy = math.sin(r), -math.cos(r)
        p.append(drum(1.05, 0.12, (dx * 1.62, dy * 1.62, 10.4), "clock_face", 16, (math.pi / 2, 0, r)))
        p.append(box((0.1, 0.06, 0.8) if a % 2 == 0 else (0.06, 0.1, 0.8), (dx * 1.7, dy * 1.7, 10.7), "black"))
        p.append(box((0.5, 0.06, 0.1) if a % 2 == 0 else (0.06, 0.5, 0.1), (dx * 1.7 + (0.22 if a % 2 == 0 else 0), dy * 1.7 + (0 if a % 2 == 0 else 0.22), 10.4), "black"))
    return join("clock_tower", p)


def wheat():
    """A stook of wheat: sheaves leant together, their heads gold"""
    p = []
    for i in range(6):
        a = i / 6 * math.tau
        p.append(box((0.12, 0.12, 1.1), (math.cos(a) * 0.18, math.sin(a) * 0.18, 0.5), "straw", (math.sin(a) * 0.25, -math.cos(a) * 0.25, 0)))
        p.append(box((0.18, 0.18, 0.35), (math.cos(a) * 0.08, math.sin(a) * 0.08, 1.1), "wheat_head"))
    return join("wheat", p)


def corn():
    """A corn stalk: tall and green, leaves off it, a cob and a tassel"""
    p = [box((0.1, 0.1, 2.2), (0, 0, 1.1), "corn_leaf"), box((0.16, 0.16, 0.5), (0.14, 0, 1.2), "corn_cob", (0, 0.4, 0)),
         box((0.06, 0.3, 0.3), (0, 0, 2.3), "straw")]
    for i, z in enumerate((0.7, 1.1, 1.5, 1.85)):
        a = i * 2.2
        p.append(box((0.8, 0.12, 0.04), (math.cos(a) * 0.35, math.sin(a) * 0.35, z), "corn_leaf", (0, -0.4, a)))
    return join("corn", p)


def pumpkin():
    """A pumpkin, ribbed, with its stem"""
    p = [ball((0.9, 0.9, 0.62), (0, 0, 0.31), "pumpkin", 10, 6), box((0.08, 0.08, 0.22), (0, 0, 0.68), "corn_leaf")]
    return join("pumpkin", p)


def sunflower():
    """A sunflower: a tall stalk, broad leaves, its big yellow head with a dark middle"""
    p = [box((0.08, 0.08, 2.0), (0, 0, 1.0), "corn_leaf"), drum(0.42, 0.06, (0, -0.1, 2.05), "yellow", 12, (math.pi / 2 - 0.3, 0, 0)),
         drum(0.22, 0.08, (0, -0.13, 2.05), "wood_dark", 10, (math.pi / 2 - 0.3, 0, 0))]
    for i, z in enumerate((0.7, 1.2)):
        p.append(box((0.5, 0.3, 0.04), (0.25 * (1 if i % 2 else -1), 0, z), "corn_leaf", (0, 0.3 * (1 if i % 2 else -1), 0)))
    return join("sunflower", p)


def cabbage():
    """A cabbage: a pale green head in its spread outer leaves"""
    p = [ball((0.5, 0.5, 0.42), (0, 0, 0.24), "cabbage", 8, 5)]
    for i in range(5):
        a = i / 5 * math.tau
        p.append(ball((0.42, 0.28, 0.1), (math.cos(a) * 0.28, math.sin(a) * 0.28, 0.1), "leaf", 6, 3, (0.4, 0, a)))
    return join("cabbage", p)


def striped_melon(length, width, height, at, rings=10, sides=16):
    """A watermelon's body: a long egg of dark green with pale stripes running nose to tail"""
    verts, faces, face_mats = [], [], []
    for i in range(rings + 1):
        u = i / rings * math.pi
        for j in range(sides):
            v = j / sides * math.tau
            verts.append((at[0] - math.cos(u) * length * 0.5, at[1] + math.sin(u) * math.cos(v) * width * 0.5,
                          at[2] + math.sin(u) * math.sin(v) * height * 0.5))
    for i in range(rings):
        for j in range(sides):
            a, b = i * sides + j, i * sides + (j + 1) % sides
            faces.append((a, b, b + sides, a + sides))
            face_mats.append(j % 4 == 0)
    mesh = bpy.data.meshes.new("melon_body")
    mesh.from_pydata(verts, [], faces)
    o = bpy.data.objects.new("melon_body", mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat("melon"))
    o.data.materials.append(mat("melon_light"))
    for poly, light in zip(o.data.polygons, face_mats):
        poly.material_index = 1 if light else 0
    return o


def melon():
    """A watermelon: a round striped ball, dark green with pale bands running round it from the stub
    of its stem"""
    return join("melon", [striped_melon(1.15, 1.15, 1.1, (0, 0, 0.53)), box((0.18, 0.07, 0.07), (0.64, 0, 0.53), "corn_leaf")])


def pepper():
    """A chilli pepper plant: a low leafy bush hung with red and green peppers"""
    p = [roughen(ball((0.7, 0.7, 0.6), (0, 0, 0.35), "leaf", 7, 4), 0.06, 51)]
    for i in range(6):
        a = i / 6 * math.tau
        p.append(cone(0.06, 0.24, (math.cos(a) * 0.3, math.sin(a) * 0.3, 0.28), "chili" if i % 3 else "leaf_dark", 6, (math.pi, 0, 0)))
    return join("pepper", p)


def hill():
    """A low rolling hill, grassed, its foot sunk in the ground"""
    return join("hill", [ball((28.0, 24.0, 4.6), (0, 0, 0), "hill", 12, 6)])


def control_tower():
    """An airfield's control tower: a concrete shaft and a glass cab with a beacon on top"""
    p = [box((2.4, 2.4, 9.0), (0, 0, 4.5), "concrete"), box((4.2, 4.2, 0.3), (0, 0, 9.15), "metal_dark"),
         box((3.8, 3.8, 2.0), (0, 0, 10.3), "glass"), box((4.2, 4.2, 0.3), (0, 0, 11.45), "metal_dark"),
         drum(0.2, 0.6, (0, 0, 11.9), "metal", 6), ball((0.35, 0.35, 0.35), (0, 0, 12.3), "light_red", 6, 3)]
    return join("control_tower", p)


def plane():
    """A little high-winged prop plane, nose to -Y"""
    p = [box((0.9, 5.0, 1.0), (0, 0, 1.3), "white"), box((7.5, 1.3, 0.12), (0, -0.4, 1.9), "white"),
         box((2.6, 0.8, 0.1), (0, 2.3, 1.45), "white"), box((0.1, 0.8, 1.0), (0, 2.3, 1.9), "red"),
         box((0.92, 1.1, 0.5), (0, -0.9, 1.75), "glass"), box((0.1, 0.1, 1.6), (0, -2.55, 1.3), "metal_dark"),
         box((1.6, 0.1, 0.1), (0, -2.6, 1.3), "metal_dark"), box((7.6, 0.2, 0.06), (0, -0.4, 1.97), "red")]
    for x in (-0.9, 0.9):
        p.append(box((0.08, 0.08, 0.9), (x, -0.4, 0.55), "metal_dark"))
        p.append(drum(0.28, 0.16, (x, -0.4, 0.28), "tyre", 8, (0, math.pi / 2, 0)))
    p.append(drum(0.2, 0.12, (0, 2.0, 0.25), "tyre", 8, (0, math.pi / 2, 0)))
    return join("plane", p)


def runway():
    """An airfield's runway: 80 m of tarmac with a dashed white line down it and its ends marked"""
    p = [box((10.0, 80.0, 0.12), (0, 0, 0.06), "asphalt")]
    for i in range(10):
        p.append(box((0.5, 4.0, 0.06), (0, -36.0 + i * 8.0, 0.15), "white"))
    for end in (-1, 1):
        for x in (-3.5, -2.0, 2.0, 3.5):
            p.append(box((0.6, 5.0, 0.06), (x, end * 36.5, 0.15), "white"))
    return join("runway", p)


def house():
    """A little town house, proportioned like a doll's house (tall for its size, like the farmhouse):
    a storey and a half of clapboard on a foundation, a steep shingled roof with eaves, a brick
    chimney, a stoop at the door under its own little roof, and framed windows with shutters"""
    w, d, h = 5.2, 4.4, 4.2
    front = -d / 2
    p = [box((w + 0.2, d + 0.2, 0.35), (0, 0, 0.17), "concrete"),
         box((w, d, h), (0, 0, 0.35 + h / 2), "walls"),
         gable(w + 0.7, d + 0.7, 3.0, (0, 0, 0.35 + h), "roof"),
         box((0.6, 0.6, 2.4), (1.5, 0.7, h + 2.3), "brick"),
         box((0.95, 0.12, 2.0), (0, front - 0.02, 1.35), "door"),
         # the stoop: a step, its deck, two posts and a little roof over it
         box((1.8, 0.5, 0.18), (0, front - 1.3, 0.09), "concrete"),
         box((2.2, 1.0, 0.3), (0, front - 0.55, 0.15), "wood"),
         box((2.4, 1.3, 0.12), (0, front - 0.6, 2.75), "roof")]
    for x in (-1.0, 1.0):
        p.append(box((0.14, 0.14, 2.45), (x, front - 1.1, 1.5), "trim"))
    # windows: two down, two up, one in each side, one in the gable; each in a white frame, the
    # downstairs ones with shutters
    def window(x, z, ww, wh, shutters):
        p.append(box((ww + 0.24, 0.08, wh + 0.24), (x, front - 0.03, z), "trim"))
        p.append(box((ww, 0.1, wh), (x, front - 0.06, z), "window"))
        if shutters:
            for s in (-1, 1):
                p.append(box((0.32, 0.08, wh + 0.1), (x + s * (ww / 2 + 0.32), front - 0.04, z), "door"))
    for x in (-1.6, 1.6):
        window(x, 1.65, 0.85, 1.05, True)
        window(x, 3.45, 0.75, 0.8, False)
    window(0, 5.25, 0.55, 0.55, False)
    for s in (-1, 1):
        p.append(box((0.08, 1.0, 1.15), (s * (w / 2 + 0.03), 0, 1.65), "trim"))
        p.append(box((0.1, 0.8, 0.95), (s * (w / 2 + 0.06), 0, 1.65), "window"))
    return join("house", p)


def silo():
    return join("silo", [drum(2.0, 9.0, (0, 0, 4.5), "metal", 10), ball((4.0, 4.0, 2.8), (0, 0, 9.0), "metal_dark", 10, 4),
                         box((0.2, 0.1, 8.0), (0, -2.0, 4.5), "metal_dark")])


def tree():
    return join("tree", [drum(0.3, 2.6, (0, 0, 1.3), "bark", 6), ball((3.2, 3.2, 2.8), (0, 0, 3.6), "leaf", 8, 5),
                         ball((2.2, 2.2, 2.0), (0.6, 0.4, 4.8), "leaf", 7, 4)])


def pine():
    return join("pine", [drum(0.25, 1.6, (0, 0, 0.8), "bark", 6), cone(2.0, 3.0, (0, 0, 2.6), "leaf_dark", 7),
                         cone(1.6, 2.6, (0, 0, 3.9), "leaf_dark", 7), cone(1.1, 2.2, (0, 0, 5.1), "leaf_dark", 7)])


def willow():
    """A weeping willow by the water: a thick leaning trunk, a high rounded crown, and thin strands of
    leaves hanging from all round it nearly to the ground, in two layers"""
    p = [drum(0.38, 3.0, (0.15, 0, 1.5), "bark", 7, (0, 0.12, 0)), drum(0.2, 1.4, (0.6, 0.2, 3.4), "bark", 6, (0.3, 0.5, 0)),
         roughen(ball((3.4, 3.4, 2.6), (0.3, 0, 4.3), "leaf", 9, 5), 0.15, 30)]
    rnd = random.Random(31)
    for layer, (r, top) in enumerate(((1.75, 4.4), (1.25, 4.9))):
        count = 26 if layer == 0 else 18
        for i in range(count):
            a = i / count * math.tau + rnd.uniform(-0.08, 0.08)
            long = rnd.uniform(2.2, 3.2) - layer * 0.5
            p.append(box((0.22, 0.06, long), (0.3 + r * math.cos(a), r * math.sin(a), top - long * 0.5), "leaf" if (i + layer) % 3 else "leaf_dark", (0, 0, a + math.pi / 2)))
    return join("willow", p)


def cottonwood():
    """A great plains cottonwood: a tall grey trunk forking into two, a high, ragged, open crown"""
    p = [drum(0.42, 3.4, (0, 0, 1.7), "bark", 7), drum(0.24, 2.4, (0.5, 0, 4.1), "bark", 6, (0, 0.4, 0)),
         drum(0.22, 2.2, (-0.45, 0.1, 4.0), "bark", 6, (0, -0.45, 0))]
    rnd = random.Random(33)
    for i in range(6):
        a = i / 6 * math.tau
        p.append(roughen(ball((2.4, 2.2, 1.8), (1.6 * math.cos(a), 1.4 * math.sin(a), 5.6 + rnd.uniform(-0.4, 0.7)), "leaf" if i % 2 else "aspen_leaf", 7, 4), 0.2, 80 + i))
    p.append(roughen(ball((2.6, 2.6, 2.0), (0, 0, 6.6), "leaf", 7, 4), 0.2, 90))
    return join("cottonwood", p)


def joshua_tree():
    """A Joshua tree of the Mojave: a shaggy trunk branching in crooked arms, each ending in a spiky
    tuft of blades"""
    p = [drum(0.26, 2.2, (0, 0, 1.1), "sage", 6)]
    arms = [((0.0, 0.0, 2.1), 0.5, 0.0, 1.3), ((0.0, 0.0, 2.0), 0.6, 2.2, 1.1), ((0.0, 0.0, 1.6), 0.7, 4.1, 1.0)]
    for base, lean, turn, long in arms:
        tip = (base[0] + math.cos(turn) * math.sin(lean) * long, base[1] + math.sin(turn) * math.sin(lean) * long, base[2] + math.cos(lean) * long)
        mid = ((base[0] + tip[0]) / 2, (base[1] + tip[1]) / 2, (base[2] + tip[2]) / 2)
        p.append(drum(0.16, long, mid, "sage", 5, (0, lean, turn)))
        for k in range(7):
            a = k / 7 * math.tau
            p.append(cone(0.07, 0.6, (tip[0] + 0.12 * math.cos(a), tip[1] + 0.12 * math.sin(a), tip[2] + 0.25), "cactus", 4, (0.6 * math.sin(a), -0.6 * math.cos(a), 0)))
        p.append(ball((0.34, 0.34, 0.3), tip, "cactus_light", 6, 3))
    return join("joshua_tree", p)


def fence():
    p = [box((0.14, 0.14, 1.2), (-1.5, 0, 0.6), "wood"), box((0.14, 0.14, 1.2), (1.5, 0, 0.6), "wood"),
         box((3.1, 0.08, 0.14), (0, 0, 0.9), "wood"), box((3.1, 0.08, 0.14), (0, 0, 0.5), "wood")]
    return join("fence", p)


def tent():
    return join("tent", [gable(5.0, 6.0, 3.0, (0, 0, 0), "olive"), box((1.2, 0.1, 1.8), (0, -3.0, 0.9), "olive_dark")])


def floodlight():
    return join("floodlight", [drum(0.15, 6.0, (0, 0, 3.0), "metal_dark", 6), box((1.0, 0.6, 0.8), (0, -0.3, 6.1), "metal_dark", (-0.6, 0, 0)),
                               box((0.8, 0.1, 0.6), (0, -0.62, 5.9), "headlight", (-0.6, 0, 0))])


# ---------------------------------------------------------------- the saucer

def ufo():
    p = [ball((5.2, 5.2, 0.9), (0, 0, 0), "metal", 16, 6), drum(2.65, 0.14, (0, 0, 0), "metal_dark", 16),
         drum(1.5, 0.5, (0, 0, -0.35), "metal_dark", 12, top=1.0), drum(1.0, 0.12, (0, 0, -0.62), "lights_under", 12),
         drum(1.06, 0.36, (0, 0, 0.38), "metal_dark", 12)]
    for i in range(12):
        a = i / 12 * math.tau
        p.append(ball((0.28, 0.28, 0.2), (2.62 * math.cos(a), 2.62 * math.sin(a), 0), "lights", 6, 3))
    body = join("ufo", p)
    dome = _dome(1.0, 0.5)
    dome.parent = body
    return body


# ---------------------------------------------------------------- the West

def lathe(name, profile, mats, sides=10, wobble=0.0, flute=0.0, flute_from=0, seed=1):
    """A shape turned on a lathe: `profile` is (radius, height) from the bottom up, the last a point
    or a small cap. `mats[i]` paints the band between ring i and ring i+1 (and the last the cap).
    `wobble` roughs up every corner; `flute` notches every other one from ring `flute_from` up,
    for columns of rock."""
    rnd = random.Random(seed)
    verts, faces, face_mats = [], [], []
    for i, (r, z) in enumerate(profile):
        for j in range(sides):
            a = j / sides * math.tau
            rr = r * (1.0 - flute if (j % 2 and i >= flute_from) else 1.0)
            rr += rnd.uniform(-wobble, wobble) if r > 0.5 else 0.0
            zz = z + (rnd.uniform(-wobble, wobble) * 0.5 if 0 < i < len(profile) - 1 else 0.0)
            verts.append((rr * math.cos(a), rr * math.sin(a), zz))
    for i in range(len(profile) - 1):
        for j in range(sides):
            a, b = i * sides + j, i * sides + (j + 1) % sides
            faces.append((a, b, b + sides, a + sides))
            face_mats.append(min(i, len(mats) - 1))
    top = len(profile) - 1
    faces.append(tuple(top * sides + j for j in range(sides)))
    face_mats.append(len(mats) - 1)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    names = []
    for m in mats:
        if m not in names:
            names.append(m)
            o.data.materials.append(mat(m))
    for poly, m in zip(o.data.polygons, face_mats):
        poly.material_index = names.index(mats[m])
    return o


def roughen(o, amount, seed):
    rnd = random.Random(seed)
    bpy.context.view_layer.objects.active = o
    for v in o.data.vertices:
        v.co.x += rnd.uniform(-amount, amount)
        v.co.y += rnd.uniform(-amount, amount)
        v.co.z += rnd.uniform(-amount, amount) * 0.6
    return o


def mesa():
    return join("mesa", [lathe("mesa", [(19, 0), (14.5, 3), (14, 4.5), (13.8, 7), (13.6, 9.5), (13.4, 12), (0, 12.2)],
                               ["talus", "strata1", "strata2", "strata3", "strata2", "mesa_top", "mesa_top"], 11, 0.7, seed=3)])


def butte():
    return join("butte", [lathe("butte", [(10, 0), (6.5, 3.5), (6.1, 6.5), (5.8, 11), (5.6, 16), (0, 16.2)],
                                ["talus", "strata1", "strata2", "strata3", "mesa_top", "mesa_top"], 9, 0.4, seed=5)])


def devils_tower():
    # Fluted columns of grey rock standing out of a skirt of fallen ones
    skirt = lathe("skirt", [(19, 0), (14, 2.5), (10, 5.5), (0, 5.6)], ["tower_talus", "tower_talus", "tower_talus"], 14, 0.9, seed=7)
    column = lathe("column", [(9.2, 4.5), (8.4, 12), (7.4, 20), (6.6, 25), (6.2, 25.6), (0, 26)], ["tower", "tower", "tower", "tower", "talus"],
                   28, 0.15, flute=0.1, seed=8)
    p = [skirt, column]
    rnd = random.Random(9)
    for i in range(9):
        a = rnd.uniform(0, math.tau)
        d = rnd.uniform(11, 17)
        p.append(roughen(ball((2.2, 1.6, 1.2), (d * math.cos(a), d * math.sin(a), 1.2), "tower_talus", 6, 4), 0.2, i))
    return join("devils_tower", p)


def peak():
    """A Rocky Mountain peak: craggy, a little taller than a mesa, its main summit with two shoulders, rock
    outcrops on its flanks, snow only on its top"""
    main = lathe("peak", [(24, 0), (20.5, 3.5), (16, 8), (11.5, 12.5), (7, 16.5), (3.2, 20), (0.4, 22)],
                 ["mountain", "mountain", "mountain", "mountain", "snow", "snow", "snow"], 14, 2.4, seed=11)
    left = lathe("peak_l", [(11, 0), (8.5, 4), (5.5, 8.5), (2.4, 12), (0.3, 13.5)],
                 ["mountain", "mountain", "mountain", "snow", "snow"], 10, 1.5, seed=12)
    left.location = (12.5, 6.0, 0)
    right = lathe("peak_r", [(9, 0), (7, 3.5), (4.4, 7), (1.8, 9.5), (0.3, 10.5)],
                  ["mountain", "mountain", "mountain", "snow", "snow"], 9, 1.3, seed=13)
    right.location = (-11.0, -9.0, 0)
    p = [main, left, right]
    rnd = random.Random(14)
    for i in range(8):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(9.0, 17.0)
        z = max(0.5, 16.0 - r * 0.9)
        p.append(roughen(ball((rnd.uniform(3.5, 6.0), rnd.uniform(3.0, 5.0), rnd.uniform(2.0, 3.5)), (r * math.cos(a), r * math.sin(a), z), "rock", 7, 4), 0.35, 60 + i))
    return join("peak", p)


def crag():
    """A haven's crag: a narrow jagged spire of rock, taller than a mesa, snow on its tip, a ring of
    them walling a hidden valley"""
    main = lathe("crag", [(5.2, 0), (4.4, 3.5), (3.7, 7.5), (2.9, 10.5), (1.9, 13), (0.9, 15), (0.2, 16)],
                 ["mountain", "mountain", "mountain", "mountain", "mountain", "snow", "snow"], 9, 0.9, seed=21)
    side = lathe("crag_s", [(3.0, 0), (2.4, 3.5), (1.6, 7), (0.8, 9), (0.2, 10)],
                 ["mountain", "mountain", "mountain", "snow", "snow"], 7, 0.6, seed=22)
    side.location = (3.2, 1.2, 0)
    p = [main, side]
    rnd = random.Random(23)
    for i in range(4):
        a = rnd.uniform(0, math.tau)
        p.append(roughen(ball((rnd.uniform(1.6, 2.4), rnd.uniform(1.4, 2.0), rnd.uniform(1.0, 1.6)), (4.2 * math.cos(a), 4.2 * math.sin(a), 0.6), "rock", 7, 4), 0.25, 70 + i))
    return join("crag", p)




def saguaro():
    p = [drum(0.35, 5.0, (0, 0, 2.5), "cactus", 8), ball((0.7, 0.7, 0.5), (0, 0, 5.0), "cactus", 8, 4)]
    for s, h, reach in ((1, 2.2, 0.9), (-1, 2.9, 0.7)):
        p.append(drum(0.24, reach, (s * (0.3 + reach / 2), 0, h), "cactus", 6, (0, math.pi / 2, 0)))
        p.append(drum(0.24, 1.6, (s * (0.3 + reach), 0, h + 0.8), "cactus", 6))
        p.append(ball((0.48, 0.48, 0.36), (s * (0.3 + reach), 0, h + 1.6), "cactus", 6, 3))
    return join("saguaro", p)


def prickly_pear():
    p = []
    for i, (x, z, ry) in enumerate([(0, 0.4, 0), (0.35, 0.8, 0.5), (-0.3, 0.75, -0.4), (0.1, 1.15, 0.2)]):
        p.append(ball((0.6, 0.18, 0.7), (x, 0, z), "cactus_light", 8, 4, (0, ry, 0)))
        p.append(ball((0.1, 0.1, 0.12), (x + 0.1, 0, z + 0.38), "fruit", 4, 3))
    return join("prickly_pear", p)


def sagebrush():
    p = [roughen(ball((1.4, 1.2, 0.8), (0, 0, 0.35), "sage", 7, 4), 0.1, 1),
         roughen(ball((0.9, 0.9, 0.7), (0.5, 0.3, 0.45), "sage", 6, 4), 0.1, 2),
         roughen(ball((0.9, 0.8, 0.6), (-0.4, -0.3, 0.35), "sage", 6, 4), 0.1, 3)]
    return join("sagebrush", p)


def rock():
    return join("rock", [roughen(ball((2.0, 1.6, 1.3), (0, 0, 0.45), "rock", 7, 4), 0.25, 4),
                         roughen(ball((1.1, 1.0, 0.9), (1.1, 0.4, 0.3), "rock", 6, 4), 0.15, 5)])


def aspen():
    return join("aspen", [drum(0.16, 4.0, (0, 0, 2.0), "aspen_bark", 6),
                          roughen(ball((1.8, 1.8, 2.6), (0, 0, 4.3), "aspen_leaf", 7, 4), 0.2, 6),
                          roughen(ball((1.3, 1.3, 1.6), (0.3, 0.2, 5.6), "aspen_leaf", 6, 4), 0.15, 7)])


def pinyon():
    return join("pinyon", [drum(0.18, 0.8, (0, 0, 0.4), "bark", 6), roughen(ball((2.4, 2.2, 1.7), (0, 0, 1.6), "pinyon", 7, 4), 0.2, 8),
                           roughen(ball((1.4, 1.4, 1.2), (0.3, -0.2, 2.4), "pinyon", 6, 4), 0.15, 9)])


def adobe():
    p = [box((7.0, 6.0, 3.0), (0, 0, 1.5), "adobe"), box((7.3, 6.3, 0.4), (0, 0, 3.15), "adobe"),
         box((1.0, 0.12, 2.0), (-1.5, -3.02, 1.0), "door_blue"), box((0.9, 0.12, 0.8), (1.6, -3.02, 1.7), "window"),
         box((0.7, 0.12, 0.7), (1.6, -3.05, 1.7), "door_blue")]
    for x in (-3.0, -1.8, -0.6, 0.6, 1.8, 3.0):
        p.append(drum(0.1, 0.7, (x, -3.2, 2.7), "wood", 6, (math.pi / 2, 0, 0)))
    p.append(box((0.14, 0.14, 0.9), (-0.6, -3.2, 2.05), "chili"))
    p.append(box((3.0, 3.0, 1.8), (1.5, 1.2, 4.2), "adobe"))
    return join("adobe", p)


def windmill():
    legs = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            legs.append(box((0.12, 0.12, 8.2), (sx * 0.7, sy * 0.7, 4.0), "metal_dark", (sy * 0.09, -sx * 0.09, 0)))
    legs += [box((1.0, 1.0, 0.12), (0, 0, 8.0), "metal_dark"), box((0.2, 2.0, 0.6), (0, 1.3, 8.4), "metal")]
    body = join("windmill", legs)
    blades = [drum(0.3, 0.3, (0, 0, 0), "metal_dark", 8, (math.pi / 2, 0, 0))]
    for i in range(12):
        a = i / 12 * math.tau
        blades.append(box((0.32, 0.04, 1.5), (math.cos(a) * 1.0, 0, math.sin(a) * 1.0), "metal", (0, -a + math.pi / 2, 0)))
    fan = join("fan", blades)
    fan.location = (0, -0.4, 8.5)
    attach(fan, body)
    return body


def pumpjack():
    base = [box((1.6, 5.0, 0.4), (0, 0.4, 0.2), "metal_dark"), box((1.2, 1.2, 0.8), (0, 2.2, 0.8), "metal_dark"),
            box((0.12, 0.12, 3.4), (0.45, 0, 1.8), "tractor", (0.25, 0, 0)), box((0.12, 0.12, 3.4), (-0.45, 0, 1.8), "tractor", (0.25, 0, 0)),
            box((0.12, 0.12, 3.4), (0.45, 0.5, 1.8), "tractor", (-0.25, 0, 0)), box((0.12, 0.12, 3.4), (-0.45, 0.5, 1.8), "tractor", (-0.25, 0, 0)),
            drum(0.08, 2.2, (0, -2.6, 1.1), "metal", 6)]
    body = join("pumpjack", base)
    arm = [box((0.4, 5.4, 0.4), (0, 0, 0), "tractor"), box((0.5, 0.8, 1.4), (0, -2.9, -0.3), "tractor"),
           box((1.0, 0.8, 1.0), (0, 2.6, -0.4), "metal_dark")]
    beam = join("beam", arm)
    beam.location = (0, 0.25, 3.5)
    attach(beam, body)
    return body


def diner():
    p = [box((12.0, 6.0, 3.4), (0, 0, 1.7), "chrome"), box((12.1, 6.1, 0.5), (0, 0, 1.0), "chili"),
         box((11.0, 0.1, 1.0), (0, -3.02, 2.2), "window"), box((1.2, 0.12, 2.2), (-4.0, -3.03, 1.1), "door"),
         box((12.4, 6.4, 0.3), (0, 0, 3.5), "chrome"), drum(0.12, 4.0, (5.0, -3.6, 2.0), "metal_dark", 6),
         box((3.0, 0.3, 1.2), (5.0, -3.6, 4.6), "neon"), box((3.2, 0.2, 1.4), (5.0, -3.5, 4.6), "black")]
    return join("diner", p)


def water_tower():
    p = [drum(2.6, 3.2, (0, 0, 9.0), "metal", 12), cone(2.8, 1.4, (0, 0, 11.3), "metal_dark", 12)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(box((0.18, 0.18, 7.6), (sx * 1.7, sy * 1.7, 3.8), "metal_dark", (sy * 0.06, -sx * 0.06, 0)))
    p.append(box((5.4, 0.1, 0.8), (0, -2.55, 9.2), "white"))
    return join("water_tower", p)


def horse():
    p = [box((0.7, 1.8, 0.75), (0, 0, 1.35), "horse"), box((0.36, 0.5, 0.9), (0, -1.0, 1.85), "horse", (-0.6, 0, 0)),
         box((0.34, 0.75, 0.36), (0, -1.45, 2.25), "horse", (0.2, 0, 0)), box((0.12, 0.9, 0.3), (0, -0.85, 2.2), "mane", (-0.6, 0, 0)),
         box((0.12, 0.12, 0.8), (0, 1.0, 1.25), "mane", (0.4, 0, 0))]
    for s in (-1, 1):
        p.append(box((0.08, 0.06, 0.2), (0.12 * s, -1.25, 2.55), "horse"))
        p.append(box((0.04, 0.04, 0.05), (0.18 * s, -1.6, 2.35), "black"))
        for y in (-0.7, 0.7):
            p.append(box((0.16, 0.16, 1.0), (0.24 * s, y, 0.5), "horse"))
            p.append(box((0.17, 0.17, 0.1), (0.24 * s, y, 0.05), "black"))
    return join("horse", p)


def bison():
    p = [box((1.0, 2.0, 1.0), (0, 0.2, 1.2), "bison"), roughen(ball((1.5, 1.4, 1.6), (0, -0.6, 1.5), "bison_dark", 8, 5), 0.06, 1),
         box((0.6, 0.6, 0.6), (0, -1.3, 0.95), "bison_dark"), box((0.4, 0.2, 0.3), (0, -1.6, 0.85), "black")]
    for s in (-1, 1):
        p.append(cone(0.07, 0.3, (0.34 * s, -1.2, 1.3), "horn", rot=(0, -0.8 * s, 0)))
        for y in (-0.6, 0.8):
            p.append(box((0.22, 0.22, 0.75), (0.32 * s, y, 0.38), "bison_dark"))
    p.append(box((0.06, 0.06, 0.6), (0, 1.25, 1.2), "bison_dark", (0.3, 0, 0)))
    return join("bison", p)


def longhorn():
    p = [box((0.85, 1.7, 0.8), (0, 0, 1.05), "longhorn"), box((0.48, 0.55, 0.5), (0, -1.0, 1.3), "longhorn"),
         box((0.4, 0.2, 0.3), (0, -1.33, 1.15), "white"), box((0.6, 0.5, 0.45), (0.12, 0.3, 1.15), "horse")]
    for s in (-1, 1):
        p.append(drum(0.06, 1.1, (0.75 * s, -0.95, 1.55), "horn", 6, (0, math.pi / 2, 0)))
        p.append(cone(0.06, 0.3, (1.38 * s, -0.95, 1.68), "horn", 6, (0, 0, 0)))
        for y in (-0.6, 0.6):
            p.append(box((0.2, 0.2, 0.65), (0.3 * s, y, 0.33), "longhorn"))
    return join("longhorn", p)


def coyote():
    p = [box((0.36, 1.0, 0.4), (0, 0, 0.62), "coyote"), box((0.3, 0.4, 0.32), (0, -0.62, 0.82), "coyote"),
         box((0.16, 0.3, 0.16), (0, -0.92, 0.75), "coyote"), box((0.05, 0.05, 0.05), (0, -1.08, 0.79), "black"),
         box((0.14, 0.6, 0.14), (0, 0.72, 0.55), "coyote", (-0.6, 0, 0))]
    for s in (-1, 1):
        p.append(cone(0.07, 0.22, (0.1 * s, -0.6, 1.08), "coyote", 4))
        p.append(box((0.04, 0.02, 0.04), (0.08 * s, -0.83, 0.88), "black"))
        for y in (-0.35, 0.35):
            p.append(box((0.09, 0.09, 0.45), (0.12 * s, y, 0.22), "coyote"))
    return join("coyote", p)


def rv():
    p = [box((2.3, 7.0, 2.6), (0, 0.2, 1.75), "white"), box((2.32, 7.02, 0.4), (0, 0.2, 1.6), "rv_stripe"),
         box((2.2, 1.2, 1.3), (0, -3.6, 1.15), "white"), box((2.0, 0.1, 0.7), (0, -4.2, 1.5), "glass"),
         box((2.34, 1.6, 0.6), (0, 0.5, 2.3), "glass"), box((2.34, 1.0, 0.6), (0, 2.6, 2.3), "glass")]
    for s in (-1, 1):
        for y in (-2.8, 1.0, 2.6):
            p += wheel(0.45, 0.3, (1.05 * s, y, 0.45))
        p.append(box((0.3, 0.05, 0.14), (0.7 * s, -4.22, 1.0), "headlight"))
    return join("rv", p)


def cabin():
    p = [box((6.0, 5.0, 2.8), (0, 0, 1.4), "logs"), gable(6.8, 5.8, 2.4, (0, 0, 2.8), "roof"),
         box((1.0, 0.1, 2.0), (0.8, -2.52, 1.0), "door"), box((0.9, 0.1, 0.8), (-1.6, -2.52, 1.6), "window"),
         box((1.0, 1.0, 5.6), (2.6, 1.6, 2.8), "stone")]
    for z in (0.4, 1.0, 1.6, 2.2):
        p.append(box((6.2, 5.2, 0.12), (0, 0, z), "wood_dark"))
    return join("cabin", p)


def camp_tent():
    return join("camp_tent", [ball((2.6, 2.2, 2.4), (0, 0, 0), "camp", 8, 4), box((0.8, 0.1, 0.9), (0, -1.08, 0.45), "black")])

def _dome(radius, z, squash=1.1):
    """The glass the alien sits under: the top half of a ball, named "dome" (the game makes it glass).
    Smooth, unlike everything else: glass shows every facet"""
    import bmesh
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, radius=radius, location=(0, 0, z))
    bpy.ops.object.shade_smooth()
    dome = bpy.context.object
    bm = bmesh.new()
    bm.from_mesh(dome.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.01], context="VERTS")
    bm.to_mesh(dome.data)
    bm.free()
    dome.scale = (1.0, 1.0, squash)
    _done(dome, "glass")
    dome.name = "dome"
    bpy.ops.object.select_all(action="DESELECT")
    dome.select_set(True)
    bpy.context.view_layer.objects.active = dome
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return dome


def _ship(name, parts, dome_r, dome_z, squash=1.0, shift=(0, 0, 0), k=1.0):
    """Joins a ship's parts, moves them by `shift` and scales them by `k` about the pilot's seat
    (the origin, where the game seats the pilot), and seats the glass on top at `dome_z`. The glass
    keeps its size (the pilot does too), so a ship made smaller keeps a cockpit that reads."""
    from mathutils import Matrix
    body = join(name, parts)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    body.data.transform(Matrix.Scale(k, 4) @ Matrix.Translation(shift))
    body.data.update()
    dome = _dome(dome_r, dome_z, squash)
    dome.parent = body
    return body


def orb():
    """After the little scout ships of Close Encounters of the Third Kind: a ball ringed with lights
    of every colour, glowing from underneath, with the pilot under glass on top"""
    p = [ball((3.2, 3.2, 2.7), (0, 0, 0), "orb_shell", 16, 8), drum(1.7, 0.3, (0, 0, 0), "hull_edge", 16),
         drum(0.8, 0.7, (0, 0, -1.25), "orb_glow", 12, top=0.3), drum(1.35, 0.14, (0, 0, -0.7), "light_amber", 12),
         drum(1.05, 0.2, (0, 0, 1.15), "hull_edge", 12)]
    colours = ["light_red", "light_blue", "light_white", "light_amber"]
    for i in range(16):
        a = i / 16 * math.tau
        p.append(ball((0.46, 0.46, 0.4), (1.72 * math.cos(a), 1.72 * math.sin(a), 0), colours[i % 4], 6, 3))
    for i in range(10):
        a = i / 10 * math.tau + 0.3
        p.append(ball((0.2, 0.2, 0.18), (1.35 * math.cos(a), 1.35 * math.sin(a), -0.85), colours[(i + 1) % 4], 5, 3))
    body = join("orb", p)
    dome = _dome(0.95, 1.2, 1.05)
    dome.parent = body
    return body


def triangle():
    """The black triangle: flat, dark, a white light at each corner and a red one in the middle"""
    front, back, half = 3.6, 2.0, 3.1
    mesh = bpy.data.meshes.new("triangle")
    verts = [(0, -front, 0), (half, back, 0), (-half, back, 0), (0, -front, -0.3), (half, back, -0.3), (-half, back, -0.3), (0, 0, 0.3)]
    faces = [(0, 6, 1), (1, 6, 2), (2, 6, 0), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (2, 0, 3, 5)]
    mesh.from_pydata(verts, [], faces)
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    hull = bpy.data.objects.new("triangle", mesh)
    bpy.context.collection.objects.link(hull)
    _done(hull, "black_hull")
    p = [hull, box((0.5, 4.6, 0.12), (0, -0.8, -0.33), "hull_edge"), drum(0.55, 0.14, (0, 0.2, -0.43), "light_red", 10),
         drum(0.8, 0.3, (0, 0, 0.12), "hull_edge", 16)]
    for x, y in ((0, -front + 0.45), (half - 0.55, back - 0.3), (-half + 0.55, back - 0.3)):
        p.append(ball((0.6, 0.6, 0.3), (x, y, -0.33), "light_white", 8, 4))
    body = join("triangle", p)
    dome = _dome(0.75, 0.25, 1.0)
    dome.parent = body
    return body


def foo():
    """A foo fighter, the balls of light that flew beside the bombers in the war: a small glowing ball
    with a ring of metal round its middle, lights in the ring, and the pilot under glass on top"""
    p = [ball((1.8, 1.8, 1.7), (0, 0, 0), "foo_glow", 12, 7), drum(1.0, 0.16, (0, 0, 0), "hull_edge", 14),
         drum(0.54, 0.3, (0, 0, 0.64), "hull_edge", 12), drum(0.3, 0.12, (0, 0, -0.86), "light_white", 8)]
    for i in range(8):
        a = i / 8 * math.tau
        p.append(ball((0.24, 0.24, 0.2), (1.0 * math.cos(a), 1.0 * math.sin(a), 0), "light_white" if i % 2 else "light_red", 5, 3))
    body = join("foo", p)
    dome = _dome(0.5, 0.76, 1.0)
    dome.parent = body
    return body


def cigar():
    """The cigar-shaped mother ship of the 1950s sightings: long and silver, a row of lit portholes
    down each side, a fin at the tail, a glowing hatch underneath and the pilot under glass on its back"""
    half = 4.5
    band = drum(1.0, 0.36, (0, 0, 0), "hull_edge", 12, (math.pi / 2, 0, 0))
    band.scale = (1.16, 1.06, 1.0)
    p = [ball((2.2, 2.0, half * 2.0), (0, 0, 0), "metal", 12, 10, (math.pi / 2, 0, 0)), band,
         ball((0.8, 2.4, 0.5), (0, 0.2, -0.95), "lights_under", 8, 4),
         drum(1.0, 0.5, (0, 0, 0.78), "hull_edge", 14),
         ball((0.34, 0.34, 0.34), (0, -half + 0.05, 0), "light_red", 6, 3),
         box((0.12, 1.4, 0.9), (0, half - 1.0, 0.75), "metal_dark", (0.3, 0, 0)),
         box((1.8, 0.9, 0.1), (0, half - 0.9, 0.0), "metal_dark")]
    for side in (-1, 1):
        for k in range(7):
            y = -3.0 + k * 1.0
            x = 1.1 * math.sqrt(1.0 - (y / half) ** 2)
            p.append(ball((0.22, 0.4, 0.4), (side * x * 0.99, y, 0.22), "window", 6, 3))
    # (four fifths the size it was: at 9 m it filled a phone's screen)
    return _ship("cigar", p, 0.75, 0.8, k=0.8)


def bell():
    """The bell-shaped scout ship of the 1952 photographs: a bell of a hull with a row of portholes, a
    wide flat rim ringed with lights, three balls underneath for landing gear, the pilot under glass"""
    p = [lathe("bell_hull", [(2.7, 0.0), (2.7, 0.18), (1.75, 0.36), (1.55, 1.12), (1.05, 1.34)],
               ["hull_edge", "metal", "metal", "metal", "metal"], sides=16),
         drum(2.76, 0.1, (0, 0, -0.03), "metal_dark", 16), drum(1.0, 0.1, (0, 0, -0.1), "lights_under", 12),
         drum(1.0, 0.1, (0, 0, 1.38), "hull_edge", 12)]
    for i in range(8):
        a = i / 8 * math.tau + math.pi / 8
        p.append(ball((0.38, 0.38, 0.34), (1.64 * math.cos(a), 1.64 * math.sin(a), 0.74), "window", 6, 3))
    for i in range(12):
        a = i / 12 * math.tau
        p.append(ball((0.2, 0.2, 0.14), (2.66 * math.cos(a), 2.66 * math.sin(a), 0.09), "light_amber", 5, 3))
    for i in range(3):
        a = -math.pi / 2 + i * math.tau / 3
        p.append(ball((0.95, 0.95, 0.95), (1.3 * math.cos(a), 1.3 * math.sin(a), -0.26), "metal_dark", 10, 5))
    body = join("bell", p)
    dome = _dome(0.85, 1.3, 1.0)
    dome.parent = body
    return body

def jelly():
    """A jellyfish of a ship: a glowing pink bell, a pale rim, glowing tentacles trailing under it, the
    pilot under glass on top"""
    p = [lathe("jelly_bell", [(2.4, 0.0), (2.35, 0.45), (1.9, 1.05), (1.0, 1.42), (0.66, 1.5)],
               ["jelly", "jelly", "jelly", "jelly", "jelly"], sides=14, wobble=0.04, seed=11),
         drum(2.55, 0.12, (0, 0, 0.0), "white", 16), drum(1.2, 0.1, (0, 0, -0.11), "lights_under", 12)]
    for i in range(12):
        a = i / 12 * math.tau
        r = 1.9 if i % 2 else 1.2
        long = 1.9 if i % 2 else 1.3
        top = (r * math.cos(a), r * math.sin(a), 0.05)
        tip = (r * 1.08 * math.cos(a), r * 1.08 * math.sin(a), -long)
        p.append(rod(0.07, top, tip, "jelly_glow", 5))
        p.append(ball((0.2, 0.2, 0.2), tip, "jelly_glow", 5, 3))
    body = join("jelly", p)
    dome = _dome(0.62, 1.47, 1.0)
    dome.parent = body
    return body


def _market_parts(k, tent=True):
    """The Moon Market saucer's parts, `k` times as big: its tent top only if `tent`"""
    p = [ball((6.0 * k, 6.0 * k, 1.1 * k), (0, 0, 0), "red", 18, 6), drum(3.1 * k, 0.16 * k, (0, 0, 0), "yellow", 20),
         drum(2.2 * k, 0.26 * k, (0, 0, 0.5 * k), "white", 18), drum(1.25 * k, 0.1 * k, (0, 0, 0.66 * k), "red", 18),
         drum(1.4 * k, 0.3 * k, (0, 0, -0.5 * k), "lights_under", 14)]
    if tent:
        p += [cone(1.7 * k, 1.5 * k, (0, 0, 1.2 * k), "red", 12), drum(0.05 * k, 0.9 * k, (0, 0, 2.3 * k), "metal", 4),
              box((0.5 * k, 0.04 * k, 0.3 * k), (0.26 * k, 0, 2.6 * k), "yellow")]
        for i in range(12):
            a = i / 12 * math.tau
            p.append(box((0.16 * k, 1.75 * k, 0.04 * k), (0.85 * k * math.cos(a), 0.85 * k * math.sin(a), 1.2 * k), "white" if i % 2 else "yellow", (0.72, 0, a + math.pi / 2)))
    bulbs = ["light_red", "light_amber", "light_blue", "light_white"]
    for i in range(20):
        a = i / 20 * math.tau
        p.append(ball((0.26 * k, 0.26 * k, 0.2 * k), (3.1 * k * math.cos(a), 3.1 * k * math.sin(a), 0), bulbs[i % 4], 6, 3))
    return p


def market():
    """The Moon Market's trading saucer, that comes down for a level's shopping: a saucer painted like
    a carnival, red and yellow bands, a striped circus-tent top with a flag, ringed with bulbs of
    every colour"""
    return join("market", _market_parts(1.0))


def carnival():
    """The Moon Market's saucer to fly (found once every other ship is): smaller, the circus tent
    swapped for the pilot's glass, a ring of striped pennants round it"""
    p = _market_parts(0.8, False)
    for i in range(10):
        a = i / 10 * math.tau
        p.append(cone(0.16, 0.3, (1.45 * math.cos(a), 1.45 * math.sin(a), 0.63), "yellow" if i % 2 else "white", 4))
    body = join("carnival", p)
    dome = _dome(0.75, 0.5, 1.0)
    dome.parent = body
    return body


def meteor():
    """A little moon to fly: a pale grey ball pocked with craters, each a darker floor in a raised
    rim, a faint glow underneath, the pilot under glass in a ring set into its top"""
    from mathutils import Vector
    rx, rz = 1.5, 1.4
    p = [roughen(ball((rx * 2, rx * 2, rz * 2), (0, 0, 0), "moon_pale", 20, 12), 0.03, 21),
         drum(0.74, 0.5, (0, 0, 1.3), "moon_dark", 14), drum(0.5, 0.12, (0, 0, -1.42), "lights_under", 12)]
    # (azimuth, elevation, size): none on the very top, where the pilot sits
    for az, el, size in ((0.3, 0.25, 0.42), (1.4, -0.1, 0.3), (2.3, 0.45, 0.24), (2.9, -0.35, 0.46), (3.9, 0.15, 0.34),
                         (4.6, 0.55, 0.22), (5.3, -0.2, 0.38), (5.9, 0.6, 0.2), (0.9, -0.65, 0.3), (3.4, -0.75, 0.26),
                         (1.9, 0.75, 0.18), (4.9, -0.55, 0.22), (0.6, 0.95, 0.2), (3.6, 0.95, 0.22)):
        at = Vector((rx * math.cos(el) * math.cos(az), rx * math.cos(el) * math.sin(az), rz * math.sin(el)))
        normal = Vector((at.x / rx ** 2, at.y / rx ** 2, at.z / rz ** 2)).normalized()
        rot = tuple(Vector((0, 0, 1)).rotation_difference(normal).to_euler())
        # (the floor a drum standing out of the surface, its face clear of it; the rim round it hides its side)
        p.append(drum(size, 0.14, at + normal * 0.01, "moon_dark", 10, rot))
        p.append(_ring(size + 0.02, 0.045 + size * 0.05, at + normal * 0.03, "moon_pale", 14, 5, rot))
    body = join("meteor", p)
    dome = _dome(0.62, 1.52, 1.0)
    dome.parent = body
    return body


def tictac():
    """The tic tac the Navy pilots filmed off the Nimitz in 2004: a smooth white capsule, no wings, no
    windows, a faint glow along its belly, the pilot under a little glass on top"""
    p = [ball((1.5, 4.4, 1.3), (0, 0, 0), "white", 14, 8),
         ball((0.6, 2.6, 0.3), (0, 0, -0.62), "lights_under", 8, 3)]
    body = join("tictac", p)
    dome = _dome(0.42, 0.5, 1.0)
    dome.parent = body
    return body


def saturn():
    """A ball in a tilted ring, like a little Saturn: the ring set with blue and white lights, glowing
    from underneath, the pilot under glass on top"""
    tilt = 0.32
    p = [ball((2.5, 2.5, 2.4), (0, 0, 0), "orb_shell", 16, 8),
         drum(2.9, 0.08, (0, 0, 0), "hull_edge", 24, (tilt, 0, 0)),
         drum(2.0, 0.2, (0, 0, 0), "metal_dark", 20, (tilt, 0, 0)),
         drum(0.6, 0.12, (0, 0, -1.22), "lights_under", 12), drum(0.66, 0.3, (0, 0, 1.0), "hull_edge", 14)]
    for i in range(16):
        a = i / 16 * math.tau
        x, y = 2.7 * math.cos(a), 2.7 * math.sin(a)
        p.append(ball((0.22, 0.22, 0.16), (x, y * math.cos(tilt), y * math.sin(tilt)), "light_blue" if i % 2 else "light_white", 5, 3))
    body = join("saturn", p)
    dome = _dome(0.62, 1.1, 1.0)
    dome.parent = body
    return body


def diamond():
    """A crystal of light: two six-sided pyramids point to point, glowing violet, a ring of white
    lights round its widest, the pilot under glass in its top"""
    p = [lathe("diamond_hull", [(0.02, -1.7), (2.1, 0.0), (0.7, 1.2), (0.02, 1.25)],
               ["crystal", "crystal", "hull_edge", "hull_edge"], sides=6),
         drum(2.14, 0.1, (0, 0, 0), "hull_edge", 6, (0, 0, math.pi / 2))]
    for i in range(6):
        a = i / 6 * math.tau
        p.append(ball((0.3, 0.3, 0.24), (2.1 * math.cos(a), 2.1 * math.sin(a), 0), "light_white", 6, 3))
    body = join("diamond", p)
    dome = _dome(0.6, 1.2, 1.0)
    dome.parent = body
    return body

# ---------------------------------------------------------------- wildlife

def quadruped(name, body, leg, head_at, head, colour, dark=None, tail=None):
    """A four-legged animal: a body box `body` (w, l, h) at its height, four legs `leg` (w, h) high,
    a head box `head` at `head_at`"""
    w, l, h = body
    lw, lh = leg
    p = [box((w, l, h), (0, 0, lh + h / 2), colour), box(head, head_at, colour)]
    for s in (-1, 1):
        for y in (-l / 2 + lw, l / 2 - lw):
            p.append(box((lw, lw, lh + 0.1), (s * (w / 2 - lw / 2), y, lh / 2), dark or colour))
        p.append(box((0.04, 0.02, 0.04), (s * head[0] * 0.35, head_at[1] - head[1] / 2, head_at[2] + head[2] * 0.15), "black"))
    if tail:
        p.append(box(tail, (0, l / 2 + tail[1] / 2, lh + h * 0.7), dark or colour))
    return p


def bear():
    p = quadruped("bear", (0.9, 1.7, 0.85), (0.28, 0.55), (0, -1.05, 1.15), (0.55, 0.6, 0.5), "bear")
    p += [roughen(ball((1.0, 1.0, 0.7), (0, -0.4, 1.35), "bear", 8, 4), 0.04, 1), box((0.3, 0.25, 0.22), (0, -1.4, 1.05), "bison_dark")]
    for s in (-1, 1):
        p.append(ball((0.16, 0.08, 0.16), (s * 0.2, -0.95, 1.45), "bear", 6, 3))
    return join("bear", p)


def mountain_goat():
    p = quadruped("mountain_goat", (0.5, 1.1, 0.6), (0.14, 0.55), (0, -0.7, 1.25), (0.28, 0.42, 0.32), "goat", "goat", (0.1, 0.12, 0.1))
    p += [box((0.3, 0.2, 0.3), (0, -0.78, 0.95), "goat"), box((0.52, 0.6, 0.3), (0, -0.3, 1.35), "goat")]
    for s in (-1, 1):
        p.append(cone(0.04, 0.3, (s * 0.08, -0.62, 1.52), "black", 5, (0.4, 0, 0)))
    return join("mountain_goat", p)


def elk():
    p = quadruped("elk", (0.65, 1.7, 0.8), (0.14, 1.0), (0, -1.2, 2.15), (0.3, 0.6, 0.32), "elk", "elk_dark", (0.12, 0.1, 0.12))
    p += [box((0.4, 0.4, 0.8), (0, -0.95, 1.85), "elk_dark", (-0.5, 0, 0)), box((0.66, 0.5, 0.6), (0, 0.65, 1.4), "hawk_light")]
    for s in (-1, 1):
        base = (s * 0.1, -1.1, 2.3)
        tip = (s * 0.5, -0.8, 3.1)
        p.append(drum(0.04, 0.95, ((base[0] + tip[0]) / 2, (base[1] + tip[1]) / 2, (base[2] + tip[2]) / 2), "antler", 5, (0.35, -0.5 * s, 0)))
        for k in range(3):
            p.append(cone(0.03, 0.35, (s * (0.2 + k * 0.12), -1.0 + k * 0.08, 2.55 + k * 0.2), "antler", 4, (-0.4, 0, 0)))
    return join("elk", p)


def pronghorn():
    p = quadruped("pronghorn", (0.42, 1.1, 0.5), (0.09, 0.75), (0, -0.75, 1.45), (0.2, 0.36, 0.22), "pronghorn", "white")
    p += [box((0.3, 0.3, 0.5), (0, -0.62, 1.2), "pronghorn", (-0.4, 0, 0)), box((0.44, 0.3, 0.3), (0, 0.45, 1.05), "white"),
          box((0.43, 0.8, 0.18), (0, 0, 0.82), "white")]
    for s in (-1, 1):
        p.append(cone(0.03, 0.3, (s * 0.06, -0.7, 1.7), "black", 4))
    return join("pronghorn", p)


def rabbit(name="rabbit", antlers=False):
    p = [ball((0.36, 0.5, 0.36), (0, 0, 0.22), "rabbit", 8, 4), ball((0.24, 0.26, 0.24), (0, -0.25, 0.4), "rabbit", 6, 4),
         ball((0.12, 0.12, 0.12), (0, 0.26, 0.28), "white", 5, 3)]
    for s in (-1, 1):
        p.append(box((0.05, 0.03, 0.3), (s * 0.06, -0.22, 0.62), "rabbit", (0.2, 0, s * 0.15)))
        p.append(box((0.03, 0.02, 0.03), (s * 0.08, -0.37, 0.43), "black"))
        if antlers:
            p.append(drum(0.018, 0.3, (s * 0.1, -0.2, 0.68), "antler", 4, (0, 0, -0.5 * s)))
            p.append(cone(0.015, 0.15, (s * 0.2, -0.2, 0.8), "antler", 4, (0, 0, 0.3 * s)))
    return join(name, p)


def roadrunner():
    p = [ball((0.2, 0.5, 0.22), (0, 0, 0.45), "roadrunner", 6, 4), ball((0.14, 0.16, 0.14), (0, -0.25, 0.62), "roadrunner", 6, 3),
         cone(0.035, 0.18, (0, -0.4, 0.62), "black", 4, (math.pi / 2, 0, 0)), box((0.04, 0.12, 0.12), (0, -0.22, 0.72), "black"),
         box((0.08, 0.45, 0.05), (0, 0.4, 0.55), "roadrunner", (-0.4, 0, 0))]
    for s in (-1, 1):
        p.append(box((0.02, 0.02, 0.36), (s * 0.05, 0, 0.18), "hawk_light"))
    return join("roadrunner", p)


def bird(name, colour, size, light=None):
    """A bird with its wings on two children, `wing_l` and `wing_r`, which the game flaps"""
    s = size
    p = [ball((0.2 * s, 0.5 * s, 0.2 * s), (0, 0, 0), colour, 6, 4), ball((0.15 * s, 0.15 * s, 0.15 * s), (0, -0.27 * s, 0.06 * s), colour, 6, 3),
         cone(0.03 * s, 0.12 * s, (0, -0.38 * s, 0.05 * s), "yellow" if light else "black", 4, (math.pi / 2, 0, 0)),
         box((0.18 * s, 0.25 * s, 0.03 * s), (0, 0.32 * s, 0), colour)]
    if light:
        p.append(ball((0.17 * s, 0.35 * s, 0.1 * s), (0, -0.02 * s, -0.06 * s), light, 6, 3))
    body = join(name, p)
    for side, label in ((1, "wing_r"), (-1, "wing_l")):
        w = join(label, [box((0.55 * s, 0.24 * s, 0.025 * s), (side * 0.3 * s, 0, 0), colour)])
        w.parent = body
    return body


def phone_pole():
    p = [drum(0.13, 7.6, (0, 0, 3.8), "pole", 6), box((1.8, 0.14, 0.14), (0, 0, 6.9), "pole"), box((1.1, 0.12, 0.12), (0, 0, 6.3), "pole")]
    for x in (-0.8, -0.3, 0.3, 0.8):
        p.append(drum(0.05, 0.16, (x, 0, 7.05), "insulator", 5))
    p.append(drum(0.2, 0.5, (0.25, 0, 5.3), "metal_dark", 6))
    return join("phone_pole", p)



def helicopter():
    """A police helicopter: a blue and white body with a glass bubble at the front (-Y), a tail boom
    and fin, skids, and a main rotor ("rotor") and tail rotor ("tail_rotor") that the game spins"""
    body = join("helicopter", [
        ball((1.6, 3.0, 1.5), (0, 0, 1.6), "police_blue", 10, 6), ball((1.3, 1.4, 1.1), (0, -1.1, 1.75), "glass", 10, 6),
        box((1.62, 2.2, 0.3), (0, 0.2, 1.2), "white"), drum(0.22, 4.2, (0, 3.3, 1.85), "police_blue", 8, (math.pi / 2, 0, 0)),
        box((0.12, 0.9, 1.3), (0, 5.2, 2.3), "police_blue"), box((1.4, 0.5, 0.1), (0, 5.0, 1.9), "white"),
        drum(0.25, 0.4, (0, 0, 2.5), "metal_dark", 8), box((0.6, 0.3, 0.12), (0, 0.6, 0.85), "light_white"),
        box((0.12, 3.2, 0.12), (0.75, -0.2, 0.25), "metal_dark"), box((0.12, 3.2, 0.12), (-0.75, -0.2, 0.25), "metal_dark"),
        box((0.08, 0.08, 0.6), (0.65, -0.9, 0.55), "metal_dark"), box((0.08, 0.08, 0.6), (-0.65, -0.9, 0.55), "metal_dark"),
        box((0.08, 0.08, 0.6), (0.65, 0.6, 0.55), "metal_dark"), box((0.08, 0.08, 0.6), (-0.65, 0.6, 0.55), "metal_dark")])
    rotor = join("rotor", [box((7.0, 0.3, 0.05), (0, 0, 2.75), "metal_dark"), box((0.3, 7.0, 0.05), (0, 0, 2.75), "metal_dark")])
    attach(rotor, body)
    tail = join("tail_rotor", [box((0.05, 0.2, 1.4), (0.15, 5.3, 2.4), "metal_dark"), box((0.05, 1.4, 0.2), (0.15, 5.3, 2.4), "metal_dark")])
    attach(tail, body)
    return body


def city_hall():
    """A town's city hall: two storeys of pale stone, a portico of columns up steps at the front (-Y),
    a pediment over it, and a small dome with a flagpole on top"""
    p = [box((14.0, 9.0, 7.0), (0, 0, 3.5), "stone_pale"), box((14.6, 9.6, 0.5), (0, 0, 7.25), "trim"),
         box((6.4, 2.4, 0.5), (0, -5.6, 0.25), "stone_pale"), box((7.0, 3.0, 0.3), (0, -5.8, 0.6), "stone_pale"),
         box((7.4, 2.6, 0.4), (0, -5.6, 6.2), "trim"), gable(7.6, 2.8, 1.6, (0, -5.6, 6.4), "stone_pale"),
         drum(2.2, 1.8, (0, 0, 8.4), "stone_pale", 12), ball((4.2, 4.2, 3.4), (0, 0, 9.3), "dome_green", 12, 6),
         drum(0.06, 3.0, (0, 0, 12.3), "metal", 4), box((1.2, 0.04, 0.7), (0.62, 0, 13.4), "red"),
         box((1.6, 0.12, 2.8), (0, -4.52, 1.4), "door")]
    for x in (-2.7, -0.9, 0.9, 2.7):
        p.append(drum(0.32, 5.6, (x, -6.4, 3.4), "trim", 8))
    for x in (-5.6, -4.0, 4.0, 5.6):
        for z in (2.0, 5.0):
            p.append(box((1.0, 0.1, 1.5), (x, -4.52, z), "window"))
    return join("city_hall", p)


def church():
    """A white wooden church: a long nave with a steep roof, a steeple over the door (-Y) with a
    belfry and spire, and tall lit windows down its sides"""
    p = [box((6.0, 11.0, 4.5), (0, 0, 2.25), "white"), gable(6.6, 11.6, 3.6, (0, 0, 4.5), "roof"),
         box((3.0, 3.0, 7.0), (0, -6.4, 3.5), "white"), box((2.4, 2.4, 2.0), (0, -6.4, 8.0), "white"),
         cone(1.8, 4.6, (0, -6.4, 11.3), "roof", 4, (0, 0, math.pi / 4)), box((0.08, 0.08, 1.2), (0, -6.4, 14.0), "gold"),
         box((0.6, 0.08, 0.08), (0, -6.4, 14.2), "gold"), box((1.2, 0.12, 2.2), (0, -7.92, 1.1), "door"),
         box((1.2, 0.1, 1.2), (0, -7.6, 8.0), "black")]
    for y in (-3.5, -1.0, 1.5, 4.0):
        p.append(box((0.1, 0.8, 2.0), (3.02, y, 2.4), "window"))
        p.append(box((0.1, 0.8, 2.0), (-3.02, y, 2.4), "window"))
    return join("church", p)


def fountain():
    """A town square's fountain: a round stone basin of water, a pillar, a bowl on top"""
    p = [drum(3.0, 0.6, (0, 0, 0.3), "stone_pale", 16), drum(2.7, 0.62, (0, 0, 0.32), "water", 16),
         drum(0.35, 2.0, (0, 0, 1.3), "stone_pale", 8), drum(1.1, 0.3, (0, 0, 2.3), "stone_pale", 12, top=0.7),
         drum(0.9, 0.32, (0, 0, 2.35), "water", 12)]
    return join("fountain", p)


def hay_pile():
    """A haystack: a big rounded pile of loose hay, a little pole through its top"""
    return join("hay_pile", [ball((4.2, 4.2, 3.6), (0, 0, 1.0), "hay", 10, 6), drum(0.06, 1.0, (0, 0, 3.0), "wood", 4)])


def chinook():
    """An army Chinook: a long olive body with a rotor at each end (the back one up on a pylon), a
    glass nose (-Y), wheels, and a ramp at the back. The game spins "rotor_front" and "rotor_back"."""
    body = join("chinook", [
        box((2.6, 10.0, 2.6), (0, 0, 2.2), "olive"), ball((2.6, 2.4, 2.6), (0, -5.0, 2.2), "olive", 10, 6),
        box((2.4, 1.2, 1.0), (0, -5.6, 2.9), "glass"), box((1.6, 2.4, 1.6), (0, 4.0, 3.9), "olive_dark"),
        box((2.0, 1.0, 1.4), (0, 0.0, 3.8), "olive_dark"), box((2.4, 0.15, 1.8), (0, 5.05, 1.6), "olive_dark", (0.5, 0, 0)),
        box((2.65, 6.0, 0.25), (0, 0, 1.35), "olive_dark")]
        + [box((0.12, 0.6, 0.5), (x, y, 2.6), "glass") for x in (-1.32, 1.32) for y in (-3.0, -1.5, 0.0, 1.5)]
        + [drum(0.38, 0.3, (x, y, 0.38), "tyre", 8, (0, math.pi / 2, 0)) for x in (-1.1, 1.1) for y in (-3.5, 2.5)])
    for name, y, z in (("rotor_front", -4.6, 3.9), ("rotor_back", 4.0, 5.0)):
        rotor = join(name, [box((11.0, 0.35, 0.06), (0, y, z), "metal_dark"), box((0.35, 11.0, 0.06), (0, y, z), "metal_dark"),
                            drum(0.25, 0.4, (0, y, z - 0.25), "metal_dark", 6)])
        attach(rotor, body)
    return body


def telescope():
    """A stargazer's telescope: a white tube tilted up at the sky on a tripod"""
    p = [drum(0.16, 1.5, (0, 0.25, 1.65), "white", 8, (-0.75, 0, 0)), drum(0.2, 0.25, (0, 0.78, 2.12), "black", 8, (-0.75, 0, 0)),
         box((0.18, 0.18, 0.18), (0, 0, 1.35), "metal_dark")]
    for i in range(3):
        a = i / 3 * math.tau
        p.append(box((0.05, 0.05, 1.45), (math.cos(a) * 0.3, math.sin(a) * 0.3, 0.68), "metal_dark", (math.sin(a) * 0.22, -math.cos(a) * 0.22, 0)))
    return join("telescope", p)


def barrel():
    """An oil drum: red, with dark ribs and a yellow hazard band"""
    p = [drum(0.42, 1.2, (0, 0, 0.6), "red", 10), drum(0.44, 0.08, (0, 0, 0.3), "black", 10), drum(0.44, 0.08, (0, 0, 0.9), "black", 10),
         drum(0.43, 0.22, (0, 0, 0.62), "yellow", 10), drum(0.08, 0.06, (0.18, 0, 1.22), "metal_dark", 6)]
    return join("barrel", p)

def phone_booth():
    """A roadside phone booth: glass on three sides, the door to the road, a lit TELEPHONE sign on
    the roof and an aerial above it (the game sends radio waves out of its tip, BOOTH_TIP, while
    someone calls, or sparks if the lines are down)"""
    p = [box((1.2, 1.2, 0.1), (0, 0, 0.05), "concrete"), box((1.16, 1.16, 0.12), (0, 0, 2.36), "metal_dark"),
         box((0.96, 0.96, 0.26), (0, 0, 2.55), "booth_sign"), box((1.02, 1.02, 0.05), (0, 0, 2.7), "metal_dark"),
         box((0.24, 0.12, 0.4), (0, 0.5, 1.45), "black"), box((0.5, 0.06, 0.04), (0, -0.55, 1.1), "metal")]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(box((0.07, 0.07, 2.26), (sx * 0.55, sy * 0.55, 1.18), "metal"))
    for sx in (-1, 1):
        p.append(box((0.03, 1.04, 1.7), (sx * 0.55, 0, 1.3), "glass"))
    p += [box((1.04, 0.03, 1.7), (0, 0.55, 1.3), "glass"), box((0.95, 0.03, 1.5), (0, -0.55, 1.35), "glass"),
          drum(0.045, 1.3, (0.3, 0.3, 3.35), "metal", 5), ball((0.2, 0.2, 0.2), (0.3, 0.3, 4.02), "light_red", 6, 3)]
    return join("phone_booth", p)


# ---------------------------------------------------------------- rare finds

def sasquatch():
    p = []
    for s in (-1, 1):
        p.append(box((0.3, 0.32, 1.0), (0.2 * s, 0, 0.5), "sasquatch"))
        p.append(box((0.32, 0.5, 0.14), (0.2 * s, -0.08, 0.07), "sasquatch_face"))
        p.append(box((0.24, 0.26, 1.15), (0.55 * s, 0, 1.25), "sasquatch", (0, 0.12 * s, 0)))
        p.append(box((0.2, 0.22, 0.24), (0.6 * s, -0.02, 0.62), "sasquatch_face"))
    p += [roughen(ball((1.0, 0.75, 1.15), (0, 0, 1.55), "sasquatch", 8, 5), 0.05, 2), roughen(ball((0.95, 0.65, 0.45), (0, 0, 2.1), "sasquatch", 8, 4), 0.05, 3),
          ball((0.5, 0.5, 0.55), (0, -0.08, 2.4), "sasquatch", 7, 4), box((0.34, 0.1, 0.3), (0, -0.33, 2.35), "sasquatch_face"),
          box((0.3, 0.06, 0.05), (0, -0.37, 2.47), "black")]
    return join("sasquatch", p)


def meteorite():
    return join("meteorite", [roughen(ball((1.3, 1.1, 0.9), (0, 0, 0.4), "black", 7, 4), 0.15, 5),
                              roughen(ball((0.7, 0.7, 0.6), (0.2, -0.1, 0.7), "meteor_glow", 6, 4), 0.08, 6),
                              roughen(ball((2.6, 2.6, 0.3), (0, 0, 0.0), "talus", 8, 3), 0.1, 7)])


def crash_site():
    """Another saucer, come down long ago (or just now, shot down): tipped up and half in the ground,
    its dome cracked and a few of its lights still glowing. The ground it ploughed up is
    `crash_dirt`, apart from it, so that beaming the wreck up leaves the dirt behind"""
    tilt = (0.42, 0.25, 0)
    p = [ball((4.4, 4.4, 0.8), (0, 0, 0.55), "metal_dark", 14, 6, tilt),
         drum(2.25, 0.12, (0, 0, 0.55), "rock", 14, tilt),
         ball((1.7, 1.7, 1.2), (0.25, -0.35, 1.05), "glass", 10, 5, tilt),
         box((0.9, 0.08, 0.5), (0.5, -0.6, 1.45), "black", (0.4, 0.6, 0.2))]
    for i in range(5):
        a = (i * 0.9 + 0.4)
        p.append(ball((0.22, 0.22, 0.16), (2.1 * math.cos(a), 2.1 * math.sin(a), 0.75 + 0.5 * math.sin(a)), "light_amber", 6, 3))
    return join("crash_site", p)


def crash_dirt():
    """The ground a crashed saucer ploughed up: a dark scar, a ring of heaped dirt round where it
    lies, and clods thrown out further"""
    p = [ball((6.2, 6.2, 0.25), (0, 0, 0.05), "spot", 12, 3)]
    rnd = random.Random(7)
    for i in range(14):
        a = i / 14 * math.tau + rnd.uniform(-0.1, 0.1)
        deep = 0.5 + 0.5 * max(math.cos(a - 4.4), 0.0)
        r = 2.3 * rnd.uniform(0.9, 1.08)
        p.append(roughen(ball((1.4 * rnd.uniform(0.8, 1.2), 1.4 * rnd.uniform(0.8, 1.2), 1.1 * deep), (r * math.cos(a), r * math.sin(a), 0.1), "boot", 7, 4), 0.08, 30 + i))
    for i in range(8):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(3.4, 4.8)
        p.append(ball((0.4, 0.35, 0.25), (r * math.cos(a), r * math.sin(a), 0.1), "boot", 5, 3))
    return join("crash_dirt", p)


def satellite():
    p = [drum(0.5, 1.4, (0, 0, 0.55), "satellite", 8, (0.3, 0.2, 0)), drum(0.55, 0.2, (0, 0.65, 0.75), "gold", 8, (0.3, 0.2, 0)),
         box((2.2, 0.8, 0.04), (1.6, 0, 0.4), "panel", (0, 0.3, 0.1)), box((2.2, 0.8, 0.04), (-1.6, 0, 0.75), "panel", (0, -0.2, 0)),
         cone(0.5, 0.4, (0, -0.8, 0.4), "satellite", 8, (math.pi / 2 + 0.3, 0, 0)), drum(0.03, 1.2, (0.2, -0.6, 1.2), "metal", 4)]
    return join("satellite", p)

# ---------------------------------------------------------------- the law and the army

def police_station():
    p = [box((10.0, 7.0, 4.0), (0, 0, 2.0), "brick"), box((10.4, 7.4, 0.4), (0, 0, 4.1), "concrete"),
         box((4.0, 0.2, 0.9), (0, -3.6, 3.3), "police_blue"), box((3.6, 0.22, 0.5), (0, -3.62, 3.3), "white"),
         box((1.6, 0.12, 2.4), (0, -3.52, 1.2), "glass"), box((0.5, 0.3, 0.2), (-0.4, -3.4, 4.45), "siren_red"),
         box((0.5, 0.3, 0.2), (0.4, -3.4, 4.45), "siren_blue"), drum(0.08, 6.0, (6.0, -3.0, 3.0), "metal", 6),
         box((1.2, 0.04, 0.8), (6.65, -3.0, 5.5), "police_blue")]
    for x in (-3.6, -2.2, 2.2, 3.6):
        p.append(box((1.0, 0.12, 1.0), (x, -3.52, 2.2), "window"))
    return join("police_station", p)


def hangar():
    """A quonset hangar: half a drum on its side, open at the front"""
    import bmesh
    p = []
    segs = 10
    for i in range(segs):
        a0, a1 = math.pi * i / segs, math.pi * (i + 1) / segs
        mid = (a0 + a1) / 2
        r = 7.0
        p.append(box((r * (a1 - a0) + 0.05, 16.0, 0.25), (math.cos(mid) * r, 0, math.sin(mid) * r), "hangar", (0, -(mid - math.pi / 2), 0)))
    back = drum(7.0, 0.3, (0, 8.0, 0), "hangar", 16, (math.pi / 2, 0, 0))
    p.append(back)
    p += [box((14.0, 0.4, 0.6), (0, -8.0, 7.2), "hazard"), box((14.2, 16.4, 0.1), (0, 0, 0.05), "concrete")]
    return join("hangar", p)


def watchtower():
    p = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(box((0.2, 0.2, 7.2), (sx * 1.0, sy * 1.0, 3.6), "olive_dark", (sy * 0.06, -sx * 0.06, 0)))
    p += [box((2.8, 2.8, 0.2), (0, 0, 7.2), "olive_dark"), box((2.6, 2.6, 1.0), (0, 0, 7.8), "olive"),
          gable(3.2, 3.2, 0.8, (0, 0, 8.3), "olive_dark"), box((2.62, 2.62, 0.4), (0, 0, 8.0), "glass")]
    return join("watchtower", p)


def substation():
    """An electric substation: transformers on a pad behind a fence, with a gantry over them"""
    p = [box((12.0, 9.0, 0.2), (0, 0, 0.1), "concrete")]
    for x in (-3.5, 0.0, 3.5):
        p += [box((2.0, 2.4, 2.4), (x, 0.6, 1.4), "transformer"), box((2.1, 0.3, 1.6), (x, 1.9, 1.3), "metal_dark")]
        for k in (-0.6, 0.0, 0.6):
            p.append(drum(0.12, 0.9, (x + k, 0.2, 3.0), "insulator", 6))
            p.append(ball((0.16, 0.16, 0.16), (x + k, 0.2, 3.5), "spark", 5, 3))
    for x in (-5.0, 5.0):
        p.append(box((0.3, 0.3, 6.0), (x, -1.5, 3.0), "metal"))
    p += [box((10.3, 0.3, 0.4), (0, -1.5, 5.9), "metal"), box((1.0, 0.06, 0.7), (0, -4.6, 1.2), "hazard")]
    for side in (-1, 1):
        p.append(box((12.0, 0.06, 2.0), (0, side * 4.5, 1.0), "metal_dark"))
        p.append(box((0.06, 9.0, 2.0), (side * 6.0, 0, 1.0), "metal_dark"))
    return join("substation", p)

# ---------------------------------------------------------------- those who watch the sky

def observatory():
    """A white drum of a building under a dome (a child, "cupola", that the game turns) with a slit in it"""
    import bmesh
    body = join("observatory", [drum(4.0, 5.0, (0, 0, 2.5), "white", 16), drum(4.2, 0.3, (0, 0, 5.0), "metal", 16),
                                box((1.4, 0.2, 2.2), (0, -4.0, 1.1), "door"), box((3.0, 1.6, 2.6), (5.0, 0, 1.3), "white")])
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=4.0, location=(0, 0, 0))
    cup = bpy.context.object
    bm = bmesh.new()
    bm.from_mesh(cup.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.01 or (abs(v.co.x) < 0.7 and v.co.y < 0 and v.co.z > 0.3)], context="VERTS")
    bm.to_mesh(cup.data)
    bm.free()
    _done(cup, "metal")
    slit = drum(0.05, 7.0, (0, -1.0, 2.6), "black", 4, (math.pi / 2 - 0.6, 0, 0))
    scope = drum(0.45, 3.4, (0, -0.8, 1.6), "metal_dark", 8, (0.8, 0, 0))
    cupola = join("cupola", [cup, slit, scope])
    cupola.location = (0, 0, 5.1)
    attach(cupola, body)
    return body


def seti_dish():
    """A radio telescope: a pedestal and a dish (a child, "dish", that the game aims) on a yoke"""
    p = [drum(0.9, 0.6, (0, 0, 0.3), "concrete", 10), drum(0.45, 6.0, (0, 0, 3.3), "white", 8),
         box((2.6, 0.5, 0.5), (0, 0, 6.3), "white")]
    # (the yoke's two arms up to the dish's pivot)
    for x in (-1.2, 1.2):
        p.append(box((0.25, 0.4, 1.0), (x, 0, 6.9), "white"))
    body = join("seti_dish", p)
    bowl = lathe("bowl", [(0.3, -0.6), (2.0, -0.35), (3.6, 0.3), (4.6, 1.2), (4.7, 1.25)], ["white", "white", "white", "metal", "metal"], 18, 0.0, seed=12)
    # the hub on the pivot between the yoke's arms, the feed up the middle, and three struts from
    # the bowl out near its rim up to the feed's horn
    feed = [bowl, drum(0.6, 1.2, (0, 0, -0.6), "white", 10), rod(0.06, (0, 0, -0.4), (0, 0, 3.7), "metal_dark", 4),
            ball((0.4, 0.4, 0.5), (0, 0, 3.7), "metal_dark", 6, 3)]
    for a in range(3):
        ang = a * math.tau / 3 + math.pi / 6
        foot = (math.cos(ang) * 3.4, math.sin(ang) * 3.4, 0.25)
        feed.append(rod(0.05, foot, (0, 0, 3.6), "metal_dark", 4))
    dish = join("dish", feed)
    dish.location = (0, 0, 7.2)
    dish.rotation_euler = (0.9, 0, 0)
    attach(dish, body)
    return body

def pod():
    """A trader's goods: a canister on little feet with a glowing band (recoloured per upgrade) and a cap"""
    p = [drum(0.45, 1.0, (0, 0, 0.65), "metal_dark", 10), drum(0.47, 0.22, (0, 0, 0.75), "pod_glow", 10),
         ball((0.9, 0.9, 0.5), (0, 0, 1.15), "metal", 10, 4), drum(0.12, 0.25, (0, 0, 1.45), "pod_glow", 6)]
    for i in range(3):
        a = i * math.tau / 3
        p.append(box((0.12, 0.12, 0.3), (math.cos(a) * 0.35, math.sin(a) * 0.35, 0.12), "metal_dark", (0, 0, a)))
    return join("pod", p)

# ---------------------------------------------------------------- the moon

def moon_surface():
    """A round piece of the moon, 70 m across: rolling grey ground pocked with craters, each a bowl
    with a raised rim (the game bends it away at the edges, so it reads as a small world)"""
    import bmesh
    rnd = random.Random(21)
    craters = [(rnd.uniform(-28, 28), rnd.uniform(-28, 28), rnd.uniform(2.0, 6.5)) for _ in range(14)]
    craters = [c for c in craters if math.hypot(c[0], c[1]) > 9.0]
    # (and some big ones off behind the ship, toward Earth, where the title looks)
    craters += [(18.0, 16.0, 7.0), (27.0, 6.0, 4.5), (9.0, 26.0, 5.0), (25.0, 25.0, 3.5), (14.0, 31.0, 3.0), (31.0, 15.0, 3.0)]
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=56, y_subdivisions=56, size=70.0, location=(0, 0, 0))
    o = bpy.context.object
    bm = bmesh.new()
    bm.from_mesh(o.data)
    for v in bm.verts:
        x, y = v.co.x, v.co.y
        h = 0.35 * math.sin(x * 0.21) * math.cos(y * 0.17) + 0.2 * math.sin(x * 0.53 + y * 0.31)
        for cx, cy, cr in craters:
            d = math.hypot(x - cx, y - cy) / cr
            if d < 1.0:
                h -= 0.55 * cr * 0.25 * (1.0 - d * d)
            elif d < 1.5:
                h += 0.35 * cr * 0.15 * math.cos((d - 1.0) / 0.5 * math.pi * 0.5)
        # (flat where the ship stands, so its feet rest on the ground and the cooler and the radio
        # stand level in front of it: MoonSet.SHIP_AT, 4.2 across and 3.2 back)
        pad = math.hypot(x - 4.2, y - 3.2)
        h *= min(1.0, max(0.0, (pad - 4.5) / 2.5))
        # (the edge drops away, so the piece has no lip)
        edge = max(0.0, math.hypot(x, y) - 30.0)
        v.co.z = h - edge * 0.4
    bm.to_mesh(o.data)
    bm.free()
    _done(o, "regolith")
    p = [o]
    for i in range(10):
        a = rnd.uniform(0, math.tau)
        d = rnd.uniform(7, 26)
        p.append(roughen(ball((rnd.uniform(0.6, 1.6),) * 2 + (rnd.uniform(0.4, 0.9),), (d * math.cos(a), d * math.sin(a), 0.1), "regolith_dark", 6, 4), 0.12, i))
    return join("moon_surface", p)


def lounge_chair():
    """A deck chair: a frame of chrome tube and a striped canvas seat, facing -Y"""
    p = []
    for s in (-1, 1):
        p.append(box((0.05, 1.3, 0.05), (s * 0.3, 0.0, 0.32), "chrome_leg", (-0.45, 0, 0)))
        p.append(box((0.05, 1.0, 0.05), (s * 0.3, 0.05, 0.3), "chrome_leg", (0.55, 0, 0)))
        p.append(box((0.05, 0.6, 0.05), (s * 0.32, -0.05, 0.5), "chrome_leg"))
    for i in range(5):
        stripe = "canvas_a" if i % 2 == 0 else "canvas_b"
        p.append(box((0.12, 0.62, 0.03), (-0.24 + i * 0.12, 0.05, 0.44), stripe, (-0.0, 0, 0)))
        p.append(box((0.12, 0.03, 0.55), (-0.24 + i * 0.12, 0.38, 0.72), stripe, (-0.35, 0, 0)))
    return join("lounge_chair", p)


def cocktail():
    """A cocktail: a stemmed glass of something green, an olive, and a little paper umbrella"""
    p = [drum(0.06, 0.012, (0, 0, 0.006), "glass", 8), drum(0.008, 0.12, (0, 0, 0.07), "glass", 6),
         drum(0.09, 0.09, (0, 0, 0.17), "glass", 10, top=None), drum(0.075, 0.06, (0, 0, 0.165), "drink", 10),
         ball((0.025, 0.025, 0.025), (0.02, 0.01, 0.2), "leaf", 5, 3), drum(0.004, 0.2, (0.03, 0, 0.28), "wood", 4, (0.25, 0, 0)),
         cone(0.08, 0.04, (0.055, 0, 0.37), "umbrella", 8)]
    return join("cocktail", p)


def beer():
    """An open bottle of beer: brown glass, a pale label, a long neck, no cap"""
    p = [drum(0.04, 0.15, (0, 0, 0.075), "beer", 8), drum(0.041, 0.06, (0, 0, 0.08), "cooler_white", 8),
         drum(0.04, 0.04, (0, 0, 0.17), "beer", 8, top=0.018), drum(0.018, 0.075, (0, 0, 0.225), "beer", 6),
         drum(0.021, 0.012, (0, 0, 0.262), "beer", 6)]
    return join("beer", p)


def bottle_cap():
    """A bottle cap prised off and bent: a crimped disc folded up on one side"""
    p = [drum(0.022, 0.006, (0, 0, 0), "beer_cap", 10), drum(0.022, 0.006, (0.012, 0, 0.006), "beer_cap", 10, (0, -0.9, 0))]
    for i in range(10):
        a = i * math.tau / 10
        p.append(box((0.008, 0.006, 0.01), (math.cos(a) * 0.022, math.sin(a) * 0.022, -0.004), "beer_cap", (0, 0, a)))
    return join("bottle_cap", p)


def cooler():
    """A cooler with its lid open, full of ice and brown bottles of beer, facing -Y"""
    p = [box((0.7, 0.42, 0.36), (0, 0, 0.2), "cooler_red"), box((0.72, 0.44, 0.04), (0, 0, 0.02), "cooler_white"),
         box((0.62, 0.34, 0.04), (0, 0, 0.34), "ice"),
         # (the lid, swung up and back, and the handles)
         box((0.72, 0.06, 0.44), (0, 0.24, 0.6), "cooler_white", (-0.25, 0, 0)),
         box((0.04, 0.08, 0.04), (-0.37, 0, 0.3), "cooler_white"), box((0.04, 0.08, 0.04), (0.37, 0, 0.3), "cooler_white")]
    for i in range(8):
        x, y = -0.24 + (i % 4) * 0.16, -0.07 + (i // 4) * 0.14
        tilt = (0.15 * ((i * 7) % 3 - 1), 0.12 * ((i * 5) % 3 - 1), 0)
        glass = "beer" if i % 3 else "beer_green"
        if i in (2, 5):
            p.append(drum(0.04, 0.13, (x, y, 0.36), "can_red" if i == 2 else "can_silver", 8, tilt))
            continue
        p.append(drum(0.035, 0.2, (x, y, 0.4), glass, 6, tilt))
        p.append(drum(0.018, 0.08, (x, y, 0.53), glass, 6, tilt))
        p.append(drum(0.02, 0.015, (x, y, 0.575), "beer_cap", 6, tilt))
    return join("cooler", p)


def boombox():
    """A boombox: two big speakers, a tape deck between them, a chrome handle and an aerial, facing -Y"""
    p = [box((0.7, 0.18, 0.36), (0, 0, 0.2), "radio_body"), box((0.72, 0.2, 0.03), (0, 0, 0.385), "radio_trim"),
         box((0.18, 0.02, 0.1), (0, -0.095, 0.24), "radio_trim"), box((0.14, 0.02, 0.04), (0, -0.095, 0.33), "lights"),
         box((0.04, 0.04, 0.14), (-0.22, 0, 0.46), "radio_trim"), box((0.04, 0.04, 0.14), (0.22, 0, 0.46), "radio_trim"),
         box((0.48, 0.04, 0.04), (0, 0, 0.53), "radio_trim"), drum(0.008, 0.6, (0.3, 0.02, 0.62), "radio_trim", 4, (0, 0.45, 0))]
    for s in (-1, 1):
        p.append(drum(0.12, 0.03, (s * 0.21, -0.09, 0.19), "radio_trim", 12, (math.pi / 2, 0, 0)))
        p.append(drum(0.1, 0.04, (s * 0.21, -0.09, 0.19), "speaker", 12, (math.pi / 2, 0, 0)))
        p.append(drum(0.035, 0.05, (s * 0.21, -0.1, 0.19), "radio_trim", 8, (math.pi / 2, 0, 0)))
    return join("boombox", p)


# (shapes the items are made from: a plate cut to an outline, a tube swept along a path, a ring, a
# faceted star; each a closed mesh, its faces turned outwards)

def _mesh(name, verts, faces, mats, face_mats, at, rot):
    import bmesh
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.location = at
    o.rotation_euler = rot
    names = []
    for m in mats:
        if m not in names:
            names.append(m)
            o.data.materials.append(mat(m))
    for poly, k in zip(o.data.polygons, face_mats):
        poly.material_index = names.index(mats[k])
    return o


def _turned(o):
    """Turns a mesh's faces outwards (a lathe's profile that doubles back)"""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(o.data)
    bm.free()
    return o


def _plate(pts, depth, at, m, rot=(0, 0, 0), bevel=0.0, face=None, bow=0.0, puff=0.0):
    """A plate cut to an outline (x, z points, as seen from the front, -Y), `depth` thick, its front
    edge chamfered by `bevel`, its front face (in `face`) domed out by `puff` and its sides bowed
    back by `bow`"""
    n = len(pts)
    if sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1] for i in range(n)) < 0:
        pts = pts[::-1]

    def inset(d):
        out = []
        for i in range(n):
            p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % n]
            e1, e2 = (p1[0] - p0[0], p1[1] - p0[1]), (p2[0] - p1[0], p2[1] - p1[1])
            l1, l2 = math.hypot(*e1) or 1.0, math.hypot(*e2) or 1.0
            n1, n2 = (-e1[1] / l1, e1[0] / l1), (-e2[1] / l2, e2[0] / l2)
            bx, bz = n1[0] + n2[0], n1[1] + n2[1]
            bl = math.hypot(bx, bz)
            if bl < 1e-6:
                out.append(p1)
                continue
            bx, bz = bx / bl, bz / bl
            k = d / max(bx * n1[0] + bz * n1[1], 0.35)
            out.append((p1[0] + bx * k, p1[1] + bz * k))
        return out

    rings = [(pts, depth / 2)]
    if bevel > 0:
        rings += [(pts, -depth / 2 + bevel), (inset(bevel), -depth / 2)]
    else:
        rings += [(pts, -depth / 2)]
    verts = [(x, y + bow * x * x, z) for ring, y in rings for (x, z) in ring]
    faces, fm = [tuple(range(n))[::-1]], [0]
    for r in range(len(rings) - 1):
        for i in range(n):
            j = (i + 1) % n
            faces.append((r * n + i, r * n + j, (r + 1) * n + j, (r + 1) * n + i))
            fm.append(0)
    last = (len(rings) - 1) * n
    if puff > 0:
        cx = sum(p[0] for p in rings[-1][0]) / n
        cz = sum(p[1] for p in rings[-1][0]) / n
        verts.append((cx, -depth / 2 - puff + bow * cx * cx, cz))
        for i in range(n):
            faces.append((last + i, last + (i + 1) % n, len(verts) - 1))
            fm.append(1)
    else:
        faces.append(tuple(last + i for i in range(n)))
        fm.append(1)
    return _mesh("plate", verts, faces, [m, face or m], fm, at, rot)


def _sweep(path, w, d, at, m, rot=(0, 0, 0)):
    """A bar swept along a path (x, z points), `w` wide across it (one width, or one for each point)
    and `d` deep (in y)"""
    n = len(path)
    ws = w if isinstance(w, (list, tuple)) else [w] * n
    verts = []
    for i, (x, z) in enumerate(path):
        a, b = path[max(i - 1, 0)], path[min(i + 1, n - 1)]
        tx, tz = b[0] - a[0], b[1] - a[1]
        tl = math.hypot(tx, tz) or 1.0
        nx, nz = -tz / tl * ws[i] / 2, tx / tl * ws[i] / 2
        verts += [(x + nx, -d / 2, z + nz), (x - nx, -d / 2, z - nz), (x - nx, d / 2, z - nz), (x + nx, d / 2, z + nz)]
    faces = [(0, 1, 2, 3), tuple(4 * (n - 1) + k for k in (3, 2, 1, 0))]
    for i in range(n - 1):
        for k in range(4):
            a, b = 4 * i + k, 4 * i + (k + 1) % 4
            faces.append((a, b, b + 4, a + 4))
    return _mesh("sweep", verts, faces, [m], [0] * len(faces), at, rot)


def _arc(r, a0, a1, steps, cx=0.0, cz=0.0):
    """Points round an arc (in the x, z plane) from angle `a0` to `a1`"""
    return [(cx + r * math.cos(a0 + (a1 - a0) * k / steps), cz + r * math.sin(a0 + (a1 - a0) * k / steps)) for k in range(steps + 1)]


def _ring(radius, thick, at, m, segs=16, sides=6, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_segments=segs, minor_segments=sides, major_radius=radius,
                                     minor_radius=thick, location=at, rotation=rot)
    return _done(bpy.context.object, m)


def _star(r, thick, at, m, rot=(0, 0, 0), points=5, inner=0.48):
    """A chunky faceted star (a star bit, a sparkle), facing -Y"""
    verts = []
    for k in range(points * 2):
        a = math.pi / 2 + k * math.pi / points
        rr = r if k % 2 == 0 else r * inner
        verts.append((rr * math.cos(a), 0.0, rr * math.sin(a)))
    verts += [(0, -thick / 2, 0), (0, thick / 2, 0)]
    f, b, n = len(verts) - 2, len(verts) - 1, points * 2
    faces = [(i, (i + 1) % n, f) for i in range(n)] + [((i + 1) % n, i, b) for i in range(n)]
    return _mesh("star", verts, faces, [m], [0] * len(faces), at, rot)


def _heart_pts(w, steps=24):
    """A heart's outline, `w` across, its tip at the origin"""
    pts = []
    for k in range(steps):
        t = k / steps * math.tau
        x = 16 * math.sin(t) ** 3
        z = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x * w / 32, (z + 17) * w / 32))
    return pts


def _moved(p, rot, at=(0, 0, 0)):
    """Point `p` turned by `rot` and moved to `at`"""
    from mathutils import Euler, Vector
    v = Vector(p)
    v.rotate(Euler(rot))
    return tuple(v + Vector(at))


# A lightning bolt, pointing down, its top at the origin (x, z)
BOLT = [(-0.2, 0.0), (0.2, 0.0), (0.0, -0.4), (0.25, -0.4), (-0.35, -1.1), (-0.13, -0.58), (-0.4, -0.58)]


def _scaled(pts, s, dx=0.0, dz=0.0):
    return [(x * s + dx, z * s + dz) for x, z in pts]


def _emitter(at, m="metal"):
    """The saucer's beam emitter: a stepped ring, lights round its rim, a glowing lens beneath"""
    x, y, z = at
    head = lathe("emitter", [(0.13, 0.0), (0.28, 0.03), (0.38, 0.09), (0.4, 0.14), (0.36, 0.18), (0.24, 0.22),
                             (0.14, 0.27), (0.08, 0.31), (0.04, 0.33)],
                 ["metal_dark", m, m, "metal_dark", m, m, "metal_dark", "metal_dark", "metal_dark"], sides=16)
    head.location = at
    p = [head, drum(0.16, 0.04, (x, y, z + 0.005), "pod_glow", 16)]
    for i in range(10):
        a = i / 10 * math.tau
        p.append(ball((0.05, 0.05, 0.05), (x + 0.4 * math.cos(a), y + 0.4 * math.sin(a), z + 0.12), "lights", 6, 3))
    return p


# ---------------------------------------------------------------- items (upgrades), as Risk of Rain 2 shows them

def item_engine():
    """ENGINE: a jet thruster on its side, a fan in its intake, finned, a flame roaring out of its bell"""
    X, z = (0, math.pi / 2, 0), 0.42
    p = [_ring(0.25, 0.05, (-0.46, 0, z), "chrome", 16, 6, X), drum(0.235, 0.04, (-0.43, 0, z), "metal_dark", 16, X),
         cone(0.08, 0.16, (-0.5, 0, z), "chrome", 10, (0, -math.pi / 2, 0)),
         drum(0.27, 0.54, (-0.15, 0, z), "metal", 16, X),
         drum(0.29, 0.05, (-0.3, 0, z), "metal_dark", 16, X), drum(0.29, 0.05, (-0.02, 0, z), "metal_dark", 16, X),
         drum(0.25, 0.2, (0.21, 0, z), "metal_dark", 16, X, top=0.17),
         drum(0.16, 0.16, (0.38, 0, z), "chili", 16, X, top=0.23), drum(0.2, 0.02, (0.465, 0, z), "flame", 16, X),
         cone(0.09, 0.34, (0.62, 0, z), "light_white", 8, X)]
    plume = roughen(lathe("plume", [(0.19, 0.0), (0.22, 0.08), (0.2, 0.2), (0.13, 0.34), (0.05, 0.46), (0.0, 0.52)], ["flame"] * 6, sides=10), 0.02, 7)
    plume.location, plume.rotation_euler = (0.47, 0, z), X
    p.append(plume)
    for i in range(8):
        a = i / 8 * math.tau
        p.append(box((0.015, 0.05, 0.17), (-0.455, 0.12 * math.cos(a), z + 0.12 * math.sin(a)), "metal", (a - math.pi / 2, 0, 0)))
    fin = [(-0.26, 0.22), (0.06, 0.22), (0.12, 0.44), (0.0, 0.44)]
    for k in range(3):
        p.append(_plate(fin, 0.04, (0, 0, z), "chili", (k * math.tau / 3, 0, 0), bevel=0.012))
    return join("item_engine", p)


def item_beam():
    """BEAM: the emitter, its beam a column of glowing rings, a cow being lifted up it"""
    p = _emitter((0, 0, 0.62))
    for k in range(4):
        r = 0.17 + k * 0.06
        p.append(_ring(r, 0.022, (0, 0, 0.5 - k * 0.15), "pod_glow", 16, 4))
    for i in range(6):
        a = i / 6 * math.tau + 0.3
        p.append(rod(0.01, (0.15 * math.cos(a), 0.15 * math.sin(a), 0.6), (0.36 * math.cos(a), 0.36 * math.sin(a), 0.05), "pod_glow", 4))
    p.append(drum(0.38, 0.02, (0, 0, 0.01), "pod_glow", 16))
    cow = [box((0.24, 0.12, 0.12), (0, 0, 0), "hide"), box((0.09, 0.08, 0.09), (-0.15, 0, 0.05), "hide"),
           box((0.05, 0.07, 0.04), (-0.2, 0, 0.03), "pink"), box((0.07, 0.13, 0.06), (0.03, 0, 0.02), "spot"),
           box((0.02, 0.14, 0.02), (-0.14, 0, 0.1), "horn")]
    for sx in (-1, 1):
        for sy in (-1, 1):
            cow.append(box((0.03, 0.03, 0.08), (sx * 0.08, sy * 0.04, -0.09 - 0.02 * sx), "hide", (0, 0.3 * sx, 0)))
    cow = join("cow_up", cow)
    cow.location = (0.0, 0.0, 0.28)
    cow.rotation_euler = (0.2, -0.35, 0.4)
    p.append(cow)
    return join("item_beam", p)


def item_shield():
    """SHIELD: a heater shield, its steel rim riveted round a blue field, a glowing boss at its heart"""
    out = [(-0.4, 1.0), (-0.2, 1.03), (0, 1.04), (0.2, 1.03), (0.4, 1.0), (0.4, 0.62), (0.37, 0.43), (0.29, 0.25),
           (0.16, 0.1), (0, 0.0), (-0.16, 0.1), (-0.29, 0.25), (-0.37, 0.43), (-0.4, 0.62)]
    mid = [(x * 0.82, 0.56 + (z - 0.56) * 0.82) for x, z in out]
    p = [_plate(out, 0.1, (0, 0.03, 0), "metal", bevel=0.025, bow=0.35),
         _plate(mid, 0.06, (0, -0.03, 0), "police_blue", bevel=0.02, bow=0.35),
         _plate([(-0.04, 0.88), (0.04, 0.88), (0.04, 0.2), (-0.04, 0.2)], 0.04, (0, -0.06, 0), "metal", bow=0.35),
         _plate([(-0.3, 0.6), (0.3, 0.6), (0.3, 0.68), (-0.3, 0.68)], 0.04, (0, -0.06, 0), "metal", bow=0.35),
         _ring(0.12, 0.03, (0, -0.09, 0.62), "chrome", 16, 6, (math.pi / 2, 0, 0)),
         ball((0.2, 0.14, 0.2), (0, -0.1, 0.62), "spark", 12, 6)]
    for x, z in out[::2]:
        x, z = x * 0.91, 0.56 + (z - 0.56) * 0.91
        p.append(ball((0.05, 0.05, 0.05), (x, -0.025 + 0.35 * x * x, z), "chrome", 6, 4))
    return join("item_shield", p)


def item_dash():
    """DASH: three chevrons charging to the right, brighter each, speed lines behind"""
    chevron = [(-0.12, 0.5), (0.08, 0.5), (0.34, 0.25), (0.08, 0.0), (-0.12, 0.0), (0.14, 0.25)]
    p = []
    for k, m in enumerate(("metal_dark", "metal", "spark")):
        s = 0.8 + 0.12 * k
        p.append(_plate(_scaled(chevron, s, -0.4 + 0.33 * k, 0.4 - 0.25 * s), 0.14, (0, 0, 0), m, bevel=0.03))
    for x, z, l in ((-0.62, 0.52, 0.26), (-0.7, 0.4, 0.36), (-0.62, 0.28, 0.26)):
        p.append(_plate([(x - l / 2, z - 0.02), (x + l / 2, z - 0.025), (x + l / 2, z + 0.025), (x - l / 2, z + 0.02)], 0.05, (0, 0, 0), "metal"))
    return join("item_dash", p)


def item_laser():
    """LASER: a ray gun, a finned body with a glowing bulb on top, a ringed barrel and a bolt out of it"""
    X, z = (0, math.pi / 2, 0), 0.55
    body = lathe("gun", [(0.05, 0.0), (0.14, 0.03), (0.19, 0.1), (0.2, 0.22), (0.17, 0.33), (0.11, 0.4), (0.07, 0.42)],
                 ["metal_dark", "metal", "metal", "metal", "metal", "metal_dark", "metal_dark"], sides=14)
    body.location, body.rotation_euler = (-0.36, 0, z), X
    p = [body, drum(0.05, 0.08, (-0.38, 0, z), "laser_glow", 8, X),
         drum(0.045, 0.38, (0.25, 0, z), "metal_dark", 8, X)]
    for x in (0.14, 0.23, 0.32):
        p.append(drum(0.085, 0.035, (x, 0, z), "chili", 12, X))
    p += [drum(0.06, 0.08, (0.46, 0, z), "metal", 10, X, top=0.09), ball((0.1, 0.1, 0.1), (0.5, 0, z), "laser_glow", 8, 5),
          ball((0.34, 0.06, 0.06), (0.78, 0, z), "laser_glow", 6, 4), ball((0.12, 0.04, 0.04), (1.04, 0, z), "laser_glow", 6, 3),
          drum(0.06, 0.06, (-0.14, 0, z + 0.2), "metal_dark", 10), ball((0.13, 0.13, 0.15), (-0.14, 0, z + 0.28), "laser_glow", 10, 6)]
    fin = [(-0.42, 0.14), (-0.2, 0.14), (-0.3, 0.3), (-0.44, 0.3)]
    for k in (0, 1, 2):
        p.append(_plate(fin, 0.03, (0, 0, z), "chili", (k * math.tau / 3 + math.pi / 3, 0, 0), bevel=0.01))
    p.append(_plate([(-0.1, 0.45), (-0.27, 0.45), (-0.38, 0.12), (-0.33, 0.04), (-0.2, 0.06)], 0.11, (0, 0, 0), "metal_dark", bevel=0.025))
    p.append(_sweep([(-0.12, 0.4), (-0.08, 0.3), (0.0, 0.27), (0.05, 0.34), (0.04, 0.4)], 0.025, 0.035, (0, 0, 0), "metal"))
    p.append(box((0.025, 0.03, 0.07), (-0.05, 0, 0.37), "metal_dark", (0, 0.3, 0)))
    return join("item_laser", p)


def item_turret():
    """AUTO TURRET: a sentry gun, a round head on a yoke over a stepped base, its twin barrels out and
    a red eye"""
    base = lathe("turret_base", [(0.36, 0.0), (0.36, 0.06), (0.3, 0.08), (0.3, 0.12), (0.22, 0.14), (0.2, 0.2)],
                 ["metal_dark", "metal", "metal_dark", "metal", "metal_dark", "metal_dark"], sides=16)
    p = [base, drum(0.24, 0.04, (0, 0, 0.22), "hazard", 16), box((0.14, 0.56, 0.06), (0, 0, 0.26), "metal_dark")]
    for s in (-1, 1):
        p += [box((0.14, 0.05, 0.3), (0, s * 0.255, 0.4), "metal_dark"), drum(0.07, 0.06, (0, s * 0.215, 0.5), "chrome", 10, (math.pi / 2, 0, 0))]
    p.append(ball((0.42, 0.38, 0.38), (0, 0, 0.5), "metal", 14, 8))
    p.append(box((0.08, 0.3, 0.16), (0.18, 0, 0.47), "metal_dark"))
    for s in (-1, 1):
        p += [drum(0.035, 0.42, (0.4, s * 0.08, 0.47), "metal_dark", 8, (0, math.pi / 2, 0)),
              drum(0.055, 0.07, (0.6, s * 0.08, 0.47), "metal", 8, (0, math.pi / 2, 0)),
              drum(0.025, 0.02, (0.64, s * 0.08, 0.47), "light_amber", 8, (0, math.pi / 2, 0))]
    p += [drum(0.05, 0.04, (0.18, -0.06, 0.62), "light_red", 10, (0, 1.0, 0)), rod(0.012, (-0.06, 0.08, 0.66), (-0.12, 0.12, 0.88), "metal", 4),
          ball((0.04, 0.04, 0.04), (-0.12, 0.12, 0.89), "light_red", 6, 3)]
    return join("item_turret", p)


def _missile(at, rot, size):
    """A missile, nose up (before it is turned): striped, finned, its exhaust burning"""
    nose = lathe("nose", [(0.09, 0.25), (0.085, 0.32), (0.065, 0.39), (0.035, 0.44), (0.0, 0.46)], ["chili"] * 5, sides=12)
    p = [drum(0.09, 0.5, (0, 0, 0), "white", 12), nose, drum(0.095, 0.04, (0, 0, 0.16), "chili", 12),
         drum(0.095, 0.03, (0, 0, -0.12), "metal_dark", 12), drum(0.09, 0.09, (0, 0, -0.285), "metal_dark", 12, top=0.07),
         cone(0.07, 0.26, (0, 0, -0.45), "flame", 8, (math.pi, 0, 0)), cone(0.04, 0.16, (0, 0, -0.4), "light_white", 6, (math.pi, 0, 0))]
    for k in range(4):
        p.append(_plate([(0.07, -0.3), (0.2, -0.36), (0.2, -0.27), (0.07, -0.08)], 0.025, (0, 0, 0), "chili", (0, 0, k * math.pi / 2 + math.pi / 4)))
    o = join("missile", p)
    o.location, o.rotation_euler, o.scale = at, rot, (size, size, size)
    return o


def item_missiles():
    """MISSILES: a pair of homing missiles climbing away, a curling trail of smoke behind the leader"""
    p = [_missile((0.2, 0, 0.62), (0, 0.9, 0), 1.0), _missile((-0.16, 0.18, 0.92), (0, 0.9, 0), 0.62)]
    for k, (x, z, r) in enumerate(((-0.35, 0.22, 0.09), (-0.49, 0.15, 0.11), (-0.65, 0.15, 0.13), (-0.8, 0.22, 0.14))):
        p.append(ball((r * 2, r * 2, r * 1.8), (x, 0.03 * k, z), "metal" if k % 2 else "white", 8, 5))
    return join("item_missiles", p)


def item_cloak():
    """CLOAK: a hooded cloak in folds, eyes glinting in the dark of its hood, its edge breaking up into
    nothing"""
    cape = lathe("cape", [(0.38, 0.0), (0.36, 0.1), (0.3, 0.3), (0.24, 0.5), (0.19, 0.62), (0.16, 0.66)],
                 ["cloak_dark", "cloak_cloth", "cloak_cloth", "cloak_cloth", "cloak_cloth", "cloak_cloth"], sides=16, flute=0.14, flute_from=0)
    p = [cape, ball((0.36, 0.36, 0.38), (0, 0.02, 0.8), "cloak_cloth", 12, 8),
         cone(0.13, 0.24, (0, 0.13, 0.98), "cloak_cloth", 8, (-0.8, 0, 0)),
         ball((0.24, 0.12, 0.28), (0, -0.12, 0.78), "black", 10, 6),
         ball((0.05, 0.03, 0.035), (-0.05, -0.18, 0.8), "spark", 6, 3), ball((0.05, 0.03, 0.035), (0.05, -0.18, 0.8), "spark", 6, 3),
         ball((0.07, 0.06, 0.07), (0, -0.19, 0.63), "gold", 8, 4)]
    for k, (x, y, z, s) in enumerate(((0.42, -0.05, 0.36, 0.08), (0.52, 0.02, 0.5, 0.06), (0.6, -0.08, 0.3, 0.05),
                                      (0.47, 0.05, 0.16, 0.06), (0.68, 0.0, 0.44, 0.04), (0.56, -0.1, 0.62, 0.035))):
        p.append(box((s, s, s), (x, y, z), "cloak_cloth" if k % 2 == 0 else "spark", (0.6 * k, 0.4 * k, 0.3)))
    return join("item_cloak", p)


def item_magnet():
    """MAGNET: a horseshoe magnet, red with steel poles, lines of force flaring from them and a nut
    drawn up between"""
    path = [(-0.22, 0.42), (-0.22, 0.55)] + _arc(0.22, math.pi, 0, 12, 0, 0.66) + [(0.22, 0.55), (0.22, 0.42)]
    p = [_sweep(path, 0.17, 0.2, (0, 0, 0), "chili")]
    for s in (-1, 1):
        p += [box((0.18, 0.21, 0.13), (s * 0.22, 0, 0.385), "metal"), box((0.185, 0.215, 0.03), (s * 0.22, 0, 0.47), "white")]
    # (lines of force flaring from each pole, and a nut drawn up between them)
    for s in (-1, 1):
        for k, lean in enumerate((-0.5, 0.0, 0.5)):
            x0 = s * 0.22 + 0.06 * (k - 1)
            p.append(_plate([(x0 - 0.015, 0.29), (x0 + 0.015, 0.29), (x0 + 0.015 + lean * 0.1, 0.18), (x0 - 0.015 + lean * 0.1, 0.18)], 0.03, (0, -0.02, 0), "spark"))
    p += [drum(0.065, 0.045, (0, -0.02, 0.12), "metal", 6, (math.pi / 2, 0, 0.3)), drum(0.028, 0.055, (0, -0.02, 0.12), "black", 6, (math.pi / 2, 0, 0.3))]
    return join("item_magnet", p)


def item_wide():
    """WIDE BEAM: the emitter throwing a broad fan of light, arrows pushing it out both ways"""
    p = _emitter((0, 0, 0.7), "chrome")
    for k in range(3):
        r = 0.22 + k * 0.2
        p.append(_ring(r, 0.022, (0, 0, 0.55 - k * 0.2), "pod_glow", 20, 4))
    for i in range(8):
        a = i / 8 * math.tau + 0.2
        p.append(rod(0.01, (0.15 * math.cos(a), 0.15 * math.sin(a), 0.68), (0.62 * math.cos(a), 0.62 * math.sin(a), 0.15), "pod_glow", 4))
    arrow = [(-0.72, 0.06), (-0.54, 0.18), (-0.54, 0.1), (0.54, 0.1), (0.54, 0.18), (0.72, 0.06), (0.54, -0.06),
             (0.54, 0.02), (-0.54, 0.02), (-0.54, -0.06)]
    p.append(_plate(_scaled(arrow, 1.0, 0, 0.06), 0.06, (0, -0.1, 0), "spark", bevel=0.015))
    return join("item_wide", p)


def item_scanner():
    """SCANNER: a radar dish on a pivoting mast, its feed horn on struts, waves going out of it"""
    base = lathe("scan_base", [(0.26, 0.0), (0.26, 0.05), (0.2, 0.07), (0.12, 0.1), (0.1, 0.12)],
                 ["metal_dark", "metal", "metal_dark", "metal_dark", "metal_dark"], sides=16)
    tilt = (1.0, 0, -0.2)
    at = (0, 0, 0.62)
    dish = _turned(lathe("dish", [(0.05, -0.01), (0.16, 0.015), (0.28, 0.06), (0.4, 0.14), (0.42, 0.17), (0.38, 0.17),
                                  (0.27, 0.1), (0.15, 0.06), (0.05, 0.045)],
                         ["metal", "metal", "metal", "metal_dark", "metal_dark", "white", "white", "white", "white"], sides=18))
    dish.location, dish.rotation_euler = at, tilt
    hub = _moved((0, 0, -0.05), tilt, at)
    p = [base, drum(0.045, 0.32, (0, 0, 0.26), "metal", 8), dish, rod(0.04, (0, 0, 0.38), hub, "metal_dark", 8),
         drum(0.1, 0.08, hub, "metal_dark", 12, tilt)]
    feed = _moved((0, 0, 0.32), tilt, at)
    for k in range(3):
        a = k / 3 * math.tau + 0.5
        p.append(rod(0.012, _moved((0.34 * math.cos(a), 0.34 * math.sin(a), 0.14), tilt, at), feed, "metal_dark", 4))
    p += [drum(0.04, 0.08, feed, "metal", 8, tilt), ball((0.08, 0.08, 0.08), _moved((0, 0, 0.36), tilt, at), "pod_glow", 8, 5)]
    # (the waves face the hologram's camera, going out up the dish's way)
    tip = _moved((0, 0, 0.36), tilt, at)
    for k, r in enumerate((0.13, 0.22, 0.31)):
        p.append(_sweep(_arc(r, 2.45 - 0.55, 2.45 + 0.55, 8), 0.035, 0.03, tip, "pod_glow", (0, 0, 0.6)))
    return join("item_scanner", p)


def item_jammer():
    """JAMMER: a rugged little radio set with a handle and two aerials, a jagged trace across its screen"""
    case = [(-0.28, 0.08), (-0.24, 0.04), (0.24, 0.04), (0.28, 0.08), (0.28, 0.44), (0.24, 0.48), (-0.24, 0.48), (-0.28, 0.44)]
    p = [_plate(case, 0.3, (0, 0, 0), "metal_dark", bevel=0.03, face="metal"),
         box((0.3, 0.02, 0.17), (-0.07, -0.155, 0.32), "panel"),
         _sweep([(-0.2, 0.31), (-0.15, 0.31), (-0.12, 0.38), (-0.08, 0.26), (-0.04, 0.36), (0.0, 0.3), (0.06, 0.3)], 0.022, 0.02, (0, -0.17, 0), "light_amber")]
    for x, m in ((-0.17, "light_red"), (-0.07, "light_amber"), (0.03, "lights_under")):
        p.append(box((0.06, 0.02, 0.04), (x, -0.155, 0.15), m))
    for z in (0.33, 0.17):
        p += [drum(0.05, 0.04, (0.17, -0.16, z), "metal_dark", 10, (math.pi / 2, 0, 0)),
              box((0.012, 0.02, 0.05), (0.17, -0.185, z + 0.015), "white")]
    for s in (-1, 1):
        p.append(box((0.06, 0.32, 0.06), (s * 0.27, 0, 0.06), "black"))
    p += [_sweep([(-0.02, 0.47)] + _arc(0.1, math.pi, 0, 6, 0.1, 0.52) + [(0.22, 0.47)], 0.035, 0.05, (0, 0, 0), "black"),
          drum(0.03, 0.04, (-0.19, 0, 0.5), "metal", 8), rod(0.014, (-0.19, 0, 0.5), (-0.26, 0, 1.05), "chrome", 5),
          ball((0.05, 0.05, 0.05), (-0.26, 0, 1.06), "light_red", 6, 4),
          rod(0.012, (0.22, 0.08, 0.48), (0.38, 0.08, 0.8), "chrome", 5), ball((0.04, 0.04, 0.04), (0.38, 0.08, 0.8), "chrome", 6, 3)]
    for k, r in enumerate((0.09, 0.15)):
        for s in (-1, 1):
            arc = _arc(r, -0.6 if s > 0 else math.pi - 0.6, 0.6 if s > 0 else math.pi + 0.6, 5, -0.26, 1.0)
            p.append(_sweep(arc, 0.02, 0.02, (0, 0, 0), "light_amber"))
    return join("item_jammer", p)


def canister():
    """A power-up to beam up (see main.gd BOOSTS): a glowing capsule of something, capped in metal
    (its glow tinted by the game for what it does)"""
    p = [drum(0.26, 0.62, (0, 0, 0.5), "pod_glow", 10), drum(0.31, 0.1, (0, 0, 0.17), "metal", 10),
         drum(0.31, 0.1, (0, 0, 0.83), "metal", 10), drum(0.12, 0.12, (0, 0, 0.94), "metal_dark", 8),
         drum(0.42, 0.06, (0, 0, 0.03), "metal_dark", 10)]
    for i in range(3):
        a = i * math.tau / 3
        p.append(box((0.05, 0.05, 0.6), (math.cos(a) * 0.29, math.sin(a) * 0.29, 0.5), "metal"))
    return join("canister", p)


def item_lucky():
    """LUCKY CHARM: a four-leaf clover of heart-shaped leaves on a curling stem, a glint beside it"""
    heart = _heart_pts(0.3, 20)
    p = [_sweep([(0.0, 0.6), (0.02, 0.45), (0.08, 0.3), (0.07, 0.15), (0.0, 0.04), (-0.06, 0.0)], [0.05, 0.05, 0.045, 0.04, 0.035, 0.03], 0.045, (0, 0.04, 0), "leaf_dark"),
         ball((0.08, 0.08, 0.08), (0, -0.03, 0.62), "leaf_dark", 8, 4)]
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        b = math.atan2(math.cos(a), math.sin(a))
        at = (0.03 * math.cos(a), 0.012 * k - 0.02, 0.62 + 0.03 * math.sin(a))
        p.append(_plate(heart, 0.05, at, "leaf", (0, b, 0), bevel=0.012, face="cactus_light", puff=0.03))
        p.append(_plate([(-0.008, 0.02), (0.008, 0.02), (0.006, 0.2), (-0.006, 0.2)], 0.02, (at[0], at[1] - 0.045, at[2]), "leaf_dark", (0, b, 0)))
    p += [_star(0.09, 0.04, (0.36, -0.05, 0.88), "light_white", (0, 0, 0.2), 4, 0.3),
          _star(0.05, 0.03, (0.44, -0.05, 0.72), "light_white", (0, 0, 0.5), 4, 0.3)]
    return join("item_lucky", p)


def item_armor():
    """ARMOR: a steel breastplate, ridged and riveted, two bands of plate hung beneath it"""
    half = [(0.0, 0.26), (0.16, 0.28), (0.25, 0.34), (0.27, 0.48), (0.3, 0.66), (0.27, 0.76), (0.27, 0.84), (0.33, 0.92),
            (0.38, 0.96), (0.36, 1.03), (0.2, 1.05), (0.12, 0.97), (0.0, 0.93)]
    torso = half + [(-x, z) for x, z in reversed(half[1:-1])]
    p = [_plate(torso, 0.14, (0, 0, 0), "metal", bevel=0.035, bow=1.2, puff=0.05)]
    for k, (z, w) in enumerate(((0.19, 0.27), (0.09, 0.24))):
        p.append(_plate([(-w, z - 0.05), (w, z - 0.05), (w + 0.02, z + 0.05), (-w - 0.02, z + 0.05)], 0.08, (0, -0.02 * k - 0.04, 0), "metal_dark", bevel=0.02, bow=1.2))
    p.append(_sweep([(0.0, 0.33), (0.0, 0.6), (0.0, 0.9)], [0.03, 0.05, 0.03], 0.04, (0, -0.12, 0), "chrome"))
    p.append(_sweep(_arc(0.12, math.pi, math.tau, 8, 0, 1.03), 0.035, 0.05, (0, -0.07, 0), "chrome"))
    for x, z in ((0.3, 0.97), (-0.3, 0.97), (0.22, 0.5), (-0.22, 0.5), (0.2, 0.33), (-0.2, 0.33)):
        p.append(ball((0.045, 0.045, 0.045), (x, -0.08 + 1.2 * x * x, z), "chrome", 6, 4))
    for z in (0.19, 0.09):
        for s in (-1, 1):
            p.append(ball((0.04, 0.04, 0.04), (s * 0.22, -0.11 - (0.02 if z < 0.15 else 0) + 1.2 * 0.22 * 0.22, z), "chrome", 6, 4))
    return join("item_armor", p)


def item_sling():
    """GRAVITY SLING: a slingshot (a wooden Y with a wrapped grip), its bands drawn back to a pouch
    holding a blazing meteor, a ring of orbiting rock round the fork"""
    p = [drum(0.06, 0.32, (0, 0, 0.16), "wood_dark", 6), drum(0.068, 0.14, (0, 0, 0.12), "denim", 6),
         drum(0.05, 0.3, (-0.09, 0, 0.42), "wood_dark", 6, (0, -0.5, 0)), drum(0.05, 0.3, (0.09, 0, 0.42), "wood_dark", 6, (0, 0.5, 0))]
    for s in (-1, 1):
        p.append(drum(0.06, 0.05, (0.17 * s, 0, 0.56), "metal", 6))
        p.append(box((0.025, 0.36, 0.025), (0.1 * s, 0.17, 0.53), "red", (0, 0, -0.45 * s)))
    p += [box((0.16, 0.06, 0.1), (0, 0.33, 0.5), "boot"),
          roughen(ball((0.22, 0.22, 0.22), (0, 0.36, 0.6), "rock", 7, 5), 0.02, 95),
          ball((0.3, 0.3, 0.3), (0, 0.36, 0.6), "flame", 6, 4),
          cone(0.12, 0.3, (0, 0.55, 0.68), "flame", 6, (-1.2, 0, 0))]
    for k in range(5):
        a = k / 5 * math.tau
        p.append(roughen(ball((0.06, 0.06, 0.05), (0.3 * math.cos(a), 0.3 * math.sin(a), 0.42 + 0.05 * math.sin(a * 2)), "rock", 5, 3), 0.01, 96 + k))
    return join("item_sling", p)


def item_swivel():
    """SWIVEL MOUNT: a ball joint in its collar, the beam's emitter on its arm tipped well over, its
    beam slanting out to one side, an arrow of the swing"""
    base = lathe("swivel_base", [(0.28, 0.0), (0.28, 0.05), (0.22, 0.07), (0.16, 0.12), (0.14, 0.17)],
                 ["metal_dark", "metal", "metal_dark", "metal_dark", "metal_dark"], sides=16)
    head, beam = (0.3, 0, 0.62), (0.6, 0, -0.8)
    tilt = (0, math.atan2(-beam[0], -beam[2]), 0)
    p = [base, _ring(0.15, 0.04, (0, 0, 0.24), "metal_dark", 16, 6), ball((0.26, 0.26, 0.26), (0, 0, 0.3), "chrome", 12, 8),
         rod(0.05, (0, 0, 0.3), head, "metal", 8),
         drum(0.17, 0.14, head, "metal", 12, tilt, top=0.1), drum(0.14, 0.03, (head[0] + beam[0] * 0.075, 0, head[2] + beam[2] * 0.075), "pod_glow", 12, tilt),
         drum(0.26, 0.46, (head[0] + beam[0] * 0.33, 0, head[2] + beam[2] * 0.33), "light_blue", 12, tilt, top=0.12)]
    for k in range(6):
        a = k / 6 * math.tau
        p.append(ball((0.04, 0.04, 0.04), _moved((0.17 * math.cos(a), 0.17 * math.sin(a), 0.0), tilt, head), "lights", 6, 3))
    swing = _arc(0.44, math.pi * 0.95, math.pi * 0.58, 10, 0, 0.3)
    p.append(_sweep(swing, 0.04, 0.04, (0, -0.05, 0), "spark"))
    for (x, z), (x2, z2) in ((swing[0], swing[1]), (swing[-1], swing[-2])):
        d = math.atan2(z - z2, x - x2)
        tri = [(x + 0.1 * math.cos(d), z + 0.1 * math.sin(d)), (x + 0.07 * math.cos(d + 2.2), z + 0.07 * math.sin(d + 2.2)),
               (x + 0.07 * math.cos(d - 2.2), z + 0.07 * math.sin(d - 2.2))]
        p.append(_plate(tri, 0.04, (0, -0.05, 0), "spark"))
    return join("item_swivel", p)


def item_starbits():
    """STAR BIT BLASTER: a Gatling blaster, six barrels in a turning cluster, a hopper of star bits on
    top and star bits spraying from its muzzle"""
    X, z = (0, math.pi / 2, 0), 0.5
    p = [_plate([(-0.38, 0.38), (0.06, 0.38), (0.1, 0.42), (0.1, 0.62), (0.06, 0.66), (-0.32, 0.66), (-0.38, 0.6)], 0.26, (0, 0, 0), "yellow", bevel=0.04),
         _plate([(-0.12, 0.4), (-0.27, 0.4), (-0.36, 0.1), (-0.31, 0.03), (-0.19, 0.05)], 0.11, (0, 0, 0), "metal_dark", bevel=0.025),
         _sweep([(-0.1, 0.39), (-0.06, 0.29), (0.02, 0.27), (0.07, 0.33), (0.07, 0.39)], 0.025, 0.035, (0, 0, 0), "metal_dark"),
         drum(0.1, 0.06, (0.12, 0, z), "metal_dark", 12, X), drum(0.03, 0.56, (0.36, 0, z), "metal_dark", 8, X)]
    for k in range(6):
        a = k / 6 * math.tau
        y, zz = 0.085 * math.cos(a), z + 0.085 * math.sin(a)
        p += [drum(0.038, 0.46, (0.36, y, zz), "metal", 8, X), drum(0.024, 0.02, (0.595, y, zz), "neon_pink", 6, X)]
    for x in (0.25, 0.45):
        p.append(drum(0.145, 0.04, (x, 0, z), "metal_dark", 12, X))
    p.append(drum(0.14, 0.03, (0.55, 0, z), "neon_pink", 12, X))
    hopper = _turned(lathe("hopper", [(0.13, 0.0), (0.15, 0.13), (0.13, 0.15), (0.11, 0.06)], ["neon_pink", "white", "white", "black"], sides=12))
    hopper.location = (-0.14, 0, 0.64)
    p.append(hopper)
    bits = (("light_red", (-0.18, -0.03, 0.8)), ("light_blue", (-0.1, 0.03, 0.81)), ("light_amber", (-0.14, 0.0, 0.85)))
    for k, (m, at) in enumerate(bits):
        p.append(_star(0.06, 0.04, at, m, (0.3 * k, 0.5 * k, 0.4 * k)))
    spray = (("light_amber", (0.76, -0.04, 0.53), 0.08), ("neon_pink", (0.92, 0.04, 0.66), 0.07), ("light_blue", (0.95, -0.06, 0.4), 0.07),
             ("meteor_glow", (1.1, 0.0, 0.56), 0.06), ("light_red", (1.08, 0.05, 0.75), 0.05), ("light_white", (1.2, -0.04, 0.42), 0.045))
    for k, (m, at, r) in enumerate(spray):
        p.append(_star(r, r * 0.8, at, m, (0.4 * k, 0.6 * k + 0.3, 0.7 * k)))
    return join("item_starbits", p)


def item_second_wind():
    """SECOND WIND: a puffed-up heart on a pair of feathered wings, an extra life"""
    p = [_plate(_scaled(_heart_pts(0.5), 1.0, 0, 0.2), 0.16, (0, 0, 0), "chili", bevel=0.04, face="light_red", puff=0.08),
         ball((0.08, 0.04, 0.06), (-0.1, -0.15, 0.58), "light_white", 6, 3, (0, 0.3, 0.5))]
    # (each wing a fan of long flight feathers behind a shorter row, their ends scalloped)
    big = [(0.0, 0.0), (0.0, 0.1), (0.12, 0.2), (0.28, 0.3), (0.44, 0.4), (0.58, 0.46), (0.52, 0.34), (0.54, 0.26),
           (0.44, 0.24), (0.46, 0.13), (0.35, 0.13), (0.35, 0.02), (0.25, 0.06), (0.23, -0.06), (0.14, 0.0), (0.1, -0.1)]
    small = [(0.0, 0.04), (0.0, 0.12), (0.12, 0.21), (0.27, 0.29), (0.38, 0.33), (0.33, 0.24), (0.34, 0.16), (0.24, 0.17),
             (0.22, 0.07), (0.13, 0.1), (0.08, 0.0)]
    for s in (-1, 1):
        p.append(_plate([(s * x, z) for x, z in big], 0.05, (s * 0.14, 0.07, 0.36), "white", (0, -s * 0.12, 0), bevel=0.015))
        p.append(_plate([(s * x, z) for x, z in small], 0.04, (s * 0.15, 0.02, 0.38), "trim", (0, -s * 0.12, 0), bevel=0.012))
    return join("item_second_wind", p)


def item_coolant():
    """COOLANT: a frosted canister of coolant, finned top and bottom, a snowflake on it, a valve on
    its cap, a pipe out of it, icicles hanging"""
    can = lathe("can", [(0.2, 0.04), (0.22, 0.07), (0.22, 0.6), (0.19, 0.66), (0.12, 0.7), (0.1, 0.72)], ["ice"] * 6, sides=16)
    p = [can, drum(0.25, 0.06, (0, 0, 0.03), "metal", 16)]
    for z in (0.13, 0.19, 0.55):
        p.append(drum(0.27, 0.025, (0, 0, z), "metal", 16))
    for k in range(3):
        a = k * math.pi / 3
        p.append(box((0.03, 0.03, 0.26), (0, -0.215, 0.37), "spark", (0, a, 0)))
        for s in (-1, 1):
            tip = (s * 0.1 * math.sin(a), s * 0.1 * math.cos(a))
            p.append(box((0.07, 0.03, 0.025), (tip[0], -0.215, 0.37 + tip[1]), "spark", (0, a, 0)))
    p += [drum(0.06, 0.1, (0, 0, 0.75), "metal_dark", 10), _ring(0.12, 0.022, (0, 0, 0.82), "police_blue", 16, 6),
          box((0.24, 0.025, 0.025), (0, 0, 0.82), "police_blue"), box((0.025, 0.24, 0.025), (0, 0, 0.82), "police_blue"),
          drum(0.035, 0.04, (0, 0, 0.83), "metal", 8),
          _sweep([(0.12, 0.66), (0.28, 0.68), (0.35, 0.62), (0.36, 0.44)], 0.05, 0.05, (0, 0, 0), "metal_dark"),
          drum(0.045, 0.04, (0.36, 0, 0.43), "metal", 8)]
    for k, a in enumerate((-2.0, -1.6, -1.1, -0.6)):
        p.append(cone(0.022, 0.09 + 0.03 * (k % 2), (0.27 * math.cos(a), 0.27 * math.sin(a), 0.49 - 0.015 * (k % 2)), "ice", 5, (math.pi, 0, 0)))
    return join("item_coolant", p)


def item_nanobots():
    """NANOBOTS: a honeycomb of little bevelled cells, some glowing, a mending cross at its heart"""
    hexa = [(0.135 * math.cos(k * math.pi / 3), 0.135 * math.sin(k * math.pi / 3)) for k in range(6)]
    p = [_plate(_scaled(hexa, 1.0, 0, 0.5), 0.18, (0, -0.02, 0), "metal", bevel=0.03, face="metal")]
    for k in range(6):
        a = math.pi / 6 + k * math.pi / 3
        x, z = 0.27 * math.cos(a), 0.5 + 0.27 * math.sin(a)
        p.append(_plate(_scaled(hexa, 1.0, x, z), 0.12, (0, 0.02 * (k % 2), 0), "metal_dark", bevel=0.025,
                        face="spark" if k % 2 == 0 else "metal_dark", puff=0.02))
    p += [box((0.16, 0.04, 0.05), (0, -0.13, 0.5), "spark"), box((0.05, 0.04, 0.16), (0, -0.13, 0.5), "spark")]
    for (x, z) in ((0.47, 0.82), (-0.46, 0.2)):
        p += [ball((0.08, 0.08, 0.07), (x, -0.02, z), "metal", 8, 5), ball((0.03, 0.02, 0.03), (x - 0.02, -0.06, z + 0.01), "spark", 6, 3)]
        for s in (-1, 1):
            p.append(rod(0.008, (x, -0.02, z), (x + s * 0.07, -0.02, z - 0.06), "metal_dark", 4))
    return join("item_nanobots", p)


def _coin(at, rot=(0, 0, 0)):
    c = _turned(lathe("coin", [(0.01, -0.02), (0.15, -0.02), (0.16, -0.03), (0.2, -0.03), (0.2, 0.03), (0.16, 0.03),
                               (0.15, 0.02), (0.01, 0.02)], ["gold_dark", "gold", "gold", "gold", "gold", "gold", "gold_dark", "gold_dark"], sides=18))
    c.location, c.rotation_euler = at, rot
    return c


def item_gold():
    """GOLD: a stack of rimmed gold coins, one stood up in front with a star struck on it, a gold bar
    behind and a glint or two"""
    p = [_plate([(-0.24, 0.0), (0.24, 0.0), (0.19, 0.14), (-0.19, 0.14)], 0.24, (-0.12, 0.2, 0), "gold", bevel=0.03, face="gold"),
         _plate([(-0.24, 0.0), (0.24, 0.0), (0.19, 0.14), (-0.19, 0.14)], 0.24, (-0.12, 0.2, 0.15), "gold", (0, 0, 0.25), bevel=0.03, face="gold")]
    for k in range(5):
        p.append(_coin((0.14 + 0.015 * math.sin(k * 2.0), -0.02 + 0.015 * math.cos(k * 2.0), 0.03 + k * 0.065), (0, 0, k * 0.4)))
    p += [_coin((-0.2, -0.17, 0.23), (math.pi / 2 - 0.15, 0, 0.25)),
          _star(0.09, 0.03, _moved((0, 0, 0.035), (math.pi / 2 - 0.15, 0, 0.25), (-0.2, -0.17, 0.23)), "gold_dark", (-0.15, 0, 0.25)),
          _star(0.08, 0.03, (0.4, -0.1, 0.62), "light_white", (0, 0, 0.3), 4, 0.3),
          _star(0.05, 0.03, (-0.42, -0.1, 0.5), "light_white", (0, 0, 0.6), 4, 0.3)]
    return join("item_gold", p)


def item_emp():
    """EMP: a Tesla coil, copper windings up its column, a ring on top round a crackling sphere, bolts
    jumping off it"""
    base = lathe("emp_base", [(0.3, 0.0), (0.3, 0.06), (0.24, 0.08), (0.2, 0.12), (0.12, 0.14)],
                 ["metal_dark", "metal", "metal_dark", "metal_dark", "metal_dark"], sides=16)
    p = [base, drum(0.1, 0.42, (0, 0, 0.33), "white", 12)]
    for k in range(6):
        p.append(drum(0.115, 0.035, (0, 0, 0.18 + k * 0.055), "copper", 12))
    p += [_ring(0.21, 0.07, (0, 0, 0.6), "chrome", 18, 8), ball((0.26, 0.26, 0.26), (0, 0, 0.66), "spark", 12, 8)]
    # (the bolts in the plane the hologram's camera faces, at 0.6 round from the x axis)
    for a, down, s in ((0.6, 0.25, 0.42), (0.6 + math.pi, 0.45, 0.38), (0.6, -0.95, 0.26), (0.6 + math.pi, -0.8, 0.22)):
        at = (0.12 * math.cos(a), 0.12 * math.sin(a), 0.68)
        p.append(_plate(_scaled(BOLT, s), 0.04, at, "spark", (0, down - math.pi / 2, a)))
    return join("item_emp", p)


# ---------------------------------------------------------------- the railway, fairgrounds and roadside

def track():
    """A length of railway (8 m, along x): two steel rails on wooden sleepers"""
    p = []
    for s in (-1, 1):
        p.append(box((8.0, 0.1, 0.14), (0, 0.72 * s, 0.29), "metal_dark"))
    for i in range(10):
        p.append(box((0.24, 2.3, 0.1), (-3.6 + i * 0.8, 0, 0.17), "wood_dark"))
    return join("track", p)


def locomotive():
    """A steam locomotive: a black boiler on its wheels, a smokestack and a red-roofed cab, the cow
    catcher and lamp in front"""
    p = [drum(0.9, 5.0, (0, -0.6, 1.9), "black", 12, (math.pi / 2, 0, 0)), box((2.0, 7.4, 0.5), (0, 0, 0.75), "metal_dark"),
         box((2.3, 2.2, 2.4), (0, 2.6, 2.3), "black"), box((2.6, 2.6, 0.2), (0, 2.6, 3.6), "barn"),
         box((1.6, 0.06, 0.9), (0, 1.48, 2.8), "window"), drum(0.32, 1.2, (0, -2.4, 3.1), "black", 8, top=0.45),
         drum(0.35, 0.3, (0, -3.2, 2.0), "headlight", 8, (math.pi / 2, 0, 0)), box((1.9, 0.6, 0.6), (0, -3.7, 0.55), "red", (0.6, 0, 0)),
         drum(0.5, 0.6, (0, 0.2, 2.9), "gold", 8)]
    for s in (-1, 1):
        for y in (-2.0, -0.6, 0.8, 2.4):
            p.append(drum(0.55 if y > 0 else 0.42, 0.18, (1.0 * s, y, 0.55), "red", 10, (0, math.pi / 2, 0)))
    return join("locomotive", p)


def boxcar():
    """A railway boxcar, barn red, a sliding door in each side"""
    p = [box((2.4, 8.0, 2.6), (0, 0, 2.0), "barn"), box((2.5, 8.1, 0.14), (0, 0, 3.35), "roof"),
         box((2.0, 7.6, 0.4), (0, 0, 0.6), "metal_dark")]
    for s in (-1, 1):
        p.append(box((0.06, 2.0, 2.2), (1.22 * s, 0, 1.95), "wood_dark"))
        for y in (-2.8, 2.8):
            p += wheel(0.38, 0.2, (0.95 * s, y, 0.38))
    return join("boxcar", p)


def caboose():
    """The caboose: red, with its lookout on the roof and lit windows"""
    p = [box((2.4, 6.0, 2.4), (0, 0, 1.9), "red"), box((2.5, 6.1, 0.14), (0, 0, 3.15), "roof"),
         box((1.6, 1.8, 0.9), (0, 0, 3.6), "red"), box((1.7, 1.9, 0.12), (0, 0, 4.1), "roof"),
         box((2.0, 5.6, 0.4), (0, 0, 0.6), "metal_dark")]
    for s in (-1, 1):
        for y in (-1.6, 0, 1.6):
            p.append(box((0.06, 0.6, 0.5), (1.22 * s, y, 2.3), "window"))
        for y in (-2.0, 2.0):
            p += wheel(0.38, 0.2, (0.95 * s, y, 0.38))
    return join("caboose", p)


def rider():
    """A cowboy on horseback"""
    body = horse()
    man = figure("rider_man", False, True)
    man.location = (0, 0.1, 1.15)
    bpy.context.view_layer.update()
    return join("rider", [body, man])


def gored(name, profile, colours, sides=16):
    """A surface of revolution about z through `profile` [(radius, z)...], its panels coloured by
    longitude in turn from `colours` (a balloon's gores)"""
    verts, faces, face_mats = [], [], []
    for r, z in profile:
        for j in range(sides):
            a = j / sides * math.tau
            verts.append((r * math.cos(a), r * math.sin(a), z))
    for i in range(len(profile) - 1):
        for j in range(sides):
            a, b = i * sides + j, i * sides + (j + 1) % sides
            faces.append((a, b, b + sides, a + sides))
            face_mats.append(j % len(colours))
    top = len(profile) - 1
    faces.append(tuple(top * sides + j for j in range(sides)))
    face_mats.append(0)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    for c in colours:
        o.data.materials.append(mat(c))
    for poly, m in zip(o.data.polygons, face_mats):
        poly.material_index = m
    return o


def balloon():
    """A hot air balloon: a great teardrop envelope in gores of bright colours, narrowing to its mouth,
    a wicker basket hung under it on ropes, the burner glowing"""
    envelope = gored("envelope", [(0.7, 4.3), (1.5, 4.9), (2.4, 5.9), (3.0, 7.1), (3.25, 8.3), (3.1, 9.4), (2.6, 10.3),
                                  (1.8, 11.0), (0.8, 11.4), (0.0, 11.5)], ["red", "yellow", "denim", "white"], 16)
    p = [envelope, drum(0.72, 0.15, (0, 0, 4.25), "felt", 16),
         box((1.2, 1.2, 0.9), (0, 0, 0.45), "straw"), box((1.3, 1.3, 0.1), (0, 0, 0.92), "wood_dark"),
         drum(0.25, 0.3, (0, 0, 1.6), "camp", 8)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(box((0.04, 0.04, 3.5), (0.55 * sx, 0.55 * sy, 2.6), "felt", (-0.05 * sy, 0.05 * sx, 0)))
    return join("balloon", p)


def fish():
    """A fish: a long body (tinted by the game: its back and its belly), a forked tail, a fin on its
    back, eyes; its head at the front (-y)"""
    p = [ball((0.24, 0.7, 0.26), (0, 0, 0.0), "fish_body", 8, 5), ball((0.18, 0.55, 0.12), (0, -0.02, -0.07), "fish_belly", 8, 4),
         box((0.03, 0.22, 0.12), (0, 0.05, 0.14), "fish_body"),
         box((0.03, 0.2, 0.18), (0, 0.42, 0.07), "fish_body", (0.5, 0, 0)), box((0.03, 0.2, 0.18), (0, 0.42, -0.07), "fish_body", (-0.5, 0, 0)),
         box((0.26, 0.04, 0.04), (0, -0.26, 0.04), "black")]
    return join("fish", p)


def catfish():
    """A catfish: broad, flat-headed and grey, long whiskers either side of its mouth"""
    p = [ball((0.32, 0.85, 0.22), (0, 0, 0.0), "metal_dark", 8, 5), ball((0.26, 0.6, 0.1), (0, -0.05, -0.07), "stone_pale", 8, 4),
         box((0.03, 0.22, 0.14), (0, 0.52, 0.07), "metal_dark", (0.5, 0, 0)), box((0.03, 0.22, 0.14), (0, 0.52, -0.07), "metal_dark", (-0.5, 0, 0)),
         box((0.03, 0.3, 0.08), (0, 0.05, 0.13), "metal_dark"), box((0.34, 0.04, 0.04), (0, -0.32, 0.05), "black")]
    for s in (-1, 1):
        p.append(box((0.3, 0.02, 0.02), (0.18 * s, -0.42, 0.0), "black", (0, 0, 0.4 * s)))
    return join("catfish", p)


def frog():
    """A frog: a squat green body, big bulging eyes on top, its back legs folded beside it"""
    p = [ball((0.36, 0.42, 0.22), (0, 0, 0.13), "leaf", 8, 4), ball((0.3, 0.32, 0.12), (0, -0.02, 0.06), "cactus_light", 8, 3)]
    for s in (-1, 1):
        p += [ball((0.11, 0.11, 0.11), (0.1 * s, -0.12, 0.27), "leaf", 6, 4), ball((0.06, 0.06, 0.06), (0.11 * s, -0.16, 0.3), "black", 4, 3),
              ball((0.14, 0.28, 0.1), (0.2 * s, 0.1, 0.06), "leaf_dark", 6, 3)]
    return join("frog", p)


def tube_man():
    """A wacky waving inflatable tube man: a tall tube with a face, arms out, on its blower"""
    p = [box((0.8, 0.8, 0.5), (0, 0, 0.25), "metal_dark"), drum(0.36, 4.2, (0, 0, 2.6), "orange", 10),
         drum(0.36, 0.3, (0, 0, 4.85), "yellow", 10), box((0.1, 0.05, 0.12), (0.12, -0.36, 4.1), "black"),
         box((0.1, 0.05, 0.12), (-0.12, -0.36, 4.1), "black"), box((0.3, 0.05, 0.06), (0, -0.36, 3.8), "black")]
    for s in (-1, 1):
        p.append(drum(0.14, 1.6, (0.9 * s, 0, 3.4), "orange", 6, (0, math.pi / 2 - 0.5 * s, 0)))
    return join("tube_man", p)


def gas_station():
    """A gas station: a lit canopy on posts over two pumps, and a little store with a sign"""
    p = [box((9.0, 6.0, 0.4), (0, 0, 4.2), "white"), box((9.1, 6.1, 0.12), (0, 0, 3.95), "window"),
         box((9.2, 0.1, 0.5), (0, -3.05, 4.2), "red"), box((6.0, 5.0, 3.2), (0, 8.0, 1.6), "walls"),
         box((6.2, 5.2, 0.2), (0, 8.0, 3.3), "roof"), box((3.0, 0.06, 1.6), (0, 5.48, 1.3), "window"),
         box((4.0, 0.2, 0.8), (0, 5.4, 3.0), "red"), box((10.0, 15.0, 0.12), (0, 3.5, 0.06), "concrete")]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(box((0.3, 0.3, 4.0), (3.8 * sx, 2.4 * sy, 2.0), "white"))
        p += [box((0.6, 0.5, 1.4), (1.8 * sx, 0, 0.7), "red"), box((0.5, 0.06, 0.4), (1.8 * sx, -0.26, 1.1), "window")]
    p += [drum(0.12, 6.0, (5.5, -2.5, 3.0), "metal", 6), box((0.3, 2.2, 1.6), (5.5, -2.5, 6.5), "yellow")]
    return join("gas_station", p)


def dealership():
    """A car dealership's showroom: glass across the front, a long sign and pennant bunting"""
    p = [box((12.0, 7.0, 4.0), (0, 0, 2.0), "white"), box((12.2, 7.2, 0.3), (0, 0, 4.15), "roof"),
         box((10.0, 0.08, 3.0), (0, -3.52, 1.7), "glass"), box((8.0, 0.25, 1.0), (0, -3.6, 4.6), "denim"),
         box((7.0, 0.28, 0.5), (0, -3.62, 4.6), "white")]
    flags = ["red", "yellow", "denim", "white"]
    for i in range(12):
        p.append(cone(0.22, 0.4, (-5.5 + i, -3.7, 3.9), flags[i % 4], 3, (math.pi, 0, 0)))
    return join("dealership", p)


def schoolhouse():
    """A one-room schoolhouse, red with white trim: a pitched roof over red gable ends, the door in
    the front gable (-y) under a little open belfry on the ridge, its bell hanging in it"""
    pitch = math.atan2(2.0, 3.0)
    p = [box((6.0, 9.0, 3.2), (0, 0, 1.6), "barn"), gable(6.0, 9.0, 2.0, (0, 0, 3.2), "barn"),
         box((6.2, 9.2, 0.16), (0, 0, 3.2), "white"),
         # (the door, its white frame and the step up to it)
         box((1.5, 0.08, 2.3), (0, -4.54, 1.15), "white"), box((1.1, 0.08, 1.95), (0, -4.6, 0.98), "wood_dark"),
         box((2.0, 0.7, 0.2), (0, -4.85, 0.1), "concrete"),
         # (the belfry: a white base on the ridge, four posts, the bell hung between them, a pointed roof)
         box((1.6, 1.6, 1.2), (0, -3.6, 5.0), "white")]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(box((0.16, 0.16, 1.2), (0.65 * sx, -3.6 + 0.65 * sy, 6.2), "white"))
    p += [cone(0.32, 0.5, (0, -3.6, 6.15), "gold", 8), ball((0.12, 0.12, 0.12), (0, -3.6, 5.85), "gold", 6, 3),
          box((1.7, 1.7, 0.12), (0, -3.6, 6.86), "white"), cone(1.25, 1.2, (0, -3.6, 7.5), "roof", 4, (0, 0, math.pi / 4))]
    # The roof: two boards pitched down from the ridge to the eaves, overhanging a little
    for s in (-1, 1):
        n = (math.sin(pitch) * s, 0, math.cos(pitch))
        p.append(box((3.9, 9.6, 0.2), (1.5 * s + n[0] * 0.12, 0, 4.2 + n[2] * 0.12), "roof", (0, pitch * s, 0)))
        for y in (-1.8, 0.4, 2.6):
            p.append(box((0.08, 1.0, 1.3), (3.02 * s, y, 1.8), "window"))
    # (a round window up in each gable)
    for y in (-4.52, 4.52):
        p.append(drum(0.35, 0.06, (0, y, 4.0), "window", 10, (math.pi / 2, 0, 0)))
    return join("schoolhouse", p)


def playground():
    """A playground: a swing set, a slide up a little ladder, and a seesaw"""
    p = []
    for s in (-1, 1):
        p.append(box((0.12, 0.12, 2.6), (-2.0 + 0.5 * s, -1.2, 1.2), "red", (0.3 * s, 0, 0)))
        p.append(box((0.12, 0.12, 2.6), (2.0 + 0.5 * s, -1.2, 1.2), "red", (0.3 * s, 0, 0)))
    p.append(box((4.6, 0.12, 0.12), (0, -1.2, 2.45), "red"))
    for x in (-1.0, 1.0):
        p += [box((0.03, 0.03, 1.8), (x - 0.25, -1.2, 1.5), "metal"), box((0.03, 0.03, 1.8), (x + 0.25, -1.2, 1.5), "metal"),
              box((0.6, 0.3, 0.06), (x, -1.2, 0.6), "denim")]
    p += [box((1.0, 3.6, 0.1), (0, 2.6, 1.0), "yellow", (0.55, 0, 0)), box((1.0, 1.0, 0.12), (0, 1.0, 1.95), "yellow"),
          box((0.1, 0.1, 2.0), (-0.45, 0.6, 1.0), "denim"), box((0.1, 0.1, 2.0), (0.45, 0.6, 1.0), "denim"),
          box((3.2, 0.3, 0.1), (3.2, 2.2, 0.5), "wood", (0, 0.18, 0)), box((0.3, 0.3, 0.45), (3.2, 2.2, 0.22), "denim")]
    return join("playground", p)


def crane():
    """A tower crane over a building site: a yellow lattice mast, a long jib and a hanging hook"""
    p = [box((3.0, 3.0, 0.6), (0, 0, 0.3), "concrete"), box((1.2, 1.2, 16.0), (0, 0, 8.6), "yellow"),
         box((1.0, 16.0, 0.8), (0, 3.0, 16.8), "yellow"), box((1.8, 2.0, 1.6), (0, -0.4, 15.6), "white"),
         box((1.6, 2.0, 1.6), (0, -4.0, 16.2), "concrete"), box((0.05, 0.05, 6.0), (0, 9.0, 13.4), "metal_dark"),
         box((0.5, 0.5, 0.4), (0, 9.0, 10.3), "metal_dark")]
    for i in range(16):
        p.append(box((1.25, 1.25, 0.08), (0, 0, 1.2 + i), "metal_dark"))
    return join("crane", p)


def excavator():
    """A yellow excavator on its tracks, its arm reaching down to the bucket"""
    p = [box((2.4, 3.6, 0.8), (0, 0, 0.4), "metal_dark"), box((2.2, 2.6, 1.4), (0, 0.3, 1.5), "yellow"),
         box((1.0, 1.2, 1.2), (0.6, -0.8, 2.6), "glass"), box((0.4, 2.8, 0.4), (-0.4, -2.0, 2.6), "yellow", (0.5, 0, 0)),
         box((0.35, 2.0, 0.35), (-0.4, -3.6, 2.0), "yellow", (-0.7, 0, 0)), box((1.0, 0.6, 0.7), (-0.4, -4.2, 0.9), "metal_dark")]
    return join("excavator", p)


def girders():
    """A stack of steel girders on a building site, with a traffic cone or two"""
    p = []
    for i in range(4):
        p.append(box((0.4, 6.0, 0.4), (-0.9 + i * 0.6, 0, 0.2 + (i % 2) * 0.4), "rust"))
    for x in (-2.5, 2.4):
        p += [cone(0.25, 0.7, (x, 2.6, 0.35), "orange", 8), box((0.6, 0.6, 0.06), (x, 2.6, 0.03), "orange")]
    return join("girders", p)


def mixer():
    """A cement mixer truck, its drum on the back"""
    p = car_body_parts(5.6, "white") + [drum(1.0, 3.0, (0, 1.0, 1.9), "orange", 10, (math.pi / 2 - 0.25, 0, 0))]
    return join("mixer", p)


def car_body_parts(length, paint):
    p = [box((2.0, length, 0.8), (0, 0, 0.8), paint), box((2.0, 1.6, 1.3), (0, -length / 2 + 0.8, 1.6), paint),
         box((1.9, 0.06, 0.7), (0, -length / 2, 1.8), "glass")]
    for s in (-1, 1):
        for y in (-length * 0.35, length * 0.15, length * 0.38):
            p += wheel(0.45, 0.3, (1.0 * s, y, 0.45))
    return p


def tire_stack():
    """A stack of old tyres"""
    p = []
    for i in range(5):
        p.append(drum(0.5, 0.28, (0.05 * (i % 2), 0, 0.14 + i * 0.28), "tyre", 10))
    return join("tire_stack", p)


def scrap_pile():
    """A heap of scrap in a junkyard: rusted panels and pipes"""
    p = [roughen(ball((4.0, 3.5, 2.0), (0, 0, 0.4), "rust", 8, 4), 0.25, 21)]
    for i in range(6):
        a = i * 1.1
        p.append(box((1.6, 0.1, 0.9), (math.cos(a) * 1.2, math.sin(a) * 1.0, 1.0), "metal_dark" if i % 2 else "rust", (0.5 * i, 0.3, a)))
    return join("scrap_pile", p)


def bench():
    """A park bench"""
    p = [box((1.8, 0.5, 0.08), (0, 0, 0.45), "wood"), box((1.8, 0.08, 0.45), (0, 0.24, 0.75), "wood")]
    for s in (-1, 1):
        p.append(box((0.08, 0.5, 0.45), (0.8 * s, 0, 0.22), "metal_dark"))
    return join("bench", p)


def gazebo():
    """A white park gazebo, an eight-sided roof on posts"""
    p = [drum(3.0, 0.4, (0, 0, 0.2), "white", 8), cone(3.4, 1.8, (0, 0, 3.9), "roof", 8), drum(0.2, 0.3, (0, 0, 4.9), "white", 6)]
    for i in range(8):
        a = i / 8 * math.tau
        p.append(box((0.16, 0.16, 2.8), (2.7 * math.cos(a), 2.7 * math.sin(a), 1.8), "white"))
    return join("gazebo", p)


def screen():
    """A drive-in's movie screen, a picture glowing on it, up on its frame, and the projection booth"""
    p = [box((14.0, 0.4, 7.0), (0, 0, 6.5), "white"), box((13.0, 0.1, 6.0), (0, -0.25, 6.5), "screen_glow")]
    for x in (-6, -2, 2, 6):
        p.append(box((0.3, 0.3, 10.0), (x, 0.4, 5.0), "metal_dark"))
    p += [box((3.0, 3.0, 2.4), (0, -22.0, 1.2), "walls"), box((3.2, 3.2, 0.2), (0, -22.0, 2.5), "roof"),
          box((0.5, 0.1, 0.4), (0, -20.45, 1.8), "headlight")]
    return join("screen", p)


def speaker_post():
    """A drive-in's speaker post"""
    return join("speaker_post", [box((0.08, 0.08, 1.2), (0, 0, 0.6), "metal"), box((0.3, 0.16, 0.24), (0, 0, 1.2), "metal_dark")])


def bleachers():
    """Wooden bleachers: rows of benches stepping up, on a frame"""
    p = []
    for i in range(5):
        p.append(box((10.0, 0.6, 0.12), (0, i * 0.7, 0.45 + i * 0.5), "wood"))
        p.append(box((10.0, 0.06, 0.5), (0, i * 0.7 - 0.3, 0.2 + i * 0.5), "wood_dark"))
    for x in (-4.8, 0, 4.8):
        p.append(box((0.15, 3.4, 0.15), (x, 1.4, 1.2), "metal_dark", (-0.62, 0, 0)))
    return join("bleachers", p)


def ferris_wheel():
    """A Ferris wheel, its rim strung with lights, the cars hanging round it, on an A-frame; the wheel
    turns (the `fan`)"""
    legs = []
    for s in (-1, 1):
        legs.append(box((0.3, 0.3, 9.0), (2.0 * s, 0.6, 4.3), "white", (0, 0.24 * s, 0)))
        legs.append(box((0.3, 0.3, 9.0), (2.0 * s, -0.6, 4.3), "white", (0, 0.24 * s, 0)))
    legs.append(box((5.0, 2.0, 0.4), (0, 0, 0.2), "red"))
    body = join("ferris_wheel", legs)
    wheel_parts = [drum(0.6, 1.4, (0, 0, 0), "metal", 10, (math.pi / 2, 0, 0))]
    bulbs = ["light_red", "light_amber", "light_blue", "light_white"]
    for i in range(12):
        a = i / 12 * math.tau
        wheel_parts.append(box((0.12, 0.12, 6.4), (math.cos(a) * 3.2, 0, math.sin(a) * 3.2), "white", (0, -a + math.pi / 2, 0)))
        wheel_parts.append(box((1.1, 0.12, 0.12), (math.cos(a) * 6.3, 0, math.sin(a) * 6.3), "white", (0, -a, 0)))
        wheel_parts.append(box((0.9, 1.2, 0.8), (math.cos(a) * 6.3, 0, math.sin(a) * 6.3 - 0.7), ["red", "yellow", "denim"][i % 3]))
        wheel_parts.append(ball((0.3, 0.3, 0.3), (math.cos(a + 0.26) * 6.4, 0, math.sin(a + 0.26) * 6.4), bulbs[i % 4], 5, 3))
    fan = join("fan", wheel_parts)
    fan.location = (0, 0, 8.6)
    attach(fan, body)
    return body


def carousel():
    """A carousel: a striped canopy over a turning floor of horses on poles, lights round its edge;
    the floor and canopy turn (`spin`)"""
    body = join("carousel", [drum(4.2, 0.4, (0, 0, 0.2), "red", 16), drum(0.4, 5.0, (0, 0, 2.6), "gold", 8)])
    parts = [drum(4.0, 0.2, (0, 0, 0.5), "white", 16), cone(4.6, 1.8, (0, 0, 5.2), "red", 16), drum(4.6, 0.6, (0, 0, 4.1), "yellow", 16)]
    bulbs = ["light_red", "light_amber", "light_blue", "light_white"]
    for i in range(10):
        a = i / 10 * math.tau
        x, y = 3.0 * math.cos(a), 3.0 * math.sin(a)
        parts += [box((0.06, 0.06, 3.6), (x, y, 2.4), "gold"), box((0.35, 1.0, 0.45), (x, y, 1.6 + 0.3 * (i % 2)), "white", (0, 0, a)),
                  box((0.2, 0.3, 0.5), (x - 0.4 * math.sin(a), y + 0.4 * math.cos(a), 2.0 + 0.3 * (i % 2)), "white", (0, 0, a))]
    for i in range(16):
        a = i / 16 * math.tau
        parts.append(ball((0.22, 0.22, 0.22), (4.6 * math.cos(a), 4.6 * math.sin(a), 3.75), bulbs[i % 4], 5, 3))
    spin = join("spin", parts)
    attach(spin, body)
    return body


def circus_tent():
    """A big top: a round striped tent, a flag on the pole"""
    p = []
    for i in range(12):
        a = i / 12 * math.tau
        p.append(box((2.2, 0.15, 3.0), (5.1 * math.cos(a), 5.1 * math.sin(a), 1.5), "red" if i % 2 else "white", (0, 0, a + math.pi / 2)))
    p += [cone(6.0, 3.8, (0, 0, 4.9), "red", 12), cone(5.95, 3.78, (0, 0, 4.92), "white", 6), drum(0.06, 1.6, (0, 0, 7.4), "metal", 4),
          box((0.6, 0.04, 0.35), (0.3, 0, 8.0), "yellow"), box((1.8, 0.2, 2.2), (0, -5.3, 1.1), "black")]
    return join("circus_tent", p)


def booth():
    """A carnival game booth, striped awning, lights along its front"""
    p = [box((3.0, 2.0, 1.0), (0, 0, 0.5), "wood"), box((3.0, 0.1, 2.4), (0, 1.0, 1.2), "denim"),
         box((3.2, 2.4, 0.15), (0, -0.2, 2.5), "red", (0.25, 0, 0))]
    for i in range(6):
        p.append(ball((0.16, 0.16, 0.16), (-1.3 + i * 0.52, -1.25, 2.25), ["light_red", "light_amber", "light_blue"][i % 3], 5, 3))
    return join("booth", p)
def street_light():
    """A street light: a tall grey pole, its arm out over the road, the lamp glowing under it"""
    return join("street_light", [drum(0.16, 0.3, (0, 0, 0.15), "metal_dark", 8), drum(0.08, 6.0, (0, 0, 3.0), "metal", 6),
                                 box((0.08, 1.7, 0.08), (0, -0.85, 6.0), "metal"), box((0.32, 0.6, 0.16), (0, -1.55, 5.94), "metal_dark"),
                                 box((0.26, 0.5, 0.06), (0, -1.55, 5.84), "lights")])


def lamp_post():
    """An old-fashioned lamp post for a park, a glowing globe on top"""
    return join("lamp_post", [drum(0.14, 0.3, (0, 0, 0.15), "black", 8), drum(0.06, 2.8, (0, 0, 1.6), "black", 6),
                              ball((0.4, 0.4, 0.46), (0, 0, 3.15), "lights", 8, 5), drum(0.18, 0.08, (0, 0, 3.42), "black", 8)])


def road_sign():
    """A stop sign on its post"""
    return join("road_sign", [box((0.07, 0.07, 2.2), (0, 0, 1.1), "metal"),
                              drum(0.38, 0.04, (0, -0.05, 2.1), "white", 8, (math.pi / 2, 0, math.pi / 8)),
                              drum(0.33, 0.05, (0, -0.07, 2.1), "red", 8, (math.pi / 2, 0, math.pi / 8))])


def highway_sign():
    """A big green highway sign on two posts, white lines of lettering and a white border"""
    p = [box((0.14, 0.14, 4.6), (-1.7, 0, 2.3), "metal"), box((0.14, 0.14, 4.6), (1.7, 0, 2.3), "metal"),
         box((4.2, 0.1, 2.2), (0, 0.02, 3.9), "white"), box((4.0, 0.12, 2.0), (0, -0.01, 3.9), "hwy_green")]
    for i, w in enumerate((2.6, 1.8, 2.2)):
        p.append(box((w, 0.05, 0.22), (-0.4 + (2.6 - w) * 0.3, -0.08, 4.5 - i * 0.55), "white"))
    p.append(box((0.5, 0.05, 0.5), (1.4, -0.08, 3.4), "white", (0, math.pi / 4, 0)))
    return join("highway_sign", p)


def trash_can():
    """A street trash can"""
    return join("trash_can", [drum(0.3, 0.9, (0, 0, 0.45), "metal_dark", 10), drum(0.33, 0.08, (0, 0, 0.94), "metal", 10)])


def bush():
    """A round green bush"""
    p = [roughen(ball((1.2, 1.1, 0.9), (0, 0, 0.45), "leaf", 7, 4), 0.1, 41),
         roughen(ball((0.8, 0.8, 0.7), (0.35, 0.2, 0.7), "leaf_dark", 6, 4), 0.08, 42),
         roughen(ball((0.7, 0.7, 0.6), (-0.3, -0.2, 0.6), "leaf", 6, 4), 0.08, 43)]
    return join("bush", p)


def stealth():
    """A stealth bomber: a black flying wing, saw-toothed behind, the cockpit a dark ridge"""
    mesh = bpy.data.meshes.new("stealth")
    v = [(0, -4.0, 0), (9.0, 2.0, 0), (6.0, 3.0, 0), (3.0, 1.8, 0), (0, 3.2, 0), (-3.0, 1.8, 0), (-6.0, 3.0, 0), (-9.0, 2.0, 0)]
    top = [(x, y, 0.35 if abs(x) < 3 else 0.12) for x, y, z in v]
    mesh.from_pydata(v + top, [], [tuple(range(7, -1, -1)), tuple(range(8, 16))] + [(i, (i + 1) % 8, 8 + (i + 1) % 8, 8 + i) for i in range(8)])
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    wing = bpy.data.objects.new("stealth", mesh)
    bpy.context.collection.objects.link(wing)
    _done(wing, "black")
    return join("stealth", [wing, box((1.6, 2.4, 0.4), (0, -1.6, 0.4), "metal_dark"), box((1.0, 0.8, 0.2), (0, -2.4, 0.62), "glass"),
                            drum(0.3, 0.3, (1.4, 2.4, 0.2), "flame", 8, (math.pi / 2, 0, 0)), drum(0.3, 0.3, (-1.4, 2.4, 0.2), "flame", 8, (math.pi / 2, 0, 0))])


def warthog():
    """A ground-attack jet: a grey body with its big gun at the nose, straight wings, two engines on
    pods up behind, and twin tails"""
    p = [drum(0.6, 8.0, (0, 0, 0), "jet", 8, (math.pi / 2, 0, 0)), cone(0.6, 1.4, (0, -4.6, 0), "jet", 8, (-math.pi / 2, 0, 0)),
         drum(0.12, 1.2, (0, -5.6, -0.1), "metal_dark", 6, (math.pi / 2, 0, 0)), box((1.0, 1.4, 0.45), (0, -2.8, 0.55), "glass"),
         box((12.0, 1.6, 0.18), (0, -0.2, -0.1), "jet"), box((5.0, 1.0, 0.14), (0, 3.6, 0.4), "jet")]
    for s in (-1, 1):
        p += [drum(0.5, 2.2, (0.9 * s, 2.0, 0.9), "metal_dark", 8, (math.pi / 2, 0, 0)), drum(0.42, 0.3, (0.9 * s, 3.2, 0.9), "flame", 8, (math.pi / 2, 0, 0)),
              box((0.12, 1.0, 1.6), (2.4 * s, 3.8, 1.1), "jet")]
        for x in (2.5, 4.0):
            p.append(box((0.16, 0.9, 0.16), (x * s, -0.4, -0.35), "olive_dark"))
    return join("warthog", p)


def beer_can():
    """An opened can of beer"""
    return join("beer_can", [drum(0.033, 0.12, (0, 0, 0.06), "can_red", 10), drum(0.034, 0.03, (0, 0, 0.06), "can_silver", 10),
                             drum(0.028, 0.01, (0, 0, 0.125), "can_silver", 10)])


def liquor_store():
    """A liquor store: a squat brick shop, its window full of bottles, LIQUOR in pink neon on top and a
    blue neon OPEN in the window"""
    p = [box((8.0, 6.0, 3.6), (0, 0, 1.8), "brick"), box((8.2, 6.2, 0.25), (0, 0, 3.7), "roof"),
         box((5.0, 0.08, 1.8), (0, -3.02, 1.6), "window"), box((1.2, 0.1, 2.2), (2.8, -3.05, 1.1), "door"),
         box((5.6, 0.3, 1.1), (0, -2.8, 4.4), "black"), box((5.0, 0.32, 0.6), (0, -2.84, 4.4), "neon_pink"),
         box((1.2, 0.1, 0.4), (-1.6, -3.08, 2.1), "neon_blue")]
    for i in range(10):
        x = -2.2 + (i % 5) * 0.9
        z = 1.0 + (i // 5) * 0.7
        p.append(drum(0.12, 0.5, (x, -2.9, z), ["beer", "beer_green", "white", "chili"][i % 4], 6))
    return join("liquor_store", p)


def hydrant():
    """A red fire hydrant: its barrel, a domed cap and the nozzles out either side"""
    return join("hydrant", [drum(0.22, 0.12, (0, 0, 0.06), "red", 8), drum(0.16, 0.6, (0, 0, 0.42), "red", 8),
                            drum(0.2, 0.08, (0, 0, 0.74), "red", 8), ball((0.32, 0.32, 0.24), (0, 0, 0.8), "red", 8, 4),
                            drum(0.06, 0.1, (0, 0, 0.94), "yellow", 6),
                            drum(0.08, 0.44, (0, 0, 0.5), "yellow", 6, (0, math.pi / 2, 0)),
                            drum(0.1, 0.12, (0, -0.2, 0.46), "yellow", 6, (math.pi / 2, 0, 0))])



def rocket():
    """A rocket on its pad, ready to go: a tall white first stage with black roll bands, a narrower
    second stage, the capsule under a red-tipped escape tower, four fins at its foot, the engine bell
    under it"""
    p = [cone(0.85, 1.0, (0, 0, 0.5), "metal_dark", 12, (math.pi, 0, 0)),
         drum(1.1, 9.0, (0, 0, 5.5), "white", 16), drum(1.12, 0.6, (0, 0, 3.0), "black", 16), drum(1.12, 0.6, (0, 0, 8.4), "black", 16),
         drum(1.13, 0.3, (0, 0, 6.0), "red", 16),
         cone(1.1, 0.6, (0, 0, 10.3), "white", 16), drum(0.85, 4.0, (0, 0, 12.6), "white", 14), drum(0.87, 0.4, (0, 0, 11.2), "black", 14),
         cone(0.85, 1.6, (0, 0, 15.4), "metal", 12), drum(0.08, 1.2, (0, 0, 16.8), "metal_dark", 4), cone(0.14, 0.4, (0, 0, 17.6), "red", 6),
         box((0.5, 0.08, 0.35), (0, -0.96, 14.9), "window")]
    for k in range(4):
        a = k / 4 * math.tau + math.pi / 4
        p.append(box((0.08, 1.4, 2.2), (1.4 * math.cos(a), 1.4 * math.sin(a), 2.0), "white", (0.25 * math.sin(a), -0.25 * math.cos(a), a + math.pi / 2)))
    return join("rocket", p)


def launch_pad():
    """A rocket's launch pad: a raised concrete deck over a flame trench, and a red steel service tower
    beside where the rocket stands, its swing arms reaching over, a lightning mast on top"""
    p = [box((14.0, 14.0, 1.5), (0, 0, 0.75), "concrete"), box((5.0, 15.0, 0.4), (0, 0, 1.35), "asphalt"),
         box((4.2, 2.4, 1.2), (0, 7.4, 0.5), "black"), box((4.2, 2.4, 1.2), (0, -7.4, 0.5), "black"),
         box((2.6, 2.6, 0.3), (0, 0, 1.62), "metal_dark")]
    tx = 3.6
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(box((0.3, 0.3, 18.0), (tx + 0.9 * sx + 0.9, 0.9 * sy, 10.5), "red"))
    for k in range(9):
        z = 2.5 + k * 2.0
        p.append(box((2.1, 2.1, 0.18), (tx + 0.9, 0, z), "red"))
        p.append(box((0.12, 2.5, 0.12), (tx + 1.8, 0, z + 1.0), "red", (0.8, 0, 0)))
    for z in (9.0, 13.5):
        p.append(box((2.2, 0.5, 0.3), (tx - 1.3, 0, z), "red"))
    p += [drum(0.1, 4.0, (tx + 0.9, 0, 21.5), "metal", 4), box((2.6, 2.6, 0.2), (tx + 0.9, 0, 19.5), "metal_dark")]
    return join("launch_pad", p)


def mission_control():
    """Mission control: a long low building, a band of lit windows round it, a big dish on its roof
    and aerials, its sign glowing over the door"""
    p = [box((14.0, 8.0, 4.0), (0, 0, 2.0), "concrete"), box((14.4, 8.4, 0.3), (0, 0, 4.15), "roof"),
         box((13.0, 0.08, 1.2), (0, -4.02, 2.6), "window"), box((13.0, 0.08, 1.2), (0, 4.02, 2.6), "window"),
         box((1.8, 0.1, 2.4), (0, -4.06, 1.2), "door"), box((4.0, 0.3, 0.7), (0, -4.2, 3.7), "screen_glow"),
         drum(0.25, 1.6, (3.5, 1.0, 5.0), "metal", 8), ball((3.0, 3.0, 1.2), (3.5, 1.0, 6.2), "white", 12, 4, (0.6, 0, 0)),
         drum(0.06, 3.0, (-5.0, 2.0, 5.6), "metal", 4), drum(0.06, 2.2, (-4.0, 2.5, 5.2), "metal", 4)]
    for x in (-6.9, 6.9):
        p.append(box((0.08, 7.0, 1.2), (x, 0, 2.6), "window"))
    return join("mission_control", p)

def bank():
    """A small-town bank: pale stone, four columns along its porch under a pediment, bronze doors,
    and a gold dollar sign over them"""
    p = [box((8.0, 6.0, 4.6), (0, 0.4, 2.3), "stone_pale"), box((8.4, 6.6, 0.3), (0, 0.3, 4.75), "concrete"),
         box((8.6, 1.8, 0.4), (0, -3.0, 0.2), "concrete"), box((8.4, 0.4, 0.5), (0, -3.6, 4.85), "stone_pale"),
         box((1.6, 0.1, 2.6), (0, -2.62, 1.3), "door"), box((7.4, 0.3, 0.9), (0, -3.6, 5.45), "stone_pale", (0, 0, 0)),
         box((0.5, 0.2, 1.3), (0, -3.82, 3.4), "gold"), box((1.1, 0.2, 0.22), (0, -3.83, 3.75), "gold"),
         box((1.1, 0.2, 0.22), (0, -3.83, 3.05), "gold"), box((2.0, 0.08, 1.4), (-2.6, -2.62, 2.2), "window"),
         box((2.0, 0.08, 1.4), (2.6, -2.62, 2.2), "window")]
    for x in (-3.3, -1.1, 1.1, 3.3):
        p.append(drum(0.32, 4.2, (x, -3.5, 2.5), "stone_pale", 8))
    return join("bank", p)


def fort_knox():
    """Fort Knox: the gold vault, a squat granite block of two storeys with a smaller one stepped up on
    top, a great bronze door, gold bars stacked inside it, a flag over it"""
    p = [box((16.0, 16.0, 6.0), (0, 0, 3.0), "stone"), box((16.6, 16.6, 0.5), (0, 0, 6.2), "concrete"),
         box((9.0, 9.0, 3.0), (0, 0, 7.9), "stone"), box((9.4, 9.4, 0.4), (0, 0, 9.6), "concrete"),
         box((4.0, 1.2, 4.6), (0, -8.2, 2.3), "stone_pale"), box((2.6, 0.2, 3.4), (0, -8.85, 1.7), "gold"),
         box((18.0, 18.0, 0.3), (0, 0, 0.15), "concrete"), drum(0.08, 5.0, (0, 0, 12.0), "metal", 6),
         box((1.6, 0.06, 1.0), (0.8, 0, 13.9), "red")]
    for i in range(6):
        p.append(box((0.9, 0.4, 0.3), (-0.9 + (i % 3) * 0.9, -9.0, 0.35 + (i // 3) * 0.32), "gold"))
    for s in (-1, 1):
        for k in range(3):
            p.append(box((1.6, 0.1, 1.0), (s * (3.0 + k * 2.2), -8.02, 4.2), "window"))
    return join("fort_knox", p)


def goalpost():
    """A football goalpost: a yellow post, the crossbar and the two uprights"""
    return join("goalpost", [box((0.16, 0.16, 3.0), (0, 0.6, 1.5), "yellow"), box((0.16, 0.6, 0.16), (0, 0.3, 3.0), "yellow"),
                             box((5.6, 0.16, 0.16), (0, 0, 3.0), "yellow"), box((0.14, 0.14, 4.0), (-2.8, 0, 5.0), "yellow"),
                             box((0.14, 0.14, 4.0), (2.8, 0, 5.0), "yellow")])


def tug():
    """A deep-space hauler after the Nostromo: a long dark industrial hull, the bridge stepped up at the
    front, towers and masts along its back, two great engine blocks glowing behind, and the pilot under
    an observation blister on the deck amidships"""
    p = [box((2.6, 6.4, 1.4), (0, 0, 0), "metal_dark"), box((2.0, 2.2, 0.9), (0, -2.2, 1.0), "metal"),
         box((1.4, 1.2, 0.6), (0, -2.8, 1.6), "metal_dark"), box((1.2, 0.08, 0.3), (0, -3.44, 1.7), "window"),
         box((0.9, 1.0, 1.6), (-0.75, 2.2, 1.4), "metal"), box((0.7, 0.8, 1.1), (0.85, 2.0, 1.2), "metal_dark"),
         drum(0.05, 1.4, (0.85, 2.0, 2.4), "metal", 4), drum(0.05, 1.2, (-0.75, 2.4, 2.75), "metal", 4),
         box((3.4, 0.5, 0.3), (0, -1.0, -0.65), "metal"), drum(0.95, 0.4, (0, 0.74, 0.85), "hull_edge", 14)]
    for s in (-1, 1):
        p += [box((1.3, 2.4, 1.6), (1.25 * s, 3.6, 0.0), "metal_dark"), drum(0.5, 0.16, (1.25 * s, 4.88, 0.0), "flame", 10, (math.pi / 2, 0, 0)),
              box((0.4, 4.0, 0.3), (1.45 * s, -0.6, 0.4), "metal")]
    for x, y in ((-0.95, -0.7), (0.95, -0.7), (-0.95, 0.1), (0.95, 0.1)):
        p.append(box((0.3, 0.3, 0.2), (x, y, 0.8), "metal"))
    # (the blister amidships over the pilot's seat, and two thirds the size it was: at 8.4 m long it
    # filled a phone's screen, and its far end swung out where the game draws things see-through)
    return _ship("tug", p, 0.5, 0.69, shift=(0, -0.74, 0), k=0.68)


def frigate():
    """A frigate after the Nebulon-B: a tall forward section with a strut and crossbar hung under it,
    a long thin spine with the pilot's pod at its middle, and a deep engine section behind glowing blue"""
    p = [box((1.4, 2.8, 1.8), (0, -3.6, 0.9), "white"), box((0.9, 2.0, 0.5), (0, -4.0, 2.0), "metal"),
         rod(0.15, (0, -4.0, 0.1), (0, -3.4, -1.1), "metal_dark", 6), box((2.8, 0.2, 0.2), (0, -3.4, -1.1), "metal"),
         box((0.35, 4.4, 0.35), (0, -0.2, 0.1), "metal"), box((0.2, 4.4, 0.6), (0, -0.2, -0.3), "metal_dark"),
         box((2.6, 2.6, 1.6), (0, 2.8, -0.2), "white"), box((2.0, 0.2, 1.1), (0, 4.15, -0.2), "light_blue"),
         box((1.2, 1.4, 0.6), (0, 2.4, 0.9), "metal"), drum(0.8, 0.5, (0, -0.375, 0.2), "metal", 14)]
    for s in (-1, 1):
        p.append(box((0.6, 2.0, 0.9), (1.5 * s, 2.6, -0.4), "white"))
        p.append(box((0.5, 0.15, 0.7), (1.5 * s, 3.65, -0.4), "light_blue"))
    # (seven tenths the size it was, about its middle: at 12 m it filled a phone's screen, and with the
    # pilot at the bow the stern swung far out on every turn)
    return _ship("frigate", p, 0.48, 0.3, shift=(0, 0.375, 0), k=0.7)


def trek():
    """A starship of the Federation sort: the great saucer in front with the pilot under glass on top
    of it, the slim neck down to the secondary hull, and two warp nacelles up on pylons behind, glowing
    red at the front and blue along their sides"""
    p = [drum(2.5, 0.42, (0, -1.6, 0.9), "white", 24), drum(1.0, 0.3, (0, -1.6, 1.2), "metal", 16),
         box((0.5, 1.4, 1.0), (0, 0.2, 0.4), "white", (0.5, 0, 0)), drum(0.55, 3.4, (0, 1.4, -0.2), "white", 12, (math.pi / 2, 0, 0)),
         drum(0.4, 0.2, (0, -0.35, -0.2), "light_amber", 10, (math.pi / 2, 0, 0))]
    for s in (-1, 1):
        p += [rod(0.11, (0.3 * s, 1.9, -0.05), (1.5 * s, 2.1, 1.1), "white", 6),
              drum(0.3, 3.8, (1.5 * s, 2.0, 1.1), "white", 10, (math.pi / 2, 0, 0)),
              ball((0.5, 0.5, 0.5), (1.5 * s, 0.1, 1.1), "light_red", 8, 4),
              box((0.1, 3.0, 0.3), (1.8 * s, 2.0, 1.1), "light_blue")]
    for i in range(16):
        a = i / 16 * math.tau
        p.append(ball((0.18, 0.18, 0.14), (2.5 * math.cos(a), -1.6 + 2.5 * math.sin(a), 0.9), "window", 4, 2))
    # (the saucer's middle over the pilot's seat, and two thirds the size it was: at 8 m it filled a
    # phone's screen)
    return _ship("trek", p, 0.5, 0.86, shift=(0, 1.6, 0), k=0.66)


def motorcycle():
    """A motorcycle and its rider (the game paints the bike and the rider's clothes for who rides it:
    a rider, a motorcycle cop, a biker)"""
    p = wheel(0.34, 0.14, (0, -0.75, 0.34)) + wheel(0.34, 0.14, (0, 0.75, 0.34))
    p += [box((0.3, 1.2, 0.3), (0, 0, 0.6), "paint"), box((0.34, 0.5, 0.32), (0, -0.25, 0.85), "paint"),
          box((0.32, 0.55, 0.12), (0, 0.3, 0.86), "black"), box((0.7, 0.06, 0.06), (0, -0.7, 1.15), "metal"),
          box((0.06, 0.3, 0.06), (0, -0.62, 1.0), "metal", (0.5, 0, 0)), drum(0.1, 0.08, (0, -0.85, 0.85), "headlight", 8, (math.pi / 2, 0, 0)),
          box((0.12, 0.6, 0.1), (0.2, 0.4, 0.4), "metal")]
    bike = join("motorcycle_body", p)
    man = figure("motorcycle_rider", False, False)
    man.location = (0, 0.25, 0.5)
    bpy.context.view_layer.update()
    return join("motorcycle", [bike, man])


def cult_altar():
    """A cult's altar: a ring of standing stones round a black obelisk with a glowing green eye, and
    braziers burning"""
    p = [drum(3.2, 0.12, (0, 0, 0.06), "stone", 16), cone(0.8, 4.2, (0, 0, 2.2), "black", 4),
         ball((0.6, 0.2, 0.4), (0, -0.4, 2.6), "lights_under", 8, 4)]
    for i in range(8):
        a = i / 8 * math.tau
        p.append(box((0.5, 0.35, 1.6), (2.8 * math.cos(a), 2.8 * math.sin(a), 0.8), "stone", (0, 0, a)))
    for i in range(4):
        a = i / 4 * math.tau + 0.4
        x, y = 1.8 * math.cos(a), 1.8 * math.sin(a)
        p += [drum(0.2, 0.7, (x, y, 0.35), "metal_dark", 6), ball((0.35, 0.35, 0.4), (x, y, 0.85), "camp", 6, 3)]
    return join("cult_altar", p)


def helicarrier():
    """A flying aircraft carrier: a long grey deck with its island, held up on four great rotors in
    rings, glowing blue beneath"""
    p = [box((7.0, 20.0, 1.2), (0, 0, 0), "metal"), box((6.6, 19.6, 0.1), (0, 0, 0.65), "metal_dark"),
         box((1.6, 4.0, 3.0), (2.6, 2.0, 2.0), "metal"), box((1.0, 1.0, 1.6), (2.6, 2.0, 4.2), "metal_dark"),
         box((0.12, 18.0, 0.04), (-0.2, 0, 0.72), "white")]
    for sx in (-1, 1):
        for sy in (-1, 1):
            at = (5.2 * sx, 6.5 * sy, 0)
            p += [drum(2.3, 0.5, at, "metal_dark", 16), drum(2.0, 0.3, (at[0], at[1], -0.2), "light_blue", 16)]
    return join("helicarrier", p)


def railgun():
    """A rail gun: a turret on a heavy base, its long twin rails ringed with glowing blue coils"""
    p = [box((3.0, 3.0, 0.8), (0, 0, 0.4), "olive"), drum(1.1, 0.8, (0, 0, 1.2), "olive_dark", 10),
         box((0.25, 6.0, 0.25), (-0.25, -2.8, 1.9), "metal_dark", (0.35, 0, 0)), box((0.25, 6.0, 0.25), (0.25, -2.8, 1.9), "metal_dark", (0.35, 0, 0))]
    for i in range(5):
        p.append(drum(0.5, 0.12, (0, -1.0 - i * 0.9, 1.6 + i * 0.33), "light_blue", 10, (math.pi / 2 + 0.35, 0, 0)))
    return join("railgun", p)


def laser_truck():
    """A truck carrying a laser: an olive cab and bed, a mast on the back with the red-glowing lens"""
    p = car_body_parts(5.6, "olive") + [box((0.3, 0.3, 1.4), (0, 1.4, 1.8), "metal_dark"), drum(0.6, 0.5, (0, 1.2, 2.6), "metal_dark", 10, (math.pi / 2, 0, 0)),
                                       drum(0.42, 0.1, (0, 0.92, 2.6), "light_red", 10, (math.pi / 2, 0, 0))]
    return join("laser_truck", p)


def fire_truck():
    """A fire engine: long and red, a ladder along its top, lights on the cab"""
    p = car_body_parts(7.0, "red") + [box((0.6, 5.0, 0.15), (0, 1.0, 2.0), "metal"), box((0.7, 0.1, 0.1), (0, 3.4, 2.05), "metal"),
                                      box((1.2, 0.3, 0.2), (0, -2.8, 2.35), "siren_red"), box((2.04, 4.6, 0.2), (0, 1.2, 1.0), "white")]
    return join("fire_truck", p)


def ambulance():
    """An ambulance: a white box van with a red stripe and a red cross, lights on top"""
    p = car_body_parts(5.6, "white") + [box((2.04, 3.6, 2.0), (0, 0.9, 1.6), "white"), box((2.06, 3.6, 0.3), (0, 0.9, 1.3), "red"),
                                        box((0.1, 0.8, 0.25), (1.04, 0.9, 2.1), "red"), box((0.1, 0.25, 0.8), (1.04, 0.9, 2.1), "red"),
                                        box((1.0, 0.3, 0.2), (0, -0.85, 2.7), "siren_red")]
    return join("ambulance", p)


def hospital():
    """A small town hospital: white, three storeys, rows of lit windows, a red cross high on the front
    and the emergency entrance under its canopy"""
    p = [box((12.0, 7.0, 7.5), (0, 0, 3.75), "white"), box((12.4, 7.4, 0.3), (0, 0, 7.6), "roof"),
         box((4.0, 2.0, 0.2), (0, -4.4, 2.6), "white"), box((0.15, 0.15, 2.6), (-1.8, -5.3, 1.3), "white"), box((0.15, 0.15, 2.6), (1.8, -5.3, 1.3), "white"),
         box((2.0, 0.1, 2.2), (0, -3.52, 1.1), "glass"), box((0.4, 0.12, 1.6), (0, -3.6, 6.2), "red"), box((1.6, 0.12, 0.4), (0, -3.6, 6.2), "red")]
    for row in range(3):
        for i in range(6):
            x = -5.0 + i * 2.0
            if row == 0 and abs(x) < 2.5:
                continue
            p.append(box((0.9, 0.1, 0.9), (x, -3.52, 1.6 + row * 2.2), "window"))
    return join("hospital", p)


def fire_station():
    """A fire station: red brick, two big garage doors, a hose tower on one side"""
    p = [box((10.0, 8.0, 4.6), (0, 0, 2.3), "brick"), box((10.4, 8.4, 0.3), (0, 0, 4.7), "roof"),
         box((2.4, 2.4, 9.0), (4.6, 2.6, 4.5), "brick"), box((2.6, 2.6, 0.3), (4.6, 2.6, 9.1), "roof"),
         box((3.0, 0.4, 0.7), (0, -4.1, 4.0), "white")]
    for x in (-2.4, 1.2):
        p.append(box((3.0, 0.1, 3.2), (x, -4.02, 1.6), "red"))
        p.append(box((2.6, 0.12, 0.5), (x, -4.04, 2.6), "window"))
    return join("fire_station", p)


def prison():
    """A prison: a long cell block of grey concrete, barred windows in rows, inside a high wall with
    razor wire along its top"""
    p = [box((14.0, 6.0, 6.0), (0, 2.0, 3.0), "concrete"), box((14.4, 6.4, 0.3), (0, 2.0, 6.15), "roof")]
    for row in range(2):
        for i in range(10):
            p.append(box((0.6, 0.1, 0.7), (-6.0 + i * 1.33, -1.02, 1.8 + row * 2.3), "black"))
    for s in (-1, 1):
        p.append(box((26.0, 0.6, 4.0), (0, 12.0 * s, 2.0), "concrete"))
        p.append(box((0.6, 24.0, 4.0), (13.0 * s, 0, 2.0), "concrete"))
        p.append(drum(0.25, 26.0, (0, 12.0 * s, 4.25), "metal", 6, (0, math.pi / 2, 0)))
        p.append(drum(0.25, 24.0, (13.0 * s, 0, 4.25), "metal", 6, (math.pi / 2, 0, 0)))
    p.append(box((3.0, 0.7, 3.4), (0, -12.0, 1.7), "metal_dark"))
    return join("prison", p)


def grain_elevator():
    """A grain elevator: a row of tall concrete bins, the head house up on top, and the spout down to
    the loading track"""
    p = []
    for i in range(4):
        p.append(drum(1.6, 16.0, (-4.8 + i * 3.2, 0, 8.0), "concrete", 12))
        p.append(drum(1.65, 0.3, (-4.8 + i * 3.2, 0, 16.1), "metal_dark", 12))
    p += [box((12.0, 3.0, 0.4), (0, 0, 16.4), "concrete"), box((4.0, 3.0, 4.0), (-1.5, 0, 18.6), "concrete"),
          box((4.2, 3.2, 0.3), (-1.5, 0, 20.7), "roof"), box((2.0, 0.1, 0.8), (-1.5, -1.55, 19.2), "window"),
          box((0.3, 0.3, 9.0), (6.4, -1.0, 12.0), "metal_dark", (0, -0.5, 0)), box((3.0, 4.0, 3.0), (-8.0, 0, 1.5), "metal")]
    return join("grain_elevator", p)


def chicken_coop():
    """A chicken coop: a little red shed up on legs, its ramp down and a wire run beside it"""
    p = [box((2.0, 1.6, 1.2), (0, 0, 1.2), "barn"), box((2.2, 1.0, 0.1), (0, -0.45, 1.95), "roof", (0.4, 0, 0)),
         box((2.2, 1.0, 0.1), (0, 0.45, 1.95), "roof", (-0.4, 0, 0)), box((0.4, 1.4, 0.06), (0.4, -1.3, 0.35), "wood", (0.55, 0, 0)),
         box((2.6, 2.4, 1.0), (0, -2.6, 0.5), "metal"), box((0.36, 0.06, 0.36), (0.4, -0.82, 1.1), "black")]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(box((0.1, 0.1, 0.6), (0.9 * sx, 0.7 * sy, 0.3), "wood_dark"))
    return join("chicken_coop", p)


def irrigation():
    """A center-pivot irrigation line: a long low truss of pipe across the field on wheeled towers"""
    p = [box((30.0, 0.2, 0.2), (0, 0, 3.0), "metal"), drum(0.5, 3.0, (-15.0, 0, 1.5), "metal_dark", 8)]
    for i in range(5):
        x = -9.0 + i * 6.0
        p += [box((0.12, 0.12, 3.0), (x - 0.6, 0, 1.5), "metal", (0, -0.2, 0)), box((0.12, 0.12, 3.0), (x + 0.6, 0, 1.5), "metal", (0, 0.2, 0))]
        p += wheel(0.5, 0.2, (x, 0, 0.5))
        p.append(drum(0.4, 0.08, (x + 3.0, 0, 2.6), "metal_dark", 6))
    return join("irrigation", p)


def feed_bin():
    """A small round grain bin of corrugated steel with its cone roof"""
    return join("feed_bin", [drum(1.6, 3.2, (0, 0, 1.6), "chrome", 14), cone(1.7, 1.2, (0, 0, 3.8), "metal", 14),
                             drum(0.25, 0.3, (0, 0, 4.5), "metal_dark", 6)])


BUILDERS = [cow, pig, sheep, chicken, lambda: figure("farmer", True), lambda: figure("person", False), scarecrow,
            car, police_car, pickup, tractor, jeep, tank, jet, hay_bale, outhouse, barn, farmhouse, house, silo,
            tree, pine, willow, cottonwood, joshua_tree, fence, tent, floodlight, ufo,
            mesa, butte, devils_tower, peak, crag, hydrant, bank, fort_knox, rocket, launch_pad, mission_control, saguaro, prickly_pear, sagebrush, rock, aspen, pinyon, adobe, windmill, pumpjack,
            diner, water_tower, horse, bison, longhorn, coyote, rv, cabin, camp_tent, lambda: figure("cowboy", False, True), orb, triangle, foo, cigar, bell, tictac, saturn, diamond, jelly, market, carnival, meteor, track, locomotive, boxcar, caboose, rider, balloon, fish, catfish, frog, tube_man, gas_station, dealership, schoolhouse, playground, crane, excavator, girders, mixer, tire_stack, scrap_pile, bench, gazebo, screen, speaker_post, bleachers, ferris_wheel, carousel, circus_tent, booth, street_light, lamp_post, road_sign, highway_sign, trash_can, bush, stealth, warthog, beer_can, liquor_store, goalpost, tug, frigate, trek, sunflower, cabbage, melon, pepper, motorcycle, cult_altar, helicarrier, railgun, laser_truck, fire_truck, ambulance, hospital, fire_station, prison, grain_elevator, chicken_coop, irrigation, feed_bin,
            bear, mountain_goat, elk, pronghorn, rabbit, lambda: rabbit("jackalope", True), roadrunner,
            lambda: bird("crow", "crow", 1.0), lambda: bird("hawk", "hawk", 1.7, "hawk_light"), phone_pole, phone_booth, helicopter, storefront, clock_tower, wheat, corn, pumpkin, hill, control_tower, plane, runway, city_hall, church, fountain, hay_pile, chinook, telescope, barrel, sasquatch, meteorite, satellite, crash_site, crash_dirt,
            police_station, hangar, watchtower, substation, observatory, seti_dish, pod, moon_surface, lounge_chair, cocktail, cooler, boombox, beer, bottle_cap,
            item_engine, item_beam, item_shield, item_dash, item_laser, item_turret, item_missiles, item_cloak,
            item_magnet, item_wide, item_scanner, item_jammer, item_coolant, item_lucky, item_armor, item_swivel, item_sling, item_starbits, item_second_wind, canister, item_nanobots, item_gold, item_emp]


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(MODELS, exist_ok=True)
    os.makedirs(ART, exist_ok=True)
    # (CE_ONLY=name,name builds just those models, and leaves the .blend alone: see tools/look_models.py)
    only = [n for n in os.environ.get("CE_ONLY", "").split(",") if n]
    x = 0.0
    for build in BUILDERS:
        if only and getattr(build, "__name__", "") not in only:
            continue
        root = build()
        if only and root.name not in only:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        root.select_set(True)
        for child in root.children:
            child.select_set(True)
        bpy.ops.export_scene.gltf(filepath=os.path.join(MODELS, root.name + ".glb"), export_format="GLB",
                                  use_selection=True, export_apply=True, export_yup=True)
        print("built", root.name)
        # (laid out in a row in the .blend, to look over)
        root.location.x = x
        x += max(root.dimensions.x, 2.0) + 3.0
    if not only:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ART, "models.blend"))


main()

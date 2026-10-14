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
    "red": (0.75, 0.12, 0.1), "yellow": (0.95, 0.75, 0.15), "white": (0.95, 0.95, 0.92),
    "skin": (0.92, 0.7, 0.55), "denim": (0.22, 0.32, 0.6), "shirt": (0.8, 0.3, 0.25),
    "straw": (0.88, 0.76, 0.42), "boot": (0.25, 0.16, 0.1), "hair": (0.3, 0.2, 0.12),
    "tyre": (0.08, 0.08, 0.08), "hub": (0.6, 0.6, 0.58), "glass": (0.35, 0.45, 0.55),
    "paint": (0.2, 0.45, 0.75), "olive": (0.3, 0.36, 0.2), "olive_dark": (0.2, 0.24, 0.13),
    "gun": (0.15, 0.15, 0.15), "tractor": (0.8, 0.15, 0.1), "barn": (0.62, 0.12, 0.1),
    "trim": (0.95, 0.93, 0.88), "roof": (0.3, 0.3, 0.33), "walls": (0.92, 0.9, 0.82),
    "wood": (0.5, 0.34, 0.2), "wood_dark": (0.32, 0.2, 0.12), "metal": (0.62, 0.64, 0.68),
    "metal_dark": (0.32, 0.34, 0.38), "leaf": (0.2, 0.42, 0.18), "leaf_dark": (0.12, 0.3, 0.14),
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
    "orb_shell": (0.62, 0.6, 0.58), "black_hull": (0.09, 0.09, 0.11), "hull_edge": (0.2, 0.2, 0.24),
}
GLOWS = {
    "window": ((1.0, 0.85, 0.45), 2.0), "siren_red": ((1.0, 0.1, 0.1), 3.0),
    "siren_blue": ((0.15, 0.35, 1.0), 3.0), "lights": ((1.0, 0.9, 0.4), 3.0),
    "lights_under": ((0.5, 1.0, 0.6), 3.0), "headlight": ((1.0, 0.95, 0.8), 2.0),
    "flame": ((1.0, 0.55, 0.15), 3.0), "neon": ((1.0, 0.35, 0.6), 3.0),
    "light_red": ((1.0, 0.2, 0.15), 3.0), "light_blue": ((0.3, 0.5, 1.0), 3.0), "light_white": ((1.0, 1.0, 0.95), 3.0),
    "light_amber": ((1.0, 0.65, 0.2), 3.0), "orb_glow": ((1.0, 0.6, 0.25), 2.0),
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
    # (the origin stays at the world's: every part was placed about the model's foot)
    return o


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
    p = []
    for s in (-1, 1):
        p.append(box((0.16, 0.18, 0.8), (0.11 * s, 0, 0.42), "denim"))
        p.append(box((0.17, 0.26, 0.1), (0.11 * s, -0.04, 0.05), "boot"))
        p.append(box((0.12, 0.12, 0.55), (0.3 * s, 0, 1.08), "shirt", (0, 0.15 * s, 0)))
        p.append(box((0.11, 0.11, 0.11), (0.33 * s, 0, 0.77), "skin"))
    p += [box((0.44, 0.24, 0.5), (0, 0, 1.08), "shirt"), box((0.3, 0.3, 0.32), (0, 0, 1.52), "skin")]
    for s in (-1, 1):
        p.append(box((0.04, 0.02, 0.05), (0.07 * s, -0.16, 1.55), "black"))
    if cowboy:
        p += [drum(0.38, 0.04, (0, 0, 1.69), "felt", 10), drum(0.16, 0.22, (0, 0, 1.8), "felt", 8, top=0.13),
              box((0.34, 0.06, 0.14), (0, -0.12, 1.33), "chili")]
    elif hat:
        p += [drum(0.32, 0.04, (0, 0, 1.68), "straw", 10), drum(0.17, 0.18, (0, 0, 1.77), "straw", 8)]
        p += [box((0.3, 0.25, 0.3), (0, 0.01, 1.0), "denim")]
    else:
        p += [box((0.32, 0.32, 0.1), (0, 0.02, 1.7), "hair"), box((0.32, 0.08, 0.24), (0, 0.13, 1.56), "hair")]
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
    turret.parent = body
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
    p = [box((7.0, 6.0, 3.2), (0, 0, 1.6), "walls"), gable(7.6, 6.6, 2.4, (0, 0, 3.2), "roof"),
         box((1.0, 0.1, 2.0), (0, -3.0, 1.0), "door"), box((0.6, 0.6, 1.6), (2.0, 1.5, 5.0), "barn"),
         box((7.2, 1.6, 0.1), (0, -3.6, 2.4), "roof"), box((0.1, 0.1, 2.3), (-3.4, -4.3, 1.15), "trim"),
         box((0.1, 0.1, 2.3), (3.4, -4.3, 1.15), "trim")]
    for x in (-2.2, 2.2):
        p.append(box((1.0, 0.1, 0.9), (x, -3.02, 1.7), "window"))
    for y in (-1.4, 1.4):
        p.append(box((0.1, 0.9, 0.9), (3.52, y, 1.7), "window"))
        p.append(box((0.1, 0.9, 0.9), (-3.52, y, 1.7), "window"))
    return join("farmhouse", p)


def house():
    p = [box((6.0, 6.0, 3.0), (0, 0, 1.5), "walls"), gable(6.6, 6.6, 2.2, (0, 0, 3.0), "roof"),
         box((1.0, 0.1, 2.0), (0, -3.0, 1.0), "door")]
    for x in (-1.8, 1.8):
        p.append(box((0.9, 0.1, 0.9), (x, -3.02, 1.7), "window"))
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
         drum(1.5, 0.5, (0, 0, -0.35), "metal_dark", 12, top=1.0), drum(1.0, 0.06, (0, 0, -0.6), "lights_under", 12),
         drum(1.05, 0.24, (0, 0, 0.42), "metal_dark", 12)]
    for i in range(12):
        a = i / 12 * math.tau
        p.append(ball((0.28, 0.28, 0.2), (2.62 * math.cos(a), 2.62 * math.sin(a), 0), "lights", 6, 3))
    body = join("ufo", p)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=1.0, location=(0, 0, 0.5))
    dome = bpy.context.object
    # (only the top half: the alien sits in it)
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(dome.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.01], context="VERTS")
    bm.to_mesh(dome.data)
    bm.free()
    dome.scale = (1.0, 1.0, 1.1)
    _done(dome, "glass")
    dome.name = "dome"
    bpy.ops.object.select_all(action="DESELECT")
    dome.select_set(True)
    bpy.context.view_layer.objects.active = dome
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
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
    return join("peak", [lathe("peak", [(24, 0), (18, 8), (12, 18), (7.5, 26), (3.5, 33), (0.3, 37)],
                               ["mountain", "mountain", "mountain", "snow", "snow", "snow"], 10, 1.6, seed=11)])


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
    fan.parent = body
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
    beam.parent = body
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
    """The glass the alien sits under: the top half of a ball, named "dome" (the game makes it glass)"""
    import bmesh
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=radius, location=(0, 0, z))
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
    verts = [(0, -front, 0), (half, back, 0), (-half, back, 0), (0, -front, -0.3), (half, back, -0.3), (-half, back, -0.3), (0, 0, 0.45)]
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
    p = [hull, box((0.5, 5.6, 0.12), (0, 0.1, -0.33), "hull_edge"), drum(0.55, 0.12, (0, 0.2, -0.38), "light_red", 10)]
    for x, y in ((0, -front + 0.45), (half - 0.55, back - 0.3), (-half + 0.55, back - 0.3)):
        p.append(ball((0.6, 0.6, 0.3), (x, y, -0.33), "light_white", 8, 4))
    body = join("triangle", p)
    dome = _dome(0.75, 0.2, 1.0)
    dome.parent = body
    return body

BUILDERS = [cow, pig, sheep, chicken, lambda: figure("farmer", True), lambda: figure("person", False), scarecrow,
            car, police_car, pickup, tractor, jeep, tank, jet, hay_bale, outhouse, barn, farmhouse, house, silo,
            tree, pine, fence, tent, floodlight, ufo,
            mesa, butte, devils_tower, peak, saguaro, prickly_pear, sagebrush, rock, aspen, pinyon, adobe, windmill, pumpjack,
            diner, water_tower, horse, bison, longhorn, coyote, rv, cabin, camp_tent, lambda: figure("cowboy", False, True), orb, triangle]


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(MODELS, exist_ok=True)
    os.makedirs(ART, exist_ok=True)
    x = 0.0
    for build in BUILDERS:
        root = build()
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ART, "models.blend"))


main()

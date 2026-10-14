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
}
GLOWS = {
    "window": ((1.0, 0.85, 0.45), 2.0), "siren_red": ((1.0, 0.1, 0.1), 3.0),
    "siren_blue": ((0.15, 0.35, 1.0), 3.0), "lights": ((1.0, 0.9, 0.4), 3.0),
    "lights_under": ((0.5, 1.0, 0.6), 3.0), "headlight": ((1.0, 0.95, 0.8), 2.0),
    "flame": ((1.0, 0.55, 0.15), 3.0),
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

def figure(name, hat):
    p = []
    for s in (-1, 1):
        p.append(box((0.16, 0.18, 0.8), (0.11 * s, 0, 0.42), "denim"))
        p.append(box((0.17, 0.26, 0.1), (0.11 * s, -0.04, 0.05), "boot"))
        p.append(box((0.12, 0.12, 0.55), (0.3 * s, 0, 1.08), "shirt", (0, 0.15 * s, 0)))
        p.append(box((0.11, 0.11, 0.11), (0.33 * s, 0, 0.77), "skin"))
    p += [box((0.44, 0.24, 0.5), (0, 0, 1.08), "shirt"), box((0.3, 0.3, 0.32), (0, 0, 1.52), "skin")]
    for s in (-1, 1):
        p.append(box((0.04, 0.02, 0.05), (0.07 * s, -0.16, 1.55), "black"))
    if hat:
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


BUILDERS = [cow, pig, sheep, chicken, lambda: figure("farmer", True), lambda: figure("person", False), scarecrow,
            car, police_car, pickup, tractor, jeep, tank, jet, hay_bale, outhouse, barn, farmhouse, house, silo,
            tree, pine, fence, tent, floodlight, ufo]


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

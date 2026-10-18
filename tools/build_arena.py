# Builds the models for Close Encounters' ARENA: a carnival the aliens have set up on the moon, where the
# saucers fight it out like bumper cars (after Banjo-Kazooie's Witchyworld). The round crater floor and
# its padded bumper rim, the carnival round it (an entrance arch, a Ferris wheel, striped tents, bumper
# posts, lamp poles strung with bulbs, a rocket tower), and the things lying about to be beamed up:
# astronauts, tourists in bubble helmets, a moon buggy, a lander, a habitat, radio dishes, solar
# panels, a flag, moon rocks, glowing gems, a snack cart and a little booth.
#
#   blender -b --factory-startup --python tools/build_arena.py
#
# Writes models/arena_<name>.glb (each model alone) and art/arena.blend (all of them in a row, to open
# and edit). CE_ONLY=arena_astronaut,arena_gem_pink builds just those and leaves the .blend alone.
# It uses build_models.py's helpers (box, ball, drum, lathe, _moonlet, figure...) and its conventions:
# low-poly and flat-coloured (Godot swaps each material for its PS1 shader in that colour; GLOWS
# glow), each model standing on the ground at its origin and facing -Y.

import bpy
import math
import os
import random

HERE = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(HERE, "build_models.py"), encoding="utf-8").read().replace("\nmain()\n", "\n")
exec(compile(_src, "build_models.py", "exec"))

COLOURS.update({
    "suit": (0.93, 0.93, 0.9), "suit_grey": (0.6, 0.62, 0.66), "tent_purple": (0.42, 0.18, 0.62), "tent_teal": (0.1, 0.6, 0.58),
    "bumper_red": (0.85, 0.12, 0.18), "pad": (0.95, 0.93, 0.85), "foil": (0.88, 0.7, 0.22), "candy": (1.0, 0.62, 0.86),
    "rover_blue": (0.2, 0.4, 0.8), "flag_red": (0.8, 0.1, 0.12), "flag_blue": (0.15, 0.25, 0.65), "alien_green": (0.45, 0.85, 0.35),
})
GLOWS.update({
    "gem_pink": ((1.0, 0.35, 0.75), 1.4), "gem_blue": ((0.35, 0.7, 1.0), 1.4), "gem_green": ((0.4, 1.0, 0.55), 1.4),
    "gem_gold": ((1.0, 0.8, 0.25), 1.4), "lime_glow": ((0.55, 1.0, 0.3), 2.5), "sign_glow": ((1.0, 0.45, 0.9), 2.5),
})

RIM = 40.0  # the floor's radius to the bumper rail, metres


# ---------------------------------------------------------------- the arena itself

def arena_floor():
    """The crater's floor: a disc RIM metres across of regolith, flat in the middle and rising gently
    to the rim like a bowl, cut into a grid of about 3 m (it bends with the world: see box()), with a
    few small craters in it"""
    import bmesh
    step = 3.0
    n = int(math.ceil((RIM + step * 2.0) / step))
    verts, index = [], {}
    def height(x, y):
        r = math.hypot(x, y)
        return 0.0 if r < RIM * 0.6 else 1.0 * ((r - RIM * 0.6) / (RIM * 0.4)) ** 2
    for i in range(-n, n + 1):
        for j in range(-n, n + 1):
            x, y = i * step, j * step
            r = math.hypot(x, y)
            if r > RIM + step * 2.0:
                continue
            if r > RIM + 1.0:
                # (the edge pulled onto a circle under the rail)
                x, y = x / r * (RIM + 1.0), y / r * (RIM + 1.0)
            index[(i, j)] = len(verts)
            verts.append((x, y, height(x, y)))
    faces, mats = [], []
    for i in range(-n, n):
        for j in range(-n, n):
            q = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
            if all(k in index for k in q):
                faces.append(tuple(index[k] for k in q))
                # (all one regolith: the game's moon shader patches it, and darker cells read as a checkerboard)
                mats.append(0)
    mesh = bpy.data.meshes.new("arena_floor")
    mesh.from_pydata(verts, [], faces)
    o = bpy.data.objects.new("arena_floor", mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat("regolith"))
    o.data.materials.append(mat("regolith_dark"))
    for poly, m in zip(o.data.polygons, mats):
        poly.material_index = m
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    p = [o]
    rnd = random.Random(5)
    for k in range(9):
        a = k * 2.39996 + rnd.uniform(-0.3, 0.3)
        r = rnd.uniform(8.0, RIM * 0.55)
        size = rnd.uniform(1.6, 3.4)
        at = (r * math.cos(a), r * math.sin(a), 0.0)
        # (a floor a little dark, standing clear of the ground, in a raised rim that hides its side)
        p.append(drum(size, 0.16, (at[0], at[1], 0.0), "regolith_dark", 14))
        p.append(_ring(size + 0.1, 0.22, (at[0], at[1], 0.06), "regolith", 16, 5))
    return join("arena_floor", p)


def _uncapped(o):
    """A lathe without the cap lathe() puts over its last ring (the rim bank's would roof the arena over)"""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if len(f.verts) > 4], context="FACES_ONLY")
    bm.to_mesh(o.data)
    bm.free()
    return o


def arena_rim():
    """The crater's rim all round the floor: a regolith bank, and on its foot the bumper rail, padded and
    striped red and white like a dodgem track's, with lights along its top"""
    p = [_uncapped(lathe("arena_bank", [(RIM + 0.6, 0.0), (RIM + 2.0, 1.2), (RIM + 5.0, 3.2), (RIM + 9.0, 3.6), (RIM + 14.0, 2.0)],
               ["regolith", "regolith", "regolith_dark", "regolith"], sides=48, wobble=0.25, seed=3))]
    count = 64
    for k in range(count):
        a0, a1 = k / count * math.tau, (k + 1) / count * math.tau
        r = RIM + 0.2
        a = (r * math.cos(a0), r * math.sin(a0), 1.6)
        b = (r * math.cos(a1), r * math.sin(a1), 1.6)
        p.append(rod(0.75, a, b, "bumper_red" if k % 2 else "pad", 8))
        if k % 4 == 0:
            p.append(ball((0.34, 0.34, 0.3), (r * math.cos(a0), r * math.sin(a0), 2.42), "light_amber" if k % 8 else "light_red", 6, 3))
    # (the rail's lower edge: a dark kerb it stands on)
    p.append(_ring(RIM + 0.25, 0.5, (0, 0, 0.6), "metal_dark", 64, 6))
    return join("arena_rim", p)


# ---------------------------------------------------------------- the carnival round it

def arena_arch():
    """The carnival's entrance arch: two striped towers topped with glowing balls, an arch of lights
    between them and a glowing alien sign hung from it"""
    p = []
    for s in (-1, 1):
        x = 5.0 * s
        for k in range(6):
            p.append(drum(0.9, 1.0, (x, 0, 0.5 + k), "tent_purple" if k % 2 else "yellow", 8))
        p += [cone(1.2, 1.6, (x, 0, 6.8), "bumper_red", 8), ball((0.7, 0.7, 0.7), (x, 0, 7.9), "neon_pink", 8, 4)]
    steps = 14
    for k in range(steps):
        a0, a1 = k / steps * math.pi, (k + 1) / steps * math.pi
        pa = (5.0 * math.cos(a0), 0, 6.0 + 3.0 * math.sin(a0))
        pb = (5.0 * math.cos(a1), 0, 6.0 + 3.0 * math.sin(a1))
        p.append(rod(0.32, pa, pb, "tent_teal", 6))
        p.append(ball((0.34, 0.34, 0.34), pa, ["light_red", "light_amber", "light_blue", "lime_glow"][k % 4], 6, 3))
    p += [box((6.0, 0.3, 1.6), (0, -0.3, 7.2), "black"), box((5.4, 0.12, 1.1), (0, -0.48, 7.2), "sign_glow"),
          rod(0.05, (-2.4, -0.3, 8.0), (-2.4, -0.3, 8.9), "metal", 4), rod(0.05, (2.4, -0.3, 8.0), (2.4, -0.3, 8.9), "metal", 4)]
    return join("arena_arch", p)


def arena_ferris():
    """A Ferris wheel the aliens brought: a ring of glowing spokes on two legs, little saucer-shaped
    cars hung round it"""
    hub = (0, 0, 9.0)
    p = [drum(0.7, 1.8, hub, "metal_dark", 10, (math.pi / 2, 0, 0))]
    for s in (-1, 1):
        p.append(rod(0.25, (-3.2, 0.7 * s, 0), (0, 0.7 * s, 9.0), "metal", 6))
        p.append(rod(0.25, (3.2, 0.7 * s, 0), (0, 0.7 * s, 9.0), "metal", 6))
        p.append(_ring(7.0, 0.18, (0, 0.6 * s, 9.0), "tent_teal", 32, 5, (math.pi / 2, 0, 0)))
    cars = 10
    for k in range(cars):
        a = k / cars * math.tau
        x, z = 7.0 * math.cos(a), 9.0 + 7.0 * math.sin(a)
        p.append(rod(0.09, (0, 0, 9.0), (x, 0, z), "neon_pink" if k % 2 else "neon_blue", 4))
        p.append(rod(0.05, (x, 0, z), (x, 0, z - 0.9), "metal", 4))
        p.append(ball((1.3, 1.3, 0.5), (x, 0, z - 1.15), ["bumper_red", "yellow", "tent_purple", "tent_teal"][k % 4], 8, 4))
        p.append(ball((0.6, 0.6, 0.5), (x, 0, z - 0.95), "glass", 8, 4))
    return join("arena_ferris", p)


def arena_tent():
    """A striped carnival tent, purple and teal, with a glowing sign over its door"""
    p = [drum(3.0, 2.4, (0, 0, 1.2), "tent_purple", 12), cone(3.4, 2.6, (0, 0, 3.7), "tent_teal", 12),
         drum(0.05, 1.2, (0, 0, 5.5), "metal", 4), box((0.7, 0.04, 0.45), (0.35, 0, 5.9), "neon_pink")]
    for k in range(12):
        a = k / 12 * math.tau
        if k % 2:
            p.append(box((0.5, 0.08, 2.4), (3.0 * math.cos(a), 3.0 * math.sin(a), 1.2), "yellow", (0, 0, a + math.pi / 2)))
    p += [box((1.6, 0.5, 1.9), (0, -2.9, 0.95), "black"), box((2.4, 0.2, 0.6), (0, -3.1, 2.7), "black"),
          box((2.1, 0.06, 0.4), (0, -3.22, 2.7), "sign_glow")]
    return join("arena_tent", p)


def arena_bumper_post():
    """A dodgem-track post: a striped padded pillar with a lamp on top (a thing to bounce off)"""
    p = []
    for k in range(4):
        p.append(drum(0.55, 0.6, (0, 0, 0.3 + k * 0.6), "bumper_red" if k % 2 else "pad", 10))
    p += [drum(0.62, 0.3, (0, 0, 0.15), "metal_dark", 10), ball((0.5, 0.5, 0.5), (0, 0, 2.65), "light_amber", 8, 4)]
    return join("arena_bumper_post", p)


def arena_lights():
    """A lamp pole strung with bulbs: strings of them looping out from its top to the ground all round"""
    p = [drum(0.12, 6.0, (0, 0, 3.0), "metal_dark", 6), ball((0.45, 0.45, 0.45), (0, 0, 6.15), "light_white", 6, 3),
         drum(0.4, 0.2, (0, 0, 0.1), "metal_dark", 8)]
    bulbs = ["light_red", "light_amber", "light_blue", "lime_glow", "neon_pink"]
    for s in range(4):
        a = s / 4 * math.tau + 0.4
        steps = 8
        prev = (0.0, 0.0, 6.0)
        for k in range(1, steps + 1):
            t = k / steps
            x, y = 4.5 * t * math.cos(a), 4.5 * t * math.sin(a)
            z = 6.0 - 3.6 * t - 1.0 * math.sin(t * math.pi)
            p.append(rod(0.03, prev, (x, y, z), "black", 3))
            p.append(ball((0.22, 0.22, 0.26), (x, y, z - 0.12), bulbs[(k + s) % 5], 5, 3))
            prev = (x, y, z)
        p.append(drum(0.15, 0.4, (prev[0], prev[1], 0.2), "metal_dark", 6))
        p.append(rod(0.03, prev, (prev[0], prev[1], 0.4), "black", 3))
    return join("arena_lights", p)


def arena_rocket_tower():
    """A tower like an old rocket standing on its fins, striped, its porthole windows lit, a beacon on
    its nose"""
    p = [lathe("rocket_body", [(1.4, 0.0), (1.6, 1.0), (1.6, 7.0), (1.2, 9.5), (0.4, 11.0), (0.05, 11.6)],
               ["white", "bumper_red", "white", "bumper_red", "white"], sides=12),
         ball((0.4, 0.4, 0.4), (0, 0, 11.75), "light_red", 6, 3)]
    for k in range(3):
        a = k / 3 * math.tau
        p.append(box((0.25, 2.4, 3.0), (1.9 * math.cos(a), 1.9 * math.sin(a), 1.5), "tent_teal", (0, 0, a + math.pi / 2)))
    for k in range(4):
        a = k / 4 * math.tau + 0.4
        p.append(drum(0.4, 0.24, (1.6 * math.cos(a), 1.6 * math.sin(a), 5.5), "window", 10, (math.pi / 2, 0, a + math.pi / 2)))
    return join("arena_rocket_tower", p)


# ---------------------------------------------------------------- things to take up

def arena_astronaut():
    """An astronaut: the same blocky person under the same glass bubble as the tourists, in a space suit
    (the game paints their clothes white, see Thing.KINDS), a life-support pack on their back and a
    panel of lights on their chest"""
    body = figure("arena_astronaut_body", False)
    pack = [box((0.38, 0.2, 0.44), (0, 0.22, 0.76), "suit_grey"), box((0.3, 0.06, 0.08), (0, 0.33, 0.9), "suit"),
            box((0.18, 0.05, 0.1), (0, -0.14, 0.8), "suit_grey"), box((0.05, 0.03, 0.04), (-0.04, -0.17, 0.81), "light_red"),
            box((0.05, 0.03, 0.04), (0.04, -0.17, 0.81), "light_blue")]
    bubble = ball((0.94, 0.94, 0.94), (0, 0, 1.22), "glass", 16, 10)
    bubble.name = "dome_bubble"
    rim = _ring(0.38, 0.05, (0, 0, 0.84), "metal", 16, 5)
    return _with_glass(join("arena_astronaut", [body, rim] + pack), bubble)


def arena_tourist():
    """A tourist come to the moon to see the carnival: one of the blocky people in a loud shirt (the game
    tints it), a glass bubble over their head"""
    body = figure("arena_tourist_body", False)
    bubble = ball((0.94, 0.94, 0.94), (0, 0, 1.22), "glass", 16, 10)
    bubble.name = "dome_bubble"
    rim = _ring(0.38, 0.05, (0, 0, 0.84), "metal", 16, 5)
    return _with_glass(join("arena_tourist", [body, rim]), bubble)


def _with_glass(body, glass):
    """Hangs a glass part on a joined model (the game draws a part named "dome..." as glass)"""
    bpy.context.view_layer.update()
    glass.parent = body
    glass.matrix_parent_inverse = body.matrix_world.inverted()
    return body


def arena_rover():
    """A moon buggy: an open frame on four wire wheels, two seats, a dish and an antenna"""
    p = [box((1.5, 2.6, 0.12), (0, 0, 0.6), "foil"), box((1.6, 0.12, 0.4), (0, -1.3, 0.75), "metal"),
         box((1.6, 0.12, 0.4), (0, 1.3, 0.75), "metal"), box((0.5, 0.5, 0.5), (-0.4, 0.2, 0.9), "suit_grey"),
         box((0.5, 0.5, 0.5), (0.4, 0.2, 0.9), "suit_grey"), box((0.5, 0.12, 0.6), (-0.4, 0.5, 1.2), "suit_grey"),
         box((0.5, 0.12, 0.6), (0.4, 0.5, 1.2), "suit_grey"), rod(0.03, (0.6, 1.0, 0.7), (0.6, 1.0, 2.0), "metal", 4),
         drum(0.35, 0.06, (-0.5, 1.0, 1.5), "white", 10, (0.5, 0, 0)), rod(0.04, (-0.5, 1.0, 0.7), (-0.5, 1.0, 1.45), "metal", 4)]
    for x in (-0.8, 0.8):
        for y in (-0.95, 0.95):
            p += [drum(0.38, 0.22, (x, y, 0.38), "metal_dark", 10, (0, math.pi / 2, 0)),
                  drum(0.2, 0.26, (x, y, 0.38), "foil", 8, (0, math.pi / 2, 0))]
    return join("arena_rover", p)


def arena_lander():
    """A lunar lander: a gold-foil descent stage on four splayed legs, the boxy cabin on top with its
    windows and dish"""
    p = [drum(1.1, 1.0, (0, 0, 1.6), "foil", 8), box((1.4, 1.4, 1.2), (0, 0, 2.7), "suit_grey"),
         box((0.5, 0.06, 0.35), (0, -0.72, 2.95), "window"), drum(0.4, 0.06, (0.6, 0.4, 3.6), "white", 10, (0.6, 0, 0)),
         rod(0.04, (0.6, 0.4, 3.3), (0.6, 0.4, 3.55), "metal", 4), cone(0.5, 0.5, (0, 0, 0.95), "metal_dark", 8, (math.pi, 0, 0))]
    for k in range(4):
        a = k / 4 * math.tau + math.pi / 4
        top = (0.9 * math.cos(a), 0.9 * math.sin(a), 1.5)
        foot = (2.0 * math.cos(a), 2.0 * math.sin(a), 0.1)
        p += [rod(0.06, top, foot, "metal", 6), drum(0.3, 0.08, foot, "metal", 8)]
    return join("arena_lander", p)


def arena_habitat():
    """A moonbase habitat: a squat round module under a white dome, a hatch, a lit porthole band"""
    p = [drum(2.6, 1.6, (0, 0, 0.8), "suit_grey", 16), lathe("habitat_dome", [(2.6, 1.6), (2.3, 2.6), (1.4, 3.4), (0.05, 3.7)],
         ["white", "white", "white"], sides=16), box((1.0, 0.8, 1.4), (0, -2.6, 0.7), "white"), box((0.6, 0.06, 1.0), (0, -3.02, 0.65), "metal_dark")]
    for k in range(10):
        a = k / 10 * math.tau
        p.append(drum(0.22, 0.12, (2.62 * math.cos(a), 2.62 * math.sin(a), 1.1), "window", 8, (math.pi / 2, 0, a + math.pi / 2)))
    return join("arena_habitat", p)


def arena_dish():
    """A radio dish on a tripod, tipped to the sky (to take up whole)"""
    p = [rod(0.08, (-0.7, -0.4, 0), (0, 0, 1.8), "metal", 6), rod(0.08, (0.7, -0.4, 0), (0, 0, 1.8), "metal", 6),
         rod(0.08, (0, 0.8, 0), (0, 0, 1.8), "metal", 6), drum(1.4, 0.3, (0, 0.2, 2.3), "white", 14, (0.6, 0, 0), top=0.5),
         rod(0.04, (0, 0.1, 2.4), (0, -0.5, 3.2), "metal", 4), ball((0.2, 0.2, 0.2), (0, -0.5, 3.25), "light_red", 6, 3)]
    return join("arena_dish", p)


def arena_solar():
    """A solar panel array: a frame on a post, its cells dark blue in a silver grid"""
    tilt = 0.5
    p = [drum(0.1, 1.2, (0, 0, 0.6), "metal", 6), box((3.2, 1.8, 0.08), (0, 0, 1.3), "metal", (tilt, 0, 0))]
    # (the cells laid on the frame's tilted face, standing a little out of it)
    up = (0.0, -math.sin(tilt), math.cos(tilt))
    for i in range(4):
        for j in range(2):
            v = -0.42 + j * 0.84
            at = (-1.2 + i * 0.8 + up[0] * 0.06, v * math.cos(tilt) + up[1] * 0.06, 1.3 + v * math.sin(tilt) + up[2] * 0.06)
            p.append(box((0.72, 0.78, 0.06), at, "panel", (tilt, 0, 0)))
    return join("arena_solar", p)


def arena_flag():
    """A flag on the moon: an alien's, a green saucer on purple, held out by its top bar"""
    p = [drum(0.04, 2.6, (0, 0, 1.3), "metal", 6), rod(0.03, (0, 0, 2.5), (1.4, 0, 2.5), "metal", 4),
         box((1.4, 0.04, 0.9), (0.72, 0, 2.03), "tent_purple"), ball((0.5, 0.06, 0.2), (0.72, -0.03, 2.03), "alien_green", 8, 3),
         drum(0.25, 0.1, (0, 0, 0.05), "regolith_dark", 8)]
    return join("arena_flag", p)


def arena_rock_small():
    return join("arena_rock_small", [roughen(ball((0.9, 0.8, 0.6), (0, 0, 0.25), "moon_pale", 7, 4), 0.08, 2),
                                     roughen(ball((0.5, 0.5, 0.4), (0.4, 0.2, 0.15), "moon_dark", 6, 3), 0.05, 3)])


def arena_rock_big():
    """A big moon rock: a moonlet half sunk in the floor"""
    return join("arena_rock_big", _moonlet(1.2, (0, 0, 0.75), 77, craters=7, segs=12, rings=8))


def _gem(name, glow):
    """A glowing moon gem: a cluster of crystals standing out of a lump of rock"""
    rnd = random.Random(len(name))
    p = [roughen(ball((1.0, 0.9, 0.5), (0, 0, 0.15), "moon_dark", 7, 4), 0.06, 4)]
    for k in range(5):
        a = k / 5 * math.tau + rnd.uniform(-0.3, 0.3)
        lean = 0.0 if k == 0 else 0.45
        size = 0.32 if k == 0 else rnd.uniform(0.16, 0.24)
        long = 1.3 if k == 0 else rnd.uniform(0.6, 0.9)
        foot = (0.0, 0.0, 0.2) if k == 0 else (0.22 * math.cos(a), 0.22 * math.sin(a), 0.2)
        tip = (foot[0] + math.sin(lean) * math.cos(a) * long, foot[1] + math.sin(lean) * math.sin(a) * long, foot[2] + math.cos(lean) * long)
        p.append(rod(size, foot, tip, glow, 6))
        p.append(cone(size, size * 1.6, (0, 0, 0), glow, 6))
        # (the point on the top of the crystal, put where the rod ends)
        last = p[-1]
        from mathutils import Vector
        d = (Vector(tip) - Vector(foot)).normalized()
        last.location = Vector(tip) + d * size * 0.8
        last.rotation_euler = Vector((0, 0, 1)).rotation_difference(d).to_euler()
    return join(name, p)


def arena_gem_pink():
    return _gem("arena_gem_pink", "gem_pink")


def arena_gem_blue():
    return _gem("arena_gem_blue", "gem_blue")


def arena_gem_green():
    return _gem("arena_gem_green", "gem_green")


def arena_gem_gold():
    return _gem("arena_gem_gold", "gem_gold")


def arena_snack_cart():
    """An alien carnival snack cart: a striped awning on poles over a counter on wheels, a tub of pink
    cotton candy clouds and a glowing sign"""
    p = [box((1.8, 1.0, 1.0), (0, 0, 0.7), "white"), box((1.84, 1.04, 0.12), (0, 0, 1.22), "bumper_red"),
         box((0.12, 0.6, 0.12), (1.0, 0, 0.9), "metal")]
    for x in (-0.6, 0.6):
        p.append(drum(0.24, 0.1, (x, -0.52, 0.24), "tyre", 8, (math.pi / 2, 0, 0)))
        p.append(drum(0.24, 0.1, (x, 0.52, 0.24), "tyre", 8, (math.pi / 2, 0, 0)))
    for x in (-0.85, 0.85):
        for y in (-0.45, 0.45):
            p.append(drum(0.04, 1.3, (x, y, 1.9), "metal", 4))
    for k in range(6):
        p.append(box((0.32, 1.3, 0.1), (-0.8 + k * 0.32, 0, 2.6), "tent_purple" if k % 2 else "yellow", (0, 0.0, 0)))
    for k in range(5):
        p.append(roughen(ball((0.4, 0.4, 0.4), (-0.5 + k * 0.25, -0.1 + (k % 2) * 0.2, 1.5 + (k % 2) * 0.1), "candy", 6, 4), 0.04, 50 + k))
    p += [box((1.2, 0.06, 0.3), (0, -0.53, 0.95), "sign_glow")]
    return join("arena_snack_cart", p)


def arena_booth():
    """A little carnival game booth: a counter under a striped roof, a row of alien dolls on the shelf
    (prizes) and lights along the front"""
    p = [box((2.4, 1.4, 1.0), (0, 0, 0.5), "tent_teal"), box((2.5, 1.5, 0.1), (0, 0, 1.05), "yellow"),
         box((2.4, 0.12, 1.4), (0, 0.65, 1.8), "tent_purple"), box((2.5, 0.12, 0.06), (0, 0.5, 1.6), "metal")]
    for x in (-1.15, 1.15):
        p.append(drum(0.06, 1.6, (x, -0.65, 1.8), "metal", 4))
    for k in range(8):
        p.append(box((0.32, 1.6, 0.08), (-1.1 + k * 0.315, -0.05, 2.62), "bumper_red" if k % 2 else "pad", (0.2, 0, 0)))
    for k in range(4):
        x = -0.8 + k * 0.53
        p += [ball((0.28, 0.28, 0.3), (x, 0.5, 1.82), "alien_green", 6, 4), ball((0.1, 0.06, 0.1), (x - 0.06, 0.37, 1.86), "black", 4, 2),
              ball((0.1, 0.06, 0.1), (x + 0.06, 0.37, 1.86), "black", 4, 2)]
    for k in range(6):
        p.append(ball((0.14, 0.14, 0.14), (-1.0 + k * 0.4, -0.72, 2.4), ["light_red", "light_amber", "light_blue"][k % 3], 5, 3))
    return join("arena_booth", p)


ARENA_BUILDERS = [arena_floor, arena_rim, arena_arch, arena_ferris, arena_tent, arena_bumper_post, arena_lights, arena_rocket_tower,
                  arena_astronaut, arena_tourist, arena_rover, arena_lander, arena_habitat, arena_dish, arena_solar, arena_flag,
                  arena_rock_small, arena_rock_big, arena_gem_pink, arena_gem_blue, arena_gem_green, arena_gem_gold, arena_snack_cart, arena_booth]


def arena_main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()
    os.makedirs(MODELS, exist_ok=True)
    os.makedirs(ART, exist_ok=True)
    only = [n for n in os.environ.get("CE_ONLY", "").split(",") if n]
    x = 0.0
    for build in ARENA_BUILDERS:
        if only and build.__name__ not in only:
            continue
        root = build()
        bpy.ops.object.select_all(action="DESELECT")
        root.select_set(True)
        for child in root.children:
            child.select_set(True)
        bpy.ops.export_scene.gltf(filepath=os.path.join(MODELS, root.name + ".glb"), export_format="GLB",
                                  use_selection=True, export_apply=True, export_yup=True)
        print("built", root.name)
        root.location.x = x
        x += max(root.dimensions.x, 2.0) + 3.0
    if not only:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ART, "arena.blend"))


arena_main()

"""Blender (headless): models authored from code for Slide & Seal, exported as mesh-only .glb.

    blender --background --factory-startup --python tools/blender/build_props.py -- <out_dir>

column.glb  A fluted classical column, 1 unit wide and 4 units tall, origin at the base centre:
            square plinth, torus mouldings, 20-flute shaft with entasis, echinus and abacus capital.
seal_dais.glb  A stepped hexagonal dais (radius 0.46, 0.12 high) with an engraved ring channel,
            origin at the floor centre. It sits inside one cell, so it never reads as a wall.
Both are bevelled for highlights, smooth-shaded with sharp edges kept, and box/cylinder UV mapped
so the game's tiling scanned textures read at real-world scale.
"""
import bpy, bmesh, math, os, sys
from mathutils import Vector

out = sys.argv[sys.argv.index("--") + 1:][0]
os.makedirs(out, exist_ok=True)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def finish(obj, name, bevel=0.0, angle=40):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    if bevel > 0:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(angle)
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.cube_project(cube_size=1.0)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.shade_auto_smooth(angle=math.radians(angle))
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    bpy.ops.export_scene.gltf(filepath=os.path.join(out, name + ".glb"), export_format="GLB",
        export_materials="NONE", export_normals=True, export_texcoords=True, export_yup=True)
    print(f"BUILT {name}: {tris} triangles")


def lathe(bm, profile, segments, flutes=0, flute_depth=0.0, flute_range=None):
    """Revolve (radius, z) profile points around Z. Flutes cut the radius between flute_range z."""
    rings = []
    for r, z in profile:
        ring = []
        for i in range(segments):
            a = 2 * math.pi * i / segments
            rr = r
            if flutes and flute_range and flute_range[0] <= z <= flute_range[1]:
                rr = r * (1.0 - flute_depth * (0.5 + 0.5 * math.cos(a * flutes)) ** 3)
            ring.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), z)))
        rings.append(ring)
    for k in range(len(rings) - 1):
        for i in range(segments):
            j = (i + 1) % segments
            bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])


def box(bm, centre, size):
    res = bmesh.ops.create_cube(bm, size=1.0)
    for v in res["verts"]:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) + Vector(centre)


# --- Column -------------------------------------------------------------------------
reset()
mesh = bpy.data.meshes.new("column")
obj = bpy.data.objects.new("column", mesh)
bpy.context.scene.collection.objects.link(obj)
bm = bmesh.new()
box(bm, (0, 0, 0.09), (1.0, 1.0, 0.18))           # plinth
box(bm, (0, 0, 3.86), (0.98, 0.98, 0.14))          # abacus
profile = [(0.44, 0.18), (0.44, 0.24), (0.47, 0.28), (0.44, 0.33), (0.40, 0.36), (0.38, 0.40)]
shaft_top = 3.55
for k in range(1, 13):
    z = 0.40 + (shaft_top - 0.40) * k / 12
    profile.append((0.38 - 0.05 * (k / 12) ** 1.5, z))  # entasis: gently narrowing
profile += [(0.36, 3.6), (0.40, 3.64), (0.36, 3.68), (0.40, 3.72), (0.47, 3.79)]
lathe(bm, profile, 40, flutes=20, flute_depth=0.08, flute_range=(0.41, 3.54))
bm.to_mesh(mesh)
bm.free()
finish(obj, "column", bevel=0.012, angle=35)

# --- Seal dais ----------------------------------------------------------------------
reset()
mesh = bpy.data.meshes.new("seal_dais")
obj = bpy.data.objects.new("seal_dais", mesh)
bpy.context.scene.collection.objects.link(obj)
bm = bmesh.new()
# Hexagonal tiers: lower 0.46 wide, upper 0.38, with a sunken ring channel cut in the top.
lathe(bm, [(0.46, 0.0), (0.46, 0.05), (0.40, 0.06), (0.38, 0.11), (0.33, 0.12), (0.31, 0.10),
           (0.27, 0.10), (0.25, 0.12), (0.0001, 0.12)], 6)
bm.to_mesh(mesh)
bm.free()
obj.rotation_euler.z = math.radians(30)
bpy.ops.object.select_all(action="DESELECT")
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
bpy.ops.object.transform_apply(rotation=True)
finish(obj, "seal_dais", bevel=0.006, angle=30)

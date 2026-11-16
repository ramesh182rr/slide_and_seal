"""Blender (headless) pipeline: scanned CC0 models (rocks, barrels) -> mobile-ready meshes for Godot.

    blender --background --factory-startup --python tools/blender/process_rocks.py -- <src_dir> <out_dir>

For each model: import glTF, join, apply transforms, centre on the bounding box, scale so the
largest dimension is 2 units, decimate to a triangle budget, smooth-shade, export a mesh-only .glb
(UVs and normals; Godot builds tangents on import). Materials are made in the game from the
model's own scanned textures, so the .glb carries no images.
"""
import bpy, sys, os
from mathutils import Vector

# asset id -> triangle budget
BUDGET = {"boulder_01": 6000, "rock_07": 2500, "rock_09": 2500, "Barrel_01": 3000, "barrel_03": 2000}

args = sys.argv[sys.argv.index("--") + 1:]
src, out = args[0], args[1]
os.makedirs(out, exist_ok=True)

for asset, budget in BUDGET.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(src, asset, f"{asset}_1k.gltf"))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # Centre and normalise.
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    lo = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
    hi = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
    centre = (lo + hi) / 2
    for v in obj.data.vertices:
        v.co -= centre
    scale = 2.0 / max(hi - lo)
    obj.scale = (scale, scale, scale)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    tris_before = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    # glTF stores a separate vertex per UV seam; weld them so the mesh is connected again
    # (UVs live on face corners in Blender, so they survive), then decimate.
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.0005)
    bpy.ops.object.mode_set(mode="OBJECT")
    # Repeat until within budget (one collapse pass can stop short).
    for _ in range(6):
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        if tris <= budget * 1.05:
            break
        mod = obj.modifiers.new("decimate", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = max(0.05, min(1.0, budget / tris))
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.shade_smooth()
    obj.data.materials.clear()
    tris_after = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    bpy.ops.export_scene.gltf(filepath=os.path.join(out, f"{asset}.glb"), export_format="GLB",
        use_selection=False, export_materials="NONE", export_normals=True, export_texcoords=True,
        export_yup=True)
    print(f"PROCESSED {asset}: {tris_before} -> {tris_after} triangles, max dimension 2.0")

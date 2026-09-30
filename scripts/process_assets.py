"""
Workshop Zero - Asset Processing Script (Blender)

Automates the asset bridge pipeline:
Hyper3D/Rodin raw export -> Blender geometry cleanup -> Normalization/Orientation -> Scaling -> Decimation -> Export

Usage:
  blender --background --python scripts/process_assets.py
"""

import bpy
import bmesh
import os
import math
import mathutils

def clean_mesh(obj):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bm = bmesh.from_edit_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0001)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.update_edit_mesh(obj.data)
    bpy.ops.object.mode_set(mode='OBJECT')

def decimate_if_needed(obj, max_tris):
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if tris > max_tris:
        ratio = max_tris / tris
        print(f"  Decimating from {tris} tris to target {max_tris} (ratio {ratio:.4f})")
        mod = obj.modifiers.new(name="Decimate", type='DECIMATE')
        mod.ratio = ratio
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
        new_tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        print(f"  Post-decimate tris: {new_tris}")

def process_asset(cfg):
    name = cfg["name"]
    source_glb = os.path.abspath(cfg["source"])
    blend_out = os.path.abspath(f"assets/source/blender/{name}.blend")
    glb_out = os.path.abspath(f"assets/export/roblox/{name}.glb")
    
    print(f"\n=======================================================")
    print(f"PROCESSING: {name}")
    print(f"Source: {source_glb}")
    
    if not os.path.exists(source_glb):
        print(f"ERROR: {source_glb} does not exist!")
        return

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=source_glb)
    
    mesh_objs = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    if not mesh_objs:
        print("ERROR: No mesh objects found!")
        return

    if len(mesh_objs) > 1:
        bpy.context.view_layer.objects.active = mesh_objs[0]
        for o in mesh_objs:
            o.select_set(True)
        bpy.ops.object.join()
        obj = mesh_objs[0]
    else:
        obj = mesh_objs[0]

    obj.name = name
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)

    clean_mesh(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    if "orient_rot" in cfg:
        rx, ry, rz = cfg["orient_rot"]
        obj.rotation_euler = (math.radians(rx), math.radians(ry), math.radians(rz))
        bpy.ops.object.transform_apply(rotation=True)

    bbox_corners = [mathutils.Vector(c) for c in obj.bound_box]
    center = sum(bbox_corners, mathutils.Vector()) / 8.0
    
    pivot_mode = cfg.get("pivot_mode", "center")
    if pivot_mode == "bottom_center":
        min_z = min(c.z for c in bbox_corners)
        offset = mathutils.Vector((center.x, center.y, min_z))
    else:
        offset = center

    for v in obj.data.vertices:
        v.co -= offset

    obj.data.update()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    dim = obj.dimensions
    print(f"  Pre-scale dimensions: X={dim.x:.3f}, Y={dim.y:.3f}, Z={dim.z:.3f}")

    target_dim = cfg["target_dim"]
    sx = target_dim[0] / dim.x if dim.x > 0 else 1.0
    sy = target_dim[1] / dim.y if dim.y > 0 else 1.0
    sz = target_dim[2] / dim.z if dim.z > 0 else 1.0

    if cfg.get("uniform_scale", False):
        s = min(sx, sy, sz)
        obj.scale = (s, s, s)
    else:
        obj.scale = (sx, sy, sz)

    bpy.ops.object.transform_apply(scale=True)
    dim = obj.dimensions
    print(f"  Post-scale dimensions: X={dim.x:.3f}, Y={dim.y:.3f}, Z={dim.z:.3f}")

    max_tris = cfg.get("max_tris", 12000)
    decimate_if_needed(obj, max_tris)

    clean_mesh(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    os.makedirs(os.path.dirname(blend_out), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=blend_out)
    print(f"  Saved blend: {blend_out}")

    os.makedirs(os.path.dirname(glb_out), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=glb_out,
        export_format='GLB',
        use_selection=True,
        export_apply=True,
        export_yup=True
    )
    print(f"  Exported glb: {glb_out} ({os.path.getsize(glb_out)} bytes)")

configs = [
    {
        "name": "motor_electric_01",
        "source": "assets/source/hyper3d/motor_electric_01/base_basic_pbr.glb",
        "orient_rot": (90, 0, -90),
        "target_dim": (2.0, 2.0, 2.0),
        "pivot_mode": "center",
        "max_tris": 3500,
    },
    {
        "name": "wheel_rubber_01",
        "source": "assets/source/hyper3d/wheel_rubber_01/base_basic_pbr.glb",
        "orient_rot": (0, 0, 90),
        "target_dim": (0.4, 2.4, 2.4),
        "pivot_mode": "center",
        "max_tris": 3000,
    },
    {
        "name": "plank_beam_01",
        "source": "assets/source/hyper3d/plank_beam_01/base_basic_pbr.glb",
        "orient_rot": (0, 0, 0),
        "target_dim": (8.0, 0.6, 2.0),
        "pivot_mode": "center",
        "max_tris": 2500,
    },
    {
        "name": "block_cube_01",
        "source": "assets/source/hyper3d/block_cube_01/base_basic_pbr.glb",
        "orient_rot": (0, 0, 0),
        "target_dim": (2.0, 2.0, 2.0),
        "pivot_mode": "center",
        "max_tris": 2000,
    },
    {
        "name": "workbench_maker_01",
        "source": "assets/source/hyper3d/workbench_maker_01/base_basic_pbr.glb",
        "orient_rot": (0, 0, 0),
        "target_dim": (12.0, 3.5, 5.0),
        "pivot_mode": "bottom_center",
        "max_tris": 12000,
    },
    {
        "name": "rack_tool_01",
        "source": "assets/source/hyper3d/rack_tool_01/base_basic_pbr.glb",
        "orient_rot": (0, 0, 0),
        "target_dim": (10.0, 4.0, 4.0),
        "pivot_mode": "bottom_center",
        "max_tris": 10000,
    },
    {
        "name": "wall_panel_01",
        "source": "assets/source/hyper3d/wall_panel_01/base_basic_pbr.glb",
        "orient_rot": (90, 0, 0),
        "target_dim": (8.0, 12.0, 1.0),
        "pivot_mode": "bottom_center",
        "max_tris": 8000,
    },
]

if __name__ == "__main__":
    for cfg in configs:
        process_asset(cfg)
    print("\nAll assets processed successfully!")

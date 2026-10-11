import bpy
import mathutils

print("OBJECTS:", [(o.name, o.type) for o in bpy.data.objects])

mins = [1e9, 1e9, 1e9]
maxs = [-1e9, -1e9, -1e9]
for o in bpy.data.objects:
    if o.type == 'MESH':
        for v in o.bound_box:
            w = o.matrix_world @ mathutils.Vector(v)
            for i in range(3):
                mins[i] = min(mins[i], w[i])
                maxs[i] = max(maxs[i], w[i])
print("NBOUNDS", mins, maxs)
print("SIZE", [maxs[i] - mins[i] for i in range(3)])

bpy.ops.export_scene.gltf(
    filepath=r"C:\Users\ADMIN\Documents\LUIS\PROGRAMACION\videojuego\tracks\pista_1.glb",
    export_format='GLB',
)
print("EXPORTED_OK")

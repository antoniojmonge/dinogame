import bpy
import math

c = bpy.data.objects["NurbsPath"]
pts = [(p.co[0], p.co[1]) for p in c.data.splines[0].points]

# drop last if nearly equal to first (closed loop)
if math.dist(pts[0], pts[-1]) < 0.4:
    pts = pts[:-1]

# translate so p0 at origin, rotate so initial direction -> (0,-1) in Godot (x,z)
x0, y0 = pts[0]
rel = [(x - x0, y - y0) for (x, y) in pts]
dx, dy = rel[1]
ang = -math.pi / 2.0 - math.atan2(dy, dx)
ca, sa = math.cos(ang), math.sin(ang)

scale = 4.5
out = []
for (x, y) in rel:
    # map blender (x,y) -> godot (x, z); rotate; scale
    rx = x * ca - y * sa
    rz = x * sa + y * ca
    out.append((round(rx * scale, 2), round(rz * scale, 2)))

print("GODOT_POINTS", out)

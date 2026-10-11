extends Node3D

## Genera una pista cerrada en forma de cinta siguiendo una curva suave,
## con bordillos, marcas de carril, colision, obstaculos y decoracion.

@export var road_width := 11.0
@export var road_thickness := 1.0
@export var curb_width := 1.0
@export var lane_width := 0.35
@export var samples := 480
@export var build_scenery := true
@export var build_obstacles := true
@export var obstacle_count := 14
@export var tree_count := 260
@export var rock_count := 80

const ROAD_COLOR := Color(0.15, 0.15, 0.17)
const CURB_COLOR := Color(0.9, 0.9, 0.92)
const LANE_COLOR := Color(0.85, 0.75, 0.2)

var _curve: Curve3D


func _ready() -> void:
	_curve = _make_curve(_control_points())
	_build_road()
	if build_obstacles:
		_build_obstacles()
	if build_scenery:
		_build_scenery()


func _control_points() -> Array:
	return [
		Vector3(0, 0, 0),
		Vector3(0, 1.0, -60),
		Vector3(18, 3.0, -110),
		Vector3(60, 6.0, -140),
		Vector3(110, 7.0, -115),
		Vector3(130, 6.0, -65),
		Vector3(120, 6.0, -15),
		Vector3(85, 5.0, 30),
		Vector3(40, 3.0, 50),
		Vector3(0, 1.0, 45),
	]


func _make_curve(pts: Array) -> Curve3D:
	var n := pts.size()
	var c := Curve3D.new()
	for i in n:
		var prev: Vector3 = pts[(i - 1 + n) % n]
		var nxt: Vector3 = pts[(i + 1) % n]
		c.add_point(pts[i], (prev - nxt) / 6.0, (nxt - prev) / 6.0)
	c.add_point(pts[0], (pts[n - 1] - pts[1]) / 6.0, (pts[1] - pts[n - 1]) / 6.0)
	return c


func _build_road() -> void:
	var total := _curve.get_baked_length()
	var half := road_width * 0.5
	var cw := curb_width
	var lw := lane_width

	# Limites de cada franja de la seccion transversal
	var xs := [-half, -half + cw, -lw, lw, half - cw, half]
	# Color (izquierda, derecha) de cada franja
	var qcolors := [
		[CURB_COLOR, ROAD_COLOR],
		[ROAD_COLOR, ROAD_COLOR],
		[LANE_COLOR, LANE_COLOR],
		[ROAD_COLOR, ROAD_COLOR],
		[ROAD_COLOR, CURB_COLOR],
	]

	var rings := []
	var ups := []
	for i in samples:
		var off := (float(i) / samples) * total
		var xf := _curve.sample_baked_with_rotation(off, true, true)
		var right := xf.basis.x.normalized()
		var up := xf.basis.y.normalized()
		var ring := []
		for k in xs.size():
			ring.append(xf.origin + right * xs[k])
		rings.append(ring)
		ups.append(up)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in samples:
		var a: Array = rings[i]
		var b: Array = rings[(i + 1) % samples]
		var ua: Vector3 = ups[i]
		var ub: Vector3 = ups[(i + 1) % samples]
		for k in qcolors.size():
			var cl: Color = qcolors[k][0]
			var cr: Color = qcolors[k][1]
			st.set_normal(ua)
			st.set_color(cl)
			st.set_uv(Vector2(0, 0))
			st.add_vertex(a[k])
			st.set_normal(ua)
			st.set_color(cr)
			st.set_uv(Vector2(1, 0))
			st.add_vertex(a[k + 1])
			st.set_normal(ub)
			st.set_color(cr)
			st.set_uv(Vector2(1, 1))
			st.add_vertex(b[k + 1])

			st.set_normal(ua)
			st.set_color(cl)
			st.set_uv(Vector2(0, 0))
			st.add_vertex(a[k])
			st.set_normal(ub)
			st.set_color(cr)
			st.set_uv(Vector2(1, 1))
			st.add_vertex(b[k + 1])
			st.set_normal(ub)
			st.set_color(cl)
			st.set_uv(Vector2(0, 1))
			st.add_vertex(b[k])

	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "Road"
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.9
	mi.material_override = mat
	add_child(mi)
	mi.create_trimesh_collision()
	for child in mi.get_children():
		if child is StaticBody3D:
			child.collision_layer = 1
			for cshape in child.get_children():
				if cshape is CollisionShape3D and cshape.shape is ConcavePolygonShape3D:
					cshape.shape.backface_collision = true


func _build_obstacles() -> void:
	var scene: PackedScene = load("res://scenes/obstacle.tscn")
	if scene == null:
		return
	var total := _curve.get_baked_length()
	for i in obstacle_count:
		var t := float(i + 1) / float(obstacle_count + 1)
		var off := t * total
		var xf := _curve.sample_baked_with_rotation(off, true, true)
		var right := xf.basis.x.normalized()
		var side := -1.0 if i % 2 == 0 else 1.0
		var pos := xf.origin + right * side * (road_width * 0.26)
		var obs: Node3D = scene.instantiate()
		add_child(obs)
		obs.scale = Vector3(0.7, 0.7, 0.7)
		obs.global_position = pos + Vector3(0, 0.7, 0)
		obs.rotate_y(float(i) * 0.7)


func _build_scenery() -> void:
	var pts := []
	var total := _curve.get_baked_length()
	for i in 240:
		pts.append(_curve.sample_baked((float(i) / 240.0) * total, true))

	var rng := RandomNumberGenerator.new()
	rng.seed = 20240411

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.28
	trunk_mesh.bottom_radius = 0.5
	trunk_mesh.height = 3.2
	trunk_mesh.radial_segments = 6
	var leaf_mesh := SphereMesh.new()
	leaf_mesh.radius = 2.2
	leaf_mesh.height = 4.4
	leaf_mesh.radial_segments = 8
	leaf_mesh.rings = 4

	var trunk_mm := MultiMesh.new()
	trunk_mm.transform_format = MultiMesh.TRANSFORM_3D
	trunk_mm.mesh = trunk_mesh
	var leaf_mm := MultiMesh.new()
	leaf_mm.transform_format = MultiMesh.TRANSFORM_3D
	leaf_mm.mesh = leaf_mesh

	var places := _scatter(rng, pts, tree_count, 15.0, Vector3(-260, 0, -220), Vector3(300, 0, 160))
	trunk_mm.instance_count = places.size()
	leaf_mm.instance_count = places.size()
	for i in places.size():
		var p: Vector3 = places[i]
		var s := rng.randf_range(0.8, 1.9)
		var b := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(s, s, s))
		trunk_mm.set_instance_transform(i, Transform3D(b, p + Vector3(0, 1.6 * s, 0)))
		leaf_mm.set_instance_transform(i, Transform3D(b, p + Vector3(0, 4.4 * s, 0)))

	var trunk_inst := MultiMeshInstance3D.new()
	trunk_inst.name = "TreeTrunks"
	trunk_inst.multimesh = trunk_mm
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.35, 0.24, 0.14)
	trunk_inst.material_override = trunk_mat
	add_child(trunk_inst)

	var leaf_inst := MultiMeshInstance3D.new()
	leaf_inst.name = "TreeLeaves"
	leaf_inst.multimesh = leaf_mm
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.16, 0.42, 0.18)
	leaf_inst.material_override = leaf_mat
	add_child(leaf_inst)

	var rock_mm := MultiMesh.new()
	rock_mm.transform_format = MultiMesh.TRANSFORM_3D
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 1.0
	rock_mesh.height = 1.4
	rock_mesh.radial_segments = 6
	rock_mesh.rings = 3
	rock_mm.mesh = rock_mesh
	var rock_places := _scatter(rng, pts, rock_count, 13.0, Vector3(-260, 0, -220), Vector3(300, 0, 160))
	rock_mm.instance_count = rock_places.size()
	for i in rock_places.size():
		var p: Vector3 = rock_places[i]
		var s := rng.randf_range(0.6, 2.4)
		var b := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(s, s * 0.7, s))
		rock_mm.set_instance_transform(i, Transform3D(b, p + Vector3(0, 0.4 * s, 0)))
	var rock_inst := MultiMeshInstance3D.new()
	rock_inst.name = "Rocks"
	rock_inst.multimesh = rock_mm
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.42, 0.42, 0.45)
	rock_inst.material_override = rock_mat
	add_child(rock_inst)

	_build_hills(rng)


func _scatter(rng: RandomNumberGenerator, track_pts: Array, count: int, min_dist: float, min_p: Vector3, max_p: Vector3) -> Array:
	var out := []
	var attempts := 0
	while out.size() < count and attempts < count * 50:
		attempts += 1
		var p := Vector3(rng.randf_range(min_p.x, max_p.x), 0.0, rng.randf_range(min_p.z, max_p.z))
		if _distance_to_track(p, track_pts) < min_dist:
			continue
		out.append(p)
	return out


func _distance_to_track(p: Vector3, track_pts: Array) -> float:
	var best := INF
	for q in track_pts:
		var d := Vector2(p.x - q.x, p.z - q.z).length()
		if d < best:
			best = d
	return best


func _build_hills(rng: RandomNumberGenerator) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = 14
	for i in 14:
		var angle := (float(i) / 14.0) * TAU + rng.randf_range(-0.1, 0.1)
		var dist := rng.randf_range(330.0, 430.0)
		var p := Vector3(cos(angle) * dist + 60.0, -rng.randf_range(20.0, 40.0), sin(angle) * dist - 60.0)
		var r := rng.randf_range(70.0, 130.0)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(r, r * 0.8, r)), p))
	var inst := MultiMeshInstance3D.new()
	inst.name = "Hills"
	inst.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.33, 0.22)
	inst.material_override = mat
	add_child(inst)

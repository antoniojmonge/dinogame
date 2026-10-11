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
@export var item_box_count := 8
@export var bank_strength := 12.0
@export var max_bank := 0.4
@export var tree_count := 260
@export var rock_count := 80

const ROAD_COLOR := Color(1.0, 1.0, 1.0)
const CURB_COLOR := Color(0.8, 0.72, 0.57)
const LANE_COLOR := Color(1.0, 0.93, 0.7)
const LOOP_OFFSET := 14.0
const LOOP_RADIUS := 4.5
const LOOP_DRIFT := 28.3

var _curve: Curve3D
var _path := PackedVector3Array()
var _terrain_noise: FastNoiseLite


func _ready() -> void:
	add_to_group("track")
	_curve = _make_curve(_control_points())
	_build_path()
	_build_base_floor()
	_build_terrain()
	_build_road()
	_build_loop()
	_build_barriers()
	_build_finish_line()
	if build_obstacles:
		_build_obstacles()
	_build_item_boxes()
	_build_rivals()
	if build_scenery:
		_build_scenery()
	_build_edge_decor()


func _build_path() -> void:
	var total := _curve.get_baked_length()
	var n := 220
	for i in n:
		_path.append(_curve.sample_baked((float(i) / float(n)) * total, true))


func path_points() -> PackedVector3Array:
	return _path


func half_width() -> float:
	return road_width * 0.5


func _build_rivals() -> void:
	var scene: PackedScene = load("res://scenes/rival.tscn")
	if scene == null:
		return
	var placements := [[1.0, -2.5], [1.0, 2.5], [3.0, 0.0]]
	for i in placements.size():
		var pl: Array = placements[i]
		var off: float = pl[0]
		var lat: float = pl[1]
		var xf := _curve.sample_baked_with_rotation(off, true, true)
		var rival: Node3D = scene.instantiate()
		rival.name = "Rival%d" % (i + 1)
		add_child(rival)
		var pos := xf.origin + xf.basis.x.normalized() * lat
		rival.global_transform = Transform3D(xf.basis.orthonormalized(), pos)


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

	var origins := []
	var rights := []
	var ups := []
	var headings := []
	for i in samples:
		var off := (float(i) / samples) * total
		var xf := _curve.sample_baked_with_rotation(off, true, true)
		origins.append(xf.origin)
		rights.append(xf.basis.x.normalized())
		ups.append(xf.basis.y.normalized())
		var f := xf.basis.z.normalized()
		headings.append(atan2(f.x, f.z))

	var banks := []
	for i in samples:
		var prev: float = headings[(i - 1 + samples) % samples]
		var nxt: float = headings[(i + 1) % samples]
		var d := wrapf(nxt - prev, -PI, PI)
		banks.append(clampf(d * bank_strength, -max_bank, max_bank))

	var rings := []
	var ring_ups := []
	for i in samples:
		var r: Vector3 = rights[i]
		var u: Vector3 = ups[i]
		var f: Vector3 = (origins[(i + 1) % samples] - origins[(i - 1 + samples) % samples])
		if banks[i] != 0.0 and f.length_squared() > 0.0001:
			var rot := Basis(f.normalized(), banks[i])
			r = (rot * r).normalized()
			u = (rot * u).normalized()
		var ring := []
		for k in xs.size():
			ring.append(origins[i] + r * xs[k])
		rings.append(ring)
		ring_ups.append(u)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in samples:
		var a: Array = rings[i]
		var b: Array = rings[(i + 1) % samples]
		var ua: Vector3 = ring_ups[i]
		var ub: Vector3 = ring_ups[(i + 1) % samples]
		var off_i := (float(i) / float(samples)) * total
		if off_i >= LOOP_OFFSET - 0.2 and off_i <= LOOP_OFFSET + LOOP_DRIFT + 0.2:
			continue
		for k in qcolors.size():
			var cl: Color = qcolors[k][0]
			var cr: Color = qcolors[k][1]
			st.set_normal(ua)
			st.set_color(cl)
			st.set_uv(Vector2(0, 0))
			st.add_vertex(a[k])
			st.set_normal(ub)
			st.set_color(cr)
			st.set_uv(Vector2(1, 1))
			st.add_vertex(b[k + 1])
			st.set_normal(ua)
			st.set_color(cr)
			st.set_uv(Vector2(1, 0))
			st.add_vertex(a[k + 1])

			st.set_normal(ua)
			st.set_color(cl)
			st.set_uv(Vector2(0, 0))
			st.add_vertex(a[k])
			st.set_normal(ub)
			st.set_color(cl)
			st.set_uv(Vector2(0, 1))
			st.add_vertex(b[k])
			st.set_normal(ub)
			st.set_color(cr)
			st.set_uv(Vector2(1, 1))
			st.add_vertex(b[k + 1])

	# Faldon lateral: da grosor a la pista (no flota)
	var skirt_depth := 2.6
	var edge_col := Color(0.34, 0.26, 0.17)
	var edge_cols := [0, xs.size() - 1]
	for i in samples:
		var a: Array = rings[i]
		var b: Array = rings[(i + 1) % samples]
		var ua: Vector3 = ring_ups[i]
		var ub: Vector3 = ring_ups[(i + 1) % samples]
		var rn: Vector3 = rights[i].normalized()
		for col in edge_cols:
			var n: Vector3 = rn if col == xs.size() - 1 else -rn
			var a_top: Vector3 = a[col]
			var b_top: Vector3 = b[col]
			var a_bot: Vector3 = a_top - ua * skirt_depth
			var b_bot: Vector3 = b_top - ub * skirt_depth
			st.set_normal(n)
			st.set_color(edge_col)
			st.set_uv(Vector2(0, 0))
			st.add_vertex(a_top)
			st.set_normal(n)
			st.set_color(edge_col)
			st.set_uv(Vector2(1, 0))
			st.add_vertex(a_bot)
			st.set_normal(n)
			st.set_color(edge_col)
			st.set_uv(Vector2(1, 1))
			st.add_vertex(b_bot)
			st.set_normal(n)
			st.set_color(edge_col)
			st.set_uv(Vector2(0, 0))
			st.add_vertex(a_top)
			st.set_normal(n)
			st.set_color(edge_col)
			st.set_uv(Vector2(1, 1))
			st.add_vertex(b_bot)
			st.set_normal(n)
			st.set_color(edge_col)
			st.set_uv(Vector2(0, 1))
			st.add_vertex(b_top)

	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "Road"
	mi.mesh = mesh
	mi.material_override = _make_road_material()
	add_child(mi)
	mi.create_trimesh_collision()
	for child in mi.get_children():
		if child is StaticBody3D:
			child.collision_layer = 1
			for cshape in child.get_children():
				if cshape is CollisionShape3D and cshape.shape is ConcavePolygonShape3D:
					cshape.shape.backface_collision = false


func _build_loop() -> void:
	var xf := _curve.sample_baked_with_rotation(LOOP_OFFSET, true, true)
	var P := xf.origin
	var f := -xf.basis.z
	f.y = 0.0
	if f.length_squared() < 0.0001:
		f = Vector3.FORWARD
	f = f.normalized()
	var u := Vector3.UP
	var C := P + u * LOOP_RADIUS
	var half := road_width * 0.5
	var steps := 72
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_n := Vector3.UP
	for i in steps + 1:
		var t := float(i) / float(steps)
		var th := t * TAU
		var pos := C + f * (LOOP_RADIUS * sin(th) + LOOP_DRIFT * t) + u * (-LOOP_RADIUS * cos(th))
		var tangent := (f * (LOOP_RADIUS * cos(th) + LOOP_DRIFT / TAU) + u * (LOOP_RADIUS * sin(th))).normalized()
		var up := (u * cos(th) - f * sin(th)).normalized()
		var right := tangent.cross(up).normalized()
		var l := pos - right * half
		var r := pos + right * half
		if i > 0:
			var v0 := float(i - 1) / float(steps)
			var v1 := t
			st.set_normal(prev_n)
			st.set_color(ROAD_COLOR)
			st.set_uv(Vector2(0, v0 * 14.0))
			st.add_vertex(prev_l)
			st.set_normal(prev_n)
			st.set_color(ROAD_COLOR)
			st.set_uv(Vector2(1, v0 * 14.0))
			st.add_vertex(prev_r)
			st.set_normal(up)
			st.set_color(ROAD_COLOR)
			st.set_uv(Vector2(1, v1 * 14.0))
			st.add_vertex(r)
			st.set_normal(prev_n)
			st.set_color(ROAD_COLOR)
			st.set_uv(Vector2(0, v0 * 14.0))
			st.add_vertex(prev_l)
			st.set_normal(up)
			st.set_color(ROAD_COLOR)
			st.set_uv(Vector2(1, v1 * 14.0))
			st.add_vertex(r)
			st.set_normal(up)
			st.set_color(ROAD_COLOR)
			st.set_uv(Vector2(0, v1 * 14.0))
			st.add_vertex(l)
		prev_l = l
		prev_r = r
		prev_n = up
	var mi := MeshInstance3D.new()
	mi.name = "Loop"
	mi.mesh = st.commit()
	mi.material_override = _make_road_material()
	add_child(mi)
	mi.create_trimesh_collision()
	for child in mi.get_children():
		if child is StaticBody3D:
			child.collision_layer = 1
			for cshape in child.get_children():
				if cshape is CollisionShape3D and cshape.shape is ConcavePolygonShape3D:
					cshape.shape.backface_collision = true


func _build_finish_line() -> void:
	var scene: PackedScene = load("res://scenes/finish_line.tscn")
	if scene == null:
		return
	var xf := _curve.sample_baked_with_rotation(6.0, true, true)
	var fl: Node3D = scene.instantiate()
	add_child(fl)
	fl.global_transform = Transform3D(xf.basis.orthonormalized(), xf.origin)


func _build_obstacles() -> void:
	var scene: PackedScene = load("res://scenes/hazard.tscn")
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
		obs.global_position = pos


func _build_item_boxes() -> void:
	var scene: PackedScene = load("res://scenes/item_box.tscn")
	if scene == null:
		return
	var total := _curve.get_baked_length()
	for i in item_box_count:
		var t := (float(i) + 0.5) / float(item_box_count)
		var xf := _curve.sample_baked_with_rotation(t * total, true, true)
		var box: Node3D = scene.instantiate()
		add_child(box)
		box.global_position = xf.origin + Vector3(0, 1.4, 0)


func _build_terrain() -> void:
	var cells := 120
	var size := 600.0
	var cx := 60.0
	var cz := -50.0
	var step := size / float(cells)
	_terrain_noise = FastNoiseLite.new()
	_terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_terrain_noise.frequency = 0.012
	_terrain_noise.fractal_octaves = 4
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid := []
	for iz in cells + 1:
		var row := []
		for ix in cells + 1:
			var x := cx - size * 0.5 + ix * step
			var z := cz - size * 0.5 + iz * step
			var h := _terrain_height(x, z)
			row.append(Vector3(x, h, z))
		grid.append(row)
	for iz in cells:
		for ix in cells:
			var p00: Vector3 = grid[iz][ix]
			var p10: Vector3 = grid[iz][ix + 1]
			var p01: Vector3 = grid[iz + 1][ix]
			var p11: Vector3 = grid[iz + 1][ix + 1]
			st.set_uv(Vector2(p00.x, p00.z) * 0.12)
			st.add_vertex(p00)
			st.set_uv(Vector2(p01.x, p01.z) * 0.12)
			st.add_vertex(p01)
			st.set_uv(Vector2(p11.x, p11.z) * 0.12)
			st.add_vertex(p11)
			st.set_uv(Vector2(p00.x, p00.z) * 0.12)
			st.add_vertex(p00)
			st.set_uv(Vector2(p11.x, p11.z) * 0.12)
			st.add_vertex(p11)
			st.set_uv(Vector2(p10.x, p10.z) * 0.12)
			st.add_vertex(p10)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = st.commit()
	mi.material_override = _make_terrain_material()
	add_child(mi)
	mi.create_trimesh_collision()
	for child in mi.get_children():
		if child is StaticBody3D:
			child.collision_layer = 1
			for cshape in child.get_children():
				if cshape is CollisionShape3D and cshape.shape is ConcavePolygonShape3D:
					cshape.shape.backface_collision = false


func _terrain_height(x: float, z: float) -> float:
	var best_d := INF
	var best_h := 0.0
	for i in _path.size():
		var p: Vector3 = _path[i]
		var d := Vector2(x - p.x, z - p.z).length()
		if d < best_d:
			best_d = d
			best_h = p.y
	var edge := road_width * 0.5
	# El terreno sigue la altura de la pista y solo se ondula lejos de ella.
	var t := clampf((best_d - edge) / 55.0, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	var n := _terrain_noise.get_noise_2d(x, z)
	var h := best_h - 0.4 + n * 7.0 * t
	# Terraplenes/cerros laterales que sostienen visualmente el camino.
	var b := sin(clampf((best_d - edge) / 22.0, 0.0, 1.0) * PI)
	h += b * 2.0 * (1.0 - t)
	return h


func _build_base_floor() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3000, 3000)
	mi.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.42, 0.2)
	mi.material_override = mat
	mi.position = Vector3(60, -6, -50)
	add_child(mi)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3000, 2, 3000)
	cs.shape = shape
	body.add_child(cs)
	body.position = Vector3(60, -7, -50)
	add_child(body)


func _make_terrain_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://textures/aerial_grass_rock_diff.jpg")
	mat.albedo_color = Color(0.85, 0.95, 0.8)
	mat.roughness = 1.0
	return mat


func _build_barriers() -> void:
	var total := _curve.get_baked_length()
	var n := 110
	var half := road_width * 0.5
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.5, 5.0, 8.0)
	var body := StaticBody3D.new()
	body.name = "Barriers"
	body.collision_layer = 1
	add_child(body)
	for i in n:
		var off := ((float(i) + 0.5) / float(n)) * total
		var xf := _curve.sample_baked_with_rotation(off, true, true)
		var right := xf.basis.x.normalized()
		for side in [-1.0, 1.0]:
			var sf: float = side
			var pos := xf.origin + right * sf * (half + 0.2) + Vector3.UP * 2.1
			var cs := CollisionShape3D.new()
			cs.shape = shape
			cs.transform = Transform3D(xf.basis.orthonormalized(), pos)
			body.add_child(cs)


func _make_road_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://textures/brown_mud_leaves_01_diff.jpg")
	mat.albedo_color = Color(0.95, 0.9, 0.85)
	mat.roughness = 1.0
	mat.roughness_texture = load("res://textures/brown_mud_leaves_01_rough.jpg")
	mat.normal_enabled = true
	mat.normal_texture = load("res://textures/brown_mud_leaves_01_nor_gl.jpg")
	mat.normal_scale = 1.0
	mat.uv1_scale = Vector3(2.0, 0.2, 1.0)
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _build_edge_decor() -> void:
	var total := _curve.get_baked_length()
	var count := 26
	var half := road_width * 0.5

	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.14
	post_mesh.bottom_radius = 0.17
	post_mesh.height = 1.6
	post_mesh.radial_segments = 6
	var rope_mesh := CylinderMesh.new()
	rope_mesh.top_radius = 0.05
	rope_mesh.bottom_radius = 0.05
	rope_mesh.height = 1.0
	rope_mesh.radial_segments = 5
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 1.0
	rock_mesh.height = 1.7
	rock_mesh.radial_segments = 8
	rock_mesh.rings = 4

	var post_mm := MultiMesh.new()
	post_mm.transform_format = MultiMesh.TRANSFORM_3D
	post_mm.mesh = post_mesh
	var rope_mm := MultiMesh.new()
	rope_mm.transform_format = MultiMesh.TRANSFORM_3D
	rope_mm.mesh = rope_mesh
	var rock_mm := MultiMesh.new()
	rock_mm.transform_format = MultiMesh.TRANSFORM_3D
	rock_mm.mesh = rock_mesh

	var rng := RandomNumberGenerator.new()
	rng.seed = 4242

	var left_tops := []
	var right_tops := []
	var rock_tfs := []
	for i in count:
		var t := (float(i) + 0.5) / float(count)
		var xf := _curve.sample_baked_with_rotation(t * total, true, true)
		var right := xf.basis.x.normalized()
		for side in [-1.0, 1.0]:
			var sf: float = side
			var base: Vector3 = xf.origin + right * sf * (half + 0.7)
			base.y = _terrain_height(base.x, base.z)
			var top: Vector3 = base + Vector3.UP * 1.6
			if sf < 0.0:
				left_tops.append(top)
			else:
				right_tops.append(top)
			if rng.randf() < 0.6:
				var s := rng.randf_range(1.0, 2.4)
				var off: float = (half + 1.9 + rng.randf_range(0.0, 2.5)) * sf
				var rpos: Vector3 = xf.origin + right * off
				rpos.y = _terrain_height(rpos.x, rpos.z) + s * 0.45
				rock_tfs.append(Transform3D(Basis().scaled(Vector3(s, s * 0.8, s)), rpos))

	var post_tfs := []
	var rope_tfs := []
	for tops in [left_tops, right_tops]:
		var arr: Array = tops
		for i in arr.size():
			var top: Vector3 = arr[i]
			post_tfs.append(Transform3D(Basis(), top - Vector3(0, 0.8, 0)))
			if i > 0:
				rope_tfs.append(_rope_transform(arr[i - 1], top))

	_fill_multimesh(post_mm, post_tfs)
	rope_mm.instance_count = 0
	_fill_multimesh(rock_mm, rock_tfs)

	var post_inst := MultiMeshInstance3D.new()
	post_inst.name = "Posts"
	post_inst.multimesh = post_mm
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.34, 0.24, 0.14)
	post_inst.material_override = post_mat
	add_child(post_inst)

	var rope_inst := MultiMeshInstance3D.new()
	rope_inst.name = "Ropes"
	rope_inst.multimesh = rope_mm
	var rope_mat := StandardMaterial3D.new()
	rope_mat.albedo_color = Color(0.5, 0.4, 0.26)
	rope_inst.material_override = rope_mat
	add_child(rope_inst)

	var rock_inst := MultiMeshInstance3D.new()
	rock_inst.name = "EdgeRocks"
	rock_inst.multimesh = rock_mm
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.46, 0.42, 0.37)
	rock_mat.roughness = 1.0
	rock_inst.material_override = rock_mat
	add_child(rock_inst)


func _fill_multimesh(mm: MultiMesh, tfs: Array) -> void:
	mm.instance_count = tfs.size()
	for i in tfs.size():
		mm.set_instance_transform(i, tfs[i])


func _rope_transform(a: Vector3, b: Vector3) -> Transform3D:
	var mid := (a + b) * 0.5
	var d := b - a
	var len := d.length()
	if len < 0.001:
		return Transform3D()
	var y := d / len
	var x := Vector3.UP.cross(y)
	if x.length() < 0.001:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	var basis := Basis(x, y, z).scaled(Vector3(1.0, len, 1.0))
	return Transform3D(basis, mid)


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
		var x := rng.randf_range(min_p.x, max_p.x)
		var z := rng.randf_range(min_p.z, max_p.z)
		var p := Vector3(x, _terrain_height(x, z), z)
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

extends CharacterBody3D

## Controlador estilo Sonic/CTR: corre solo, gira, salta y DERRAPA para
## cargar un turbo. La camara va en un SpringArm3D (evita atravesar geometria).

@export var max_speed := 22.0
@export var acceleration := 25.0
@export var steering_speed := 2.4
@export var jump_velocity := 13.0
@export var gravity := 32.0
@export var align_speed := 18.0
@export var outline_enabled := true
@export var rim_enabled := true

@export_group("Derrape / Turbo")
@export var drift_steer_mult := 1.9
@export var drift_min_speed := 8.0
@export var drift_charge_levels: Array[float] = [0.6, 1.5, 2.5]
@export var boost_multipliers: Array[float] = [1.35, 1.6, 1.9]
@export var boost_duration := 1.2

@onready var anim: AnimationPlayer = $Model/AnimationPlayer
@onready var camera_rig: SpringArm3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D

const ANIM_IDLE := "Armature|TRex_Idle"
const ANIM_WALK := "Armature|TRex_Walk"
const ANIM_RUN := "Armature|TRex_Run"
const ANIM_JUMP := "Armature|TRex_Jump"

const CAM_BASE_LENGTH := 6.0
const CAM_BOOST_LENGTH := 8.5

var speed := 0.0
var up_dir := Vector3.UP
var _vertical := 0.0
var _air_time := 0.0

var _drifting := false
var _drift_charge := 0.0
var _drift_level := 0
var _boost_timer := 0.0
var _boost_mult := 1.0
var _dino_mats: Array[StandardMaterial3D] = []


func _ready() -> void:
	add_to_group("player")
	_setup_animations()
	_apply_materials()
	up_direction = up_dir
	floor_max_angle = deg_to_rad(85.0)


func _setup_animations() -> void:
	if anim == null:
		return
	for name in [ANIM_IDLE, ANIM_WALK, ANIM_RUN]:
		if anim.has_animation(name):
			anim.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	_play(ANIM_RUN, true)


func _apply_materials() -> void:
	var outline := StandardMaterial3D.new()
	outline.albedo_color = Color(0.05, 0.05, 0.07)
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.grow = true
	outline.grow_amount = 2.0
	for mi in _all_meshes($Model):
		for s in mi.mesh.get_surface_count():
			var m: Material = mi.get_active_material(s)
			if m == null:
				m = mi.mesh.surface_get_material(s)
			if m is StandardMaterial3D:
				var mat: StandardMaterial3D = m
				if outline_enabled:
					mat.next_pass = outline
				if rim_enabled:
					mat.rim_enabled = true
					mat.rim = 0.5
					mat.rim_tint = 0.3
				_dino_mats.append(mat)


func _all_meshes(n: Node) -> Array:
	var out := []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_all_meshes(c))
	return out


func apply_obstacle_hit(slowdown: float, bounce: float) -> void:
	speed = maxf(0.0, speed * slowdown)
	_vertical = maxf(_vertical, bounce)


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return

	var on_floor := is_on_floor()

	if on_floor:
		up_dir = up_dir.slerp(get_floor_normal(), clampf(align_speed * delta, 0.0, 1.0)).normalized()
		_air_time = 0.0
	else:
		up_dir = up_dir.slerp(Vector3.UP, clampf(1.5 * delta, 0.0, 1.0)).normalized()
		_air_time += delta
	up_direction = up_dir

	var turn := Input.get_axis("move_left", "move_right")
	_update_drift(delta, turn, on_floor)

	var steer_amount := turn * steering_speed
	if _drifting:
		steer_amount *= drift_steer_mult
	if steer_amount != 0.0:
		transform.basis = (Basis(up_dir, -steer_amount * delta) * transform.basis).orthonormalized()

	var fwd := -transform.basis.z
	fwd = fwd - up_dir * fwd.dot(up_dir)
	if fwd.length_squared() < 0.0001:
		fwd = up_dir.cross(Vector3.RIGHT)
		if fwd.length_squared() < 0.0001:
			fwd = Vector3.FORWARD
	fwd = fwd.normalized()
	var right := fwd.cross(up_dir).normalized()
	transform.basis = Basis(right, up_dir, -fwd).orthonormalized()

	if on_floor and Input.is_action_just_pressed("jump"):
		_vertical = jump_velocity
	elif on_floor:
		_vertical = -2.0
	else:
		_vertical -= gravity * delta

	var target_speed := max_speed * _boost_mult
	speed = move_toward(speed, target_speed, acceleration * delta)
	velocity = fwd * speed + Vector3.UP * _vertical

	move_and_slide()

	_update_animation()
	_update_camera(delta)
	_update_drift_visual()

	if global_position.y < -20.0:
		get_tree().reload_current_scene()


func _update_drift(delta: float, turn: float, on_floor: bool) -> void:
	if _boost_timer > 0.0:
		_boost_timer -= delta
		if _boost_timer <= 0.0:
			_boost_mult = 1.0

	var turning := absf(turn) > 0.15
	if Input.is_action_pressed("drift") and on_floor and speed > drift_min_speed and turning:
		if not _drifting:
			_drifting = true
			_drift_charge = 0.0
		_drift_charge += delta
		var lvl := 0
		for i in drift_charge_levels.size():
			if _drift_charge >= drift_charge_levels[i]:
				lvl = i + 1
		_drift_level = lvl
	elif _drifting:
		_release_drift()


func _release_drift() -> void:
	_drifting = false
	if _drift_level > 0 and _drift_level <= boost_multipliers.size():
		_boost_mult = boost_multipliers[_drift_level - 1]
		_boost_timer = boost_duration
	_drift_charge = 0.0
	_drift_level = 0


func _update_animation() -> void:
	if anim == null:
		return
	if _air_time > 0.12:
		_play(ANIM_JUMP)
	else:
		_play(ANIM_RUN)
		anim.speed_scale = clampf(speed / max_speed, 0.7, 1.8)


func _update_camera(delta: float) -> void:
	var t := clampf(speed / max_speed, 0.0, 1.6)
	if camera:
		var target_fov := lerpf(68.0, 90.0, clampf(t, 0.0, 1.0))
		camera.fov = lerpf(camera.fov, target_fov, clampf(6.0 * delta, 0.0, 1.0))
	if camera_rig:
		var target_len := CAM_BOOST_LENGTH if _boost_timer > 0.0 else CAM_BASE_LENGTH
		camera_rig.spring_length = lerpf(camera_rig.spring_length, target_len, clampf(3.0 * delta, 0.0, 1.0))


func _update_drift_visual() -> void:
	var energy := 0.0
	var col := Color(0.0, 0.0, 0.0)
	if _drifting and _drift_level > 0:
		col = _drift_color(_drift_level)
		energy = 0.3 + 0.35 * float(_drift_level)
	elif _boost_timer > 0.0:
		col = Color(0.4, 0.85, 1.0)
		energy = 1.2
	for m in _dino_mats:
		m.emission_enabled = energy > 0.0
		m.emission = col
		m.emission_energy_multiplier = energy


func _drift_color(level: int) -> Color:
	match level:
		1:
			return Color(1.0, 0.9, 0.3)
		2:
			return Color(1.0, 0.55, 0.12)
		_:
			return Color(0.4, 0.7, 1.0)


func _play(name: String, force := false) -> void:
	if anim == null or not anim.has_animation(name):
		return
	if force or anim.current_animation != name:
		anim.play(name)

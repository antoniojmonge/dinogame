class_name DinoBase
extends CharacterBody3D

## Clase base de dinosaurio (estilo Sonic/CTR): corre solo, gira, salta,
## derrapa para turbo, y soporta HABILIDADES (subclases) e ITEMS usables.
## Subclases: trex.gd (rugido), velociraptor.gd (agilidad).

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

@export_group("Habilidad")
@export var ability_cooldown := 4.0
@export var is_player := false

@onready var anim: AnimationPlayer = get_node_or_null("Model/AnimationPlayer") as AnimationPlayer
@onready var camera_rig: SpringArm3D = get_node_or_null("CameraRig") as SpringArm3D
@onready var camera: Camera3D = get_node_or_null("CameraRig/Camera3D") as Camera3D
@onready var smoke: GPUParticles3D = get_node_or_null("DriftSmoke") as GPUParticles3D

const ANIM_IDLE := "Armature|TRex_Idle"
const ANIM_WALK := "Armature|TRex_Walk"
const ANIM_RUN := "Armature|TRex_Run"
const ANIM_JUMP := "Armature|TRex_Jump"

const CAM_BASE_LENGTH := 6.0
const CAM_BOOST_LENGTH := 8.5

var speed := 0.0
var up_dir := Vector3.UP
var held_power := ""

var _vertical := 0.0
var _air_time := 0.0
var _stun_time := 0.0
var _ability_cd := 0.0
var _ability_flash_time := 0.0
var _ability_flash_color := Color.WHITE

var _drifting := false
var _drift_charge := 0.0
var _drift_level := 0
var _boost_timer := 0.0
var _boost_mult := 1.0
var _shield_time := 0.0
var _dino_mats: Array[StandardMaterial3D] = []


func _ready() -> void:
	add_to_group("dino")
	if is_player:
		add_to_group("player")
	_setup_animations()
	_apply_materials()
	up_direction = up_dir
	floor_max_angle = deg_to_rad(85.0)


# --- Ganchos para subclases ---

func activate_ability() -> void:
	pass


# --- Entrada (virtual): el jugador lee teclado, la IA calcula ---

func _get_steer() -> float:
	return Input.get_axis("move_left", "move_right")


func _get_jump() -> bool:
	return Input.is_action_just_pressed("jump")


func _get_drift() -> bool:
	return Input.is_action_pressed("drift")


func _get_ability() -> bool:
	return Input.is_action_just_pressed("ability")


func _get_use_item() -> bool:
	return Input.is_action_just_pressed("use_item")


# --- Estado externo (golpes / poderes / aturdimiento) ---

func apply_stun(duration: float) -> void:
	_stun_time = maxf(_stun_time, duration)


func apply_obstacle_hit(slowdown: float, bounce: float) -> void:
	if _shield_time > 0.0:
		return
	speed = maxf(0.0, speed * slowdown)
	_vertical = maxf(_vertical, bounce)


func apply_power(power: String) -> void:
	match power:
		"turbo":
			_boost_mult = 1.8
			_boost_timer = boost_duration
		"shield":
			_shield_time = 5.0
		"projectile", "trap":
			held_power = power


# --- Bucle principal ---

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return

	if _shield_time > 0.0:
		_shield_time -= delta
	if _stun_time > 0.0:
		_stun_time -= delta
	if _ability_cd > 0.0:
		_ability_cd -= delta
	if _ability_flash_time > 0.0:
		_ability_flash_time -= delta

	if _ability_cd <= 0.0 and _stun_time <= 0.0 and _get_ability():
		activate_ability()
		_ability_cd = ability_cooldown
	if _get_use_item():
		use_held_power()

	var on_floor := is_on_floor()
	if on_floor:
		up_dir = up_dir.slerp(get_floor_normal(), clampf(align_speed * delta, 0.0, 1.0)).normalized()
		_air_time = 0.0
	else:
		up_dir = up_dir.slerp(Vector3.UP, clampf(1.5 * delta, 0.0, 1.0)).normalized()
		_air_time += delta
	up_direction = up_dir

	var turn := _get_steer()
	if _stun_time > 0.0:
		turn = 0.0

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

	if on_floor and _stun_time <= 0.0 and _get_jump():
		_vertical = jump_velocity
	elif on_floor:
		_vertical = -2.0
	else:
		_vertical -= gravity * delta

	var target_speed := max_speed * _boost_mult
	if _stun_time > 0.0:
		target_speed = 0.0
	speed = move_toward(speed, target_speed, acceleration * delta)
	velocity = fwd * speed + Vector3.UP * _vertical

	move_and_slide()

	_update_animation()
	_update_camera(delta)
	_update_visuals()

	if global_position.y < -20.0:
		get_tree().reload_current_scene()


# --- Items ---

func use_held_power() -> void:
	match held_power:
		"projectile":
			_spawn_projectile()
			held_power = ""
		"trap":
			_spawn_trap()
			held_power = ""


func _spawn_projectile() -> void:
	var scene: PackedScene = load("res://scenes/projectile.tscn")
	if scene == null:
		return
	var fwd := -transform.basis.z
	var p: Node3D = scene.instantiate()
	get_tree().current_scene.add_child(p)
	p.global_position = global_position + fwd * 1.2 + up_dir * 1.6
	if p.has_method("setup"):
		p.setup(fwd, self)


func _spawn_trap() -> void:
	var scene: PackedScene = load("res://scenes/trap.tscn")
	if scene == null:
		return
	var fwd := -transform.basis.z
	var t: Node3D = scene.instantiate()
	get_tree().current_scene.add_child(t)
	t.global_position = global_position - fwd * 1.8
	if t.has_method("setup"):
		t.setup(self)


# --- Animaciones / camara / visuales ---

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


func _update_drift(delta: float, turn: float, on_floor: bool) -> void:
	if _boost_timer > 0.0:
		_boost_timer -= delta
		if _boost_timer <= 0.0:
			_boost_mult = 1.0

	if _get_drift() and on_floor and speed > drift_min_speed and _stun_time <= 0.0:
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
	if camera != null:
		var target_fov := lerpf(68.0, 90.0, clampf(t, 0.0, 1.0))
		camera.fov = lerpf(camera.fov, target_fov, clampf(6.0 * delta, 0.0, 1.0))
	if camera_rig != null:
		var target_len := CAM_BOOST_LENGTH if _boost_timer > 0.0 else CAM_BASE_LENGTH
		camera_rig.spring_length = lerpf(camera_rig.spring_length, target_len, clampf(3.0 * delta, 0.0, 1.0))


func _update_visuals() -> void:
	var energy := 0.0
	var col := Color(0.0, 0.0, 0.0)
	if _ability_flash_time > 0.0:
		col = _ability_flash_color
		energy = 1.4
	elif _drifting and _drift_level > 0:
		col = _drift_color(_drift_level)
		energy = 0.3 + 0.35 * float(_drift_level)
	elif _boost_timer > 0.0:
		col = Color(0.4, 0.85, 1.0)
		energy = 1.2
	elif _shield_time > 0.0:
		col = Color(0.35, 1.0, 0.45)
		energy = 1.0
	for m in _dino_mats:
		m.emission_enabled = energy > 0.0
		m.emission = col
		m.emission_energy_multiplier = energy
	if smoke != null:
		smoke.emitting = _drifting


func _flash_ability(col: Color, duration := 0.5) -> void:
	_ability_flash_color = col
	_ability_flash_time = duration


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

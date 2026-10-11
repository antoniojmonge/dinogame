extends CharacterBody3D

## Controlador estilo Sonic: el dino corre solo hacia adelante,
## el jugador gira a izquierda/derecha y salta.

@export var max_speed := 22.0
@export var acceleration := 25.0
@export var steering_speed := 2.4
@export var jump_velocity := 13.0
@export var gravity := 32.0
@export var outline_enabled := true
@export var rim_enabled := true

@onready var anim: AnimationPlayer = $Model/AnimationPlayer
@onready var camera: Camera3D = $Camera3D

const ANIM_IDLE := "Armature|TRex_Idle"
const ANIM_WALK := "Armature|TRex_Walk"
const ANIM_RUN := "Armature|TRex_Run"
const ANIM_JUMP := "Armature|TRex_Jump"

var speed := 0.0


func _ready() -> void:
	add_to_group("player")
	_setup_animations()
	_apply_materials()


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


func _all_meshes(n: Node) -> Array:
	var out := []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_all_meshes(c))
	return out


func apply_obstacle_hit(slowdown: float, bounce: float) -> void:
	speed = maxf(0.0, speed * slowdown)
	if velocity.y < bounce:
		velocity.y = bounce


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	speed = move_toward(speed, max_speed, acceleration * delta)

	var turn := Input.get_axis("move_left", "move_right")
	rotate_y(-turn * steering_speed * delta)

	var forward := -transform.basis.z
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed

	move_and_slide()

	_update_animation()
	_update_camera(delta)

	if global_position.y < -20.0:
		get_tree().reload_current_scene()


func _update_animation() -> void:
	if anim == null:
		return
	if not is_on_floor():
		_play(ANIM_JUMP)
	else:
		_play(ANIM_RUN)
		anim.speed_scale = clampf(speed / max_speed, 0.7, 1.6)


func _update_camera(delta: float) -> void:
	if camera == null:
		return
	var target_fov := lerpf(68.0, 88.0, speed / max_speed)
	camera.fov = lerpf(camera.fov, target_fov, clampf(6.0 * delta, 0.0, 1.0))


func _play(name: String, force := false) -> void:
	if anim == null or not anim.has_animation(name):
		return
	if force or anim.current_animation != name:
		anim.play(name)

extends Area3D

## Proyectil que viaja en linea recta. Aturde a otros dinos y se destruye
## al impactar (dino u obstaculo) o al agotar su vida util.

var direction := Vector3.FORWARD
var speed := 46.0
var life := 3.0
var shooter: Node = null


func setup(dir: Vector3, owner_dino: Node) -> void:
	direction = dir.normalized()
	shooter = owner_dino


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body == shooter or body.is_in_group("track_world"):
		return
	if body.is_in_group("dino"):
		if body.has_method("apply_stun"):
			body.apply_stun(1.2)
		queue_free()
	elif body is StaticBody3D:
		queue_free()

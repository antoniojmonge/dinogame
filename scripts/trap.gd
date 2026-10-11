extends Area3D

## Trampa en el suelo: ralentiza a los dinos que la pisan (excepto su dueno).

@export var slow_factor := 0.3
@export var life := 12.0

var shooter: Node = null
var _armed := false


func setup(owner_dino: Node) -> void:
	shooter = owner_dino


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	await get_tree().create_timer(0.4).timeout
	_armed = true


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if not _armed or body == shooter:
		return
	if body.is_in_group("dino") and body.has_method("apply_obstacle_hit"):
		body.apply_obstacle_hit(slow_factor, 3.0)
		queue_free()

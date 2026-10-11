extends Area3D

## Caja de items: al tocarla da un poder aleatorio y se oculta para reaparecer.

@export var powers: Array[String] = ["turbo", "shield", "projectile", "trap"]
@export var respawn_time := 4.0

var _cooldown := 0.0
var _mesh: Node3D = null


func _ready() -> void:
	add_to_group("item_box")
	_mesh = get_node_or_null("MeshInstance3D")
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _mesh != null:
		_mesh.rotate_y(delta * 1.6)
	if _cooldown > 0.0:
		_cooldown -= delta
		if _cooldown <= 0.0:
			set_deferred("monitoring", true)
			visible = true


func _on_body_entered(body: Node3D) -> void:
	if _cooldown > 0.0:
		return
	if body.is_in_group("dino") and body.has_method("apply_power"):
		_cooldown = respawn_time
		set_deferred("monitoring", false)
		visible = false
		var p: String = powers[randi() % powers.size()]
		body.apply_power(p)

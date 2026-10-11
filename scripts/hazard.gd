extends Area3D

## Obstaculo interactivo: al tocar al jugador le reduce la velocidad
## (estilo Sonic/CTR) con un pequeno rebote. No bloquea el paso.

@export var slowdown_factor: float = 0.35
@export var bounce_strength: float = 6.0
@export var hit_cooldown: float = 0.8

var _cooldown := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta


func _on_body_entered(body: Node3D) -> void:
	if _cooldown > 0.0:
		return
	if body.is_in_group("dino") and body.has_method("apply_obstacle_hit"):
		_cooldown = hit_cooldown
		body.apply_obstacle_hit(slowdown_factor, bounce_strength)

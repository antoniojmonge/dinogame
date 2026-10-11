extends Area3D

## Linea de meta / salida. Al cruzar el jugador emite la senal 'crossed'.

signal crossed

var _cooldown := 0.0


func _ready() -> void:
	add_to_group("finish_line")
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta


func _on_body_entered(body: Node3D) -> void:
	if _cooldown > 0.0:
		return
	if body.is_in_group("player"):
		_cooldown = 1.0
		crossed.emit()

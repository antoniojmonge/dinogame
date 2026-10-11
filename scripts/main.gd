extends Node3D

## Sustituye el dinosaurio del jugador según la selección del menú.

func _ready() -> void:
	if Game.selected_dino != "velociraptor":
		return
	var dino: Node3D = get_node_or_null("Dino")
	if dino == null:
		return
	var pos: Vector3 = dino.global_position
	var basis: Basis = dino.global_transform.basis
	dino.queue_free()
	var raptor: Node3D = load("res://scenes/velociraptor.tscn").instantiate()
	add_child(raptor)
	raptor.global_transform = Transform3D(basis, pos)

extends Node3D

## Sustituye el dinosaurio del jugador según la selección del menú.

const SCENES := {
	"velociraptor": "res://scenes/velociraptor.tscn",
	"triceratops": "res://scenes/triceratops.tscn",
}


func _ready() -> void:
	if not SCENES.has(Game.selected_dino):
		return
	var dino: Node3D = get_node_or_null("Dino")
	if dino == null:
		return
	var pos: Vector3 = dino.global_position
	var basis: Basis = dino.global_transform.basis
	dino.queue_free()
	var chosen: Node3D = load(SCENES[Game.selected_dino]).instantiate()
	add_child(chosen)
	chosen.global_transform = Transform3D(basis, pos)

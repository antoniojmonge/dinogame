extends Node3D

## Importa un modelo de pista (glb) y le genera colision estatica (trimesh).

@export var model_path := "res://tracks/track_import.glb"


func _ready() -> void:
	var packed: PackedScene = load(model_path)
	if packed == null:
		push_warning("No se pudo cargar " + model_path)
		return
	var inst: Node = packed.instantiate()
	add_child(inst)
	var count := 0
	for mi in _meshes(inst):
		if mi.mesh != null:
			mi.create_trimesh_collision()
			for child in mi.get_children():
				if child is StaticBody3D:
					child.collision_layer = 1
			count += 1
	print("PISTA importada: ", count, " mallas con colision")


func _meshes(n: Node) -> Array:
	var out := []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out

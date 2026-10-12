extends Node

## Valida los .glb de tools/models/ (clips, huesos, tamano) SIN importarlos.
## Ejecutar:  godot --headless res://tools/validate_models.tscn
## Usa GLTFDocument (parseo en runtime) para no depender del pipeline de import.

const DIR := "res://tools/models"


func _ready() -> void:
	var dir := DirAccess.open(DIR)
	if dir == null:
		print("VALIDATE: no existe ", DIR, " (ejecuta tools/fetch_models.py)")
		get_tree().quit()
		return
	var files := []
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".glb"):
			files.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	files.sort()

	print("VALIDATE: ", files.size(), " modelos en ", DIR)
	for name in files:
		_validate(DIR + "/" + name)
	get_tree().quit()


func _validate(path: String) -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path, state)
	if err != OK:
		print(" - ", path.get_file(), ": ERROR GLTF (", err, ")")
		return
	var inst: Node = doc.generate_scene(state)
	if inst == null:
		print(" - ", path.get_file(), ": escena nula")
		return

	var aabb := AABB()
	var first := true
	for mi in _meshes(inst):
		var wb: AABB = mi.get_aabb()
		aabb = wb if first else aabb.merge(wb)
		first = false

	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	var sk: Skeleton3D = inst.find_child("Skeleton3D", true, false)
	var clips: Array = ap.get_animation_list() if ap != null else []

	print(" - %s | clips=%d %s | bones=%d | size=(%.2f, %.2f, %.2f) min_y=%.2f" % [
		path.get_file(), clips.size(), str(clips),
		sk.get_bone_count() if sk != null else 0,
		aabb.size.x, aabb.size.y, aabb.size.z, aabb.position.y])
	inst.free()


func _meshes(n: Node) -> Array:
	var out := []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out

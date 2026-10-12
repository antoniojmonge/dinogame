extends Node3D

## Escena de referencia aislada del T-Rex. NO forma parte del juego.
## Mide el modelo (mundo), lista clips y deja una capsula de referencia
## para comparar con la colision real del juego.

@onready var model: Node3D = $Model
@onready var camera: Camera3D = $Camera


func _ready() -> void:
	camera.position = Vector3(4.5, 3.0, 6.0)
	camera.look_at(Vector3(0.0, 1.6, 0.0), Vector3.UP)
	await get_tree().process_frame
	_report()


func _report() -> void:
	var aabb := AABB()
	var first := true
	for mi in _meshes(model):
		var wb: AABB = mi.global_transform * mi.get_aabb()
		aabb = wb if first else aabb.merge(wb)
		first = false
	var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	var clips: Array = ap.get_animation_list() if ap != null else []
	print("REF trex | world min_y=%.3f  size=(%.2f, %.2f, %.2f)  clips=%d %s" % [
		aabb.position.y, aabb.size.x, aabb.size.y, aabb.size.z, clips.size(), str(clips)])
	print("REF escala/origen modelo = ", model.transform)


func _meshes(n: Node) -> Array:
	var out := []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out

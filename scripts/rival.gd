extends DinoBase

## Rival con IA: sigue la linea de carrera mirando un punto por delante,
## usa su habilidad e items de vez en cuando.

@export var lookahead := 8
@export var steer_gain := 2.4

var _path: PackedVector3Array = PackedVector3Array()
var _ability_timer := 0.0


func _ready() -> void:
	super._ready()
	var track: Node = get_tree().get_first_node_in_group("track")
	if track != null and track.has_method("path_points"):
		_path = track.path_points()
	_ability_timer = randf_range(4.0, 9.0)


func activate_ability() -> void:
	_boost_mult = 1.5
	_boost_timer = 1.2
	_flash_ability(Color(0.9, 0.6, 1.0), 0.5)


func _get_ability() -> bool:
	_ability_timer -= get_physics_process_delta_time()
	if _ability_timer <= 0.0:
		_ability_timer = randf_range(7.0, 13.0)
		return true
	return false


func _get_use_item() -> bool:
	return held_power != "" and randf() < 0.02


func _get_steer() -> float:
	if _path.is_empty():
		return 0.0
	var idx := _nearest_index(global_position)
	var target: Vector3 = _path[(idx + lookahead) % _path.size()]
	var to_target := target - global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.0001:
		return 0.0
	var fwd := -transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var cross := fwd.cross(to_target.normalized())
	return clampf(-cross.y * steer_gain, -1.0, 1.0)


func _nearest_index(pos: Vector3) -> int:
	var best := 0
	var best_d := INF
	for i in _path.size():
		var d := _path[i].distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = i
	return best

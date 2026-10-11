extends Node

## Gestiona el cronometro, la POSICION de carrera (por progreso en la curva)
## y la tabla de resultados al terminar las vueltas.

@export var total_laps := 3

var _label: Label = null
var _results: Label = null
var _player: Node = null
var _dinos: Array = []
var _path := PackedVector3Array()
var _progress := {}
var _running := false
var _finished := false
var _lap := 0
var _lap_start := 0.0
var _best := -1.0


func _ready() -> void:
	_label = get_node_or_null("../HUD/Info")
	_results = get_node_or_null("../HUD/Results")
	if _results != null:
		_results.visible = false
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")
	var track := get_tree().get_first_node_in_group("track")
	if track != null and track.has_method("path_points"):
		_path = track.path_points()
	_dinos = get_tree().get_nodes_in_group("dino")
	for d in _dinos:
		_progress[d] = float(_nearest_index(d.global_position))
	var fl := get_tree().get_first_node_in_group("finish_line")
	if fl != null and fl.has_signal("crossed"):
		fl.crossed.connect(_on_crossed)


func _process(_delta: float) -> void:
	if _finished:
		return
	_update_progress()
	_draw_hud()


func _update_progress() -> void:
	if _path.is_empty():
		return
	var n := _path.size()
	for d in _dinos:
		if not is_instance_valid(d):
			continue
		var raw := _nearest_index(d.global_position)
		var prev: float = _progress.get(d, float(raw))
		var k := roundf((prev - raw) / float(n))
		_progress[d] = float(raw) + k * float(n)
	if _player != null and _progress.get(_player, 0.0) >= float(total_laps) * float(n):
		_finish_race()


func _standings() -> Array:
	var arr: Array = _dinos.duplicate()
	arr.sort_custom(func(a, b): return _progress.get(a, 0.0) > _progress.get(b, 0.0))
	return arr


func _draw_hud() -> void:
	if _label == null:
		return
	var n := maxi(_path.size(), 1)
	var cur := 0.0
	if _running:
		cur = _now() - _lap_start
	var best := "--"
	if _best >= 0.0:
		best = "%.2f" % _best
	var item := "-"
	if _player != null and _player.held_power != "":
		item = str(_player.held_power)
	var pos := 1
	var total := _dinos.size()
	var plaps := 1
	if _player != null:
		pos = _standings().find(_player) + 1
		plaps = clampi(int(_progress.get(_player, 0.0)) / n + 1, 1, total_laps)
	_label.text = "Vuelta: %d/%d\nPos: %d/%d\nTiempo: %.2f\nMejor: %s\nItem: %s" % [plaps, total_laps, pos, total, cur, best, item]


func _finish_race() -> void:
	_finished = true
	var st := _standings()
	var txt := "CARRERA TERMINADA\n\n"
	for i in st.size():
		var nm: String = "TÚ" if st[i] == _player else str(st[i].name)
		txt += "%d.  %s\n" % [i + 1, nm]
	if _results != null:
		_results.text = txt
		_results.visible = true


func _on_crossed() -> void:
	if _finished:
		return
	if not _running:
		_running = true
		_lap = 1
		_lap_start = _now()
		return
	var t := _now() - _lap_start
	if _best < 0.0 or t < _best:
		_best = t
	_lap += 1
	_lap_start = _now()


func _nearest_index(pos: Vector3) -> int:
	var best := 0
	var best_d := INF
	for i in _path.size():
		var d := _path[i].distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = i
	return best


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

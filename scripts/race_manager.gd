extends Node

## Gestiona el cronometro de vueltas y actualiza el HUD.

var _label: Label = null
var _running := false
var _lap := 0
var _lap_start := 0.0
var _best := -1.0


func _ready() -> void:
	_label = get_node_or_null("../HUD/Info")
	await get_tree().process_frame
	var fl := get_tree().get_first_node_in_group("finish_line")
	if fl != null and fl.has_signal("crossed"):
		fl.crossed.connect(_on_crossed)


func _process(_delta: float) -> void:
	if _label == null:
		return
	var cur := 0.0
	if _running:
		cur = _now() - _lap_start
	var best := "--"
	if _best >= 0.0:
		best = "%.2f" % _best
	_label.text = "Vuelta: %d\nTiempo: %.2f\nMejor: %s" % [_lap, cur, best]


func _on_crossed() -> void:
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


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

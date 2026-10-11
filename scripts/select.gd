extends Node3D

const DINOS := ["trex", "velociraptor", "triceratops"]
const NAMES := {"trex": "T-Rex", "velociraptor": "Velociraptor", "triceratops": "Triceratops"}
const SCALES := {"trex": 0.1, "velociraptor": 0.08, "triceratops": 0.115}
const ABILITY := {
	"trex": "Rugido: aturde a los rivales cercanos (E)",
	"velociraptor": "Agilidad: impulso de turbo (E)",
	"triceratops": "Coraza: escudo + embestida (E)",
}

var _index := 0
var _model: Node3D = null


func _ready() -> void:
	_index = maxi(DINOS.find(Game.selected_dino), 0)
	$UI/BottomCenter/Bottom/Nav/Prev.pressed.connect(_step.bind(-1))
	$UI/BottomCenter/Bottom/Nav/Next.pressed.connect(_step.bind(1))
	$UI/BottomCenter/Bottom/Actions/Play.pressed.connect(_play)
	$UI/BottomCenter/Bottom/Actions/Back.pressed.connect(_back)
	_show()


func _step(direction: int) -> void:
	_index = (_index + direction + DINOS.size()) % DINOS.size()
	_show()


func _show() -> void:
	var id: String = DINOS[_index]
	Game.selected_dino = id
	Game.save_game()
	if _model != null:
		_model.queue_free()
	var inst: Node3D = load("res://models/trex.glb").instantiate()
	$Pivot.add_child(inst)
	var s: float = SCALES.get(id, 0.1)
	inst.scale = Vector3(s, s, s)
	_model = inst
	$UI/TopCenter/Top/Name.text = NAMES.get(id, id)
	$UI/TopCenter/Top/Ability.text = ABILITY.get(id, "")


func _process(delta: float) -> void:
	$Pivot.rotate_y(delta * 0.8)


func _play() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

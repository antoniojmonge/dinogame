extends Control

func _ready() -> void:
	$Center/VBox/Play.pressed.connect(_on_play)
	$Center/VBox/Select.pressed.connect(_on_select)
	$Center/VBox/CreditsBtn.pressed.connect(_on_credits)
	$Center/VBox/Quit.pressed.connect(Game.quit_game)
	_update_info()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Game.quit_game()


func _update_info() -> void:
	var best := "--"
	if Game.best_lap > 0.0:
		best = "%.2f s" % Game.best_lap
	$Center/VBox/Info.text = "Dinosaurio: %s\nMejor vuelta: %s" % [_dino_name(), best]


func _dino_name() -> String:
	return "Velociraptor" if Game.selected_dino == "velociraptor" else "T-Rex"


func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_select() -> void:
	Game.selected_dino = "velociraptor" if Game.selected_dino == "trex" else "trex"
	Game.save_game()
	_update_info()


func _on_credits() -> void:
	$Credits.visible = not $Credits.visible

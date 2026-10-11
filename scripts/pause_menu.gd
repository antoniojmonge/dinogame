extends CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	$Center/VBox/Continue.pressed.connect(_resume)
	$Center/VBox/Restart.pressed.connect(_restart)
	$Center/VBox/Menu.pressed.connect(_to_menu)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	if get_tree().paused:
		_resume()
	else:
		get_tree().paused = true
		visible = true


func _resume() -> void:
	get_tree().paused = false
	visible = false


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

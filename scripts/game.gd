extends Node

## Estado global y guardado (autoload "Game").

const SAVE_PATH := "user://save.cfg"

var selected_dino := "trex"
var best_lap := -1.0


func _ready() -> void:
	load_game()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			toggle_fullscreen()


func toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func quit_game() -> void:
	get_tree().quit()


func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		selected_dino = cfg.get_value("game", "selected_dino", "trex")
		best_lap = cfg.get_value("game", "best_lap", -1.0)


func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "selected_dino", selected_dino)
	cfg.set_value("game", "best_lap", best_lap)
	cfg.save(SAVE_PATH)


func save_best(t: float) -> void:
	if t <= 0.0:
		return
	if best_lap < 0.0 or t < best_lap:
		best_lap = t
		save_game()

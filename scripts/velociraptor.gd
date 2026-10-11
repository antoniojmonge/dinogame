extends DinoBase

## Velociraptor: habilidad "Impulso de agilidad" (turbo fuerte y breve).

@export var dash_mult := 2.0
@export var dash_duration := 1.6


func activate_ability() -> void:
	_boost_mult = dash_mult
	_boost_timer = dash_duration
	_flash_ability(Color(0.5, 1.0, 0.35), 0.6)

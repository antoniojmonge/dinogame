extends DinoBase

## Triceratops: habilidad "Coraza" (escudo temporal + embestida de turbo).

func activate_ability() -> void:
	_shield_time = 4.0
	_boost_mult = 1.6
	_boost_timer = 1.6
	_flash_ability(Color(0.6, 0.85, 1.0), 0.6)

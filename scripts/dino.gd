extends DinoBase

## T-Rex: habilidad "Rugido" que aturde a los rivales cercanos (radio).

@export var roar_radius := 14.0
@export var roar_stun := 1.6


func activate_ability() -> void:
	for other in get_tree().get_nodes_in_group("dino"):
		if other == self:
			continue
		if global_position.distance_to(other.global_position) <= roar_radius:
			if other.has_method("apply_stun"):
				other.apply_stun(roar_stun)
	_flash_ability(Color(1.0, 0.3, 0.2), 0.6)

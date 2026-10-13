class_name LightSource
extends Area2D
## Fonte de luz: recarrega a brasa de quem estiver dentro dela.

@export var refill_per_second := 60.0


func _physics_process(delta: float) -> void:
	for body in get_overlapping_bodies():
		var player := body as Player
		if player:
			player.ember.refill(refill_per_second * delta)

extends Area2D
## Zona de queda: devolve o jogador ao ponto de início e enche a brasa.

@export var respawn_point: Marker2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player == null or respawn_point == null:
		return
	player.global_position = respawn_point.global_position
	player.velocity = Vector2.ZERO
	player.ember.refill(player.ember.max_energy)

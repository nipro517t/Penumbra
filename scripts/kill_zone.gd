extends Area2D
## Zona de queda: devolve o herói ao último checkpoint (ou ao ponto inicial).

@export var respawn_point: Marker2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player == null:
		return
	if GameState.has_checkpoint():
		GameState.respawn(player)
	elif respawn_point:
		player.respawn_at(respawn_point.global_position)

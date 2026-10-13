class_name LightSource
extends Area2D
## Fonte de luz: recarrega a brasa, recupera a sanidade e vira checkpoint.

@export var refill_per_second := 60.0
@export var is_checkpoint := true
## Onde o herói reaparece em relação à fonte (acima do chão).
@export var checkpoint_offset := Vector2(0.0, -14.0)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	for body in get_overlapping_bodies():
		var player := body as Player
		if player:
			player.ember.refill(refill_per_second * delta)


func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player == null:
		return
	player.enter_light()
	if is_checkpoint:
		GameState.set_checkpoint(global_position + checkpoint_offset)


func _on_body_exited(body: Node2D) -> void:
	var player := body as Player
	if player:
		player.exit_light()

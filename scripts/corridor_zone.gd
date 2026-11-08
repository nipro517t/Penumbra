class_name CorridorZone
extends Area2D
## Área do "corredor escuro": enquanto o herói está dentro, o dash e o pulo ficam desligados
## e a luz dele fica mínima (ver Player.set_corridor_mode).
## Como usar: coloque um Area2D com um CollisionShape2D cobrindo o corredor e anexe este script.
## As vozes e as criaturas do corredor ainda não existem: use VoiceTriggers dentro da área
## para as falas (as falas são suas).

## Pausa a sanidade dentro do corredor (as criaturas nas bordas não "pegam" o herói).
@export var pause_sanity := true
## Opcional: marca este flag no GameState ao entrar (ex.: "entrou_corredor").
@export var flag_to_set := ""

var _paused_sanity := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player == null:
		return
	player.set_corridor_mode(true)
	if pause_sanity and player.sanity.enabled:
		player.sanity.enabled = false
		_paused_sanity = true
	if flag_to_set != "":
		GameState.set_flag(flag_to_set)


func _on_body_exited(body: Node2D) -> void:
	var player := body as Player
	if player == null:
		return
	player.set_corridor_mode(false)
	if _paused_sanity:
		player.sanity.enabled = true
		_paused_sanity = false

class_name VoiceTrigger
extends Area2D
## Faz a voz em vermelho falar quando o herói entra na área.
## Escreva as falas no Inspetor (propriedade "lines").

@export var lines: Array[String] = ["(fala da voz: edite no Inspetor)"]
@export var once := true
## Opcional: marca este flag no GameState ao disparar (ex.: "ouviu_voz_1").
@export var flag_to_set := ""

var _done := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player == null or (once and _done):
		return
	_done = true
	var box := get_tree().get_first_node_in_group("voice_box")
	if box:
		box.say_lines(lines)
	if flag_to_set != "":
		GameState.set_flag(flag_to_set)

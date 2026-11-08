class_name ChapterEnd
extends Node
## Tela de fim do capítulo.
## Como funciona: quando o ECO termina a conversa (sinal `talked`), espera um instante,
## escurece a tela e mostra o título do capítulo e um texto. Depois de um tempo (ou ao
## apertar interagir/confirmar) volta ao menu principal.
## Tudo é construído por código. O TEXTO FINAL É SEU: edite `end_text` no Inspetor
## (o atual é só um marcador).
##
## Como usar: um nó Node com este script na fase e `echo` apontando para o Echo.

@export var echo: NodePath
@export var chapter_title := "CAPÍTULO 1"
@export_multiline var end_text := "(texto de fim do capítulo: escreva o seu)"
@export var delay_after_talk := 1.2
@export var fade_time := 1.6
## Segundos antes de aparecer a dica para continuar.
@export var hint_delay := 3.0
@export var next_scene := "res://scenes/main_menu.tscn"
## Flag marcada no GameState ao terminar.
@export var flag_to_set := "capitulo_1_completo"

var _started := false
var _ready_to_leave := false
var _layer: CanvasLayer
var _black: ColorRect
var _title: Label
var _text: Label
var _hint: Label


func _ready() -> void:
	var node := get_node_or_null(echo)
	if node and node.has_signal("talked"):
		node.talked.connect(_on_echo_talked)
	else:
		push_warning("ChapterEnd: aponte `echo` para o nó do Eco no Inspetor.")


func _on_echo_talked() -> void:
	if _started:
		return
	_started = true
	await get_tree().create_timer(delay_after_talk).timeout
	_build_screen()
	_run()


func _build_screen() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 60
	add_child(_layer)

	_black = ColorRect.new()
	_black.color = Color(0.0, 0.0, 0.0, 1.0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.modulate.a = 0.0
	_black.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(_black)

	_title = _make_label(28, Color(1.0, 0.82, 0.5))
	_title.text = chapter_title
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.offset_top = -40.0
	_title.modulate.a = 0.0
	_layer.add_child(_title)

	_text = _make_label(12, Color(0.75, 0.8, 0.9))
	_text.text = end_text
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text.offset_top = 20.0
	_text.offset_left = 60.0
	_text.offset_right = -60.0
	_text.modulate.a = 0.0
	_layer.add_child(_text)

	_hint = _make_label(10, Color(0.6, 0.65, 0.75))
	_hint.text = "[ Interagir / Confirmar ]  voltar ao menu"
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -30.0
	_hint.offset_bottom = -10.0
	_hint.modulate.a = 0.0
	_layer.add_child(_hint)


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _run() -> void:
	GameState.set_flag(flag_to_set)

	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.controls_locked = true
		if player.sanity:
			player.sanity.enabled = false

	var tween := create_tween()
	tween.tween_property(_black, "modulate:a", 1.0, fade_time)
	tween.tween_property(_title, "modulate:a", 1.0, 1.0)
	tween.tween_property(_text, "modulate:a", 1.0, 1.0)
	await tween.finished

	await get_tree().create_timer(hint_delay).timeout
	var hint_tween := create_tween()
	hint_tween.tween_property(_hint, "modulate:a", 1.0, 0.6)
	_ready_to_leave = true


func _unhandled_input(event: InputEvent) -> void:
	if not _ready_to_leave:
		return
	var accept: bool = event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")
	if accept:
		_ready_to_leave = false
		get_viewport().set_input_as_handled()
		_leave()


func _leave() -> void:
	# voltar ao menu começa uma partida nova (igual ao "Voltar ao menu" da pausa)
	Engine.time_scale = 1.0
	GameState.checkpoint = Vector2.INF
	GameState.flags.clear()
	get_tree().change_scene_to_file(next_scene)

class_name DialogBox
extends CanvasLayer
## Caixa de diálogo com texto digitado, usada pelos ecos (NPCs).
## Uso: `await box.open("Nome", ["linha 1", "linha 2"])` — a função só termina quando
## o jogador passa por todas as linhas.
##
## Controles: "interact" (E) ou "ui_accept" (Enter, Espaço, ✕ no controle) avançam.
## Se o texto ainda está sendo digitado, o primeiro aperto completa a linha.
## É construída por código; ajuste as variáveis no Inspetor (se a instanciar na cena).

signal finished

@export var chars_per_second := 42.0
@export var panel_color := Color(0.03, 0.03, 0.07, 0.88)
@export var border_color := Color(0.45, 0.55, 0.75, 1.0)
@export var text_color := Color(0.85, 0.92, 1.0)
@export var name_color := Color(1.0, 0.78, 0.45)
@export var font_size := 10
@export var name_font_size := 9

var _lines: Array[String] = []
var _index := 0
var _typing := false
var _open := false
var _opened_frame := 0
var _tween: Tween

var _panel: PanelContainer
var _name_label: Label
var _text_label: Label


func _ready() -> void:
	layer = 15
	add_to_group("dialog_box")
	_build()
	_panel.visible = false


func is_open() -> bool:
	return _open


## Abre o diálogo e só retorna quando ele termina (use com `await`).
func open(speaker: String, lines: Array[String]) -> void:
	if _open or lines.is_empty():
		return
	_open = true
	_lines.clear()
	for line in lines:
		_lines.append(line)
	_index = 0
	_opened_frame = Engine.get_process_frames()
	_name_label.text = speaker
	_name_label.visible = speaker != ""
	_panel.visible = true
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.15)
	_show_line()
	await finished


func _process(_delta: float) -> void:
	if not _open:
		return
	# ignora o aperto que acabou de abrir o diálogo (mesmo frame ou o seguinte)
	if Engine.get_process_frames() <= _opened_frame + 1:
		return
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
		_advance()


# ---------------------------------------------------------------- linhas

func _show_line() -> void:
	_text_label.text = _lines[_index]
	_text_label.visible_ratio = 0.0
	_typing = true
	var duration := maxf(float(_lines[_index].length()) / chars_per_second, 0.05)
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_text_label, "visible_ratio", 1.0, duration)
	_tween.finished.connect(_on_typing_done)


func _on_typing_done() -> void:
	_typing = false


func _advance() -> void:
	if _typing:
		# completa a linha na hora
		if _tween and _tween.is_valid():
			_tween.kill()
		_text_label.visible_ratio = 1.0
		_typing = false
		return
	_index += 1
	if _index >= _lines.size():
		_close()
	else:
		_show_line()


func _close() -> void:
	_open = false
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, 0.12)
	await tween.finished
	_panel.visible = false
	finished.emit()


# ------------------------------------------------------------ construção

func _build() -> void:
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = panel_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	# ancorado embaixo, com margens; cresce para cima se o texto for maior
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 24.0
	_panel.offset_right = -24.0
	_panel.offset_top = -78.0
	_panel.offset_bottom = -16.0
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_panel.add_child(box)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", name_font_size)
	_name_label.add_theme_color_override("font_color", name_color)
	box.add_child(_name_label)

	_text_label = Label.new()
	_text_label.add_theme_font_size_override("font_size", font_size)
	_text_label.add_theme_color_override("font_color", text_color)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.custom_minimum_size = Vector2(0.0, 28.0)
	box.add_child(_text_label)

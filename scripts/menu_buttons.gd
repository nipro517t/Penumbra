extends VBoxContainer
## Botões do menu: sem bordas cinzas; o botão em foco (mouse, teclado ou controle)
## desliza levemente para a direita e muda de cor.
## Como usar: anexe este script ao VBoxContainer que contém os botões.

@export var shift_px := 14.0
@export var shift_time := 0.12
@export var normal_color := Color(0.62, 0.58, 0.68)
@export var focus_color := Color(1.0, 0.78, 0.45)
## O primeiro botão já começa selecionado (necessário para navegar com teclado/controle).
@export var focus_first_button := true

var _styles: Dictionary = {}
var _tweens: Dictionary = {}


func _ready() -> void:
	var first: Button = null
	for child in get_children():
		var button := child as Button
		if button == null:
			continue
		if first == null:
			first = button
		_setup(button)
	if focus_first_button and first:
		first.grab_focus()


func _setup(button: Button) -> void:
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT

	# um estilo vazio (sem borda) para todos os estados; sua margem esquerda é animada
	var style := StyleBoxEmpty.new()
	style.content_margin_left = 0.0
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, style)
	_styles[button] = style

	button.add_theme_color_override("font_color", normal_color)
	for color_name in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(color_name, focus_color)

	# o foco é a única fonte de verdade: passar o mouse também dá o foco
	button.mouse_entered.connect(button.grab_focus)
	button.focus_entered.connect(_shift.bind(button, shift_px))
	button.focus_exited.connect(_shift.bind(button, 0.0))


func _shift(button: Button, target: float) -> void:
	var style: StyleBoxEmpty = _styles[button]
	if _tweens.has(button) and (_tweens[button] as Tween).is_valid():
		(_tweens[button] as Tween).kill()
	var tween := create_tween()
	tween.tween_property(style, "content_margin_left", target, shift_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tweens[button] = tween

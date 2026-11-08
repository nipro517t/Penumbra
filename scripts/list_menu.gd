extends CanvasLayer
## Lista de opções genérica (usada pela pausa e pelas configurações). Construída por código.
## Navegar: setas/WASD, D-pad ou analógico. Confirmar: Enter/Espaço/✕. Voltar: Esc/○/Start.
## O mouse também funciona (passar = selecionar, clicar = confirmar).
##
## Cada linha de `rows` é um Dictionary:
##   "text":   Callable que devolve o texto da linha (relido a cada mudança)
##   "accept": Callable chamado ao confirmar (opcional)
##   "adjust": Callable com um int (-1 ou +1), chamado com esquerda/direita (opcional)
## Use open() e hide_menu(). `cancel` é chamado ao apertar "voltar".
## Enquanto aberto, engole teclado e controle para nada por baixo reagir.

const NORMAL_COLOR := Color(0.55, 0.5, 0.62)
const FOCUS_COLOR := Color(1.0, 0.78, 0.45)
const SHIFT_PX := 12.0
const COLOR_NAMES := ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]

var title := ""
var hint := ""
var rows: Array = []
var cancel: Callable = Callable()
var dim_alpha := 0.7
## Quadro em que foi escondido (o autoload da pausa usa para não reabrir no mesmo aperto).
var last_hide_frame := -1

var _open := false
var _open_frame := -1
var _index := 0
var _buttons: Array[Button] = []
var _styles: Array[StyleBoxEmpty] = []
var _armed_x := true
var _armed_y := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, dim_alpha)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var title_label := Label.new()
	title_label.text = title
	title_label.position = Vector2(40.0, 56.0)
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.78))
	add_child(title_label)

	var box := VBoxContainer.new()
	box.position = Vector2(40.0, 96.0)
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	for i in rows.size():
		var button := Button.new()
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 12)
		var style := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, style)
		button.mouse_entered.connect(_select.bind(i))
		button.pressed.connect(_on_row_pressed.bind(i))
		box.add_child(button)
		_buttons.append(button)
		_styles.append(style)

	if hint != "":
		var hint_label := Label.new()
		hint_label.text = hint
		hint_label.position = Vector2(40.0, 246.0)
		hint_label.add_theme_font_size_override("font_size", 9)
		hint_label.add_theme_color_override("font_color", Color(0.5, 0.46, 0.58))
		add_child(hint_label)


func open(start_index: int = 0) -> void:
	_index = clampi(start_index, 0, maxi(rows.size() - 1, 0))
	_open = true
	_open_frame = Engine.get_process_frames()
	_armed_x = false
	_armed_y = false
	visible = true
	_refresh()


func hide_menu() -> void:
	_open = false
	visible = false
	last_hide_frame = Engine.get_process_frames()


func is_open() -> bool:
	return _open


func _input(event: InputEvent) -> void:
	if not _open:
		return
	var is_key := event is InputEventKey
	var is_joy := event is InputEventJoypadButton or event is InputEventJoypadMotion
	if not is_key and not is_joy:
		return
	# o aperto que abriu o menu não deve acioná-lo de novo
	var same_frame := Engine.get_process_frames() == _open_frame

	var nav := _read_nav(event)
	if nav.y != 0:
		_select(wrapi(_index + nav.y, 0, rows.size()))
	elif nav.x != 0:
		_adjust(nav.x)
	elif not same_frame and _is_accept(event):
		_activate(_index)
	elif not same_frame and _is_cancel(event):
		if cancel.is_valid():
			cancel.call()
	get_viewport().set_input_as_handled()


func _read_nav(event: InputEvent) -> Vector2i:
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed:
			return Vector2i.ZERO
		if key.is_action_pressed("ui_up", true) or key.physical_keycode == KEY_W:
			return Vector2i(0, -1)
		if key.is_action_pressed("ui_down", true) or key.physical_keycode == KEY_S:
			return Vector2i(0, 1)
		if key.is_action_pressed("ui_left", true) or key.physical_keycode == KEY_A:
			return Vector2i(-1, 0)
		if key.is_action_pressed("ui_right", true) or key.physical_keycode == KEY_D:
			return Vector2i(1, 0)
	elif event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		if button.pressed:
			match button.button_index:
				JOY_BUTTON_DPAD_UP:
					return Vector2i(0, -1)
				JOY_BUTTON_DPAD_DOWN:
					return Vector2i(0, 1)
				JOY_BUTTON_DPAD_LEFT:
					return Vector2i(-1, 0)
				JOY_BUTTON_DPAD_RIGHT:
					return Vector2i(1, 0)
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var value := motion.axis_value
		if motion.axis == JOY_AXIS_LEFT_Y:
			if absf(value) < 0.35:
				_armed_y = true
			elif _armed_y and absf(value) > 0.65:
				_armed_y = false
				return Vector2i(0, 1 if value > 0.0 else -1)
		elif motion.axis == JOY_AXIS_LEFT_X:
			if absf(value) < 0.35:
				_armed_x = true
			elif _armed_x and absf(value) > 0.65:
				_armed_x = false
				return Vector2i(1 if value > 0.0 else -1, 0)
	return Vector2i.ZERO


func _is_accept(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key := event as InputEventKey
		return key.pressed and not key.echo and key.is_action_pressed("ui_accept")
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		return button.pressed and button.button_index == JOY_BUTTON_A
	return false


func _is_cancel(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key := event as InputEventKey
		return key.pressed and not key.echo and \
				(key.is_action_pressed("ui_cancel") or key.is_action_pressed("pause"))
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		return button.pressed and \
				(button.button_index == JOY_BUTTON_B or button.button_index == JOY_BUTTON_START)
	return false


func _select(index: int) -> void:
	if not _open or index == _index:
		return
	_index = index
	_refresh()


func _adjust(direction: int) -> void:
	var row: Dictionary = rows[_index]
	if row.has("adjust"):
		var adjust: Callable = row["adjust"]
		adjust.call(direction)
		_refresh()


func _activate(index: int) -> void:
	var row: Dictionary = rows[index]
	if row.has("accept"):
		var accept: Callable = row["accept"]
		accept.call()
	elif row.has("adjust"):
		var adjust: Callable = row["adjust"]
		adjust.call(1)
	if _open:
		_refresh()


func _on_row_pressed(index: int) -> void:
	if not _open:
		return
	_index = index
	_activate(index)


func _refresh() -> void:
	for i in _buttons.size():
		var row: Dictionary = rows[i]
		var text_fn: Callable = row["text"]
		_buttons[i].text = str(text_fn.call())
		var color := FOCUS_COLOR if i == _index else NORMAL_COLOR
		for color_name in COLOR_NAMES:
			_buttons[i].add_theme_color_override(color_name, color)
		_styles[i].content_margin_left = SHIFT_PX if i == _index else 0.0

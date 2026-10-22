class_name Echo
extends Area2D
## Eco: uma pessoa consumida pela sombra, que fala com o herói. É um NPC pacífico.
##
## As FALAS são suas: edite as listas no Inspetor (os textos atuais são só marcadores).
##  - lines         → a conversa (aparece numa caixa de diálogo, texto digitado)
##  - repeat_lines  → o que ele diz se você falar de novo (vazio = não conversa mais)
##  - leave_lines   → um comentário solto que flutua quando você se afasta depois de conversar
##
## Como funciona: um Area2D detecta o herói. Com `auto_start` a primeira conversa começa
## sozinha ao chegar perto (no chão); as seguintes pedem apertar "interact" (aparece um aviso).
## Durante a conversa o herói fica parado e a sanidade pausa. Tudo é construído por código.

signal talked

const DIALOG_SCENE := preload("res://scenes/dialog_box.tscn")

@export var echo_name := "Eco"
@export var show_name := true
@export var lines: Array[String] = ["(fala do eco: edite no Inspetor)"]
@export var repeat_lines: Array[String] = []
@export var leave_lines: Array[String] = []
## Primeira conversa começa sozinha ao se aproximar.
@export var auto_start := true
@export var prompt_text := "Falar"
## Opcional: flag marcada no GameState depois da conversa (ex.: "falou_com_eco_1").
@export var flag_to_set := ""
## Pausa a queda de sanidade enquanto conversam.
@export var pause_sanity := true
@export var activation_radius := 44.0
@export var leave_text_time := 3.0
@export var body_color := Color(0.55, 0.65, 0.85, 0.7)
@export var hud_color := Color(0.8, 0.9, 1.0)

var _player: Player
var _inside := false
var _talking := false
var _talked := false
var _leave_index := 0
var _time := 0.0
var _visual: Node2D
var _hud: CanvasLayer
var _prompt: Label
var _leave_label: Label
var _leave_tween: Tween


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitorable = false

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = activation_radius
	shape.shape = circle
	shape.position = Vector2(0.0, -10.0)
	add_child(shape)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_visual()
	_build_hud()


func _process(delta: float) -> void:
	_time += delta
	_visual.position.y = sin(_time * 1.6) * 1.5
	_visual.modulate.a = 0.85 + 0.15 * sin(_time * 3.1)
	# os avisos ficam numa camada de tela (a escuridão do mundo não os apaga)
	var screen := get_global_transform_with_canvas() * Vector2(0.0, -34.0)
	_prompt.position = screen - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_leave_label.position = screen - Vector2(_leave_label.size.x * 0.5, _leave_label.size.y + 12.0)


func _physics_process(_delta: float) -> void:
	if _player == null or not _inside or _talking:
		return
	var can_talk := _player.is_on_floor() and not _player.controls_locked
	if not can_talk:
		return
	if auto_start and not _talked:
		_start_dialog(lines)
	elif Input.is_action_just_pressed("interact") and _can_interact():
		_start_dialog(repeat_lines if _talked else lines)


func _can_interact() -> bool:
	return not _talked or not repeat_lines.is_empty()


# ---------------------------------------------------------------- conversa

func _start_dialog(dialog_lines: Array[String]) -> void:
	if dialog_lines.is_empty():
		return
	_talking = true
	_show_prompt(false)
	_hide_leave()
	_player.controls_locked = true
	if pause_sanity:
		_player.sanity.enabled = false

	var box := _get_box()
	await box.open(echo_name if show_name else "", dialog_lines)

	# pequena folga para o aperto que fechou a caixa não virar um pulo
	await get_tree().create_timer(0.12).timeout
	_player.controls_locked = false
	if pause_sanity:
		_player.sanity.enabled = true

	_talking = false
	_talked = true
	if flag_to_set != "":
		GameState.set_flag(flag_to_set)
	talked.emit()
	_show_prompt(_inside and _can_interact())


func _get_box() -> DialogBox:
	var box := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	if box == null:
		box = DIALOG_SCENE.instantiate() as DialogBox
		get_tree().current_scene.add_child(box)
	return box


func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player == null:
		return
	_player = player
	_inside = true
	_show_prompt(not _talking and not (auto_start and not _talked) and _can_interact())


func _on_body_exited(body: Node2D) -> void:
	var player := body as Player
	if player == null:
		return
	_inside = false
	_show_prompt(false)
	if _talked and not _talking and not leave_lines.is_empty():
		_say_leave()


# ------------------------------------------------------------------ avisos

func _interact_key() -> String:
	for event in InputMap.action_get_events("interact"):
		var key := event as InputEventKey
		if key:
			return OS.get_keycode_string(key.physical_keycode)
	return "E"


func _show_prompt(visible_now: bool) -> void:
	_prompt.text = "[%s] %s" % [_interact_key(), prompt_text]
	create_tween().tween_property(_prompt, "modulate:a", 1.0 if visible_now else 0.0, 0.15)


func _say_leave() -> void:
	_leave_label.text = leave_lines[_leave_index % leave_lines.size()]
	_leave_index += 1
	if _leave_tween and _leave_tween.is_valid():
		_leave_tween.kill()
	_leave_tween = create_tween()
	_leave_tween.tween_property(_leave_label, "modulate:a", 1.0, 0.3)
	_leave_tween.tween_interval(leave_text_time)
	_leave_tween.tween_property(_leave_label, "modulate:a", 0.0, 0.6)


func _hide_leave() -> void:
	if _leave_tween and _leave_tween.is_valid():
		_leave_tween.kill()
	_leave_label.modulate.a = 0.0


# ------------------------------------------------------------ construção

func _build_visual() -> void:
	_visual = Node2D.new()
	add_child(_visual)

	var body := Polygon2D.new()
	body.color = body_color
	var points := PackedVector2Array()
	for i in 14:
		var angle := TAU * float(i) / 14.0
		var wobble := 0.85 + 0.15 * sin(angle * 3.0)
		points.append(Vector2(cos(angle) * 9.0, sin(angle) * 14.0 * wobble))
	body.polygon = points
	body.position = Vector2(0.0, -14.0)
	_visual.add_child(body)

	for eye_x in [-3.5, 1.5]:
		var eye := ColorRect.new()
		eye.color = Color(1.0, 0.97, 0.85)
		eye.size = Vector2(2.0, 3.0)
		eye.position = Vector2(float(eye_x), -19.0)
		_visual.add_child(eye)

	# uma luz fraca: o eco brilha um pouco no escuro
	var light := PointLight2D.new()
	light.texture = _radial_texture()
	light.color = Color(0.6, 0.75, 1.0)
	light.energy = 0.7
	light.texture_scale = 0.45
	light.position = Vector2(0.0, -14.0)
	add_child(light)


func _radial_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 8
	add_child(_hud)
	_prompt = _make_label()
	_leave_label = _make_label()


func _make_label() -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", hud_color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(150.0, 0.0)
	label.size = Vector2(150.0, 12.0)
	label.modulate.a = 0.0
	_hud.add_child(label)
	return label

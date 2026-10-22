extends Node2D
## Menu principal estilizado: um raio de luz mira o botão selecionado e a luz revela
## uma parte diferente do cenário. No botão "Sair", tudo apaga e surgem olhos na escuridão.
## Tudo é construído por código; ajuste as variáveis no Inspetor do nó MainMenu.

const GAME_SCENE := "res://scenes/main.tscn"
const HERO_FRAMES := "res://assets/player/adventurer/adventurer-idle-%02d.png"
const GROUND_Y := 215.0

## Por opção: onde a luz de "revelação" fica, o tamanho/força dela, a luz ambiente,
## a força do raio (0 = apagado) e a visibilidade dos olhos.
## Ordem: Jogar, Configurações, Créditos, Sair.
const FOCUS := [
	{"reveal": Vector2(380.0, 150.0), "scale": 1.3, "energy": 1.0, "ambient": Color(0.20, 0.20, 0.30), "beam": 1.0, "eyes": 0.0},
	{"reveal": Vector2(305.0, 125.0), "scale": 0.9, "energy": 1.0, "ambient": Color(0.15, 0.15, 0.24), "beam": 1.0, "eyes": 0.0},
	{"reveal": Vector2(265.0, 175.0), "scale": 1.0, "energy": 0.9, "ambient": Color(0.13, 0.13, 0.22), "beam": 1.0, "eyes": 0.0},
	{"reveal": Vector2(380.0, 150.0), "scale": 0.6, "energy": 0.0, "ambient": Color(0.04, 0.04, 0.08), "beam": 0.0, "eyes": 1.0},
]
## Prédios do fundo: x, largura, altura.
const BUILDINGS := [
	Vector3(140.0, 26.0, 70.0), Vector3(172.0, 34.0, 110.0), Vector3(212.0, 22.0, 60.0),
	Vector3(240.0, 40.0, 95.0), Vector3(288.0, 30.0, 125.0), Vector3(330.0, 26.0, 80.0),
	Vector3(425.0, 40.0, 100.0), Vector3(458.0, 30.0, 70.0),
]
const EYE_SPOTS := [Vector2(95.0, 196.0), Vector2(330.0, 206.0), Vector2(445.0, 150.0), Vector2(215.0, 120.0)]

@export var game_title := "Penumbra"
@export var options: Array[String] = ["Jogar", "Configurações", "Créditos", "Sair"]
@export var title_font_size := 22
@export var button_font_size := 12
@export var menu_position := Vector2(20.0, 150.0)
@export var button_spacing := 6
@export var shift_px := 12.0
@export var normal_color := Color(0.55, 0.5, 0.62)
@export var focus_color := Color(1.0, 0.78, 0.45)
## Cor do botão "Sair" quando selecionado.
@export var dark_focus_color := Color(0.9, 0.3, 0.3)
## De onde sai o raio de luz (fora da tela, em cima).
@export var beam_origin := Vector2(300.0, -40.0)
## Abertura do raio (radianos).
@export var beam_half_angle := 0.3
@export var beam_energy := 1.5
@export var move_time := 0.45

var beam_target := Vector2(60.0, 160.0)
var beam_strength := 0.0

var _time := 0.0
var _focus_tween: Tween
var _buttons: Array[Button] = []
var _styles: Dictionary = {}
var _shift_tweens: Dictionary = {}
var _world: Node2D
var _ambient: CanvasModulate
var _beam_light: PointLight2D
var _reveal_light: PointLight2D
var _beam_poly: Polygon2D
var _eyes_root: Node2D
var _eyes: Array[Node2D] = []
var _info: Label
var _fade: ColorRect
var _busy := false


func _ready() -> void:
	_build_world()
	_build_fx()
	_build_ui()
	_fade.color.a = 1.0
	create_tween().tween_property(_fade, "color:a", 0.0, 0.9)
	# espera um frame para o layout dos botões ficar pronto
	await get_tree().process_frame
	if not _buttons.is_empty():
		_buttons[0].grab_focus()


func _process(delta: float) -> void:
	_time += delta
	_update_beam()
	_blink_eyes()


# -------------------------------------------------------------------- mundo

func _build_world() -> void:
	_world = Node2D.new()
	add_child(_world)

	_ambient = CanvasModulate.new()
	_ambient.color = FOCUS[0]["ambient"]
	_world.add_child(_ambient)

	# chão
	_add_rect(Vector2(-10.0, GROUND_Y), Vector2(500.0, 80.0), Color(0.30, 0.24, 0.22))

	# ruínas ao fundo
	for b in BUILDINGS:
		var building: Vector3 = b
		var shade := 0.85 + 0.15 * sin(building.x)
		_add_rect(Vector2(building.x, GROUND_Y - building.z), Vector2(building.y, building.z),
				Color(0.34 * shade, 0.32 * shade, 0.42 * shade))

	# engrenagens (aparecem com "Configurações")
	_world.add_child(_gear(Vector2(305.0, 125.0), 14.0, Color(0.50, 0.42, 0.30)))
	_world.add_child(_gear(Vector2(326.0, 138.0), 9.0, Color(0.44, 0.36, 0.26)))

	# ecos (aparecem com "Créditos")
	for echo_x in [250.0, 282.0]:
		_world.add_child(_echo(Vector2(float(echo_x), GROUND_Y - 9.0)))

	# o herói olhando para o raio de luz (a arte atual não tem a vista de costas)
	_world.add_child(_hero(Vector2(390.0, GROUND_Y - 52.5)))

	# luz de "revelação": se move conforme a opção
	_reveal_light = PointLight2D.new()
	_reveal_light.texture = _radial_texture()
	_reveal_light.color = Color(1.0, 0.72, 0.42)
	_reveal_light.energy = 0.0
	_reveal_light.position = FOCUS[0]["reveal"]
	_reveal_light.texture_scale = FOCUS[0]["scale"]
	_world.add_child(_reveal_light)

	# o raio: uma luz em cone apontada para o botão
	_beam_light = PointLight2D.new()
	_beam_light.texture = _cone_texture()
	_beam_light.color = Color(1.0, 0.82, 0.55)
	_beam_light.energy = 0.0
	_beam_light.position = beam_origin
	_world.add_child(_beam_light)


func _add_rect(pos: Vector2, size: Vector2, color: Color) -> void:
	var poly := Polygon2D.new()
	poly.color = color
	poly.polygon = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)])
	poly.position = pos
	_world.add_child(poly)


func _gear(center: Vector2, radius: float, color: Color) -> Polygon2D:
	var points := PackedVector2Array()
	var teeth := 10
	for i in teeth * 2:
		var angle := TAU * float(i) / float(teeth * 2)
		var r := radius if i % 2 == 0 else radius * 0.72
		points.append(Vector2(cos(angle), sin(angle)) * r)
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = color
	poly.position = center
	return poly


func _echo(pos: Vector2) -> Node2D:
	var root := Node2D.new()
	root.position = pos
	var body := Polygon2D.new()
	body.color = Color(0.55, 0.65, 0.85, 0.7)
	var points := PackedVector2Array()
	for i in 14:
		var angle := TAU * float(i) / 14.0
		points.append(Vector2(cos(angle) * 9.0, sin(angle) * 13.0 * (0.85 + 0.15 * sin(angle * 3.0))))
	body.polygon = points
	root.add_child(body)
	for eye_x in [-3.5, 1.5]:
		var eye := ColorRect.new()
		eye.color = Color(1.0, 0.95, 0.8)
		eye.size = Vector2(2.0, 3.0)
		eye.position = Vector2(float(eye_x), -4.0)
		root.add_child(eye)
	return root


func _hero(pos: Vector2) -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 5.0)
	frames.set_animation_loop("idle", true)
	for i in 4:
		frames.add_frame("idle", load(HERO_FRAMES % i))
	var hero := AnimatedSprite2D.new()
	hero.sprite_frames = frames
	hero.flip_h = true
	hero.scale = Vector2(3.0, 3.0)
	hero.position = pos
	hero.play("idle")
	return hero


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


## Textura em cone: a ponta fica no centro e o feixe abre para a direita.
func _cone_texture() -> ImageTexture:
	var size := 256
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	for y in size:
		for x in size:
			var d := Vector2(float(x), float(y)) - center
			var v := 0.0
			if d.x > 0.0:
				var angle := absf(atan2(d.y, d.x))
				var edge := 1.0 - smoothstep(beam_half_angle * 0.25, beam_half_angle, angle)
				var fade := 1.0 - clampf(d.x / (size * 0.5), 0.0, 1.0)
				v = edge * (0.35 + 0.65 * fade)
			image.set_pixel(x, y, Color(v, v, v, v))
	return ImageTexture.create_from_image(image)


# ----------------------------------------------------------------- efeitos
# O raio visível e os olhos ficam numa camada própria, para a luz ambiente
# escura (CanvasModulate) não apagá-los.

func _build_fx() -> void:
	var fx := CanvasLayer.new()
	fx.layer = 1
	add_child(fx)

	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_beam_poly = Polygon2D.new()
	_beam_poly.material = additive
	fx.add_child(_beam_poly)

	_eyes_root = Node2D.new()
	_eyes_root.modulate.a = 0.0
	fx.add_child(_eyes_root)
	for spot in EYE_SPOTS:
		var pair := Node2D.new()
		pair.position = spot
		for eye_x in [0.0, 6.0]:
			var eye := ColorRect.new()
			eye.color = Color(0.95, 0.1, 0.1)
			eye.size = Vector2(2.0, 3.0)
			eye.position = Vector2(float(eye_x), 0.0)
			pair.add_child(eye)
		_eyes_root.add_child(pair)
		_eyes.append(pair)


func _update_beam() -> void:
	var to := beam_target - beam_origin
	var length := maxf(to.length(), 1.0)
	var flicker := 1.0 + 0.04 * sin(_time * 11.0) + 0.02 * sin(_time * 27.0)

	_beam_light.position = beam_origin
	_beam_light.rotation = to.angle()
	_beam_light.texture_scale = length / 128.0 * 1.15
	_beam_light.energy = beam_energy * beam_strength * flicker

	var dir := to / length
	var normal := dir.orthogonal()
	var half_width := length * tan(beam_half_angle) * 0.9
	var near := Color(1.0, 0.85, 0.55, 0.0)
	var far := Color(1.0, 0.85, 0.55, 0.20 * beam_strength * flicker)
	_beam_poly.polygon = PackedVector2Array([
		beam_origin + normal * 4.0, beam_origin - normal * 4.0,
		beam_target - normal * half_width, beam_target + normal * half_width])
	_beam_poly.vertex_colors = PackedColorArray([near, near, far, far])


func _blink_eyes() -> void:
	for i in _eyes.size():
		_eyes[i].visible = fmod(_time * 0.6 + float(i) * 1.3, 4.0) > 0.18


# ---------------------------------------------------------------------- UI

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 2
	add_child(ui)

	var title := Label.new()
	title.text = game_title
	title.position = Vector2(16.0, 10.0)
	title.add_theme_font_size_override("font_size", title_font_size)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.78))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	title.add_theme_constant_override("outline_size", 3)
	ui.add_child(title)

	var box := VBoxContainer.new()
	box.position = menu_position
	box.add_theme_constant_override("separation", button_spacing)
	ui.add_child(box)
	for i in options.size():
		var button := Button.new()
		button.text = options[i]
		_setup_button(button, i)
		box.add_child(button)
		_buttons.append(button)

	_info = Label.new()
	_info.position = menu_position + Vector2(0.0, 6.0 + options.size() * (button_font_size + 14.0))
	_info.add_theme_font_size_override("font_size", 10)
	_info.add_theme_color_override("font_color", Color(0.7, 0.65, 0.78))
	_info.modulate.a = 0.0
	ui.add_child(_info)

	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 3
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _setup_button(button: Button, index: int) -> void:
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", button_font_size)

	# estilo vazio (sem bordas); a margem esquerda é animada para o botão "andar" para a direita
	var style := StyleBoxEmpty.new()
	style.content_margin_left = 0.0
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, style)
	_styles[button] = style

	var highlight := dark_focus_color if index == options.size() - 1 else focus_color
	button.add_theme_color_override("font_color", normal_color)
	for color_name in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(color_name, highlight)

	button.mouse_entered.connect(button.grab_focus)
	button.focus_entered.connect(_on_focus.bind(index))
	button.focus_exited.connect(_shift.bind(button, 0.0))
	button.pressed.connect(_on_pressed.bind(index))


func _shift(button: Button, target: float) -> void:
	var style: StyleBoxEmpty = _styles[button]
	if _shift_tweens.has(button) and (_shift_tweens[button] as Tween).is_valid():
		(_shift_tweens[button] as Tween).kill()
	var tween := create_tween()
	tween.tween_property(style, "content_margin_left", target, 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_shift_tweens[button] = tween


## O botão ganhou o foco: o raio vai até ele e a luz de revelação muda de lugar.
func _on_focus(index: int) -> void:
	var button := _buttons[index]
	_shift(button, shift_px)

	var data: Dictionary = FOCUS[mini(index, FOCUS.size() - 1)]
	var target := button.global_position + button.size * 0.5

	if _focus_tween and _focus_tween.is_valid():
		_focus_tween.kill()
	_focus_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_focus_tween.tween_property(self, "beam_target", target, move_time)
	_focus_tween.tween_property(self, "beam_strength", float(data["beam"]), move_time)
	_focus_tween.tween_property(_ambient, "color", data["ambient"], move_time)
	_focus_tween.tween_property(_reveal_light, "position", data["reveal"], move_time)
	_focus_tween.tween_property(_reveal_light, "texture_scale", float(data["scale"]), move_time)
	_focus_tween.tween_property(_reveal_light, "energy", float(data["energy"]), move_time)
	_focus_tween.tween_property(_eyes_root, "modulate:a", float(data["eyes"]), move_time)


func _on_pressed(index: int) -> void:
	if _busy:
		return
	match index:
		0:
			_start_game()
		1, 2:
			_say("Em breve.")
		3:
			_busy = true
			var tween := create_tween()
			tween.tween_property(_fade, "color:a", 1.0, 0.5)
			await tween.finished
			get_tree().quit()


func _start_game() -> void:
	_busy = true
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.6)
	await tween.finished
	get_tree().change_scene_to_file(GAME_SCENE)


func _say(text: String) -> void:
	_info.text = text
	_info.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(_info, "modulate:a", 0.0, 0.4)

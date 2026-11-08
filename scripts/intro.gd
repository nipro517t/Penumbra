extends Node2D
## Cutscene de abertura (~17 s): o herói atravessa a cidade já destruída, andando para a
## direita, em direção à escuridão. Ele para, olha para a frente e o título aparece.
##
## Tudo é construído por código e depende só do TEMPO (_t), então pular é só acelerar o fim.
## Pular: segurar Enter / Espaço / ✕ / Esc / ○ por ~0,7 s.
##
## A fala da voz (opcional) fica vazia: escreva em `opening_line` no Inspetor.

## Cena que abre depois da cutscene.
@export_file("*.tscn") var next_scene := "res://scenes/main_cap1.tscn"
@export var game_title := "Penumbra"
## Uma linha curta da voz em vermelho (deixe vazio para não mostrar nada).
@export var opening_line := ""
## Altura (y da tela) do chão onde o herói pisa.
@export var ground_y := 240.0
## Velocidade da câmera (px/s) enquanto o herói anda; os planos de fundo andam uma fração disso.
@export var camera_speed := 60.0
## Posição do herói na tela (x): começa fora da tela e para aqui.
@export var hero_start_x := -30.0
@export var hero_stop_x := 150.0
## Velocidade da animação de corrida (1.0 = a do jogo). Menor parece uma caminhada.
@export var hero_anim_scale := 0.7

@export_group("Tempos (s)")
@export var t_fade_in := 1.2
@export var t_walk_start := 0.6
@export var t_stop := 11.0
@export var t_dark_start := 2.5
@export var t_title := 11.8
@export var t_end := 17.5
@export var skip_hold_time := 0.7

## [arquivo, fração do movimento da câmera, opacidade]
const LAYERS := [
	["sky", 0.0, 1.0],
	["city4plan", 0.05, 1.0],
	["city3plan", 0.1, 1.0],
	["city2plan", 0.2, 1.0],
	["city1plan", 0.4, 1.0],
	["smog1", 0.5, 0.55],
]
const CITY_DIR := "res://assets/background/city/"
const HERO_DIR := "res://assets/player/adventurer/adventurer-"
## O herói entra na cena depois deste plano (para a névoa passar por cima dele).
const HERO_AFTER_LAYER := 4
const EYE_SPOTS := [
	Vector2(330.0, 82.0), Vector2(438.0, 120.0), Vector2(372.0, 170.0),
	Vector2(300.0, 214.0), Vector2(440.0, 232.0),
]
## Escuridão que fecha pela direita (o lado para onde o herói caminha).
const DARK_SHADER := """
shader_type canvas_item;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.04, 0.035, 0.07, 1.0);
void fragment() {
	float front = mix(1.2, 0.4, amount);
	float a = smoothstep(front, front + 0.4, UV.x);
	COLOR = vec4(tint.rgb, clamp(a * 0.96 + 0.18 * amount, 0.0, 0.97));
}
"""

var _t := 0.0
var _hold := 0.0
var _armed := false
var _leaving := false
var _finished := false
var _out_start := 0.0
var _out_end := 0.0
var _scroll := 0.0

var _layers: Array = []
var _hero: AnimatedSprite2D
var _dark: ColorRect
var _eyes: Array[Node2D] = []
var _eyes_root: Node2D
var _title: Label
var _voice: Label
var _hint: Label
var _fade: ColorRect


func _ready() -> void:
	_out_start = t_end - 1.0
	_out_end = t_end
	_build_world()
	_build_overlays()
	_process(0.0)


func _build_world() -> void:
	var world := Node2D.new()
	add_child(world)
	for i in LAYERS.size():
		var info: Array = LAYERS[i]
		var tex := load(CITY_DIR + String(info[0]) + ".png") as Texture2D
		if tex == null:
			push_warning("intro: textura não encontrada: %s%s.png" % [CITY_DIR, info[0]])
		else:
			var sprite := Sprite2D.new()
			sprite.centered = false
			sprite.texture = tex
			sprite.region_enabled = true
			sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.modulate.a = float(info[2])
			world.add_child(sprite)
			_layers.append({"sprite": sprite, "fx": float(info[1])})
		if i == HERO_AFTER_LAYER:
			_build_hero(world)


func _build_hero(parent: Node) -> void:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	for entry in [["idle", 4, 6.0], ["run", 6, 12.0]]:
		var anim_name: String = entry[0]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, float(entry[2]))
		frames.set_animation_loop(anim_name, true)
		for n in int(entry[1]):
			var tex := load("%s%s-%02d.png" % [HERO_DIR, anim_name, n]) as Texture2D
			if tex != null:
				frames.add_frame(anim_name, tex)
	_hero = AnimatedSprite2D.new()
	_hero.sprite_frames = frames
	_hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hero.position = Vector2(hero_start_x, ground_y - 17.5)  # pé na linha 36 do quadro 50x37
	parent.add_child(_hero)
	_hero.play(&"run")


func _build_overlays() -> void:
	var size := get_viewport_rect().size

	# escuridão que fecha pela direita
	var dark_layer := CanvasLayer.new()
	dark_layer.layer = 1
	add_child(dark_layer)
	var shader := Shader.new()
	shader.code = DARK_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	_dark = ColorRect.new()
	_dark.size = size
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dark.material = material
	dark_layer.add_child(_dark)

	# olhos vermelhos na escuridão (vermelho vivo só para olhos)
	var eyes_layer := CanvasLayer.new()
	eyes_layer.layer = 2
	add_child(eyes_layer)
	_eyes_root = Node2D.new()
	_eyes_root.modulate.a = 0.0
	eyes_layer.add_child(_eyes_root)
	for spot in EYE_SPOTS:
		var pair := Node2D.new()
		pair.position = spot
		for eye_x in [0.0, 6.0]:
			var eye := ColorRect.new()
			eye.color = Color(0.9, 0.1, 0.1)
			eye.size = Vector2(2.0, 3.0)
			eye.position = Vector2(float(eye_x), 0.0)
			pair.add_child(eye)
		_eyes_root.add_child(pair)
		_eyes.append(pair)

	# textos
	var text_layer := CanvasLayer.new()
	text_layer.layer = 3
	add_child(text_layer)
	_title = Label.new()
	_title.text = game_title
	_title.position = Vector2(24.0, 40.0)
	_title.size = Vector2(240.0, 44.0)
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.78))
	_title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	_title.add_theme_constant_override("outline_size", 4)
	_title.modulate.a = 0.0
	text_layer.add_child(_title)

	_voice = Label.new()
	_voice.text = opening_line
	_voice.position = Vector2(0.0, 24.0)
	_voice.size = Vector2(size.x, 20.0)
	_voice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_voice.add_theme_font_size_override("font_size", 11)
	_voice.add_theme_color_override("font_color", Color(0.88, 0.13, 0.18))
	_voice.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	_voice.add_theme_constant_override("outline_size", 3)
	_voice.visible_ratio = 0.0
	text_layer.add_child(_voice)

	_hint = Label.new()
	_hint.text = "Segure Enter ou ✕ para pular"
	_hint.position = Vector2(size.x - 180.0, size.y - 16.0)
	_hint.size = Vector2(172.0, 12.0)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override("font_size", 8)
	_hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	_hint.modulate.a = 0.0
	text_layer.add_child(_hint)

	# preto por cima de tudo (entrada e saída)
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 4
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.size = size
	_fade.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(_fade)


func _process(delta: float) -> void:
	_t += delta
	_update_skip(delta)

	# 0 = parado, 1 = andando: acelera no começo e freia antes de t_stop
	var walking := smoothstep(t_walk_start, t_walk_start + 1.5, _t) * (1.0 - smoothstep(t_stop - 2.0, t_stop, _t))
	_scroll += camera_speed * walking * delta

	var view := get_viewport_rect().size
	for layer in _layers:
		var sprite: Sprite2D = layer["sprite"]
		var tex_h := float(sprite.texture.get_height())
		sprite.region_rect = Rect2(
			roundf(_scroll * float(layer["fx"])), maxf(tex_h - view.y, 0.0), view.x, view.y)

	# o herói anda na tela até hero_stop_x e depois fica parado, olhando para a direita
	var walk_progress := smoothstep(t_walk_start, t_stop, _t)
	_hero.position.x = roundf(lerpf(hero_start_x, hero_stop_x, walk_progress))
	_hero.speed_scale = hero_anim_scale
	var anim := &"run" if _t < t_stop else &"idle"
	if _hero.animation != anim:
		_hero.play(anim)
	if anim == &"idle":
		_hero.speed_scale = 1.0

	var dark := smoothstep(t_dark_start, t_stop, _t)
	(_dark.material as ShaderMaterial).set_shader_parameter("amount", dark)
	_eyes_root.modulate.a = smoothstep(0.55, 1.0, dark) * 0.85
	for i in _eyes.size():
		_eyes[i].visible = fmod(_t * 0.6 + float(i) * 1.3, 4.0) > 0.18

	_title.modulate.a = smoothstep(t_title, t_title + 1.5, _t)
	if opening_line != "":
		_voice.visible_ratio = smoothstep(6.0, 8.5, _t)
		_voice.modulate.a = 1.0 - smoothstep(t_stop - 1.0, t_stop, _t)

	_fade.color.a = maxf(1.0 - smoothstep(0.0, t_fade_in, _t), smoothstep(_out_start, _out_end, _t))
	if _t >= _out_end:
		_finish()


## Segurar o botão por skip_hold_time pula a cutscene. Só vale depois de soltar o botão
## uma vez (o Enter do menu ainda pode estar apertado quando a cena abre).
func _update_skip(delta: float) -> void:
	if _leaving:
		return
	var pressed := false
	for action in ["ui_accept", "ui_cancel", "jump"]:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			pressed = true
	if not _armed:
		if not pressed:
			_armed = true
		return
	_hold = _hold + delta if pressed else maxf(_hold - delta * 2.0, 0.0)
	_hint.modulate.a = 0.3 + 0.7 * clampf(_hold / skip_hold_time, 0.0, 1.0)
	if _hold >= skip_hold_time:
		_leaving = true
		_out_start = _t
		_out_end = _t + 0.6


func _finish() -> void:
	if _finished:
		return
	_finished = true
	set_process(false)
	GameState.set_flag("intro_vista")
	get_tree().change_scene_to_file(next_scene)

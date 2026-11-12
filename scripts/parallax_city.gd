extends Node2D
## Fundo em camadas (skyline) com parallax. Feito por script para não depender
## de onde a câmera começa. Fica atrás de tudo (z_index negativo) e, por estar no
## canvas padrão, escurece com o CanvasModulate e recebe as luzes do jogo.
##
## Cada camada: [textura, velocidade X, velocidade Y, opacidade, primeiro plano?]
## Velocidade 0 = parada na tela; 1 = anda junto com o mundo. Camadas longe = valores baixos.

const LAYERS := [
	["res://assets/background/city/sky.png", 0.0, 0.0, 1.0, false],
	["res://assets/background/city/city4plan.png", 0.06, 0.05, 1.0, false],
	["res://assets/background/city/city3plan.png", 0.12, 0.08, 1.0, false],
	["res://assets/background/city/city2plan.png", 0.2, 0.12, 1.0, false],
	["res://assets/background/city/far_machines.png", 0.25, 0.14, 1.0, false],
	["res://assets/background/city/city1plan.png", 0.3, 0.16, 1.0, false],
	["res://assets/background/city/smog1.png", 0.4, 0.2, 0.55, false],
	["res://assets/background/city/cables.png", 0.45, 0.2, 1.0, false],
	# Primeiro plano (quinto valor = true): anda mais rápido que o mundo e fica NA FRENTE de tudo.
	["res://assets/background/city/foliage_front.png", 1.2, 0.0, 1.0, true],
]
## z_index das camadas de primeiro plano (maior que o do herói e dos blocos).
@export var foreground_z_index := 10
## Altura (y do mundo) em que a câmera costuma ficar com o herói no chão.
@export var reference_camera_y := 190.0
@export var base_z_index := -50

var _sprites: Array[Sprite2D] = []


func _ready() -> void:
	# Atualiza DEPOIS da câmera no mesmo quadro; senão o fundo anda 1 quadro atrasado e parece travado.
	process_priority = 1000
	for i in LAYERS.size():
		var info: Array = LAYERS[i]
		var tex := load(info[0]) as Texture2D
		if tex == null:
			push_warning("parallax_city: textura não encontrada: %s" % info[0])
			continue
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture = tex
		sprite.region_enabled = true
		sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_index = foreground_z_index if bool(info[4]) else base_z_index + i
		sprite.modulate.a = float(info[3])
		sprite.set_meta("fx", float(info[1]))
		sprite.set_meta("fy", float(info[2]))
		add_child(sprite)
		_sprites.append(sprite)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var center := camera.get_screen_center_position()
	var view := get_viewport_rect().size
	for sprite in _sprites:
		var tex := sprite.texture
		var max_y := maxf(float(tex.get_height()) - view.y, 0.0)
		var y0 := clampf(max_y + (center.y - reference_camera_y) * float(sprite.get_meta("fy")), 0.0, max_y)
		sprite.global_position = center - view * 0.5
		sprite.region_rect = Rect2(
			center.x * float(sprite.get_meta("fx")), y0, view.x, view.y)

extends Area2D
## Item de luz (opcional): um objeto brilhante no chão. Chegar perto mostra "[E] Pegar";
## pegar liga o efeito "no talo" (light_item_effect.gd) até o herói passar pelo ponto de
## quebra (light_item_zone.gd, tipo BREAK). Tudo é construído por código.
## Flags no GameState: pegou_item_luz.
## O nó fica com a origem no CHÃO (coloque a posição na altura do piso).

@export var prompt_text := "Pegar"
## Falas ao pegar (as falas são suas; estas são só marcadores).
@export var pick_lines: Array[String] = ["(V1-A: fala ao pegar o item — edite no Inspetor)"]
@export var glow_color := Color(1.0, 0.8, 0.45)

const EFFECT := preload("res://scripts/light_item_effect.gd")

var _player: Player = null
var _prompt: Label
var _orb: Node2D


func _ready() -> void:
	if GameState.get_flag("pegou_item_luz"):
		queue_free()
		return
	collision_layer = 0
	collision_mask = 1

	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	shape_node.shape = circle
	shape_node.position = Vector2(0.0, -14.0)
	add_child(shape_node)

	_orb = Node2D.new()
	_orb.position = Vector2(0.0, -16.0)
	add_child(_orb)
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(0, -6), Vector2(4, 0), Vector2(0, 6), Vector2(-4, 0)])
	body.color = glow_color.lightened(0.4)
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	body.material = unshaded
	_orb.add_child(body)

	var light := PointLight2D.new()
	light.texture = _radial_texture()
	light.color = glow_color
	light.energy = 1.0
	light.texture_scale = 0.55
	_orb.add_child(light)

	var bob := create_tween().set_loops()
	bob.tween_property(_orb, "position:y", -19.0, 0.9).set_trans(Tween.TRANS_SINE)
	bob.tween_property(_orb, "position:y", -13.0, 0.9).set_trans(Tween.TRANS_SINE)

	# o aviso fica numa camada de interface (não é escurecido pelo CanvasModulate da fase)
	var hud := CanvasLayer.new()
	hud.layer = 8
	add_child(hud)
	_prompt = Label.new()
	_prompt.text = "[E / Triângulo] %s" % prompt_text
	_prompt.add_theme_font_size_override("font_size", 10)
	_prompt.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	_prompt.position = Vector2(0.0, 214.0)
	_prompt.size = Vector2(480.0, 16.0)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.modulate.a = 0.0
	hud.add_child(_prompt)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player = body
		create_tween().tween_property(_prompt, "modulate:a", 1.0, 0.15)


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
		create_tween().tween_property(_prompt, "modulate:a", 0.0, 0.15)


func _process(_delta: float) -> void:
	if _player == null or _player.controls_locked or not _player.is_on_floor():
		return
	if Input.is_action_just_pressed("interact"):
		_pick()


func _pick() -> void:
	var player := _player
	_player = null
	set_process(false)
	GameState.set_flag("pegou_item_luz")
	var effect = EFFECT.new()
	player.add_child(effect)
	effect.start(player)
	for line in pick_lines:
		GameState.say(line)
	queue_free()


func _radial_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture

extends CanvasLayer
## Criaturas de olhos vermelhos nas bordas da tela + vinheta, reagindo à sanidade.
## Ao zerar a sanidade, as criaturas "pulam", a tela escurece e o herói volta ao checkpoint.

const HIDDEN_PX := -26.0
const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv) * 1.7;
	float v = smoothstep(0.3, 1.0, d) * intensity;
	COLOR = vec4(0.08, 0.0, 0.02, v);
}
"""
## pos = ponto na borda (0 a 1), dir = direção para dentro da tela, stage = estágio em que aparece.
const SLOTS := [
	{"pos": Vector2(0.0, 0.25), "dir": Vector2(1.0, 0.0), "stage": 1},
	{"pos": Vector2(1.0, 0.70), "dir": Vector2(-1.0, 0.0), "stage": 1},
	{"pos": Vector2(0.15, 1.0), "dir": Vector2(0.0, -1.0), "stage": 2},
	{"pos": Vector2(0.85, 0.0), "dir": Vector2(0.0, 1.0), "stage": 2},
	{"pos": Vector2(0.0, 0.75), "dir": Vector2(1.0, 0.0), "stage": 3},
	{"pos": Vector2(1.0, 0.20), "dir": Vector2(-1.0, 0.0), "stage": 3},
	{"pos": Vector2(0.60, 1.0), "dir": Vector2(0.0, -1.0), "stage": 3},
	{"pos": Vector2(0.40, 0.0), "dir": Vector2(0.0, 1.0), "stage": 3},
]

@export var body_radius := 13.0
@export var eye_color := Color(0.9, 0.1, 0.1)
@export var catch_time := 0.45

var _player: Player
var _sanity: SanityComponent
var _stage := 0
var _time := 0.0
var _catching := false
var _creatures: Array[Node2D] = []
var _inward: Array[float] = []
var _vignette_mat: ShaderMaterial
var _fade: ColorRect


func _ready() -> void:
	layer = 10
	_build_vignette()
	_build_creatures()
	_build_fade()
	_connect_player()


func _process(delta: float) -> void:
	_time += delta
	var ratio := _sanity.ratio() if _sanity else 1.0
	_vignette_mat.set_shader_parameter("intensity", clampf(1.0 - ratio, 0.0, 1.0) * 0.85)
	if _catching:
		return
	for i in _creatures.size():
		var slot: Dictionary = SLOTS[i]
		var slot_stage: int = slot["stage"]
		var target := HIDDEN_PX
		if _stage >= slot_stage:
			target = 6.0 + float(_stage - slot_stage) * 14.0
		_inward[i] = lerpf(_inward[i], target, minf(delta * 2.5, 1.0))
	_place_creatures()


# ------------------------------------------------------------ construção

func _build_vignette() -> void:
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = shader
	rect.material = _vignette_mat
	add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_creatures() -> void:
	var root := Node2D.new()
	root.name = "Creatures"
	add_child(root)
	for _slot in SLOTS:
		var creature := Node2D.new()
		var body := Polygon2D.new()
		body.color = Color(0.02, 0.0, 0.03, 0.95)
		body.polygon = _blob(body_radius)
		creature.add_child(body)
		for eye_x in [-4.5, 3.0]:
			var eye := ColorRect.new()
			eye.color = eye_color
			eye.size = Vector2(2.0, 3.0)
			eye.position = Vector2(float(eye_x), -3.0)
			eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
			creature.add_child(eye)
		root.add_child(creature)
		_creatures.append(creature)
		_inward.append(HIDDEN_PX)
	_place_creatures()


func _build_fade() -> void:
	_fade = ColorRect.new()
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _blob(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := 14
	for i in count:
		var angle := TAU * float(i) / float(count)
		var r := radius * (0.8 + 0.2 * sin(angle * 3.0 + 1.0))
		points.append(Vector2(cos(angle), sin(angle)) * r)
	return points


func _connect_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player == null:
		return
	_sanity = _player.get_node("Sanity") as SanityComponent
	_sanity.stage_changed.connect(_on_stage_changed)
	_sanity.broke.connect(_on_broke)


# ---------------------------------------------------------- comportamento

func _place_creatures() -> void:
	var size := get_viewport().get_visible_rect().size
	for i in _creatures.size():
		var slot: Dictionary = SLOTS[i]
		var edge: Vector2 = slot["pos"]
		var dir: Vector2 = slot["dir"]
		var base := Vector2(edge.x * size.x, edge.y * size.y)
		var sway := dir.orthogonal() * sin(_time * 1.4 + float(i) * 1.7) * 3.0
		_creatures[i].position = base + dir * _inward[i] + sway


func _on_stage_changed(new_stage: int) -> void:
	_stage = new_stage


func _on_broke() -> void:
	if _catching or _player == null:
		return
	_catching = true
	_player.controls_locked = true

	# as criaturas "pulam" em direção ao herói
	var center := get_viewport().get_visible_rect().size * 0.5
	var jump := create_tween().set_parallel(true)
	for creature in _creatures:
		jump.tween_property(creature, "position", center, catch_time) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		jump.tween_property(creature, "scale", Vector2(3.0, 3.0), catch_time)
	await jump.finished

	await _fade_to(1.0, 0.25)
	GameState.respawn(_player)
	_player.controls_locked = true  # segue travado durante o fade
	_reset_creatures()
	await get_tree().create_timer(0.35).timeout
	_catching = false
	await _fade_to(0.0, 0.5)
	_player.controls_locked = false


func _reset_creatures() -> void:
	for i in _creatures.size():
		_creatures[i].scale = Vector2.ONE
		_inward[i] = HIDDEN_PX
	_place_creatures()


func _fade_to(alpha: float, time: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, time)
	await tween.finished

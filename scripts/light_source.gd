class_name LightSource
extends Area2D
## Fonte de luz: recarrega a brasa, recupera a sanidade e vira checkpoint.
## O herói só conta como "na luz" se estiver dentro da zona E houver linha de visão
## (nenhuma parede, chão ou teto entre a lâmpada e ele).

@export var refill_per_second := 60.0
@export var is_checkpoint := true
## Onde o herói reaparece em relação à fonte (acima do chão).
@export var checkpoint_offset := Vector2(0.0, -14.0)
## Raio da zona de efeito, como fração do raio do brilho visual da luz.
@export_range(0.2, 1.0) var zone_ratio := 0.7
## Pontos do corpo do herói usados na linha de visão (basta um deles estar visível).
@export var sight_offsets: Array[Vector2] = [Vector2(0.0, -10.0), Vector2.ZERO, Vector2(0.0, 10.0)]

## Otimização: a luz (com sombra) só é desenhada quando está perto da tela.
## Isso NÃO afeta a zona de efeito (recarga, sanidade, checkpoint), só o desenho.
@export var cull_lights := true
## Folga extra (px) além da borda da tela antes de apagar a luz.
@export var cull_margin := 60.0

var _cull_timer := 0.0
var _player_ref: Node2D

@onready var light: PointLight2D = $PointLight2D
@onready var zone: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	body_exited.connect(_on_body_exited)
	light.shadow_enabled = true
	_fit_zone()


## Ajusta a zona ao tamanho do brilho (cada instância ganha o seu próprio círculo).
func _fit_zone() -> void:
	var circle := zone.shape as CircleShape2D
	if circle == null or light.texture == null:
		return
	circle = circle.duplicate() as CircleShape2D
	zone.shape = circle
	circle.radius = light.texture.get_width() * 0.5 * light.texture_scale * zone_ratio
	zone.position = light.position


func _process(delta: float) -> void:
	if not cull_lights:
		return
	_cull_timer -= delta
	if _cull_timer > 0.0:
		return
	_cull_timer = 0.15
	if _player_ref == null or not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as Node2D
		if _player_ref == null:
			return
	var reach := 0.0
	if light.texture:
		reach = light.texture.get_width() * 0.5 * light.texture_scale
	var half := get_viewport_rect().size * 0.5
	var d := (light.global_position - _player_ref.global_position).abs()
	light.visible = d.x < half.x + reach + cull_margin and d.y < half.y + reach + cull_margin


func _physics_process(delta: float) -> void:
	for body in get_overlapping_bodies():
		var player := body as Player
		if player == null:
			continue
		var lit := _has_line_of_sight(player)
		player.set_lit_by(self, lit)
		if lit:
			player.ember.refill(refill_per_second * delta)
			if is_checkpoint:
				var checkpoint_pos := global_position + checkpoint_offset
				if GameState.checkpoint != checkpoint_pos:
					AudioManager.play("lamp")
				GameState.set_checkpoint(checkpoint_pos)


func _on_body_exited(body: Node2D) -> void:
	var player := body as Player
	if player:
		player.set_lit_by(self, false)


func _has_line_of_sight(player: Player) -> bool:
	var space := get_world_2d().direct_space_state
	for offset in sight_offsets:
		var query := PhysicsRayQueryParameters2D.create(
			light.global_position, player.global_position + offset, 1)
		query.exclude = [player.get_rid()]
		if space.intersect_ray(query).is_empty():
			return true
	return false

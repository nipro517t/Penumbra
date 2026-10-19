class_name EnemyShadow
extends CharacterBody2D
## Rastejador de sombra: patrulha, persegue o herói de perto e tira sanidade ao encostar.
## Camadas: corpo = 2 (não bloqueia o herói), hurtbox = 3 (o golpe do herói a enxerga).

signal died

enum State { PATROL, CHASE, HURT, DEAD }

@export var max_health := 4
## Sanidade que o herói perde ao ser tocado.
@export var contact_damage := 15.0
@export var patrol_speed := 28.0
@export var chase_speed := 62.0
@export var patrol_range := 70.0
## Distância horizontal e vertical em que enxerga o herói.
@export var sight_range := 120.0
@export var sight_height := 40.0
@export var gravity := 900.0
@export var knockback := Vector2(130.0, -80.0)
@export var hit_stun_time := 0.3
@export var eye_color := Color(0.95, 0.1, 0.1)

var state: State = State.PATROL
var health := 0

var _dir := 1.0
var _origin_x := 0.0
var _stun := 0.0
var _time := 0.0
var _player: Player
var _visual: Node2D
var _flash: Polygon2D

@onready var contact_area: Area2D = $ContactArea


func _ready() -> void:
	health = max_health
	_origin_x = global_position.x
	_player = get_tree().get_first_node_in_group("player") as Player
	_build_visual()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_time += delta
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, 400.0)

	match state:
		State.PATROL:
			_patrol_step()
		State.CHASE:
			_chase_step()
		State.HURT:
			_stun -= delta
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			if _stun <= 0.0:
				state = State.CHASE

	move_and_slide()
	_check_contact()
	_update_visual()


# ------------------------------------------------------------- comportamento

func _patrol_step() -> void:
	velocity.x = _dir * patrol_speed
	var too_far := absf(global_position.x - _origin_x) > patrol_range \
			and signf(global_position.x - _origin_x) == _dir
	if is_on_wall() or not _ground_ahead() or too_far:
		_dir = -_dir
	if _can_see_player():
		state = State.CHASE


func _chase_step() -> void:
	if _player == null:
		state = State.PATROL
		return
	var dx := _player.global_position.x - global_position.x
	var dy := absf(_player.global_position.y - global_position.y)
	if absf(dx) > sight_range * 1.6 or dy > sight_height * 2.0:
		state = State.PATROL
		_origin_x = global_position.x
		return
	if absf(dx) > 2.0:
		_dir = signf(dx)
	if _ground_ahead() and not is_on_wall():
		velocity.x = _dir * chase_speed
	else:
		velocity.x = 0.0


func _can_see_player() -> bool:
	if _player == null:
		return false
	var delta_pos := _player.global_position - global_position
	return absf(delta_pos.x) <= sight_range and absf(delta_pos.y) <= sight_height


func _ground_ahead() -> bool:
	var from := global_position + Vector2(_dir * 10.0, 0.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 16.0), 1)
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _check_contact() -> void:
	if state == State.DEAD or state == State.HURT:
		return
	for body in contact_area.get_overlapping_bodies():
		var player := body as Player
		if player:
			player.take_damage(contact_damage, global_position)


# ---------------------------------------------------------------------- dano

## Chamado pelo golpe do herói. Retorna true se este golpe matou o inimigo.
func take_hit(damage: int, from: Vector2) -> bool:
	if state == State.DEAD:
		return false
	health -= damage
	_flash_white()
	var away := signf(global_position.x - from.x)
	if away == 0.0:
		away = 1.0
	velocity = Vector2(away * knockback.x, knockback.y)
	if health <= 0:
		_die()
		return true
	state = State.HURT
	_stun = hit_stun_time
	return false


func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
	$ContactArea/CollisionShape2D.set_deferred("disabled", true)
	died.emit()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_visual, "modulate:a", 0.0, 0.35)
	tween.tween_property(_visual, "scale", Vector2(1.4, 0.2), 0.35)
	await tween.finished
	queue_free()


func _flash_white() -> void:
	_flash.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(_flash, "modulate:a", 0.0, 0.12)


# ---------------------------------------------------------------------- visual

func _update_visual() -> void:
	_visual.scale.x = _dir if _dir != 0.0 else 1.0
	_visual.position.y = -2.0 + sin(_time * 9.0) * 0.8 * float(absf(velocity.x) > 5.0)


## Silhueta preta com contorno vermelho escuro e olhos brilhantes (sem asset de arte).
func _build_visual() -> void:
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

	_visual = Node2D.new()
	_visual.position = Vector2(0.0, -2.0)
	add_child(_visual)

	var points := _blob(11.0, 8.0)
	var body := Polygon2D.new()
	body.color = Color(0.0, 0.0, 0.0, 1.0)
	body.polygon = points
	_visual.add_child(body)

	var outline := Line2D.new()
	outline.points = points
	outline.closed = true
	outline.width = 1.0
	outline.default_color = Color(0.5, 0.08, 0.2, 1.0)
	outline.material = unshaded
	_visual.add_child(outline)

	for eye_x in [2.0, 6.5]:
		var eye := ColorRect.new()
		eye.color = eye_color
		eye.size = Vector2(2.0, 3.0)
		eye.position = Vector2(float(eye_x), -3.0)
		eye.material = unshaded
		_visual.add_child(eye)

	_flash = Polygon2D.new()
	_flash.color = Color(1.0, 1.0, 1.0, 1.0)
	_flash.polygon = points
	_flash.material = unshaded
	_flash.modulate.a = 0.0
	_visual.add_child(_flash)


func _blob(radius_x: float, radius_y: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := 14
	for i in count:
		var angle := TAU * float(i) / float(count)
		var wobble := 0.85 + 0.15 * sin(angle * 3.0 + 1.0)
		points.append(Vector2(cos(angle) * radius_x, sin(angle) * radius_y) * wobble)
	return points

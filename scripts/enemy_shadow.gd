class_name EnemyShadow
extends CharacterBody2D
## Rastejador de sombra: patrulha, persegue o herói de perto e tira sanidade ao encostar.
## Camadas: corpo = 2 (não bloqueia o herói), hurtbox = 3 (o golpe do herói a enxerga).
##
## ESTADOS: PATROL (anda perto do ponto inicial) → CHASE (persegue ao enxergar o herói)
## → RECOIL (recua depois de ferir) | HURT (atordoado ao levar um golpe) | DEAD.
## O dano no herói é por contato (_check_contact → Player.take_damage). O herói o machuca
## chamando take_hit(), que o Player encontra pela área "Hurtbox" (camada 3).

signal died

enum State { PATROL, CHASE, HURT, RECOIL, DEAD }

## Arte provisória (monster pack 2, recolorida): folhas de células 48x48.
const SHEET_BODY := "res://assets/enemies/shadow/shadow_body.png"
const SHEET_EYES := "res://assets/enemies/shadow/shadow_eyes.png"
const CELL := 48
## nome: [linha da folha, nº de quadros, quadros por segundo, repete?]
const ANIMS := {
	"idle": [0, 8, 8.0, true],
	"walk": [1, 8, 10.0, true],
	"attack": [4, 8, 14.0, false],
	"death": [2, 10, 12.0, false],
}

@export var max_health := 4
## Sanidade que o herói perde ao ser tocado.
@export var contact_damage := 15.0
@export var patrol_speed := 28.0
@export var chase_speed := 62.0
@export var patrol_range := 70.0
## Distância horizontal e vertical em que enxerga o herói.
@export var sight_range := 120.0
@export var sight_height := 40.0
## Depois de ferir o herói, o inimigo recua e espera antes de poder ferir de novo.
@export var attack_cooldown := 1.0
@export var recoil_time := 0.45
@export var recoil_speed := 55.0
@export var gravity := 900.0
@export var knockback := Vector2(130.0, -80.0)
@export var hit_stun_time := 0.3
@export var eye_color := Color(0.95, 0.1, 0.1)

var state: State = State.PATROL
var health := 0

var _dir := 1.0
var _origin_x := 0.0
var _stun := 0.0
var _recoil := 0.0
var _contact_cd := 0.0
var _time := 0.0
var _player: Player
var _visual: Node2D
var _body: AnimatedSprite2D
var _eyes: AnimatedSprite2D
var _flash: AnimatedSprite2D
var _anim: StringName = &""

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
	_contact_cd = maxf(_contact_cd - delta, 0.0)
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, 400.0)

	match state:
		State.PATROL:
			_patrol_step()
		State.CHASE:
			_chase_step()
		State.RECOIL:
			_recoil_step(delta)
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


func _recoil_step(delta: float) -> void:
	_recoil -= delta
	var away := -_dir
	if _player:
		away = signf(global_position.x - _player.global_position.x)
		if away == 0.0:
			away = -_dir
	velocity.x = away * recoil_speed if _ground_ahead_for(away) else 0.0
	if _recoil <= 0.0:
		state = State.CHASE


func _can_see_player() -> bool:
	if _player == null:
		return false
	var delta_pos := _player.global_position - global_position
	return absf(delta_pos.x) <= sight_range and absf(delta_pos.y) <= sight_height


func _ground_ahead() -> bool:
	return _ground_ahead_for(_dir)


func _ground_ahead_for(direction: float) -> bool:
	var from := global_position + Vector2(direction * 10.0, 0.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 16.0), 1)
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _check_contact() -> void:
	if state == State.DEAD or state == State.HURT or state == State.RECOIL or _contact_cd > 0.0:
		return
	for body in contact_area.get_overlapping_bodies():
		var player := body as Player
		if player and player.take_damage(contact_damage, global_position):
			# acertou o herói: recua e espera antes de poder ferir de novo
			_contact_cd = attack_cooldown
			_recoil = recoil_time
			state = State.RECOIL
			return


# ---------------------------------------------------------------------- dano

## Chamado pelo golpe do herói. Retorna true se este golpe matou o inimigo.
func take_hit(damage: int, from: Vector2) -> bool:
	if state == State.DEAD:
		return false
	health -= damage
	_flash_white()
	AudioManager.play("enemy_die" if health <= 0 else "enemy_hit")
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
	_play(&"death")
	await _body.animation_finished
	var tween := create_tween()
	tween.tween_property(_visual, "modulate:a", 0.0, 0.3)
	await tween.finished
	queue_free()


func _flash_white() -> void:
	_flash.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(_flash, "modulate:a", 0.0, 0.12)


# ---------------------------------------------------------------------- visual

func _update_visual() -> void:
	_visual.scale.x = _dir if _dir != 0.0 else 1.0
	if state == State.RECOIL:
		_play(&"attack")
	elif absf(velocity.x) > 5.0:
		_play(&"walk")
	else:
		_play(&"idle")


## Toca a mesma animação no corpo, nos olhos e no clarão, para ficarem sincronizados.
func _play(anim: StringName) -> void:
	if anim == _anim:
		return
	_anim = anim
	_body.play(anim)
	_eyes.play(anim)
	_flash.play(anim)


func _make_frames(sheet: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	for anim_name in ANIMS:
		var info: Array = ANIMS[anim_name]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, float(info[2]))
		frames.set_animation_loop(anim_name, bool(info[3]))
		for i in int(info[1]):
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(i * CELL, int(info[0]) * CELL, CELL, CELL)
			frames.add_frame(anim_name, atlas)
	return frames


## Corpo escuro (recebe luz e sombra) + olhos sem luz (brilham no escuro) + clarão branco ao levar golpe.
func _build_visual() -> void:
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

	var flash_shader := Shader.new()
	flash_shader.code = "shader_type canvas_item;\nrender_mode unshaded;\nvoid fragment() { COLOR = vec4(1.0, 1.0, 1.0, COLOR.a); }\n"
	var flash_material := ShaderMaterial.new()
	flash_material.shader = flash_shader

	var body_frames := _make_frames(load(SHEET_BODY) as Texture2D)
	var eyes_frames := _make_frames(load(SHEET_EYES) as Texture2D)

	# O pé da arte (linha 31 da célula) cai na base da cápsula (y = +8) com o sprite centrado.
	_visual = Node2D.new()
	add_child(_visual)

	_body = AnimatedSprite2D.new()
	_body.sprite_frames = body_frames
	_visual.add_child(_body)

	_eyes = AnimatedSprite2D.new()
	_eyes.sprite_frames = eyes_frames
	_eyes.modulate = eye_color
	_eyes.material = unshaded
	_visual.add_child(_eyes)

	_flash = AnimatedSprite2D.new()
	_flash.sprite_frames = body_frames
	_flash.material = flash_material
	_flash.modulate.a = 0.0
	_visual.add_child(_flash)

	_play(&"idle")

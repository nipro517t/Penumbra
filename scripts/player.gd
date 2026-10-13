class_name Player
extends CharacterBody2D
## Herói: corrida, pulo, parede, quinas, agachar/deslizar e dash movido a brasa.

signal dashed

enum State { IDLE, RUN, JUMP, FALL, WALL_SLIDE, CROUCH, SLIDE, DASH, LEDGE_HANG, LEDGE_CLIMB }

@export_group("Movimento")
@export var max_speed := 140.0
@export var acceleration := 1200.0
@export var friction := 1400.0
@export var air_control := 0.7

@export_group("Pulo")
@export var jump_velocity := -300.0
@export var gravity := 900.0
@export var fall_gravity_multiplier := 1.4
@export var jump_cut_multiplier := 0.5
@export var max_fall_speed := 400.0
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.1

@export_group("Parede")
@export var wall_slide_speed := 45.0
@export var wall_jump_velocity := Vector2(150.0, -280.0)
## Tempo sem controle horizontal logo após um pulo na parede.
@export var wall_jump_lock_time := 0.15
@export var wall_coyote_time := 0.1

@export_group("Agachar e Deslizar")
@export var crouch_speed := 50.0
## Altura da cápsula agachado (precisa ser >= 2x o raio da cápsula).
@export var crouch_height := 20.0
@export var slide_speed := 230.0
@export var slide_friction := 350.0

@export_group("Dash")
@export var dash_speed := 320.0
@export var dash_duration := 0.16
@export var dash_cooldown := 0.3
@export var dash_ember_cost := 25.0
## Velocidade horizontal mantida ao terminar o dash.
@export var dash_exit_speed := 170.0
@export var dash_invincible := true
## No chão, o dash vira um deslize (usa a animação de slide e a colisão baixa).
@export var dash_slides_on_ground := true

@export_group("Quina")
@export var ledge_enabled := true
## Quantos px abaixo do topo da quina fica a origem do herói ao se pendurar.
@export var ledge_hang_offset := 4.0
@export var ledge_climb_time := 0.4
## Tempo sem poder agarrar de novo depois de soltar ou subir.
@export var ledge_regrab_delay := 0.25

@export_group("Visual")
## Ajuste vertical (px) por animação, para os pés baterem na base da colisão.
@export var anim_y_offset := {"fall": 4.0, "wall_slide": 2.0}

@export_group("Luz")
@export var light_min_scale := 0.3
@export var light_max_scale := 0.75
@export var light_min_energy := 0.35
@export var light_max_energy := 1.1

var state: State = State.IDLE
var facing := 1
## Use isto no sistema de dano (passo 7): ignore golpes enquanto for true.
var invincible := false
## Quantas fontes de luz o herói está tocando agora (> 0 = na luz).
var light_zones := 0
## Travado durante cenas (ex.: quando as criaturas pegam o herói).
var controls_locked := false
## Onde a cena começou; usado como respawn se ainda não houver checkpoint.
var spawn_position := Vector2.ZERO

var _coyote_timer := 0.0
var _buffer_timer := 0.0
var _wall_coyote_timer := 0.0
var _wall_side := 0  # -1 = parede à esquerda, 1 = à direita, 0 = nenhuma
var _last_wall_side := 0
var _lock_timer := 0.0
var _dash_timer := 0.0
var _dash_cooldown_timer := 0.0
var _dash_dir := 1
var _afterimage_timer := 0.0
var _crouched := false
var _dash_on_ground := false
var _sprite_base_y := 0.0
var _radius := 6.0
var _ledge_dir := 1
var _ledge_wall_x := 0.0
var _ledge_top_y := 0.0
var _ledge_cooldown := 0.0
var _climb_t := 0.0
var _climb_from := Vector2.ZERO
var _climb_to := Vector2.ZERO
var _stand_height := 28.0
var _stand_shape_y := 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shape_node: CollisionShape2D = $CollisionShape2D
@onready var ember: EmberComponent = $Ember
@onready var light: PointLight2D = $PointLight2D
@onready var sanity: SanityComponent = $Sanity
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	var capsule := shape_node.shape as CapsuleShape2D
	_stand_height = capsule.height
	_stand_shape_y = shape_node.position.y
	_sprite_base_y = sprite.position.y
	_radius = capsule.radius
	spawn_position = global_position
	_ensure_slide_action()


func _physics_process(delta: float) -> void:
	if controls_locked:
		_locked_step(delta)
		return

	var dir := Input.get_axis("move_left", "move_right")
	_tick_timers(delta)

	match state:
		State.DASH:
			_dash_step(delta)
		State.LEDGE_HANG:
			_ledge_hang_step(dir)
		State.LEDGE_CLIMB:
			_ledge_climb_step(delta)
		_:
			if not _try_start_dash(dir):
				_move_step(delta, dir)

	if state != State.LEDGE_HANG and state != State.LEDGE_CLIMB:
		move_and_slide()
	_apply_crouch_shape()
	_update_animation()
	_update_light()


## Sem controle: só gravidade e atrito (usado quando as criaturas pegam o herói).
func _locked_step(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	move_and_slide()
	state = State.IDLE if is_on_floor() else State.FALL
	_apply_crouch_shape()
	_update_animation()
	_update_light()


# ---------------------------------------------------------------- timers

func _tick_timers(delta: float) -> void:
	var on_floor := is_on_floor()
	_coyote_timer = coyote_time if on_floor else _coyote_timer - delta

	if Input.is_action_just_pressed("jump"):
		_buffer_timer = jump_buffer_time
	else:
		_buffer_timer -= delta

	_lock_timer = maxf(_lock_timer - delta, 0.0)
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	_ledge_cooldown = maxf(_ledge_cooldown - delta, 0.0)

	_wall_side = _detect_wall()
	if _wall_side != 0 and not on_floor:
		_last_wall_side = _wall_side
		_wall_coyote_timer = wall_coyote_time
	else:
		_wall_coyote_timer -= delta


func _detect_wall() -> int:
	if test_move(global_transform, Vector2(-2.0, 0.0)):
		return -1
	if test_move(global_transform, Vector2(2.0, 0.0)):
		return 1
	return 0


# ------------------------------------------------------------ movimento

func _move_step(delta: float, dir: float) -> void:
	var stuck_low := _crouched and not _can_stand()

	if dir != 0.0 and _lock_timer <= 0.0 and state != State.SLIDE:
		facing = 1 if dir > 0.0 else -1

	# gravidade (mais forte na queda)
	if not is_on_floor():
		var g := gravity * (fall_gravity_multiplier if velocity.y > 0.0 else 1.0)
		velocity.y = minf(velocity.y + g * delta, max_fall_speed)

	# deslizar na parede: caindo, encostado e segurando em direção a ela
	var wall_sliding := false
	if not is_on_floor() and _wall_side != 0 and velocity.y > 0.0 and dir * _wall_side > 0.0:
		wall_sliding = true
		velocity.y = minf(velocity.y, wall_slide_speed)

	# pulo e pulo na parede
	if _buffer_timer > 0.0 and not stuck_low:
		if _coyote_timer > 0.0:
			_start_jump()
		elif _wall_coyote_timer > 0.0:
			_start_wall_jump()
			wall_sliding = false
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier

	var on_ground := is_on_floor() and velocity.y >= 0.0
	var want_crouch := Input.is_action_pressed("crouch") or stuck_low

	# estado
	if on_ground:
		if state == State.SLIDE:
			velocity.x = move_toward(velocity.x, 0.0, slide_friction * delta)
			if absf(velocity.x) <= crouch_speed:
				state = State.CROUCH if want_crouch else State.IDLE
		elif Input.is_action_just_pressed("slide"):
			var slide_dir: int = int(signf(velocity.x)) if absf(velocity.x) > 5.0 else facing
			facing = slide_dir
			velocity.x = slide_dir * maxf(absf(velocity.x), slide_speed)
			state = State.SLIDE
		elif want_crouch:
			state = State.CROUCH
		else:
			state = State.RUN if absf(velocity.x) > 5.0 else State.IDLE
	elif wall_sliding:
		state = State.WALL_SLIDE
	else:
		state = State.JUMP if velocity.y < 0.0 else State.FALL

	# controle horizontal
	if _lock_timer <= 0.0 and state != State.SLIDE:
		var speed_cap := crouch_speed if state == State.CROUCH else max_speed
		var control := 1.0 if on_ground else air_control
		if dir != 0.0:
			velocity.x = move_toward(velocity.x, dir * speed_cap, acceleration * control * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * control * delta)

	# agarrar quina: no ar, subindo devagar ou caindo, segurando em direção à parede
	if ledge_enabled and not on_ground and _ledge_cooldown <= 0.0 and _lock_timer <= 0.0 \
			and velocity.y >= -30.0 and dir * float(facing) > 0.0:
		var ledge := _find_ledge()
		if not ledge.is_empty():
			_start_ledge_hang(ledge)


func _start_jump() -> void:
	velocity.y = jump_velocity
	_buffer_timer = 0.0
	_coyote_timer = 0.0
	state = State.JUMP


func _start_wall_jump() -> void:
	velocity = Vector2(-_last_wall_side * wall_jump_velocity.x, wall_jump_velocity.y)
	facing = -_last_wall_side
	_lock_timer = wall_jump_lock_time
	_buffer_timer = 0.0
	_wall_coyote_timer = 0.0
	_coyote_timer = 0.0
	state = State.JUMP


# ---------------------------------------------------------------- quina

func _raycast(from: Vector2, to: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from, to, collision_mask)
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query)


## Procura uma quina na frente do herói: a parede aparece na altura do peito e
## o espaço acima da cabeça está livre. Retorna {} ou {"wall_x", "top_y"}.
func _find_ledge() -> Dictionary:
	var d := float(facing)
	var reach := _radius + 3.0
	var head := -_stand_height * 0.5
	var chest := global_position + Vector2(0.0, head + 7.0)
	var chest_hit := _raycast(chest, chest + Vector2(d * reach, 0.0))
	if chest_hit.is_empty():
		return {}
	var above := global_position + Vector2(0.0, head - 5.0)
	if not _raycast(above, above + Vector2(d * reach, 0.0)).is_empty():
		return {}
	var wall_x: float = chest_hit["position"].x
	var probe_x := wall_x + d * 2.0
	var top_hit := _raycast(
		Vector2(probe_x, global_position.y + head - 10.0),
		Vector2(probe_x, global_position.y + head + 14.0))
	if top_hit.is_empty():
		return {}
	return {"wall_x": wall_x, "top_y": float(top_hit["position"].y)}


func _start_ledge_hang(ledge: Dictionary) -> void:
	_ledge_dir = facing
	_ledge_wall_x = float(ledge["wall_x"])
	_ledge_top_y = float(ledge["top_y"])
	velocity = Vector2.ZERO
	global_position = Vector2(
		_ledge_wall_x - _ledge_dir * (_radius + 0.5),
		_ledge_top_y + _stand_height * 0.5 + ledge_hang_offset)
	_buffer_timer = 0.0
	state = State.LEDGE_HANG


func _climb_target() -> Vector2:
	return Vector2(
		_ledge_wall_x + _ledge_dir * (_radius + 2.0),
		_ledge_top_y - _stand_height * 0.5 - 0.5)


## Há espaço para subir (primeiro para cima, depois para frente)?
func _can_climb() -> bool:
	var to := _climb_target()
	var up := Vector2(0.0, to.y - global_position.y)
	if test_move(global_transform, up):
		return false
	var raised := global_transform.translated(up)
	return not test_move(raised, Vector2(to.x - global_position.x, 0.0))


func _ledge_hang_step(dir: float) -> void:
	velocity = Vector2.ZERO
	facing = _ledge_dir
	if Input.is_action_just_pressed("jump") and _can_climb():
		_climb_from = global_position
		_climb_to = _climb_target()
		_climb_t = 0.0
		state = State.LEDGE_CLIMB
	elif Input.is_action_just_pressed("crouch") or dir * float(_ledge_dir) < -0.5:
		_drop_from_ledge(dir)


func _drop_from_ledge(dir: float) -> void:
	_ledge_cooldown = ledge_regrab_delay
	var push := 0.0
	if dir * float(_ledge_dir) < 0.0:
		push = dir * 40.0
	velocity = Vector2(push, 20.0)
	state = State.FALL


func _ledge_climb_step(delta: float) -> void:
	velocity = Vector2.ZERO
	_climb_t += delta / ledge_climb_time
	var t := clampf(_climb_t, 0.0, 1.0)
	# primeiro sobe, depois avança por cima da quina
	var up_t := clampf(t / 0.6, 0.0, 1.0)
	var forward_t := clampf((t - 0.6) / 0.4, 0.0, 1.0)
	global_position = Vector2(
		lerpf(_climb_from.x, _climb_to.x, forward_t),
		lerpf(_climb_from.y, _climb_to.y, up_t))
	if _climb_t >= 1.0:
		global_position = _climb_to
		_ledge_cooldown = ledge_regrab_delay
		state = State.IDLE


# ----------------------------------------------------------------- dash

func _try_start_dash(dir: float) -> bool:
	if not Input.is_action_just_pressed("dash"):
		return false
	var d: int = int(signf(dir)) if dir != 0.0 else facing
	if _dash_cooldown_timer > 0.0 or _wall_side == d:
		return false
	if not ember.spend(dash_ember_cost):
		return false

	_dash_dir = d
	facing = d
	_dash_on_ground = dash_slides_on_ground and is_on_floor()
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_duration + dash_cooldown
	_afterimage_timer = 0.0
	_lock_timer = 0.0
	invincible = dash_invincible
	velocity = Vector2(d * dash_speed, 0.0)
	state = State.DASH
	dashed.emit()
	return true


func _dash_step(delta: float) -> void:
	_dash_timer -= delta
	velocity = Vector2(_dash_dir * dash_speed, 0.0)

	_afterimage_timer -= delta
	if _afterimage_timer <= 0.0:
		_spawn_afterimage()
		_afterimage_timer = 0.03

	# pular durante o dash cancela o dash e mantém o impulso
	if _buffer_timer > 0.0 and _coyote_timer > 0.0 and _can_stand():
		_end_dash()
		_start_jump()
		velocity.x = _dash_dir * dash_speed * 0.85
		return

	if _dash_timer <= 0.0 or _wall_side == _dash_dir:
		_end_dash()


func _end_dash() -> void:
	invincible = false
	velocity.x = _dash_dir * dash_exit_speed
	state = State.FALL if not is_on_floor() else State.IDLE


## Rastro do dash: copia o frame atual e faz sumir (não precisa de asset de dash).
func _spawn_afterimage() -> void:
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if tex == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = tex
	ghost.flip_h = sprite.flip_h
	ghost.modulate = Color(1.0, 0.65, 0.25, 0.6)
	ghost.z_index = -1
	get_parent().add_child(ghost)
	ghost.global_position = sprite.global_position
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tween.tween_callback(ghost.queue_free)


# ------------------------------------------------------ agachar (colisão)

func _can_stand() -> bool:
	if not _crouched:
		return true
	return not test_move(global_transform, Vector2(0.0, -(_stand_height - crouch_height)))


func _apply_crouch_shape() -> void:
	var want := state == State.CROUCH or state == State.SLIDE \
			or (state == State.DASH and _dash_on_ground)
	if want == _crouched:
		return
	if want or _can_stand():
		_set_crouched(want)


func _set_crouched(value: bool) -> void:
	_crouched = value
	var capsule := shape_node.shape as CapsuleShape2D
	var h := crouch_height if value else _stand_height
	capsule.height = h
	# mantém os pés no mesmo lugar
	shape_node.position.y = _stand_shape_y + (_stand_height - h) * 0.5


# ------------------------------------------------------- visual e luz

func _update_animation() -> void:
	# os frames originais olham para a direita; o wall slide olha para a esquerda
	if state == State.WALL_SLIDE:
		sprite.flip_h = _last_wall_side < 0
	else:
		sprite.flip_h = facing < 0

	var anim := "idle"
	match state:
		State.RUN: anim = "run"
		State.JUMP: anim = "jump"
		State.FALL: anim = "fall"
		State.WALL_SLIDE: anim = "wall_slide"
		State.CROUCH: anim = "crouch"
		State.SLIDE: anim = "slide"
		State.DASH: anim = "slide" if _dash_on_ground else "dash"
		State.LEDGE_HANG: anim = "ledge_hang"
		State.LEDGE_CLIMB: anim = "ledge_climb"
	if sprite.animation != anim:
		sprite.play(anim)
	sprite.position.y = _sprite_base_y + float(anim_y_offset.get(anim, 0.0))


func _update_light() -> void:
	var t := ember.ratio()
	light.energy = lerpf(light_min_energy, light_max_energy, t)
	light.texture_scale = lerpf(light_min_scale, light_max_scale, t)


# ------------------------------------------------------- luz e respawn

func enter_light() -> void:
	light_zones += 1


func exit_light() -> void:
	light_zones = maxi(light_zones - 1, 0)


func is_in_light() -> bool:
	return light_zones > 0


## Reaparece em "pos" com tudo restaurado (usado pelo checkpoint e pela zona de queda).
func respawn_at(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	state = State.IDLE
	invincible = false
	_dash_timer = 0.0
	_lock_timer = 0.0
	controls_locked = false
	ember.refill(ember.max_energy)
	sanity.restore()
	camera.reset_smoothing()


## Cria a ação "slide" caso ela não exista no Mapa de Entrada.
## (C ou Ctrl esquerdo no teclado; L1 ou L2 no controle de PS4.)
## Se preferir, crie a ação "slide" no Mapa de Entrada e esta função não faz nada.
func _ensure_slide_action() -> void:
	if InputMap.has_action("slide"):
		return
	InputMap.add_action("slide", 0.2)
	for keycode: Key in [KEY_C, KEY_CTRL]:
		var key := InputEventKey.new()
		key.physical_keycode = keycode
		InputMap.action_add_event("slide", key)
	var l1 := InputEventJoypadButton.new()
	l1.button_index = JOY_BUTTON_LEFT_SHOULDER
	InputMap.action_add_event("slide", l1)
	var l2 := InputEventJoypadMotion.new()
	l2.axis = JOY_AXIS_TRIGGER_LEFT
	l2.axis_value = 1.0
	InputMap.action_add_event("slide", l2)

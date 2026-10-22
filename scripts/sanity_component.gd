class_name SanityComponent
extends Node
## Sanidade do herói: cai fora das fontes de luz e recupera dentro delas.
## Ao chegar no marcador crítico a sanidade para de cair e a BRASA começa a queimar;
## quando a brasa acaba, a sanidade volta a cair até quebrar.
##
## FLUXO A CADA FRAME (_process):
##  1. Dentro da luz (com linha de visão) → recupera e sai do estado crítico.
##  2. No escuro e ACIMA do marcador crítico → cai, mas para no marcador.
##  3. No marcador e ainda com brasa → a BRASA queima e a sanidade fica parada
##     (é o "estado crítico": o jogador deve se curar ou chegar a uma luz).
##  4. No marcador e sem brasa → a sanidade volta a cair até zerar.
##  5. Zerou → emite `broke` (o ShadowEyes faz as criaturas "pegarem" o herói).
## Os ESTÁGIOS (1 a 3, por faixas de sanidade) aparecem em `stage_changed`.

signal changed(value: float, max_value: float)
signal stage_changed(stage: int)
signal critical_changed(is_critical: bool)
signal broke

@export var max_sanity := 100.0
@export var drain_per_second := 4.0
@export var recover_per_second := 30.0
## Desligue para pausar a sanidade (ex.: durante a cena do item de luz).
@export var enabled := true
## Marcador do estado crítico (fração da sanidade máxima).
@export_range(0.05, 0.9) var critical_ratio := 0.3
## Brasa queimada por segundo no estado crítico (se o jogador não se curar).
@export var critical_ember_per_second := 12.0
## Fração da sanidade em que começa cada estágio (do 1º ao 3º).
@export var stage_thresholds: Array[float] = [0.75, 0.5, 0.3]

var sanity := 0.0
var stage := 0

var _broken := false
var _critical := false

@onready var player: Player = get_parent() as Player


func _ready() -> void:
	sanity = max_sanity
	changed.emit(sanity, max_sanity)


func _process(delta: float) -> void:
	if _broken or not enabled or player == null:
		return

	if player.is_in_light():
		_set_critical(false)
		set_sanity(sanity + recover_per_second * delta)
		return

	var floor_value := max_sanity * critical_ratio
	var drain := drain_per_second * player.sanity_drain_multiplier() * delta
	if sanity > floor_value + 0.01:
		# no escuro: cai até o marcador crítico e para
		set_sanity(maxf(sanity - drain, floor_value))
		_set_critical(sanity <= floor_value + 0.01)
	else:
		# estado crítico: a brasa queima e segura a sanidade; sem brasa, ela cai
		_set_critical(true)
		if player.ember.drain(critical_ember_per_second * delta):
			return
		set_sanity(sanity - drain)


func set_sanity(value: float) -> void:
	sanity = clampf(value, 0.0, max_sanity)
	changed.emit(sanity, max_sanity)
	_update_stage()
	if sanity <= 0.0 and not _broken:
		_broken = true
		broke.emit()


func restore() -> void:
	_broken = false
	_set_critical(false)
	set_sanity(max_sanity)


func ratio() -> float:
	return sanity / max_sanity if max_sanity > 0.0 else 0.0


func is_critical() -> bool:
	return _critical


func _set_critical(value: bool) -> void:
	if value != _critical:
		_critical = value
		critical_changed.emit(_critical)


func _update_stage() -> void:
	var new_stage := 0
	var r := ratio()
	for threshold in stage_thresholds:
		if r <= threshold:
			new_stage += 1
	if sanity <= 0.0:
		new_stage = stage_thresholds.size() + 1
	if new_stage != stage:
		stage = new_stage
		stage_changed.emit(stage)

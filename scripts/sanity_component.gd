class_name SanityComponent
extends Node
## Sanidade do herói: cai fora das fontes de luz e recupera dentro delas.
## Os estágios (0 a 3) aumentam conforme a sanidade cai; no estágio 4 ela quebrou.

signal changed(value: float, max_value: float)
signal stage_changed(stage: int)
signal broke

@export var max_sanity := 100.0
@export var drain_per_second := 4.0
@export var recover_per_second := 30.0
## Desligue para pausar a sanidade (ex.: durante a cena do item de luz).
@export var enabled := true
## Fração da sanidade em que começa cada estágio (do 1º ao 3º).
@export var stage_thresholds: Array[float] = [0.75, 0.5, 0.25]

var sanity := 0.0
var stage := 0

var _broken := false

@onready var player: Player = get_parent() as Player


func _ready() -> void:
	sanity = max_sanity
	changed.emit(sanity, max_sanity)


func _process(delta: float) -> void:
	if _broken or not enabled or player == null:
		return
	if player.is_in_light():
		set_sanity(sanity + recover_per_second * delta)
	else:
		set_sanity(sanity - drain_per_second * delta)


func set_sanity(value: float) -> void:
	sanity = clampf(value, 0.0, max_sanity)
	changed.emit(sanity, max_sanity)
	_update_stage()
	if sanity <= 0.0 and not _broken:
		_broken = true
		broke.emit()


func restore() -> void:
	_broken = false
	set_sanity(max_sanity)


func ratio() -> float:
	return sanity / max_sanity if max_sanity > 0.0 else 0.0


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

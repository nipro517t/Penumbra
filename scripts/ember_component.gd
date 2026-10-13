class_name EmberComponent
extends Node
## Barra de brasa: alimenta o dash, drena com o tempo e recarrega em fontes de luz.

signal changed(value: float, max_value: float)
signal depleted

@export var max_energy := 100.0
@export var start_full := true
## Quanto a brasa perde por segundo quando "draining" está ligado.
@export var drain_per_second := 3.0
## Deixe desligado até a perseguição da escuridão começar (passo 6).
@export var draining := false

var energy := 0.0


func _ready() -> void:
	energy = max_energy if start_full else 0.0
	changed.emit(energy, max_energy)


func _process(delta: float) -> void:
	if draining and energy > 0.0:
		set_energy(energy - drain_per_second * delta)


## Gasta energia. Retorna false (sem gastar nada) se não houver o suficiente.
func spend(amount: float) -> bool:
	if energy < amount:
		return false
	set_energy(energy - amount)
	return true


## Gasta até "amount" (usado para gasto contínuo, por segundo). Retorna false se já estava vazia.
func drain(amount: float) -> bool:
	if energy <= 0.0:
		return false
	set_energy(energy - amount)
	return true


func refill(amount: float) -> void:
	set_energy(energy + amount)


func set_energy(value: float) -> void:
	var previous := energy
	energy = clampf(value, 0.0, max_energy)
	changed.emit(energy, max_energy)
	if previous > 0.0 and energy == 0.0:
		depleted.emit()


func ratio() -> float:
	return energy / max_energy if max_energy > 0.0 else 0.0

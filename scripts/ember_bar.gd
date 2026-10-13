extends CanvasLayer
## Barra de brasa na tela (canto superior esquerdo).

@onready var bar: ProgressBar = $Bar


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var ember := player.get_node("Ember") as EmberComponent
	ember.changed.connect(_on_changed)
	_on_changed(ember.energy, ember.max_energy)


func _on_changed(value: float, max_value: float) -> void:
	bar.max_value = max_value
	bar.value = value

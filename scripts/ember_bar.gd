extends CanvasLayer
## Barras de teste na tela: brasa (laranja) e sanidade (roxa).

@onready var bar: ProgressBar = $Bar
@onready var sanity_bar: ProgressBar = $SanityBar


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var ember := player.get_node("Ember") as EmberComponent
	ember.changed.connect(_on_ember_changed)
	_on_ember_changed(ember.energy, ember.max_energy)
	var sanity := player.get_node("Sanity") as SanityComponent
	sanity.changed.connect(_on_sanity_changed)
	_on_sanity_changed(sanity.sanity, sanity.max_sanity)


func _on_ember_changed(value: float, max_value: float) -> void:
	bar.max_value = max_value
	bar.value = value


func _on_sanity_changed(value: float, max_value: float) -> void:
	sanity_bar.max_value = max_value
	sanity_bar.value = value

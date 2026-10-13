extends CanvasLayer
## Barras de teste na tela: brasa (laranja) e sanidade (roxa) com o marcador crítico.

@onready var bar: ProgressBar = $Bar
@onready var sanity_bar: ProgressBar = $SanityBar
@onready var marker: ColorRect = $SanityBar/CriticalMarker

var _critical := false
var _time := 0.0


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var ember := player.get_node("Ember") as EmberComponent
	ember.changed.connect(_on_ember_changed)
	_on_ember_changed(ember.energy, ember.max_energy)
	var sanity := player.get_node("Sanity") as SanityComponent
	sanity.changed.connect(_on_sanity_changed)
	sanity.critical_changed.connect(func(value: bool) -> void: _critical = value)
	_on_sanity_changed(sanity.sanity, sanity.max_sanity)
	var width := sanity_bar.offset_right - sanity_bar.offset_left
	marker.position.x = width * sanity.critical_ratio


func _process(delta: float) -> void:
	_time += delta
	# pulsa em vermelho no estado crítico
	if _critical:
		var pulse := 0.5 + 0.5 * sin(_time * 9.0)
		sanity_bar.modulate = Color(1.0, 1.0 - 0.6 * pulse, 1.0 - 0.6 * pulse)
	else:
		sanity_bar.modulate = Color.WHITE


func _on_ember_changed(value: float, max_value: float) -> void:
	bar.max_value = max_value
	bar.value = value


func _on_sanity_changed(value: float, max_value: float) -> void:
	sanity_bar.max_value = max_value
	sanity_bar.value = value

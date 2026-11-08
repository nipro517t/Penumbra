extends CanvasLayer
## Barras de teste na tela: brasa (laranja) e sanidade (roxa) com o marcador crítico.

@onready var bar: TextureProgressBar = $Bar
@onready var sanity_bar: TextureProgressBar = $SanityBar
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
	# o preenchimento começa 2 px dentro da borda (texture_progress_offset)
	var fill_width := float(sanity_bar.texture_progress.get_width())
	marker.position.x = sanity_bar.texture_progress_offset.x + fill_width * sanity.critical_ratio - 0.5


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

extends Node
## Efeito do item de luz enquanto ele "funciona" (filho do Player, criado por light_item.gd).
## Tudo "no talo": sanidade parada e cheia, brasa sempre cheia, dash sem custo e um brilho
## quente em volta do herói. O efeito NÃO acaba sozinho: ele termina quando o herói passa
## pelo ponto de quebra (light_item_zone.gd chama finish()).

const GLOW_TEXTURE_SCALE := 1.1

var _player: Player
var _saved_dash_cost := 25.0
var _glow: PointLight2D


func start(player: Player) -> void:
	_player = player
	add_to_group("light_item_effect")
	_saved_dash_cost = player.dash_ember_cost
	player.dash_ember_cost = 0.0
	player.sanity.restore()
	player.sanity.enabled = false
	player.ember.set_energy(player.ember.max_energy)

	_glow = PointLight2D.new()
	_glow.texture = player.light.texture
	_glow.color = Color(1.0, 0.82, 0.5)
	_glow.energy = 0.0
	_glow.texture_scale = GLOW_TEXTURE_SCALE
	_glow.position = player.light.position
	_glow.shadow_enabled = true
	player.add_child(_glow)
	create_tween().tween_property(_glow, "energy", 1.0, 0.4)


func _process(_delta: float) -> void:
	if _player and is_instance_valid(_player):
		_player.ember.set_energy(_player.ember.max_energy)


## Quebra o item: tudo volta ao normal, sem punição extra.
func finish() -> void:
	remove_from_group("light_item_effect")
	if _player and is_instance_valid(_player):
		_player.dash_ember_cost = _saved_dash_cost
		_player.sanity.enabled = true
	if _glow:
		var tween := create_tween()
		tween.tween_property(_glow, "energy", 0.0, 0.5)
		tween.tween_callback(_glow.queue_free)
	set_process(false)
	# espera o brilho apagar antes de sair da árvore
	get_tree().create_timer(0.7).timeout.connect(queue_free)

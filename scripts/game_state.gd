extends Node
## Estado global do jogo (Autoload "GameState").
## Guarda o checkpoint atual, flags (ex.: pegou o item de luz) e finais já vistos,
## e salva/carrega em disco.

signal checkpoint_changed(position: Vector2)

const SAVE_PATH := "user://penumbra_save.json"

## Último checkpoint (uma fonte de luz). Vector2.INF = ainda não tem.
var checkpoint := Vector2.INF
var flags: Dictionary = {}
var endings: Array = []


func has_checkpoint() -> bool:
	return checkpoint != Vector2.INF


func set_checkpoint(pos: Vector2) -> void:
	if checkpoint == pos:
		return
	checkpoint = pos
	checkpoint_changed.emit(pos)


## Leva o herói de volta ao último checkpoint (ou ao ponto onde a cena começou).
func respawn(player: Player) -> void:
	var target := checkpoint if has_checkpoint() else player.spawn_position
	player.respawn_at(target)


func set_flag(key: String, value: Variant = true) -> void:
	flags[key] = value


func get_flag(key: String, default_value: Variant = false) -> Variant:
	return flags.get(key, default_value)


func unlock_ending(id: String) -> void:
	if not endings.has(id):
		endings.append(id)
		save_game()


## Mostra uma fala na caixa de voz (se existir na cena).
func say(text: String) -> void:
	var box := get_tree().get_first_node_in_group("voice_box")
	if box:
		box.say(text)


func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"flags": flags, "endings": endings}))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		flags = data.get("flags", {})
		endings = data.get("endings", [])

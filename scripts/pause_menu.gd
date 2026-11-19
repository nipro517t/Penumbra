extends Node
## Autoload "PauseMenu": menu de pausa e de configurações (volume e tela cheia).
## - Pausa: Esc (teclado) ou Start (controle), só durante o jogo (quando existe um Player
##   e ele não está travado por diálogo/captura).
## - As configurações também abrem pelo menu principal: PauseMenu.open_settings(callback).
## - Salva em user://penumbra_settings.cfg e aplica ao iniciar o jogo.
## A lista em si (navegação, desenho) está em list_menu.gd.

const ListMenu := preload("res://scripts/list_menu.gd")
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const SETTINGS_PATH := "user://penumbra_settings.cfg"

## Volume geral, de 0 a 100.
var volume := 100
var fullscreen := false

# listas sem tipo de propósito: são instâncias de list_menu.gd (chamadas dinâmicas)
var _pause_list = null
var _settings_list = null
var _settings_return: Callable = Callable()
var _fps_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_pause_action()
	_load_settings()
	_apply_settings(true)

	# contador de FPS (tecla F3), para medir o desempenho
	var fps_layer := CanvasLayer.new()
	fps_layer.layer = 100
	add_child(fps_layer)
	_fps_label = Label.new()
	_fps_label.position = Vector2(4.0, 2.0)
	_fps_label.add_theme_font_size_override("font_size", 8)
	_fps_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_fps_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	_fps_label.add_theme_constant_override("outline_size", 3)
	_fps_label.visible = false
	fps_layer.add_child(_fps_label)

	_settings_list = ListMenu.new()
	_settings_list.layer = 52
	_settings_list.title = "Configurações"
	_settings_list.hint = "Setas: navegar e ajustar   Enter: confirmar   Esc: voltar"
	_settings_list.dim_alpha = 0.8
	_settings_list.rows = [
		{
			"text": func() -> String: return "Volume geral: < %d%% >" % volume,
			"accept": _cycle_volume,
			"adjust": _adjust_volume,
		},
		{
			"text": func() -> String: return "Tela cheia: < %s >" % ("Sim" if fullscreen else "Não"),
			"accept": _toggle_fullscreen,
			"adjust": func(_dir: int) -> void: _toggle_fullscreen(),
		},
		{
			"text": func() -> String: return "Voltar",
			"accept": _close_settings,
		},
	]
	_settings_list.cancel = _close_settings
	add_child(_settings_list)

	_pause_list = ListMenu.new()
	_pause_list.layer = 51
	_pause_list.title = "Pausado"
	_pause_list.hint = "Esc / Start: continuar"
	_pause_list.dim_alpha = 0.7
	_pause_list.rows = [
		{"text": func() -> String: return "Continuar", "accept": _resume},
		{"text": func() -> String: return "Configurações", "accept": _open_settings_from_pause},
		{"text": func() -> String: return "Voltar ao menu", "accept": _to_main_menu},
		{"text": func() -> String: return "Sair do jogo", "accept": _quit_game},
	]
	_pause_list.cancel = _resume
	add_child(_pause_list)


func _process(_delta: float) -> void:
	if _fps_label.visible:
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F3:
		_fps_label.visible = not _fps_label.visible
		return
	if event.is_echo() or not event.is_action_pressed("pause"):
		return
	if get_tree().paused or _pause_list.is_open() or _settings_list.is_open():
		return
	# não reabre no mesmo aperto que acabou de fechar a pausa
	if Engine.get_process_frames() == _pause_list.last_hide_frame:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null or bool(player.get("controls_locked")):
		return
	get_viewport().set_input_as_handled()
	get_tree().paused = true
	_pause_list.open(0)


## Abre as configurações (ex.: pelo menu principal). `on_close` é chamado ao voltar.
func open_settings(on_close: Callable = Callable()) -> void:
	_settings_return = on_close
	_settings_list.open(0)


# ------------------------------------------------------------------ pausa

func _resume() -> void:
	_pause_list.hide_menu()
	get_tree().paused = false


func _open_settings_from_pause() -> void:
	_pause_list.hide_menu()
	open_settings(func() -> void: _pause_list.open(1))


func _to_main_menu() -> void:
	_pause_list.hide_menu()
	get_tree().paused = false
	Engine.time_scale = 1.0
	# voltar ao menu começa uma partida nova (checkpoint e flags zerados; ainda não há "Continuar")
	GameState.checkpoint = Vector2.INF
	GameState.flags.clear()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _quit_game() -> void:
	get_tree().quit()


# ------------------------------------------------------------------ configurações

func _close_settings() -> void:
	_settings_list.hide_menu()
	if _settings_return.is_valid():
		_settings_return.call()


func _adjust_volume(direction: int) -> void:
	volume = clampi(volume + direction * 10, 0, 100)
	_apply_and_save()


## Confirmar/clicar no volume: sobe de 10 em 10 e volta a 0 depois de 100.
func _cycle_volume() -> void:
	volume = 0 if volume >= 100 else volume + 10
	_apply_and_save()


func _toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	_apply_and_save()


func _apply_and_save() -> void:
	_apply_settings(false)
	_save_settings()


func _apply_settings(booting: bool) -> void:
	AudioServer.set_bus_mute(0, volume <= 0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume / 100.0, 0.0001)))
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not booting:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	volume = clampi(int(cfg.get_value("audio", "volume", 100)), 0, 100)
	fullscreen = bool(cfg.get_value("video", "fullscreen", false))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.save(SETTINGS_PATH)


## Cria a ação "pause" (Esc e Start) se ela ainda não existir no Mapa de Entrada.
func _ensure_pause_action() -> void:
	if InputMap.has_action("pause"):
		return
	InputMap.add_action("pause")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_ESCAPE
	InputMap.action_add_event("pause", key)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_START
	InputMap.action_add_event("pause", pad)

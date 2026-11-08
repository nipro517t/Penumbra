extends Node
## Autoload "AudioManager": toca os efeitos sonoros e o ambiente.
##
## COMO FUNCIONA
## - `AudioManager.play("jump")` toca o som de nome "jump".
## - Para cada nome, o script procura primeiro um ARQUIVO SEU em
##     res://assets/audio/sfx/<nome>.ogg  (ou .wav / .mp3)
##   Se não achar, usa um som PROVISÓRIO gerado por código (bipes simples), só para o
##   jogo não ficar mudo durante o desenvolvimento. Esses sons provisórios NÃO são arte
##   final: troque por sons seus colocando os arquivos com os mesmos nomes na pasta.
## - O ambiente (`ambient`) funciona igual, na pasta res://assets/audio/music/.
## - Quando um herói (grupo "player") entra na cena, o ambiente começa e os sinais do
##   herói (dash, dano, golpe, sanidade crítica, colapso) tocam seus sons sozinhos.
##
## NOMES USADOS: jump, wall_jump, land, step, dash, attack, hit, hurt, enemy_hit,
## enemy_die, heal, lamp, critical, collapse, ledge  e a música "ambient".

const RATE := 22050
const VOICES := 8

## nome: [onda, freq. inicial, freq. final, duração (s), volume 0..1, mistura de ruído 0..1, db, variação de tom]
## ondas: "square", "saw", "sine", "noise"
const RECIPES := {
	"jump": ["square", 260.0, 520.0, 0.12, 0.22, 0.0, -8.0, 0.05],
	"wall_jump": ["square", 200.0, 420.0, 0.14, 0.22, 0.1, -8.0, 0.05],
	"land": ["sine", 110.0, 50.0, 0.10, 0.5, 0.5, -8.0, 0.08],
	"step": ["noise", 0.0, 0.0, 0.04, 0.18, 1.0, -14.0, 0.15],
	"dash": ["saw", 700.0, 150.0, 0.16, 0.3, 0.6, -8.0, 0.05],
	"attack": ["saw", 500.0, 250.0, 0.10, 0.25, 0.7, -9.0, 0.10],
	"hit": ["square", 180.0, 60.0, 0.12, 0.45, 0.4, -5.0, 0.08],
	"hurt": ["saw", 150.0, 70.0, 0.25, 0.5, 0.5, -4.0, 0.03],
	"enemy_hit": ["saw", 300.0, 90.0, 0.10, 0.4, 0.3, -6.0, 0.08],
	"enemy_die": ["saw", 220.0, 40.0, 0.35, 0.45, 0.3, -5.0, 0.03],
	"heal": ["sine", 330.0, 660.0, 0.50, 0.35, 0.0, -8.0, 0.0],
	"lamp": ["sine", 520.0, 780.0, 0.35, 0.3, 0.0, -9.0, 0.0],
	"critical": ["sine", 70.0, 55.0, 0.25, 0.7, 0.0, -6.0, 0.0],
	"collapse": ["saw", 120.0, 30.0, 0.80, 0.5, 0.5, -4.0, 0.0],
	"ledge": ["sine", 200.0, 150.0, 0.06, 0.3, 0.5, -10.0, 0.05],
}

var _cache := {}
var _players: Array[AudioStreamPlayer] = []
var _ambient: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 12345
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_ambient = AudioStreamPlayer.new()
	_ambient.volume_db = -22.0
	add_child(_ambient)
	get_tree().node_added.connect(_on_node_added)


## Toca um efeito. `pitch` multiplica o tom (1.0 = normal); `db` soma ao volume.
func play(sfx_name: String, pitch: float = 1.0, db: float = 0.0) -> void:
	var stream := _get_stream("sfx", sfx_name)
	if stream == null:
		return
	var recipe: Array = RECIPES.get(sfx_name, [])
	var variation: float = recipe[7] if recipe.size() > 7 else 0.0
	var base_db: float = recipe[6] if recipe.size() > 6 else 0.0
	var voice := _free_voice()
	voice.stream = stream
	voice.pitch_scale = maxf(pitch * (1.0 + _rng.randf_range(-variation, variation)), 0.1)
	voice.volume_db = base_db + db
	voice.play()


## Liga o ambiente (música de fundo em loop).
func play_ambient(music_name: String = "ambient") -> void:
	var stream := _get_stream("music", music_name)
	if stream == null:
		return
	if _ambient.playing and _ambient.stream == stream:
		return
	_ambient.stream = stream
	_ambient.play()


func stop_ambient() -> void:
	_ambient.stop()


func _free_voice() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0]


# ---------------------------------------------------------------- ganchos do herói

func _on_node_added(node: Node) -> void:
	if node is Player:
		node.ready.connect(_hook_player.bind(node), CONNECT_ONE_SHOT)


func _hook_player(player: Player) -> void:
	player.dashed.connect(func() -> void: play("dash"))
	player.damaged.connect(func() -> void: play("hurt"))
	player.hit_enemy.connect(func() -> void: play("hit"))
	if player.sanity:
		player.sanity.critical_changed.connect(_on_critical_changed)
		player.sanity.broke.connect(_on_broke)
	player.tree_exited.connect(stop_ambient)
	play_ambient()


func _on_critical_changed(is_critical: bool) -> void:
	if is_critical:
		play("critical")


func _on_broke() -> void:
	play("collapse")


# ---------------------------------------------------------------- carregar ou gerar

func _get_stream(kind: String, sfx_name: String) -> AudioStream:
	var key := kind + "/" + sfx_name
	if _cache.has(key):
		return _cache[key]
	var stream: AudioStream = null
	for ext in ["ogg", "wav", "mp3"]:
		var path := "res://assets/audio/%s/%s.%s" % [kind, sfx_name, ext]
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
			break
	if stream == null:
		if kind == "sfx" and RECIPES.has(sfx_name):
			stream = _synth(RECIPES[sfx_name])
		elif kind == "music" and sfx_name == "ambient":
			stream = _make_drone()
	if stream is AudioStreamOggVorbis and kind == "music":
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3 and kind == "music":
		(stream as AudioStreamMP3).loop = true
	_cache[key] = stream
	return stream


## Sons provisórios: onda simples com deslize de frequência e queda de volume.
func _synth(recipe: Array) -> AudioStreamWAV:
	var wave: String = recipe[0]
	var f0: float = recipe[1]
	var f1: float = recipe[2]
	var dur: float = recipe[3]
	var vol: float = recipe[4]
	var noise_mix: float = recipe[5]
	var n := int(RATE * dur)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var phase := 0.0
	var attack := int(RATE * 0.004)
	for i in n:
		var t := float(i) / float(n)
		phase += lerpf(f0, f1, t) / float(RATE)
		var cycle := fmod(phase, 1.0)
		var v := 0.0
		match wave:
			"square":
				v = 1.0 if cycle < 0.5 else -1.0
			"saw":
				v = 2.0 * cycle - 1.0
			"sine":
				v = sin(TAU * phase)
			_:
				v = _rng.randf_range(-1.0, 1.0)
		if wave != "noise" and noise_mix > 0.0:
			v = lerpf(v, _rng.randf_range(-1.0, 1.0), noise_mix)
		var env := minf(1.0, float(i) / float(maxi(attack, 1))) * pow(1.0 - t, 2.0)
		bytes.encode_s16(i * 2, int(clampf(v * env * vol, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav


## Ambiente provisório: um zumbido grave que respira devagar (loop de 4 s sem emenda,
## porque todas as frequências têm um número inteiro de ciclos em 4 s).
func _make_drone() -> AudioStreamWAV:
	var seconds := 4.0
	var n := int(RATE * seconds)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var t := float(i) / float(RATE)
		var swell := 0.65 + 0.35 * sin(TAU * 0.25 * t)
		var v := 0.5 * sin(TAU * 55.0 * t) + 0.3 * sin(TAU * 82.5 * t) + 0.15 * sin(TAU * 164.5 * t)
		bytes.encode_s16(i * 2, int(clampf(v * swell * 0.5, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav

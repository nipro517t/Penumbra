extends CanvasLayer
## Caixa de voz em vermelho (estilo Carmen): mostra falas digitadas, uma por vez.

@export var chars_per_second := 30.0
@export var hold_time := 2.0
@export var fade_time := 0.4

var _queue: Array[String] = []
var _busy := false

@onready var label: Label = $Label


func _ready() -> void:
	add_to_group("voice_box")
	label.text = ""
	label.modulate.a = 0.0


func say(text: String) -> void:
	_queue.append(text)
	if not _busy:
		_run()


func say_lines(lines: Array) -> void:
	for line in lines:
		say(str(line))


func _run() -> void:
	_busy = true
	while not _queue.is_empty():
		var text: String = _queue.pop_front()
		label.text = text
		label.visible_ratio = 0.0
		label.modulate.a = 1.0
		var type_time := maxf(float(text.length()) / chars_per_second, 0.05)
		var typing := create_tween()
		typing.tween_property(label, "visible_ratio", 1.0, type_time)
		await typing.finished
		await get_tree().create_timer(hold_time).timeout
		var fade := create_tween()
		fade.tween_property(label, "modulate:a", 0.0, fade_time)
		await fade.finished
	_busy = false

extends Area2D
## Gatilhos da cena do item de luz (coloque um Area2D com CollisionShape2D e este script).
## BREAK:   ponto de quebra. Se o herói pegou o item, ele para de funcionar aqui (tudo volta
##          ao normal) e a voz comenta. Depois disso, apertar "interact" (por um tempo)
##          dispara a fala do "clique vazio". Quem não pegou o item não vê nada.
##          Ponha este gatilho um pouco ANTES da CorridorZone (ela também mexe na sanidade).
## IGNORED: logo depois do item. Se o herói passou direto sem pegar, a voz reage.
## Flags: item_luz_quebrou, ignorou_item_luz. As falas são marcadores: edite no Inspetor.

enum Kind { BREAK, IGNORED }

@export var kind: Kind = Kind.BREAK
@export var lines: Array[String] = ["(V1: fala — edite no Inspetor)"]
## Só no tipo BREAK: fala ao tentar usar o item de novo.
@export var empty_lines: Array[String] = ["(V1-VAZIO: fala do clique vazio)"]
@export var empty_click_seconds := 30.0

var _done := false
var _empty_left := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _empty_left > 0.0:
		_empty_left -= delta


func _unhandled_input(event: InputEvent) -> void:
	if _empty_left > 0.0 and event.is_action_pressed("interact") and not event.is_echo():
		_empty_left = 0.0
		for line in empty_lines:
			GameState.say(line)


func _on_body_entered(body: Node2D) -> void:
	if _done or not (body is Player):
		return
	match kind:
		Kind.BREAK:
			var effect = get_tree().get_first_node_in_group("light_item_effect")
			if effect == null:
				return  # não pegou o item (ou ele já quebrou)
			effect.finish()
			GameState.set_flag("item_luz_quebrou")
			_done = true
			_empty_left = empty_click_seconds
			for line in lines:
				GameState.say(line)
		Kind.IGNORED:
			if GameState.get_flag("pegou_item_luz") or GameState.get_flag("ignorou_item_luz"):
				return
			GameState.set_flag("ignorou_item_luz")
			_done = true
			for line in lines:
				GameState.say(line)

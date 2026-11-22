class_name KCompanion
extends Node
## Everything K says and where K goes.
## - Clareira: K LEADS you, one creature at a time, in a fixed order. K walks to the next
##   one and only explains it once you can actually see it (or are right next to it).
##   The hidden one is hinted at, never explained.
## - Afterwards K keeps talking from afar: first creature of an area, half an area, guardian
##   awake (and where), guardian freed (a reflection + where to go next), chords, and a
##   gentle hint when you have been stuck for a while.

const IDLE_HINT_SECONDS := 110.0

var world: GameWorld
var game: Node
var _guide_index := -1
var _idle := 0.0

## Tutorial order. "wait" is the marker where K stands; "explain" fires when you see the blob.
var steps := [
	{"id": "fa", "blob": "clearing:fa", "wait": "k_fa", "explain": [
		"Vês aquela? Está verde... e o verde é Fá.",
		"Escolhe a nota com %s a %s. Se lhe chamares com a nota errada, ela responde com a sua: ouve-a, e depois responde-lhe.",
	]},
	{"id": "mi", "blob": "clearing:mi", "wait": "k_mi", "explain": [
		"Aquela, no meio do lago, é amarela: Mi. Não consegues chegar lá a nadar.",
		"Um ping curto não chega tão longe. Mantém %s mais tempo antes de largar: quanto mais carregas, mais longe vai.",
	]},
	{"id": "shy", "blob": "clearing:shy", "wait": "k_shy", "explain": [
		"Shh... esta é tímida. Acorda-a com a nota dela...",
		"...e depois deixa-a em paz. Qualquer som, mesmo outra nota, assusta-a outra vez. Ela mostra-te quanto tempo falta.",
	]},
	{"id": "pair", "blob": "clearing:pair_a", "wait": "k_pair", "explain": [
		"Estas duas estão separadas pela pedra. Precisam de ouvir o mesmo chamamento ao mesmo tempo.",
		"Uma só onda que chegue às duas. Procura o sítio de onde as consegues ver a ambas.",
	]},
	{"id": "stim", "blob": "clearing:stim", "wait": "k_stim", "explain": [
		"Esta está ansiosa por companhia. Repara no que ela te mostra: quantas vezes, e em quanto tempo.",
	]},
	{"id": "hidden", "blob": "clearing:hidden", "wait": "k_hidden", "explain": []},
]


func _init(owner_world: GameWorld) -> void:
	world = owner_world
	name = "KCompanion"


func _ready() -> void:
	game = get_node("/root/Game")


func _process(delta: float) -> void:
	if world.player == null:
		return
	_idle += delta
	if not game.progress["clearing_done"]:
		_update_guide()
	elif _idle > IDLE_HINT_SECONDS and not world.dialogue.is_busy():
		_idle_hint()


func note_progress() -> void:
	_idle = 0.0


# --- Clareira guide ---------------------------------------------------------------------

func _blob(blob_id: String) -> EchoBlob:
	for blob in world._area_blobs["clearing"]:
		if blob.blob_id == blob_id:
			return blob
	return null


func _marker(name: String) -> Vector2:
	return world.geometry.region_data("clearing")["markers"][name]


func current_step() -> Dictionary:
	if _guide_index < 0 or _guide_index >= steps.size():
		return {}
	return steps[_guide_index]


func _update_guide() -> void:
	# The next step is the first creature (in order) that still needs help.
	var index := -1
	for step_index in range(steps.size()):
		var blob := _blob(steps[step_index]["blob"])
		if blob != null and not blob.is_freed():
			index = step_index
			break
	if index < 0:
		return
	var step: Dictionary = steps[index]
	if index != _guide_index:
		_guide_index = index
		var wait := _marker(step["wait"])
		world.k_body.glide_to(wait, clampf(world.k_body.global_position.distance_to(wait) / 260.0, 0.6, 4.0))
		if index > 0:
			var go_lines := {"mi": "Agora por aqui. Segue-me.", "shy": "Há mais alguém, a oeste. Vem.", "pair": "Para este. Duas que se perderam uma da outra.", "stim": "Ainda há alguém para sul. Vem comigo.", "hidden": "Quase... mas ainda falta alguém."}
			world.say([go_lines.get(step["id"], "Por aqui.")])
	if world.dialogue.is_busy():
		return
	var blob := _blob(step["blob"])
	var player_position: Vector2 = world.player.global_position
	var sees := world.fov.is_point_visible(blob.global_position) or player_position.distance_to(blob.global_position) < 200.0
	var near_k := player_position.distance_to(world.k_body.global_position) < 170.0
	if step["id"] == "stim" and not game.dialogue_seen("explain_current") and (near_k or _near_current(player_position)):
		world.say_once("explain_current", [
			"Há alguém do outro lado desta corrente. A andar, ela empurra-te para trás.",
			"Mantém %s para ganhar balanço e larga para dar um salto. Quanto mais tempo carregas, mais longe vais." % game.key_label("echo_dash"),
		])
		return
	if step["id"] == "hidden":
		if not game.dialogue_seen("hint_hidden") and (near_k or sees):
			world.say_once("hint_hidden", [
				"Não a vejo... mas ouço-a. Algures aqui perto, para norte.",
				"Há quem só apareça quando um ping lhe toca.",
			])
		return
	if not game.dialogue_seen("explain_" + step["id"]) and sees:
		var lines: Array = []
		for line in step["explain"]:
			var text: String = line
			if text.contains("%s a %s"):
				text = text % [game.key_label("echo_note_1"), game.key_label("echo_note_7")]
			elif text.contains("%s"):
				text = text % game.key_label("echo_ping")
			lines.append(text)
		world.say_once("explain_" + step["id"], lines)


func _near_current(point: Vector2) -> bool:
	for current in world.currents:
		if current.global_position.distance_to(point) < 230.0:
			return true
	return false


# --- Events from the world -----------------------------------------------------------------

func on_blob_freed(blob: EchoBlob) -> void:
	note_progress()
	var area := blob.area
	if area == "clearing":
		if blob.blob_id == "clearing:fa":
			world.say_once("fa_freed", ["Ela lembrou-se de quem é. É assim que ajudamos: percebendo o que cada uma precisa."])
		return
	if not area in game.AREAS:
		return
	var freed: int = world.area_freed(area)
	var total: int = world.area_total(area)
	if freed == 1:
		world.say_once("first_" + area, [{
			"vista": "Ajudaste a primeira das Grutas. Vês? Agora ela ilumina à sua volta.",
			"som": "A primeira voz do Vale ganhou cor. Quanto mais ouvires, mais fácil será reconhecê-las.",
			"tato": "A primeira do Bosque confiou em ti. Aqui, a calma vale mais do que a pressa.",
		}[area]])
	elif freed * 2 >= total and not game.dialogue_seen("half_" + area):
		world.say_once("half_" + area, [{
			"vista": "Já ajudaste metade das Grutas. Repara como já vês mais longe do que quando chegaste.",
			"som": "Metade do Vale já canta contigo. Agora, quando escolheres a nota certa perto de alguém, vais senti-la vibrar.",
			"tato": "Metade do Bosque já não foge de ti. Ficaram mais pacientes contigo.",
		}[area]])


func on_vassal_awake(letter: String, area: String) -> void:
	note_progress()
	var where := {"Y": "no fundo das Grutas, a oeste", "C": "no topo do Vale, a norte", "M": "no coração do Bosque, a leste"}
	world.say_once("awake_" + letter, [
		"Ajudaste criaturas suficientes em %s. Não precisas de encontrar todas." % world.region_title(area),
		"O guardião %s acordou, %s. Vai ter com ele quando quiseres." % [letter, where[letter]],
	])


func on_vassal_completed(letter: String) -> void:
	note_progress()
	var reflection := {
		"Y": "A Y escondia-se porque tinha medo de ser vista sem a sua luz. Às vezes ajudar é não obrigar ninguém a mostrar-se.",
		"C": "A C não precisava que falasses por ela. Precisava que a ouvisses até ela se lembrar da própria voz.",
		"M": "A M tinha espinhos porque já a tinham apressado demasiadas vezes. Tu esperaste.",
	}
	var lines: Array = [reflection[letter]]
	var remaining: Array[String] = []
	var places := {"Y": "as Grutas, a oeste", "C": "o Vale, a norte", "M": "o Bosque, a leste"}
	for other in ["Y", "C", "M"]:
		if not game.is_vassal_freed(other) and other != letter:
			remaining.append(places[other])
	if remaining.size() == 2:
		lines.append("Ainda faltam %s e %s." % [remaining[0], remaining[1]])
	elif remaining.size() == 1:
		lines.append("Só falta %s." % remaining[0])
	world.say(lines)


func on_chord_unlocked(pc: int) -> void:
	note_progress()
	var extras := EchoNotes.triad_extras(pc)
	var names := "%s, %s e %s" % [EchoNotes.name_for(pc), EchoNotes.name_for(extras[0]), EchoNotes.name_for(extras[1])]
	if not game.dialogue_seen("first_chord"):
		world.say_once("first_chord", [
			"Ajudaste cinco criaturas de %s. Agora essa nota pode soar como um acorde: %s." % [EchoNotes.name_for(pc), EchoNotes.chord_name_for(pc)],
			"Escolhe %s e carrega %s. O teu ping passa a levar %s ao mesmo tempo, e qualquer criatura dessas cores o ouve." % [EchoNotes.name_for(pc), game.key_label("echo_chord"), names],
			"Ninguém precisa de acordes... mas tornam muita coisa mais leve. Carrega %s outra vez para voltar a uma nota só." % game.key_label("echo_chord"),
		])
	else:
		world.say(["Também o teu %s pode ser acorde agora: %s (%s)." % [EchoNotes.name_for(pc), EchoNotes.chord_name_for(pc), names]])


# --- Hints ----------------------------------------------------------------------------

func _idle_hint() -> void:
	_idle = 0.0
	var region: String = world.current_region
	if not region in game.AREAS:
		return
	var player_position: Vector2 = world.player.global_position
	var best: EchoBlob = null
	for blob in world._area_blobs[region]:
		if blob.is_freed():
			continue
		if best == null or blob.global_position.distance_to(player_position) < best.global_position.distance_to(player_position):
			best = blob
	if best == null:
		return
	var direction := direction_word(best.global_position - player_position)
	var hint := {
		EchoBlob.Need.NOTE: "Alguém espera a sua nota, para %s.",
		EchoBlob.Need.SHY: "Há uma tímida para %s. Depois de a acordares, silêncio.",
		EchoBlob.Need.STIMULATED: "Alguém ansioso, para %s. Vários pings, depressa.",
		EchoBlob.Need.GENTLE: "Para %s há alguém delicado. Pings curtos, e de perto.",
		EchoBlob.Need.CAUTIOUS: "Para %s há alguém desconfiado. Aproxima-te devagar.",
		EchoBlob.Need.WARMTH: "Alguém tem frio, para %s. Fica perto dela um bocadinho.",
		EchoBlob.Need.MELODY: "Ouço uma canção para %s. Responde-lhe nota a nota.",
		EchoBlob.Need.PUSH: "Para %s há alguém longe do ninho. Talvez precise de um empurrão.",
	}
	var text: String = hint.get(best.need, "Ainda há alguém para %s.") % direction
	if best.hidden_until_pinged and not best.has_answered:
		text = "Não a vejo, mas ouço alguém para %s. Um ping talvez a revele." % direction
	world.say([text])


static func direction_word(offset: Vector2) -> String:
	var angle := rad_to_deg(atan2(offset.y, offset.x))
	var names := ["este", "sudeste", "sul", "sudoeste", "oeste", "noroeste", "norte", "nordeste"]
	return names[posmod(roundi(angle / 45.0), 8)]

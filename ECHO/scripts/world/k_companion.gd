class_name KCompanion
extends Node
## Everything K says, and the tutorial guide.
## K is only a VOICE until the very end (its reveal is part of the ending).
## - Clareira: strictly in order. Each creature stays dormant (invisible, deaf) until its
##   turn. Then it appears, a light on the ground shows EXACTLY where to stand, and K
##   explains when you step on it. Pinging is locked until the opening speech ends.
## - Afterwards K keeps talking from afar: first creature of an area, half an area, guardian
##   awake (and where), guardian freed (a reflection + where to go next), chords, and a
##   gentle hint when you have been stuck for a while.

const IDLE_HINT_SECONDS := 110.0

var world: GameWorld
var game: Node
var marker: GuideMarker
var _guide_index := -1
var _phase := 0
var _idle := 0.0

## Tutorial order. "blobs": creatures of the step; "spot": guide light marker name.
## "phases": [spot, dialogue key, lines] in sequence (most steps have one).
var steps := [
	{"id": "fa", "blobs": ["clearing:fa"], "go": "Vês aquela luz no chão? Vai até lá.", "phases": [
		["g_fa", "explain_fa", [
			"Vês aquela blob? Está verde... e o verde é Fá.",
			"Escolhe a nota com %NOTES%. Se lhe chamares com a nota errada, ela responde com a sua: ouve-a, e depois responde-lhe.",
		]],
	]},
	{"id": "mi", "blobs": ["clearing:mi"], "go": "Muito bem. Agora segue a luz outra vez.", "phases": [
		["g_mi", "explain_mi", [
			"Aquela, no meio do lago, é amarela: Mi. Não consegues chegar lá a nadar.",
			"Daqui, um ping curto não chega. Mantém %PING% mais tempo antes de largar: quanto mais carregas, mais longe vai.",
		]],
	]},
	{"id": "shy", "blobs": ["clearing:shy"], "go": "Há mais alguém, a oeste. Segue a luz.", "phases": [
		["g_shy", "explain_shy", [
			"Shh... ali, vermelha. É tímida. Acorda-a com a nota dela...",
			"...e depois deixa-a em paz. Qualquer som, mesmo outra nota, assusta-a outra vez. Ela mostra-te quanto tempo falta.",
		]],
	]},
	{"id": "pair", "blobs": ["clearing:pair_a", "clearing:pair_b"], "go": "Agora para este. Segue a luz.", "phases": [
		["g_pair", "explain_pair", [
			"Estas duas estão separadas pela pedra. Precisam de ouvir o mesmo chamamento ao mesmo tempo.",
			"Daqui consegues chegar às duas. Uma só onda: chama-as.",
		]],
	]},
	{"id": "stim", "blobs": ["clearing:stim"], "go": "Ainda há alguém para sul. Segue a luz.", "phases": [
		["g_current", "explain_current", [
			"Há alguém do outro lado desta corrente. A andar, ela empurra-te para trás.",
			"Mantém %DASH% para ganhar balanço e larga para dar um salto. Quanto mais tempo carregas, mais longe vais.",
		]],
		["g_stim", "explain_stim", [
			"Esta está ansiosa por companhia. Repara no que ela te mostra: quantas vezes, e em quanto tempo.",
		]],
	]},
	{"id": "hidden", "blobs": ["clearing:hidden"], "go": "Quase... mas ainda falta alguém. Segue a luz.", "phases": [
		["g_hidden", "hint_hidden", [
			"Não a vejo... mas ouço-a. Algures aqui perto.",
			"Há quem só apareça quando um ping lhe toca.",
		]],
	]},
]


func _init(owner_world: GameWorld) -> void:
	world = owner_world
	name = "KCompanion"


func _ready() -> void:
	game = get_node("/root/Game")
	marker = GuideMarker.new()
	marker.name = "GuideMarker"
	world.add_child.call_deferred(marker)
	if not game.progress["clearing_done"]:
		# Future creatures wait, invisible, until the guide reaches them.
		for step in steps:
			for blob_id in step["blobs"]:
				var blob := _blob(blob_id)
				if blob != null and not blob.is_freed():
					blob.set_dormant(true)


func _process(delta: float) -> void:
	if world.player == null:
		return
	_idle += delta
	if not game.progress["clearing_done"]:
		_update_guide()


func note_progress() -> void:
	_idle = 0.0


# --- Clareira guide ---------------------------------------------------------------------

func _blob(blob_id: String) -> EchoBlob:
	for blob in world._area_blobs["clearing"]:
		if blob.blob_id == blob_id:
			return blob
	return null


func _marker_position(name: String) -> Vector2:
	return world.geometry.region_data("clearing")["markers"][name]


func current_step() -> Dictionary:
	if _guide_index < 0 or _guide_index >= steps.size():
		return {}
	return steps[_guide_index]


func guide_target() -> Vector2:
	return marker.global_position if marker != null and marker.visible else Vector2.INF


func _step_done(step: Dictionary) -> bool:
	for blob_id in step["blobs"]:
		var blob := _blob(blob_id)
		if blob != null and not blob.is_freed():
			return false
	return true


func _update_guide() -> void:
	if not game.dialogue_seen("intro") or (world.intro_running() and _guide_index < 0):
		return
	var index := -1
	for step_index in range(steps.size()):
		if not _step_done(steps[step_index]):
			index = step_index
			break
	if index < 0:
		marker.visible = false
		return
	var step: Dictionary = steps[index]
	if index != _guide_index:
		_guide_index = index
		_phase = 0
		for blob_id in step["blobs"]:
			var blob := _blob(blob_id)
			if blob != null:
				blob.set_dormant(false)
		marker.show_at(_marker_position(step["phases"][0][0]))
		world.say([step["go"]])
	var phases: Array = step["phases"]
	if _phase >= phases.size() or world.dialogue.is_busy():
		return
	var phase: Array = phases[_phase]
	if marker.is_reached(world.player.global_position):
		world.say_once(phase[1], _fill(phase[2]))
		_phase += 1
		# The light has done its job: it disappears, so nobody thinks they must stay there.
		if _phase < phases.size():
			marker.show_at(_marker_position(phases[_phase][0]))
		else:
			marker.visible = false


func _fill(lines: Array) -> Array:
	var result: Array = []
	for line in lines:
		var text: String = line
		text = text.replace("%NOTES%", "%s a %s" % [game.key_label("echo_note_1"), game.key_label("echo_note_7")])
		text = text.replace("%PING%", game.key_label("echo_ping"))
		text = text.replace("%DASH%", game.key_label("echo_dash"))
		result.append(text)
	return result


# --- Events from the world -----------------------------------------------------------------

## Chords unlocked while a themed challenge (guardian or finale) is running are explained
## only after that challenge ends, so the explanation doesn't interrupt it.
var _pending_chords: Array[int] = []


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
			"vista": "Ajudaste a primeira blob das Grutas. Vês? Agora ela ilumina à sua volta.",
			"som": "A primeira voz do Vale ganhou cor. Quanto mais ouvires, mais fácil será reconhecê-las.",
			"tato": "A primeira blob do Bosque confiou em ti. Aqui, a calma vale mais do que a pressa.",
		}[area]])
	elif freed * 2 >= total and not game.dialogue_seen("half_" + area):
		world.say_once("half_" + area, [{
			"vista": "Já ajudaste metade das blobs das Grutas. Repara como já vês mais longe do que quando chegaste.",
			"som": "Metade do Vale já canta contigo. Agora, quando escolheres a nota certa perto de uma blob, vais senti-la vibrar.",
			"tato": "Metade do Bosque já não foge de ti. Ficaram mais pacientes contigo.",
		}[area]])


func on_vassal_awake(_letter: String, area: String) -> void:
	note_progress()
	world.say_once("awake_" + area, [
		"Ajudaste blobs suficientes em %s. Não precisas de encontrar todas." % world.region_title(area),
		"O vassalo desta zona acordou, lá no fundo. Ficou sozinho muito tempo... vai ter com ele quando quiseres.",
	])


## Called by the world when the player comes near a guardian that is still asleep.
func on_near_sleeping_vassal(area: String) -> void:
	world.say_once("asleep_" + area, [
		"Este é o vassalo desta zona. Está adormecido.",
		"Vai acordar quando tiveres ajudado blobs suficientes por aqui: %d de %d." % [world.area_needed(area), world.area_total(area)],
	])


func on_vassal_completed(letter: String) -> void:
	note_progress()
	var reflection := {
		"Y": "Ela escondia-se porque tinha medo de ser vista sem a sua luz. Às vezes ajudar é não obrigar ninguém a mostrar-se.",
		"C": "Ela não precisava que falasses por ela. Precisava que a ouvisses até se lembrar da própria voz.",
		"M": "Ela tinha espinhos porque já a tinham apressado demasiadas vezes. Tu esperaste.",
	}
	var color_word := {"Y": "o amarelo", "C": "o ciano", "M": "o magenta"}
	var lines: Array = [reflection[letter]]
	if game.cmy_freed_count() == 1:
		lines.append("Sentes? O mundo ficou menos escuro... e %s voltou. Cada vassalo guardava uma das cores do mundo." % color_word[letter])
	else:
		lines.append("E %s voltou ao mundo." % color_word[letter])
	var remaining: Array[String] = []
	var places := {"Y": "as Grutas, a oeste da Nascente", "C": "o Vale, a norte da Nascente", "M": "o Bosque, a este da Nascente"}
	for other in ["Y", "C", "M"]:
		if not game.is_vassal_freed(other) and other != letter:
			remaining.append(places[other])
	if remaining.size() == 2:
		lines.append("Esta zona já está em paz. Ainda há vassalos à espera em %s e %s. As blobs que faltam aqui podem esperar, se quiseres." % [remaining[0], remaining[1]])
	elif remaining.size() == 1:
		lines.append("Só falta um vassalo, em %s." % remaining[0])
	world.say(lines)
	_flush_pending_chords()


func on_chord_unlocked(pc: int) -> void:
	note_progress()
	if world.in_themed_challenge():
		_pending_chords.append(pc)
		return
	_explain_chord(pc)


func _flush_pending_chords() -> void:
	for pc in _pending_chords:
		_explain_chord(pc)
	_pending_chords.clear()


func pending_chords() -> Array[int]:
	return _pending_chords


func _explain_chord(pc: int) -> void:
	var extras := EchoNotes.triad_extras(pc)
	var names := "%s, %s e %s" % [EchoNotes.name_for(pc), EchoNotes.name_for(extras[0]), EchoNotes.name_for(extras[1])]
	if not game.dialogue_seen("first_chord"):
		world.say_once("first_chord", [
			"Ajudaste cinco blobs de %s. Agora essa nota pode soar como um acorde: %s." % [EchoNotes.name_for(pc), EchoNotes.chord_name_for(pc)],
			"Escolhe %s e carrega %s. O teu ping passa a levar %s ao mesmo tempo, e qualquer blob dessas cores o ouve." % [EchoNotes.name_for(pc), game.key_label("echo_chord"), names],
			"Ninguém precisa de acordes... mas tornam muita coisa mais leve. Carrega %s outra vez para voltar a uma nota só." % game.key_label("echo_chord"),
		])
	else:
		world.say(["Também o teu %s pode ser acorde agora: %s (%s)." % [EchoNotes.name_for(pc), EchoNotes.chord_name_for(pc), names]])


## First time you come near each kind of advanced challenge: a nudge, never the answer.
func on_near_set_piece(pattern: String) -> void:
	var nudges := {
		"chorus": ["Estas três estão ligadas, e são todas tímidas.", "Se acordares uma de cada vez... o que acontece às outras quando voltas a chamar?"],
		"neighbours": ["Duas vizinhas que precisam de coisas muito diferentes.", "Talvez a ordem importe. E onde estás quando chamas."],
		"lake": ["Não consegues chegar perto destas. Só a tua voz atravessa a água."],
		"current": ["Do outro lado da corrente há uma blob desconfiada. Entrar a correr pode não ser boa ideia."],
		"cluster": ["Estas estão juntas, mas cada uma quer a sua própria nota.", "Só se soltam quando todas tiverem ouvido a sua. A ordem não importa."],
		"same_wave": ["Da mesma cor, e separadas. Lembras-te do par da Clareira? Uma só onda que chegue a todas."],
	}
	if nudges.has(pattern):
		world.say_once("near_sp_" + pattern, nudges[pattern])


# --- Hints ----------------------------------------------------------------------------

func _idle_hint() -> void:
	_idle = 0.0
	var region: String = world.current_region
	if not region in game.AREAS:
		return
	# Once a zone's guardian is free, don't keep pushing the player around that zone.
	if game.is_vassal_freed(game.AREA_VASSAL[region]):
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
	if region == "vista":
		# Directions make little sense where you can barely see.
		world.say(["Há mais blobs aqui no escuro. Os teus pings revelam-nas... e cada uma que ajudares deixa-te ver mais longe."])
		return
	var direction := direction_word(best.global_position - player_position)
	var hint := {
		EchoBlob.Need.NOTE: "Há uma blob que espera a sua nota, para %s.",
		EchoBlob.Need.SHY: "Há uma tímida para %s. Depois de a acordares, silêncio.",
		EchoBlob.Need.STIMULATED: "Há uma blob ansiosa, para %s. Vários pings, depressa.",
		EchoBlob.Need.GENTLE: "Para %s há uma blob delicada. Pings curtos, e de perto.",
		EchoBlob.Need.CAUTIOUS: "Para %s há uma blob desconfiada. Aproxima-te devagar.",
		EchoBlob.Need.WARMTH: "Há uma blob com frio, para %s. Fica perto dela um bocadinho.",
		EchoBlob.Need.MELODY: "Ouço uma canção para %s. Responde-lhe nota a nota.",
		EchoBlob.Need.PUSH: "Para %s há uma blob longe do ninho. Talvez precise de um empurrão.",
	}
	var text: String = hint.get(best.need, "Ainda há alguém para %s.") % direction
	if best.hidden_until_pinged and not best.has_answered:
		text = "Não a vejo, mas ouço uma blob para %s. Um ping talvez a revele." % direction
	world.say([text])


static func direction_word(offset: Vector2) -> String:
	var angle := rad_to_deg(atan2(offset.y, offset.x))
	var names := ["este", "sudeste", "sul", "sudoeste", "oeste", "noroeste", "norte", "nordeste"]
	return names[posmod(roundi(angle / 45.0), 8)]

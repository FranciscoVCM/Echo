class_name GameWorld
extends Node2D
## The whole Echo world: Clareira (tutorial with K) -> Nascente (hub) -> three sense areas
## (any order) -> vassals C/M/Y -> K's final challenge -> ending.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const ENDING_SCRIPT: Script = preload("res://scripts/ui/ending_screen.gd")
const PAUSE_SCRIPT: Script = preload("res://scripts/ui/pause_menu.gd")
const DEBUG_SCRIPT: Script = preload("res://scripts/ui/debug_panel.gd")
## K is the black ink: once it is back, the Nascente turns deep black.
const BLACK_NASCENTE := Color(0.11, 0.11, 0.13)
const VASSAL_COLORS := {"C": Color(0.1, 0.85, 0.95), "M": Color(0.95, 0.22, 0.66), "Y": Color(1.0, 0.9, 0.15)}

var geometry: WorldGeometry
var player: PlayerController
var emitter: PingEmitter
var fov: EchoFov
var grading: ColorGrading
var hud: EchoHud
var dialogue: DialogueBox
var k_body: VassalBody
var vassals: Dictionary = {}
var current_region := ""

var _game: Node
var _creatures: Node2D
var _area_blobs: Dictionary = {"clearing": [], "vista": [], "som": [], "tato": []}
var _clearing_gate: MembraneGate
var _sanctum_gate: MembraneGate
var _chord_mode := false
var _final_stage := -1
var _final_fragments: Array[EchoBlob] = []
var _final_trio: EchoBlobGroup
var _vision_target := 260.0
var _opacity_target := 0.7
var _pause_menu: CanvasLayer
var companion: KCompanion
var currents: Array[CurrentZone] = []
var _intro_running := false
var _challenge_time := 0.0
const VASSAL_HINTS := {
	"C": [
		"Vai até cada pedra e chama-a de perto: cada uma toca a sua nota. Qual delas soa como a primeira nota da canção?",
		"Toca as pedras pela ordem da canção, uma de cada vez. Se te perderes, chama a vassala e ela canta outra vez.",
	],
	"Y": [
		"As faíscas estão escondidas aqui no escuro. Só um ping as revela.",
		"Quando as três faíscas voltarem, chama-a pela cor dela: o amarelo.",
	],
	"M": [
		"Ela assusta-se se chegares depressa, ou se gritares. Mantém %s para andar devagar.",
		"Fica junto dela, quieta, até os espinhos baixarem. Depois, um ping curto e de perto.",
	],
}
## [pattern, center, area] of the hand-made advanced challenges (for K's first-sight nudges).
var _set_piece_spots: Array = []
var _finale_gates: Array[MembraneGate] = []


func _ready() -> void:
	_game = get_node("/root/Game")
	geometry = WorldGeometry.new()
	geometry.name = "Geometry"
	add_child(geometry)
	var layout := WorldLayout.regions()
	if _game.is_vassal_freed("K"):
		for region in layout:
			if region["name"] == "hub":
				region["floor_color"] = BLACK_NASCENTE
	geometry.build(layout)
	_scatter_flora()
	grading = ColorGrading.new()
	add_child(grading)
	_creatures = Node2D.new()
	_creatures.name = "Creatures"
	add_child(_creatures)
	var ping_layer := CanvasLayer.new()
	ping_layer.name = "PingLayer"
	ping_layer.layer = 2
	ping_layer.follow_viewport_enabled = true
	ping_layer.add_to_group("ping_wave_layer")
	add_child(ping_layer)

	_spawn_player()
	fov = EchoFov.new()
	fov.name = "Fog"
	fov.target = player
	add_child(fov)
	fov.set_world_segments(geometry.segments)
	hud = EchoHud.new()
	add_child(hud)
	dialogue = DialogueBox.new()
	add_child(dialogue)
	dialogue.finished.connect(_on_dialogue_finished)
	_pause_menu = PAUSE_SCRIPT.new()
	add_child(_pause_menu)
	var debug_panel: CanvasLayer = DEBUG_SCRIPT.new()
	debug_panel.set("world", self)
	add_child(debug_panel)

	_spawn_currents()
	_spawn_clearing()
	for area in _game.AREAS:
		for spec in SetPieces.for_area(area):
			var center := Vector2.ZERO
			for blob in EncounterSpawner.spawn(spec, _creatures, geometry):
				_register_blob(blob, area)
				center += blob.position
			center /= maxf(spec["blobs"].size(), 1)
			var pattern: String = spec.get("pattern", "")
			if str(spec["id"]).ends_with("current"):
				pattern = "current"
			_set_piece_spots.append([pattern, center, area])
	for area in _game.AREAS:
		var saved: Array = _game.progress["area_specs"].get(area, [])
		if not saved.is_empty():
			_spawn_area(area, saved)
	_spawn_vassals()
	_spawn_k()
	_spawn_gates()
	_update_grading(false)
	companion = KCompanion.new(self)
	add_child(companion)
	_game.chord_unlocked.connect(_on_chord_unlocked)
	emitter.ping_tone_changed.connect(func(_i: int, _n: String, _f: float) -> void: _apply_tone())
	emitter.ping_emitted.connect(_on_player_ping)
	_apply_tone()
	_refresh_area_ease()
	if not _game.progress["clearing_done"] and not _game.dialogue_seen("intro"):
		# No pinging until the opening speech is over (so nothing is solved before it's taught).
		emitter.input_enabled = false
		_intro_running = true
		_say_once("intro", [
			"...Olá, pequena. Consegues ouvir-me?",
			"Este mundo perdeu a cor. E as blobs perderam-se umas das outras.",
			"Mexe-te com %s %s %s %s. Para chamar, mantém %s e larga: é o teu ping." % [_key("echo_up"), _key("echo_left"), _key("echo_down"), _key("echo_right"), _key("echo_ping")],
		])
	elif _game.progress["clearing_done"]:
		hud.show_message(_region_title(geometry.region_at(player.global_position)), 3.0)


func _key(action: String) -> String:
	return _game.key_label(action)


# --- Building ---------------------------------------------------------------------------

func _scatter_flora() -> void:
	var container := Node2D.new()
	container.name = "Flora"
	add_child(container)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for region in geometry.regions:
		var palette: Array = region.get("flora", [Color(0.5, 0.8, 0.6)])
		var target := 14 if region["name"] in ["clearing", "hub"] else 34
		var placed := 0
		var attempts := 0
		while placed < target and attempts < target * 20:
			attempts += 1
			var polygon: PackedVector2Array = region["polygons"][rng.randi() % region["polygons"].size()]
			var bounds := Rect2(polygon[0], Vector2.ZERO)
			for point in polygon:
				bounds = bounds.expand(point)
			var at := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
			if not Geometry2D.is_point_in_polygon(at, polygon) or not geometry.is_walkable(at, 50.0):
				continue
			if region["name"] == "hub" and at.length() < 360.0:
				continue  # keep the sanctum clear for K's finale
			var patch := FloraPatch.new()
			patch.position = at
			patch.flora_color = palette[rng.randi() % palette.size()]
			patch.count = rng.randi_range(4, 9)
			patch.spread = rng.randf_range(30.0, 70.0)
			patch.bulb_size = rng.randf_range(5.0, 10.0)
			patch.seed_value = rng.randi()
			patch.restoration = 1.0
			container.add_child(patch)
			patch.z_index = -6
			placed += 1


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate() as PlayerController
	player.name = "Player"
	player.collision_mask = 3
	var start: Vector2 = geometry.region_data("clearing")["markers"]["start"]
	if _game.progress["clearing_done"]:
		start = geometry.region_data("hub")["markers"]["test_start"]
	player.position = start
	add_child(player)
	var camera := Camera2D.new()
	camera.zoom = Vector2(1.15, 1.15)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	player.add_child(camera)
	camera.make_current()
	emitter = player.get_node("PingEmitter") as PingEmitter
	emitter.tone_count = 7
	emitter.chord_range_factor = 0.6  # chords carry three notes but reach less far
	var preview := emitter.get_node_or_null("TonePreview") as AudioStreamPlayer
	if preview != null:
		preview.volume_db = 5.0  # your own voice should stand out over the world's
	player.collision_mask = 2 | 1 | WorldGeometry.WATER_LAYER
	# A longer dash than the lab default: currents are crossed with it.
	player.max_dash_speed = 1000.0
	player.max_dash_duration = 0.32
	EchoBlob.player = player
	EchoBlob.always_show_note_names = _game.settings["note_names_always"]


func spawn_blob(data: Dictionary, area: String) -> EchoBlob:
	var blob := EncounterSpawner.make_blob(data, area)
	_creatures.add_child(blob)
	return blob


func _spawn_currents() -> void:
	for region in geometry.regions:
		for data in region.get("currents", []):
			var current := CurrentZone.new()
			current.position = data[0]
			current.size = data[1]
			current.direction = (data[2] as Vector2).normalized()
			add_child(current)
			currents.append(current)


func _physics_process(delta: float) -> void:
	for current in currents:
		current.push(player, delta)


func area_freed(area: String) -> int:
	var count := 0
	for blob in _area_blobs.get(area, []):
		if blob.is_freed():
			count += 1
	return count


func area_total(area: String) -> int:
	return _area_blobs.get(area, []).size()


## Creatures that must be helped before the guardian wakes (not all of them).
func area_needed(area: String) -> int:
	return ceili(area_total(area) * _game.AREA_WAKE_RATIO)


func area_ready(area: String) -> bool:
	if _game.progress["area_specs"].get(area, []).is_empty():
		return false
	return area_freed(area) >= area_needed(area)


func region_title(region: String) -> String:
	return _region_title(region)


func say_once(key: String, lines: Array, speaker: String = "K") -> void:
	_say_once(key, lines, speaker)


func _spawn_clearing() -> void:
	var m: Dictionary = geometry.region_data("clearing")["markers"]
	var specs := [
		{"id": "clearing:fa", "area": "clearing", "blobs": [{"id": "clearing:fa", "pos": _p(m["fa"]), "note": 3, "need": "NOTE"}]},
		{"id": "clearing:mi", "area": "clearing", "blobs": [{"id": "clearing:mi", "pos": _p(m["mi"]), "note": 2, "need": "NOTE"}]},
		{"id": "clearing:shy", "area": "clearing", "blobs": [{"id": "clearing:shy", "pos": _p(m["shy"]), "note": 0, "need": "SHY", "shy_silence": 5.0}]},
		{"id": "clearing:pair", "area": "clearing", "group": "same_wave", "blobs": [
			{"id": "clearing:pair_a", "pos": _p(m["pair_a"]), "note": 4, "need": "NOTE"},
			{"id": "clearing:pair_b", "pos": _p(m["pair_b"]), "note": 4, "need": "NOTE"},
		]},
		{"id": "clearing:stim", "area": "clearing", "blobs": [{"id": "clearing:stim", "pos": _p(m["stim"]), "note": 1, "need": "STIMULATED", "hits": 3, "stim_window": 9.0}]},
		{"id": "clearing:hidden", "area": "clearing", "blobs": [{"id": "clearing:hidden", "pos": _p(m["hidden"]), "note": 5, "need": "NOTE", "hidden": true}]},
	]
	for spec in specs:
		for blob in EncounterSpawner.spawn(spec, _creatures, geometry):
			_register_blob(blob, "clearing")


func _p(point: Vector2) -> Array:
	return [point.x, point.y]


func _spawn_area(area: String, specs: Array) -> void:
	for spec in specs:
		if spec.get("group", "") in ["cluster", "same_wave", "window"]:
			var center := Vector2.ZERO
			for data in spec["blobs"]:
				center += Vector2(data["pos"][0], data["pos"][1])
			_set_piece_spots.append([spec["group"], center / spec["blobs"].size(), area])
		for blob in EncounterSpawner.spawn(spec, _creatures, geometry):
			_register_blob(blob, area)
	fov.set_world_segments(geometry.segments)
	_refresh_area_ease()


func generate_area(area: String) -> void:
	if not _game.progress["area_specs"].get(area, []).is_empty():
		return
	var generator := EncounterGenerator.new(geometry, int(_game.progress["seed"]) + hash(area))
	# Balance notes against what already exists, and let owned chords influence clusters.
	for blob in _all_blobs():
		generator.note_usage[EchoNotes.pitch_class(blob.note)] += 1
	generator.owned_chords = _game.unlocked_chords()
	var specs := generator.generate_area(area, geometry.region_data(area)["sites"])
	_game.progress["area_specs"][area] = specs
	_game.save_game()
	_spawn_area(area, specs)


func _register_blob(blob: EchoBlob, area: String) -> void:
	_area_blobs[area].append(blob)
	blob.freed.connect(_on_blob_freed)


func _all_blobs() -> Array[EchoBlob]:
	var all: Array[EchoBlob] = []
	for area in _area_blobs:
		for blob in _area_blobs[area]:
			all.append(blob)
	return all


func _spawn_vassals() -> void:
	for area in _game.AREAS:
		var letter: String = _game.AREA_VASSAL[area]
		var markers: Dictionary = geometry.region_data(area)["markers"]
		var body = Vassals.create(letter, self)
		body.name = "Vassal" + letter
		body.position = markers["vassal"]
		match letter:
			"Y":
				for index in range(4):
					body.anchors.append(markers["y_anchor_%d" % index])
				for index in range(3):
					body.spark_positions.append(markers["spark_%d" % index])
			"C":
				for index in range(3):
					body.stone_positions.append(markers["stone_%d" % index])
			"M":
				for index in range(3):
					body.anchors.append(markers["m_anchor_%d" % index])
		_creatures.add_child(body)
		vassals[letter] = body
		if _game.is_vassal_freed(letter):
			body.awake = true
			body.completed = true
			body.glow = 1.0
		elif area_ready(area):
			body.call_deferred("wake")


func _spawn_k() -> void:
	k_body = VassalBody.new()
	k_body.name = "K"
	k_body.letter = "K"
	k_body.base_color = Color(0.1, 0.1, 0.12)
	k_body.radius = 34.0
	k_body.grey_until_freed = false
	k_body.always_visible = true
	k_body.glow = 0.3
	k_body.collision_layer = 0
	# K is never seen until it reveals itself during the finale.
	k_body.visible = _game.is_vassal_freed("K")
	if _game.is_vassal_freed("K"):
		k_body.position = Vector2(0, 0)
		k_body.radius = 80.0
		k_body.completed = true
		k_body.awake = true
		k_body.glow = 1.0
		k_body.base_color = Color(0.05, 0.05, 0.07)
	elif _game.progress["clearing_done"]:
		k_body.position = Vector2(140, 140) if _game.cmy_freed_count() < 3 else Vector2(0, 0)
	else:
		k_body.position = geometry.region_data("clearing")["markers"]["k_start"]
	_creatures.add_child(k_body)
	k_body.collision_layer = 0
	k_body.remove_from_group("ping_blobs")
	k_body.mode_completed.connect(_on_k_mode_completed)


func _spawn_gates() -> void:
	if not _game.progress["clearing_done"]:
		_clearing_gate = MembraneGate.new()
		_clearing_gate.size = Vector2(300, 44)
		_clearing_gate.position = geometry.region_data("clearing")["markers"]["gate"]
		add_child(_clearing_gate)
	if _game.cmy_freed_count() < 3:
		_sanctum_gate = MembraneGate.new()
		_sanctum_gate.size = Vector2(300, 56)
		_sanctum_gate.color = Color(0.35, 0.35, 0.4)
		_sanctum_gate.position = geometry.region_data("hub")["markers"]["sanctum_gate"]
		add_child(_sanctum_gate)


# --- Frame update -----------------------------------------------------------------------

func _process(delta: float) -> void:
	var region := geometry.region_at(player.global_position)
	if region != "" and region != current_region:
		_enter_region(region)
	_update_theme(delta)
	_update_final(delta)
	_update_status()
	_update_k_pointer()
	_update_proximity_comments()
	_update_vassal_hints(delta)


func _enter_region(region: String) -> void:
	current_region = region
	hud.show_message(_region_title(region), 2.5)
	if region in _game.AREAS:
		generate_area(region)
		_game.note_area_entered(region)
		match region:
			"vista":
				_say_once("vista_intro", [
					"As Grutas da Vista. Aqui quase nada se vê.",
					"O teu ping é os teus olhos. E cada blob que ajudares aqui vai deixar-te ver mais longe.",
				])
			"som":
				_say_once("som_intro", [
					"O Vale dos Ecos. Aqui as blobs perderam a cor... mas não a voz.",
					"Ouve bem o que cantam. Compara com as tuas notas antes de responder.",
				])
			"tato":
				_say_once("tato_intro", [
					"O Bosque do Toque. Aqui sente-se mais do que se ouve.",
					"Algumas assustam-se com pressa e com barulho. Há quem só precise que fiques perto.",
				])
	elif region == "hub" and _game.progress["clearing_done"]:
		_say_once("hub_first", [
			"Esta é a Nascente. Daqui saem três caminhos: o Vale a oeste, o Bosque a norte, as Grutas a este.",
			"Em cada lugar há muitas blobs perdidas... e um vassalo adormecido.",
			"Vai pela ordem que quiseres. Entra e sai quando quiseres.",
		])


func _region_title(region: String) -> String:
	var data := geometry.region_data(region)
	return data.get("title", "")


func _update_theme(delta: float) -> void:
	var vision := 260.0
	var opacity := 0.7
	match current_region:
		"clearing":
			vision = 280.0
			opacity = 0.6
		"hub":
			vision = 300.0
			opacity = 0.58
		"vista":
			var ease := _area_ease("vista")
			vision = lerpf(85.0, 250.0, ease)
			opacity = lerpf(0.97, 0.86, ease)
			if _game.is_vassal_freed("Y"):
				vision = 290.0
				opacity = 0.66  # the light came back to the caves
		"som", "tato":
			vision = 260.0
			opacity = 0.7
	if _final_stage == 1:
		vision = 110.0
		opacity = 0.96
	if _game.is_vassal_freed("K"):
		vision = 420.0
		opacity = 0.35
	fov.vision_radius = lerpf(fov.vision_radius, vision, 1.0 - exp(-delta * 2.0))
	fov.fog_opacity = lerpf(fov.fog_opacity, opacity, 1.0 - exp(-delta * 2.0))
	var lights: Array = []
	for blob in _area_blobs["vista"]:
		if blob.is_light_source() and blob.global_position.distance_to(player.global_position) < 1600.0:
			lights.append([blob.global_position, 190.0, 0.85])
	var y: VassalY = vassals.get("Y")
	if y != null and y.awake and y.global_position.distance_to(player.global_position) < 1800.0:
		lights.append([y.global_position, y.light_radius(), 0.9])
	fov.lights = lights


func _area_ease(area: String) -> float:
	var blobs: Array = _area_blobs.get(area, [])
	if blobs.is_empty():
		return 0.0
	var freed := 0
	for blob in blobs:
		if blob.is_freed():
			freed += 1
	return float(freed) / blobs.size()


func _area_complete(area: String) -> bool:
	var blobs: Array = _area_blobs.get(area, [])
	if blobs.is_empty():
		return false
	for blob in blobs:
		if not blob.is_freed():
			return false
	return true


func _refresh_area_ease() -> void:
	for area in ["vista", "som", "tato"]:
		var ease := _area_ease(area)
		for blob in _area_blobs[area]:
			blob.ease = ease
			# Hearing area: once you are attuned enough, blobs vibrate when your note matches.
			blob.resonance_hint = area == "som" and ease >= 0.35
	var c: VassalBody = vassals.get("C")
	if c != null:
		c.resonance_hint = _area_ease("som") >= 0.35


func _update_status() -> void:
	var lines: Array[String] = [_region_title(current_region)]
	if current_region in _area_blobs and not _area_blobs[current_region].is_empty():
		var freed := 0
		for blob in _area_blobs[current_region]:
			if blob.is_freed():
				freed += 1
		lines.append("Blobs ajudadas: %d / %d" % [freed, _area_blobs[current_region].size()])
		if current_region in _game.AREAS and not vassals[_game.AREA_VASSAL[current_region]].awake:
			lines.append("O vassalo acorda aos %d" % area_needed(current_region))
	# The colours are only mentioned once the first guardian has given one back.
	if _game.cmy_freed_count() > 0:
		var cmy: Array[String] = []
		var letters := ["C", "M", "Y"]
		if _final_stage >= 2 or _game.is_vassal_freed("K"):
			letters.append("K")
		for letter in letters:
			cmy.append(letter if _game.is_vassal_freed(letter) else "·")
		lines.append("Cores: " + " ".join(cmy))
	if _game.test_mode:
		lines.append("[TESTE] F8 painel de debug")
	hud.set_status("\n".join(lines))


# --- Notes and chords -------------------------------------------------------------------

func _apply_tone() -> void:
	var tone := emitter.ping_tone_index
	emitter.ping_color = EchoNotes.color_for(tone)
	var extras := PackedInt32Array()
	if _chord_mode and _game.is_chord_unlocked(EchoNotes.pitch_class(tone)):
		extras = EchoNotes.triad_extras(tone)
	emitter.chord_tone_indices = extras
	var colors: Array[Color] = []
	for degree in extras:
		colors.append(EchoNotes.color_for(degree))
	emitter.chord_colors = colors
	hud.set_tone(tone, extras)


func _toggle_chord() -> void:
	var pc := EchoNotes.pitch_class(emitter.ping_tone_index)
	if _game.unlocked_chords().is_empty():
		hud.show_message("Ainda não conheces acordes: ajuda 5 blobs da mesma nota.", 3.0)
		return
	if not _game.is_chord_unlocked(pc):
		var known: Array[String] = []
		for root in _game.unlocked_chords():
			known.append(EchoNotes.chord_name_for(root))
		hud.show_message("Conheces: %s. Escolhe essa nota para o usar." % ", ".join(known), 3.0)
		return
	_chord_mode = not _chord_mode
	_apply_tone()
	emitter.play_note_preview(-1)  # hear the chord (or the single note) right away


func _on_chord_unlocked(pc: int) -> void:
	var extras := EchoNotes.triad_extras(pc)
	hud.show_message("Novo acorde: %s (%s · %s · %s)\nEscolhe %s e carrega %s." % [
		EchoNotes.chord_name_for(pc), EchoNotes.name_for(pc), EchoNotes.name_for(extras[0]),
		EchoNotes.name_for(extras[1]), EchoNotes.name_for(pc), _key("echo_chord")], 6.0)
	if _final_stage < 0:
		companion.on_chord_unlocked(pc)
	hud.set_tone(emitter.ping_tone_index, emitter.chord_tone_indices)


func _on_player_ping(_origin: Vector2, is_echo: bool, _charge: float, _tone: int, _frequency: float) -> void:
	if is_echo:
		return
	_game.add_stat("pings")
	if not emitter.chord_tone_indices.is_empty():
		_game.add_stat("chord_pings")
	if not _game.progress["clearing_done"]:
		_say_once("first_ping", [
			"Isso. O ping viaja, bate nas paredes... e tudo o que toca responde.",
			"Escolhe a nota com %s a %s, ou com a roda do rato. Cada nota tem uma cor." % [_key("echo_note_1"), _key("echo_note_7")],
		])


# --- Blob events ------------------------------------------------------------------------

func _on_blob_freed(blob: EchoBlob) -> void:
	_refresh_area_ease()
	var area := blob.area
	companion.on_blob_freed(blob)
	if area == "clearing":
		if _area_complete("clearing") and not _game.progress["clearing_done"]:
			_finish_clearing()
	elif area in _game.AREAS and area_ready(area):
		var letter: String = _game.AREA_VASSAL[area]
		var vassal: VassalBody = vassals[letter]
		if not vassal.awake:
			vassal.wake()
			hud.show_message("Algo despertou em %s." % _region_title(area), 4.0)
			companion.on_vassal_awake(letter, area)


func _finish_clearing() -> void:
	_game.progress["clearing_done"] = true
	_game.save_game()
	if _clearing_gate != null:
		_clearing_gate.open()
	_say_once("clearing_done", [
		"A clareira respira outra vez.",
		"Mais à frente há três lugares onde muitas blobs se perderam. Segue o caminho para norte.",
	])
	k_body.glide_to(Vector2(140, 140), 6.0)


func on_vassal_completed(letter: String) -> void:
	_game.free_vassal(letter)
	_update_grading(true)
	var vassal: VassalBody = vassals[letter]
	EchoMarker.spawn(vassal.global_position, VASSAL_COLORS[letter], 90.0, get_tree(), true)
	companion.on_vassal_completed(letter)
	var color_name: String = {"C": "o ciano", "M": "o magenta", "Y": "o amarelo"}[letter]
	hud.show_message("O mundo está menos escuro: %s voltou." % color_name, 6.0)
	match letter:
		"Y":
			say([["Y", "Obrigada por me encontrares... sem me obrigares a ser vista."]], "Y")
		"C":
			say([["C", "A minha voz... ouviste-a antes de mim."]], "C")
		"M":
			say([["M", "Esperaste por mim. Ninguém tinha esperado."]], "M")
	if _game.cmy_freed_count() >= 3:
		k_body.glide_to(Vector2(0, 0), 4.0)
		if _sanctum_gate != null:
			_sanctum_gate.open()
		say([
			["K", "Três cores voltaram. Falta uma... a mais escura."],
			["K", "Vem ao centro da Nascente. Estou à tua espera."],
		])


func _update_grading(animate: bool) -> void:
	if _game.is_vassal_freed("K"):
		grading.set_state(1.0, 1.0, 1.0, 1.05, animate)
		return
	var c := 1.0 if _game.is_vassal_freed("C") else 0.0
	var m := 1.0 if _game.is_vassal_freed("M") else 0.0
	var y := 1.0 if _game.is_vassal_freed("Y") else 0.0
	grading.set_state(c, m, y, 0.5 + 0.13 * _game.cmy_freed_count(), animate)


# --- K: tutorial triggers ---------------------------------------------------------------

## K is only a voice ("Voz") until it reveals itself at the very end.
func say(lines: Array, speaker: String = "K", sequence_id: String = "") -> void:
	var revealed: bool = _final_stage >= 2 or _game.is_vassal_freed("K")
	var voice := "K" if revealed else "Voz"
	var mapped: Array = []
	for line in lines:
		if line is Array:
			mapped.append([voice if line[0] == "K" else line[0], line[1]])
		else:
			mapped.append(line)
	dialogue.say(mapped, voice if speaker == "K" else speaker, sequence_id)


func _say_once(key: String, lines: Array, speaker: String = "K") -> void:
	if _game.dialogue_seen(key):
		return
	_game.mark_dialogue(key)
	say(lines, speaker, key)


## K comments when you first come near a sleeping guardian or an advanced challenge.
func _update_proximity_comments() -> void:
	if dialogue.is_busy() or not current_region in _game.AREAS:
		return
	var position := player.global_position
	var letter: String = _game.AREA_VASSAL[current_region]
	var vassal: VassalBody = vassals[letter]
	if not vassal.awake and not vassal.completed and vassal.global_position.distance_to(position) < 520.0:
		companion.on_near_sleeping_vassal(current_region)
		return
	if vassal.awake and not vassal.completed and vassal.global_position.distance_to(position) < 650.0:
		var lines: Array = []
		for line in vassal.call("meet_lines"):
			lines.append([line[0], str(line[1]).replace("%SLOW%", _key("echo_slow"))])
		_say_once("meet_" + letter, lines)
		return
	for blob in _area_blobs[current_region]:
		if blob.state == EchoBlob.State.LOST and not blob.dormant and blob.visible and blob.global_position.distance_to(position) < 330.0:
			if not _game.dialogue_seen("need_%d" % blob.need):
				companion.on_first_need(blob.need)
				if dialogue.is_busy():
					return
	for spot in _set_piece_spots:
		if spot[2] == current_region and (spot[1] as Vector2).distance_to(position) < 360.0:
			companion.on_near_set_piece(spot[0])
			return


## If you stay stuck near an awake vassal, K offers a gentle hint, then a clearer one.
func _update_vassal_hints(delta: float) -> void:
	EchoBlob.hush = in_themed_challenge()
	var active := ""
	for letter in vassals:
		var vassal: VassalBody = vassals[letter]
		if vassal.awake and not vassal.completed and vassal.global_position.distance_to(player.global_position) < 900.0:
			active = letter
	if active == "":
		_challenge_time = 0.0
		return
	_challenge_time += delta
	var hints: Array = VASSAL_HINTS[active]
	if _challenge_time > 50.0 and not dialogue.is_busy():
		_say_once("stuck1_" + active, [str(hints[0]).replace("%s", _key("echo_slow"))])
	if _challenge_time > 120.0 and not dialogue.is_busy():
		_say_once("stuck2_" + active, [str(hints[1])])


## True while a guardian's challenge (or K's finale) is in progress around the player.
func in_themed_challenge() -> bool:
	if _final_stage >= 1 and _final_stage <= 5:
		return true
	for letter in vassals:
		var vassal: VassalBody = vassals[letter]
		if vassal.awake and not vassal.completed and vassal.global_position.distance_to(player.global_position) < 900.0:
			return true
	return false


func _update_k_pointer() -> void:
	if _game.progress["clearing_done"] or current_region != "clearing":
		hud.set_pointer(Vector2.INF)
		return
	var target := companion.guide_target()
	if target == Vector2.INF:
		hud.set_pointer(Vector2.INF)
		return
	var canvas := get_viewport().get_canvas_transform()
	var screen := canvas * target
	var size := get_viewport().get_visible_rect().size
	if Rect2(Vector2(40, 40), size - Vector2(80, 80)).has_point(screen):
		hud.set_pointer(Vector2.INF)
	else:
		hud.set_pointer(screen)


func _on_dialogue_finished(sequence_id: String) -> void:
	if sequence_id == "intro":
		_intro_running = false
		emitter.input_enabled = true
		hud.show_message("Já podes usar o ping (%s)." % _key("echo_ping"), 3.0)


func intro_running() -> bool:
	return _intro_running


# --- K: final challenge -----------------------------------------------------------------

func _update_final(_delta: float) -> void:
	if _game.is_vassal_freed("K") or _game.cmy_freed_count() < 3:
		return
	if _final_stage == -1 and player.global_position.length() < 250.0:
		_start_final_stage(1)


func _start_final_stage(stage: int) -> void:
	_final_stage = stage
	var markers: Dictionary = geometry.region_data("hub")["markers"]
	match stage:
		1:
			# No leaving the Nascente once K's challenge has begun.
			for exit in [["exit_s", Vector2(320, 44)], ["exit_n", Vector2(320, 44)], ["exit_w", Vector2(44, 320)], ["exit_e", Vector2(44, 320)]]:
				var gate := MembraneGate.new()
				gate.size = exit[1]
				gate.color = Color(0.3, 0.3, 0.35)
				gate.position = markers[exit[0]]
				add_child(gate)
				_finale_gates.append(gate)
			var missing: Array[int] = _game.grant_all_chords()
			if not missing.is_empty():
				var names: Array[String] = []
				for pc in missing:
					names.append(EchoNotes.chord_name_for(pc))
				say([["K", "Antes de começares... leva também as vozes que ainda não aprendeste: %s." % ", ".join(names)]])
				_apply_tone()
			say([
				["K", "Então chegaste."],
				["K", "Antes de me veres, tens de me encontrar. Parti-me em quatro... algures nesta escuridão."],
				["K", "Usa tudo o que aprendeste. Os teus acordes também."],
			])
			k_body.visible = false
			k_body.always_visible = false
			var parts := [
				{"note": 0, "need": "SHY", "shy_silence": 5.0},
				{"note": 2, "need": "STIMULATED", "hits": 3, "stim_window": 9.5},
				{"note": 4, "need": "NOTE", "hits": 2},
				{"note": 5, "need": "GENTLE", "hits": 2},
			]
			for index in range(4):
				var data: Dictionary = parts[index].duplicate()
				var at: Vector2 = markers["k_fragment_%d" % index]
				data["id"] = ""  # final pieces are not saved: the finale restarts cleanly
				data["pos"] = [at.x, at.y]
				data["hidden"] = true
				data["singer"] = true
				var blob := spawn_blob(data, "k")
				blob.freed.connect(_on_final_fragment_freed)
				_final_fragments.append(blob)
		2:
			for blob in _final_fragments:
				# Flying back into K: no longer part of the world (can't be pinged or leave echoes).
				blob.remove_from_group("ping_blobs")
				var tween := blob.create_tween()
				tween.tween_property(blob, "global_position", Vector2.ZERO, 1.5).set_trans(Tween.TRANS_SINE)
				tween.tween_callback(blob.set_dormant.bind(true))
			k_body.visible = true
			k_body.always_visible = true
			k_body.modulate.a = 1.0
			k_body.add_to_group("ping_blobs")
			k_body.grey_until_freed = true
			k_body.start_melody(PackedInt32Array([5, 2, 0]))
			say([["K", "Agora ouve a minha canção... e devolve-ma."]])
		3:
			say([
				["K", "Antes de seguires... chega-te a mim. Devagar."],
				["K", "Os espinhos crescem quando me apressam. Fica perto até eles baixarem."],
			])
			k_body.start_approach()
		4:
			say([["K", "Ninguém se encontra sozinho. Chama as três ao mesmo tempo."]])
			for pillar in [Vector2(-95, -40), Vector2(95, -40)]:
				geometry.add_dynamic_obstacle(WorldGeometry.noisy_ellipse(pillar, 34, 34, 0.15, 999, 16))
			fov.set_world_segments(geometry.segments)
			var spec := {"id": "k:trio", "area": "k", "group": "same_wave", "blobs": [
				{"id": "", "pos": [-205, -70], "note": 6, "need": "NOTE"},
				{"id": "", "pos": [205, -70], "note": 6, "need": "NOTE"},
				{"id": "", "pos": [0, 210], "note": 6, "need": "NOTE"},
			]}
			var blobs := EncounterSpawner.spawn(spec, _creatures, geometry)
			_final_trio = blobs[0].group
			_final_trio.resolved.connect(func(_g: EchoBlobGroup) -> void: _start_final_stage(5))
			k_body.global_position = Vector2(0, -235)  # out of the way of the trio and pillars
		5:
			k_body.start_silence(6.0)
			say([["K", "E agora... não digas nada. Só ouve."]])


func _on_final_fragment_freed(_blob: EchoBlob) -> void:
	for blob in _final_fragments:
		if not blob.is_freed():
			return
	_start_final_stage(2)


func _on_k_mode_completed(mode: int) -> void:
	if mode == VassalBody.Mode.MELODY and _final_stage == 2:
		_start_final_stage(3)
	elif mode == VassalBody.Mode.APPROACH and _final_stage == 3:
		_start_final_stage(4)
	elif mode == VassalBody.Mode.SILENCE and _final_stage == 5:
		_complete_game()


func _complete_game() -> void:
	_final_stage = 6
	for gate in _finale_gates:
		if is_instance_valid(gate):
			gate.open()
	k_body.completed = true
	k_body.remove_from_group("ping_blobs")
	_game.free_vassal("K")
	_game.progress["ended"] = true
	_game.save_game()
	_update_grading(true)
	player.controls_enabled = false
	emitter.input_enabled = false
	var grow := k_body.create_tween().set_parallel(true)
	grow.tween_property(k_body, "radius", 80.0, 3.0).set_trans(Tween.TRANS_SINE)
	k_body.glow = 1.0
	k_body.base_color = Color(0.05, 0.05, 0.07)
	geometry.set_floor_color("hub", BLACK_NASCENTE)
	var lines := ElderSpeech.lines(_game.progress)
	say(lines, "K", "ending")
	dialogue.finished.connect(func(sequence: String) -> void:
		if sequence == "ending":
			var ending := ENDING_SCRIPT.new() as CanvasLayer
			add_child(ending)
	)


# --- Input ------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("echo_chord"):
		_toggle_chord()
	elif event.is_action_pressed("echo_note_names"):
		EchoBlob.always_show_note_names = not EchoBlob.always_show_note_names
		_game.settings["note_names_always"] = EchoBlob.always_show_note_names
		_game.save_settings()
		hud.show_message("Nomes das notas: " + ("sempre visíveis" if EchoBlob.always_show_note_names else "só quando a blob responde"), 2.5)
	elif event.is_action_pressed("echo_pause"):
		_pause_menu.call("open")
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).physical_keycode
		if key == KEY_H:
			hud.toggle_help()
		else:
			return
	else:
		return
	get_viewport().set_input_as_handled()


# --- DEBUG (F8 panel; testing only) --------------------------------------------------------

func _walkable_near(target: Vector2, distance: float) -> Vector2:
	for ring in [distance, distance * 0.6, distance * 1.4]:
		for index in range(16):
			var probe: Vector2 = target + Vector2.RIGHT.rotated(TAU * index / 16.0) * float(ring)
			if geometry.is_walkable(probe, 30.0):
				return probe
	return target


func debug_teleport(region: String, marker: String) -> void:
	var target: Vector2 = geometry.region_data(region)["markers"][marker]
	if marker == "vassal":
		target = _walkable_near(target, 320.0)
	elif marker == "center":
		target = Vector2(0, 180)
	player.global_position = target
	player.velocity = Vector2.ZERO


func _area_of(letter: String) -> String:
	for area in _game.AREA_VASSAL:
		if _game.AREA_VASSAL[area] == letter:
			return area
	return ""


func debug_wake_vassal(letter: String) -> void:
	var area := _area_of(letter)
	generate_area(area)
	var vassal: VassalBody = vassals[letter]
	if not vassal.awake:
		vassal.wake()
	debug_teleport(area, "vassal")
	hud.show_message("[DEBUG] Vassalo %s acordado." % letter, 2.5)


func debug_free_vassal(letter: String) -> void:
	var vassal: VassalBody = vassals[letter]
	if vassal.completed:
		return
	if not vassal.awake:
		vassal.wake()
	vassal.call("_finish_mode")


func debug_free_current_area() -> void:
	var area := current_region
	if not area in _area_blobs:
		return
	var needed := area_needed(area) - area_freed(area) if area in _game.AREAS else area_total(area)
	for blob in _area_blobs[area]:
		if needed <= 0:
			break
		if not blob.is_freed():
			blob.set_dormant(false)
			blob.free_blob()
			needed -= 1
	hud.show_message("[DEBUG] Blobs ajudadas em %s." % _region_title(area), 2.5)


func debug_finish_clearing() -> void:
	for blob in _area_blobs["clearing"]:
		if not blob.is_freed():
			blob.set_dormant(false)
			blob.free_blob()
	debug_teleport("hub", "test_start")


func debug_grant_chords() -> void:
	_game.grant_all_chords()
	_apply_tone()
	hud.show_message("[DEBUG] Todos os acordes.", 2.5)


func debug_go_final() -> void:
	if not _game.progress["clearing_done"]:
		debug_finish_clearing()
	for letter in ["Y", "C", "M"]:
		debug_free_vassal(letter)
	debug_teleport("hub", "test_start")

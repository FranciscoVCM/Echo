class_name EchoWorld
extends Node2D
## Root of an Echo exploration area. Connects the player, the blobs and the HUD:
## note colours on the player's Ping, chord unlocks, recruit/absorb choices, companions
## relaying pings and the world slowly regaining colour as creatures are helped.
##
## Everything marked PROTOTYPE is a reversible default, not a confirmed group decision.

@export_category("Progression (PROTOTYPE)")
## Resolved encounters (a single blob or a whole group) needed to unlock the reward chord.
@export_range(1, 10, 1) var chord_unlock_after_encounters := 2
@export_enum("Dó", "Ré", "Mi", "Fá", "Sol", "Lá", "Si") var chord_reward_root := 0

@export_category("Recruit / Absorb (PROTOTYPE)")
@export_range(40.0, 300.0, 5.0) var choice_distance := 130.0
## Absorbing: the player's body grows and sees further.
@export_range(0.0, 10.0, 0.5) var absorb_size_bonus := 2.5
@export_range(0.0, 120.0, 5.0) var absorb_vision_bonus := 35.0
## Recruiting: companions repeat each of the player's pings from where they are.
@export_range(0.1, 1.0, 0.05) var relay_range_ratio := 0.6
@export_range(0.0, 1.5, 0.05) var relay_delay := 0.3

@export_category("World colour")
@export var floor_lost_color := Color(0.17, 0.19, 0.21, 1.0)
@export var floor_restored_color := Color(0.16, 0.24, 0.24, 1.0)

var _player: PlayerController
var _emitter: PingEmitter
var _visual: BlobVisual
var _fov: Node
var _floor: Polygon2D
var _hud: EchoHud
var _blobs: Array[EchoBlob] = []
var _encounter_keys: Array = []
var _resolved_encounters: Dictionary = {}
var _unlocked_chords: Dictionary = {}
var _chord_mode := false
var _followers: Array[EchoBlob] = []
var _absorbed_count := 0
var _choice_target: EchoBlob
var _restoration := 0.0
var _first_free_explained := false


func _ready() -> void:
	_player = get_node("Player") as PlayerController
	_emitter = _player.get_node("PingEmitter") as PingEmitter
	_visual = _player.get_node("BlobVisual") as BlobVisual
	_fov = get_node_or_null("FieldOfView")
	_floor = get_node_or_null("Floor") as Polygon2D
	_hud = EchoHud.new()
	_hud.name = "EchoHud"
	add_child(_hud)

	for node in get_tree().get_nodes_in_group("echo_blobs"):
		var blob := node as EchoBlob
		if blob == null or not is_ancestor_of(blob):
			continue
		_blobs.append(blob)
		blob.freed.connect(_on_blob_freed)
		var key: Object = blob.group if blob.group != null else blob
		if not key in _encounter_keys:
			_encounter_keys.append(key)

	_emitter.ping_tone_changed.connect(_on_tone_changed)
	_emitter.ping_emitted.connect(_on_player_ping)
	_apply_tone()
	_set_restoration(0.0, false)
	_hud.set_unlocked_chords(_unlocked_chords)
	_update_status()
	_hud.show_message("Há criaturas perdidas nesta clareira. Ouve-as... e responde-lhes.", 6.0)


func _process(_delta: float) -> void:
	_update_choice_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).physical_keycode
	match key:
		KEY_Q:
			_toggle_chord()
		KEY_Z:
			if _choice_target != null:
				recruit(_choice_target)
		KEY_X:
			if _choice_target != null:
				absorb(_choice_target)
		KEY_H:
			_hud.toggle_help()
		KEY_N:
			EchoBlob.always_show_note_names = not EchoBlob.always_show_note_names
			_hud.show_message("Nomes das notas: " + ("sempre visíveis" if EchoBlob.always_show_note_names else "só depois de a blob responder"), 2.5)
		KEY_F9:
			get_tree().reload_current_scene()
		_:
			return
	get_viewport().set_input_as_handled()


# --- Notes and chords ------------------------------------------------------------------

func _on_tone_changed(_tone_index: int, _note_name: String, _frequency: float) -> void:
	_apply_tone()


func _toggle_chord() -> void:
	var pitch_class := EchoNotes.pitch_class(_emitter.ping_tone_index)
	if _unlocked_chords.is_empty():
		_hud.show_message("Ainda não conheces nenhum acorde.", 2.0)
		return
	if not _unlocked_chords.get(pitch_class, false):
		var known: Array[String] = []
		for root in _unlocked_chords:
			known.append(EchoNotes.chord_name_for(root))
		_hud.show_message("Conheces: %s. Escolhe essa nota para o usar." % ", ".join(known), 2.5)
		return
	_chord_mode = not _chord_mode
	_apply_tone()


func _apply_tone() -> void:
	var tone := _emitter.ping_tone_index
	_emitter.ping_color = EchoNotes.color_for(tone)
	var extras := PackedInt32Array()
	if _chord_mode and _unlocked_chords.get(EchoNotes.pitch_class(tone), false):
		extras = EchoNotes.triad_extras(tone)
	_emitter.chord_tone_indices = extras
	var colors: Array[Color] = []
	for degree in extras:
		colors.append(EchoNotes.color_for(degree))
	_emitter.chord_colors = colors
	_hud.set_tone(tone, extras)


func unlock_chord(root: int) -> void:
	_unlocked_chords[EchoNotes.pitch_class(root)] = true
	_hud.set_unlocked_chords(_unlocked_chords)
	var extras := EchoNotes.triad_extras(root)
	_hud.show_message(
		"Algo em ti ressoa com o que ouviste. Aprendeste o acorde %s (%s · %s · %s).\nEscolhe %s e carrega Q para o alternar."
		% [EchoNotes.chord_name_for(root), EchoNotes.name_for(root), EchoNotes.name_for(extras[0]), EchoNotes.name_for(extras[1]), EchoNotes.name_for(root)],
		7.0
	)
	_update_status()


# --- Blobs -----------------------------------------------------------------------------

func _on_blob_freed(blob: EchoBlob) -> void:
	var key: Object = blob.group if blob.group != null else blob
	var newly_resolved := not _resolved_encounters.has(key)
	_resolved_encounters[key] = true
	var freed_count := 0
	for candidate in _blobs:
		if candidate.state != EchoBlob.State.LOST and candidate.state != EchoBlob.State.WAKING:
			freed_count += 1
	_set_restoration(float(freed_count) / maxf(_blobs.size(), 1.0), true)
	if newly_resolved:
		if not _first_free_explained:
			_first_free_explained = true
			_hud.show_message("Ela confia em ti agora. Aproxima-te para decidir: caminhar juntas, ou tornar-se parte de ti.\n(Também podes simplesmente seguir caminho.)", 6.5)
		if _resolved_encounters.size() >= chord_unlock_after_encounters and not _unlocked_chords.get(chord_reward_root, false):
			unlock_chord(chord_reward_root)
	if _resolved_encounters.size() >= _encounter_keys.size():
		_hud.show_message("A clareira voltou a ter cor. (Fim da fatia vertical.)", 6.0)
	_update_status()


func recruit(blob: EchoBlob) -> void:
	if blob.decided or not blob.is_freed():
		return
	var index := _followers.size()
	var offset := Vector2(-52.0, 30.0).rotated(index * 1.25) * (1.0 + 0.25 * index)
	blob.start_following(_player, offset)
	_followers.append(blob)
	_hud.show_message("%s caminha contigo. Repete os teus pings a partir de onde está." % EchoNotes.name_for(blob.note), 3.5)
	_update_status()


func absorb(blob: EchoBlob) -> void:
	if blob.decided or not blob.is_freed():
		return
	blob.absorb_into(_player)
	_absorbed_count += 1
	_visual.body_radius += absorb_size_bonus
	_visual.body_color = _visual.body_color.lerp(blob.get_true_color(), 0.12)
	if _fov != null:
		_fov.set("vision_radius", float(_fov.get("vision_radius")) + absorb_vision_bonus)
	_hud.show_message("%s faz agora parte de ti. Sentes-te maior e vês mais longe." % EchoNotes.name_for(blob.note), 3.5)
	_update_status()


func get_followers() -> Array[EchoBlob]:
	return _followers


func _on_player_ping(_origin: Vector2, is_echo: bool, charge: float, tone_index: int, _frequency: float) -> void:
	if is_echo or _followers.is_empty():
		return
	var wave_range := lerpf(_emitter.minimum_ping_range, _emitter.maximum_ping_range, charge) * relay_range_ratio
	var extras := _emitter.chord_tone_indices.duplicate()
	for index in range(_followers.size()):
		var follower := _followers[index]
		var timer := get_tree().create_timer(relay_delay + 0.12 * index)
		timer.timeout.connect(follower.relay_ping.bind(tone_index, extras, wave_range))


func _update_choice_prompt() -> void:
	var nearest: EchoBlob = null
	var nearest_distance := choice_distance
	for blob in _blobs:
		if blob.decided or not blob.is_freed():
			continue
		var distance := blob.global_position.distance_to(_player.global_position)
		if distance < nearest_distance:
			nearest = blob
			nearest_distance = distance
	_choice_target = nearest
	if nearest == null:
		_hud.set_prompt("")
	else:
		_hud.set_prompt("%s está tranquila contigo.\n[Z] Recrutar — viaja contigo e repete os teus pings      [X] Absorver — ficas maior e vês mais longe" % EchoNotes.name_for(nearest.note))


func _set_restoration(value: float, animate: bool) -> void:
	_restoration = value
	for node in get_tree().get_nodes_in_group("restorable"):
		if not is_ancestor_of(node):
			continue
		if animate:
			create_tween().tween_property(node, "restoration", value, 2.0).set_trans(Tween.TRANS_SINE)
		else:
			node.set("restoration", value)
	if _floor != null:
		var target := floor_lost_color.lerp(floor_restored_color, value)
		if animate:
			create_tween().tween_property(_floor, "color", target, 2.0)
		else:
			_floor.color = target


func _update_status() -> void:
	var freed := 0
	for blob in _blobs:
		if blob.state != EchoBlob.State.LOST and blob.state != EchoBlob.State.WAKING:
			freed += 1
	var lines: Array[String] = ["Blobs ajudadas: %d / %d" % [freed, _blobs.size()]]
	if _unlocked_chords.is_empty():
		lines.append("Acordes: nenhum")
	else:
		var names: Array[String] = []
		for root in _unlocked_chords:
			names.append(EchoNotes.chord_name_for(root))
		lines.append("Acordes: %s  (Q)" % ", ".join(names))
	_hud.set_status("\n".join(lines))

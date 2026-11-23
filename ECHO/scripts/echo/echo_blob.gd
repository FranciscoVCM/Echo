class_name EchoBlob
extends PingDummy
## A creature of the world that has to be understood, not beaten.
##
## Builds on the existing PingDummy (organic body, FOV fade, answering PingEmitter).
## Every blob's colour is a note (EchoNotes): it only listens to a Ping carrying that
## note (a chord counts if one of its tones matches). On top of that it has a
## temperament (`need`). Feedback is never colour-only: a wrong note makes it sing its
## own note back, and timers / counts are drawn on the blob when they matter.

signal freed(blob: EchoBlob)

enum Need {
	NOTE,  ## Hear its note `required_hits` times.
	SHY,  ## Its note wakes it; then it needs `shy_silence` s without ANY ping reaching it.
	STIMULATED,  ## `required_hits` correct pings within `stim_window` seconds.
	GENTLE,  ## Only soft (low charge), close pings of its note; a strong one scares it.
	CAUTIOUS,  ## Flees if you rush at it; come close slowly, then ping its note.
	WARMTH,  ## Stay close for a while; once warm it wants its note once.
	MELODY,  ## Answer its little song: the notes of `melody`, in order.
	PUSH,  ## Lost from its nest: nudge it home with your body.
}
enum State { LOST, WAKING, FREED }

const PROXIMITY_CLOSE := 130.0

@export_category("Echo Blob")
@export var blob_id := ""
@export var area := ""
@export_enum("Dó", "Ré", "Mi", "Fá", "Sol", "Lá", "Si") var note := 0
@export var need: Need = Need.NOTE
@export_range(1, 6, 1) var required_hits := 1
## Invisible even inside the field of view until a Ping has touched it once.
@export var hidden_until_pinged := false
## Colourless until freed: the player has to recognise its note by ear.
@export var grey := false
## Sings its note (or melody) regularly and clearly.
@export var singer := false
## Never moves (e.g. sits on a lily pad in a lake).
@export var anchored := false

@export_category("Temperament")
@export_range(1.0, 20.0, 0.5) var shy_silence := 5.0
@export_range(2.0, 20.0, 0.5) var stim_window := 7.0
@export_range(0.1, 1.0, 0.05) var gentle_max_charge := 0.35
@export_range(80.0, 500.0, 10.0) var gentle_distance := 240.0
@export_range(40.0, 300.0, 5.0) var cautious_speed := 120.0
@export_range(100.0, 500.0, 10.0) var cautious_radius := 240.0
@export_range(1.0, 15.0, 0.5) var warmth_duration := 4.0
@export_range(50.0, 250.0, 5.0) var warmth_radius := 100.0
@export var melody := PackedInt32Array()
@export var nest_position := Vector2.ZERO
@export_range(20.0, 120.0, 5.0) var nest_radius := 46.0

@export_category("Voice")
@export_range(2.0, 30.0, 0.5) var call_interval := 7.0
@export_range(-40.0, 6.0, 1.0) var voice_volume_db := -19.0
@export_range(80.0, 600.0, 10.0) var answer_range := 260.0

## Shared references / options set by the world.
static var always_show_note_names := false
static var player: Node2D

## 0..1: how attuned the player is to this blob's area (set by the world). Higher = easier.
var ease := 0.0
## Sound area tier 3: wobble when the player's selected note matches.
var resonance_hint := false

var state := State.LOST
## Tutorial: not its turn yet. Invisible, silent and deaf until the guide reaches it.
var dormant := false
var group: EchoBlobGroup
var hits := 0
var has_answered := false
var group_mark := 0.0
var group_window_ratio := -1.0

var _true_color := Color.WHITE
var _base_radius := 24.0
var _shy_remaining := 0.0
var _stim_remaining := 0.0
var _warmth := 0.0
var _warm := false
var _melody_step := 0
var _revealed := false
var _call_timer := 0.0
var _call_ring := 0.0
var _time := 0.0
var _jolt := 0.0
var _hit_flash := 0.0
var _droop := 0.0
var _scared := 0.0
var _emote := ""
var _emote_time := 0.0
var _flee_target := Vector2.ZERO
var _fleeing := false
var _voice: AudioStreamPlayer2D
var _sing_queue: Array[int] = []
var _sing_timer := 0.0


func _ready() -> void:
	super._ready()
	add_to_group("echo_blobs")
	# The mask stays empty at rest: a resting body whose mask includes the walls is paired
	# with the whole world collision every physics step (very expensive). We only enable
	# walls (2) + water (8) for the instant the creature actually moves (see _slide()).
	collision_mask = 0
	if need == Need.MELODY and melody.is_empty():
		melody = PackedInt32Array([note, posmod(note + 2, 7)])
	if need == Need.MELODY:
		note = melody[0]
	_true_color = EchoNotes.color_for(note)
	_base_radius = body_radius
	_ping_emitter.respond_to_ping = false
	_ping_emitter.ping_tone_index = note
	_ping_emitter.ping_color = _display_color()
	_ping_emitter.ping_cooldown = 1.2
	_voice = AudioStreamPlayer2D.new()
	_voice.name = "Voice"
	_voice.max_distance = 1100.0
	_voice.attenuation = 1.6
	add_child(_voice)
	_time = randf() * 10.0
	_call_timer = randf_range(1.0, call_interval)
	if need == Need.PUSH and nest_position == Vector2.ZERO:
		nest_position = global_position + Vector2(160, 0)
	var game := get_node_or_null("/root/Game")
	if game != null and not blob_id.is_empty() and game.is_freed(blob_id):
		_set_freed_silently()
	_apply_look()


func _process(delta: float) -> void:
	super._process(delta)
	_time += delta
	_jolt = move_toward(_jolt, 0.0, delta * 2.5)
	_hit_flash = move_toward(_hit_flash, 0.0, delta * 1.8)
	_droop = move_toward(_droop, 0.0, delta * 0.8)
	_scared = move_toward(_scared, 0.0, delta * 1.2)
	_call_ring = move_toward(_call_ring, 0.0, delta * 0.7)
	_emote_time = maxf(_emote_time - delta, 0.0)
	_process_singing(delta)
	match state:
		State.LOST:
			_process_lost(delta)
		State.WAKING:
			_shy_remaining -= delta
			if _shy_remaining <= 0.0:
				free_blob()
		State.FREED:
			_call_timer -= delta
			if _call_timer <= 0.0:
				_call_timer = randf_range(9.0, 16.0)
				_play_voice(note, -12.0)
	_apply_look()
	if visible:
		queue_redraw()


func _process_lost(delta: float) -> void:
	if dormant:
		return
	var interval := call_interval * lerpf(1.0, 0.5, ease) if singer else call_interval
	_call_timer -= delta
	if _call_timer <= 0.0:
		_call_timer = interval * randf_range(0.85, 1.2)
		_call_ring = 1.0
		if need == Need.MELODY:
			_sing_melody()
		else:
			_play_voice(note, -3.0 if singer else -7.0)
	match need:
		Need.STIMULATED:
			if _stim_remaining > 0.0:
				_stim_remaining -= delta
				if _stim_remaining <= 0.0:
					hits = 0
					droop()
		Need.WARMTH:
			if not _warm:
				var near := player != null and player.global_position.distance_to(global_position) <= warmth_radius
				var duration := warmth_duration * lerpf(1.0, 0.55, ease)
				if near:
					_warmth = minf(_warmth + delta / duration, 1.0)
					if _warmth >= 1.0:
						_warm = true
						_hit_flash = 1.0
						_set_emote("<3", 1.5)
						_play_voice(note, -4.0)
				else:
					_warmth = maxf(_warmth - delta / (duration * 2.0), 0.0)


func _physics_process(delta: float) -> void:
	if state != State.LOST or player == null:
		return
	match need:
		Need.CAUTIOUS:
			_physics_cautious(delta)
		Need.PUSH:
			_physics_push(delta)
		Need.GENTLE:
			if _fleeing:
				_move_toward_target(delta, 150.0)


func _physics_cautious(delta: float) -> void:
	var to_player := player.global_position - global_position
	var player_velocity: Vector2 = player.get("velocity") if "velocity" in player else Vector2.ZERO
	var threshold := cautious_speed * lerpf(1.0, 1.7, ease)
	var approaching := player_velocity.length() > threshold and player_velocity.dot(-to_player) > 0.0
	if not _fleeing and to_player.length() < cautious_radius and approaching:
		_fleeing = true
		_flee_target = global_position - to_player.normalized() * 130.0
		_set_emote("!", 1.0)
		_jolt = 0.6
		_play_voice(note, -8.0)
		_add_stat("scares")
	if _fleeing:
		_move_toward_target(delta, 200.0)


func _physics_push(delta: float) -> void:
	var to_blob := global_position - player.global_position
	var player_velocity: Vector2 = player.get("velocity") if "velocity" in player else Vector2.ZERO
	var touching := to_blob.length() < collision_radius + 28.0
	if touching and player_velocity.dot(to_blob.normalized()) > 15.0:
		velocity = to_blob.normalized() * maxf(player_velocity.length() * 0.95, 60.0)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
	_slide()
	if global_position.distance_to(nest_position) <= nest_radius:
		free_blob()


func _slide() -> void:
	if anchored:
		return
	collision_mask = 2 | 8
	move_and_slide()
	collision_mask = 0


func _move_toward_target(_delta: float, speed: float) -> void:
	var offset := _flee_target - global_position
	if offset.length() < 6.0:
		_fleeing = false
		velocity = Vector2.ZERO
		return
	velocity = offset.normalized() * speed
	_slide()
	if get_slide_collision_count() > 0:
		_fleeing = false
		velocity = Vector2.ZERO


# --- Ping reception -------------------------------------------------------------------

func set_dormant(value: bool) -> void:
	dormant = value
	if dormant:
		visible = false
	else:
		_call_timer = 0.3  # announce itself as soon as it becomes part of the story


func receive_ping_wave(wave: PingWave) -> void:
	if wave.is_echo() or dormant:
		return
	_revealed = true
	EchoMarker.spawn(global_position, _display_color(), body_radius, get_tree())
	var matched := wave.carries_pitch_class(_expected_note())
	match state:
		State.LOST:
			_on_lost_ping(wave, matched)
		State.WAKING:
			# Any sound at all, right note or not, startles it and restarts its calm.
			_shy_remaining = shy_silence
			_jolt = 1.0
			_set_emote("!", 0.8)
			_add_stat("startles")
		State.FREED:
			_hit_flash = 0.5


func _on_lost_ping(wave: PingWave, matched: bool) -> void:
	if group != null and group.mode != EchoBlobGroup.Mode.TOGETHER:
		if matched:
			_hit_flash = 1.0
		else:
			_answer()
		group.on_member_pinged(self, matched, wave.get_instance_id())
		return
	if need == Need.PUSH:
		_answer()
		return
	if not matched:
		if need == Need.MELODY:
			# Keep the progress; it just sings the note it is waiting for.
			has_answered = true
			_jolt = 0.6
			_add_stat("wrong_notes")
			_play_voice(_expected_note(), 0.0)
		else:
			_answer()
		return
	var distance := wave.global_position.distance_to(global_position)
	match need:
		Need.NOTE:
			_count_hit()
		Need.SHY:
			_wake()
		Need.STIMULATED:
			if hits == 0:
				_stim_remaining = stim_window
			_count_hit()
		Need.GENTLE:
			var max_charge := lerpf(gentle_max_charge, minf(gentle_max_charge + 0.3, 0.9), ease)
			if wave.get_charge() > max_charge:
				hits = 0
				_scared = 1.0
				_fleeing = not anchored
				_flee_target = global_position + (global_position - wave.global_position).normalized() * 90.0
				_set_emote("!", 1.0)
				_add_stat("scares")
				_play_voice(note, -6.0)
			elif distance > gentle_distance:
				_set_emote("?", 1.2)
			else:
				_count_hit()
		Need.CAUTIOUS:
			if _fleeing:
				return
			if distance <= PROXIMITY_CLOSE:
				_add_stat("gentle_approaches")
				free_blob()
			else:
				_set_emote("...", 1.4)
				_play_voice(note, -10.0)
		Need.WARMTH:
			if _warm:
				free_blob()
			else:
				_set_emote("...", 1.2)
		Need.MELODY:
			_melody_step += 1
			_hit_flash = 1.0
			_play_voice(_expected_note_for(_melody_step - 1), -4.0)
			if _melody_step >= melody.size():
				free_blob()


func _count_hit() -> void:
	hits += 1
	_hit_flash = 1.0
	if hits >= required_hits:
		free_blob()
	else:
		_play_voice(note, -4.0)


func _expected_note() -> int:
	if need == Need.MELODY:
		return _expected_note_for(_melody_step)
	return note


func _expected_note_for(step: int) -> int:
	return melody[clampi(step, 0, melody.size() - 1)]


func _wake() -> void:
	state = State.WAKING
	_shy_remaining = shy_silence
	_hit_flash = 1.0
	_play_voice(note, -8.0)


## The blob replies with its own note: the player learns what it is listening for.
func _answer() -> void:
	has_answered = true
	_jolt = 0.6
	_add_stat("wrong_notes")
	if need == Need.MELODY:
		_sing_melody()
		return
	if _ping_emitter.ping_cooldown_remaining <= 0.0:
		_ping_emitter.ping_tone_index = note
		_ping_emitter.ping_color = _display_color()
		_ping_emitter.chord_tone_indices = PackedInt32Array()
		_ping_emitter.emit_ping(true, answer_range, 0.4)
		_play_voice(note, 0.0)


func free_blob() -> void:
	if state == State.FREED:
		return
	state = State.FREED
	hits = required_hits
	has_answered = true
	group_mark = 0.0
	group_window_ratio = -1.0
	_fleeing = false
	velocity = Vector2.ZERO
	_hit_flash = 1.0
	_call_timer = randf_range(3.0, 6.0)
	_play_voice(note, 2.0)
	EchoMarker.spawn(global_position, _true_color, body_radius, get_tree(), true)
	var game := get_node_or_null("/root/Game")
	if game != null:
		game.mark_freed(blob_id, note, area)
	freed.emit(self)


func _set_freed_silently() -> void:
	state = State.FREED
	hits = required_hits
	has_answered = true
	_revealed = true
	if need == Need.PUSH:
		global_position = nest_position


## Visual/audio "that didn't work out", used for expiring windows and broken melodies.
func droop() -> void:
	_droop = 1.0
	_play_voice(note, -12.0)


func is_freed() -> bool:
	return state == State.FREED


func is_shy_waking() -> bool:
	return state == State.WAKING


func get_shy_remaining() -> float:
	return _shy_remaining


func get_true_color() -> Color:
	return _true_color


func is_light_source() -> bool:
	return state == State.FREED and visible


# --- Singing ---------------------------------------------------------------------------

func _sing_melody() -> void:
	_sing_queue.clear()
	for degree in melody:
		_sing_queue.append(degree)
	_sing_timer = 0.0
	_call_ring = 1.0


func _process_singing(delta: float) -> void:
	if _sing_queue.is_empty():
		return
	_sing_timer -= delta
	if _sing_timer <= 0.0:
		var degree: int = _sing_queue.pop_front()
		_play_voice(degree, 0.0)
		_jolt = 0.25
		_sing_timer = 0.55


func _play_voice(degree: int, volume_offset_db: float) -> void:
	if _voice == null:
		return
	_voice.stream = EchoNotes.voice_stream(degree)
	_voice.volume_db = voice_volume_db + volume_offset_db
	_voice.play()


func _set_emote(text: String, duration: float) -> void:
	_emote = text
	_emote_time = duration


func _add_stat(key: String) -> void:
	var game := get_node_or_null("/root/Game")
	if game != null:
		game.add_stat(key)


# --- Field of view ---------------------------------------------------------------------

func set_fov_visible(is_in_view: bool) -> void:
	if dormant:
		visible = false
		return
	if hidden_until_pinged and not _revealed and state != State.FREED:
		is_in_view = false
	super.set_fov_visible(is_in_view)


# --- Look ------------------------------------------------------------------------------

func _display_color() -> Color:
	if grey and state != State.FREED:
		return Color(0.62, 0.64, 0.68)
	return _true_color


func _apply_look() -> void:
	var shown := _display_color()
	var gray := Color(shown.get_luminance(), shown.get_luminance(), shown.get_luminance())
	var base := shown
	var radius_scale := 1.0
	match state:
		State.LOST:
			base = shown.lerp(gray, 0.45).darkened(0.15)
			radius_scale = 0.84 if need == Need.SHY else 0.96 + sin(_time * 1.6) * 0.02
			if need == Need.WARMTH and not _warm:
				radius_scale = lerpf(0.82, 0.96, _warmth)
		State.WAKING:
			var calm := 1.0 - clampf(_shy_remaining / shy_silence, 0.0, 1.0)
			base = shown.lerp(gray, 0.45 * (1.0 - calm)).darkened(0.15 * (1.0 - calm))
			radius_scale = lerpf(0.88, 1.0, calm) + sin(_time * lerpf(22.0, 4.0, calm)) * 0.02 * (1.0 - calm)
		State.FREED:
			radius_scale = 1.0 + sin(_time * 3.0) * 0.04
	radius_scale *= 1.0 - _droop * 0.12 - _scared * 0.25
	body_radius = _base_radius * radius_scale
	body_color = base.lerp(Color.WHITE, _hit_flash * 0.45)
	outline_color = base.darkened(0.5) if state == State.LOST else shown.lightened(0.35)


func _resonating() -> bool:
	if not resonance_hint or state != State.LOST or player == null:
		return false
	if player.global_position.distance_to(global_position) > 320.0:
		return false
	var emitter := player.get_node_or_null("PingEmitter") as PingEmitter
	return emitter != null and EchoNotes.pitch_class(emitter.ping_tone_index) == EchoNotes.pitch_class(_expected_note())


func _draw() -> void:
	var shown := _display_color()
	if need == Need.PUSH and state == State.LOST:
		var nest_local := to_local(nest_position)
		var pulse := 0.5 + sin(_time * 2.0) * 0.5
		draw_circle(nest_local, nest_radius, Color(shown, 0.08 + 0.05 * pulse))
		draw_arc(nest_local, nest_radius, 0.0, TAU, 40, Color(shown, 0.4 + 0.2 * pulse), 2.0, true)
		for index in range(5):
			var angle := TAU * index / 5.0 + _time * 0.3
			draw_circle(nest_local + Vector2.RIGHT.rotated(angle) * nest_radius * 0.55, 5.0, Color(shown.darkened(0.3), 0.5))

	if _call_ring > 0.0:
		var ring_radius := body_radius * (1.3 + (1.0 - _call_ring) * 1.8)
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 48, Color(shown, 0.4 * _call_ring), 2.0, true)

	var shake := Vector2(sin(_time * 38.0) * 4.0 * _jolt, 0.0)
	if state == State.WAKING:
		shake.x += sin(_time * 30.0) * 1.2 * clampf(_shy_remaining / shy_silence, 0.0, 1.0)
	if anchored:
		# Lily pad under creatures that live on the water.
		draw_circle(Vector2(0, 6), _base_radius * 1.25, Color(0.25, 0.5, 0.3, 0.85))
		draw_arc(Vector2(0, 6), _base_radius * 1.25, 0.2, TAU - 0.3, 24, Color(0.4, 0.7, 0.45, 0.9), 2.0, true)
	if _resonating():
		shake += Vector2(sin(_time * 55.0), cos(_time * 47.0)) * 1.6
		draw_circle(Vector2.ZERO, body_radius + 10.0, Color(1, 1, 1, 0.08 + 0.05 * sin(_time * 12.0)))
	var bob := Vector2(0.0, sin(_time * 3.0) * 2.0) if state == State.FREED else Vector2.ZERO
	draw_set_transform(shake + bob + Vector2(0.0, _droop * 4.0))
	super._draw()
	_draw_face()
	draw_set_transform(Vector2.ZERO)

	if group_mark > 0.01:
		var mark_color := Color(shown.lightened(0.3), group_mark)
		draw_arc(Vector2.ZERO, body_radius + 8.0, 0.0, TAU, 48, Color(mark_color, 0.3 * group_mark), 5.0, true)
		draw_arc(Vector2.ZERO, body_radius + 8.0, 0.0, TAU, 48, mark_color, 2.0, true)

	if state == State.LOST:
		_draw_progress(shown)
	elif state == State.WAKING:
		var calm := 1.0 - clampf(_shy_remaining / shy_silence, 0.0, 1.0)
		_draw_meter(calm, shown.lightened(0.4))
		_draw_small_text("%.0f s" % ceilf(_shy_remaining), Vector2(0, -body_radius - 22.0), Color(1, 1, 1, 0.85))

	if _emote_time > 0.0:
		var alpha := minf(_emote_time / 0.3, 1.0)
		_draw_small_text(_emote, Vector2(body_radius * 0.7, -body_radius - 6.0), Color(1, 1, 1, alpha), 20)

	var show_name := (has_answered and not grey) or state == State.FREED or always_show_note_names
	if show_name:
		var text := EchoNotes.name_for(note)
		if need == Need.MELODY and state != State.FREED and not grey:
			var names: Array[String] = []
			for degree in melody:
				names.append(EchoNotes.name_for(degree))
			text = " · ".join(names)
		_draw_small_text(text, Vector2(0, body_radius + 20.0), _true_color.lightened(0.45) if state == State.FREED or not grey else Color(0.85, 0.86, 0.9))


## Pips (counts) and rings (timers) so the player can always read what is happening.
func _draw_progress(shown: Color) -> void:
	var pip_total := 0
	var pip_done := 0
	match need:
		Need.NOTE, Need.GENTLE, Need.STIMULATED:
			if required_hits > 1:
				pip_total = required_hits
				pip_done = hits
		Need.MELODY:
			pip_total = melody.size()
			pip_done = _melody_step
	if pip_total > 0:
		var spacing := 11.0
		var start := -spacing * (pip_total - 1) * 0.5
		for index in range(pip_total):
			var at := Vector2(start + spacing * index, -body_radius - 12.0)
			var pip_color := shown.lightened(0.4)
			if need == Need.MELODY and (not grey or index < pip_done):
				pip_color = EchoNotes.color_for(melody[index])
			if index < pip_done:
				draw_circle(at, 4.0, pip_color)
			else:
				draw_arc(at, 4.0, 0.0, TAU, 16, Color(pip_color, 0.6), 1.5, true)
	if need == Need.STIMULATED and _stim_remaining > 0.0:
		_draw_meter(_stim_remaining / stim_window, Color(1.0, 0.85, 0.4))
		_draw_small_text("%.0f s" % ceilf(_stim_remaining), Vector2(0, -body_radius - 26.0), Color(1, 0.9, 0.6, 0.9))
	if need == Need.WARMTH:
		if _warm:
			_draw_meter(1.0, Color(1.0, 0.7, 0.75))
		elif _warmth > 0.0:
			_draw_meter(_warmth, Color(1.0, 0.6, 0.55))
			draw_arc(Vector2.ZERO, warmth_radius, 0.0, TAU, 48, Color(1.0, 0.6, 0.55, 0.12), 2.0, true)


func _draw_meter(ratio: float, color: Color) -> void:
	draw_arc(Vector2.ZERO, body_radius + 10.0, 0.0, TAU, 48, Color(1, 1, 1, 0.12), 3.0, true)
	if ratio > 0.0:
		draw_arc(Vector2.ZERO, body_radius + 10.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(ratio, 0.0, 1.0), 48, Color(color, 0.9), 3.0, true)


func _draw_small_text(text: String, center: Vector2, color: Color, font_size: int = 14) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := center + Vector2(-width * 0.5, font_size * 0.35)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0.04, 0.05, 0.07, 0.9 * color.a))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_face() -> void:
	var eye_color := Color(0.06, 0.07, 0.09, 0.85)
	var spacing := body_radius * 0.32
	var eye_y := -body_radius * 0.12
	if state == State.FREED:
		for side in [-1.0, 1.0]:
			draw_arc(Vector2(side * spacing, eye_y + 2.0), 3.6, PI * 1.1, PI * 1.9, 8, eye_color, 2.0, true)
		return
	if state == State.WAKING or _scared > 0.0 or _fleeing:
		for side in [-1.0, 1.0]:
			draw_circle(Vector2(side * spacing, eye_y), 3.4, eye_color)
			draw_circle(Vector2(side * spacing + 0.8, eye_y - 0.8), 1.0, Color(1, 1, 1, 0.8))
		return
	var closed := need == Need.SHY or (need == Need.WARMTH and not _warm)
	for side in [-1.0, 1.0]:
		var center := Vector2(side * spacing, eye_y)
		if closed:
			draw_line(center - Vector2(3.5, 0), center + Vector2(3.5, 0), eye_color, 2.0, true)
		else:
			draw_circle(center + Vector2(0, 3.0), 2.6, eye_color)

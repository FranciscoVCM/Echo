class_name EchoBlob
extends PingDummy
## A creature of the world that has to be understood through Ping, not beaten.
##
## Builds on the existing PingDummy (organic body, FOV fade, answering PingEmitter).
## Every blob has a colour, and its colour is a note: it only reacts to a Ping that
## carries that note (a chord counts if one of its tones matches). On top of that it
## can have a temperament (see `need`) or belong to an EchoBlobGroup.
##
## Feedback is never colour-only: a wrong note makes the blob sing its own note back
## (sound + a coloured echo wave) and its note name appears under it from then on.

signal freed(blob: EchoBlob)

enum Need {
	NOTE,  ## Wakes up / is helped as soon as it hears its note `required_hits` times.
	SHY,  ## Its note wakes it; then it needs `shy_silence_duration` s with NO pings at all.
}
enum State { LOST, WAKING, FREED, FOLLOWING, ABSORBED }

@export_category("Echo Blob")
@export var display_name := "Blob"
@export_enum("Dó", "Ré", "Mi", "Fá", "Sol", "Lá", "Si") var note := 0
@export var need: Need = Need.NOTE
@export_range(1, 5, 1) var required_hits := 1
## Invisible even inside the field of view until a Ping has touched it once.
@export var hidden_until_pinged := false

@export_category("Shy")
@export_range(1.0, 20.0, 0.5) var shy_silence_duration := 5.0

@export_category("Voice")
## Seconds between the soft calls an unhelped blob makes (helps locating it by ear).
@export_range(2.0, 30.0, 0.5) var call_interval := 6.5
@export_range(-40.0, 6.0, 1.0) var voice_volume_db := -12.0
@export_range(80.0, 600.0, 10.0) var answer_range := 260.0

## Set by the world when the player enables "always show note names".
static var always_show_note_names := false

var state := State.LOST
var group: EchoBlobGroup
var hits := 0
var has_answered := false
var decided := false
## 0..1 strength of a partial group mark (a ring drawn around the body).
var group_mark := 0.0
## 0..1 remaining time of a group window, or -1 when no window is shown.
var group_window_ratio := -1.0

var _true_color := Color.WHITE
var _base_radius := 24.0
var _shy_remaining := 0.0
var _revealed := false
var _call_timer := 0.0
var _call_ring := 0.0
var _time := 0.0
var _jolt := 0.0
var _hit_flash := 0.0
var _droop := 0.0
var _voice: AudioStreamPlayer2D
var _follow_target: Node2D
var _follow_offset := Vector2.ZERO


func _ready() -> void:
	super._ready()
	add_to_group("echo_blobs")
	_true_color = EchoNotes.color_for(note)
	_base_radius = body_radius
	_ping_emitter.respond_to_ping = false
	_ping_emitter.ping_tone_index = note
	_ping_emitter.ping_color = _true_color
	_ping_emitter.ping_cooldown = 1.2
	_voice = AudioStreamPlayer2D.new()
	_voice.name = "Voice"
	_voice.max_distance = 1100.0
	_voice.attenuation = 1.6
	_voice.volume_db = voice_volume_db
	add_child(_voice)
	_time = randf() * 10.0
	_call_timer = randf_range(1.0, call_interval)
	_apply_look(0.0)


func _process(delta: float) -> void:
	super._process(delta)
	_time += delta
	_jolt = move_toward(_jolt, 0.0, delta * 2.5)
	_hit_flash = move_toward(_hit_flash, 0.0, delta * 1.8)
	_droop = move_toward(_droop, 0.0, delta * 0.8)
	_call_ring = move_toward(_call_ring, 0.0, delta * 0.7)
	match state:
		State.LOST:
			_call_timer -= delta
			if _call_timer <= 0.0:
				_call_timer = call_interval * randf_range(0.8, 1.3)
				_call_ring = 1.0
				_play_voice(-6.0)
		State.WAKING:
			_shy_remaining -= delta
			if _shy_remaining <= 0.0:
				free_blob()
		State.FREED:
			_call_timer -= delta
			if _call_timer <= 0.0:
				_call_timer = randf_range(8.0, 14.0)
				_play_voice(-10.0)
	_apply_look(delta)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if state != State.FOLLOWING or _follow_target == null or not is_instance_valid(_follow_target):
		return
	var target := _follow_target.global_position + _follow_offset
	var offset := target - global_position
	if offset.length() > 700.0:
		# Lost behind a wall: catch up instead of getting stuck.
		global_position = target
		velocity = Vector2.ZERO
		return
	velocity = velocity.lerp(offset * 3.2, 1.0 - exp(-delta * 6.0)).limit_length(340.0)
	move_and_slide()


# --- Ping reception -------------------------------------------------------------------

func receive_ping_wave(wave: PingWave) -> void:
	if state == State.ABSORBED or wave.is_echo():
		return
	_revealed = true
	EchoMarker.spawn(global_position, _true_color, body_radius, get_tree())
	var matched := wave.carries_pitch_class(note)
	match state:
		State.LOST:
			if group != null:
				if matched:
					_hit_flash = 1.0
				else:
					_answer()
				group.on_member_pinged(self, matched, wave.get_instance_id())
			elif not matched:
				_answer()
			elif need == Need.SHY:
				_wake()
			else:
				hits += 1
				_hit_flash = 1.0
				if hits >= required_hits:
					free_blob()
				else:
					_play_voice(-4.0)
		State.WAKING:
			# Any sound at all, right note or not, startles it and restarts its calm.
			_shy_remaining = shy_silence_duration
			_jolt = 1.0
		State.FREED, State.FOLLOWING:
			_hit_flash = 0.5


func _wake() -> void:
	state = State.WAKING
	_shy_remaining = shy_silence_duration
	_hit_flash = 1.0
	_play_voice(-8.0)


## The blob replies with its own note: the player learns what it is listening for.
func _answer() -> void:
	has_answered = true
	_jolt = 0.6
	if _ping_emitter.ping_cooldown_remaining <= 0.0:
		_ping_emitter.ping_tone_index = note
		_ping_emitter.ping_color = _true_color
		_ping_emitter.chord_tone_indices = PackedInt32Array()
		_ping_emitter.emit_ping(true, answer_range, 0.4)
		_play_voice(0.0)


func free_blob() -> void:
	if state == State.FREED or state == State.FOLLOWING or state == State.ABSORBED:
		return
	state = State.FREED
	hits = required_hits
	has_answered = true
	group_mark = 0.0
	group_window_ratio = -1.0
	_hit_flash = 1.0
	_call_timer = randf_range(3.0, 6.0)
	_play_voice(2.0)
	EchoMarker.spawn(global_position, _true_color, body_radius, get_tree(), true)
	freed.emit(self)


## Visual-only "that didn't work out" feedback, used by groups when a window expires.
func droop() -> void:
	_droop = 1.0
	_play_voice(-10.0)


func is_freed() -> bool:
	return state == State.FREED


func is_shy_waking() -> bool:
	return state == State.WAKING


func get_shy_remaining() -> float:
	return _shy_remaining


func get_true_color() -> Color:
	return _true_color


# --- Recruit / absorb (PROTOTYPE, outcomes not decided by the group) -----------------------

func start_following(target: Node2D, offset: Vector2) -> void:
	state = State.FOLLOWING
	decided = true
	_follow_target = target
	_follow_offset = offset
	# Companions must never block the player or other creatures.
	collision_layer = 0
	collision_mask = 2


## Repeat the player's ping from this companion's position (lets sound turn corners).
func relay_ping(root_degree: int, extra_degrees: PackedInt32Array, wave_range: float) -> void:
	if state != State.FOLLOWING:
		return
	_ping_emitter.ping_tone_index = posmod(root_degree, 8)
	_ping_emitter.ping_color = EchoNotes.color_for(root_degree)
	_ping_emitter.chord_tone_indices = extra_degrees
	var colors: Array[Color] = []
	for degree in extra_degrees:
		colors.append(EchoNotes.color_for(degree))
	_ping_emitter.chord_colors = colors
	_ping_emitter.emit_ping(false, wave_range, 0.5)
	_ping_emitter.chord_tone_indices = PackedInt32Array()
	_ping_emitter.chord_colors = []
	_play_voice(-14.0)


func absorb_into(target: Node2D) -> void:
	state = State.ABSORBED
	decided = true
	remove_from_group("ping_blobs")
	collision_layer = 0
	collision_mask = 0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "global_position", target.global_position, 0.45).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", Vector2(0.15, 0.15), 0.45)
	tween.chain().tween_callback(hide)


# --- Field of view ---------------------------------------------------------------------

func set_fov_visible(is_in_view: bool) -> void:
	if state == State.ABSORBED:
		return
	if state == State.FOLLOWING:
		is_in_view = true
	elif hidden_until_pinged and not _revealed:
		is_in_view = false
	super.set_fov_visible(is_in_view)


# --- Look ------------------------------------------------------------------------------

func _apply_look(_delta: float) -> void:
	var gray := Color(_true_color.get_luminance(), _true_color.get_luminance(), _true_color.get_luminance())
	var base := _true_color
	var radius_scale := 1.0
	match state:
		State.LOST:
			base = _true_color.lerp(gray, 0.5).darkened(0.18)
			radius_scale = 0.84 if need == Need.SHY else 0.96 + sin(_time * 1.6) * 0.02
		State.WAKING:
			var calm := 1.0 - clampf(_shy_remaining / shy_silence_duration, 0.0, 1.0)
			base = _true_color.lerp(gray, 0.5 * (1.0 - calm)).darkened(0.18 * (1.0 - calm))
			radius_scale = lerpf(0.88, 1.0, calm) + sin(_time * lerpf(22.0, 4.0, calm)) * 0.02 * (1.0 - calm)
		State.FREED, State.FOLLOWING:
			radius_scale = 1.0 + sin(_time * 3.0) * 0.04
	radius_scale *= 1.0 - _droop * 0.12
	body_radius = _base_radius * radius_scale
	body_color = base.lerp(Color.WHITE, _hit_flash * 0.45)
	outline_color = base.darkened(0.5) if state == State.LOST else _true_color.lightened(0.35)


func _draw() -> void:
	if _call_ring > 0.0:
		var ring_radius := body_radius * (1.3 + (1.0 - _call_ring) * 1.8)
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 48, Color(_true_color, 0.4 * _call_ring), 2.0, true)

	var shake := Vector2(sin(_time * 38.0) * 4.0 * _jolt, 0.0)
	if state == State.WAKING:
		shake.x += sin(_time * 30.0) * 1.2 * clampf(_shy_remaining / shy_silence_duration, 0.0, 1.0)
	var bob := Vector2(0.0, sin(_time * 3.0) * 2.0) if state == State.FREED else Vector2.ZERO
	draw_set_transform(shake + bob + Vector2(0.0, _droop * 4.0))
	super._draw()
	_draw_face()
	draw_set_transform(Vector2.ZERO)

	# Group mark: a ring that shows this blob already heard its note for the group.
	if group_mark > 0.01:
		var mark_color := Color(_true_color.lightened(0.3), group_mark)
		draw_arc(Vector2.ZERO, body_radius + 8.0, 0.0, TAU, 48, Color(mark_color, 0.3 * group_mark), 5.0, true)
		if group_window_ratio >= 0.0:
			draw_arc(Vector2.ZERO, body_radius + 8.0, -PI * 0.5, -PI * 0.5 + TAU * group_window_ratio, 48, mark_color, 3.0, true)
		else:
			draw_arc(Vector2.ZERO, body_radius + 8.0, 0.0, TAU, 48, mark_color, 2.0, true)

	# Shy calm meter: fills while the player stays silent.
	if state == State.WAKING:
		var calm := 1.0 - clampf(_shy_remaining / shy_silence_duration, 0.0, 1.0)
		draw_arc(Vector2.ZERO, body_radius + 10.0, 0.0, TAU, 48, Color(1, 1, 1, 0.15), 3.0, true)
		draw_arc(Vector2.ZERO, body_radius + 10.0, -PI * 0.5, -PI * 0.5 + TAU * calm, 48, Color(_true_color.lightened(0.4), 0.9), 3.0, true)

	if has_answered or always_show_note_names or state != State.LOST:
		var font := ThemeDB.fallback_font
		var text := EchoNotes.name_for(note)
		var font_size := 14
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
		var at := Vector2(-width * 0.5, body_radius + 20.0)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0.04, 0.05, 0.07, 0.9))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _true_color.lightened(0.45))


func _draw_face() -> void:
	var eye_color := Color(0.06, 0.07, 0.09, 0.85)
	var spacing := body_radius * 0.32
	var eye_y := -body_radius * 0.12
	match state:
		State.LOST:
			if need == Need.SHY:
				# Asleep / hiding: closed eyes.
				for side in [-1.0, 1.0]:
					var center := Vector2(side * spacing, eye_y)
					draw_line(center - Vector2(3.5, 0), center + Vector2(3.5, 0), eye_color, 2.0, true)
			else:
				# Looking down, a little lost.
				for side in [-1.0, 1.0]:
					draw_circle(Vector2(side * spacing, eye_y + 3.0), 2.6, eye_color)
		State.WAKING:
			for side in [-1.0, 1.0]:
				draw_circle(Vector2(side * spacing, eye_y), 3.2, eye_color)
				draw_circle(Vector2(side * spacing + 0.8, eye_y - 0.8), 1.0, Color(1, 1, 1, 0.8))
		_:
			# Content: soft upward arcs.
			for side in [-1.0, 1.0]:
				draw_arc(Vector2(side * spacing, eye_y + 2.0), 3.6, PI * 1.1, PI * 1.9, 8, eye_color, 2.0, true)


func _play_voice(volume_offset_db: float) -> void:
	if _voice == null:
		return
	_voice.stream = EchoNotes.voice_stream(note)
	_voice.volume_db = voice_volume_db + volume_offset_db
	_voice.play()

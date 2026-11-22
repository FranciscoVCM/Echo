class_name PingEmitter
extends Node2D
## Charges a sonar pulse while E is held and lets other blobs answer it.

signal ping_emitted(origin: Vector2, is_echo: bool, charge: float, tone_index: int, frequency: float)
signal ping_received(source_position: Vector2, is_echo: bool)
signal ping_received_details(source_position: Vector2, is_echo: bool, charge: float, tone_index: int, frequency: float, wave_id: int)
signal ping_tone_changed(tone_index: int, note_name: String, frequency: float)

const PING_WAVE_SCENE: PackedScene = preload("res://scenes/ping_wave.tscn")
const PING_NOTE_NAMES := ["C3", "D3", "E3", "F3", "G3", "A3", "B3", "C4"]
const PING_NOTE_SEMITONES := [0, 2, 4, 5, 7, 9, 11, 12]
const BASE_NOTE_FREQUENCY := 130.8128
const PREVIEW_DURATION := 0.5
const PREVIEW_SAMPLE_RATE := 22050

@export_category("Ping Charge")
@export var listen_for_input := false
@export var respond_to_ping := false
@export_range(80.0, 1200.0, 10.0) var minimum_ping_range := 150.0
@export_range(100.0, 1600.0, 10.0) var maximum_ping_range := 670.0
@export_range(0.2, 4.0, 0.05) var maximum_charge_time := 1.1
@export_range(0.5, 3.0, 0.05) var wave_duration := 1.5
@export_range(0.0, 10.0, 0.1) var ping_cooldown := 2.0
@export var ping_color := Color.WHITE
@export_category("Cooldown Feedback")
## Multiplier for fill opacity immediately after firing; returns smoothly to full opacity.
@export_range(0.0, 1.0, 0.01) var cooldown_body_opacity := 0.3

@export_category("Ping Tone")
@export_enum("C3", "D3", "E3", "F3", "G3", "A3", "B3", "C4") var ping_tone_index := 0

## Optional extra scale degrees emitted together with the selected tone (a chord).
## Empty by default, so existing scenes keep emitting a single note.
## Degrees count scale steps from C3 and may exceed 7 (see EchoNotes).
var chord_tone_indices := PackedInt32Array()
## Optional colours drawn by the wave for each extra chord tone.
var chord_colors: Array[Color] = []

var ping_charging := false
var ping_charge := 0.0
var ping_squash := 0.0
var ping_cooldown_remaining := 0.0
var cooldown_opacity := 1.0

var _e_was_pressed := false
var _ping_animation_time := -1.0
var _tone_preview_streams: Array[AudioStreamWAV] = []
var _chord_preview_streams: Dictionary = {}
@onready var _tone_preview_player: AudioStreamPlayer = get_node_or_null("TonePreview") as AudioStreamPlayer


var ping_tone_name: String:
	get:
		return PING_NOTE_NAMES[ping_tone_index]

var ping_tone_frequency: float:
	get:
		return frequency_for_tone(ping_tone_index)


static func tone_name_for_index(index: int) -> String:
	return PING_NOTE_NAMES[posmod(index, PING_NOTE_NAMES.size())]


static func frequency_for_tone(index: int) -> float:
	var semitone: int = PING_NOTE_SEMITONES[posmod(index, PING_NOTE_SEMITONES.size())]
	return BASE_NOTE_FREQUENCY * pow(2.0, float(semitone) / 12.0)


## Frequency for any scale degree counted from C3 (7 = C4, 9 = E4 ...).
static func frequency_for_degree(degree: int) -> float:
	var octave := floori(float(degree) / 7.0)
	var semitone: int = PING_NOTE_SEMITONES[posmod(degree, 7)] + 12 * octave
	return BASE_NOTE_FREQUENCY * pow(2.0, float(semitone) / 12.0)


## All degrees carried by the next ping: the selected tone plus any chord tones.
func current_tone_indices() -> PackedInt32Array:
	var tones := PackedInt32Array([ping_tone_index])
	tones.append_array(chord_tone_indices)
	return tones


func _ready() -> void:
	if _tone_preview_player == null:
		return
	for semitone in PING_NOTE_SEMITONES:
		var frequency := BASE_NOTE_FREQUENCY * pow(2.0, float(semitone) / 12.0)
		_tone_preview_streams.append(_create_note_preview(frequency))


func _physics_process(delta: float) -> void:
	_update_ping_animation(delta)
	ping_cooldown_remaining = maxf(ping_cooldown_remaining - delta, 0.0)
	if ping_cooldown > 0.0 and ping_cooldown_remaining > 0.0:
		var progress := 1.0 - ping_cooldown_remaining / ping_cooldown
		var eased_progress := progress * progress * (3.0 - 2.0 * progress)
		cooldown_opacity = lerpf(cooldown_body_opacity, 1.0, eased_progress)
	else:
		cooldown_opacity = 1.0
	var e_pressed := Input.is_physical_key_pressed(KEY_E)
	if not listen_for_input:
		ping_charging = false
		ping_charge = 0.0
		_e_was_pressed = e_pressed
		return

	if e_pressed and not _e_was_pressed and ping_cooldown_remaining <= 0.0:
		ping_charging = true
		ping_charge = 0.0
	elif e_pressed and ping_charging:
		ping_charge = minf(ping_charge + delta / maximum_charge_time, 1.0)
	elif not e_pressed and _e_was_pressed and ping_charging:
		var released_charge := ping_charge
		var released_range := lerpf(minimum_ping_range, maximum_ping_range, released_charge)
		ping_charging = false
		ping_charge = 0.0
		emit_ping(false, released_range, released_charge)

	_e_was_pressed = e_pressed


func _unhandled_input(event: InputEvent) -> void:
	if not listen_for_input:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_change_ping_tone(1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_change_ping_tone(-1)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key_code: int = event.physical_keycode
		if key_code < KEY_1 or key_code > KEY_8:
			key_code = event.keycode
		if key_code >= KEY_1 and key_code <= KEY_8:
			_select_ping_tone(key_code - KEY_1)
			get_viewport().set_input_as_handled()


func _change_ping_tone(step: int) -> void:
	_select_ping_tone(ping_tone_index + step)


func _select_ping_tone(index: int) -> void:
	ping_tone_index = posmod(index, PING_NOTE_NAMES.size())
	ping_tone_changed.emit(ping_tone_index, ping_tone_name, ping_tone_frequency)
	_play_tone_preview()


func _play_tone_preview() -> void:
	play_note_preview(ping_tone_index)


func play_note_preview(tone_index: int = -1) -> void:
	if _tone_preview_player == null:
		return
	if _tone_preview_streams.is_empty():
		return
	var index := ping_tone_index if tone_index < 0 else posmod(tone_index, PING_NOTE_NAMES.size())
	_tone_preview_player.stop()
	if tone_index < 0 and not chord_tone_indices.is_empty():
		_tone_preview_player.stream = _chord_preview(current_tone_indices())
	else:
		_tone_preview_player.stream = _tone_preview_streams[index]
	_tone_preview_player.play()


func _chord_preview(degrees: PackedInt32Array) -> AudioStreamWAV:
	var key := str(degrees)
	if not _chord_preview_streams.has(key):
		var frequencies: Array[float] = []
		for degree in degrees:
			frequencies.append(frequency_for_degree(degree))
		_chord_preview_streams[key] = _create_note_preview(frequencies[0], frequencies.slice(1))
	return _chord_preview_streams[key]


func _create_note_preview(frequency: float, extra_frequencies: Array[float] = []) -> AudioStreamWAV:
	var frame_count := int(PREVIEW_DURATION * PREVIEW_SAMPLE_RATE)
	var pcm_data := PackedByteArray()
	pcm_data.resize(frame_count * 2)
	for frame in range(frame_count):
		var time := float(frame) / PREVIEW_SAMPLE_RATE
		var attack := minf(time / 0.012, 1.0)
		var release_progress := clampf((time - 0.34) / (PREVIEW_DURATION - 0.34), 0.0, 1.0)
		var release := 1.0 - release_progress * release_progress * (3.0 - 2.0 * release_progress)
		var phase := TAU * frequency * time
		var tone := sin(phase) + sin(phase * 2.0) * 0.16 + sin(phase * 3.0) * 0.06
		for extra_frequency in extra_frequencies:
			# Slight strum: each chord tone enters a few milliseconds later.
			var extra_phase := TAU * extra_frequency * time
			tone += (sin(extra_phase) + sin(extra_phase * 2.0) * 0.12) * minf(time / 0.03, 1.0)
		if not extra_frequencies.is_empty():
			tone /= sqrt(1.0 + extra_frequencies.size())
		var sample := roundi(clampf(tone * 0.16 * attack * release, -1.0, 1.0) * 32767.0)
		if sample < 0:
			sample += 65536
		pcm_data[frame * 2] = sample & 0xFF
		pcm_data[frame * 2 + 1] = (sample >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = PREVIEW_SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm_data
	return stream


func emit_ping(is_echo: bool, range_override: float = -1.0, charge: float = 1.0) -> void:
	_play_tone_preview()
	var source := get_parent() as CollisionObject2D
	var wave := PING_WAVE_SCENE.instantiate() as PingWave
	var range_to_use := maximum_ping_range if range_override < 0.0 else range_override
	wave.global_position = global_position
	wave.configure(source, range_to_use, wave_duration, ping_color, is_echo, charge, ping_tone_index, ping_tone_frequency)
	if not chord_tone_indices.is_empty():
		wave.set_tones(current_tone_indices(), [ping_color] + chord_colors)
	# Scenes may provide a dedicated layer (e.g. drawn above the fog); otherwise use the scene root.
	var wave_parent := get_tree().get_first_node_in_group("ping_wave_layer")
	if wave_parent == null:
		wave_parent = get_tree().current_scene
	wave_parent.add_child(wave)
	ping_cooldown_remaining = ping_cooldown
	cooldown_opacity = cooldown_body_opacity
	_ping_animation_time = 0.0
	ping_squash = 0.0
	ping_emitted.emit(global_position, is_echo, charge, ping_tone_index, ping_tone_frequency)


func receive_ping(source_position: Vector2, is_echo: bool) -> void:
	receive_ping_details(source_position, is_echo, 1.0, ping_tone_index, ping_tone_frequency, 0)


func receive_ping_details(
	source_position: Vector2,
	is_echo: bool,
	charge: float,
	tone_index: int,
	frequency: float,
	wave_id: int
) -> void:
	ping_received.emit(source_position, is_echo)
	ping_received_details.emit(source_position, is_echo, charge, tone_index, frequency, wave_id)
	if respond_to_ping and not is_echo and ping_cooldown_remaining <= 0.0:
		emit_ping(true)


func _update_ping_animation(delta: float) -> void:
	if _ping_animation_time < 0.0:
		return
	_ping_animation_time += delta
	if _ping_animation_time < 0.12:
		var compression := _ping_animation_time / 0.12
		ping_squash = compression * compression * (3.0 - 2.0 * compression)
	elif _ping_animation_time < 0.34:
		var expansion := (_ping_animation_time - 0.12) / 0.22
		ping_squash = -0.24 * sin(PI * expansion)
	else:
		ping_squash = 0.0
		_ping_animation_time = -1.0

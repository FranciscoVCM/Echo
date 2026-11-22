class_name SmallBlobInteraction
extends Node
## One configurable prototype behavior attached to the existing PingDummy scene.

signal ping_reached_interaction(interaction: SmallBlobInteraction, source_position: Vector2, charge: float, tone_index: int, frequency: float, wave_id: int)
signal state_changed(interaction_id: String, state: String)

enum Kind { FRIGHTENED, CONNECTION, LOST, FREQUENCY, RESONANCE, SILENCE }

const STATE_IDLE := "IDLE"
const STATE_REACTING := "REACTING"
const STATE_PROGRESSING := "PROGRESSING"
const STATE_COMPLETED := "COMPLETED"

@export_category("Interaction")
@export var interaction_id := "blob"
@export var display_name := "Small Blob"
@export var interaction_kind: Kind = Kind.FRIGHTENED
@export_range(1, 10, 1) var required_successes := 3

@export_category("Frightened Blob")
@export_range(0.0, 1.0, 0.01) var maximum_comfortable_ping_charge := 0.3
@export_range(80.0, 400.0, 10.0) var comfortable_ping_distance := 220.0
@export_range(0.0, 1.0, 0.01) var frightened_scale := 0.68
@export_range(40.0, 240.0, 5.0) var frightened_retreat_distance := 90.0
@export_range(40.0, 200.0, 5.0) var comfortable_approach_distance := 85.0

@export_category("Lost Blob")
@export_range(50.0, 500.0, 10.0) var contact_distance := 175.0
@export_range(0.2, 8.0, 0.1) var ping_reveal_duration := 2.5
@export var safe_destination := Vector2.ZERO

@export_category("Frequency Matching")
@export_range(0, 7, 1) var target_tone_index := 4
@export_range(0.1, 20.0, 0.1) var frequency_tolerance_hz := 2.0
@export_range(0.5, 5.0, 0.1) var voice_repeat_interval := 1.7

@export_category("Group Resonance")
@export_range(1.0, 20.0, 0.5) var activation_duration := 8.0

@export_category("Silence")
@export_range(2.0, 30.0, 0.5) var uninterrupted_silence_required := 8.0

@export_category("Feedback")
@export var relaxed_color := Color(0.62, 0.92, 0.76, 1.0)
@export var completed_color := Color(0.92, 0.88, 0.58, 1.0)
@export_range(0.5, 8.0, 0.1) var movement_speed := 90.0

var state := STATE_IDLE
var success_count := 0
var is_revealed := false
var resonance_time_remaining := 0.0
var _external_progress_total := 3

var _body: PingDummy
var _emitter: PingEmitter
var _debug_label: Label
var _resting_radius := 24.0
var _resting_color := Color.WHITE
var _initial_position := Vector2.ZERO
var _movement_target := Vector2.ZERO
var _movement_mode := 0
var _fear_time_remaining := 0.0
var _reveal_time_remaining := 0.0
var _silence_time_remaining := 0.0
var _voice_time_remaining := 0.0
var _ping_count_after_reveal := 0
var _completed := false
var _synchronized := false
var _time := 0.0
var _pulse_phase := 0.0


func _ready() -> void:
	_body = get_parent() as PingDummy
	if _body == null:
		push_error("SmallBlobInteraction must be a child of PingDummy.")
		return
	_emitter = _body.get_node("PingEmitter") as PingEmitter
	_resting_radius = _body.body_radius
	_resting_color = _body.body_color
	_initial_position = _body.global_position
	_pulse_phase = float(posmod(interaction_id.hash(), 1000)) / 1000.0 * TAU
	_emitter.ping_received_details.connect(_on_ping_received)
	_add_debug_label()
	if interaction_kind == Kind.LOST:
		_body.visible = false
	_update_debug_label()


func _process(delta: float) -> void:
	if _body == null:
		return
	_time += delta
	if _fear_time_remaining > 0.0:
		_fear_time_remaining = maxf(_fear_time_remaining - delta, 0.0)
	if interaction_kind == Kind.LOST and _reveal_time_remaining > 0.0:
		_reveal_time_remaining = maxf(_reveal_time_remaining - delta, 0.0)
	if interaction_kind == Kind.SILENCE and not _completed:
		if _silence_time_remaining > 0.0:
			_silence_time_remaining = maxf(_silence_time_remaining - delta, 0.0)
			if _silence_time_remaining <= 0.0:
				_complete()
	if interaction_kind == Kind.RESONANCE and resonance_time_remaining > 0.0 and not _completed:
		resonance_time_remaining = maxf(resonance_time_remaining - delta, 0.0)
		if resonance_time_remaining <= 0.0:
			_set_state(STATE_IDLE)
	if interaction_kind == Kind.FREQUENCY and _completed:
		_voice_time_remaining -= delta
		if _voice_time_remaining <= 0.0:
			_emitter.play_note_preview(target_tone_index)
			_voice_time_remaining = voice_repeat_interval
	elif interaction_kind == Kind.RESONANCE and _synchronized:
		_voice_time_remaining -= delta
		if _voice_time_remaining <= 0.0:
			_emitter.play_note_preview(target_tone_index)
			_voice_time_remaining = 1.35
	_update_visuals()
	_update_debug_label()
	_body.queue_redraw()


func _physics_process(_delta: float) -> void:
	_update_motion()


func reset_interaction() -> void:
	if _body == null:
		return
	_completed = false
	_synchronized = false
	success_count = 0
	is_revealed = interaction_kind != Kind.LOST
	resonance_time_remaining = 0.0
	_fear_time_remaining = 0.0
	_reveal_time_remaining = 0.0
	_voice_time_remaining = 0.0
	_ping_count_after_reveal = 0
	_movement_mode = 0
	_body.velocity = Vector2.ZERO
	_body.global_position = _initial_position
	_body.body_color = _resting_color
	_body.body_radius = _resting_radius
	_emitter.ping_cooldown_remaining = 0.0
	_emitter.cooldown_opacity = 1.0
	var preview_player := _emitter.get_node_or_null("TonePreview") as AudioStreamPlayer
	if preview_player != null:
		preview_player.stop()
	if interaction_kind == Kind.SILENCE:
		_silence_time_remaining = 0.0
		_set_state(STATE_REACTING)
	else:
		_silence_time_remaining = 0.0
		_set_state(STATE_IDLE)
	if interaction_kind == Kind.LOST:
		_body.visible = false
	else:
		_body.visible = true
	_body.modulate.a = 1.0
	_update_visuals()
	_update_debug_label()
	_body.queue_redraw()


func fov_visibility_override() -> int:
	if interaction_kind != Kind.LOST:
		return -1
	if not is_revealed:
		return 0
	if _reveal_time_remaining > 0.0:
		return 1
	return -1


func is_resonating() -> bool:
	return interaction_kind == Kind.RESONANCE and resonance_time_remaining > 0.0


func set_external_progress(progress: int, total: int, completed: bool) -> void:
	success_count = progress
	_external_progress_total = total
	if completed:
		_complete()
	elif progress > 0:
		_set_state(STATE_PROGRESSING)
	_update_debug_label()


func set_synchronized_success() -> void:
	_synchronized = true
	_complete()


func _on_ping_received(
	source_position: Vector2,
	is_echo: bool,
	charge: float,
	tone_index: int,
	frequency: float,
	wave_id: int
) -> void:
	if _completed or (is_echo and interaction_kind != Kind.SILENCE):
		return
	if not is_echo:
		ping_reached_interaction.emit(self, source_position, charge, tone_index, frequency, wave_id)
	match interaction_kind:
		Kind.FRIGHTENED:
			_handle_frightened_ping(source_position, charge)
		Kind.CONNECTION:
			_set_state(STATE_REACTING)
		Kind.LOST:
			_handle_lost_ping(source_position)
		Kind.FREQUENCY:
			_handle_frequency_ping(frequency)
		Kind.RESONANCE:
			resonance_time_remaining = activation_duration
			_set_state(STATE_PROGRESSING)
		Kind.SILENCE:
			_silence_time_remaining = uninterrupted_silence_required
			_set_state(STATE_REACTING)
	_update_visuals()
	_update_debug_label()
	_body.queue_redraw()


func _handle_frightened_ping(source_position: Vector2, charge: float) -> void:
	var source_distance := _body.global_position.distance_to(source_position)
	if charge <= maximum_comfortable_ping_charge and source_distance <= comfortable_ping_distance:
		success_count += 1
		_fear_time_remaining = 0.0
		_set_state(STATE_PROGRESSING)
		if success_count >= required_successes:
			var toward_player := (source_position - _body.global_position).normalized()
			_movement_target = source_position - toward_player * comfortable_approach_distance
			_movement_mode = 1
			_complete()
	else:
		success_count = 0
		_fear_time_remaining = 0.8
		var away_from_player := (_body.global_position - source_position).normalized()
		_movement_target = _body.global_position + away_from_player * frightened_retreat_distance
		_movement_mode = -1
		_set_state(STATE_REACTING)


func _handle_lost_ping(source_position: Vector2) -> void:
	if not is_revealed:
		is_revealed = true
		_ping_count_after_reveal = 1
	else:
		_ping_count_after_reveal += 1
	_reveal_time_remaining = ping_reveal_duration
	_body.set_fov_visible(true)
	if _ping_count_after_reveal >= 2 and _body.global_position.distance_to(source_position) <= contact_distance:
		var destination := safe_destination if safe_destination != Vector2.ZERO else _initial_position + Vector2(0.0, 130.0)
		_movement_target = destination
		_movement_mode = 2
		_complete()
	else:
		_set_state(STATE_PROGRESSING)


func _handle_frequency_ping(frequency: float) -> void:
	var target_frequency: float = PingEmitter.frequency_for_tone(target_tone_index)
	if absf(frequency - target_frequency) <= frequency_tolerance_hz:
		success_count += 1
		_set_state(STATE_PROGRESSING)
		if success_count >= required_successes:
			_voice_time_remaining = 0.0
			_complete()
	else:
		_set_state(STATE_REACTING)


func _update_motion() -> void:
	if _movement_mode == 0 or _body == null:
		return
	var offset := _movement_target - _body.global_position
	if offset.length() <= 6.0:
		_body.velocity = Vector2.ZERO
		_movement_mode = 0
		return
	_body.velocity = offset.normalized() * movement_speed
	_body.move_and_slide()


func _update_visuals() -> void:
	if _body == null:
		return
	var pulse := sin(_time * 5.0) * 0.05
	var radius_scale := 1.0
	var tint := _resting_color
	if interaction_kind == Kind.FRIGHTENED and _fear_time_remaining > 0.0:
		radius_scale = lerpf(1.0, frightened_scale, clampf(_fear_time_remaining / 0.8, 0.0, 1.0))
		tint = _resting_color.lerp(Color(0.68, 0.32, 0.34, 1.0), 0.55)
	elif _completed:
		tint = _resting_color.lerp(relaxed_color if interaction_kind == Kind.FRIGHTENED else completed_color, 0.72)
		if _synchronized:
			radius_scale = 1.0 + sin(Time.get_ticks_msec() * 0.001 * 5.0) * 0.055
		else:
			radius_scale = 1.0 + pulse
	elif interaction_kind == Kind.RESONANCE and resonance_time_remaining > 0.0:
		radius_scale = 1.0 + sin(Time.get_ticks_msec() * 0.001 * 5.0) * 0.075
		tint = _resting_color.lerp(completed_color, 0.55)
	elif interaction_kind == Kind.CONNECTION:
		var signal_pulse := (sin(_time * 2.4 + _pulse_phase) + 1.0) * 0.5
		radius_scale = 1.0 + signal_pulse * 0.035
		tint = _resting_color.lerp(Color(0.92, 0.88, 0.70, 1.0), signal_pulse * 0.18)
	elif interaction_kind == Kind.RESONANCE:
		radius_scale = 1.0 + sin(_time * 3.0 + _pulse_phase) * 0.025
	elif interaction_kind == Kind.SILENCE:
		if _completed:
			_body.global_position = _initial_position
			tint = _resting_color.lerp(relaxed_color, 0.7)
		else:
			var agitation := 1.0 if _silence_time_remaining <= 0.0 else clampf(_silence_time_remaining / uninterrupted_silence_required, 0.0, 1.0)
			var shake := sin(_time * lerpf(5.0, 18.0, agitation)) * agitation * 1.5
			_body.global_position.x = _initial_position.x + shake
			radius_scale = 1.0 + sin(_time * 12.0) * agitation * 0.025
			tint = _resting_color.lerp(Color(0.88, 0.42, 0.36, 1.0), agitation * 0.45)
	_body.body_radius = _resting_radius * radius_scale
	_body.body_color = tint
	_emitter.ping_color = tint


func _complete() -> void:
	_completed = true
	_movement_mode = _movement_mode if interaction_kind in [Kind.FRIGHTENED, Kind.LOST] else 0
	_set_state(STATE_COMPLETED)
	_update_visuals()


func _set_state(new_state: String) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(interaction_id, state)
	_update_debug_label()


func _add_debug_label() -> void:
	_debug_label = Label.new()
	_debug_label.position = Vector2(-118.0, -78.0)
	_debug_label.size = Vector2(236.0, 64.0)
	_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_debug_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label_settings := LabelSettings.new()
	label_settings.font_size = 14
	label_settings.font_color = Color(0.96, 0.97, 0.98, 1.0)
	label_settings.outline_size = 4
	label_settings.outline_color = Color(0.06, 0.08, 0.1, 0.92)
	_debug_label.label_settings = label_settings
	_body.call_deferred("add_child", _debug_label)


func _update_debug_label() -> void:
	if _debug_label == null:
		return
	var details := state
	match interaction_kind:
		Kind.FRIGHTENED, Kind.FREQUENCY:
			details += "  %d/%d" % [success_count, required_successes]
		Kind.CONNECTION:
			details += "  %d/%d" % [success_count, _external_progress_total]
		Kind.LOST:
			details = "CONTACT" if _completed else ("ECHO FOUND" if is_revealed else "HIDDEN")
		Kind.RESONANCE:
			details += "  %.1fs" % resonance_time_remaining if resonance_time_remaining > 0.0 else ""
		Kind.SILENCE:
			if _completed:
				details = "CALM"
			elif _silence_time_remaining > 0.0:
				details = "SILENCE %.1fs" % _silence_time_remaining
			else:
				details = "OVERWHELMED — PING TO START"
	var extra := ""
	if interaction_kind == Kind.FREQUENCY:
		extra = "\nNOTE " + PingEmitter.tone_name_for_index(target_tone_index)
	elif interaction_kind == Kind.LOST and is_revealed and not _completed:
		extra = "\nPING AGAIN NEARBY"
	_debug_label.text = "%s\n%s%s" % [display_name, details, extra]

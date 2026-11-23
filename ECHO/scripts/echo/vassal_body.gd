class_name VassalBody
extends CharacterBody2D
## Large creature (C, M, Y vassals and K). Reusable "listening modes" that the specific
## vassal scripts chain together into their themed challenge:
##   MELODY  - answer its song, note by note (pips show progress; a slip restarts gently)
##   SILENCE - stay silent for `silence_duration`; any ping restarts (ring + seconds shown)
##   NOTE    - wants a ping carrying `wanted_note`
##   SOFT    - wants a soft, close ping (low charge)

signal mode_completed(mode: int)
signal pinged(wave: PingWave)

enum Mode { IDLE, MELODY, SILENCE, NOTE, SOFT, APPROACH }

@export var letter := "K"
@export var base_color := Color(0.15, 0.15, 0.17)
@export var radius := 58.0
@export var grey_until_freed := true

var mode: Mode = Mode.IDLE
var awake := true
var completed := false
## 0..1, how "lit" the body is (drawn colour strength).
var glow := 0.2
var melody := PackedInt32Array()
var melody_step := 0
var silence_duration := 6.0
var silence_remaining := 0.0
var wanted_note := 0
var soft_max_charge := 0.4
var soft_distance := 170.0
var resonance_hint := false
var hum_interval := 6.0
var always_visible := false
## APPROACH: spikes grow if you move fast nearby (and push you back); come close calmly.
var approach_tension := 0.0
var approach_warmth := 0.0
const APPROACH_RADIUS := 420.0
const APPROACH_CALM_SPEED := 140.0
const APPROACH_CLOSE := 130.0
const APPROACH_TIME := 5.0

var _time := 0.0
var _jolt := 0.0
var _flash := 0.0
var _droop := 0.0
var _hum_timer := 2.0
var _sing_queue: Array[int] = []
var _sing_timer := 0.0
var _voice: AudioStreamPlayer2D
var _shape: CollisionShape2D
var _fade_tween: Tween
var _target_visible := true
var extra_draw: Callable


func _ready() -> void:
	add_to_group("ping_blobs")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 1
	collision_mask = 0  # enabled only while moving (see slide()), for performance
	_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius * 0.8
	_shape.shape = circle
	add_child(_shape)
	_voice = AudioStreamPlayer2D.new()
	_voice.max_distance = 1500.0
	_voice.attenuation = 1.3
	_voice.volume_db = -11.0
	add_child(_voice)


func receive_ping(_source: Vector2, _is_echo: bool) -> void:
	pass


func receive_ping_wave(wave: PingWave) -> void:
	if wave.is_echo() or completed:
		return
	EchoMarker.spawn(global_position, _current_color(), radius, get_tree())
	pinged.emit(wave)
	if not awake:
		_jolt = 0.3
		return
	match mode:
		Mode.MELODY:
			if wave.carries_pitch_class(melody[melody_step]):
				_flash = 1.0
				sing(melody[melody_step], 0.0)
				melody_step += 1
				if melody_step >= melody.size():
					_finish_mode()
			else:
				# Keep the progress; it hums the note it is waiting for.
				_jolt = 0.5
				sing(melody[melody_step], 0.0)
				_hum_timer = hum_interval
		Mode.SILENCE:
			silence_remaining = silence_duration
			_jolt = 1.0
			var game := get_node_or_null("/root/Game")
			if game != null:
				game.add_stat("startles")
		Mode.NOTE:
			if wave.carries_pitch_class(wanted_note):
				_flash = 1.0
				_finish_mode()
			else:
				_jolt = 0.6
				sing(wanted_note, 0.0)
		Mode.SOFT:
			var distance := wave.global_position.distance_to(global_position)
			if wave.get_charge() <= soft_max_charge and distance <= soft_distance:
				_flash = 1.0
				_finish_mode()
			else:
				_jolt = 1.0


func slide() -> void:
	collision_mask = 2 | 8
	move_and_slide()
	collision_mask = 0


func start_melody(notes: PackedInt32Array) -> void:
	mode = Mode.MELODY
	melody = notes
	melody_step = 0
	_hum_timer = 1.0


func start_silence(duration: float) -> void:
	mode = Mode.SILENCE
	silence_duration = duration
	silence_remaining = duration


func start_note(pitch_class: int) -> void:
	mode = Mode.NOTE
	wanted_note = pitch_class


func start_soft() -> void:
	mode = Mode.SOFT


func start_approach() -> void:
	mode = Mode.APPROACH
	approach_tension = 0.0
	approach_warmth = 0.0


func _process_approach(delta: float) -> void:
	var player := EchoBlob.player as CharacterBody2D
	if player == null:
		return
	var distance := player.global_position.distance_to(global_position)
	var speed := player.velocity.length()
	if distance < APPROACH_RADIUS and speed > APPROACH_CALM_SPEED:
		approach_tension = minf(approach_tension + delta * 1.4, 1.0)
	else:
		approach_tension = maxf(approach_tension - delta * 0.45, 0.0)
	if approach_tension >= 1.0:
		# Too much, too fast: the spikes push you away and the warmth fades.
		approach_tension = 0.0
		approach_warmth *= 0.3
		_jolt = 1.0
		var away := (player.global_position - global_position).normalized()
		player.velocity = away * 600.0
		return
	if distance < APPROACH_CLOSE and approach_tension < 0.5:
		approach_warmth = minf(approach_warmth + delta / APPROACH_TIME, 1.0)
		if approach_warmth >= 1.0:
			_finish_mode()
	elif distance >= APPROACH_CLOSE:
		approach_warmth = maxf(approach_warmth - delta / (APPROACH_TIME * 2.5), 0.0)


func _finish_mode() -> void:
	var finished := mode
	mode = Mode.IDLE
	mode_completed.emit(finished)


func sing(degree: int, volume_offset: float = 0.0) -> void:
	_voice.stream = EchoNotes.voice_stream(degree)
	_voice.volume_db = -11.0 + volume_offset
	_voice.pitch_scale = 0.5
	_voice.play()
	_jolt = maxf(_jolt, 0.25)


func hum_melody() -> void:
	_sing_queue.clear()
	for degree in melody:
		_sing_queue.append(degree)
	_sing_timer = 0.0


func glide_to(target: Vector2, duration: float = 1.5) -> Tween:
	var tween := create_tween()
	tween.tween_property(self, "global_position", target, duration).set_trans(Tween.TRANS_SINE)
	return tween


func set_fov_visible(is_in_view: bool) -> void:
	if always_visible:
		is_in_view = true
	if _target_visible == is_in_view:
		return
	_target_visible = is_in_view
	if _fade_tween != null and _fade_tween.is_running():
		_fade_tween.kill()
	if is_in_view:
		visible = true
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0 if is_in_view else 0.0, 0.3)
	if not is_in_view:
		_fade_tween.tween_callback(hide)


func _process(delta: float) -> void:
	_time += delta
	_jolt = move_toward(_jolt, 0.0, delta * 2.0)
	_flash = move_toward(_flash, 0.0, delta * 1.5)
	_droop = move_toward(_droop, 0.0, delta * 0.8)
	if mode == Mode.MELODY and awake:
		_hum_timer -= delta
		if _hum_timer <= 0.0:
			_hum_timer = hum_interval
			hum_melody()
	if mode == Mode.APPROACH and awake:
		_process_approach(delta)
	if mode == Mode.SILENCE:
		silence_remaining -= delta
		if silence_remaining <= 0.0:
			_finish_mode()
	if not _sing_queue.is_empty():
		_sing_timer -= delta
		if _sing_timer <= 0.0:
			sing(_sing_queue.pop_front(), 0.0)
			_sing_timer = 0.6
	if visible:
		queue_redraw()


func _current_color() -> Color:
	var grey := Color(0.45, 0.46, 0.5)
	if grey_until_freed and not completed:
		return grey.lerp(base_color, glow * 0.6)
	return base_color


func _resonating() -> bool:
	if not resonance_hint or mode != Mode.MELODY or EchoBlob.player == null:
		return false
	var emitter := EchoBlob.player.get_node_or_null("PingEmitter") as PingEmitter
	return emitter != null and EchoNotes.pitch_class(emitter.ping_tone_index) == EchoNotes.pitch_class(melody[melody_step])


func _draw() -> void:
	var color := _current_color().lerp(Color.WHITE, _flash * 0.35)
	var lit := glow if not completed else 1.0
	if lit > 0.05:
		draw_circle(Vector2.ZERO, radius * (1.6 + 0.1 * sin(_time * 2.0)), Color(base_color, 0.08 * lit))
	var shake := Vector2(sin(_time * 30.0) * 5.0 * _jolt, _droop * 5.0)
	if _resonating():
		shake += Vector2(sin(_time * 50.0), cos(_time * 43.0)) * 2.0
	var points := PackedVector2Array()
	var breathing := 1.0 + sin(_time * (1.2 if awake else 0.5)) * 0.03
	for index in range(48):
		var angle := TAU * index / 48.0
		var wobble := 1.0 + sin(angle * 3.0 + _time * 0.8) * 0.04 + sin(angle * 5.0 - _time * 0.6) * 0.025
		points.append(shake + Vector2(cos(angle), sin(angle)) * radius * wobble * breathing * (1.0 - _droop * 0.08))
	draw_colored_polygon(points, color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, color.lightened(0.35) if completed else color.darkened(0.45), 3.0, true)
	if extra_draw.is_valid():
		extra_draw.call(self)
	_draw_face(shake)
	var font := ThemeDB.fallback_font
	var letter_color := Color(1, 1, 1, 0.22 + 0.5 * lit)
	var width := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	draw_string(font, shake + Vector2(-width * 0.5, radius * 0.62), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, letter_color)
	match mode:
		Mode.APPROACH:
			var length := 10.0 + 28.0 * approach_tension
			for index in range(20):
				var angle := TAU * index / 20.0 + sin(_time * 0.7) * 0.05
				var base := Vector2.RIGHT.rotated(angle) * radius * 0.92
				var tip := Vector2.RIGHT.rotated(angle) * (radius + length)
				var side := Vector2.RIGHT.rotated(angle + PI * 0.5) * 6.0
				draw_colored_polygon(PackedVector2Array([base + side, tip, base - side]), Color(0.9, 0.9, 1.0, 0.85))
			if approach_warmth > 0.0:
				draw_arc(Vector2.ZERO, radius + 18.0, -PI * 0.5, -PI * 0.5 + TAU * approach_warmth, 64, Color(0.7, 0.95, 0.8, 0.9), 4.0, true)
			if approach_tension > 0.05:
				draw_arc(Vector2.ZERO, radius + 26.0, -PI * 0.5, -PI * 0.5 + TAU * approach_tension, 64, Color(1.0, 0.3, 0.3, 0.75), 3.0, true)
		Mode.NOTE:
			# Waiting to be called by a colour: a pulsing ring in that colour.
			var pulse := 0.5 + 0.5 * sin(_time * 3.0)
			draw_arc(Vector2.ZERO, radius + 14.0 + pulse * 6.0, 0.0, TAU, 64, Color(EchoNotes.color_for(wanted_note), 0.5 + 0.4 * pulse), 4.0, true)
		Mode.MELODY:
			var spacing := 16.0
			var start := -spacing * (melody.size() - 1) * 0.5
			for index in range(melody.size()):
				var at := Vector2(start + spacing * index, -radius - 16.0)
				if index < melody_step:
					draw_circle(at, 5.0, Color(1, 1, 1, 0.9))
				else:
					draw_arc(at, 5.0, 0.0, TAU, 16, Color(1, 1, 1, 0.6), 1.5, true)
		Mode.SILENCE:
			var ratio := 1.0 - clampf(silence_remaining / silence_duration, 0.0, 1.0)
			draw_arc(Vector2.ZERO, radius + 12.0, 0.0, TAU, 64, Color(1, 1, 1, 0.12), 4.0, true)
			draw_arc(Vector2.ZERO, radius + 12.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 64, Color(1, 1, 1, 0.85), 4.0, true)
			var text := "%.0f s" % ceilf(silence_remaining)
			var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string_outline(font, Vector2(-text_width * 0.5, -radius - 22.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.8))
			draw_string(font, Vector2(-text_width * 0.5, -radius - 22.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.9))
	if not awake:
		var z_alpha := 0.4 + 0.3 * sin(_time * 1.5)
		draw_string(font, Vector2(radius * 0.6, -radius * 0.8 - fposmod(_time * 8.0, 16.0)), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, z_alpha))


func _draw_face(offset: Vector2) -> void:
	var eye_color := Color(0.05, 0.05, 0.07, 0.9) if letter != "K" else Color(0.95, 0.95, 1.0, 0.9)
	var spacing := radius * 0.3
	var eye_y := -radius * 0.15
	for side in [-1.0, 1.0]:
		var center: Vector2 = offset + Vector2(side * spacing, eye_y)
		if not awake:
			draw_line(center - Vector2(6, 0), center + Vector2(6, 0), eye_color, 3.0, true)
		elif completed:
			draw_arc(center + Vector2(0, 3), 6.0, PI * 1.1, PI * 1.9, 10, eye_color, 3.0, true)
		else:
			draw_circle(center, 5.5, eye_color)

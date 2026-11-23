class_name EchoStone
extends StaticBody2D
## A standing stone that rings with its note whenever a Ping touches it (any note).
## Used by C as a listening reference. Blocks movement, not Ping.

var note := 0
var colored := false
var _ring := 0.0
var _time := 0.0
var _voice: AudioStreamPlayer2D


func _ready() -> void:
	add_to_group("ping_blobs")
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 24.0
	shape.shape = circle
	add_child(shape)
	_voice = AudioStreamPlayer2D.new()
	_voice.max_distance = 1200.0
	add_child(_voice)


func receive_ping(_source: Vector2, _is_echo: bool) -> void:
	pass


func receive_ping_wave(wave: PingWave) -> void:
	if wave.is_echo():
		return
	_ring = 1.0
	_voice.stream = EchoNotes.voice_stream(note)
	_voice.pitch_scale = 0.5
	_voice.volume_db = -9.0
	_voice.play()


func set_fov_visible(is_in_view: bool) -> void:
	visible = is_in_view or _ring > 0.0


func _process(delta: float) -> void:
	_time += delta
	_ring = move_toward(_ring, 0.0, delta * 0.8)
	queue_redraw()


func _draw() -> void:
	var color := EchoNotes.color_for(note) if colored else Color(0.5, 0.52, 0.56)
	var rect := Rect2(Vector2(-18, -34), Vector2(36, 62))
	draw_rect(Rect2(rect.position + Vector2(0, 4), rect.size), Color(0, 0, 0, 0.25))
	draw_rect(rect, color.darkened(0.35))
	draw_rect(rect, color.lightened(0.1), false, 2.0)
	if _ring > 0.0:
		for index in range(3):
			var r := 30.0 + (1.0 - _ring) * 60.0 + index * 12.0
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(color.lightened(0.4), _ring * (0.6 - index * 0.15)), 2.0, true)

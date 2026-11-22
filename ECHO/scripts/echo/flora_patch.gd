@tool
class_name FloraPatch
extends Node2D
## Decorative organic growth. Starts grey and regains its colour as the world is restored
## (the world sets `restoration` from 0 to 1 as blobs are helped).

@export var flora_color := Color(0.4, 0.75, 0.55, 1.0):
	set(value):
		flora_color = value
		queue_redraw()
@export_range(1, 24, 1) var count := 7:
	set(value):
		count = value
		queue_redraw()
@export_range(10.0, 300.0, 1.0) var spread := 60.0:
	set(value):
		spread = value
		queue_redraw()
@export_range(3.0, 40.0, 0.5) var bulb_size := 9.0:
	set(value):
		bulb_size = value
		queue_redraw()
@export var seed_value := 1:
	set(value):
		seed_value = value
		queue_redraw()
## Marks a special place (e.g. where one Ping can reach several blobs): a soft ring.
@export var draw_ring := false:
	set(value):
		draw_ring = value
		queue_redraw()
@export_range(0.0, 1.0, 0.01) var restoration := 0.0:
	set(value):
		restoration = value
		queue_redraw()

var _time := 0.0


func _ready() -> void:
	add_to_group("restorable")
	z_index = -1


func _process(delta: float) -> void:
	if draw_ring:
		_time += delta
		queue_redraw()


func _draw() -> void:
	var gray_value := flora_color.get_luminance() * 0.55 + 0.12
	var gray := Color(gray_value, gray_value, gray_value * 1.05, 1.0)
	var tint := gray.lerp(flora_color, restoration)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	if draw_ring:
		var pulse := 0.5 + sin(_time * 1.6) * 0.5
		draw_circle(Vector2.ZERO, spread, Color(tint, 0.06 + 0.05 * pulse))
		draw_arc(Vector2.ZERO, spread, 0.0, TAU, 64, Color(tint.lightened(0.2), 0.25 + 0.2 * pulse), 2.0, true)
	for index in range(count):
		var angle := rng.randf() * TAU
		var distance := sqrt(rng.randf()) * spread
		var position := Vector2.RIGHT.rotated(angle) * distance
		var size := bulb_size * rng.randf_range(0.6, 1.3)
		draw_circle(position + Vector2(0.0, size * 0.35), size, Color(0.0, 0.0, 0.0, 0.12))
		draw_circle(position, size, tint.darkened(rng.randf_range(0.0, 0.25)))
		draw_circle(position + Vector2(-size * 0.3, -size * 0.3), size * 0.35, Color(tint.lightened(0.35), 0.6))

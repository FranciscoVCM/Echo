class_name GuideMarker
extends Node2D
## A soft light on the ground showing exactly where to stand during the tutorial.
## K is only a voice until the end, so this is how "come here" is shown.

const REACH := 75.0

var _time := 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = -1  # above the CMYK pass so it keeps its colour, below the creatures
	visible = false


func show_at(point: Vector2) -> void:
	global_position = point
	visible = true


func is_reached(point: Vector2) -> bool:
	return visible and point.distance_to(global_position) <= REACH


func _process(delta: float) -> void:
	_time += delta
	if visible:
		queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 2.5)
	draw_circle(Vector2.ZERO, REACH * 0.9, Color(1.0, 0.95, 0.75, 0.08 + 0.06 * pulse))
	draw_arc(Vector2.ZERO, REACH * (0.55 + 0.1 * pulse), 0.0, TAU, 48, Color(1.0, 0.95, 0.8, 0.55), 2.5, true)
	for index in range(3):
		var phase := fposmod(_time * 0.6 + index / 3.0, 1.0)
		draw_arc(Vector2.ZERO, REACH * (0.3 + phase * 0.9), 0.0, TAU, 40, Color(1.0, 0.95, 0.8, 0.35 * (1.0 - phase)), 1.5, true)
	for index in range(6):
		var angle := TAU * index / 6.0 + _time * 0.5
		var lift := fposmod(_time * 18.0 + index * 13.0, 40.0)
		draw_circle(Vector2.RIGHT.rotated(angle) * REACH * 0.45 + Vector2(0, -lift), 2.5, Color(1, 1, 0.85, 0.6 * (1.0 - lift / 40.0)))

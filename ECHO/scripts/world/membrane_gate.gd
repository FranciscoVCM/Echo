class_name MembraneGate
extends StaticBody2D
## A soft living membrane that blocks a passage (movement and Ping) until it is opened.

@export var size := Vector2(240, 40)
@export var color := Color(0.6, 0.55, 0.75)

var _time := 0.0
var _opening := 0.0
var _open := false


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	z_index = -3
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	add_child(shape)


func open() -> void:
	if _open:
		return
	_open = true
	collision_layer = 0
	var tween := create_tween()
	tween.tween_property(self, "_opening", 1.0, 1.6).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(queue_free)


func is_open() -> bool:
	return _open


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var half := size * 0.5
	var horizontal := size.x >= size.y
	var points := PackedVector2Array()
	var steps := 24
	var alpha := 1.0 - _opening
	for index in range(steps + 1):
		var t := float(index) / steps
		var wave := sin(t * TAU * 2.0 + _time * 2.0) * 5.0 * (1.0 - _opening)
		points.append(Vector2(lerpf(-half.x, half.x, t), wave) if horizontal else Vector2(wave, lerpf(-half.y, half.y, t)))
	draw_polyline(points, Color(color, 0.25 * alpha), size.y if horizontal else size.x, true)
	draw_polyline(points, Color(color.lightened(0.4), 0.8 * alpha), 3.0, true)
	for index in range(5):
		var t := fposmod(_time * 0.15 + index * 0.2, 1.0)
		var at := Vector2(lerpf(-half.x, half.x, t), sin(t * 9.0 + _time) * 8.0) if horizontal else Vector2(sin(t * 9.0 + _time) * 8.0, lerpf(-half.y, half.y, t))
		draw_circle(at, 4.0 * alpha, Color(1, 1, 1, 0.5 * alpha))

@tool
class_name WallBlock
extends StaticBody2D
## Rectangular wall / rock that blocks movement, vision and Ping waves.
## Resize it with `size` in the inspector; collision and drawing follow automatically.

@export var size := Vector2(120.0, 40.0):
	set(value):
		size = value
		_rebuild()
@export var color := Color(0.11, 0.14, 0.16, 1.0):
	set(value):
		color = value
		queue_redraw()
@export_range(0.0, 30.0, 1.0) var corner_radius := 10.0:
	set(value):
		corner_radius = value
		queue_redraw()

var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	if not Engine.is_editor_hint():
		add_to_group("vision_occluders")
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		# Created at runtime (no owner), so it is never saved into the scene file.
		_shape = CollisionShape2D.new()
		_shape.name = "GeneratedShape"
		add_child(_shape)
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	_shape.shape = rectangle
	queue_redraw()


func _draw() -> void:
	var half := size * 0.5
	var radius := minf(corner_radius, minf(half.x, half.y))
	var points := PackedVector2Array()
	var corners := [
		[Vector2(half.x - radius, -half.y + radius), -PI * 0.5],
		[Vector2(half.x - radius, half.y - radius), 0.0],
		[Vector2(-half.x + radius, half.y - radius), PI * 0.5],
		[Vector2(-half.x + radius, -half.y + radius), PI],
	]
	for corner in corners:
		var center: Vector2 = corner[0]
		var start_angle: float = corner[1]
		for step in range(5):
			points.append(center + Vector2.RIGHT.rotated(start_angle + PI * 0.5 * step / 4.0) * radius)
	draw_colored_polygon(points, color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, color.lightened(0.12), 2.0, true)

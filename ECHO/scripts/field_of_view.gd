extends CanvasLayer
## Builds the player's wall-blocked visibility polygon and renders its fog mask.

const MAX_POLYGON_POINTS := 256
const VisibilityPolygonLibrary = preload("res://addons/visibility_polygon/visibility_polygon.gd")

@export_category("Field of View")
@export var target_path: NodePath
@export var occluder_group := "vision_occluders"
@export_range(80.0, 600.0, 10.0) var vision_radius := 250.0
@export_range(0.0, 1.0, 0.01) var fog_opacity := 0.48
@export var fog_color := Color(0.14, 0.19, 0.23, 1.0)
@export_range(0.0, 180.0, 5.0) var edge_softness := 80.0
@export_range(0.0, 24.0, 1.0) var wall_edge_softness := 8.0
@export_range(0.0, 2.0, 0.05) var blur_strength := 0.28

@onready var _fog_rect: ColorRect = $ColorRect

var _target: Node2D
var _wall_segments: Array = []
var _world_visibility_polygon := PackedVector2Array()
var _last_target_position := Vector2.ZERO
var _last_canvas_transform := Transform2D.IDENTITY
var _has_visibility_cache := false


func _ready() -> void:
	if not target_path.is_empty():
		_target = get_node_or_null(target_path) as Node2D
	_wall_segments = _collect_wall_segments()
	_update_visibility()
	_update_blob_visibility()


func _physics_process(_delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		if not target_path.is_empty():
			_target = get_node_or_null(target_path) as Node2D
		if _target == null:
			return

	var canvas_transform := get_viewport().get_canvas_transform()
	var target_moved := _target.global_position.distance_squared_to(_last_target_position) > 0.01
	if not _has_visibility_cache or target_moved or canvas_transform != _last_canvas_transform:
		_update_visibility()
	_update_blob_visibility()


func refresh_occluders(group_name: String = "") -> void:
	if not group_name.is_empty():
		occluder_group = group_name
	_wall_segments = _collect_wall_segments()
	_has_visibility_cache = false
	_update_visibility()
	_update_blob_visibility()


func _collect_wall_segments() -> Array:
	var polygons: Array = []
	for occluder in get_tree().get_nodes_in_group(occluder_group):
		if not occluder is Node2D:
			continue
		for node in occluder.find_children("*", "CollisionShape2D", true, false):
			var collision_shape := node as CollisionShape2D
			if collision_shape.disabled or collision_shape.shape == null:
				continue
			var local_points := _shape_outline(collision_shape.shape)
			if local_points.size() < 3:
				continue
			var world_polygon := PackedVector2Array()
			for point in local_points:
				world_polygon.append(collision_shape.to_global(point))
			polygons.append(world_polygon)

		for node in occluder.find_children("*", "CollisionPolygon2D", true, false):
			var collision_polygon := node as CollisionPolygon2D
			if collision_polygon.disabled or collision_polygon.polygon.size() < 3:
				continue
			var world_polygon := PackedVector2Array()
			for point in collision_polygon.polygon:
				world_polygon.append(collision_polygon.to_global(point))
			polygons.append(world_polygon)

	var segments := VisibilityPolygonLibrary.convert_to_segments(polygons)
	if segments.is_empty():
		return segments
	# Wall collision outlines may meet or overlap at corners; split them before the sweep.
	return VisibilityPolygonLibrary.break_intersections(segments)


func _shape_outline(shape: Shape2D) -> PackedVector2Array:
	var points := PackedVector2Array()
	if shape is RectangleShape2D:
		var half_size := (shape as RectangleShape2D).size * 0.5
		points.append_array(PackedVector2Array([
			Vector2(-half_size.x, -half_size.y),
			Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, half_size.y),
			Vector2(-half_size.x, half_size.y)
		]))
	elif shape is ConvexPolygonShape2D:
		points = (shape as ConvexPolygonShape2D).points
	return points


func _update_visibility() -> void:
	if _target == null:
		return
	var material := _fog_rect.material as ShaderMaterial
	var viewport_size := get_viewport().get_visible_rect().size
	var canvas_transform := get_viewport().get_canvas_transform()
	var center_on_screen := canvas_transform * _target.global_position
	var segments := _wall_segments
	if segments.is_empty():
		segments = _create_fallback_bounds(_target.global_position)
	var world_polygon := VisibilityPolygonLibrary.compute(_target.global_position, segments)
	_world_visibility_polygon = world_polygon
	var screen_polygon := PackedVector2Array()
	var visible_point_count := mini(world_polygon.size(), MAX_POLYGON_POINTS)
	for index in range(visible_point_count):
		screen_polygon.append((canvas_transform * world_polygon[index]) / viewport_size)
	if visible_point_count == 0:
		return

	# The shader uniform is fixed-size; the vertex count limits which points are used.
	while screen_polygon.size() < MAX_POLYGON_POINTS:
		screen_polygon.append(screen_polygon[screen_polygon.size() - 1])
	material.set_shader_parameter("visibility_points", screen_polygon)
	material.set_shader_parameter("point_count", visible_point_count)
	material.set_shader_parameter("player_uv", center_on_screen / viewport_size)
	material.set_shader_parameter("viewport_size", viewport_size)
	material.set_shader_parameter(
		"vision_radius_pixels",
		canvas_transform.basis_xform(Vector2(vision_radius, 0.0)).length()
	)
	material.set_shader_parameter("fog_color", fog_color)
	material.set_shader_parameter("fog_opacity", fog_opacity)
	material.set_shader_parameter("blur_strength", blur_strength)
	material.set_shader_parameter("edge_softness", edge_softness)
	material.set_shader_parameter("wall_edge_softness", wall_edge_softness)
	_last_target_position = _target.global_position
	_last_canvas_transform = canvas_transform
	_has_visibility_cache = true


func _update_blob_visibility() -> void:
	if _target == null:
		return
	for blob in get_tree().get_nodes_in_group("ping_blobs"):
		if blob == _target or not blob is Node2D:
			continue
		var blob_node := blob as Node2D
		var within_radius := _target.global_position.distance_to(blob_node.global_position) <= vision_radius
		var visible_through_walls := (
			not _world_visibility_polygon.is_empty()
			and VisibilityPolygonLibrary.point_in_polygon(blob_node.global_position, _world_visibility_polygon)
		)
		var is_in_view := within_radius and visible_through_walls
		# Only hide drawing; the blob's physics, interaction, and ping response keep running.
		if blob_node.has_method("set_fov_visible"):
			blob_node.call("set_fov_visible", is_in_view)
		else:
			blob_node.visible = is_in_view


func _create_fallback_bounds(center: Vector2) -> Array:
	var extent := vision_radius * 2.0
	var minimum := center - Vector2.ONE * extent
	var maximum := center + Vector2.ONE * extent
	return [
		[Vector2(minimum.x, minimum.y), Vector2(maximum.x, minimum.y)],
		[Vector2(maximum.x, minimum.y), Vector2(maximum.x, maximum.y)],
		[Vector2(maximum.x, maximum.y), Vector2(minimum.x, maximum.y)],
		[Vector2(minimum.x, maximum.y), Vector2(minimum.x, minimum.y)],
	]

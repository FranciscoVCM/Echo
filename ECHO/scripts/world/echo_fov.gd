class_name EchoFov
extends CanvasLayer
## Fog of war for the large Echo world. Same idea as field_of_view.gd (which stays for the
## arena), but: segments come from the world geometry and are filtered around the player,
## the polygon is clipped to the screen, and it supports light sources and per-area tuning.

const MAX_POLYGON_POINTS := 384
const MAX_LIGHTS := 48
const FILTER_RADIUS := 760.0
const SHADER: Shader = preload("res://resources/echo_fog.gdshader")

@export var vision_radius := 240.0
@export var fog_opacity := 0.7
@export var fog_color := Color(0.05, 0.06, 0.08, 1.0)
@export var edge_softness := 90.0

var target: Node2D
## Array of [Vector2 world_position, float radius, float strength].
var lights: Array = []

var _rect: ColorRect
var _material: ShaderMaterial
var _all_segments: Array = []
var _segments: Array = []
var _filter_center := Vector2(INF, INF)
var _world_polygon := PackedVector2Array()
var _last_position := Vector2(INF, INF)
var _last_canvas := Transform2D()
var _last_segment_count := -1


func _ready() -> void:
	layer = 1
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect.material = _material
	add_child(_rect)


func set_world_segments(segments: Array) -> void:
	_all_segments = segments
	_filter_center = Vector2(INF, INF)


func _physics_process(_delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.global_position.distance_to(_filter_center) > 160.0:
		_refilter()
	_update_visibility()
	_update_blob_visibility()


func _refilter() -> void:
	_filter_center = target.global_position
	var raw: Array = []
	var limit := FILTER_RADIUS + 180.0
	for segment in _all_segments:
		var a: Vector2 = segment[0]
		var b: Vector2 = segment[1]
		var closest := Geometry2D.get_closest_point_to_segment(_filter_center, a, b)
		if closest.distance_to(_filter_center) <= limit:
			raw.append(segment)
	_segments = raw


func _update_visibility() -> void:
	var viewport := get_viewport()
	var viewport_size := viewport.get_visible_rect().size
	var canvas := viewport.get_canvas_transform()
	var inverse := canvas.affine_inverse()
	var view_min := inverse * Vector2.ZERO
	var view_max := inverse * viewport_size
	var position := target.global_position
	var unchanged := position.distance_squared_to(_last_position) < 0.25 and canvas == _last_canvas and _all_segments.size() == _last_segment_count
	if not unchanged:
		_last_position = position
		_last_canvas = canvas
		_last_segment_count = _all_segments.size()
		_recompute_polygon(position, view_min, view_max)
	_upload(canvas, viewport_size, position)


func _recompute_polygon(position: Vector2, view_min: Vector2, view_max: Vector2) -> void:
	var pad := Vector2(40, 40)
	if _segments.is_empty():
		_world_polygon = PackedVector2Array([view_min - pad, Vector2(view_max.x, view_min.y) + Vector2(pad.x, -pad.y), view_max + pad, Vector2(view_min.x, view_max.y) + Vector2(-pad.x, pad.y)])
	else:
		_world_polygon = VisibilityPolygon.compute_viewport(position, _segments, view_min - pad, view_max + pad)


func _upload(canvas: Transform2D, viewport_size: Vector2, position: Vector2) -> void:
	var count := mini(_world_polygon.size(), MAX_POLYGON_POINTS)
	var screen_points := PackedVector2Array()
	for index in range(count):
		screen_points.append((canvas * _world_polygon[index]) / viewport_size)
	if count == 0:
		return
	while screen_points.size() < MAX_POLYGON_POINTS:
		screen_points.append(screen_points[screen_points.size() - 1])
	var scale := canvas.basis_xform(Vector2(1.0, 0.0)).length()
	_material.set_shader_parameter("visibility_points", screen_points)
	_material.set_shader_parameter("point_count", count)
	_material.set_shader_parameter("player_uv", (canvas * position) / viewport_size)
	_material.set_shader_parameter("viewport_size", viewport_size)
	_material.set_shader_parameter("vision_radius_pixels", vision_radius * scale)
	_material.set_shader_parameter("edge_softness", edge_softness * scale)
	_material.set_shader_parameter("fog_color", fog_color)
	_material.set_shader_parameter("fog_opacity", fog_opacity)
	var light_data := PackedVector4Array()
	for light in lights:
		if light_data.size() >= MAX_LIGHTS:
			break
		var screen: Vector2 = canvas * (light[0] as Vector2)
		var radius: float = float(light[1]) * scale
		if screen.x < -radius or screen.y < -radius or screen.x > viewport_size.x + radius or screen.y > viewport_size.y + radius:
			continue
		light_data.append(Vector4(screen.x, screen.y, radius, float(light[2])))
	var used := light_data.size()
	while light_data.size() < MAX_LIGHTS:
		light_data.append(Vector4.ZERO)
	_material.set_shader_parameter("lights", light_data)
	_material.set_shader_parameter("light_count", used)


func is_point_visible(point: Vector2) -> bool:
	if target == null:
		return false
	if target.global_position.distance_to(point) > vision_radius:
		for light in lights:
			if point.distance_to(light[0]) <= float(light[1]) * 0.8:
				return true
		return false
	return _world_polygon.size() >= 3 and Geometry2D.is_point_in_polygon(point, _world_polygon)


func _update_blob_visibility() -> void:
	for blob in get_tree().get_nodes_in_group("ping_blobs"):
		if blob == target or not blob is Node2D:
			continue
		var node := blob as Node2D
		var in_view := is_point_visible(node.global_position)
		if node.has_method("set_fov_visible"):
			node.call("set_fov_visible", in_view)
		else:
			node.visible = in_view

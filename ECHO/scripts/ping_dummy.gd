class_name PingDummy
extends CharacterBody2D
## Stationary test blob that answers the player's sonar pulse.

const POINT_COUNT := 40

@export_category("Appearance")
@export_range(8.0, 64.0, 1.0) var body_radius := 24.0
@export var body_color := Color(0.88, 0.28, 0.26, 1.0)
@export var outline_color := Color(0.38, 0.10, 0.12, 1.0)
@export_range(0.5, 8.0, 0.5) var outline_width := 2.5

@export_category("Collision")
@export_range(20.0, 48.0, 1.0) var collision_radius := 35.0

@export_category("Field of View")
@export_range(0.05, 1.0, 0.05) var fov_fade_duration := 0.24

@onready var _ping_emitter: PingEmitter = $PingEmitter
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
var _was_pinging := false
var _fov_visibility_initialized := false
var _fov_target_visible := true
var _fov_tween: Tween


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var collision_circle := _collision_shape.shape as CircleShape2D
	if collision_circle != null:
		var instance_shape := collision_circle.duplicate() as CircleShape2D
		instance_shape.radius = collision_radius
		_collision_shape.shape = instance_shape
	queue_redraw()


func _process(_delta: float) -> void:
	var is_animating := not is_zero_approx(_ping_emitter.ping_squash)
	if is_animating or _was_pinging or _ping_emitter.cooldown_opacity < 0.999:
		queue_redraw()
	_was_pinging = is_animating


func receive_ping(source_position: Vector2, is_echo: bool) -> void:
	_ping_emitter.receive_ping(source_position, is_echo)


func receive_ping_details(
	source_position: Vector2,
	is_echo: bool,
	charge: float,
	tone_index: int,
	frequency: float,
	wave_id: int
) -> void:
	_ping_emitter.receive_ping_details(source_position, is_echo, charge, tone_index, frequency, wave_id)


func set_fov_visible(is_in_view: bool) -> void:
	var interaction := get_node_or_null("Interaction")
	if interaction != null and interaction.has_method("fov_visibility_override"):
		var override: int = interaction.call("fov_visibility_override")
		if override >= 0:
			is_in_view = override == 1
	# Keep physics and ping handling active while fading only the rendered node.
	if not _fov_visibility_initialized:
		_fov_visibility_initialized = true
		_fov_target_visible = is_in_view
		visible = is_in_view
		modulate.a = 1.0
		return
	if _fov_target_visible == is_in_view:
		return

	_fov_target_visible = is_in_view
	if _fov_tween != null and _fov_tween.is_running():
		_fov_tween.kill()
	if is_in_view:
		visible = true
	_fov_tween = create_tween()
	_fov_tween.tween_property(self, "modulate:a", 1.0 if is_in_view else 0.0, fov_fade_duration)
	if not is_in_view:
		_fov_tween.tween_callback(hide)


func _draw() -> void:
	var contour := PackedVector2Array()
	for index in range(POINT_COUNT):
		var angle := TAU * float(index) / float(POINT_COUNT)
		var irregularity := 1.0 + sin(angle * 3.0 + 0.4) * 0.035 + sin(angle * 5.0 - 1.0) * 0.018
		var horizontal_scale := 1.0 + _ping_emitter.ping_squash * 0.035
		var vertical_scale := 1.0 - _ping_emitter.ping_squash * 0.07
		var point := Vector2.RIGHT.rotated(angle) * body_radius * irregularity
		contour.append(Vector2(point.x * horizontal_scale, point.y * vertical_scale))
	var fill_color := body_color
	fill_color.a *= _ping_emitter.cooldown_opacity
	draw_colored_polygon(contour, fill_color)
	contour.append(contour[0])
	draw_polyline(contour, outline_color, outline_width, true)

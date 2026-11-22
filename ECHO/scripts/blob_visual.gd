class_name BlobVisual
extends Node2D
## Draws and animates the blob; PlayerController remains responsible for movement and collisions.

# More points produce a smoother contour; slight radial variation avoids a perfect circle.
const BODY_POINT_COUNT := 40

@onready var _controller: PlayerController = get_parent() as PlayerController

@export_category("Shape")
## Resting visual radius, independent of the CharacterBody2D collision radius.
@export_range(8.0, 64.0, 1.0) var body_radius: float = 20.0
## Surface and outline colors.
@export var body_color := Color(0.22, 0.78, 0.78, 1.0)
@export var outline_color := Color(0.08, 0.35, 0.43, 1.0)
@export var body_shadow_color := Color(0.025, 0.11, 0.15, 0.16)
@export_range(0.5, 8.0, 0.5) var outline_width := 2.5

@export_category("Movement Response")
## Maximum stretch in the movement direction.
@export_range(0.0, 0.5, 0.01) var max_stretch: float = 0.25
## Spring strength that restores each contour point.
@export_range(1.0, 60.0, 0.5) var spring_strength: float = 30.0
## Damping prevents the surface from oscillating indefinitely.
@export_range(0.1, 20.0, 0.1) var damping: float = 8.0

@export_category("Collision Squish")
## How much the side touching a wall compresses under player input.
@export_range(0.0, 0.7, 0.01) var wall_compression: float = 0.5
## How much the body expands sideways during compression.
@export_range(0.0, 0.6, 0.01) var wall_lateral_expansion: float = 0.38

@export_category("Ping Feedback")
@export_range(0.0, 2.0, 0.05) var tone_change_shake_strength := 0.65

@export_category("Dash Feedback Colors")
## Color of the dash trail.
@export var dash_trail_color := Color(0.94, 0.98, 1.0, 1.0)
@export var dash_ripple_color := Color(0.9, 0.95, 1.0, 1.0)
## The arrow uses a dark edge and a lighter fill for contrast against the blob.
@export var dash_arrow_outline_color := Color(0.12, 0.15, 0.18, 1.0)
@export var dash_arrow_fill_color := Color(0.94, 0.98, 1.0, 1.0)

@export_category("Dash Cooldown Colors")
@export var cooldown_track_color := Color(0.05, 0.08, 0.06, 0.55)
@export var cooldown_low_color := Color(0.92, 0.12, 0.10, 1.0)
@export var cooldown_middle_color := Color(1.0, 0.82, 0.16, 1.0)
@export var cooldown_ready_color := Color(0.24, 0.88, 0.42, 1.0)

# Internal animation state: direction, pressure, contour shape, and body offset.
var _time := 0.0
var _deformation_direction := Vector2.DOWN
var _wall_pressure_direction := Vector2.ZERO
var _wall_pressure_intensity := 0.0
var _normalized_speed := 0.0
var _initial_body_radius := 0.0
var _base_radii: Array[float] = []
var _body_radii: Array[float] = []
var _radius_velocities: Array[float] = []
var _body_offset := Vector2.ZERO
var _body_offset_velocity := Vector2.ZERO
var _dash_trail_intensity := 0.0
var _previous_velocity := Vector2.ZERO
var _peak_speed_since_stop := 0.0
var _stop_direction := Vector2.DOWN
var _stop_squash := 0.0
var _stop_squash_velocity := 0.0
var _previous_input_direction := Vector2.ZERO
var _anticipation_direction := Vector2.DOWN
var _anticipation_time_remaining := 0.0
var _anticipation_strength := 0.0
var _current_anticipation := 0.0
var _dash_visual_compression := 0.0
var _dash_visual_stretch := 0.0
var _dash_visual_intensity := 0.0
var _charge_arrow_opacity := 0.0
var _tone_jolt_remaining := 0.0
@onready var _ping_emitter: PingEmitter = get_parent().get_node_or_null("PingEmitter") as PingEmitter


func _ready() -> void:
	_initial_body_radius = body_radius
	if _ping_emitter != null:
		_ping_emitter.ping_tone_changed.connect(_on_ping_tone_changed)
	# Store a slightly irregular resting radius so the blob does not look geometric.
	for index in range(BODY_POINT_COUNT):
		var angle := TAU * float(index) / float(BODY_POINT_COUNT)
		var irregularity := 1.0 + sin(angle * 3.0 + 0.4) * 0.035 + sin(angle * 5.0 - 1.0) * 0.018
		var initial_radius := body_radius * irregularity
		_base_radii.append(initial_radius)
		_body_radii.append(initial_radius)
		_radius_velocities.append(0.0)


func _process(delta: float) -> void:
	_time += delta
	_tone_jolt_remaining = maxf(_tone_jolt_remaining - delta, 0.0)
	if _controller != null:
		var max_speed := _controller.movement.max_speed if _controller.movement != null else 1.0
		_update_movement_response(
			_controller.velocity,
			_controller.input_direction,
			_controller.wall_pressure_direction,
			max_speed,
			delta
		)
		var trail_target := 1.0 if _controller.dash_active else 0.0
		var trail_fade_time := 0.035 if _controller.dash_active else 0.14
		_dash_trail_intensity = move_toward(_dash_trail_intensity, trail_target, delta / trail_fade_time)
		if _controller.dash_charging:
			_dash_visual_compression = 0.25 + 0.75 * _controller.dash_charge
			_dash_visual_stretch = 0.0
			_dash_visual_intensity = 1.0
		elif _controller.dash_active:
			var dash_phase := clampf(1.0 - _controller.dash_time_remaining / maxf(_controller.current_dash_duration, 0.001), 0.0, 1.0)
			var charge_intensity := 0.25 + 0.75 * _controller.dash_charge
			_dash_visual_compression = charge_intensity * (1.0 - _smooth_fade(clampf(dash_phase / 0.48, 0.0, 1.0)))
			_dash_visual_stretch = charge_intensity * _smooth_fade(clampf((dash_phase - 0.24) / 0.5, 0.0, 1.0))
			_dash_visual_intensity = 1.0
		else:
			_dash_visual_intensity = move_toward(_dash_visual_intensity, 0.0, delta * 7.0)
		var arrow_target := 1.0 if _controller.dash_charging and _controller.dash_fully_charged else 0.0
		var arrow_fade_duration := 0.12 if arrow_target > _charge_arrow_opacity else 0.18
		_charge_arrow_opacity = lerpf(
			_charge_arrow_opacity,
			arrow_target,
			1.0 - exp(-delta / arrow_fade_duration)
		)
	else:
		_charge_arrow_opacity = move_toward(_charge_arrow_opacity, 0.0, delta / 0.18)
	# Update surface radii and ask Godot to redraw the blob.
	_update_contour(delta)
	queue_redraw()


func _update_movement_response(
	velocity: Vector2,
	requested_direction: Vector2,
	wall_pressure_direction: Vector2,
	max_speed: float,
	delta: float
) -> void:
	# Normalize speed and contact values for animation.
	_normalized_speed = clampf(velocity.length() / maxf(max_speed, 1.0), 0.0, 1.0)
	# When movement stops abruptly, the mass compresses and settles with a small bounce.
	if velocity.length() > 14.0:
		_peak_speed_since_stop = maxf(_peak_speed_since_stop, velocity.length())
	if _previous_velocity.length() > 14.0 and velocity.length() <= 14.0:
		var stop_strength := clampf(_peak_speed_since_stop / maxf(max_speed, 1.0), 0.0, 1.0)
		_stop_direction = _previous_velocity.normalized()
		_stop_squash = maxf(_stop_squash, stop_strength * 0.7)
		_stop_squash_velocity = -stop_strength * 3.8
		_body_offset_velocity += _stop_direction * stop_strength * 95.0
		_peak_speed_since_stop = 0.0
	_previous_velocity = velocity
	var squash_acceleration := -_stop_squash * 88.0 - _stop_squash_velocity * 12.0
	_stop_squash_velocity += squash_acceleration * delta
	_stop_squash = clampf(_stop_squash + _stop_squash_velocity * delta, -0.25, 1.0)
	_wall_pressure_intensity = clampf(wall_pressure_direction.length(), 0.0, 1.0)
	if _wall_pressure_intensity > 0.0:
		_wall_pressure_direction = wall_pressure_direction.normalized()
	var is_charging_dash := _controller != null and _controller.dash_charging
	# The visual front follows input immediately, except during radial dash charging.
	if requested_direction != Vector2.ZERO:
		var new_direction := requested_direction.normalized()
		var started_moving := _previous_input_direction == Vector2.ZERO
		var changed_direction := not started_moving and _previous_input_direction.dot(new_direction) < 0.5
		if not is_charging_dash and (started_moving or changed_direction):
			_anticipation_direction = new_direction
			_anticipation_time_remaining = 0.15
			_anticipation_strength = lerpf(0.55, 0.24, _normalized_speed) * (1.0 if started_moving else 0.7)
		if not is_charging_dash:
			_deformation_direction = new_direction
		_previous_input_direction = new_direction
	else:
		_previous_input_direction = Vector2.ZERO
	_anticipation_time_remaining = maxf(_anticipation_time_remaining - delta, 0.0)
	var anticipation_progress := 1.0 - _anticipation_time_remaining / 0.15
	_current_anticipation = _anticipation_strength * sin(PI * anticipation_progress)

	# The visual center lags slightly; wall pressure pushes it inward.
	var target_offset := Vector2.ZERO if is_charging_dash else -_deformation_direction * (_normalized_speed * 4.0)
	target_offset -= _anticipation_direction * (_current_anticipation * 3.5)
	target_offset += _wall_pressure_direction * (_wall_pressure_intensity * 8.0)
	var offset_acceleration := (target_offset - _body_offset) * 24.0
	_body_offset_velocity += offset_acceleration * delta
	_body_offset_velocity *= exp(-8.0 * delta)
	_body_offset += _body_offset_velocity * delta


func _update_contour(delta: float) -> void:
	# Each point reacts to direction, speed, and contact; a damped spring restores it.
	var breathing := 1.0 + sin(_time * 2.3) * 0.025 * (1.0 - _normalized_speed)
	var stretch := max_stretch * _normalized_speed
	if _controller != null and _controller.dash_charging:
		stretch = 0.0
	elif _controller != null and _controller.dash_active:
		# Let the dash deformation dominate the normal running stretch.
		stretch *= 0.15
	var stiffness := spring_strength * lerpf(1.0, 2.4, _wall_pressure_intensity)
	var current_damping := damping * lerpf(1.0, 0.75, _wall_pressure_intensity)
	var size_scale := body_radius / maxf(_initial_body_radius, 1.0)
	for index in range(BODY_POINT_COUNT):
		var angle := TAU * float(index) / float(BODY_POINT_COUNT)
		var radial := Vector2(cos(angle), sin(angle))
		var forward := radial.dot(_deformation_direction)
		var lateral := radial.dot(_deformation_direction.orthogonal())
		var directional_shape := 1.0 + stretch * forward * forward - stretch * 0.48 * lateral * lateral
		# Compress the front slightly and shift volume backward as the blob accelerates.
		if _controller == null or not _controller.dash_charging:
			directional_shape -= forward * _normalized_speed * 0.055
		var stop_forward := radial.dot(_stop_direction)
		var stop_side := radial.dot(_stop_direction.orthogonal())
		directional_shape -= _stop_squash * 0.25 * stop_forward * stop_forward
		directional_shape += _stop_squash * 0.17 * stop_side * stop_side
		var anticipation_forward := radial.dot(_anticipation_direction)
		var anticipation_side := radial.dot(_anticipation_direction.orthogonal())
		directional_shape -= _current_anticipation * 0.18 * anticipation_forward * anticipation_forward
		directional_shape += _current_anticipation * 0.12 * anticipation_side * anticipation_side
		var wall_forward := maxf(radial.dot(_wall_pressure_direction), 0.0)
		var wall_side := absf(radial.dot(_wall_pressure_direction.orthogonal()))
		directional_shape -= wall_compression * _wall_pressure_intensity * pow(wall_forward, 2.0)
		directional_shape += wall_lateral_expansion * _wall_pressure_intensity * pow(wall_side, 4.0)
		var wave := sin(angle * 3.0 + _time * (2.0 + _normalized_speed * 3.0)) * 0.035 * _normalized_speed
		var target_radius := _base_radii[index] * size_scale * breathing * directional_shape * (1.0 + wave)
		var radius_acceleration := (target_radius - _body_radii[index]) * stiffness
		_radius_velocities[index] += radius_acceleration * delta
		_radius_velocities[index] *= exp(-current_damping * delta)
		_body_radii[index] += _radius_velocities[index] * delta


func _draw() -> void:
	# Draw the blob and its movement feedback from the current spring contour.
	var points := _create_contour(_body_offset)
	_apply_dash_deformation(points)
	_apply_ping_deformation(points)
	if _tone_jolt_remaining > 0.0:
		var jolt_fade := _tone_jolt_remaining / 0.12
		var jolt_offset := Vector2(sin(_time * 34.0), cos(_time * 29.0)) * tone_change_shake_strength * jolt_fade
		for index in range(points.size()):
			points[index] += jolt_offset
	var dash_fully_charged := _controller != null and _controller.dash_fully_charged
	var ping_fully_charged := _ping_emitter != null and _ping_emitter.ping_charging and _ping_emitter.ping_charge >= 1.0
	if dash_fully_charged or ping_fully_charged:
		_draw_charge_ripples()
	if dash_fully_charged:
		var vibration := Vector2(sin(_time * 61.0), cos(_time * 67.0)) * 0.8
		for index in range(points.size()):
			points[index] += vibration
	if _controller != null and _dash_trail_intensity > 0.001:
		_draw_dash_trail(points)
	var shadow := points.duplicate()
	for index in range(shadow.size()):
		shadow[index] += Vector2(0.0, 2.5)
	draw_colored_polygon(shadow, body_shadow_color)
	var fill_color := body_color
	if _ping_emitter != null:
		fill_color.a *= _ping_emitter.cooldown_opacity
	draw_colored_polygon(points, fill_color)
	var closed_outline := points.duplicate()
	closed_outline.append(points[0])
	draw_polyline(closed_outline, outline_color, outline_width, true)
	_draw_full_charge_direction()
	_draw_dash_meter()
	_draw_ping_meter()


func _apply_ping_deformation(points: PackedVector2Array) -> void:
	if _ping_emitter == null:
		return
	var charge_scale := 1.0
	if _ping_emitter.ping_charging:
		charge_scale = 1.0 - _ping_emitter.ping_charge * 0.08
	var horizontal_scale := 1.0 + _ping_emitter.ping_squash * 0.035
	var vertical_scale := 1.0 - _ping_emitter.ping_squash * 0.07
	for index in range(points.size()):
		var relative := (points[index] - _body_offset) * charge_scale
		points[index] = _body_offset + Vector2(relative.x * horizontal_scale, relative.y * vertical_scale)


func _on_ping_tone_changed(_tone_index: int, _note_name: String, _frequency: float) -> void:
	_tone_jolt_remaining = 0.12


func _apply_dash_deformation(points: PackedVector2Array) -> void:
	if _controller == null or _dash_visual_intensity <= 0.001:
		return
	if _controller.dash_charging:
		# Charge compresses the mass uniformly, so changing direction does not rotate it.
		var charge_scale := 1.0 - 0.28 * _dash_visual_compression
		for index in range(points.size()):
			points[index] = _body_offset + (points[index] - _body_offset) * charge_scale
		return
	var direction := _controller.dash_direction
	var lateral := direction.orthogonal()
	var forward_scale := 1.0 - 0.48 * _dash_visual_compression + 0.52 * _dash_visual_stretch
	var lateral_scale := 1.0 + 0.32 * _dash_visual_compression - 0.30 * _dash_visual_stretch
	forward_scale = lerpf(1.0, forward_scale, _dash_visual_intensity)
	lateral_scale = lerpf(1.0, lateral_scale, _dash_visual_intensity)
	for index in range(points.size()):
		var relative := points[index] - _body_offset
		points[index] = _body_offset + direction * (relative.dot(direction) * forward_scale) + lateral * (relative.dot(lateral) * lateral_scale)


func _draw_charge_ripples() -> void:
	for index in 2:
		var phase := fposmod(_time * 1.25 + float(index) * 0.5, 1.0)
		var ripple_radius := body_radius + 4.0 + phase * 15.0
		var opacity := (1.0 - phase) * 0.22
		var ripple_tint := dash_ripple_color
		ripple_tint.a *= opacity
		draw_arc(_body_offset, ripple_radius, 0.0, TAU, 48, ripple_tint, 1.4, true)


func _create_contour(offset: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()

	for index in range(BODY_POINT_COUNT):
		var angle := TAU * float(index) / float(BODY_POINT_COUNT)
		var radius := _body_radii[index]
		var point := Vector2(cos(angle), sin(angle)) * radius
		points.append(offset + point)
	return points


func _draw_dash_trail(points: PackedVector2Array) -> void:
	var direction := _controller.dash_direction
	for layer in range(4, 0, -1):
		var trail := PackedVector2Array()
		for point in points:
			var relative := point - _body_offset
			var stretched := relative + direction * relative.dot(direction) * 0.23
			trail.append(_body_offset + stretched - direction * float(layer) * 6.5)
		var alpha := (0.07 + float(4 - layer) * 0.035) * _dash_trail_intensity
		var trail_tint := dash_trail_color
		trail_tint.a *= alpha
		draw_colored_polygon(trail, trail_tint)


func _draw_dash_meter() -> void:
	if _controller == null or _controller.dash_cooldown_remaining <= 0.0:
		return
	var center := _body_offset + Vector2(-12.0, -body_radius - 14.0)
	_draw_cooldown_meter(center, _controller.dash_cooldown_remaining, _controller.dash_cooldown)


func _draw_ping_meter() -> void:
	if _ping_emitter == null or _ping_emitter.ping_cooldown <= 0.0 or _ping_emitter.ping_cooldown_remaining <= 0.0:
		return
	var center := _body_offset + Vector2(12.0, -body_radius - 14.0)
	_draw_cooldown_meter(center, _ping_emitter.ping_cooldown_remaining, _ping_emitter.ping_cooldown)


func _draw_cooldown_meter(center: Vector2, remaining: float, duration: float) -> void:
	var progress := clampf(1.0 - remaining / duration, 0.0, 1.0)
	var meter_radius := 8.0
	var fade_in := _smooth_fade(clampf(progress / 0.1, 0.0, 1.0))
	var fade_out := _smooth_fade(clampf(remaining / 0.22, 0.0, 1.0))
	var opacity := fade_in * fade_out
	var meter_scale := lerpf(0.72, 1.0, fade_in)
	meter_radius *= meter_scale
	var track_tint := cooldown_track_color
	track_tint.a *= opacity
	draw_arc(center, meter_radius, 0.0, TAU, 32, track_tint, 3.0 * meter_scale, true)
	if progress > 0.0:
		var end_angle := -PI * 0.5 + TAU * progress
		var cooldown_tint := _cooldown_color(progress)
		cooldown_tint.a *= 0.98 * opacity
		draw_arc(center, meter_radius, -PI * 0.5, end_angle, 32, cooldown_tint, 3.0 * meter_scale, true)


func _cooldown_color(progress: float) -> Color:
	if progress < 0.5:
		return cooldown_low_color.lerp(cooldown_middle_color, _smooth_fade(progress * 2.0))
	return cooldown_middle_color.lerp(cooldown_ready_color, _smooth_fade((progress - 0.5) * 2.0))


func _draw_full_charge_direction() -> void:
	if _controller == null or _charge_arrow_opacity <= 0.01:
		return
	var direction := _controller.charge_direction.normalized()
	if direction == Vector2.ZERO:
		return
	var perpendicular := direction.orthogonal()
	var anchor := _body_offset + direction * (body_radius + 9.0)
	var shaft_start := anchor - direction * 5.0
	var tip := anchor + direction * 7.0
	var head_base := tip - direction * 5.5
	var head_left := head_base + perpendicular * 4.0
	var head_right := head_base - perpendicular * 4.0
	var dark := dash_arrow_outline_color
	dark.a *= 0.95 * _charge_arrow_opacity
	var light := dash_arrow_fill_color
	light.a *= 0.98 * _charge_arrow_opacity
	draw_line(shaft_start, tip, dark, 4.0, true)
	draw_line(head_left, tip, dark, 4.0, true)
	draw_line(tip, head_right, dark, 4.0, true)
	draw_line(shaft_start, tip, light, 2.0, true)
	draw_line(head_left, tip, light, 2.0, true)
	draw_line(tip, head_right, light, 2.0, true)


func _smooth_fade(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)

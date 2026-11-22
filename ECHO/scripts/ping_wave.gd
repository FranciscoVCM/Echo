class_name PingWave
extends Node2D
## Radial pulse whose wavefront stops at the first collider along each direction.

const RAY_COUNT := 360
const FADE_DURATION := 0.18

var _source: CollisionObject2D
var _max_range := 600.0
var _travel_duration := 1.5
var _wave_color := Color.WHITE
var _is_echo := false
var _charge := 1.0
var _tone_index := 0
var _frequency := 130.8128
## All scale degrees carried by this wave (one for a single note, several for a chord).
var _tone_indices := PackedInt32Array()
var _tone_colors: Array[Color] = []
@export_flags_2d_physics var collision_mask := 2
@export var receiver_group := "ping_blobs"
var _radius := 0.0
var _travel_elapsed := 0.0
var _fade := 1.0
var _travel_intensity := 1.0
var _ray_distances: Array[float] = []
var _receiver_targets: Array[Node2D] = []
var _receiver_distances: Array[float] = []
var _notified_targets: Dictionary = {}
var _range_finished := false
var _fade_remaining := FADE_DURATION


func _ready() -> void:
	add_to_group("active_ping_waves")


func configure(
	source: CollisionObject2D,
	max_range: float,
	travel_duration: float,
	wave_color: Color,
	is_echo: bool,
	charge: float = 1.0,
	tone_index: int = 0,
	frequency: float = 130.8128
) -> void:
	_source = source
	_max_range = max_range
	_travel_duration = travel_duration
	_wave_color = wave_color
	_is_echo = is_echo
	_charge = charge
	_tone_index = tone_index
	_frequency = frequency
	_tone_indices = PackedInt32Array([tone_index])
	_tone_colors = [wave_color]


## Optional: make this wave carry a chord. The first degree should be the selected tone.
func set_tones(tone_indices: PackedInt32Array, tone_colors: Array) -> void:
	_tone_indices = tone_indices.duplicate()
	_tone_colors.clear()
	for color in tone_colors:
		_tone_colors.append(color)


func get_tone_indices() -> PackedInt32Array:
	return _tone_indices


## True when any tone of the wave has this pitch class (C3 and C4 both count as Dó).
func carries_pitch_class(pitch_class: int) -> bool:
	for degree in _tone_indices:
		if posmod(degree, 7) == posmod(pitch_class, 7):
			return true
	return false


func is_echo() -> bool:
	return _is_echo


func get_charge() -> float:
	return _charge


func get_source() -> CollisionObject2D:
	return _source


func _physics_process(delta: float) -> void:
	if _ray_distances.is_empty():
		_cache_ray_paths()
		_cache_receivers()

	if not _range_finished:
		_travel_elapsed += delta
		var progress := clampf(_travel_elapsed / _travel_duration, 0.0, 1.0)
		var eased_progress := 1.0 - pow(1.0 - progress, 2.2)
		_radius = _max_range * eased_progress
		_travel_intensity = lerpf(1.0, 0.22, eased_progress)
		_notify_reached_targets()
		if progress >= 1.0:
			_radius = _max_range
			_range_finished = true
	else:
		_fade_remaining -= delta
		_fade = clampf(_fade_remaining / FADE_DURATION, 0.0, 1.0)
		if _fade_remaining <= 0.0:
			queue_free()
	queue_redraw()


func _cache_ray_paths() -> void:
	var space_state := get_world_2d().direct_space_state
	for index in range(RAY_COUNT):
		var angle := TAU * float(index) / float(RAY_COUNT)
		var direction := Vector2.RIGHT.rotated(angle)
		var query := PhysicsRayQueryParameters2D.create(
			global_position,
			global_position + direction * _max_range,
			collision_mask
		)
		query.collide_with_areas = true
		if _source != null and is_instance_valid(_source):
			query.exclude = [_source.get_rid()]

		var result := space_state.intersect_ray(query)
		var travel_distance := _max_range
		if not result.is_empty():
			travel_distance = global_position.distance_to(result["position"])
		_ray_distances.append(travel_distance)


func _cache_receivers() -> void:
	var space_state := get_world_2d().direct_space_state
	for candidate in get_tree().get_nodes_in_group(receiver_group):
		if not candidate is Node2D or not candidate.has_method("receive_ping"):
			continue
		var receiver := candidate as Node2D
		if receiver == _source:
			continue
		var offset := receiver.global_position - global_position
		var center_distance := offset.length()
		if center_distance <= 0.001:
			continue

		var receiver_radius := _receiver_radius(receiver)
		var direction := offset / center_distance
		var hit_distance := maxf(center_distance - receiver_radius, 0.0)
		if hit_distance > _max_range:
			continue
		var ray_end := global_position + direction * hit_distance
		var query := PhysicsRayQueryParameters2D.create(
			global_position,
			ray_end,
			collision_mask
		)
		if _source != null and is_instance_valid(_source):
			query.exclude = [_source.get_rid()]
		var wall_hit := space_state.intersect_ray(query)
		if not wall_hit.is_empty() and global_position.distance_to(wall_hit["position"]) < hit_distance - 1.0:
			continue

		_receiver_targets.append(receiver)
		_receiver_distances.append(hit_distance)


func _receiver_radius(receiver: Node2D) -> float:
	for node in receiver.find_children("*", "CollisionShape2D", true, false):
		var collision_shape := node as CollisionShape2D
		if collision_shape.disabled or collision_shape.shape == null:
			continue
		var scale := maxf(absf(collision_shape.global_scale.x), absf(collision_shape.global_scale.y))
		if collision_shape.shape is CircleShape2D:
			return (collision_shape.shape as CircleShape2D).radius * scale
		return collision_shape.shape.get_rect().size.length() * 0.5 * scale
	return 0.0


func _notify_reached_targets() -> void:
	for index in range(_receiver_targets.size()):
		var target := _receiver_targets[index]
		if not is_instance_valid(target):
			continue
		var target_id := target.get_instance_id()
		if _notified_targets.has(target_id) or _radius < _receiver_distances[index]:
			continue
		_notified_targets[target_id] = true
		if target.has_method("receive_ping_wave"):
			# Newer receivers read everything (including chord tones) from the wave itself.
			target.call("receive_ping_wave", self)
		elif target.has_method("receive_ping_details"):
			target.call("receive_ping_details", global_position, _is_echo, _charge, _tone_index, _frequency, get_instance_id())
		else:
			target.call("receive_ping", global_position, _is_echo)


func _draw() -> void:
	if _radius <= 0.0 or _ray_distances.is_empty():
		return
	var wavefront := PackedVector2Array()
	for index in range(RAY_COUNT + 1):
		var ray_index := index % RAY_COUNT
		var angle := TAU * float(ray_index) / float(RAY_COUNT)
		var visible_radius := minf(_radius, _ray_distances[ray_index])
		wavefront.append(Vector2.RIGHT.rotated(angle) * visible_radius)

	var intensity := _travel_intensity * _fade
	var glow := Color(_wave_color, 0.16 * intensity)
	var line := Color(_wave_color, 0.88 * intensity)
	draw_polyline(wavefront, glow, 7.0, true)
	draw_polyline(wavefront, line, 2.4, true)
	# Chord tones trail the main wavefront as thinner rings in their own colours.
	for tone in range(1, _tone_colors.size()):
		var trailing := PackedVector2Array()
		var offset := 7.0 * tone
		for index in range(RAY_COUNT + 1):
			var ray_index := index % RAY_COUNT
			var angle := TAU * float(ray_index) / float(RAY_COUNT)
			var visible_radius := minf(maxf(_radius - offset, 0.0), _ray_distances[ray_index])
			trailing.append(Vector2.RIGHT.rotated(angle) * visible_radius)
		draw_polyline(trailing, Color(_tone_colors[tone], 0.75 * intensity), 2.0, true)

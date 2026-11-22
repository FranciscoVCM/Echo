class_name BlobInteractionCoordinator
extends Node2D
## Coordinates interactions that depend on more than one small blob.

@export_range(1, 8, 1) var successful_connections_required := 3
@export_range(2, 8, 1) var simultaneous_resonators_required := 3

var _interactions: Array[SmallBlobInteraction] = []
var _connection_hits_by_wave: Dictionary = {}
var _connection_progress := 0
var _connections_completed := false
var _resonance_completed := false


func configure(interactions: Array[SmallBlobInteraction]) -> void:
	_interactions = interactions
	for interaction in _interactions:
		if not interaction.ping_reached_interaction.is_connected(_on_interaction_ping_reached):
			interaction.ping_reached_interaction.connect(_on_interaction_ping_reached)
	reset_all()


func reset_interactions() -> void:
	reset_connection()
	reset_resonance()


func reset_connection() -> void:
	_connection_hits_by_wave.clear()
	_connection_progress = 0
	_connections_completed = false
	for interaction in _interactions:
		if interaction.interaction_kind == SmallBlobInteraction.Kind.CONNECTION:
			interaction.set_external_progress(0, successful_connections_required, false)
	queue_redraw()


func reset_resonance() -> void:
	_resonance_completed = false


func reset_all() -> void:
	reset_interactions()
	for interaction in _interactions:
		interaction.reset_interaction()


func get_connection_progress() -> int:
	return _connection_progress


func get_resonance_count() -> int:
	var count := 0
	for interaction in _interactions:
		if interaction.is_resonating():
			count += 1
	return count


func _process(_delta: float) -> void:
	if _resonance_completed:
		return
	if get_resonance_count() < simultaneous_resonators_required:
		return
	_resonance_completed = true
	for interaction in _interactions:
		if interaction.interaction_kind == SmallBlobInteraction.Kind.RESONANCE:
			interaction.set_synchronized_success()


func _draw() -> void:
	if not _connections_completed:
		return
	var first := _find_interaction("link_a")
	var second := _find_interaction("link_b")
	if first == null or second == null:
		return
	var first_blob := first.get_parent() as Node2D
	var second_blob := second.get_parent() as Node2D
	if first_blob == null or second_blob == null:
		return
	var start := to_local(first_blob.global_position)
	var finish := to_local(second_blob.global_position)
	var pulse := 0.5 + sin(Time.get_ticks_msec() * 0.001 * 3.0) * 0.15
	draw_line(start, finish, Color(0.68, 0.84, 1.0, 0.18 * pulse), 9.0, true)
	draw_line(start, finish, Color(0.76, 0.89, 1.0, 0.8 * pulse), 2.0, true)


func _find_interaction(target_id: String) -> SmallBlobInteraction:
	for interaction in _interactions:
		if interaction.interaction_id == target_id:
			return interaction
	return null


func _on_interaction_ping_reached(
	interaction: SmallBlobInteraction,
	_source_position: Vector2,
	_charge: float,
	_tone_index: int,
	_frequency: float,
	wave_id: int
) -> void:
	if interaction.interaction_kind != SmallBlobInteraction.Kind.CONNECTION or _connections_completed:
		return
	if not _connection_hits_by_wave.has(wave_id):
		_connection_hits_by_wave[wave_id] = {}
	var hits: Dictionary = _connection_hits_by_wave[wave_id]
	hits[interaction.interaction_id] = true
	if not hits.has("link_a") or not hits.has("link_b"):
		return
	_connection_hits_by_wave.erase(wave_id)
	_connection_progress += 1
	_connections_completed = _connection_progress >= successful_connections_required
	queue_redraw()
	for candidate in _interactions:
		if candidate.interaction_kind == SmallBlobInteraction.Kind.CONNECTION:
			candidate.set_external_progress(
				_connection_progress,
				successful_connections_required,
				_connections_completed
			)
			if _connections_completed:
				candidate.set_synchronized_success()

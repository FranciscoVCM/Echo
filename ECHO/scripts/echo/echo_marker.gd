class_name EchoMarker
extends Node2D
## Short-lived sonar silhouette: where a Ping touched a creature, a ghost of it flashes
## above the fog, so Ping is genuinely useful for finding things in the dark.

var color := Color.WHITE
var radius := 24.0
var duration := 1.6
var ring_growth := 2.2
var _elapsed := 0.0


static func spawn(at: Vector2, marker_color: Color, marker_radius: float, tree: SceneTree, big: bool = false) -> EchoMarker:
	var marker := EchoMarker.new()
	marker.color = marker_color
	marker.radius = marker_radius
	if big:
		marker.duration = 2.2
		marker.ring_growth = 5.0
	var parent := tree.get_first_node_in_group("ping_wave_layer")
	if parent == null:
		parent = tree.current_scene
	parent.add_child(marker)
	marker.global_position = at
	return marker


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress := _elapsed / duration
	var fade := 1.0 - progress
	fade *= fade
	draw_circle(Vector2.ZERO, radius, Color(color, 0.22 * fade))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color, 0.85 * fade), 2.0, true)
	var ring := radius * (1.0 + progress * ring_growth)
	draw_arc(Vector2.ZERO, ring, 0.0, TAU, 48, Color(color, 0.5 * fade), 1.5, true)

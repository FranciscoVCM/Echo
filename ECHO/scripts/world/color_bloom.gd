class_name ColorBloom
extends Node2D
## After K: the world blooms. Rainbow flower patches (every colour, not only C/M/Y/K) appear
## all over the Clareira, the Nascente and the three areas. How many depends on the
## "bloom level" (how many blobs were helped along the journey); helping more blobs after
## the ending raises the level and more flowers open.

## Patches shown per region at each level (index = level 0..4).
const COUNTS := {
	"hub": [0, 12, 22, 32, 44],
	"clearing": [0, 8, 14, 20, 28],
	"area": [0, 6, 12, 20, 30],
}
const POP_SPEED := 900.0  # px/s: flowers open in a wave travelling out from the origin

var level := 0
## region -> Array of patches, in the order they open.
var _patches: Dictionary = {}


func build(geometry: WorldGeometry) -> void:
	z_index = -1  # above the colour grading (always vivid), under creatures and fog
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for region in geometry.regions:
		var region_name: String = region["name"]
		var key := region_name if region_name in COUNTS else "area"
		var wanted: int = COUNTS[key][4]
		var list: Array = []
		var attempts := 0
		while list.size() < wanted and attempts < wanted * 40:
			attempts += 1
			var polygon: PackedVector2Array = region["polygons"][rng.randi() % region["polygons"].size()]
			var bounds := Rect2(polygon[0], Vector2.ZERO)
			for point in polygon:
				bounds = bounds.expand(point)
			var at := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
			if not Geometry2D.is_point_in_polygon(at, polygon) or not geometry.is_walkable(at, 36.0):
				continue
			if region_name == "hub" and at.length() < 150.0:
				continue  # K rests in the middle
			var too_close := false
			for other in list:
				if (other as Node2D).position.distance_to(at) < 110.0:
					too_close = true
					break
			if too_close:
				continue
			var patch := BloomPatch.new()
			patch.position = at
			patch.seed_value = rng.randi()
			patch.visible = false
			add_child(patch)
			list.append(patch)
		_patches[region_name] = list


func patch_count_visible() -> int:
	var count := 0
	for region_name in _patches:
		for patch in _patches[region_name]:
			if patch.visible:
				count += 1
	return count


## Shows the patches of `new_level`. With `origin`, new ones open in a wave from there.
func set_level(new_level: int, origin: Vector2 = Vector2.INF) -> void:
	level = clampi(new_level, 0, 4)
	for region_name in _patches:
		var key: String = region_name if region_name in COUNTS else "area"
		var shown: int = COUNTS[key][level]
		var list: Array = _patches[region_name]
		for index in range(list.size()):
			var patch: BloomPatch = list[index]
			var should := index < shown
			if should == patch.visible:
				continue
			if not should:
				patch.visible = false
				continue
			if origin == Vector2.INF:
				patch.visible = true
				patch.scale = Vector2.ONE
			else:
				patch.open_after(patch.position.distance_to(origin) / POP_SPEED)


class BloomPatch:
	extends Node2D
	var seed_value := 0

	func open_after(delay: float) -> void:
		visible = true
		scale = Vector2.ZERO
		var tween := create_tween()
		tween.tween_interval(delay)
		tween.tween_property(self, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var base := rng.randi() % 7
		# A soft wash of colour on the ground...
		draw_circle(Vector2.ZERO, rng.randf_range(46.0, 74.0), Color(EchoNotes.color_for(base), 0.16))
		draw_circle(Vector2(rng.randf_range(-20, 20), rng.randf_range(-20, 20)), rng.randf_range(26.0, 40.0), Color(EchoNotes.color_for((base + 3) % 7), 0.14))
		# ...and small flowers of neighbouring rainbow colours.
		var flowers := rng.randi_range(4, 8)
		for index in range(flowers):
			var at := Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(0.0, 44.0)
			var petal_color := EchoNotes.color_for((base + rng.randi_range(0, 3)) % 7).lightened(rng.randf_range(0.0, 0.25))
			var petal := rng.randf_range(3.5, 6.5)
			var petals := rng.randi_range(5, 6)
			var turn := rng.randf() * TAU
			for p in range(petals):
				draw_circle(at + Vector2.RIGHT.rotated(turn + TAU * p / petals) * petal * 1.1, petal, Color(petal_color, 0.95))
			draw_circle(at, petal * 0.7, Color(EchoNotes.color_for((base + 4) % 7).lightened(0.4), 1.0))


## One-shot rainbow explosion (rings + sparks) above the fog. Bigger with a higher level.
class Burst:
	extends Node2D
	var level := 1
	var _time := 0.0
	var _sparks: Array = []  # [position, velocity, colour]
	var _rings := 0
	var _reach := 0.0

	static func spawn(at: Vector2, burst_level: int, tree: SceneTree) -> Node2D:
		var burst := Burst.new()
		burst.level = clampi(burst_level, 1, 4)
		var parent := tree.get_first_node_in_group("ping_wave_layer")
		if parent == null:
			parent = tree.current_scene
		parent.add_child(burst)
		burst.global_position = at
		return burst

	func _ready() -> void:
		_rings = 4 + level * 3
		_reach = 520.0 + 420.0 * level
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for index in range(40 + level * 45):
			var direction := Vector2.RIGHT.rotated(rng.randf() * TAU)
			_sparks.append([Vector2.ZERO, direction * rng.randf_range(200.0, 340.0 + 160.0 * level), EchoNotes.color_for(rng.randi() % 7).lightened(0.15)])

	func _process(delta: float) -> void:
		_time += delta
		for spark in _sparks:
			spark[0] += spark[1] * delta
			spark[1] *= 1.0 - delta * 0.9
		if _time > 4.5 + 0.2 * _rings:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		for index in range(_rings):
			var t := (_time - index * 0.2) / 3.0
			if t <= 0.0 or t >= 1.0:
				continue
			var eased := 1.0 - pow(1.0 - t, 2.0)
			var color := EchoNotes.color_for(index % 7)
			draw_arc(Vector2.ZERO, _reach * eased, 0.0, TAU, 96, Color(color, 0.85 * (1.0 - t)), lerpf(16.0, 3.0, t), true)
		var spark_alpha := clampf(1.0 - _time / 3.5, 0.0, 1.0)
		if spark_alpha > 0.0:
			for spark in _sparks:
				draw_circle(spark[0], 4.0, Color(spark[2], spark_alpha))

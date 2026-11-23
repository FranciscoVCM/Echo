class_name ColorBloom
extends Node2D
## After K: the world blooms. Rainbow flower patches (every colour, not only C/M/Y/K) appear
## all over the Clareira, the Nascente and the three areas. How many depends on the
## "bloom level" (how many blobs were helped along the journey); helping more blobs after
## the ending raises the level and more flowers open.

## Patches shown per region at each level (index = level 0..4).
## Level 1 (under half the blobs) barely adds anything: the world simply has its four inks
## back. 2 and 3 are a clear step; 4 (every blob) is the big one.
const COUNTS := {
	"hub": [0, 3, 14, 19, 44],
	"clearing": [0, 0, 8, 11, 28],
	"area": [0, 0, 6, 9, 30],
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


## The ending's colour animation. Three different styles:
##   SOFT    (level 1)   - one slow pale ring and a few drifting motes; a single low note.
##   RAINBOW (levels 2-3) - the seven colours ring out from K, a fountain of sparks and an
##                          arpeggio (level 3: more rings, further, a fuller arpeggio).
##   GRAND   (level 4)   - a white flash, three waves of rainbow rings across the whole view,
##                          fireworks popping all around and the full scale ending in a chord.
class Burst:
	extends Node2D
	enum Style { SOFT, RAINBOW, GRAND }
	var level := 1
	var style: Style = Style.SOFT
	var _time := 0.0
	var _sparks: Array = []  # [position, velocity, colour, start time]
	var _rings: Array = []  # [start time, colour, reach, duration, width]
	var _fireworks: Array = []  # [start time, position, colour]
	var _flash := 0.0
	var _lifetime := 5.0
	var _rng := RandomNumberGenerator.new()

	static func spawn(at: Vector2, burst_level: int, tree: SceneTree) -> Node2D:
		var burst := Burst.new()
		burst.level = clampi(burst_level, 1, 4)
		burst.style = Style.SOFT if burst.level == 1 else (Style.GRAND if burst.level == 4 else Style.RAINBOW)
		var parent := tree.get_first_node_in_group("ping_wave_layer")
		if parent == null:
			parent = tree.current_scene
		parent.add_child(burst)
		burst.global_position = at
		return burst

	func _ready() -> void:
		_rng.randomize()
		match style:
			Style.SOFT:
				_rings.append([0.0, Color(0.85, 0.85, 0.9), 520.0, 4.5, 6.0])
				for index in range(24):
					var direction := Vector2.RIGHT.rotated(_rng.randf() * TAU)
					_add_spark(direction * _rng.randf_range(20.0, 120.0), direction * _rng.randf_range(15.0, 45.0) + Vector2(0, -20), Color(EchoNotes.color_for(_rng.randi() % 7), 0.55), _rng.randf() * 1.5)
				_play([[0.0, 0, -4.0]])
				_lifetime = 6.0
			Style.RAINBOW:
				var count := 7 if level == 2 else 10
				var reach := 900.0 if level == 2 else 1200.0
				for index in range(count):
					_rings.append([index * 0.18, EchoNotes.color_for(index % 7), reach, 3.0, 14.0])
				for index in range(110 if level == 2 else 170):
					var direction := Vector2.RIGHT.rotated(_rng.randf() * TAU)
					_add_spark(Vector2.ZERO, direction * _rng.randf_range(220.0, 420.0 if level == 2 else 520.0), EchoNotes.color_for(_rng.randi() % 7).lightened(0.15), 0.0)
				var notes := [[0.0, 0, 0.0], [0.22, 2, 0.0], [0.44, 4, 0.0]]
				if level == 3:
					notes.append([0.66, 7, 0.0])
				_play(notes)
				_lifetime = 5.5
			Style.GRAND:
				_flash = 1.0
				for wave in range(3):
					for index in range(7):
						_rings.append([wave * 1.2 + index * 0.12, EchoNotes.color_for(index), 2100.0, 3.4, 20.0])
				for index in range(260):
					var direction := Vector2.RIGHT.rotated(_rng.randf() * TAU)
					_add_spark(Vector2.ZERO, direction * _rng.randf_range(300.0, 820.0), EchoNotes.color_for(_rng.randi() % 7).lightened(0.2), 0.0)
				for index in range(18):
					var at := Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf_range(260.0, 950.0)
					var start := 0.8 + index * 0.24 + _rng.randf() * 0.2
					var color := EchoNotes.color_for(index % 7).lightened(0.15)
					_fireworks.append([start, at, color])
					for spark in range(26):
						_add_spark(at, Vector2.RIGHT.rotated(TAU * spark / 26.0) * _rng.randf_range(140.0, 240.0), color, start)
				var scale_notes := []
				for degree in range(7):
					scale_notes.append([degree * 0.14, degree, 0.0])
				for degree in [0, 2, 4, 7]:
					scale_notes.append([1.2, degree, -2.0])  # and the whole chord at once
				for index in range(9):
					scale_notes.append([1.9 + index * 0.45, [4, 6, 2, 5, 0, 3, 1, 4, 7][index], -4.0])  # fireworks
				_play(scale_notes)
				_lifetime = 8.5

	func _add_spark(at: Vector2, velocity: Vector2, color: Color, start: float) -> void:
		_sparks.append([at, velocity, color, start])

	func _play(notes: Array) -> void:
		for note in notes:
			var player := AudioStreamPlayer.new()
			player.stream = EchoNotes.voice_stream(note[1])
			player.volume_db = -6.0 + note[2]
			player.pitch_scale = 0.5 if style == Style.SOFT else 1.0
			add_child(player)
			if note[0] <= 0.0:
				player.play()
			else:
				get_tree().create_timer(note[0]).timeout.connect(player.play)

	func _process(delta: float) -> void:
		_time += delta
		_flash = move_toward(_flash, 0.0, delta * 1.2)
		var drag := 0.35 if style == Style.SOFT else 0.9
		for spark in _sparks:
			if _time < spark[3]:
				continue
			spark[0] += spark[1] * delta
			spark[1] *= 1.0 - delta * drag
		if _time > _lifetime:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		if _flash > 0.0:
			draw_circle(Vector2.ZERO, 3000.0, Color(1, 1, 1, 0.75 * _flash * _flash))
		for ring in _rings:
			var t: float = (_time - ring[0]) / ring[3]
			if t <= 0.0 or t >= 1.0:
				continue
			var eased := 1.0 - pow(1.0 - t, 2.0)
			draw_arc(Vector2.ZERO, ring[2] * eased, 0.0, TAU, 128, Color(ring[1], 0.85 * (1.0 - t)), lerpf(ring[4], 2.0, t), true)
		for firework in _fireworks:
			var t: float = (_time - firework[0]) / 1.2
			if t > 0.0 and t < 1.0:
				draw_circle(firework[1], 30.0 * (1.0 - t), Color(1, 1, 1, 0.8 * (1.0 - t)))
				draw_arc(firework[1], 30.0 + 150.0 * t, 0.0, TAU, 48, Color(firework[2], 0.8 * (1.0 - t)), 4.0, true)
		var spark_life := 5.0 if style == Style.SOFT else 3.0
		for spark in _sparks:
			var age: float = _time - spark[3]
			if age < 0.0:
				continue
			var alpha := clampf(1.0 - age / spark_life, 0.0, 1.0)
			if alpha > 0.0:
				var color: Color = spark[2]
				draw_circle(spark[0], 4.0 if style != Style.SOFT else 3.0, Color(color, color.a * alpha))

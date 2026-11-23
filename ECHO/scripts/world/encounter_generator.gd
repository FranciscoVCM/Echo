class_name EncounterGenerator
extends RefCounted
## PCG of blob encounters, following our A7 proposal:
## - the DESIGNER defines interaction patterns, rules and limits (POOLS + makers below);
## - the COMPUTER picks a pattern per site, varies notes/positions/obstacles/timing and
##   EVALUATES it (reachable, solvable with single notes, feasible timing, obstacle that
##   actually matters, not repeated too often) - rejected candidates are regenerated;
## - the PLAYER influences it indirectly: areas are generated on first visit, and chords
##   they already own make chord-friendly clusters (using those notes) more likely.
## Output specs are plain dictionaries (JSON-friendly) so they can be saved and replayed.

const PING_MAX_RANGE := 670.0
const PING_COOLDOWN := 2.0
const SOLUTION_RANGE := 470.0
const MAX_PER_PATTERN := 3

const POOLS := {
	"vista": {
		"hidden_note": 3.0, "hidden_shy": 2.0, "shy": 1.0, "same_wave_pair": 2.0,
		"same_wave_trio": 1.0, "cluster": 1.0, "stimulated": 1.0, "hidden_stimulated": 1.0,
		"window_trio": 1.5,
	},
	"som": {
		"note": 3.0, "shy": 2.0, "melody2": 1.5, "same_wave_pair": 2.0,
		"stimulated": 1.0, "cluster2": 1.0,
	},
	"tato": {
		"gentle": 3.0, "cautious": 2.0, "warmth": 2.0, "push": 2.0, "same_wave_pair": 1.0,
		"stimulated": 1.0, "gentle_shy": 1.0, "nervous": 2.0, "window_trio": 1.0,
	},
}

var geometry: WorldGeometry
var rng := RandomNumberGenerator.new()
## Pitch-class usage across the world, used to balance notes (so every chord is reachable).
var note_usage: Array[int] = [0, 0, 0, 0, 0, 0, 0]
## Pitch classes whose chord the player already owns (player influence).
var owned_chords: Array[int] = []
var rejected := 0

var _placed_points: Array[Vector2] = []
var _pattern_counts: Dictionary = {}
var _last_pattern := ""


func _init(world_geometry: WorldGeometry, seed_value: int) -> void:
	geometry = world_geometry
	rng.seed = seed_value


func generate_area(area: String, sites: Array) -> Array:
	_pattern_counts.clear()
	_last_pattern = ""
	var specs: Array = []
	for site_index in range(sites.size()):
		var site: Array = sites[site_index]
		var spec := {}
		for attempt in range(40):
			var pattern := _pick_pattern(area, site[1])
			var candidate := _make(area, pattern, site[0], site[1])
			if not candidate.is_empty() and _validate_common(candidate):
				spec = candidate
				break
			rejected += 1
		if spec.is_empty():
			spec = _fallback(area, site[0])
		spec["id"] = "%s:%d" % [area, site_index]
		for blob_index in range(spec["blobs"].size()):
			spec["blobs"][blob_index]["id"] = "%s:%d:%d" % [area, site_index, blob_index]
		_commit(spec)
		specs.append(spec)
	return specs


# --- Pattern choice ---------------------------------------------------------------------

func _pick_pattern(area: String, site_radius: float) -> String:
	var pool: Dictionary = POOLS[area]
	var weights := {}
	var total := 0.0
	for pattern in pool:
		var weight: float = pool[pattern]
		if pattern == _last_pattern or _pattern_counts.get(pattern, 0) >= MAX_PER_PATTERN:
			weight *= 0.05
		if site_radius < 120.0 and (pattern.begins_with("same_wave") or pattern.begins_with("cluster") or pattern.begins_with("window") or pattern == "push"):
			weight = 0.0  # small alcoves only get single blobs
		if (pattern.begins_with("cluster") or pattern.begins_with("window")) and not owned_chords.is_empty():
			weight *= 2.0  # player influence: chords they own become useful
		weights[pattern] = weight
		total += weight
	var roll := rng.randf() * total
	for pattern in weights:
		roll -= weights[pattern]
		if roll <= 0.0:
			return pattern
	return pool.keys()[0]


func _pick_note() -> int:
	# Least-used notes are strongly preferred, so every note (and its chord) appears often
	# enough to be unlockable (5 creatures of the same note).
	var least := 999
	for count in note_usage:
		least = mini(least, count)
	if rng.randf() < 0.75:
		var candidates: Array[int] = []
		for pc in range(7):
			if note_usage[pc] == least:
				candidates.append(pc)
		return candidates[rng.randi() % candidates.size()]
	var weights: Array[float] = []
	var total := 0.0
	var most := 0
	for count in note_usage:
		most = maxi(most, count)
	for pc in range(7):
		var weight := 1.0 + float(most - note_usage[pc]) * 1.5
		weights.append(weight)
		total += weight
	var roll := rng.randf() * total
	for pc in range(7):
		roll -= weights[pc]
		if roll <= 0.0:
			return pc
	return 0


# --- Makers -----------------------------------------------------------------------------

func _blob(pos: Vector2, note: int, need: String, extra: Dictionary = {}) -> Dictionary:
	var blob := {"pos": [pos.x, pos.y], "note": note, "need": need, "hits": 1, "hidden": false, "grey": false, "singer": false}
	for key in extra:
		blob[key] = extra[key]
	return blob


func _random_point(center: Vector2, radius: float, margin: float = 45.0) -> Vector2:
	for attempt in range(25):
		var angle := rng.randf() * TAU
		var point := center + Vector2.RIGHT.rotated(angle) * sqrt(rng.randf()) * radius
		if geometry.is_walkable(point, margin) and _far_from_placed(point, 110.0):
			return point
	return Vector2.INF


func _make(area: String, pattern: String, center: Vector2, radius: float) -> Dictionary:
	var spec := {"pattern": pattern, "area": area, "blobs": [], "group": "", "obstacles": []}
	var grey := area == "som"
	match pattern:
		"note", "hidden_note":
			var point := _random_point(center, radius)
			if point == Vector2.INF:
				return {}
			spec["blobs"].append(_blob(point, _pick_note(), "NOTE", {"hits": rng.randi_range(1, 2), "hidden": pattern == "hidden_note"}))
		"shy", "hidden_shy", "gentle_shy":
			var point := _random_point(center, radius)
			if point == Vector2.INF:
				return {}
			var silence := snappedf(rng.randf_range(4.0, 6.5), 0.5)
			spec["blobs"].append(_blob(point, _pick_note(), "SHY", {"hidden": pattern == "hidden_shy", "shy_silence": silence}))
		"stimulated", "hidden_stimulated":
			var point := _random_point(center, radius)
			if point == Vector2.INF:
				return {}
			var hits := rng.randi_range(3, 4)
			# Evaluation built in: the window always allows the hits with the ping cooldown.
			var window := snappedf(hits * PING_COOLDOWN + rng.randf_range(2.5, 4.0), 0.5)
			spec["blobs"].append(_blob(point, _pick_note(), "STIMULATED", {"hits": hits, "stim_window": window, "hidden": pattern == "hidden_stimulated"}))
		"gentle":
			var point := _random_point(center, radius)
			if point == Vector2.INF:
				return {}
			spec["blobs"].append(_blob(point, _pick_note(), "GENTLE", {"hits": 2}))
		"nervous":
			var point := _random_point(center, radius, 60.0)
			if point == Vector2.INF or not _has_flee_room(point):
				return {}
			spec["blobs"].append(_blob(point, _pick_note(), "NERVOUS"))
		"window_trio":
			return _make_window(spec, center, radius)
		"cautious":
			var point := _random_point(center, radius, 60.0)
			if point == Vector2.INF or not _has_flee_room(point):
				return {}
			spec["blobs"].append(_blob(point, _pick_note(), "CAUTIOUS"))
		"warmth":
			var point := _random_point(center, radius)
			if point == Vector2.INF:
				return {}
			spec["blobs"].append(_blob(point, _pick_note(), "WARMTH", {"warmth_duration": snappedf(rng.randf_range(3.5, 5.0), 0.5)}))
		"push":
			return _make_push(spec, center, radius)
		"melody2", "melody3":
			var point := _random_point(center, radius)
			if point == Vector2.INF:
				return {}
			var length := 2 if pattern == "melody2" else 3
			var melody: Array = [_pick_note()]
			while melody.size() < length:
				var next := rng.randi() % 7
				if next != melody[melody.size() - 1]:
					melody.append(next)
			spec["blobs"].append(_blob(point, melody[0], "MELODY", {"melody": melody}))
		"same_wave_pair", "same_wave_trio":
			return _make_same_wave(spec, center, radius, 2 if pattern == "same_wave_pair" else 3)
		"cluster", "cluster2":
			return _make_cluster(spec, center, radius, 3 if pattern == "cluster" else 2)
	if grey:
		for blob in spec["blobs"]:
			blob["grey"] = true
			blob["singer"] = true
	return spec


func _make_same_wave(spec: Dictionary, center: Vector2, radius: float, count: int) -> Dictionary:
	var rock_radius := rng.randf_range(42.0, 66.0)
	var rock_center := center + Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(0.0, radius * 0.3)
	if not geometry.is_walkable(rock_center, rock_radius + 50.0) or not _far_from_placed(rock_center, rock_radius + 70.0):
		return {}
	var rock_seed := rng.randi()
	var rock := WorldGeometry.noisy_ellipse(rock_center, rock_radius, rock_radius, 0.18, rock_seed, 16)
	var note := _pick_note()
	var base_angle := rng.randf() * TAU
	var members: Array[Vector2] = []
	for index in range(count):
		var spread := PI if count == 2 else TAU / 3.0
		var angle := base_angle + spread * index + rng.randf_range(-0.25, 0.25)
		var distance := rock_radius + rng.randf_range(85.0, 150.0)
		var point := rock_center + Vector2.RIGHT.rotated(angle) * distance
		if not geometry.is_walkable(point, 45.0) or not _far_from_placed(point, 110.0):
			return {}
		members.append(point)
	# Evaluation: there must be places where ONE wave reaches everyone, but the rock must
	# matter (many places must NOT work), otherwise it isn't a real situation to read.
	var valid: Array[Vector2] = []
	var total := 0
	var step := 40.0
	var extent := radius + 200.0
	var x := -extent
	while x <= extent:
		var y := -extent
		while y <= extent:
			var spot := rock_center + Vector2(x, y)
			y += step
			if spot.distance_to(rock_center) < rock_radius + 30.0 or not geometry.is_walkable(spot, 28.0):
				continue
			total += 1
			var ok := true
			for member in members:
				if spot.distance_to(member) > SOLUTION_RANGE or not geometry.has_line_of_sight(spot, member, [rock]):
					ok = false
					break
			if ok:
				valid.append(spot)
		x += step
	if valid.size() < 3 or total == 0 or float(valid.size()) / total > 0.6:
		return {}
	var best := valid[0]
	for spot in valid:
		if spot.distance_to(rock_center) < best.distance_to(rock_center):
			best = spot
	spec["group"] = "same_wave"
	spec["obstacles"].append({"pos": [rock_center.x, rock_center.y], "r": rock_radius, "seed": rock_seed})
	spec["solution"] = [best.x, best.y]
	for member in members:
		spec["blobs"].append(_blob(member, note, "NOTE"))
	if spec["area"] == "som":
		for blob in spec["blobs"]:
			blob["grey"] = true
			blob["singer"] = true
	return spec


func _make_cluster(spec: Dictionary, center: Vector2, radius: float, count: int) -> Dictionary:
	var notes: Array = []
	if not owned_chords.is_empty() and rng.randf() < 0.7:
		var root: int = owned_chords[rng.randi() % owned_chords.size()]
		notes = [root, posmod(root + 2, 7), posmod(root + 4, 7)].slice(0, count)
	else:
		var root := _pick_note()
		notes = [root, posmod(root + 2, 7), posmod(root + 4, 7)].slice(0, count)
	var anchor := _random_point(center, radius * 0.6, 90.0)
	if anchor == Vector2.INF:
		return {}
	var base_angle := rng.randf() * TAU
	for index in range(count):
		var point := anchor + Vector2.RIGHT.rotated(base_angle + TAU * index / count) * 62.0
		if not geometry.is_walkable(point, 40.0) or not _far_from_placed(point, 110.0):
			return {}
		spec["blobs"].append(_blob(point, notes[index], "NOTE"))
	spec["group"] = "cluster"
	if spec["area"] == "som":
		for blob in spec["blobs"]:
			blob["grey"] = true
			blob["singer"] = true
	return spec


## Three blobs of different colours (a triad, so the matching chord helps) that must all
## hear their note within a shared window. Evaluation: one spot sees all three, and the
## window always allows three single-note pings with the cooldown, plus slack.
func _make_window(spec: Dictionary, center: Vector2, radius: float) -> Dictionary:
	var root := _pick_note()
	if not owned_chords.is_empty() and rng.randf() < 0.6:
		root = owned_chords[rng.randi() % owned_chords.size()]
	var notes := [root, posmod(root + 2, 7), posmod(root + 4, 7)]
	var anchor := _random_point(center, radius * 0.5, 60.0)
	if anchor == Vector2.INF:
		return {}
	var base_angle := rng.randf() * TAU
	for index in range(3):
		var point := anchor + Vector2.RIGHT.rotated(base_angle + TAU * index / 3.0) * rng.randf_range(120.0, 170.0)
		if not geometry.is_walkable(point, 40.0) or not _far_from_placed(point, 110.0) or not geometry.has_line_of_sight(anchor, point):
			return {}
		spec["blobs"].append(_blob(point, notes[index], "NOTE"))
	spec["group"] = "window"
	spec["window"] = snappedf(3 * PING_COOLDOWN + rng.randf_range(6.0, 8.0), 0.5)
	spec["solution"] = [anchor.x, anchor.y]
	return spec


func _make_push(spec: Dictionary, center: Vector2, radius: float) -> Dictionary:
	var start := _random_point(center, radius * 0.5, 60.0)
	if start == Vector2.INF:
		return {}
	for attempt in range(12):
		var direction := Vector2.RIGHT.rotated(rng.randf() * TAU)
		var nest := start + direction * rng.randf_range(190.0, 290.0)
		var behind := start - direction * 75.0
		if not geometry.is_walkable(nest, 55.0) or not geometry.is_walkable(behind, 30.0):
			continue
		var side := direction.orthogonal() * 34.0
		if geometry.has_line_of_sight(start + side, nest + side) and geometry.has_line_of_sight(start - side, nest - side) and geometry.has_line_of_sight(start, nest):
			spec["blobs"].append(_blob(start, _pick_note(), "PUSH", {"nest": [nest.x, nest.y]}))
			return spec
	return {}


func _has_flee_room(point: Vector2) -> bool:
	var open := 0
	for index in range(8):
		if geometry.is_walkable(point + Vector2.RIGHT.rotated(TAU * index / 8.0) * 130.0, 35.0):
			open += 1
	return open >= 4


func _fallback(area: String, center: Vector2) -> Dictionary:
	var spec := {"pattern": "note", "area": area, "blobs": [], "group": "", "obstacles": []}
	spec["blobs"].append(_blob(center, _pick_note(), "NOTE", {"grey": area == "som", "singer": area == "som"}))
	return spec


# --- Evaluation -------------------------------------------------------------------------

func _validate_common(spec: Dictionary) -> bool:
	if spec["blobs"].is_empty():
		return false
	var points: Array[Vector2] = []
	for blob in spec["blobs"]:
		var point := Vector2(blob["pos"][0], blob["pos"][1])
		if not geometry.is_walkable(point, 38.0):
			return false
		for other in points:
			if other.distance_to(point) < 90.0 and spec["group"] != "cluster":
				return false
		points.append(point)
	# The player must be able to get near: a walkable spot with line of sight to each blob.
	for point in points:
		var reachable := false
		for index in range(12):
			var probe := point + Vector2.RIGHT.rotated(TAU * index / 12.0) * 120.0
			if geometry.is_walkable(probe, 26.0) and geometry.has_line_of_sight(probe, point):
				reachable = true
				break
		if not reachable:
			return false
	return true


func _far_from_placed(point: Vector2, distance: float) -> bool:
	for placed in _placed_points:
		if placed.distance_to(point) < distance:
			return false
	return true


func _commit(spec: Dictionary) -> void:
	for blob in spec["blobs"]:
		_placed_points.append(Vector2(blob["pos"][0], blob["pos"][1]))
		# Chords count creatures by their own note (a melody blob's note is its first note).
		note_usage[int(blob["note"])] += 1
	_pattern_counts[spec["pattern"]] = _pattern_counts.get(spec["pattern"], 0) + 1
	_last_pattern = spec["pattern"]

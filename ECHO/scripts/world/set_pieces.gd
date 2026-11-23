class_name SetPieces
extends RefCounted
## Hand-designed ADVANCED challenges (not PCG). Each combines things taught in the Clareira
## in a harder, more creative way, and the same templates come back in several areas with
## a different twist:
##   chorus      - three shy blobs of one colour around a rock. Wake them one by one and
##                 each new ping startles the ones already waking; wake them with ONE wave
##                 (find the spot) and then stay silent.
##   neighbours  - two blobs with opposite needs side by side (e.g. one wants several quick
##                 pings, the other silence). Order and where you stand matter.
##   lake        - creatures on lily pads: you can't get close, only call from the shore
##                 (charged pings; gentle ones still need soft pings from the right spot).
##   behind_current - a creature in an alcove guarded by a current: dash in... and if it
##                 is cautious, arriving at full speed scares it. Then come close slowly.
##   hidden_song - a hidden creature that sings a little melody you must answer.


static func for_area(area: String) -> Array:
	var specs := _authored(area)
	for spec in specs:
		for blob in spec["blobs"]:
			var at := WorldLayout.transform_point(area, Vector2(blob["pos"][0], blob["pos"][1]))
			blob["pos"] = [at.x, at.y]
	return specs


static func _authored(area: String) -> Array:
	match area:
		"vista":
			return [
				chorus("vista:sp:chorus", area, Vector2(-2980, -880), 150.0, 6, {"hidden": true}),
				lake("vista:sp:lake", area, [
					{"pos": [-3040, 860], "note": 1, "need": "STIMULATED", "hits": 3, "stim_window": 10.0, "hidden": true},
					{"pos": [-2900, 830], "note": 4, "need": "NOTE", "hits": 2, "hidden": true},
				]),
				_single("vista:sp:song", area, {"pos": [-2380, -990], "need": "MELODY", "note": 5, "melody": [5, 2, 0], "hidden": true}),
			]
		"som":
			return [
				neighbours("som:sp:neighbours", area, [
					{"pos": [-970, -2020], "note": 3, "need": "STIMULATED", "hits": 3, "stim_window": 10.0},
					{"pos": [-690, -2250], "note": 0, "need": "SHY", "shy_silence": 5.0},
				], {"grey": true, "singer": true}),
				chorus("som:sp:chorus", area, Vector2(820, -2120), 150.0, 5, {"grey": true, "singer": true}),
				lake("som:sp:lake", area, [
					{"pos": [500, -3070], "need": "SHY", "note": 4, "shy_silence": 5.0, "grey": true, "singer": true},
					{"pos": [630, -3040], "need": "STIMULATED", "note": 6, "hits": 3, "stim_window": 10.0, "grey": true, "singer": true},
				]),
			]
		"tato":
			return [
				_single("tato:sp:current", area, {"pos": [1990, -1090], "note": 2, "need": "CAUTIOUS"}),
				lake("tato:sp:lake", area, [
					{"pos": [3160, 820], "note": 6, "need": "GENTLE", "hits": 2},
				]),
				neighbours("tato:sp:neighbours", area, [
					{"pos": [3090, -760], "note": 4, "need": "WARMTH", "warmth_duration": 4.5},
					{"pos": [3260, -880], "note": 1, "need": "SHY", "shy_silence": 5.0},
				]),
			]
	return []


static func chorus(id: String, area: String, rock_center: Vector2, radius: float, note: int, extra: Dictionary) -> Dictionary:
	var blobs: Array = []
	for index in range(3):
		var angle := PI + TAU * index / 3.0
		var at := rock_center + Vector2.RIGHT.rotated(angle) * radius
		var blob := {"id": "%s:%d" % [id, index], "pos": [at.x, at.y], "note": note, "need": "SHY", "shy_silence": 5.0}
		blob.merge(extra)
		blobs.append(blob)
	return {"id": id, "area": area, "pattern": "chorus", "group": "together", "blobs": blobs}


static func lake(id: String, area: String, blobs: Array) -> Dictionary:
	var result: Array = []
	for index in range(blobs.size()):
		var blob: Dictionary = blobs[index].duplicate()
		blob["id"] = "%s:%d" % [id, index]
		blob["anchored"] = true
		result.append(blob)
	return {"id": id, "area": area, "pattern": "lake", "group": "", "blobs": result}


static func neighbours(id: String, area: String, blobs: Array, extra: Dictionary = {}) -> Dictionary:
	var result: Array = []
	for index in range(blobs.size()):
		var blob: Dictionary = blobs[index].duplicate()
		blob["id"] = "%s:%d" % [id, index]
		blob.merge(extra)
		result.append(blob)
	return {"id": id, "area": area, "pattern": "neighbours", "group": "", "blobs": result}


static func _single(id: String, area: String, data: Dictionary) -> Dictionary:
	var blob := data.duplicate()
	blob["id"] = id + ":0"
	return {"id": id, "area": area, "pattern": "single", "group": "", "blobs": [blob]}

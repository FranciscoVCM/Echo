extends Node
## Automated checks + a full scripted playthrough of the Echo world.
## Run (fast, no window):
##   Godot_v4.6.2-stable_win64_console.exe --headless --fixed-fps 60 --path . res://tests/world_tests.tscn
## Pings are real PingWaves (real wall blocking); the player is teleported and input is
## simulated through the same input actions the game uses.

const WORLD_SCENE := "res://scenes/world/game_world.tscn"

var game: Node
var world: GameWorld
var failures: Array[String] = []
var checks := 0


func _ready() -> void:
	game = get_node("/root/Game")
	_run.call_deferred()


func _run() -> void:
	var started := Time.get_ticks_msec()
	await _test_geometry_and_pcg()
	await _test_full_playthrough()
	print("\n%d checks, %d failures, %.1f s" % [checks, failures.size(), (Time.get_ticks_msec() - started) / 1000.0])
	if failures.is_empty():
		print("ALL WORLD TESTS PASSED")
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("  ok  " + message)
	else:
		failures.append(message)
		printerr("  !!  " + message)


func frames(count: int) -> void:
	for index in range(count):
		await get_tree().physics_frame


func wait(seconds: float) -> void:
	await frames(int(seconds * 60.0))


# --- Static checks ----------------------------------------------------------------------

func _test_geometry_and_pcg() -> void:
	print("Geometry")
	var geometry := WorldGeometry.new()
	add_child(geometry)
	var t0 := Time.get_ticks_msec()
	geometry.build(WorldLayout.regions())
	print("  build: %d ms, %d outer loops, %d holes, %d segments" % [Time.get_ticks_msec() - t0, geometry.outer_loops.size(), geometry.hole_loops.size(), geometry.segments.size()])
	check(geometry.outer_loops.size() == 1, "the whole world is one connected walkable space")
	for region in geometry.regions:
		for marker in region["markers"]:
			if marker.ends_with("gate"):
				continue
			check(geometry.is_walkable(region["markers"][marker], 25.0), "marker %s/%s is walkable" % [region["name"], marker])
		for site in region["sites"]:
			check(geometry.is_walkable(site[0], 30.0), "site %s %s is walkable" % [region["name"], site[0]])

	print("PCG (several seeds)")
	for seed_value in [1, 77, 2024, 31337, 9]:
		var generator := EncounterGenerator.new(geometry, seed_value)
		# The clearing already has Fá, Mi, Dó, Sol x2, Ré, Lá (as the game passes it in).
		var clearing_usage: Array[int] = [1, 1, 1, 1, 2, 1, 0]
		for pc in range(7):
			generator.note_usage[pc] = clearing_usage[pc]
		var all_specs := []
		var t1 := Time.get_ticks_msec()
		for area in ["vista", "som", "tato"]:
			var specs := generator.generate_area(area, geometry.region_data(area)["sites"])
			all_specs.append_array(specs)
			var blob_count := 0
			for spec in specs:
				blob_count += spec["blobs"].size()
			check(blob_count >= 12, "seed %d %s: %d blobs" % [seed_value, area, blob_count])
		var usage: Array[int] = clearing_usage.duplicate()
		for spec in all_specs:
			for blob in spec["blobs"]:
				usage[int(blob["note"])] += 1
				if spec.get("group", "") == "same_wave":
					var spot := Vector2(spec["solution"][0], spec["solution"][1])
					var rock: Dictionary = spec["obstacles"][0]
					var polygon := WorldGeometry.noisy_ellipse(Vector2(rock["pos"][0], rock["pos"][1]), rock["r"], rock["r"], 0.18, int(rock["seed"]), 16)
					var pos := Vector2(blob["pos"][0], blob["pos"][1])
					if not geometry.has_line_of_sight(spot, pos, [polygon]):
						check(false, "seed %d %s same-wave solution sees every member" % [seed_value, spec["id"]])
				if blob["need"] == "STIMULATED":
					if float(blob["stim_window"]) < int(blob["hits"]) * 2.0 + 1.5:
						check(false, "seed %d %s stimulated window is feasible" % [seed_value, spec["id"]])
		var min_usage := 99
		for count in usage:
			min_usage = mini(min_usage, count)
		check(min_usage >= 5, "seed %d: every note has >= 5 creatures in the world, so every chord is reachable (%s), %d rejected, %d ms" % [seed_value, usage, generator.rejected, Time.get_ticks_msec() - t1])
	geometry.queue_free()


# --- Playthrough ------------------------------------------------------------------------

func _load_world() -> void:
	game.test_mode = true
	game.new_progress(4242)
	var packed := load(WORLD_SCENE) as PackedScene
	world = packed.instantiate() as GameWorld
	add_child(world)
	await frames(5)


func ping_at(at: Vector2, note: int, charge: float = 0.4, chord: bool = false) -> void:
	var player := world.player
	player.global_position = at
	player.velocity = Vector2.ZERO
	await frames(3)
	world.emitter._select_ping_tone(note)
	world.emitter.chord_tone_indices = EchoNotes.triad_extras(note) if chord else PackedInt32Array()
	world.emitter.ping_cooldown_remaining = 0.0
	var wave_range := lerpf(world.emitter.minimum_ping_range, world.emitter.maximum_ping_range, charge)
	world.emitter.emit_ping(false, wave_range, charge)
	await wait(1.3)


## A walkable spot near `target` with line of sight to it.
func spot_near(target: Vector2, distance: float = 110.0) -> Vector2:
	for ring in [distance, distance * 0.7, distance * 1.4, distance * 2.0]:
		for index in range(16):
			var probe: Vector2 = target + Vector2.RIGHT.rotated(TAU * index / 16.0) * float(ring)
			if world.geometry.is_walkable(probe, 24.0) and world.geometry.has_line_of_sight(probe, target):
				return probe
	return target + Vector2(0, 60)


func away_from(target: Vector2) -> Vector2:
	return spot_near(target, 600.0)


func _test_full_playthrough() -> void:
	print("Playthrough: clearing")
	await _load_world()
	var clearing: Array = world._area_blobs["clearing"]
	check(clearing.size() == 7, "clearing has 7 blobs")
	for blob in clearing:
		await solve_blob(blob, [])
	check(game.progress["clearing_done"], "clearing completed, gate opens")
	await wait(2.0)
	check(world._clearing_gate == null or not is_instance_valid(world._clearing_gate) or world._clearing_gate.is_open(), "clearing gate is open")

	for area in ["vista", "som", "tato"]:
		print("Playthrough: " + area)
		world.player.global_position = world.geometry.region_data(area)["markers"]["entry"]
		await frames(4)
		var blobs: Array = world._area_blobs[area]
		check(blobs.size() >= 12, "%s generated %d blobs on entry" % [area, blobs.size()])
		var specs: Array = game.progress["area_specs"][area]
		for spec in specs:
			await solve_spec(spec, area)
		var freed := 0
		for blob in blobs:
			if blob.is_freed():
				freed += 1
			else:
				print("     unsolved: %s need=%d note=%d" % [blob.blob_id, blob.need, blob.note])
		check(freed == blobs.size(), "%s: all %d creatures helped by playing (%d)" % [area, blobs.size(), freed])
		await wait(0.5)
		var letter: String = game.AREA_VASSAL[area]
		check(world.vassals[letter].awake, "vassal %s woke up after the area was completed" % letter)
		await solve_vassal(letter)
		check(game.is_vassal_freed(letter), "vassal %s freed" % letter)

	print("Chords: %s" % [game.unlocked_chords()])
	check(game.unlocked_chords().size() >= 3, "several chords unlocked by playing (%d)" % game.unlocked_chords().size())

	print("Playthrough: K finale")
	await wait(1.0)
	check(world._sanctum_gate == null or not is_instance_valid(world._sanctum_gate) or world._sanctum_gate.is_open(), "sanctum gate opened after C, M, Y")
	world.player.global_position = Vector2(0, 150)
	await frames(10)
	check(world._final_stage == 1, "entering the sanctum starts K's challenge")
	for blob in world._final_fragments:
		await solve_blob(blob, [])
	await wait(2.0)
	check(world._final_stage == 2, "four fragments found -> K's song")
	await solve_melody_body(world.k_body)
	await wait(1.0)
	check(world._final_stage == 3, "song answered -> trio around pillars")
	var trio_spot := find_same_wave_spot(world._final_trio.members, 450.0)
	check(trio_spot != Vector2.INF, "there is a spot where one wave reaches the whole trio")
	await ping_at(trio_spot, 6, 0.8)
	await wait(0.5)
	check(world._final_stage == 4, "trio freed -> silence")
	world.player.global_position = Vector2(0, 250)
	await wait(7.0)
	check(game.is_vassal_freed("K"), "silence respected -> K freed, game complete")
	check(game.progress["ended"], "ending reached")
	var lines := ElderSpeech.lines(game.progress)
	check(lines.size() >= 8, "K's closing speech has %d lines" % lines.size())
	for line in lines:
		print("     K: " + str(line[1]))


func find_same_wave_spot(members: Array, max_range: float) -> Vector2:
	var center := Vector2.ZERO
	for member in members:
		center += member.global_position
	center /= members.size()
	var best := Vector2.INF
	for x in range(-500, 501, 30):
		for y in range(-500, 501, 30):
			var spot := center + Vector2(x, y)
			if not world.geometry.is_walkable(spot, 24.0):
				continue
			var ok := true
			for member in members:
				if spot.distance_to(member.global_position) > max_range or not world.geometry.has_line_of_sight(spot, member.global_position):
					ok = false
					break
			if ok and (best == Vector2.INF or spot.distance_to(center) < best.distance_to(center)):
				best = spot
	return best


func solve_spec(spec: Dictionary, area: String) -> void:
	var blobs: Array[EchoBlob] = []
	for data in spec["blobs"]:
		for blob in world._area_blobs[area]:
			if blob.blob_id == data["id"]:
				blobs.append(blob)
	if blobs.is_empty():
		return
	match spec.get("group", ""):
		"same_wave":
			var spot := Vector2(spec["solution"][0], spec["solution"][1])
			await ping_at(spot, blobs[0].note, 1.0)
		"cluster":
			for blob in blobs:
				await ping_at(spot_near(blob.global_position, 130.0), blob.note, 0.3)
		_:
			for blob in blobs:
				await solve_blob(blob, [])


func solve_blob(blob: EchoBlob, _context: Array) -> void:
	if blob.is_freed():
		return
	var at := spot_near(blob.global_position, 110.0)
	match blob.need:
		EchoBlob.Need.NOTE:
			if blob.group != null:
				var spot := find_same_wave_spot(blob.group.members, 450.0)
				await ping_at(spot, blob.note, 1.0)
			else:
				for index in range(blob.required_hits):
					await ping_at(at, blob.note, 0.3)
					await wait(0.8)
		EchoBlob.Need.SHY:
			await ping_at(at, blob.note, 0.3)
			world.player.global_position = away_from(blob.global_position)
			await wait(blob.shy_silence + 0.8)
		EchoBlob.Need.STIMULATED:
			for index in range(blob.required_hits):
				await ping_at(at, blob.note, 0.3)
				await wait(0.75)
		EchoBlob.Need.GENTLE:
			for index in range(blob.required_hits):
				await ping_at(at, blob.note, 0.15)
				await wait(0.8)
		EchoBlob.Need.CAUTIOUS:
			# Arrive slowly: teleport next to it with no velocity, then ping.
			await ping_at(spot_near(blob.global_position, 90.0), blob.note, 0.2)
		EchoBlob.Need.WARMTH:
			world.player.global_position = spot_near(blob.global_position, 70.0)
			world.player.velocity = Vector2.ZERO
			await wait(blob.warmth_duration + 0.5)
			await ping_at(spot_near(blob.global_position, 70.0), blob.note, 0.2)
		EchoBlob.Need.MELODY:
			for degree in blob.melody:
				await ping_at(at, degree, 0.3)
				await wait(0.3)
		EchoBlob.Need.PUSH:
			await push_home(blob)
	await wait(0.3)
	if not blob.is_freed():
		print("     (retry %s need=%d)" % [blob.blob_id, blob.need])


func push_home(blob: EchoBlob) -> void:
	for attempt in range(8):
		if blob.is_freed():
			return
		var direction := (blob.nest_position - blob.global_position).normalized()
		world.player.global_position = blob.global_position - direction * 70.0
		world.player.velocity = Vector2.ZERO
		await frames(2)
		_press_direction(direction)
		await wait(1.2)
		_release_direction()
		await frames(10)


func _press_direction(direction: Vector2) -> void:
	_release_direction()
	if direction.x > 0.05:
		Input.action_press("echo_right", direction.x)
	elif direction.x < -0.05:
		Input.action_press("echo_left", -direction.x)
	if direction.y > 0.05:
		Input.action_press("echo_down", direction.y)
	elif direction.y < -0.05:
		Input.action_press("echo_up", -direction.y)


func _release_direction() -> void:
	for action in ["echo_left", "echo_right", "echo_up", "echo_down"]:
		Input.action_release(action)


func solve_melody_body(body: VassalBody) -> void:
	var at := spot_near(body.global_position, 150.0)
	for degree in body.melody:
		await ping_at(at, degree, 0.3)
		await wait(0.2)


func solve_vassal(letter: String) -> void:
	var vassal: VassalBody = world.vassals[letter]
	match letter:
		"Y":
			var y := vassal as VassalY
			for index in range(3):
				var markers: Dictionary = world.geometry.region_data("vista")["markers"]
				var spark_pos: Vector2 = markers["spark_%d" % index]
				await ping_at(spot_near(spark_pos, 100.0), VassalY.SPARK_NOTES[index], 0.3)
			await wait(2.0)
			check(y.sparks_returned == 3, "Y: three sparks returned (%d)" % y.sparks_returned)
			check(y.mode == VassalBody.Mode.NOTE, "Y waits for its colour")
			await ping_at(spot_near(y.global_position, 160.0), 1, 0.4)
			check(not y.completed, "Y: wrong note does not free it")
			await ping_at(spot_near(y.global_position, 160.0), 2, 0.4)
		"C":
			var c := vassal as VassalC
			check(c.stones.size() == 3, "C: three echo stones")
			await ping_at(spot_near(c.global_position, 150.0), 6, 0.3)
			check(c.melody_step == 0, "C: a wrong first note keeps the song at the start")
			await solve_melody_body(c)
		"M":
			var m := vassal as VassalM
			# Rushing in raises tension (simulated with real input).
			world.player.global_position = m.global_position + Vector2(-380, 0)
			await frames(3)
			_press_direction(Vector2.RIGHT)
			await wait(0.9)
			_release_direction()
			check(m.tension > 0.2 or m._rolling_to != Vector2.INF, "M: rushing towards it makes it tense (%.2f)" % m.tension)
			await wait(3.0)
			world.player.global_position = spot_near(m.global_position, 95.0)
			world.player.velocity = Vector2.ZERO
			await wait(5.8)
			check(m.mode == VassalBody.Mode.SOFT, "M: staying close calmly warms it up")
			await ping_at(spot_near(m.global_position, 95.0), 0, 0.2)
	await wait(1.0)

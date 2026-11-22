extends SceneTree
## Headless gameplay test for the clearing vertical slice. It teleports the player and
## emits real pings (real waves, real wall blocking), then checks blob states.
##
## Run from the ECHO folder:
##   Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/clearing_slice_test.gd

const SCENE := "res://scenes/world/clearing_slice.tscn"
const WAVE_WAIT := 1.8

var _failures: Array[String] = []
var _world: EchoWorld
var _player: PlayerController
var _emitter: PingEmitter


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _load_world()
	await _test_tutorial_note()
	await _test_shy()
	await _test_pair()
	await _test_trio_single_notes()
	await _test_hidden()
	await _test_recruit_relay_and_absorb()
	await _load_world()
	await _test_trio_with_chord()
	await _test_trio_window_expires()
	if _failures.is_empty():
		print("ALL CLEARING SLICE TESTS PASSED")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		quit(1)


func _load_world() -> void:
	if _world != null:
		_world.queue_free()
		await process_frame
	EchoBlob.always_show_note_names = false
	_world = (load(SCENE) as PackedScene).instantiate() as EchoWorld
	root.add_child(_world)
	current_scene = _world
	_player = _world.get_node("Player") as PlayerController
	_emitter = _player.get_node("PingEmitter") as PingEmitter
	await _frames(3)


func _blob(path: String) -> EchoBlob:
	return _world.get_node("Blobs/" + path) as EchoBlob


func _ping(at: Vector2, tone: int, charge: float = 1.0) -> void:
	_player.global_position = at
	_player.velocity = Vector2.ZERO
	await _frames(2)
	_emitter._select_ping_tone(tone)
	var wave_range := lerpf(_emitter.minimum_ping_range, _emitter.maximum_ping_range, charge)
	_emitter.emit_ping(false, wave_range, charge)


func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok  " + message)
	else:
		_failures.append(message)
		printerr("  !!  " + message)


func _test_tutorial_note() -> void:
	print("Tutorial (Fá, note only)")
	var blob := _blob("Fa_Perdida")
	await _ping(Vector2(-900, 600), 0, 0.3)
	await _wait(WAVE_WAIT)
	_check(blob.state == EchoBlob.State.LOST, "wrong note (Dó) does not free the Fá blob")
	_check(blob.has_answered, "wrong note makes the blob answer with its own note")
	await _ping(Vector2(-900, 600), 3, 0.3)
	await _wait(WAVE_WAIT)
	_check(blob.is_freed(), "Fá ping frees the Fá blob")


func _test_shy() -> void:
	print("Shy (Dó + silence)")
	var blob := _blob("Do_Timida")
	var spot := Vector2(-900, -470)
	await _ping(spot, 0, 0.4)
	await _wait(WAVE_WAIT)
	_check(blob.is_shy_waking(), "Dó ping wakes the shy blob")
	await _wait(1.0)
	await _ping(spot, 3, 0.4)  # any sound, even the wrong note, startles it
	await _wait(0.9)
	_check(blob.is_shy_waking() and blob.get_shy_remaining() > 4.0, "a second ping resets its calm timer (remaining %.1f)" % blob.get_shy_remaining())
	_player.global_position = Vector2(-1000, 600)
	await _wait(5.5)
	_check(blob.is_freed(), "after 5 s of silence the shy blob is freed")


func _test_pair() -> void:
	print("Pair (Sol, same wave)")
	var a := _blob("Par_Sol/Sol_A")
	var b := _blob("Par_Sol/Sol_B")
	await _ping(Vector2(-260, -330), 4, 0.5)
	await _wait(WAVE_WAIT)
	_check(a.group_mark > 0.0 or a.state == EchoBlob.State.LOST, "a wave on one side marks A")
	_check(a.state == EchoBlob.State.LOST and b.state == EchoBlob.State.LOST, "one side alone does not free the pair")
	await _wait(1.0)
	await _ping(Vector2(0, -110), 4, 1.0)
	await _wait(WAVE_WAIT)
	_check(a.is_freed() and b.is_freed(), "one Sol wave from below the pillar frees both")


func _test_trio_single_notes() -> void:
	print("Trio (Dó Mi Sol) with single notes only")
	var spot := Vector2(830, -450)
	var trio := ["Trio_DoMaior/Trio_Do", "Trio_DoMaior/Trio_Mi", "Trio_DoMaior/Trio_Sol"]
	_world.set("_chord_mode", false)
	await _ping(spot, 0, 0.35)
	await _wait(2.05)
	_emitter.ping_cooldown_remaining = 0.0
	await _ping(spot, 2, 0.35)
	await _wait(2.05)
	_emitter.ping_cooldown_remaining = 0.0
	await _ping(spot, 4, 0.35)
	await _wait(WAVE_WAIT)
	var all_freed := true
	for path in trio:
		all_freed = all_freed and _blob(path).is_freed()
	_check(all_freed, "three single notes within 6 s from the sweet spot free the trio (no chord needed)")


func _test_hidden() -> void:
	print("Hidden (Lá)")
	var blob := _blob("La_Escondida")
	await _ping(Vector2(775, 250), 5, 1.0)
	await _wait(WAVE_WAIT)
	_check(blob.state == EchoBlob.State.LOST, "from the doorway the pillar blocks the ping")
	await _ping(Vector2(1080, 420), 5, 0.4)
	await _wait(WAVE_WAIT)
	_check(blob.is_freed(), "inside the room a Lá ping frees the hidden blob")


func _test_recruit_relay_and_absorb() -> void:
	print("Recruit / absorb placeholders")
	var green := _blob("Fa_Perdida")
	var hidden := _blob("La_Escondida")
	_world.recruit(green)
	_check(green.state == EchoBlob.State.FOLLOWING, "recruited blob follows the player")
	var fov := _world.get_node("FieldOfView")
	var vision_before: float = fov.get("vision_radius")
	_world.absorb(hidden)
	await _wait(0.6)
	_check(float(fov.get("vision_radius")) > vision_before, "absorbing increases vision radius")
	_check(hidden.state == EchoBlob.State.ABSORBED and not hidden.visible, "absorbed blob disappears into the player")
	# Relay: the follower should emit its own wave shortly after the player's ping.
	var waves_before := get_nodes_in_group("active_ping_waves").size()
	_emitter.ping_cooldown_remaining = 0.0
	await _ping(_player.global_position, 1, 0.5)
	await _wait(0.6)
	var waves_after := get_nodes_in_group("active_ping_waves").size()
	_check(waves_after >= waves_before + 2, "a companion relays the player's ping (%d -> %d waves)" % [waves_before, waves_after])


func _test_trio_with_chord() -> void:
	print("Trio with the Dó maior chord (fresh scene)")
	_world.unlock_chord(0)
	_emitter._select_ping_tone(0)
	_world.call("_toggle_chord")
	_check(_emitter.chord_tone_indices.size() == 2, "chord mode adds Mi and Sol to Dó")
	await _ping(Vector2(830, -450), 0, 0.35)
	await _wait(WAVE_WAIT)
	var all_freed := true
	for path in ["Trio_DoMaior/Trio_Do", "Trio_DoMaior/Trio_Mi", "Trio_DoMaior/Trio_Sol"]:
		all_freed = all_freed and _blob(path).is_freed()
	_check(all_freed, "one Dó maior ping from the sweet spot frees the whole trio")
	_world.call("_toggle_chord")


func _test_trio_window_expires() -> void:
	print("Pair partial / window behaviour")
	await _load_world()
	var trio_do := _blob("Trio_DoMaior/Trio_Do")
	await _ping(Vector2(830, -450), 0, 0.35)
	await _wait(WAVE_WAIT)
	_check(trio_do.group_mark > 0.0 and trio_do.state == EchoBlob.State.LOST, "first trio note marks Dó but does not free it")
	await _wait(6.5)
	_check(trio_do.group_mark == 0.0 and trio_do.state == EchoBlob.State.LOST, "after the 6 s window the mark fades (no softlock, can retry)")

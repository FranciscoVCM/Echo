extends SceneTree
## Dev tool: walks the player through the clearing, pings, and saves screenshots.
## Needs a window (NOT --headless):
##   Godot_v4.6.2-stable_win64_console.exe --path . --script res://tests/capture_tour.gd -- <output_dir>

var _world: EchoWorld
var _player: PlayerController
var _emitter: PingEmitter
var _out := "user://captures"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	_world = (load("res://scenes/world/clearing_slice.tscn") as PackedScene).instantiate() as EchoWorld
	root.add_child(_world)
	current_scene = _world
	_player = _world.get_node("Player") as PlayerController
	_emitter = _player.get_node("PingEmitter") as PingEmitter
	await _wait(1.0)
	await _shot("01_start")
	await _ping(Vector2(-900, 600), 0, 0.3, 0.5)
	await _shot("02_wrong_note_answer")
	await _wait(1.5)
	await _ping(Vector2(-900, 600), 3, 0.3, 1.2)
	await _shot("03_freed_choice")
	await _ping(Vector2(-900, -470), 0, 0.4, 1.6)
	await _shot("04_shy_waking")
	await _move(Vector2(-150, -150))
	await _ping(Vector2(-150, -150), 4, 1.0, 0.7)
	await _shot("05_pair_wave")
	await _wait(1.5)
	await _move(Vector2(830, -450))
	_world.unlock_chord(0)
	_emitter._select_ping_tone(0)
	_world.call("_toggle_chord")
	await _wait(0.3)
	await _ping(Vector2(830, -450), 0, 0.35, 0.45)
	await _shot("06_chord_wave")
	await _wait(2.0)
	await _shot("07_trio_freed")
	await _move(Vector2(780, 250))
	await _ping(Vector2(780, 250), 5, 1.0, 0.8)
	await _shot("08_dark_room_echo")
	quit(0)


func _move(to: Vector2) -> void:
	_player.global_position = to
	_player.velocity = Vector2.ZERO
	await _wait(0.6)


func _ping(at: Vector2, tone: int, charge: float, wait_after: float) -> void:
	_player.global_position = at
	await _wait(0.2)
	_emitter._select_ping_tone(tone)
	_emitter.ping_cooldown_remaining = 0.0
	_emitter.emit_ping(false, lerpf(_emitter.minimum_ping_range, _emitter.maximum_ping_range, charge), charge)
	await _wait(wait_after)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	image.save_png(_out.path_join(name + ".png"))
	print("saved ", name)

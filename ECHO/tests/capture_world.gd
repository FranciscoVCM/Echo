extends Node
## Dev tool: screenshots of each region (needs a window, NOT --headless):
##   Godot_v4.6.2-stable_win64_console.exe --path . res://tests/capture_world.tscn -- <output_dir>

var game: Node
var world: GameWorld
var out_dir := "user://captures"


func _ready() -> void:
	game = get_node("/root/Game")
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	game.test_mode = true
	game.new_progress(4242)
	world = (load("res://scenes/world/game_world.tscn") as PackedScene).instantiate() as GameWorld
	add_child(world)
	await _wait(1.5)
	await _shot("01_clearing_start")
	while world.dialogue.is_busy():
		world.dialogue._finish_line()
	await _wait(1.0)
	await _shot("01b_guide_light")
	world.player.global_position = Vector2(-330, 1720)
	await _wait(1.2)
	await _shot("01c_on_the_light")
	while world.dialogue.is_busy():
		world.dialogue._finish_line()
	await _goto(Vector2(-60, 1690))
	await _ping(2, 0.6)
	await _wait(0.6)
	await _shot("02_clearing_pond")
	await _goto(Vector2(60, 1880))
	await _wait(0.4)
	await _shot("02b_clearing_current")
	await _goto(Vector2(600, 1560))
	await _ping(4, 0.9)
	await _wait(0.4)
	await _shot("03_clearing_pair")
	game.progress["clearing_done"] = true
	await _goto(Vector2(0, 450))
	await _wait(1.0)
	await _shot("04_hub")
	await _goto(world.geometry.region_data("vista")["markers"]["entry"] + Vector2(-350, 0))
	await _wait(1.5)
	await _ping(2, 1.0)
	await _wait(0.5)
	await _shot("05_vista_dark_ping")
	await _goto(Vector2(0, -1600))
	await _wait(1.5)
	await _shot("06_som")
	await _goto(Vector2(-820, -2120))
	await _wait(1.0)
	await _shot("07_som_amphitheatre")
	await _goto(Vector2(3160, 640))
	await _wait(1.5)
	await _shot("08_tato_lake")
	await _goto(Vector2(2700, 0))
	await _wait(1.0)
	await _shot("09_tato_heart")
	# Colour restoration preview: C and M restored.
	game.progress["vassals"]["C"] = true
	game.progress["vassals"]["M"] = true
	world._update_grading(false)
	await _wait(0.5)
	await _shot("10_tato_restored_cm")
	get_tree().quit()


func _goto(at: Vector2) -> void:
	world.player.global_position = at
	world.player.velocity = Vector2.ZERO
	await _wait(0.8)
	# Walk around a little so the fog has to recompute (realistic load).
	Input.action_press("echo_right")
	await _wait(0.6)
	Input.action_release("echo_right")


func _ping(note: int, charge: float) -> void:
	world.emitter._select_ping_tone(note)
	world.emitter.ping_cooldown_remaining = 0.0
	world.emitter.emit_ping(false, lerpf(world.emitter.minimum_ping_range, world.emitter.maximum_ping_range, charge), charge)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("saved %s  (%d fps, %.1f ms physics)" % [name, Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])

extends Node
## Dev tool: screenshots of vassal states, full-area colour and the ending bloom levels.
##   Godot_v4.6.2-stable_win64_console.exe --path . res://tests/capture_colour.tscn -- <output_dir>

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
	await _wait(1.0)
	world.debug_finish_clearing()
	world.generate_area("tato")
	var m: VassalBody = world.vassals["M"]
	await _goto(m.global_position + Vector2(0, 230))
	_skip()
	await _shot("c01_vassal_asleep")
	m.wake()
	await _wait(1.2)
	_skip()
	await _shot("c02_vassal_awake")
	world.debug_clear_area("tato", false)
	await _goto(m.global_position + Vector2(0, 230))
	await _wait(4.0)
	_skip()
	await _shot("c03_vassal_freed_normal")
	world.debug_clear_area("tato", true)
	await _goto(m.global_position + Vector2(0, 230))
	await _wait(4.5)
	_skip()
	await _shot("c04_tato_full")
	for level in [1, 4]:
		world.debug_ending(level)
		await _wait(2.4)
		await _shot("c1%d_ending_burst_level%d" % [level, level])
		await _wait(4.0)
		_skip()
		world.resume_after_ending()
		await _goto(Vector2(-250, 420))
		await _wait(0.6)
		_skip()
		await _shot("c1%d_nascente_level%d" % [level, level])
		await _goto(world.geometry.region_data("clearing")["markers"]["start"])
		_skip()
		await _shot("c1%d_clareira_level%d" % [level, level])
		await _goto(world.geometry.region_data("som")["markers"]["entry"] + Vector2(-300, 0))
		_skip()
		await _shot("c1%d_vale_level%d" % [level, level])
	get_tree().quit()


func _skip() -> void:
	world.dialogue.clear()
	for child in world.get_children():
		if child is CanvasLayer and child.get_script() == GameWorld.ENDING_SCRIPT:
			child.queue_free()


func _goto(at: Vector2) -> void:
	world.player.global_position = at
	world.player.velocity = Vector2.ZERO
	await _wait(1.0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("saved %s  (%d fps)" % [name, Engine.get_frames_per_second()])

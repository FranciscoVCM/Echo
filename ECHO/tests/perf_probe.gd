extends Node
## Dev tool: average frame cost while walking in a few places (needs a window).

var game: Node
var world: GameWorld


func _ready() -> void:
	game = get_node("/root/Game")
	_run.call_deferred()


func _run() -> void:
	game.test_mode = true
	game.new_progress(4242)
	game.progress["clearing_done"] = true
	world = (load("res://scenes/world/game_world.tscn") as PackedScene).instantiate() as GameWorld
	add_child(world)
	await get_tree().create_timer(1.0).timeout
	for spot in [["clearing", Vector2(-60, 1690)], ["hub", Vector2(0, 450)], ["tato", Vector2(2700, 0)], ["vista", Vector2(-2800, 300)]]:
		world.player.global_position = spot[1]
		await get_tree().create_timer(0.5).timeout
		var frames := 0
		var process_total := 0.0
		var physics_total := 0.0
		var start := Time.get_ticks_usec()
		Input.action_press("echo_right")
		while Time.get_ticks_usec() - start < 2500000:
			await get_tree().process_frame
			frames += 1
			process_total += Performance.get_monitor(Performance.TIME_PROCESS)
			physics_total += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		Input.action_release("echo_right")
		var seconds := (Time.get_ticks_usec() - start) / 1000000.0
		print("%-9s %5.0f fps   process %.2f ms   physics %.2f ms   blobs %d" % [spot[0], frames / seconds, process_total / frames * 1000.0, physics_total / frames * 1000.0, get_tree().get_nodes_in_group("echo_blobs").size()])
	get_tree().quit()

extends Node
## Smoke test for menus: title, options (incl. a rebind), test skip into the world, pause.

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := get_node("/root/Game")
	var title := (load("res://scenes/ui/title_screen.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(title)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = title  # so changing scene frees the title, not this test
	var options := OptionsMenu.new()
	add_child(options)
	await get_tree().process_frame
	options._start_rebind("echo_chord")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_R
	event.pressed = true
	options._input(event)
	print("rebind chord -> ", game.key_label("echo_chord"), " ok=", game.key_for("echo_chord") == KEY_R)
	game.reset_bindings()
	print("reset -> ", game.key_label("echo_chord"))
	options._close()
	title._test_skip_clearing()
	await get_tree().create_timer(1.0).timeout
	var world := get_tree().current_scene
	print("scene after skip: ", world.name, " clearing_done=", game.progress["clearing_done"], " test_mode=", game.test_mode)
	world._pause_menu.open()
	await get_tree().process_frame
	print("paused=", get_tree().paused)
	world._pause_menu.close()
	print("paused after close=", get_tree().paused)
	world.debug_wake_vassal("C")
	await get_tree().create_timer(0.5).timeout
	print("debug wake C -> awake=", world.vassals["C"].awake, " stones=", world.vassals["C"].stones.size())
	world.debug_go_final()
	await get_tree().create_timer(0.5).timeout
	print("debug go final -> CMY freed=", game.cmy_freed_count(), " chords=", game.unlocked_chords().size())
	print("UI SMOKE DONE")
	get_tree().quit()

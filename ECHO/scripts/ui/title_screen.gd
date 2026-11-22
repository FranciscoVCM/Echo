extends Control
## Title screen: new game, continue, options, test shortcuts, quit.

const WORLD_SCENE := "res://scenes/world/game_world.tscn"
const ARENA_SCENE := "res://scenes/interaction_test_arena.tscn"

var _time := 0.0
var _blobs: Array = []  # [position, velocity, colour, radius]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for index in range(14):
		_blobs.append([
			Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 720)),
			Vector2(rng.randf_range(-20, 20), rng.randf_range(-14, 14)),
			EchoNotes.color_for(index % 7), rng.randf_range(10, 26),
		])
	var game := get_node("/root/Game")
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.position = Vector2(-160, -150)
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	var title := UiStyle.title("ECHO", 84)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_y", 4)
	column.add_child(title)
	var subtitle := UiStyle.title("um jogo sobre ouvir", 18)
	subtitle.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	column.add_child(subtitle)
	column.add_child(Control.new())
	if game.has_save():
		var continue_button := UiStyle.button("Continuar")
		continue_button.pressed.connect(_continue)
		column.add_child(continue_button)
	var new_button := UiStyle.button("Novo jogo")
	new_button.pressed.connect(_new_game)
	column.add_child(new_button)
	var options := UiStyle.button("Opções")
	options.pressed.connect(func() -> void: add_child(OptionsMenu.new()))
	column.add_child(options)
	var quit := UiStyle.button("Sair")
	quit.pressed.connect(func() -> void: get_tree().quit())
	column.add_child(quit)
	(column.get_child(3) as Button).grab_focus.call_deferred()

	# TEST shortcuts (will not exist in the final game).
	var test_box := VBoxContainer.new()
	test_box.anchor_left = 1.0
	test_box.anchor_right = 1.0
	test_box.anchor_top = 1.0
	test_box.anchor_bottom = 1.0
	test_box.offset_left = -300.0
	test_box.offset_top = -120.0
	test_box.offset_right = -16.0
	test_box.offset_bottom = -16.0
	add_child(test_box)
	var test_label := Label.new()
	test_label.text = "TESTE (não fica no jogo final)"
	test_label.add_theme_font_size_override("font_size", 12)
	test_label.add_theme_color_override("font_color", Color(1, 0.7, 0.4, 0.8))
	test_box.add_child(test_label)
	var skip := Button.new()
	skip.text = "Saltar a Clareira"
	skip.pressed.connect(_test_skip_clearing)
	test_box.add_child(skip)
	var arena := Button.new()
	arena.text = "Laboratório original (arena)"
	arena.pressed.connect(func() -> void: get_tree().change_scene_to_file(ARENA_SCENE))
	test_box.add_child(arena)


func _new_game() -> void:
	var game := get_node("/root/Game")
	game.test_mode = false
	game.delete_save()
	game.new_progress()
	game.save_game()
	get_tree().change_scene_to_file(WORLD_SCENE)


func _continue() -> void:
	var game := get_node("/root/Game")
	game.test_mode = false
	if game.load_game():
		get_tree().change_scene_to_file(WORLD_SCENE)


func _test_skip_clearing() -> void:
	var game := get_node("/root/Game")
	game.new_progress()
	game.test_mode = true
	game.progress["clearing_done"] = true
	for key in ["intro", "first_ping", "clearing_done"]:
		game.mark_dialogue(key)
	get_tree().change_scene_to_file(WORLD_SCENE)


func _process(delta: float) -> void:
	_time += delta
	for blob in _blobs:
		blob[0] += blob[1] * delta
		blob[0].x = fposmod(blob[0].x, size.x + 60.0)
		blob[0].y = fposmod(blob[0].y, size.y + 60.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.04, 0.055))
	for blob in _blobs:
		var center: Vector2 = blob[0] - Vector2(30, 30)
		var radius: float = blob[3]
		var color: Color = blob[2]
		var pulse := fposmod(_time * 0.3 + radius, 3.0) / 3.0
		draw_arc(center, radius * (1.5 + pulse * 3.0), 0.0, TAU, 40, Color(color, 0.25 * (1.0 - pulse)), 1.5, true)
		draw_circle(center, radius, Color(color, 0.55))

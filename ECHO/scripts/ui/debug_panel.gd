extends CanvasLayer
## DEBUG panel (F8, in game). For testing only; remove or hide for the final build.

var world: Node
var _root: PanelContainer


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = PanelContainer.new()
	_root.position = Vector2(16, 60)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.05, 0.02, 0.92)
	style.border_color = Color(1.0, 0.6, 0.3, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	_root.add_theme_stylebox_override("panel", style)
	_root.visible = false
	add_child(_root)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_root.add_child(column)
	var title := Label.new()
	title.text = "DEBUG (F8)  — só para testes"
	title.add_theme_color_override("font_color", Color(1, 0.75, 0.45))
	column.add_child(title)
	_section(column, "Ir para")
	var travel := GridContainer.new()
	travel.columns = 3
	column.add_child(travel)
	for entry in [["Clareira", "clearing", "start"], ["Nascente", "hub", "test_start"], ["Grutas", "vista", "entry"],
			["Vale", "som", "entry"], ["Bosque", "tato", "entry"], ["Santuário", "hub", "center"],
			["Vassalo Y", "vista", "vassal"], ["Vassalo C", "som", "vassal"], ["Vassalo M", "tato", "vassal"]]:
		_button(travel, entry[0], Callable(world, "debug_teleport").bind(entry[1], entry[2]))
	_section(column, "Desafios")
	var wake := HBoxContainer.new()
	column.add_child(wake)
	for letter in ["Y", "C", "M"]:
		_button(wake, "Acordar " + letter, Callable(world, "debug_wake_vassal").bind(letter))
	var free := HBoxContainer.new()
	column.add_child(free)
	for letter in ["Y", "C", "M"]:
		_button(free, "Libertar " + letter, Callable(world, "debug_free_vassal").bind(letter))
	_button(column, "Ajudar o necessário na área atual", Callable(world, "debug_free_current_area"))
	_section(column, "Áreas (vassalo libertado)  ·  normal = o mínimo, completa = todas as blobs")
	var areas := GridContainer.new()
	areas.columns = 3
	column.add_child(areas)
	for entry in [["Grutas", "vista"], ["Vale", "som"], ["Bosque", "tato"]]:
		_button(areas, entry[0] + " normal", Callable(world, "debug_clear_area").bind(entry[1], false))
	for entry in [["Grutas", "vista"], ["Vale", "som"], ["Bosque", "tato"]]:
		_button(areas, entry[0] + " completa", Callable(world, "debug_clear_area").bind(entry[1], true))
	_button(column, "Terminar a Clareira", Callable(world, "debug_finish_clearing"))
	_button(column, "Dar todos os acordes", Callable(world, "debug_grant_chords"))
	_button(column, "Ir para o desafio final (K)", Callable(world, "debug_go_final"))
	_section(column, "Final: explosão de cor por nível (blobs ajudadas)")
	var endings := HBoxContainer.new()
	column.add_child(endings)
	for entry in [["1 (<50%)", 1], ["2 (50%+)", 2], ["3 (75%+)", 3], ["4 (todas)", 4]]:
		_button(endings, entry[0], Callable(world, "debug_ending").bind(entry[1]))
	_root.reset_size()


func _section(parent: Node, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1, 0.85, 0.7, 0.7))
	parent.add_child(label)


func _button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_F8:
		_root.visible = not _root.visible
		get_viewport().set_input_as_handled()

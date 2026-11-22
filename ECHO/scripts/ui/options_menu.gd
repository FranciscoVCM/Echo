class_name OptionsMenu
extends CanvasLayer
## Options: volume, fullscreen, note names, and key rebinding. Usable from the title screen
## and from the pause menu.

signal closed

var _rows: Dictionary = {}
var _waiting_action := ""
var _root: Control


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var game := get_node("/root/Game")
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel())
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(640, 600)
	panel.position = Vector2(-320, -300)
	_root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(UiStyle.title("Opções", 28))

	var volume_row := HBoxContainer.new()
	var volume_label := Label.new()
	volume_label.text = "Volume"
	volume_label.custom_minimum_size = Vector2(220, 0)
	volume_row.add_child(volume_label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(game.settings["master_volume"])
	slider.custom_minimum_size = Vector2(320, 24)
	slider.value_changed.connect(func(value: float) -> void:
		game.settings["master_volume"] = value
		game.apply_audio_and_video()
		game.save_settings())
	volume_row.add_child(slider)
	column.add_child(volume_row)

	var fullscreen := CheckBox.new()
	fullscreen.text = "Ecrã inteiro"
	fullscreen.button_pressed = bool(game.settings["fullscreen"])
	fullscreen.toggled.connect(func(on: bool) -> void:
		game.settings["fullscreen"] = on
		game.apply_audio_and_video()
		game.save_settings())
	column.add_child(fullscreen)

	var names := CheckBox.new()
	names.text = "Mostrar sempre o nome das notas por baixo das criaturas (acessibilidade)"
	names.button_pressed = bool(game.settings["note_names_always"])
	names.toggled.connect(func(on: bool) -> void:
		game.settings["note_names_always"] = on
		EchoBlob.always_show_note_names = on
		game.save_settings())
	column.add_child(names)

	var keys_title := Label.new()
	keys_title.text = "Teclas (clica e carrega na nova tecla)"
	keys_title.add_theme_font_size_override("font_size", 16)
	column.add_child(keys_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	scroll.add_child(grid)
	for entry in game.ACTIONS:
		var label := Label.new()
		label.text = entry[1]
		label.custom_minimum_size = Vector2(300, 0)
		grid.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(200, 30)
		button.pressed.connect(_start_rebind.bind(entry[0]))
		grid.add_child(button)
		_rows[entry[0]] = button
	_refresh_keys()

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	var reset := Button.new()
	reset.text = "Repor teclas"
	reset.pressed.connect(func() -> void:
		game.reset_bindings()
		_refresh_keys())
	buttons.add_child(reset)
	var back := Button.new()
	back.text = "Voltar"
	back.custom_minimum_size = Vector2(140, 36)
	back.pressed.connect(_close)
	buttons.add_child(back)
	column.add_child(buttons)
	back.grab_focus.call_deferred()


func _refresh_keys() -> void:
	var game := get_node("/root/Game")
	for action in _rows:
		_rows[action].text = "..." if action == _waiting_action else game.key_label(action)


func _start_rebind(action: String) -> void:
	_waiting_action = action
	_refresh_keys()


func _input(event: InputEvent) -> void:
	if _waiting_action.is_empty():
		if event.is_action_pressed("echo_pause"):
			_close()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var game := get_node("/root/Game")
		game.rebind(_waiting_action, (event as InputEventKey).physical_keycode)
		_waiting_action = ""
		_refresh_keys()
		get_viewport().set_input_as_handled()


func _close() -> void:
	closed.emit()
	queue_free()

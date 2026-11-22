extends CanvasLayer
## Pause menu (Esc): continue, options, back to the title screen.

var _root: Control


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.position = Vector2(-160, -130)
	column.add_theme_constant_override("separation", 14)
	_root.add_child(column)
	column.add_child(UiStyle.title("Pausa", 34))
	var resume := UiStyle.button("Continuar")
	resume.pressed.connect(close)
	column.add_child(resume)
	var options := UiStyle.button("Opções")
	options.pressed.connect(_open_options)
	column.add_child(options)
	var title := UiStyle.button("Voltar ao menu inicial")
	title.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn"))
	column.add_child(title)


func open() -> void:
	_root.visible = true
	get_tree().paused = true
	(_root.get_child(1).get_child(1) as Button).grab_focus()


func close() -> void:
	_root.visible = false
	get_tree().paused = false


func _open_options() -> void:
	var options := OptionsMenu.new()
	add_child(options)


func _unhandled_input(event: InputEvent) -> void:
	if _root.visible and event.is_action_pressed("echo_pause"):
		close()
		get_viewport().set_input_as_handled()

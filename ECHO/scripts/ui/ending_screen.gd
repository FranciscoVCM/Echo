extends CanvasLayer
## Final card after K's words.

var world: Node

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.modulate.a = 0.0
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.03, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.position = Vector2(-300, -140)
	column.custom_minimum_size = Vector2(600, 0)
	column.add_theme_constant_override("separation", 18)
	root.add_child(column)
	column.add_child(UiStyle.title("ECHO", 64))
	var thanks := UiStyle.title("O mundo voltou a ter cor.\nObrigado por jogares.", 22)
	column.add_child(thanks)
	if world != null and world.has_method("resume_after_ending"):
		var explore := UiStyle.button("Continuar a explorar")
		explore.pressed.connect(func() -> void:
			world.resume_after_ending()
			queue_free())
		column.add_child(explore)
	var back := UiStyle.button("Voltar ao menu inicial")
	back.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn"))
	column.add_child(back)
	create_tween().tween_property(root, "modulate:a", 1.0, 2.5)
	(column.get_child(2) as Button).grab_focus.call_deferred()

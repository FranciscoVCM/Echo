class_name DialogueBox
extends CanvasLayer
## Non-blocking dialogue: lines appear with a typewriter effect and advance on their own
## (or with the "echo_dialogue" key). The player keeps moving while K talks.

signal finished(sequence_id: String)

var _panel: PanelContainer
var _name_label: Label
var _text_label: Label
var _hint_label: Label
var _queue: Array = []  # [speaker, text, sequence_id]
var _current_text := ""
var _visible_chars := 0.0
var _hold := 0.0
var _current_sequence := ""
var _active := false


func _ready() -> void:
	layer = 4
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.offset_left = -380.0
	_panel.offset_right = 380.0
	_panel.offset_top = 18.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.035, 0.05, 0.86)
	style.border_color = Color(0.5, 0.5, 0.6, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var column := VBoxContainer.new()
	_panel.add_child(column)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	column.add_child(_name_label)
	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(720, 0)
	_text_label.add_theme_font_size_override("font_size", 17)
	column.add_child(_text_label)
	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.add_theme_font_size_override("font_size", 11)
	_hint_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 0.7))
	column.add_child(_hint_label)
	_panel.visible = false


## lines: Array of Strings (spoken by `speaker`) or [speaker, text] pairs.
func say(lines: Array, speaker: String = "K", sequence_id: String = "") -> void:
	for index in range(lines.size()):
		var line = lines[index]
		var last := index == lines.size() - 1
		if line is Array:
			_queue.append([line[0], line[1], sequence_id if last else ""])
		else:
			_queue.append([speaker, line, sequence_id if last else ""])
	if not _active:
		_next()


func is_busy() -> bool:
	return _active


func clear() -> void:
	_queue.clear()
	_active = false
	_panel.visible = false


func _next() -> void:
	if _queue.is_empty():
		_active = false
		_panel.visible = false
		return
	var entry: Array = _queue.pop_front()
	_active = true
	_panel.visible = true
	_name_label.text = entry[0]
	_current_text = entry[1]
	_current_sequence = entry[2]
	_visible_chars = 0.0
	_hold = 1.6 + _current_text.length() * 0.035
	_text_label.text = _current_text
	_text_label.visible_characters = 0
	var key := "Enter"
	var game := get_node_or_null("/root/Game")
	if game != null:
		key = game.key_label("echo_dialogue")
	_hint_label.text = "%s  continuar" % key


func _process(delta: float) -> void:
	if not _active:
		return
	if _visible_chars < _current_text.length():
		_visible_chars += delta * 55.0
		_text_label.visible_characters = int(_visible_chars)
	else:
		_hold -= delta
		if _hold <= 0.0:
			_finish_line()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if InputMap.has_action("echo_dialogue") and event.is_action_pressed("echo_dialogue"):
		if _visible_chars < _current_text.length():
			_visible_chars = _current_text.length()
			_text_label.visible_characters = -1
		else:
			_finish_line()
		get_viewport().set_input_as_handled()


func _finish_line() -> void:
	var sequence := _current_sequence
	_next()
	if sequence != "":
		finished.emit(sequence)

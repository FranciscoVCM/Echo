class_name EchoHud
extends CanvasLayer
## In-game HUD: note strip (colour + name + key + chord progress), region / area status,
## a toggleable controls panel and fading messages. Reads progress from the Game autoload.

var selected_tone := 0
var chord_degrees := PackedInt32Array()

var _help_panel: PanelContainer
var _help_label: Label
var _help_expanded := false
var _status_label: Label
var _message_label: Label
var _message_time := 0.0
var _note_strip: Control


func _ready() -> void:
	layer = 3
	_build_help()
	_build_status()
	_build_message()
	_build_note_strip()
	var game := get_node_or_null("/root/Game")
	if game != null:
		game.progress_changed.connect(_note_strip.queue_redraw)


func _process(delta: float) -> void:
	if _message_time > 0.0:
		_message_time -= delta
		_message_label.modulate.a = clampf(_message_time / 0.8, 0.0, 1.0)


func show_message(text: String, duration: float = 4.5) -> void:
	_message_label.text = text
	_message_time = duration
	_message_label.modulate.a = 1.0


func set_status(text: String) -> void:
	_status_label.text = text


func toggle_help() -> void:
	_help_expanded = not _help_expanded
	_refresh_help()


func set_tone(tone_index: int, chord: PackedInt32Array) -> void:
	selected_tone = tone_index
	chord_degrees = chord
	_note_strip.queue_redraw()


func _key(action: String, fallback: String) -> String:
	var game := get_node_or_null("/root/Game")
	return game.key_label(action) if game != null else fallback


func _refresh_help() -> void:
	if _help_expanded:
		_help_label.text = "\n".join([
			"%s %s %s %s  mover     %s (manter)  devagar     %s  dash" % [_key("echo_up", "W"), _key("echo_left", "A"), _key("echo_down", "S"), _key("echo_right", "D"), _key("echo_slow", "Shift"), _key("echo_dash", "Espaço")],
			"%s (manter e largar)  Ping — mais tempo = mais longe" % _key("echo_ping", "E"),
			"%s–%s / roda  escolher nota     %s  acorde (5 blobs da mesma nota)" % [_key("echo_note_1", "1"), _key("echo_note_7", "7"), _key("echo_chord", "Q")],
			"%s  nomes das notas     %s  diálogo     %s  pausa / opções" % [_key("echo_note_names", "N"), _key("echo_dialogue", "Enter"), _key("echo_pause", "Esc")],
			"H  esconder esta ajuda",
		])
	else:
		_help_label.text = "H  controlos"
	_help_panel.reset_size()


func _build_help() -> void:
	_help_panel = PanelContainer.new()
	_help_panel.anchor_top = 1.0
	_help_panel.anchor_bottom = 1.0
	_help_panel.offset_left = 16.0
	_help_panel.offset_top = -150.0
	_help_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.055, 0.07, 0.72)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	_help_panel.add_theme_stylebox_override("panel", style)
	add_child(_help_panel)
	_help_label = Label.new()
	_help_label.add_theme_font_size_override("font_size", 12)
	_help_panel.add_child(_help_label)
	_refresh_help()


func _build_status() -> void:
	_status_label = Label.new()
	_status_label.anchor_left = 1.0
	_status_label.anchor_right = 1.0
	_status_label.offset_left = -360.0
	_status_label.offset_right = -16.0
	_status_label.offset_top = 14.0
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	add_child(_status_label)


func _build_message() -> void:
	_message_label = Label.new()
	_message_label.anchor_left = 0.5
	_message_label.anchor_right = 0.5
	_message_label.offset_left = -400.0
	_message_label.offset_right = 400.0
	_message_label.offset_top = 150.0
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 18)
	_message_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_message_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_message_label)


func _build_note_strip() -> void:
	_note_strip = Control.new()
	_note_strip.anchor_left = 0.5
	_note_strip.anchor_right = 0.5
	_note_strip.anchor_top = 1.0
	_note_strip.anchor_bottom = 1.0
	_note_strip.offset_left = -245.0
	_note_strip.offset_right = 245.0
	_note_strip.offset_top = -92.0
	_note_strip.offset_bottom = -12.0
	_note_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note_strip.draw.connect(_draw_note_strip)
	add_child(_note_strip)


func _draw_note_strip() -> void:
	var strip := _note_strip
	var font := ThemeDB.fallback_font
	var game := get_node_or_null("/root/Game")
	var slot_width := strip.size.x / 7.0
	var chord_pcs: Array[int] = []
	for degree in chord_degrees:
		chord_pcs.append(EchoNotes.pitch_class(degree))
	for index in range(7):
		var center := Vector2(slot_width * (index + 0.5), 30.0)
		var color := EchoNotes.color_for(index)
		var is_selected := index == selected_tone
		var in_chord := index in chord_pcs and not is_selected
		var radius := 17.0 if is_selected else 12.0
		if is_selected or in_chord:
			strip.draw_circle(center, radius + 6.0, Color(color, 0.25))
		strip.draw_circle(center, radius, color if (is_selected or in_chord) else color.darkened(0.35))
		strip.draw_arc(center, radius, 0.0, TAU, 32, Color(1, 1, 1, 0.9 if is_selected else 0.25), 2.0 if is_selected else 1.0, true)
		if in_chord:
			strip.draw_arc(center, radius + 4.0, 0.0, TAU, 32, Color(1, 1, 1, 0.6), 1.5, true)
		if game != null:
			var freed: int = game.freed_count_for_note(index)
			var needed: int = game.CHORD_UNLOCK_COUNT
			if freed >= needed:
				for dot in range(3):
					strip.draw_circle(center + Vector2(-6.0 + dot * 6.0, -radius - 8.0), 2.2, Color(1, 1, 1, 0.9))
			else:
				var text := "%d/%d" % [freed, needed]
				var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
				strip.draw_string(font, center + Vector2(-width * 0.5, -radius - 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.45))
		var label := "%s  %s" % [_key("echo_note_%d" % (index + 1), str(index + 1)), EchoNotes.name_for(index)]
		var text_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var text_color := Color(1, 1, 1, 1.0 if is_selected else 0.65)
		strip.draw_string_outline(font, Vector2(center.x - text_width * 0.5, 68.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.8))
		strip.draw_string(font, Vector2(center.x - text_width * 0.5, 68.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, text_color)
	if not chord_degrees.is_empty():
		var chord_text := "Acorde: " + EchoNotes.chord_name_for(selected_tone)
		var chord_width := font.get_string_size(chord_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		strip.draw_string_outline(font, Vector2(strip.size.x * 0.5 - chord_width * 0.5, -8.0), chord_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.8))
		strip.draw_string(font, Vector2(strip.size.x * 0.5 - chord_width * 0.5, -8.0), chord_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.95))

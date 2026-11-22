class_name EchoHud
extends CanvasLayer
## Minimal HUD for the Echo world: note strip (colour + name + key), short status,
## toggleable controls help and fading messages. Built in code so it is easy to tweak.

var selected_tone := 0
var chord_degrees := PackedInt32Array()
var unlocked_chords: Dictionary = {}

var _help_panel: PanelContainer
var _status_label: Label
var _message_label: Label
var _message_time := 0.0
var _note_strip: Control
var _prompt_label: Label
var _help_label: Label
var _help_expanded := true
var _help_auto_collapse := 16.0


func _ready() -> void:
	layer = 3
	_build_help()
	_build_status()
	_build_message()
	_build_note_strip()


func _process(delta: float) -> void:
	if _help_auto_collapse > 0.0:
		_help_auto_collapse -= delta
		if _help_auto_collapse <= 0.0 and _help_expanded:
			toggle_help()
	if _message_time > 0.0:
		_message_time -= delta
		_message_label.modulate.a = clampf(_message_time / 0.8, 0.0, 1.0)


func show_message(text: String, duration: float = 4.5) -> void:
	_message_label.text = text
	_message_time = duration
	_message_label.modulate.a = 1.0


func set_status(text: String) -> void:
	_status_label.text = text


func set_prompt(text: String) -> void:
	_prompt_label.text = text
	_prompt_label.visible = not text.is_empty()


func toggle_help() -> void:
	_help_auto_collapse = 0.0
	_help_expanded = not _help_expanded
	_help_label.text = HELP_TEXT if _help_expanded else "H  ajuda / controlos"
	_help_panel.reset_size()


func set_tone(tone_index: int, chord: PackedInt32Array) -> void:
	selected_tone = tone_index
	chord_degrees = chord
	_note_strip.queue_redraw()


func set_unlocked_chords(chords: Dictionary) -> void:
	unlocked_chords = chords
	_note_strip.queue_redraw()


func _build_help() -> void:
	_help_panel = PanelContainer.new()
	_help_panel.position = Vector2(16.0, 16.0)
	_help_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_help_panel)
	_help_label = Label.new()
	_help_label.text = HELP_TEXT
	_help_label.add_theme_font_size_override("font_size", 12)
	_help_panel.add_child(_help_label)


const HELP_TEXT := """ECHO — Clareira (fatia vertical, protótipo)
WASD/setas  mover      Espaço  dash
E (manter e largar)  Ping — mais tempo = mais longe
1–8 / roda  escolher nota      Q  acorde (quando desbloqueado)
Z  recrutar      X  absorver      (perto de uma blob ajudada)
N  mostrar sempre nomes das notas      H  esconder ajuda
F9  recomeçar a cena"""


func _build_status() -> void:
	_status_label = Label.new()
	_status_label.anchor_left = 1.0
	_status_label.anchor_right = 1.0
	_status_label.offset_left = -330.0
	_status_label.offset_right = -16.0
	_status_label.offset_top = 16.0
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	add_child(_status_label)

	_prompt_label = Label.new()
	_prompt_label.anchor_left = 0.5
	_prompt_label.anchor_right = 0.5
	_prompt_label.anchor_top = 1.0
	_prompt_label.anchor_bottom = 1.0
	_prompt_label.offset_left = -360.0
	_prompt_label.offset_right = 360.0
	_prompt_label.offset_top = -150.0
	_prompt_label.offset_bottom = -96.0
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_prompt_label.add_theme_font_size_override("font_size", 15)
	_prompt_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_prompt_label.visible = false
	add_child(_prompt_label)


func _build_message() -> void:
	_message_label = Label.new()
	_message_label.anchor_left = 0.5
	_message_label.anchor_right = 0.5
	_message_label.offset_left = -420.0
	_message_label.offset_right = 420.0
	_message_label.offset_top = 172.0
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 17)
	_message_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_message_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_message_label)


func _build_note_strip() -> void:
	_note_strip = Control.new()
	_note_strip.anchor_left = 0.5
	_note_strip.anchor_right = 0.5
	_note_strip.anchor_top = 1.0
	_note_strip.anchor_bottom = 1.0
	_note_strip.offset_left = -270.0
	_note_strip.offset_right = 270.0
	_note_strip.offset_top = -86.0
	_note_strip.offset_bottom = -14.0
	_note_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note_strip.draw.connect(_draw_note_strip)
	add_child(_note_strip)


func _draw_note_strip() -> void:
	var font := ThemeDB.fallback_font
	var slot_width := _note_strip.size.x / 8.0
	var selected_pc := EchoNotes.pitch_class(selected_tone)
	var chord_pcs: Array[int] = []
	for degree in chord_degrees:
		chord_pcs.append(EchoNotes.pitch_class(degree))
	for index in range(8):
		var center := Vector2(slot_width * (index + 0.5), 26.0)
		var color := EchoNotes.color_for(index)
		var is_selected := index == selected_tone
		var in_chord := EchoNotes.pitch_class(index) in chord_pcs and not is_selected
		var radius := 17.0 if is_selected else 12.0
		if is_selected or in_chord:
			_note_strip.draw_circle(center, radius + 6.0, Color(color, 0.25))
		_note_strip.draw_circle(center, radius, color if (is_selected or in_chord) else color.darkened(0.35))
		_note_strip.draw_arc(center, radius, 0.0, TAU, 32, Color(1, 1, 1, 0.9 if is_selected else 0.25), 2.0 if is_selected else 1.0, true)
		if in_chord:
			_note_strip.draw_arc(center, radius + 4.0, 0.0, TAU, 32, Color(1, 1, 1, 0.6), 1.5, true)
		if unlocked_chords.get(EchoNotes.pitch_class(index), false):
			# Small triad marker: this note can become a chord (Q).
			for dot in range(3):
				_note_strip.draw_circle(center + Vector2(-6.0 + dot * 6.0, -radius - 7.0), 2.0, Color(1, 1, 1, 0.8))
		var name := EchoNotes.name_for(index) + ("'" if index == 7 else "")
		var label := "%d  %s" % [index + 1, name]
		var text_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var text_color := Color(1, 1, 1, 1.0 if is_selected else 0.65)
		_note_strip.draw_string_outline(font, Vector2(center.x - text_width * 0.5, 64.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.8))
		_note_strip.draw_string(font, Vector2(center.x - text_width * 0.5, 64.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, text_color)
	if not chord_degrees.is_empty():
		var chord_text := "Acorde: " + EchoNotes.chord_name_for(selected_pc)
		var chord_width := font.get_string_size(chord_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		_note_strip.draw_string_outline(font, Vector2(_note_strip.size.x * 0.5 - chord_width * 0.5, -6.0), chord_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.8))
		_note_strip.draw_string(font, Vector2(_note_strip.size.x * 0.5 - chord_width * 0.5, -6.0), chord_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.95))


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.055, 0.07, 0.78)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

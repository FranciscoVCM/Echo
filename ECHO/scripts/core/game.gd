extends Node
## Autoload "Game": settings, rebindable input actions, progress and save/load.
## Everything that must survive scene changes lives here.

signal progress_changed
signal chord_unlocked(pitch_class: int)
signal vassal_freed(letter: String)

const SETTINGS_PATH := "user://settings.cfg"
const SAVE_PATH := "user://save.json"
const CHORD_UNLOCK_COUNT := 5
const NOTE_COUNT := 7
const AREAS: PackedStringArray = ["vista", "som", "tato"]
const AREA_VASSAL := {"vista": "Y", "som": "C", "tato": "M"}

## Rebindable actions: name -> [label, default physical keycode]. Movement also keeps arrows.
const ACTIONS := [
	["echo_up", "Mover para cima", KEY_W],
	["echo_down", "Mover para baixo", KEY_S],
	["echo_left", "Mover para a esquerda", KEY_A],
	["echo_right", "Mover para a direita", KEY_D],
	["echo_ping", "Ping (manter e largar)", KEY_E],
	["echo_slow", "Andar devagar (manter)", KEY_SHIFT],
	["echo_dash", "Dash", KEY_SPACE],
	["echo_chord", "Alternar acorde", KEY_Q],
	["echo_note_1", "Nota Dó", KEY_1],
	["echo_note_2", "Nota Ré", KEY_2],
	["echo_note_3", "Nota Mi", KEY_3],
	["echo_note_4", "Nota Fá", KEY_4],
	["echo_note_5", "Nota Sol", KEY_5],
	["echo_note_6", "Nota Lá", KEY_6],
	["echo_note_7", "Nota Si", KEY_7],
	["echo_note_names", "Mostrar nomes das notas", KEY_N],
	["echo_dialogue", "Avançar diálogo", KEY_ENTER],
	["echo_pause", "Pausa", KEY_ESCAPE],
]
const SECONDARY_KEYS := {
	"echo_up": KEY_UP, "echo_down": KEY_DOWN, "echo_left": KEY_LEFT, "echo_right": KEY_RIGHT,
	"echo_dialogue": KEY_KP_ENTER,
}

var settings := {
	"master_volume": 0.8,
	"note_names_always": false,
	"fullscreen": false,
	"bindings": {},
}
var progress: Dictionary = {}
## Set by the title screen's TEST button: skips the clearing and enables debug keys.
var test_mode := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	new_progress()
	_load_settings()
	apply_input_bindings()
	apply_audio_and_video()


func _process(delta: float) -> void:
	if not get_tree().paused and progress.has("stats"):
		progress["stats"]["play_time"] += delta


# --- Settings / input -------------------------------------------------------------------

func default_key(action: String) -> int:
	for entry in ACTIONS:
		if entry[0] == action:
			return entry[2]
	return KEY_NONE


func key_for(action: String) -> int:
	return int(settings["bindings"].get(action, default_key(action)))


func key_label(action: String) -> String:
	return OS.get_keycode_string(key_for(action))


func rebind(action: String, physical_keycode: int) -> void:
	settings["bindings"][action] = physical_keycode
	apply_input_bindings()
	save_settings()


func reset_bindings() -> void:
	settings["bindings"] = {}
	apply_input_bindings()
	save_settings()


func apply_input_bindings() -> void:
	for entry in ACTIONS:
		var action: String = entry[0]
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event := InputEventKey.new()
		event.physical_keycode = key_for(action) as Key
		InputMap.action_add_event(action, event)
		if SECONDARY_KEYS.has(action):
			var secondary := InputEventKey.new()
			secondary.physical_keycode = SECONDARY_KEYS[action]
			InputMap.action_add_event(action, secondary)
	for wheel in [["echo_note_next", MOUSE_BUTTON_WHEEL_UP], ["echo_note_prev", MOUSE_BUTTON_WHEEL_DOWN]]:
		if not InputMap.has_action(wheel[0]):
			InputMap.add_action(wheel[0])
		InputMap.action_erase_events(wheel[0])
		var mouse := InputEventMouseButton.new()
		mouse.button_index = wheel[1]
		InputMap.action_add_event(wheel[0], mouse)


func apply_audio_and_video() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(float(settings["master_volume"]), 0.0001)))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
		)


func save_settings() -> void:
	var config := ConfigFile.new()
	for key in settings:
		config.set_value("settings", key, settings[key])
	config.save(SETTINGS_PATH)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for key in settings:
		settings[key] = config.get_value("settings", key, settings[key])


# --- Progress ---------------------------------------------------------------------------

func new_progress(seed_value: int = -1) -> void:
	if seed_value < 0:
		seed_value = randi() % 1000000
	progress = {
		"seed": seed_value,
		"clearing_done": false,
		"freed": {},  # blob id -> pitch class
		"freed_area": {},  # blob id -> area name
		"vassals": {"C": false, "M": false, "Y": false, "K": false},
		"area_specs": {},  # area -> generated encounter specs (PCG, JSON-friendly)
		"dialogue_seen": {},
		"areas_entered": [],
		"stats": {
			"play_time": 0.0, "pings": 0, "chord_pings": 0, "wrong_notes": 0,
			"startles": 0, "scares": 0, "gentle_approaches": 0,
		},
		"ended": false,
	}


func is_freed(blob_id: String) -> bool:
	return progress["freed"].has(blob_id)


func mark_freed(blob_id: String, pitch_class: int, area: String) -> void:
	if blob_id.is_empty() or is_freed(blob_id):
		return
	var chords_before := unlocked_chords()
	progress["freed"][blob_id] = pitch_class
	progress["freed_area"][blob_id] = area
	for pc in unlocked_chords():
		if not pc in chords_before:
			chord_unlocked.emit(pc)
	progress_changed.emit()
	save_game()


func freed_count_for_note(pitch_class: int) -> int:
	var count := 0
	for blob_id in progress["freed"]:
		# Vassal pieces and K fragments do not count towards chords.
		if blob_id.begins_with("vassal") or blob_id.begins_with("k:"):
			continue
		if int(progress["freed"][blob_id]) == pitch_class:
			count += 1
	return count


func freed_count_in_area(area: String) -> int:
	var count := 0
	for blob_id in progress["freed_area"]:
		if progress["freed_area"][blob_id] == area and not blob_id.begins_with("vassal"):
			count += 1
	return count


func unlocked_chords() -> Array[int]:
	var chords: Array[int] = []
	for pc in range(NOTE_COUNT):
		if freed_count_for_note(pc) >= CHORD_UNLOCK_COUNT:
			chords.append(pc)
	return chords


func is_chord_unlocked(pitch_class: int) -> bool:
	return freed_count_for_note(pitch_class) >= CHORD_UNLOCK_COUNT


func free_vassal(letter: String) -> void:
	if progress["vassals"].get(letter, false):
		return
	progress["vassals"][letter] = true
	vassal_freed.emit(letter)
	progress_changed.emit()
	save_game()


func is_vassal_freed(letter: String) -> bool:
	return progress["vassals"].get(letter, false)


func cmy_freed_count() -> int:
	var count := 0
	for letter in ["C", "M", "Y"]:
		if is_vassal_freed(letter):
			count += 1
	return count


func dialogue_seen(key: String) -> bool:
	return progress["dialogue_seen"].has(key)


func mark_dialogue(key: String) -> void:
	progress["dialogue_seen"][key] = true


func add_stat(key: String, amount: float = 1.0) -> void:
	progress["stats"][key] = progress["stats"].get(key, 0) + amount


func note_area_entered(area: String) -> void:
	if not area in progress["areas_entered"]:
		progress["areas_entered"].append(area)
		save_game()


# --- Save / load ------------------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	if test_mode:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(progress))


func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	new_progress(int(data.get("seed", 0)))
	for key in data:
		progress[key] = data[key]
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

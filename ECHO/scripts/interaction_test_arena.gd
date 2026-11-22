extends Node2D
## Builds a repeatable six-zone development arena from existing player and blob scenes.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const DUMMY_SCENE: PackedScene = preload("res://scenes/ping_dummy.tscn")
const FOV_SCRIPT: Script = preload("res://scripts/field_of_view.gd")
const FOV_SHADER: Shader = preload("res://resources/field_of_view.gdshader")
const COORDINATOR_SCRIPT: Script = preload("res://scripts/blob_interaction_coordinator.gd")

const ROOM_SIZE := Vector2(800.0, 520.0)
const ROOM_CENTERS := [
	Vector2(-900.0, -340.0),
	Vector2(0.0, -340.0),
	Vector2(900.0, -340.0),
	Vector2(-900.0, 340.0),
	Vector2(0.0, 340.0),
	Vector2(900.0, 340.0)
]
const ZONE_TITLES := [
	"01 — FRIGHTENED BLOB",
	"02 — SOUND CONNECTION",
	"03 — ECHOLOCATION",
	"04 — FREQUENCY MATCHING",
	"05 — GROUP RESONANCE",
	"06 — SILENCE"
]
const ZONE_HINTS := [
	"Send three nearby short, low-range pings. Strong pings reset progress.",
	"Move around the block; one wave must reach both blobs.",
	"Ping the hidden blob, approach its echo, then ping nearby.",
	"Select 5 for G3 and match the note three times.",
	"Activate all three blobs together before their timers expire.",
	"Ping the unstable blob once, then stay silent until it calms."
]
const ROOM_COLORS := [
	Color(0.22, 0.29, 0.32, 1.0),
	Color(0.25, 0.29, 0.34, 1.0),
	Color(0.23, 0.30, 0.34, 1.0),
	Color(0.27, 0.29, 0.32, 1.0),
	Color(0.23, 0.31, 0.31, 1.0),
	Color(0.28, 0.28, 0.32, 1.0)
]
const RAINBOW_BLOB_COLORS: Array[Color] = [
	Color(0.96, 0.25, 0.29),
	Color(1.0, 0.48, 0.18),
	Color(0.98, 0.78, 0.20),
	Color(0.67, 0.85, 0.22),
	Color(0.22, 0.76, 0.34),
	Color(0.12, 0.75, 0.68),
	Color(0.18, 0.63, 0.94),
	Color(0.31, 0.43, 0.96),
	Color(0.52, 0.34, 0.91),
	Color(0.76, 0.30, 0.88),
	Color(0.94, 0.31, 0.66),
	Color(0.96, 0.48, 0.52)
]

var _player: PlayerController
var _coordinator: BlobInteractionCoordinator
var _fov: CanvasLayer
var _interactions: Array[SmallBlobInteraction] = []
var _zone_interactions: Array = [[], [], [], [], [], []]
var _active_zone := 0
var _hud_status_labels: Array[Label] = []
var _hud_zone_label: Label
var _hud_update_remaining := 0.0
var _blob_color_pool: Array[Color] = []
var _last_blob_color := Color.TRANSPARENT
var _has_last_blob_color := false


func _ready() -> void:
	_refill_blob_color_pool()
	_create_rooms()
	_create_obstacles()
	_create_player()
	_create_zone_blobs()
	_create_coordinator()
	_create_field_of_view()
	_create_hud()
	_teleport_to_zone(0)
	_update_hud()


func _process(delta: float) -> void:
	_hud_update_remaining -= delta
	if _hud_update_remaining <= 0.0:
		_hud_update_remaining = 0.15
		_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	if key_event.keycode >= KEY_F1 and key_event.keycode <= KEY_F6:
		_teleport_to_zone(key_event.keycode - KEY_F1)
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_R:
		if key_event.shift_pressed:
			_reset_all()
		else:
			_reset_active_zone()
		get_viewport().set_input_as_handled()


func _create_rooms() -> void:
	for index in range(ROOM_CENTERS.size()):
		var center: Vector2 = ROOM_CENTERS[index]
		var floor := Polygon2D.new()
		floor.name = "Zone%02dFloor" % (index + 1)
		floor.position = center
		floor.polygon = _rectangle_points(ROOM_SIZE)
		floor.color = ROOM_COLORS[index]
		add_child(floor)
		_create_room_walls(center, index)
		_add_world_label(
			ZONE_TITLES[index],
			center + Vector2(-ROOM_SIZE.x * 0.5 + 24.0, -ROOM_SIZE.y * 0.5 + 12.0),
			Vector2(ROOM_SIZE.x - 48.0, 44.0),
			22,
			Color(0.91, 0.94, 0.94, 1.0)
		)
		_add_world_label(
			ZONE_HINTS[index],
			center + Vector2(-ROOM_SIZE.x * 0.5 + 26.0, -ROOM_SIZE.y * 0.5 + 48.0),
			Vector2(ROOM_SIZE.x - 52.0, 38.0),
			13,
			Color(0.78, 0.84, 0.87, 1.0)
		)


func _create_room_walls(center: Vector2, zone_index: int) -> void:
	var thickness := 22.0
	var group_name := _vision_group_for_zone(zone_index)
	_create_wall(center + Vector2(0.0, -ROOM_SIZE.y * 0.5), Vector2(ROOM_SIZE.x + thickness, thickness), group_name)
	_create_wall(center + Vector2(0.0, ROOM_SIZE.y * 0.5), Vector2(ROOM_SIZE.x + thickness, thickness), group_name)
	_create_wall(center + Vector2(-ROOM_SIZE.x * 0.5, 0.0), Vector2(thickness, ROOM_SIZE.y), group_name)
	_create_wall(center + Vector2(ROOM_SIZE.x * 0.5, 0.0), Vector2(thickness, ROOM_SIZE.y), group_name)


func _create_obstacles() -> void:
	var lost_zone: Vector2 = ROOM_CENTERS[2]
	_create_wall(lost_zone + Vector2(112.0, 0.0), Vector2(42.0, 154.0), _vision_group_for_zone(2))
	var connection_zone: Vector2 = ROOM_CENTERS[1]
	_create_wall(connection_zone, Vector2(100.0, 156.0), _vision_group_for_zone(1))


func _create_player() -> void:
	_player = PLAYER_SCENE.instantiate() as PlayerController
	_player.name = "Player"
	_player.collision_mask = 3
	_player.dash_unlocked = true
	_player.ping_unlocked = true
	add_child(_player)
	var camera := Camera2D.new()
	camera.name = "Camera2D"
	camera.zoom = Vector2(1.12, 1.12)
	_player.add_child(camera)
	camera.make_current()


func _create_zone_blobs() -> void:
	var center: Vector2
	center = ROOM_CENTERS[0]
	_spawn_blob(0, "frightened", "Frightened", SmallBlobInteraction.Kind.FRIGHTENED, Vector2(66.0, 0.0))
	_player.global_position = center + Vector2(-104.0, 0.0)

	center = ROOM_CENTERS[1]
	_spawn_blob(1, "link_a", "Separated A", SmallBlobInteraction.Kind.CONNECTION, Vector2(-300.0, 0.0))
	_spawn_blob(1, "link_b", "Separated B", SmallBlobInteraction.Kind.CONNECTION, Vector2(300.0, 0.0))

	_spawn_blob(2, "lost", "Lost Blob", SmallBlobInteraction.Kind.LOST, Vector2(258.0, 0.0))

	_spawn_blob(3, "frequency", "Silenced", SmallBlobInteraction.Kind.FREQUENCY, Vector2(175.0, 0.0), true)

	var resonator_a := _spawn_blob(4, "resonance_a", "Resonator A", SmallBlobInteraction.Kind.RESONANCE, Vector2(-220.0, 0.0), true)
	var resonator_b := _spawn_blob(4, "resonance_b", "Resonator B", SmallBlobInteraction.Kind.RESONANCE, Vector2(150.0, -165.0), true)
	var resonator_c := _spawn_blob(4, "resonance_c", "Resonator C", SmallBlobInteraction.Kind.RESONANCE, Vector2(150.0, 165.0), true)
	resonator_a.target_tone_index = 0
	resonator_b.target_tone_index = 2
	resonator_c.target_tone_index = 4
	(resonator_a.get_parent().get_node("PingEmitter") as PingEmitter).ping_tone_index = resonator_a.target_tone_index
	(resonator_b.get_parent().get_node("PingEmitter") as PingEmitter).ping_tone_index = resonator_b.target_tone_index
	(resonator_c.get_parent().get_node("PingEmitter") as PingEmitter).ping_tone_index = resonator_c.target_tone_index

	_spawn_blob(5, "silence", "Overwhelmed", SmallBlobInteraction.Kind.SILENCE, Vector2(160.0, 0.0))


func _spawn_blob(
	zone_index: int,
	interaction_id: String,
	display_name: String,
	kind: int,
	local_position: Vector2,
	needs_voice: bool = false
) -> SmallBlobInteraction:
	var blob := DUMMY_SCENE.instantiate() as PingDummy
	var color := _take_blob_color()
	blob.name = "Blob_" + interaction_id
	blob.position = _room_center(zone_index) + local_position
	blob.body_radius = 25.0
	blob.collision_radius = 32.0
	blob.body_color = color
	blob.outline_color = color.darkened(0.48)
	var emitter := blob.get_node("PingEmitter") as PingEmitter
	emitter.respond_to_ping = true
	emitter.ping_color = color
	if needs_voice:
		var audio_player := AudioStreamPlayer.new()
		audio_player.name = "TonePreview"
		emitter.add_child(audio_player)
	var interaction := SmallBlobInteraction.new()
	interaction.name = "Interaction"
	interaction.interaction_id = interaction_id
	interaction.display_name = display_name
	interaction.interaction_kind = kind
	if kind == SmallBlobInteraction.Kind.LOST:
		interaction.safe_destination = _room_center(zone_index) + Vector2(180.0, 150.0)
	if kind == SmallBlobInteraction.Kind.FREQUENCY:
		interaction.target_tone_index = 4
		emitter.ping_tone_index = interaction.target_tone_index
	blob.add_child(interaction)
	add_child(blob)
	interaction.state_changed.connect(_on_interaction_state_changed)
	_interactions.append(interaction)
	_zone_interactions[zone_index].append(interaction)
	return interaction


func _refill_blob_color_pool() -> void:
	_blob_color_pool = RAINBOW_BLOB_COLORS.duplicate()
	_blob_color_pool.shuffle()
	if _has_last_blob_color and _blob_color_pool.size() > 1 and _blob_color_pool.back().is_equal_approx(_last_blob_color):
		var swap_index := _blob_color_pool.size() - 2
		var color_to_swap := _blob_color_pool[swap_index]
		_blob_color_pool[swap_index] = _blob_color_pool.back()
		_blob_color_pool[_blob_color_pool.size() - 1] = color_to_swap


func _take_blob_color() -> Color:
	if _blob_color_pool.is_empty():
		_refill_blob_color_pool()
	var color: Color = _blob_color_pool.pop_back()
	_last_blob_color = color
	_has_last_blob_color = true
	return color


func _create_coordinator() -> void:
	_coordinator = COORDINATOR_SCRIPT.new() as BlobInteractionCoordinator
	_coordinator.name = "InteractionCoordinator"
	add_child(_coordinator)
	_coordinator.configure(_interactions)


func _create_field_of_view() -> void:
	var fov := CanvasLayer.new()
	fov.name = "FieldOfView"
	fov.layer = 1
	fov.set_script(FOV_SCRIPT)
	fov.set("target_path", NodePath("../Player"))
	fov.set("occluder_group", _vision_group_for_zone(_active_zone))
	var color_rect := ColorRect.new()
	color_rect.name = "ColorRect"
	color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = FOV_SHADER
	material.set_shader_parameter("fog_opacity", 0.4)
	material.set_shader_parameter("fog_color", Color(0.12, 0.16, 0.19, 1.0))
	material.set_shader_parameter("vision_radius_pixels", 270.0)
	material.set_shader_parameter("edge_softness", 95.0)
	material.set_shader_parameter("wall_edge_softness", 8.0)
	material.set_shader_parameter("blur_strength", 0.25)
	color_rect.material = material
	fov.add_child(color_rect)
	add_child(fov)
	_fov = fov


func _create_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "TestHUD"
	canvas.layer = 2
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(16.0, 16.0)
	panel.custom_minimum_size = Vector2(320.0, 0.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.075, 0.09, 0.88)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 14.0
	panel_style.content_margin_right = 14.0
	panel_style.content_margin_top = 10.0
	panel_style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", panel_style)
	canvas.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	var title := Label.new()
	title.text = "SMALL BLOB INTERACTION LAB"
	title.add_theme_font_size_override("font_size", 17)
	column.add_child(title)
	var controls := Label.new()
	controls.text = "WASD move • Hold/release E ping • Wheel or 1–8 tone"
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_theme_font_size_override("font_size", 12)
	column.add_child(controls)
	var navigation := Label.new()
	navigation.text = "F1–F6 visit zones • R reset zone • Shift+R reset all"
	navigation.add_theme_font_size_override("font_size", 12)
	column.add_child(navigation)
	_hud_zone_label = Label.new()
	_hud_zone_label.add_theme_font_size_override("font_size", 14)
	column.add_child(_hud_zone_label)
	for index in range(6):
		var status := Label.new()
		status.add_theme_font_size_override("font_size", 12)
		_hud_status_labels.append(status)
		column.add_child(status)
	var button_row := HBoxContainer.new()
	column.add_child(button_row)
	var reset_zone_button := Button.new()
	reset_zone_button.text = "Reset zone"
	reset_zone_button.pressed.connect(_reset_active_zone)
	button_row.add_child(reset_zone_button)
	var reset_all_button := Button.new()
	reset_all_button.text = "Reset all"
	reset_all_button.pressed.connect(_reset_all)
	button_row.add_child(reset_all_button)


func _update_hud() -> void:
	if _hud_zone_label == null:
		return
	_hud_zone_label.text = "ACTIVE: " + ZONE_TITLES[_active_zone]
	for zone_index in range(_hud_status_labels.size()):
		var completed := 0
		var total: int = _zone_interactions[zone_index].size()
		var progressing := false
		for interaction in _zone_interactions[zone_index]:
			if interaction.state == SmallBlobInteraction.STATE_COMPLETED:
				completed += 1
			elif interaction.state != SmallBlobInteraction.STATE_IDLE:
				progressing = true
		var zone_state := "COMPLETED" if completed == total else ("ACTIVE" if progressing else "IDLE")
		if zone_index == 1:
			zone_state = "COMPLETED" if _coordinator.get_connection_progress() >= _coordinator.successful_connections_required else "%d/%d LINK PINGS" % [_coordinator.get_connection_progress(), _coordinator.successful_connections_required]
		elif zone_index == 4:
			zone_state = "COMPLETED" if completed == total else "%d/3 ACTIVE" % _coordinator.get_resonance_count()
		_hud_status_labels[zone_index].text = "%02d  %s" % [zone_index + 1, zone_state]


func _on_interaction_state_changed(_interaction_id: String, _state: String) -> void:
	_update_hud()


func _teleport_to_zone(index: int) -> void:
	_active_zone = clampi(index, 0, ROOM_CENTERS.size() - 1)
	if _player != null:
		var spawn_offset := Vector2.ZERO
		if _active_zone == 0:
			spawn_offset = Vector2(-104.0, 0.0)
		elif _active_zone == 1:
			spawn_offset = Vector2(-245.0, 0.0)
		_player.global_position = _room_center(_active_zone) + spawn_offset
		_player.velocity = Vector2.ZERO
		_player.dash_active = false
		_player.dash_charging = false
		_player.dash_cooldown_remaining = 0.0
		var ping_emitter := _player.get_node("PingEmitter") as PingEmitter
		ping_emitter.ping_charging = false
		ping_emitter.ping_charge = 0.0
		ping_emitter.ping_cooldown_remaining = 0.0
		ping_emitter.cooldown_opacity = 1.0
	if _fov != null:
		_fov.call("refresh_occluders", _vision_group_for_zone(_active_zone))
	_update_hud()


func _reset_active_zone() -> void:
	_clear_ping_waves(_active_zone)
	var player_preview := _player.get_node_or_null("PingEmitter/TonePreview") as AudioStreamPlayer
	if player_preview != null:
		player_preview.stop()
	for interaction in _zone_interactions[_active_zone]:
		interaction.reset_interaction()
	if _active_zone == 1:
		_coordinator.reset_connection()
	elif _active_zone == 4:
		_coordinator.reset_resonance()
	_teleport_to_zone(_active_zone)
	_update_hud()


func _reset_all() -> void:
	_clear_ping_waves(-1)
	_coordinator.reset_all()
	(_player.get_node("PingEmitter") as PingEmitter).ping_tone_index = 0
	_teleport_to_zone(0)
	_update_hud()
	var player_preview := _player.get_node_or_null("PingEmitter/TonePreview") as AudioStreamPlayer
	if player_preview != null:
		player_preview.stop()


func _clear_ping_waves(zone_index: int) -> void:
	for wave in get_tree().get_nodes_in_group("active_ping_waves"):
		if zone_index < 0:
			wave.queue_free()
		elif ROOM_CENTERS[zone_index].distance_to(wave.global_position) <= ROOM_SIZE.length() * 0.5:
			wave.queue_free()


func _create_wall(center: Vector2, size: Vector2, group_name: String) -> void:
	var wall := StaticBody2D.new()
	wall.position = center
	wall.collision_layer = 2
	wall.collision_mask = 0
	wall.add_to_group(group_name)
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collision.shape = rectangle
	wall.add_child(collision)
	var visual := Polygon2D.new()
	visual.polygon = _rectangle_points(size)
	visual.color = Color(0.12, 0.16, 0.18, 1.0)
	visual.z_index = 1
	wall.add_child(visual)
	add_child(wall)


func _rectangle_points(size: Vector2) -> PackedVector2Array:
	var half := size * 0.5
	return PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y)
	])


func _room_center(index: int) -> Vector2:
	var center: Vector2 = ROOM_CENTERS[index]
	return center


func _vision_group_for_zone(index: int) -> String:
	return "vision_occluders_zone_%d" % (index + 1)


func _add_world_label(text: String, position: Vector2, size: Vector2, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = size
	label.z_index = 5
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.03, 0.04, 0.05, 0.85))
	add_child(label)

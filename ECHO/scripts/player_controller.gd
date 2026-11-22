class_name PlayerController
extends CharacterBody2D
## Reads player input, applies movement, and exposes collision data to the blob visuals.

## Reusable profile for maximum speed, acceleration, and deceleration.
@export var movement: TopDownMovement

@export_category("Unlockable Abilities")
## Disable until the dash is unlocked through game progression.
@export var dash_unlocked := true
## Disable until ping is unlocked through game progression.
@export var ping_unlocked := true

@export_category("Dash")
@export_range(0.1, 2.0, 0.05) var max_dash_charge_time: float = 1.05
@export_range(100.0, 1200.0, 10.0) var min_dash_speed: float = 430.0
@export_range(100.0, 1200.0, 10.0) var max_dash_speed: float = 850.0
@export_range(0.05, 0.5, 0.01) var min_dash_duration: float = 0.08
@export_range(0.05, 0.5, 0.005) var max_dash_duration: float = 0.265
@export_range(0.1, 10.0, 0.1) var dash_cooldown: float = 2.0

# The visual reads these values to orient deformation and surface squashing.
var input_direction := Vector2.ZERO
var wall_pressure_direction := Vector2.ZERO
var dash_active := false
var dash_charging := false
var dash_fully_charged := false
var dash_charge := 0.0
var dash_time_remaining := 0.0
var dash_cooldown_remaining := 0.0
var dash_direction := Vector2.DOWN
var charge_direction := Vector2.DOWN
var current_dash_duration := 0.16
var current_dash_speed := 850.0

var _last_direction := Vector2.DOWN
var _space_was_pressed := false
var _dash_charge_time := 0.0
@onready var _ping_emitter: PingEmitter = $PingEmitter


func _ready() -> void:
	_ping_emitter.listen_for_input = ping_unlocked


func _physics_process(delta: float) -> void:
	input_direction = _read_direction()
	if input_direction != Vector2.ZERO:
		_last_direction = input_direction

	var space_pressed := dash_unlocked and Input.is_physical_key_pressed(KEY_SPACE)
	if not dash_unlocked:
		dash_charging = false
		dash_fully_charged = false
		dash_charge = 0.0
	elif space_pressed and not _space_was_pressed and dash_cooldown_remaining <= 0.0 and not dash_active:
		dash_charging = true
		_dash_charge_time = 0.0
		dash_charge = 0.0
		charge_direction = input_direction if input_direction != Vector2.ZERO else _last_direction
	elif dash_charging and space_pressed:
		_dash_charge_time = minf(_dash_charge_time + delta, max_dash_charge_time)
		dash_charge = _dash_charge_time / max_dash_charge_time
		if input_direction != Vector2.ZERO:
			charge_direction = input_direction
		elif velocity.length_squared() > 16.0:
			charge_direction = velocity.normalized()
		else:
			charge_direction = _last_direction
		dash_fully_charged = dash_charge >= 0.999
	elif dash_charging and not space_pressed:
		dash_charging = false
		_start_dash()
	_space_was_pressed = space_pressed
	dash_cooldown_remaining = maxf(dash_cooldown_remaining - delta, 0.0)

	if movement == null:
		wall_pressure_direction = Vector2.ZERO
		return

	if dash_active:
		velocity = dash_direction * current_dash_speed
	else:
		# Outside a dash, the movement profile controls motion as usual.
		velocity = movement.calculate_velocity(velocity, input_direction, delta)

	# CharacterBody2D continues to resolve collisions during a dash.
	move_and_slide()
	wall_pressure_direction = _calculate_wall_pressure()

	if dash_active:
		dash_time_remaining -= delta
		if get_slide_collision_count() > 0:
			# An impact ends the dash and preserves a small amount of momentum.
			dash_active = false
			velocity *= 0.3
		elif dash_time_remaining <= 0.0:
			dash_active = false
			velocity *= 0.55


func _start_dash() -> void:
	dash_fully_charged = false
	dash_direction = input_direction
	if dash_direction == Vector2.ZERO:
		dash_direction = charge_direction
	current_dash_speed = lerpf(min_dash_speed, max_dash_speed, dash_charge)
	current_dash_duration = lerpf(min_dash_duration, max_dash_duration, dash_charge)
	dash_active = true
	dash_time_remaining = current_dash_duration
	dash_cooldown_remaining = dash_cooldown
	velocity = dash_direction * current_dash_speed


func receive_ping(source_position: Vector2, is_echo: bool) -> void:
	_ping_emitter.receive_ping(source_position, is_echo)


func receive_ping_details(
	source_position: Vector2,
	is_echo: bool,
	charge: float,
	tone_index: int,
	frequency: float,
	wave_id: int
) -> void:
	_ping_emitter.receive_ping_details(source_position, is_echo, charge, tone_index, frequency, wave_id)



func _calculate_wall_pressure() -> Vector2:
	var pressure := Vector2.ZERO
	for index in range(get_slide_collision_count()):
		var normal := get_slide_collision(index).get_normal()
		# Squash the blob only when input pushes into a collision surface.
		var intensity := -input_direction.dot(normal)
		if intensity > 0.0:
			pressure += -normal * intensity
	return pressure.limit_length(1.0)


func _read_direction() -> Vector2:
	var arrow_direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	# Physical key codes keep WASD consistent across keyboard layouts.
	var wasd_direction := Vector2(
		int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A)),
		int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W))
	)
	return (arrow_direction + wasd_direction).limit_length(1.0)

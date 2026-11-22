class_name TopDownMovement
extends Resource
## Configuration resource that separates movement response from the player controller.

@export_category("Movement")
## Maximum speed in pixels per second.
@export_range(1.0, 1000.0, 1.0, "or_greater") var max_speed: float = 260.0
## How quickly velocity approaches a pressed direction.
@export_range(1.0, 5000.0, 1.0, "or_greater") var acceleration: float = 900.0
## How quickly velocity falls when the player releases the controls.
@export_range(1.0, 5000.0, 1.0, "or_greater") var deceleration: float = 950.0


func calculate_velocity(current_velocity: Vector2, direction: Vector2, delta: float) -> Vector2:
	# Move current velocity toward its target without changing it instantly.
	var clamped_direction := direction.limit_length(1.0)
	var target_velocity := clamped_direction * max_speed
	var rate := acceleration if clamped_direction != Vector2.ZERO else deceleration
	return current_velocity.move_toward(target_velocity, rate * delta)

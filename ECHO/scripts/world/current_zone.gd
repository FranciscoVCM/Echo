class_name CurrentZone
extends Node2D
## A band of strong current (wind / water flow). It pushes the player along `direction`
## faster than they can walk, so going against it needs a DASH. Going with it is easy, so
## it can never trap anyone. Pings and vision pass through.

@export var size := Vector2(220, 140)  ## x: across the passage, y: thickness to cross
@export var direction := Vector2.UP  ## where it pushes
@export var strength := 360.0

var _time := 0.0


func _ready() -> void:
	z_index = -1  # above the CMYK pass (added after it), below the creatures
	rotation = direction.angle() + PI * 0.5  # local -y points along the push


func contains(point: Vector2) -> bool:
	var local := to_local(point)
	return absf(local.x) <= size.x * 0.5 and absf(local.y) <= size.y * 0.5


## Applies the push to a player for this physics step (skipped while dashing).
func push(player: PlayerController, delta: float) -> void:
	if player.dash_active or not contains(player.global_position):
		return
	player.move_and_collide(direction.normalized() * strength * delta)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half, size), Color(0.55, 0.75, 1.0, 0.12))
	# Streaks flowing along -y (the push direction in local space).
	for index in range(12):
		var lane := -half.x + size.x * (index + 0.5) / 12.0
		var offset := fposmod(_time * 260.0 + index * 37.0, size.y + 40.0)
		var y := half.y - offset
		var start := Vector2(lane + sin(_time * 3.0 + index) * 4.0, clampf(y + 22.0, -half.y, half.y))
		var finish := Vector2(lane, clampf(y, -half.y, half.y))
		draw_line(start, finish, Color(0.85, 0.92, 1.0, 0.45), 2.0, true)
	for side in [-1.0, 1.0]:
		draw_line(Vector2(-half.x, side * half.y), Vector2(half.x, side * half.y), Color(0.8, 0.9, 1.0, 0.2), 1.5, true)
	# Chevrons show which way it pushes.
	for index in range(3):
		var at := Vector2((index - 1) * size.x * 0.3, fposmod(_time * 60.0, 30.0) - 15.0)
		draw_polyline(PackedVector2Array([at + Vector2(-10, 6), at + Vector2(0, -4), at + Vector2(10, 6)]), Color(1, 1, 1, 0.35), 2.0, true)

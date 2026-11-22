class_name VassalM
extends VassalBody
## M - Bosque do Toque (touch). M is curled up in thorns and does not let anyone near.
## Rushing towards it (or shouting with strong pings) makes its thorns bristle; too much
## and it rolls away. Come close slowly (hold Shift), stay beside it until it warms up,
## and then it will accept a soft touch: a gentle, short Ping.

enum Phase { APPROACH, WARM, SOFT }

const TENSION_RADIUS := 420.0
const CALM_SPEED := 140.0
const CLOSE := 125.0
const WARM_TIME := 5.0

var world: Node
var anchors: Array[Vector2] = []
var phase := Phase.APPROACH
var tension := 0.0
var warmth := 0.0
var _rolling_to := Vector2.INF
var _hinted := false


func _init() -> void:
	letter = "M"
	base_color = Color(0.95, 0.22, 0.66)
	radius = 56.0
	awake = false
	glow = 0.1
	extra_draw = _draw_thorns


func _ready() -> void:
	super._ready()
	mode_completed.connect(_on_mode_completed)
	pinged.connect(_on_pinged)


func wake() -> void:
	if awake or completed:
		return
	awake = true
	world.say([
		["M", "(Espinhos. Um corpo enrolado que estremece com cada passo teu.)"],
		["K", "A M tem medo do toque. Não a apresses."],
	], "M", "m_wake")


func _physics_process(delta: float) -> void:
	if not awake or completed or EchoBlob.player == null:
		return
	if _rolling_to != Vector2.INF:
		var offset := _rolling_to - global_position
		if offset.length() < 8.0:
			_rolling_to = Vector2.INF
		else:
			velocity = offset.normalized() * 260.0
			move_and_slide()
		return
	var player_node := EchoBlob.player
	var distance := player_node.global_position.distance_to(global_position)
	var speed: float = (player_node.get("velocity") as Vector2).length()
	if phase != Phase.SOFT:
		if distance < TENSION_RADIUS and speed > CALM_SPEED:
			tension = minf(tension + delta * 1.5, 1.0)
		else:
			tension = maxf(tension - delta * 0.45, 0.0)
		if tension >= 1.0:
			_roll_away()
			return
		if distance < CLOSE and tension < 0.5:
			phase = Phase.WARM
			warmth = minf(warmth + delta / WARM_TIME, 1.0)
			glow = 0.1 + warmth * 0.4
			if warmth >= 1.0:
				phase = Phase.SOFT
				start_soft()
				world.say([["M", "(Os espinhos baixam. Ela espera um toque leve.)"]], "M")
		elif distance >= CLOSE:
			warmth = maxf(warmth - delta / (WARM_TIME * 2.5), 0.0)


func _roll_away() -> void:
	tension = 0.0
	warmth *= 0.3
	phase = Phase.APPROACH
	_jolt = 1.0
	var player_position := EchoBlob.player.global_position
	var best := global_position
	for anchor in anchors:
		if anchor.distance_to(player_position) > best.distance_to(player_position):
			best = anchor
	_rolling_to = best
	if not _hinted:
		_hinted = true
		var key := "Shift"
		var game := get_node_or_null("/root/Game")
		if game != null:
			key = game.key_label("echo_slow")
		world.say([["K", "Devagar... Mantém %s para andares com cuidado." % key]], "K")


func _on_pinged(wave: PingWave) -> void:
	if not awake or completed:
		return
	var strong := wave.get_charge() > soft_max_charge
	if phase == Phase.SOFT and strong:
		mode = Mode.IDLE
		phase = Phase.WARM
		warmth = 0.5
		tension = 0.6
	elif phase != Phase.SOFT and strong and wave.global_position.distance_to(global_position) < 500.0:
		tension = minf(tension + 0.45, 1.0)


func _on_mode_completed(_mode: int) -> void:
	completed = true
	glow = 1.0
	world.on_vassal_completed("M")


func _draw_thorns(_body: VassalBody) -> void:
	if completed:
		return
	var curl := 1.0 if phase != Phase.SOFT else 0.25
	var length := (10.0 + 26.0 * tension) * curl
	var thorn_color := Color(0.25, 0.1, 0.2, 0.95)
	for index in range(18):
		var angle := TAU * index / 18.0 + sin(_time * 0.7) * 0.05
		var base := Vector2.RIGHT.rotated(angle) * radius * 0.92
		var tip := Vector2.RIGHT.rotated(angle) * (radius + length)
		var side := Vector2.RIGHT.rotated(angle + PI * 0.5) * 6.0
		draw_colored_polygon(PackedVector2Array([base + side, tip, base - side]), thorn_color)
	if warmth > 0.0:
		draw_arc(Vector2.ZERO, radius + 18.0, -PI * 0.5, -PI * 0.5 + TAU * warmth, 64, Color(1.0, 0.6, 0.75, 0.9), 4.0, true)
	if phase == Phase.APPROACH and tension > 0.05:
		draw_arc(Vector2.ZERO, radius + 26.0, -PI * 0.5, -PI * 0.5 + TAU * tension, 64, Color(1.0, 0.3, 0.3, 0.7), 3.0, true)

class_name VassalY
extends VassalBody
## Y - Grutas da Vista (sight). Y lost its light and hides from being looked at: when you
## come near it slips away into the dark. Its light broke into three sparks hidden in the
## chamber (only a Ping reveals them). Each spark you help returns to Y and lights the
## room. With its light back, Y stops hiding and listens for its own colour: Mi (yellow).

const SPARK_NOTES := [1, 3, 6]

var world: Node
var anchors: Array[Vector2] = []
var spark_positions: Array[Vector2] = []
var sparks_returned := 0
var _flee_target := Vector2.INF


func _init() -> void:
	letter = "Y"
	base_color = Color(1.0, 0.9, 0.15)
	radius = 56.0
	awake = false
	glow = 0.1


func _ready() -> void:
	super._ready()
	mode_completed.connect(_on_mode_completed)


func wake() -> void:
	if awake or completed:
		return
	awake = true
	for index in range(spark_positions.size()):
		var blob: EchoBlob = world.spawn_blob({
			"id": "vassal:Y:%d" % index, "pos": [spark_positions[index].x, spark_positions[index].y],
			"note": SPARK_NOTES[index], "need": "NOTE", "hidden": true, "radius": 16.0,
		}, "vista")
		blob.freed.connect(_on_spark_freed)
		if blob.is_freed():
			_on_spark_freed.call_deferred(blob)



## Said by K when you first come close to this vassal after it woke up.
func meet_lines() -> Array:
	return [
		["Y", "(Uma luz fraca treme... e foge quando te aproximas.)"],
		["K", "Esta vassala tem vergonha de ser vista sem a sua luz. Foge sempre que chegas perto."],
		["K", "A luz dela partiu-se em três faíscas, escondidas aqui no escuro. Só um ping as revela. Ajuda-as, e elas voltam para ela."],
	]


func light_radius() -> float:
	if completed:
		return 520.0
	return 120.0 + 120.0 * sparks_returned


func _physics_process(delta: float) -> void:
	if not awake or completed or sparks_returned >= spark_positions.size() or EchoBlob.player == null:
		return
	var player_position := EchoBlob.player.global_position
	if _flee_target == Vector2.INF and player_position.distance_to(global_position) < 300.0:
		var best := global_position
		for anchor in anchors:
			if anchor.distance_to(player_position) > best.distance_to(player_position):
				best = anchor
		if best != global_position:
			_flee_target = best
			_jolt = 0.6
	if _flee_target != Vector2.INF:
		var offset := _flee_target - global_position
		if offset.length() < 8.0:
			_flee_target = Vector2.INF
			velocity = Vector2.ZERO
		else:
			velocity = offset.normalized() * 190.0
			slide()
			if get_slide_collision_count() > 0 and velocity.length() < 5.0:
				_flee_target = Vector2.INF
	var _unused := delta


func _on_spark_freed(blob: EchoBlob) -> void:
	sparks_returned += 1
	glow = 0.15 + 0.28 * sparks_returned
	var tween := blob.create_tween()
	tween.tween_property(blob, "global_position", global_position, 1.2).set_trans(Tween.TRANS_SINE)
	# Merges into Y: removed, so it can't reappear on top of it.
	tween.tween_callback(blob.queue_free)
	sing(SPARK_NOTES[mini(sparks_returned - 1, 2)], -2.0)
	if sparks_returned >= spark_positions.size():
		_flee_target = Vector2.INF
		start_note(2)
		world.say([
			["Y", "...Já não preciso de me esconder."],
			["Y", "Chama-me pela minha cor. A cor da luz."],
		], "Y")
	else:
		world.say([["Y", "(A luz cresce um pouco: %d de 3.)" % sparks_returned]], "Y")


func _on_mode_completed(_mode: int) -> void:
	completed = true
	glow = 1.0
	world.on_vassal_completed("Y")

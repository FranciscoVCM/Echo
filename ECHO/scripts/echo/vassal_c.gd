class_name VassalC
extends VassalBody
## C - Vale dos Ecos (hearing). C lost its voice: it can only hum a broken little song.
## Three echo stones around it each ring with one note when pinged (any note) - they are
## instruments to find the notes by ear. Answer C's song note by note and its voice (and
## the cyan of the world) comes back. No timer: listening, trying, comparing.

const SONG := [4, 0, 2]  # the order C hums (Sol, Dó, Mi)
const STONE_NOTES := [0, 2, 4]  # notes of the stones left -> right (Dó, Mi, Sol)

var world: Node
var stone_positions: Array[Vector2] = []
var stones: Array[EchoStone] = []


func _init() -> void:
	letter = "C"
	base_color = Color(0.1, 0.85, 0.95)
	radius = 60.0
	awake = false
	glow = 0.1
	hum_interval = 6.5


func _ready() -> void:
	super._ready()
	mode_completed.connect(_on_mode_completed)


func wake() -> void:
	if awake or completed:
		return
	awake = true
	for index in range(stone_positions.size()):
		var stone := EchoStone.new()
		stone.note = STONE_NOTES[index]
		stone.position = stone_positions[index]
		get_parent().add_child(stone)
		stones.append(stone)
	start_melody(PackedInt32Array(SONG))
	world.say([
		["C", "(Um zumbido partido... três notas, e depois silêncio.)"],
		["K", "A C perdeu a voz. As pedras à volta ainda se lembram de como soa. Ouve-as."],
	], "C", "c_wake")


func _on_mode_completed(_mode: int) -> void:
	completed = true
	glow = 1.0
	for stone in stones:
		stone.colored = true
	world.on_vassal_completed("C")

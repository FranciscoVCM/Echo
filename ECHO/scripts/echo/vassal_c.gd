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
		stone.colored = true  # the stones are the reference: colour + name shown
		stone.position = stone_positions[index]
		get_parent().add_child(stone)
		stones.append(stone)
	start_melody(PackedInt32Array(SONG))



## Said by K when you first come close to this vassal after it woke up.
func meet_lines() -> Array:
	return [
		["C", "(Um zumbido partido... três notas, e depois silêncio.)"],
		["K", "Esta vassala perdeu a voz. Só consegue cantar três notas, baixinho, sem cor."],
		["K", "As três pedras à volta lembram-se dos sons. Vai até uma e chama: ela toca a sua nota."],
		["K", "Descobre que notas são as da canção, e devolve-lhas uma a uma, pela ordem em que ela as canta. Os pontos por cima dela mostram quantas já acertaste."],
	]


func _on_mode_completed(_mode: int) -> void:
	completed = true
	glow = 1.0
	for stone in stones:
		stone.colored = true
	world.on_vassal_completed("C")

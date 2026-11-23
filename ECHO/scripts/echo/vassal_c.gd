class_name VassalC
extends VassalBody
## C - Vale dos Ecos (hearing). C lost its voice: it can only hum a broken little song,
## without colour. Around it stand three echo stones, each showing its colour and note:
## they are C's instruments. You don't answer C directly - you PLAY its song on the
## stones: go to the right stone, in the order C hums, and call it up close.
## Pinging C itself asks it to hum the song again. No timer; a wrong stone keeps your
## progress and C hums the note it is waiting for.

const SONG := [4, 0, 2, 0]  # the order C hums (Sol, Dó, Mi, Dó)
const STONE_NOTES := [0, 2, 4]  # stones left -> right (Dó, Mi, Sol)

var world: Node
var stone_positions: Array[Vector2] = []
var stones: Array[EchoStone] = []


func _init() -> void:
	letter = "C"
	base_color = Color(0.1, 0.85, 0.95)
	radius = 60.0
	awake = false
	glow = 0.1
	hum_interval = 8.0


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
		stone.rung.connect(_on_stone_rung)
		stones.append(stone)
	start_melody(PackedInt32Array(SONG))


## Said by K when you first come close to this vassal after it woke up.
func meet_lines() -> Array:
	return [
		["C", "(Um zumbido partido... quatro notas, sem cor.)"],
		["K", "Esta vassala perdeu a voz. Só consegue trautear a sua canção, baixinho."],
		["K", "As três pedras à volta eram os instrumentos dela. Vai até uma e chama-a de perto: ela toca a sua nota."],
		["K", "Toca a canção dela nas pedras, pela ordem em que ela a canta. Se quiseres ouvi-la outra vez, chama-a a ela."],
	]


## Pinging C itself: it hums its song again (it doesn't take answers directly).
func receive_ping_wave(wave: PingWave) -> void:
	if wave.is_echo() or completed:
		return
	EchoMarker.spawn(global_position, _current_color(), radius, get_tree())
	pinged.emit(wave)
	_jolt = 0.4
	if awake and mode == Mode.MELODY:
		hum_melody()
		_hum_timer = hum_interval


func _on_stone_rung(stone: EchoStone) -> void:
	if not awake or completed or mode != Mode.MELODY:
		return
	if stone.note == melody[melody_step]:
		melody_step += 1
		_flash = 1.0
		glow = 0.1 + 0.2 * melody_step
		if melody_step >= melody.size():
			_finish_mode()
	else:
		# Keep the progress; after the stone's ring, C hums the note it is waiting for.
		_jolt = 0.6
		get_tree().create_timer(0.7).timeout.connect(func() -> void:
			if not completed:
				sing(melody[melody_step], 0.0))


func _on_mode_completed(_mode: int) -> void:
	completed = true
	glow = 1.0
	hum_melody()
	world.on_vassal_completed("C")

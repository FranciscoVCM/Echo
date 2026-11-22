class_name EchoNotes
extends RefCounted
## Shared note / colour / chord vocabulary for the Echo world.
##
## PROTOTYPE DEFAULT (reversible, NOT a confirmed group decision):
## the seven natural notes map to the seven rainbow colours, Dó = red ... Si = violet.
## The PingEmitter's 8th tone (C4, "Dó agudo") counts as Dó: blobs listen to the
## pitch class, not the octave.
##
## "Degrees" are scale steps counted from C3 (0 = C3, 7 = C4, 9 = E4 ...). They can go
## above 7 so chords keep a natural voicing (e.g. Sol chord = G3 B3 D4).

const NOTE_COUNT := 7
const NAMES: PackedStringArray = ["Dó", "Ré", "Mi", "Fá", "Sol", "Lá", "Si"]
const LETTERS: PackedStringArray = ["C", "D", "E", "F", "G", "A", "B"]
const COLORS: Array[Color] = [
	Color(0.94, 0.27, 0.27),  # Dó  - vermelho
	Color(1.00, 0.56, 0.16),  # Ré  - laranja
	Color(0.98, 0.86, 0.22),  # Mi  - amarelo
	Color(0.32, 0.82, 0.36),  # Fá  - verde
	Color(0.22, 0.70, 0.96),  # Sol - azul
	Color(0.36, 0.36, 0.92),  # Lá  - anil
	Color(0.74, 0.38, 0.93),  # Si  - violeta
]
## Diatonic triads built on each degree of C major (root, third, fifth).
const CHORD_NAMES: PackedStringArray = [
	"Dó maior", "Ré menor", "Mi menor", "Fá maior", "Sol maior", "Lá menor", "Si diminuto"
]
const VOICE_SAMPLE_RATE := 22050
const VOICE_DURATION := 0.42

static var _voice_cache: Dictionary = {}


static func pitch_class(degree: int) -> int:
	return posmod(degree, NOTE_COUNT)


static func name_for(degree: int) -> String:
	return NAMES[pitch_class(degree)]


static func color_for(degree: int) -> Color:
	return COLORS[pitch_class(degree)]


static func chord_name_for(degree: int) -> String:
	return CHORD_NAMES[pitch_class(degree)]


## Extra degrees (third and fifth) that turn a single note into its diatonic triad.
static func triad_extras(root_degree: int) -> PackedInt32Array:
	return PackedInt32Array([root_degree + 2, root_degree + 4])


static func frequency_for_degree(degree: int) -> float:
	return PingEmitter.frequency_for_degree(degree)


## A short, soft "creature voice" one octave above the player's Ping, cached per degree.
static func voice_stream(degree: int) -> AudioStreamWAV:
	if _voice_cache.has(degree):
		return _voice_cache[degree]
	var frequency := frequency_for_degree(degree) * 2.0
	var frame_count := int(VOICE_DURATION * VOICE_SAMPLE_RATE)
	var pcm := PackedByteArray()
	pcm.resize(frame_count * 2)
	for frame in range(frame_count):
		var time := float(frame) / VOICE_SAMPLE_RATE
		var attack := minf(time / 0.03, 1.0)
		var release := clampf(1.0 - (time - 0.12) / (VOICE_DURATION - 0.12), 0.0, 1.0)
		var envelope := attack * release * release
		# A small upward glide and vibrato make it sound alive rather than electronic.
		var glide := 1.0 - 0.03 * (1.0 - minf(time / 0.08, 1.0))
		var vibrato := 1.0 + sin(TAU * 6.0 * time) * 0.006
		var phase := TAU * frequency * glide * vibrato * time
		var tone := sin(phase) + sin(phase * 2.0) * 0.1
		var sample := roundi(clampf(tone * 0.22 * envelope, -1.0, 1.0) * 32767.0)
		if sample < 0:
			sample += 65536
		pcm[frame * 2] = sample & 0xFF
		pcm[frame * 2 + 1] = (sample >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = VOICE_SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm
	_voice_cache[degree] = stream
	return stream

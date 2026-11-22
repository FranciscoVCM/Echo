class_name Vassals
extends RefCounted
## Factory + shared helpers for the three themed vassals. Each vassal sleeps until every
## blob of its area has been helped; then it wakes and its challenge begins.

static func create(letter: String, world: Node) -> VassalBody:
	var body: VassalBody
	match letter:
		"Y":
			body = VassalY.new()
		"C":
			body = VassalC.new()
		"M":
			body = VassalM.new()
	body.set("world", world)
	return body

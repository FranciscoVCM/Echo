class_name EchoBlobGroup
extends Node2D
## Blobs that can only be helped together. Put EchoBlob instances as children.
##
## SAME_WAVE   - one single wave must reach every member with its note
##               (e.g. two separated blobs: find the spot where one Ping touches both).
## TIME_WINDOW - every member must hear its own note within `window_seconds` of the first.
##               Solvable with single notes by switching quickly; a chord containing all
##               their notes can do it in one Ping (chords help, never required).

signal resolved(group: EchoBlobGroup)

enum Mode { SAME_WAVE, TIME_WINDOW }

@export var mode: Mode = Mode.SAME_WAVE
@export_range(1.0, 20.0, 0.5) var window_seconds := 6.0
## How long a partial SAME_WAVE mark stays visible before the blob feels alone again.
@export_range(0.3, 4.0, 0.1) var partial_mark_duration := 1.6
@export var draw_links := true

var members: Array[EchoBlob] = []
var _resolved := false
var _wave_hits: Dictionary = {}
var _window_remaining := 0.0
var _window_hits: Dictionary = {}
var _time := 0.0


func _ready() -> void:
	for child in get_children():
		if child is EchoBlob:
			var blob := child as EchoBlob
			blob.group = self
			members.append(blob)


func is_resolved() -> bool:
	return _resolved


func on_member_pinged(blob: EchoBlob, matched: bool, wave_id: int) -> void:
	if _resolved or not matched:
		return
	match mode:
		Mode.SAME_WAVE:
			if not _wave_hits.has(wave_id):
				_wave_hits[wave_id] = {}
			var hits: Dictionary = _wave_hits[wave_id]
			hits[blob] = true
			blob.group_mark = 1.0
			if hits.size() >= members.size():
				_resolve()
		Mode.TIME_WINDOW:
			if _window_remaining <= 0.0:
				_window_remaining = window_seconds
				_window_hits.clear()
			_window_hits[blob] = true
			blob.group_mark = 1.0
			if _window_hits.size() >= members.size():
				_resolve()


func _process(delta: float) -> void:
	_time += delta
	if not _resolved:
		match mode:
			Mode.SAME_WAVE:
				var any_marked := false
				for member in members:
					if member.group_mark > 0.0:
						member.group_mark = maxf(member.group_mark - delta / partial_mark_duration, 0.0)
						if member.group_mark <= 0.0:
							member.droop()
						any_marked = true
				if not any_marked:
					_wave_hits.clear()
			Mode.TIME_WINDOW:
				if _window_remaining > 0.0:
					_window_remaining -= delta
					var ratio := maxf(_window_remaining / window_seconds, 0.0)
					for member in members:
						member.group_window_ratio = ratio if _window_hits.has(member) else -1.0
					if _window_remaining <= 0.0:
						for member in members:
							member.group_mark = 0.0
							member.group_window_ratio = -1.0
							if _window_hits.has(member):
								member.droop()
						_window_hits.clear()
	queue_redraw()


func _resolve() -> void:
	_resolved = true
	_window_remaining = 0.0
	for member in members:
		member.free_blob()
	resolved.emit(self)


func _draw() -> void:
	if not draw_links or members.size() < 2:
		return
	# Soft threads between members the player can currently see: a hint that they belong together.
	for index in range(members.size()):
		var first := members[index]
		var second := members[(index + 1) % members.size()]
		if members.size() == 2 and index == 1:
			break
		if not _is_shown(first) or not _is_shown(second):
			continue
		var alpha := minf(first.modulate.a, second.modulate.a)
		var lit := maxf(first.group_mark, second.group_mark)
		if _resolved:
			lit = 0.6 + sin(_time * 2.5) * 0.2
		var start := to_local(first.global_position)
		var finish := to_local(second.global_position)
		var color := first.get_true_color().lerp(second.get_true_color(), 0.5)
		_draw_dotted(start, finish, Color(color, (0.18 + lit * 0.6) * alpha), 2.0 + lit * 1.5)


func _is_shown(blob: EchoBlob) -> bool:
	return blob.visible and blob.modulate.a > 0.05 and blob.state != EchoBlob.State.ABSORBED and blob.state != EchoBlob.State.FOLLOWING


func _draw_dotted(start: Vector2, finish: Vector2, color: Color, width: float) -> void:
	var length := start.distance_to(finish)
	var direction := (finish - start) / maxf(length, 0.001)
	var drift := fmod(_time * 18.0, 18.0)
	var distance := drift
	while distance < length:
		var segment_end := minf(distance + 9.0, length)
		draw_line(start + direction * distance, start + direction * segment_end, color, width, true)
		distance += 18.0

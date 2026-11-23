class_name EchoBlobGroup
extends Node2D
## Blobs that are helped together. Put EchoBlob instances as children.
##
## SAME_WAVE - members share one colour; ONE wave must reach all of them
##             (e.g. blobs around a rock: find the spot where a single Ping touches all).
## CLUSTER   - members of different colours huddled together; each needs its own note,
##             in any order, no time limit. A chord holding their notes does it in one Ping.

signal resolved(group: EchoBlobGroup)

enum Mode {
	SAME_WAVE,
	CLUSTER,
	TOGETHER,  ## shy chorus: ONE wave must wake them all; a startle resets them all; freed together
	TIME_WINDOW,  ## different colours; all must hear their note within `window_seconds` of the first
}

@export var mode: Mode = Mode.SAME_WAVE
## How long a partial SAME_WAVE mark stays visible before the blob feels alone again.
@export_range(0.3, 4.0, 0.1) var partial_mark_duration := 1.6
@export var draw_links := true
## TIME_WINDOW: always long enough to do it note by note (chords only make it easier).
@export_range(4.0, 30.0, 0.5) var window_seconds := 13.0
var _window_remaining := 0.0
var _window_hits: Dictionary = {}

var members: Array[EchoBlob] = []
var _resolved := false
var _wave_hits: Dictionary = {}
var _cluster_hits: Dictionary = {}
var _time := 0.0


func _ready() -> void:
	for child in get_children():
		if child is EchoBlob:
			var blob := child as EchoBlob
			blob.group = self
			members.append(blob)
	var all_freed := not members.is_empty()
	for member in members:
		all_freed = all_freed and member.is_freed()
	_resolved = all_freed


func is_resolved() -> bool:
	return _resolved


func on_member_pinged(blob: EchoBlob, matched: bool, wave_id: int) -> void:
	if _resolved or not matched or mode == Mode.TOGETHER:
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
		Mode.CLUSTER:
			_cluster_hits[blob] = true
			blob.group_mark = 1.0
			if _cluster_hits.size() >= members.size():
				_resolve()
		Mode.TIME_WINDOW:
			if _window_remaining <= 0.0:
				_window_remaining = window_seconds
				_window_hits.clear()
			_window_hits[blob] = true
			blob.group_mark = 1.0
			if _window_hits.size() >= members.size():
				_resolve()


## Shy chorus: only a single wave that reaches every sleeping member wakes them.
func on_chorus_pinged(blob: EchoBlob, wave_id: int) -> void:
	if _resolved:
		return
	if not _wave_hits.has(wave_id):
		_wave_hits[wave_id] = {}
	var hits: Dictionary = _wave_hits[wave_id]
	hits[blob] = true
	var sleeping := 0
	for member in members:
		if member.state == EchoBlob.State.LOST:
			sleeping += 1
	if hits.size() >= sleeping:
		_wave_hits.clear()
		for member in members:
			member.group_mark = 0.0
			member.wake_up()
	else:
		blob.stir()


## Startle one and the whole chorus starts its calm over again.
func on_chorus_startled(_source: EchoBlob) -> void:
	for member in members:
		if member.state == EchoBlob.State.WAKING:
			member.startle()


func _process(delta: float) -> void:
	_time += delta
	if mode == Mode.TOGETHER and not _resolved:
		for member in members:
			if member.group_mark > 0.0 and member.state == EchoBlob.State.LOST:
				member.group_mark = maxf(member.group_mark - delta / partial_mark_duration, 0.0)
	if mode == Mode.TOGETHER and not _resolved:
		var all_freed := true
		for member in members:
			all_freed = all_freed and member.is_freed()
		if all_freed:
			_resolved = true
			resolved.emit(self)
	if not _resolved and mode == Mode.TIME_WINDOW and _window_remaining > 0.0:
		_window_remaining -= delta
		var ratio := maxf(_window_remaining / window_seconds, 0.0)
		for member in members:
			member.group_window_ratio = ratio if _window_hits.has(member) else -1.0
		if _window_remaining <= 0.0:
			for member in members:
				if _window_hits.has(member):
					member.droop()
				member.group_mark = 0.0
				member.group_window_ratio = -1.0
			_window_hits.clear()
	if not _resolved and mode == Mode.SAME_WAVE:
		var any_marked := false
		for member in members:
			if member.group_mark > 0.0:
				member.group_mark = maxf(member.group_mark - delta / partial_mark_duration, 0.0)
				if member.group_mark <= 0.0:
					member.droop()
				any_marked = true
		if not any_marked:
			_wave_hits.clear()
	queue_redraw()


func _resolve() -> void:
	_resolved = true
	for member in members:
		member.free_blob()
	resolved.emit(self)


func _draw() -> void:
	if not draw_links or members.size() < 2:
		return
	# Soft threads between visible members: a hint that they belong together.
	for index in range(members.size()):
		if members.size() == 2 and index == 1:
			break
		var first := members[index]
		var second := members[(index + 1) % members.size()]
		if not _is_shown(first) or not _is_shown(second):
			continue
		var alpha := minf(first.modulate.a, second.modulate.a)
		var lit := maxf(first.group_mark, second.group_mark)
		if _resolved:
			lit = 0.6 + sin(_time * 2.5) * 0.2
		var color := first._display_color().lerp(second._display_color(), 0.5)
		_draw_dotted(to_local(first.global_position), to_local(second.global_position), Color(color, (0.18 + lit * 0.6) * alpha), 2.0 + lit * 1.5)


func _is_shown(blob: EchoBlob) -> bool:
	return blob.visible and blob.modulate.a > 0.05


func _draw_dotted(start: Vector2, finish: Vector2, color: Color, width: float) -> void:
	var length := start.distance_to(finish)
	var direction := (finish - start) / maxf(length, 0.001)
	var distance := fmod(_time * 18.0, 18.0)
	while distance < length:
		var segment_end := minf(distance + 9.0, length)
		draw_line(start + direction * distance, start + direction * segment_end, color, width, true)
		distance += 18.0

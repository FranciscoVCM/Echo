class_name VisibilityPolygon
extends RefCounted
## 2D visibility polygon (isovist) over a set of line segments -- an O(N log N)
## active-edge rotational sweep with a binary heap of segments ordered by
## distance from the observer. A vertex is emitted only when the nearest segment
## changes, so a polygon edge never straddles a wall (unlike a naive "cast a ray
## per endpoint, connect nearest hits by angle" sweep, which cuts across walls at
## deep corners -- letting you "see" around a corner into the next room).
##
## Ported by hand from byronknoll/visibility-polygon-js (public domain,
## https://github.com/byronknoll/visibility-polygon-js). Function names/structure
## follow the original for auditability. This addon is released under CC0 1.0.
##
## Segment convention: `segments` is an Array; each element is [Vector2, Vector2]
## (a pair of endpoints). Segments must not intersect except at shared endpoints;
## call break_intersections() first if yours might. Determinism: endpoints are
## angle-sorted with a stable tie-break on (segment index, endpoint), so compute()
## is a pure function -- same input yields a bit-identical polygon.
## Coincidence tolerance. byronknoll uses 1e-7 for normalized coords; a slightly
## larger epsilon suits world units (metres over tens of units) and avoids float
## dropouts at shared vertices.
const VP_EPSILON: float = 0.00001
## Visibility polygon from `position` over `segments`. An outer bounding box is
## added automatically so the polygon never extends to infinity. Returns the
## polygon vertices in angular order.
static func compute(position: Vector2, segments: Array) -> PackedVector2Array:
	var bounded: Array = []
	var minv := position
	var maxv := position
	for s in segments:
		minv.x = min(minv.x, min(s[0].x, s[1].x))
		minv.y = min(minv.y, min(s[0].y, s[1].y))
		maxv.x = max(maxv.x, max(s[0].x, s[1].x))
		maxv.y = max(maxv.y, max(s[0].y, s[1].y))
		bounded.append([s[0], s[1]])
	minv -= Vector2.ONE
	maxv += Vector2.ONE
	bounded.append([Vector2(minv.x, minv.y), Vector2(maxv.x, minv.y)])
	bounded.append([Vector2(maxv.x, minv.y), Vector2(maxv.x, maxv.y)])
	bounded.append([Vector2(maxv.x, maxv.y), Vector2(minv.x, maxv.y)])
	bounded.append([Vector2(minv.x, maxv.y), Vector2(minv.x, minv.y)])
	var polygon := PackedVector2Array()
	var sorted := _sort_points(position, bounded)
	var seg_map: Array = []
	seg_map.resize(bounded.size())
	seg_map.fill(-1)
	var heap: Array = []
	var start := Vector2(position.x + 1.0, position.y)
	for i in bounded.size():
		var a1 := _angle(bounded[i][0], position)
		var a2 := _angle(bounded[i][1], position)
		var active := false
		if a1 > -180.0 and a1 <= 0.0 and a2 <= 180.0 and a2 >= 0.0 and a2 - a1 > 180.0: active = true
		if a2 > -180.0 and a2 <= 0.0 and a1 <= 180.0 and a1 >= 0.0 and a1 - a2 > 180.0: active = true
		if active:
			_insert(i, heap, position, bounded, start, seg_map)
	var i := 0
	while i < sorted.size():
		var extend := false
		var shorten := false
		var orig := i
		var vertex: Vector2 = bounded[sorted[i][0]][sorted[i][1]]
		var old_segment: int = heap[0]
		while true:
			if seg_map[sorted[i][0]] != -1:
				if sorted[i][0] == old_segment:
					extend = true
					vertex = bounded[sorted[i][0]][sorted[i][1]]
				_remove(seg_map[sorted[i][0]], heap, position, bounded, vertex, seg_map)
			else:
				_insert(sorted[i][0], heap, position, bounded, vertex, seg_map)
				if heap[0] != old_segment:
					shorten = true
			i += 1
			if i == sorted.size(): break
			if not (sorted[i][2] < sorted[orig][2] + VP_EPSILON): break
		if extend:
			polygon.append(vertex)
			var cur := _intersect_lines(bounded[heap[0]][0], bounded[heap[0]][1], position, vertex)
			if cur.x != INF and not _equal(cur, vertex): polygon.append(cur)
		elif shorten:
			var a := _intersect_lines(bounded[old_segment][0], bounded[old_segment][1], position, vertex)
			var b := _intersect_lines(bounded[heap[0]][0], bounded[heap[0]][1], position, vertex)
			if a.x != INF: polygon.append(a)
			if b.x != INF: polygon.append(b)
	return polygon
## Visibility polygon clipped to the axis-aligned rectangle [viewport_min,
## viewport_max]. Segments are split at the viewport borders and only in-view
## pieces kept, then the viewport edges are added and compute() is run. Faster
## than compute() when many segments lie outside the viewport. `position` should
## be inside the viewport.
static func compute_viewport(position: Vector2, segments: Array, viewport_min: Vector2, viewport_max: Vector2) -> PackedVector2Array:
	var vmin := viewport_min
	var vmax := viewport_max
	var viewport := [
		Vector2(vmin.x, vmin.y), Vector2(vmax.x, vmin.y),
		Vector2(vmax.x, vmax.y), Vector2(vmin.x, vmax.y)]
	var clipped: Array = []
	for s in segments:
		var p1: Vector2 = s[0]
		var p2: Vector2 = s[1]
		if p1.x < vmin.x and p2.x < vmin.x: continue
		if p1.y < vmin.y and p2.y < vmin.y: continue
		if p1.x > vmax.x and p2.x > vmax.x: continue
		if p1.y > vmax.y and p2.y > vmax.y: continue
		var intersections: Array = []
		for j in viewport.size():
			var k := (j + 1) % viewport.size()
			var it := _intersect_lines(p1, p2, viewport[j], viewport[k])
			if it.x == INF: continue
			if not _on_segment(it, p1, p2): continue
			if not _on_segment(it, viewport[j], viewport[k]): continue
			if _equal(it, p1) or _equal(it, p2): continue
			intersections.append(it)
		var seg_start := p1
		while intersections.size() > 0:
			var end_index := 0
			var end_dis := _distance(seg_start, intersections[0])
			for j in range(1, intersections.size()):
				var dis := _distance(seg_start, intersections[j])
				if dis < end_dis:
					end_dis = dis
					end_index = j
			var piece_end: Vector2 = intersections[end_index]
			if _in_viewport(seg_start, vmin, vmax) and _in_viewport(piece_end, vmin, vmax):
				clipped.append([seg_start, piece_end])
			seg_start = piece_end
			intersections.remove_at(end_index)
		if _in_viewport(seg_start, vmin, vmax) and _in_viewport(p2, vmin, vmax):
			clipped.append([seg_start, p2])
	var e := VP_EPSILON * 10.0
	clipped.append([Vector2(vmin.x - e, vmin.y - e), Vector2(vmax.x + e, vmin.y - e)])
	clipped.append([Vector2(vmax.x + e, vmin.y - e), Vector2(vmax.x + e, vmax.y + e)])
	clipped.append([Vector2(vmax.x + e, vmax.y + e), Vector2(vmin.x - e, vmax.y + e)])
	clipped.append([Vector2(vmin.x - e, vmax.y + e), Vector2(vmin.x - e, vmin.y - e)])
	return compute(position, clipped)
## Point-in-polygon. Wraps Godot's built-in with a clear contract: a polygon with
## fewer than 3 vertices contains nothing. Argument order matches byronknoll.
static func point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3:
		return false
	return Geometry2D.is_point_in_polygon(point, polygon)
## Triangle-fan indices for a vertex list whose vertex 0 is the fan pivot (e.g.
## the observer) and 1..N are boundary vertices in angular order. Returns one
## PackedInt32Array [0, i, i+1] per boundary edge. A star-shaped polygon (like a
## visibility polygon around its observer) is always validly triangulated this
## way -- useful for Polygon2D.polygons to bypass its auto-triangulation, which
## Geometry2D.triangulate_polygon can fail (return empty) on some outlines.
## count < 3 -> no triangles.
static func fan_indices(vertex_count: int) -> Array:
	var tris: Array = []
	if vertex_count < 3:
		return tris
	for i in range(1, vertex_count - 1):
		tris.append(PackedInt32Array([0, i, i + 1]))
	if vertex_count > 3:
		tris.append(PackedInt32Array([0, vertex_count - 1, 1]))
	return tris
## Converts polygons (each an Array/PackedVector2Array of points) to a flat Array
## of [Vector2, Vector2] segments, closing each polygon loop.
static func convert_to_segments(polygons: Array) -> Array:
	var segments: Array = []
	for poly in polygons:
		var n: int = poly.size()
		for j in n:
			var k := (j + 1) % n
			segments.append([poly[j], poly[k]])
	return segments
## Breaks segments apart so none intersect except at endpoints (O(N^2)). Use on
## input that may self-intersect before calling compute().
static func break_intersections(segments: Array) -> Array:
	var output: Array = []
	for i in segments.size():
		var intersections: Array = []
		for j in segments.size():
			if i == j:
				continue
			var it := _intersect_lines(segments[i][0], segments[i][1], segments[j][0], segments[j][1])
			if it.x == INF:
				continue
			if not _on_segment(it, segments[i][0], segments[i][1]):
				continue
			if not _on_segment(it, segments[j][0], segments[j][1]):
				continue
			if _equal(it, segments[i][0]) or _equal(it, segments[i][1]):
				continue
			intersections.append(it)
		var seg_start: Vector2 = segments[i][0]
		while intersections.size() > 0:
			var end_index := 0
			var end_dis := _distance(seg_start, intersections[0])
			for j in range(1, intersections.size()):
				var dis := _distance(seg_start, intersections[j])
				if dis < end_dis:
					end_dis = dis
					end_index = j
			output.append([seg_start, intersections[end_index]])
			seg_start = intersections[end_index]
			intersections.remove_at(end_index)
		output.append([seg_start, segments[i][1]])
	return output
# --- internal sweep helpers (byronknoll) -------------------------------------

static func _sort_points(position: Vector2, segments: Array) -> Array:
	var points: Array = []
	for i in segments.size():
		for j in 2:
			points.append([i, j, _angle(segments[i][j], position)])
	points.sort_custom(_point_less)
	return points

static func _point_less(a: Array, b: Array) -> bool:
	if a[2] != b[2]: return a[2] < b[2]
	if a[0] != b[0]: return a[0] < b[0]
	return a[1] < b[1]
static func _less_than(index1: int, index2: int, position: Vector2, segments: Array, destination: Vector2) -> bool:
	var inter1 := _intersect_lines(segments[index1][0], segments[index1][1], position, destination)
	var inter2 := _intersect_lines(segments[index2][0], segments[index2][1], position, destination)
	if not _equal(inter1, inter2):
		return _distance(inter1, position) < _distance(inter2, position)
	var end1 := 0
	if _equal(inter1, segments[index1][0]): end1 = 1
	var end2 := 0
	if _equal(inter2, segments[index2][0]): end2 = 1
	var a1 := _angle2(segments[index1][end1], inter1, position)
	var a2 := _angle2(segments[index2][end2], inter2, position)
	if a1 < 180.0:
		if a2 > 180.0: return true
		return a2 < a1
	return a1 < a2
static func _insert(index: int, heap: Array, position: Vector2, segments: Array, destination: Vector2, seg_map: Array) -> void:
	var intersect := _intersect_lines(segments[index][0], segments[index][1], position, destination)
	if intersect.x == INF: return
	var cur := heap.size()
	heap.push_back(index)
	seg_map[index] = cur
	while cur > 0:
		var parent := (cur - 1) / 2
		if not _less_than(heap[cur], heap[parent], position, segments, destination):
			break
		seg_map[heap[parent]] = cur
		seg_map[heap[cur]] = parent
		var temp: int = heap[cur]
		heap[cur] = heap[parent]
		heap[parent] = temp
		cur = parent
static func _remove(index: int, heap: Array, position: Vector2, segments: Array, destination: Vector2, seg_map: Array) -> void:
	seg_map[heap[index]] = -1
	if index == heap.size() - 1:
		heap.pop_back()
		return
	heap[index] = heap.pop_back()
	seg_map[heap[index]] = index
	var cur := index
	var parent := (cur - 1) / 2
	if cur != 0 and _less_than(heap[cur], heap[parent], position, segments, destination):
		while cur > 0:
			parent = (cur - 1) / 2
			if not _less_than(heap[cur], heap[parent], position, segments, destination):
				break
			seg_map[heap[parent]] = cur
			seg_map[heap[cur]] = parent
			var temp: int = heap[cur]
			heap[cur] = heap[parent]
			heap[parent] = temp
			cur = parent
	else:
		while true:
			var left := 2 * cur + 1
			var right := left + 1
			if left < heap.size() and _less_than(heap[left], heap[cur], position, segments, destination) \
					and (right == heap.size() or _less_than(heap[left], heap[right], position, segments, destination)):
				seg_map[heap[left]] = cur
				seg_map[heap[cur]] = left
				var temp: int = heap[left]
				heap[left] = heap[cur]
				heap[cur] = temp
				cur = left
			elif right < heap.size() and _less_than(heap[right], heap[cur], position, segments, destination):
				seg_map[heap[right]] = cur
				seg_map[heap[cur]] = right
				var temp: int = heap[right]
				heap[right] = heap[cur]
				heap[cur] = temp
				cur = right
			else:
				break
static func _angle(a: Vector2, b: Vector2) -> float:
	return atan2(b.y - a.y, b.x - a.x) * 180.0 / PI

static func _angle2(a: Vector2, b: Vector2, c: Vector2) -> float:
	var a3 := _angle(a, b) - _angle(b, c)
	if a3 < 0.0: a3 += 360.0
	if a3 > 360.0: a3 -= 360.0
	return a3

static func _equal(a: Vector2, b: Vector2) -> bool:
	return absf(a.x - b.x) < VP_EPSILON and absf(a.y - b.y) < VP_EPSILON
static func _distance(a: Vector2, b: Vector2) -> float:
	var dx := a.x - b.x
	var dy := a.y - b.y
	return dx * dx + dy * dy
## Intersection point of line a1-a2 with line b1-b2, or Vector2(INF, INF) if
## parallel. Infinite lines (matches byronknoll intersectLines).
static func _intersect_lines(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2) -> Vector2:
	var dbx := b2.x - b1.x
	var dby := b2.y - b1.y
	var dax := a2.x - a1.x
	var day := a2.y - a1.y
	var u_b := dby * dax - dbx * day
	if u_b != 0.0:
		var ua := (dbx * (a1.y - b1.y) - dby * (a1.x - b1.x)) / u_b
		return Vector2(a1.x - ua * -dax, a1.y - ua * -day)
	return Vector2(INF, INF)
## True if point k (assumed collinear) lies within the bounding box of segment i-j.
static func _on_segment(k: Vector2, i: Vector2, j: Vector2) -> bool:
	return (i.x <= k.x or j.x <= k.x) and (k.x <= i.x or k.x <= j.x) \
		and (i.y <= k.y or j.y <= k.y) and (k.y <= i.y or k.y <= j.y)
static func _in_viewport(p: Vector2, vmin: Vector2, vmax: Vector2) -> bool:
	if p.x < vmin.x - VP_EPSILON: return false
	if p.y < vmin.y - VP_EPSILON: return false
	if p.x > vmax.x + VP_EPSILON: return false
	if p.y > vmax.y + VP_EPSILON: return false
	return true

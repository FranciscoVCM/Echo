class_name WorldGeometry
extends Node2D
## Builds the organic world from layout data (see WorldLayout):
##   walkable = union(rooms, corridors) - union(rocks, ridges)
## The resulting outlines never intersect, so they are used directly for collision
## (segments, layer 2: blocks movement, vision and Ping), the fog of war, and for the
## procedural generator's checks (walkable spots, line of sight).

const GRID_CELL := 200.0
const ROCK_COLOR := Color(0.075, 0.085, 0.10)

var regions: Array = []  # Array of Dictionaries (see WorldLayout), plus "polygons"
var outer_loops: Array[PackedVector2Array] = []
var hole_loops: Array[PackedVector2Array] = []
var segments: Array = []  # [Vector2, Vector2]
var _grid: Dictionary = {}
var _rock_polygons: Array[PackedVector2Array] = []
var _body: StaticBody2D
var _outer_orientation := true


func build(layout: Array) -> void:
	z_index = -10
	regions.clear()
	var floor_shapes: Array[PackedVector2Array] = []
	var obstacle_shapes: Array[PackedVector2Array] = []
	for region_data in layout:
		var region: Dictionary = region_data.duplicate()
		var polygons: Array[PackedVector2Array] = []
		for room in region.get("rooms", []):
			polygons.append(noisy_ellipse(room[0], room[1], room[2], room[3], room[4]))
		for corridor in region.get("corridors", []):
			for polygon in Geometry2D.offset_polyline(smooth_polyline(corridor[0]), corridor[1] * 0.5, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
				polygons.append(polygon)
		region["polygons"] = polygons
		floor_shapes.append_array(polygons)
		for rock in region.get("rocks", []):
			obstacle_shapes.append(noisy_ellipse(rock[0], rock[1], rock[1], 0.18, rock[2], 16))
		for ridge in region.get("ridges", []):
			for polygon in Geometry2D.offset_polyline(smooth_polyline(ridge[0]), ridge[1] * 0.5, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
				obstacle_shapes.append(polygon)
		regions.append(region)

	var floor_union := union_all(floor_shapes)
	outer_loops = floor_union[0]
	hole_loops = floor_union[1]
	var obstacle_union := union_all(obstacle_shapes)
	for obstacle in obstacle_union[0]:
		_subtract(obstacle)
	# Fewer segments = cheaper fog of war; 2.5 px of simplification is invisible.
	for index in range(outer_loops.size()):
		outer_loops[index] = simplify(outer_loops[index], 2.5)
	for index in range(hole_loops.size()):
		hole_loops[index] = simplify(hole_loops[index], 2.5)
	_rock_polygons.clear()
	_rock_polygons.append_array(hole_loops)
	_rebuild_segments()
	_build_collision()
	queue_redraw()


# --- Polygon helpers ------------------------------------------------------------------

static func noisy_ellipse(center: Vector2, rx: float, ry: float, noise: float, seed_value: int, points: int = 40) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var p1 := rng.randf() * TAU
	var p2 := rng.randf() * TAU
	var p3 := rng.randf() * TAU
	var polygon := PackedVector2Array()
	for index in range(points):
		var angle := TAU * index / points
		var wobble := 1.0 + noise * (sin(angle * 3.0 + p1) * 0.5 + sin(angle * 5.0 + p2) * 0.3 + sin(angle * 7.0 + p3) * 0.2)
		polygon.append(center + Vector2(cos(angle) * rx, sin(angle) * ry) * wobble)
	return polygon


## Catmull-Rom subdivision so corridors and ridges curve instead of bending sharply.
static func smooth_polyline(points: Array, steps: int = 6) -> PackedVector2Array:
	var source := PackedVector2Array(points)
	if source.size() < 3:
		return source
	var result := PackedVector2Array()
	for index in range(source.size() - 1):
		var p0 := source[maxi(index - 1, 0)]
		var p1 := source[index]
		var p2 := source[index + 1]
		var p3 := source[mini(index + 2, source.size() - 1)]
		for step in range(steps):
			var t := float(step) / steps
			var t2 := t * t
			var t3 := t2 * t
			result.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	result.append(source[source.size() - 1])
	return result


## Ramer-Douglas-Peucker on a closed loop.
static func simplify(loop: PackedVector2Array, epsilon: float) -> PackedVector2Array:
	if loop.size() < 8:
		return loop
	# Split the loop at its two farthest-apart points and simplify both halves.
	var far_index := 0
	for index in range(loop.size()):
		if loop[index].distance_squared_to(loop[0]) > loop[far_index].distance_squared_to(loop[0]):
			far_index = index
	var first := loop.slice(0, far_index + 1)
	var second := loop.slice(far_index)
	second.append(loop[0])
	var result := _rdp(first, epsilon)
	var tail := _rdp(second, epsilon)
	result.resize(result.size() - 1)
	tail.resize(tail.size() - 1)
	result.append_array(tail)
	return result if result.size() >= 3 else loop


static func _rdp(points: PackedVector2Array, epsilon: float) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var start := points[0]
	var finish := points[points.size() - 1]
	var max_distance := 0.0
	var max_index := 0
	for index in range(1, points.size() - 1):
		var distance := points[index].distance_to(Geometry2D.get_closest_point_to_segment(points[index], start, finish))
		if distance > max_distance:
			max_distance = distance
			max_index = index
	if max_distance <= epsilon:
		return PackedVector2Array([start, finish])
	var left := _rdp(points.slice(0, max_index + 1), epsilon)
	var right := _rdp(points.slice(max_index), epsilon)
	left.resize(left.size() - 1)
	left.append_array(right)
	return left


static func signed_area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for index in range(polygon.size()):
		var a := polygon[index]
		var b := polygon[(index + 1) % polygon.size()]
		area += a.x * b.y - b.x * a.y
	return area * 0.5


## Union of many polygons -> [outers, holes]. Holes later covered by other shapes are dropped.
func union_all(shapes: Array[PackedVector2Array]) -> Array:
	var outers: Array[PackedVector2Array] = []
	var holes: Array[PackedVector2Array] = []
	for shape in shapes:
		if shape.size() < 3:
			continue
		var current := shape
		var keep: Array[PackedVector2Array] = []
		for outer in outers:
			if Geometry2D.intersect_polygons(outer, current).is_empty():
				keep.append(outer)
				continue
			var merged := Geometry2D.merge_polygons(outer, current)
			var largest_index := 0
			for index in range(merged.size()):
				if absf(signed_area(merged[index])) > absf(signed_area(merged[largest_index])):
					largest_index = index
			var orientation := signed_area(merged[largest_index]) > 0.0
			for index in range(merged.size()):
				if index == largest_index:
					continue
				if (signed_area(merged[index]) > 0.0) != orientation:
					holes.append(merged[index])
				else:
					keep.append(merged[index])
			current = merged[largest_index]
		keep.append(current)
		outers = keep
	# Drop holes that some shape fills (later shapes may cover an earlier ring's hole).
	var real_holes: Array[PackedVector2Array] = []
	for hole in holes:
		var center := _polygon_inner_point(hole)
		var covered := false
		for shape in shapes:
			if Geometry2D.is_point_in_polygon(center, shape):
				covered = true
				break
		if not covered:
			real_holes.append(hole)
	if not outers.is_empty():
		_outer_orientation = signed_area(outers[0]) > 0.0
	return [outers, real_holes]


func _subtract(obstacle: PackedVector2Array) -> void:
	var new_outers: Array[PackedVector2Array] = []
	for outer in outer_loops:
		if Geometry2D.intersect_polygons(outer, obstacle).is_empty():
			new_outers.append(outer)
			continue
		var clipped := Geometry2D.clip_polygons(outer, obstacle)
		var largest_index := 0
		for index in range(clipped.size()):
			if absf(signed_area(clipped[index])) > absf(signed_area(clipped[largest_index])):
				largest_index = index
		if clipped.is_empty():
			continue
		var orientation := signed_area(clipped[largest_index]) > 0.0
		for index in range(clipped.size()):
			if (signed_area(clipped[index]) > 0.0) == orientation:
				new_outers.append(clipped[index])
			else:
				hole_loops.append(clipped[index])
	outer_loops = new_outers


static func _polygon_inner_point(polygon: PackedVector2Array) -> Vector2:
	var center := Vector2.ZERO
	for point in polygon:
		center += point
	center /= maxf(polygon.size(), 1)
	if Geometry2D.is_point_in_polygon(center, polygon):
		return center
	# Concave: use a triangle centroid that lies inside.
	var triangles := Geometry2D.triangulate_polygon(polygon)
	if triangles.size() >= 3:
		return (polygon[triangles[0]] + polygon[triangles[1]] + polygon[triangles[2]]) / 3.0
	return center


# --- Collision / segments ---------------------------------------------------------------

func _all_loops() -> Array[PackedVector2Array]:
	var loops: Array[PackedVector2Array] = []
	loops.append_array(outer_loops)
	loops.append_array(hole_loops)
	return loops


func _rebuild_segments() -> void:
	segments.clear()
	_grid.clear()
	for loop in _all_loops():
		for index in range(loop.size()):
			_add_segment(loop[index], loop[(index + 1) % loop.size()])


func _add_segment(a: Vector2, b: Vector2) -> void:
	var segment_index := segments.size()
	segments.append([a, b])
	var min_cell := Vector2i(floori(minf(a.x, b.x) / GRID_CELL), floori(minf(a.y, b.y) / GRID_CELL))
	var max_cell := Vector2i(floori(maxf(a.x, b.x) / GRID_CELL), floori(maxf(a.y, b.y) / GRID_CELL))
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			var key := Vector2i(x, y)
			if not _grid.has(key):
				_grid[key] = []
			_grid[key].append(segment_index)


func _build_collision() -> void:
	if _body != null:
		_body.queue_free()
	_body = StaticBody2D.new()
	_body.name = "WorldCollision"
	_body.collision_layer = 2
	_body.collision_mask = 0
	add_child(_body)
	for loop in _all_loops():
		var shape := CollisionPolygon2D.new()
		shape.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
		var closed := loop.duplicate()
		closed.append(loop[0])
		shape.polygon = closed
		_body.add_child(shape)


## A solid obstacle added at runtime (PCG rocks, vassal pillars). Must lie inside the floor.
func add_dynamic_obstacle(polygon: PackedVector2Array) -> void:
	hole_loops.append(polygon)
	_rock_polygons.append(polygon)
	for index in range(polygon.size()):
		_add_segment(polygon[index], polygon[(index + 1) % polygon.size()])
	var shape := CollisionPolygon2D.new()
	shape.polygon = polygon
	_body.add_child(shape)
	queue_redraw()


# --- Queries ----------------------------------------------------------------------------

func _segments_near(rect: Rect2) -> Dictionary:
	var found := {}
	var min_cell := Vector2i(floori(rect.position.x / GRID_CELL), floori(rect.position.y / GRID_CELL))
	var max_cell := Vector2i(floori(rect.end.x / GRID_CELL), floori(rect.end.y / GRID_CELL))
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			for segment_index in _grid.get(Vector2i(x, y), []):
				found[segment_index] = true
	return found


func is_inside_floor(point: Vector2) -> bool:
	var inside := false
	for loop in outer_loops:
		if Geometry2D.is_point_in_polygon(point, loop):
			inside = true
			break
	if not inside:
		return false
	for loop in hole_loops:
		if Geometry2D.is_point_in_polygon(point, loop):
			return false
	return true


func distance_to_wall(point: Vector2, search: float = 300.0) -> float:
	var best := search
	for segment_index in _segments_near(Rect2(point - Vector2(search, search), Vector2(search, search) * 2.0)):
		var segment: Array = segments[segment_index]
		best = minf(best, point.distance_to(Geometry2D.get_closest_point_to_segment(point, segment[0], segment[1])))
	return best


func is_walkable(point: Vector2, margin: float = 30.0) -> bool:
	return is_inside_floor(point) and distance_to_wall(point, margin + 1.0) > margin


func has_line_of_sight(a: Vector2, b: Vector2, extra_polygons: Array = []) -> bool:
	var rect := Rect2(a, Vector2.ZERO).expand(b).grow(2.0)
	for segment_index in _segments_near(rect):
		var segment: Array = segments[segment_index]
		if Geometry2D.segment_intersects_segment(a, b, segment[0], segment[1]) != null:
			return false
	for polygon in extra_polygons:
		var poly: PackedVector2Array = polygon
		for index in range(poly.size()):
			if Geometry2D.segment_intersects_segment(a, b, poly[index], poly[(index + 1) % poly.size()]) != null:
				return false
	return true


func region_at(point: Vector2) -> String:
	for region in regions:
		for polygon in region["polygons"]:
			if Geometry2D.is_point_in_polygon(point, polygon):
				return region["name"]
	return ""


func region_data(name: String) -> Dictionary:
	for region in regions:
		if region["name"] == name:
			return region
	return {}


# --- Drawing ----------------------------------------------------------------------------

func _draw() -> void:
	for region in regions:
		var floor_color: Color = region.get("floor_color", Color(0.3, 0.3, 0.3))
		for polygon in region["polygons"]:
			draw_colored_polygon(polygon, floor_color)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(region["name"])
		# Organic speckles for texture (inside the region's shapes only).
		for polygon in region["polygons"]:
			var bounds := Rect2(polygon[0], Vector2.ZERO)
			for point in polygon:
				bounds = bounds.expand(point)
			var count := int(bounds.get_area() / 9000.0)
			for index in range(count):
				var at := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
				if Geometry2D.is_point_in_polygon(at, polygon):
					var shade := floor_color.darkened(rng.randf_range(0.08, 0.22)) if rng.randf() < 0.7 else floor_color.lightened(rng.randf_range(0.05, 0.12))
					draw_circle(at, rng.randf_range(3.0, 11.0), shade)
	for polygon in _rock_polygons:
		if polygon.size() >= 3:
			draw_colored_polygon(polygon, ROCK_COLOR)
	for loop in _all_loops():
		var closed := loop.duplicate()
		closed.append(loop[0])
		draw_polyline(closed, Color(0.55, 0.6, 0.65, 0.35), 3.0, true)

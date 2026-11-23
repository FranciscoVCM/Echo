class_name ColorGrading
extends Node2D
## World-space full-screen pass drawn between the environment (z < -1) and the creatures
## (z >= 0), so only the environment loses / regains colour. Blobs, pings and the HUD keep
## their colours because they carry gameplay information.
## Besides the global C/M/Y inks: each sense area can be "fully" restored (all its blobs and
## its vassal helped: its ink gets stronger there), and after K the whole world "blooms".

const SHADER: Shader = preload("res://resources/cmyk_grading.gdshader")

var restored := Vector3.ZERO
var brightness := 0.55
## vista, som, tato: 0..1 extra ink where the area was fully cleared.
var area_full := Vector3.ZERO
## 0..1 after the ending: rainbow wash + stronger colour everywhere.
var bloom := 0.0
var _material: ShaderMaterial
var _time := 0.0


func _ready() -> void:
	z_index = -2  # environment is drawn below this; water, currents and creatures above
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	material = _material
	_apply()


## Rects (world space) of vista, som and tato, so the shader knows where each area is.
func set_area_rects(rects: Array) -> void:
	for index in range(mini(rects.size(), 3)):
		var rect: Rect2 = rects[index]
		_material.set_shader_parameter("area_rect_%d" % index, Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))


func set_state(c: float, m: float, y: float, new_brightness: float, animate: bool = true) -> void:
	var target := Vector3(c, m, y)
	if animate:
		var tween := create_tween().set_parallel(true)
		tween.tween_property(self, "restored", target, 3.0).set_trans(Tween.TRANS_SINE)
		tween.tween_property(self, "brightness", new_brightness, 3.0).set_trans(Tween.TRANS_SINE)
	else:
		restored = target
		brightness = new_brightness


func set_extras(full: Vector3, new_bloom: float, animate: bool = true, duration: float = 3.0) -> void:
	if animate:
		var tween := create_tween().set_parallel(true)
		tween.tween_property(self, "area_full", full, duration).set_trans(Tween.TRANS_SINE)
		tween.tween_property(self, "bloom", new_bloom, duration).set_trans(Tween.TRANS_SINE)
	else:
		area_full = full
		bloom = new_bloom


func _process(delta: float) -> void:
	_time += delta
	_apply()
	queue_redraw()


func _apply() -> void:
	if _material == null:
		return
	# Every ink back: settle to natural colour instead of the "returning" boost.
	var all_back := restored.x > 0.99 and restored.y > 0.99 and restored.z > 0.99 and brightness > 1.0
	_material.set_shader_parameter("chroma_boost", 1.15 if all_back else 1.8)
	_material.set_shader_parameter("restored", restored)
	_material.set_shader_parameter("brightness", brightness)
	_material.set_shader_parameter("area_full", area_full)
	_material.set_shader_parameter("bloom", bloom)
	_material.set_shader_parameter("time_s", _time)


func _draw() -> void:
	var inverse := get_viewport().get_canvas_transform().affine_inverse()
	var size := get_viewport().get_visible_rect().size
	var top_left := inverse * Vector2.ZERO
	var bottom_right := inverse * size
	draw_rect(Rect2(top_left - Vector2(64, 64), bottom_right - top_left + Vector2(128, 128)), Color.WHITE)

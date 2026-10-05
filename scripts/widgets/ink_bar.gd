## 文气槽 —— 以墨条刻度呈现
class_name InkBar
extends Control

var value := 20
var maxv := 20
var col: Color = Palette.JADE
var segments := 20


func set_values(v: int, m: int) -> void:
	value = v
	maxv = m
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var rad := r.size.y * 0.5
	draw_rect(r, Color(Palette.INK, 0.10), true)
	# 分段填充
	var seg_w := r.size.x / float(segments)
	var on := int(round(float(value) / float(maxv) * segments))
	var full := value >= maxv
	for i in segments:
		var x := r.position.x + i * seg_w + 1.0
		var w := seg_w - 2.0
		if i < on:
			draw_rect(Rect2(x, r.position.y + 2.0, w, r.size.y - 4.0), Palette.GOLD if full else col, true)
		else:
			draw_rect(Rect2(x, r.position.y + 2.0, w, r.size.y - 4.0), Color(Palette.INK, 0.07), true)
	draw_rect(r, Color(Palette.INK, 0.28), false, maxf(1.0, rad * 0.10))

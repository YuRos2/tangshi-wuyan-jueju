## 朱砂印章
class_name Seal
extends Control

var chars: Array = ["拾", "字", "成", "詩"]
var col: Color = Palette.CINNABAR
var round_box := false


func setup(c: Array, color: Color = Palette.CINNABAR) -> void:
	chars = c
	col = color
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s < 8.0:
		return
	var r := Rect2((size - Vector2(s, s)) * 0.5, Vector2(s, s))
	draw_rect(r, Color(col, 0.92), true)
	draw_rect(r.grow(-s * 0.08), Color(Palette.PAPER_LIGHT, 0.85), false, maxf(1.0, s * 0.035))
	if chars.size() == 2:
		var fs2 := int(s * 0.36)
		for i in 2:
			draw_string(Ink.fb, Vector2(r.position.x, r.position.y + s * (0.10 + 0.48 * i) + fs2 * 0.92),
					String(chars[i]), HORIZONTAL_ALIGNMENT_CENTER, s, fs2, Palette.PAPER_LIGHT)
		return
	var fs := int(s * 0.36)
	var cells := [Vector2(0.05, 0.03), Vector2(0.53, 0.03), Vector2(0.05, 0.51), Vector2(0.53, 0.51)]
	for i in mini(4, chars.size()):
		draw_string(Ink.fb, Vector2(r.position.x + s * cells[i].x, r.position.y + s * cells[i].y + fs * 0.96),
				String(chars[i]), HORIZONTAL_ALIGNMENT_CENTER, s * 0.42, fs, Palette.PAPER_LIGHT)

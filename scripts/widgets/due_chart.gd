## 记忆曲线 · 未来七日到期柱图
class_name DueChart
extends Control

var counts: Array = []

const LABELS := ["今", "明", "3", "4", "5", "6", "7"]


func set_counts(a: Array) -> void:
	counts = a
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if counts.is_empty():
		return
	var n := counts.size()
	var w := size.x
	var h := size.y
	var label_h := h * 0.26
	var bar_area := h - label_h
	var slot := w / float(n)
	var peak := 1
	var total := 0
	for c in counts:
		peak = maxi(peak, int(c))
		total += int(c)
	var fnt: Font = Ink.f
	var fs := int(label_h * 0.72)
	# 基线
	draw_line(Vector2(0, bar_area), Vector2(w, bar_area), Color(Palette.INK, 0.22), 1.0, true)
	if total == 0:
		draw_string(fnt, Vector2(0, bar_area * 0.55), "近七日無到期之詩",
				HORIZONTAL_ALIGNMENT_CENTER, w, fs, Palette.INK_FAINT)
	for i in n:
		var c := int(counts[i])
		var bw := slot * 0.56
		var bx := i * slot + (slot - bw) * 0.5
		if c > 0:
			var bh := maxf(3.0, bar_area * 0.86 * float(c) / float(peak))
			var by := bar_area - bh
			var col: Color = Palette.CINNABAR if i == 0 else Palette.JADE
			draw_rect(Rect2(bx, by, bw, bh), col, true)
			draw_string(fnt, Vector2(i * slot, by - fs * 0.25), str(c),
					HORIZONTAL_ALIGNMENT_CENTER, slot, fs, Palette.INK_SOFT)
		draw_string(fnt, Vector2(i * slot, h - fs * 0.28), LABELS[i] if i < LABELS.size() else "",
				HORIZONTAL_ALIGNMENT_CENTER, slot, fs, Palette.INK_FAINT)
	draw_string(fnt, Vector2(0, h - fs * 0.28), "日後", HORIZONTAL_ALIGNMENT_RIGHT, w, int(fs * 0.9), Palette.INK_FAINT)

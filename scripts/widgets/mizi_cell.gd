## 米字格 —— 诗句落字之处
class_name MiziCell
extends PressControl

enum { EMPTY, FILLED, CORRECT, WRONG, HINTED }

var state: int = EMPTY
var ch := ""
var focused := false          # 当前待落字的格子
var label: Label

var _pulse := 0.0
var _wrong_flash := 0.0


func _init() -> void:
	press_scale = 0.97


func _ready() -> void:
	super._ready()
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Ink.fb)
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()


func _process(delta: float) -> void:
	if focused and state == EMPTY:
		_pulse += delta
		queue_redraw()
	if _wrong_flash > 0.0:
		_wrong_flash = maxf(0.0, _wrong_flash - delta)
		if _wrong_flash == 0.0:
			queue_redraw()


func resize_cell(s: float) -> void:
	custom_minimum_size = Vector2(s, s)
	size = Vector2(s, s)
	label.add_theme_font_size_override("font_size", int(s * 0.70))
	queue_redraw()


func set_char(t: String, st: int = FILLED) -> void:
	ch = t
	state = st
	label.text = t
	label.add_theme_color_override("font_color", _ink_for_state())
	label.pivot_offset = size * 0.5
	if t != "":
		label.scale = Vector2(0.55, 0.55)
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(label, "scale", Vector2.ONE, 0.22)
	queue_redraw()


func set_state(st: int) -> void:
	state = st
	label.add_theme_color_override("font_color", _ink_for_state())
	if st == WRONG:
		_wrong_flash = 1.0
	queue_redraw()


func clear_char() -> void:
	ch = ""
	state = EMPTY
	label.text = ""
	queue_redraw()


func _ink_for_state() -> Color:
	match state:
		CORRECT:
			return Palette.JADE
		HINTED:
			return Palette.CINNABAR
		WRONG:
			return Palette.CINNABAR
		_:
			return Palette.INK


func shake() -> void:
	var tw := create_tween()
	var base := position
	for i in 3:
		tw.tween_property(self, "position", base + Vector2(9, 0), 0.05)
		tw.tween_property(self, "position", base - Vector2(9, 0), 0.05)
	tw.tween_property(self, "position", base, 0.05)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var ink := Palette.INK
	# 底色
	var bg := Color(Palette.PAPER_LIGHT, 0.62)
	match state:
		CORRECT:
			bg = Color(Palette.JADE, 0.13)
		HINTED:
			bg = Color(Palette.CINNABAR, 0.11)
		WRONG:
			bg = Color(Palette.CINNABAR, 0.16)
		FILLED:
			bg = Color(Palette.PAPER_LIGHT, 0.86)
	draw_rect(r, bg, true)
	# 边框
	var bw := 2.0 if state == EMPTY else 2.6
	var bc := Color(ink, 0.42)
	if state == CORRECT:
		bc = Color(Palette.JADE, 0.85)
	elif state == HINTED or state == WRONG:
		bc = Color(Palette.CINNABAR, 0.85)
	elif focused:
		var p := 0.55 + 0.45 * sin(_pulse * 3.4)
		bc = Color(Palette.GOLD, 0.45 + 0.5 * p)
		bw = 2.0 + 1.8 * p
	draw_rect(r.grow(-bw * 0.5), bc, false, bw)
	# 米字虚线
	if state == EMPTY || state == FILLED:
		var dc := Color(ink, 0.20 if state == EMPTY else 0.13)
		var m := size * 0.5
		Gfx.dashes(self, Vector2(r.position.x, m.y), Vector2(r.end.x, m.y), dc, 1.2, 6, 7)
		Gfx.dashes(self, Vector2(m.x, r.position.y), Vector2(m.x, r.end.y), dc, 1.2, 6, 7)
		Gfx.dashes(self, r.position, r.end, dc, 1.0, 5, 9)
		Gfx.dashes(self, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), dc, 1.0, 5, 9)
	elif state == CORRECT:
		# 对勾般的角标
		var c := Color(Palette.JADE, 0.9)
		var a := 8.0
		draw_line(Vector2(a, a), Vector2(a + 10, a + 10), c, 2.4, true)
		draw_line(Vector2(a + 10, a + 10), Vector2(a + 26, a - 14), c, 2.4, true)

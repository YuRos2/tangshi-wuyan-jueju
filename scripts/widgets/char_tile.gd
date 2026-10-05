## 字牌 —— 字库中待选之字
class_name CharTile
extends PressControl

var ch := ""
var used := false
var label: Label
var font_scale := 0.66

var _sb_normal: StyleBoxFlat
var _sb_hover: StyleBoxFlat


func _init() -> void:
	press_scale = 0.90


func _ready() -> void:
	super._ready()
	_sb_normal = Ink.box_shadow(Palette.PAPER_LIGHT, Palette.PAPER_EDGE, 2, 12, Color(0, 0, 0, 0.17), 7, Vector2(0, 3))
	_sb_hover = Ink.box_shadow(Color("fffaf0"), Palette.GOLD, 3, 12, Color(0, 0, 0, 0.20), 8, Vector2(0, 3))
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Ink.fb)
	label.add_theme_color_override("font_color", Palette.INK)
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()


func set_char(t: String) -> void:
	ch = t
	label.text = t
	queue_redraw()


func set_used(v: bool) -> void:
	used = v
	modulate.a = 0.0 if v else 1.0
	pressable = not v
	mouse_filter = Control.MOUSE_FILTER_IGNORE if v else Control.MOUSE_FILTER_STOP


func resize_tile(w: float, h: float) -> void:
	custom_minimum_size = Vector2(w, h)
	size = Vector2(w, h)
	label.add_theme_font_size_override("font_size", int(h * font_scale))
	label.pivot_offset = size * 0.5


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_style_box(_sb_hover if _hover else _sb_normal, r)
	# 纸牌内双线
	var r2 := r.grow(-5.0)
	draw_rect(r2, Color(Palette.PAPER_EDGE, 0.55), false, 1.0)

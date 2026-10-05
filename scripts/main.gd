extends Control
## Main —— 场景路由、弹层、提示（应用外壳）

const SCREENS := {
	"home": preload("res://scripts/screens/home_screen.gd"),
	"game": preload("res://scripts/screens/game_screen.gd"),
	"review": preload("res://scripts/screens/review_screen.gd"),
	"album": preload("res://scripts/screens/album_screen.gd"),
	"shop": preload("res://scripts/screens/shop_screen.gd"),
}

var _bg: PaperBg
var _content: Control
var _overlay: Control
var _toast_box: VBoxContainer
var _modal: Control = null

var screen: Control = null
var screen_name := ""


func _ready() -> void:
	theme = Ink.theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_bg = PaperBg.new()
	add_child(_bg)

	_content = Control.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_content)

	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	_toast_box = VBoxContainer.new()
	_toast_box.alignment = BoxContainer.ALIGNMENT_END
	_toast_box.add_theme_constant_override("separation", 8)
	_toast_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_toast_box.offset_left = 40
	_toast_box.offset_right = -40
	_toast_box.offset_top = -330
	_toast_box.offset_bottom = -150
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_box)

	# 诗库稍后载入，不阻塞首屏
	PoemDB.ensure_loaded.call_deferred()

	goto("home")


func goto(name: String, params: Dictionary = {}) -> void:
	if not SCREENS.has(name):
		push_error("未知界面: " + name)
		return
	close_modal()
	if screen != null and is_instance_valid(screen):
		screen.queue_free()
		screen = null
	var s: Control = (SCREENS[name] as GDScript).new()
	s.set("app", self)
	if not params.is_empty() and "params" in s:
		s.set("params", params)
	_content.add_child(s)
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen = s
	screen_name = name
	s.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(s, "modulate:a", 1.0, 0.18)
	if s.has_method("entered"):
		s.call("entered")


## 浮出提示
func toast(text: String, col: Color = Palette.INK) -> void:
	var p := Ink.panel(Color(Palette.PAPER_LIGHT, 0.97), Palette.PAPER_EDGE, 2, 12, 12)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Ink.label(text, Ink.F_SMALL, col, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(minf(size.x - 120.0, 560.0), 0)
	p.add_child(l)
	_toast_box.add_child(p)
	p.modulate.a = 0.0
	p.position.y += 12
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(p, "modulate:a", 1.0, 0.18)
	tw.tween_property(p, "position:y", p.position.y - 12, 0.22).set_trans(Tween.TRANS_QUAD)
	tw.set_parallel(false)
	tw.tween_interval(1.7)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)


## 弹出模态层（content 需自带最小尺寸，如 PanelContainer）
func modal(content: Control, closable: bool = true) -> Control:
	close_modal()
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.10, 0.07, 0.05, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(content)
	holder.add_child(center)

	if closable:
		dim.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				close_modal())

	_overlay.add_child(holder)
	_modal = holder
	holder.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(holder, "modulate:a", 1.0, 0.16)
	content.pivot_offset = content.size * 0.5
	return holder


func close_modal() -> void:
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null


func modal_open() -> bool:
	return _modal != null and is_instance_valid(_modal)

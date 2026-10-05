## 可按压控件基类：统一触控 / 鼠标、悬停与按下回弹
class_name PressControl
extends Control

signal pressed(index: int)

var index := 0
var pressable := true
var hover_enabled := true
var press_scale := 0.93

var _down := false
var _hover := false
var _tween: Tween
var _last_emit := 0
var _last_kind := -1

## 防抖：同一次按下若同时收到触控与模拟鼠标两种事件，只取一次（250 ms 内异类去重）
const DUP_WINDOW_MS := 250


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if hover_enabled:
		mouse_entered.connect(_on_hover.bind(true))
		mouse_exited.connect(_on_hover.bind(false))


func _on_hover(v: bool) -> void:
	if _hover == v:
		return
	_hover = v
	queue_redraw()


func _set_zoom(z: float) -> void:
	pivot_offset = size * 0.5
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2(z, z), 0.08)


func _gui_input(e: InputEvent) -> void:
	if not pressable:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_down = true
			_set_zoom(press_scale)
			accept_event()
		elif _down:
			_down = false
			_set_zoom(1.0)
			if Rect2(Vector2.ZERO, size).has_point(e.position):
				_emit(0)
			accept_event()
	elif e is InputEventScreenTouch:
		if e.pressed and not _down:
			_down = true
			_set_zoom(press_scale)
			accept_event()
		elif not e.pressed and _down:
			_down = false
			_set_zoom(1.0)
			if Rect2(Vector2.ZERO, size).has_point(e.position):
				_emit(1)
			accept_event()


func _emit(kind: int) -> void:
	var now := Time.get_ticks_msec()
	if kind != _last_kind and now - _last_emit < DUP_WINDOW_MS:
		return
	_last_emit = now
	_last_kind = kind
	pressed.emit(index)

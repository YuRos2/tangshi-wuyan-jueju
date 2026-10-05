## 壁画地仗底 —— 全局背景（土墙沙色、斑驳颗粒、卷草边饰、飘带与藻井）
class_name PaperBg
extends Control

static var _tex: Texture2D = null
static var _grad: GradientTexture2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


static func _ensure() -> void:
	if _tex == null:
		_tex = Gfx.paper_texture(192)
	if _grad == null:
		var g := Gradient.new()
		g.set_color(0, Color("f0e0bd"))
		g.set_color(1, Color("dcc697"))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.width = 8
		gt.height = 256
		gt.fill_from = Vector2(0, 0)
		gt.fill_to = Vector2(0, 1)
		_grad = gt


func _draw() -> void:
	_ensure()
	var r := Rect2(Vector2.ZERO, size)
	var w := size.x
	var h := size.y
	draw_texture_rect(_grad, r, false)
	draw_texture_rect(_tex, r, true, Color(1, 1, 1, 0.75))

	# 藻井（顶部中央，极淡，如窟顶华盖）
	Gfx.caisson(self, Vector2(w * 0.5, h * 0.115), w * 0.28, Color(Palette.GOLD, 0.11), 4, 1.4)

	# 飞天飘带（自上方两角飘垂而入）
	Gfx.ribbon(self, Vector2(-w * 0.08, h * 0.055), Vector2(w * 0.70, h * 0.235),
			Color(Palette.CINNABAR, 0.13), 8, 1.1, 22, -w * 0.16)
	Gfx.ribbon(self, Vector2(w * 1.08, h * 0.075), Vector2(w * 0.34, h * 0.255),
			Color(Palette.AZURE, 0.12), 7, 0.9, 18, w * 0.15)
	Gfx.ribbon(self, Vector2(w * 0.92, h * 0.985), Vector2(w * 0.10, h * 0.86),
			Color(Palette.JADE, 0.09), 6, 1.0, 16, h * 0.06)

	# 壁画边饰：外框 + 卷草带 + 四角忍冬
	Gfx.mural_border(self, r.grow(-10.0), Color(Palette.INK, 0.34), Color(Palette.CINNABAR, 0.26), 62.0, true)

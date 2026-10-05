extends Node
## Ink —— 全局字体、主题、配色与控件工厂（autoload 单例）
## 全部界面由此构建，保证「书卷气」的一致调性。

const FONT_PATH := "res://fonts/wenkai.woff2"
const MAP_PATH := "res://data/t2s_map.json"

# —— 字号体系（基准视口 720×1280）——
const F_HUGE := 72
const F_TITLE := 58
const F_H1 := 42
const F_H2 := 34
const F_BODY := 29
const F_SMALL := 24
const F_TINY := 20

var f: Font                       # 正体（霞鹜文楷）
var fb: Font                      # 粗体（embolden 变化）
var theme: Theme
var simp := false                 # true = 简体显示
var _map: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	f = load(FONT_PATH)
	var fv := FontVariation.new()
	fv.base_font = f
	fv.variation_embolden = 0.45
	fb = fv

	theme = Theme.new()
	theme.default_font = f
	theme.default_font_size = F_BODY
	theme.set_color("font_color", "Label", Palette.INK)
	_load_map()
	set_simp(simp)


func _load_map() -> void:
	if not FileAccess.file_exists(MAP_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	if d is Dictionary:
		_map = d


## 繁/簡切换
func set_simp(v: bool) -> void:
	simp = v


## 界面文本转换（繁 → 簡，仅在 simp 开启时）
func T(s: String) -> String:
	if not simp or s.is_empty():
		return s
	var out := ""
	for c in s:
		out += _map.get(c, c)
	return out


# ---------------------------------------------------------------- 样式盒
static func box(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0,
		radius: int = 0, inset: float = 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	if bw > 0:
		sb.set_border_width_all(bw)
		sb.border_color = border
	if radius > 0:
		sb.set_corner_radius_all(radius)
	if inset > 0.0:
		sb.set_content_margin_all(inset)
	sb.anti_aliasing = true
	return sb


static func box_shadow(bg: Color, border: Color, bw: int, radius: int,
		shadow: Color, size: int, offset: Vector2) -> StyleBoxFlat:
	var sb := box(bg, border, bw, radius)
	sb.shadow_color = shadow
	sb.shadow_size = size
	sb.shadow_offset = offset
	return sb


# ---------------------------------------------------------------- 控件工厂
func panel(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0,
		radius: int = 0, pad: float = 0.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, border, bw, radius, pad))
	return p


func label(txt: String, fsize: int = F_BODY, col: Color = Palette.INK,
		align: int = HORIZONTAL_ALIGNMENT_LEFT, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = T(txt)
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_override("font", fb if bold else f)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## kind: ink=浓墨实心  paper=纸面描边  ghost=无底  red=朱砂  gold=藤黄
func button(txt: String, fsize: int = F_BODY, kind: String = "paper",
		pad: Vector2 = Vector2(22, 12), radius: int = 10) -> Button:
	var b := Button.new()
	b.text = T(txt)
	b.add_theme_font_size_override("font_size", fsize)
	b.add_theme_font_override("font", f)
	b.focus_mode = Control.FOCUS_NONE
	var fg: Color
	match kind:
		"ink":
			fg = Palette.PAPER_LIGHT
			b.add_theme_stylebox_override("normal", box_shadow(Palette.INK, Palette.INK, 0, radius, Color(0, 0, 0, 0.25), 6, Vector2(0, 3)))
			b.add_theme_stylebox_override("hover", box_shadow(Palette.INK_SOFT, Palette.INK, 0, radius, Color(0, 0, 0, 0.25), 6, Vector2(0, 3)))
			b.add_theme_stylebox_override("pressed", box(Palette.INK, Palette.INK, 0, radius))
			b.add_theme_stylebox_override("disabled", box(Color(Palette.INK, 0.35), Color(0, 0, 0, 0), 0, radius))
		"red":
			fg = Palette.PAPER_LIGHT
			b.add_theme_stylebox_override("normal", box_shadow(Palette.CINNABAR, Palette.CINNABAR, 0, radius, Color(0, 0, 0, 0.22), 6, Vector2(0, 3)))
			b.add_theme_stylebox_override("hover", box_shadow(Palette.CINNABAR_SOFT, Palette.CINNABAR, 0, radius, Color(0, 0, 0, 0.22), 6, Vector2(0, 3)))
			b.add_theme_stylebox_override("pressed", box(Palette.CINNABAR, Palette.CINNABAR, 0, radius))
			b.add_theme_stylebox_override("disabled", box(Color(Palette.CINNABAR, 0.35), Color(0, 0, 0, 0), 0, radius))
		"gold":
			fg = Palette.INK
			b.add_theme_stylebox_override("normal", box_shadow(Palette.GOLD_SOFT, Palette.GOLD, 2, radius, Color(0, 0, 0, 0.18), 6, Vector2(0, 3)))
			b.add_theme_stylebox_override("hover", box_shadow(Color("e8cd88"), Palette.GOLD, 2, radius, Color(0, 0, 0, 0.2), 6, Vector2(0, 3)))
			b.add_theme_stylebox_override("pressed", box(Palette.GOLD_SOFT, Palette.GOLD, 2, radius))
			b.add_theme_stylebox_override("disabled", box(Color(Palette.GOLD_SOFT, 0.3), Color(Palette.GOLD, 0.4), 2, radius))
		"ghost":
			fg = Palette.INK_SOFT
			b.add_theme_stylebox_override("normal", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, radius))
			b.add_theme_stylebox_override("hover", box(Color(Palette.INK, 0.07), Color(0, 0, 0, 0), 0, radius))
			b.add_theme_stylebox_override("pressed", box(Color(Palette.INK, 0.14), Color(0, 0, 0, 0), 0, radius))
			b.add_theme_stylebox_override("disabled", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, radius))
			b.add_theme_color_override("font_disabled_color", Color(Palette.INK, 0.3))
		_:  # paper
			fg = Palette.INK
			b.add_theme_stylebox_override("normal", box_shadow(Palette.PAPER_LIGHT, Palette.PAPER_EDGE, 2, radius, Color(0, 0, 0, 0.16), 6, Vector2(0, 3)))
			b.add_theme_stylebox_override("hover", box_shadow(Color("fffaf0"), Palette.GOLD, 2, radius, Color(0, 0, 0, 0.18), 6, Vector2(0, 3)))
			b.add_theme_stylebox_override("pressed", box(Palette.PAPER_DEEP, Palette.GOLD, 2, radius))
			b.add_theme_stylebox_override("disabled", box(Color(Palette.PAPER_LIGHT, 0.45), Color(Palette.PAPER_EDGE, 0.4), 2, radius))
			b.add_theme_color_override("font_disabled_color", Color(Palette.INK, 0.32))
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	if not b.has_theme_color_override("font_disabled_color"):
		if kind == "ink" or kind == "red":
			b.add_theme_color_override("font_disabled_color", Color(Palette.PAPER_LIGHT, 0.45))
		else:
			b.add_theme_color_override("font_disabled_color", Color(Palette.INK, 0.32))
	for s in ["normal", "hover", "pressed", "disabled"]:
		var sb := b.get_theme_stylebox(s)
		if sb is StyleBoxFlat:
			sb.set_content_margin_all(0.0)
			sb.content_margin_left = pad.x
			sb.content_margin_right = pad.x
			sb.content_margin_top = pad.y
			sb.content_margin_bottom = pad.y
	return b


func vspace(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func hspace(w: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## 一根细线
func rule(col: Color = Palette.PAPER_EDGE, thick: float = 1.0, vertical: bool = false) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vertical:
		r.custom_minimum_size = Vector2(thick, 0)
	else:
		r.custom_minimum_size = Vector2(0, thick)
	return r


func expand(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c

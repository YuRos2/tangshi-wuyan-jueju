## 成就卡牌 —— 完成诗篇后凝结而成的收藏品
## 整张卡牌以 _draw 直绘（无子节点），可在任意尺寸下等比呈现：
## 同一份代码既用于卡册缩略图，也用于全幅展示与「存为图片」导出。
class_name CardWidget
extends PressControl

var rec: Dictionary = {}
var mini := false
var simp := false

static var _paper_tex: Texture2D = null


func _init() -> void:
	press_scale = 0.95


func setup(record: Dictionary, is_mini: bool = false) -> void:
	rec = record
	mini = is_mini
	simp = Ink.simp
	queue_redraw()


func _paper() -> Texture2D:
	if _paper_tex == null:
		_paper_tex = Gfx.paper_texture(160)
	return _paper_tex


func _rarity() -> int:
	return clampi(int(rec.get("r", 3)), 0, 3)


## 取出繁/簡诗行（两联）
func _couplets() -> Array:
	var l = rec.get("sl" if simp else "l", [])
	if not (l is Array) or l.is_empty():
		l = rec.get("l", [])
	return l


## 整理为四句（每句五字，去标点）
func _poem4() -> Array:
	var out: Array = []
	for para in _couplets():
		for part in String(para).split("，"):
			var p := _strip_punct(part)
			if not p.is_empty():
				out.append(p)
	while out.size() < 4:
		out.append("")
	return out


func _title() -> String:
	return String(rec.get("st" if simp else "t", rec.get("t", "")))


func _author() -> String:
	return String(rec.get("sa" if simp else "a", rec.get("a", "")))


func _draw() -> void:
	if rec.is_empty():
		return
	if mini:
		if size.x < 40.0 or size.y < 56.0:
			return
		_draw_mini()
	else:
		# 容器首次布局时会先给宽度、后给高度，尚未成形时不绘
		if size.x < 220.0 or size.y < 300.0:
			return
		_draw_full()


# ------------------------------------------------------------------ 缩略卡
func _draw_mini() -> void:
	var w := size.x
	var h := size.y
	var r := Rect2(Vector2.ZERO, size)
	var ri := _rarity()
	var fnt: Font = Ink.f
	var paper := Palette.PAPER_LIGHT.lerp(Palette.RARITY_SOFT[ri], 0.30)
	draw_rect(r, paper, true)
	draw_rect(r, Palette.PAPER_EDGE, false, 2.0)
	draw_texture_rect(_paper(), r.grow(-3), true, Color(1, 1, 1, 0.45))
	draw_rect(r.grow(-6), Color(Palette.PAPER_EDGE, 0.55), false, 1.0)

	# 品级色带
	var band := h * 0.048
	draw_rect(Rect2(6, 6, w - 12, band), Palette.RARITY_SOFT[ri], true)
	draw_rect(Rect2(6, 6, w * 0.22, band), Palette.RARITY[ri], true)
	var fs := int(band * 0.72)
	draw_string(fnt, Vector2(6, 6 + band * 0.78), Palette.RARITY_NAME[ri],
			HORIZONTAL_ALIGNMENT_RIGHT, w - 12, fs, Palette.RARITY[ri])

	# 卷草一道（壁画边饰的缩略）
	Gfx.vine(self, Vector2(12, h * 0.088), Vector2(w - 12, h * 0.088), Color(Palette.CINNABAR, 0.3), 26.0, 2.4, 1.0)

	# 题目
	var t := "《" + _title() + "》"
	var tf := int(h * 0.076)
	var tw := Ink.fb.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tf).x
	if tw > w - 26.0:
		tf = maxi(11, int(tf * (w - 26.0) / tw * 0.97))
	draw_string(Ink.fb, Vector2(0, h * 0.36), t, HORIZONTAL_ALIGNMENT_CENTER, w, tf, Palette.INK)

	# 作者
	draw_string(fnt, Vector2(0, h * 0.47), _author(), HORIZONTAL_ALIGNMENT_CENTER, w,
			int(h * 0.052), Palette.INK_SOFT)

	# 印
	var ss := h * 0.155
	_draw_seal(Rect2(w * 0.5 - ss * 0.5, h * 0.575, ss, ss), ["拾", "字", "成", "詩"], Palette.CINNABAR)

	# 落款
	draw_string(fnt, Vector2(0, h * 0.94), Defs.date_cn(int(rec.get("ts", 0))),
			HORIZONTAL_ALIGNMENT_CENTER, w, int(h * 0.040), Palette.INK_FAINT)

	# 记忆阶与下次温习
	var st := clampi(int(rec.get("stage", 0)), 0, 8)
	var due := int(rec.get("due", 0))
	var is_due := due > 0 and due <= int(Time.get_unix_time_from_system())
	var dr := h * 0.008
	var dx0 := w * 0.5 - (8 * dr * 2.6) * 0.5 + dr
	for i in 8:
		var cc := Vector2(dx0 + i * dr * 2.6, h * 0.795)
		draw_circle(cc, dr, Palette.CINNABAR if i < st else Color(Palette.INK, 0.15))
	var lx := "待 溫 習" if is_due else Defs.due_cn(due)
	draw_string(fnt, Vector2(0, h * 0.855), lx, HORIZONTAL_ALIGNMENT_CENTER, w,
			int(h * 0.038), Palette.CINNABAR if is_due else Palette.JADE)


# ------------------------------------------------------------------ 全幅卡
func _draw_full() -> void:
	var w := size.x
	var h := size.y
	var r := Rect2(Vector2.ZERO, size)
	var ri := _rarity()
	var fnt: Font = Ink.f
	var m := w * 0.045

	var paper := Palette.PAPER_LIGHT.lerp(Palette.RARITY_SOFT[ri], 0.35)
	var sb := Ink.box_shadow(paper, Palette.PAPER_EDGE, 2, 8, Color(0, 0, 0, 0.26), 16, Vector2(0, 6))
	draw_style_box(sb, r)
	draw_texture_rect(_paper(), r.grow(-3), true, Color(1, 1, 1, 0.55))
	# 壁画边饰：卷草藤蔓 + 四角忍冬
	Gfx.mural_border(self, r.grow(-m * 0.55), Color(Palette.INK, 0.55), Color(Palette.CINNABAR, 0.42),
			maxf(26.0, w * 0.055), true)

	# 抬头
	var hf := int(h * 0.025)
	draw_string(fnt, Vector2(m * 1.1, h * 0.082), "唐詩五言絕句",
			HORIZONTAL_ALIGNMENT_LEFT, -1, hf, Palette.INK_FAINT)
	draw_string(fnt, Vector2(0, h * 0.082), "拾字成詩 · 藏",
			HORIZONTAL_ALIGNMENT_RIGHT, w - m * 1.1, hf, Palette.INK_FAINT)

	# 记忆阶（八个墨点）
	var st := clampi(int(rec.get("stage", 0)), 0, 8)
	var dy := h * 0.124
	draw_string(fnt, Vector2(m * 1.1, dy), "記憶", HORIZONTAL_ALIGNMENT_LEFT, -1, int(hf * 0.85), Palette.INK_FAINT)
	var dr := hf * 0.22
	var dx0 := m * 1.1 + hf * 2.2 + dr
	for i in 8:
		var cc := Vector2(dx0 + i * dr * 2.5, dy - hf * 0.30)
		if i < st:
			draw_circle(cc, dr, Palette.CINNABAR)
		elif st > 0:
			draw_circle(cc, dr, Color(Palette.INK, 0.16))
		else:
			draw_circle(cc, dr, Color(Palette.INK, 0.10))
	if bool(rec.get("due", 0)) and int(rec.get("due", 0)) <= int(Time.get_unix_time_from_system()):
		draw_string(fnt, Vector2(0, dy), "待溫習", HORIZONTAL_ALIGNMENT_RIGHT, w - m * 1.1, int(hf * 0.85), Palette.CINNABAR)

	# 品级印记（右上）
	var rw := w * 0.145
	var rh := h * 0.050
	var rr := Rect2(w - m * 1.1 - rw, h * 0.102, rw, rh)
	draw_rect(rr, Palette.RARITY[ri], true)
	draw_string(fnt, Vector2(rr.position.x, rr.position.y + rh * 0.74), Palette.RARITY_NAME[ri],
			HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, int(rh * 0.64), Palette.PAPER_LIGHT)

	# 题目
	var tstr := "《" + _title() + "》"
	var tf := int(h * 0.078)
	var avail := w - m * 3.0
	var tw := Ink.fb.get_string_size(tstr, HORIZONTAL_ALIGNMENT_LEFT, -1, tf).x
	if tw > avail:
		tf = maxi(14, int(tf * avail / tw * 0.97))
	draw_string(Ink.fb, Vector2(0, h * 0.212), tstr, HORIZONTAL_ALIGNMENT_CENTER, w, tf, Palette.INK)

	# 作者 + 名章
	var af := int(h * 0.038)
	var astr := _author()
	var aw := fnt.get_string_size(astr, HORIZONTAL_ALIGNMENT_LEFT, -1, af).x
	var ss2 := af * 1.45
	draw_string(fnt, Vector2(0, h * 0.262), astr, HORIZONTAL_ALIGNMENT_CENTER, w, af, Palette.INK_SOFT)
	_draw_seal(Rect2(w * 0.5 + aw * 0.5 + af * 0.30, h * 0.262 - af * 1.02, ss2, ss2),
			[astr.substr(0, 1), "印"], Palette.CINNABAR)

	# 诗文（横排四面五字，去标点，如写经原貌）
	var lines := _poem4()
	var top := h * 0.292
	var line_h := h * 0.123
	var avail_w := w - m * 3.0
	var csz := int(minf(line_h * 0.72, avail_w / 5.2))
	for li in 4:
		var body := String(lines[li])
		var base := top + li * line_h + (line_h - csz) * 0.5 + fnt.get_ascent(csz)
		draw_string(Ink.fb, Vector2(0, base), body, HORIZONTAL_ALIGNMENT_CENTER, w, csz, Palette.INK)

	# 题名两侧小莲
	var tstr_w := Ink.fb.get_string_size(tstr, HORIZONTAL_ALIGNMENT_LEFT, -1, tf).x
	var ly := h * 0.212 - tf * 0.30
	var lgap := w * 0.030
	Gfx.lotus(self, Vector2(w * 0.5 - tstr_w * 0.5 - lgap, ly), tf * 0.23,
			Color(Palette.AZURE, 0.60), Color(Palette.CINNABAR, 0.85), 8)
	Gfx.lotus(self, Vector2(w * 0.5 + tstr_w * 0.5 + lgap, ly), tf * 0.23,
			Color(Palette.AZURE, 0.60), Color(Palette.CINNABAR, 0.85), 8)

	# 上下分隔
	var ry := h * 0.802
	draw_line(Vector2(m * 1.1, ry), Vector2(w - m * 1.1, ry), Color(Palette.INK, 0.30), 1.4, true)

	# 出处
	var ff := int(h * 0.027)
	draw_string(fnt, Vector2(m * 1.1, h * 0.850), "出處：《全唐詩》",
			HORIZONTAL_ALIGNMENT_LEFT, -1, ff, Palette.INK_SOFT)
	# 编号 · 重温 · 落款
	var no := maxi(1, int(rec.get("no", 1)))
	var meta := "第 %s 號" % _cn_num(no, 4)
	var rep := int(rec.get("n", 1))
	if rep > 1:
		meta += " · 重溫 %d 次" % rep
	meta += " · " + Defs.date_cn(int(rec.get("ts", 0)))
	draw_string(fnt, Vector2(m * 1.1, h * 0.928), meta,
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(ff * 0.90), Palette.INK_FAINT)

	# 评章（右下，印之左侧）
	var sz := int(h * 0.026)
	var txt := ""
	var col := Palette.CINNABAR
	if bool(rec.get("fu", false)):
		txt = "天授"
		col = Palette.JADE
	elif int(rec.get("mis", 0)) == 0:
		txt = "一氣呵成"
	if txt != "":
		var tw2 := fnt.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var bw := tw2 + sz * 1.1
		_draw_outline_seal(Rect2(w * 0.78 - bw, h * 0.850 - sz * 1.05, bw, sz * 2.3), txt, sz, col)

	# 大印（右下角）
	var gs := w * 0.115
	_draw_seal(Rect2(w - m * 1.1 - gs, h - m * 1.1 - gs, gs, gs),
			["拾", "字", "成", "詩"], Palette.CINNABAR)


func _strip_punct(s: String) -> String:
	var out := ""
	for c in s:
		if c != "，" and c != "。" and c != "、" and c != "；":
			out += c
	return out


## 朱砂方印（四字 2×2，或两字竖排）
func _draw_seal(r: Rect2, chars: Array, col: Color) -> void:
	draw_rect(r, Color(col, 0.92), true)
	var iv := r.size.x * 0.08
	draw_rect(r.grow(-iv), Color(Palette.PAPER_LIGHT, 0.85), false, maxf(1.0, r.size.x * 0.035))
	if chars.size() == 2:
		var fs2 := int(r.size.y * 0.40)
		for i in 2:
			draw_string(Ink.fb, Vector2(r.position.x, r.position.y + r.size.y * (0.08 + 0.50 * i) + fs2 * 0.9),
					chars[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs2, Palette.PAPER_LIGHT)
		return
	var fs := int(r.size.y * 0.38)
	var cells := [Vector2(0.04, 0.02), Vector2(0.52, 0.02), Vector2(0.04, 0.50), Vector2(0.52, 0.50)]
	for i in mini(4, chars.size()):
		draw_string(Ink.fb, Vector2(r.position.x + r.size.x * cells[i].x,
				r.position.y + r.size.y * cells[i].y + fs * 0.98),
				chars[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x * 0.44, fs, Palette.PAPER_LIGHT)


## 朱砂细框评章（横书）
func _draw_outline_seal(r: Rect2, txt: String, fs: int, col: Color) -> void:
	draw_rect(r, Color(col, 0.10), true)
	draw_rect(r, Color(col, 0.85), false, maxf(1.5, fs * 0.07))
	draw_string(Ink.f, Vector2(r.position.x, r.position.y + r.size.y * 0.68), txt,
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, Color(col, 0.95))


## 四位编号（〇一二三…）
func _cn_num(n: int, digits: int) -> String:
	var map := "〇一二三四五六七八九"
	var s := str(n)
	while s.length() < digits:
		s = "0" + s
	var out := ""
	for c in s:
		out += map[("0123456789").find(c)] if ("0123456789").find(c) >= 0 else c
	return out

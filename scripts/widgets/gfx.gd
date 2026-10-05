## 通用绘制工具 · 敦煌纹样（卷草 / 忍冬 / 火焰 / 莲花 / 飘带 / 藻井）
class_name Gfx


## 虚线（用于米字格）
static func dashes(ci: CanvasItem, from: Vector2, to: Vector2, col: Color,
		width: float = 1.0, dash: float = 7.0, gap: float = 6.0) -> void:
	var total := from.distance_to(to)
	if total <= 0.001:
		return
	var dir := (to - from) / total
	var t := 0.0
	while t < total:
		var e: float = minf(t + dash, total)
		ci.draw_line(from + dir * t, from + dir * e, col, width, true)
		t = e + gap


## 卷草纹（连绵藤蔓）：沿 a→b 的正弦藤蔓，波峰缀果
static func vine(ci: CanvasItem, a: Vector2, b: Vector2, col: Color,
		wavelength: float = 54.0, amp: float = 5.0, w: float = 1.4) -> void:
	var total := a.distance_to(b)
	if total < wavelength * 0.8:
		return
	var dir := (b - a) / total
	var nrm := Vector2(-dir.y, dir.x)
	var waves := total / wavelength
	var steps := maxi(12, int(total / 4.0))
	var pts := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / steps
		pts.append(a + dir * (t * total) + nrm * sin(t * TAU * waves) * amp)
	ci.draw_polyline(pts, col, w, true)
	var berries := int(waves)
	for i in maxi(1, berries):
		var t := (float(i) + 0.5) / float(maxi(1, berries))
		if t >= 1.0:
			continue
		var p := a + dir * (t * total) + nrm * sin(t * TAU * waves) * amp
		ci.draw_circle(p, w * 1.15, col)


## 忍冬卷草角（螺旋卷曲）
static func spiral(ci: CanvasItem, c: Vector2, r: float, col: Color,
		turns: float = 1.35, rot: float = 0.0) -> void:
	if r < 3.0:
		return
	var steps := 44
	var pts := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / steps
		var ang := rot + t * TAU * turns
		var rad := r * (1.0 - t * 0.86)
		pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
	ci.draw_polyline(pts, col, maxf(1.0, r * 0.13), true)


## 火焰纹（向上三舌，用于角饰）
static func flame(ci: CanvasItem, c: Vector2, h: float, col: Color, flip := 1.0) -> void:
	if h < 4.0:
		return
	var w := h * 0.42
	var body := PackedVector2Array([
		c + Vector2(0, 0),
		c + Vector2(-w * flip, -h * 0.42),
		c + Vector2(-w * 0.34 * flip, -h),
		c + Vector2(0, -h * 0.62),
		c + Vector2(w * 0.34 * flip, -h),
		c + Vector2(w * flip, -h * 0.42),
	])
	ci.draw_colored_polygon(body, col)


## 莲花（n 瓣）
static func lotus(ci: CanvasItem, c: Vector2, r: float, petal: Color, core: Color, n: int = 8) -> void:
	if r < 3.0:
		return
	for i in n:
		var a := TAU * float(i) / float(n)
		var tip := c + Vector2(cos(a), sin(a)) * r
		var l := c + Vector2(cos(a - 0.42), sin(a - 0.42)) * r * 0.40
		var rr := c + Vector2(cos(a + 0.42), sin(a + 0.42)) * r * 0.40
		ci.draw_colored_polygon(PackedVector2Array([c, l, tip, rr]), petal)
	ci.draw_circle(c, r * 0.24, core)


## 飘带（飞天帛带）：沿二次曲线飘动、两端渐细
static func ribbon(ci: CanvasItem, a: Vector2, b: Vector2, col: Color,
		width: float = 6.0, waves: float = 1.5, amp: float = 24.0, bend: float = 0.0) -> void:
	var total := a.distance_to(b)
	if total < 8.0:
		return
	var dir := (b - a) / total
	var nrm := Vector2(-dir.y, dir.x)
	var ctrl := (a + b) * 0.5 + nrm * bend
	var steps := 56
	var prev := a
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var p := a * (1.0 - t) * (1.0 - t) + ctrl * 2.0 * (1.0 - t) * t + b * t * t
		p += nrm * sin(t * TAU * waves) * amp * sin(t * PI)
		var w := maxf(0.7, width * (1.0 - absf(t - 0.32) * 1.25))
		ci.draw_line(prev, p, col, w, true)
		prev = p


## 藻井（层层套叠的方/菱形，中心一朵莲）
static func caisson(ci: CanvasItem, c: Vector2, r: float, col: Color,
		layers: int = 5, lw: float = 1.6) -> void:
	if r < 10.0:
		return
	for i in layers:
		var f := 1.0 - float(i) / float(layers)
		var s := r * f
		var col2 := Color(col, col.a * (0.45 + 0.55 * f))
		if i % 2 == 0:
			ci.draw_rect(Rect2(c - Vector2(s, s), Vector2(s * 2, s * 2)), col2, false, lw)
		else:
			var p := PackedVector2Array([
				c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)])
			ci.draw_polyline(PackedVector2Array([p[0], p[1], p[2], p[3], p[0]]), col2, lw, true)
	lotus(ci, c, r * 0.20, Color(col, col.a * 0.9), Color(col, col.a * 0.6), 8)


## 壁画边饰：外框 + 卷草带 + 四角忍冬火焰
static func mural_border(ci: CanvasItem, rect: Rect2, ink: Color, vine_col: Color,
		wavelength: float = 54.0, corner: bool = true) -> void:
	ci.draw_rect(rect, ink, false, 2.0)
	var inner := rect.grow(-7.0)
	if inner.size.x < 10.0 or inner.size.y < 10.0:
		return
	ci.draw_rect(inner, Color(ink, ink.a * 0.55), false, 1.0)
	var band := 3.5
	var top_a := inner.position + Vector2(10, band)
	var top_b := Vector2(inner.end.x - 10, inner.position.y + band)
	var bot_a := Vector2(inner.position.x + 10, inner.end.y - band)
	var bot_b := inner.end - Vector2(10, band)
	vine(ci, top_a, top_b, vine_col, wavelength, 4.5, 1.3)
	vine(ci, bot_b, bot_a, vine_col, wavelength, 4.5, 1.3)
	vine(ci, Vector2(top_a.x, top_a.y), Vector2(bot_a.x, bot_a.y), vine_col, wavelength, 4.5, 1.3)
	vine(ci, Vector2(top_b.x, top_b.y), Vector2(bot_b.x, bot_b.y), vine_col, wavelength, 4.5, 1.3)
	if corner:
		var cs := 15.0
		spiral(ci, inner.position + Vector2(cs * 0.62, cs * 0.62), cs, vine_col, 1.3, PI)
		spiral(ci, Vector2(inner.end.x - cs * 0.62, inner.position.y + cs * 0.62), cs, vine_col, 1.3, PI * 0.5)
		spiral(ci, Vector2(inner.position.x + cs * 0.62, inner.end.y - cs * 0.62), cs, vine_col, 1.3, PI * 1.5)
		spiral(ci, inner.end - Vector2(cs * 0.62, cs * 0.62), cs, vine_col, 1.3, 0.0)


## 双线书框（保留给需要素雅处）
static func double_frame(ci: CanvasItem, rect: Rect2, col: Color,
		outer: float = 2.0, inner: float = 1.0, gap: float = 8.0) -> void:
	ci.draw_rect(rect, col, false, outer)
	var r2 := rect.grow(-gap)
	if r2.size.x > 4.0 and r2.size.y > 4.0:
		ci.draw_rect(r2, Color(col, col.a * 0.75), false, inner)


static func corner_marks(ci: CanvasItem, rect: Rect2, col: Color, arm: float = 16.0, w: float = 2.0) -> void:
	var r := rect
	var pts := [
		Vector2(r.position.x, r.position.y),
		Vector2(r.end.x, r.position.y),
		Vector2(r.position.x, r.end.y),
		Vector2(r.end.x, r.end.y),
	]
	for i in pts.size():
		var p: Vector2 = pts[i]
		var sx: float = 1.0 if (i == 0 or i == 2) else -1.0
		var sy: float = 1.0 if (i == 0 or i == 1) else -1.0
		ci.draw_line(p, p + Vector2(arm * sx, 0), col, w, true)
		ci.draw_line(p, p + Vector2(0, arm * sy), col, w, true)


## 生成一张壁画地仗纹理（土墙颗粒与斑驳）
static func paper_texture(size: int = 192) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261005
	for y in size:
		for x in size:
			var n := rng.randf()
			var a := 0.0
			var col := Color(0.32, 0.23, 0.14, 0)
			if n > 0.78:
				a = (n - 0.78) * 0.42        # 沙粒
			elif n < 0.035:
				a = 0.16                      # 斑驳
				col = Color(0.55, 0.32, 0.18, 0)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return ImageTexture.create_from_image(img)

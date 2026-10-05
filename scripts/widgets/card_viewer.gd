## 卡牌详览弹层（收藏与结算共用），支持「存为图片」
class_name CardViewer
extends PanelContainer

var app: Node
var rec: Dictionary = {}
var card_key := ""
var card: CardWidget

## 测试时置 true，避免自动打开文件管理器
static var silent := false


static func build(host: Node, record: Dictionary, key: String = "") -> CardViewer:
	var v := CardViewer.new()
	v.app = host
	v.rec = record
	v.card_key = key
	v._compose()
	return v


func _compose() -> void:
	var vs: Vector2 = app.size if app != null else Vector2(720, 1280)
	var ch: float = minf(vs.y * 0.70, 1020.0)
	var cw: float = ch * 0.714
	ch = minf(ch, (vs.x - 90.0) / 0.714)
	cw = ch * 0.714

	add_theme_stylebox_override("panel", Ink.box(Color(Palette.PAPER, 0.98), Palette.PAPER_EDGE, 2, 16, 16.0))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	add_child(v)

	# 记忆档期一行
	if rec.has("due"):
		var st := clampi(int(rec.get("stage", 0)), 0, 8)
		var due := int(rec.get("due", 0))
		var is_due := due > 0 and due <= int(Time.get_unix_time_from_system())
		var info := "記憶階 %d ／ 8　·　溫習 %d 次　·　%s" % [
			st, int(rec.get("rev", 0)),
			"今 日 待 溫" if is_due else Defs.due_cn(due)]
		v.add_child(Ink.label(info, Ink.F_TINY, Palette.CINNABAR if is_due else Palette.JADE,
				HORIZONTAL_ALIGNMENT_CENTER))

	card = CardWidget.new()
	card.custom_minimum_size = Vector2(cw, ch)
	card.setup(rec, false)
	v.add_child(card)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	if card_key != "" and GameState.cards.has(card_key):
		var b_rev := Ink.button("閃現溫習", Ink.F_BODY, "gold", Vector2(22, 14))
		b_rev.pressed.connect(func():
			if app != null:
				app.goto("review", {"key": card_key}))
		row.add_child(b_rev)
	var b_save := Ink.button("存為圖片", Ink.F_BODY, "paper", Vector2(22, 14))
	b_save.pressed.connect(_on_save)
	row.add_child(b_save)
	var b_close := Ink.button("收 起", Ink.F_BODY, "paper", Vector2(22, 14))
	b_close.pressed.connect(func():
		if app != null and app.has_method("close_modal"):
			app.close_modal())
	row.add_child(b_close)


## 把卡牌渲染成 900×1260 的图片
static func render_card(host: Node, record: Dictionary) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(900, 1260)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(vp)
	var c := CardWidget.new()
	c.setup(record, false)
	c.custom_minimum_size = Vector2(900, 1260)
	vp.add_child(c)
	c.size = Vector2(900, 1260)
	c.position = Vector2.ZERO
	# 低耗模式或窗口被遮时帧不会自动绘，须强制出图
	for i in 3:
		await host.get_tree().process_frame
		RenderingServer.force_draw(false, 0.0)
	var img: Image = null
	if vp.get_texture() != null:
		img = vp.get_texture().get_image()
	vp.queue_free()
	return img


func _on_save() -> void:
	var img: Image = await render_card(self, rec)
	if img == null:
		if app != null:
			app.toast("圖影未成，請再試一次", Palette.CINNABAR)
		return

	var fname := _safe_name("%s_%s" % [rec.get("t", "詩"), rec.get("a", "")]) + ".png"
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(img.save_png_to_buffer(), fname, "image/png")
		if app != null:
			app.toast("已送出下載：" + fname, Palette.JADE)
		return
	var dir := "user://cards"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir + "/" + fname
	var err := img.save_png(path)
	if err == OK:
		if app != null:
			app.toast("已存為圖片：" + fname + "（存於相册文件夾）", Palette.JADE)
		if not silent:
			OS.shell_open(ProjectSettings.globalize_path(dir))
	else:
		if app != null:
			app.toast("存圖失敗（%d）" % err, Palette.CINNABAR)


func _safe_name(s: String) -> String:
	var out := ""
	for c in s:
		if c in "\\/:*?\"<>|":
			continue
		out += c
	return out

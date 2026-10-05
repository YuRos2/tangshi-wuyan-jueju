extends Control
## 溫習 —— 闪卡：三秒闪现已藏之卡，自评印象，依记忆曲线排下次档期
## 目的：以温习回文氣、得文貝，与开卷／书坊构成闭环。

var app: Node
var params: Dictionary = {}

enum { SHOW, ASK, REVEAL }

var queue: Array = []          # 待温之卡 key 序列
var idx := -1
var phase := SHOW
var cur_key := ""
var cur_stage := 0
var cur_again := false         # 本张已用过「再闪」
var rewarded_stamina := 0
var rewarded_coins := 0
var reviewed := 0
var recalled := 0
var practice := false          # 整轮皆为随意温习（未到期）

var _lbl_progress: Label
var _lbl_stage: Label
var _lbl_res: Label
var _lbl_status: Label
var _lbl_ask: Label
var _card_box: Control
var _card: CardWidget
var _back: Control
var _bar: InkBar
var _bar_wrap: Control
var _btn_row: HBoxContainer
var _btn_again: Button
var _reward: Label
var _flash_tw: Tween
var _card_w := 460.0
var _card_h := 644.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_queue()
	if queue.is_empty():
		app.toast(Ink.T("今日已無待溫之詩"), Palette.JADE)
		app.goto.call_deferred("home")
		return
	_build()
	_next_card()


# ------------------------------------------------------------------ 队列
func _build_queue() -> void:
	var want := String(params.get("key", ""))
	if want != "" and GameState.cards.has(want):
		queue = [want]
		practice = not GameState.is_due(GameState.cards[want])
		return
	queue = GameState.due_keys()
	practice = false


# ------------------------------------------------------------------ 构建
func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)

	# 顶栏
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)
	var back := Ink.button("‹ 返回", Ink.F_SMALL, "ghost", Vector2(10, 8), 8)
	back.pressed.connect(_on_quit)
	top.add_child(back)
	var title := Ink.label("溫 習", Ink.F_H1, Palette.INK, HORIZONTAL_ALIGNMENT_LEFT, true)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(title)
	top.add_child(Ink.spacer())
	_lbl_stage = Ink.label("", Ink.F_SMALL, Palette.CINNABAR)
	_lbl_stage.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_lbl_stage)
	var sep := Ink.rule(Color(Palette.INK, 0.22), 1.0, true)
	sep.custom_minimum_size = Vector2(1, 18)
	sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(sep)
	_lbl_progress = Ink.label("0 / 0", Ink.F_SMALL, Palette.INK_FAINT)
	_lbl_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_lbl_progress)

	_lbl_res = Ink.label("", Ink.F_TINY, Palette.INK_FAINT)
	col.add_child(_lbl_res)

	# 卡牌 / 卡背（同一位置叠放）
	_card_box = Control.new()
	_card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_box.custom_minimum_size = Vector2(_card_w, _card_h)
	_card_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_card_box)

	_card = CardWidget.new()
	_card.setup({}, false)
	_card.pressable = false
	_card.hover_enabled = false
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.custom_minimum_size = Vector2(_card_w, _card_h)
	_card_box.add_child(_card)

	_back = _make_back()
	_card_box.add_child(_back)

	# 倒数条
	_bar_wrap = Control.new()
	_bar_wrap.custom_minimum_size = Vector2(_card_w, 14)
	_bar_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_bar_wrap)
	_bar = InkBar.new()
	_bar.segments = 20
	_bar.custom_minimum_size = Vector2(_card_w, 14)
	_bar.size = Vector2(_card_w, 14)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_wrap.add_child(_bar)

	# 自评区
	var ask := VBoxContainer.new()
	ask.add_theme_constant_override("separation", 8)
	col.add_child(ask)
	_lbl_ask = Ink.label("", Ink.F_H2, Palette.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	ask.add_child(_lbl_ask)
	_btn_row = HBoxContainer.new()
	_btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_btn_row.add_theme_constant_override("separation", 12)
	ask.add_child(_btn_row)
	var b1 := Ink.button("沒記住", Ink.F_BODY, "red", Vector2(14, 14), 10)
	b1.pressed.connect(_rate.bind(1))
	_btn_row.add_child(b1)
	var b2 := Ink.button("有些模糊", Ink.F_BODY, "paper", Vector2(10, 14), 10)
	b2.pressed.connect(_rate.bind(2))
	_btn_row.add_child(b2)
	var b3 := Ink.button("記得清楚", Ink.F_BODY, "gold", Vector2(10, 14), 10)
	b3.pressed.connect(_rate.bind(3))
	_btn_row.add_child(b3)
	_reward = Ink.label("", Ink.F_BODY, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER, true)
	ask.add_child(_reward)

	col.add_child(Ink.spacer())

	# 底部：再闪 + 今日额度
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	col.add_child(bottom)
	_btn_again = Ink.button("再閃一次", Ink.F_SMALL, "ghost", Vector2(12, 8), 8)
	_btn_again.pressed.connect(_again)
	bottom.add_child(_btn_again)
	bottom.add_child(Ink.spacer())
	_lbl_status = Ink.label("", Ink.F_TINY, Palette.INK_FAINT, HORIZONTAL_ALIGNMENT_RIGHT)
	bottom.add_child(_lbl_status)

	_set_ask_visible(false)
	_resize_card()


func _make_back() -> Control:
	var p := Ink.panel(Color(Palette.PAPER_LIGHT, 0.97), Palette.PAPER_EDGE, 2, 10, 0.0)
	p.custom_minimum_size = Vector2(_card_w, _card_h)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	p.add_child(v)
	var seal := Seal.new()
	seal.custom_minimum_size = Vector2(132, 132)
	seal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	seal.setup(["記", "憶"], Palette.CINNABAR)
	v.add_child(seal)
	v.add_child(Ink.label("方才那首", Ink.F_H1, Palette.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	return p


func _resize_card() -> void:
	var vs := size if size.x > 10.0 else Vector2(720, 1280)
	var h: float = clampf(vs.y * 0.555, 320.0, 820.0)
	var w: float = h * 0.714
	if w > vs.x - 96.0:
		w = vs.x - 96.0
		h = w / 0.714
	_card_w = w
	_card_h = h
	if _card_box == null:
		return
	_card_box.custom_minimum_size = Vector2(w, h)
	_card.custom_minimum_size = Vector2(w, h)
	_card.setup(_card.rec, false)
	_back.custom_minimum_size = Vector2(w, h)
	_bar.custom_minimum_size = Vector2(w, 14)
	_bar.size = Vector2(w, 14)
	_bar_wrap.custom_minimum_size = Vector2(w, 14)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _card_box != null:
		_resize_card()


# ------------------------------------------------------------------ 流程
func _next_card() -> void:
	idx += 1
	if idx >= queue.size():
		_finish()
		return
	cur_key = String(queue[idx])
	var rec: Dictionary = GameState.cards.get(cur_key, {})
	if rec.is_empty():
		_next_card()
		return
	cur_stage = int(rec.get("stage", 0))
	cur_again = false
	practice = not GameState.is_due(rec)
	_card.setup(rec, false)
	_card.modulate = Color(1, 1, 1, 1)
	_card.visible = true
	_back.visible = false
	_set_ask_visible(false)
	_reward.text = ""
	_lbl_stage.text = Ink.T("記憶階 %d" % cur_stage)
	_lbl_progress.text = "%d / %d" % [idx + 1, queue.size()]
	_btn_again.visible = true
	_btn_again.disabled = false
	_btn_again.text = Ink.T("再閃一次")
	_refresh_res()

	var secs: float = GameState.flash_secs(cur_stage)
	phase = SHOW
	Sfx.play("ui", -14.0)
	if _flash_tw != null and _flash_tw.is_valid():
		_flash_tw.kill()
	_card.modulate = Color(1, 1, 1, 0)
	_flash_tw = create_tween()
	_flash_tw.set_parallel(true)
	_flash_tw.tween_property(_card, "modulate:a", 1.0, 0.22)
	_flash_tw.tween_method(func(v: float): _bar.set_values(int(round(v * 20.0)), 20), 1.0, 0.0, secs)
	_flash_tw.set_parallel(false)
	_flash_tw.tween_callback(_ask)


func _ask() -> void:
	if phase != SHOW:
		return
	phase = ASK
	_card.visible = false
	_back.visible = true
	_bar.set_values(0, 20)
	_set_ask_visible(true)
	_lbl_ask.text = Ink.T("隨意溫習 · 無賞" if practice else "方才那首，記得幾何？")
	_btn_again.disabled = cur_again
	_btn_again.text = Ink.T("再閃一次（評級限略記）" if not cur_again else "已再閃")


func _again() -> void:
	if phase != ASK or cur_again:
		return
	cur_again = true
	_back.visible = false
	_card.visible = true
	_set_ask_visible(false)
	phase = SHOW
	var secs: float = GameState.flash_secs(cur_stage)
	if _flash_tw != null and _flash_tw.is_valid():
		_flash_tw.kill()
	_card.modulate = Color(1, 1, 1, 0)
	_flash_tw = create_tween()
	_flash_tw.set_parallel(true)
	_flash_tw.tween_property(_card, "modulate:a", 1.0, 0.2)
	_flash_tw.tween_method(func(v: float): _bar.set_values(int(round(v * 20.0)), 20), 1.0, 0.0, secs)
	_flash_tw.set_parallel(false)
	_flash_tw.tween_callback(_ask)


func _rate(q: int) -> void:
	if phase != ASK:
		return
	phase = REVEAL
	if cur_again:
		q = mini(q, 2)
	var res: Dictionary = GameState.record_review(cur_key, q)
	if res.is_empty():
		_next_card()
		return
	reviewed += 1
	if q >= 3:
		recalled += 1
	rewarded_stamina += int(res.get("stamina", 0))
	rewarded_coins += int(res.get("coin", 0))
	if bool(res.get("was_due", false)):
		Sfx.play("place" if q >= 3 else "take", -6.0)
	else:
		Sfx.play("take", -12.0)

	# 亮出卡牌，给一句回执
	_back.visible = false
	_card.visible = true
	_card.setup(GameState.cards.get(cur_key, res["record"]), false)
	_card.modulate = Color(1, 1, 1, 0)
	_set_ask_visible(false)
	var txt := "%s · %s" % [GameState.quality_name(q), String(res.get("next", ""))]
	if bool(res.get("was_due", false)):
		txt += " ｜ 文氣 +%d · 文貝 +%d" % [int(res.get("stamina", 0)), int(res.get("coin", 0))]
	else:
		txt += " ｜ 隨意溫習，檔期不變"
	_reward.text = Ink.T(txt)
	_reward.visible = true
	_refresh_res()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_card, "modulate:a", 1.0, 0.2)
	tw.tween_property(_card, "scale", Vector2(0.985, 0.985), 0.3)
	tw.set_parallel(false)
	tw.tween_interval(1.15)
	tw.tween_callback(_next_card)


func _refresh_res() -> void:
	_lbl_res.text = Ink.T("已溫 %d 篇 · 今日回氣 %d/%d · 今日得貝 %d/%d　（%s）" % [
		reviewed, GameState.stamina_from_review, GameState.REVIEW_STAMINA_CAP,
		GameState.coins_from_review, GameState.REVIEW_COIN_CAP,
		"隨意溫習" if practice else "到期溫習"])
	_lbl_status.text = Ink.T("文氣 %d/%d · 文貝 %d" % [GameState.stamina, GameState.STAMINA_MAX, GameState.coins])


func _set_ask_visible(v: bool) -> void:
	if _btn_row != null:
		_btn_row.visible = v
	if _lbl_ask != null:
		_lbl_ask.visible = v


func _finish() -> void:
	var panel := Ink.panel(Color(Palette.PAPER, 0.99), Palette.PAPER_EDGE, 2, 16, 22)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var msg := "今日溫習已畢" if not practice else "隨意溫習已畢"
	v.add_child(Ink.label(msg, Ink.F_H1, Palette.INK, HORIZONTAL_ALIGNMENT_CENTER, true))
	v.add_child(Ink.rule(Palette.PAPER_EDGE, 1.0))
	v.add_child(Ink.label(Ink.T("溫習 %d 篇 · 記得清楚 %d 篇" % [reviewed, recalled]),
			Ink.F_BODY, Palette.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(Ink.label(Ink.T("文氣 +%d（今日 %d/%d）" % [rewarded_stamina, GameState.stamina_from_review, GameState.REVIEW_STAMINA_CAP]),
			Ink.F_BODY, Palette.JADE, HORIZONTAL_ALIGNMENT_CENTER, true))
	v.add_child(Ink.label(Ink.T("文貝 +%d（今日 %d/%d）" % [rewarded_coins, GameState.coins_from_review, GameState.REVIEW_COIN_CAP]),
			Ink.F_BODY, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER, true))
	var nxt := GameState.due_next_days(7)
	var tip := "明日 %d 篇到期 · 後日 %d 篇" % [int(nxt[1]), int(nxt[2])] if nxt.size() > 2 else ""
	if GameState.streak > 0:
		tip += " · 連續溫習 %d 日" % GameState.streak
	v.add_child(Ink.label(Ink.T(tip), Ink.F_SMALL, Palette.INK_FAINT, HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	var b_card := Ink.button("看卡冊", Ink.F_BODY, "paper", Vector2(24, 14))
	b_card.pressed.connect(func():
		app.close_modal()
		app.goto("album"))
	row.add_child(b_card)
	var b_ok := Ink.button("收 下", Ink.F_BODY, "ink", Vector2(28, 14))
	b_ok.pressed.connect(func():
		app.close_modal()
		app.goto("home"))
	row.add_child(b_ok)
	app.modal(panel, false)
	Sfx.play("coin", -4.0)


func _on_quit() -> void:
	if reviewed > 0:
		_finish()
		return
	app.goto("home")

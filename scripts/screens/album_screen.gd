extends Control
## 卡册 —— 收藏成就卡牌

var app: Node

const PER_PAGE := 30

var _grid: GridContainer
var _scroll_box: VBoxContainer
var _lbl_head: Label
var _lbl_stats: Label
var _btn_more: Button
var _filter := -1          # -1 全部, 0..3 品级, 8 待温习, 9 成就
var _sort := 0             # 0 待温习优先, 1 收藏新旧, 2 记忆阶
var _chart: DueChart
var _btn_review: Button
var _shown := 0
var _list: Array = []
var _ach_box: VBoxContainer
var _card_w := 200.0
var _card_h := 280.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	GameState.cards_changed.connect(_reload)
	GameState.achievements_changed.connect(_reload)
	resized.connect(_relayout)
	_reload()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)
	var back := Ink.button("‹ 返回", Ink.F_SMALL, "ghost", Vector2(12, 8), 8)
	back.pressed.connect(func(): app.goto("home"))
	top.add_child(back)
	var title := Ink.label("卡 冊", Ink.F_H1, Palette.INK, HORIZONTAL_ALIGNMENT_LEFT, true)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(title)
	top.add_child(Ink.spacer())
	_lbl_head = Ink.label("", Ink.F_SMALL, Palette.GOLD)
	_lbl_head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_lbl_head)

	_lbl_stats = Ink.label("", Ink.F_TINY, Palette.INK_FAINT)
	col.add_child(_lbl_stats)

	# 记忆曲线：未来七日
	var mem := HBoxContainer.new()
	mem.add_theme_constant_override("separation", 12)
	col.add_child(mem)
	_chart = DueChart.new()
	_chart.custom_minimum_size = Vector2(0, 66)
	_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mem.add_child(_chart)
	_btn_review = Ink.button("開 始 溫 習", Ink.F_SMALL, "gold", Vector2(18, 12), 10)
	_btn_review.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_btn_review.pressed.connect(_on_review_all)
	mem.add_child(_btn_review)

	# 筛选
	var filt := HBoxContainer.new()
	filt.add_theme_constant_override("separation", 8)
	col.add_child(filt)
	var names := ["全部", "逸品", "神品", "妙品", "能品", "待溫習", "成就"]
	for i in names.size():
		var idx := -1
		if i >= 1 and i <= 4:
			idx = i - 1
		elif i == 5:
			idx = 8
		elif i == 6:
			idx = 9
		var b := Ink.button(names[i], Ink.F_TINY, "paper", Vector2(12, 7), 8)
		b.pressed.connect(_on_filter.bind(idx))
		filt.add_child(b)
	var b_sort := Ink.button("序：溫習", Ink.F_TINY, "ghost", Vector2(10, 7), 8)
	b_sort.pressed.connect(func():
		_sort = (_sort + 1) % 3
		b_sort.text = Ink.T(["序：溫習", "序：新藏", "序：記階"][_sort])
		_reload())
	filt.add_child(b_sort)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)

	_scroll_box = VBoxContainer.new()
	_scroll_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_box.add_theme_constant_override("separation", 12)
	scroll.add_child(_scroll_box)

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 12)
	_scroll_box.add_child(_grid)

	_ach_box = VBoxContainer.new()
	_ach_box.add_theme_constant_override("separation", 8)
	_ach_box.visible = false
	_scroll_box.add_child(_ach_box)

	_btn_more = Ink.button("載入更多", Ink.F_BODY, "paper", Vector2(30, 14))
	_btn_more.pressed.connect(func():
		_shown += PER_PAGE
		_fill())
	_scroll_box.add_child(_btn_more)


func _relayout() -> void:
	var avail := size.x - 44.0 - 18.0 - 20.0
	_card_w = (avail - 20.0) / 3.0
	_card_h = _card_w / 0.714
	_reload()


func _on_filter(idx: int) -> void:
	_filter = idx
	_reload()


func _reload() -> void:
	if _grid == null:
		return
	_shown = PER_PAGE
	_list.clear()
	for k in GameState.cards.keys():
		var r: Dictionary = GameState.cards[k]
		r["_key"] = k
		if _filter >= 0 and _filter <= 3 and int(r.get("r", 3)) != _filter:
			continue
		if _filter == 8 and not GameState.is_due(r):
			continue
		_list.append(r)
	match _sort:
		0:
			_list.sort_custom(func(a, b): return int(a.get("due", 0)) < int(b.get("due", 0)))
		1:
			_list.sort_custom(func(a, b): return int(a.get("ts", 0)) > int(b.get("ts", 0)))
		_:
			_list.sort_custom(func(a, b): return int(a.get("stage", 0)) > int(b.get("stage", 0)))

	var rc := GameState.rarity_counts()
	_lbl_head.text = Ink.T("文貝 %d" % GameState.coins)
	var total := PoemDB.count()
	var due := GameState.due_count()
	var avg := 0.0 if GameState.card_count() <= 0 else float(GameState.stage_sum()) / GameState.card_count()
	_lbl_stats.text = Ink.T("已藏 %d%s · 待溫習 %d · 均階 %.1f · 連續 %d 日 · 逸 %d 神 %d 妙 %d 能 %d" % [
		GameState.card_count(), (" ／ %d" % total) if total > 0 else "", due, avg, GameState.streak,
		rc[0], rc[1], rc[2], rc[3]])
	_chart.set_counts(GameState.due_next_days(7))
	_btn_review.text = Ink.T("開 始 溫 習 %d" % due) if due > 0 else Ink.T("今日無待溫習")
	_btn_review.disabled = due <= 0
	_btn_review.modulate = Color(1, 1, 1, 1) if due > 0 else Color(1, 1, 1, 0.45)
	_fill()


func _on_review_all() -> void:
	var due := GameState.due_keys()
	if due.is_empty():
		app.toast(Ink.T("今日已無待溫之詩"), Palette.JADE)
		return
	Sfx.play("ui")
	app.goto("game", {"mode": "review", "key": String(due[0])})


func _fill() -> void:
	for c in _grid.get_children():
		c.queue_free()
	for c in _ach_box.get_children():
		c.queue_free()

	var is_ach := _filter == 9
	_grid.visible = not is_ach
	_ach_box.visible = is_ach
	_btn_more.visible = not is_ach and _shown < _list.size()

	if is_ach:
		_fill_achievements()
		return

	if _list.is_empty():
		var msg := "尚無收藏。開卷成詩，自有卡牌入冊。"
		if _filter == 8:
			msg = "今日無待溫之詩，明日再會。"
		var l := Ink.label(msg, Ink.F_BODY, Palette.INK_FAINT, HORIZONTAL_ALIGNMENT_CENTER)
		l.custom_minimum_size = Vector2(size.x - 60.0, 120)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_grid.add_child(l)
		return

	var n: int = mini(_shown, _list.size())
	for i in n:
		var cw := CardWidget.new()
		cw.custom_minimum_size = Vector2(_card_w, _card_h)
		cw.setup(_list[i], true)
		var rec: Dictionary = _list[i]
		cw.pressed.connect(func(_idx: int): app.modal(CardViewer.build(app, rec, String(rec.get("_key", "")))))
		_grid.add_child(cw)

	_btn_more.text = Ink.T("載入更多（%d / %d）" % [n, _list.size()])


func _fill_achievements() -> void:
	var head := Ink.label("成 就", Ink.F_H2, Palette.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	_ach_box.add_child(head)
	for a in Defs.ACHIEVEMENTS:
		var done := GameState.achievement_done(String(a["id"]))
		var panel := Ink.panel(
			Color(Palette.PAPER_LIGHT, 0.92) if done else Color(Palette.PAPER_DEEP, 0.5),
			Palette.GOLD if done else Palette.PAPER_EDGE, 2, 10, 12.0)
		_ach_box.add_child(panel)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		panel.add_child(h)
		var mark := Ink.label("已" if done else "未", Ink.F_SMALL, Palette.GOLD if done else Palette.INK_FAINT, HORIZONTAL_ALIGNMENT_CENTER, done)
		mark.custom_minimum_size = Vector2(44, 0)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(mark)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(Ink.label(String(a["name"]), Ink.F_BODY, Palette.INK if done else Palette.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT, true))
		var d := Ink.label(String(a["desc"]), Ink.F_TINY, Palette.INK_FAINT)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(d)
		var reward := Ink.label("文貝 +%d" % int(a["coin"]), Ink.F_TINY, Palette.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
		reward.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(reward)

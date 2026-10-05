extends Control
## 主界面 —— 开卷 / 卡册 / 书坊 / 凡例

var app: Node

var _lbl_stamina: Label
var _bar: InkBar
var _lbl_next: Label
var _lbl_coins: Label
var _lbl_stats: Label
var _lbl_total: Label
var _btn_start: Button
var _btn_simp: Button
var _btn_sfx: Button
var _btn_album: Button
var _btn_tea: Button
var _btn_review: Button
var _lbl_memory: Label
var _quote_box: PanelContainer
var _lbl_quote: Label
var _lbl_quote_by: Label
var _quote_poem: Dictionary = {}
var _tick := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	GameState.stamina_changed.connect(_refresh)
	GameState.coins_changed.connect(_refresh)
	GameState.cards_changed.connect(_refresh)
	GameState.achievements_changed.connect(_refresh)
	if PoemDB.loaded:
		_refresh.call_deferred()
	else:
		PoemDB.library_ready.connect(_refresh)
	_refresh()


func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 1.0:
		_tick = 0.0
		_refresh_timers()


func _refresh_timers() -> void:
	var s := GameState.stamina
	_lbl_next.text = Ink.T("文氣已滿") if s >= GameState.STAMINA_MAX else Ink.T("下點 %02d:%02d" % [GameState.stamina_next_secs() / 60, GameState.stamina_next_secs() % 60])


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	# —— 顶栏：文气 / 文贝 / 繁简 / 音 ——
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)

	var t1 := Ink.label("文氣", Ink.F_SMALL, Palette.INK_SOFT)
	top.add_child(t1)
	_bar = InkBar.new()
	_bar.custom_minimum_size = Vector2(150, 18)
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_bar)
	_lbl_stamina = Ink.label("20/20", Ink.F_SMALL, Palette.INK_SOFT)
	top.add_child(_lbl_stamina)
	top.add_child(Ink.spacer())
	_lbl_coins = Ink.label("文貝 60", Ink.F_SMALL, Palette.GOLD)
	top.add_child(_lbl_coins)
	_btn_simp = Ink.button("字：繁", Ink.F_SMALL, "paper", Vector2(14, 8), 8)
	_btn_simp.pressed.connect(_on_simp)
	top.add_child(_btn_simp)
	_btn_sfx = Ink.button("音：開", Ink.F_SMALL, "paper", Vector2(14, 8), 8)
	_btn_sfx.pressed.connect(_on_sfx)
	top.add_child(_btn_sfx)

	_lbl_next = Ink.label("", Ink.F_TINY, Palette.INK_FAINT, HORIZONTAL_ALIGNMENT_RIGHT)
	col.add_child(_lbl_next)

	col.add_child(Ink.vspace(10))
	col.add_child(Ink.spacer())

	# —— 题名 ——
	var title := Ink.label("拾 字 成 詩", Ink.F_HUGE, Palette.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	col.add_child(title)

	var deco := HBoxContainer.new()
	deco.add_theme_constant_override("separation", 16)
	deco.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(deco)
	deco.add_child(Ink.spacer())
	var seal := Seal.new()
	seal.custom_minimum_size = Vector2(74, 74)
	seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	seal.setup(["五", "言", "絕", "句"], Palette.CINNABAR)
	deco.add_child(seal)
	deco.add_child(Ink.spacer())

	var sub := Ink.label("唐詩五言絕句 · 亂字重組", Ink.F_H2, Palette.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(sub)
	_lbl_total = Ink.label("", Ink.F_SMALL, Palette.INK_FAINT, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_lbl_total)
	_lbl_stats = Ink.label("", Ink.F_SMALL, Palette.INK_FAINT, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_lbl_stats)

	col.add_child(Ink.spacer())

	# —— 今日诗句 ——
	var qp := Ink.panel(Color(Palette.PAPER_LIGHT, 0.5), Palette.PAPER_EDGE, 1, 10, 16.0)
	qp.visible = false
	col.add_child(qp)
	_quote_box = qp
	var qv := VBoxContainer.new()
	qv.add_theme_constant_override("separation", 6)
	qp.add_child(qv)
	qv.add_child(Ink.label("— 今 日 詩 句 —", Ink.F_TINY, Palette.INK_FAINT, HORIZONTAL_ALIGNMENT_CENTER))
	_lbl_quote = Ink.label("", Ink.F_H2, Palette.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	qv.add_child(_lbl_quote)
	_lbl_quote_by = Ink.label("", Ink.F_SMALL, Palette.INK_FAINT, HORIZONTAL_ALIGNMENT_CENTER)
	qv.add_child(_lbl_quote_by)

	col.add_child(Ink.spacer())
	col.add_child(Ink.vspace(6))

	# —— 开卷 ——
	_btn_start = Ink.button("開   卷", Ink.F_TITLE, "ink", Vector2(60, 22), 14)
	_btn_start.custom_minimum_size = Vector2(0, 96)
	_btn_start.pressed.connect(_on_start)
	col.add_child(_btn_start)

	var cost := Ink.label("開卷耗文氣 2 點", Ink.F_TINY, Palette.INK_FAINT, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(cost)

	# —— 温习（记忆曲线）——
	_btn_review = Ink.button("溫 習", Ink.F_H2, "gold", Vector2(40, 18), 12)
	_btn_review.custom_minimum_size = Vector2(0, 74)
	_btn_review.pressed.connect(_on_review)
	col.add_child(_btn_review)
	_lbl_memory = Ink.label("", Ink.F_TINY, Palette.INK_FAINT, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_lbl_memory)

	_btn_tea = Ink.button("飲 茶", Ink.F_SMALL, "paper", Vector2(24, 12), 10)
	_btn_tea.pressed.connect(_on_tea)
	col.add_child(_btn_tea)
	col.add_child(Ink.vspace(6))

	# —— 副按钮 ——
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	_btn_album = Ink.button("卡 冊", Ink.F_BODY, "paper", Vector2(20, 16), 12)
	_btn_album.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_album.pressed.connect(func(): app.goto("album"))
	row.add_child(_btn_album)
	var b_shop := Ink.button("書 坊", Ink.F_BODY, "paper", Vector2(20, 16), 12)
	b_shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_shop.pressed.connect(func(): app.goto("shop"))
	row.add_child(b_shop)
	var b_help := Ink.button("凡 例", Ink.F_BODY, "paper", Vector2(20, 16), 12)
	b_help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_help.pressed.connect(_show_help)
	row.add_child(b_help)


func _refresh() -> void:
	if _lbl_stamina == null:
		return
	_bar.set_values(GameState.stamina, GameState.STAMINA_MAX)
	_lbl_stamina.text = "%d/%d" % [GameState.stamina, GameState.STAMINA_MAX]
	_lbl_coins.text = Ink.T("文貝 %d" % GameState.coins)
	_lbl_total.text = Ink.T("已藏 %d 首 · 詩庫 %d 首" % [GameState.card_count(), PoemDB.count()])
	_lbl_stats.text = Ink.T("開卷 %d 局 · 完美 %d 次" % [int(GameState.stats.get("played", 0)), int(GameState.stats.get("perfect", 0))])
	_btn_album.text = Ink.T("卡 冊 %d" % GameState.card_count())
	var can := GameState.can_play()
	_btn_start.disabled = not can
	if can:
		_btn_start.text = Ink.T("開   卷")
	else:
		_btn_start.text = Ink.T("文氣不足")
	_btn_simp.text = Ink.T("字：簡" if Ink.simp else "字：繁")
	_btn_sfx.text = Ink.T("音：開" if Sfx.enabled else "音：靜")
	var tea := GameState.item_count("cha")
	_btn_tea.text = Ink.T("飲清心茶（餘 %d）· 文氣 +5" % tea)
	_btn_tea.disabled = tea <= 0 or GameState.stamina >= GameState.STAMINA_MAX
	# —— 温习入口 ——
	var due := GameState.due_count()
	if due > 0:
		_btn_review.text = Ink.T("溫 習  %d 篇" % due)
		_btn_review.disabled = false
		_btn_review.modulate = Color(1, 1, 1, 1)
	else:
		_btn_review.text = Ink.T("今日無待溫之詩")
		_btn_review.disabled = true
		_btn_review.modulate = Color(1, 1, 1, 0.45)
	var total := GameState.card_count()
	var avg := 0.0 if total <= 0 else float(GameState.stage_sum()) / total
	_lbl_memory.text = Ink.T("已藏 %d 首 · 平均記憶階 %.1f · 連續溫習 %d 日 · 今日回氣 %d/%d" % [
		total, avg, GameState.streak, GameState.stamina_from_review, GameState.REVIEW_STAMINA_CAP])
	_refresh_quote()
	_refresh_timers()


## 今日诗句：从传世名篇中抽一联
func _refresh_quote() -> void:
	if _quote_poem.is_empty():
		if PoemDB.count() <= 0:
			_quote_box.visible = false
			return
		_quote_poem = PoemDB.pick_of_rarity(0)
	var lines: Array = PoemDB.lines_of(_quote_poem)
	if lines.is_empty():
		_quote_box.visible = false
		return
	_quote_box.visible = true
	_lbl_quote.text = String(lines[0])
	_lbl_quote_by.text = "— %s《%s》" % [PoemDB.author_of(_quote_poem), PoemDB.title_of(_quote_poem)]


func _on_start() -> void:
	if not GameState.can_play():
		app.toast(Ink.T("文氣不足，稍候片刻或飲清心茶"), Palette.CINNABAR)
		Sfx.play("err")
		return
	Sfx.play("ui")
	app.goto("game")


## 温习：从最早到期的一篇开始
func _on_review() -> void:
	var due := GameState.due_keys()
	if due.is_empty():
		app.toast(Ink.T("今日已無待溫之詩"), Palette.JADE)
		Sfx.play("err", -10.0)
		return
	Sfx.play("ui")
	app.goto("review")


func _on_simp() -> void:
	GameState.set_simp(not Ink.simp)
	Sfx.play("ui")
	_refresh()


func _on_sfx() -> void:
	GameState.set_sfx(not Sfx.enabled)
	Sfx.play("ui")
	_refresh()


func _on_tea() -> void:
	if GameState.item_count("cha") <= 0:
		app.toast(Ink.T("清心茶已盡，可至書坊添置"), Palette.CINNABAR)
		Sfx.play("err")
		return
	if GameState.stamina >= GameState.STAMINA_MAX:
		app.toast(Ink.T("文氣已滿"), Palette.INK_SOFT)
		return
	GameState.use_item("cha")
	GameState.add_stamina(5)
	Sfx.play("coin")
	app.toast(Ink.T("清心茶 · 文氣 +5"), Palette.JADE)
	_refresh()


func _show_help() -> void:
	var panel := Ink.panel(Color(Palette.PAPER, 0.99), Palette.PAPER_EDGE, 2, 14, 22)
	panel.custom_minimum_size = Vector2(minf(size.x - 70.0, 620.0), 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var head := Ink.label("凡 例", Ink.F_H1, Palette.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	col.add_child(head)
	col.add_child(Ink.rule(Palette.PAPER_EDGE, 1.0))

	var rules := [
		"一、每局取《全唐詩》五言絕句一首，二十字盡亂其序，置於下方字庫。",
		"二、點字庫之字，即落於上方米字格；點格中已落之字，可退回字庫。",
		"三、四句二十字皆與原詩相符，此局乃成，得一張成就卡牌可藏。",
		"四、開卷耗文氣二點；文氣每三分鐘復一點，以二十點為滿。",
		"五、卡牌分逸、神、妙、能四品。零失誤者鈐「一氣呵成」印。",
		"六、道具四事：青玉硯添字、菱花鏡照影、清心茶補氣、琅嬛符天成。",
		"七、文貝得自完成詩篇，可於書坊購置道具。",
		"八、卡牌可「存為圖片」，置於相冊收藏。",
		"九、詩文依《全唐詩》原文，可於主界面切換繁簡。",
		"十、卡冊即記憶之庫：每篇各有檔期。到期溫習不耗文氣，成功則回文氣與文貝。",
		"十一、溫習即閃卡：卡牌閃現三息（記憶愈牢，閃現愈短），繼而自評印象——",
		"　　　記得進一階（一、二、四、七、十五、三十、六十、一百二十日）；模糊檔期減半；沒記住退一階，十分鐘後再會。",
		"十二、溫習回賞：文氣與文貝各有每日額度，逾額不再增。隨意溫習（未到期）無賞、不改檔期。",
		"十三、開卷若重遇已藏之詩，記憶階四以上者，字庫會摻入五個干擾字。",
	]
	for r in rules:
		var l := Ink.label(r, Ink.F_SMALL, Palette.INK_SOFT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(panel.custom_minimum_size.x - 48.0, 0)
		col.add_child(l)

	col.add_child(Ink.rule(Palette.PAPER_EDGE, 1.0))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	var b_wipe := Ink.button("清空存檔", Ink.F_SMALL, "ghost", Vector2(18, 12))
	b_wipe.pressed.connect(_confirm_wipe)
	row.add_child(b_wipe)
	var b_close := Ink.button("知 道 了", Ink.F_BODY, "ink", Vector2(30, 14))
	b_close.pressed.connect(func(): app.close_modal())
	row.add_child(b_close)
	app.modal(panel)


func _confirm_wipe() -> void:
	var panel := Ink.panel(Color(Palette.PAPER, 0.99), Palette.PAPER_EDGE, 2, 14, 22)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)
	col.add_child(Ink.label("清空存檔？", Ink.F_H1, Palette.CINNABAR, HORIZONTAL_ALIGNMENT_CENTER, true))
	var l := Ink.label("卡冊、道具、文貝、文氣將盡數歸零，不可復原。", Ink.F_SMALL, Palette.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(420, 0)
	col.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	var b_no := Ink.button("且慢", Ink.F_BODY, "paper", Vector2(30, 14))
	b_no.pressed.connect(func(): app.close_modal())
	row.add_child(b_no)
	var b_yes := Ink.button("清 空", Ink.F_BODY, "red", Vector2(30, 14))
	b_yes.pressed.connect(func():
		GameState.wipe()
		app.close_modal()
		app.toast(Ink.T("存檔已清空"), Palette.CINNABAR)
		_refresh())
	row.add_child(b_yes)
	app.modal(panel)

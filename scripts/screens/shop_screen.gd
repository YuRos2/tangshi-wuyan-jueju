extends Control
## 书坊 —— 以文贝购置道具

var app: Node

var _lbl_coins: Label
var _rows: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	GameState.coins_changed.connect(_refresh)
	GameState.items_changed.connect(_refresh)
	_refresh()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)
	var back := Ink.button("‹ 返回", Ink.F_SMALL, "ghost", Vector2(12, 8), 8)
	back.pressed.connect(func(): app.goto("home"))
	top.add_child(back)
	var title := Ink.label("書 坊", Ink.F_H1, Palette.INK, HORIZONTAL_ALIGNMENT_LEFT, true)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(title)
	top.add_child(Ink.spacer())
	_lbl_coins = Ink.label("", Ink.F_BODY, Palette.GOLD)
	_lbl_coins.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_lbl_coins)

	var note := Ink.label("文貝得自完成詩篇：初藏新篇賞賜尤厚，逸品更豐。", Ink.F_TINY, Palette.INK_FAINT)
	col.add_child(note)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 14)
	scroll.add_child(box)

	for id in Defs.ITEM_ORDER:
		var d: Dictionary = Defs.ITEMS[id]
		var panel := Ink.panel(Color(Palette.PAPER_LIGHT, 0.94), Palette.PAPER_EDGE, 2, 12, 14.0)
		box.add_child(panel)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		panel.add_child(h)

		var seal := Seal.new()
		seal.custom_minimum_size = Vector2(66, 66)
		seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		seal.setup([String(d["short"]), "物"], Palette.CINNABAR)
		h.add_child(seal)

		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 4)
		h.add_child(v)
		v.add_child(Ink.label(String(d["name"]), Ink.F_H2, Palette.INK, HORIZONTAL_ALIGNMENT_LEFT, true))
		var desc := Ink.label(String(d["desc"]), Ink.F_TINY, Palette.INK_SOFT)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(size.x - 260.0, 0)
		v.add_child(desc)

		var v2 := VBoxContainer.new()
		v2.add_theme_constant_override("separation", 4)
		v2.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(v2)
		var price := Ink.label("文貝 %d" % int(d["price"]), Ink.F_SMALL, Palette.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
		v2.add_child(price)
		var own := Ink.label("持有 0", Ink.F_TINY, Palette.INK_FAINT, HORIZONTAL_ALIGNMENT_RIGHT)
		v2.add_child(own)
		var buy := Ink.button("購 入", Ink.F_SMALL, "gold", Vector2(20, 10), 10)
		buy.pressed.connect(_buy.bind(id))
		v2.add_child(buy)
		_rows[id] = {"own": own, "buy": buy}

	box.add_child(Ink.vspace(10))
	var tip := Ink.label("清心茶可於主界面「飲茶」處即時服用，不必入局。", Ink.F_TINY, Palette.INK_FAINT)
	box.add_child(tip)


func _refresh() -> void:
	if _lbl_coins == null:
		return
	_lbl_coins.text = Ink.T("文貝 %d" % GameState.coins)
	for id in Defs.ITEM_ORDER:
		var r: Dictionary = _rows.get(id, {})
		if r.is_empty():
			continue
		var n := GameState.item_count(id)
		r["own"].text = Ink.T("持有 %d" % n)
		r["buy"].disabled = GameState.coins < int(Defs.ITEMS[id]["price"])


func _buy(id: String) -> void:
	var d: Dictionary = Defs.ITEMS[id]
	if not GameState.spend_coins(int(d["price"])):
		app.toast(Ink.T("文貝不足"), Palette.CINNABAR)
		Sfx.play("err")
		return
	GameState.add_item(id)
	Sfx.play("coin")
	app.toast(Ink.T("購得 %s" % String(d["name"])), Palette.GOLD)
	_refresh()

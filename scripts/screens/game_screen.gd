extends Control
## 对局界面 —— 上方诗词格，下方字库，道具相伴

var app: Node

const N := 20
const MAX_TILES := 25
const GAP := 9.0

const EMPTY := MiziCell.EMPTY
const FILLED := MiziCell.FILLED
const CORRECT := MiziCell.CORRECT
const WRONG := MiziCell.WRONG
const HINTED := MiziCell.HINTED

var poem: Dictionary = {}
var _ans := ""
var slots: Array = []        # {ch, state, locked}
var pool: Array = []         # {ch, used}
var cursor := 0
var mistakes := 0
var items_used: Dictionary = {}
var used_fu := false
var started_at := 0.0
var busy := false
var finished := false

var _cells: Array = []
var _tiles: Array = []
var _fx: Control
var _top: HBoxContainer
var _lbl_stam: Label
var _lbl_coins: Label
var _btn_swap: Button
var _btn_reset: Button
var _btn_back: Button
var _item_btns: Dictionary = {}

var _r_plaque := Rect2()
var _r_item := Rect2()
var _y_label := 0.0
var _cell := 120.0
var _grid_x := 0.0
var _poem_y := 0.0
var _pool_y := 0.0

# —— 干扰字（重遇已藏之诗时用）——
var _decoy_n := 0
var pool_n := 20
var _pool_rows := 4


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = false
	_build()
	GameState.stamina_changed.connect(_refresh_hud)
	GameState.coins_changed.connect(_refresh_hud)
	GameState.items_changed.connect(_refresh_hud)
	resized.connect(_layout)
	if not GameState.spend_stamina(GameState.COST_PER_GAME):
		app.toast(Ink.T("文氣不足"), Palette.CINNABAR)
		app.goto.call_deferred("home")
		return
	if not _start_round():
		app.goto.call_deferred("home")
		return
	_layout.call_deferred()


# ------------------------------------------------------------------ 构建
func _build() -> void:
	# 顶栏
	_top = HBoxContainer.new()
	_top.add_theme_constant_override("separation", 8)
	add_child(_top)
	_btn_back = Ink.button("‹ 返回", Ink.F_SMALL, "ghost", Vector2(12, 8), 8)
	_btn_back.pressed.connect(_on_back)
	_top.add_child(_btn_back)
	_lbl_stam = Ink.label("文氣 20/20", Ink.F_SMALL, Palette.JADE)
	_top.add_child(_lbl_stam)
	_lbl_coins = Ink.label("文貝 0", Ink.F_SMALL, Palette.GOLD)
	_top.add_child(_lbl_coins)
	_top.add_child(Ink.spacer())
	_btn_swap = Ink.button("換題·1氣", Ink.F_SMALL, "paper", Vector2(12, 8), 8)
	_btn_swap.tooltip_text = "另取一籤（耗文氣 1）"
	_btn_swap.pressed.connect(_on_swap)
	_top.add_child(_btn_swap)
	_btn_reset = Ink.button("重置", Ink.F_SMALL, "paper", Vector2(14, 8), 8)
	_btn_reset.tooltip_text = "盡收落字，重頭再來"
	_btn_reset.pressed.connect(_on_reset)
	_top.add_child(_btn_reset)

	# 米字格
	for i in N:
		var c := MiziCell.new()
		c.index = i
		c.pressed.connect(_on_cell_pressed)
		add_child(c)
		_cells.append(c)

	# 字库（最多 25 张：20 正字 + 5 干扰）
	for i in MAX_TILES:
		var t := CharTile.new()
		t.index = i
		t.pressed.connect(_on_tile_pressed)
		add_child(t)
		_tiles.append(t)

	# 道具条
	for id in Defs.ITEM_ORDER:
		var d: Dictionary = Defs.ITEMS[id]
		var b := Ink.button("%s 0" % d["name"], Ink.F_SMALL, "paper", Vector2(10, 12), 10)
		b.pressed.connect(_use_item.bind(id))
		b.tooltip_text = String(d["desc"])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(b)
		_item_btns[id] = b

	# 动画层
	_fx = Control.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)


# ------------------------------------------------------------------ 布局
func _layout() -> void:
	var W := size.x
	var H := size.y
	if W < 40.0 or H < 40.0:
		return
	var M := 16.0
	var top_h := 60.0
	var plaque_h := clampf(H * 0.090, 92.0, 138.0)
	var label_h := 42.0
	var item_h := clampf(H * 0.108, 96.0, 140.0)

	var rows := 4 + _pool_rows
	var by_w := (W - M * 2.0 - GAP * 4.0) / 5.0
	# 纵向：固定开销（顶栏 + 题牌 + 字库题头 + 道具条 + 五处间隙 + 下边距）
	var fixed := top_h + plaque_h + label_h + item_h + 8.0 * 5.0 + M * 0.5
	var by_h := (H - fixed - GAP * (_pool_rows + 2)) / float(rows)
	_cell = clampf(minf(by_w, by_h), 40.0, 152.0)

	_top.position = Vector2(M, 10)
	_top.size = Vector2(W - M * 2.0, top_h - 14.0)

	var gw := _cell * 5.0 + GAP * 4.0
	_grid_x = (W - gw) * 0.5
	var gh := _cell * 4.0 + GAP * 3.0
	var gh_pool := _cell * _pool_rows + GAP * float(_pool_rows - 1)

	var y := top_h + 4.0
	_r_plaque = Rect2(M, y, W - M * 2.0, plaque_h)
	y += plaque_h

	var bottom := H - item_h - M * 0.5
	var need := gh + gh_pool + label_h + 24.0
	var slack := maxf(0.0, (bottom - y) - need)
	y += 8.0 + slack * 0.45
	_poem_y = y
	y += gh
	y += 8.0 + slack * 0.35
	_y_label = y
	y += label_h
	_pool_y = y + 8.0

	# 格与牌
	for i in N:
		var cx := _grid_x + (i % 5) * (_cell + GAP)
		_cells[i].position = Vector2(cx, _poem_y + floori(i / 5.0) * (_cell + GAP))
		_cells[i].resize_cell(_cell)
	for i in MAX_TILES:
		var cx2 := _grid_x + (i % 5) * (_cell + GAP)
		_tiles[i].position = Vector2(cx2, _pool_y + floori(i / 5.0) * (_cell + GAP))
		_tiles[i].resize_tile(_cell, _cell)

	# 道具条
	_r_item = Rect2(M, H - item_h - M * 0.4, W - M * 2.0, item_h)
	var bx := _r_item.position.x + 6.0
	var bw := _r_item.size.x - 12.0
	var pad := 8.0
	var each := (bw - pad * 3.0) / 4.0
	for k in Defs.ITEM_ORDER.size():
		var b: Button = _item_btns[Defs.ITEM_ORDER[k]]
		b.position = Vector2(bx + k * (each + pad), _r_item.position.y + 10.0)
		b.size = Vector2(each, _r_item.size.y - 20.0)
	_highlight_cursor()
	queue_redraw()


# ------------------------------------------------------------------ 绘制
func _draw() -> void:
	var W := size.x
	# —— 诗题牌 ——
	if _r_plaque.size.x > 10.0:
		var r := _r_plaque
		draw_rect(r, Color(Palette.PAPER_LIGHT, 0.94), true)
		draw_rect(r.grow(-3.0), Color(Palette.INK, 0.30), false, 1.4)
		Gfx.spiral(self, r.position + Vector2(13, 13), 12.0, Color(Palette.CINNABAR, 0.4), 1.2, PI)
		Gfx.spiral(self, Vector2(r.end.x - 13, r.position.y + 13), 12.0, Color(Palette.CINNABAR, 0.4), 1.2, PI * 0.5)
		Gfx.spiral(self, Vector2(r.position.x + 13, r.end.y - 13), 12.0, Color(Palette.CINNABAR, 0.4), 1.2, PI * 1.5)
		Gfx.spiral(self, r.end - Vector2(13, 13), 12.0, Color(Palette.CINNABAR, 0.4), 1.2, 0.0)
		var ri := clampi(int(poem.get("r", 3)), 0, 3)
		var fnt: Font = Ink.fb
		var t := "《" + PoemDB.title_of(poem) + "》"
		var tf := int(r.size.y * 0.40)
		var availw := r.size.x - 30.0
		var tw := fnt.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tf).x
		if tw > availw:
			tf = maxi(16, int(tf * availw / tw * 0.97))
		draw_string(fnt, Vector2(r.position.x, r.position.y + r.size.y * 0.50), t,
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, tf, Palette.INK)
		# 作者 · 出处，与品级签同排居中
		var astr := PoemDB.author_of(poem) + " · 《全唐詩》"
		if _decoy_n > 0:
			astr = PoemDB.author_of(poem) + " · 重溫 · 干擾 %d 字" % _decoy_n
		var af := int(r.size.y * 0.215)
		var aw := Ink.f.get_string_size(astr, HORIZONTAL_ALIGNMENT_LEFT, -1, af).x
		var tagw := af * 2.35
		var tagh := af * 1.30
		var gap := af * 0.75
		var totw := tagw + gap + aw
		var gx := r.position.x + (r.size.x - totw) * 0.5
		var by := r.position.y + r.size.y * 0.84
		var tag := Rect2(gx, by - tagh * 0.80, tagw, tagh)
		draw_rect(tag, Palette.RARITY[ri], true)
		draw_string(Ink.f, Vector2(tag.position.x, tag.position.y + tagh * 0.75), Palette.RARITY_NAME[ri],
				HORIZONTAL_ALIGNMENT_CENTER, tagw, int(tagh * 0.64), Palette.PAPER_LIGHT)
		draw_string(Ink.f, Vector2(gx + tagw + gap, by), astr,
				HORIZONTAL_ALIGNMENT_LEFT, -1, af, Palette.INK_SOFT)

	# —— 字库题头 ——
	if _y_label > 0.0:
		var used := 0
		for p in pool:
			if p.used:
				used += 1
		var txt := "字 庫 · 餘 %d 字" % (pool_n - used)
		if _decoy_n > 0:
			txt += "（含干擾 %d）" % _decoy_n
		draw_string(Ink.f, Vector2(0, _y_label + 26.0), txt,
				HORIZONTAL_ALIGNMENT_CENTER, size.x, Ink.F_SMALL, Palette.INK_SOFT)
		var cy := _y_label + 34.0
		draw_line(Vector2(_grid_x, cy), Vector2(size.x - _grid_x, cy), Color(Palette.INK, 0.25), 1.2, true)

	# —— 道具条底 ——
	if _r_item.size.x > 10.0:
		draw_rect(_r_item, Color(Palette.PAPER_DEEP, 0.55), true)
		draw_line(_r_item.position, Vector2(_r_item.end.x, _r_item.position.y), Color(Palette.INK, 0.20), 1.2, true)


# ------------------------------------------------------------------ 开局
## 取诗：优先未藏之篇；若抽中已藏之诗，则依其记忆阶决定是否掺干扰字
func _pick_poem() -> Dictionary:
	return PoemDB.pick(GameState.last_poem_key, GameState.cards)


## 摆好一局；返回是否成局
func _start_round() -> bool:
	poem = _pick_poem()
	if poem.is_empty():
		app.toast(Ink.T("詩庫為空"), Palette.CINNABAR)
		return false
	_ans = ""
	for para in poem.get("sl" if Ink.simp else "l", []):
		for c in String(para):
			if c != "，" and c != "。" and c != "、" and c != "；":
				_ans += c

	var chars: Array = []
	for i in _ans.length():
		chars.append(_ans.substr(i, 1))
	# 重遇旧卡：记忆阶高者，字库掺入干扰字
	_decoy_n = 0
	var old: Dictionary = GameState.cards.get(PoemDB.key_of(poem), {})
	if not old.is_empty() and int(old.get("stage", 0)) >= GameState.DECOY_FROM_STAGE:
		for c in PoemDB.decoys(poem, GameState.DECOY_COUNT):
			chars.append(String(c))
			_decoy_n += 1
	pool_n = chars.size()
	_pool_rows = ceili(pool_n / 5.0)
	_shuffle(chars)

	slots.clear()
	for i in N:
		slots.append({"ch": "", "state": EMPTY, "locked": false})
	pool.clear()
	for i in MAX_TILES:
		var ch := String(chars[i]) if i < chars.size() else ""
		pool.append({"ch": ch, "used": ch == ""})

	cursor = 0
	mistakes = 0
	items_used.clear()
	used_fu = false
	finished = false
	busy = false
	started_at = Time.get_unix_time_from_system()

	for i in N:
		_cells[i].clear_char()
	for i in MAX_TILES:
		_tiles[i].set_char(String(pool[i]["ch"]))
		_tiles[i].set_used(pool[i]["used"])
		_tiles[i].modulate.a = 0.0 if pool[i]["used"] else 1.0
	_highlight_cursor()
	_refresh_hud()
	_layout()
	queue_redraw()
	return true


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := randi() % (i + 1)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func _refresh_hud() -> void:
	_lbl_stam.text = Ink.T("文氣 %d/%d" % [GameState.stamina, GameState.STAMINA_MAX])
	_lbl_coins.text = Ink.T("文貝 %d" % GameState.coins)
	for id in Defs.ITEM_ORDER:
		var b: Button = _item_btns[id]
		var n := GameState.item_count(id)
		b.text = Ink.T("%s %d" % [Defs.ITEMS[id]["name"], n])
		b.modulate = Color(1, 1, 1, 1.0 if n > 0 else 0.45)
	queue_redraw()


func _highlight_cursor() -> void:
	for i in N:
		_cells[i].focused = (i == cursor and slots[i]["ch"] == "")
		_cells[i].queue_redraw()


func _first_empty(from: int = 0) -> int:
	for i in range(from, N):
		if slots[i]["ch"] == "":
			return i
	return -1


# ------------------------------------------------------------------ 交互
func _on_cell_pressed(i: int) -> void:
	if busy or finished:
		return
	if slots[i]["ch"] == "":
		cursor = i
		_highlight_cursor()
		Sfx.play("ui", -18.0)
	else:
		_take_back(i)


func _on_tile_pressed(i: int) -> void:
	if busy or finished:
		return
	if pool[i]["used"]:
		return
	var target := cursor if slots[cursor]["ch"] == "" else _first_empty()
	if target < 0:
		app.toast(Ink.T("二十字已滿，請先校對"), Palette.CINNABAR)
		return
	_place(i, target)


func _place(tile_idx: int, target: int) -> void:
	var ch := String(pool[tile_idx]["ch"])
	pool[tile_idx]["used"] = true
	_tiles[tile_idx].set_used(true)
	busy = true
	Sfx.play("place")
	var from := Rect2(_tiles[tile_idx].position, _tiles[tile_idx].size)
	var to := Rect2(_cells[target].position, _cells[target].size)
	_fly(ch, from, to, func():
		busy = false
		slots[target]["ch"] = ch
		slots[target]["state"] = FILLED
		_cells[target].set_char(ch, FILLED)
		if _first_empty() >= 0:
			cursor = _first_empty()
		_highlight_cursor()
		_refresh_hud()
		_check_board())


func _take_back(i: int, silent: bool = false) -> void:
	if slots[i]["locked"]:
		app.toast(Ink.T("此字由道具所定，不可移動"), Palette.CINNABAR)
		Sfx.play("err", -10.0)
		return
	if slots[i]["ch"] == "":
		return
	if not silent:
		Sfx.play("take")
	_return_char(i, not silent)
	if _first_empty() >= 0:
		cursor = _first_empty()
	_highlight_cursor()
	_refresh_hud()


## 把格中之字退回字库
func _return_char(i: int, animate: bool) -> void:
	var ch := String(slots[i]["ch"])
	slots[i]["ch"] = ""
	slots[i]["state"] = EMPTY
	_cells[i].clear_char()
	for t in MAX_TILES:
		if pool[t]["used"] and String(pool[t]["ch"]) == ch:
			pool[t]["used"] = false
			if animate:
				var from := Rect2(_cells[i].position, _cells[i].size)
				var to := Rect2(_tiles[t].position, _tiles[t].size)
				var slot := t
				_fly(ch, from, to, func():
					_tiles[slot].set_used(false)
					_tiles[slot].modulate.a = 1.0)
			else:
				_tiles[t].set_used(false)
				_tiles[t].modulate.a = 1.0
			break


func _on_reset() -> void:
	if busy or finished:
		return
	var any := false
	for i in N:
		if slots[i]["ch"] != "":
			any = true
	for i in N:
		if slots[i]["ch"] != "":
			_take_back(i, true)
	cursor = 0
	_highlight_cursor()
	_refresh_hud()
	Sfx.play("take")
	if any:
		app.toast(Ink.T("盡收落字，重頭再來"), Palette.INK_SOFT)


func _on_swap() -> void:
	if busy or finished:
		return
	if not GameState.spend_stamina(GameState.COST_SWAP):
		app.toast(Ink.T("文氣不足，無以換題"), Palette.CINNABAR)
		Sfx.play("err")
		return
	Sfx.play("ui")
	GameState.record_abandon()
	_start_round()
	app.toast(Ink.T("另取一籤"), Palette.JADE)


func _on_back() -> void:
	if finished:
		app.goto("home")
		return
	var placed := 0
	for i in N:
		if String(slots[i]["ch"]) != "":
			placed += 1
	if placed == 0 and items_used.is_empty():
		GameState.record_abandon()
		app.goto("home")
		return
	_confirm_quit()


func _confirm_quit() -> void:
	var panel := Ink.panel(Color(Palette.PAPER, 0.99), Palette.PAPER_EDGE, 2, 14, 22)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	v.add_child(Ink.label("棄此局而去？", Ink.F_H1, Palette.CINNABAR, HORIZONTAL_ALIGNMENT_CENTER, true))
	var tip := Ink.label("已落之字與所用道具皆不復還。", Ink.F_SMALL, Palette.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(400, 0)
	v.add_child(tip)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	var b_no := Ink.button("續作詩", Ink.F_BODY, "paper", Vector2(30, 14))
	b_no.pressed.connect(func(): app.close_modal())
	row.add_child(b_no)
	var b_yes := Ink.button("棄 局", Ink.F_BODY, "red", Vector2(30, 14))
	b_yes.pressed.connect(func():
		app.close_modal()
		GameState.record_abandon()
		app.goto("home"))
	row.add_child(b_yes)
	app.modal(panel)


# ------------------------------------------------------------------ 校勘
func _check_board() -> void:
	if busy or finished:
		return
	if _first_empty() >= 0:
		return
	var wrong: Array = []
	for i in N:
		if String(slots[i]["ch"]) == _ans.substr(i, 1):
			slots[i]["state"] = CORRECT
			_cells[i].set_state(CORRECT)
		else:
			wrong.append(i)
	if wrong.is_empty():
		_win()
		return

	mistakes += 1
	Sfx.play("err")
	busy = true
	for i in wrong:
		_cells[i].set_state(WRONG)
		_cells[i].shake()
	app.toast(Ink.T("有 %d 字未合，退回字庫" % wrong.size()), Palette.CINNABAR)
	await get_tree().create_timer(0.9).timeout
	for i in wrong:
		slots[i]["state"] = EMPTY
		_cells[i].set_state(EMPTY)
		_return_char(i, false)
	if _first_empty() >= 0:
		cursor = _first_empty()
	busy = false
	_highlight_cursor()
	_refresh_hud()


# ------------------------------------------------------------------ 得成
func _win() -> void:
	finished = true
	busy = true
	Sfx.play("win")
	for i in N:
		var c: MiziCell = _cells[i]
		c.set_state(CORRECT)
		var tw := create_tween()
		tw.tween_interval(0.03 * i)
		tw.tween_property(c, "scale", Vector2(1.10, 1.10), 0.12)
		tw.tween_property(c, "scale", Vector2.ONE, 0.16)
	await get_tree().create_timer(1.1).timeout

	var secs := int(Time.get_unix_time_from_system() - started_at)
	var hint := items_used.has("yan") or items_used.has("jing")
	var res: Dictionary = GameState.record_win(poem, mistakes, secs, used_fu, not items_used.is_empty(), hint)
	busy = false
	_show_result(res, secs)


func _show_result(res: Dictionary, secs: int) -> void:
	var rec: Dictionary = res["record"]
	var ri := int(res.get("rarity", 3))
	var panel := Ink.panel(Color(Palette.PAPER, 0.99), Palette.PAPER_EDGE, 2, 16, 18)

	var vs := size
	var card_h: float = minf(vs.y * 0.56, 860.0)
	var card_w: float = card_h * 0.714
	if card_w > vs.x - 90.0:
		card_w = vs.x - 90.0
		card_h = card_w / 0.714

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	var head_txt := "此 局 已 成"
	var sub_txt := "%s · %s · 得文貝 %d" % [Palette.RARITY_NAME[ri], "初藏新篇" if res["new"] else "重溫舊卷", int(res.get("coin", 0))]
	var srs: Dictionary = res.get("srs", {})
	if not res["new"]:
		sub_txt += " · 記憶階 %d" % int(srs.get("to", 0))
	var head := Ink.label(head_txt, Ink.F_H1, Palette.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	v.add_child(head)
	var sub := Ink.label(sub_txt, Ink.F_SMALL, Palette.RARITY[ri], HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(sub)

	var card := CardWidget.new()
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.setup(rec, false)
	card.pressed.connect(func(_i: int): app.modal(CardViewer.build(app, rec)))
	v.add_child(card)

	var meta := "耗時 %s · 失誤 %d 次" % [Defs.duration_cn(secs), mistakes]
	if bool(res.get("perfect", false)):
		meta += " · 一氣呵成"
	elif used_fu:
		meta += " · 假琅嬛符"
	if _decoy_n > 0:
		meta += " · 干擾 %d 字未用" % _decoy_n
	var ml := Ink.label(meta, Ink.F_SMALL, Palette.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(ml)

	var unlocked: Array = res.get("unlocked", [])
	if not unlocked.is_empty():
		var names: Array = []
		for id in unlocked:
			var a := Defs.ach_by_id(String(id))
			if not a.is_empty():
				names.append("「%s」" % a["name"])
		var al := Ink.label(Ink.T("成就 " + "、".join(names)), Ink.F_SMALL, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(al)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	var b_again := Ink.button("再來一局", Ink.F_BODY, "gold", Vector2(26, 14))
	b_again.disabled = not GameState.can_play()
	b_again.pressed.connect(func():
		app.close_modal()
		_next_round())
	row.add_child(b_again)
	var b_ok := Ink.button("收 下", Ink.F_BODY, "ink", Vector2(30, 14))
	b_ok.pressed.connect(func():
		app.close_modal()
		app.goto("home"))
	row.add_child(b_ok)

	app.modal(panel, false)
	# 卡片自小放大，如画卷展开
	card.pivot_offset = Vector2(card_w, card_h) * 0.5
	card.scale = Vector2(0.86, 0.86)
	card.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(card, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.22)
	await get_tree().create_timer(0.5).timeout
	Sfx.play("seal", -4.0)


func _next_round() -> void:
	if not GameState.spend_stamina(GameState.COST_PER_GAME):
		app.toast(Ink.T("文氣不足"), Palette.CINNABAR)
		return
	_start_round()


# ------------------------------------------------------------------ 道具
func _use_item(id: String) -> void:
	if finished:
		app.toast(Ink.T("此局已成"), Palette.INK_SOFT)
		return
	var count := GameState.item_count(id)
	if count <= 0:
		app.toast(Ink.T("%s 已用盡，可至書坊添置" % Defs.ITEMS[id]["name"]), Palette.CINNABAR)
		Sfx.play("err", -10.0)
		return
	if busy:
		return
	match id:
		"yan":
			_hint_one()
		"jing":
			_peek()
		"cha":
			if GameState.stamina >= GameState.STAMINA_MAX:
				app.toast(Ink.T("文氣已滿，無需添茶"), Palette.INK_SOFT)
				return
			GameState.use_item("cha")
			items_used["cha"] = int(items_used.get("cha", 0)) + 1
			GameState.add_stamina(5)
			Sfx.play("coin")
			app.toast(Ink.T("清心茶 · 文氣 +5"), Palette.JADE)
		"fu":
			_auto_complete()


func _hint_one() -> void:
	var idx := _first_empty()
	if idx < 0:
		app.toast(Ink.T("二十字已滿"), Palette.INK_SOFT)
		return
	var ch := _ans.substr(idx, 1)
	var tile := -1
	for t in MAX_TILES:
		if not pool[t]["used"] and String(pool[t]["ch"]) == ch:
			tile = t
			break
	if tile < 0:
		return
	GameState.use_item("yan")
	items_used["yan"] = int(items_used.get("yan", 0)) + 1
	pool[tile]["used"] = true
	_tiles[tile].set_used(true)
	busy = true
	Sfx.play("place", -3.0)
	app.toast(Ink.T("青玉硯 · 添一字"), Palette.JADE)
	var from := Rect2(_tiles[tile].position, _tiles[tile].size)
	var to := Rect2(_cells[idx].position, _cells[idx].size)
	_fly(ch, from, to, func():
		busy = false
		slots[idx]["ch"] = ch
		slots[idx]["locked"] = true
		slots[idx]["state"] = HINTED
		_cells[idx].set_char(ch, HINTED)
		if _first_empty() >= 0:
			cursor = _first_empty()
		_highlight_cursor()
		_refresh_hud()
		_check_board())


func _peek() -> void:
	GameState.use_item("jing")
	items_used["jing"] = int(items_used.get("jing", 0)) + 1
	Sfx.play("ui")
	var panel := Ink.panel(Color(Palette.PAPER, 0.99), Palette.PAPER_EDGE, 2, 14, 22)
	panel.custom_minimum_size = Vector2(minf(size.x - 70.0, 620.0), 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(Ink.label("菱花鏡 · 照影三息", Ink.F_H2, Palette.JADE, HORIZONTAL_ALIGNMENT_CENTER, true))
	v.add_child(Ink.rule(Palette.PAPER_EDGE, 1.0))
	v.add_child(Ink.label("《" + PoemDB.title_of(poem) + "》", Ink.F_BODY, Palette.INK, HORIZONTAL_ALIGNMENT_CENTER))
	for para in poem.get("sl" if Ink.simp else "l", []):
		v.add_child(Ink.label(String(para), Ink.F_H1, Palette.INK, HORIZONTAL_ALIGNMENT_CENTER, true))
	var bar := InkBar.new()
	bar.col = Palette.JADE
	bar.custom_minimum_size = Vector2(0, 10)
	v.add_child(bar)
	app.modal(panel)
	# 三息之后自动收起
	_tick_peek(panel.get_parent(), bar)


func _tick_peek(holder: Node, bar: InkBar) -> void:
	for i in range(10, -1, -1):
		if not is_instance_valid(holder) or not holder.is_inside_tree():
			return
		bar.set_values(i, 10)
		await get_tree().create_timer(0.3).timeout
	if is_instance_valid(app) and app.modal_open():
		app.close_modal()


func _auto_complete() -> void:
	GameState.use_item("fu")
	items_used["fu"] = int(items_used.get("fu", 0)) + 1
	used_fu = true
	busy = true
	Sfx.play("coin", -2.0)
	app.toast(Ink.T("琅嬛符 · 天成補全"), Palette.GOLD)
	for i in N:
		if String(slots[i]["ch"]) == _ans.substr(i, 1):
			continue
		if String(slots[i]["ch"]) != "":
			_return_char(i, false)
	var delay := 0.0
	for i in N:
		if String(slots[i]["ch"]) != "":
			continue
		var ch := _ans.substr(i, 1)
		var tile := -1
		for t in MAX_TILES:
			if not pool[t]["used"] and String(pool[t]["ch"]) == ch:
				tile = t
				break
		if tile < 0:
			continue
		pool[tile]["used"] = true
		_tiles[tile].set_used(true)
		slots[i]["ch"] = ch
		slots[i]["locked"] = true
		slots[i]["state"] = HINTED
		_cells[i].set_char(ch, HINTED)
		_cells[i].modulate.a = 0.0
		var cell: MiziCell = _cells[i]
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(cell, "modulate:a", 1.0, 0.18)
		delay += 0.045
	_refresh_hud()
	await get_tree().create_timer(delay + 0.35).timeout
	for i in N:
		_cells[i].modulate.a = 1.0
	busy = false
	_check_board()


# ------------------------------------------------------------------ 动画
## 字牌飞入 / 飞回
func _fly(ch: String, from: Rect2, to: Rect2, cb: Callable) -> void:
	var g := CharTile.new()
	g.pressable = false
	g.hover_enabled = false
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.add_child(g)
	g.resize_tile(from.size.x, from.size.y)
	g.pivot_offset = from.size * 0.5
	g.position = from.position
	g.set_char(ch)
	var sc := to.size.x / maxf(1.0, from.size.x)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(g, "position", to.position + (to.size - from.size) * 0.5, 0.24).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(g, "scale", Vector2(sc, sc), 0.24).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(g, "modulate:a", 0.25, 0.24)
	tw.chain().tween_callback(g.queue_free)
	tw.chain().tween_callback(cb)

extends Node
## GameState —— 存档 / 文气 / 文贝 / 道具 / 卡牌 / 成就（autoload 单例）

const SAVE_PATH := "user://tangshi_save.json"
const SAVE_VER := 2

const STAMINA_MAX := 20
const STAMINA_REGEN := 180.0      # 每 3 分钟回复 1 点文气
const COST_PER_GAME := 2          # 每局耗文气
const COST_SWAP := 1              # 换题耗文气
const START_COINS := 60
const START_ITEMS := {"yan": 1, "jing": 1, "cha": 1, "fu": 0}

## 首通奖励（按品级）: 逸 神 妙 能
const REWARD_NEW := [30, 22, 16, 12]
## 重温奖励
const REWARD_OLD := [14, 10, 7, 5]
const PERFECT_BONUS := 5

# ---------------------------------------------------------------- 记忆曲线
## 档期阶梯（日）；索引 = 记忆阶
const SRS_LADDER := [1, 2, 4, 7, 15, 30, 60, 120]
const SRS_MAX_STAGE := 7
const SRS_LAPSE_SECS := 600            # 生疏后 10 分钟再会
## 闪现时长（秒，按记忆阶递增而递减：记得越牢，看得越快）
const FLASH_SECS := [3.2, 3.2, 3.0, 2.8, 2.6, 2.4, 2.2, 2.0]
## 温习回赏（q=1 未记 / 2 略记 / 3 记得）
const REVIEW_STAMINA := [1, 1, 2]
## 温习文贝基数（按品级）
const REVIEW_COIN := [5, 4, 3, 2]
const REVIEW_STAMINA_CAP := 10         # 每日由温习回气上限
const REVIEW_COIN_CAP := 60            # 每日由温习得贝上限
## 记忆阶达到此值后，字库掺入干扰字
const DECOY_FROM_STAGE := 4
const DECOY_COUNT := 5

signal stamina_changed
signal coins_changed
signal items_changed
signal cards_changed
signal achievements_changed

var stamina := STAMINA_MAX
var stamina_ts := 0.0
var coins := START_COINS
var items: Dictionary = {}
var cards: Dictionary = {}
var stats := {"played": 0, "win": 0, "perfect": 0, "sec": 0, "reviews": 0, "recall": 0}
var ach: Dictionary = {}
var settings := {"simp": false, "sfx": true, "seen_help": false}
var last_poem_key := ""

# —— 记忆曲线相关状态 ——
var review_day := 0            # 当日日期（YYYYMMDD），用于每日上限重置
var stamina_from_review := 0   # 今日已由复习回得文气
var coins_from_review := 0     # 今日已由复习得文贝
var streak := 0                # 连续温习天数
var last_review_day := 0

var _dirty := false
var _save_cool := 0.0
var _tick := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	_roll_day()
	Ink.set_simp(bool(settings.get("simp", false)))
	Sfx.enabled = bool(settings.get("sfx", true))


func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 1.0:
		_tick = 0.0
		if refresh_stamina():
			stamina_changed.emit()


## 任何变动立即落盘（存档不大，避免网页版关页丢档）
func mark_dirty() -> void:
	_dirty = true
	_save_cool = 1.5
	_save()


func _now() -> float:
	return Time.get_unix_time_from_system()


# ---------------------------------------------------------------- 文气
## 依时间结算文气回复；返回是否有变化
func refresh_stamina() -> bool:
	var t := _now()
	if stamina >= STAMINA_MAX:
		stamina_ts = t
		return false
	var elapsed := t - stamina_ts
	if elapsed <= 0.0:
		return false
	var gained := int(floor(elapsed / STAMINA_REGEN))
	if gained <= 0:
		return false
	stamina = mini(STAMINA_MAX, stamina + gained)
	if stamina >= STAMINA_MAX:
		stamina_ts = t
	else:
		stamina_ts += gained * STAMINA_REGEN
	mark_dirty()
	return true


## 距离下一点文气所需秒数（已满则 0）
func stamina_next_secs() -> int:
	if stamina >= STAMINA_MAX:
		return 0
	var left := STAMINA_REGEN - (_now() - stamina_ts)
	return maxi(0, int(ceil(left)))


func can_play() -> bool:
	refresh_stamina()
	return stamina >= COST_PER_GAME


func spend_stamina(n: int) -> bool:
	refresh_stamina()
	if stamina < n:
		return false
	stamina -= n
	if stamina == STAMINA_MAX - 1:
		stamina_ts = _now()
	mark_dirty()
	stamina_changed.emit()
	return true


func add_stamina(n: int) -> void:
	refresh_stamina()
	stamina = clampi(stamina + n, 0, STAMINA_MAX)
	mark_dirty()
	stamina_changed.emit()


# ---------------------------------------------------------------- 文贝
func add_coins(n: int) -> void:
	coins += n
	mark_dirty()
	coins_changed.emit()


func spend_coins(n: int) -> bool:
	if coins < n:
		return false
	coins -= n
	mark_dirty()
	coins_changed.emit()
	return true


# ---------------------------------------------------------------- 道具
func item_count(id: String) -> int:
	return int(items.get(id, 0))


func add_item(id: String, n: int = 1) -> void:
	items[id] = maxi(0, item_count(id) + n)
	mark_dirty()
	items_changed.emit()


func use_item(id: String) -> bool:
	if item_count(id) <= 0:
		return false
	items[id] = item_count(id) - 1
	mark_dirty()
	items_changed.emit()
	return true


# ---------------------------------------------------------------- 卡牌
func has_card(key: String) -> bool:
	return cards.has(key)


func card(key: String) -> Dictionary:
	return cards.get(key, {})


func card_count() -> int:
	return cards.size()


func rarity_counts() -> Array:
	var out := [0, 0, 0, 0]
	for k in cards:
		var r := int(cards[k].get("r", 3))
		out[clampi(r, 0, 3)] += 1
	return out


## 收录一次完成：返回结算信息
func record_win(poem: Dictionary, mistakes: int, seconds: int, used_fu: bool, used_any_item: bool, used_hint: bool = false) -> Dictionary:
	var key := PoemDB.key_of(poem)
	var r := clampi(int(poem.get("r", 3)), 0, 3)
	var is_new := not cards.has(key)
	var perfect := mistakes == 0 and not used_fu

	var rec: Dictionary = cards.get(key, {})
	if is_new:
		rec["no"] = cards.size() + 1
	rec["t"] = poem.get("t", "")
	rec["a"] = poem.get("a", "")
	rec["l"] = poem.get("l", [])
	rec["st"] = poem.get("st", "")
	rec["sa"] = poem.get("sa", "")
	rec["sl"] = poem.get("sl", [])
	rec["r"] = r
	rec["n"] = int(rec.get("n", 0)) + 1
	rec["ts"] = int(_now())
	rec["mis"] = mistakes
	rec["sec"] = seconds
	rec["fu"] = used_fu
	if perfect:
		rec["perf"] = int(rec.get("perf", 0)) + 1
	# —— 记忆曲线：新卡入档（明日首温），旧卡顺带推进档期 ——
	var now := int(_now())
	var srs: Dictionary = {}
	if is_new:
		srs = _srs_enroll(rec, now)
	else:
		srs = _srs_update(rec, quality_of(mistakes, used_hint, used_fu), now)
	cards[key] = rec

	var coin: int = (REWARD_NEW[r] if is_new else REWARD_OLD[r])
	if perfect:
		coin += PERFECT_BONUS

	stats["played"] = int(stats["played"]) + 1
	stats["win"] = int(stats["win"]) + 1
	if perfect:
		stats["perfect"] = int(stats["perfect"]) + 1
	stats["sec"] = int(stats["sec"]) + seconds

	coins += coin
	last_poem_key = key
	mark_dirty()
	cards_changed.emit()
	coins_changed.emit()

	if used_any_item:
		pass
	unlock_nohelp_if(r == 0 and not used_any_item)
	var unlocked := _check_achievements()
	return {
		"key": key, "new": is_new, "coin": coin, "perfect": perfect,
		"rarity": r, "unlocked": unlocked, "record": rec, "srs": srs,
	}


## 记录一次放弃（仍计入开局数）
func record_abandon() -> void:
	stats["played"] = int(stats["played"]) + 1
	mark_dirty()


# ---------------------------------------------------------------- 记忆曲线
func _today() -> int:
	var d := Time.get_datetime_dict_from_system()
	return int(d["year"]) * 10000 + int(d["month"]) * 100 + int(d["day"])


## 跨日则重置每日上限
func _roll_day() -> void:
	var t := _today()
	if review_day != t:
		review_day = t
		stamina_from_review = 0
		coins_from_review = 0
		mark_dirty()


func is_due(rec: Dictionary) -> bool:
	return int(rec.get("due", 0)) <= int(_now())


## 到期卡 key，按到期早晚排序
func due_keys() -> Array:
	_roll_day()
	var out: Array = []
	for k in cards:
		if is_due(cards[k]):
			out.append(k)
	out.sort_custom(func(a, b): return int(cards[a].get("due", 0)) < int(cards[b].get("due", 0)))
	return out


func due_count() -> int:
	return due_keys().size()


## 全部已藏卡的记忆阶之和（用于均阶）
func stage_sum() -> int:
	var s := 0
	for k in cards:
		s += int(cards[k].get("stage", 0))
	return s


func memorized_count(min_stage: int = 5) -> int:
	var n := 0
	for k in cards:
		if int(cards[k].get("stage", 0)) >= min_stage:
			n += 1
	return n


## 未来七日到期分布（索引 0 = 今日/逾期）
func due_next_days(days: int = 7) -> Array:
	var now := int(_now())
	var bucket := []
	bucket.resize(days)
	bucket.fill(0)
	for k in cards:
		var left := int(cards[k].get("due", 0)) - now
		var d := 0 if left <= 0 else int(ceil(left / 86400.0))
		if d < days:
			bucket[d] += 1
	return bucket


## 到期文案
func due_label(rec: Dictionary) -> String:
	return Defs.due_cn(int(rec.get("due", 0)), int(_now()))


## 回忆质量：3 熟记 / 2 略记 / 1 生疏（用于开卷重遇已藏之诗）
func quality_of(mistakes: int, used_hint: bool, used_fu: bool) -> int:
	if used_fu:
		return 1
	if mistakes == 0:
		return 2 if used_hint else 3
	if mistakes <= 2:
		return 1 if used_hint else 2
	return 1


func quality_name(q: int) -> String:
	return ["生疏", "略記", "熟記"][clampi(q - 1, 0, 2)]


## 该记忆阶的闪现时长
func flash_secs(stage: int) -> float:
	return FLASH_SECS[clampi(stage, 0, FLASH_SECS.size() - 1)]


## 推进记忆档期，返回本次变动
func _srs_update(rec: Dictionary, q: int, now: int) -> Dictionary:
	var stage0 := int(rec.get("stage", 0))
	var stage := stage0
	var secs := 0
	if q >= 3:
		stage = mini(SRS_MAX_STAGE, stage0 + 1)
		secs = int(SRS_LADDER[stage]) * 86400
	elif q == 2:
		secs = int(int(SRS_LADDER[stage0]) * 86400 * 0.6)
	else:
		stage = maxi(0, stage0 - 1)
		secs = SRS_LAPSE_SECS
		rec["lapse"] = int(rec.get("lapse", 0)) + 1
	rec["stage"] = stage
	rec["due"] = now + secs
	rec["last"] = now
	return {"from": stage0, "to": stage, "secs": secs, "due": rec["due"], "q": q}


func _touch_streak() -> void:
	var today := _today()
	if last_review_day == today:
		return
	var y := Time.get_datetime_dict_from_unix_time(int(_now()) - 86400)
	var yday := int(y["year"]) * 10000 + int(y["month"]) * 100 + int(y["day"])
	streak = streak + 1 if last_review_day == yday else 1
	last_review_day = today


## 闪卡温习结算：依自评 q（1 未记 / 2 略记 / 3 记得）推进档期；到期者回文氣与文貝
func record_review(key: String, q: int) -> Dictionary:
	if not cards.has(key):
		return {}
	_roll_day()
	var now := int(_now())
	var rec: Dictionary = cards[key]
	var was_due := is_due(rec)
	var stage_before := int(rec.get("stage", 0))
	q = clampi(q, 1, 3)
	var srs: Dictionary = {}
	if was_due:
		srs = _srs_update(rec, q, now)
	else:
		# 随意温习：档期不变
		srs = {"from": stage_before, "to": stage_before, "secs": 0, "due": int(rec.get("due", 0)), "q": q, "practice": true}

	rec["rev"] = int(rec.get("rev", 0)) + 1
	rec["n"] = int(rec.get("n", 0)) + 1
	rec["ts"] = now

	var st_gain := 0
	var coin := 0
	if was_due:
		st_gain = mini(int(REVIEW_STAMINA[q - 1]), maxi(0, REVIEW_STAMINA_CAP - stamina_from_review))
		stamina_from_review += st_gain
		var r := clampi(int(rec.get("r", 3)), 0, 3)
		coin = int(REVIEW_COIN[r]) + int(mini(stage_before, 6) / 2) + (1 if q >= 3 else 0)
		coin = mini(coin, maxi(0, REVIEW_COIN_CAP - coins_from_review))
		coins_from_review += coin
		_touch_streak()

	stamina = clampi(stamina + st_gain, 0, STAMINA_MAX)
	coins += coin
	stats["reviews"] = int(stats["reviews"]) + 1
	if q >= 3:
		stats["recall"] = int(stats["recall"]) + 1

	mark_dirty()
	cards_changed.emit()
	coins_changed.emit()
	stamina_changed.emit()
	var unlocked := _check_achievements()
	return {
		"q": q, "srs": srs, "stamina": st_gain, "coin": coin, "was_due": was_due,
		"stage_from": stage_before, "stage_to": int(rec.get("stage", 0)),
		"next": due_label(rec), "key": key, "record": rec, "unlocked": unlocked,
	}


## 新卡入档：记忆阶 0，明日首次温习
func _srs_enroll(rec: Dictionary, now: int) -> Dictionary:
	rec["stage"] = 0
	rec["due"] = now + int(SRS_LADDER[0]) * 86400
	rec["last"] = now
	rec["lapse"] = int(rec.get("lapse", 0))
	rec["rev"] = int(rec.get("rev", 0))
	return {"from": 0, "to": 0, "secs": int(SRS_LADDER[0]) * 86400, "due": rec["due"], "q": 3}


# ---------------------------------------------------------------- 成就
func _check_achievements() -> Array:
	var rc := rarity_counts()
	var total := card_count()
	var perfect := int(stats.get("perfect", 0))
	var unlocked: Array = []
	var repeat_max := 0
	for k in cards:
		repeat_max = maxi(repeat_max, int(cards[k].get("n", 0)))

	var ok := {
		"boot": total >= 1,
		"p1": perfect >= 1,
		"p10": perfect >= 10,
		"n10": total >= 10,
		"n30": total >= 30,
		"n100": total >= 100,
		"n300": total >= 300,
		"r0": rc[0] >= 1,
		"r0x5": rc[0] >= 5,
		"all4": rc[0] > 0 and rc[1] > 0 and rc[2] > 0 and rc[3] > 0,
		"repe": repeat_max >= 5,
		"rev1": int(stats.get("reviews", 0)) >= 1,
		"rev30": int(stats.get("reviews", 0)) >= 30,
		"rev200": int(stats.get("reviews", 0)) >= 200,
		"recall50": int(stats.get("recall", 0)) >= 50,
		"streak7": streak >= 7,
		"mem5": memorized_count(5) >= 5,
	}
	for id in ok:
		if ok[id] and not ach.has(id):
			ach[id] = true
			var a := Defs.ach_by_id(id)
			coins += int(a.get("coin", 0))
			unlocked.append(id)
	if not unlocked.is_empty():
		mark_dirty()
		achievements_changed.emit()
		coins_changed.emit()
	return unlocked


## 特殊成就：不假外物（需在结算时携带条件）
func unlock_nohelp_if(cond: bool) -> void:
	if cond and not ach.has("nohelp"):
		ach["nohelp"] = true
		var a := Defs.ach_by_id("nohelp")
		coins += int(a.get("coin", 0))
		mark_dirty()
		achievements_changed.emit()
		coins_changed.emit()


func achievement_done(id: String) -> bool:
	return ach.has(id)


# ---------------------------------------------------------------- 设置
func set_simp(v: bool) -> void:
	settings["simp"] = v
	Ink.set_simp(v)
	mark_dirty()


func set_sfx(v: bool) -> void:
	settings["sfx"] = v
	Sfx.enabled = v
	mark_dirty()


# ---------------------------------------------------------------- 存读档
func _load() -> void:
	items = START_ITEMS.duplicate(true)
	stamina = STAMINA_MAX
	stamina_ts = _now()
	if not FileAccess.file_exists(SAVE_PATH):
		mark_dirty()
		return
	var txt := FileAccess.get_file_as_string(SAVE_PATH)
	var d = JSON.parse_string(txt)
	if not (d is Dictionary):
		return
	var ver := int(d.get("ver", 1))
	stamina = clampi(int(d.get("stamina", STAMINA_MAX)), 0, STAMINA_MAX)
	stamina_ts = float(d.get("stamina_ts", _now()))
	coins = int(d.get("coins", START_COINS))
	var it = d.get("items", {})
	if it is Dictionary:
		for k in it:
			items[k] = int(it[k])
	var cd = d.get("cards", {})
	if cd is Dictionary:
		cards = cd
	var st = d.get("stats", {})
	if st is Dictionary:
		for k in stats.keys():
			if st.has(k):
				stats[k] = int(st[k])
	var ac = d.get("ach", {})
	if ac is Dictionary:
		ach = ac
	var se = d.get("settings", {})
	if se is Dictionary:
		for k in settings.keys():
			if se.has(k):
				settings[k] = se[k]
	last_poem_key = String(d.get("last", ""))
	review_day = int(d.get("review_day", 0))
	stamina_from_review = int(d.get("stamina_from_review", 0))
	coins_from_review = int(d.get("coins_from_review", 0))
	streak = int(d.get("streak", 0))
	last_review_day = int(d.get("last_review_day", 0))
	if not stats.has("reviews"):
		stats["reviews"] = 0
	if not stats.has("recall"):
		stats["recall"] = 0
	if ver < 2:
		_migrate_v2()
	_roll_day()
	refresh_stamina()


## 旧存档升到 v2：所有旧卡立即入档（现下到期，可即刻温习）
func _migrate_v2() -> void:
	var now := int(_now())
	for k in cards:
		var rec: Dictionary = cards[k]
		if not rec.has("stage"):
			rec["stage"] = 0
			rec["last"] = int(rec.get("ts", now))
			rec["rev"] = maxi(0, int(rec.get("n", 1)) - 1)
			rec["lapse"] = 0
			rec["due"] = now
	mark_dirty()


func _save() -> void:
	_dirty = false
	_save_cool = 0.0
	var d := {
		"ver": SAVE_VER,
		"stamina": stamina,
		"stamina_ts": stamina_ts,
		"coins": coins,
		"items": items,
		"cards": cards,
		"stats": stats,
		"ach": ach,
		"settings": settings,
		"last": last_poem_key,
		"review_day": review_day,
		"stamina_from_review": stamina_from_review,
		"coins_from_review": coins_from_review,
		"streak": streak,
		"last_review_day": last_review_day,
	}
	var fa := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if fa == null:
		return
	fa.store_string(JSON.stringify(d))
	fa.close()


func wipe() -> void:
	cards.clear()
	ach.clear()
	items = START_ITEMS.duplicate(true)
	coins = START_COINS
	stamina = STAMINA_MAX
	stamina_ts = _now()
	stats = {"played": 0, "win": 0, "perfect": 0, "sec": 0, "reviews": 0, "recall": 0}
	last_poem_key = ""
	review_day = _today()
	stamina_from_review = 0
	coins_from_review = 0
	streak = 0
	last_review_day = 0
	mark_dirty()
	_save()
	cards_changed.emit()
	achievements_changed.emit()
	items_changed.emit()
	coins_changed.emit()
	stamina_changed.emit()

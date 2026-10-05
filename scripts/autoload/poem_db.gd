extends Node
## PoemDB —— 詩庫（全唐詩五言絕句 3716 首，含繁簡雙文與品級）
## 首次取詩時才解析 JSON，保證主界面秒開。

const DATA_PATH := "res://data/poems.json"

signal library_ready

var poems: Array = []
var meta: Dictionary = {}
var by_key: Dictionary = {}
var loaded := false

## 抽取权重：能品常见、逸品罕遇
const BASE_WEIGHT := [5.0, 12.0, 30.0, 53.0]


func ensure_loaded() -> void:
	if loaded:
		return
	loaded = true
	var txt := FileAccess.get_file_as_string(DATA_PATH)
	var d = JSON.parse_string(txt)
	if d is Dictionary:
		meta = d.get("meta", {})
		poems = d.get("poems", [])
		by_key.clear()
		for p in poems:
			by_key[key_of(p)] = p
	library_ready.emit()


func count() -> int:
	return poems.size()


func get_by_key(k: String) -> Dictionary:
	ensure_loaded()
	return by_key.get(k, {})


## 取 n 个不在该诗中的干扰字（用于高阶记忆温习）
func decoys(poem: Dictionary, n: int) -> Array:
	ensure_loaded()
	var in_poem := {}
	for para in poem.get("l", []):
		for c in String(para):
			in_poem[c] = true
	for para in poem.get("sl", []):
		for c in String(para):
			in_poem[c] = true
	var out: Array = []
	var guard := 0
	while out.size() < n and guard < 400:
		guard += 1
		var p: Dictionary = poems[randi() % poems.size()]
		var stop := false
		for para in p.get("sl", []):
			for c in String(para):
				if c == "，" or c == "。":
					continue
				if in_poem.has(c) or out.has(c):
					continue
				out.append(c)
				if out.size() >= n:
					stop = true
					break
			if stop:
				break
	return out


static func key_of(p: Dictionary) -> String:
	return String(p.get("a", "")) + "|" + String(p.get("t", "")) + "|" + (p.get("l", [""])[0] if p.get("l") else "")


## 抽取一首詩；exclude 用于避免与上一首重复，collected 为已收藏 key 集合
func pick(exclude: String = "", collected: Dictionary = {}) -> Dictionary:
	ensure_loaded()
	if poems.is_empty():
		return {}
	var total := 0.0
	var weights := PackedFloat32Array()
	weights.resize(poems.size())
	for i in poems.size():
		var p: Dictionary = poems[i]
		var w: float = BASE_WEIGHT[clampi(int(p.get("r", 3)), 0, 3)]
		if not collected.has(key_of(p)):
			w *= 2.4
		# 重字极多的诗篇略降权（玩起来枯燥）
		if int(p.get("mx", 0)) >= 4:
			w *= 0.5
		if exclude != "" and key_of(p) == exclude:
			w = 0.0
		weights[i] = w
		total += w
	if total <= 0.0:
		return poems[randi() % poems.size()]
	var roll := randf() * total
	for i in poems.size():
		roll -= weights[i]
		if roll <= 0.0:
			return poems[i]
	return poems[poems.size() - 1]


## 取指定品級中的一首（用于首页「今日诗句」之类）
func pick_of_rarity(r: int) -> Dictionary:
	ensure_loaded()
	var bucket: Array = []
	for p in poems:
		if int(p.get("r", 3)) == r:
			bucket.append(p)
	if bucket.is_empty():
		return pick()
	return bucket[randi() % bucket.size()]


## 取詩文（依當前繁簡設定）
func lines_of(p: Dictionary) -> Array:
	var simp: bool = Ink.simp
	var arr = p.get("sl" if simp else "l", [])
	return arr


func title_of(p: Dictionary) -> String:
	return String(p.get("st" if Ink.simp else "t", p.get("t", "")))


func author_of(p: Dictionary) -> String:
	return String(p.get("sa" if Ink.simp else "a", p.get("a", "")))

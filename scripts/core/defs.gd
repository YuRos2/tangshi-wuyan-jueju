## 静态数据定义：道具、成就
class_name Defs

## 道具（書坊可購）
## short —— 道具条上的单字标记
const ITEMS := {
	"yan": {
		"name": "青玉硯", "short": "硯", "price": 30,
		"desc": "磨墨落筆：為下一空格自動填上正解，並鎖定不移。",
		"tip": "已添一字",
	},
	"jing": {
		"name": "菱花鏡", "short": "鏡", "price": 45,
		"desc": "照影三息：暫現全詩三秒，助君憶起下文。",
		"tip": "照影三息",
	},
	"cha": {
		"name": "清心茶", "short": "茶", "price": 60,
		"desc": "靜心凝神：恢復 5 點文氣。",
		"tip": "文氣 +5",
	},
	"fu": {
		"name": "琅嬛符", "short": "符", "price": 200,
		"desc": "天成之術：一鍵補全全詩。然天成之篇，不得「一氣呵成」之評。",
		"tip": "天成補全",
	},
}

const ITEM_ORDER := ["yan", "jing", "cha", "fu"]

## 成就：id / 名称 / 说明 / 文貝奖赏
const ACHIEVEMENTS := [
	{"id": "boot", "name": "初開卷", "desc": "完成第一首詩", "coin": 20},
	{"id": "p1", "name": "一氣呵成", "desc": "零失誤完成一首詩", "coin": 20},
	{"id": "p10", "name": "筆下生風", "desc": "零失誤完成十首", "coin": 80},
	{"id": "n10", "name": "十篇成誦", "desc": "累計完成十首", "coin": 30},
	{"id": "n30", "name": "三十而立", "desc": "累計完成三十首", "coin": 60},
	{"id": "n100", "name": "百首通儒", "desc": "累計完成一百首", "coin": 200},
	{"id": "n300", "name": "三百篇後", "desc": "累計完成三百首", "coin": 500},
	{"id": "r0", "name": "拾得逸品", "desc": "收藏第一張逸品卡牌", "coin": 50},
	{"id": "r0x5", "name": "五色雲箋", "desc": "收藏五張逸品", "coin": 150},
	{"id": "all4", "name": "四品俱備", "desc": "逸神妙能四品皆有收藏", "coin": 60},
	{"id": "repe", "name": "溫故知新", "desc": "重溫同一首詩五次", "coin": 40},
	{"id": "nohelp", "name": "不假外物", "desc": "不借道具完成一首逸品", "coin": 120},
	{"id": "rev1", "name": "學而時習", "desc": "完成第一次溫習", "coin": 30},
	{"id": "rev30", "name": "溫故不腐", "desc": "累計溫習三十篇次", "coin": 100},
	{"id": "rev200", "name": "書讀百遍", "desc": "累計溫習二百篇次", "coin": 400},
	{"id": "recall50", "name": "過目成誦", "desc": "自評「記得清楚」五十次", "coin": 300},
	{"id": "streak7", "name": "勤學不輟", "desc": "連續七日溫習", "coin": 150},
	{"id": "mem5", "name": "記憶如新", "desc": "五張卡牌的記憶階達五", "coin": 200},
]

static func item_name(id: String) -> String:
	return String(ITEMS.get(id, {}).get("name", id))


static func ach_by_id(id: String) -> Dictionary:
	for a in ACHIEVEMENTS:
		if a["id"] == id:
			return a
	return {}


# ---------------------------------------------------------------- 中文数字
const CN_DIGITS := "〇一二三四五六七八九"

static func cn_digits(s: String) -> String:
	var out := ""
	for c in s:
		var k := "0123456789".find(c)
		out += CN_DIGITS[k] if k >= 0 else c
	return out


static func cn_num(n: int) -> String:
	if n < 0:
		return str(n)
	if n < 10:
		return CN_DIGITS[n]
	if n == 10:
		return "十"
	if n < 20:
		return "十" + CN_DIGITS[n % 10]
	if n < 100:
		var t := "%s十" % CN_DIGITS[n / 10]
		if n % 10 != 0:
			t += CN_DIGITS[n % 10]
		return t
	return str(n)


## 下次温习的相对日期文案（用于卡牌落款区）
static func due_cn(due_ts: int, now_ts: int = 0) -> String:
	if due_ts <= 0:
		return ""
	var now := now_ts if now_ts > 0 else int(Time.get_unix_time_from_system())
	var left := due_ts - now
	if left <= 0:
		return "待 溫 習"
	var d := int(ceil(left / 86400.0))
	return "明日再溫" if d <= 1 else "%d 日後" % d


## 落款日期：二〇二六年十月五日
static func date_cn(ts: int) -> String:
	if ts <= 0:
		return ""
	var d := Time.get_datetime_dict_from_unix_time(ts)
	return "%s年%s月%s日" % [
		cn_digits(str(d.get("year", 2026))),
		cn_num(int(d.get("month", 1))),
		cn_num(int(d.get("day", 1))),
	]


## 时长：三分十二秒
static func duration_cn(sec: int) -> String:
	if sec < 60:
		return "%d 秒" % sec
	var m := sec / 60
	var s := sec % 60
	if s == 0:
		return "%d 分" % m
	return "%d 分 %d 秒" % [m, s]

## 全局配色 · 敦煌壁画
## 取自莫高窟壁画的矿物颜料谱系：土红、石青、石绿、雌黄、蛤粉，地仗为土墙沙色。
class_name Palette

# —— 线描 · 地仗 · 蛤粉 ——
const INK := Color("3b2a1e")          # 深褐线描（壁画勾勒）
const INK_SOFT := Color("6d5642")     # 淡褐
const INK_FAINT := Color("9c8469")    # 灰褐（辅助字）
const PAPER := Color("e8d7b0")        # 壁画地仗（土墙沙色）
const PAPER_LIGHT := Color("f7edd6")  # 蛤粉（卡片、面板）
const PAPER_DEEP := Color("d9c193")   # 深土色
const PAPER_EDGE := Color("bfa172")   # 边线

# —— 矿物颜料 ——
const CINNABAR := Color("a8382a")     # 土红
const CINNABAR_SOFT := Color("c25a44")
const JADE := Color("33795f")         # 石绿
const JADE_SOFT := Color("4f9e7a")
const GOLD := Color("bd8a1a")         # 雌黄（金）
const GOLD_SOFT := Color("d8b154")
const AZURE := Color("2e5c8a")        # 石青
const AZURE_SOFT := Color("5b86ac")

# —— 品级：逸品 · 神品 · 妙品 · 能品 ——
const RARITY := [Color("bd8a1a"), Color("2e5c8a"), Color("33795f"), Color("8a7256")]
const RARITY_SOFT := [Color("f3e4c0"), Color("dbe5ef"), Color("d9e8dd"), Color("e9dfcd")]
const RARITY_NAME := ["逸品", "神品", "妙品", "能品"]
const RARITY_STARS := [5, 4, 3, 2]

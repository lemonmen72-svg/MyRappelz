#!/usr/bin/env python3
# Промты ChatGPT на значки трофеев монстров подземелья (этап 2, 0.36): 12 предметов ItemData (goblin_token …
# sect_sigil; лист 2 — 3 трофея босса-капитана, 0.38). Пишет tools/Промты_значки_добычи_подземелья.docx. Запуск из корня: python3 -I tools/make_dungeon_loot_icons_doc.py
# (нужен python-docx). Лист — 4 × 3 плитки на белом фоне; нарезка:
#   python3 -I tools/cut_icon_sheet.py <лист.png> assets/icons/items <id через запятую> [--cols 4]
import os

from docx import Document
from docx.shared import Pt

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCX = os.path.join(ROOT, "tools", "Промты_значки_добычи_подземелья.docx")

STYLE = ("Game inventory item icons, anime cel-shading in the spirit of Genshin Impact, fully original design (no logos, "
	"no text, no existing game assets). Each icon: one object, centered, slightly angled 3/4 view, clean dark outline, "
	"soft cel shading with 2–3 tones, a subtle rim light, rich saturated colors, readable at 64 px. Each icon on its own "
	"rounded-square tile with a dark blue-grey gradient background and a thin frame (grey for common items, blue for "
	"rare, golden for unique). Tiles are separated by clear WHITE gaps of at least 40 px on a pure white sheet.")
THEME = ("Theme: a cursed underground cave of the Sect of Darkness — emerald-green ghostly glow, damp stone, rust, sea "
	"salt, old bones, corals; the sect symbol is an EYE WITH TENTACLES and green SPIRALS.")

# id, название, редкость (рамка), что нарисовать (англ.), кто роняет
ITEMS = [
	("goblin_token", "Племенной знак", "обычная", "a small bone amulet on a leather cord, carved with a glowing green "
		"spiral, crude goblin cuts and notches", "гоблины"),
	("rusty_buckle", "Ржавая пряжка", "обычная", "a heavy rusty iron belt buckle, orange rust flakes, a scrap of torn "
		"leather strap still attached", "гоблины"),
	("warlord_tusk", "Клык вождя", "редкая", "a huge curved yellowed tusk set in a dented copper band with rivets, "
		"tribal green paint stripes", "Вождь гоблинов"),
	("brine_rag", "Просоленный лоскут", "обычная", "a torn piece of an old grey-green ship sail, stiff with white salt "
		"crust, a frayed rope end", "мёртвые матросы, корсары"),
	("sea_bone", "Морская кость", "обычная", "a pale old bone overgrown with tiny barnacles and a strand of seaweed",
		"мёртвые матросы, корсары, утопленники"),
	("coral_shard", "Осколок коралла", "обычная", "a jagged branch of emerald-teal coral glowing softly from inside, "
		"with a bit of corroded armour plate fused to its base", "корсары, утопленники"),
	("dead_plate", "Пластина мёртвого доспеха", "обычная", "a blackened, scratched armour plate with a faint green eye "
		"sigil etched on it, cracked edge", "мёртвые стражи и мечники, Мёртвый рыцарь"),
	("grave_chain", "Звено погребальной цепи", "обычная", "three heavy dark iron chain links, the last one broken, "
		"green moss in the joints", "мёртвые стражи и мечники"),
	("black_seal", "Чёрная печать", "редкая", "a round black metal seal medallion with a glowing emerald eye and four "
		"tentacles engraved, cracked wax around the rim", "Мёртвый рыцарь"),
	("sect_candle", "Зелёная свеча", "обычная", "a short melted ritual candle stub of pale green wax, the wax itself "
		"glowing emerald, dark drips", "жрецы и призраки секты"),
	("ritual_ash", "Ритуальный пепел", "обычная", "a small cloth pouch spilling grey ash with faint green embers inside",
		"жрецы и призраки секты, Старший жрец"),
	("sect_sigil", "Знак Секты Мрака", "уникальная", "a cast dark-silver emblem of an eye with tentacles, an emerald gem "
		"as the pupil, bright green glow and golden trim", "Старший жрец"),
]

# Лист 2 (0.38): трофеи босса подземелья — Проклятого капитана, сетка 3 × 1
BOSS_ITEMS = [
	("captain_doubloon", "Проклятый дублон", "редкая", "a heavy old gold doubloon coin, an emerald-green eye stamped "
		"instead of a royal crest, sea-green patina in the grooves, a faint green glow", "Проклятый капитан"),
	("oath_crystal", "Погасший кристалл клятвы", "уникальная", "a large faceted emerald crystal in a broken dark-silver "
		"setting with torn chain links, mostly dull and dark, a weak green light deep inside", "Проклятый капитан"),
	("captain_logbook", "Судовой журнал капитана", "уникальная", "a swollen water-damaged leather ship logbook with brass "
		"corners, a green eye-and-tentacles mark burned into the cover, seaweed on the strap", "Проклятый капитан"),
]

# Лист 3 (0.40): значки эффектов — благословения Сестры Аделины (баффы) и ослабления Проклятого капитана (дебаффы).
# Рисуются в кружке у полосок HP (StatusRow), рамку цвета (зелёная — баф, красная — дебаф) игра рисует сама.
FX_STYLE = ("Game status-effect icons (buff and debuff icons), anime cel-shading in the spirit of Genshin Impact, fully "
	"original design (no logos, no text, no letters, no existing game assets). Each icon: one bold simple symbol, "
	"centered, clean dark outline, 2–3 tone cel shading, glowing accents, readable at 32 px. Each icon on its own "
	"square tile with a dark navy radial-gradient background and NO frame (the game draws the frame). Tiles are "
	"separated by clear WHITE gaps of at least 40 px on a pure white sheet.")
FX_ITEMS = [
	("bless_might", "Благословение силы", "баф", "a golden sword pointing up inside a radiant warm-orange sunburst, holy light rays", "физ. атака +19.5 %"),
	("bless_arcana", "Благословение чар", "баф", "a violet magic orb with a small star inside, surrounded by orbiting arcane sparks", "маг. атака +19.5 %"),
	("bless_bulwark", "Благословение стойкости", "баф", "a sturdy bronze kite shield with a glowing golden sun emblem", "защита +19.5 %"),
	("bless_ward", "Благословение оберега", "баф", "a translucent sky-blue magic barrier dome with a white rune circle", "маг. защита +19.5 %"),
	("bless_fury", "Благословение ярости", "баф", "two crossed short blades with orange speed streaks and flame-like trails", "скорость атаки +18 %"),
	("bless_word", "Благословение слова", "баф", "an open glowing book with cyan light rising from the pages like a spell", "скорость каста +19.5 %"),
	("bless_wind", "Благословение ветра", "баф", "a light green winged boot with swirling wind lines", "бег +19.5 %"),
	("debuff_stun", "Оглушение", "дебаф", "a dazed head silhouette with yellow stars and spirals circling above it", "Проклятый капитан: оглушение 2 с"),
	("debuff_aslow", "Слабая рука", "дебаф", "a cracked sword wrapped in a heavy dark-green chain, sluggish purple haze", "скорость атаки −15 %"),
	("debuff_slow", "Тяжёлые ноги", "дебаф", "a boot stuck in thick green sea sludge with dripping slime", "бег −15 %"),
	("debuff_armor", "Разбитая броня", "дебаф", "a dented breastplate with a jagged crack and green corrosion spreading", "защита −10 %"),
	("debuff_poison", "Яд бездны", "дебаф", "a toxic emerald droplet with a small skull reflection, bubbling green fumes", "яд: 100 HP в секунду 5 с"),
]


def sheet(doc, items, cols, rows, size, style=None):
	lines = [style or STYLE, THEME, "Draw a sheet of %d icons in a %d x %d grid, in this exact order (left to right, top to bottom):"
		% (len(items), cols, rows)]
	for n, it in enumerate(items, 1):
		frame = {"обычная": "grey frame", "редкая": "blue frame", "уникальная": "golden frame", "баф": "", "дебаф": ""}[it[2]]
		lines.append("%d. %s%s." % (n, it[3], " (%s)" % frame if frame else ""))
	lines.append("Sheet %s px or larger. No captions, no numbers on the sheet." % size)
	doc.add_paragraph("\n".join(lines))


def table(doc, items):
	t = doc.add_table(rows=1, cols=5)
	t.style = "Table Grid"
	for c, h in enumerate(["№", "id (имя файла)", "Что", "Рамка или вид", "Откуда, что даёт"]):
		t.rows[0].cells[c].text = h
	for n, it in enumerate(items, 1):
		r = t.add_row().cells
		r[0].text = str(n)
		r[1].text = it[0]
		r[2].text = it[1]
		r[3].text = it[2]
		r[4].text = it[4]


def main():
	doc = Document()
	st = doc.styles["Normal"]
	st.font.name = "Calibri"
	st.font.size = Pt(10.5)
	doc.add_heading("Dark Pact — значки подземелья: трофеи и эффекты (0.36–0.40)", 0)
	doc.add_paragraph("Лист 1 ChatGPT: 12 значков сеткой 4 × 3, по порядку таблицы (слева направо, сверху вниз). "
		"В игре они пока процедурные (ItemIcon по полю icon), с картинкой станут настоящими. Готовый лист — пришли мне, "
		"нарежу командой:")
	doc.add_paragraph("python3 -I tools/cut_icon_sheet.py <лист.png> assets/icons/items " + ",".join(i[0] for i in ITEMS)
		+ " --cols 4")
	doc.add_heading("Лист 1 — монстры подземелья (вставить в ChatGPT целиком)", 1)
	sheet(doc, ITEMS, 4, 3, "1536 x 1152")
	doc.add_heading("Что на каждой плитке листа 1", 1)
	table(doc, ITEMS)
	doc.add_heading("Лист 2 — трофеи Проклятого капитана (0.38)", 1)
	doc.add_paragraph("Отдельный лист, 3 значка в ряд. Нарезка:")
	doc.add_paragraph("python3 -I tools/cut_icon_sheet.py <лист.png> assets/icons/items " + ",".join(i[0] for i in BOSS_ITEMS)
		+ " --cols 3")
	sheet(doc, BOSS_ITEMS, 3, 1, "1536 x 512")
	doc.add_heading("Что на каждой плитке листа 2", 1)
	table(doc, BOSS_ITEMS)
	doc.add_heading("Лист 3 — значки эффектов: благословения жрицы и ослабления капитана (0.40)", 1)
	doc.add_paragraph("Отдельный лист 4 × 3. Значки встают в кружки эффектов у полосок здоровья (рамку игра рисует сама). "
		"Нарезка:")
	doc.add_paragraph("python3 -I tools/cut_icon_sheet.py <лист.png> assets/icons/effects " + ",".join(i[0] for i in FX_ITEMS)
		+ " --cols 4")
	sheet(doc, FX_ITEMS, 4, 3, "1536 x 1152", FX_STYLE)
	doc.add_heading("Что на каждой плитке листа 3", 1)
	table(doc, FX_ITEMS)
	doc.save(DOCX)
	print("записан", DOCX)


if __name__ == "__main__":
	main()

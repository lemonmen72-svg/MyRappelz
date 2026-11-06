#!/usr/bin/env python3
# Промты ChatGPT на значки трофеев монстров подземелья (этап 2, 0.36): 12 предметов ItemData (goblin_token …
# sect_sigil). Пишет tools/Промты_значки_добычи_подземелья.docx. Запуск из корня: python3 -I tools/make_dungeon_loot_icons_doc.py
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


def main():
	doc = Document()
	st = doc.styles["Normal"]
	st.font.name = "Calibri"
	st.font.size = Pt(10.5)
	doc.add_heading("Dark Pact — значки трофеев монстров подземелья (0.36)", 0)
	doc.add_paragraph("Один лист ChatGPT: 12 значков сеткой 4 × 3, по порядку таблицы (слева направо, сверху вниз). "
		"В игре они пока процедурные (ItemIcon по полю icon), с картинкой станут настоящими. Готовый лист — пришли мне, "
		"нарежу командой:")
	doc.add_paragraph("python3 -I tools/cut_icon_sheet.py <лист.png> assets/icons/items " + ",".join(i[0] for i in ITEMS)
		+ " --cols 4")
	doc.add_heading("Промт листа (вставить в ChatGPT целиком)", 1)
	lines = [STYLE, THEME, "Draw a sheet of 12 icons in a 4 x 3 grid, in this exact order (left to right, top to bottom):"]
	for n, it in enumerate(ITEMS, 1):
		frame = {"обычная": "grey frame", "редкая": "blue frame", "уникальная": "golden frame"}[it[2]]
		lines.append("%d. %s (%s)." % (n, it[3], frame))
	lines.append("Square sheet, 1536 x 1152 px or larger. No captions, no numbers on the sheet.")
	doc.add_paragraph("\n".join(lines))
	doc.add_heading("Что на каждой плитке", 1)
	t = doc.add_table(rows=1, cols=5)
	t.style = "Table Grid"
	for c, h in enumerate(["№", "id (имя файла)", "Предмет", "Рамка", "Кто роняет"]):
		t.rows[0].cells[c].text = h
	for n, it in enumerate(ITEMS, 1):
		r = t.add_row().cells
		r[0].text = str(n)
		r[1].text = it[0]
		r[2].text = it[1]
		r[3].text = it[2]
		r[4].text = it[4]
	doc.save(DOCX)
	print("записан", DOCX)


if __name__ == "__main__":
	main()

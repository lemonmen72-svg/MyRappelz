#!/usr/bin/env python3
# Промты ChatGPT (0.41): значки вкладок сумки, значки кнопок окон, оформление кнопок (рамки), быстрые слоты зелий
# и страницы умений, значки оружия 2-го ранга. Пишет tools/Промты_значки_сумка_кнопки_оружие2.docx.
# Запуск из корня: python3 -I tools/make_ui_icons_doc.py (нужен python-docx). Нарезка листа:
#   python3 -I tools/cut_icon_sheet.py <лист.png> <папка> <id через запятую> --cols N
import os

from docx import Document
from docx.shared import Pt

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCX = os.path.join(ROOT, "tools", "Промты_значки_сумка_кнопки_оружие2.docx")

UI_STYLE = ("Game UI icons for a mobile fantasy MMORPG, anime cel-shading in the spirit of Genshin Impact, fully original "
	"design (no logos, no text, no letters, no numbers, no existing game assets). Each icon: ONE bold, simple, instantly "
	"readable symbol, centered, clean dark outline, 2–3 tone cel shading, warm gold and ivory main colors with one accent "
	"color per icon, a soft inner glow, readable at 40 px on a phone. Each icon on its own rounded-square tile with a "
	"dark navy-to-indigo gradient background and a thin golden frame. Tiles are separated by clear WHITE gaps of at "
	"least 40 px on a pure white sheet.")
ITEM_STYLE = ("Game inventory item icons, anime cel-shading in the spirit of Genshin Impact, fully original design (no "
	"logos, no text, no numerals, no existing game assets). Each icon: one weapon, centered, rotated diagonally 45° "
	"(grip bottom-left, tip top-right; shield and bow — front view), whole weapon visible, clean dark outline, soft cel "
	"shading with 2–3 tones, a subtle rim light, rich saturated colors, readable at 64 px. RANK 2 look: bright polished "
	"steel, silver and gold fittings, ONE glowing gem. Each icon on its own rounded-square tile with a dark blue-grey "
	"gradient background and a thin BLUE frame. Tiles are separated by clear WHITE gaps of at least 40 px on a pure "
	"white sheet.")
SKIN_STYLE = ("Game UI button skins for a mobile fantasy MMORPG, anime cel-shading in the spirit of Genshin Impact, fully "
	"original (no text, no icons, no letters on the buttons). Each skin: an EMPTY wide rounded-rectangle button seen "
	"straight from the front, aspect ratio 3:1, flat front view, no perspective, no shadow outside the button. Style: "
	"dark navy lacquered panel with an ornate thin golden border, small decorative golden corner flourishes, a soft "
	"top highlight; the middle must stay PLAIN and EVEN (it will be stretched — 9-slice), all decoration only in the "
	"corners and along the edges. Each skin on pure WHITE background, separated by clear white gaps of at least 60 px.")

# id, что, где в игре, что нарисовать (англ.)
BAG_TABS = [
	("bagtab_all", "Все предметы", "вкладка сумки", "an open leather adventurer's bag with several items peeking out"),
	("bagtab_gear", "Оружие и броня", "вкладка сумки", "a crossed sword and kite shield"),
	("bagtab_loot", "Добыча монстров", "вкладка сумки", "a beast claw and a fang lying on a small pile of hide"),
	("bagtab_cards", "Карты питомцев", "вкладка сумки", "a fan of two fantasy creature cards with a paw-print emblem"),
	("bagtab_jewelry", "Украшения", "вкладка сумки", "a golden ring with a blue gem next to a pendant"),
	("bagtab_quest", "Предметы заданий", "вкладка сумки", "a rolled parchment scroll with a red wax seal and a golden "
		"exclamation-shaped ribbon"),
	("bagtab_potions", "Зелья и усиления", "вкладка сумки", "a round red potion flask and a small blue flask side by side"),
	("bagtab_other", "Остальное", "вкладка сумки", "a small wooden crate with a cube, a gear and a feather on top"),
]

ACTIONS_1 = [
	("act_equip", "Надеть", "карточка предмета", "a golden arrow pointing down into a breastplate silhouette"),
	("act_unequip", "Снять", "надетое", "a golden arrow pointing up out of a breastplate silhouette"),
	("act_offhand", "Во 2-ю руку", "оружие, щит", "a left hand gauntlet holding a small shield"),
	("act_use", "Использовать / выпить", "зелья, свитки", "a hand holding a glowing flask with sparkles rising"),
	("act_sell", "Продать", "торговец", "a gold coin dropping into an open palm"),
	("act_sell_all", "Продать все", "торговец", "a stack of gold coins pouring into an open palm"),
	("act_buy", "Купить", "торговец", "a small shopping pouch with a gold coin and a plus-shaped sparkle"),
	("act_buy_many", "Купить ×5", "торговец", "three shopping pouches stacked with gold coins"),
	("act_move", "Переместить", "сумка", "four golden arrows pointing in four directions around a small square"),
	("act_drop", "Выбросить", "сумка", "an item falling out of an open hand with a short motion line"),
	("act_drop_all", "Выбросить все", "сумка", "several items falling out of a tilted open bag"),
	("act_sort", "Сортировать", "сумка, склад", "three horizontal bars of decreasing length with a small golden arrow"),
	("act_form", "Сформировать питомца", "карта с душой", "a creature card releasing a glowing soul wisp shaped like a "
		"small beast"),
	("act_read", "Прочитать", "документы заданий", "an open old book with a glowing page and a magnifying glass"),
	("act_craft_put", "В крафт", "панель крафта", "an item flying into a glowing magic cube"),
	("act_recipes", "Рецепты", "панель крафта", "an open recipe book with a cube and a gem drawn on its pages"),
]

ACTIONS_2 = [
	("act_store", "На склад", "склад", "a wooden storage chest with a golden arrow pointing down into it"),
	("act_store_all", "На склад все", "склад", "a wooden chest with three golden arrows pointing down into it"),
	("act_take", "В сумку", "склад", "a golden arrow pointing out of a chest into a leather bag"),
	("act_take_all", "В сумку все", "склад", "three golden arrows from a chest into a bag"),
	("act_gold_in", "Положить золото", "склад", "gold coins sliding into a chest slot"),
	("act_gold_out", "Забрать золото", "склад", "gold coins jumping out of a chest"),
	("act_forge_put", "На наковальню", "кузница", "a sword lying on an anvil with a small hammer above"),
	("act_confirm", "Да / подтвердить", "все окна", "a bold golden check mark with a green glow"),
	("act_cancel", "Отмена", "все окна", "a bold curved arrow turning back to the left, soft red glow"),
	("act_plus", "Больше", "количество", "a bold golden plus sign in a small circle"),
	("act_minus", "Меньше", "количество", "a bold golden minus sign in a small circle"),
	("act_belt_put", "В пояс", "пояс питомцев", "a creature card sliding into a leather belt pocket"),
	("act_belt_take", "Из пояса", "пояс питомцев", "a creature card pulled out of a leather belt pocket"),
	("act_belt_expand", "Расширить пояс", "пояс питомцев", "a leather belt with a new glowing pocket and a plus sparkle"),
	("act_details", "Подробнее", "карточки", "a golden magnifying glass over a small page"),
	("act_ring2", "Во 2-е кольцо", "украшения", "two golden rings side by side, the second one glowing"),
]

ACTIONS_3 = [
	("act_learn", "Изучить умение", "окно героя и существа", "a glowing skill rune with an upward golden arrow"),
	("act_assign", "На кнопку", "умения", "a skill rune moving into a round button slot"),
	("act_slot_clear", "Убрать из ячейки", "ячейки умений", "an empty round slot with a small cross"),
	("act_toggle", "Вкл / выкл", "переключаемые умения", "a round power switch with a golden glow"),
	("act_summon", "Призвать", "питомцы", "a magic summoning circle with a beast silhouette rising from it"),
	("act_recall", "Отозвать", "питомцы", "a beast silhouette dissolving into sparkles into a card"),
	("act_release", "Отпустить", "питомцы", "an open hand with a small bird-like soul flying away"),
	("act_revive", "Воскресить", "питомцы", "a white feather with a golden halo and a soft rising light"),
	("act_evolve", "Эволюция", "Учитель Кирк", "three ascending creature silhouettes, small to large, with an upward arrow"),
	("act_pet_gear", "Надеть питомцу", "снаряжение питомца", "a paw print under a small sword and shield"),
	("act_quest_take", "Взять задание", "диалог", "a parchment with a golden exclamation-shaped seal"),
	("act_quest_turnin", "Сдать задание", "диалог", "a parchment with a big golden check mark seal"),
	("act_track", "Отслеживать", "журнал заданий", "a golden map pin on a small map"),
	("act_abandon", "Отказаться", "журнал заданий", "a torn parchment with a red cross"),
	("act_trade", "Торговля", "диалог", "a merchant's balance scale with gold coins"),
	("act_bye", "До встречи", "диалог", "a waving hand with a small speech bubble"),
]

QUICK = [
	("quick_slot_empty", "Пустой быстрый слот", "3 кнопки зелий", "an empty round potion slot: a faint dotted flask outline"),
	("quick_edit", "Настроить быстрые слоты", "3 кнопки зелий", "a potion flask with a small golden gear"),
	("skill_swipe", "Листать умения", "кнопки умений", "two curved golden arrows left and right around three small round "
		"skill dots"),
	("skill_slot_empty", "Пустая ячейка умения", "кнопки умений", "an empty round skill slot with a faint rune outline"),
	("auto_attack", "Автоатака", "кнопка «Атака»", "a sword inside a circular arrow loop, orange glow"),
	("act_bless", "Благословения", "жрица Аделина", "a glowing golden sun emblem over praying hands"),
]

SKINS = [
	("btn_skin_normal", "Кнопка обычная", "все окна", "the default button: dark navy panel, golden border"),
	("btn_skin_pressed", "Кнопка нажата", "все окна", "the same button pressed: slightly darker, inner shadow at the top, "
		"golden border a bit brighter"),
	("btn_skin_primary", "Главная кнопка", "«Надеть», «Купить», «Крафт»", "a warm GOLD-orange panel with a darker golden "
		"border — the main action button"),
	("btn_skin_danger", "Опасная кнопка", "«Выбросить», «Отказаться»", "a deep CRIMSON panel with a golden border"),
	("btn_skin_disabled", "Кнопка недоступна", "все окна", "a desaturated grey-blue panel with a dull grey border"),
	("tab_skin_off", "Вкладка", "вкладки окон и сумки", "a SQUARE (1:1) small tab: dark navy, thin dull-gold border"),
	("tab_skin_on", "Вкладка выбрана", "вкладки окон и сумки", "the same square tab selected: brighter, glowing golden "
		"border and a soft golden underline glow"),
	("slot_skin", "Ячейка сумки", "сумка, склад, лавки", "a SQUARE (1:1) inventory slot: recessed dark panel with a thin "
		"bronze border, empty inside"),
]

WEAPONS_R2 = [
	("weapon_sword_1h_r2", "Одноручный меч II", "оружие 2-го ранга", "Azure Oathblade — a one-handed straight sword, "
		"polished steel blade with an azure-blue fuller line, silver cross guard with small wings, a blue gem in the guard"),
	("weapon_sword_2h_r2", "Двуручный меч II", "оружие 2-го ранга", "a big two-handed greatsword, broad bright blade, "
		"heavy golden cross guard with a large RED RUBY in the center, long wrapped grip"),
	("weapon_dagger_r2", "Кинжал II", "оружие 2-го ранга", "Emerald Dawnblade — a slim elegant dagger, curved silver "
		"blade, golden guard, an EMERALD green gem in the pommel"),
	("weapon_mace_1h_r2", "Одноручная булава II", "оружие 2-го ранга", "Embercrest Scepter — a one-handed flanged mace, "
		"golden flanged head with an orange-red ember gem in the middle, silver shaft"),
	("weapon_mace_2h_r2", "Двуручная булава II", "оружие 2-го ранга", "Sunforged War Scepter — a long two-handed war "
		"maul with a big golden sun-shaped head, a glowing amber gem, long silver haft"),
	("weapon_axe_1h_r2", "Одноручный топор II", "оружие 2-го ранга", "Ruby Sovereign Axe — a one-handed axe, crescent "
		"silver blade with golden trim, a RUBY set at the blade base"),
	("weapon_axe_2h_r2", "Двуручный топор II", "оружие 2-го ранга", "Crimson Crescent Halberd — a two-handed great axe / "
		"halberd with a wide crimson-red crescent blade edged in gold, long dark haft"),
	("weapon_staff_1h_r2", "Одноручный посох II", "оружие 2-го ранга", "Amethyst Sovereign Staff — a short royal staff, "
		"silver shaft, a golden crown-like top holding a glowing purple AMETHYST"),
	("weapon_staff_2h_r2", "Двуручный посох II", "оружие 2-го ранга", "Celestial Sapphire Scepter — a long two-handed "
		"magic staff, white-gold shaft, a large glowing blue SAPPHIRE held by curved golden crescents at the top"),
	("weapon_spear_r2", "Копьё II", "оружие 2-го ранга", "Azureleaf Lance — a long spear with a leaf-shaped azure-steel "
		"spearhead, golden collar, a small blue gem, dark wrapped shaft"),
	("weapon_bow_r2", "Лук II", "оружие 2-го ранга", "Emeraldleaf Bow — an elegant recurve longbow, white-gold limbs "
		"shaped like leaves, an EMERALD in the grip, glowing green string"),
	("weapon_crossbow_r2", "Арбалет II", "оружие 2-го ранга", "Gilded Arbalest — a heavy ornate crossbow, gilded bow "
		"arms, dark wood stock with golden inlays, a blue gem on the stock"),
	("weapon_shield_r2", "Щит II", "оружие 2-го ранга", "Sapphire Sunshield — a round-topped kite shield, polished "
		"silver face with a golden sun emblem and a large blue SAPPHIRE in the center"),
]

SHEETS = [
	("Лист 1 — вкладки сумки", "assets/icons/ui", BAG_TABS, 4, 2, "1536 x 768", UI_STYLE,
		"8 вкладок сумки (слева направо по порядку): Все, Оружие и броня, Добыча монстров, Карты питомцев, Украшения, "
		"Предметы заданий, Зелья и усиления, Остальное. Вкладки компактные — только значок, подпись по долгому касанию."),
	("Лист 2 — кнопки: предметы и торговля", "assets/icons/ui", ACTIONS_1, 4, 4, "1536 x 1536", UI_STYLE,
		"Значки встанут слева от подписи на кнопках карточки предмета в сумке и лавках."),
	("Лист 3 — кнопки: склад, кузница, подтверждения, пояс", "assets/icons/ui", ACTIONS_2, 4, 4, "1536 x 1536", UI_STYLE,
		"Склад, наковальня, «Да / Отмена», ± количества, пояс с картами питомцев."),
	("Лист 4 — кнопки: умения, питомцы, задания, диалоги", "assets/icons/ui", ACTIONS_3, 4, 4, "1536 x 1536", UI_STYLE,
		"Окно героя и существа, окно «Питомцы», журнал заданий, пункты диалога с жителями."),
	("Лист 5 — быстрые слоты зелий и страницы умений", "assets/icons/ui", QUICK, 3, 2, "1152 x 768", UI_STYLE,
		"3 новые кнопки под зелья и усилители (ставятся без захода в сумку) и листание 12 умений свайпом."),
	("Лист 6 — оформление кнопок (рамки)", "assets/icons/ui_skin", SKINS, 2, 4, "1536 x 2048", SKIN_STYLE,
		"Не значки, а сами кнопки: фон, рамка, уголки. Середина ровная — игра растягивает её под любую длину кнопки "
		"(9-slice), уголки не растягиваются. Вкладки и ячейка — квадратные."),
	("Лист 7 — оружие 2-го ранга", "assets/icons/items", WEAPONS_R2, 4, 4, "1536 x 1536", ITEM_STYLE,
		"Значков оружия 2-го ранга в игре нет — сейчас показан значок 1-го ранга. Описания — по моделям оружия 2-го "
		"ранга, которые уже в игре (Azure Oathblade и др.). 13 значков, последние 3 плитки листа пустые."),
]


def sheet_prompt(items, cols, rows, size, style):
	lines = [style, "Draw a sheet of %d images in a %d x %d grid, in this exact order (left to right, top to bottom):"
		% (len(items), cols, rows)]
	for n, it in enumerate(items, 1):
		lines.append("%d. %s." % (n, it[3]))
	if len(items) < cols * rows:
		lines.append("Leave the remaining %d tiles of the grid empty (pure white)." % (cols * rows - len(items)))
	lines.append("Sheet %s px or larger. No captions, no numbers on the sheet." % size)
	return "\n".join(lines)


def table(doc, items):
	t = doc.add_table(rows=1, cols=4)
	t.style = "Table Grid"
	for c, h in enumerate(["№", "id (имя файла)", "Что", "Где в игре"]):
		t.rows[0].cells[c].text = h
	for n, it in enumerate(items, 1):
		r = t.add_row().cells
		r[0].text = str(n)
		r[1].text = it[0]
		r[2].text = it[1]
		r[3].text = it[2]


def main():
	doc = Document()
	st = doc.styles["Normal"]
	st.font.name = "Calibri"
	st.font.size = Pt(10.5)
	doc.add_heading("Dark Pact — значки: сумка, кнопки окон, быстрые слоты, оружие 2-го ранга (0.41)", 0)
	doc.add_paragraph("7 листов для ChatGPT. Каждый лист — отдельный запрос: скопируйте весь текст из блока «Промт» "
		"и вставьте. Плитки — по порядку таблицы (слева направо, сверху вниз). Пока картинок нет, в игре стоят "
		"процедурные значки — ничего не ломается. Готовые листы пришлите мне — нарежу и подключу сам (команда нарезки "
		"под каждым листом).")
	total = 0
	for title, folder, items, cols, rows, size, style, note in SHEETS:
		total += len(items)
		doc.add_heading(title, 1)
		doc.add_paragraph(note)
		doc.add_heading("Промт", 2)
		doc.add_paragraph(sheet_prompt(items, cols, rows, size, style))
		doc.add_heading("Что на каждой плитке", 2)
		table(doc, items)
		doc.add_paragraph("Нарезка: python3 -I tools/cut_icon_sheet.py <лист.png> %s %s --cols %d"
			% (folder, ",".join(i[0] for i in items), cols))
	doc.add_paragraph("Всего значков и рамок: %d." % total)
	doc.save(DOCX)
	print("записан", DOCX, "значков", total)


if __name__ == "__main__":
	main()

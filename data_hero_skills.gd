class_name HeroSkills
extends RefCounted
## Умения героя и их древо. У Бродяги (id класса "assassin") — полное древо по образцу профессии Strider
## из Rappelz (механика и числа — из вики, названия, описания и значки свои; справка —
## tools/rappelz_strider_reference.md). У остальных классов в древе их два умения из ClassData (один ярус,
## изучены сразу, без JP). Умение изучается и повышается за очки умений героя (JP) в окне героя
## (CharacterWindow, вкладки древа). Применение — Player (кнопки умений skill1…skill4, назначение в древе).
##
## Поля умения:
##   kind — "active" (кнопка), "passive" (действует всегда), "toggle" (включается в древе или кнопкой,
##     тратит MP при включении и раз в 10 с);
##   tab — вкладка древа: "common" (общие), "blades" (мечи и кинжалы), "crossbow" (арбалет);
##   weapon — какое оружие нужно: "" — любое, "blades" — кинжалы или мечи, "crossbow" — арбалет
##     (активное без него не применить, бонусы пассивных и переключаемых действуют только с ним);
##   jlv — уровень профессии в вики для каждого уровня умения (наш уровень героя = × 0.3, не меньше 1),
##     req — наш уровень героя напрямую (свои умения без вики);
##   jp — стоимость каждого уровня в JP; start — 1-й уровень дан сразу (стартовое умение класса);
##   pre — [умение, уровень]: что нужно изучить раньше (линия в древе);
##   числа по уровням умения — массивы (n-й элемент — уровень n).
## Активные: mp, cd (с; число или массив), target ("melee" — клинками рядом, "ranged" — болтом из арбалета,
##   "self" — на себя, "dash" — рывок к цели, "near" — цель рядом в radius м), mult — доля атаки за удар,
##   flat — прибавка к урону за удар (база вики × FLAT_SCALE), hits — ударов, crit — всегда крит, heal — лечение
##   долей урона, sleep — сон (с, будит удар), fear — страх (с: зверь убегает, не бьёт), knock — отбросить на м,
##   root — удержать на месте (с), dot / dot_flat — урон в секунду (доля атаки / прибавка) на dot_time с,
##   no_regen — пока идёт урон, зверь не лечится, buff — {бонус: массив} на buff_time с, dash — дальность рывка.
## Пассивные и переключаемые: bonus — {вид бонуса: массив по уровням} (виды — BONUS_NAMES), у переключаемых
##   ещё mp (включение) и upkeep (MP за UPKEEP_PERIOD с).

## Очки умений героя: у нового героя и за каждый уровень опыта (по долям за каждое убийство).
const JP_START := 5
const JP_PER_LEVEL := 10
## Поддержка переключаемых умений списывается раз в UPKEEP_PERIOD секунд.
const UPKEEP_PERIOD := 10.0
## Сколько кнопок умений в HUD (skill1…skill4).
const SLOTS := 4
## Базовый урон умений вики (сотни единиц) → наш масштаб атаки.
const FLAT_SCALE := 0.06
const KIND_NAMES := {"active": "активное", "passive": "пассивное", "toggle": "переключаемое"}
const WEAPON_NAMES := {"blades": "кинжалы или мечи", "crossbow": "арбалет"}
## Вкладки древа Бродяги.
const TABS := [["common", "Общие"], ["blades", "Мечи и кинжалы"], ["crossbow", "Арбалет"]]
## Значки: картинка 128×128 (прозрачные углы) — res://assets/icons/skills/<id>.png; нет файла — кружок с буквой.
const ICON_DIR := "res://assets/icons/skills/"

const SHADE := Color(0.5, 0.3, 0.75)
const WIND := Color(0.35, 0.7, 0.6)
const BLADE := Color(0.82, 0.25, 0.3)
const BOLT := Color(0.78, 0.55, 0.25)

const SKILLS := {
	# ---------- Общие ----------
	"shadow_step": {  # стартовое умение Бродяги (своё, без вики)
		"name": "Шаг тени", "kind": "active", "tab": "common", "weapon": "", "glyph": "Ш", "color": SHADE,
		"desc": "Мгновенный рывок сквозь тень к выбранному зверю.",
		"req": [1, 4, 8], "jp": [0, 2, 3], "start": true,
		"target": "dash", "mp": [3, 4, 5], "cd": [12.0, 10.0, 8.0], "dash": [12.0, 14.0, 16.0],
	},
	"evasion_expert": {  # ← Avoidance Expert
		"name": "Неуловимость", "kind": "passive", "tab": "common", "weapon": "", "glyph": "Н", "color": WIND,
		"desc": "Странница чаще уходит от ударов зверей.",
		"jlv": [1, 15, 30], "jp": [1, 2, 3], "bonus": {"eva": [0.05, 0.10, 0.15]},
	},
	"armor_mastery": {  # ← Armor Mastery (брони пока нет: прибавка к HP и защите)
		"name": "Стойкость странницы", "kind": "passive", "tab": "common", "weapon": "", "glyph": "С",
		"color": Color(0.55, 0.6, 0.7),
		"desc": "Привычка к долгим переходам: больше здоровья и защиты.",
		"jlv": [1, 10, 20, 30, 40], "jp": [1, 2, 3, 4, 5],
		"bonus": {"hp_pct": [0.06, 0.07, 0.08, 0.09, 0.10], "def_flat": [1, 1, 2, 2, 3]},
	},
	"oblivion": {  # ← Oblivion
		"name": "Тихая поступь", "kind": "toggle", "tab": "common", "weapon": "", "glyph": "Т",
		"color": Color(0.4, 0.4, 0.6),
		"desc": "Звери замечают странницу ближе, а её удары реже отвлекают зверя от питомца.",
		"jlv": [1, 10, 20, 30, 40], "jp": [1, 1, 2, 3, 4],
		"mp": [2, 3, 4, 5, 6], "upkeep": [1, 1, 1, 1, 1], "bonus": {"stealth": [0.05, 0.10, 0.15, 0.20, 0.25]},
	},
	"concentration": {  # ← Concentration (точность → у нас шанс крита: промахов у героя нет)
		"name": "Холодный расчёт", "kind": "toggle", "tab": "common", "weapon": "", "glyph": "Х",
		"color": Color(0.45, 0.65, 0.95),
		"desc": "Собранность и точный глаз: удары чаще попадают в уязвимое место.",
		"jlv": [10, 10, 20, 30, 40], "jp": [1, 1, 2, 3, 4], "pre": ["evasion_expert", 1],
		"mp": [2, 2, 3, 3, 4], "upkeep": [1, 1, 1, 1, 1], "bonus": {"crit": [0.02, 0.03, 0.04, 0.05, 0.06]},
	},
	"quick_pace": {  # ← Quick Pace
		"name": "Попутный ветер", "kind": "toggle", "tab": "common", "weapon": "", "glyph": "В", "color": WIND,
		"desc": "Ветер в спину: странница бегает быстрее.",
		"jlv": [15, 15, 20, 30, 40], "jp": [1, 1, 2, 3, 4], "pre": ["concentration", 1],
		"mp": [2, 3, 3, 4, 4], "upkeep": [1, 1, 1, 1, 1], "bonus": {"speed_pct": [0.07, 0.10, 0.14, 0.17, 0.21]},
	},
	"deep_evasion": {  # ← Deep Evasion
		"name": "Танец теней", "kind": "active", "tab": "common", "weapon": "", "glyph": "Д", "color": SHADE,
		"desc": "Короткий танец среди теней: уклонение, атака и точность выше на 20 с.",
		"jlv": [25, 25, 25, 40], "jp": [1, 2, 3, 4], "pre": ["quick_pace", 1],
		"target": "self", "mp": [20, 30, 40, 50], "cd": 90.0, "buff_time": 20.0,
		"buff": {"eva": [0.10, 0.12, 0.13, 0.15], "atk_pct": [0.05, 0.06, 0.08, 0.09], "crit": [0.02, 0.03, 0.04, 0.05]},
	},
	"haste": {  # ← Asuran Haste (у Strider уровни 2–3)
		"name": "Боевой ритм", "kind": "toggle", "tab": "common", "weapon": "", "glyph": "Р",
		"color": Color(0.95, 0.65, 0.3),
		"desc": "Странница держит быстрый ритм боя: атакует чаще.",
		"jlv": [30, 40], "jp": [2, 3], "mp": [16, 21], "upkeep": [3, 4], "bonus": {"aspd": [0.03, 0.05]},
	},
	"evasive_resilience": {  # ← Evasive Resilience (у Strider уровни 2–3)
		"name": "Гибкая стойкость", "kind": "passive", "tab": "common", "weapon": "", "glyph": "Г", "color": WIND,
		"desc": "Чем лучше странница уклоняется, тем больше у неё здоровья и MP.",
		"jlv": [35, 35], "jp": [3, 4], "bonus": {"hp_from_eva": [0.6, 0.8], "mp_from_eva": [0.3, 0.4]},
	},
	# ---------- Мечи и кинжалы ----------
	"backstab": {  # стартовое умение Бродяги (своё, без вики)
		"name": "Удар в спину", "kind": "active", "tab": "blades", "weapon": "blades", "glyph": "У", "color": BLADE,
		"desc": "Удар клинком в незащищённое место — всегда крит.",
		"req": [1, 4, 8], "jp": [0, 2, 3], "start": true,
		"target": "melee", "mp": [3, 4, 5], "cd": 7.0, "mult": [1.3, 1.5, 1.7], "crit": true,
	},
	"blade_mastery": {  # ← Assassin Weapon Mastery (10 ур. вики → 5: наш ур. = два ур. вики)
		"name": "Школа клинка", "kind": "passive", "tab": "blades", "weapon": "blades", "glyph": "К", "color": BLADE,
		"desc": "Выучка мечницы: с кинжалами и мечами атака выше.",
		"jlv": [1, 10, 20, 30, 40], "jp": [1, 2, 3, 4, 5], "bonus": {"atk_pct": [0.04, 0.08, 0.12, 0.16, 0.20]},
	},
	"charge_stab": {  # ← Charge Stab
		"name": "Пронзающий выпад", "kind": "active", "tab": "blades", "weapon": "blades", "glyph": "П",
		"color": BLADE,
		"desc": "Резкий выпад с разгона: один очень сильный укол.",
		"jlv": [5, 10, 20, 30, 40], "jp": [1, 1, 2, 3, 4], "pre": ["blade_mastery", 1],
		"target": "melee", "mp": [7, 10, 13, 16, 19], "cd": 6.0,
		"mult": [3.07, 3.52, 3.97, 4.42, 4.87], "flat": [8, 16, 24, 32, 41],
	},
	"dark_strike": {  # ← Dark Strike (10 → 5 ур.)
		"name": "Три тени", "kind": "active", "tab": "blades", "weapon": "blades", "glyph": "Т", "color": SHADE,
		"desc": "Три стремительных удара подряд, клинки окутаны тенью.",
		"jlv": [10, 10, 20, 30, 40], "jp": [1, 2, 3, 4, 5], "pre": ["charge_stab", 1],
		"target": "melee", "mp": [6, 13, 20, 27, 34], "cd": 3.0, "hits": 3,
		"mult": [1.03, 1.33, 1.63, 1.93, 2.23], "flat": [4, 5, 6, 8, 9],
	},
	"bloody_blade": {  # ← Bloody Blade (10 → 5 ур.)
		"name": "Алая жатва", "kind": "active", "tab": "blades", "weapon": "blades", "glyph": "А",
		"color": Color(0.85, 0.15, 0.25),
		"desc": "Тёмный удар, который возвращает часть нанесённого урона здоровьем.",
		"jlv": [15, 15, 20, 30, 40], "jp": [1, 2, 3, 4, 5], "pre": ["dark_strike", 1],
		"target": "melee", "mp": [4, 10, 16, 22, 28], "cd": 20.0,
		"mult": [1.15, 1.45, 1.75, 2.05, 2.35], "flat": [5, 11, 17, 23, 29], "heal": 0.07,
	},
	"dual_expert": {  # ← Dual Blade Expert
		"name": "Обоерукость", "kind": "passive", "tab": "blades", "weapon": "blades", "glyph": "О", "color": BLADE,
		"desc": "Оба клинка работают слаженно: обычные удары сильнее и чаще.",
		"jlv": [20, 20, 20, 30, 40], "jp": [1, 2, 2, 3, 4], "pre": ["bloody_blade", 1],
		"bonus": {"basic_pct": [0.08, 0.16, 0.24, 0.32, 0.40], "aspd": [0.02, 0.04, 0.06, 0.08, 0.10]},
	},
	"sleeping_dust": {  # ← Sleeping Dust
		"name": "Сонная пыльца", "kind": "active", "tab": "blades", "weapon": "", "glyph": "С",
		"color": Color(0.6, 0.5, 0.85),
		"desc": "Горсть сонной пыльцы в морду зверю рядом: он засыпает, пока его не ударят.",
		"jlv": [20, 20, 20, 30, 40], "jp": [1, 1, 2, 3, 4], "pre": ["bloody_blade", 1],
		"target": "near", "radius": 6.0, "mp": [3, 4, 5, 6, 7], "cd": 30.0, "sleep": [8.0, 8.5, 9.0, 9.5, 10.0],
	},
	"head_breaker": {  # ← Head Breaker
		"name": "Устрашающий удар", "kind": "active", "tab": "blades", "weapon": "blades", "glyph": "Б",
		"color": Color(0.55, 0.2, 0.45),
		"desc": "Жестокий удар: зверь в страхе убегает и не может атаковать.",
		"jlv": [30, 30, 30, 30, 40], "jp": [1, 1, 2, 3, 4], "pre": ["sleeping_dust", 1],
		"target": "melee", "mp": [4, 6, 9, 11, 14], "cd": 30.0,
		"mult": [2.2, 2.7, 3.2, 3.7, 4.2], "flat": [5, 11, 17, 23, 29], "fear": [3.3, 3.6, 3.9, 4.2, 4.5],
	},
	"twin_fury": {  # ← Assassin Impact
		"name": "Вихрь клинков", "kind": "toggle", "tab": "blades", "weapon": "blades", "glyph": "В",
		"color": Color(0.95, 0.35, 0.35),
		"desc": "Пока включено, обычный удар парными клинками иногда бьёт дважды.",
		"jlv": [35, 35, 35], "jp": [1, 2, 3], "pre": ["dual_expert", 1],
		"mp": [5, 8, 10], "upkeep": [1, 2, 2], "bonus": {"double": [0.15, 0.20, 0.25]},
	},
	# ---------- Арбалет ----------
	"crossbow_mastery": {  # ← Crossbow Mastery (10 → 5 ур.)
		"name": "Твёрдая рука", "kind": "passive", "tab": "crossbow", "weapon": "crossbow", "glyph": "Р", "color": BOLT,
		"desc": "Навык стрелка: с арбалетом атака выше.",
		"jlv": [1, 10, 20, 30, 40], "jp": [1, 2, 3, 4, 5],
		"bonus": {"atk_pct": [0.04, 0.08, 0.12, 0.16, 0.20], "atk_flat": [1, 2, 2, 3, 4]},
	},
	"dual_shot": {  # ← Dual Shot
		"name": "Сдвоенный болт", "kind": "active", "tab": "crossbow", "weapon": "crossbow", "glyph": "С",
		"color": BOLT,
		"desc": "Два болта разом в одну цель.",
		"jlv": [5, 10, 20, 30, 40], "jp": [1, 1, 2, 3, 4], "pre": ["crossbow_mastery", 1],
		"target": "ranged", "mp": [5, 7, 9, 12, 14], "cd": 9.0, "hits": 2,
		"mult": [2.35, 2.70, 3.05, 3.40, 3.75], "flat": [7, 9, 11, 13, 15],
	},
	"thrust_arrow": {  # ← Thrust Arrow (10 → 5 ур.)
		"name": "Таранный болт", "kind": "active", "tab": "crossbow", "weapon": "crossbow", "glyph": "Т",
		"color": Color(0.7, 0.6, 0.4),
		"desc": "Тяжёлый болт отбрасывает зверя и на миг пригвождает к месту.",
		"jlv": [10, 10, 20, 30, 40], "jp": [1, 2, 3, 4, 5], "pre": ["dual_shot", 1],
		"target": "ranged", "mp": [3, 4, 6, 7, 9], "cd": 15.0,
		"mult": [2.35, 2.95, 3.55, 4.15, 4.75], "flat": [2, 5, 7, 10, 12], "knock": 5.0, "root": 1.0,
	},
	"piercing_arrow": {  # ← Piercing Arrow (10 → 5 ур.)
		"name": "Кровоточащий болт", "kind": "active", "tab": "crossbow", "weapon": "crossbow", "glyph": "К",
		"color": Color(0.85, 0.2, 0.2),
		"desc": "Болт с зазубринами: рана кровоточит 13 с, и зверь не может залечить её.",
		"jlv": [15, 15, 20, 30, 40], "jp": [1, 2, 3, 4, 5], "pre": ["thrust_arrow", 1],
		"target": "ranged", "mp": [9, 10, 12, 14, 16], "cd": [9.8, 9.6, 9.4, 9.2, 9.0],
		"mult": [2.8, 3.8, 4.8, 5.8, 6.8], "flat": [2, 5, 7, 10, 12],
		"dot": [0.3, 0.3, 0.3, 0.3, 0.3], "dot_time": 13.0, "no_regen": true,
	},
	"crossbow_expert": {  # ← Crossbow Expert
		"name": "Быстрая тетива", "kind": "passive", "tab": "crossbow", "weapon": "crossbow", "glyph": "Б",
		"color": BOLT,
		"desc": "Перезарядка в одно движение: стреляет чаще и сильнее.",
		"jlv": [20, 20, 20, 30, 40], "jp": [1, 2, 2, 3, 4], "pre": ["piercing_arrow", 1],
		"bonus": {"aspd": [0.03, 0.06, 0.09, 0.12, 0.15], "basic_pct": [0.03, 0.06, 0.09, 0.12, 0.15]},
	},
	"cursed_arrow": {  # ← Cursed Arrow
		"name": "Чёрная метка", "kind": "active", "tab": "crossbow", "weapon": "crossbow", "glyph": "Ч",
		"color": SHADE,
		"desc": "Болт, пропитанный тьмой: удар и урон тьмой ещё 15 с.",
		"jlv": [20, 30, 30, 30, 40], "jp": [1, 1, 2, 3, 4], "pre": ["piercing_arrow", 1],
		"target": "ranged", "mp": [5, 7, 9, 11, 13], "cd": 20.0,
		"mult": [2.2, 2.65, 3.1, 3.55, 4.0], "flat": [2, 5, 7, 10, 12],
		"dot": [0.2, 0.2, 0.2, 0.2, 0.2], "dot_flat": [1, 2, 4, 5, 6], "dot_time": 15.0,
	},
	"critical_shot": {  # ← Critical Shot
		"name": "Выстрел в сердце", "kind": "active", "tab": "crossbow", "weapon": "crossbow", "glyph": "В",
		"color": Color(0.95, 0.75, 0.3),
		"desc": "Два прицельных болта — оба критические.",
		"jlv": [35, 35, 35, 35, 40], "jp": [1, 1, 2, 3, 4], "pre": ["cursed_arrow", 1],
		"target": "ranged", "mp": [4, 5, 7, 8, 10], "cd": 8.0, "hits": 2, "crit": true,
		"mult": [2.65, 2.8, 2.95, 3.1, 3.25], "flat": [2, 4, 6, 8, 11],
	},
	"hunter_mark": {  # ← Hunter Impact
		"name": "Беглый огонь", "kind": "toggle", "tab": "crossbow", "weapon": "crossbow", "glyph": "О",
		"color": Color(0.95, 0.55, 0.25),
		"desc": "Пока включено, обычный выстрел из арбалета иногда выпускает второй болт.",
		"jlv": [40, 40, 40], "jp": [1, 2, 3], "pre": ["crossbow_expert", 1],
		"mp": [5, 8, 10], "upkeep": [1, 2, 2], "bonus": {"double": [0.10, 0.20, 0.30]},
	},
	"drain_arrow": {  # ← Drain Arrow
		"name": "Иссушающие болты", "kind": "toggle", "tab": "crossbow", "weapon": "crossbow", "glyph": "И",
		"color": Color(0.4, 0.55, 1.0),
		"desc": "Пока включено, обычные выстрелы возвращают часть урона в MP.",
		"jlv": [40, 40, 40], "jp": [1, 2, 3], "pre": ["critical_shot", 1],
		"mp": [2, 3, 4], "upkeep": [1, 1, 1], "bonus": {"mp_drain": [0.01, 0.015, 0.02]},
	},
}

## Древо класса (порядок — порядок значков в ярусе). Классов без древа — их умения из ClassData.
const CLASS_TREES := {
	"assassin": [
		"shadow_step", "evasion_expert", "armor_mastery", "oblivion", "concentration", "quick_pace",
		"deep_evasion", "haste", "evasive_resilience",
		"blade_mastery", "backstab", "charge_stab", "dark_strike", "bloody_blade", "dual_expert", "sleeping_dust",
		"head_breaker", "twin_fury",
		"crossbow_mastery", "dual_shot", "thrust_arrow", "piercing_arrow", "crossbow_expert", "cursed_arrow",
		"critical_shot", "hunter_mark", "drain_arrow",
	],
}

## Названия бонусов (тексты окна героя).
const BONUS_NAMES := {
	"eva": "уклонение", "atk_pct": "атака", "atk_flat": "атака", "hp_pct": "макс. HP", "def_flat": "защита",
	"crit": "шанс крита", "speed_pct": "скорость бега", "aspd": "скорость атаки", "basic_pct": "урон обычных атак",
	"double": "шанс двойной атаки", "mp_drain": "MP с выстрела", "stealth": "незаметность",
	"hp_from_eva": "HP от уклонения", "mp_from_eva": "MP от уклонения",
}


# ---------- Данные ----------

## Умение по id: из древа или (у других классов) обёртка умения ClassData. Пустой словарь — нет такого.
static func get_skill(id: String) -> Dictionary:
	if SKILLS.has(id):
		return SKILLS[id]
	var cs := ClassData.skill(id)
	if cs.is_empty():
		return {}
	var nm := String(cs["name"])
	var col := Color(0.6, 0.45, 0.85)
	for cid in ClassData.CLASSES:
		var c: Dictionary = ClassData.CLASSES[cid]
		if (c["skills"] as Array).has(id):
			col = c["accent"]
	return {
		"name": nm, "kind": "active", "tab": "common", "weapon": "", "glyph": nm.substr(0, 1), "color": col,
		"desc": String(cs.get("desc", "")), "req": [1], "jp": [0], "start": true, "class_skill": true,
		"cd": float(cs.get("cd", 1.0)), "mp": [0],
	}


static func has_tree(class_id: String) -> bool:
	return CLASS_TREES.has(class_id)


## id умений класса (у Бродяги — всё древо, у других — два умения класса).
static func list_for(class_id: String) -> Array:
	if CLASS_TREES.has(class_id):
		return CLASS_TREES[class_id]
	return ClassData.cls(class_id)["skills"]


## Вкладки древа класса: [[id, название], ...].
static func tabs_for(class_id: String) -> Array:
	if CLASS_TREES.has(class_id):
		return TABS
	return [["common", "Умения"]]


## id умений класса на вкладке tab.
static func list_tab(class_id: String, tab: String) -> Array:
	var res: Array = []
	for id in list_for(class_id):
		if String(get_skill(String(id)).get("tab", "common")) == tab:
			res.append(String(id))
	return res


static func has_skill(class_id: String, id: String) -> bool:
	return list_for(class_id).has(id)


static func max_level(id: String) -> int:
	var sk := get_skill(id)
	if sk.has("req"):
		return (sk["req"] as Array).size()
	return (sk.get("jlv", []) as Array).size()


## Наш уровень героя для уровня n умения (0 — такого уровня нет).
static func level_needed(id: String, n: int) -> int:
	var sk := get_skill(id)
	if n < 1 or n > max_level(id):
		return 0
	if sk.has("req"):
		return int(sk["req"][n - 1])
	return PetSkills.req_level(int(sk["jlv"][n - 1]))


## Стоимость уровня n в JP.
static func jp_cost(id: String, n: int) -> int:
	var a: Array = get_skill(id).get("jp", [])
	if n < 1 or n > a.size():
		return 0
	return int(a[n - 1])


## Значение поля key на уровне n: массив — n-й элемент (за краем — последний), число — как есть.
static func field(id: String, key: String, n: int) -> float:
	var v: Variant = get_skill(id).get(key, 0.0)
	if v is Array:
		var a: Array = v
		if a.is_empty():
			return 0.0
		return float(a[clampi(n - 1, 0, a.size() - 1)])
	if v is float or v is int:
		return float(v)
	return 0.0


static func mp_cost(id: String, n: int) -> int:
	return roundi(field(id, "mp", n))


static func upkeep(id: String, n: int) -> int:
	return roundi(field(id, "upkeep", n))


static func cooldown(id: String, n: int) -> float:
	return field(id, "cd", n)


static func kind(id: String) -> String:
	return String(get_skill(id).get("kind", ""))


static func kind_name(id: String) -> String:
	return String(KIND_NAMES.get(kind(id), ""))


## Подходит ли надетое оружие (вид ItemData: "daggers", "dual_swords", "crossbow", "" — нет) умению.
static func weapon_ok(id: String, weapon_kind: String) -> bool:
	var need := String(get_skill(id).get("weapon", ""))
	return need == "" or ItemData.weapon_group(weapon_kind) == need


static func weapon_name(id: String) -> String:
	return String(WEAPON_NAMES.get(String(get_skill(id).get("weapon", "")), "любое"))


## Путь значка умения (может не существовать — тогда древо рисует кружок с буквой).
static func icon_path(id: String) -> String:
	return ICON_DIR + id + ".png"


## JP героя уровня lvl по умолчанию (новый герой, старые сохранения).
static func default_jp(lvl: int) -> int:
	return JP_START + JP_PER_LEVEL * (maxi(lvl, 1) - 1)


# ---------- Запись героя (Game.hero) ----------

## Новая запись: {"jp", "jp_part", "skills" {id: ур.}, "toggles" {id: true}, "slots" [id × SLOTS]}.
static func new_record(class_id: String, lvl: int) -> Dictionary:
	var rec := {"jp": default_jp(lvl), "jp_part": 0.0, "skills": {}, "toggles": {}, "slots": []}
	ensure_record(rec, class_id)
	return rec


## Приводит запись к классу: поля на месте, стартовые умения изучены, чужие умения и кнопки убраны,
## пустые кнопки — стартовыми активными умениями.
static func ensure_record(rec: Dictionary, class_id: String) -> void:
	if not rec.has("jp"):
		rec["jp"] = JP_START
	if not rec.has("jp_part"):
		rec["jp_part"] = 0.0
	var skills: Dictionary = {}
	var src: Variant = rec.get("skills", {})
	if src is Dictionary:
		for k in src:
			var id := String(k)
			var n := mini(int(src[k]), max_level(id))
			if n > 0 and has_skill(class_id, id):
				skills[id] = n
	for id in list_for(class_id):
		if bool(get_skill(String(id)).get("start", false)) and int(skills.get(id, 0)) < 1:
			skills[String(id)] = 1
	rec["skills"] = skills
	var toggles: Dictionary = {}
	var tsrc: Variant = rec.get("toggles", {})
	if tsrc is Dictionary:
		for k in tsrc:
			var id := String(k)
			if bool(tsrc[k]) and kind(id) == "toggle" and int(skills.get(id, 0)) > 0:
				toggles[id] = true
	rec["toggles"] = toggles
	var slots: Array = []
	var ssrc: Variant = rec.get("slots", [])
	var any := false
	for i in SLOTS:
		var id := ""
		if ssrc is Array and i < (ssrc as Array).size():
			id = String((ssrc as Array)[i])
		if id != "" and (int(skills.get(id, 0)) <= 0 or kind(id) == "passive"):
			id = ""
		if id != "":
			any = true
		slots.append(id)
	if not any:
		# Пустые кнопки — стартовые активные умения в порядке класса (ClassData: «Удар в спину», «Шаг тени»)
		var i := 0
		for id in ClassData.cls(class_id)["skills"]:
			if i >= SLOTS:
				break
			if int(skills.get(String(id), 0)) > 0 and kind(String(id)) == "active":
				slots[i] = String(id)
				i += 1
	rec["slots"] = slots


static func skill_level(rec: Dictionary, id: String) -> int:
	var sk: Variant = rec.get("skills", {})
	if sk is Dictionary:
		return int((sk as Dictionary).get(id, 0))
	return 0


static func toggle_on(rec: Dictionary, id: String) -> bool:
	var tg: Variant = rec.get("toggles", {})
	if tg is Dictionary:
		return bool((tg as Dictionary).get(id, false))
	return false


## Почему нельзя изучить следующий уровень умения id героем класса class_id уровня lvl ("" — можно).
static func learn_block(rec: Dictionary, class_id: String, lvl: int, id: String) -> String:
	var sk := get_skill(id)
	if sk.is_empty() or not has_skill(class_id, id):
		return "Классу умение недоступно"
	var n := skill_level(rec, id) + 1
	if n > max_level(id):
		return "Изучено полностью"
	var need := level_needed(id, n)
	if lvl < need:
		return "Нужен ур. %d" % need
	if sk.has("pre"):
		var pre: Array = sk["pre"]
		var pl := int(pre[1])
		if skill_level(rec, String(pre[0])) < pl:
			return "Нужно «%s» ур. %d" % [String(get_skill(String(pre[0]))["name"]), pl]
	var cost := jp_cost(id, n)
	if int(rec.get("jp", 0)) < cost:
		return "Не хватает JP (нужно %d)" % cost
	return ""


## Изучить следующий уровень: тратит JP. true — изучено.
static func learn(rec: Dictionary, class_id: String, lvl: int, id: String) -> bool:
	if learn_block(rec, class_id, lvl, id) != "":
		return false
	var n := skill_level(rec, id) + 1
	var skills: Dictionary = rec["skills"]
	skills[id] = n
	rec["jp"] = int(rec["jp"]) - jp_cost(id, n)
	return true


## Выключить переключаемые умения, которым не подходит оружие weapon_kind. Возвращает их id.
static func drop_unfit_toggles(rec: Dictionary, weapon_kind: String) -> Array:
	var off: Array = []
	var tg: Variant = rec.get("toggles", {})
	if not (tg is Dictionary):
		return off
	var d: Dictionary = tg
	for k in d.keys():
		if not weapon_ok(String(k), weapon_kind):
			d.erase(k)
			off.append(String(k))
	return off


## Почему умение id нельзя применить с оружием weapon_kind ("" — можно): «Нужен арбалет» / «Нужны клинки».
static func weapon_block(id: String, weapon_kind: String) -> String:
	if weapon_ok(id, weapon_kind):
		return ""
	match String(get_skill(id).get("weapon", "")):
		"crossbow":
			return "Нужен арбалет"
		"blades":
			return "Нужны клинки"
	return "Не подходит оружие"


## Начислить JP долями (amount может быть дробным). Возвращает, сколько целых JP прибавилось.
static func add_jp(rec: Dictionary, amount: float) -> int:
	var part := float(rec.get("jp_part", 0.0)) + maxf(amount, 0.0)
	var whole := int(floor(part + 0.0001))
	rec["jp_part"] = maxf(0.0, part - float(whole))
	rec["jp"] = int(rec.get("jp", 0)) + whole
	return whole


## Сумма бонусов пассивных и включённых переключаемых умений при оружии weapon_kind:
## {"eva", "atk_pct", "atk_flat", "hp_pct", "def_flat", "crit", "speed_pct", "aspd", "basic_pct", "double",
##  "mp_drain", "stealth", "hp_from_eva", "mp_from_eva"} (только то, что есть).
static func bonuses(rec: Dictionary, class_id: String, weapon_kind: String) -> Dictionary:
	var res: Dictionary = {}
	for id in list_for(class_id):
		var sid := String(id)
		var sk := get_skill(sid)
		if not sk.has("bonus"):
			continue
		var n := skill_level(rec, sid)
		if n <= 0 or not weapon_ok(sid, weapon_kind):
			continue
		if String(sk["kind"]) == "toggle" and not toggle_on(rec, sid):
			continue
		var b: Dictionary = sk["bonus"]
		for key in b:
			var a: Array = b[key]
			res[key] = float(res.get(key, 0.0)) + float(a[clampi(n - 1, 0, a.size() - 1)])
	return res


## Сколько JP стоит всё древо класса (без стартовых уровней) — для проверки темпа.
static func total_cost(class_id: String) -> int:
	var t := 0
	for id in list_for(class_id):
		for n in range(1, max_level(String(id)) + 1):
			t += jp_cost(String(id), n)
	return t


# ---------- Тексты для окна героя ----------

static func _pct(v: float) -> String:
	var p := v * 100.0
	if is_equal_approx(p, roundf(p)):
		return "%d%%" % roundi(p)
	return "%.1f%%" % p


static func _num(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(roundi(v))
	return "%.1f" % v


static func bonus_text(key: String, v: float) -> String:
	match key:
		"eva", "crit", "atk_pct", "hp_pct", "speed_pct", "aspd", "basic_pct":
			return "%s +%s" % [String(BONUS_NAMES[key]), _pct(v)]
		"atk_flat", "def_flat":
			return "%s +%s" % [String(BONUS_NAMES[key]), _num(v)]
		"double":
			return "шанс второго удара %s" % _pct(v)
		"mp_drain":
			return "обычный выстрел возвращает %s урона в MP" % _pct(v)
		"stealth":
			return "звери замечают вас на %s ближе, удары отвлекают зверя от питомца на %s реже" % [_pct(v), _pct(v * 2.0)]
		"hp_from_eva":
			return "макс. HP +%s%% за 1%% уклонения" % _num(v)
		"mp_from_eva":
			return "макс. MP +%s%% за 1%% уклонения" % _num(v)
	return "%s %s" % [key, _num(v)]


## Урон одного удара: «307% атаки + 8».
static func _dmg_text(id: String, n: int) -> String:
	var t := "%s атаки" % _pct(field(id, "mult", n))
	var fl := field(id, "flat", n)
	if fl > 0.0:
		t += " + %s" % _num(fl)
	return t


## Эффект уровня n (n ≥ 1) одной строкой.
static func effect_text(id: String, n: int) -> String:
	var sk := get_skill(id)
	if sk.is_empty():
		return ""
	if bool(sk.get("class_skill", false)):
		return "%s; перезарядка %s с" % [String(sk["desc"]), _num(float(sk["cd"]))]
	var parts: PackedStringArray = []
	var k := String(sk.get("kind", ""))
	if k == "passive" or k == "toggle":
		var b: Dictionary = sk["bonus"]
		for key in b:
			parts.append(bonus_text(String(key), field_bonus(id, String(key), n)))
		if k == "toggle":
			parts.append("включение %d MP, %d MP / 10 с" % [mp_cost(id, n), upkeep(id, n)])
		return ", ".join(parts)
	match String(sk.get("target", "")):
		"dash":
			parts.append("рывок к цели до %s м" % _num(field(id, "dash", n)))
		"self":
			var bf: Dictionary = sk.get("buff", {})
			var bp: PackedStringArray = []
			for key in bf:
				bp.append(bonus_text(String(key), field_buff(id, String(key), n)))
			parts.append("%s с: %s" % [_num(float(sk.get("buff_time", 0.0))), ", ".join(bp)])
		"near":
			pass
		_:
			var hits := int(sk.get("hits", 1))
			if hits > 1:
				parts.append("урон %d × (%s)" % [hits, _dmg_text(id, n)])
			else:
				parts.append("урон %s" % _dmg_text(id, n))
	if bool(sk.get("crit", false)):
		parts.append("всегда крит")
	if sk.has("heal"):
		parts.append("лечит на %s урона" % _pct(float(sk["heal"])))
	if sk.has("sleep"):
		parts.append("сон %s с (будит удар), до %s м" % [_num(field(id, "sleep", n)), _num(float(sk.get("radius", 6.0)))])
	if sk.has("fear"):
		parts.append("страх %s с: зверь убегает и не бьёт" % _num(field(id, "fear", n)))
	if sk.has("knock"):
		parts.append("отбрасывает на %s м и держит %s с" % [_num(float(sk["knock"])), _num(float(sk.get("root", 0.0)))])
	if sk.has("dot"):
		var dt := "%s атаки" % _pct(field(id, "dot", n))
		if field(id, "dot_flat", n) > 0.0:
			dt += " + %s" % _num(field(id, "dot_flat", n))
		parts.append("ещё %s с по %s в секунду%s" % [_num(float(sk["dot_time"])), dt,
			", зверь не лечится" if bool(sk.get("no_regen", false)) else ""])
	if mp_cost(id, n) > 0:
		parts.append("MP %d" % mp_cost(id, n))
	parts.append("перезарядка %s с" % _num(cooldown(id, n)))
	return ", ".join(parts)


static func field_bonus(id: String, key: String, n: int) -> float:
	var b: Dictionary = get_skill(id).get("bonus", {})
	var a: Array = b.get(key, [])
	return 0.0 if a.is_empty() else float(a[clampi(n - 1, 0, a.size() - 1)])


static func field_buff(id: String, key: String, n: int) -> float:
	var b: Dictionary = get_skill(id).get("buff", {})
	var a: Array = b.get(key, [])
	return 0.0 if a.is_empty() else float(a[clampi(n - 1, 0, a.size() - 1)])


## Требования к уровню n: «ур. 6, «Три тени» ур. 1, 2 JP».
static func requirement_text(id: String, n: int) -> String:
	var sk := get_skill(id)
	if n < 1 or n > max_level(id):
		return ""
	var parts: PackedStringArray = ["ур. %d" % level_needed(id, n)]
	if sk.has("pre"):
		var pre: Array = sk["pre"]
		parts.append("«%s» ур. %d" % [String(get_skill(String(pre[0]))["name"]), int(pre[1])])
	parts.append("%d JP" % jp_cost(id, n))
	return ", ".join(parts)

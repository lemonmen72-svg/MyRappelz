class_name HeroSkills
extends RefCounted
## Умения героя и их древа по профессиям. Бродяга (ClassData.WANDERER) умений не имеет. У Наёмника (id "assassin") —
## древо по образцу профессии Strider из Rappelz (SKILLS ниже, справка — tools/rappelz_strider_reference.md), у
## остальных восьми профессий — данные JobSkills (справка — tools/rappelz_jobs_reference.md); механика и числа — из
## вики, названия, описания и значки свои. Требуемый уровень героя = 10 + JLv вики × 0.75 (req_level: умения
## профессии открываются с 11 по 40 ур.; стартовые умения Наёмника — с получения профессии, req 10).
## Умение изучается и повышается за очки умений героя (JP) в окне героя (CharacterWindow, вкладки древа).
## Применение — Player (кнопки skill1…skill4): умения Наёмника — Player._cast_hero, умения с полем fx —
## движок HeroSkillFx (формат — раздел «Движок эффектов» ниже).
##
## Поля умения:
##   kind — "active" (кнопка), "passive" (действует всегда), "toggle" (включается в древе или кнопкой,
##     тратит MP при включении и раз в 10 с);
##   tab — вкладка древа (у Наёмника "common" / "blades" / "crossbow", у других профессий — из JobSkills.TREES);
##   weapon — какое оружие нужно: "" — любое, группа WEAPON_GROUPS ("blades", "crossbow", "shield", "staff" …) или
##     массив групп (активное без него не применить, бонусы пассивных и переключаемых действуют только с ним);
##   jlv — уровень профессии в вики для каждого уровня умения (наш уровень = req_level), req — наш уровень напрямую;
##   jp — стоимость каждого уровня в JP; start — 1-й уровень дан сразу (стартовое умение профессии);
##   pre — [умение, уровень]: что нужно изучить раньше (линия в древе);
##   числа по уровням умения — массивы (n-й элемент — уровень n).
## Активные Наёмника: mp, cd (с; число или массив), target ("melee" — клинками рядом, "ranged" — болтом из арбалета,
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
## Воин: искра духа — за каждые SPARK_HITS попавших обычных атак (JobFxWarrior).
const SPARK_HITS := 4
## Базовый урон умений вики (сотни единиц) → наш масштаб атаки.
const FLAT_SCALE := 0.06
const KIND_NAMES := {"active": "активное", "passive": "пассивное", "toggle": "переключаемое"}
## Вкладки древа Наёмника.
const TABS := [["common", "Общие"], ["blades", "Мечи и кинжалы"], ["crossbow", "Арбалет"]]
## Значки: картинка 128×128 (прозрачные углы) — res://assets/icons/skills/<id>.png; нет файла — кружок с буквой.
const ICON_DIR := "res://assets/icons/skills/"

const SHADE := Color(0.5, 0.3, 0.75)
const WIND := Color(0.35, 0.7, 0.6)
const BLADE := Color(0.82, 0.25, 0.3)
const BOLT := Color(0.78, 0.55, 0.25)

const SKILLS := {
	# ---------- Общие ----------
	"shadow_step": {  # стартовое умение Наёмника (своё, без вики)
		"name": "Шаг тени", "kind": "active", "tab": "common", "weapon": "", "glyph": "Ш", "color": SHADE,
		"desc": "Мгновенный рывок сквозь тень к выбранному зверю.",
		"req": [10, 20, 30], "jp": [0, 2, 3], "start": true,
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
	"concentration": {  # ← Concentration (точность → у нас шанс крита: промахи героя редки, HeroStats)
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
	"backstab": {  # стартовое умение Наёмника (своё, без вики)
		"name": "Удар в спину", "kind": "active", "tab": "blades", "weapon": "blades", "glyph": "У", "color": BLADE,
		"desc": "Удар клинком в незащищённое место — всегда крит.",
		"req": [10, 20, 30], "jp": [0, 2, 3], "start": true,
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

## Древо Наёмника (порядок — порядок значков в ярусе). Древа остальных профессий — JobSkills.TREES,
## у Бродяги древа нет.
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

## Группы оружия для поля weapon умения: kinds — виды хвата (ItemData.WEAPON_KINDS, ItemData.grip_kind: один кинжал —
## "dagger", два — "daggers"), shield — нужен щит во второй
## руке, name — для карточки, need — сообщение, когда оружие не подходит (по умолчанию «Нужно оружие: …»).
const WEAPON_GROUPS := {
	"blades": {"kinds": ["dagger", "daggers", "sword_1h", "dual_swords"], "name": "кинжалы или мечи", "need": "Нужны клинки"},
	"crossbow": {"kinds": ["crossbow"], "name": "арбалет", "need": "Нужен арбалет"},
	"bow": {"kinds": ["bow"], "name": "лук", "need": "Нужен лук"},
	"shield": {"kinds": [], "shield": true, "name": "щит", "need": "Нужен щит"},
	"sword": {"kinds": ["sword_1h", "sword_2h", "dual_swords"], "name": "меч"},
	"mace": {"kinds": ["mace_1h", "mace_2h"], "name": "булава"},
	"axe": {"kinds": ["axe_1h", "axe_2h", "dual_axes"], "name": "топор"},
	"staff": {"kinds": ["staff_1h", "staff_2h"], "name": "посох"},
	"dagger": {"kinds": ["dagger", "daggers"], "name": "кинжал"},
	"dual_swords": {"kinds": ["dual_swords"], "name": "два меча", "need": "Нужны два меча"},
	"dual_axes": {"kinds": ["dual_axes"], "name": "два топора", "need": "Нужны два топора"},
	"sword_2h": {"kinds": ["sword_2h"], "name": "двуручный меч"},
	"axe_2h": {"kinds": ["axe_2h"], "name": "двуручный топор"},
}
## Требуемый уровень героя = JOB_REQ_BASE + JLv вики × JOB_REQ_K (JLv 1 → 11, 40 → 40).
const JOB_REQ_BASE := 10.0
const JOB_REQ_K := 0.75
## Уровни умения по JLv вики: n-й уровень — не раньше этих JLv (последний — 40).
const JLV_STEPS := [0, 10, 20, 30]
## Пусто у Бродяги (вкладки древа, кнопка умения).
const WANDERER_NOTE := "Умения появятся после выбора профессии на 10 уровне"

## Названия бонусов (тексты окна героя).
const BONUS_NAMES := {
	"eva": "уклонение", "atk_pct": "атака", "atk_flat": "атака", "hp_pct": "макс. HP", "def_flat": "защита",
	"crit": "шанс крита", "speed_pct": "скорость бега", "aspd": "скорость атаки", "basic_pct": "урон обычных атак",
	"double": "шанс двойной атаки", "mp_drain": "MP с выстрела", "stealth": "незаметность",
	"hp_from_eva": "HP от уклонения", "mp_from_eva": "MP от уклонения",
	"def_pct": "защита", "matk_pct": "маг. атака", "mdef_flat": "маг. защита", "mp_pct": "макс. MP", "hp_flat": "макс. HP",
	"regen": "восстановление HP", "guard": "получаемый урон", "block": "шанс блока", "cdr": "перезарядка умений",
	"cast": "скорость каста",
	"sparks": "запас искр духа", "edge": "урон стихией к обычным атакам", "edge_stun": "шанс оглушить ударом",
	"edge_poison": "шанс отравить ударом", "edge_mp": "шанс вернуть MP ударом", "poison": "шанс отравить выстрелом",
	"thorns": "ответный урон огнём",
	"str": "Сила", "vit": "Выносливость", "agi": "Ловкость", "int": "Интеллект", "wis": "Мудрость", "dex": "Меткость",
	"luck": "Удача",
}
## Статусы зверя для эффекта "status" движка (тексты).
const STATUS_NAMES := {
	"stun": "оглушение", "sleep": "сон (будит удар)", "fear": "страх: зверь убегает", "slow": "бег медленнее",
	"root": "держит на месте", "blind": "морок: все удары мимо", "miss": "промахи", "vuln": "урон по зверю выше",
	"weak": "удары зверя слабее", "taunt": "зверь бьёт героя",
}

## Движок эффектов (данные умения; применяет HeroSkillFx, вызывает Player.use_skill):
## Пассивные (kind "passive") и переключаемые ("toggle"): bonus — {ключ: массив по уровням}, ключи BONUS_NAMES
##   (у Player.recalc_stats: атака/защита/HP/MP в долях и числах, уклонение, крит, скорость, блок, перезарядка,
##   7 статов "str"…"luck" — прибавка к статам до формул); у переключаемых ещё mp (включение) и upkeep
##   (MP за UPKEEP_PERIOD с); aura — "both" (герою и питомцу) / "pet" (только питомцу, герою бонус не идёт;
##   питомцу — этап 2: PetManager читает HeroSkills.pet_aura_bonuses); group — одно умение группы за раз.
## Активные (kind "active"): use — как выбирается цель: "melee" (удар оружием по цели рядом), "ranged" (снаряд
##   оружия), "magic" (заклинание по цели до range м; proj = true — летит сгусток, эффекты при попадании),
##   "near" (цель в radius м), "self" (без цели), "pet" (призванный питомец); anim — "attack" | "cast" | "bash" |
##   "spin" | "buff" | "dash"; mp, cd — числа или массивы по уровням; fx — список эффектов по порядку:
##   {"do": "damage", "mult", "flat", "hits", "crit": bool, "power": "atk" | "matk", "area": радиус вокруг цели,
##     "leech": доля урона в HP героя};
##   {"do": "heal", "who": "self" | "pet" | "ally" (кому хуже), "pct": доля макс. HP, "mult": доля маг. атаки};
##   {"do": "hot", "who", "pct": доля макс. HP за всё время, "time"} — лечение со временем;
##   {"do": "status", "status": STATUS_NAMES, "time", "value" (доля для slow/miss/vuln/weak), "chance", "area"};
##   {"do": "dot", "mult", "flat", "time", "no_regen"} — урон в секунду;
##   {"do": "knock", "dist"} — отбросить;
##   {"do": "buff", "who": "self" | "pet" | "both", "time", "bonus": {ключ: массив}} — усиление на время
##     (значок у полоски HP, Player.timed_bonus; питомцу — этап 2);
##   {"do": "special", "handler": "<имя>"} — особая механика: метод sp_<имя>(sid, n, target, e) в HeroSkillFx.
##   Числа эффектов — массивы по уровням умения (или одно число).
## Наёмник (SKILLS выше) — прежний формат активных (target, mult, flat, hits, crit, heal, sleep, fear, knock, root,
##   dot, buff), его применяет Player._cast_hero.

## Профессия, для которой по умолчанию берутся вкладка, уровни, пререквизит и оружие общих умений (ставит Game).
static var job := ""
static var _merged: Dictionary = {}


# ---------- Данные ----------

## Данные умения без привязки к профессии (Наёмник или JobSkills); {} — нет такого.
static func base_skill(id: String) -> Dictionary:
	if SKILLS.has(id):
		return SKILLS[id]
	return JobSkills.SKILLS.get(id, {})


## Есть ли умение героя с таким id.
static func is_skill(id: String) -> bool:
	return not base_skill(id).is_empty()


## Умение по id для профессии class_id ("" — текущая, HeroSkills.job): данные умения + запись древа профессии
## (вкладка, уровни jlv, пререквизит, оружие). Умения Наёмника в его древе — как есть. {} — нет такого.
static func get_skill(id: String, class_id: String = "") -> Dictionary:
	var base := base_skill(id)
	if base.is_empty():
		return {}
	var cid := class_id if class_id != "" else job
	var e := JobSkills.entry(cid, id)
	if e.is_empty():
		if SKILLS.has(id):
			return base
		cid = JobSkills.first_job_with(id)
		e = JobSkills.entry(cid, id)
	var key := cid + "/" + id
	if _merged.has(key):
		return _merged[key]
	var sk: Dictionary = base.duplicate()
	if not e.is_empty():
		var first := int(e[2])
		var lv := int(base.get("lv", 3 if first >= 35 else 5))
		if base.has("jlv"):
			lv = (base["jlv"] as Array).size()
		sk["tab"] = String(e[1])
		sk["jlv"] = jlv_levels(first, lv)
		sk.erase("req")
		sk.erase("start")
		if String(e[3]) != "":
			sk["pre"] = [String(e[3]), 1]
		else:
			sk.erase("pre")
		if e.size() > 4:
			sk["weapon"] = e[4]
		if not sk.has("jp") or (sk["jp"] as Array).size() != lv:
			var src: Array = [1, 2, 3, 4, 5] if String(sk.get("kind", "")) == "passive" else [1, 1, 2, 3, 4]
			if lv <= 3:
				src = [1, 2, 3]
			sk["jp"] = src.slice(0, lv)
	if not sk.has("glyph"):
		sk["glyph"] = String(sk.get("name", "?")).substr(0, 1)
	if not sk.has("color"):
		sk["color"] = JobSkills.COLORS.get(String(sk.get("c", "")), Color(0.6, 0.6, 0.7))
	if not sk.has("weapon"):
		sk["weapon"] = ""
	if not sk.has("tab"):
		sk["tab"] = "common"
	_merged[key] = sk
	return sk


## JLv вики по уровням умения: 1-й — first, дальше не раньше 10, 20, 30, последний — 40.
static func jlv_levels(first: int, lv: int) -> Array:
	var res: Array = []
	for k in lv:
		if k == lv - 1 and lv > 1:
			res.append(maxi(first, 40))
		else:
			res.append(maxi(first, int(JLV_STEPS[mini(k, JLV_STEPS.size() - 1)])))
	return res


## Наш уровень героя для JLv вики: 10 + JLv × 0.75 (JLv 1 → 11, 5 → 14, 10 → 18, 20 → 25, 30 → 33, 40 → 40).
static func req_level(jlv: int) -> int:
	return roundi(JOB_REQ_BASE + float(jlv) * JOB_REQ_K)


static func has_tree(class_id: String) -> bool:
	return not list_for(class_id).is_empty()


## id умений профессии (у Бродяги — пусто).
static func list_for(class_id: String) -> Array:
	if CLASS_TREES.has(class_id):
		return CLASS_TREES[class_id]
	return JobSkills.ids(class_id)


## Вкладки древа профессии: [[id, название], ...] (у Бродяги — пусто).
static func tabs_for(class_id: String) -> Array:
	if CLASS_TREES.has(class_id):
		return TABS
	return JobSkills.TABS.get(class_id, [])


## id умений профессии на вкладке tab.
static func list_tab(class_id: String, tab: String) -> Array:
	var res: Array = []
	for id in list_for(class_id):
		if String(get_skill(String(id), class_id).get("tab", "common")) == tab:
			res.append(String(id))
	return res


static func has_skill(class_id: String, id: String) -> bool:
	return list_for(class_id).has(id)


static func max_level(id: String, class_id: String = "") -> int:
	var sk := get_skill(id, class_id)
	if sk.has("req"):
		return (sk["req"] as Array).size()
	return (sk.get("jlv", []) as Array).size()


## Наш уровень героя для уровня n умения (0 — такого уровня нет).
static func level_needed(id: String, n: int, class_id: String = "") -> int:
	var sk := get_skill(id, class_id)
	if n < 1 or n > max_level(id, class_id):
		return 0
	if sk.has("req"):
		return int(sk["req"][n - 1])
	return req_level(int(sk["jlv"][n - 1]))


## Стоимость уровня n в JP.
static func jp_cost(id: String, n: int, class_id: String = "") -> int:
	var a: Array = get_skill(id, class_id).get("jp", [])
	if n < 1 or n > a.size():
		return 0
	return int(a[n - 1])


## Значение поля key на уровне n: массив — n-й элемент (за краем — последний), число — как есть.
static func field(id: String, key: String, n: int) -> float:
	return value_at(get_skill(id).get(key, 0.0), n)


## Число из значения-массива по уровням (или числа) на уровне n.
static func value_at(v: Variant, n: int) -> float:
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
	return String(base_skill(id).get("kind", ""))


static func kind_name(id: String) -> String:
	var t := String(KIND_NAMES.get(kind(id), ""))
	match String(base_skill(id).get("aura", "")):
		"both":
			t += " (аура: герой и питомец)"
		"pet":
			t += " (аура питомца)"
	return t


## Готово ли действие умения (этап 1: умения Наёмника и образцы движка). Остальные можно изучить, действие —
## на этапе 2.
static func is_ready(id: String) -> bool:
	var sk := base_skill(id)
	match String(sk.get("kind", "")):
		"passive", "toggle":
			return sk.has("bonus")
		"active":
			return sk.has("fx") or sk.has("target")
	return false


# ---------- Оружие ----------

## Группы оружия, которые нужны умению (пусто — любое).
static func weapon_need(id: String, class_id: String = "") -> Array:
	var w: Variant = get_skill(id, class_id).get("weapon", "")
	if w is Array:
		return w
	var s := String(w)
	return [] if s == "" else [s]


## Подходит ли оружие вида weapon_kind (и щит во второй руке) группе group.
static func group_fits(group: String, weapon_kind: String, shield: bool = false) -> bool:
	var g: Dictionary = WEAPON_GROUPS.get(group, {})
	if bool(g.get("shield", false)):
		return shield
	return (g.get("kinds", []) as Array).has(weapon_kind)


## Подходит ли надетое оружие (вид ItemData, "" — нет; shield — щит во второй руке) умению.
static func weapon_ok(id: String, weapon_kind: String, shield: bool = false, class_id: String = "") -> bool:
	var need := weapon_need(id, class_id)
	if need.is_empty():
		return true
	for g in need:
		if group_fits(String(g), weapon_kind, shield):
			return true
	return false


static func weapon_name(id: String, class_id: String = "") -> String:
	var need := weapon_need(id, class_id)
	if need.is_empty():
		return "любое"
	var names: PackedStringArray = []
	for g in need:
		names.append(String((WEAPON_GROUPS.get(String(g), {}) as Dictionary).get("name", String(g))))
	return " или ".join(names)


## Почему умение id нельзя применить с оружием ("" — можно): «Нужен арбалет», «Нужны клинки», «Нужен щит»…
static func weapon_block(id: String, weapon_kind: String, shield: bool = false) -> String:
	if weapon_ok(id, weapon_kind, shield):
		return ""
	var need := weapon_need(id)
	if need.size() == 1:
		var g: Dictionary = WEAPON_GROUPS.get(String(need[0]), {})
		if g.has("need"):
			return String(g["need"])
	return "Нужно оружие: " + weapon_name(id)


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


## Приводит запись к профессии: поля на месте, стартовые умения изучены, чужие умения и кнопки убраны,
## пустые кнопки — стартовыми активными умениями (ClassData skills). Умения, изученные раньше на уровне ниже нового
## требования (старые сохранения), не отбираются.
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
			var n := mini(int(src[k]), max_level(id, class_id))
			if n > 0 and has_skill(class_id, id):
				skills[id] = n
	for id in list_for(class_id):
		if bool(get_skill(String(id), class_id).get("start", false)) and int(skills.get(id, 0)) < 1:
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
		# Пустые кнопки — стартовые активные умения в порядке профессии (Наёмник: «Удар в спину», «Шаг тени»)
		var i := 0
		for id in ClassData.cls(class_id).get("skills", []):
			if i >= SLOTS:
				break
			if int(skills.get(String(id), 0)) > 0 and kind(String(id)) == "active":
				slots[i] = String(id)
				i += 1
	rec["slots"] = slots


## Сбросить все изученные умения с возвратом потраченных JP (стартовые уровни бесплатны). Возвращает JP.
static func refund_all(rec: Dictionary, class_id: String) -> int:
	var jp := 0
	var src: Variant = rec.get("skills", {})
	if src is Dictionary:
		for k in src:
			for n in range(1, int((src as Dictionary)[k]) + 1):
				jp += jp_cost(String(k), n, class_id)
	rec["skills"] = {}
	rec["toggles"] = {}
	rec["slots"] = []
	rec["jp"] = int(rec.get("jp", 0)) + jp
	return jp


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


## Почему нельзя изучить следующий уровень умения id героем профессии class_id уровня lvl ("" — можно).
static func learn_block(rec: Dictionary, class_id: String, lvl: int, id: String) -> String:
	if ClassData.is_wanderer(class_id):
		return WANDERER_NOTE
	var sk := get_skill(id, class_id)
	if sk.is_empty() or not has_skill(class_id, id):
		return "Профессии умение недоступно"
	var n := skill_level(rec, id) + 1
	if n > max_level(id, class_id):
		return "Изучено полностью"
	var need := level_needed(id, n, class_id)
	if lvl < need:
		return "Нужен ур. %d" % need
	if sk.has("pre"):
		var pre: Array = sk["pre"]
		var pl := int(pre[1])
		if skill_level(rec, String(pre[0])) < pl:
			return "Нужно «%s» ур. %d" % [String(get_skill(String(pre[0]), class_id)["name"]), pl]
	var cost := jp_cost(id, n, class_id)
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
	rec["jp"] = int(rec["jp"]) - jp_cost(id, n, class_id)
	return true


## Изучить всё, что можно (по кругу, пока изучается; для админ-панели). Возвращает число изученных уровней.
static func learn_all(rec: Dictionary, class_id: String, lvl: int) -> int:
	var count := 0
	var again := true
	while again:
		again = false
		for id in list_for(class_id):
			if learn(rec, class_id, lvl, String(id)):
				count += 1
				again = true
	return count


## Выключить переключаемые умения, которым не подходит оружие weapon_kind (и щит). Возвращает их id.
static func drop_unfit_toggles(rec: Dictionary, weapon_kind: String, shield: bool = false) -> Array:
	var off: Array = []
	var tg: Variant = rec.get("toggles", {})
	if not (tg is Dictionary):
		return off
	var d: Dictionary = tg
	for k in d.keys():
		if not weapon_ok(String(k), weapon_kind, shield):
			d.erase(k)
			off.append(String(k))
	return off


## Начислить JP долями (amount может быть дробным). Возвращает, сколько целых JP прибавилось.
static func add_jp(rec: Dictionary, amount: float) -> int:
	var part := float(rec.get("jp_part", 0.0)) + maxf(amount, 0.0)
	var whole := int(floor(part + 0.0001))
	rec["jp_part"] = maxf(0.0, part - float(whole))
	rec["jp"] = int(rec.get("jp", 0)) + whole
	return whole


## Сумма бонусов героя от пассивных и включённых переключаемых умений при оружии weapon_kind (и щите):
## {ключ BONUS_NAMES: число} (только то, что есть). Ауры только для питомца (aura "pet") герою не идут.
static func bonuses(rec: Dictionary, class_id: String, weapon_kind: String, shield: bool = false) -> Dictionary:
	return _sum_bonuses(rec, class_id, weapon_kind, shield, false)


## Бонусы питомцу от аур героя (aura "both" и "pet") — для этапа 2 (PetManager / Pet).
static func pet_aura_bonuses(rec: Dictionary, class_id: String, weapon_kind: String, shield: bool = false) -> Dictionary:
	return _sum_bonuses(rec, class_id, weapon_kind, shield, true)


static func _sum_bonuses(rec: Dictionary, class_id: String, weapon_kind: String, shield: bool, for_pet: bool) -> Dictionary:
	var res: Dictionary = {}
	for id in list_for(class_id):
		var sid := String(id)
		var sk := get_skill(sid, class_id)
		if not sk.has("bonus"):
			continue
		var aura := String(sk.get("aura", ""))
		if for_pet and aura == "":
			continue
		if not for_pet and aura == "pet":
			continue
		var n := skill_level(rec, sid)
		if n <= 0 or not weapon_ok(sid, weapon_kind, shield, class_id):
			continue
		if String(sk["kind"]) == "toggle" and not toggle_on(rec, sid):
			continue
		var b: Dictionary = sk["bonus"]
		for key in b:
			res[key] = float(res.get(key, 0.0)) + value_at(b[key], n)
	return res


## Сколько JP стоит всё древо профессии (без стартовых уровней) — для проверки темпа.
static func total_cost(class_id: String) -> int:
	var t := 0
	for id in list_for(class_id):
		for n in range(1, max_level(String(id), class_id) + 1):
			t += jp_cost(String(id), n, class_id)
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
	var sg := "+" if v >= 0.0 else "−"
	match key:
		"eva", "crit", "atk_pct", "hp_pct", "speed_pct", "aspd", "basic_pct", "def_pct", "matk_pct", "mp_pct", "block", "cast":
			return "%s %s%s" % [String(BONUS_NAMES[key]), sg, _pct(absf(v))]
		"atk_flat", "def_flat", "mdef_flat", "hp_flat", "str", "vit", "agi", "int", "wis", "dex", "luck":
			return "%s %s%s" % [String(BONUS_NAMES[key]), sg, _num(absf(v))]
		"sparks":
			return "можно копить до %s искр духа (искра — за каждые %d попавших обычных атак)" % [_num(v), SPARK_HITS]
		"edge":
			return "обычные атаки добавляют урон стихией: %s маг. атаки" % _pct(v)
		"edge_stun", "edge_poison", "edge_mp", "poison":
			return "%s %s" % [String(BONUS_NAMES[key]), _pct(v)]
		"thorns":
			return "кто бьёт вблизи, получает огнём %s маг. атаки" % _pct(v)
		"regen":
			return "восстановление HP +%s/с" % _num(v)
		"guard":
			return "получаемый урон −%s" % _pct(v)
		"cdr":
			return "перезарядка умений −%s" % _pct(v)
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
	return "%s %s" % [String(BONUS_NAMES.get(key, key)), _num(v)]


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
	var parts: PackedStringArray = []
	var k := String(sk.get("kind", ""))
	if not is_ready(id):
		return "действие умения появится в следующем обновлении (изучить можно уже сейчас)"
	if k == "passive" or k == "toggle":
		var b: Dictionary = sk.get("bonus", {})
		for key in b:
			parts.append(bonus_text(String(key), field_bonus(id, String(key), n)))
		if k == "toggle":
			parts.append("включение %d MP, %d MP / 10 с" % [mp_cost(id, n), upkeep(id, n)])
		return ", ".join(parts)
	if sk.has("fx"):
		parts.append(fx_text(id, n))
	else:
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


## Эффекты движка (поле fx) уровня n одной строкой.
static func fx_text(id: String, n: int) -> String:
	var sk := get_skill(id)
	var parts: PackedStringArray = []
	# Воин: искры духа (JobFxWarrior)
	if sk.has("spark_cost"):
		parts.append("тратит %s искру духа" % _num(value_at(sk["spark_cost"], n)))
	if sk.has("spark_spend"):
		parts.append("тратит до %s искр духа (нужна хотя бы одна)" % _num(value_at(sk["spark_spend"], n)))
	for e in sk.get("fx", []):
		var d: Dictionary = e
		match String(d.get("do", "")):
			"damage":
				var power := "маг. атаки" if String(d.get("power", "atk")) == "matk" else "атаки"
				var t := "%s %s" % [_pct(value_at(d.get("mult", 1.0), n)), power]
				var fl := value_at(d.get("flat", 0.0), n)
				if fl > 0.0:
					t += " + %s" % _num(fl)
				var hits := int(value_at(d.get("hits", 1), n))
				t = ("урон %d × (%s)" % [hits, t]) if hits > 1 else "урон " + t
				if d.has("area"):
					t += " всем зверям в %s м" % _num(value_at(d["area"], n))
				if bool(d.get("crit", false)):
					t += ", всегда крит"
				if d.has("leech"):
					t += ", лечит на %s урона" % _pct(value_at(d["leech"], n))
				parts.append(t)
			"heal", "hot":
				var who: String = {"self": "героя", "pet": "питомца", "ally": "героя или питомца (кому хуже)"}.get(
					String(d.get("who", "self")), "героя")
				var t := "лечит %s на %s макс. HP" % [who, _pct(value_at(d.get("pct", 0.0), n))]
				if d.has("mult"):
					t += " + %s маг. атаки" % _pct(value_at(d["mult"], n))
				if String(d["do"]) == "hot":
					t += " за %s с" % _num(value_at(d.get("time", 10.0), n))
				parts.append(t)
			"status":
				var st := String(d.get("status", ""))
				var t := String(STATUS_NAMES.get(st, st))
				if d.has("value"):
					t += " на %s" % _pct(value_at(d["value"], n))
				t += " %s с" % _num(value_at(d.get("time", 0.0), n))
				if d.has("chance"):
					t = "шанс %s: %s" % [_pct(value_at(d["chance"], n)), t]
				parts.append(t)
			"dot":
				parts.append("ещё %s с по %s %s в секунду" % [_num(value_at(d.get("time", 10.0), n)),
					_pct(value_at(d.get("mult", 0.0), n)), "маг. атаки" if String(d.get("power", "atk")) == "matk" else "атаки"])
			"knock":
				parts.append("отбрасывает на %s м" % _num(value_at(d.get("dist", 3.0), n)))
			"buff":
				var bp: PackedStringArray = []
				var bf: Dictionary = d.get("bonus", {})
				for key in bf:
					bp.append(bonus_text(String(key), value_at(bf[key], n)))
				parts.append("%s с: %s" % [_num(value_at(d.get("time", 10.0), n)), ", ".join(bp)])
			"special":
				parts.append(String(sk.get("desc", "")))
	return ", ".join(parts)


static func field_bonus(id: String, key: String, n: int) -> float:
	var b: Dictionary = get_skill(id).get("bonus", {})
	return value_at(b.get(key, []), n)


static func field_buff(id: String, key: String, n: int) -> float:
	var b: Dictionary = get_skill(id).get("buff", {})
	return value_at(b.get(key, []), n)


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

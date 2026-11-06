class_name PetData
extends RefCounted
## Виды питомцев: роль, стадии эволюции, характеристики, умения ролей.
## id вида совпадает с id зверя (MobData.TYPES). Названия стадий свои.
## Полная система характеристик (7 статов, производные, MP) — PetStats, изучаемые умения и JP — PetSkills.

const MAX_LEVEL := 130
## Доля опыта убитого зверя, которую получает призванный питомец.
const XP_SHARE := 0.6
## Эволюция — вручную у Учителя Кирка (решение Максима, как в оригинале): во 2-ю форму с 50 ур., в 3-ю — со 100.
## Позже — сверх-эволюция: +SUPER_PER_LEVEL ко всем статам за каждый уровень сверх порога, до SUPER_MAX
## (на 60 и 115 ур. — полная). Стадия — поле записи "stage", уровни эволюций — "evo" [ур. 1-й, ур. 2-й].
## (В формуле сервера оригинала уровень эволюции статы не меняет: стат = база формы + прирост формы × уровень.)
const EVOLVE_LEVELS := [50, 100]
## Уровни, с которых возможна стадия 0 / 1 / 2 (для перебора стадий).
const STAGE_LEVELS := [1, 50, 100]
const SUPER_LEVELS := [60, 115]
const SUPER_PER_LEVEL := 0.01
const SUPER_MAX := [0.1, 0.15]
## Опыт до следующего уровня существа 1…130 (SummonLevelResource оригинала: разница normal_exp).
const XP_TABLE := [12, 26, 57, 128, 256, 432, 708, 1066, 1380, 2203, 3125, 4378, 5812, 7448, 9240, 11468, 14132, 16800,
	24833, 29427, 33972, 39140, 44800, 51208, 58100, 65284, 73383, 82051, 110864, 123060, 135854, 149248, 164190, 179629,
	196560, 213331, 231650, 251596, 329472, 355680, 383796, 411908, 442247, 474912, 507300, 542082, 579360, 616327, 797328,
	848966, 900211, 955199, 1013277, 1071346, 1133000, 1197912, 1262816, 1331517, 1707861, 1799200, 1893294, 1989085,
	2090592, 2193868, 2300076, 2408640, 2522704, 2642431, 3375520, 3530261, 3688265, 3853710, 4018310, 4195576, 4372039,
	4556390, 4744320, 4935827, 6297689, 6551288, 6815525, 7078716, 7352721, 7638796, 7922768, 8219033, 8527927, 8834605,
	11263898, 11668438, 12089297, 12517248, 12953501, 13405584, 13856237, 14333154, 14807382, 15300806, 19509292, 20145506,
	20803280, 21474062, 22165640, 22858500, 23572456, 24310989, 25049349, 25811145, 32933405, 33934912, 34954267, 35988186,
	37053494, 38137344, 39236272, 40352131, 41500752, 42666826, 54220865, 55466422, 56717405, 57973524, 59261486, 60554408,
	61854135, 63183715, 64517760, 65855966]
## Стадии: множитель размера модели, доля сдвига цвета к цвету эволюции.
## Скачок характеристик на эволюции — база следующей формы (PetStats.FORMS).
const STAGES := [
	{"scale": 1.0, "tint": 0.0},
	{"scale": 1.2, "tint": 0.45},
	{"scale": 1.4, "tint": 0.85},
]

const ROLES := {
	"tank": {"name": "Танк", "desc": "Принимает удары и отвлекает зверей от хозяина."},
	"fighter": {"name": "Боец", "desc": "Сильные удары вблизи и рывок к цели."},
	"mage": {"name": "Маг", "desc": "Бьёт издалека снарядами и по площади."},
	"healer": {"name": "Лекарь", "desc": "Лечит хозяина, слабо атакует издалека."},
}

## Умения ролей. cd: перезарядка, с. power: множитель атаки (у лекаря: доля HP хозяина).
const SKILLS := {
	"tank": {"name": "Вызов", "cd": 5.0, "duration": 4.0, "radius": 12.0},
	"fighter": {"name": "Рывок", "cd": 7.0, "power": 2.2, "min_dist": 3.0, "max_dist": 10.0},
	"mage": {"name": "Теневая вспышка", "cd": 9.0, "power": 1.6, "radius": 3.5},
	"healer": {"name": "Целебная роса", "cd": 8.0, "power": 0.3, "threshold": 0.6},
}

## stages: названия трёх стадий. hp/atk/def: Макс. HP, главная атака роли и физ. защита на 1 уровне —
## по ним калибруются формулы PetStats (рост по уровню и стадии — из статов). Числа подобраны под зверей мира
## (MobStats, HP ×MOB_HP_MULT): питомец своего уровня почти на равных со зверем своего уровня (зверь чуть
## сильнее), герой с питомцем побеждают уверенно; у роли свой облик — боец бьёт часто, маг сильно и издалека,
## танк крепок, лекарь крепок и лечит (после HP зверей ×3 HP и атака всех видов ×1.5–1.7; расчёт —
## tools/rappelz_pet_reference.md).
## range: дальность атаки, м. cd: перезарядка атаки, с. scale: размер модели на 1 стадии.
## evo_color: к этому цвету сдвигается окраска на старших стадиях (у модели из файла — мягкий
## оттенок текстуры, см. asset_tint). fx_color: цвет снарядов и вспышек мага/лекаря (необязательно).
const SPECIES := {
	"boar": {
		"role": "fighter", "stages": ["Щетинка", "Клыкач", "Буревепрь"],
		"hp": 135, "atk": 19, "def": 2,
		"speed": 6.6, "range": 1.9, "cd": 1.0, "scale": 0.75, "evo_color": Color(0.85, 0.35, 0.2),
	},
	"wolf": {
		"role": "fighter", "stages": ["Серохвост", "Лунный клык", "Вожак бури"],
		"hp": 120, "atk": 20, "def": 1,
		"speed": 7.5, "range": 1.9, "cd": 0.9, "scale": 0.8, "evo_color": Color(0.75, 0.82, 1.0),
	},
	# Кентавр — «Редкий» боец-копейщик (Kentauros вики — физический урон): бьёт дальше других бойцов.
	# На 1-й стадии питомец ростом с героя (scale 0.75 от 2.25 м дикого), к 3-й — заметно выше
	"centaur": {
		"role": "fighter", "stages": ["Резвое копыто", "Степной копейщик", "Громовой табунщик"],
		"hp": 160, "atk": 22, "def": 2,
		"speed": 7.2, "range": 2.6, "cd": 1.1, "scale": 0.75, "evo_color": Color(0.9, 0.62, 0.3),
	},
	"panther": {
		"role": "mage", "stages": ["Сумрачный котёнок", "Теневая пантера", "Владычица полуночи"],
		"hp": 201, "atk": 36, "def": 1,
		"speed": 7.0, "range": 9.0, "cd": 1.5, "scale": 0.8, "evo_color": Color(0.55, 0.35, 0.95),
		"fx_color": Color(0.6, 0.32, 1.0),
	},
	"pheasant": {
		"role": "healer", "stages": ["Пёстрышко", "Рассветный фазан", "Златохвост"],
		"hp": 260, "atk": 19, "def": 1,
		"speed": 6.0, "range": 8.0, "cd": 1.4, "scale": 0.85, "evo_color": Color(1.0, 0.78, 0.35),
		"fx_color": Color(1.0, 0.85, 0.45),
	},
	"turtle": {
		"role": "tank", "stages": ["Галечник", "Мшистый панцирь", "Древний бастион"],
		"hp": 339, "atk": 16, "def": 6,
		"speed": 5.5, "range": 2.0, "cd": 1.3, "scale": 0.85, "evo_color": Color(0.3, 0.7, 0.65),
	},
	# Питомцы подземелья (этап 3, 0.37): «Обычные», как волк. Скелет — боец с мечом (weapons по стадии — модели
	# assets/handheld/mw_*), Спрут — маг поддержки: вампиризм хозяину, страх, яд, поле с лечением
	"skeleton": {
		"role": "fighter", "stages": ["Костяной мечник", "Расколотый страж", "Латник Мрака"],
		"hp": 125, "atk": 21, "def": 2,
		"speed": 7.0, "range": 2.0, "cd": 1.0, "scale": 0.85, "evo_color": Color(0.35, 0.95, 0.55),
		"weapons": ["mw_rusty_dagger", "mw_shortsword", "mw_straight_sword"],
	},
	"octopus": {
		"role": "mage", "stages": ["Спрутёнок глубин", "Изумрудный спрут", "Владыка пучины"],
		"hp": 175, "atk": 31, "def": 1,
		"speed": 6.2, "range": 8.0, "cd": 1.5, "scale": 0.8, "evo_color": Color(0.25, 0.9, 0.6),
		"fx_color": Color(0.3, 1.0, 0.6),
	},
	"golem": {
		"role": "tank", "stages": ["Камушек", "Валунный страж", "Древний колосс"],
		"hp": 442, "atk": 26, "def": 8,
		"speed": 6.0, "range": 2.4, "cd": 1.3, "scale": 0.75, "evo_color": Color(0.55, 0.75, 0.95),
	},
}


static func get_species(id: String) -> Dictionary:
	return SPECIES.get(id, SPECIES["boar"])


## Оружие в руке модели питомца стадии stage (у скелета; у остальных "").
static func weapon_of(id: String, stage: int) -> String:
	var w: Array = get_species(id).get("weapons", [])
	return String(w[clampi(stage, 0, w.size() - 1)]) if not w.is_empty() else ""


## Роль вида: "tank" | "fighter" | "mage" | "healer".
static func role(id: String) -> String:
	return String(get_species(id)["role"])


static func role_name(id: String) -> String:
	return String(ROLES[role(id)]["name"])


## Умение роли вида (словарь из SKILLS).
static func skill(id: String) -> Dictionary:
	return SKILLS[role(id)]


## Стадия эволюции записи питомца (0, 1, 2).
static func stage_of(rec: Dictionary) -> int:
	return clampi(int(rec.get("stage", 0)), 0, STAGES.size() - 1)


## Название стадии вида (оно же имя питомца).
static func stage_name(id: String, stage: int) -> String:
	var names: Array = get_species(id)["stages"]
	return String(names[clampi(stage, 0, names.size() - 1)])


static func stage_color(id: String, stage: int) -> Color:
	var base: Color = MobData.get_type(id)["color"]
	var evo: Color = get_species(id)["evo_color"]
	var st: Dictionary = STAGES[clampi(stage, 0, STAGES.size() - 1)]
	return base.lerp(evo, float(st["tint"]))


## Оттенок текстуры модели из файла на стадии: белый на 1-й стадии, на старших мягко сдвигается
## к evo_color (текстура не перекрашивается целиком).
static func asset_tint(id: String, stage: int) -> Color:
	var evo: Color = get_species(id)["evo_color"]
	var st: Dictionary = STAGES[clampi(stage, 0, STAGES.size() - 1)]
	return Color.WHITE.lerp(evo, float(st["tint"]) * 0.4)


## Цвет снарядов и вспышек питомца (маг, лекарь); fallback — если у вида свой не задан.
static func fx_color(id: String, fallback: Color) -> Color:
	return get_species(id).get("fx_color", fallback)


static func stage_scale(id: String, stage: int) -> float:
	var st: Dictionary = STAGES[clampi(stage, 0, STAGES.size() - 1)]
	return float(get_species(id)["scale"]) * float(st["scale"])


## Характеристики питомца: max_hp, max_mp, atk (главная атака роли), def (int), speed, range, cd (float)
## и остальные из PetStats.derived (7 статов, маг. атака, точность, крит…). skills / toggles — из записи питомца.
static func stats_for(id: String, lvl: int, skills: Dictionary = {}, toggles: Dictionary = {}, stage: int = 0) -> Dictionary:
	return PetStats.derived(id, lvl, skills, toggles, {}, stage)


## Характеристики питомца по записи rec (вид, уровень, стадия, сверх-эволюция, умения).
static func stats_of(rec: Dictionary) -> Dictionary:
	var r := PetStats.derived(String(rec.get("species", "boar")), int(rec.get("level", 1)), rec.get("skills", {}),
		rec.get("toggles", {}), {}, stage_of(rec), super_bonus(rec))
	PetGear.apply(rec, r)
	return r


## Опыт до следующего уровня питомца (таблица оригинала XP_TABLE).
static func xp_to_next(lvl: int) -> int:
	return int(XP_TABLE[clampi(lvl, 1, XP_TABLE.size()) - 1])


## Можно ли эволюционировать запись rec: "" — да, иначе причина.
static func evolve_block(rec: Dictionary) -> String:
	var st := stage_of(rec)
	if st >= EVOLVE_LEVELS.size():
		return "Это последняя форма"
	var need := int(EVOLVE_LEVELS[st])
	if int(rec.get("level", 1)) < need:
		return "Эволюция — с %d ур. (сверх-эволюция — на %d ур.)" % [need, int(SUPER_LEVELS[st])]
	if bool(rec.get("dead", false)):
		return "Сначала воскресите питомца"
	return ""


## Прибавка сверх-эволюции к статам записи rec (доля): за каждую эволюцию — SUPER_PER_LEVEL за уровень сверх
## порога, до SUPER_MAX.
static func super_bonus(rec: Dictionary) -> float:
	var evo: Array = rec.get("evo", [])
	var b := 0.0
	for i in mini(evo.size(), EVOLVE_LEVELS.size()):
		b += minf(float(SUPER_MAX[i]), SUPER_PER_LEVEL * float(maxi(0, int(evo[i]) - int(EVOLVE_LEVELS[i]))))
	return b


## Эволюционировать запись rec (без проверок — их делает evolve_block): стадия +1, уровень эволюции в "evo",
## имя — по новой стадии (если было имя стадии).
static func evolve_record(rec: Dictionary) -> void:
	var sp := String(rec.get("species", ""))
	var old_name := String(rec.get("name", ""))
	var st := stage_of(rec)
	var evo: Array = rec.get("evo", [])
	evo.append(int(rec.get("level", 1)))
	rec["evo"] = evo
	rec["stage"] = st + 1
	if old_name == "" or old_name == stage_name(sp, st):
		rec["name"] = stage_name(sp, st + 1)

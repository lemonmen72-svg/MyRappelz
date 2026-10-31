class_name PetData
extends RefCounted
## Виды питомцев: роль, стадии эволюции, характеристики, умения ролей.
## id вида совпадает с id зверя (MobData.TYPES). Названия стадий свои.
## Полная система характеристик (7 статов, производные, MP) — PetStats, изучаемые умения и JP — PetSkills.

const MAX_LEVEL := 50
## Доля опыта убитого зверя, которую получает призванный питомец.
const XP_SHARE := 0.6
## Уровни, с которых начинаются стадии эволюции.
const STAGE_LEVELS := [1, 15, 30]
## Стадии: множитель размера модели, доля сдвига цвета к цвету эволюции.
## Скачок характеристик на эволюции дают таблицы статов (PetStats.TABLES).
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
## (MobStats): питомец своего уровня побеждает зверя своего уровня; у роли свой облик — боец бьёт часто,
## маг сильно и издалека, танк крепок, лекарь крепок и лечит (прежние числа ×1.45 у бойцов, ×2.3 у мага,
## ×1.9 у танков, у лекаря HP ×3.6 и атака ×3; расчёт — tools/rappelz_pet_reference.md).
## range: дальность атаки, м. cd: перезарядка атаки, с. scale: размер модели на 1 стадии.
## evo_color: к этому цвету сдвигается окраска на старших стадиях (у модели из файла — мягкий
## оттенок текстуры, см. asset_tint). fx_color: цвет снарядов и вспышек мага/лекаря (необязательно).
const SPECIES := {
	"boar": {
		"role": "fighter", "stages": ["Щетинка", "Клыкач", "Буревепрь"],
		"hp": 87, "atk": 12, "def": 2,
		"speed": 6.6, "range": 1.9, "cd": 1.0, "scale": 0.75, "evo_color": Color(0.85, 0.35, 0.2),
	},
	"wolf": {
		"role": "fighter", "stages": ["Серохвост", "Лунный клык", "Вожак бури"],
		"hp": 80, "atk": 13, "def": 1,
		"speed": 7.5, "range": 1.9, "cd": 0.9, "scale": 0.8, "evo_color": Color(0.75, 0.82, 1.0),
	},
	# Кентавр — «Редкий» боец-копейщик (Kentauros вики — физический урон): бьёт дальше других бойцов.
	# На 1-й стадии питомец ростом с героя (scale 0.75 от 2.25 м дикого), к 3-й — заметно выше
	"centaur": {
		"role": "fighter", "stages": ["Резвое копыто", "Степной копейщик", "Громовой табунщик"],
		"hp": 101, "atk": 14, "def": 2,
		"speed": 7.2, "range": 2.6, "cd": 1.1, "scale": 0.75, "evo_color": Color(0.9, 0.62, 0.3),
	},
	"panther": {
		"role": "mage", "stages": ["Сумрачный котёнок", "Теневая пантера", "Владычица полуночи"],
		"hp": 119, "atk": 21, "def": 1,
		"speed": 7.0, "range": 9.0, "cd": 1.5, "scale": 0.8, "evo_color": Color(0.55, 0.35, 0.95),
		"fx_color": Color(0.6, 0.32, 1.0),
	},
	"pheasant": {
		"role": "healer", "stages": ["Пёстрышко", "Рассветный фазан", "Златохвост"],
		"hp": 160, "atk": 12, "def": 1,
		"speed": 6.0, "range": 8.0, "cd": 1.4, "scale": 0.85, "evo_color": Color(1.0, 0.78, 0.35),
		"fx_color": Color(1.0, 0.85, 0.45),
	},
	"turtle": {
		"role": "tank", "stages": ["Галечник", "Мшистый панцирь", "Древний бастион"],
		"hp": 219, "atk": 10, "def": 6,
		"speed": 5.5, "range": 2.0, "cd": 1.3, "scale": 0.85, "evo_color": Color(0.3, 0.7, 0.65),
	},
	"golem": {
		"role": "tank", "stages": ["Камушек", "Валунный страж", "Древний колосс"],
		"hp": 285, "atk": 17, "def": 8,
		"speed": 6.0, "range": 2.4, "cd": 1.3, "scale": 0.75, "evo_color": Color(0.55, 0.75, 0.95),
	},
}


static func get_species(id: String) -> Dictionary:
	return SPECIES.get(id, SPECIES["boar"])


## Роль вида: "tank" | "fighter" | "mage" | "healer".
static func role(id: String) -> String:
	return String(get_species(id)["role"])


static func role_name(id: String) -> String:
	return String(ROLES[role(id)]["name"])


## Умение роли вида (словарь из SKILLS).
static func skill(id: String) -> Dictionary:
	return SKILLS[role(id)]


## Номер стадии эволюции (0, 1, 2) для уровня.
static func stage_for(lvl: int) -> int:
	var s := 0
	for i in STAGE_LEVELS.size():
		if lvl >= int(STAGE_LEVELS[i]):
			s = i
	return s


## Название стадии вида на этом уровне (оно же имя питомца).
static func stage_name(id: String, lvl: int) -> String:
	var names: Array = get_species(id)["stages"]
	return String(names[stage_for(lvl)])


static func stage_color(id: String, lvl: int) -> Color:
	var base: Color = MobData.get_type(id)["color"]
	var evo: Color = get_species(id)["evo_color"]
	var st: Dictionary = STAGES[stage_for(lvl)]
	return base.lerp(evo, float(st["tint"]))


## Оттенок текстуры модели из файла на стадии: белый на 1-й стадии, на старших мягко сдвигается
## к evo_color (текстура не перекрашивается целиком).
static func asset_tint(id: String, lvl: int) -> Color:
	var evo: Color = get_species(id)["evo_color"]
	var st: Dictionary = STAGES[stage_for(lvl)]
	return Color.WHITE.lerp(evo, float(st["tint"]) * 0.4)


## Цвет снарядов и вспышек питомца (маг, лекарь); fallback — если у вида свой не задан.
static func fx_color(id: String, fallback: Color) -> Color:
	return get_species(id).get("fx_color", fallback)


static func stage_scale(id: String, lvl: int) -> float:
	var st: Dictionary = STAGES[stage_for(lvl)]
	return float(get_species(id)["scale"]) * float(st["scale"])


## Характеристики питомца: max_hp, max_mp, atk (главная атака роли), def (int), speed, range, cd (float)
## и остальные из PetStats.derived (7 статов, маг. атака, точность, крит…). skills / toggles — из записи питомца.
static func stats_for(id: String, lvl: int, skills: Dictionary = {}, toggles: Dictionary = {}) -> Dictionary:
	return PetStats.derived(id, lvl, skills, toggles)


## Опыт до следующего уровня питомца.
static func xp_to_next(lvl: int) -> int:
	var l := float(lvl)
	return int(20.0 + 10.0 * l + 1.5 * l * l)

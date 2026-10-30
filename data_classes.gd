class_name ClassData
extends RefCounted
## Расы, классы и умения персонажа. Берём только архетипы жанра, названия и описания свои.

## Внешний вид (CharacterModel): skin — кожа, hair — волосы, eyes — радужка, hair_style — причёска
## ("short" | "long" | "ponytail"), ears — заострённые уши.
const RACES := {
	"human": {
		"name": "Люди",
		"desc": "Сильные и выносливые. Топоры, луки и магия природы.",
		"skin": Color(0.95, 0.8, 0.65), "hair": Color(0.4, 0.25, 0.12), "ears": false,
		"eyes": Color(0.3, 0.52, 0.86), "hair_style": "short",
		"classes": ["warrior", "ranger"],
	},
	"light_elf": {
		"name": "Светлые эльфы",
		"desc": "Целители и защитники. Щит, меч и магия света.",
		"skin": Color(1.0, 0.93, 0.86), "hair": Color(0.96, 0.9, 0.7), "ears": true,
		"eyes": Color(0.2, 0.72, 0.58), "hair_style": "long",
		"classes": ["guardian", "cleric"],
	},
	"dark_elf": {
		"name": "Тёмные эльфы",
		"desc": "Быстрые и точные. Клинок странника и разрушительная магия тьмы.",
		"skin": Color(0.62, 0.56, 0.78), "hair": Color(0.9, 0.86, 0.98), "ears": true,
		"eyes": Color(0.92, 0.3, 0.45), "hair_style": "ponytail",
		"classes": ["assassin", "warlock"],
	},
}

## attack: "melee" | "ranged" | "magic". range: дальность атаки, м. cd: перезарядка атаки, с.
## hp/atk/def: на 1 уровне, *_lvl: прибавка за уровень. crit: шанс крита 0..1.
## Внешний вид: color — основной цвет одежды, accent — акцент (плащ, пояс, щит, свечение), weapon — оружие.
const CLASSES := {
	"warrior": {
		"name": "Воин", "race": "human", "weapon": "axe",
		"desc": "Ближний бой, много здоровья, удары по площади.",
		"attack": "melee", "range": 2.8, "cd": 0.8,
		"hp": 120, "hp_lvl": 24, "atk": 13, "atk_lvl": 3.0, "def": 4, "def_lvl": 1.0,
		"speed": 6.5, "crit": 0.05, "color": Color(0.7, 0.3, 0.2), "accent": Color(0.92, 0.72, 0.3),
		"skills": ["cleave", "war_cry"],
	},
	"ranger": {
		"name": "Следопыт", "race": "human", "weapon": "bow",
		"desc": "Стрельба из лука издалека.",
		"attack": "ranged", "range": 12.0, "cd": 0.9,
		"hp": 90, "hp_lvl": 16, "atk": 11, "atk_lvl": 3.0, "def": 2, "def_lvl": 0.6,
		"speed": 6.8, "crit": 0.1, "color": Color(0.3, 0.55, 0.25), "accent": Color(0.85, 0.7, 0.42),
		"skills": ["power_shot", "quick_step"],
	},
	"guardian": {
		"name": "Страж", "race": "light_elf", "weapon": "sword_shield",
		"desc": "Щит и меч: высокая защита, оглушение.",
		"attack": "melee", "range": 2.8, "cd": 0.9,
		"hp": 140, "hp_lvl": 28, "atk": 10, "atk_lvl": 2.0, "def": 7, "def_lvl": 1.5,
		"speed": 6.2, "crit": 0.03, "color": Color(0.85, 0.85, 0.95), "accent": Color(0.3, 0.45, 0.82),
		"skills": ["shield_bash", "holy_guard"],
	},
	"cleric": {
		"name": "Жрец", "race": "light_elf", "weapon": "staff",
		"desc": "Магия света: лечит себя и питомца.",
		"attack": "magic", "range": 10.0, "cd": 1.0,
		"hp": 85, "hp_lvl": 15, "atk": 10, "atk_lvl": 3.0, "def": 2, "def_lvl": 0.6,
		"speed": 6.3, "crit": 0.05, "color": Color(1.0, 0.9, 0.5), "accent": Color(0.95, 0.78, 0.35),
		"skills": ["holy_bolt", "heal"],
	},
	"assassin": {
		"name": "Бродяга", "race": "dark_elf", "weapon": "sword",
		"desc": "Странствующая мечница: быстрые удары клинком, частые криты.",
		"attack": "melee", "range": 2.4, "cd": 0.55,
		"hp": 95, "hp_lvl": 17, "atk": 9, "atk_lvl": 2.5, "def": 2, "def_lvl": 0.7,
		"speed": 7.2, "crit": 0.2, "color": Color(0.35, 0.2, 0.45), "accent": Color(0.82, 0.16, 0.26),
		"skills": ["backstab", "shadow_step"],
	},
	"warlock": {
		"name": "Чернокнижник", "race": "dark_elf", "weapon": "staff",
		"desc": "Магия тьмы: большой урон издалека.",
		"attack": "magic", "range": 11.0, "cd": 1.1,
		"hp": 80, "hp_lvl": 14, "atk": 15, "atk_lvl": 4.0, "def": 1, "def_lvl": 0.5,
		"speed": 6.3, "crit": 0.07, "color": Color(0.5, 0.15, 0.6), "accent": Color(0.78, 0.45, 1.0),
		"skills": ["dark_burst", "drain"],
	},
}

## Умения классов. Эффекты реализует player.gd.
## cd: перезарядка, с. mult: множитель атаки для урона. radius: радиус, м. time: длительность, с.
## value: сила эффекта (доля). target: "enemy" — нужна цель рядом, "self" — без цели.
const SKILLS := {
	"cleave": {"name": "Рассечение", "cd": 6.0, "target": "enemy", "mult": 1.4, "radius": 3.5,
		"desc": "Круговой удар топором: урон всем врагам в 3.5 м."},
	"war_cry": {"name": "Боевой клич", "cd": 20.0, "target": "self", "value": 0.3, "time": 10.0,
		"desc": "+30% атаки на 10 с."},
	"power_shot": {"name": "Меткий выстрел", "cd": 7.0, "target": "enemy", "mult": 2.0,
		"desc": "Тяжёлая стрела с двойным уроном."},
	"quick_step": {"name": "Быстрый шаг", "cd": 15.0, "target": "self", "value": 0.4, "time": 5.0,
		"desc": "+40% скорости бега на 5 с."},
	"shield_bash": {"name": "Удар щитом", "cd": 8.0, "target": "enemy", "mult": 1.2, "time": 2.0,
		"desc": "Урон и оглушение врага на 2 с."},
	"holy_guard": {"name": "Щит света", "cd": 20.0, "target": "self", "value": 0.5, "time": 8.0,
		"desc": "Получаемый урон −50% на 8 с."},
	"holy_bolt": {"name": "Луч света", "cd": 6.0, "target": "enemy", "mult": 2.2,
		"desc": "Сгусток света с уроном ×2.2."},
	"heal": {"name": "Исцеление", "cd": 10.0, "target": "self", "value": 0.35,
		"desc": "Лечит вас и питомца на 35% здоровья."},
	"backstab": {"name": "Удар в спину", "cd": 7.0, "target": "enemy", "mult": 1.3,
		"desc": "Удар клинком с гарантированным критом."},
	"shadow_step": {"name": "Шаг тени", "cd": 12.0, "target": "enemy", "radius": 12.0,
		"desc": "Мгновенный рывок к цели до 12 м."},
	"dark_burst": {"name": "Взрыв тьмы", "cd": 8.0, "target": "enemy", "mult": 1.5, "radius": 3.5,
		"desc": "Сфера тьмы: урон всем врагам в 3.5 м вокруг цели."},
	"drain": {"name": "Похищение жизни", "cd": 10.0, "target": "enemy", "mult": 1.3, "value": 0.5,
		"desc": "Урон и лечение на половину нанесённого урона."},
}

## Названия типов атаки для интерфейса.
const ATTACK_NAMES := {"melee": "ближний бой", "ranged": "лук", "magic": "магия"}


static func race(id: String) -> Dictionary:
	return RACES.get(id, RACES["human"])


static func cls(id: String) -> Dictionary:
	return CLASSES.get(id, CLASSES["warrior"])


## Умение по id (пустой словарь, если такого нет).
static func skill(id: String) -> Dictionary:
	return SKILLS.get(id, {})


static func attack_name(kind: String) -> String:
	return String(ATTACK_NAMES.get(kind, kind))


## Характеристики класса на уровне: max_hp, atk, def, speed, range, cd, crit, attack.
static func stats_for(class_id: String, level: int) -> Dictionary:
	var c := cls(class_id)
	var l := level - 1
	return {
		"max_hp": int(c["hp"] + c["hp_lvl"] * l),
		"atk": int(c["atk"] + c["atk_lvl"] * l),
		"def": int(c["def"] + c["def_lvl"] * l),
		"speed": float(c["speed"]),
		"range": float(c["range"]),
		"cd": float(c["cd"]),
		"crit": float(c["crit"]),
		"attack": String(c["attack"]),
	}

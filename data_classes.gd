class_name ClassData
extends RefCounted
## Расы, классы и умения персонажа. Берём только архетипы жанра, названия и описания свои.

const RACES := {
	"human": {
		"name": "Люди",
		"desc": "Сильные и выносливые. Топоры, луки и магия природы.",
		"skin": Color(0.95, 0.8, 0.65),
		"classes": ["warrior", "ranger"],
	},
	"light_elf": {
		"name": "Светлые эльфы",
		"desc": "Целители и защитники. Щит, меч и магия света.",
		"skin": Color(1.0, 0.93, 0.86),
		"classes": ["guardian", "cleric"],
	},
	"dark_elf": {
		"name": "Тёмные эльфы",
		"desc": "Быстрые и точные. Кинжалы и разрушительная магия тьмы.",
		"skin": Color(0.62, 0.56, 0.78),
		"classes": ["assassin", "warlock"],
	},
}

## attack: "melee" | "ranged" | "magic". range: дальность атаки, м. cd: перезарядка атаки, с.
## hp/atk/def: на 1 уровне, *_lvl: прибавка за уровень. crit: шанс крита 0..1.
const CLASSES := {
	"warrior": {
		"name": "Воин", "race": "human", "desc": "Ближний бой, много здоровья, удары по площади.",
		"attack": "melee", "range": 2.8, "cd": 0.8,
		"hp": 120, "hp_lvl": 24, "atk": 13, "atk_lvl": 3.0, "def": 4, "def_lvl": 1.0,
		"speed": 6.5, "crit": 0.05, "color": Color(0.7, 0.3, 0.2),
		"skills": ["cleave", "war_cry"],
	},
	"ranger": {
		"name": "Следопыт", "race": "human", "desc": "Стрельба из лука издалека.",
		"attack": "ranged", "range": 12.0, "cd": 0.9,
		"hp": 90, "hp_lvl": 16, "atk": 11, "atk_lvl": 3.0, "def": 2, "def_lvl": 0.6,
		"speed": 6.8, "crit": 0.1, "color": Color(0.3, 0.55, 0.25),
		"skills": ["power_shot", "quick_step"],
	},
	"guardian": {
		"name": "Страж", "race": "light_elf", "desc": "Щит и меч: высокая защита, оглушение.",
		"attack": "melee", "range": 2.8, "cd": 0.9,
		"hp": 140, "hp_lvl": 28, "atk": 10, "atk_lvl": 2.0, "def": 7, "def_lvl": 1.5,
		"speed": 6.2, "crit": 0.03, "color": Color(0.85, 0.85, 0.95),
		"skills": ["shield_bash", "holy_guard"],
	},
	"cleric": {
		"name": "Жрец", "race": "light_elf", "desc": "Магия света: лечит себя и питомца.",
		"attack": "magic", "range": 10.0, "cd": 1.0,
		"hp": 85, "hp_lvl": 15, "atk": 10, "atk_lvl": 3.0, "def": 2, "def_lvl": 0.6,
		"speed": 6.3, "crit": 0.05, "color": Color(1.0, 0.9, 0.5),
		"skills": ["holy_bolt", "heal"],
	},
	"assassin": {
		"name": "Убийца", "race": "dark_elf", "desc": "Быстрые удары кинжалами, частые криты.",
		"attack": "melee", "range": 2.4, "cd": 0.55,
		"hp": 95, "hp_lvl": 17, "atk": 9, "atk_lvl": 2.5, "def": 2, "def_lvl": 0.7,
		"speed": 7.2, "crit": 0.2, "color": Color(0.35, 0.2, 0.45),
		"skills": ["backstab", "shadow_step"],
	},
	"warlock": {
		"name": "Чернокнижник", "race": "dark_elf", "desc": "Магия тьмы: большой урон издалека.",
		"attack": "magic", "range": 11.0, "cd": 1.1,
		"hp": 80, "hp_lvl": 14, "atk": 15, "atk_lvl": 4.0, "def": 1, "def_lvl": 0.5,
		"speed": 6.3, "crit": 0.07, "color": Color(0.5, 0.15, 0.6),
		"skills": ["dark_burst", "drain"],
	},
}

## Умения классов. cd: перезарядка, с. Эффекты реализует player.gd.
const SKILLS := {
	"cleave": {"name": "Рассечение", "cd": 6.0, "desc": "Урон всем врагам вокруг."},
	"war_cry": {"name": "Боевой клич", "cd": 20.0, "desc": "+30% атаки на 10 с."},
	"power_shot": {"name": "Меткий выстрел", "cd": 7.0, "desc": "Выстрел с двойным уроном."},
	"quick_step": {"name": "Быстрый шаг", "cd": 15.0, "desc": "+40% скорости на 5 с."},
	"shield_bash": {"name": "Удар щитом", "cd": 8.0, "desc": "Урон и оглушение на 2 с."},
	"holy_guard": {"name": "Щит света", "cd": 20.0, "desc": "Получаемый урон −50% на 8 с."},
	"holy_bolt": {"name": "Луч света", "cd": 6.0, "desc": "Сильный удар светом."},
	"heal": {"name": "Исцеление", "cd": 10.0, "desc": "Лечит вас и питомца на 35%."},
	"backstab": {"name": "Удар в спину", "cd": 7.0, "desc": "Удар с гарантированным критом."},
	"shadow_step": {"name": "Шаг тени", "cd": 12.0, "desc": "Мгновенный рывок к цели."},
	"dark_burst": {"name": "Взрыв тьмы", "cd": 8.0, "desc": "Урон вокруг цели."},
	"drain": {"name": "Похищение жизни", "cd": 10.0, "desc": "Урон и лечение на половину урона."},
}


static func race(id: String) -> Dictionary:
	return RACES.get(id, RACES["human"])


static func cls(id: String) -> Dictionary:
	return CLASSES.get(id, CLASSES["warrior"])


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

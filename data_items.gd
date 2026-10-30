class_name ItemData
extends RefCounted
## Предметы. type: "crystal" (приручение), "consumable" (расходник), "trophy" (на продажу), "weapon" (оружие).
## buy: цена у торговца (0 = не продаётся), sell: цена продажи торговцу.
## Оружие (type "weapon"): weapon — вид ("daggers" парные кинжалы, "dual_swords" парные мечи, "crossbow" арбалет),
## atk — прибавка к атаке, cd — время между обычными атаками, с, range — дальность, м, crit — прибавка к шансу крита,
## class — кому подходит (id класса ClassData). Надетое оружие — Game.weapon (id предмета, лежит в сумке).

const ITEMS := {
	"crystal_common": {
		"name": "Кристалл души", "type": "crystal", "tier": 1, "buy": 25, "sell": 8,
		"color": Color(0.6, 0.8, 1.0), "desc": "Приручение базовых зверей.",
	},
	"crystal_rare": {
		"name": "Редкий кристалл души", "type": "crystal", "tier": 2, "buy": 0, "sell": 30,
		"color": Color(0.4, 0.5, 1.0), "desc": "Приручение базовых и редких зверей.",
	},
	"crystal_unique": {
		"name": "Древний кристалл души", "type": "crystal", "tier": 3, "buy": 0, "sell": 100,
		"color": Color(1.0, 0.8, 0.2), "desc": "Приручение любых зверей, даже стражей.",
	},
	"hp_potion": {
		"name": "Зелье здоровья", "type": "consumable", "buy": 10, "sell": 3,
		"color": Color(0.9, 0.2, 0.25), "desc": "Восстанавливает 50% здоровья.",
	},
	"revive_scroll": {
		"name": "Свиток воскрешения", "type": "consumable", "buy": 30, "sell": 10,
		"color": Color(0.95, 0.9, 0.6), "desc": "Воскрешает погибшего питомца.",
	},
	# ---------- Оружие Бродяги: стартовый набор (выдаётся новому и прежнему Бродяге) ----------
	"daggers_starter": {
		"name": "Парные кинжалы", "type": "weapon", "weapon": "daggers", "class": "assassin",
		"atk": 1, "cd": 0.45, "range": 2.2, "crit": 0.05, "buy": 0, "sell": 5,
		"color": Color(0.78, 0.75, 0.9), "desc": "Короткие клинки: самые частые удары и больше критов.",
	},
	"dual_swords_starter": {
		"name": "Парные мечи", "type": "weapon", "weapon": "dual_swords", "class": "assassin",
		"atk": 3, "cd": 0.55, "range": 2.4, "crit": 0.0, "buy": 0, "sell": 5,
		"color": Color(0.85, 0.88, 0.96), "desc": "Два лёгких меча: удары справа и слева по очереди.",
	},
	"crossbow_starter": {
		"name": "Лёгкий арбалет", "type": "weapon", "weapon": "crossbow", "class": "assassin",
		"atk": 6, "cd": 1.0, "range": 11.0, "crit": 0.0, "buy": 0, "sell": 5,
		"color": Color(0.72, 0.52, 0.32), "desc": "Стреляет болтами издалека, но реже.",
	},
	# ---------- Оружие у торговца ----------
	"daggers_steel": {
		"name": "Стальные кинжалы", "type": "weapon", "weapon": "daggers", "class": "assassin",
		"atk": 4, "cd": 0.45, "range": 2.2, "crit": 0.06, "buy": 120, "sell": 40,
		"color": Color(0.7, 0.8, 1.0), "desc": "Закалённые кинжалы странницы.",
	},
	"dual_swords_steel": {
		"name": "Стальные парные мечи", "type": "weapon", "weapon": "dual_swords", "class": "assassin",
		"atk": 7, "cd": 0.55, "range": 2.4, "crit": 0.0, "buy": 120, "sell": 40,
		"color": Color(0.75, 0.9, 1.0), "desc": "Пара закалённых мечей.",
	},
	"crossbow_heavy": {
		"name": "Тяжёлый арбалет", "type": "weapon", "weapon": "crossbow", "class": "assassin",
		"atk": 11, "cd": 1.05, "range": 12.0, "crit": 0.02, "buy": 140, "sell": 45,
		"color": Color(0.85, 0.6, 0.35), "desc": "Мощные болты, бьёт чуть дальше.",
	},
	"boar_tusk": {"name": "Клык кабана", "type": "trophy", "buy": 0, "sell": 4, "color": Color(0.95, 0.9, 0.8), "desc": "Трофей."},
	"wolf_pelt": {"name": "Волчья шкура", "type": "trophy", "buy": 0, "sell": 7, "color": Color(0.6, 0.6, 0.65), "desc": "Трофей."},
	"panther_fang": {"name": "Клык пантеры", "type": "trophy", "buy": 0, "sell": 12, "color": Color(0.9, 0.86, 0.95), "desc": "Трофей."},
	"pheasant_feather": {"name": "Перо фазана", "type": "trophy", "buy": 0, "sell": 15, "color": Color(0.85, 0.5, 0.2), "desc": "Трофей."},
	"shell_plate": {"name": "Пластина панциря", "type": "trophy", "buy": 0, "sell": 18, "color": Color(0.45, 0.6, 0.35), "desc": "Трофей."},
	"golem_shard": {"name": "Осколок стража", "type": "trophy", "buy": 0, "sell": 40, "color": Color(0.55, 0.55, 0.5), "desc": "Трофей."},
}


## Виды оружия: название и кому подходят умения («клинки» — кинжалы и мечи).
const WEAPON_KINDS := {
	"daggers": {"name": "парные кинжалы", "group": "blades"},
	"dual_swords": {"name": "парные мечи", "group": "blades"},
	"crossbow": {"name": "арбалет", "group": "crossbow"},
}
## Стартовый набор оружия класса и что надето сразу (старые сохранения Бродяги — парные мечи).
const STARTER_WEAPONS := {
	"assassin": ["dual_swords_starter", "daggers_starter", "crossbow_starter"],
}

## Прежние id предметов → новые (старые сохранения переводит Game.from_dict).
const RENAMED := {"bear_claw": "panther_fang", "fairy_dust": "pheasant_feather", "spark_core": "shell_plate"}


static func get_item(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func item_name(id: String) -> String:
	return String(get_item(id).get("name", id))


## Новый id предмета по прежнему (из старого сохранения); остальные — как есть.
static func migrate_id(id: String) -> String:
	return String(RENAMED.get(id, id))


static func is_weapon(id: String) -> bool:
	return String(get_item(id).get("type", "")) == "weapon"


## Вид оружия предмета ("daggers" | "dual_swords" | "crossbow" | "").
static func weapon_kind(id: String) -> String:
	return String(get_item(id).get("weapon", ""))


## Название вида оружия по-русски ("парные мечи").
static func weapon_kind_name(kind: String) -> String:
	return String(WEAPON_KINDS.get(kind, {}).get("name", kind))


## Группа вида оружия для умений: "blades" (кинжалы, мечи), "crossbow" или "".
static func weapon_group(kind: String) -> String:
	return String(WEAPON_KINDS.get(kind, {}).get("group", ""))


## Подходит ли оружие классу.
static func weapon_fits(id: String, class_id: String) -> bool:
	return is_weapon(id) and String(get_item(id).get("class", "")) == class_id


## Пользуется ли класс сменным оружием (есть стартовый набор).
static func class_uses_weapons(class_id: String) -> bool:
	return STARTER_WEAPONS.has(class_id)


## Оружие по умолчанию у класса (первое из стартового набора) или "".
static func default_weapon(class_id: String) -> String:
	var a: Array = STARTER_WEAPONS.get(class_id, [])
	return String(a[0]) if not a.is_empty() else ""


## Характеристики оружия одной строкой: «атака +3, удар раз в 0.55 с, 2.4 м».
static func weapon_stats_text(id: String) -> String:
	var it := get_item(id)
	if it.is_empty():
		return ""
	var t := "атака +%d, удар раз в %.2f с, дальность %.1f м" % [int(it.get("atk", 0)), float(it.get("cd", 1.0)),
		float(it.get("range", 2.0))]
	if float(it.get("crit", 0.0)) > 0.0:
		t += ", крит +%d%%" % roundi(float(it["crit"]) * 100.0)
	return t

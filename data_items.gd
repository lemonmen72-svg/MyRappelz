class_name ItemData
extends RefCounted
## Предметы. type: "crystal" (приручение), "consumable" (расходник), "trophy" (на продажу).
## buy: цена у торговца (0 = не продаётся), sell: цена продажи торговцу.

const ITEMS := {
	"crystal_common": {
		"name": "Кристалл души", "type": "crystal", "tier": 1, "buy": 25, "sell": 8,
		"color": Color(0.6, 0.8, 1.0), "desc": "Приручение обычных зверей.",
	},
	"crystal_rare": {
		"name": "Редкий кристалл души", "type": "crystal", "tier": 2, "buy": 0, "sell": 30,
		"color": Color(0.4, 0.5, 1.0), "desc": "Приручение обычных и редких зверей.",
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
	"boar_tusk": {"name": "Клык кабана", "type": "trophy", "buy": 0, "sell": 4, "color": Color(0.95, 0.9, 0.8), "desc": "Трофей."},
	"wolf_pelt": {"name": "Волчья шкура", "type": "trophy", "buy": 0, "sell": 7, "color": Color(0.6, 0.6, 0.65), "desc": "Трофей."},
	"bear_claw": {"name": "Медвежий коготь", "type": "trophy", "buy": 0, "sell": 12, "color": Color(0.35, 0.25, 0.2), "desc": "Трофей."},
	"fairy_dust": {"name": "Пыльца феи", "type": "trophy", "buy": 0, "sell": 15, "color": Color(0.6, 1.0, 0.7), "desc": "Трофей."},
	"spark_core": {"name": "Искровое ядро", "type": "trophy", "buy": 0, "sell": 18, "color": Color(1.0, 0.6, 0.2), "desc": "Трофей."},
	"golem_shard": {"name": "Осколок стража", "type": "trophy", "buy": 0, "sell": 40, "color": Color(0.55, 0.55, 0.5), "desc": "Трофей."},
}


static func get_item(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func item_name(id: String) -> String:
	return String(get_item(id).get("name", id))

class_name MobData
extends RefCounted
## Звери мира: характеристики, редкость (для приручения), добыча.
## Где и какого уровня они появляются — mob_zones в world/training_island.json.
## id зверя совпадает с id вида питомца (PetData).

## Радиус безопасной зоны города новичков в центре мира (там торговец, звери туда не заходят).
## Источник правды — safe_zones в world/training_island.json; здесь — для кода без острова.
const SAFE_RADIUS := 22.0

## Какой кристалл души нужен: ItemData "tier" кристалла >= tier редкости зверя.
const RARITY_TIER := {"common": 1, "rare": 2, "unique": 3}

## loot: [id предмета, шанс 0..1, мин., макс.]. gold: [мин., макс.].
const TYPES := {
	"boar": {
		"name": "Кабан", "level": 1, "hp": 30, "atk": 5, "speed": 3.0, "xp": 12, "gold": [2, 5],
		"color": Color(0.55, 0.35, 0.2), "scale": 0.9, "rarity": "common",
		"loot": [["boar_tusk", 0.6, 1, 1], ["hp_potion", 0.08, 1, 1], ["crystal_common", 0.05, 1, 1]],
	},
	"wolf": {
		"name": "Волк", "level": 3, "hp": 50, "atk": 9, "speed": 4.4, "xp": 25, "gold": [4, 9],
		"color": Color(0.5, 0.5, 0.55), "scale": 1.0, "rarity": "common",
		"loot": [["wolf_pelt", 0.55, 1, 1], ["hp_potion", 0.1, 1, 1], ["crystal_common", 0.06, 1, 1]],
	},
	"bear": {
		"name": "Медведь", "level": 6, "hp": 130, "atk": 16, "speed": 3.0, "xp": 70, "gold": [10, 20],
		"color": Color(0.3, 0.2, 0.15), "scale": 1.5, "rarity": "common",
		"loot": [["bear_claw", 0.5, 1, 2], ["hp_potion", 0.15, 1, 1], ["revive_scroll", 0.05, 1, 1],
			["crystal_rare", 0.03, 1, 1]],
	},
	"fairy": {
		"name": "Лесная фея", "level": 4, "hp": 45, "atk": 7, "speed": 3.6, "xp": 35, "gold": [6, 12],
		"color": Color(0.55, 0.95, 0.6), "scale": 0.7, "rarity": "rare",
		"loot": [["fairy_dust", 0.6, 1, 2], ["hp_potion", 0.15, 1, 1], ["crystal_rare", 0.05, 1, 1]],
	},
	"sparkbug": {
		"name": "Искрожук", "level": 7, "hp": 90, "atk": 18, "speed": 3.4, "xp": 80, "gold": [12, 24],
		"color": Color(1.0, 0.55, 0.15), "scale": 1.0, "rarity": "rare",
		"loot": [["spark_core", 0.5, 1, 1], ["revive_scroll", 0.08, 1, 1], ["crystal_rare", 0.06, 1, 1]],
	},
	"golem": {
		"name": "Каменный страж", "level": 10, "hp": 400, "atk": 24, "speed": 2.6, "xp": 250, "gold": [60, 120],
		"color": Color(0.5, 0.5, 0.45), "scale": 2.0, "rarity": "unique",
		"loot": [["golem_shard", 1.0, 1, 3], ["crystal_rare", 0.3, 1, 1], ["crystal_unique", 0.15, 1, 1]],
	},
}


static func get_type(id: String) -> Dictionary:
	return TYPES.get(id, TYPES["boar"])


static func rarity_tier(id: String) -> int:
	return int(RARITY_TIER.get(get_type(id)["rarity"], 1))

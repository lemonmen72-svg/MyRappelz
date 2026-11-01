class_name LootTable
extends RefCounted
## Добыча со зверей и случайные награды заданий (правила Максима).
##
## Добыча зверя: золото — всегда (MobData.gold_range: немного, ± цена материала зверя) и ровно N предметов:
## обычный зверь — 2, минибосс (MobData.is_mini_boss: «Редкие» — вожак анатем, змеекрыл, кентавр) — 3, босс — 4;
## в подземелье (dungeon, будет позже) — на один больше. Каждый предмет — отдельный бросок: сначала категория,
## потом предмет внутри неё. Категория выбирается среди доступных этому зверю пропорционально «шансам» из правил
## (CATEGORIES chance — вес выбора): зелья 75, карта существа — шанс приручения тира карты (Taming.CHANCE: базовая
## 70, обычная 45, редкая 35, уникальная 25), оружие 25, материал зверя 25, особый материал — 10 (только боссы).
## Пример: волк (приручаемый, синяя карта 45) — зелье 75 / 170 ≈ 44 %, карта 45 / 170 ≈ 26 %, оружие и материал
## по 25 / 170 ≈ 15 %; анатема (не приручается, карт нет) — зелье 60 %, оружие 20 %, материал 20 %; босс-пантера —
## зелье 75, карта 25, оружие 25, материал 25, особый 10 → 47 / 16 / 16 / 16 / 6 %. Повтор категории возможен (два
## зелья с одного зверя).
## Внутри категории: зелье — вид по весам POTION_WEIGHTS (и свиток воскрешения), ранг — по уровню зверя
## (ItemData.potion_rank_for_level: 1–10 ур. — 1-й, 11–20 — 2-й…); оружие — любое обычное оружие ранга по уровню
## зверя (ItemData.equip_rank_for_level: 1–20 ур. — 1-й, 21–50 — 2-й; нет оружия такого ранга — старший из
## имеющихся ниже); карта — карта вида (приручаемые; у боссов — карта их вида) и зеркальная (MobData.drops_mirror),
## материал — MobData.materials, особый — MobData.special_materials.
## Место под будущее снаряжение (этапы 2–3): категории armor (броня, как оружие, 25), jewelry (украшения, 15, только
## боссы), cube (кубы: обычный зверь 10, минибосс 25, босс 35) уже в таблице — пока их предметов нет (пул пуст),
## категория не выбирается.
##
## Награды заданий (quest_reward): 1–2 случайных предмета сверх наград из данных; шансы вдвое ниже, чем в добыче
## (зелье 37.5 %, оружие 12.5 % — подходящее профессии, карта существа — половина шанса приручения карты
## случайного приручаемого вида острова), ранг — по уровню героя. Каждая категория бросается отдельно; выпало
## больше двух — остаются два случайных, не выпало ничего — один предмет категории, выбранной по тем же шансам.

## Категории: name — для игрока, chance — вес выбора (шанс из правил); "card" — по тиру карты (Taming.CHANCE);
## boss_only — только у боссов; у cube шанс по типу зверя.
const CATEGORIES := {
	"potion": {"name": "Зелья", "chance": 0.75},
	"card": {"name": "Карты существ", "chance": -1.0},
	"weapon": {"name": "Оружие", "chance": 0.25},
	"material": {"name": "Материалы", "chance": 0.25},
	"special": {"name": "Особые материалы", "chance": 0.10, "boss_only": true},
	"armor": {"name": "Броня", "chance": 0.25},
	"jewelry": {"name": "Украшения", "chance": 0.15, "boss_only": true},
	"cube": {"name": "Кубы", "chance": {"normal": 0.10, "mini": 0.25, "boss": 0.35}},
}
## Сколько предметов по типу зверя; в подземелье — +DUNGEON_BONUS.
const COUNT := {"normal": 2, "mini": 3, "boss": 4}
const DUNGEON_BONUS := 1
## Вид зелья в категории «зелья» (вес): здоровье чаще всего; revive — свиток воскрешения питомца.
const POTION_WEIGHTS := {"hp": 40.0, "mp": 25.0, "aspd": 8.0, "cast": 8.0, "speed": 8.0, "revive": 6.0}
## Внутри карт: карта вида — 3, зеркальная — 1.
const CARD_WEIGHT := 3.0
const MIRROR_WEIGHT := 1.0
## Награды заданий: случайных предметов от и до, доля шанса добычи.
const QUEST_MIN := 1
const QUEST_MAX := 2
const QUEST_CHANCE_MULT := 0.5
const QUEST_CATEGORIES := ["potion", "weapon", "card"]


## Тип зверя для добычи: "boss" | "mini" | "normal".
static func mob_class(type_id: String) -> String:
	if MobData.is_boss(type_id):
		return "boss"
	if MobData.is_mini_boss(type_id):
		return "mini"
	return "normal"


## Сколько предметов выпадает со зверя (без золота).
static func item_count(type_id: String, dungeon: bool = false) -> int:
	return int(COUNT[mob_class(type_id)]) + (DUNGEON_BONUS if dungeon else 0)


## Шанс (вес) категории cat у зверя type_id; 0 — категории у него нет.
static func category_chance(cat: String, type_id: String) -> float:
	var c: Dictionary = CATEGORIES.get(cat, {})
	if c.is_empty():
		return 0.0
	if bool(c.get("boss_only", false)) and not MobData.is_boss(type_id):
		return 0.0
	var ch: Variant = c["chance"]
	if ch is Dictionary:
		return float((ch as Dictionary).get(mob_class(type_id), 0.0))
	if cat == "card":
		return float(Taming.CHANCE.get(MobData.card_tier(type_id), 0.5))
	return float(ch)


## Категории добычи зверя уровня lvl с непустым пулом: {категория: вес}.
static func categories_for(type_id: String, lvl: int) -> Dictionary:
	var res: Dictionary = {}
	for k in CATEGORIES:
		var cat := String(k)
		var w := category_chance(cat, type_id)
		if w > 0.0 and not pool(cat, type_id, lvl).is_empty():
			res[cat] = w
	return res


## Предметы категории cat у зверя type_id уровня lvl: [[id, вес], …] ([] — категории у зверя нет).
static func pool(cat: String, type_id: String, lvl: int) -> Array:
	var res: Array = []
	match cat:
		"potion":
			var r := ItemData.potion_rank_for_level(lvl)
			for k in POTION_WEIGHTS:
				var kind := String(k)
				var id := "revive_scroll" if kind == "revive" else ItemData.potion_id(kind, r)
				if not ItemData.get_item(id).is_empty():
					res.append([id, float(POTION_WEIGHTS[k])])
		"card":
			var sp := MobData.species_of(type_id)
			var card := ItemData.card_for(sp)
			if card != "" and MobData.tameable(sp) and (MobData.tameable(type_id) or MobData.is_boss(type_id)):
				res.append([card, CARD_WEIGHT])
			if MobData.drops_mirror(type_id):
				res.append([ItemData.MIRROR_CARD, MIRROR_WEIGHT])
		"weapon":
			for id in weapons_of_rank(ItemData.equip_rank_for_level(lvl)):
				res.append([String(id), 1.0])
		"material":
			for id in MobData.materials(type_id):
				res.append([String(id), 1.0])
		"special":
			for id in MobData.special_materials(type_id):
				res.append([String(id), 1.0])
		_:
			# armor, jewelry, cube — предметов пока нет
			pass
	return res


## Обычное (не улучшенное) оружие ранга rank_n; нет такого — ближайшего младшего ранга, где оно есть.
static func weapons_of_rank(rank_n: int) -> Array:
	if _weapons_cache.has(rank_n):
		return _weapons_cache[rank_n]
	var r := rank_n
	var res: Array = []
	while r >= 1 and res.is_empty():
		for k in ItemData.ITEMS:
			var id := String(k)
			if ItemData.is_weapon(id) and ItemData.rank(id) == r and ItemData.rarity(id) == "common":
				res.append(id)
		r -= 1
	_weapons_cache[rank_n] = res
	return res


## Оружие по рангам (предметы не меняются во время игры).
static var _weapons_cache: Dictionary = {}


## Бросок добычи зверя type_id уровня lvl: {id: количество} — ровно item_count предметов (золото — gold).
## rng — свой генератор (тесты); null — общий randf.
static func roll(type_id: String, lvl: int, dungeon: bool = false, rng: RandomNumberGenerator = null) -> Dictionary:
	var res: Dictionary = {}
	var cats := categories_for(type_id, lvl)
	if cats.is_empty():
		return res
	for i in item_count(type_id, dungeon):
		var cat := String(pick(_pairs(cats), rng))
		var list := pool(cat, type_id, lvl)
		var id := String(pick(list, rng))
		if id != "":
			res[id] = int(res.get(id, 0)) + 1
	return res


## Золото за зверя: случайное в MobData.gold_range.
static func gold(type_id: String, lvl: int, rng: RandomNumberGenerator = null) -> int:
	var g: Array = MobData.gold_range(type_id, lvl)
	var lo := int(g[0])
	var hi := maxi(lo, int(g[1]))
	return rng.randi_range(lo, hi) if rng != null else randi_range(lo, hi)


## Категория предмета добычи (для статистики и тестов): potion, card, weapon, material, special, "" — иное.
static func category_of(id: String, type_id: String = "") -> String:
	if ItemData.is_potion(id) or id == "revive_scroll":
		return "potion"
	if ItemData.is_card(id):
		return "card"
	if ItemData.is_weapon(id):
		return "weapon"
	if type_id != "" and MobData.special_materials(type_id).has(id):
		return "special"
	if ItemData.item_type(id) == "trophy":
		return "material"
	return ""


## Случайная награда задания герою уровня hero_lvl профессии class_id: {id: количество}, 1–2 предмета.
static func quest_reward(hero_lvl: int, class_id: String = "", rng: RandomNumberGenerator = null) -> Dictionary:
	var chances := quest_chances(hero_lvl, class_id, rng)
	var got: Array = []
	for k in chances:
		var cat := String(k)
		if _rand(rng) < float((chances[cat] as Array)[0]):
			got.append(cat)
	if got.is_empty():
		var w: Dictionary = {}
		for k in chances:
			w[k] = float((chances[k] as Array)[0])
		got.append(String(pick(_pairs(w), rng)))
	while got.size() > QUEST_MAX:
		got.remove_at(_randi(rng, got.size()))
	var res: Dictionary = {}
	for c in got:
		var entry: Array = chances[String(c)]
		var list: Array = entry[1]
		var id := String(pick(list, rng))
		if id != "":
			res[id] = int(res.get(id, 0)) + 1
	return res


## Категории награды задания: {категория: [шанс, пул [[id, вес], …]]} — шанс вдвое ниже, чем в добыче.
static func quest_chances(hero_lvl: int, class_id: String = "", rng: RandomNumberGenerator = null) -> Dictionary:
	var res: Dictionary = {}
	var potions: Array = []
	var r := ItemData.potion_rank_for_level(hero_lvl)
	for k in POTION_WEIGHTS:
		if String(k) != "revive":
			potions.append([ItemData.potion_id(String(k), r), float(POTION_WEIGHTS[k])])
	res["potion"] = [float(CATEGORIES["potion"]["chance"]) * QUEST_CHANCE_MULT, potions]
	var weapons: Array = []
	var fit: Array = []
	for id in weapons_of_rank(ItemData.equip_rank_for_level(hero_lvl)):
		weapons.append([String(id), 1.0])
		if class_id != "" and ItemData.weapon_fits(String(id), class_id):
			fit.append([String(id), 1.0])
	if not fit.is_empty():
		weapons = fit
	if not weapons.is_empty():
		res["weapon"] = [float(CATEGORIES["weapon"]["chance"]) * QUEST_CHANCE_MULT, weapons]
	# Карта: случайный приручаемый вид острова, шанс — половина шанса приручения его карты
	var species: Array = []
	for k in MobData.TYPES:
		var sp := String(k)
		if MobData.tameable(sp) and ItemData.card_for(sp) != "" and Taming.lives_in_world(sp):
			species.append(sp)
	if not species.is_empty():
		var sp := String(species[_randi(rng, species.size())])
		var ch := float(Taming.CHANCE.get(MobData.card_tier(sp), 0.5)) * QUEST_CHANCE_MULT
		res["card"] = [ch, [[ItemData.card_for(sp), 1.0]]]
	return res


## Взвешенный выбор из [[значение, вес], …] ("" — пусто).
static func pick(list: Array, rng: RandomNumberGenerator = null) -> Variant:
	var total := 0.0
	for e in list:
		total += maxf(0.0, float((e as Array)[1]))
	if total <= 0.0:
		return ""
	var x := _rand(rng) * total
	for e in list:
		var pair: Array = e
		x -= maxf(0.0, float(pair[1]))
		if x < 0.0:
			return pair[0]
	return (list[list.size() - 1] as Array)[0]


static func _pairs(d: Dictionary) -> Array:
	var res: Array = []
	for k in d:
		res.append([k, float(d[k])])
	return res


static func _rand(rng: RandomNumberGenerator) -> float:
	return rng.randf() if rng != null else randf()


static func _randi(rng: RandomNumberGenerator, n: int) -> int:
	if n <= 1:
		return 0
	return rng.randi_range(0, n - 1) if rng != null else randi_range(0, n - 1)

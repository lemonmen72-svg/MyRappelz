class_name ItemData
extends RefCounted
## Предметы. type: "card" (карта существа — приручение), "consumable" (расходник), "trophy" (на продажу),
## "weapon" (оружие).
## buy: цена покупки у NPC (0 = не продаётся; кто чем торгует — NpcData.shop: зелья, свиток и оружие — торговец,
## карты существ и зеркальная карта — Учитель Кирк), sell: цена продажи торговцу.
## Оружие (type "weapon"): weapon — вид (WEAPON_KINDS: одноручный и двуручный меч, кинжал, парные кинжалы "daggers",
## парные мечи, булавы, топоры, посохи, арбалет, лук, щит), atk — прибавка к атаке, def — к защите (щит),
## cd — время между обычными атаками, с, range — дальность, м, crit — прибавка к шансу крита, rank — ранг
## (1 — оружие 1–10 ур.; Бродяга носит только 1-й ранг). Кому подходит — по виду: ClassData weapons профессии
## (weapon_fits). Надетое оружие — Game.weapon, щит во второй руке — Game.shield (id предметов, лежат в сумке,
## но в окне сумки показаны в слотах экипировки, а не в ячейках).
## Для окна сумки: rarity — редкость ("common" по умолчанию, "improved", "rare", "unique": цвет рамки ячейки),
## icon — что рисовать процедурным значком, пока нет картинки (ItemIcon: "flask", "scroll", "card",
## "daggers", "swords", "crossbow", "fang", "pelt", "feather", "plate", "shard"), stack — размер стопки в ячейке
## (по умолчанию 99, у оружия 1). Картинка значка: res://assets/icons/items/<id>.png (128×128, прозрачные углы).
## Карты существ (type "card", приручение — Taming): species — вид зверя (MobData), soul = true — карта с пойманной
## душой (из неё формируется питомец). Пустая карта вида — card_<вид> (стопка до CARD_STACK), заполненная —
## card_<вид>_soul (по одной в ячейке), зеркальная карта mirror_card (без вида) — ломается вместо карты существа
## при неудачном приручении. Тир и цвет карты — по виду (MobData.card_tier, CARD_TIERS).

const ITEMS := {
	# ---------- Карты существ: базовые продаёт Учитель Кирк, остальные выпадают из зверей своего вида ----------
	"card_panther": {
		"name": "Карта существа: Пантера", "type": "card", "species": "panther", "icon": "card", "stack": 20,
		"buy": 25, "sell": 8, "color": Color(0.62, 0.52, 0.78), "desc": "Чистая карта: ловит дух пантеры.",
	},
	"card_turtle": {
		"name": "Карта существа: Черепаха", "type": "card", "species": "turtle", "icon": "card", "stack": 20,
		"buy": 25, "sell": 8, "color": Color(0.5, 0.72, 0.45), "desc": "Чистая карта: ловит дух черепахи.",
	},
	"card_pheasant": {
		"name": "Карта существа: Фазан", "type": "card", "species": "pheasant", "icon": "card", "stack": 20,
		"buy": 25, "sell": 8, "color": Color(0.9, 0.58, 0.3), "desc": "Чистая карта: ловит дух фазана.",
	},
	"card_wolf": {
		"name": "Карта существа: Волк", "type": "card", "species": "wolf", "icon": "card", "stack": 20,
		"buy": 0, "sell": 12, "color": Color(0.66, 0.68, 0.74), "desc": "Чистая карта: ловит дух волка.",
	},
	"card_centaur": {
		"name": "Карта существа: Кентавр", "type": "card", "species": "centaur", "icon": "card", "stack": 20,
		"buy": 0, "sell": 20, "color": Color(0.78, 0.58, 0.38), "desc": "Чистая карта: ловит дух кентавра.",
	},
	"card_panther_soul": {
		"name": "Карта пантеры (с душой)", "type": "card", "species": "panther", "soul": true, "icon": "card",
		"stack": 1, "buy": 0, "sell": 15, "color": Color(0.62, 0.52, 0.78), "desc": "В карте спит пойманная душа пантеры.",
	},
	"card_turtle_soul": {
		"name": "Карта черепахи (с душой)", "type": "card", "species": "turtle", "soul": true, "icon": "card",
		"stack": 1, "buy": 0, "sell": 15, "color": Color(0.5, 0.72, 0.45), "desc": "В карте спит пойманная душа черепахи.",
	},
	"card_pheasant_soul": {
		"name": "Карта фазана (с душой)", "type": "card", "species": "pheasant", "soul": true, "icon": "card",
		"stack": 1, "buy": 0, "sell": 15, "color": Color(0.9, 0.58, 0.3), "desc": "В карте спит пойманная душа фазана.",
	},
	"card_wolf_soul": {
		"name": "Карта волка (с душой)", "type": "card", "species": "wolf", "soul": true, "icon": "card",
		"stack": 1, "buy": 0, "sell": 18, "color": Color(0.66, 0.68, 0.74), "desc": "В карте спит пойманная душа волка.",
	},
	"card_centaur_soul": {
		"name": "Карта кентавра (с душой)", "type": "card", "species": "centaur", "soul": true, "icon": "card",
		"stack": 1, "buy": 0, "sell": 30, "color": Color(0.78, 0.58, 0.38), "desc": "В карте спит пойманная душа кентавра.",
	},
	"mirror_card": {
		"name": "Зеркальная карта", "type": "card", "icon": "card", "stack": 20, "buy": 60, "sell": 20,
		"color": Color(0.82, 0.88, 0.98),
		"desc": "Оберег для приручения: если попытка не удалась, ломается зеркальная карта, а карта существа остаётся цела.",
	},
	"hp_potion": {
		"name": "Зелье здоровья", "type": "consumable", "icon": "flask", "buy": 10, "sell": 3,
		"color": Color(0.9, 0.2, 0.25), "desc": "Восстанавливает 50% здоровья.",
	},
	"revive_scroll": {
		"name": "Свиток воскрешения", "type": "consumable", "icon": "scroll", "buy": 30, "sell": 10,
		"color": Color(0.95, 0.9, 0.6), "desc": "Воскрешает погибшего питомца.",
	},
	# ---------- Оружие 1-го ранга (ур. 1–10): у торговца; стартовое у Бродяги и профессий (STARTER_WEAPONS) ----------
	"weapon_sword_1h_r1": {
		"name": "Учебный меч", "type": "weapon", "icon": "swords", "weapon": "sword_1h", "rank": 1,
		"atk": 3, "cd": 0.75, "range": 2.6, "crit": 0.02, "buy": 40, "sell": 8,
		"color": Color(0.85, 0.87, 0.92), "desc": "Простой одноручный меч новичка. Вторая рука свободна — для щита.",
	},
	"weapon_sword_2h_r1": {
		"name": "Двуручный меч новичка", "type": "weapon", "icon": "swords", "weapon": "sword_2h", "rank": 1,
		"atk": 6, "cd": 1.05, "range": 2.9, "crit": 0.02, "buy": 55, "sell": 12,
		"color": Color(0.8, 0.83, 0.92), "desc": "Длинный тяжёлый клинок: бьёт реже, но сильнее.",
	},
	"weapon_dagger_r1": {
		"name": "Кинжал новичка", "type": "weapon", "icon": "daggers", "weapon": "dagger", "rank": 1,
		"atk": 2, "cd": 0.55, "range": 2.2, "crit": 0.05, "buy": 35, "sell": 7,
		"color": Color(0.78, 0.75, 0.9), "desc": "Короткий клинок: частые удары и больше критов.",
	},
	"weapon_mace_1h_r1": {
		"name": "Учебная булава", "type": "weapon", "icon": "mace", "weapon": "mace_1h", "rank": 1,
		"atk": 4, "cd": 0.85, "range": 2.5, "crit": 0.0, "buy": 40, "sell": 8,
		"color": Color(0.72, 0.7, 0.66), "desc": "Окованная булава в одну руку. Хороша со щитом.",
	},
	"weapon_mace_2h_r1": {
		"name": "Тяжёлая булава новичка", "type": "weapon", "icon": "mace", "weapon": "mace_2h", "rank": 1,
		"atk": 7, "cd": 1.15, "range": 2.8, "crit": 0.0, "buy": 55, "sell": 12,
		"color": Color(0.68, 0.66, 0.62), "desc": "Двуручная булава: медленно, зато каждый удар чувствуется.",
	},
	"weapon_axe_1h_r1": {
		"name": "Учебный топор", "type": "weapon", "icon": "axe", "weapon": "axe_1h", "rank": 1,
		"atk": 4, "cd": 0.8, "range": 2.5, "crit": 0.03, "buy": 40, "sell": 8,
		"color": Color(0.8, 0.72, 0.6), "desc": "Лёгкий топор в одну руку.",
	},
	"weapon_axe_2h_r1": {
		"name": "Двуручный топор новичка", "type": "weapon", "icon": "axe", "weapon": "axe_2h", "rank": 1,
		"atk": 7, "cd": 1.1, "range": 2.9, "crit": 0.04, "buy": 55, "sell": 12,
		"color": Color(0.78, 0.68, 0.55), "desc": "Широкое лезвие на длинной рукояти: самый тяжёлый удар среди оружия новичка.",
	},
	"weapon_staff_1h_r1": {
		"name": "Жезл новичка", "type": "weapon", "icon": "staff", "weapon": "staff_1h", "rank": 1,
		"atk": 3, "cd": 1.0, "range": 9.0, "crit": 0.0, "buy": 40, "sell": 8,
		"color": Color(0.82, 0.68, 0.45), "desc": "Короткий жезл: обычная атака — сгусток магии издалека. Вторая рука свободна.",
	},
	"weapon_staff_2h_r1": {
		"name": "Посох новичка", "type": "weapon", "icon": "staff", "weapon": "staff_2h", "rank": 1,
		"atk": 5, "cd": 1.15, "range": 10.0, "crit": 0.0, "buy": 55, "sell": 12,
		"color": Color(0.8, 0.64, 0.4), "desc": "Посох в две руки: магический снаряд сильнее и летит дальше.",
	},
	"weapon_shield_r1": {
		"name": "Деревянный щит", "type": "weapon", "icon": "shield", "weapon": "shield", "rank": 1,
		"atk": 0, "def": 2, "cd": 0.0, "range": 0.0, "crit": 0.0, "buy": 35, "sell": 7,
		"color": Color(0.62, 0.45, 0.28), "desc": "Щит во вторую руку (к одноручному оружию): защита выше.",
	},
	# ---------- Оружие Наёмника: стартовый набор (выдаётся новому и прежнему Наёмнику) ----------
	"daggers_starter": {
		"name": "Парные кинжалы", "type": "weapon", "icon": "daggers", "weapon": "daggers", "rank": 1,
		"atk": 1, "cd": 0.45, "range": 2.2, "crit": 0.05, "buy": 0, "sell": 5,
		"color": Color(0.78, 0.75, 0.9), "desc": "Короткие клинки: самые частые удары и больше критов.",
	},
	"dual_swords_starter": {
		"name": "Парные мечи", "type": "weapon", "icon": "swords", "weapon": "dual_swords", "rank": 1,
		"atk": 3, "cd": 0.55, "range": 2.4, "crit": 0.0, "buy": 0, "sell": 5,
		"color": Color(0.85, 0.88, 0.96), "desc": "Два лёгких меча: удары справа и слева по очереди.",
	},
	"crossbow_starter": {
		"name": "Лёгкий арбалет", "type": "weapon", "icon": "crossbow", "weapon": "crossbow", "rank": 1,
		"atk": 6, "cd": 1.0, "range": 11.0, "crit": 0.0, "buy": 0, "sell": 5,
		"color": Color(0.72, 0.52, 0.32), "desc": "Стреляет болтами издалека, но реже.",
	},
	# ---------- Оружие у торговца ----------
	"daggers_steel": {
		"name": "Стальные кинжалы", "type": "weapon", "icon": "daggers", "rarity": "improved", "weapon": "daggers", "rank": 1,
		"atk": 4, "cd": 0.45, "range": 2.2, "crit": 0.06, "buy": 120, "sell": 40,
		"color": Color(0.7, 0.8, 1.0), "desc": "Закалённые кинжалы странницы.",
	},
	"dual_swords_steel": {
		"name": "Стальные парные мечи", "type": "weapon", "icon": "swords", "rarity": "improved", "weapon": "dual_swords", "rank": 1,
		"atk": 7, "cd": 0.55, "range": 2.4, "crit": 0.0, "buy": 120, "sell": 40,
		"color": Color(0.75, 0.9, 1.0), "desc": "Пара закалённых мечей.",
	},
	"crossbow_heavy": {
		"name": "Тяжёлый арбалет", "type": "weapon", "icon": "crossbow", "rarity": "improved", "weapon": "crossbow", "rank": 1,
		"atk": 11, "cd": 1.05, "range": 12.0, "crit": 0.02, "buy": 140, "sell": 45,
		"color": Color(0.85, 0.6, 0.35), "desc": "Мощные болты, бьёт чуть дальше.",
	},
	"boar_tusk": {"name": "Клык кабана", "type": "trophy", "icon": "fang", "buy": 0, "sell": 4, "color": Color(0.95, 0.9, 0.8), "desc": "Крепкий изогнутый клык кабана. Трофей для торговца."},
	"wolf_pelt": {"name": "Волчья шкура", "type": "trophy", "icon": "pelt", "buy": 0, "sell": 7, "color": Color(0.6, 0.6, 0.65), "desc": "Серая шкура с густым мехом. Трофей для торговца."},
	"panther_fang": {"name": "Клык пантеры", "type": "trophy", "icon": "fang", "buy": 0, "sell": 12, "color": Color(0.9, 0.86, 0.95), "desc": "Острый клык пантеры. Трофей для торговца."},
	"pheasant_feather": {"name": "Перо фазана", "type": "trophy", "icon": "feather", "buy": 0, "sell": 15, "color": Color(0.85, 0.5, 0.2), "desc": "Яркое рыжее перо. Трофей для торговца."},
	"shell_plate": {"name": "Пластина панциря", "type": "trophy", "icon": "plate", "buy": 0, "sell": 18, "color": Color(0.45, 0.6, 0.35), "desc": "Прочная пластина черепашьего панциря. Трофей для торговца."},
	"golem_shard": {"name": "Осколок стража", "type": "trophy", "icon": "shard", "rarity": "rare", "buy": 0, "sell": 40, "color": Color(0.55, 0.55, 0.5), "desc": "Обломок каменного стража, в трещинах мерцают руны. Ценный трофей."},
	"flyfish_scale": {"name": "Летучая чешуя", "type": "trophy", "icon": "scale", "buy": 0, "sell": 10, "color": Color(0.35, 0.55, 0.85), "desc": "Лёгкая синяя чешуйка летучего зубана, переливается на свету. Трофей для торговца."},
	"sail_fin": {"name": "Плавник-парус", "type": "trophy", "icon": "fin", "buy": 0, "sell": 16, "color": Color(0.95, 0.6, 0.3), "desc": "Тонкий плавник рыбы-парусника с прочными лучами. Трофей для торговца."},
	"drake_crest": {"name": "Гребень змеекрыла", "type": "trophy", "icon": "fin", "buy": 0, "sell": 30, "color": Color(0.3, 0.45, 0.8), "desc": "Колючий гребень змеекрыла, ещё хранит запах ветра. Ценный трофей."},
	# Трофеи кентавра
	"spear_tip": {"name": "Наконечник копья", "type": "trophy", "icon": "spike", "buy": 0, "sell": 26, "color": Color(0.78, 0.8, 0.86), "desc": "Стальной наконечник копья кентавра, по лезвию — степной узор. Ценный трофей."},
	"horse_hair": {"name": "Конский волос", "type": "trophy", "icon": "pelt", "buy": 0, "sell": 14, "color": Color(0.42, 0.26, 0.15), "desc": "Жёсткая прядь из хвоста кентавра, годится на тетиву. Трофей для торговца."},
	# Трофеи анатем (ящеры с костяными клинками)
	"lizard_scale": {"name": "Чешуя ящера", "type": "trophy", "icon": "scale", "buy": 0, "sell": 12, "color": Color(0.3, 0.45, 0.25), "desc": "Жёсткая тёмно-зелёная чешуя анатемы. Трофей для торговца."},
	"bone_blade": {"name": "Костяной клинок", "type": "trophy", "icon": "fang", "buy": 0, "sell": 22, "color": Color(0.92, 0.88, 0.78), "desc": "Изогнутый костяной серп с предплечья анатемы-рубаки, острый как сталь. Ценный трофей."},
	"chief_spike": {"name": "Шип вожака", "type": "trophy", "icon": "spike", "rarity": "rare", "buy": 0, "sell": 40, "color": Color(0.85, 0.8, 0.68), "desc": "Костяной шип с плеча вожака анатем, весь в зазубринах. Ценный трофей."},
}


## Виды оружия: name — название, hands — 1 (одноручное: можно щит во вторую руку), 2 (двуручное), "dual" (парное),
## "off" (щит, вторая рука); attack — обычная атака ("melee" удар, "ranged" стрела или болт, "magic" сгусток магии);
## model — что держит модель героя (CharacterModel: модель из файла умеет sword, dagger, daggers, dual_swords, crossbow,
## axe, mace, staff; щит — отдельно). Группы видов для умений — HeroSkills.WEAPON_GROUPS.
## "daggers" — парные кинжалы (dual_daggers; id прежний ради сохранений).
const WEAPON_KINDS := {
	"sword_1h": {"name": "одноручный меч", "hands": 1, "attack": "melee", "model": "sword"},
	"sword_2h": {"name": "двуручный меч", "hands": 2, "attack": "melee", "model": "sword"},
	"dagger": {"name": "кинжал", "hands": 1, "attack": "melee", "model": "dagger"},
	"daggers": {"name": "парные кинжалы", "hands": "dual", "attack": "melee", "model": "daggers"},
	"dual_swords": {"name": "парные мечи", "hands": "dual", "attack": "melee", "model": "dual_swords"},
	"mace_1h": {"name": "одноручная булава", "hands": 1, "attack": "melee", "model": "mace"},
	"mace_2h": {"name": "двуручная булава", "hands": 2, "attack": "melee", "model": "mace"},
	"axe_1h": {"name": "одноручный топор", "hands": 1, "attack": "melee", "model": "axe"},
	"axe_2h": {"name": "двуручный топор", "hands": 2, "attack": "melee", "model": "axe"},
	"dual_axes": {"name": "парные топоры", "hands": "dual", "attack": "melee", "model": "axe"},
	"staff_1h": {"name": "одноручный посох", "hands": 1, "attack": "magic", "model": "staff"},
	"staff_2h": {"name": "двуручный посох", "hands": 2, "attack": "magic", "model": "staff"},
	"crossbow": {"name": "арбалет", "hands": 2, "attack": "ranged", "model": "crossbow"},
	"bow": {"name": "лук", "hands": 2, "attack": "ranged", "model": "bow"},
	"shield": {"name": "щит", "hands": "off", "attack": "", "model": ""},
}
## Стартовый набор оружия профессии: выдаётся новому герою (Бродяга) и при смене профессии (Game.change_job);
## первое — надевается, щит из набора — во вторую руку. Старые сохранения Наёмника — парные мечи.
const STARTER_WEAPONS := {
	"wanderer": ["weapon_sword_1h_r1"],
	"swordsman": ["weapon_sword_1h_r1", "weapon_shield_r1"],
	"wizard": ["weapon_staff_2h_r1", "weapon_mace_1h_r1"],
	"beastmaster": ["weapon_staff_2h_r1", "weapon_mace_1h_r1"],
	"assassin": ["dual_swords_starter", "daggers_starter", "crossbow_starter"],
	"neophyte": ["weapon_staff_2h_r1", "weapon_dagger_r1"],
	"adept": ["weapon_staff_2h_r1", "weapon_dagger_r1"],
	"warrior": ["weapon_axe_2h_r1", "weapon_axe_1h_r1"],
	"shaman": ["weapon_staff_2h_r1", "weapon_axe_1h_r1"],
	"conjurer": ["weapon_sword_1h_r1", "weapon_axe_1h_r1"],
}

## Прежние id предметов → новые (старые сохранения переводит Game.from_dict). Кристаллы души заменены картами:
## каждый кристалл — зеркальная карта (за редкий и древний ещё LEGACY_GOLD). Карт кабана и каменного стража
## больше нет (их нельзя приручить) — если они остались в сумке, становятся зеркальными картами.
const RENAMED := {
	"bear_claw": "panther_fang", "fairy_dust": "pheasant_feather", "spark_core": "shell_plate",
	"crystal_common": "mirror_card", "crystal_rare": "mirror_card", "crystal_unique": "mirror_card",
	"card_boar": "mirror_card", "card_boar_soul": "mirror_card", "card_golem": "mirror_card", "card_golem_soul": "mirror_card",
}
## Доплата золотом за каждый прежний предмет при переводе: цена продажи прежнего кристалла (редкий — 30,
## древний — 100), зеркальная карта идёт сверху.
const LEGACY_GOLD := {"crystal_rare": 30, "crystal_unique": 100}


static func get_item(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func item_name(id: String) -> String:
	return String(get_item(id).get("name", id))


## Новый id предмета по прежнему (из старого сохранения); остальные — как есть.
static func migrate_id(id: String) -> String:
	return String(RENAMED.get(id, id))


## Доплата золотом за прежние предметы сумки {id: количество} (LEGACY_GOLD).
static func legacy_gold(src: Dictionary) -> int:
	var g := 0
	for k in src:
		g += int(LEGACY_GOLD.get(String(k), 0)) * maxi(0, int(src[k]))
	return g


static func is_weapon(id: String) -> bool:
	return String(get_item(id).get("type", "")) == "weapon"


## Вид оружия предмета (WEAPON_KINDS: "sword_1h", "daggers", "crossbow", "shield" и т. д.; "" — не оружие).
static func weapon_kind(id: String) -> String:
	return String(get_item(id).get("weapon", ""))


## Название вида оружия по-русски ("парные мечи").
static func weapon_kind_name(kind: String) -> String:
	return String(WEAPON_KINDS.get(kind, {}).get("name", kind))


## Хват вида оружия: 1, 2, "dual" или "off" (щит).
static func hands(kind: String) -> Variant:
	var d: Dictionary = WEAPON_KINDS.get(kind, {})
	return d.get("hands", 2)


## Одноручное оружие (во вторую руку можно щит).
static func is_one_handed(kind: String) -> bool:
	var h: Variant = hands(kind)
	return h is int and int(h) == 1


static func is_shield(id: String) -> bool:
	return weapon_kind(id) == "shield"


## Обычная атака оружием вида kind: "melee" | "ranged" | "magic" ("" — щит или не оружие).
static func weapon_attack(kind: String) -> String:
	var d: Dictionary = WEAPON_KINDS.get(kind, {})
	return String(d.get("attack", ""))


## Что держит модель героя для вида kind (CharacterModel).
static func model_kind(kind: String) -> String:
	var d: Dictionary = WEAPON_KINDS.get(kind, {})
	return String(d.get("model", ""))


static func rank(id: String) -> int:
	return int(get_item(id).get("rank", 1))


## Подходит ли оружие профессии: вид — среди ClassData weapons профессии, Бродяге — только 1-й ранг.
static func weapon_fits(id: String, class_id: String) -> bool:
	if not is_weapon(id):
		return false
	if ClassData.is_wanderer(class_id) and rank(id) > 1:
		return false
	return ClassData.weapons(class_id).has(weapon_kind(id))


## Пользуется ли класс сменным оружием (у всех профессий есть стартовый набор).
static func class_uses_weapons(class_id: String) -> bool:
	return STARTER_WEAPONS.has(ClassData.migrate_id(class_id))


## Стартовый набор профессии.
static func starter_weapons(class_id: String) -> Array:
	return STARTER_WEAPONS.get(ClassData.migrate_id(class_id), [])


## Оружие по умолчанию у класса (первое из стартового набора) или "".
static func default_weapon(class_id: String) -> String:
	var a := starter_weapons(class_id)
	return String(a[0]) if not a.is_empty() else ""


## Характеристики оружия одной строкой: «атака +3, удар раз в 0.55 с, 2.4 м».
static func weapon_stats_text(id: String) -> String:
	var it := get_item(id)
	if it.is_empty():
		return ""
	if is_shield(id):
		return "защита +%d (во второй руке)" % int(it.get("def", 0))
	var t := "атака +%d, удар раз в %.2f с, дальность %.1f м" % [int(it.get("atk", 0)), float(it.get("cd", 1.0)),
		float(it.get("range", 2.0))]
	if float(it.get("crit", 0.0)) > 0.0:
		t += ", крит +%d%%" % roundi(float(it["crit"]) * 100.0)
	return t


# ---------- Сумка: типы, редкость, стопки, значки ----------

## Типы предметов: название, порядок сортировки, цвет рамки (у обычных расходников и трофеев; у карт — цвет тира).
const TYPES := {
	"weapon": {"name": "Оружие", "order": 0, "color": Color(0.7, 0.72, 0.78)},
	"armor": {"name": "Доспех", "order": 1, "color": Color(0.7, 0.72, 0.78)},
	"consumable": {"name": "Расходник", "order": 2, "color": Color(0.95, 0.45, 0.5)},
	"card": {"name": "Карта существа", "order": 3, "color": Color(0.78, 0.56, 0.34)},
	"trophy": {"name": "Трофей", "order": 4, "color": Color(0.85, 0.65, 0.4)},
}
## Редкость: название, ранг (для сортировки), цвет рамки и названия.
const RARITIES := {
	"common": {"name": "Обычный", "rank": 0, "color": Color(0.7, 0.72, 0.78)},
	"improved": {"name": "Улучшенный", "rank": 1, "color": Color(0.45, 0.95, 0.45)},
	"rare": {"name": "Редкий", "rank": 2, "color": Color(0.4, 0.62, 1.0)},
	"unique": {"name": "Уникальный", "rank": 3, "color": Color(1.0, 0.8, 0.25)},
}
## Размер стопки в ячейке сумки по умолчанию (у оружия — 1).
const STACK := 99
## Тиры карт существ (как в руководстве: цвет карты по группе зверя): название, цвет, ранг (сортировка).
## Тир идёт от редкости зверя (MobData.CARD_TIER_BY_RARITY), названия — как у редкостей: базовая (коричневая) —
## «Базовые» звери, обычная (синяя) — «Обычные» (волк), редкая (фиолетовая) — «Редкие», уникальная (жёлтая) —
## «Уникальные». Ключи тиров внутренние (шансы — Taming.CHANCE по ним же).
const CARD_TIERS := {
	"basic": {"name": "базовая", "color_name": "коричневая", "rank": 0, "color": Color(0.8, 0.56, 0.32)},
	"rare": {"name": "обычная", "color_name": "синяя", "rank": 1, "color": Color(0.36, 0.58, 1.0)},
	"special": {"name": "редкая", "color_name": "фиолетовая", "rank": 2, "color": Color(0.72, 0.42, 1.0)},
	"unique": {"name": "уникальная", "color_name": "жёлтая", "rank": 3, "color": Color(1.0, 0.82, 0.25)},
}
## Зеркальная карта: id и цвет рамки (серебро).
const MIRROR_CARD := "mirror_card"
const MIRROR_COLOR := Color(0.8, 0.86, 0.96)
## Картинки значков предметов: <ICON_DIR><id>.png (нет файла — процедурный значок ItemIcon).
const ICON_DIR := "res://assets/icons/items/"


static func item_type(id: String) -> String:
	return String(get_item(id).get("type", ""))


static func type_name(id: String) -> String:
	return String(TYPES.get(item_type(id), {}).get("name", "Предмет"))


static func rarity(id: String) -> String:
	var r := String(get_item(id).get("rarity", "common"))
	return r if RARITIES.has(r) else "common"


static func rarity_name(id: String) -> String:
	return String(RARITIES[rarity(id)]["name"])


static func rarity_color(id: String) -> Color:
	return RARITIES[rarity(id)]["color"]


## Цвет рамки ячейки: у карт — цвет тира (зеркальная — серебро), иначе по редкости (у оружия и необычных
## предметов) или по типу.
static func frame_color(id: String) -> Color:
	if is_card(id):
		return MIRROR_COLOR if card_species(id) == "" else card_tier_color(card_tier(id))
	var r := rarity(id)
	if r != "common" or is_weapon(id) or not TYPES.has(item_type(id)):
		return RARITIES[r]["color"]
	return TYPES[item_type(id)]["color"]


## Сколько штук лежит в одной ячейке сумки.
static func stack_size(id: String) -> int:
	var t := item_type(id)
	if t == "weapon" or t == "armor":
		return 1
	return maxi(1, int(get_item(id).get("stack", STACK)))


## Что рисовать процедурным значком ("flask", "card", ...; "" — буква названия).
static func icon_shape(id: String) -> String:
	return String(get_item(id).get("icon", ""))


static func icon_path(id: String) -> String:
	return ICON_DIR + id + ".png"


## Порядок в сумке: тип, затем редкость (лучшие раньше; у карт — тир, заполненные раньше пустых, зеркальные
## в конце), название, id.
static func sort_before(a: String, b: String) -> bool:
	var ta := int(TYPES.get(item_type(a), {}).get("order", 9))
	var tb := int(TYPES.get(item_type(b), {}).get("order", 9))
	if ta != tb:
		return ta < tb
	var ra := _sort_rank(a)
	var rb := _sort_rank(b)
	if ra != rb:
		return ra > rb
	var na := item_name(a)
	var nb := item_name(b)
	if na != nb:
		return na < nb
	return a < b


static func _sort_rank(id: String) -> int:
	if is_card(id):
		if card_species(id) == "":
			return -1
		return int(CARD_TIERS[card_tier(id)]["rank"]) * 2 + (1 if is_soul_card(id) else 0)
	return int(RARITIES[rarity(id)]["rank"])


# ---------- Карты существ ----------

static func is_card(id: String) -> bool:
	return item_type(id) == "card"


## Вид зверя карты ("" — не карта существа или зеркальная).
static func card_species(id: String) -> String:
	return String(get_item(id).get("species", "")) if is_card(id) else ""


## Карта с пойманной душой (из неё формируется существо).
static func is_soul_card(id: String) -> bool:
	return is_card(id) and bool(get_item(id).get("soul", false))


## Пустая карта существа (ловит дух своего вида).
static func is_empty_card(id: String) -> bool:
	return card_species(id) != "" and not is_soul_card(id)


## Пустая карта вида species ("" — у вида нет карты).
static func card_for(species: String) -> String:
	var id := "card_" + species
	return id if is_empty_card(id) else ""


## Заполненная карта вида species ("" — нет).
static func soul_card_for(species: String) -> String:
	var id := "card_%s_soul" % species
	return id if is_soul_card(id) else ""


## Тир карты: "basic" | "rare" | "special" | "unique" ("" — зеркальная или не карта).
static func card_tier(id: String) -> String:
	var sp := card_species(id)
	if sp == "":
		return ""
	var t := MobData.card_tier(sp)
	return t if CARD_TIERS.has(t) else "basic"


static func card_tier_color(tier: String) -> Color:
	return CARD_TIERS.get(tier, CARD_TIERS["basic"])["color"]


## Тир словами: «коричневая (базовая)».
static func card_tier_label(tier: String) -> String:
	var t: Dictionary = CARD_TIERS.get(tier, CARD_TIERS["basic"])
	return "%s (%s)" % [String(t["color_name"]), String(t["name"])]


## Вторая строка в карточке предмета после типа: у карт — тир («Коричневая (базовая)»), у зеркальной —
## «Оберег», у остальных — редкость.
static func grade_name(id: String) -> String:
	if is_card(id):
		if card_species(id) == "":
			return "Оберег"
		var t := card_tier_label(card_tier(id))
		return t.substr(0, 1).to_upper() + t.substr(1)
	return rarity_name(id)

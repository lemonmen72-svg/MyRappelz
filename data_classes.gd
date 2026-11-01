class_name ClassData
extends RefCounted
## Расы и профессии героя. Берём только архетипы жанра (ориентир — профессии Rappelz 1-й смены,
## tools/rappelz_jobs_reference.md), названия и описания свои.
## Новый герой любой расы — Бродяга (WANDERER): без умений, обычная атака оружием новичка, JP копятся.
## С JOB_LEVEL (10) уровня — сдача задания «Доклад мудрецу» Мудрецу Альдерику (QuestData "sage_first_job", выдаёт охотница),
## в конце выбор одной из трёх профессий своей расы (RACES jobs, окно JobWindow). Сменить профессию повторно
## нельзя (пока есть только первая смена). Пройти задание можно позже: при смене профессии — «сверх-эволюция»
## (over_jp: +OVER_JP_PER_LEVEL JP за каждый уровень выше JOB_LEVEL, не выше OVER_LEVEL_CAP).
## Умения профессии — HeroSkills (Наёмник) и JobSkills (остальные 8 профессий), требуемый уровень = 10 + JLv × 0.75.

## Стартовая профессия всех рас.
const WANDERER := "wanderer"
## С какого уровня можно взять задание на первую профессию.
const JOB_LEVEL := 10
## Сверх-эволюция: JP за каждый уровень выше JOB_LEVEL при смене профессии, до этого уровня (потолок).
const OVER_JP_PER_LEVEL := 5
const OVER_LEVEL_CAP := 20
## Раса и профессия героя по умолчанию для сохранений старых версий (там герой был тёмной эльфийкой-Наёмником;
## другие классы старых сохранений переводит Game.from_dict).
const HERO_RACE := "dark_elf"
const HERO_CLASS := "assassin"
## Прежние классы → профессии новой схемы (тесты и данные прошлых версий; старые сохранения с ними
## становятся Наёмниками — Game.from_dict).
const LEGACY_CLASSES := {"ranger": "warrior", "guardian": "swordsman", "cleric": "wizard", "warlock": "neophyte"}
## Пол героя: м / ж (модель — CharacterModel.hero_asset).
const GENDERS := [["f", "Женский"], ["m", "Мужской"]]

## Внешний вид (CharacterModel): skin — кожа, hair — волосы, eyes — радужка, hair_style — причёска
## ("short" | "long" | "ponytail"), ears — заострённые уши. jobs — три профессии 1-й смены расы.
## desc, strengths (сильные стороны), weaknesses (слабые) — для экрана создания (CharacterCreate, шаг «Раса»): по
## страницам рас и профессий rappelz.fandom.com (расовые умения, Strengths/Weaknesses; источник —
## tools/rappelz_jobs_reference.md), текст свой.
const RACES := {
	"human": {
		"name": "Люди",
		"desc": "Опора острова: крепкие телом и сильные духом. Бьют реже, но тяжело, и умеют поймать миг для сокрушительного удара.",
		"strengths": ["Крепкие: у бойцов много здоровья и хорошая защита", "Расовый дар — сосредоточение: на время чаще бьют критом",
			"Стихии и созвучия усиливают и героя, и питомца; маги хорошо держат чужую магию",
			"Колдун меньше других призывателей зависит от питомца"],
		"weaknesses": ["Медленная атака, особенно с тяжёлым топором", "Почти нет постоянного лечения — лишь редкий рывок",
			"Заклинания дорого стоят по мане"],
		"skin": Color(0.95, 0.8, 0.65), "hair": Color(0.4, 0.25, 0.12), "ears": false,
		"eyes": Color(0.3, 0.52, 0.86), "hair_style": "short",
		"jobs": ["warrior", "shaman", "conjurer"],
	},
	"light_elf": {
		"name": "Светлые эльфы",
		"desc": "Хранители света: выносливые и терпеливые. Лечат себя и друзей, держат удар и берегут питомца.",
		"strengths": ["Расовые дары: малое исцеление себя и лечение со временем", "Самые крепкие защитники: держат зверей на себе",
			"Лучшие лекари и усиления для героя и питомца", "Дар света — точность: реже промахиваются"],
		"weaknesses": ["Урона меньше, чем у людей и тёмных эльфов", "У лекаря и зверолова мало атакующих умений",
			"Маны лекарю хватает ненадолго: восстанавливать её нечем"],
		"skin": Color(1.0, 0.93, 0.86), "hair": Color(0.96, 0.9, 0.7), "ears": true,
		"eyes": Color(0.2, 0.72, 0.58), "hair_style": "long",
		"jobs": ["swordsman", "wizard", "beastmaster"],
	},
	"dark_elf": {
		"name": "Тёмные эльфы",
		"desc": "Быстрые и скрытные: бьют первыми и часто, уходят от ударов и черпают силу у тьмы и крови.",
		"strengths": ["Расовый дар — глубокое уклонение: на время ловчее, сильнее и точнее",
			"Высокая скорость атаки и уклонение у клинков и арбалета", "Самый большой урон магией: огонь, молния, тьма, вытягивание жизни",
			"Питомец — сосуд силы: у него можно взять жизнь и ману"],
		"weaknesses": ["Мало здоровья и защиты: тяжёлые удары держат плохо", "Почти нет лечения",
			"Сильные умения легко злят зверей вокруг"],
		"skin": Color(0.62, 0.56, 0.78), "hair": Color(0.9, 0.86, 0.98), "ears": true,
		"eyes": Color(0.92, 0.3, 0.45), "hair_style": "ponytail",
		"jobs": ["assassin", "adept", "neophyte"],
	},
}

## Профессии. race — чья профессия ("" — Бродяга, у всех рас); role — роль одной строкой; desc — 2–3 строки
## для экрана выбора; weapon_text — каким оружием владеет; weapons — виды оружия (ItemData.WEAPON_KINDS),
## которые можно надеть (пары "daggers", "dual_swords", "dual_axes" — второе такое же во вторую руку; Бродяга — любое
## оружие, решение Максима); key_skills — 3–4 ключевых
## умения для карточки выбора; strengths / features — сильные стороны и особенности (слабости) профессии для экрана
## создания (шаг «Профессии», по Strengths/Weaknesses вики, текст свой); skills — умения на кнопках 1…4 у новой записи (стартовые, start = true).
## attack / range / cd — обычная атака без оружия (у всех героев оружие есть, атаку задаёт оно).
## hp, mp, atk, def, eva, crit — числа 1-го уровня для калибровки статов (HeroStats.calibration), рост по уровню —
## от 7 статов (HeroStats); *_lvl — прибавка за уровень без статов (ClassData.stats_for, запасной путь).
## Внешний вид: color — основной цвет одежды, accent — акцент; weapon — вид оружия модели по умолчанию.
const CLASSES := {
	"wanderer": {
		"name": "Бродяга", "race": "", "role": "новичок",
		"desc": "Путник без ремесла: бьётся простым оружием, приручает зверей и копит опыт. С 10 уровня Мудрец Альдерик поможет выбрать профессию.",
		"weapon_text": "любое оружие",
		"weapons": ["sword_1h", "dual_swords", "sword_2h", "dagger", "daggers", "mace_1h", "mace_2h", "axe_1h", "dual_axes", "axe_2h",
			"staff_1h", "staff_2h", "spear", "crossbow", "bow", "shield"],
		"key_skills": [], "skills": [],
		"attack": "melee", "range": 2.6, "cd": 0.8, "weapon": "sword",
		"hp": 100, "hp_lvl": 18, "atk": 8, "atk_lvl": 2.5, "def": 3, "def_lvl": 0.8, "mp": 25, "mp_lvl": 5,
		"eva": 0.03, "crit": 0.05, "speed": 7.0,
		"color": Color(0.45, 0.38, 0.3), "accent": Color(0.75, 0.62, 0.4),
	},
	# ---------- Светлые эльфы ----------
	"swordsman": {
		"name": "Мечник", "race": "light_elf", "role": "защитник",
		"desc": "Щит и меч: держит зверя на себе, оглушает и ослабляет его, немного лечится светом. Рядом с ним питомцу ничего не грозит.",
		"weapon_text": "двуручный меч, копьё, один или два одноручных меча, двуручная или одноручная булава, щит",
		"weapons": ["sword_2h", "spear", "sword_1h", "dual_swords", "mace_2h", "mace_1h", "shield"],
		"key_skills": ["challenge", "shield_hammer", "holy_strike", "grace"], "skills": [],
		"strengths": ["Много здоровья и физической защиты", "Держит зверей на себе: вызов, оглушение щитом", "Блок щитом и свет на клинке"],
		"features": ["Урона меньше, чем у Наёмника и Воина", "Умения щита работают только со щитом"],
		"attack": "melee", "range": 2.6, "cd": 0.85, "weapon": "sword_shield",
		"hp": 125, "hp_lvl": 24, "atk": 8, "atk_lvl": 2.2, "def": 4, "def_lvl": 1.3, "mp": 28, "mp_lvl": 5,
		"eva": 0.02, "crit": 0.05, "speed": 6.8,
		"color": Color(0.85, 0.85, 0.95), "accent": Color(0.3, 0.45, 0.82),
	},
	"wizard": {
		"name": "Волшебник", "race": "light_elf", "role": "лекарь и заклинатель",
		"desc": "Лечит себя и питомца, дарит усиления, бьёт светом, водой и землёй издалека. Без него отряд долго не продержится.",
		"weapon_text": "одноручный или двуручный посох",
		"weapons": ["staff_1h", "staff_2h"],
		"key_skills": ["healing_touch", "light_pulse", "gift_strength", "soul_return"], "skills": [],
		"strengths": ["Лучшее лечение, в том числе лечение со временем", "Ауры-усиления: Сила, Выносливость, Интеллект, Мудрость", "Ослабления и немало атакующей магии"],
		"features": ["Мало защиты от ударов", "Восстанавливать ману нечем"],
		"attack": "magic", "range": 10.0, "cd": 1.0, "weapon": "staff",
		"hp": 90, "hp_lvl": 15, "atk": 9, "atk_lvl": 2.8, "def": 2, "def_lvl": 0.6, "mp": 45, "mp_lvl": 8,
		"eva": 0.02, "crit": 0.05, "speed": 6.8,
		"color": Color(1.0, 0.9, 0.5), "accent": Color(0.95, 0.78, 0.35),
	},
	"beastmaster": {
		"name": "Зверолов", "race": "light_elf", "role": "сила через питомца",
		"desc": "Всё через зверя: усиливает, лечит и воскрешает питомца, сам помогает светом. Чем сильнее связь — тем страшнее питомец.",
		"weapon_text": "двуручная булава, одноручный или двуручный посох",
		"weapons": ["mace_2h", "staff_1h", "staff_2h"],
		"key_skills": ["beast_kinship", "beast_might", "mend_beast", "second_wind"], "skills": [],
		"strengths": ["Поддерживает любого питомца: лечит, усиливает, воскрешает", "Много пассивок питомца", "С крепким питомцем — хороший урон"],
		"features": ["Целиком полагается на питомца", "Мало атакующих умений и ослаблений", "Защита слабее, чем у бойцов"],
		"attack": "magic", "range": 9.5, "cd": 1.0, "weapon": "staff",
		"hp": 95, "hp_lvl": 16, "atk": 8, "atk_lvl": 2.5, "def": 2, "def_lvl": 0.7, "mp": 40, "mp_lvl": 7,
		"eva": 0.02, "crit": 0.05, "speed": 6.8,
		"color": Color(0.55, 0.78, 0.45), "accent": Color(0.95, 0.85, 0.5),
	},
	# ---------- Тёмные эльфы ----------
	"assassin": {
		"name": "Наёмник", "race": "dark_elf", "role": "клинки или арбалет, уклонение",
		"desc": "Странница, что пробует любое оружие: парные кинжалы, парные мечи или арбалет. Уклоняется и часто бьёт критом.",
		"weapon_text": "один или два кинжала, один или два одноручных меча, арбалет",
		"weapons": ["dagger", "daggers", "sword_1h", "dual_swords", "crossbow"],
		"key_skills": ["backstab", "shadow_step", "charge_stab", "dual_shot"], "skills": ["backstab", "shadow_step"],
		"strengths": ["Хороший урон и высокая скорость атаки", "Высокое уклонение", "Две дороги: парные клинки вблизи или арбалет издалека"],
		"features": ["Настоящего лечения нет", "Защита ниже, чем у Мечника и Воина", "Умения легко переманивают зверей на себя"],
		"attack": "melee", "range": 2.4, "cd": 0.55, "weapon": "daggers",
		"hp": 95, "hp_lvl": 17, "atk": 7, "atk_lvl": 2.5, "def": 2, "def_lvl": 0.7, "mp": 30, "mp_lvl": 6,
		"eva": 0.05, "crit": 0.2, "speed": 7.2,
		"color": Color(0.35, 0.2, 0.45), "accent": Color(0.82, 0.16, 0.26),
	},
	"neophyte": {
		"name": "Неофит", "race": "dark_elf", "role": "маг урона",
		"desc": "Огонь, молния и тьма: самый большой урон издалека, проклятия и поглощение жизни. Хрупок вблизи — держите зверя подальше.",
		"weapon_text": "одноручный или двуручный посох",
		"weapons": ["staff_1h", "staff_2h"],
		"key_skills": ["fire_spark", "zap", "life_sip", "flame_orb"], "skills": [],
		"strengths": ["Быстрые заклинания издалека — можно чередовать без пауз", "Вытягивает жизнь, поглощает тела зверей: HP и MP", "Урон по площади и со временем, ослабления"],
		"features": ["Очень мало здоровья и защиты от ударов", "Сильный рывок урона быстро съедает ману"],
		"attack": "magic", "range": 11.0, "cd": 1.05, "weapon": "staff",
		"hp": 85, "hp_lvl": 14, "atk": 10, "atk_lvl": 3.2, "def": 1, "def_lvl": 0.5, "mp": 45, "mp_lvl": 8,
		"eva": 0.04, "crit": 0.07, "speed": 6.9,
		"color": Color(0.5, 0.15, 0.6), "accent": Color(0.78, 0.45, 1.0),
	},
	"adept": {
		"name": "Адепт", "race": "dark_elf", "role": "тёмная связь с питомцем",
		"desc": "Подпитывает питомца тьмой, берёт у него жизнь и жертвует им ради силы. Немного огня и ритуального клинка.",
		"weapon_text": "кинжал, одноручный или двуручный посох; щит — к кинжалу и одноручному посоху",
		"weapons": ["dagger", "staff_1h", "staff_2h", "shield"],
		"key_skills": ["fire_feed", "blood_gift", "borrowed_life", "abyss_blood"], "skills": [],
		"strengths": ["Много умений для питомца и сильные усиления", "Часть тёмной магии Неофита", "Хороший урон вместе с питомцем"],
		"features": ["Сильно зависит от питомца, сам хрупок", "Питомец — сосуд: берёт у него HP и MP, может пожертвовать им ради силы"],
		"attack": "magic", "range": 10.0, "cd": 1.0, "weapon": "staff",
		"hp": 90, "hp_lvl": 15, "atk": 8, "atk_lvl": 2.6, "def": 2, "def_lvl": 0.6, "mp": 40, "mp_lvl": 7,
		"eva": 0.04, "crit": 0.06, "speed": 7.0,
		"color": Color(0.3, 0.12, 0.25), "accent": Color(0.85, 0.2, 0.35),
	},
	# ---------- Люди ----------
	"warrior": {
		"name": "Воин", "race": "human", "role": "боец ближнего и дальнего боя",
		"desc": "Двуручный или парные топоры, а то и лук: высокий урон. Копит искры духа и тратит их на лечение, оглушение и заморозку.",
		"weapon_text": "лук, двуручный топор, один или два одноручных топора",
		"weapons": ["bow", "axe_2h", "axe_1h", "dual_axes"],
		"key_skills": ["combat_drill", "spin_strike", "kindle_spark", "power_breath"], "skills": [],
		"strengths": ["Хороший урон и запас здоровья", "Неплохая защита", "Искры духа возвращают HP и MP"],
		"features": ["Медленная атака (с уровнем быстрее)", "Лечение искрами — не постоянное", "Легко переманивает зверей на себя"],
		"attack": "melee", "range": 2.8, "cd": 0.9, "weapon": "axe",
		"hp": 120, "hp_lvl": 22, "atk": 9, "atk_lvl": 2.8, "def": 3, "def_lvl": 1.0, "mp": 25, "mp_lvl": 4,
		"eva": 0.02, "crit": 0.08, "speed": 6.8,
		"color": Color(0.7, 0.3, 0.2), "accent": Color(0.92, 0.72, 0.3),
	},
	"shaman": {
		"name": "Шаман", "race": "human", "role": "заклинатель четырёх стихий",
		"desc": "Зачаровывает оружие огнём, молнией, камнем и водой, усиливает себя и питомца, держит и усыпляет зверей.",
		"weapon_text": "двуручный посох, двуручный топор",
		"weapons": ["staff_2h", "axe_2h"],
		"key_skills": ["fire_edge", "pure_spring", "earth_grip", "wind_sickle"], "skills": [],
		"strengths": ["Ауры атаки, защиты и скорости для себя и питомца", "Хорошая защита от магии; огненная кожа жжёт ударившего", "Лезвия стихий: урон, оглушение, яд, мана"],
		"features": ["Мало защиты от ударов", "Нет быстрых повторяемых атак", "Заклинания дорогие по мане"],
		"attack": "magic", "range": 10.0, "cd": 1.0, "weapon": "staff",
		"hp": 100, "hp_lvl": 17, "atk": 9, "atk_lvl": 2.7, "def": 3, "def_lvl": 0.8, "mp": 40, "mp_lvl": 7,
		"eva": 0.02, "crit": 0.05, "speed": 6.8,
		"color": Color(0.25, 0.5, 0.6), "accent": Color(0.95, 0.6, 0.25),
	},
	"conjurer": {
		"name": "Колдун", "race": "human", "role": "един с питомцем",
		"desc": "Песни-созвучия усиливают и героя, и питомца; лечит и защищает зверя, а в конце пути может слиться с ним.",
		"weapon_text": "двуручный топор, один или два одноручных топора",
		"weapons": ["axe_2h", "axe_1h", "dual_axes"],
		"key_skills": ["chord_vitality", "chord_strength", "lullaby", "armor_split"], "skills": [],
		"strengths": ["Меньше всех призывателей зависит от питомца", "Созвучия усиливают и героя, и питомца: можно стать бойцом или стеной", "Страх, лечение и защита питомца"],
		"features": ["Умений лечения себя нет", "В слиянии душ питомец не бьётся рядом"],
		"attack": "melee", "range": 2.6, "cd": 0.85, "weapon": "axe",
		"hp": 110, "hp_lvl": 19, "atk": 8, "atk_lvl": 2.5, "def": 3, "def_lvl": 0.9, "mp": 35, "mp_lvl": 6,
		"eva": 0.02, "crit": 0.05, "speed": 6.9,
		"color": Color(0.35, 0.55, 0.3), "accent": Color(0.85, 0.75, 0.35),
	},
}

## Названия типов атаки для интерфейса.
const ATTACK_NAMES := {"melee": "ближний бой", "ranged": "стрельба", "magic": "магия"}


## id профессии по прежнему id класса (LEGACY_CLASSES); остальные — как есть.
static func migrate_id(id: String) -> String:
	return String(LEGACY_CLASSES.get(id, id))


static func race(id: String) -> Dictionary:
	return RACES.get(id, RACES["human"])


static func cls(id: String) -> Dictionary:
	return CLASSES.get(migrate_id(id), CLASSES[WANDERER])


static func job_name(id: String) -> String:
	return String(cls(id)["name"])


static func has_class(id: String) -> bool:
	return CLASSES.has(id)


static func is_wanderer(id: String) -> bool:
	return id == WANDERER


## Профессия 1-й смены (не Бродяга).
static func is_job(id: String) -> bool:
	return CLASSES.has(id) and id != WANDERER


## Три профессии расы.
static func jobs_of(race_id: String) -> Array:
	return race(race_id).get("jobs", [])


## Раса профессии ("" — у Бродяги).
static func job_race(id: String) -> String:
	return String(cls(id).get("race", ""))


## Подходит ли профессия расе (Бродяга — любой).
static func job_fits_race(id: String, race_id: String) -> bool:
	return is_wanderer(id) or jobs_of(race_id).has(id)


## Виды оружия профессии (ItemData.WEAPON_KINDS).
static func weapons(id: String) -> Array:
	return cls(id).get("weapons", [])


## Сверх-эволюция: JP при смене профессии на уровне lvl (+5 за каждый уровень выше 10, потолок — 20 ур.).
static func over_jp(lvl: int) -> int:
	return OVER_JP_PER_LEVEL * clampi(mini(lvl, OVER_LEVEL_CAP) - JOB_LEVEL, 0, OVER_LEVEL_CAP - JOB_LEVEL)


static func attack_name(kind: String) -> String:
	return String(ATTACK_NAMES.get(kind, kind))


static func gender_name(g: String) -> String:
	for e in GENDERS:
		if String(e[0]) == g:
			return String(e[1])
	return ""


## Характеристики класса на уровне без статов (запасной путь; у всех героев есть статы — HeroStats):
## max_hp, max_mp, atk, def, speed, range, cd, crit, eva, attack.
static func stats_for(class_id: String, level: int) -> Dictionary:
	var c := cls(class_id)
	var l := level - 1
	return {
		"max_hp": int(float(c["hp"]) + float(c.get("hp_lvl", 0)) * l),
		"max_mp": int(float(c.get("mp", 0)) + float(c.get("mp_lvl", 0)) * l),
		"eva": float(c.get("eva", 0.0)),
		"atk": int(float(c["atk"]) + float(c.get("atk_lvl", 0)) * l),
		"def": int(float(c["def"]) + float(c.get("def_lvl", 0)) * l),
		"speed": float(c["speed"]),
		"range": float(c["range"]),
		"cd": float(c["cd"]),
		"crit": float(c["crit"]),
		"attack": String(c["attack"]),
	}

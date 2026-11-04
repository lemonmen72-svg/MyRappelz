#!/usr/bin/env python3
# Промты ChatGPT на значки будущих умений: волк (питомец, 18 умений) и 15 вторых профессий.
# Пишет tools/Промты_значки_волк_и_вторые_профессии.docx и справочник tools/rappelz_future_skills_reference.md.
# Запуск из корня репозитория: python3 -I tools/make_future_icons_doc.py   (нужен python-docx)
# Источник умений — выгрузка базы оригинала (вторые профессии и древо волка): только список и английские названия,
# описаний в ней нет, тип у большинства записан «passive» — тип и суть выбраны по смыслу названия и по аналогам
# первых профессий. Названия, id, тексты и значки — свои (не Rappelz).
import os
import re
import sys

from docx import Document
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Pt

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCX = os.path.join(ROOT, "tools", "Промты_значки_волк_и_вторые_профессии.docx")
MD = os.path.join(ROOT, "tools", "rappelz_future_skills_reference.md")
CUT = "python3 -I tools/cut_icon_sheet.py <лист.png>"

# Тип: A — активное, P — пассивное, T — переключаемое, U — аура (переключаемое для героя и питомца).
TYPE_EN = {"A": "ACTIVE (violet)", "P": "PASSIVE (gold)", "T": "TOGGLE (teal)", "U": "AURA (teal)"}
TYPE_RU = {"A": "А", "P": "П", "T": "Т", "U": "Аура"}

# Сетка листа по числу значков: [(столбцов, рядов, размер значка), …] — по листу на элемент.
GRIDS = {
	18: [(6, 3, 200)], 16: [(4, 4, 190)], 14: [(7, 2, 170)], 13: [(7, 1, 170), (6, 1, 200)],
	10: [(5, 2, 220)], 8: [(4, 2, 220)], 7: [(7, 1, 170)], 6: [(6, 1, 200)], 5: [(5, 1, 220)], 4: [(4, 1, 220)],
}


def S(sid, ru, orig, typ, essence, short, desc):
	"""Умение: id, наше название, оригинал (англ.), тип, суть (рус.), метка для карты сетки, описание значка."""
	return {"id": sid, "ru": ru, "orig": orig, "type": typ, "essence": essence, "short": short, "desc": desc}


def SHARED(sid):
	"""Умение, общее с другой профессией: значок рисуется на листе той профессии."""
	return {"shared": sid}


# ---------------------------------------------------------------- Волк (питомец) ----------------------------------
WOLF_SUBJECT = ("a silver-grey WOLF with icy-blue eyes and a fluffy tail — a swift melee FIGHTER of the night forest "
	"(an agility creature: fast bites, lunges, howls under the moon). Theme colors: silver grey, steel blue, ice white, "
	"moonlight silver, deep night blue, with crimson-orange accents for fury and fire.")
WOLF_LOOK = ("Волк — «Обычный» питомец-боец, «существо ловкости». Облик значков как у четырёх готовых: серебристо-серый "
	"волк с голубыми глазами, синие и ледяные вихри, лунный свет; огонь и кровь — алым и оранжевым.")
# Порядок — шаблон древа других видов (пантера, черепаха, фазан, кентавр): 11 общих id + 7 своих.
WOLF = [
	S("inner_fire", "Внутренний огонь", "Awakening: P. Atk.", "P", "главная атака питомца сильнее",
		"wolf head in fire",
		"a snarling silver-grey wolf head wreathed in orange-red fire, glowing red eyes — stronger attack."),
	S("hardening", "Закалка", "Awakening: P. Def.", "P", "физ. и маг. защита выше",
		"wolf behind ice wall",
		"a crouching silver wolf behind a curved wall of blue ice crystals like a shield — tougher defense."),
	S("fierce_rush", "Свирепый натиск", "Piercing Fangs (по смыслу)", "A", "мощный удар-рывок по цели",
		"lunging wolf",
		"a silver wolf leaping forward at full speed, white impact burst and blue speed lines — powerful lunge strike."),
	S("provoke", "Дерзкий вызов", "Threatening Essence", "T",
		"пока включено, удары волка переключают зверя на него (общее)", "snarling challenge",
		"a wolf standing on a rock with raised hackles, snarling, orange challenge shockwave rings around it — draws "
		"enemies to itself."),
	S("rending_bite", "Рвущий укус", "Gouging Bite", "A",
		"глубокий укус: урон и кровотечение 10 с (урон со временем)", "bleeding bite",
		"wolf jaws clamping down, three red tear marks and blood droplets flying — bite that causes bleeding."),
	S("vitality", "Живучесть", "Bless the Body", "P", "больше макс. HP", "heart and wolf tail",
		"a big red heart with a fluffy silver wolf tail curling around it, blue wind swirls — more health."),
	S("deep_spring", "Глубокий родник", "Bless the Soul", "P", "больше макс. MP (общее)", "moonlit spring",
		"a deep blue forest spring under moonlight with a wolf paw print reflected in the water — more mana."),
	S("daze", "Морок", "— (общее у всех видов)", "A", "окутывает цель мороком: зверь бьёт мимо (общее)",
		"misted beast eye",
		"a beast eye clouded by swirling silver mist shaped like a wolf shadow — dazing, the enemy misses."),
	S("chilling_howl", "Леденящий вой", "Roar", "A",
		"вой: звери рядом оглушены на 2 с и переключаются на волка", "icy howl",
		"a wolf head howling with icy blue sound rings spreading out, a small beast silhouette flinching under a yellow "
		"stun star — howl that stuns and draws enemies."),
	S("mending", "Быстрое заживление", "Meditation", "P", "HP восстанавливается быстрее (общее)",
		"wolf licking paw",
		"a wolf licking its paw, soft green healing sparkles rising around it — fast health regeneration."),
	S("calm_mind", "Тихий разум", "Clarity", "P", "MP восстанавливается быстрее (общее)", "wolf under moon",
		"a wolf sitting with closed eyes under a crescent moon, calm blue glow — mana regeneration."),
	S("pack_bond", "Узы стаи", "Unity: Wolf", "T", "пока включено, атака хозяина и волка выше",
		"hand and paw bond",
		"a human hand and a wolf paw touching, linked by a glowing silver-blue moonlight ribbon — bond of the pack, "
		"master and wolf attack stronger."),
	S("keen_eye", "Верный глаз", "Sharp Vision", "P", "точность выше (общее)", "sharp wolf eye",
		"a sharp icy-blue wolf eye with a bright crosshair glint — accuracy."),
	S("alpha_call", "Клич вожака", "Encouragement: Strength, Agility", "A",
		"Сила и Ловкость хозяина выше на 15 с", "howl at full moon",
		"a wolf on a cliff howling at a full moon, silver-gold waves flowing down to a small human silhouette — "
		"master's strength and agility up."),
	S("fang_flurry", "Шквал клыков", "Shredding Fangs", "A", "три мощных укуса подряд", "three fang arcs",
		"three white crescent-shaped fang arcs one after another with blue speed streaks — three strong bites in a row."),
	S("endless_life", "Неиссякаемая жизнь", "Awakening: HP Regen (общее)", "P",
		"постоянное восстановление HP (общее)", "infinity loop heart",
		"a silver-blue wind ribbon forming an infinity loop around a small heart with a paw print — endless life."),
	S("moon_frenzy", "Лунное буйство", "Rampage", "A",
		"вихрь укусов по всем зверям вокруг цели, 10 с их удары слабее", "moonlit whirlwind",
		"a wolf spinning in a whirlwind of silver moonlight and claw slashes under a full moon, several beast "
		"silhouettes knocked back — rampage hitting all enemies around."),
	S("ancestor_gift", "Дар предков", "Eden's Blessing", "P", "все семь характеристик выше (общее)",
		"spirit-wolf totem",
		"a glowing silver spirit-wolf totem on an ancient rune stone under the moon — blessing of ancestors, all stats up."),
]
WOLF_HAVE = {"inner_fire", "hardening", "vitality", "fierce_rush"}
WOLF_SKIPPED = ("Creature Item Expert, Card Ability: Agility / Evasion, Blessing of Strength / Intelligence / Agility / "
	"Vitality / Dexterity / Wisdom (Basic, Intermediate), Vital Unit: Hunter Armor, Fighter Unit: Melee Weapon, "
	"Creation: Wolf's Claw / Wolf Potion — предметы и карты оригинала, у нас другой механики нет; Lunging Bite — по смыслу "
	"«Свирепый натиск»; Wound Lick — по смыслу «Быстрое заживление»; Awakening: Evasion — у фазана «Лёгкое перо», у "
	"волка на этом месте общее «Неиссякаемая жизнь» (по шаблону древа).")

# ---------------------------------------------------------------- Вторые профессии --------------------------------
JOBS = [
	# ======================== Люди ========================
	{
		"ru": "Громобой", "id": "thunderer", "orig": "Champion", "race": "Люди", "parent": "Воин ← Fighter",
		"weapon": "двуручный топор, парные топоры", "role": "боец ближнего боя: огонь и гром в ударах топора, удары по площади",
		"look": "человек-воин в тяжёлой броне из стали и бронзы, огромный двуручный топор или два топора; треск огня и молний.",
		"subject": "a HUMAN BATTLE CHAMPION in heavy steel-and-bronze armor wielding a huge two-handed axe or two "
			"one-handed axes; crackling fire, thunder and wind in every swing. Theme colors: steel grey, bronze, "
			"crimson-orange fire, electric yellow and blue lightning, wind white.",
		"skills": [
			S("thunder_cleave", "Громовой разруб", "Thunderbolt Wind Cut", "A",
				"широкий взмах с ветром и молнией: урон перед героем, шанс оглушения", "lightning axe arc",
				"a huge axe slashing in a wide arc trailing wind streaks and a jagged yellow lightning bolt — thunder-wind cleave."),
			S("crimson_blaze", "Багровое пламя", "Hellfire Flame", "A", "удар топором в огне: урон огнём и горение",
				"crimson flame axe",
				"an axe blade engulfed in dark crimson and black-red flames striking down, ember sparks — hellish fire strike "
				"with burning."),
			S("unbreakable", "Несокрушимость", "Essence of Invulnerability", "A",
				"6–8 с урон по герою почти не проходит, большая перезарядка", "golden shell armor",
				"a warrior's chest armor glowing inside a golden-white shell, arrows and claws bouncing off — short invulnerability."),
			S("power_burst", "Взрыв силы", "Energy Bomb", "A", "сгусток силы взрывается у цели: урон по площади",
				"exploding energy orb",
				"a glowing orange energy orb exploding in a ring of fire and flying fragments — area blast."),
			S("axe_whirlwind", "Секирный вихрь", "Whirlwind Assault", "A", "вращение с топором: удары по всем вокруг",
				"spinning axe whirlwind",
				"a warrior spinning with a two-handed axe inside a grey whirlwind, axe arcs all around — spinning area attack."),
			S("ground_split", "Раскол земли", "Earth Shaker", "A", "удар по земле: урон и оглушение всех вокруг",
				"axe cracking ground",
				"an axe smashing into the ground, cracked earth radiating outward with flying rocks and a yellow stun star — "
				"earth-shaking stun."),
			S("fury_beam", "Луч ярости", "Spiracle Cannon", "A", "дальний выстрел сгустком силы по линии",
				"energy beam from axe",
				"a beam of compressed orange-white spirit energy fired from a raised axe across the tile — long-range energy blast."),
			S("blade_wave", "Режущая волна", "Wave Cut", "A", "волна от взмаха летит вперёд и бьёт всех на линии",
				"flying crescent wave",
				"a crescent-shaped blue-white air wave flying forward from an axe swing, cutting through grass — flying "
				"cutting wave."),
			SHARED("shudder_flame"),
			S("flame_temper", "Пламенная закалка", "Essence of Fire", "T",
				"пока включено, обычные атаки + урон огнём, атака выше", "red-hot axe head",
				"an axe head glowing red-hot with flames running along the blade and small fire runes (no letters) — "
				"fire-enchanted weapon."),
			S("thunder_temper", "Громовая закалка", "Essence of Thunder", "T",
				"пока включено, обычные атаки + урон молнией, шанс оглушения", "lightning axe head",
				"an axe head crackling with blue-yellow lightning arcs wrapped around the blade — lightning-enchanted weapon."),
		],
	},
	{
		"ru": "Следопыт", "id": "pathfinder", "orig": "Archer", "race": "Люди", "parent": "Воин ← Fighter",
		"weapon": "лук", "role": "стрелок: ловушки, стрелы стихий, контроль на расстоянии",
		"look": "человек-лучник в зелёно-коричневой коже с капюшоном, длинный изогнутый лук, капканы и сети; стрелы "
			"огня, льда и молнии.",
		"subject": "a HUMAN WILDERNESS ARCHER in a hooded green-brown leather outfit with a long recurve bow, steel traps "
			"and nets; elemental arrows of fire, ice and lightning. Theme colors: forest green, leather brown, steel, "
			"flame orange, ice blue, lightning yellow, acid green.",
		"skills": [
			S("prey_sight", "Глаз на добычу", "Vision of Prey", "A", "20 с крит и точность по цели выше",
				"eye with target mark",
				"a hawk-sharp archer eye with a glowing red target mark over a running beast silhouette — hunter's focus on prey."),
			S("acid_snare", "Едкий капкан", "Snare of Corrosion", "A", "ловушка: попавший зверь отравлен, защита ниже",
				"trap dripping acid",
				"a steel jaw trap dripping green acid onto a corroded metal plate — corrosive trap."),
			S("forest_surge", "Лесной прилив", "Mysterious Energy", "A", "восполняет MP и на время ускоряет атаку",
				"leaf spiral into hand",
				"a glowing green-gold leaf spiral flowing into an open hand holding a bow, blue mana sparks — surge of hidden energy."),
			S("iron_cage", "Стальная клеть", "Steel Cage", "A", "клеть из прутьев: зверь не двигается 4 с",
				"beast in steel cage",
				"a beast silhouette trapped inside a cage of steel bars bursting up from the ground — steel cage that holds."),
			S("frost_snare", "Ледяной капкан", "Icicle Snare", "A", "ловушка изо льда: урон холодом и замедление",
				"icicle trap",
				"a trap of sharp icicles closing around a beast paw, frosty mist — freezing trap."),
			S("flame_column", "Огненный столп", "Fire Pillar Shot", "A", "стрела вызывает столп огня у цели: урон по площади",
				"arrow and fire pillar",
				"an arrow hitting the ground and a tall pillar of fire erupting from the impact — fire pillar arrow."),
			S("paired_arrows", "Парная стрела", "Double Shot", "A", "два выстрела подряд",
				"two arrows side by side",
				"two arrows flying side by side with matching green trails from one bow — double shot."),
			S("fire_trap", "Огненная ловушка", "Trap of Flame", "A", "ловушка-зона: огонь жжёт зверей, что в неё вошли",
				"fire trap plate",
				"a round trap plate on the ground with flames bursting up around a stepping beast foot — fire trap."),
			S("echo_arrow", "Звонкая стрела", "Resonance Shockwave", "A", "стрела с ударной волной: урон всем вокруг цели",
				"arrow with shock rings",
				"an arrow striking with concentric white resonating shock rings spreading out — shockwave arrow."),
			S("steel_skin", "Стальная кожа", "Essence of Steel", "T", "пока включено, защита выше",
				"steel-sheen bracer",
				"a leather-and-steel archer bracer and chest guard glowing with a silver metallic sheen — steel defense."),
			S("arrow_storm", "Гроза стрел", "Lightning Fury", "A", "ливень стрел-молний по площади",
				"lightning arrow rain",
				"many lightning-charged arrows falling from a dark cloud onto one spot, yellow bolts — lightning arrow rain."),
			S("through_shot", "Сквозной выстрел", "Penetrating Shot", "A", "стрела пробивает всех зверей на линии",
				"arrow through two beasts",
				"one arrow piercing straight through two beast silhouettes in a line, glowing streak — penetrating shot."),
			S("thunder_snare", "Грозовой капкан", "Snare of Lightning", "A", "ловушка с молнией: урон и оглушение",
				"lightning trap",
				"a trap plate crackling with yellow lightning arcs jolting a beast paw, yellow stun star — lightning trap."),
		],
	},
	{
		"ru": "Ведун", "id": "seer", "orig": "Druid", "race": "Люди", "parent": "Шаман ← Kahuna",
		"weapon": "двуручный посох", "role": "лекарь и заклинатель природы: лечение, воскрешение, камень и корни",
		"look": "человек-знахарь в мшисто-зелёной и бурой одежде с оберегами из кости и перьев, узловатый посох с живым "
			"зелёным кристаллом; целебная вода, камень, корни, духи огня.",
		"subject": "a HUMAN NATURE SEER-HEALER in moss-green and earth-brown robes with bone and feather charms, holding "
			"a gnarled wooden staff with a living green crystal; healing water, stone, roots and fire spirits. Theme "
			"colors: moss green, earth brown, warm amber, healing teal, fire orange, stone grey.",
		"skills": [
			S("flame_spear", "Огненное копьё", "Spear of Flame", "A", "копьё пламени: урон огнём и горение",
				"spear made of fire",
				"a long spear made of fire flying forward with an ember trail — fire spear."),
			S("mirror_gale", "Отражающий вихрь", "Gale of Reflection", "A", "15 с часть физ. урона возвращается зверю",
				"wind barrier bouncing claws",
				"a swirling green wind barrier around a small figure bouncing red claw marks back — reflecting gale."),
			S("stone_burst", "Каменный взрыв", "Explosion of Petrifaction", "A",
				"звери вокруг цели каменеют: оглушение 3 с", "beasts turning to stone",
				"a burst of grey stone dust from one point, beasts around it turning to stone with glowing cracks — "
				"petrifying explosion."),
			S("rebirth_rite", "Обряд возрождения", "Resurrection Sorcery", "A",
				"воскрешает погибшего питомца с большой долей HP и MP", "spirit rising from runes",
				"a ring of glowing green runes on the ground with a beast spirit rising back into a body under falling "
				"leaves — resurrection rite."),
			S("bull_spirit", "Дух горного быка", "Yak Advent", "A",
				"дух-хранитель: защита и макс. HP героя и питомца выше на время", "spirit bull guardian",
				"a huge translucent spirit of a shaggy mountain bull with curved horns standing behind a small figure, "
				"earthy golden glow — guardian spirit of the bull."),
			S("soul_mirror", "Зеркало души", "Reflection of the Soul", "A", "15 с часть маг. урона возвращается зверю",
				"stone mirror reflecting bolt",
				"a hand mirror of polished green stone reflecting a violet magic bolt back — magic reflection."),
			S("life_breath", "Дыхание жизни", "Essence of Life", "U", "герою и питомцу — восстановление HP выше",
				"sprout in teal aura",
				"a glowing green sprout with a heart-shaped leaf inside a soft teal breathing aura — regeneration aura."),
			S("undying_pillar", "Неугасимый столп", "Eternal Pillar of Fire", "A", "зона: столп огня 10 с жжёт зверей",
				"fire pillar on rune circle",
				"a tall unending pillar of fire standing on a glowing rune circle, flames swirling upward — lasting fire "
				"pillar zone."),
			S("earth_roots", "Корни земли", "Root of Mother Nature", "A", "корни держат зверя на месте 6 с",
				"roots binding legs",
				"thick green roots bursting from the ground and wrapping a beast's legs — root bind."),
			S("void_wave", "Волна пустоты", "Vacuum Shockwave", "A", "волна сжатого воздуха: урон по площади, отброс",
				"imploding air sphere",
				"a sphere of compressed clear air imploding and then blasting outward, dust and pebbles pushed away — vacuum "
				"shockwave."),
			S("stone_curse", "Каменное проклятие", "Deadly Petrifaction", "A",
				"зверь каменеет: оглушение 5 с, защита ниже", "beast turning to stone",
				"a single beast turning fully to grey stone from the paws up, cracks glowing green — deadly petrification."),
			S("healing_spirit", "Дух исцеления", "Spirit of Restoration", "A",
				"лечение со временем герою и питомцу", "leaf-winged spirit",
				"a small glowing teal forest spirit with leafy wings sprinkling healing light over a person and a beast — "
				"healing spirit."),
			S("purge_venom", "Противоядие", "Poison Healing", "A", "снимает яд и ослабления, немного лечит",
				"poison drawn into leaf",
				"a green poison drop being drawn out of a wound into a glowing herb leaf and turning clear — cure poison."),
			S("earth_tears", "Слёзы земли", "Tears of Gaia", "A", "большое лечение тому, кому хуже (герой или питомец)",
				"teardrops from stone face",
				"large glowing teal teardrops falling from a mossy mountain rock onto cupped hands, golden-green healing "
				"light — great heal."),
		],
	},
	{
		"ru": "Заклинатель бурь", "id": "stormcaller", "orig": "Battle Kahuna", "race": "Люди", "parent": "Шаман ← Kahuna",
		"weapon": "двуручный посох, двуручный топор", "role": "боевой маг стихий: гроза, вулкан, тяжесть земли по площади",
		"look": "человек-шаман в одежде с перьями и костяными бусами, двуручный посох или топор; грозовые тучи, лава, "
			"обсидиан.",
		"subject": "a HUMAN BATTLE SHAMAN of storm and volcano in tribal robes with feathers and bone beads, holding a "
			"two-handed staff or a great axe; storm clouds, lava and obsidian. Theme colors: storm grey-blue, electric "
			"yellow, lava orange-red, obsidian black, spirit teal.",
		"skills": [
			S("shudder_flame", "Дрожь пламени", "Shuddering Flame", "A",
				"волна огня по земле от героя: урон всем вокруг", "fire ring from staff",
				"a ring of trembling fire bursting outward along the ground around a planted staff — flame shockwave around "
				"the caster."),
			S("storm_wrath", "Гнев грозы", "Thunderstorm Slayer", "A", "гроза бьёт молниями всех у цели",
				"storm cloud bolts",
				"a black storm cloud dropping several lightning bolts onto one spot in the ground — thunderstorm area strike."),
			S("spirit_rain", "Дождь духов", "Rain of the Spirits", "A", "светящиеся капли-духи падают на площадь: урон",
				"glowing spirit raindrops",
				"glowing teal spirit droplets with tiny ghostly wisps falling like rain from a swirling cloud — rain of spirits."),
			S("volcano_rage", "Ярость вулкана", "Huge Volcanic Eruption", "A",
				"извержение под целью: большой урон по площади и горение", "erupting volcano",
				"a volcano cone erupting with a huge column of lava and flying fire rocks — volcanic eruption."),
			S("earth_weight", "Тяжесть земли", "Gravity Amplification", "A",
				"зверей вокруг прижимает к земле: сильное замедление, удары реже", "beast pressed by gravity",
				"a beast pressed down into cracked ground by a dark violet gravity sphere with heavy downward force lines — "
				"crushing gravity."),
		],
	},
	{
		"ru": "Вожатый", "id": "pack_leader", "orig": "Evoker", "race": "Люди", "parent": "Колдун ← Spell Singer",
		"weapon": "топоры", "role": "ведёт двух питомцев: печати и ярость для зверей",
		"look": "человек-друид-певец в лесном зелёном плаще, топор; ленты песни из света, два духа-зверя, закатный свет.",
		"subject": "a HUMAN BEAST-EVOKER who leads two creature companions at once: forest-green cloak with leaves, an "
			"axe, flowing song ribbons of light (no musical notes), two beast spirits. Theme colors: forest green, sunset "
			"gold, warm amber, soft teal, a little crimson for rage.",
		"skills": [
			S("twin_reins", "Две узды", "Dual Summoning Control", "P",
				"два призванных питомца слушаются лучше: оба сильнее", "two beasts on golden reins",
				"two beast silhouettes side by side held by two glowing golden reins in one hand — mastery of two creatures."),
			SHARED("blade_wave"),
			S("earth_seal", "Печать земли", "Seal of Gaia", "A",
				"печать под питомцем: защита и восстановление питомца выше", "earth seal under paw",
				"a glowing green-gold circular earth seal with stone glyph shapes (no letters) on the ground under a big "
				"beast paw — earth seal protecting the creature."),
			S("fury_peak", "Вершина ярости", "Paragon of Anger", "A",
				"15 с питомец в ярости: атака и скорость атаки выше", "beast with fiery mane",
				"a beast head with blazing red-gold eyes and a fiery mane aura, veins of fire — creature rage."),
			S("beast_quake", "Звериная волна", "Beast Shockwave", "A",
				"питомец бьёт лапами по земле: волна урона вокруг него", "paw slam shockwave",
				"a big beast paw slamming the ground with a green-gold shockwave ring spreading out — creature shockwave."),
		],
	},
	# ======================== Светлые эльфы ========================
	{
		"ru": "Страж света", "id": "light_warden", "orig": "Knight", "race": "Светлые эльфы", "parent": "Мечник ← Holy Warrior",
		"weapon": "одноручный меч или булава и щит", "role": "защитник: держит зверей, ломает их защиту, неуязвимость",
		"look": "светлый эльф в тяжёлых серебристо-белых латах, большой щит с солнцем, длинный меч или булава.",
		"subject": "a LIGHT ELF HOLY KNIGHT-DEFENDER in heavy silver-and-white plate armor with a large tower shield "
			"bearing a sun emblem, a longsword or a flanged mace. Theme colors: polished silver, white gold, sky blue, "
			"warm sunlight yellow, a little royal blue.",
		"skills": [
			S("divine_guard", "Небесная защита", "Godly Protection", "A", "5 с урон по герою почти не проходит",
				"knight in light column",
				"a knight kneeling under a bright golden column of light inside a shimmering shield dome — divine protection."),
			SHARED("sun_aura"),
			S("taunt_aura", "Аура вызова", "Hate Aura", "U",
				"пока включено, угроза выше: звери бьют героя, а не питомца",
				"shield with angry eyes",
				"a teal aura ring around a tower shield with red angry eye shapes turning toward it — aura that draws enemies."),
			S("spell_intercept", "Перехват чар", "Spell Intercept", "P", "шанс принять магический удар на щит без урона",
				"shield catching magic bolt",
				"a tower shield catching a violet magic bolt and dispersing it into sparks — blocking magic with the shield."),
			S("armor_rift", "Разлом доспеха", "Physical Breaker", "A", "удар: защита зверя ниже 15 с",
				"sword splitting plate",
				"a sword strike splitting a heavy steel armor plate in two, shards flying — physical defense breaker."),
			S("soul_rift", "Разлом души", "Soul Breaker", "A", "удар: маг. защита зверя ниже 15 с",
				"shattered soul barrier",
				"a sword strike shattering a translucent blue soul barrier around a beast into blue shards — magic defense "
				"breaker."),
			S("light_sign", "Знамение света", "Holy Cross", "A", "два удара светом крест-накрест, вспышка вокруг",
				"cross-shaped light burst",
				"a huge glowing white-gold cross-shaped light burst behind a sword slash — holy sign strike."),
			S("heaven_verdict", "Небесный суд", "Judgment of Heaven", "A",
				"клинок света с неба: большой урон и оглушение", "blade of light from clouds",
				"a giant blade of light descending from parted clouds onto a beast — heavenly judgment."),
			S("heaven_frenzy", "Небесное неистовство", "Heaven's Madness", "A", "серия ударов светом по всем вокруг",
				"spinning sword in light storm",
				"a knight spinning a sword in a storm of golden light rays hitting all around — heavenly frenzy."),
		],
	},
	{
		"ru": "Клинок рассвета", "id": "dawnblade", "orig": "Soldier", "race": "Светлые эльфы", "parent": "Мечник ← Holy Warrior",
		"weapon": "двуручный меч, два меча", "role": "атакующий мечник света: рывки, лучи-клинки, удары по площади",
		"look": "светлый эльф в лёгкой серебристой броне, двуручный меч или два меча, лучи и всполохи рассвета.",
		"subject": "a LIGHT ELF HOLY SWORD-DANCER focused on attack: lighter silver armor with white cloth, a two-handed "
			"greatsword or two longswords, beams and streaks of sunrise light. Theme colors: white gold, sunrise orange "
			"and pink, sky blue, polished silver.",
		"skills": [
			S("sun_aura", "Аура солнца", "Holy Aura", "U",
				"пока включено, герою и питомцу — атака и защита выше", "sun disc aura",
				"a radiant sun disc aura enveloping a person and a beast silhouette, warm golden rays — holy aura."),
			S("sun_flash", "Солнечная вспышка", "Divine Flash", "A", "вспышка света: урон и промахи у всех рядом",
				"flash from raised sword",
				"a blinding white-gold flash bursting from a raised sword, rays in all directions — divine flash."),
			SHARED("taunt_aura"),
			S("double_slash", "Сдвоенный удар", "Dual Strike", "A", "два быстрых удара подряд",
				"two parallel slashes",
				"two fast parallel sword slashes with twin white-gold trails — double strike."),
			S("light_haste", "Быстрее света", "Light Speed", "A", "15 с скорость бега и атаки выше",
				"dashing light trails",
				"a sword-dancer silhouette dashing with long streaks of light behind, speed lines — light-speed haste."),
			S("blade_torrent", "Поток клинков", "Wild Stream", "A", "поток клинков-лучей бьёт всех на линии",
				"stream of light blades",
				"a stream of many glowing sword-shaped light blades rushing forward in a line — torrent of blades."),
			S("justice_blow", "Удар правосудия", "Judgment Buster", "A", "сокрушительный удар двуручным мечом, отброс",
				"greatsword shockwave",
				"a greatsword smashing down with an explosive golden shockwave that knocks a beast back — crushing judgment."),
			S("dawn_verdict", "Приговор зари", "Judgment of the Goddess", "A", "копьё света с неба по площади",
				"wing of light and lance",
				"a huge feathered wing of light and a falling lance of light striking an area, rose-gold glow — judgment "
				"of dawn."),
			S("beam_blade", "Луч-клинок", "Laser Blade", "A", "меч выпускает луч: пробивает всех на линии",
				"sword extended by beam",
				"a sword blade extended by a long thin beam of piercing white light — beam blade."),
			S("sun_crash", "Солнечный обвал", "Divine Crash", "A", "прыжок и удар светом в землю: урон по площади",
				"light dome impact",
				"a sword striking the ground from above with a dome-shaped burst of golden light and cracked earth — "
				"radiant crash."),
			S("giant_blow", "Удар исполина", "Mighty Crash", "A", "сокрушающий удар: большой урон и оглушение",
				"giant sword crater",
				"a giant glowing greatsword slamming down into a huge impact crater with a big yellow stun star — mighty crash."),
		],
	},
	{
		"ru": "Светоносец", "id": "lightbringer", "orig": "Bishop", "race": "Светлые эльфы", "parent": "Волшебник ← Cleric",
		"weapon": "посох или булава", "role": "боевой маг света, льда и земли",
		"look": "светлый эльф в бело-золотой мантии с голубой каймой, кристальный посох или булава; свет, лёд и камень.",
		"subject": "a LIGHT ELF BATTLE PRIEST of light, ice and earth in white-gold robes with blue trim, holding a "
			"crystal staff or a mace; holy light, ice shards and stone. Theme colors: white gold, ice blue, earthy brown, "
			"celestial light blue.",
		"skills": [
			S("sun_weapon", "Солнечное оружие", "Shining Weapon", "T",
				"пока включено, обычные атаки + сильный урон светом (сильнее «Сияющего лезвия»)",
				"weapon blazing with sun",
				"a mace and a staff head crossed, both blazing with bright sun-white light under a golden halo — strong "
				"light enchantment of the weapon."),
			S("stone_pin", "Каменная игла", "Rock Pin", "A", "каменный шип: урон и зверь не сдвинется 4 с",
				"stone spike pinning paw",
				"a sharp stone spike pinning a beast paw to the ground — rock pin root."),
			S("ice_bolt", "Ледяной болт", "Cold Bolt", "A", "ледяной снаряд: урон и замедление",
				"crystal ice bolt",
				"a fast ice bolt shaped like a crystal arrowhead with a frosty trail — cold bolt."),
			SHARED("sun_armor"),
			S("light_nova", "Звезда света", "Divine Nova", "A", "взрыв света вокруг героя: урон всем рядом",
				"light nova ring",
				"a starburst nova of white-gold light expanding in a ring from a staff — light nova."),
			S("deep_quake", "Сотрясение недр", "Earthquake", "A", "землетрясение у цели: урон по площади, оглушение",
				"heaving rock slabs",
				"the ground splitting with brown rock slabs heaving up and a dust cloud — earthquake."),
			S("avalanche", "Лавина", "Snowslide", "A", "снежная лавина: урон по площади и замедление",
				"snow wave rolling",
				"a huge wave of snow and ice chunks rolling down a slope onto one spot — avalanche."),
		],
	},
	{
		"ru": "Пастырь", "id": "shepherd", "orig": "Priest", "race": "Светлые эльфы", "parent": "Волшебник ← Cleric",
		"weapon": "посох", "role": "лекарь: лечение и благословения сразу герою и питомцу",
		"look": "светлый эльф в струящихся бело-золотых одеждах, высокий посох с цветком-кристаллом, мягкие крылья света.",
		"subject": "a LIGHT ELF HIGH HEALER in flowing white and pale-gold robes with a tall staff topped by a glowing "
			"crystal flower and soft wings of light; blessings that cover both a hero and a creature. Theme colors: soft "
			"white, pale gold, healing green, sky blue, a little rose.",
		"skills": [
			S("clarity_spring", "Родник ясности", "Mass MP Regeneration", "U",
				"пока включено, герою и питомцу MP восстанавливается быстрее", "blue spring under two",
				"a calm blue spring fountain glowing under a person and a beast silhouette, blue motes rising — shared mana "
				"regeneration aura."),
			S("healing_wave", "Волна исцеления", "Mass Healing", "A", "лечит героя и питомца сразу",
				"healing ring wave",
				"a wide ring wave of green-gold healing light washing over a person and a beast — group heal."),
			S("blessed_mail", "Благой доспех", "Mass Bless Armor", "U", "пока включено, защита героя и питомца выше",
				"armor and barding halo",
				"a silver chest armor and a beast's barding glowing together under a golden blessing halo — shared armor "
				"blessing."),
			SHARED("sun_weapon"),
			S("blessed_ward", "Благой оберег", "Mass Bless Magic Armor", "U",
				"пока включено, маг. защита героя и питомца выше", "hexagon barrier with halo",
				"a translucent blue hexagon barrier around a person and a beast with a small golden halo above — shared "
				"magic defense blessing."),
			S("dawn_touch", "Касание зари", "Touch of the Goddess", "A", "сильное мгновенное лечение",
				"rose-gold hand on heart",
				"a slender glowing hand of rose-gold light touching a heart, petals of light around — touch of dawn heal."),
			S("blessed_arms", "Благое оружие", "Mass Bless Weapon", "U", "пока включено, атака героя и питомца выше",
				"sword and claw with halo",
				"a sword and a beast claw crossed under a golden blessing halo, warm glow — shared attack blessing."),
			S("sun_armor", "Солнечный доспех", "Shining Armor", "T",
				"пока включено, урон по герою ниже (сильнее «Сияющего покрова»)", "armor of light",
				"a full suit of armor made of shimmering white-gold light with sun rays — shining armor."),
			S("blessed_mind", "Благой разум", "Mass Bless Magic Power", "U",
				"пока включено, маг. атака героя и питомца выше", "crystal star with halo",
				"a glowing violet-gold crystal star above a person and a beast under a golden halo — shared magic power "
				"blessing."),
			S("miracle_heal", "Чудо исцеления", "Miracle", "A",
				"полное лечение и снятие ослаблений, большая перезарядка", "wings over rising figure",
				"a burst of light petals and a pair of radiant wings of light opening over a fallen figure that rises — miracle."),
			S("life_spring", "Родник жизни", "Mass HP Regeneration", "U",
				"пока включено, герою и питомцу HP восстанавливается быстрее", "green spring under two",
				"a green glowing spring fountain under a person and a beast, red and green motes rising — shared health "
				"regeneration aura."),
		],
	},
	{
		"ru": "Небесный укротитель", "id": "sky_tamer", "orig": "Soul Breeder", "race": "Светлые эльфы",
		"parent": "Зверолов ← Breeder",
		"weapon": "двуручная булава, посох", "role": "два питомца сразу, усиление статов питомцев, небесный свет",
		"look": "светлый эльф в зелёно-кремовых одеждах с голубыми звёздами, деревянный посох с кристаллом-листом; два "
			"зверя, небесный свет.",
		"subject": "a LIGHT ELF CELESTIAL BEAST-TAMER in leaf-green and cream robes embroidered with sky-blue stars, "
			"holding a wooden staff with a leaf crystal; two creature companions, paw prints and heavenly starlight. "
			"Theme colors: leaf green, cream white, sky blue, starlight gold.",
		"skills": [
			S("twin_summon", "Двойной призыв", "Dual Summoning", "A",
				"призвать второго питомца: двое в бою сразу", "two summoning circles",
				"two creature silhouettes stepping out of two glowing summoning circles side by side — summon a second creature."),
			S("pet_might", "Мощь питомца", "Strength Boost", "P", "Сила питомцев выше", "glowing beast paw",
				"a beast paw with heavy muscles and a golden-red rune glow rising from it — creature strength."),
			S("sky_haven", "Небесное убежище", "Celestial Sanctuary", "A",
				"зона: в круге герой и питомцы получают меньше урона и лечатся", "starlight dome",
				"a glowing circle of starlight on the ground with a light dome over a person and a beast — celestial "
				"sanctuary zone."),
			S("sky_wrath", "Гнев небес", "Wrath of Heaven", "A", "питомец и луч небесного света бьют цель: урон светом",
				"beast and starlight beam",
				"a beast leaping forward while a falling beam of starlight strikes the same target — heavenly wrath."),
			S("pet_toughness", "Стойкость питомца", "Vitality Boost", "P", "Выносливость питомцев выше",
				"beast with bark shield",
				"a beast silhouette covered by a green-gold shield of bark-like fur — creature vitality."),
			S("pet_intellect", "Разум питомца", "Intelligence Boost", "P", "Интеллект питомцев выше",
				"beast with violet star",
				"a beast head with a glowing violet star on its forehead — creature intellect."),
			S("pet_wisdom", "Мудрость питомца", "Wisdom Boost", "P", "Мудрость питомцев выше",
				"beast with moon drop",
				"a beast head with closed eyes and a calm blue moon-shaped drop on its forehead — creature wisdom."),
		],
	},
	# ======================== Тёмные эльфы ========================
	{
		"ru": "Ночной клинок", "id": "nightblade", "orig": "Assassin", "race": "Тёмные эльфы", "parent": "Наёмник ← Strider",
		"weapon": "кинжалы, одноручные мечи (по одному или по два)",
		"role": "убийца ближнего боя: невидимость, рывки, серии ударов, звуковые лезвия",
		"look": "тёмный эльф в чёрно-фиолетовой коже с капюшоном и шарфом, два изогнутых кинжала или короткие мечи; дым "
			"теней, алые росчерки, звуковые дуги.",
		"subject": "a DARK ELF SHADOW ASSASSIN in black-and-violet leather with a hood and a scarf, two curved daggers or "
			"two short swords; shadow smoke, crimson cuts and sonic blade arcs. Theme colors: black, deep violet, "
			"crimson red, silver steel, a little cyan.",
		"skills": [
			S("shadow_cloak", "Плащ теней", "Cloak of Shadow", "T",
				"пока включено, герой незаметен: звери замечают ближе, первый удар сильнее", "figure in smoke cloak",
				"a hooded figure dissolving into a black-violet smoke cloak, only glowing eyes visible — stealth cloak."),
			S("gloom_stab", "Укол из мрака", "Shadow Stab", "A", "тяжёлый укол из незаметности",
				"dagger from shadow swirl",
				"a dagger thrusting out of a swirl of black shadow with a crimson cut flash — stab from the shadows."),
			S("crossed_parry", "Скрещённые клинки", "Cross Block", "A", "4 с отражает удары двумя клинками",
				"two daggers blocking claw",
				"two daggers crossed in an X blocking a beast claw, a bright spark at the contact point — cross parry."),
			SHARED("swift_dash"),
			S("rage_twist", "Искажённая ярость", "Distortion of Rage", "A", "15 с урон героя выше, защита ниже",
				"warped crimson aura",
				"a dark elf silhouette inside a warped crimson-violet aura with twisted energy lines — distorted rage buff."),
			S("death_waltz", "Смертельный вальс", "Deadly Dancing", "A", "танец клинков: много ударов по цели",
				"daggers whirling ribbon",
				"two daggers whirling around a target inside a ribbon of crimson slashes — deadly blade dance."),
			S("gloom_crash", "Удар сумрака", "Shadow Crash", "A", "прыжок из тени: удар по площади",
				"shadow drop impact",
				"a shadow figure dropping from above with daggers, a black-violet impact ring on the ground — shadow crash."),
			S("eye_dust", "Пыль в глаза", "Blinding Dust", "A", "6 с зверь бьёт мимо",
				"dust thrown into eyes",
				"a hand throwing a cloud of grey-violet dust into a beast's eyes — blinding powder."),
			S("sonic_edge", "Звуковое лезвие", "Sonic Blade", "A", "взмах выпускает звуковую волну-лезвие",
				"cyan sonic crescent",
				"a dagger slash releasing a cyan crescent-shaped sound-wave blade — sonic blade."),
			S("gloom_rush", "Рывок сумрака", "Shadow Rush", "A", "рывок сквозь зверей: удар всем на пути",
				"dash through beasts",
				"a dark elf dashing through two beast silhouettes, leaving a black-violet afterimage trail — shadow rush."),
			S("gloom_wound", "Сумрачная рана", "Shadow Wound", "A", "рана тьмы: урон со временем, лечение зверя ниже",
				"dark glowing wound",
				"a deep black-violet slash wound glowing on a beast's hide with dark wisps leaking out — shadow wound."),
			S("death_wave", "Волна погибели", "Fatal Wave", "A", "волна клинков конусом перед героем",
				"cone of crimson blades",
				"a cone-shaped wave of crimson dagger blades fanning forward — fatal wave."),
			S("sonic_cross", "Звуковой крест", "Sonic Cross", "A", "два звуковых лезвия крест-накрест",
				"two sonic crescents X",
				"two cyan crescent-shaped sound-wave blades crossing in an X — sonic cross."),
			S("last_dusk", "Последний закат", "Apocalypse", "A", "огромный удар по площади — сильнейшее умение",
				"blood-red eclipse",
				"a blood-red eclipse sun above a dark elf raising two daggers, a crimson shockwave below — apocalyptic strike."),
			S("crimson_storm", "Алая буря", "Crimson Turbulence", "A", "вихрь алых ударов по всем вокруг",
				"whirling crimson arcs",
				"a whirling storm of crimson blade arcs around a center point — crimson turbulence."),
		],
	},
	{
		"ru": "Сумрачный стрелок", "id": "dusk_marksman", "orig": "Shadow Hunter", "race": "Тёмные эльфы",
		"parent": "Наёмник ← Strider",
		"weapon": "арбалет", "role": "стрелок: стойки огня, ловкости и сумрака, болты с ядом, оглушением и тьмой",
		"look": "тёмный эльф в чёрно-фиолетовом кожаном плаще с капюшоном, тяжёлый тёмный арбалет с фиолетовыми рунами; "
			"болты яда, огня и тьмы.",
		"subject": "a DARK ELF SHADOW CROSSBOWMAN in a black-violet hooded leather coat with a heavy dark crossbow "
			"engraved with violet runes (no letters); bolts of poison, fire and darkness. Theme colors: black, deep "
			"violet, poison green, crimson fire, electric yellow, silver steel.",
		"skills": [
			S("quiet_menace", "Тихая угроза", "Subtle Enmity", "P", "угроза ниже: звери реже переключаются на героя",
				"crossbow in mist, fading marks",
				"a crossbow resting in a dim violet mist with a calm half-closed eye, red aggro marks fading away — low threat."),
			S("venom_bolt", "Ядовитый болт", "Poison Shot", "A", "болт с ядом: урон со временем 10 с",
				"dripping venom bolt",
				"a crossbow bolt with a dripping green venom head and a trail of toxic bubbles — poison bolt."),
			S("fire_stance", "Огненная стойка", "Burning Style", "T",
				"пока включено, болты + урон огнём (одна стойка за раз)", "flaming crossbow",
				"a crossbow wreathed in crimson flames with a burning bolt loaded — fire style stance."),
			S("swift_stance", "Лёгкая стойка", "Agile Style", "T",
				"пока включено, скорость атаки и уклонение выше (одна стойка за раз)", "crossbow with wind feather",
				"a crossbow with silver wind streaks and a light feather, fast motion — agile style stance."),
			S("dusk_stance", "Сумрачная стойка", "Dusk Style", "T",
				"пока включено, болты + урон тьмой, крит выше (одна стойка за раз)", "crossbow in shadow smoke",
				"a crossbow wrapped in black-violet shadow smoke with a crescent moon behind it — dusk style stance."),
			S("swift_dash", "Внезапный рывок", "Sudden Rush", "A",
				"мгновенный рывок к цели или от неё", "blink with afterimages",
				"a dark elf silhouette blinking forward with a sharp violet streak and afterimages — sudden dash."),
			S("stun_bolt", "Оглушающий болт", "Stun Shaft", "A", "урон и оглушение 3 с", "blunt bolt and stun star",
				"a heavy blunt bolt hitting a beast's head with a big yellow stun star — stunning bolt."),
			S("crushing_bolt", "Сокрушающий болт", "Bolt of Destruction", "A", "мощный выстрел: большой урон, защита ниже",
				"bolt shattering plate",
				"a massive dark bolt shattering a stone armor plate in an explosion of shards — bolt of destruction."),
			S("bolt_volley", "Беглая очередь", "Rapid Fire", "A", "пять быстрых выстрелов подряд",
				"five bolts in a line",
				"five bolts flying in a tight rapid line from one crossbow, motion blur — rapid fire."),
			S("flaw_aim", "Прицел в слабину", "Defect Aiming", "A", "выстрел в слабое место: крит наверняка, защита ниже",
				"crosshair on armor crack",
				"a crosshair locked on a glowing crack in a beast's armor plate — aim at the weak spot."),
			S("taunt_bolt", "Дразнящий болт", "Provoke Shot", "A", "зверь переключается на героя",
				"bolt with red aggro burst",
				"a bolt hitting a beast with a red angry burst, the beast turning toward the shooter — provoking shot."),
			S("glare_bolt", "Слепящий болт", "Blinding Shot", "A", "урон, и зверь бьёт мимо",
				"bolt flashing at eye",
				"a bolt bursting into a white-violet blinding flash right in front of a beast's eye — blinding shot."),
			S("wailing_bolts", "Воющие болты", "Cry of Arrows", "A", "залп воющих болтов по площади: урон и страх",
				"fan of wailing bolts",
				"a fan of screaming bolts with ghostly wailing wisps flying out — howling volley."),
			S("payback_bolt", "Ответный болт", "Vengeance Shot", "A", "выстрел тем сильнее, чем меньше HP у героя",
				"bolt from cracked heart",
				"a crossbow firing a crimson glowing bolt from behind a cracked heart emblem — revenge shot."),
			S("abyss_hail", "Град бездны", "Hail of the Underworld", "A", "дождь тёмных болтов на площадь",
				"bolts from black portal",
				"dark violet bolts raining down from a black portal in the sky onto an area — hail from the abyss."),
			S("spiral_bolt", "Спиральный болт", "Spiral Arrow", "A", "вращающийся болт пробивает всех на линии",
				"drilling spiral bolt",
				"a spinning bolt with a spiral wind tunnel around it drilling forward — spiral bolt."),
			S("storm_bolt", "Грозовой болт", "Thunderbolt Arrow", "A", "болт-молния: урон и оглушение рядом с целью",
				"bolt turned to lightning",
				"a bolt turned into a jagged yellow lightning strike hitting a beast — thunder bolt."),
			S("dark_cascade", "Каскад мрака", "Cascade of Darkness", "A", "водопад тьмы на площадь — сильнейшее умение",
				"waterfall of darkness",
				"a waterfall of black-violet darkness pouring down onto the ground from above, splashing shadows — cascade "
				"of darkness."),
		],
	},
	{
		"ru": "Разрушитель", "id": "destroyer", "orig": "Chaos Magician", "race": "Тёмные эльфы",
		"parent": "Неофит ← Dark Magician",
		"weapon": "одноручный и двуручный посох", "role": "маг разрушения: огонь, молнии, метеоры, слом чужих чар",
		"look": "тёмный эльф в тёмно-фиолетовой мантии с алым, чёрный посох с горящим фиолетовым кристаллом; руны "
			"разрушенных заклинаний, метеоры.",
		"subject": "a DARK ELF CHAOS MAGE of fire, lightning and meteors in dark violet robes with crimson accents, "
			"holding a black staff with a burning purple crystal; shattered spell circles and falling stars. Theme "
			"colors: deep violet, crimson fire, electric cyan-violet lightning, black, meteor orange.",
		"skills": [
			S("flame_blast", "Огненный взрыв", "Fire Blast", "A", "огненный шар взрывается у цели", "exploding fireball",
				"a crimson fireball exploding against a target in a burst of flame — fire blast."),
			S("thunder_bane", "Громовая кара", "Thunder Slayer", "A", "мощная молния по цели", "huge lightning strike",
				"a massive violet-cyan lightning bolt striking down from a staff tip onto a target — lightning slayer."),
			S("void_spiral", "Спираль мрака", "Dark Spiral", "A", "спираль тьмы: урон и маг. защита зверя ниже",
				"dark spiral vortex",
				"a swirling black-violet spiral vortex drilling into a target — dark spiral."),
			S("spell_skin", "Колдовская кожа", "Magic Skin", "T",
				"пока включено, часть урона по герою снимает MP вместо HP", "runic mana skin",
				"a translucent violet runic skin of light covering an arm, incoming damage turning into blue mana sparks — "
				"mana shield."),
			SHARED("null_ward"),
			S("arcane_focus", "Сосредоточение чар", "Heed of the Conjuror", "A", "20 с маг. атака выше",
				"eye in spell circle",
				"a glowing violet eye inside a spell circle above a staff, focused energy lines — magical focus."),
			S("spell_shatter", "Слом чар", "Spell Breaker", "A", "урон, снимает усиления зверя и прерывает его умение",
				"staff smashing magic circle",
				"a staff smashing a glowing violet magic circle into shards — spell breaker."),
			S("quick_casting", "Скорое колдовство", "Haste of Conjuror", "A", "15 с скорость каста выше",
				"spinning violet hourglass",
				"a staff with a small hourglass of violet sand spinning fast inside motion streaks — faster casting."),
			S("unweave", "Снятие чар", "Dispel Magic", "A", "снимает ослабления с героя и питомца",
				"hand unraveling threads",
				"a hand unraveling dark violet magic threads wrapped around a small figure — dispel."),
			S("star_fall", "Звездопад", "Meteor Shower", "A", "метеоры падают на площадь", "falling meteors",
				"several blazing meteors falling from a dark sky onto an area, fiery trails — meteor shower."),
			S("sky_rend", "Расколотое небо", "Heaven's Breaker", "A",
				"разлом неба: молнии и огонь по площади — сильнейшее умение", "crack in the sky",
				"a crack in the sky splitting open with violet light and pouring lightning and fire downward — sky-breaking "
				"ultimate."),
		],
	},
	{
		"ru": "Проклинатель", "id": "hexer", "orig": "Warlock", "race": "Тёмные эльфы", "parent": "Неофит ← Dark Magician",
		"weapon": "одноручный и двуручный посох", "role": "проклятия, смрад, страх и ловушки по площади, выжигание маны",
		"look": "тёмный эльф в рваной тёмно-фиолетовой и болотно-зелёной мантии, посох из чёрного дерева и кости с "
			"зелёным кристаллом; ядовитый туман, рунные ловушки, теневой огонь.",
		"subject": "a DARK ELF HEXER of curses and traps in tattered dark violet and swamp-green robes, holding a staff of "
			"black wood and bone with a sickly green crystal; poisonous mist, rune traps on the ground and shadow fire. "
			"Theme colors: deep violet, sickly green, black, shadow-purple flame, bone white.",
		"skills": [
			S("nightmare_shield", "Щит кошмара", "Shield of Nightmare", "A",
				"щит: урон по герою ниже, ударивший зверь — в страхе", "shield with nightmare eye",
				"a dark violet shield with a swirling nightmarish eye pattern pushing back a beast claw with fear wisps — "
				"nightmare shield."),
			S("stone_stench", "Окаменяющий смрад", "Petrified Stench", "A",
				"облако: звери замедлены и в конце каменеют (оглушение)", "stench turning legs to stone",
				"a grey-green stinking cloud around a beast whose legs are turning to stone — petrifying stench."),
			S("wind_chains", "Ветряные цепи", "Wide Windy Shackles", "A", "по площади: удары зверей реже",
				"wind chains on beasts",
				"several swirling grey-violet wind chains binding multiple beast silhouettes — wide wind shackles."),
			SHARED("spell_skin"),
			S("rot_mine", "Мина тлена", "Corpse Mine", "A", "тело зверя становится миной: взрыв по площади",
				"glowing fallen beast",
				"a fallen beast silhouette on the ground glowing sickly green with cracks of light, about to explode — "
				"corpse mine."),
			S("null_ward", "Немота чар", "Neutralize Magic", "A",
				"маг. защита зверя ниже, 5 с он не применяет умения", "spark under black seal",
				"a violet magic spark being snuffed out under a black hand-shaped seal — neutralize magic."),
			S("dread_trap", "Ловушка ужаса", "Fear Trap", "A", "ловушка: попавшие звери в страхе",
				"rune trap with fleeing beast",
				"a glowing violet rune trap on the ground with a terrified beast fleeing from a rising ghostly shadow — "
				"fear trap."),
			S("black_flame", "Чёрное пламя", "Steadfast Shadowflame", "A", "тёмное пламя: долгий урон со временем",
				"black flame on hide",
				"a black-violet flame burning steadily on a beast's hide and not going out — lasting shadowflame."),
			S("blast_trap", "Взрывная ловушка", "Explosion Trap", "A", "ловушка: взрыв по площади",
				"exploding rune trap",
				"a rune trap on the ground bursting in a violet-orange explosion — explosive trap."),
			S("daze_stench", "Дурманный смрад", "Stench of Armistice", "A", "облако: звери не атакуют 4 с",
				"beast with limp claws in cloud",
				"a heavy purple-green cloud around a beast whose claws hang limp and droop — stench that stops attacks."),
			S("bolt_trap", "Молниевая ловушка", "Lightning Trap", "A", "ловушка: урон молнией и оглушение",
				"lightning rune trap",
				"a rune trap crackling with violet lightning jolting a beast, yellow stun star — lightning trap."),
			S("shadow_wither", "Теневое иссушение", "Shadow Atrophia", "A", "зверь слабеет: атака и защита ниже",
				"withering paw",
				"a beast's paw withering and thinning under creeping black shadow veins — shadow atrophy."),
			S("horror_fog", "Туман ужаса", "Fog of Horror", "A", "туман: страх всем зверям по площади",
				"violet fog with eyes",
				"a thick violet fog with glowing frightened eyes and fleeing beast silhouettes — fog of horror."),
			S("frailty_stench", "Смрад немощи", "Stench of Frailty", "A", "облако: защита зверей по площади ниже",
				"crumbling rusted armor",
				"a green-grey stench cloud making a beast's armor plates crumble and rust — stench of frailty."),
			S("mind_fog", "Помрачение", "Mind Crisis", "A", "зверь в смятении: бьёт мимо и замедлен",
				"dizzy spirals on head",
				"a beast head with swirling dizzy violet spirals around it and a cracked glowing mind sigil — mind crisis."),
			S("mana_scorch", "Выжигание маны", "Mana Burn", "A", "выжигает ману зверя и бьёт уроном от неё",
				"mana orb burning to ash",
				"a blue mana orb burning in black-violet flames and turning to ash — mana burn."),
			S("gloom_might", "Сила мрака", "Strength of Darkness", "T",
				"пока включено, маг. атака выше, HP героя понемногу уходит", "fist in shadow flame",
				"a clenched fist wrapped in black-violet shadow flames with dark veins — strength of darkness."),
		],
	},
	{
		"ru": "Призыватель бездны", "id": "abyss_caller", "orig": "Battle Summoner", "race": "Тёмные эльфы",
		"parent": "Адепт ← Sorcerer",
		"weapon": "кинжал, посохи, щит", "role": "два питомца в бою, кровавые ауры для себя и зверей, быстрые заклинания",
		"look": "тёмный эльф в тёмно-алой и чёрной мантии, ритуальный кинжал и тёмный посох; кровавые ауры, фиолетовое "
			"пламя бездны, два зверя.",
		"subject": "a DARK ELF BATTLE SUMMONER bound to two creatures by blood: dark crimson-and-black robes, a ritual "
			"dagger and a dark staff; blood-red auras, abyssal violet flames, beast spirits. Theme colors: blood crimson, "
			"black, abyss violet, bone white, a little gold.",
		"skills": [
			SHARED("twin_summon"),
			S("dagger_cyclone", "Кинжальный смерч", "Dirk Tornado", "A", "смерч ритуальных кинжалов по площади",
				"tornado of daggers",
				"a tornado of spinning ritual daggers with crimson streaks — dagger tornado."),
			S("twin_impact", "Двойной натиск", "Double Impact", "A", "герой и питомец бьют цель одновременно",
				"dagger and claw strike",
				"a dark elf dagger and a beast claw striking the same target at once, two crimson impact bursts — double impact."),
			S("swift_word", "Быстрое слово", "Speedy Spell", "A", "10 с заклинания героя без каста",
				"fast flying sigil",
				"a crimson spell sigil (abstract shape, no letters) flying fast from a fingertip with motion streaks, a tiny "
				"broken hourglass behind — instant spell."),
			S("abyss_might", "Мощь бездны", "Might of the Underworld", "T",
				"пока включено, атака героя и питомцев выше, HP героя понемногу уходит", "abyss flame into fist",
				"a black-violet abyssal flame rising from a crack in the ground into a clenched fist — might of the abyss."),
			S("crimson_aura", "Алая аура", "Blood Aura", "U", "пока включено, герой и питомцы вытягивают HP ударами",
				"blood mist aura",
				"a crimson blood mist aura swirling around a person and a beast with red droplets flowing inward — blood aura."),
			S("soul_aura", "Аура духа", "Spirit Aura", "U", "пока включено, герою и питомцам MP восстанавливается быстрее",
				"ghostly mist aura",
				"a pale violet ghostly mist aura around a person and a beast with blue wisps — spirit aura."),
			S("abyss_aura", "Аура бездны", "Aura of Halisha", "U", "пока включено, урон героя и питомцев выше",
				"dark abyssal swirl aura",
				"a dark violet-black aura with a glowing abyssal swirl around a person and a beast silhouette — aura of "
				"the abyss."),
			S("abyss_seal", "Печать бездны", "Seal of Halisha", "P", "все статы питомцев выше",
				"seal on beast forehead",
				"a black-and-crimson circular seal with abstract abyssal shapes (no letters) glowing on a beast's forehead — "
				"seal of the abyss."),
		],
	},
]

RACE_ORDER = ["Люди", "Светлые эльфы", "Тёмные эльфы"]


# ---------------------------------------------------------------- Сборка и проверки -------------------------------
def existing_ids() -> set:
	ids = set()
	for f in ("data_job_skills.gd", "data_hero_skills.gd", "data_pet_skills.gd"):
		with open(os.path.join(ROOT, f), encoding="utf-8") as fh:
			ids |= set(re.findall(r'^\s*"([a-z0-9_]+)": \{', fh.read(), re.M))
	icons = os.path.join(ROOT, "assets", "icons", "skills")
	ids |= {n.split(".")[0] for n in os.listdir(icons)}
	return ids


def build():
	"""Листы: [(глава, номер листа, всего листов, сетка, [умения])]; где нарисован каждый id."""
	defined = {}
	for job in JOBS:
		for s in job["skills"]:
			if "shared" not in s:
				assert s["id"] not in defined, "дубль id " + s["id"]
				defined[s["id"]] = (job, s)
	for job in JOBS:
		for s in job["skills"]:
			if "shared" in s:
				assert s["shared"] in defined, "нет общего умения " + s["shared"]
				assert defined[s["shared"]][0] is not job
	have = existing_ids()
	clash = sorted(i for i in defined if i in have)
	assert not clash, "id уже есть в игре: " + ", ".join(clash)
	wolf_new = [s["id"] for s in WOLF if s["id"] not in WOLF_HAVE]
	pet_ids = set()
	with open(os.path.join(ROOT, "data_pet_skills.gd"), encoding="utf-8") as fh:
		pet_ids = set(re.findall(r'^\s*"([a-z0-9_]+)": \{', fh.read(), re.M))
	common = {"provoke", "deep_spring", "daze", "mending", "calm_mind", "keen_eye", "endless_life", "ancestor_gift"}
	for i in wolf_new:
		if i in common:
			assert i in pet_ids, "общего умения нет у питомцев: " + i
		else:
			assert i not in have and i not in defined, "id волка занят: " + i
	assert len(WOLF) == 18 and len(wolf_new) == 14
	where = {}
	sheets = []
	sheets.append(("wolf", WOLF, GRIDS[18]))
	for job in JOBS:
		drawn = [s for s in job["skills"] if "shared" not in s]
		assert len(drawn) in GRIDS, "%s: нет сетки на %d" % (job["ru"], len(drawn))
		sheets.append((job, drawn, GRIDS[len(drawn)]))
	plan = []  # (глава, i, k, (c, r, size), skills)
	for owner, drawn, grids in sheets:
		k = len(grids)
		pos = 0
		for i, g in enumerate(grids):
			n = g[0] * g[1]
			part = drawn[pos:pos + n]
			assert len(part) == n
			plan.append((owner, i + 1, k, g, part))
			for j, s in enumerate(part):
				where[s["id"]] = (owner, i + 1, k, j + 1)
			pos += n
		assert pos == len(drawn)
	return plan, where, defined


# ---------------------------------------------------------------- Word ---------------------------------------------
FONT = "Calibri"


def _font(run, size=None, bold=False):
	run.font.name = FONT
	rpr = run._element.get_or_add_rPr()
	rf = rpr.find(qn("w:rFonts"))
	if rf is None:
		rf = OxmlElement("w:rFonts")
		rpr.insert(0, rf)
	for a in ("w:ascii", "w:hAnsi", "w:cs", "w:eastAsia"):
		rf.set(qn(a), FONT)
	if size:
		run.font.size = Pt(size)
	if bold:
		run.bold = True


def para(doc, text, size=11, after=6, style=None):
	p = doc.add_paragraph(style=style) if style else doc.add_paragraph()
	_font(p.add_run(text), None if style else size)
	if not style:
		p.paragraph_format.space_after = Pt(after)
	return p


def heading(doc, text, level):
	p = doc.add_heading(level=level)
	_font(p.add_run(text))
	return p


def prompt_box(doc, lines):
	"""Промт в рамке: одна ячейка таблицы, строка промта — абзац."""
	t = doc.add_table(rows=1, cols=1)
	t.alignment = WD_TABLE_ALIGNMENT.CENTER
	tblPr = t._tbl.tblPr
	borders = OxmlElement("w:tblBorders")
	for side in ("top", "left", "bottom", "right"):
		b = OxmlElement("w:" + side)
		b.set(qn("w:val"), "single")
		b.set(qn("w:sz"), "8")
		b.set(qn("w:space"), "0")
		b.set(qn("w:color"), "9DB3CC")
		borders.append(b)
	tblPr.append(borders)
	width = OxmlElement("w:tblW")
	width.set(qn("w:type"), "pct")
	width.set(qn("w:w"), "5000")
	for old in tblPr.findall(qn("w:tblW")):
		tblPr.remove(old)
	tblPr.append(width)
	cell = t.rows[0].cells[0]
	tcPr = cell._tc.get_or_add_tcPr()
	shd = OxmlElement("w:shd")
	shd.set(qn("w:val"), "clear")
	shd.set(qn("w:color"), "auto")
	shd.set(qn("w:fill"), "F3F6FA")
	tcPr.append(shd)
	first = True
	for line in lines:
		p = cell.paragraphs[0] if first else cell.add_paragraph()
		first = False
		p.paragraph_format.space_after = Pt(0)
		_font(p.add_run(line), 10.5)
	doc.add_paragraph().paragraph_format.space_after = Pt(4)


def layout_lines(n, cols, rows, size, pet):
	frames = ("ACTIVE skills = violet/silver frame, PASSIVE skills = gold frame, TOGGLE skills = teal frame." if pet else
		"ACTIVE skills = violet/silver frame, PASSIVE skills = gold frame, TOGGLE and AURA skills = teal frame.")
	return [
		"LAYOUT (very important, I will cut the icons automatically):",
		"- Landscape image 1536x1024, pure flat WHITE background (#FFFFFF), no gradient, no texture, no shadows on the "
		"background.",
		"- Exactly %d icons in a strict grid: %d columns x %d %s, all icons the same size (about %dx%d px), evenly spaced, "
		"at least 40 px of empty white space between icons and around the edges." % (
			n, cols, rows, "row" if rows == 1 else "rows", size, size),
		"- Each icon is a fully opaque ROUNDED SQUARE tile with its own dark frame; nothing may stick out of the tile.",
		"- Frame color by type: " + frames,
		"- NO text, NO letters, NO numbers, NO captions, NO logos, NO watermark anywhere.",
		"- Original designs only, do not imitate icons from any existing game.",
	]


def sheet_prompt(skills, i, k, grid, subject, pet):
	cols, rows, size = grid
	n = len(skills)
	out = ["Create ONE image: a sprite sheet of %d skill icons for an original anime fantasy mobile MMO (cel-shaded, "
		"Genshin-Impact-like painterly style, clean bold shapes, readable at small size)." % n]
	if k > 1:
		out.append("This is sheet %d of %d for the same character class: keep exactly the same style, palette and frame "
			"look on every sheet." % (i, k))
	out.append("Subject of the whole set: " + subject)
	out.append("")
	out += layout_lines(n, cols, rows, size, pet)
	out.append("")
	out.append("GRID MAP (%d %s of %d; the numbers are only for this list, never draw them):" % (
		rows, "row" if rows == 1 else "rows", cols))
	for r in range(rows):
		row = skills[r * cols:(r + 1) * cols]
		out.append("Row %d: " % (r + 1) + ", ".join("%d %s" % (r * cols + j + 1, s["short"]) for j, s in enumerate(row)) + ".")
	out.append("")
	out.append("ICONS, left to right, top to bottom:")
	for r in range(rows):
		out.append("Row %d:" % (r + 1))
		for j, s in enumerate(skills[r * cols:(r + 1) * cols]):
			out.append("%d. %s: %s" % (r * cols + j + 1, TYPE_EN[s["type"]], s["desc"]))
	return out


def order_line(skills):
	return "Порядок: " + ", ".join("%d %s" % (j + 1, s["ru"]) for j, s in enumerate(skills)) + "."


def icons_word(n):
	if n % 10 == 1 and n % 100 != 11:
		return "значок"
	if 2 <= n % 10 <= 4 and not 12 <= n % 100 <= 14:
		return "значка"
	return "значков"


def sheet_heading(n, i, k, grid):
	g = "сетка %d×%d" % (grid[0], grid[1])
	if k == 1:
		return "%d %s, %s" % (n, icons_word(n), g)
	return "Лист %d из %d: %d %s, %s" % (i, k, n, icons_word(n), g)


def count_line(n, k):
	if k == 1:
		return "Значков: %d, один лист." % n
	return "Значков: %d, листов: %d." % (n, k)


def write_docx(plan, where, defined):
	doc = Document()
	st = doc.styles["Normal"]
	st.font.name = FONT
	st.font.size = Pt(11)
	total = sum(len(p[4]) for p in plan)
	t = doc.add_heading(level=0)
	_font(t.add_run("Промты: значки волка и вторых профессий"))
	para(doc, "Каждый промт — в рамке целиком: щёлкните в рамку, выделите весь её текст, скопируйте и вставьте в "
		"ChatGPT. Один запрос — один лист значков.")
	para(doc, "Это значки на будущее. В игре сейчас у волка 4 умения из 18, вторых профессий ещё нет; значки рисуем "
		"заранее, чтобы к реализации всё было готово. Названия профессий и умений, id и описания — свои (по оригиналу "
		"взяты только смысл и структура древа); справочник — tools/rappelz_future_skills_reference.md (id, наше "
		"название, оригинал, тип, суть, лист и номер). Порядок значков в каждом листе совпадает со справочником.")
	para(doc, "Всего листов: %d, значков на них: %d (волк — 18, из них 4 уже есть; вторые профессии — %d). Значки "
		"умений героя нарезаются в assets/icons/skills, значки волка — в assets/icons/pets/wolf." % (
			len(plan), total, total - 18))
	para(doc, "Умения, общие для двух вторых профессий, рисуются один раз — в листе одной из них (в справочнике у второй "
		"профессии стоит «лист <профессия>, №N»): Режущая волна (Громобой / Вожатый), Дрожь пламени (Заклинатель бурь / "
		"Громобой), Аура вызова (Страж света / Клинок рассвета), Аура солнца (Клинок рассвета / Страж света), Солнечное "
		"оружие (Светоносец / Пастырь), Солнечный доспех (Пастырь / Светоносец), Двойной призыв (Небесный укротитель / "
		"Призыватель бездны), Внезапный рывок (Сумрачный стрелок / Ночной клинок), Колдовская кожа (Разрушитель / "
		"Проклинатель), Немота чар (Проклинатель / Разрушитель).")
	para(doc, "Требования к сетке те же, что у значков профессий и питомцев: по ним я нарезаю автоматически. Если у "
		"профессии два листа — второй просите в том же чате («сделай второй лист в том же стиле»). Перед списком ICONS в "
		"каждом промте есть карта сетки GRID MAP — какие значки в каком ряду.")

	num = 0
	cur = None
	for owner, i, k, grid, skills in plan:
		if owner is not cur:
			cur = owner
			num += 1
			if owner == "wolf":
				heading(doc, "%d. Волк — питомец («Обычный», боец ловкости)" % num, 1)
				para(doc, WOLF_LOOK)
				para(doc, "Шаблон древа — как у пантеры, черепахи, фазана и кентавра: 11 общих умений с картинкой своего "
					"вида и 7 своих. Уже есть 4 значка: Внутренний огонь, Закалка, Свирепый натиск, Живучесть (№1, 2, 3, 6). "
					"На листе они нарисованы заново, чтобы стиль был единым; первая строка нарезки их пропускает («_»), "
					"вторая — заменяет новыми.")
				para(doc, count_line(18, 1) + " Новых — 14.")
			else:
				job = owner
				heading(doc, "%d. %s ← %s (%s, после профессии %s)" % (num, job["ru"], job["orig"], job["race"],
					job["parent"]), 1)
				para(doc, "Профессия: %s (id %s). Оружие: %s. Роль: %s. Облик: %s" % (
					job["ru"], job["id"], job["weapon"], job["role"], job["look"]))
				shared = [s["shared"] for s in job["skills"] if "shared" in s]
				if shared:
					parts = []
					for sid in shared:
						o, si, sk, sn = where[sid]
						parts.append("«%s» — лист «%s»%s, №%d" % (defined[sid][1]["ru"], o["ru"],
							(" %d" % si) if sk > 1 else "", sn))
					para(doc, "Общие с другой профессией (здесь не рисуются): " + "; ".join(parts) + ".")
				n_all = sum(len(p[4]) for p in plan if p[0] is job)
				para(doc, count_line(n_all, k))
		heading(doc, sheet_heading(len(skills), i, k, grid), 2)
		para(doc, order_line(skills), size=10, after=3)
		if owner == "wolf":
			ids = ",".join("_" if s["id"] in WOLF_HAVE else s["id"] for s in skills)
			para(doc, "Нарезка: %s assets/icons/pets/wolf %s" % (CUT, ids), size=9, after=2)
			para(doc, "Заменить и 4 готовых значка: %s assets/icons/pets/wolf %s" % (
				CUT, ",".join(s["id"] for s in skills)), size=9, after=6)
			subject, pet = WOLF_SUBJECT, True
		else:
			para(doc, "Нарезка: %s assets/icons/skills %s" % (CUT, ",".join(s["id"] for s in skills)), size=9)
			subject, pet = owner["subject"], False
		prompt_box(doc, sheet_prompt(skills, i, k, grid, subject, pet))
	doc.save(DOCX)


# ---------------------------------------------------------------- Справочник --------------------------------------
def write_md(plan, where, defined):
	users = {}
	for job in JOBS:
		for s in job["skills"]:
			users.setdefault(s.get("shared", s.get("id")), []).append(job)
	L = []
	L.append("# Будущие умения: волк и вторые профессии — справочник для значков")
	L.append("")
	L.append("Значки рисуются **заранее** (промты — `tools/Промты_значки_волк_и_вторые_профессии.docx`, генератор — "
		"`python3 -I tools/make_future_icons_doc.py`, он же пишет этот файл): в игре у волка пока 4 умения из 18, вторых "
		"профессий нет. Список умений и английские названия — из выгрузки базы оригинала (древо волка Wolf Pup / Warg / "
		"Fenrir, уникальные умения 15 вторых профессий). **Названия профессий и умений, id, тексты и значки — свои** (не "
		"переводы Rappelz); описаний в выгрузке нет, тип у большинства записан «passive» (особенность выгрузки) — тип и "
		"суть выбраны по смыслу названия и по аналогам первых профессий. Числа (урон, время, MP, уровни) — при "
		"реализации, по вики.")
	L.append("")
	L.append("Тип: А — активное, П — пассивное, Т — переключаемое, Аура — переключаемое для героя и питомца (рамка "
		"значка: А — фиолетовая, П — золотая, Т и Аура — бирюзовая). «Значок» — лист этой профессии и номер на нём, "
		"у общих умений — лист другой профессии. id не совпадают с умениями игры (`data_job_skills.gd`, "
		"`data_hero_skills.gd`, `data_pet_skills.gd`, `assets/icons/skills`) — генератор это проверяет.")
	L.append("")
	total = sum(len(p[4]) for p in plan)
	L.append("Листов: **%d**, значков на них: **%d** (волк 18, из них новых 14; вторые профессии — %d)." % (
		len(plan), total, total - 18))
	L.append("")

	def icon_ref(sid, own):
		o, i, k, n = where[sid]
		if o is own:
			return ("лист %d, №%d" % (i, n)) if k > 1 else "№%d" % n
		name = "волк" if o == "wolf" else o["ru"]
		return "лист «%s»%s, №%d" % (name, (" %d" % i) if k > 1 else "", n)

	L.append("## Волк — питомец («Обычный», боец ловкости)")
	L.append("")
	L.append("Порядок — шаблон древа других видов (пантера, черепаха, фазан, кентавр — `PetSkills.SPECIES_SKILLS`): 11 "
		"общих id (картинка у каждого вида своя) и 7 своих. Значки — `assets/icons/pets/wolf/<id>.png`, один лист 6×3. "
		"Уровни, стадии и пререквизиты — как у кентавра на тех же местах.")
	L.append("")
	L.append("| id | Наше название | ← Оригинал | Тип | Суть | Значок |")
	L.append("|---|---|---|---|---|---|")
	for s in WOLF:
		mark = " (есть)" if s["id"] in WOLF_HAVE else ""
		L.append("| `%s` | %s | %s | %s | %s | №%d%s |" % (s["id"], s["ru"], s["orig"], TYPE_RU[s["type"]],
			s["essence"], where[s["id"]][3], mark))
	L.append("")
	L.append("Не взято из древа волка: " + WOLF_SKIPPED)
	L.append("")
	L.append("## Вторые профессии")
	L.append("")
	L.append("| Раса | 1-я профессия | 2-я профессия (наше ← оригинал) | id | Оружие | Роль | Значков / листов |")
	L.append("|---|---|---|---|---|---|---|")
	for race in RACE_ORDER:
		for job in JOBS:
			if job["race"] != race:
				continue
			n = sum(len(p[4]) for p in plan if p[0] is job)
			k = sum(1 for p in plan if p[0] is job)
			L.append("| %s | %s | **%s** ← %s | `%s` | %s | %s | %d / %d |" % (race, job["parent"], job["ru"],
				job["orig"], job["id"], job["weapon"], job["role"], n, k))
	L.append("")
	L.append("Названия профессий свои: «Следопыт» — то, что справочник первых профессий берёг для лучника людей (id "
		"`pathfinder`: `ranger` занят переводом старых сохранений, `ClassData.LEGACY_CLASSES`); id профессий не совпадают "
		"с `ClassData` (у Наёмника id `assassin`, поэтому вторая профессия-убийца — `nightblade`).")
	for race in RACE_ORDER:
		L.append("")
		L.append("## " + race)
		for job in JOBS:
			if job["race"] != race:
				continue
			L.append("")
			L.append("### %s ← %s (после профессии %s)" % (job["ru"], job["orig"], job["parent"]))
			L.append("")
			n = sum(len(p[4]) for p in plan if p[0] is job)
			k = sum(1 for p in plan if p[0] is job)
			sh = sum(1 for s in job["skills"] if "shared" in s)
			L.append("id `%s`. Оружие: %s. Роль: %s. Облик: %s Умений: **%d** (в листах этой профессии %d %s, "
				"общих с другой профессией — %d). Листов значков: %d." % (job["id"], job["weapon"], job["role"],
				job["look"], len(job["skills"]), n, icons_word(n), sh, k))
			L.append("")
			L.append("| id | Наше название | ← Оригинал | Тип | Суть | Значок |")
			L.append("|---|---|---|---|---|---|")
			for s in job["skills"]:
				d = defined[s["shared"]][1] if "shared" in s else s
				other = [j["ru"] for j in users.get(d["id"], []) if j is not job]
				note = (" (общее с «%s»)" % other[0]) if other else ""
				L.append("| `%s` | %s | %s | %s | %s%s | %s |" % (d["id"], d["ru"], d["orig"], TYPE_RU[d["type"]],
					d["essence"], note, icon_ref(d["id"], job)))
	L.append("")
	with open(MD, "w", encoding="utf-8") as fh:
		fh.write("\n".join(L))


def main():
	plan, where, defined = build()
	write_docx(plan, where, defined)
	write_md(plan, where, defined)
	total = sum(len(p[4]) for p in plan)
	print("листов: %d, значков: %d (волк 18, вторые профессии %d, умений профессий %d)" % (
		len(plan), total, total - 18, sum(len(j["skills"]) for j in JOBS)))
	print("записано:", os.path.relpath(DOCX, ROOT), os.path.relpath(MD, ROOT))


if __name__ == "__main__":
	sys.exit(main())

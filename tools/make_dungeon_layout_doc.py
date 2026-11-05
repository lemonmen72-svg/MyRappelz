"""Документ-промт «Расстановка объектов подземелья по зонам» (0.35.1, просьба Максима): каждая зона — схема сверху
(reference/dungeon/zones/*.png, рисует tools — по сетке высот игры), что здесь по сюжету, рельеф и проходы,
предложение расстановки с логикой (id моделей dg_*) и промты картинок с нескольких ракурсов.
Запуск: python3 -I tools/make_dungeon_layout_doc.py  →  tools/Промты_расстановка_подземелья.docx
"""
import os
import sys

from docx import Document
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ZONES_DIR = os.path.join(ROOT, "reference", "dungeon", "zones")
OUT = os.path.join(ROOT, "tools", "Промты_расстановка_подземелья.docx")

STYLE = ("Style: anime cel-shading game art in the spirit of Genshin Impact, fully original design. Dark damp "
	"violet-grey cave rock with soft moss, sheer rock cliff walls about 7 m high (4 times a person's height) around "
	"the whole area, no sky, no ceiling visible. Light sources only: warm orange torches and braziers, acid-emerald "
	"glow (#39FF8A) of the Dark Sect runes and altars, teal and violet glowing crystals and mushrooms. Readable, "
	"uncluttered composition for a mobile game level: open walkable paths, objects grouped along walls and in "
	"meaningful clusters. No text, no letters, no numbers, no UI, no watermark.")

SCALE = "Include one small human adventurer figure (1.8 m tall) near the entrance for scale; no other characters."

GENERAL = [
	"Зачем этот документ. На скриншотах 0.35 объекты стояли «как высыпали»: без связи друг с другом, посреди "
	"проходов, камни на стенах. Прежде чем расставлять заново, договариваемся о расстановке картинками: по каждой зоне — "
	"схема сверху из самой игры, моё предложение, что где стоит и почему, и промты картинок с трёх ракурсов. Ты "
	"генерируешь, смотришь, правишь (можно прямо словами: «трон левее», «шатров меньше») — и только после твоего "
	"одобрения я расставляю объекты в игре ровно по картинке.",
	"Что уже сделано в 0.35.1 и на схемах: стены — сплошная скала 7 м (≈ 4 роста героя), камней на стенах нет; у залов "
	"свой уровень пола (вход +1.5 м, костяной зал −2, логово +1.5, шахта +3, тайник −1.5), между залами — спуски и "
	"подъёмы по коридорам, в залах — пологие волны пола, холмы и впадины; портал стоит на каменном уступе +5 м, от "
	"него вниз — лестница в зал входа; мостки к кораблю проходимы. Форму залов, воды и проходов не меняем (карта "
	"тебе нравится) — меняется только наполнение.",
	"Как пользоваться. В ChatGPT: приложи схему зоны (картинка из этого документа, она же лежит в репозитории — "
	"reference/dungeon/zones/<номер>_<зона>.png) и вставь промт целиком из рамки. Промт A — план сверху «по "
	"приложенной схеме», B — изометрия 3/4 от входа в зал, C — кадр как в игре (камера за героем). Лучше начинать с A: "
	"если план нравится, приложи к B и C ещё и картинку A — ChatGPT сохранит расстановку. Готовые картинки пришли мне "
	"с пометкой зоны — расставлю.",
	"Правила расстановки (по ним написаны все предложения ниже):",
]

RULES = [
	"Проходы свободны: от каждого входа в зал к каждому выходу — дорожка не уже 4–5 м (на схемах выходы — жёлтым). У "
	"концов мостов и у подножия лестницы — пусто на 3 м.",
	"Объекты — у стен, в углах и группами, у каждой группы есть смысл: лагерь вокруг костра, шатры полукругом, "
	"клетки рядом вдоль стены, алтарь по оси зала. Ничего «одиноко посреди пола».",
	"Главное в зале — одно и на виду: алтарь святилища, трон вожака, столбы костяного зала, корабль. Остальное "
	"подчинено ему (смотрит на него, стоит симметрично, ведёт к нему).",
	"Крупное и высокое — у стен, низкое и мелкое — ближе к середине (камера смотрит сверху-сзади: высокое посреди "
	"зала закрывает героя).",
	"Свет — по сюжету: тёплый огонь там, где живут (лагерь наёмников, гоблины, причал), зелёный — там, где секта "
	"(святилище, склеп, корабль). Огней на зал — 1–3 главных (телефон не любит много источников света).",
	"Где будут драться: в залах с минибоссами и у капитана — свободная арена ≈ 12 × 12 м (на корабле — вся палуба).",
]

# id → (название, размер Ш×В×Д, что это)
OBJECTS = [
	("dg_coral_altar", "Алтарь-череп из кораллов", "8 × 7.2 × 8", "главный алтарь секты, светится зелёным"),
	("dg_crypt_altar", "Малый алтарь склепа", "1 × 2 × 1", "постамент со знаком секты"),
	("dg_obelisk", "Проклятый обелиск", "2 × 4 × 2", "зелёные руны"),
	("dg_monolith", "Рунный монолит", "2.4 × 2.6 × 2.4", "камень со знаком глаза и щупалец"),
	("dg_rune_arch", "Рунная плита-арка", "4 × 0.8 × 2", "порог с рунами, лежит на полу"),
	("dg_spiral", "Светящаяся спираль", "4 × 0.8 × 0.8", "руна-спираль на полу"),
	("dg_witch_brazier", "Изумрудная жаровня", "1.3 × 1.6 × 1.1", "зелёный огонь"),
	("dg_candles", "Изумрудные свечи", "1 × 0.9 × 1", "группа свечей"),
	("dg_banner", "Знамя Изумрудного стража", "1.4 × 2.6 × 0.2", "знамя секты"),
	("dg_oracle", "Морской оракул", "1.6 × 1.8 × 0.9", "статуя секты"),
	("dg_prayer_rug", "Молитвенный коврик", "2.2 × 0.4 × 2.4", "ковёр культистов"),
	("dg_spire", "Мшистый клык (столб)", "3 × 4.4 × 3", "каменный столб"),
	("dg_crag", "Фиолетовая скала", "3.6 × 2.5 × 3", "валун"),
	("dg_moss_stones", "Мшистые камни", "2.6 × 1.8 × 2.6", "груда камней"),
	("dg_amethyst_spires", "Аметистовые шипы", "2.6 × 2.6 × 2.6", "кристаллы из камня"),
	("dg_crystal_purple", "Аметистовая корона", "1.8 × 1.8 × 1.8", "фиолетовые кристаллы, светятся"),
	("dg_crystal_blue", "Лазурные кристаллы", "1.8 × 1.8 × 1.8", "голубые кристаллы, светятся"),
	("dg_glowcaps", "Светящиеся грибы", "1.5 × 1.5 × 1.2", "бирюзовые грибы"),
	("dg_dripstone", "Аметистовые сталагмиты", "5 × 3.5 × 4", "островок сталагмитов, в воде или у стены"),
	("dg_cavern", "Мшистый грот", "7 × 7 × 7", "скальная арка-пещерка (у стены)"),
	("dg_cliffs", "Мшистые утёсы", "8 × 6.4 × 2.6", "кусок скалы (у стены)"),
	("dg_mine", "Заваленный вход в шахту", "6 × 3.6 × 6", "обвал с крепью — вкопан в стену"),
	("dg_ascent", "Каменная лестница", "3 × 3.6 × 6", "лестница от портала вниз"),
	("dg_tent", "Шалаш из вёсел и паруса", "3.5 × 2.5 × 3.5", "шатёр (гоблины, наёмники)"),
	("dg_bedroll", "Спальник", "2 × 0.25 × 1", "лежанка"),
	("dg_bearskin", "Медвежья шкура", "2.4 × 0.2 × 2.4", "ковёр-шкура"),
	("dg_nest", "Гнездо с добычей", "2.4 × 1 × 2.4", "лежанка гоблина"),
	("dg_stone_ring", "Кострище", "2 × 0.4 × 2", "потухший костёр"),
	("dg_cauldron", "Котёл на огне", "1.8 × 1.8 × 1.3", "светится тёплым"),
	("dg_table", "Стол", "2 × 1.4 × 1", "стол с кружками"),
	("dg_crates", "Ящики", "2 × 1.8 × 1.6", "штабель ящиков"),
	("dg_barrel", "Бочка", "0.9 × 1 × 0.85", "бочка в ракушках"),
	("dg_spoils", "Добыча торговца", "1.6 × 1 × 1.6", "мешки и тюки"),
	("dg_palisade", "Частокол с черепами", "3 × 2 × 0.8", "секция частокола"),
	("dg_barricade", "Баррикада", "3 × 1.8 × 0.3", "щиты-доски"),
	("dg_spikes", "Колья", "2.5 × 2.5 × 1.2", "заострённые колья"),
	("dg_barricade_moss", "Мшистая баррикада", "3 × 1.5 × 1.5", "старая завалившаяся баррикада"),
	("dg_totem", "Рогатый тотем из костей", "0.7 × 2.6 × 0.7", "тотем гоблинов"),
	("dg_throne", "Пиратский трон из костей", "3 × 2.4 × 2.7", "трон вожака"),
	("dg_prison", "Клетка-тюрьма", "1.8 × 1.8 × 1.6", "клетка"),
	("dg_armory", "Ржавая оружейная стойка", "2.2 × 1.1 × 2.2", "оружие и доспехи"),
	("dg_remains", "Останки", "1.6 × 0.6 × 1.6", "скелет на полу"),
	("dg_mariner", "Останки моряка", "1.8 × 0.4 × 1.8", "скелет моряка"),
	("dg_mossy_remains", "Мшистые останки", "1.8 × 1.1 × 1.6", "груда костей во мху"),
	("dg_leviathan", "Кости левиафана", "7 × 2.2 × 2.5", "скелет морского зверя"),
	("dg_relics", "Затонувшие реликвии", "1.4 × 1.4 × 1.1", "сундучок, кубки, свитки"),
	("dg_chest", "Сундук", "1.3 × 1 × 0.9", "закрытый сундук"),
	("dg_chest_open", "Открытый сундук с золотом", "1.3 × 1.3 × 1.3", "светится золотом"),
	("dg_gold", "Золото россыпью", "2 × 0.5 × 2", "монеты на полу"),
	("dg_hoard", "Пиратский клад", "2.6 × 1.3 × 2.6", "гора сокровищ"),
	("dg_torch", "Факел", "0.5 × 1.4 × 0.4", "факел на стойке"),
	("dg_brazier", "Жаровня", "0.7 × 2 × 0.7", "тёплый огонь"),
	("dg_lantern", "Медный фонарь", "0.5 × 1.2 × 0.5", "фонарь"),
	("dg_harbor_post", "Столб с фонарём", "0.6 × 3 × 0.5", "столб причала"),
	("dg_bell", "Сигнальный колокол", "2 × 2.6 × 0.8", "колокол причала"),
	("dg_dock", "Причальные мостки", "6 × 1.8 × 2.4", "кусок причала у берега"),
	("dg_pier", "Площадка мостков", "4 × 1.6 × 4", "площадка на сваях (уже стоит под мостками)"),
	("dg_wharf", "Пристань с навесом", "4 × 3.6 × 4", "домик-пристань"),
	("dg_rope_bridge", "Верёвочный мост", "2.2 × 1.6 × 8", "мост и мостки (уже стоят)"),
	("dg_net", "Рыболовная сеть", "3 × 3 × 1", "сеть на шестах"),
	("dg_anchor", "Древний якорь", "1.6 × 2.4 × 0.5", "якорь"),
	("dg_raft", "Плот", "2.5 × 0.8 × 3.5", "полузатонувший плот"),
	("dg_rowboat", "Лодка", "4 × 1.6 × 1.6", "лодка в ракушках"),
	("dg_siren", "Сирена из плавника", "2 × 3.4 × 2", "носовая фигура на камне"),
	("dg_mast", "Мачта «Глаз утопленника»", "2.5 × 7 × 0.8", "мачта из воды, зелёный глаз"),
	("dg_crows_nest", "Гнилое воронье гнездо", "2.5 × 7 × 0.8", "мачта с марсом"),
	("dg_mast_relic", "Обломок мачты", "7 × 1.4 × 4", "лежащая мачта"),
	("dg_helm", "Штурвал", "1.4 × 1.8 × 0.6", "штурвал корабля"),
	("dg_cannon", "Ржавая пушка", "2.4 × 1.2 × 1", "пушка"),
	("dg_ladder", "Верёвочная лестница", "2 × 3 × 0.3", "лестница у стены"),
	("dg_ship_deck", "Палуба корабля", "14 × 5.6 × 7", "корабль (уже стоит)"),
	("dg_ship_bow", "Нос корабля", "12 × 8.4 × 6", "нос корабля (уже стоит)"),
	("dg_wreck", "Изумрудный остов", "9 × 9 × 11.5", "затонувший остов"),
	("dg_kelp", "Золотая ламинария", "1 × 2 × 0.8", "водоросли у воды"),
	("dg_coral", "Лазурный коралл", "1.6 × 1.3 × 1.1", "коралл у воды"),
	("dg_tidepool", "Лужа с сокровищами", "2 × 1.2 × 2", "лужица в камнях"),
]

# Зоны: id картинки, заголовок, что по сюжету, рельеф и проходы, предложение [(группа, текст)], промты A/B/C
ZONES = [
	{
		"img": "01_vhod.png",
		"title": "1. Вход: брошенный лагерь наёмников и уступ с порталом",
		"story": "Здесь герой появляется из портала. По сюжету (задание «Следы у скал») — брошенный лагерь наёмников "
			"Корвена: они отступили, когда пошли следы гоблинов. Первое впечатление от подземелья: тревожно, но ещё "
			"«человеческое» место — тёплый огонь, вещи, баррикада, которая не устояла.",
		"geo": "Зал ≈ 21 × 31 м, пол +1.5 м. На юге — каменный уступ +5 м, на нём портал спиной к стене; от уступа на "
			"север вниз — лестница 6 м. Выходы — на восток: верхний коридор (северный) и коридор вдоль канала (южный).",
		"plan": [
			("Уступ с порталом", "две жаровни dg_brazier по бокам портала (у стены) — первый тёплый свет; больше на "
				"уступе ничего: сюда выходит герой."),
			("Подножие лестницы", "пара факелов dg_torch по бокам последней ступени; 3 м перед лестницей — пусто."),
			("Лагерь — западная стена", "два шатра dg_tent у западной стены входом на восток, перед ними спальники "
				"dg_bedroll; между шатрами и серединой — потухшее кострище dg_stone_ring, вокруг него стол dg_table с "
				"фонарём dg_lantern; в северо-западном углу — склад: ящики dg_crates и 2–3 бочки dg_barrel."),
			("Линия обороны — восток", "старая баррикада dg_barricade_moss и колья dg_spikes поперёк зала у восточных "
				"выходов, но с проходом 5 м у каждого выхода (её прорвали); у прохода — опрокинутый тотем гоблинов "
				"dg_totem — первый след гоблинов."),
			("Север зала", "останки наёмника dg_remains у баррикады, пара dg_moss_stones у стены — без мусора посреди "
				"пола."),
		],
		"prompts": [
			("A — план сверху", "Top-down orthographic view of a game level area following the ATTACHED SCHEME exactly "
				"(same cave outline, cliff walls, stone ledge with a glowing emerald portal on the south, stone staircase "
				"going down north from the ledge, two exits on the east). The area is an abandoned mercenary camp: two "
				"tents made of oars and old sails against the west wall with bedrolls in front, an extinguished stone "
				"fire ring with a wooden table and a copper lantern nearby, stacked crates and barnacle barrels in the "
				"north-west corner, two warm braziers beside the portal on the ledge, two torches at the foot of the "
				"stairs, a broken mossy barricade with sharpened stakes across the east side leaving a wide gap at each "
				"exit, a fallen horned bone totem of goblins at the gap, a skeleton of a fallen mercenary. Wide clear path "
				"from the stairs to both east exits. " + SCALE),
			("B — изометрия от портала", "Isometric 3/4 view of the same cave hall as in the ATTACHED SCHEME (and the "
				"attached top-down picture if given), seen from above the portal ledge looking north down the stone "
				"staircase into the hall: the abandoned mercenary camp along the left (west) wall, the broken barricade "
				"and the two dark exits on the right (east), warm firelight near the camp, the green glow of the portal "
				"behind the viewer lighting the stairs. " + SCALE),
			("C — как в игре", "Third-person mobile game screenshot: camera 12 m behind and 8 m above a small "
				"adventurer standing at the foot of the stone staircase, looking north-east across the abandoned "
				"mercenary camp of the attached plan toward the broken barricade and the two dark passages; 7 m sheer "
				"cliff walls around, warm torches and braziers, faint emerald glow from the portal ledge behind."),
		],
	},
	{
		"img": "02_koridory.png",
		"title": "2. Коридоры и канал с двумя мостами",
		"story": "Связка между залами. Верхний коридор — сухой, им ходили наёмники (факелы). Нижний — вдоль канала: "
			"сыро, водоросли, следы контрабандистов (лодка, ящики) и первый знак секты — светящаяся спираль у поворота к "
			"костяному залу.",
		"geo": "Верхний коридор шириной 8 м (север), коридор у канала 5 м (юг), между ними — стена. Канал шириной ≈ 6 м, "
			"через него два моста на юг: к тайнику (запад) и к причалу (восток). На востоке — развилка: на север к "
			"костяному залу, на восток длинный нижний коридор к шахте. Ответвление на север в середине — к святилищу.",
		"plan": [
			("Верхний коридор", "факелы dg_torch через каждые ≈ 12 м попеременно у северной и южной стены; больше "
				"ничего — сухой проход."),
			("Коридор у канала", "у кромки воды — водоросли dg_kelp и кораллы dg_coral группами по 2–3; у стены — "
				"dg_moss_stones; ни одного предмета на дорожке."),
			("Головы мостов", "у каждого моста по бокам — столбы с фонарями dg_harbor_post (за краем моста); у западного "
				"моста — ящики и бочки контрабандистов у стены."),
			("Канал", "лодка dg_rowboat, привязанная у восточного моста, и полузатонувший плот dg_raft в середине "
				"канала."),
			("Развилка у костяного зала", "на полу — светящаяся спираль секты dg_spiral (первый знак, «холодок»), по "
				"бокам прохода — два обелиска dg_obelisk; ответвление к святилищу — рунная плита dg_rune_arch на пороге."),
		],
		"prompts": [
			("A — план сверху", "Top-down orthographic view following the ATTACHED SCHEME exactly: two parallel cave "
				"corridors (the northern one dry, the southern one along a narrow teal water channel) and two rope "
				"bridges crossing the channel to the south. Dry corridor: torches on alternating walls every 12 m. "
				"Channel corridor: golden kelp and blue coral clusters at the waterline, mossy stones at the wall. At each "
				"bridge head two wooden posts with hanging lanterns beside the bridge; smugglers' crates and barrels "
				"near the western bridge; a moored barnacle rowboat and a half-sunken raft in the channel. At the "
				"north-east fork: a glowing emerald spiral rune on the floor with two cursed obelisks beside the "
				"passage; at the side passage to the sanctuary a rune slab on the threshold. Walkways completely clear. "
				+ SCALE),
			("B — изометрия", "Isometric 3/4 view from the south-west over the channel corridor of the ATTACHED SCHEME: "
				"the teal channel with two rope bridges, lantern posts at the bridge heads, the moored rowboat, the dry "
				"upper corridor behind the rock wall with its torches, and the emerald spiral rune glowing at the fork in "
				"the distance. " + SCALE),
			("C — как в игре", "Third-person mobile game screenshot: camera behind and above a small adventurer walking "
				"east along the wet channel corridor of the attached plan, a rope bridge with lantern posts on the "
				"right, kelp at the waterline, ahead the fork with the glowing emerald spiral rune between two obelisks; "
				"7 m sheer cliff walls."),
		],
	},
	{
		"img": "03_svyatilishe.png",
		"title": "3. Затопленное святилище (зал изумрудного алтаря) — минибосс Старший жрец",
		"story": "Святилище Секты Мрака: ритуальные бассейны, алтари, свечи, знамёна; здесь жрецы и Старший жрец, "
			"который «поддерживает печати». Самый «чистый» и симметричный зал — храм.",
		"geo": "Зал ≈ 42 × 32 м, пол 0; на севере — помост +0.9 м под главный алтарь; два бассейна с зелёной водой слева "
			"и справа от оси; вход один — с юга по коридору.",
		"plan": [
			("Главное — алтарь", "алтарь-череп dg_coral_altar на северном помосте по оси зала, лицом к входу; по бокам — "
				"пара изумрудных жаровен dg_witch_brazier и два малых алтаря dg_crypt_altar; за алтарём у северной стены — "
				"4 знамени dg_banner."),
			("Бассейны", "вокруг каждого — 4 группы свечей dg_candles; с внешней стороны каждого бассейна — рунный "
				"монолит dg_monolith; с внутренней — статуя-оракул dg_oracle лицом к воде."),
			("Неф", "между бассейнами — два ряда молитвенных ковриков dg_prayer_rug (по 3) лицом к алтарю, посередине — "
				"проход 4 м от входа к алтарю (арена Старшего жреца — перед помостом, ≈ 12 × 10 м)."),
			("Вход", "на пороге — рунная плита dg_rune_arch, по бокам — два обелиска dg_obelisk."),
			("Углы", "кристаллы dg_crystal_purple и грибы dg_glowcaps — мягкий свет; у помоста сбоку — останки "
				"жертв dg_mossy_remains."),
		],
		"prompts": [
			("A — план сверху", "Top-down orthographic view following the ATTACHED SCHEME exactly: a symmetrical cave "
				"temple of the Dark Sect with two glowing acid-green ritual pools left and right of the central axis and a "
				"raised stone dais on the north. On the dais a huge coral-and-skull altar facing south, flanked by two "
				"emerald witchfire braziers and two small crypt altars, four sect banners (eye above tentacles symbol) on "
				"the north wall behind it. Each pool ringed by emerald candles, a rune monolith on its outer side, a "
				"stone oracle statue on its inner side facing the water. Between the pools two rows of worn prayer rugs "
				"facing the altar with a 4 m clear aisle in the middle. Rune slab on the south threshold flanked by two "
				"obelisks. Glowing violet crystals and mushrooms in the corners. " + SCALE),
			("B — изометрия от входа", "Isometric 3/4 view from the south entrance of the sanctuary of the ATTACHED "
				"SCHEME looking north along the central aisle toward the coral skull altar on its dais, the two green "
				"glowing pools left and right, prayer rugs in rows, candles, banners; eerie emerald light. " + SCALE),
			("C — как в игре", "Third-person mobile game screenshot: camera behind and above a small adventurer "
				"standing in the aisle between the two glowing pools of the attached plan, looking north at the coral "
				"skull altar on the raised dais with braziers and banners; open arena in front of the dais; 7 m cliff "
				"walls."),
		],
	},
	{
		"img": "04_kostyanoy_zal.png",
		"title": "4. Костяной зал (склеп) — минибосс Мёртвый рыцарь",
		"story": "Нежить — мёртвые матросы и рыцари; два каменных столба, цепи, древние печати; Мёртвый рыцарь — страж "
			"прохода. После победы герой находит алтари и следы жертвоприношений (фигура с посохом и поклоняющиеся ей). "
			"Самый тёмный и мрачный зал.",
		"geo": "Самый большой зал ≈ 54 × 40 м, пол −2 м (спуск из коридоров); на севере в середине — подъём +1.2 м, на "
			"западе — впадина. Входы: с запада (коридоры) и с востока (к логову гоблинов).",
		"plan": [
			("Два столба", "два каменных столба dg_spire по оси восток–запад, ≈ 11 м друг от друга; между ними — арена "
				"Мёртвого рыцаря (≈ 12 × 12 м, пусто), у подножия столбов — останки dg_mossy_remains."),
			("Тайное место за рыцарем (северный подъём)", "алтарь склепа dg_crypt_altar, кольцо камней dg_stone_ring со "
				"спиралью dg_spiral, свечи dg_candles, обелиск dg_obelisk с глазом и щупальцами, останки жертв "
				"dg_remains — это то, что герой «находит» после рыцаря."),
			("Вдоль южной стены", "3–4 клетки dg_prison в ряд, у них — скелеты dg_mariner."),
			("Запад, впадина", "кости левиафана dg_leviathan поперёк впадины, вокруг — dg_moss_stones."),
			("Восток", "ржавые оружейные стойки dg_armory (снаряжение мёртвых рыцарей) у стены, знамя секты dg_banner; "
				"оба прохода (запад и восток) — свободные 6 м."),
			("Свет", "почти нет: свечи у алтаря, грибы dg_glowcaps в углах, один факел у западного входа."),
		],
		"prompts": [
			("A — план сверху", "Top-down orthographic view following the ATTACHED SCHEME exactly: a vast dark bone hall "
				"of the undead. Two massive mossy stone pillars on the east–west axis 11 m apart with an empty arena "
				"between them and bone piles at their bases. On the raised northern part a hidden ritual spot: small crypt "
				"altar, ring of stones with a glowing emerald spiral rune, emerald candles, cursed obelisk with the eye "
				"above tentacles symbol, remains of sacrifices. Along the south wall a row of four iron prison cages "
				"with sailor skeletons. In the western hollow the huge skeleton of a sea leviathan. On the east rusty "
				"armour racks and a tattered sect banner. Clear wide paths from the west entrance to the east exit. "
				"Very dim: candles, teal glowing mushrooms, one torch. " + SCALE),
			("B — изометрия от запада", "Isometric 3/4 view from the west entrance of the bone hall of the ATTACHED "
				"SCHEME: the floor descends into the hall, two great stone pillars framing an empty arena, cages along "
				"the right wall, leviathan bones on the left, the faint green ritual spot on the raised far side. "
				+ SCALE),
			("C — как в игре", "Third-person mobile game screenshot: camera behind and above a small adventurer "
				"entering the bone hall of the attached plan between the two stone pillars, dark arena ahead, cages "
				"with skeletons along the wall, a faint emerald glow of the ritual altar on the rise in the background; "
				"7 m cliff walls."),
		],
	},
	{
		"img": "05_logovo_goblinov.png",
		"title": "5. Логово гоблинов — минибосс вождь гоблинов",
		"story": "Песчаные проходы, шатры из парусов, баррикады, добыча, сундуки, вождь в красном камзоле. Гоблины "
			"готовят исход наверх (бегут от нежити) — поэтому много собранных припасов.",
		"geo": "Зал ≈ 47 × 30 м, пол +1.5 м (подъём из костяного зала); на северо-востоке — холм +1.3 м. Входы: с запада "
			"(от костяного зала) и на юго-востоке (к шахте).",
		"plan": [
			("Ворота — запад", "частокол dg_palisade и колья dg_spikes по обе стороны ворот шириной 5 м, у ворот — два "
				"тотема dg_totem."),
			("Шатры", "4 шатра dg_tent полукругом вдоль северной и восточной стены входами к центру, у шатров — гнёзда "
				"dg_nest и шкуры dg_bearskin."),
			("Центр", "котёл dg_cauldron на огне (главный свет), вокруг — шкуры и стол dg_table с добычей."),
			("Вождь — холм на северо-востоке", "трон dg_throne лицом к воротам, перед ним медвежья шкура, вокруг — клад "
				"dg_hoard, сундук dg_chest, тюки dg_spoils, трофеи с корабля: штурвал dg_helm и пушка dg_cannon, наведённая "
				"на ворота. Перед холмом — арена вождя ≈ 12 × 10 м."),
			("Припасы к исходу — у южной стены", "штабели ящиков dg_crates, бочки dg_barrel, сети dg_net — у выхода к "
				"шахте, но не в проходе."),
		],
		"prompts": [
			("A — план сверху", "Top-down orthographic view following the ATTACHED SCHEME exactly: a sandy goblin lair "
				"in a cave. West gate: palisade with skulls and sharpened stakes on both sides of a 5 m opening, two "
				"horned bone totems at the gate. Four tents of oars and old sails in a semicircle along the north and east "
				"walls facing the centre, nests and bear skins by the tents. In the centre a cooking cauldron over fire "
				"with skins and a table of loot around it. On the north-east hill the goblin chief's bone throne facing "
				"the gate with a bear rug, piles of pirate treasure, a chest, sacks, a stolen ship's wheel and a rusty "
				"cannon aimed at the gate, open ground in front of the hill. Stacks of supply crates, barrels and nets along "
				"the south wall near the south-east exit. Clear paths gate→centre→exit. " + SCALE),
			("B — изометрия от ворот", "Isometric 3/4 view from the west gate of the goblin lair of the ATTACHED SCHEME "
				"looking east: palisade and totems in the foreground, tents in a semicircle, the glowing cauldron in the "
				"centre, the chief's throne on the hill in the back with treasure and a cannon. Warm firelight. "
				+ SCALE),
			("C — как в игре", "Third-person mobile game screenshot: camera behind and above a small adventurer passing "
				"through the palisade gate of the attached goblin lair, tents and the cauldron ahead, the bone throne on "
				"the hill in the distance; 7 m cliff walls; warm fire and lantern light."),
		],
	},
	{
		"img": "06_shahta.png",
		"title": "6. Шахта с обвалом",
		"story": "Тупик старой шахты: обвал, крепь, завал камней (здесь потом можно открыть проход дальше). "
			"Аметисты в стенах.",
		"geo": "Вытянутый зал ≈ 29 × 13 м, пол +3 м (самый высокий — подъём по длинному нижнему коридору и от логова). "
			"Заваленный вход в шахту — в середине южной стены. Входы: с запада (нижний коридор) и с северо-востока (от "
			"логова).",
		"plan": [
			("Обвал", "заваленный вход dg_mine вкопан в южную стену (как тоннель в скалу, лицом на север); у его "
				"подножия — осыпь dg_crag и dg_moss_stones, не дальше 3 м от стены."),
			("Горное дело", "верёвочная лестница dg_ladder у северной стены, ящики с рудой dg_crates, фонари dg_lantern "
				"на стойках у входа в шахту."),
			("Аметисты", "dg_amethyst_spires и dg_crystal_purple растут из стен в восточном углу (фиолетовый свет), "
				"dg_dripstone в западном углу."),
			("Проход", "дорожка 5 м от западного входа к северо-восточному — свободна."),
		],
		"prompts": [
			("A — план сверху", "Top-down orthographic view following the ATTACHED SCHEME exactly: a narrow old mine "
				"gallery. A collapsed mine entrance with broken wooden support beams set INTO the middle of the south "
				"cliff wall, a scree of violet boulders at its foot close to the wall. A rope ladder on the north wall, "
				"crates of ore, copper lanterns on posts by the collapsed entrance, violet amethyst crystals growing from "
				"the walls in the east corner, amethyst stalagmites in the west corner. A clear 5 m path from the west "
				"entrance to the north-east exit. " + SCALE),
			("B — изометрия", "Isometric 3/4 view of the mine gallery of the ATTACHED SCHEME from the west entrance: the "
				"collapsed timbered mine entrance in the right (south) wall, boulders, lanterns, glowing amethysts in "
				"the far corner. " + SCALE),
			("C — как в игре", "Third-person mobile game screenshot: camera behind and above a small adventurer walking "
				"east through the mine gallery of the attached plan, the collapsed timbered mine entrance in the cliff "
				"wall on the right lit by lanterns, glowing violet amethysts ahead; 7 m cliff walls."),
		],
	},
	{
		"img": "07_tayik.png",
		"title": "7. Тайник контрабандистов (сокровищница)",
		"story": "Тайник за валунами: самоцветы, кристаллы, сундуки, добыча с корабля. Награда за исследование.",
		"geo": "Зал ≈ 28 × 23 м, пол −1.5 м (спуск от моста и от причала); на западе — холмик +0.7 м. Входы: с севера (мост "
			"через канал) и с востока (к причалу).",
		"plan": [
			("Клад — западный холмик", "пиратский клад dg_hoard, открытый сундук с золотом dg_chest_open (светится), "
				"золото россыпью dg_gold вокруг, реликвии dg_relics."),
			("Северная стена", "3 закрытых сундука dg_chest в ряд, оружейная стойка dg_armory."),
			("Входы спрятаны", "у обоих входов по бокам — валуны dg_crag / dg_moss_stones и мшистые баррикады "
				"dg_barricade_moss (тайник «за валунами»), проход 4–5 м свободен."),
			("Свет", "лазурные кристаллы dg_crystal_blue в двух углах, лужица с сокровищами dg_tidepool на юго-востоке."),
		],
		"prompts": [
			("A — план сверху", "Top-down orthographic view following the ATTACHED SCHEME exactly: a hidden smugglers' "
				"treasure cave. On a low mound in the west a big pile of pirate treasure, an open chest overflowing with "
				"glowing gold, scattered coins and sunken relics. Three closed chests in a row along the north wall and a "
				"rusty weapon rack. Both entrances (north and east) hidden behind violet boulders and old mossy "
				"barricades with a clear 4–5 m gap. Glowing blue crystals in two corners, a small tide pool with "
				"treasure in the south-east. " + SCALE),
			("B — изометрия от моста", "Isometric 3/4 view from the north entrance of the treasure cave of the ATTACHED "
				"SCHEME: boulders framing the entrance, the treasure mound glowing gold on the right (west), chests "
				"along the wall, blue crystal light. " + SCALE),
			("C — как в игре", "Third-person mobile game screenshot: camera behind and above a small adventurer "
				"stepping between boulders into the treasure cave of the attached plan, the golden glowing hoard on the "
				"mound ahead, chests along the wall; 7 m cliff walls."),
		],
	},
	{
		"img": "08_grot.png",
		"title": "8. Причал, мостки и грот Изумрудной Клятвы с кораблём — босс капитан",
		"story": "Огромный грот: затонувший корабль, причалы, мёртвая команда, капитан; следы исследований секты. "
			"Финал главы — бой на палубе.",
		"geo": "Маленький зал причала (пол 0) на западе, от него по воде — мостки с тремя площадками и длинный мост к "
			"носу корабля. Озеро ≈ 110 × 64 м. Корабль — палуба +0.8 м (≈ 30 × 6 м), нос — на западе, к нему ведут мостки.",
		"plan": [
			("Причал", "колокол dg_bell сбоку зала, столбы с фонарями dg_harbor_post по бокам начала мостков (не на "
				"мостках), причальные мостки dg_dock вдоль берега, якорь dg_anchor у стены, ящики и бочки."),
			("Мостки", "на каждой площадке dg_pier — столб с фонарём с краю и сеть dg_net или бочка; мост — пустой."),
			("Корабль — арена", "палуба свободна посередине; штурвал dg_helm на корме (восток), пушки dg_cannon вдоль "
				"бортов, бочки; обломок мачты dg_mast_relic поперёк кормы; на корме — следы исследований: статуя-оракул "
				"dg_oracle, свечи dg_candles, реликвии dg_relics (капитан сторожил это)."),
			("Озеро", "остов dg_wreck за кораблём (восток), мачта dg_mast «глаз утопленника» и воронье гнездо "
				"dg_crows_nest из воды, дрейфующие лодки dg_rowboat и плот dg_raft, островки сталагмитов dg_dripstone с "
				"кристаллами на юге, сирена dg_siren на камне, кости левиафана dg_leviathan на берегу; у кромки — "
				"водоросли и кораллы."),
			("Свет", "тёплые фонари причала и мостков ведут к кораблю, зелёное свечение остова и мачты — вдали."),
		],
		"prompts": [
			("A — план сверху", "Top-down orthographic view following the ATTACHED SCHEME exactly: a huge flooded grotto "
				"with black-teal water. On the west a small stone pier hall with a warning bell, lantern posts beside the "
				"start of the boardwalk, a wooden dock along the shore, an ancient anchor, crates and barrels. A rope "
				"boardwalk with three small square plank platforms on stilts (each with a lantern post and a fishing net "
				"or barrel) leads east to the bow of a rotting pirate ship. The ship deck is an open arena: ship's wheel "
				"at the stern, rusty cannons along the rails, a fallen mast across the stern, an oracle statue with "
				"emerald candles and relics at the stern. Around in the water: a green-glowing sunken wreck beyond the "
				"ship, a drowned mast with a glowing eye, a crow's nest mast, drifting rowboats and a raft, amethyst "
				"stalagmite islets with crystals in the south, a driftwood siren figurehead on a rock, leviathan bones "
				"on the shore, kelp and corals at the edges. " + SCALE),
			("B — изометрия от причала", "Isometric 3/4 view from the west pier hall of the grotto of the ATTACHED "
				"SCHEME looking east along the lantern-lit boardwalk with its platforms toward the cursed pirate ship, "
				"the green-glowing wreck and drowned mast behind it, dark teal water. " + SCALE),
			("C — как в игре", "Third-person mobile game screenshot: camera behind and above a small adventurer on the "
				"last boardwalk platform of the attached plan, the long rope bridge leading to the bow of the cursed "
				"ship ahead, lanterns along the boardwalk, the emerald glow of the wreck and the drowned mast in the "
				"distance; 7 m cliff walls around the grotto."),
		],
	},
]


def shade(cell, hex_color):
	tc = cell._tc.get_or_add_tcPr()
	shd = OxmlElement("w:shd")
	shd.set(qn("w:val"), "clear")
	shd.set(qn("w:color"), "auto")
	shd.set(qn("w:fill"), hex_color)
	tc.append(shd)


def prompt_box(doc, label, text):
	p = doc.add_paragraph()
	r = p.add_run(label)
	r.bold = True
	r.font.size = Pt(11)
	t = doc.add_table(rows=1, cols=1)
	t.style = "Table Grid"
	t.alignment = WD_TABLE_ALIGNMENT.CENTER
	c = t.rows[0].cells[0]
	shade(c, "F2F2F2")
	c.paragraphs[0].text = ""
	run = c.paragraphs[0].add_run(text + "\n\n" + STYLE)
	run.font.name = "Consolas"
	run.font.size = Pt(9)
	doc.add_paragraph()


def main():
	doc = Document()
	st = doc.styles["Normal"]
	st.font.name = "Calibri"
	st.font.size = Pt(11)
	doc.add_heading("Промты: расстановка объектов подземелья по зонам", 0)
	for t in GENERAL:
		doc.add_paragraph(t)
	for r in RULES:
		doc.add_paragraph(r, style="List Bullet")
	doc.add_heading("Объекты подземелья (что уже есть в игре)", 1)
	doc.add_paragraph("Модели Максима из папки «ДАНЖ», уже в игре (id — имя модели). Размер — Ш × В × Д, м. Если "
		"на картинке ChatGPT нарисует что-то, чего нет в списке, — либо заменю похожим, либо это повод для новой модели.")
	tb = doc.add_table(rows=1, cols=4)
	tb.style = "Table Grid"
	for i, h in enumerate(["id", "Название", "Размер, м", "Что это"]):
		tb.rows[0].cells[i].text = h
		shade(tb.rows[0].cells[i], "D9D9D9")
	for oid, name, size, what in OBJECTS:
		row = tb.add_row().cells
		row[0].text = oid
		row[1].text = name
		row[2].text = size
		row[3].text = what
	for row in tb.rows:
		for c in row.cells:
			for p in c.paragraphs:
				for r in p.runs:
					r.font.size = Pt(9)
	for z in ZONES:
		doc.add_page_break()
		doc.add_heading(z["title"], 1)
		path = os.path.join(ZONES_DIR, z["img"])
		if os.path.exists(path):
			doc.add_picture(path, width=Cm(16.5))
			cap = doc.add_paragraph("Схема из игры: reference/dungeon/zones/" + z["img"] + " — её прикладывать к промтам.")
			cap.runs[0].italic = True
			cap.runs[0].font.size = Pt(9)
		doc.add_heading("По сюжету", 2)
		doc.add_paragraph(z["story"])
		doc.add_heading("Рельеф и проходы", 2)
		doc.add_paragraph(z["geo"])
		doc.add_heading("Предложение: что где стоит и почему", 2)
		for g, text in z["plan"]:
			p = doc.add_paragraph(style="List Bullet")
			r = p.add_run(g + ": ")
			r.bold = True
			p.add_run(text)
		doc.add_heading("Промты (приложить схему зоны)", 2)
		for label, text in z["prompts"]:
			prompt_box(doc, label, text)
	doc.add_page_break()
	doc.add_heading("Что дальше", 1)
	doc.add_paragraph("Пришли картинки, которые понравились (лучше A и одну из B/C на зону), с пометкой зоны и "
		"правками словами. Я расставлю объекты в игре по ним, сделаю скриншоты с тех же ракурсов из игры и пришлю на "
		"сравнение до сборки. Если какой-то нужной вещи нет среди моделей — составлю промт для Meshy.")
	doc.save(OUT)
	print("записан", OUT)


if __name__ == "__main__":
	sys.exit(main())

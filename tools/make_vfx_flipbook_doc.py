#!/usr/bin/env python3
# Промты ChatGPT (0.46.1): раскадровки (flipbook) эффектов умений — удары, магия, заклинания, бафы, дебафы, магические
# круги. Каждый лист — одна анимация одного эффекта: сетка 4×4 кадров по порядку, белым по чёрному (игра красит по
# стихии палитрами VfxArchetypes.PALETTES — один лист служит огню, льду, тьме, свету…).
# Пишет tools/Промты_раскадровки_эффектов.docx. Запуск из корня: python3 -I tools/make_vfx_flipbook_doc.py
# (нужен python-docx). Листы Максим присылает файлами fx_<id>.png; подготовка — tools/prepare_flipbook.py (нарезка по
# сетке, центр кадра, яркость → прозрачность), подключение — VfxKit (flipbook-слои).
import os

from docx import Document
from docx.shared import Pt

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCX = os.path.join(ROOT, "tools", "Промты_раскадровки_эффектов.docx")

STYLE = ("Game VFX flipbook sprite sheet for a mobile fantasy MMORPG: stylized anime cel-shaded magic effects in the "
	"spirit of Genshin Impact, fully original (no existing game assets, no characters, no hands, no weapons, no "
	"creatures, no environment, no text, no letters, no numbers, no watermark, no logo). SQUARE image with EXACTLY 16 "
	"frames in a strict 4×4 grid of equal square cells; reading order left-to-right, top-to-bottom, frame 1 in the "
	"top-left cell, frame 16 in the bottom-right cell. All 16 frames show ONE continuous animation of the SAME effect "
	"over time — each frame is the next moment, the motion between neighbouring frames is small and smooth. The effect "
	"stays anchored at the same pivot point in every cell with consistent scale (it may grow or shrink only as part of "
	"the animation). MONOCHROME: pure white and light-grey shapes with a soft white glow on a PURE BLACK background "
	"(#000000, no dark grey, no gradient, no vignette, no colors at all — the game recolors it per element). Look: a very "
	"bright hot core, crisp stylized shapes with clean sharp edges, a soft outer glow, wispy secondary details, varied "
	"brightness inside (bright, mid-grey and dim parts), no photographic realism, no film grain. Every frame keeps an "
	"empty black margin of about 10% of the cell on each side — nothing touches or crosses a cell border. No grid "
	"lines, no frame numbers, no borders, no labels.")

VIEWS = {
	"front": "VIEW: seen from the front (camera facing the effect), the effect centered in each cell.",
	"right": "VIEW: seen from the front; the effect is directional and points or moves to the RIGHT.",
	"left": "VIEW: seen from the front; the effect flows from the RIGHT edge toward the LEFT edge of the cell.",
	"top": "VIEW: seen exactly from above (orthographic top-down), perfectly round and centered in each cell — it will "
		"lie flat on the ground.",
	"side": "VIEW: seen from the side at eye level; the effect's base sits on an invisible ground line at 85% of the "
		"cell height, centered horizontally; nothing is drawn below that line.",
	"head": "VIEW: seen from the side at eye level; the effect floats in the upper third of the cell (as above a "
		"character's head), centered horizontally.",
}
VIEW_RU = {"front": "спереди", "right": "спереди, направлен вправо", "left": "спереди, справа налево",
	"top": "сверху (ляжет на землю)", "side": "сбоку, основание на земле", "head": "сбоку, над головой"}
KINDS = {
	"once": "ONE-SHOT animation: it starts from almost nothing in frame 1, reaches its peak around frames 4–7 and fades "
		"out completely by frame 16 (frame 16 nearly empty).",
	"loop": "SEAMLESS LOOP: the motion is continuous, size and brightness stay about the same through all frames, and "
		"frame 16 flows smoothly back into frame 1.",
}
KIND_RU = {"once": "разовый", "loop": "петля"}

# Группы: (название, пояснение, [(id, название, очередь 1/2, вид, тип, где в игре, кадры по-русски, описание англ.)])
GROUPS = [
	("Каст и выпуск силы", "Самые частые эффекты: сбор силы во время каста и выброс в момент применения умения.", [
		("cast_gather", "Сбор силы (каст)", 1, "front", "loop", "каст заклинаний — 45 умений, заряд",
			"нити и искры по спирали стягиваются к яркому ядру",
			"Energy gathering into a single point: thin glowing wisps and small sparkles spiral INWARD from all sides "
			"toward a bright pulsing core at the center, the inward streaks curve like a whirlpool, the core flickers."),
		("cast_release", "Выпуск силы", 1, "front", "once", "момент применения умения — 71 умение",
			"вспышка-звезда, кольцо, лучи и искры наружу, распад",
			"A burst of released magical power: frame 1 a tiny bright point; frames 2–3 an intense flash with a "
			"4-pointed star glint; frames 3–7 a crisp expanding shock ring plus 8–12 sharp radial light rays and small "
			"sparks flying outward; frames 8–12 the ring thins and breaks into fragments, sparks slow down; frames "
			"13–16 everything dissolves into nothing."),
		("magic_orb", "Снаряд-сгусток", 2, "front", "loop", "снаряды заклинаний, шар стихии",
			"шар с ядром, внутри вращаются полосы энергии, с края срываются завитки",
			"A magical energy orb projectile seen from the front: a bright round core with a soft halo, swirling "
			"energy bands rotate inside it, small wisps peel off the edge and curl away, slight pulsing."),
	]),
	("Удары оружием", "Росчерки клинков, уколы, дробящие удары, когти, искры попадания.", [
		("slash_arc", "Росчерк клинка", 1, "front", "once", "мечи и кинжалы — 10 умений и обычные атаки",
			"серп света проходит сверху-слева вниз-вправо, искры, распад на полосы",
			"A single sword slash: a sharp crescent arc of light sweeps from upper-left to lower-right — thick bright "
			"leading edge, tapering tail, crisp clean edges; frames 1–3 the arc draws itself quickly; frames 4–6 full "
			"crescent at peak with small sparks along the edge; frames 7–12 it thins and splits into thin streaks; "
			"frames 13–16 it fades away."),
		("slash_cross", "Крест клинков", 2, "front", "once", "«Крест рассвета», двойные удары",
			"два росчерка крест-накрест, вспышка в пересечении",
			"Two fast slashes forming an X: a crescent slash from upper-left to lower-right (frames 1–4), then a second "
			"from upper-right to lower-left (frames 4–7), a bright star flash where they cross (frames 6–9), then both "
			"arcs thin, scatter into small sparks and fade (frames 10–16)."),
		("cleave", "Тяжёлый рубящий удар", 2, "front", "once", "двуручное оружие, топоры, «Тяжёлый удар»",
			"широкий полумесяц сверху вниз, вспышка удара и обломки",
			"A heavy downward cleave: a very wide, thick half-moon arc of force slams from top to bottom, a bright impact "
			"flash at the bottom with chunky debris and a short ground shock line; frames 1–4 the swing, 5–7 impact "
			"and debris, 8–16 debris falls and everything fades."),
		("stab", "Укол, выпад", 1, "right", "once", "кинжалы, копьё — 11 умений",
			"узкий конус света бьёт вправо, вспышка на острие, линии скорости",
			"A piercing thrust to the RIGHT: a narrow cone of light shoots from the left side to the right like a spear "
			"tip, with speed lines; a small sharp star flash and ring burst at the tip; frames 1–3 thrust, 4–6 tip "
			"flash, 7–16 the lines and the flash fade."),
		("blunt_impact", "Дробящий удар", 1, "front", "once", "булавы, молоты, щит — 15 умений",
			"круглая вспышка, толстое кольцо, трещины света, обломки",
			"A heavy blunt impact: frames 1–2 a big round flash; frames 2–6 a thick circular shockwave ring expands with "
			"short radial cracks of light and chunky debris flying out; frames 7–12 the ring fades and debris falls, "
			"small dust puffs remain; frames 13–16 everything disappears."),
		("hit_spark", "Искры попадания", 1, "front", "once", "обычные попадания, блок",
			"острая звезда-вспышка, искры по прямым, гаснут",
			"A small hit spark: a sharp bright starburst with 6–8 thin needle rays, many tiny sparks flying outward in "
			"straight lines and slowing down; frames 1–3 star flash, 4–10 sparks spread, 11–16 sparks fade out."),
		("crit_flash", "Критический удар", 2, "front", "once", "критические попадания",
			"большая четырёхлучевая звезда, кольца, осколки",
			"A critical hit flash: a huge 4-pointed star glint with long thin cross rays, a bright ring, sharp angular "
			"shards and a second outer ring a moment later; very punchy; frames 1–2 flash, 3–7 rays extend and rings "
			"expand, 8–16 shards scatter and fade."),
		("claw", "Удар когтями", 1, "front", "once", "питомцы, звери, «Удар когтями»",
			"три рваных следа когтей наискось, искорки, распад",
			"Three parallel claw rips slashing diagonally from upper-right to lower-left: three curved bright tearing "
			"streaks appear one after another very fast (frames 1–4), glow at peak with small torn sparks (5–7), then "
			"fade and break into thin fragments (8–16)."),
		("spin_slash", "Круговой удар", 2, "top", "once", "круговые удары, вихрь клинков",
			"кольцо серпов вращается вокруг центра, искры наружу",
			"A spinning blade whirl seen from above: a circular ring of sword-slash crescents sweeps around the center "
			"clockwise with motion trails; frames 1–5 the ring spins up and closes, 6–9 a bright full ring with sparks "
			"flying outward, 10–16 it expands slightly, thins and fades."),
		("arrow_impact", "Попадание стрелы", 2, "front", "once", "стрелы и болты",
			"маленькая вспышка, кольцо, щепки вправо",
			"An arrow or bolt impact: a small bright flash at the center with a sharp ring, splinter fragments bursting "
			"mostly to the right (the arrow came from the left), a few thin speed lines from the left; quick fade."),
	]),
	("Стихии: попадания и области", "Огонь, лёд, молния, вода, земля, ветер, свет, тьма, яд, дух.", [
		("explosion", "Взрыв", 1, "front", "once", "огненные умения, взрывы",
			"вспышка, огненный шар клубами, гриб дыма, растворение",
			"A stylized explosion: frames 1–2 a bright core flash; 3–6 a round blast with layered puffy cloud lobes and "
			"flying sparks; 7–11 it rises into a soft smoke mushroom with grey inner shading; 12–16 the smoke thins and "
			"dissolves."),
		("flame_burst", "Вспышка пламени", 2, "side", "once", "огонь из земли, «Пылающая земля»",
			"языки пламени вверх, пик, оседают, угольки",
			"A burst of flames erupting upward from the ground: tongues of stylized fire with sharp curling tips shoot "
			"up, peak, then shrink back down while embers fly up and fade."),
		("burn_loop", "Горение на цели", 2, "side", "loop", "горение (урон огнём со временем)",
			"3–4 языка пламени пляшут, угольки поднимаются",
			"Small flames burning on a target: 3–4 flickering stylized flame tongues dancing along a short horizontal "
			"line, small embers rising and fading."),
		("frost_nova", "Морозная волна", 2, "top", "once", "морозные волны, лёд вокруг героя",
			"кольцо ледяных кристаллов наружу, узоры инея, раскол",
			"A frost nova seen from above: a ring of jagged ice crystals bursts outward from the center, frost patterns "
			"spread like snowflake fractals with sparkles, then the crystals shatter and fade."),
		("ice_shards", "Ледяные осколки", 2, "front", "once", "ледяные снаряды и попадания",
			"острые осколки разлетаются, морозная дымка",
			"A burst of sharp ice shards flying outward from the center in all directions with frosty mist puffs; the "
			"shards spin, break into smaller pieces and fade."),
		("lightning_strike", "Молния с неба", 1, "side", "once", "«Молния с неба», гроза, «Раскат грома»",
			"толстая ломаная молния сверху до земли, вспышка, треск искр",
			"A lightning bolt striking from the top of the cell down to the ground: frame 1 a faint leader; frames 2–4 a "
			"thick jagged main bolt with branching forks and a big ground flash; frames 5–8 the bolt flickers (shape "
			"changes slightly), electric sparks and a ground ring burst; frames 9–16 the bolt fades, crackling sparks "
			"vanish."),
		("lightning_arc", "Разряд", 2, "front", "loop", "«Разряд», цепные молнии",
			"ломаная дуга от левого края к правому, меняет излом",
			"A horizontal jagged electric arc connecting the left edge and the right edge of the cell, its zigzag shape "
			"changing every frame, with small branching forks and sparks."),
		("water_splash", "Всплеск воды", 2, "side", "once", "водные умения",
			"корона брызг вверх и в стороны, рябь у основания",
			"A splash of water: a crown of droplets and curved water sheets bursts upward and outward from the base, "
			"droplets arc and fall, a small ripple ring at the base, then everything disappears."),
		("rock_impact", "Удар камня", 2, "side", "once", "земляные умения, «Каменный клык»",
			"угловатые обломки вверх, пыль, оседают",
			"A rock impact: chunky angular rock fragments burst upward and outward from the ground with dust clouds, the "
			"rocks tumble and fall, the dust settles and fades."),
		("ground_spikes", "Шипы из земли", 2, "side", "once", "шипы, «Хватка земли»",
			"острые шипы вырастают, стоят, крошатся",
			"Several sharp stone spikes erupt from the ground in a quick sequence, stand at full height, then crack and "
			"crumble into fragments and dust that fade."),
		("wind_slash", "Ветряной серп", 2, "right", "once", "«Серп ветра», ветряные удары",
			"серп воздуха летит вправо, завитки ветра позади",
			"A crescent wind blade flying to the right: a sharp curved crescent with flowing air streaks and small "
			"swirls behind it, it travels from left to right across the cell and dissipates into curls of wind."),
		("tornado", "Вихрь", 2, "side", "loop", "вихри, «Огненный смерч» (окрасится огнём)",
			"воронка спиральных полос, сор кружится",
			"A small whirlwind: a funnel of spiraling wind bands, wider at the top and narrow at the base touching the "
			"ground, debris specks circling around it."),
		("holy_beam", "Столб света", 2, "side", "once", "«Небесная кара», святые удары",
			"столб света сверху до земли, кольцо у основания, искры вверх",
			"A pillar of holy light descending onto the ground: a bright vertical beam with soft edges and inner rays, "
			"light motes floating up, a glowing ring at the base; it appears from the top down, glows, then narrows "
			"and fades."),
		("shadow_burst", "Взрыв тьмы", 1, "front", "once", "тёмная магия — 14 умений (окрасится в тёмный)",
			"клубящиеся щупальца и шипы наружу, кольцо дыма, втягиваются",
			"A burst of dark magic drawn in white: thick curling smoky tendrils and sharp thorn-like spikes explode "
			"outward from the center with a ring of wispy smoke, then curl back and dissolve."),
		("soul_drain", "Похищение жизни", 2, "left", "loop", "вампиризм, «Глоток жизни»",
			"поток огоньков-душ с хвостиками справа налево волной",
			"A stream of small glowing soul wisps with tiny tails and ribbon-like trails flowing from the right edge to "
			"the left edge in a gentle wave."),
		("poison_cloud", "Ядовитое облако", 2, "front", "loop", "яд, «Едкая роса», ядовитые лужи",
			"бугристые клубы медленно ворочаются, пузыри лопаются",
			"A bubbling toxic cloud: lumpy rounded puffs that slowly churn, bubbles forming and popping, droplets "
			"dripping down from the bottom."),
		("blood_burst", "Кровавый всплеск", 2, "front", "once", "кровавые умения (без жестокости)",
			"брызги и изогнутые всплески наружу, падают",
			"A stylized splash burst: droplets and curved splash streaks burst outward from the center, then fall and "
			"fade (stylized and clean, not gory)."),
		("spirit_burst", "Вспышка духа", 2, "front", "once", "умения духа, питомцы",
			"светлые лепестки и пёрышки по спирали из ядра",
			"An ethereal burst: soft glowing petals and feather-like wisps spiral outward from a bright core, light and "
			"graceful, then drift and fade."),
		("roar", "Рёв", 2, "right", "once", "рёв зверей и питомцев, «Вызов»",
			"3–4 дуги звуковой волны расходятся вправо",
			"A roar shockwave: 3–4 concentric curved sound-wave arcs expanding to the right from the left side with "
			"small vibration lines, fading as they expand."),
	]),
	("Лечение и усиления (бафы)", "Лечение, бафы, щиты, ауры, благословения.", [
		("heal_burst", "Исцеление", 1, "front", "once", "лечение — 16 умений",
			"мягкое свечение, искры-крестики и лепестки вверх",
			"A gentle healing burst: a soft round glow blooms at the center, small plus-shaped sparkles and leaf-like "
			"petals float upward and outward, a light ring expands softly, then everything rises and fades."),
		("heal_rise", "Лечение со временем", 2, "side", "loop", "«Живительный свет», лечение со временем",
			"мягкие огоньки и крестики поднимаются по спирали",
			"Soft healing motes and tiny plus-shaped sparkles rising slowly upward along gentle spiral paths around an "
			"empty central column, fading at the top."),
		("buff_up", "Усиление", 1, "side", "once", "бафы — 50 умений",
			"ленты света по спирали вверх, шевроны-стрелки, вспышка наверху",
			"A power-up: from a ground ring at the bottom, ribbons of light spiral upward around an invisible character "
			"column, upward chevron arrows and sparkles rise, a bright flash at the top, then everything fades upward."),
		("aura_ring", "Аура на земле", 2, "top", "loop", "ауры героя и питомца, переключаемые умения",
			"светящееся кольцо, энергия бежит по кругу, огоньки",
			"A persistent aura on the ground seen from above: a glowing ring with energy flowing around it, a soft inner "
			"glow and small motes orbiting."),
		("shield_bubble", "Щит-купол", 1, "front", "loop", "щиты — 7 умений, «Купол света»",
			"прозрачная сфера с шестигранниками, блики скользят",
			"A protective energy dome seen from the front: a transparent sphere outline with a subtle hexagon pattern, a "
			"bright rim, slow shimmering highlights sliding across the surface."),
		("blessing", "Благословение", 1, "side", "once", "благословения жрицы, «Дар …» — 15 умений",
			"лучи сверху, пёрышки-искры опускаются, нимб",
			"A blessing from above: soft rays of light descend from the top, feather-like sparkles drift down onto an "
			"invisible character column, a halo ring forms at the top, then a gentle flash and fade."),
		("haste", "Ускорение", 2, "side", "loop", "скорость бега, «Шаг ветра», зелья скорости",
			"полосы ветра и линии скорости у ног, завитки",
			"A speed buff: horizontal wind streaks and speed lines streaming to the left around the lower half of an "
			"invisible character, small swirls at the feet."),
	]),
	("Ослабления (дебафы)", "Эффекты на цели, пока действует ослабление: петли над головой, вокруг тела, у ног.", [
		("stun_stars", "Оглушение", 1, "head", "loop", "оглушение зверей и героя",
			"4–5 звёздочек кружат по эллипсу, мерцают",
			"A stun effect above a head: 4–5 small five-pointed stars orbiting along a horizontal ellipse seen slightly "
			"from above, twinkling."),
		("sleep_mist", "Сон", 2, "head", "loop", "«Омут сна», «Дурной сон»",
			"пузыри и мягкие завитки плывут вверх (без букв Z)",
			"A sleep effect: soft dreamy bubbles and swirling wisps floating up from a head position in a slow wave, "
			"gently popping (no letters, no Z symbols)."),
		("fear_wisps", "Страх", 2, "head", "loop", "страх, «Дикий рёв», «Вой пучины» (окрасится в тёмный)",
			"дрожащие тонкие завитки и изломанные линии вокруг головы",
			"A fear effect: jittery thin wisps and trembling jagged lines rising around a head like chills, with small "
			"droplets of dread."),
		("slow_shackles", "Замедление", 2, "top", "loop", "замедление, «Ледяные путы»",
			"тяжёлое кольцо из цепей или ледяных лент у ног",
			"A slow effect at the feet seen from above: a heavy ring of glowing chain shackles (or frosty bands) slowly "
			"rotating around the center, small particles sinking."),
		("root_vines", "Путы", 2, "side", "once", "«Хватка земли», корни, путы",
			"корни из земли обвивают ноги, держат, крошатся",
			"Rooting: thorny vines or roots burst from the ground and wrap upward around an invisible character's legs "
			"(frames 1–8), hold tight with small leaves (9–14), then crumble (15–16)."),
		("poison_bubbles", "Отравление", 2, "side", "loop", "яд на цели",
			"пузырьки и капли поднимаются и лопаются, волнистые испарения",
			"Poisoned: small bubbles and droplets rising and popping around the upper body, thin wavy fumes."),
		("curse_mark", "Проклятие", 1, "head", "loop", "проклятия капитана, «Проклятый знак»",
			"зловещий знак в зубчатом кольце пульсирует и вращается",
			"A curse sigil hovering above the head: an abstract ominous symbol (eye-like or thorned rune shape, no "
			"letters) inside a jagged ring, slowly pulsing and rotating, dripping small wisps."),
		("weaken_down", "Ослабление", 2, "side", "loop", "ослабление, защита и атака ниже",
			"шевроны-стрелки вниз медленно опускаются",
			"A weakness debuff: downward-pointing chevrons and arrows sinking slowly around the body, fading at the "
			"bottom."),
		("blind_veil", "Ослепление", 2, "head", "loop", "ослепление, промахи",
			"вихрь дымки и пятен вокруг головы, мерцает",
			"Blindness: a swirling veil of mist and smudges wrapping around a head position, flickering."),
		("bleed_drops", "Кровотечение", 2, "side", "loop", "кровотечение, «Рассекающий ветер»",
			"стилизованные капли падают, маленькие всплески внизу",
			"Bleeding: stylized droplets falling from the body area at intervals, tiny splashes at the bottom (clean, "
			"not gory)."),
	]),
	("Магические круги и волны по земле", "Все — строго сверху: ляжут на землю под героем или целью.", [
		("circle_arcane", "Магический круг", 1, "top", "loop", "каст, ритуалы, умения по площади",
			"концентрические кольца, руны (не буквы), звезда, встречное вращение",
			"A magic circle on the ground: several concentric rings with abstract rune glyphs between them (not real "
			"letters), a geometric star pattern inside, small dots along the rings; the rings counter-rotate slowly "
			"and pulse."),
		("circle_holy", "Святой круг", 2, "top", "loop", "святые умения, лечение по площади",
			"солнечный узор с лучами, кольцо звёздочек, яркий центр",
			"A holy circle: a sunburst pattern with radiant rays, a ring of small stars, a bright center; slow rotation "
			"and pulsing."),
		("circle_dark", "Тёмный круг", 2, "top", "loop", "тёмная магия по площади, «Грозовой круг»",
			"зубчатые кольца с шипами, острая звезда, завитки по краю",
			"A dark sorcery circle: jagged thorned rings, a spiky star, cracked spaces between the rings, wisps curling "
			"at the outer edge; slow rotation."),
		("circle_nature", "Круг природы", 2, "top", "loop", "лечение природы, питомцы-лекари",
			"кольца из листьев и лоз, цветочный узор в центре",
			"A nature magic circle: rings made of leaves and vines, a flower-like pattern in the center, small floating "
			"petals; slow rotation."),
		("circle_sect", "Знак Секты Мрака", 2, "top", "loop", "ритуалы секты в подземелье (окрасится в изумруд)",
			"зловещий знак: глаз в кольце-змее, ритуальные линии",
			"A cult ritual circle: an ominous abstract sigil (a stylized eye inside a serpent-like ring, no letters), "
			"thin ritual lines and dots, pulsing slowly."),
		("circle_summon", "Круг призыва", 2, "top", "loop", "призыв и формирование питомца",
			"кольца с эмблемой лапы зверя, свечение волнами от центра",
			"A summoning circle: rings with an abstract beast paw emblem in the center and small rune marks, glowing "
			"brighter in waves from the center outward."),
		("shockwave_ring", "Ударная волна", 1, "top", "once", "удары по земле, «Камнелом» — 7 умений",
			"толстое кольцо быстро расходится, рваный пыльный край",
			"A ground shockwave: a thick bright ring expands fast from the center with a dusty, broken outer edge and "
			"radial streaks, then thins and fades."),
		("ground_cracks", "Трещины в земле", 2, "top", "once", "удары по земле, землетрясения",
			"светящиеся трещины звездой от центра, гаснут",
			"Ground cracks: glowing jagged cracks spread outward from the center in all directions like a star, then the "
			"glow fades and the cracks vanish."),
		("ripple", "Рябь", 2, "top", "once", "волны воды и силы по земле",
			"3 тонких кольца расходятся одно за другим",
			"Ripples: three thin concentric rings expand from the center one after another, soft and clean, fading as "
			"they grow."),
	]),
	("Особые", "Новый уровень, призыв питомца, перенос.", [
		("level_up", "Новый уровень", 2, "side", "once", "новый уровень героя и питомца",
			"столб света из кольца, кольца скользят вверх, искры",
			"Level up: a column of light rises from a ground ring, glowing rings slide up the column, sparkles burst at "
			"the top, then everything fades."),
		("summon", "Призыв питомца", 2, "side", "once", "призыв, эволюция питомца",
			"вихрь у основания сжимается в точку, вспышка, частицы",
			"A summoning: a swirling vortex of wisps spins at the base, collapses inward into a bright point, then a big "
			"flash and a burst of particles that fade."),
		("teleport", "Перенос", 2, "side", "once", "перенос, портал, возрождение",
			"вертикальные полосы света взлетают и схлопываются, вспышка",
			"Teleport: a vertical column of light streaks shoots up and collapses into thin vertical lines, then a quick "
			"flash and sparkles vanish."),
	]),
]


def prompt(e):
	ident, title, prio, view, kind, where, frames_ru, desc = e
	return "%s\n\n%s\n%s\n\nEFFECT: %s" % (STYLE, VIEWS[view], KINDS[kind], desc)


def main():
	doc = Document()
	st = doc.styles["Normal"]
	st.font.name = "Calibri"
	st.font.size = Pt(10.5)
	total = sum(len(g[2]) for g in GROUPS)
	first = [e for g in GROUPS for e in g[2] if e[2] == 1]
	doc.add_heading("Dark Pact — раскадровки эффектов умений (flipbook)", 0)
	doc.add_paragraph(
		"Зачем: сейчас эффекты умений собраны кодом из простых масок. Раскадровка — это картинка-сетка, где по "
		"порядку идут кадры одной анимации эффекта (как кадры мультфильма). Игра проигрывает их подряд прямо на "
		"частицах и вспышках — получаются нарисованные, «живые» эффекты: росчерки, взрывы, круги, бафы.")
	doc.add_heading("Как генерировать", 1)
	for line in [
		"Один лист — один запрос в ChatGPT. Скопируйте весь английский текст из блока «Промт» целиком.",
		"Картинка — квадрат. Сетка — строго 4×4 = 16 кадров. Порядок: слева направо, сверху вниз (1-й кадр — левый "
		"верхний, 16-й — правый нижний).",
		"Эффект — БЕЛЫЙ и серый на ЧИСТО ЧЁРНОМ фоне, без цвета. Цвет даёт игра: один и тот же лист станет огнём, "
		"льдом, тьмой, светом, ядом — по стихии умения (17 палитр). Поэтому цветные листы не нужны.",
		"Разовый эффект начинается почти с нуля, на 4–7 кадре — пик, к 16-му исчезает. Петля — без начала и конца: "
		"16-й кадр плавно переходит в 1-й.",
		"Вид важен: «сверху» — круги и волны, лягут на землю; «сбоку» — основание эффекта на невидимой земле внизу "
		"кадра; «спереди» — вспышки, удары, снаряды.",
		"Если ChatGPT нарисовал не 4×4, кадры разного размера или эффект уехал из центра — попросите: «Redraw it as a "
		"strict 4×4 grid of 16 equal square cells, same pivot in every cell, pure black background». Если 16 кадров "
		"не выходят — можно 3×3 (9 кадров): допишите в конце «Use a strict 3×3 grid of 9 frames instead of 4×4».",
		"Сохраняйте файлы с именем из колонки «Файл» (например fx_cast_release.png) и присылайте пачками — первая "
		"очередь важнее.",
	]:
		doc.add_paragraph(line, style="List Bullet")
	doc.add_heading("Как проверить лист перед отправкой", 2)
	for line in [
		"16 кадров ровной сеткой, ни один эффект не касается края своей клетки.",
		"Фон чёрный (не серый, без виньетки), эффект белый без цвета.",
		"Кадры по порядку и похожи на соседние — движение плавное, эффект в одной точке.",
		"Разовый — последний кадр почти пустой; петля — 16-й похож на 1-й.",
	]:
		doc.add_paragraph(line, style="List Bullet")
	doc.add_heading("Что я сделаю с листами", 2)
	doc.add_paragraph(
		"Нарежу по сетке, выровняю кадры по центру, переведу яркость в прозрачность (чёрное — пустота), сожму для "
		"телефона и подключу к генератору эффектов: каждому архетипу (выпуск силы, взрыв, круг, оглушение…) — свой "
		"нарисованный слой поверх нынешних частиц, по стихии умения — своя окраска. Без листа остаётся нынешний эффект.")
	doc.add_heading("Первая очередь — %d листов" % len(first), 1)
	doc.add_paragraph("Самые частые эффекты в игре (по таблице генератора эффектов: выпуск силы — 71 умение, "
		"усиление — 50, каст — 45, лечение — 16, дробящий удар — 15 …): " +
		", ".join("fx_%s (%s)" % (e[0], e[1]) for e in first) + ".")
	doc.add_paragraph("Всего листов: %d. Вторая очередь — остальные, по желанию и по мере сил." % total)

	n = 0
	for gname, gnote, items in GROUPS:
		doc.add_heading(gname, 1)
		doc.add_paragraph(gnote)
		t = doc.add_table(rows=1, cols=6)
		t.style = "Table Grid"
		hdr = t.rows[0].cells
		for i, h in enumerate(["Файл", "Эффект", "Очередь", "Вид", "Тип", "Где в игре · кадры"]):
			hdr[i].text = h
		for e in items:
			r = t.add_row().cells
			r[0].text = "fx_%s.png" % e[0]
			r[1].text = e[1]
			r[2].text = "1-я ★" if e[2] == 1 else "2-я"
			r[3].text = VIEW_RU[e[3]]
			r[4].text = KIND_RU[e[4]]
			r[5].text = "%s · %s" % (e[5], e[6])
		for e in items:
			n += 1
			doc.add_heading("%d. fx_%s — %s%s" % (n, e[0], e[1], " ★" if e[2] == 1 else ""), 2)
			doc.add_paragraph("Вид: %s · %s · где: %s. Кадры: %s." % (VIEW_RU[e[3]], KIND_RU[e[4]], e[5], e[6]))
			p = doc.add_paragraph()
			p.add_run("Промт:").bold = True
			doc.add_paragraph(prompt(e))
	doc.save(DOCX)
	print("записано: %s (листов %d, первая очередь %d)" % (DOCX, total, len(first)))


if __name__ == "__main__":
	main()

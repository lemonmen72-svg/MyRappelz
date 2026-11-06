class_name VfxRules
extends RefCounted
## Правила генератора эффектов умений (docs/vfx/VFX_ARCHITECTURE.md): по названию, описанию, стихии (поле c),
## виду применения (use / target), анимации, времени каста и действиям умения (fx: урон по площади, оглушение, яд,
## лечение, усиление; у питомцев — dmg, radius, stun, buff…) подбирает архетипы фаз:
##   cast — на герое, пока идёт каст; release — выпуск силы; proj — вид снаряда; impact — попадание по цели;
##   area — по площади вокруг цели (или героя у "near"); buff — усиление / лечение на ком-то.
## Результат — словарь записи таблицы vfx/skill_vfx.json (её пишет tools/vfx_generate.gd; правки руками —
## vfx/skill_vfx_overrides.json). Правила детерминированы: та же база данных → та же таблица.

## Стихии по корням слов (название весит ×3, описание ×1, поле c ×2). Порядок — при равенстве первая.
const KEYWORDS := {
	"emerald": ["изумруд", "секты", "ритуал", "печат"],
	"fire": ["огн", "огон", "плам", "жар", "пожар", "пыла", "горящ", "горен", "пепел", "испепел"],
	"ice": ["лёд", "=лед", "ледян", "мороз", "стуж", "иней", "холод", "снеж", "леденящ"],
	"storm": ["молни", "гром", "разряд", "грозов", "грозы"],
	"water": ["вод", "прилив", "омут", "волн", "пучин", "глубин", "чернил", "брызг"],
	"earth": ["земл", "камн", "камен", "скал", "обвал", "землетряс", "панцир", "топот", "=шип", "шипы"],
	"wind": ["ветр", "ветер", "вихр", "ураган", "порыв", "крыл", "серп ветра", "перьев"],
	"poison": ["=яд", "ядом", "ядов", "=яда", "отрав", "едк", "чум", "порч", "гнил", "тлен"],
	"blood": ["кров", "жизнь взаймы", "вампир"],
	"light": ["свет", "сия", "свят", "небес", "ослеп", "рассвет", "=луч", "лучом", "=кара", "карающ", "благ", "зари",
		"искрист"],
	"heal": ["леч", "исцел", "целеб", "родник", "живительн", "заживл", "колыбельн"],
	"dark": ["тьм", "=тень", "тени", "тенью", "теневой", "теневые", "теней", "мрак", "мрачн", "сумра", "полуноч",
		"бездн", "проклят", "морок", "=сон", "=сна", "сонн", "дурн"],
	"spirit": ["дух", "=душ", "души", "душа", "душу", "искр"],
	"mind": ["разум", "мысл", "ясност", "сосредоточ"],
	"shield": ["щит", "оберег", "заслон", "покров", "купол", "стена", "крепост"],
	"beast": ["зверин", "клык", "когт", "укус", "рёв", "=рев", "=вой", "воет", "стая", "стаи", "хищник", "клевок",
		"клич"],
}

## Поле c умений профессий → стихия (то, что не стихия, — по смыслу).
const C_ELEMENT := {
	"fire": "fire", "water": "ice", "storm": "storm", "earth": "earth", "wind": "wind", "light": "light",
	"heal": "heal", "dark": "dark", "blood": "blood", "spirit": "spirit", "mind": "mind", "steel": "steel",
	"shield": "shield", "beast": "beast",
}

## Стихия по умолчанию у видов питомцев.
const PET_ELEMENT := {
	"panther": "dark", "turtle": "earth", "pheasant": "light", "wolf": "beast", "centaur": "steel",
	"skeleton": "emerald", "octopus": "water", "boar": "beast", "golem": "earth",
}

## Стихии магии (у оружейного удара с ними — цвет стихии, без них — сталь).
const MAGIC := ["fire", "ice", "storm", "water", "earth", "wind", "poison", "blood", "light", "heal", "dark",
	"spirit", "mind", "emerald"]

## Попадание магией по одной цели — архетип по стихии.
const MAGIC_IMPACT := {
	"fire": "flame_burst", "ice": "ice_shards", "water": "water_splash", "earth": "rock_impact",
	"storm": "spark_hit", "light": "spirit_burst", "heal": "heal_burst", "dark": "shadow_burst",
	"emerald": "shadow_burst", "poison": "water_splash", "blood": "blood_burst", "wind": "wind_slash",
	"spirit": "spirit_burst", "mind": "spirit_burst", "steel": "spark_hit", "shield": "spark_hit",
	"beast": "claw",
}

## Заклинание без снаряда (удар прямо по цели) — архетип по стихии.
const MAGIC_DIRECT := {
	"fire": "flame_burst", "ice": "ice_shards", "water": "water_splash", "earth": "ground_spike",
	"storm": "lightning_strike", "light": "holy_beam", "heal": "heal_burst", "dark": "shadow_burst",
	"emerald": "cursed_sigil", "poison": "toxic_pool", "blood": "blood_burst", "wind": "wind_slash",
	"spirit": "spirit_burst", "mind": "spirit_burst", "steel": "spark_hit", "shield": "spark_hit",
	"beast": "claw",
}

## Удар по площади — архетип по стихии.
const AREA := {
	"fire": "explosion", "ice": "frost_nova", "water": "water_wave", "earth": "shockwave", "storm": "lightning_strike",
	"light": "holy_nova", "heal": "heal_burst", "dark": "cursed_sigil", "emerald": "ritual_circle",
	"poison": "toxic_pool", "blood": "blood_burst", "wind": "tornado", "spirit": "holy_nova", "mind": "holy_nova",
	"steel": "shockwave", "shield": "shockwave", "beast": "roar",
}

## Особые механики профессий (handler) — свой архетип попадания или площади.
const HANDLERS := {
	"ne_pillar": {"impact": "lightning_strike", "light": "holy_beam"},
	"ne_volley": {"impact": "@impact"},
	"ne_corpse_hp": {"buff": "soul_drain", "el": "dark"},
	"ne_corpse_mp": {"buff": "soul_drain", "el": "dark"},
	"sw_rush": {"impact": "blunt_hit", "area": "shockwave"},
	"sw_cross": {"impact": "slash"},
	"revive_pet": {"buff": "blessing"},
	"sacrifice_pet": {"buff": "blood_burst"},
	"blood_rain": {"impact": "blood_burst"},
	"borrowed_life": {"buff": "soul_drain"},
	"abyss_howl": {"area": "roar"},
	"ne_blood_gift": {"buff": "blood_burst"},
	"sky_offering": {"buff": "holy_nova"},
	"spirit_wrath": {"area": "ritual_circle"},
	"ne_burn_area": {"area": "explosion"},
	"wz_renew": {"buff": "heal_burst"},
	"cleanse_pet": {"buff": "blessing"},
	"spark_heal": {"buff": "heal_burst"},
	"spark_vigor": {"buff": "buff_up"},
	"spark_gain": {"buff": "spirit_burst"},
}


## Стихия умения по названию, описанию, полю c (и виду питомца species).
static func element_of(sk: Dictionary, species: String = "") -> String:
	var name := String(sk.get("name", "")).to_lower()
	var desc := String(sk.get("desc", "")).to_lower()
	var nw := _words(name)
	var dw := _words(desc)
	var score := {}
	for el in KEYWORDS:
		var v := 0
		for w in KEYWORDS[el]:
			if _has_word(name, nw, String(w)):
				v += 3
			if _has_word(desc, dw, String(w)):
				v += 1
		if v > 0:
			score[el] = v
	var c := String(sk.get("c", ""))
	if C_ELEMENT.has(c):
		var ce := String(C_ELEMENT[c])
		score[ce] = int(score.get(ce, 0)) + 2
	if species != "" and PET_ELEMENT.has(species):
		var pe := String(PET_ELEMENT[species])
		score[pe] = int(score.get(pe, 0)) + 1
	var best := "steel"
	var bv := 0
	for el in KEYWORDS:
		if int(score.get(el, 0)) > bv:
			bv = int(score[el])
			best = String(el)
	if int(score.get("steel", 0)) > bv:
		best = "steel"
	return best


## Слова текста (буквы подряд, нижний регистр).
static func _words(text: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var cur := ""
	for i in text.length():
		var ch := text[i]
		if ch.to_upper() != ch.to_lower() or ch == "ё":
			cur += ch
		elif cur != "":
			out.append(cur)
			cur = ""
	if cur != "":
		out.append(cur)
	return out


## Ключ стихии в тексте: с пробелом — подстрока; «=слово» — слово целиком; иначе — начало слова.
static func _has_word(text: String, words: PackedStringArray, key: String) -> bool:
	if key.contains(" "):
		return text.contains(key)
	if key.begins_with("="):
		return words.has(key.substr(1))
	for w in words:
		if w.begins_with(key):
			return true
	return false


## Детерминированный seed по id (FNV-1a, 16 бит).
static func seed_of(id: String) -> int:
	var h := 2166136261
	for i in id.length():
		h = ((h ^ id.unicode_at(i)) * 16777619) & 0xffffffff
	return h & 0xffff


static func _p(arch: String, el: String, sid: String, scale: float = 1.0, dur: float = 0.8, k: float = 1.0) -> Dictionary:
	return {"arch": arch, "el": el, "scale": snappedf(scale, 0.05), "dur": snappedf(dur, 0.05), "k": snappedf(k, 0.05),
		"seed": seed_of(sid + "|" + arch)}


## Радиус площади умения (наибольший area / radius в fx и у самого умения), 0 — по одной цели.
static func _area_of(sk: Dictionary) -> float:
	var r := float(sk.get("radius", 0.0)) if String(sk.get("use", "")) != "magic" else 0.0
	for e in sk.get("fx", []):
		r = maxf(r, float((e as Dictionary).get("area", 0.0)))
	return r


static func _fx_has(sk: Dictionary, what: String) -> bool:
	for e in sk.get("fx", []):
		if String((e as Dictionary).get("do", "")) == what:
			return true
	return false


static func _statuses(sk: Dictionary) -> Array:
	var r: Array = []
	for e in sk.get("fx", []):
		var d: Dictionary = e
		if String(d.get("do", "")) == "status":
			r.append(String(d.get("status", "")))
	return r


static func _handlers(sk: Dictionary) -> Array:
	var r: Array = []
	for e in sk.get("fx", []):
		var d: Dictionary = e
		if String(d.get("do", "")) == "special":
			r.append(String(d.get("handler", "")))
	return r


## Удар оружием: вид дуги по анимации, названию и оружию.
static func _weapon_arch(sk: Dictionary, el: String) -> String:
	var name := String(sk.get("name", "")).to_lower()
	var anim := String(sk.get("anim", ""))
	if anim == "spin" or name.contains("круг") or name.contains("вихрь клинк") or name.contains("буря"):
		return "spin_slash"
	for w in ["в спину", "укол", "выпад", "пронза", "жал", "кинжал", "удар в"]:
		if name.contains(w):
			return "stab"
	for w in ["раскол", "рассек", "сокруш", "камнелом", "тяжёл", "разруб", "проло"]:
		if name.contains(w):
			return "cleave"
	if anim == "bash" or el == "shield" or name.contains("щит") or name.contains("молот") or name.contains("звон"):
		return "blunt_hit"
	if el == "beast":
		return "claw"
	return "slash"


## Запись таблицы для умения героя sid (данные HeroSkills.get_skill). Пассивные — пусто.
static func hero(sid: String, sk: Dictionary) -> Dictionary:
	var kind := String(sk.get("kind", ""))
	if kind == "passive" or sk.is_empty():
		return {}
	var el := element_of(sk)
	var out := {"el": el}
	if kind == "toggle":
		var arch := "shield" if el == "shield" else ("blessing" if el in ["light", "heal", "spirit"] else "buff_up")
		out["buff"] = _p(arch, el, sid, 1.0, 1.2)
		return out
	var use := String(sk.get("use", ""))
	var tgt := String(sk.get("target", ""))
	if use == "" and tgt != "":
		use = {"dash": "melee", "melee": "melee", "ranged": "ranged", "near": "near", "self": "self"}.get(tgt, tgt)
	var area := _area_of(sk)
	var st := _statuses(sk)
	var hs := _handlers(sk)
	var big := 1.0
	for e in sk.get("fx", []):
		var d: Dictionary = e
		if String(d.get("do", "")) == "damage":
			var hits = d.get("hits", 1)
			if (hits is Array and float((hits as Array).back()) >= 3.0) or (not hits is Array and float(hits) >= 3.0):
				big = 1.15
	var cast := float(sk.get("cast", 0.0))
	var spell := use == "magic" or String(sk.get("anim", "")) == "cast"
	if cast > 0.0 and spell:
		out["cast"] = _p("cast_gather", el, sid, 1.0, cast)
	match use:
		"melee":
			var w := _weapon_arch(sk, el)
			var tint := el if el in MAGIC else "steel"
			out["impact"] = _p(w, tint, sid, big, 0.6)
			if area > 0.0 and w != "spin_slash":
				out["area"] = _p(AREA.get(el, "shockwave"), el, sid, clampf(area / 2.6, 0.9, 2.4), 0.9)
			if tgt == "dash":
				out["release"] = _p("shadow_burst" if el == "dark" else "release", el, sid, 1.0, 0.5)
		"ranged":
			out["impact"] = _p("arrow_impact", el if el in MAGIC else "steel", sid, 1.0, 0.5)
			if el in MAGIC and el != "steel":
				out["impact"] = _p(MAGIC_IMPACT.get(el, "arrow_impact"), el, sid, 0.8, 0.6)
			if area > 0.0:
				out["area"] = _p(AREA.get(el, "shockwave"), el, sid, clampf(area / 2.6, 0.9, 2.4), 0.9)
		"magic":
			var proj := bool(sk.get("proj", false))
			out["release"] = _p("release", el, sid, 1.0, 0.5)
			if proj:
				out["proj"] = {"el": el}
				out["impact"] = _p(MAGIC_IMPACT.get(el, "spirit_burst"), el, sid, big, 0.7)
			else:
				var a := String(MAGIC_DIRECT.get(el, "spirit_burst"))
				if el == "earth" and not ("stun" in st or "root" in st or "snare" in st):
					a = "rock_impact"
				if el == "storm" and String(sk.get("name", "")).to_lower().contains("разряд"):
					a = "lightning_bolt"
				if "sleep" in st and el == "dark":
					a = "cursed_sigil"
				for e in sk.get("fx", []):
					if float((e as Dictionary).get("leech", 0.0)) > 0.0:
						a = "soul_drain"
				out["impact"] = _p(a, el, sid, big, 0.8)
			if area > 0.0:
				out["area"] = _p(AREA.get(el, "holy_nova"), el, sid, clampf(area / 2.6, 0.9, 2.4), 0.9)
		"near":
			out["release"] = _p("release", el, sid, 1.0, 0.5)
			out["area"] = _p(AREA.get(el, "holy_nova"), el, sid, clampf(maxf(area, float(sk.get("radius", 5.0))) / 2.6,
				0.9, 2.4), 0.9)
		"self", "pet":
			var arch := "buff_up"
			if _fx_has(sk, "heal") or _fx_has(sk, "hot") or el == "heal":
				arch = "heal_burst"
			elif el == "shield":
				arch = "shield"
			elif el in ["light", "spirit"]:
				arch = "blessing"
			out["buff"] = _p(arch, el, sid, 1.0, 1.2)
	for h in hs:
		if HANDLERS.has(h):
			var m: Dictionary = HANDLERS[h]
			var hel := String(m.get("el", el))
			for ph in m:
				if not ph in ["impact", "area", "buff", "release"]:
					continue
				var a := String(m[ph])
				if m.has(el):
					a = String(m[el])
				if a == "@impact":
					a = String(MAGIC_IMPACT.get(el, "spirit_burst"))
				out[ph] = _p(a, hel, sid, 1.0 if ph != "area" else 1.4, 0.9)
			if hel != el:
				out["el"] = hel
	# Провокация по площади («Вызов», «Гром щита») — рёв, а не сияние
	if "taunt" in st and out.has("area") and use != "melee":
		(out["area"] as Dictionary)["arch"] = "roar"
	if out.has("impact") and "stun" in st and use == "melee" and String((out["impact"] as Dictionary)["arch"]) == "slash":
		(out["impact"] as Dictionary)["arch"] = "blunt_hit"
	return out


## Запись таблицы для умения питомца sid вида species (данные PetSkills.get_skill).
static func pet(sid: String, sk: Dictionary, species: String) -> Dictionary:
	var kind := String(sk.get("kind", ""))
	if kind != "active" or sk.is_empty():
		return {}
	var el := element_of(sk, species)
	var out := {"el": el}
	if sk.has("buff"):
		var b := String(sk["buff"])
		var arch := "buff_up"
		match b:
			"guard":
				arch = "shield"
			"heal", "regen":
				arch = "heal_burst"
			"leech":
				arch = "blood_burst"
		out["buff"] = _p(arch, el, sid, 1.0, 1.2)
		return out
	var name := String(sk.get("name", "")).to_lower()
	var melee := "claw"
	match species:
		"turtle", "golem":
			melee = "blunt_hit"
		"centaur":
			melee = "stab"
		"pheasant":
			melee = "stab"
		"skeleton":
			melee = "slash"
		"octopus":
			melee = "water_splash"
	if name.contains("укус") or name.contains("клык") or name.contains("челюст"):
		melee = "claw" if species != "turtle" else "blunt_hit"
	var tint := el
	var impact := melee
	var dmg0 := 0.0
	if sk.get("dmg") is Array and not (sk["dmg"] as Array).is_empty():
		dmg0 = float((sk["dmg"] as Array)[0])
	if el in ["storm", "ice", "fire", "light", "dark", "water", "poison", "emerald", "blood", "spirit", "mind"] \
			and dmg0 >= 1.5:
		impact = String(MAGIC_IMPACT.get(el, melee))
	if sk.has("fear") and not sk.has("dmg"):
		out["release"] = _p("roar", el, sid, 1.0, 0.8)
		return out
	if sk.has("blind") and not sk.has("dmg"):
		impact = "shadow_burst"
	if sk.has("stun") and impact in ["claw", "slash"]:
		impact = "blunt_hit"
	if sk.has("dot") or sk.has("pool"):
		impact = String(MAGIC_IMPACT.get(el, "water_splash")) if not sk.has("pool") else impact
	out["impact"] = _p(impact, tint, sid, 1.0 + (0.15 if int(sk.get("hits", 1)) >= 3 else 0.0), 0.6)
	if sk.has("radius"):
		var r := float(sk["radius"])
		var a := String(AREA.get(el, "shockwave"))
		if sk.has("pool"):
			a = "ritual_circle" if el in ["dark", "emerald"] else "toxic_pool"
		out["area"] = _p(a, el, sid, clampf(r / 2.6, 0.9, 2.4), 1.0 if not sk.has("pool") else float(sk["pool"]))
	if float(sk.get("cast", 0.0)) > 0.0:
		out["release"] = _p("release", el, sid, 0.8, 0.5)
	return out


## Способности монстров (не из древ): удар по площади (slam) и проклятия капитана.
static func mobs() -> Dictionary:
	var out := {}
	for id in MobData.TYPES:
		var mid := String(id)
		var sl := MobData.slam_of(mid)
		if not sl.is_empty():
			var el := "emerald" if MobData.is_dungeon(mid) else "earth"
			out[mid + ":slam"] = {"el": el, "area": _p("shockwave" if el == "earth" else "ritual_circle", el,
				mid + ":slam", clampf(float(sl.get("radius", 4.0)) / 2.6, 1.0, 2.6), 0.9)}
		var cu := MobData.curses_of(mid)
		if not cu.is_empty():
			for e in cu.get("list", []):
				var kind := String((e as Array)[0])
				var el2 := "poison" if kind == "poison" else "emerald"
				out[mid + ":curse:" + kind] = {"el": el2, "buff": _p("emerald_curse" if kind != "poison" else "toxic_pool",
					el2, mid + ":curse:" + kind, 1.0 if kind != "poison" else 0.6, clampf(float((e as Array)[1]), 0.8, 5.0))}
	return out

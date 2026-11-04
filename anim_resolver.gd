class_name AnimResolver
extends RefCounted
## Система анимаций 1.0 (ТЗ DARK_PACT_ANIMATION_SYSTEM_MASTER.md, устройство — docs/animation/PROPOSED_ARCHITECTURE.md):
## единый выбор клипа героя по контексту (действие, вид умения, id умения, способ применения, хват оружия) с цепочкой
## запасных уровней и диагностикой. Таблицы клипов — константы CharacterModel (MQ_*, ASSET_ACTIONS), здесь — порядок
## уровней, исправления пробелов и учёт.
##
## Уровни цепочки (LEVELS, от точного к общему):
##   "skill"  — своё движение умения (CharacterModel.MQ_SKILL_BY_ID);
##   "grip"   — вид действия + хват оружия (MQ_ATTACKS / MQ_STRIKES / MQ_SPINS по mq_grip);
##   "shared" — общий клип вида действия, если хват его не запрещает (у лука и арбалета взмаха мечом нет);
##   "legacy" — прежний жест модели (ASSET_ACTIONS у модели из файла, процедурные удары у модели из примитивов);
##   "idle"   — подходящего ничего нет: действие не играет, герой остаётся в покое / шаге (не зависает).
## Геймплей от анимации не зависит: урон, лечение, снаряды, MP и перезарядки решает Player / HeroSkillFx по своему
## времени (договор событий — docs/animation/AUDIT_REPORT.md, раздел «События»). Клип только показывает действие.
##
## Флаг отката: AnimResolver.enabled = false — CharacterModel выбирает клипы прежним кодом (до системы 1.0).

const LEVELS := ["skill", "grip", "shared", "legacy", "idle"]
## Хваты, у которых взмах мечом как общий удар умения неуместен (стрелковое оружие): удар умения — выстрел или
## прежний жест выстрела.
const RANGED_GRIPS := ["bow", "crossbow"]
## Действия матрицы покрытия: [ключ, вид для play_skill или "" для обычной атаки, use].
const COVER_ACTIONS := [
	["attack", "", ""], ["strike", "attack", "melee"], ["bash", "bash", "melee"], ["spin", "spin", "melee"],
	["dash", "dash", "melee"], ["ranged_skill", "attack", "ranged"], ["cast", "cast", "magic"],
	["cast_self", "cast", "self"], ["buff", "buff", "self"],
]
## Хваты матрицы покрытия (CharacterModel.mq_grip): все виды оружия ItemData и щит.
const COVER_GRIPS := ["sword", "sword_shield", "sword_2h", "dual_swords", "dagger", "daggers", "axe", "axe_2h",
	"dual_axes", "mace", "mace_2h", "spear", "staff", "bow", "crossbow"]
## Хват → вид оружия ClassData.weapons (для not_applicable: профессия этим не владеет).
const GRIP_WEAPON := {"sword": ["sword_1h"], "sword_shield": ["shield"], "sword_2h": ["sword_2h"],
	"dual_swords": ["dual_swords"], "dagger": ["dagger"], "daggers": ["daggers"], "axe": ["axe_1h"], "axe_2h": ["axe_2h"],
	"dual_axes": ["dual_axes"], "mace": ["mace_1h"], "mace_2h": ["mace_2h"], "spear": ["spear"],
	"staff": ["staff_1h", "staff_2h"], "bow": ["bow"], "crossbow": ["crossbow"]}

## Актёры кроме героя (префикс ключа действия в note): жители, питомцы, звери мира.
const ACTORS := ["npc", "pet", "mob"]
const ACTOR_NAMES := {"hero": "герой", "npc": "жители", "pet": "питомцы", "mob": "звери"}
## Клипы существ (CreatureAsset.CLIPS) и их роли: что обязательно игре, чем заменяется, если нет.
## pet/mob: idle, walk, run, attack — обязательны (шаг/бег подменяют друг друга), cast → attack, hit / death — без них
## действие не играет (покой; смерть — тело пропадает по таймеру Mob).
const CREATURE_FALLBACK := {"walk": "run", "run": "walk", "cast": "attack"}
## Декоративные существа без боя (овцы в загоне): только покой и шаг.
const CREATURE_DECOR := ["sheep"]
## Клипы жителя, которые игра включает (Npc: покой, приветствие; шаг и бег — у жителей не используются).
const NPC_ACTIONS := ["idle", "wave"]

## Выключатель системы (откат на прежний выбор клипов).
static var enabled := true
## Боевой покой (CharacterModel.ASSET_IDLE_COMBAT) — отдельный выключатель.
static var combat_idle := true
## Печатать каждое решение в лог (отладка; в отчёт идёт и без этого).
static var verbose := false
## Счётчики: действие → уровень → раз.
static var stats: Dictionary = {}
## Чего не хватило (уровень legacy или idle): "действие/хват" → раз.
static var missing: Dictionary = {}
## Последние решения (до TRACE_MAX): {t, action, grip, sid, level, clip}.
static var trace: Array = []
const TRACE_MAX := 64


## Цепочка вариантов для умения: [[уровень, [ключи клипов]], …] по порядку. kind — вид анимации умения
## ("cast", "bash", "spin", "buff", "dash", "attack"), use — способ ("melee", "ranged", "magic", "self", "pet").
static func skill_chain(kind: String, sid: String, use: String, grip: String, melee: bool) -> Array:
	var chain: Array = []
	if CharacterModel.MQ_SKILL_BY_ID.has(sid):
		chain.append(["skill", [CharacterModel.MQ_SKILL_BY_ID[sid]]])
	var ranged_grip := RANGED_GRIPS.has(grip)
	match kind:
		"cast":
			var opts: Array = CharacterModel.MQ_CASTS_SELF if use == "self" or use == "pet" else CharacterModel.MQ_CASTS
			chain.append(["shared", opts])
		"buff":
			chain.append(["shared", CharacterModel.MQ_BUFFS + (CharacterModel.MQ_BUFFS_MELEE if melee else [])])
		"spin":
			if CharacterModel.MQ_SPINS.has(grip):
				chain.append(["grip", CharacterModel.MQ_SPINS[grip]])
			elif grip == "staff":
				chain.append(["grip", CharacterModel.MQ_STRIKES["staff"]])
			if not ranged_grip:
				chain.append(["shared", ["mq_axe_spin"]])
		"dash":
			if ["axe", "mace", "dual_axes", "axe_2h", "mace_2h"].has(grip):
				chain.append(["grip", ["mq_leap_slam"]])
			if not ranged_grip:
				chain.append(["shared", CharacterModel.MQ_DASH_BLADES])
		_:
			if use == "ranged" or ranged_grip:
				# Выстрел умением: из лука — натяжение; арбалет — прежний выстрел (своих клипов умений нет)
				if grip == "bow":
					chain.append(["grip", CharacterModel.MQ_BOW_SKILLS])
			else:
				if CharacterModel.MQ_STRIKES.has(grip):
					chain.append(["grip", CharacterModel.MQ_STRIKES[grip]])
				chain.append(["shared", ["mq_charged_slash"]])
	return chain


## Цепочка обычной атаки по хвату (арбалет — прежний выстрел UAL, см. CharacterModel.play_attack).
static func attack_chain(grip: String) -> Array:
	var chain: Array = []
	if CharacterModel.MQ_ATTACKS.has(grip):
		chain.append(["grip", CharacterModel.MQ_ATTACKS[grip]])
	return chain


## Первый уровень цепочки, у которого есть клипы в модели: {level, names}; has_clip(ключ) → настоящее имя или "".
## Ничего — {level: "legacy", names: []}.
static func pick(chain: Array, has_clip: Callable) -> Dictionary:
	for lv in chain:
		var names: Array[String] = []
		for k in lv[1]:
			var c := String(has_clip.call(String(k)))
			if c != "":
				names.append(c)
		if not names.is_empty():
			return {"level": String(lv[0]), "names": names}
	return {"level": "legacy", "names": [] as Array[String]}


## Учёт решения (диагностика, отчёт Кардинала и тест-бота).
static func note(action: String, grip: String, sid: String, level: String, clip: String) -> void:
	var by: Dictionary = stats.get(action, {})
	by[level] = int(by.get(level, 0)) + 1
	stats[action] = by
	if level == "legacy" or level == "idle":
		var key := "%s/%s" % [action, grip]
		missing[key] = int(missing.get(key, 0)) + 1
	trace.append({"t": Util.game_time(), "action": action, "grip": grip, "sid": sid, "level": level, "clip": clip})
	if trace.size() > TRACE_MAX:
		trace.pop_front()
	if verbose:
		print("ANIM %s grip=%s sid=%s → %s %s" % [action, grip, sid, level, clip])


static func reset_stats() -> void:
	stats.clear()
	missing.clear()
	trace.clear()


## Тип актёра по ключу действия: "npc:…", "pet:…", "mob:…" — жители, питомцы, звери; остальное — герой.
static func actor_of(action: String) -> String:
	for a in ACTORS:
		if action.begins_with(a + ":"):
			return a
	return "hero"


## Сводка: {total, by_level {уровень: раз}, by_actor {актёр: раз}, missing {…}}.
static func summary() -> Dictionary:
	var by: Dictionary = {}
	var actors: Dictionary = {}
	var total := 0
	for a in stats:
		var who := actor_of(String(a))
		for lv in stats[a]:
			by[lv] = int(by.get(lv, 0)) + int(stats[a][lv])
			actors[who] = int(actors.get(who, 0)) + int(stats[a][lv])
			total += int(stats[a][lv])
	return {"total": total, "by_level": by, "by_actor": actors, "missing": missing.duplicate()}


## Строка для отчёта: «запросов N: skill a, grip b, shared c, legacy d, idle e; без своего клипа: …».
static func summary_line() -> String:
	var s := summary()
	var parts: Array[String] = []
	for lv in LEVELS:
		parts.append("%s %d" % [lv, int(s["by_level"].get(lv, 0))])
	var who: Array[String] = []
	for a in ["hero"] + ACTORS:
		if int(s["by_actor"].get(a, 0)) > 0:
			who.append("%s %d" % [ACTOR_NAMES[a], int(s["by_actor"][a])])
	var line := "запросов %d (%s): %s" % [int(s["total"]), ", ".join(who) if not who.is_empty() else "—", ", ".join(parts)]
	if not s["missing"].is_empty():
		var miss: Array[String] = []
		for k in s["missing"]:
			miss.append("%s ×%d" % [k, int(s["missing"][k])])
		line += "; без своего клипа: " + ", ".join(miss)
	return line


# ---------- Матрица покрытия ----------

## Прежний жест (ключ ASSET_ACTIONS), который играет модель из файла, когда своего клипа нет (Player._anim_by_kind →
## play_bash / play_spin / play_cast …, CharacterModel.play_attack).
static func legacy_action(action: String, grip: String) -> String:
	match action:
		"attack":
			if RANGED_GRIPS.has(grip):
				return "shoot"
			return "cast" if grip == "staff" else "slash"
		"strike", "bash":
			return "combo"
		"spin":
			return "spin"
		"dash":
			return "leap"
		"ranged_skill":
			return "shoot"
		"cast":
			return "cast"
		"buff", "cast_self":
			return "buff"
	return ""

## Клипы модели по её <id>.json (ключи в нижнем регистре → имя), без загрузки GLB.
static func rig_clips(json_path: String) -> Dictionary:
	var out: Dictionary = {}
	var rig := CharacterModel.asset_rig(json_path.replace(".json", ".glb"))
	for c in rig.get("clips", {}):
		out[String(c).to_lower()] = String(c)
	return out


## Строки матрицы покрытия одной модели: [{model, variant, class, grip, action, level, clip, status}].
## status: implemented_unverified (свой клип уровня skill/grip/shared), missing (только прежний жест или покой),
## not_applicable (профессия этим оружием не владеет). verified ставит тест, проигравший клип на настоящей модели.
static func coverage(model_id: String, class_id: String, clips: Dictionary) -> Array:
	var rows: Array = []
	var has := func(k: String) -> String: return String(clips.get(k, ""))
	var weapons: Array = ClassData.CLASSES.get(class_id, {}).get("weapons", []) if class_id != "" else []
	for grip in COVER_GRIPS:
		var applicable := class_id == "" or class_id == ClassData.WANDERER
		for w in GRIP_WEAPON[grip]:
			applicable = applicable or weapons.has(w)
		var melee := not ["bow", "crossbow", "staff"].has(grip)
		for a in COVER_ACTIONS:
			var chain := attack_chain(grip) if String(a[1]) == "" else skill_chain(String(a[1]), "", String(a[2]), grip, melee)
			var r := pick(chain, has)
			var status := "implemented_unverified"
			# Стрелковые умения требуют лук или арбалет (HeroSkills.WEAPON_GROUPS)
			if not applicable or (String(a[0]) == "ranged_skill" and not RANGED_GRIPS.has(grip)):
				status = "not_applicable"
			elif r["level"] == "legacy":
				# Прежний жест модели (ASSET_ACTIONS) — тоже клип; нет и его — покой (missing)
				var la := legacy_action(String(a[0]), grip)
				var found := ""
				for o in CharacterModel.ASSET_ACTIONS.get(la, []):
					for k in clips:
						if found == "" and String(k).contains(String(o[0])):
							found = String(clips[k])
				if found != "":
					r = {"level": "legacy", "names": [found]}
				else:
					r = {"level": "idle", "names": []}
					status = "missing"
			rows.append({"model": model_id, "variant": "f" if model_id.contains("_f") else "m", "class": class_id,
				"grip": grip, "action": String(a[0]), "level": r["level"],
				"clip": ";".join(r["names"]), "status": status})
	return rows


## Строки матрицы покрытия существа (модель из creatures.json): для каждого клипа CreatureAsset.CLIPS — свой,
## замена (legacy) или нет (missing). Декоративные (овцы) — только покой и шаг, остальное not_applicable.
static func creature_coverage(model_id: String, clips: Dictionary) -> Array:
	var rows: Array = []
	var have: Dictionary = {}
	for c in clips:
		have[String(c).to_lower()] = String(c)
	var decor := CREATURE_DECOR.has(model_id.get_slice("_", 0))
	for k in CreatureAsset.CLIPS:
		var row := {"model": model_id, "variant": "-", "class": "creature", "grip": "-", "action": String(k),
			"level": "grip", "clip": String(have.get(k, "")), "status": "implemented_unverified"}
		if decor and not ["idle", "walk"].has(k):
			row["status"] = "not_applicable"
			row["level"] = "-"
		elif not have.has(k):
			var sub := String(CREATURE_FALLBACK.get(k, ""))
			if sub != "" and have.has(sub):
				row["level"] = "legacy"
				row["clip"] = have[sub]
			else:
				row["level"] = "idle"
				row["status"] = "missing"
		rows.append(row)
	return rows


## Строки матрицы покрытия жителя (npc_<id>.json): покой и приветствие.
static func npc_coverage(model_id: String, clips: Dictionary) -> Array:
	var rows: Array = []
	for a in NPC_ACTIONS:
		var found := ""
		for k in clips:
			if found == "" and String(k).to_lower() == a:
				found = String(clips[k])
		rows.append({"model": model_id, "variant": "f" if model_id.ends_with("_f") else "-", "class": "npc", "grip": "-",
			"action": a, "level": "grip" if found != "" else "idle", "clip": found,
			"status": "implemented_unverified" if found != "" else "missing"})
	return rows


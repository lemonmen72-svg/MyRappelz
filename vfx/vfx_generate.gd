class_name VfxGenerate
extends RefCounted
## Генератор таблицы эффектов умений (docs/vfx/VFX_ARCHITECTURE.md): проходит по всем умениям героя (HeroSkills —
## Наёмник, JobSkills — 8 профессий), питомцев (PetSkills по видам PetData.SPECIES) и способностям монстров
## (MobData: удар по площади, проклятия) и по правилам VfxRules собирает записи. Запуск —
## `godot --headless --path . res://tools/vfx_generate.tscn` (пишет vfx/skill_vfx.json и
## docs/vfx/VFX_PRESETS_CATALOG.md); тест tests/test_vfx_gen.gd проверяет, что файл совпадает с правилами.

const VERSION := 1


## Вся таблица: {"version", "hero": {id: запись}, "pet": {"вид:id": запись}, "mob": {ключ: запись}}.
static func build_table() -> Dictionary:
	var hero := {}
	var ids: Array = []
	for id in HeroSkills.SKILLS:
		ids.append(String(id))
	for id in JobSkills.SKILLS:
		if not ids.has(String(id)):
			ids.append(String(id))
	ids.sort()
	for sid in ids:
		var sk := HeroSkills.get_skill(sid)
		var e := VfxRules.hero(sid, sk)
		if not e.is_empty():
			hero[sid] = e
	var pet := {}
	var species: Array = PetData.SPECIES.keys()
	species.sort()
	for sp in species:
		var list: Array = PetSkills.list_for(String(sp)).duplicate()
		list.sort()
		for sid in list:
			var sk := PetSkills.get_skill(String(sid))
			var e := VfxRules.pet(String(sid), sk, String(sp))
			if not e.is_empty():
				pet["%s:%s" % [sp, sid]] = e
	return {"version": VERSION, "hero": hero, "pet": pet, "mob": VfxRules.mobs()}


## Таблица текстом JSON (ключи по порядку — файл не меняется без причины).
static func table_json() -> String:
	return JSON.stringify(build_table(), "\t", true)


## Каталог для людей: умение → эффекты фаз (Markdown).
static func catalog_md(t: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("# Dark Pact — каталог эффектов умений")
	lines.append("")
	lines.append("Сгенерировано `tools/vfx_generate.gd` по правилам `vfx/vfx_rules.gd`; ручные правки — `vfx/skill_vfx_overrides.json`.")
	lines.append("Фазы: каст — на герое, пока идёт каст; выпуск — сила срывается с рук; снаряд — вид полёта; попадание — по цели;")
	lines.append("площадь — вокруг цели; усиление — на герое или питомце. Стоимость: частиц на «Высоком» (на «Среднем» ×0.7, на «Низком» ×0.4).")
	lines.append("")
	lines.append("## Архетипы")
	lines.append("")
	lines.append("| Архетип | Категория | Фаза | Название |")
	lines.append("|---|---|---|---|")
	var arch_keys: Array = VfxArchetypes.LIST.keys()
	for a in arch_keys:
		var d: Dictionary = VfxArchetypes.LIST[a]
		lines.append("| `%s` | %s | %s | %s |" % [a, d["cat"], d["phase"], d["title"]])
	var count := {}
	for g in ["hero", "pet", "mob"]:
		for k in (t.get(g, {}) as Dictionary):
			var e: Dictionary = t[g][k]
			for ph in e:
				if e[ph] is Dictionary and (e[ph] as Dictionary).has("arch"):
					var a := String(e[ph]["arch"])
					count[a] = int(count.get(a, 0)) + 1
	lines.append("")
	lines.append("Сколько раз используется: " + ", ".join(PackedStringArray(_counts(count))))
	for g in [["hero", "Умения героя"], ["pet", "Умения питомцев"], ["mob", "Способности монстров"]]:
		lines.append("")
		lines.append("## " + String(g[1]))
		lines.append("")
		lines.append("| Умение | Стихия | Каст | Выпуск | Снаряд | Попадание | Площадь | Усиление |")
		lines.append("|---|---|---|---|---|---|---|---|")
		var tab: Dictionary = t.get(g[0], {})
		var keys: Array = tab.keys()
		keys.sort()
		for k in keys:
			var e: Dictionary = tab[k]
			var nm := _name(String(g[0]), String(k))
			lines.append("| %s | %s | %s | %s | %s | %s | %s | %s |" % [nm, e.get("el", ""), _ph(e, "cast"),
				_ph(e, "release"), (e["proj"]["el"] if e.has("proj") else ""), _ph(e, "impact"), _ph(e, "area"),
				_ph(e, "buff")])
	return "\n".join(lines) + "\n"


static func _counts(count: Dictionary) -> Array:
	var keys: Array = count.keys()
	keys.sort_custom(func(a, b): return int(count[a]) > int(count[b]))
	var r: Array = []
	for k in keys:
		r.append("`%s` %d" % [k, int(count[k])])
	return r


static func _ph(e: Dictionary, ph: String) -> String:
	if not e.has(ph):
		return ""
	var p: Dictionary = e[ph]
	var s := String(p.get("arch", ""))
	if float(p.get("scale", 1.0)) != 1.0:
		s += " ×%s" % str(p["scale"])
	return s


static func _name(group: String, key: String) -> String:
	match group:
		"hero":
			return "%s `%s`" % [String(HeroSkills.get_skill(key).get("name", key)), key]
		"pet":
			var parts := key.split(":")
			return "%s: %s `%s`" % [String(PetData.SPECIES.get(parts[0], {}).get("name", parts[0])),
				String(PetSkills.get_skill(parts[1]).get("name", parts[1])), parts[1]]
	return "`%s`" % key

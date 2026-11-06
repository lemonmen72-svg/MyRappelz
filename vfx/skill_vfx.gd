class_name SkillVfx
extends RefCounted
## Эффекты умений в игре (генератор VFX, docs/vfx/VFX_ARCHITECTURE.md): таблица vfx/skill_vfx.json (пишет
## tools/vfx_generate.gd по VfxRules) + ручные правки vfx/skill_vfx_overrides.json → по событию боя собирает эффект
## фазы через VfxArchetypes. Эффекты — только картинка: урон, тайминги и логику не меняют.
## Группы: "hero" (id умения героя), "pet" ("<вид>:<id>"), "mob" ("<вид>:slam", "<вид>:curse:<вид проклятия>").
## Нет записи или фазы — вызов возвращает null, и место вызова показывает прежний эффект Vfx (откат).
## Нагрузка: эффект дальше FAR от камеры не строится, дальше LOW_DIST — низкое качество; больше MAX_ACTIVE
## эффектов сразу — низкое качество, больше MAX_ACTIVE × 1.5 — новые не строятся. Качество — «Качество эффектов»
## (Quality.effective("effects"), с учётом авто-снижения при нагреве).

const PATH := "res://vfx/skill_vfx.json"
const OVERRIDES := "res://vfx/skill_vfx_overrides.json"
const MAX_ACTIVE := 36
const FAR := 55.0
const LOW_DIST := 26.0

## Новые эффекты включены (false — везде прежние эффекты Vfx; админ-панель «Тест-бот» → «Эффекты»).
static var enabled := true
## Качество для тестов (−1 — по настройке).
static var quality_override := -1
## Сколько эффектов построено с запуска (по фазам) — для отчётов и тестов.
static var built := {}
static var _table: Dictionary = {}
static var _loaded := false


static func table() -> Dictionary:
	if not _loaded:
		_loaded = true
		_table = _read(PATH)
		var ov := _read(OVERRIDES)
		for g in ov:
			if not _table.has(g):
				_table[g] = {}
			var gt: Dictionary = _table[g]
			for k in (ov[g] as Dictionary):
				var e: Dictionary = (gt.get(k, {}) as Dictionary).duplicate(true)
				var o: Dictionary = ov[g][k]
				for ph in o:
					if o[ph] == null:
						e.erase(ph)
					elif o[ph] is Dictionary and e.get(ph) is Dictionary:
						var merged: Dictionary = (e[ph] as Dictionary).duplicate()
						merged.merge(o[ph], true)
						e[ph] = merged
					else:
						e[ph] = o[ph]
				gt[k] = e
	return _table


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (v is Dictionary):
		return {}
	var d: Dictionary = v
	d.erase("version")
	d.erase("note")
	return d


static func reload() -> void:
	_loaded = false
	_table = {}


static func entry(group: String, key: String) -> Dictionary:
	if not enabled:
		return {}
	var g: Dictionary = table().get(group, {})
	return g.get(key, {})


static func has_phase(group: String, key: String, phase: String) -> bool:
	return entry(group, key).has(phase)


## Качество эффекта в точке pos: −1 — не строить (далеко или слишком много эффектов), 0–2.
static func quality_at(tree_node: Node, pos: Vector3) -> int:
	var q := quality_override if quality_override >= 0 else Quality.effective("effects")
	var active := tree_node.get_tree().get_nodes_in_group("vfx").size() if tree_node.is_inside_tree() else 0
	if active > int(MAX_ACTIVE * 1.5):
		return -1
	if active > MAX_ACTIVE:
		q = 0
	var vp := tree_node.get_viewport() if tree_node.is_inside_tree() else null
	var cam := vp.get_camera_3d() if vp != null else null
	if cam != null:
		var d := cam.global_position.distance_to(pos)
		if d > FAR:
			return -1
		if d > LOW_DIST:
			q = mini(q, 0)
	return clampi(q, 0, 2)


## Эффект фазы phase записи group/key в точке pos (parent — куда добавить: мир). o — как VfxArchetypes.build
## (dir, ground, from, to, height); dur — переопределить длительность (каст). null — нет записи или не строится.
static func play(group: String, key: String, phase: String, parent: Node, pos: Vector3, o: Dictionary = {}) -> Node3D:
	var e := entry(group, key)
	if not e.has(phase) or parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var pr: Dictionary = (e[phase] as Dictionary).duplicate()
	if o.has("dur"):
		pr["dur"] = float(o["dur"])
	var q := quality_at(parent, pos)
	if q < 0:
		return null
	var oo := o.duplicate()
	oo["q"] = q
	var root := VfxArchetypes.build(pr, parent, pos, oo)
	if root != null:
		built[phase] = int(built.get(phase, 0)) + 1
	return root


## Снаряд умения (для Projectile): {group, key} и el — вид шара (если у записи есть фаза proj); {} — нет записи,
## снаряд и попадание прежние.
static func proj_style(group: String, key: String) -> Dictionary:
	var e := entry(group, key)
	if e.is_empty():
		return {}
	var s: Dictionary = (e["proj"] as Dictionary).duplicate() if e.has("proj") else {}
	s["group"] = group
	s["key"] = key
	return s


# ---------- Удобные вызовы для героя, питомца, зверя ----------

## Опции эффекта на сущности who (герой, питомец, зверь): земля под ней, рост, направление от from.
static func opts_on(who: Node3D, from: Vector3 = Vector3.INF) -> Dictionary:
	var o := {"ground": who.global_position, "height": _height(who)}
	if from != Vector3.INF:
		var d := who.global_position - from
		o["dir"] = d
		o["from"] = from + Vector3(0, 1.2, 0)
	return o


static func _height(who: Node3D) -> float:
	var h: Variant = who.get("_height")
	if h is float and float(h) > 0.1:
		return float(h)
	return 1.7


## Точка попадания по зверю (центр тела; у парящих — на высоте парения).
static func aim_of(who: Node3D) -> Vector3:
	if who.has_method("aim_point"):
		return who.call("aim_point")
	return who.global_position + Vector3(0, 1.0, 0)


## Попадание умения по цели t (и площадь вокруг неё, если есть). true — новый эффект показан.
static func impact(group: String, key: String, caster: Node3D, t: Node3D) -> bool:
	if t == null or not is_instance_valid(t) or caster == null:
		return false
	var parent := caster.get_parent()
	var o := opts_on(t, caster.global_position)
	var a := play(group, key, "impact", parent, aim_of(t), o)
	var b := play(group, key, "area", parent, t.global_position + Vector3(0, 0.6, 0), o)
	return a != null or b != null or has_phase(group, key, "impact") or has_phase(group, key, "area")


## Площадь вокруг самого героя (умения "near").
static func area_at(group: String, key: String, who: Node3D) -> bool:
	if who == null:
		return false
	return play(group, key, "area", who.get_parent(), who.global_position + Vector3(0, 0.6, 0), opts_on(who)) != null \
		or has_phase(group, key, "area")


## Выпуск силы на герое (направление к цели t, если есть).
static func release(group: String, key: String, caster: Node3D, t: Node3D = null) -> bool:
	if caster == null:
		return false
	var o := opts_on(caster)
	if t != null and is_instance_valid(t):
		o["dir"] = t.global_position - caster.global_position
	return play(group, key, "release", caster.get_parent(), caster.global_position + Vector3(0, 0.1, 0), o) != null


## Усиление / лечение на who (герой или питомец).
static func buff(group: String, key: String, who: Node3D) -> bool:
	if who == null or not is_instance_valid(who):
		return false
	return play(group, key, "buff", who.get_parent(), who.global_position + Vector3(0, 0.1, 0), opts_on(who)) != null \
		or has_phase(group, key, "buff")


## Каст: эффект на герое на sec с (узел следует за героем). Вернёт узел — VfxArchetypes.stop при прерывании.
static func cast_start(group: String, key: String, caster: Node3D, sec: float, t: Node3D = null) -> Node3D:
	if caster == null:
		return null
	var o := opts_on(caster)
	o["dur"] = sec
	if t != null and is_instance_valid(t):
		o["dir"] = t.global_position - caster.global_position
	# Эффект каста — дочерний узел героя: идёт вместе с ним (земля — под героем, в его координатах)
	var root := play(group, key, "cast", caster, caster.global_position + Vector3(0, 0.1, 0), o)
	return root


static func cast_stop(root: Node) -> void:
	VfxArchetypes.stop(root)

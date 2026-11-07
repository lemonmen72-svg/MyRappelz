class_name StatusFx
extends Node3D
## Ослабления на герое и звере — нарисованные петли (раскадровки VfxFlip, 0.46.1): над головой — оглушение, сон,
## страх, морок, проклятие; у тела — путы, оковы замедления, яд, кровь, горение, ослабление. Узел — ребёнок сущности
## (StatusEffects.host): появляется при первом ослаблении (StatusEffects.add → watch), сверяет набор раз в CHECK с и
## уходит сам, когда ослаблений не осталось. Не больше одного слоя над головой и одного у тела (по порядку правил —
## первое подходящее); дальше FAR от камеры и у мёртвых — без слоёв. Без листа (часть пакета «vfx») — ничего:
## значки у полоски HP остаются как были.

const CHECK := 0.25
const FAR := 40.0
## Над головой: [id эффекта (на «*» — начало id), лист, стихия палитры, где ("above" — над макушкой, "eyes" — у
## глаз), сторона кадра, м (у зверя — ещё × размер)].
const HEAD := [
	["stun", "stun_stars", "light", "above", 1.25],
	["curse:stun", "stun_stars", "light", "above", 1.25],
	["sleep", "sleep_mist", "mind", "above", 1.3],
	["fear", "fear_wisps", "dark", "eyes", 1.5],
	["blind", "blind_veil", "mind", "eyes", 1.5],
	["miss", "blind_veil", "steel", "eyes", 1.4],
	["curse:*", "curse_mark", "emerald", "above", 1.15],
	["buff:curse_*", "curse_mark", "emerald", "above", 1.15],
]
## У тела: [id или начало id*, лист ("" — по стихии урона со временем: огонь — горение, яд и тьма — пузыри,
## остальное — кровь), стихия, сторона кадра, м].
const BODY := [
	["snare", "root_vines", "beast", 1.9],
	["slow", "slow_shackles", "ice", 1.8],
	["aslow", "slow_shackles", "ice", 1.8],
	["buff:curse_slow", "slow_shackles", "emerald", 1.8],
	["buff:curse_aslow", "slow_shackles", "emerald", 1.8],
	["curse:poison", "poison_bubbles", "poison", 1.9],
	["dot:*", "", "", 1.9],
	["weak", "weaken_down", "blood", 2.0],
	["vuln", "weaken_down", "blood", 2.0],
	["armor", "weaken_down", "blood", 2.0],
	["ward", "weaken_down", "mind", 2.0],
	["buff:curse_armor", "weaken_down", "emerald", 2.0],
]

## Сколько слоёв построено с запуска (тест, отчёт).
static var built := 0
## Стихия урона со временем по id умения (кэш).
static var _dot_el := {}

var host: Node3D = null
var _t := 0.0
var _ver := -1
var _far := false
var _head := {}
var _body := {}


## Ослабление наложено на сущность e: завести ей узел слоёв (или разбудить его).
static func watch(e: Node3D) -> void:
	if e == null or not is_instance_valid(e) or not e.is_inside_tree() or not VfxFlip.enabled:
		return
	var s := e.get_node_or_null("StatusFx") as StatusFx
	if s != null:
		s._t = CHECK
		return
	s = StatusFx.new()
	s.name = "StatusFx"
	s.host = e
	s._t = CHECK
	e.add_child(s)


## Листы, которые слои могут взять (загрузить заранее, проверить в тесте).
static func sheets() -> Array:
	var out: Array = ["burn_loop", "poison_bubbles", "bleed_drops"]
	for r in HEAD + BODY:
		var id := String((r as Array)[1])
		if id != "" and not id in out:
			out.append(id)
	return out


func _process(delta: float) -> void:
	_t += delta
	if _t < CHECK:
		return
	_t = 0.0
	if host == null or not is_instance_valid(host):
		queue_free()
		return
	var fx: StatusEffects = host.get("effects")
	if fx == null:
		queue_free()
		return
	var far := _is_far()
	if fx.version == _ver and far == _far:
		return
	_ver = fx.version
	_far = far
	var off: bool = far or host.get("is_dead") == true or not VfxFlip.enabled
	var hw: Array = [] if off else _pick(HEAD, fx)
	var bw: Array = [] if off else _pick(BODY, fx)
	_head = _apply(_head, hw, true)
	_body = _apply(_body, bw, false)
	if _head.is_empty() and _body.is_empty() and not _has_debuff(fx):
		queue_free()


func _is_far() -> bool:
	var cam := host.get_viewport().get_camera_3d() if host.get_viewport() != null else null
	return cam != null and cam.global_position.distance_to(host.global_position) > FAR


func _has_debuff(fx: StatusEffects) -> bool:
	for e in fx.entries():
		if bool(e.get("debuff", false)):
			return true
	return false


## Первое правило списка rules, под которое подходит действующий эффект: [правило, id эффекта] или [].
func _pick(rules: Array, fx: StatusEffects) -> Array:
	var ids: Array = []
	for e in fx.entries():
		if bool(e.get("debuff", false)):
			ids.append(String(e["id"]))
	if ids.is_empty():
		return []
	for r in rules:
		var key := String((r as Array)[0])
		for id in ids:
			if (key.ends_with("*") and String(id).begins_with(key.trim_suffix("*"))) or id == key:
				var rule: Array = (r as Array).duplicate()
				if String(rule[1]) == "":
					var el := dot_element(String(id).trim_prefix("dot:"))
					rule[1] = "burn_loop" if el == "fire" else ("poison_bubbles" if el in ["poison", "dark", "emerald"]
						else "bleed_drops")
					rule[2] = el if el in ["fire", "poison", "dark", "emerald"] else "blood"
				return [rule, id]
	return []


## Слой slot (было) → want ([правило, id] или []): тот же лист — оставить, иначе погасить старый и построить новый.
func _apply(slot: Dictionary, want: Array, head: bool) -> Dictionary:
	var key := "" if want.is_empty() else "%s|%s" % [want[0][1], want[0][2]]
	if not slot.is_empty() and String(slot.get("key", "")) == key and is_instance_valid(slot.get("node")):
		return slot
	if not slot.is_empty():
		_drop(slot.get("node"))
	if want.is_empty():
		return {}
	var rule: Array = want[0]
	var node := _make(rule, String(want[1]), head)
	if node == null:
		return {}
	built += 1
	return {"key": key, "node": node}


func _make(rule: Array, effect_id: String, head: bool) -> MeshInstance3D:
	var sheet := String(rule[1])
	if not VfxFlip.has(sheet):
		return null
	var h := float(host.get("_height")) if host.get("_height") != null else 1.75
	var k := clampf(float(host.get("body_scale")), 0.8, 2.0) if host.get("body_scale") != null else 1.0
	var o := {"pal": VfxArchetypes.palette(String(rule[2])), "loop": true, "speed": 12.0, "mirror": false}
	var size := float(rule[4] if head else rule[3]) * k
	if head:
		o["offset"] = Vector3(0, h + 0.3 * k if String(rule[3]) == "above" else h * 0.86, 0)
		o["push"] = 0.35
	else:
		o["offset"] = Vector3.ZERO
		o["push"] = 0.45
		if sheet == "root_vines":
			# Путы — разовый лист: вырастают, держат и крошатся за время действия
			var fx: StatusEffects = host.get("effects")
			o["loop"] = false
			o["time_left"] = clampf(float(fx.get_entry(effect_id).get("left", 3.0)), 1.2, 10.0)
	var time := float(o.get("time_left", 3600.0))
	return VfxKit.flipbook(self, sheet, size, time, o)


func _drop(n: Variant) -> void:
	if n == null or not is_instance_valid(n):
		return
	var mi := n as MeshInstance3D
	var m := mi.material_override as VfxMat
	if m == null:
		mi.queue_free()
		return
	var t := mi.create_tween()
	t.tween_property(m, "albedo_color:a", 0.0, 0.25)
	t.tween_callback(mi.queue_free)


## Стихия урона со временем dot (id умения героя или "pet_<id>" питомца; яд Воина, яд камня Шамана).
static func dot_element(dot: String) -> String:
	if _dot_el.has(dot):
		return String(_dot_el[dot])
	var el := ""
	if dot.begins_with("pet_"):
		var psk := PetSkills.get_skill(dot.trim_prefix("pet_"))
		if not psk.is_empty():
			el = VfxRules.element_of(psk)
	elif HeroSkills.is_skill(dot):
		el = VfxRules.element_of(HeroSkills.get_skill(dot))
	if dot in ["venom_tip", "stone_edge"]:
		el = "poison"
	_dot_el[dot] = el
	return el

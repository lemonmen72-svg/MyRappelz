class_name JobFxWizard
extends RefCounted
## Особые механики Волшебника; подключение — HeroSkillFx.JOB_FX_FILES (шесть функций, описание — шапка HeroSkillFx),
## данные — JobSkills.SKILLS. Обработчики (префикс wz_): "wz_revive_pet" — «Возвращение души»: первый погибший
##   питомец коллекции встаёт с долей pct HP и MP и сразу призывается к герою (как свиток воскрешения, но умением);
##   "wz_renew" — «Живительный свет»: тот, кому хуже (герой или призванный питомец), лечится сразу на pct макс. HP
##   (+ mult маг. атаки) и ещё на hot макс. HP за time с — узел Hot (ребёнок лечимого: раз в секунду, значок
##   «hot:<умение>» у полоски HP).
## «Сияющее лезвие» (бонус "light_hit"): попавшая обычная атака добавляет урон светом — доля маг. атаки через маг.
##   защиту зверя (on_basic_hit, счётчик fx.state["light_hits"]).
## Остальное у Волшебника — данными движка (лечение, щиты-«купола» через бонус guard, лёд и свет: замедление ударов
## "aslow", обездвиживание "snare", зона «Топь» — JobFxNeophyte "ne_zone").

const HOLY := Color(1.0, 0.9, 0.5)
const LIGHT := Color(1.0, 0.9, 0.5)


## Особая механика handler умения sid уровня n по цели t (может быть null). false — обработчик не наш.
static func special(fx: HeroSkillFx, handler: String, sid: String, n: int, _t: Mob, e: Dictionary) -> bool:
	match handler:
		"wz_revive_pet":
			_revive_pet(fx, n, e)
		"wz_renew":
			_renew(fx, sid, n, e)
		_:
			return false
	return true


## Можно ли применить ("" — можно): есть ли погибший питомец.
static func pre_cast(_fx: HeroSkillFx, _sid: String, _n: int, sk: Dictionary) -> String:
	for item in sk.get("fx", []):
		var e: Dictionary = item
		if String(e.get("handler", "")) == "wz_revive_pet" and dead_pet() < 0:
			return "нет погибших питомцев"
	return ""


## «Сияющее лезвие»: доп. урон светом попавшей обычной атаки.
static func on_basic_hit(fx: HeroSkillFx, t: Mob, _dealt: int) -> void:
	element_hit(fx, t, "light_hit", LIGHT)


## Доп. урон стихией по t: бонус key — доля маг. атаки (через маг. защиту зверя); счётчик fx.state[key + "s"].
static func element_hit(fx: HeroSkillFx, t: Mob, key: String, col: Color) -> void:
	var v := fx.bonus(key)
	if v <= 0.0 or t == null or not is_instance_valid(t) or t.is_dead:
		return
	var p := fx.p
	t.take_damage(maxi(1, roundi(float(p.cur_matk()) * v * p.damage_factor(t, true))), p, false, true)
	fx.state[key + "s"] = int(fx.state.get(key + "s", 0)) + 1
	if p.is_inside_tree():
		Vfx.hit_spark(p.get_parent(), t.aim_point(), col, 0.8)


static func on_hurt(_fx: HeroSkillFx, _attacker: Node3D, _amount: int) -> void:
	pass


static func tick(_fx: HeroSkillFx, _delta: float) -> void:
	pass


static func reset(_fx: HeroSkillFx) -> void:
	pass


## Индекс первого погибшего питомца коллекции (-1 — все живы).
static func dead_pet() -> int:
	for i in Game.pets.size():
		if bool((Game.pets[i] as Dictionary).get("dead", false)):
			return i
	return -1


## «Возвращение души»: питомец встаёт с долей pct HP и MP и призывается.
static func _revive_pet(fx: HeroSkillFx, n: int, e: Dictionary) -> void:
	var i := dead_pet()
	if i < 0:
		return
	var rec: Dictionary = Game.pets[i]
	var pct := HeroSkills.value_at(e.get("pct", 0.3), n)
	PetSkills.ensure_record(rec)
	var st := PetData.stats_for(String(rec.get("species", "boar")), int(rec.get("level", 1)), rec["skills"], rec["toggles"])
	rec["dead"] = false
	rec["hp"] = maxi(1, roundi(float(st["max_hp"]) * pct))
	rec["mp"] = maxi(0, roundi(float(st["max_mp"]) * pct))
	var p := fx.p
	var parent := p.get_parent()
	var mgr: PetManager = null
	if parent != null:
		mgr = parent.get("pets") as PetManager
	if mgr != null:
		mgr.summon(i)
	else:
		Game.changed.emit()
	var pet := p._active_pet()
	var pos: Vector3 = p.global_position
	if pet != null:
		pos = pet.global_position
	JobFxNeophyte.lightning(parent, pos, HOLY, 0.5, 4.0)
	Vfx.heal_sparkles(parent, pos, 1.2)
	p.message.emit("Питомец «%s» возвращён к жизни" % String(rec.get("name", "")))


## «Живительный свет»: лечение сразу и понемногу ещё time с тому, кому хуже.
static func _renew(fx: HeroSkillFx, sid: String, n: int, e: Dictionary) -> void:
	var node := fx._heal_target("ally")
	if node == null:
		return
	var mx := float(node.get("max_hp"))
	var now := maxi(1, roundi(mx * HeroSkills.value_at(e.get("pct", 0.1), n)
		+ float(fx.p.cur_matk()) * HeroSkills.value_at(e.get("mult", 0.0), n)))
	node.call("heal", now)
	add_hot(fx.p, node, sid, mx * HeroSkills.value_at(e.get("hot", 0.2), n), HeroSkills.value_at(e.get("time", 30.0), n))


## Лечение со временем: всего total HP узлу node (герой или питомец) за sec с, раз в секунду; повтор обновляет.
static func add_hot(p: Player, node: Node3D, sid: String, total: float, sec: float) -> void:
	if node == null or not is_instance_valid(node) or total <= 0.0 or sec <= 0.0:
		return
	var nm := "Hot_" + sid
	var h := node.get_node_or_null(nm) as Hot
	if h == null:
		h = Hot.new()
		h.name = nm
		node.add_child(h)
	h.target = node
	h.player = p
	h.key = "hot:" + sid
	h.per_sec = total / sec
	h.left = sec
	var reg := node.get("effects") as StatusEffects
	if reg != null:
		reg.add(h.key, sec, StatusEffects.effect_info("hot", StatusEffects.source_hero_skill(sid)))


## Лечение со временем (узел-ребёнок лечимого): раз в секунду накопленное HP.
class Hot extends Node:
	var target: Node3D
	var player: Player
	var key := ""
	var per_sec := 0.0
	var left := 0.0
	## Сколько всего вылечено (для тестов).
	var healed := 0
	var _acc := 0.0
	var _step := 1.0

	func _process(delta: float) -> void:
		if not is_instance_valid(target) or target.get("is_down") == true:
			queue_free()
			return
		var dt := minf(delta, maxf(left, 0.0))
		left -= delta
		_acc += per_sec * dt
		_step -= delta
		var reg := target.get("effects") as StatusEffects
		if reg != null:
			reg.sync(key, left)
		if _step <= 0.0 or left <= 0.0:
			_step = 1.0
			var whole := int(_acc)
			if whole >= 1:
				_acc -= float(whole)
				healed += whole
				_apply(whole)
		if left <= 0.0:
			queue_free()

	## Герою — тихо (без вспышки каждую секунду), питомцу — его heal.
	func _apply(amount: int) -> void:
		var pl := target as Player
		if pl != null:
			if pl.hp >= pl.max_hp:
				return
			pl.hp = mini(pl.max_hp, pl.hp + amount)
			Util.float_text(pl.get_parent(), pl.global_position + Vector3(0, 2.3, 0), "+%d" % amount, Color(0.5, 1, 0.5), 0.8)
			pl.stats_changed.emit()
		elif target.has_method("heal"):
			target.call("heal", amount)

class_name JobFxWizard
extends RefCounted
## Особые механики Волшебника; подключение — HeroSkillFx.JOB_FX_FILES (шесть функций, описание — шапка HeroSkillFx),
## данные — JobSkills.SKILLS. «Возвращение души» — общий обработчик revive_pet (PetBond, через job_fx_beastmaster.gd:
##   погибший последним питомец встаёт с долей HP и MP и призывается). Обработчик (префикс wz_): "wz_renew" —
##   «Живительный свет»: тот, кому хуже (герой или призванный питомец), лечится сразу на pct макс. HP (+ mult маг. атаки) и ещё на hot макс. HP за time с — узел Hot (ребёнок лечимого: раз в секунду, значок
##   «hot:<умение>» у полоски HP).
## «Сияющее лезвие» (бонус "light_hit"): попавшая обычная атака добавляет урон светом — доля маг. атаки через маг.
##   защиту зверя (on_basic_hit, счётчик fx.state["light_hits"]).
## Остальное у Волшебника — данными движка (лечение, щиты-«купола» через бонус guard, лёд и свет: замедление ударов
## "aslow", обездвиживание "snare", зона «Топь» — JobFxNeophyte "ne_zone").

const LIGHT := Color(1.0, 0.9, 0.5)


## Особая механика handler умения sid уровня n по цели t (может быть null). false — обработчик не наш.
static func special(fx: HeroSkillFx, handler: String, sid: String, n: int, _t: Mob, e: Dictionary) -> bool:
	match handler:
		"wz_renew":
			_renew(fx, sid, n, e)
		_:
			return false
	return true


## Особых условий нет («Возвращение души» — общий обработчик revive_pet, PetBond: проверка — там).
static func pre_cast(_fx: HeroSkillFx, _sid: String, _n: int, _sk: Dictionary) -> String:
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

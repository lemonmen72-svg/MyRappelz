class_name HeroSkillFx
extends RefCounted
## Движок эффектов умений героя: активные умения с полем fx (формат — HeroSkills, раздел «Движок эффектов»).
## Player.use_skill → _use_hero_skill → HeroSkillFx.cast: выбор цели по use ("melee", "ranged", "magic", "near",
## "self", "pet"), анимация (anim), снаряд (у "ranged" и у "magic" с proj = true — урон первого эффекта "damage"
## несёт снаряд, остальные эффекты — при попадании) и эффекты fx по порядку: damage, heal, hot, status, dot,
## knock, buff, special. Числа эффектов — массивы по уровням умения (HeroSkills.value_at).
## Особая механика (блок щитом с ответным уроном, призыв, жертва питомцем, слияние и т. п.) — метод
## sp_<имя>(sid, n, target, e) -> bool в этом файле и эффект {"do": "special", "handler": "<имя>"} в данных умения.
## Владелец — Player (поля и помощники: _find_target, _engage, _deal, _shoot, heal, add_timed_bonus, add_hot).

## Анимации героя по полю anim.
const ANIMS := ["attack", "cast", "bash", "spin", "buff", "dash"]

var p: Player


func _init(owner: Player) -> void:
	p = owner


## Применить умение sid уровня n (данные sk = HeroSkills.get_skill). false — не применилось (нет цели, нет питомца):
## MP и перезарядка не тратятся.
func cast(sid: String, n: int, sk: Dictionary) -> bool:
	var use := String(sk.get("use", "self"))
	var t: Mob = null
	match use:
		"melee":
			t = p._find_target(p.attack_range + Player.MELEE_SKILL_REACH)
		"ranged":
			t = p._find_target(p.attack_range)
		"magic":
			t = p._find_target(float(sk.get("range", maxf(p.attack_range, 10.0))))
		"near":
			t = p._find_target(float(sk.get("radius", 6.0)))
		"pet":
			if p._active_pet() == null:
				p.message.emit("Нет призванного питомца")
				return false
	if use == "melee" or use == "ranged" or use == "magic" or use == "near":
		if t == null:
			return p._no_target()
		p._engage(t)
	anim(String(sk.get("anim", "attack")))
	var fx: Array = sk.get("fx", [])
	var col: Color = sk.get("color", Color.WHITE)
	if use == "ranged" or (use == "magic" and bool(sk.get("proj", false))):
		var de := _find(fx, "damage")
		var dmg := roll(de, n) if not de.is_empty() else 1
		var cb := func(hit: Mob, dealt: int) -> void:
			if is_instance_valid(hit):
				apply(sid, n, hit, fx, dealt)
		p._shoot(t, dmg, 1.4, cb)
	else:
		apply(sid, n, t, fx, -1)
		if use == "self" or use == "pet":
			Projectile.burst(p.get_parent(), p.global_position + Vector3(0, 1.0, 0), col, 1.8, 0.35)
	p._announce(String(sk.get("name", sid)), "")
	return true


## Эффекты fx умения sid уровня n по цели t (может быть null у "self" / "pet"). proj_dealt ≥ 0 — урон первого
## эффекта "damage" уже нанёс снаряд (столько).
func apply(sid: String, n: int, t: Mob, fx: Array, proj_dealt: int) -> void:
	var src := StatusEffects.source_hero_skill(sid)
	var sk := HeroSkills.get_skill(sid)
	var col: Color = sk.get("color", Color.WHITE)
	var parent := p.get_parent()
	var dealt := 0
	var used_proj := proj_dealt < 0
	for item in fx:
		var e: Dictionary = item
		match String(e.get("do", "")):
			"damage":
				if t == null or not is_instance_valid(t):
					continue
				if not used_proj:
					used_proj = true
					dealt = proj_dealt
				else:
					var hits := maxi(1, int(HeroSkills.value_at(e.get("hits", 1), n)))
					for i in hits:
						if t.is_dead:
							break
						var dmg := roll(e, n)
						p._deal(t, dmg)
						dealt += dmg
					var dir := t.global_position - p.global_position
					if String(sk.get("use", "")) == "melee":
						Vfx.slash_arc(parent, t.aim_point(), dir, col, 1.2)
					else:
						Vfx.hit_spark(parent, t.aim_point(), col, 1.4)
				if e.has("area"):
					var r := HeroSkills.value_at(e["area"], n)
					Projectile.burst(parent, t.global_position + Vector3(0, 0.6, 0), col, r, 0.4)
					for m in p._mobs_around(t.global_position, r):
						if m != t:
							p._deal(m, roll(e, n))
				if e.has("leech") and dealt > 0:
					p.heal(maxi(1, roundi(float(dealt) * HeroSkills.value_at(e["leech"], n))))
			"heal":
				_heal(String(e.get("who", "self")), _heal_amount(e, n, String(e.get("who", "self"))))
			"hot":
				var hot_who := String(e.get("who", "self"))
				var total := _heal_amount(e, n, hot_who)
				p.add_hot(sid, _heal_target(hot_who), float(total), HeroSkills.value_at(e.get("time", 10.0), n))
			"status":
				var chance := HeroSkills.value_at(e.get("chance", 1.0), n)
				var targets: Array[Mob] = []
				if t != null and is_instance_valid(t) and not t.is_dead:
					targets.append(t)
				if e.has("area") and t != null and is_instance_valid(t):
					for m in p._mobs_around(t.global_position, HeroSkills.value_at(e["area"], n)):
						if m != t:
							targets.append(m)
				for m in targets:
					if chance >= 1.0 or randf() < chance:
						status(m, String(e.get("status", "")), HeroSkills.value_at(e.get("time", 0.0), n),
							HeroSkills.value_at(e.get("value", 0.0), n), src)
			"dot":
				if t == null or not is_instance_valid(t) or t.is_dead:
					continue
				var power := float(p.cur_matk()) if String(e.get("power", "atk")) == "matk" else float(p.cur_atk())
				var dps := power * HeroSkills.value_at(e.get("mult", 0.0), n) + HeroSkills.value_at(e.get("flat", 0.0), n)
				t.add_dot(sid, dps, HeroSkills.value_at(e.get("time", 10.0), n), p, bool(e.get("no_regen", false)), src)
			"knock":
				if t != null and is_instance_valid(t) and not t.is_dead:
					t.knock_back(p.global_position, HeroSkills.value_at(e.get("dist", 3.0), n))
			"buff":
				var buff_who := String(e.get("who", "self"))
				var bonus: Dictionary = {}
				var bf: Dictionary = e.get("bonus", {})
				for k in bf:
					bonus[k] = HeroSkills.value_at(bf[k], n)
				var sec := HeroSkills.value_at(e.get("time", 10.0), n)
				if buff_who == "self" or buff_who == "both":
					p.add_timed_bonus(sid, sec, bonus)
				if buff_who == "pet" or buff_who == "both":
					var pet := p._active_pet()
					# Питомец: усиления от героя — этап 2 (метод apply_hero_buff у Pet)
					if pet != null and pet.has_method("apply_hero_buff"):
						pet.call("apply_hero_buff", sid, sec, bonus)
			"special":
				var h := "sp_" + String(e.get("handler", ""))
				if has_method(h):
					call(h, sid, n, t, e)
				else:
					p.message.emit("«%s»: особое действие появится в следующем обновлении" % String(sk.get("name", sid)))


## Урон эффекта e на уровне n: доля атаки (power "atk") или маг. атаки ("matk") × mult + flat, разброс, крит.
func roll(e: Dictionary, n: int) -> int:
	var power := float(p.cur_matk()) if String(e.get("power", "atk")) == "matk" else float(p.cur_atk())
	var base := power * HeroSkills.value_at(e.get("mult", 1.0), n) + HeroSkills.value_at(e.get("flat", 0.0), n)
	base += float(randi_range(-2, 3))
	p._last_crit = bool(e.get("crit", false)) or randf() < p.cur_crit()
	if p._last_crit:
		base *= Player.CRIT_MULT
	return maxi(1, int(base))


## Наложить на зверя статус st на sec секунд (value — доля у slow / miss / vuln / weak).
func status(m: Mob, st: String, sec: float, value: float, src: Dictionary) -> void:
	if m == null or not is_instance_valid(m) or m.is_dead or sec <= 0.0:
		return
	match st:
		"stun", "root":
			m.stun(sec, src)
		"sleep":
			m.sleep(sec, src)
		"fear":
			m.frighten(sec, p.global_position, src)
		"slow":
			m.slow(value, sec, src)
		"blind":
			m.blind(sec, src)
		"miss":
			m.weaken_aim(value, sec, src)
		"vuln":
			m.expose(value, sec, src)
		"weak":
			m.weaken(value, sec, src)
		"taunt":
			m.taunt(p, sec, src)


func anim(kind: String) -> void:
	match kind:
		"cast":
			p._anim_cast()
		"bash":
			p._anim_bash()
		"spin":
			p._anim_spin()
		"buff":
			p._anim_buff()
		"dash":
			p._anim_dash()
		_:
			p._anim_attack()


## Сколько лечит эффект: pct — доля макс. HP того, кого лечим, mult — доля маг. атаки героя.
func _heal_amount(e: Dictionary, n: int, who: String) -> int:
	var node := _heal_target(who)
	var mx := float(p.max_hp)
	if node != null and node != p:
		mx = float(node.get("max_hp"))
	var a := mx * HeroSkills.value_at(e.get("pct", 0.0), n) + float(p.cur_matk()) * HeroSkills.value_at(e.get("mult", 0.0), n)
	return maxi(1, roundi(a))


## Кого лечить: "self" — героя, "pet" — призванного питомца, "ally" — того, у кого меньше доля HP.
func _heal_target(who: String) -> Node3D:
	var pet := p._active_pet()
	match who:
		"pet":
			return pet
		"ally":
			if pet != null:
				var pr := float(pet.get("hp")) / maxf(1.0, float(pet.get("max_hp")))
				var hr := float(p.hp) / maxf(1.0, float(p.max_hp))
				if pr < hr:
					return pet
	return p


func _heal(who: String, amount: int) -> void:
	var node := _heal_target(who)
	if node == null:
		return
	if node == p:
		p.heal(amount)
	elif node.has_method("heal"):
		node.call("heal", amount)
		Projectile.burst(p.get_parent(), node.global_position + Vector3(0, 0.8, 0), Color(0.5, 1, 0.5), 1.4, 0.4)


static func _find(fx: Array, what: String) -> Dictionary:
	for e in fx:
		var d: Dictionary = e
		if String(d.get("do", "")) == what:
			return d
	return {}

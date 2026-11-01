extends "res://tests/test_base.gd"
## Движение без дрожи (жалобы Максима: «в бою персонаж зависает и дёргается, как будто застрял», «застревает и
## дёргается у объектов вплотную», «при беге экран трясётся, как будто кочки»).
##
## Герой бежит по острову (джойстик — hud.move_vec, как в игре): по холмам (два маршрута с самым большим перепадом),
## через мост, в упор в стену постройки (повёрнутой), вдоль стены наискось, в упор в дерево, камень, жителя и круглую
## постройку (колодец, башня), потом уходит от них назад. Бой: зверь подходит и бьёт, герой держит «Атаку» 12 с;
## потом герой бегает по кругу у зверя с «Атакой». Каждый кадр пишутся: тело героя, точка, где нарисован герой
## (Player.visual_position), точка взгляда камеры (main.cam_focus) и камера, поворот героя, клип модели.
##
## Что значат пороги (кадр — 1/60 с, бег 6.5 м/с — 0.11 м за кадр):
## - «рывок» — вторая разность позиции за кадр |p[i+1] − 2p[i] + p[i−1]| (ускорение × кадр²). Рельеф сетки 1 м даёт
##   на рёбрах треугольников до ~0.05 м (излом склона 0.5 × 0.11 м); подскок тела (откат constrain с чужой высотой,
##   отрыв от земли и падение) и толчки — больше. Тело героя: не больше BODY_JERK. Точка взгляда камеры по высоте
##   сглажена — не больше LOOK_JERK_Y (2 см), камера целиком — не больше CAM_JERK;
## - «дрожь» — смена направления движения назад за кадр (скалярное произведение соседних сдвигов < −0.5 их длин,
##   оба сдвига больше 2 мм): при беге и у стены её нет совсем (до исправления у края воды и у стен — каждый кадр);
##   по высоте — подряд идущие развороты (вверх-вниз-вверх) длиннее DITHER_RUN: на гребне холма разворот один;
## - переключения клипа «покой / шаг / бег» за отрезок (без действий): старт и стоп дают 2–4, дрожь — десятки;
## - у стены в упор за последнюю секунду: размах по высоте и вдоль толчка не больше WALL_AMP (1.5 см), рывок не
##   больше WALL_JERK, разворотов нет; наискось вдоль стены — разворотов нет; назад от стены за 1 с — не меньше
##   ESCAPE м;
## - в бою (герой стоит): тело не сдвигается больше чем на STAND_DRIFT за 10 с, поворот за кадр не больше YAW_STEP,
##   развороты поворота подряд — не больше YAW_RUN; зверь у героя не «шаг — стоп» каждый кадр: переключений его клипа
##   не больше MOB_LOCO, разворотов его движения — не больше 2.

const BODY_JERK := 0.10
const LOOK_JERK_Y := 0.02
const CAM_JERK := 0.02
const DITHER_RUN := 2
const ROUTE_LOCO := 6
const WALL_AMP := 0.015
const WALL_JERK := 0.012
const ESCAPE := 2.0
const STAND_DRIFT := 0.05
const YAW_STEP := 0.2
const YAW_RUN := 3
const MOB_LOCO := 6

## Отрезок сценария: name, mode ("line" | "wall" | "stand" | "circle"), start (Vector3), input (Vector2 — джойстик),
## frames — кадров движения; у "wall" — box (стена коробки: проверка размаха вдоль толчка).
var cases: Array[Dictionary] = []
var ci := 0
var phase := 0
var t := 0
var settle := 0
var meter: Meter = null
var mob: Mob = null
var escape_from := Vector3.ZERO
var pet: Pet = null
var pet_meter: Meter = null


func race_class() -> Array:
	return ["dark_elf", "assassin"]


func hero_level() -> int:
	return 10


func before_start() -> void:
	game.active_pet = game.add_pet("wolf", PetData.stage_name("wolf", 10), 10)


## Записи кадров одного отрезка и оценки (см. шапку).
class Meter:
	var body: Array[Vector3] = []
	var vis: Array[Vector3] = []
	var look: Array[Vector3] = []
	var cam: Array[Vector3] = []
	var yaw: Array[float] = []
	var loco: Array[String] = []

	func add(b: Vector3, v: Vector3, l: Vector3, c: Vector3, y: float, lo: String) -> void:
		body.append(b)
		vis.append(v)
		look.append(l)
		cam.append(c)
		yaw.append(y)
		loco.append(lo)

	## Наибольший рывок |p[i+1] − 2p[i] + p[i−1]| с кадра from (only_y — только по высоте).
	static func jerk(a: Array[Vector3], from: int, only_y: bool) -> float:
		var m := 0.0
		for i in range(maxi(1, from + 1), a.size() - 1):
			var d: Vector3 = a[i + 1] - 2.0 * a[i] + a[i - 1]
			m = maxf(m, absf(d.y) if only_y else d.length())
		return m

	## Среднеквадратичный рывок по высоте.
	static func jerk_rms_y(a: Array[Vector3], from: int) -> float:
		var s := 0.0
		var n := 0
		for i in range(maxi(1, from + 1), a.size() - 1):
			var d: float = a[i + 1].y - 2.0 * a[i].y + a[i - 1].y
			s += d * d
			n += 1
		return sqrt(s / float(maxi(n, 1)))

	## Развороты движения по земле назад за кадр (оба сдвига больше 2 мм).
	static func flips(a: Array[Vector3], from: int) -> int:
		var n := 0
		for i in range(maxi(2, from + 2), a.size()):
			var p := Vector2(a[i - 1].x - a[i - 2].x, a[i - 1].z - a[i - 2].z)
			var q := Vector2(a[i].x - a[i - 1].x, a[i].z - a[i - 1].z)
			if p.length() > 0.002 and q.length() > 0.002 and p.dot(q) < -0.5 * p.length() * q.length():
				n += 1
		return n

	## Самая длинная серия разворотов по высоте подряд (вверх-вниз-вверх…; сдвиги больше 3 мм).
	static func dither_y(a: Array[Vector3], from: int) -> int:
		var best := 0
		var run := 0
		for i in range(maxi(2, from + 2), a.size()):
			var p: float = a[i - 1].y - a[i - 2].y
			var q: float = a[i].y - a[i - 1].y
			if p * q < 0.0 and absf(p) > 0.003 and absf(q) > 0.003:
				run += 1
				best = maxi(best, run)
			else:
				run = 0
		return best

	## Размах по высоте и вдоль оси u (если задана) с кадра from.
	static func amp(a: Array[Vector3], from: int, u: Vector3) -> Vector2:
		var ylo := INF
		var yhi := -INF
		var ulo := INF
		var uhi := -INF
		for i in range(maxi(0, from), a.size()):
			ylo = minf(ylo, a[i].y)
			yhi = maxf(yhi, a[i].y)
			var s := Vector2(a[i].x, a[i].z).dot(Vector2(u.x, u.z))
			ulo = minf(ulo, s)
			uhi = maxf(uhi, s)
		return Vector2(yhi - ylo, uhi - ulo)

	## Наибольший поворот за кадр и самая длинная серия разворотов поворота (сдвиги больше 0.004 рад).
	func yaw_stats(from: int) -> Vector2:
		var step_max := 0.0
		var best := 0
		var run := 0
		for i in range(maxi(1, from + 1), yaw.size()):
			var q := wrapf(yaw[i] - yaw[i - 1], -PI, PI)
			step_max = maxf(step_max, absf(q))
			if i >= from + 2:
				var p := wrapf(yaw[i - 1] - yaw[i - 2], -PI, PI)
				if p * q < 0.0 and absf(p) > 0.004 and absf(q) > 0.004:
					run += 1
					best = maxi(best, run)
				else:
					run = 0
		return Vector2(step_max, float(best))

	## Переключения клипа покой / шаг / бег (действия — пустой клип — пропускаются).
	func loco_switches(from: int) -> int:
		var n := 0
		var last := ""
		for i in range(maxi(0, from), loco.size()):
			var lo: String = loco[i]
			if lo != "idle" and lo != "walk" and lo != "run":
				continue
			if last != "" and lo != last:
				n += 1
			last = lo
		return n


func run_step() -> void:
	var player: Player = main.player
	player.hp = player.max_hp
	match step:
		0:
			var w := IslandWorld.current
			check(w != null, "остров построен")
			check(player.floor_snap_length >= 0.3 and player.floor_constant_speed,
				"герой прилипает к земле на кочках (%.2f м) и бежит с одной скоростью по склонам" % player.floor_snap_length)
			pet = main.pets.active_pet
			check(pet != null, "питомец призван")
			if pet != null:
				pet.set_mode("follow")
			main.cam_yaw = 0.0
			_build_cases(w)
			check(cases.size() >= 7, "отрезков для проверки: %d" % cases.size())
			ci = 0
			phase = 0
			step = 1
		1:
			if ci >= cases.size():
				ok_done()
				return
			_run_case(player, cases[ci])


## Один отрезок: phase 0 — поставить героя, 1 — постоять (settle), 2 — движение с записью, 3 — назад от стены.
func _run_case(player: Player, c: Dictionary) -> void:
	var mode := String(c["mode"])
	match phase:
		0:
			var s: Vector3 = c["start"]
			player.global_position = s
			player.velocity = Vector3.ZERO
			player.cancel_cast("")
			player._set_target(null)
			var face: Vector2 = c["input"]
			if face.length() > 0.01:
				player.rotation.y = atan2(-face.x, -face.y)
			if mode == "stand" or mode == "circle":
				_prepare_mob(player, c)
			if pet != null and is_instance_valid(pet):
				pet.global_position = s + Vector3(1.5, 0.2, 1.5)
				pet.velocity = Vector3.ZERO
			main.hud.move_vec = Vector2.ZERO
			player._face_hold = 0.0
			# Камера догоняет перенос (её сглаживание 8/с) — до записи 1 с
			settle = 60
			phase = 1
		1:
			main.hud.move_vec = Vector2.ZERO
			settle -= 1
			if settle <= 0:
				meter = Meter.new()
				pet_meter = Meter.new()
				t = 0
				phase = 2
		2:
			_drive(player, c)
			t += 1
			_sample(player)
			if t >= int(c["frames"]):
				main.hud.move_vec = Vector2.ZERO
				_judge(player, c)
				if mode == "wall":
					escape_from = player.global_position
					t = 0
					phase = 3
				else:
					_next()
		3:
			var inp: Vector2 = c["input"]
			main.hud.move_vec = -inp
			t += 1
			if t >= 60:
				main.hud.move_vec = Vector2.ZERO
				var gone := Vector2(player.global_position.x - escape_from.x, player.global_position.z - escape_from.z).length()
				check(gone >= ESCAPE, "%s: от объекта назад ушёл (%.2f м за 1 с)" % [c["name"], gone])
				_next()


func _next() -> void:
	if mob != null and is_instance_valid(mob) and not mob.is_dead:
		mob.target = null
		mob.returning = true
	mob = null
	ci += 1
	phase = 0


## Ввод кадра: джойстик (камера смотрит на север, cam_yaw = 0 — ввод в мировых x, z) и «Атака» в бою.
func _drive(player: Player, c: Dictionary) -> void:
	main.cam_yaw = 0.0
	match String(c["mode"]):
		"stand":
			main.hud.move_vec = Vector2.ZERO
			_keep_mob()
			player.try_attack()
		"circle":
			_keep_mob()
			var ctr: Vector3 = c["center"]
			var r := Vector2(player.global_position.x - ctr.x, player.global_position.z - ctr.z)
			var radial := r.normalized() if r.length() > 0.01 else Vector2(1, 0)
			var tang := Vector2(-radial.y, radial.x)
			main.hud.move_vec = (tang - radial * clampf((r.length() - 3.0) * 0.8, -0.8, 0.8)).normalized()
			player.try_attack()
		_:
			var inp: Vector2 = c["input"]
			main.hud.move_vec = inp


func _sample(player: Player) -> void:
	var lo := ""
	if player._model != null and is_instance_valid(player._model):
		lo = player._model._loco
	var look: Vector3 = main.cam_focus + Vector3(0, main._cam_look_y(), 0)
	meter.add(player.global_position, player.visual_position(), look, main.cam.global_position, player.rotation.y, lo)
	if mob != null and is_instance_valid(mob):
		var ml := ""
		if mob._asset != null:
			ml = mob._asset._loco
		pet_meter.add(mob.global_position, mob.global_position, Vector3.ZERO, Vector3.ZERO, mob.rotation.y, ml)
	elif pet != null and is_instance_valid(pet) and not pet.is_down:
		var pl := ""
		if pet._asset != null:
			pl = pet._asset._loco
		pet_meter.add(pet.global_position, pet.global_position, Vector3.ZERO, Vector3.ZERO, pet.rotation.y, pl)


## Оценки отрезка (пороги — в шапке).
func _judge(_player: Player, c: Dictionary) -> void:
	var nm := String(c["name"])
	var mode := String(c["mode"])
	var from := int(c.get("from", 5))
	var bj := Meter.jerk(meter.body, from, true)
	var brms := Meter.jerk_rms_y(meter.body, from)
	var vj := Meter.jerk(meter.vis, from, false)
	var ljy := Meter.jerk(meter.look, from, true)
	var cj := Meter.jerk(meter.cam, from, false)
	var fl := Meter.flips(meter.body, from)
	var dy := Meter.dither_y(meter.body, from)
	var sw := meter.loco_switches(from)
	var ys := meter.yaw_stats(from)
	var p0: Vector3 = meter.body[0]
	var p1: Vector3 = meter.body[meter.body.size() - 1]
	var dist := Vector2(p1.x - p0.x, p1.z - p0.z).length()
	print("ИЗМЕРЕНИЕ %s: путь %.1f м; рывок тела по высоте %.4f (СКО %.4f), точки героя %.4f, взгляда камеры по высоте %.4f, камеры %.4f м; разворотов %d, по высоте подряд %d; клип сменился %d раз; поворот за кадр до %.3f рад, развороты поворота подряд %d" % [
		nm, dist, bj, brms, vj, ljy, cj, fl, dy, sw, ys.x, int(ys.y)])
	check(bj <= BODY_JERK, "%s: тело героя без подскоков (рывок по высоте %.3f м ≤ %.2f)" % [nm, bj, BODY_JERK])
	check(fl <= 1, "%s: движение без дрожи туда-обратно (разворотов %d)" % [nm, fl])
	check(dy <= DITHER_RUN, "%s: высота не дрожит вверх-вниз (разворотов подряд %d)" % [nm, dy])
	check(ljy <= LOOK_JERK_Y, "%s: точка взгляда камеры по высоте плавная (рывок %.4f м ≤ %.3f)" % [nm, ljy, LOOK_JERK_Y])
	check(cj <= CAM_JERK, "%s: камера без тряски (рывок %.4f м ≤ %.2f)" % [nm, cj, CAM_JERK])
	match mode:
		"line":
			check(sw <= ROUTE_LOCO, "%s: клип шаг/бег/покой не дёргается (смен %d)" % [nm, sw])
			check(dist >= float(c.get("min_dist", 3.0)), "%s: герой пробежал отрезок (%.1f м)" % [nm, dist])
			if bool(c.get("pet", false)) and pet_meter.body.size() > 10:
				var psw := pet_meter.loco_switches(30)
				var pfl := Meter.flips(pet_meter.body, 30)
				print("ИЗМЕРЕНИЕ %s, питомец: клип сменился %d раз, разворотов %d" % [nm, psw, pfl])
				check(psw <= 8 and pfl <= 2, "%s: питомец бежит следом без «шаг — стоп» (смен клипа %d, разворотов %d)" % [nm, psw, pfl])
		"wall":
			var win := maxi(from, meter.body.size() - 60)
			var u := Vector3.ZERO
			if bool(c.get("box", false)):
				var inp: Vector2 = c["input"]
				u = Vector3(inp.x, 0.0, inp.y)
			var a := Meter.amp(meter.body, win, u)
			var wj := Meter.jerk(meter.body, win, false)
			var wfl := Meter.flips(meter.body, win)
			var wsw := meter.loco_switches(win)
			print("ИЗМЕРЕНИЕ %s, последняя секунда в упор: размах по высоте %.4f, вдоль толчка %.4f, рывок %.4f м, разворотов %d, смен клипа %d" % [
				nm, a.x, a.y, wj, wfl, wsw])
			if bool(c.get("slide", false)):
				# Наискось: скользит вдоль стены (за углом — дальше по земле), но не туда-обратно
				check(wfl == 0, "%s: вдоль стены без дрожи (разворотов %d)" % [nm, wfl])
			else:
				check(a.x <= WALL_AMP and wj <= WALL_JERK and wfl == 0,
					"%s: в упор тело не дрожит (по высоте %.4f м, рывок %.4f м, разворотов %d)" % [nm, a.x, wj, wfl])
				check(wsw <= 1, "%s: в упор клип не переключается туда-обратно (смен %d)" % [nm, wsw])
			if bool(c.get("box", false)):
				check(a.y <= WALL_AMP, "%s: в упор не отскакивает от стены (размах %.4f м)" % [nm, a.y])
			check(dist >= 1.0, "%s: герой дошёл до объекта (%.1f м)" % [nm, dist])
		"stand":
			var drift := 0.0
			for i in range(from, meter.body.size()):
				drift = maxf(drift, Vector2(meter.body[i].x - meter.body[from].x, meter.body[i].z - meter.body[from].z).length())
			check(drift <= STAND_DRIFT, "%s: зверь не толкает героя (сдвиг %.3f м ≤ %.2f)" % [nm, drift, STAND_DRIFT])
			check(ys.x <= YAW_STEP and int(ys.y) <= YAW_RUN,
				"%s: поворот героя к зверю без рывков и дрожи (за кадр до %.3f рад, развороты подряд %d)" % [nm, ys.x, int(ys.y)])
			check(sw <= 2, "%s: герой не переключает клип покой/шаг (смен %d)" % [nm, sw])
			_judge_mob(nm, from, true)
		"circle":
			check(int(ys.y) <= YAW_RUN, "%s: поворот героя без дрожи (развороты подряд %d)" % [nm, int(ys.y)])
			check(dist >= 0.5 and fl <= 1, "%s: герой бегает по кругу у зверя, не застревает (разворотов %d)" % [nm, fl])
			_judge_mob(nm, from, false)


## Зверь в бою: не дёргается «шаг — стоп», не бросил героя (strict — герой стоит: зверь рядом и стоит спокойно).
func _judge_mob(nm: String, from: int, strict: bool) -> void:
	var start := mini(from + 120, pet_meter.body.size() - 1)
	var msw := pet_meter.loco_switches(start)
	var mfl := Meter.flips(pet_meter.body, start)
	var near := -1.0
	if mob != null and is_instance_valid(mob):
		near = Vector2(mob.global_position.x - main.player.global_position.x,
			mob.global_position.z - main.player.global_position.z).length()
	print("ИЗМЕРЕНИЕ %s, зверь: клип сменился %d раз, разворотов %d, до героя %.2f м" % [nm, msw, mfl, near])
	if strict:
		check(msw <= MOB_LOCO and mfl <= 2, "%s: зверь у героя не дёргается (смен клипа %d, разворотов %d)" % [nm, msw, mfl])
		check(near >= 0.0 and near <= mob._reach() + 0.3, "%s: зверь дошёл до героя и бьёт (%.2f м)" % [nm, near])


# ---------- Отрезки ----------

func _build_cases(w: IslandWorld) -> void:
	var veg := _veg_pillars()
	var fps: Array = w.get_meta("poi_footprints", [])
	# Холмы: два отрезка по 28 м с самым большим перепадом высот, без построек и деревьев на пути
	var hills := _hill_routes(w, fps, veg)
	for i in hills.size():
		var hr: Dictionary = hills[i]
		cases.append({"name": "холм %d (перепад %.1f м)" % [i + 1, float(hr["rise"])], "mode": "line", "start": hr["start"],
			"input": hr["input"], "frames": int(28.0 / 6.5 * 60.0), "min_dist": 15.0, "pet": true})
	check(hills.size() >= 1, "маршруты по холмам найдены: %d" % hills.size())
	# Мост: по оси с берега на берег
	if not w.bridges.is_empty():
		var br: Dictionary = w.bridges[0]
		var a: Vector3 = br["a"]
		var e: Vector3 = br["b"]
		var ax := Vector3(e.x - a.x, 0.0, e.z - a.z).normalized()
		var s_br := a - ax * 6.0
		var span := Vector2(e.x - a.x, e.z - a.z).length() + 12.0
		cases.append({"name": "через мост", "mode": "line", "start": w.ground(s_br.x, s_br.z, 0.1), "input": Vector2(ax.x, ax.z),
			"frames": int(span / 6.5 * 60.0), "min_dist": span * 0.6})
	# Стена повёрнутой постройки: в упор и наискось вдоль неё
	var wall := _box_wall(w, fps, veg)
	check(not wall.is_empty(), "стена постройки для проверки найдена")
	if not wall.is_empty():
		var u: Vector3 = wall["u"]
		var fc: Vector3 = wall["face"]
		var tng := Vector3(-u.z, 0.0, u.x)
		var s_wall := fc + u * 4.5
		cases.append({"name": "в упор в стену «%s»" % wall["name"], "mode": "wall", "start": w.ground(s_wall.x, s_wall.z, 0.1),
			"input": Vector2(-u.x, -u.z), "frames": 150, "box": true})
		var s_slide := fc + u * 3.0 - tng * 2.0
		var d_slide := (-u + tng * 0.85).normalized()
		cases.append({"name": "наискось вдоль стены «%s»" % wall["name"], "mode": "wall", "start": w.ground(s_slide.x, s_slide.z, 0.1),
			"input": Vector2(d_slide.x, d_slide.z), "frames": 110, "slide": true})
	# Дерево и камень (коллизия растительности), житель, круглая постройка
	for want in [["дерево", 0.2, 0.7], ["камень", 0.85, 3.0]]:
		var it: Array = want
		var pc := _pillar_case(w, fps, veg, float(it[1]), float(it[2]))
		if pc.is_empty():
			# Крупный камень с коллизией на открытом месте может и не попасться — дерево обязательно
			check(String(it[0]) != "дерево", "%s для проверки найдено" % it[0])
			print("  %s с коллизией на открытом месте не найден" % it[0])
			continue
		pc["name"] = "в упор: %s" % it[0]
		cases.append(pc)
	var npc_case := _npc_case(w, fps, veg)
	if not npc_case.is_empty():
		cases.append(npc_case)
	var round_case := _round_poi_case(w, fps, veg)
	if not round_case.is_empty():
		cases.append(round_case)
	# Бой: зверь подходит и бьёт, герой держит «Атаку»; потом бег по кругу у зверя
	var m := _combat_mob(w)
	check(m != null, "зверь для боя найден")
	if m != null:
		var mp := m.global_position
		var dir := _open_dir(w, mp, 6.0, fps, veg)
		var s_mob := mp + dir * 6.0
		cases.append({"name": "бой на месте", "mode": "stand", "start": w.ground(s_mob.x, s_mob.z, 0.1), "input": Vector2(-dir.x, -dir.z),
			"frames": 60 * 12, "from": 120, "mob": m})
		cases.append({"name": "бой по кругу", "mode": "circle", "start": w.ground(s_mob.x, s_mob.z, 0.1), "input": Vector2(-dir.x, -dir.z),
			"frames": 60 * 6, "from": 60, "mob": m, "center": mp})


## Коллизии растительности: [[центр Vector2, радиус]] (капсулы в VegetationColliders).
func _veg_pillars() -> Array:
	var out: Array = []
	var body := IslandWorld.current.find_child("VegetationColliders", true, false)
	if body == null:
		return out
	for ch in body.get_children():
		var col := ch as CollisionShape3D
		if col == null or not (col.shape is CapsuleShape3D):
			continue
		var p := col.global_position
		out.append([Vector2(p.x, p.z), (col.shape as CapsuleShape3D).radius])
	return out


## Отрезок a → b свободен: проходим по сетке, вдали от построек (fps), растительности (veg) и жителей.
func _clear_path(w: IslandWorld, a: Vector3, b: Vector3, fps: Array, veg: Array, skip: Vector2 = Vector2.INF) -> bool:
	if not w.is_walkable(a.x, a.z) or not w.segment_walkable(a, b):
		return false
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	var mid := (a2 + b2) * 0.5
	var reach := a2.distance_to(b2) * 0.5 + 6.0
	for f in fps:
		var fd: Dictionary = f
		var fc: Vector2 = fd["c"]
		if skip.is_finite() and fc.distance_to(skip) < 0.6:
			continue
		if Geometry2D.get_closest_point_to_segment(fc, a2, b2).distance_to(fc) < float(fd["r"]) + 0.8:
			return false
	for v in veg:
		var it: Array = v
		var vc: Vector2 = it[0]
		if vc.distance_to(mid) > reach or (skip.is_finite() and vc.distance_to(skip) < 0.05):
			continue
		if Geometry2D.get_closest_point_to_segment(vc, a2, b2).distance_to(vc) < float(it[1]) + 0.9:
			return false
	for n in get_tree().get_nodes_in_group("npc"):
		var np := (n as Node3D).global_position
		var nc := Vector2(np.x, np.z)
		if skip.is_finite() and nc.distance_to(skip) < 0.05:
			continue
		if Geometry2D.get_closest_point_to_segment(nc, a2, b2).distance_to(nc) < 1.6:
			return false
	return true


## Отрезки по 28 м с наибольшим суммарным перепадом высот (до двух, не рядом друг с другом).
func _hill_routes(w: IslandWorld, fps: Array, veg: Array) -> Array:
	var cands: Array = []
	for gx in range(-150, 151, 9):
		for gz in range(-90, 91, 9):
			var s := Vector3(float(gx), 0.0, float(gz))
			if not w.is_walkable(s.x, s.z) or w.in_safe_zone(s):
				continue
			for k in 8:
				var a := TAU * float(k) / 8.0
				var d := Vector3(cos(a), 0.0, sin(a))
				var e := s + d * 28.0
				if not w.is_walkable(e.x, e.z) or w.in_safe_zone(e):
					continue
				var h0 := w.height_at(s.x, s.z)
				var lo := h0
				var hi := h0
				var sum := 0.0
				for i in range(1, 29):
					var q := s + d * float(i)
					var h := w.height_at(q.x, q.z)
					sum += absf(h - h0)
					h0 = h
					lo = minf(lo, h)
					hi = maxf(hi, h)
				if hi - lo < 1.5:
					continue
				cands.append([sum, s, d, hi - lo])
	cands.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	var out: Array = []
	for cnd in cands:
		var it: Array = cnd
		var rs: Vector3 = it[1]
		var rd: Vector3 = it[2]
		if not _clear_path(w, rs, rs + rd * 28.0, fps, veg) or not _wild(w, rs, rs + rd * 28.0):
			continue
		var far := true
		for o in out:
			var os: Vector3 = (o as Dictionary)["start"]
			if Vector2(os.x - rs.x, os.z - rs.z).length() < 30.0:
				far = false
		if not far:
			continue
		out.append({"start": w.ground(rs.x, rs.z, 0.1), "input": Vector2(rd.x, rd.z), "rise": float(it[3])})
		if out.size() >= 2:
			break
	return out


## Отрезок вдали от безопасных зон и мест острова (ограды деревень и лагерей, постройки без следа).
func _wild(w: IslandWorld, a: Vector3, b: Vector3) -> bool:
	for i in 15:
		var q := a.lerp(b, float(i) / 14.0)
		if w.in_safe_zone(q):
			return false
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	for p in w.cfg.get("pois", []):
		var poi: Dictionary = p
		var c := IslandWorld.v2(poi["center"])
		if Geometry2D.get_closest_point_to_segment(c, a2, b2).distance_to(c) < float(poi.get("radius", 3.0)) + 4.0:
			return false
	return true


## Стена постройки-коробки (лучше — повёрнутой не по осям): {name, face — центр грани у земли, u — наружу}.
func _box_wall(w: IslandWorld, fps: Array, veg: Array) -> Dictionary:
	var best := {}
	var best_k := -1.0
	for b in get_tree().get_nodes_in_group("poi_buildings"):
		var body := b as StaticBody3D
		if body == null:
			continue
		for ch in body.get_children():
			var col := ch as CollisionShape3D
			if col == null or not (col.shape is BoxShape3D):
				continue
			var size := (col.shape as BoxShape3D).size
			if size.x < 3.0 or size.z < 3.0 or size.y < 2.5:
				continue
			var xf := col.global_transform
			var bx := Vector3(xf.basis.x.x, 0.0, xf.basis.x.z).normalized()
			var bz := Vector3(xf.basis.z.x, 0.0, xf.basis.z.z).normalized()
			var diag := absf(sin(2.0 * atan2(bz.x, bz.z)))
			for f in 4:
				var u: Vector3 = [bz, -bz, bx, -bx][f]
				var half: float = [size.z, size.z, size.x, size.x][f] * 0.5
				var fc := Vector3(xf.origin.x, 0.0, xf.origin.z) + u * half
				var s := fc + u * 4.5
				var s2 := fc + u * 3.0 - Vector3(-u.z, 0.0, u.x) * 2.0
				if not _clear_path(w, s, fc + u * 0.8, fps, veg, Vector2(body.global_position.x, body.global_position.z)):
					continue
				if not _clear_path(w, s2, fc + u * 0.8, fps, veg, Vector2(body.global_position.x, body.global_position.z)):
					continue
				if diag > best_k:
					best_k = diag
					best = {"name": String(body.name), "face": fc, "u": u}
				break
	return best


## Дерево или камень (капсула растительности радиуса lo…hi): в упор по прямой с 4.5 м.
func _pillar_case(w: IslandWorld, fps: Array, veg: Array, lo: float, hi: float) -> Dictionary:
	var tries := 0
	for v in veg:
		var it: Array = v
		var r := float(it[1])
		if r < lo or r > hi:
			continue
		tries += 1
		if tries > 400:
			break
		var c: Vector2 = it[0]
		var c3 := Vector3(c.x, 0.0, c.y)
		for k in 8:
			var a := TAU * float(k) / 8.0
			var u := Vector3(cos(a), 0.0, sin(a))
			var s := c3 + u * (r + 4.5)
			if _clear_path(w, s, c3 + u * (r + 0.7), fps, veg, c):
				return {"mode": "wall", "start": w.ground(s.x, s.z, 0.1), "input": Vector2(-u.x, -u.z), "frames": 150}
	return {}


## Житель (капсула 0.45 м): в упор с 4.5 м.
func _npc_case(w: IslandWorld, fps: Array, veg: Array) -> Dictionary:
	for n in get_tree().get_nodes_in_group("npc"):
		var np := (n as Node3D).global_position
		var c := Vector2(np.x, np.z)
		for k in 8:
			var a := TAU * float(k) / 8.0
			var u := Vector3(cos(a), 0.0, sin(a))
			var s := np + u * 4.9
			if _clear_path(w, s, np + u * 1.2, fps, veg, c):
				return {"name": "в упор: житель «%s»" % String((n as Node).name), "mode": "wall",
					"start": w.ground(s.x, s.z, 0.1), "input": Vector2(-u.x, -u.z), "frames": 150}
	return {}


## Круглая постройка (колодец, башня, кристалл — капсула в poi_buildings): в упор с 4.5 м.
func _round_poi_case(w: IslandWorld, fps: Array, veg: Array) -> Dictionary:
	for b in get_tree().get_nodes_in_group("poi_buildings"):
		var body := b as StaticBody3D
		if body == null:
			continue
		for ch in body.get_children():
			var col := ch as CollisionShape3D
			if col == null or not (col.shape is CapsuleShape3D):
				continue
			var r := (col.shape as CapsuleShape3D).radius
			if r < 0.8:
				continue
			var cp := col.global_position
			var c := Vector2(cp.x, cp.z)
			var c3 := Vector3(cp.x, 0.0, cp.z)
			for k in 8:
				var a := TAU * float(k) / 8.0
				var u := Vector3(cos(a), 0.0, sin(a))
				var s := c3 + u * (r + 4.5)
				if _clear_path(w, s, c3 + u * (r + 0.7), fps, veg, Vector2(body.global_position.x, body.global_position.z)):
					return {"name": "в упор: «%s» (круглая)" % String(body.name), "mode": "wall",
						"start": w.ground(s.x, s.z, 0.1), "input": Vector2(-u.x, -u.z), "frames": 150}
	return {}


## Зверь для боя: фазан или волк на открытом месте, ближе к центру острова.
func _combat_mob(w: IslandWorld) -> Mob:
	var best: Mob = null
	for n in get_tree().get_nodes_in_group("mobs"):
		var m := n as Mob
		if m == null or m.is_dead or m.is_boss or MobData.flying(m.type_id):
			continue
		if m.type_id != "pheasant" and m.type_id != "wolf":
			continue
		if w.in_safe_zone(m.global_position):
			continue
		if best == null or m.global_position.length() < best.global_position.length():
			best = m
	return best


## Направление от p, в котором на dist м свободно (иначе — на юг).
func _open_dir(w: IslandWorld, p: Vector3, dist: float, fps: Array, veg: Array) -> Vector3:
	for k in 16:
		var a := TAU * float(k) / 16.0
		var u := Vector3(cos(a), 0.0, sin(a))
		if _clear_path(w, p + u * dist, p + u * 0.5, fps, veg) and not w.in_safe_zone(p + u * dist):
			return u
	return Vector3(0, 0, 1)


## Зверь боя: поставить на место, не дать умереть (HP с запасом), нацелить на героя.
func _prepare_mob(player: Player, c: Dictionary) -> void:
	var m: Variant = c.get("mob")
	if not mob_ok(m):
		mob = null
		return
	mob = m as Mob
	mob.returning = false
	mob.home = mob.global_position
	mob.max_hp = 1000000
	mob.hp = mob.max_hp
	mob.target = player


func _keep_mob() -> void:
	if mob != null and is_instance_valid(mob) and not mob.is_dead:
		mob.hp = mob.max_hp
		mob.returning = false
		mob.target = main.player

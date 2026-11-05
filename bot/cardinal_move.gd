class_name CardinalMove
extends RefCounted
## Общие действия Кардинала (CardinalRun — фарм у деревни, CardinalStory — прохождение острова): ходьба джойстиком
## по маршруту IslandWorld.Route (как игрок: HUD.move_vec относительно камеры и сразу Player.move_input в этом же тике
## физики), остановка, расстояние по земле, ускорение игры (тиков физики ×N при том же шаге 1/60 с, Engine.time_scale
## ×N, без 3D, без предела кадров) и возврат настроек движка, расчёт отдыха по формуле восстановления Player.


## Расстояние по земле (без высоты).
static func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Шаг джойстиком к точке to (маршрут nav: мосты через реку). Камера — main.cam_yaw.
static func walk(bot: TestBot, nav: IslandWorld.Route, p: Player, h: HUD, to: Vector3, dt: float) -> void:
	var pos := p.global_position
	var dir := nav.dir_to(pos, to, dt)
	if dir.length() < 0.01:
		dir = Vector3(to.x - pos.x, 0.0, to.z - pos.z).normalized()
	var yaw := float(bot.main.get("cam_yaw"))
	var mv := Vector3(dir.x, 0.0, dir.z).rotated(Vector3.UP, -yaw)
	h.move_vec = Vector2(mv.x, mv.z)
	# Сразу и герою — в этом же тике физики (main._process переносит джойстик в героя раз в кадр отрисовки: на
	# ускорении ×8 это разные тики, и два прогона с одним seed расходились)
	p.move_input = Vector2(dir.x, dir.z) if dir.length() >= 0.15 else Vector2.ZERO


## Отпустить джойстик.
static func stop(p: Player, h: HUD) -> void:
	if h != null:
		h.move_vec = Vector2.ZERO
	if p != null:
		p.move_input = Vector2.ZERO


## Ускорение ×accel (accel > 1): тиков физики в accel раз больше, шаг тика тот же 1/60 с, без сглаживания числа
## тиков в кадре (оно зависит от накопленной фазы — у второго прогона другая), без 3D и без предела кадров.
## Возвращает прежние настройки (для restore).
static func speed_up(bot: TestBot, accel: float) -> Dictionary:
	var saved := {"time_scale": Engine.time_scale, "steps": Engine.max_physics_steps_per_frame, "fps": Engine.max_fps,
		"no3d": bot.get_viewport().disable_3d, "ticks": Engine.physics_ticks_per_second, "jitter": Engine.physics_jitter_fix}
	if accel > 1.0:
		Engine.physics_ticks_per_second = int(saved["ticks"]) * int(round(accel))
		Engine.physics_jitter_fix = 0.0
		Engine.time_scale = accel
		Engine.max_physics_steps_per_frame = maxi(8, int(ceil(accel * 4.0)))
		Engine.max_fps = 0
		bot.get_viewport().disable_3d = true
	return saved


## Вернуть настройки движка, сохранённые speed_up.
static func restore(bot: TestBot, saved: Dictionary) -> void:
	Engine.time_scale = float(saved.get("time_scale", 1.0))
	Engine.physics_ticks_per_second = int(saved.get("ticks", 60))
	Engine.physics_jitter_fix = float(saved.get("jitter", 0.5))
	Engine.max_physics_steps_per_frame = int(saved.get("steps", 8))
	Engine.max_fps = int(saved.get("fps", 0))
	if bot != null and is_instance_valid(bot) and bot.is_inside_tree():
		bot.get_viewport().disable_3d = bool(saved.get("no3d", false))


## Сколько игровых секунд отдыхать до доли until макс. HP по формуле восстановления Player: статы и питомец
## (hp_regen, aura_regen) всегда, отдых — max_hp × REST_REGEN после regen_delay.
static func rest_predict(p: Player, until: float) -> float:
	var target := float(p.max_hp) * until
	var h0 := float(p.hp)
	if h0 >= target:
		return 0.0
	var stat := maxf(0.0, p.hp_regen + p.aura_regen)
	var delay := maxf(0.0, p.regen_delay)
	var h1 := h0 + stat * delay
	if h1 >= target:
		return (target - h0) / maxf(stat, 0.001)
	return delay + (target - h1) / (float(p.max_hp) * Player.REST_REGEN + stat)

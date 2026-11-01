class_name ThermalGuard
extends Node
## Бережение телефона (жалоба Максима «выкрутил всё на максимум — телефон прям раскалился»). Узел главной сцены
## (main._ready), живёт с экранов входа до выхода:
## - игра без фокуса (шторка уведомлений, окно поверх) или свёрнута — Quality.set_background: BACKGROUND_FPS кадров/с;
## - авто-снижение графики (настройка «Беречь телефон от перегрева», Quality.guard_enabled, по умолчанию вкл):
##   «горячо» — статус температуры Android MODERATE и выше (PowerManager.getCurrentThermalStatus через плагин
##   MyRappelzDownload, метод thermalStatus) или прогноз запаса до троттлинга ≥ HOT_HEADROOM (thermalHeadroom, ‰),
##   или стабильно долгий кадр (среднее время кадра дольше бюджета 1/предел × SLOW_K дольше SLOW_TIME с; на ПК и
##   без плагина — только так). Горячо — шаг вниз (Quality.set_throttle + Quality.apply: потолки THROTTLE_STEPS —
##   кадры/с → разрешение 3D → тени → сглаживание и постобработка → всё ниже), не чаще раза в STEP_GAP с
##   (SEVERE — STEP_GAP_SEVERE, CRITICAL и выше — сразу последний шаг); сообщение «Телефон нагрелся — графика
##   снижена». «Прохладно» (статус не выше LIGHT, запас ≤ COOL_HEADROOM, кадр в бюджете) держится _cool_need с —
##   шаг вверх (на 0 — «Телефон остыл — графика восстановлена»). Нагрелся снова за REHEAT с после шага вверх —
##   _cool_need удваивается (до COOL_TIME_MAX): без качелей «снизил — вернул — снизил».
## - раз в ModelLod.TICK — контур дальних моделей (ModelLod.tick).
## В автотестах (tests/runner.tscn) авто-снижение и фон выключены (кадры CI на программном рендере долгие);
## тест включает force и подставляет источники (status_source, headroom_source) и время кадра (tick).

## Статусы PowerManager.THERMAL_STATUS_*.
const STATUS_LIGHT := 1
const STATUS_MODERATE := 2
const STATUS_SEVERE := 3
const STATUS_CRITICAL := 4
## Опрос температуры, с (getThermalHeadroom чаще раза в секунду не отвечает).
const POLL := 5.0
## Не чаще одного шага вниз, с; при SEVERE.
const STEP_GAP := 30.0
const STEP_GAP_SEVERE := 10.0
## Прохладно столько секунд — шаг вверх; после повторного нагрева — вдвое дольше, не больше COOL_TIME_MAX.
const COOL_TIME := 60.0
const COOL_TIME_MAX := 600.0
## Нагрелся снова в течение стольких секунд после шага вверх — повторный нагрев.
const REHEAT := 120.0
## Прогноз запаса до троттлинга через 10 с, ‰ (1000 — телефон начнёт снижать частоты): горячо / прохладно.
const HOT_HEADROOM := 950
const COOL_HEADROOM := 800
## Кадр «не успевает»: среднее (EMA за FRAME_TAU с) дольше бюджета × SLOW_K — SLOW_TIME с подряд; «успевает» —
## не дольше бюджета × FAST_K.
const SLOW_K := 1.35
const FAST_K := 1.12
const SLOW_TIME := 12.0
const FRAME_TAU := 2.0
## После запуска и после смены графики время кадра не считается столько секунд (компиляция шейдеров, загрузка).
const WARMUP := 15.0
const SETTLE := 6.0
## Кадр дольше HITCH с — заминка (загрузка), а не нагрев: HITCH_SETTLE с кадры не считаются.
const HITCH := 0.4
const HITCH_SETTLE := 3.0

static var current: ThermalGuard = null

## Источники (подмена в тестах): статус температуры Android (−1 — неизвестно) и прогноз запаса, ‰ (−1).
var status_source: Callable
var headroom_source: Callable
## Включить авто-снижение и в автотесте (тест ThermalGuard).
var force := false
## Последние значения (тест, настройки).
var status := -1
var headroom := -1
var frame_avg := 0.0
## Почему последний раз снижали: "thermal" / "frames".
var reason := ""

var _poll_t := 0.0
var _slow_t := 0.0
var _cool_t := 0.0
var _since_change := STEP_GAP
var _cool_need := COOL_TIME
var _time := 0.0
var _restored_at := -1.0e9
var _settle := WARMUP
var _plugin_ok := true
var _in_tests := false


func _init() -> void:
	name = "ThermalGuard"
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_args():
		if String(a).ends_with("tests/runner.tscn"):
			_in_tests = true


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


## Работает ли авто-снижение (настройка; в автотестах — только с force).
func active() -> bool:
	return Quality.guard_enabled() and (force or not _in_tests)


func _process(delta: float) -> void:
	ModelLod.tick(delta)
	if not active():
		return
	tick(delta, delta)


func _notification(what: int) -> void:
	if _in_tests and not force:
		return
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			Quality.set_background(true)
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			Quality.set_background(false)
			# Кадры после возврата — не показатель
			_settle = maxf(_settle, SETTLE)


## Шаг логики: dt — прошедшее время, frame_dt — время последнего кадра (в игре — то же delta).
func tick(dt: float, frame_dt: float) -> void:
	_time += dt
	_since_change += dt
	_poll_t -= dt
	if _poll_t <= 0.0:
		_poll_t = POLL
		status = _read(status_source, "thermalStatus")
		headroom = _read(headroom_source, "thermalHeadroom")
	var budget := 1.0 / float(maxi(Quality.current_fps_cap(), 1))
	# Окно, экран до мира, фон — свой предел кадров, время кадра не показатель
	var measure := not Quality.menu_open() and not Quality.in_background()
	# Разовая заминка (загрузка мира, компиляция шейдеров) — не нагрев: пару секунд кадры не считаются
	if frame_dt > HITCH:
		_settle = maxf(_settle, HITCH_SETTLE)
	if _settle > 0.0:
		_settle -= dt
		measure = false
	if measure:
		var k := 1.0 - exp(-dt / FRAME_TAU)
		if frame_avg <= 0.0:
			frame_avg = budget
		frame_avg = lerpf(frame_avg, clampf(frame_dt, 0.0, 0.25), k)
		if frame_avg > budget * SLOW_K:
			_slow_t += dt
		else:
			_slow_t = 0.0
	else:
		_slow_t = 0.0
	var hot_thermal := status >= STATUS_MODERATE or headroom >= HOT_HEADROOM
	var hot_frames := _slow_t >= SLOW_TIME
	var cool := status <= STATUS_LIGHT and (headroom < 0 or headroom <= COOL_HEADROOM) \
		and (not measure or frame_avg <= budget * FAST_K)
	var lvl := Quality.throttle_level()
	if hot_thermal or hot_frames:
		_cool_t = 0.0
		var gap := STEP_GAP_SEVERE if status >= STATUS_SEVERE else STEP_GAP
		if lvl < Quality.throttle_max() and _since_change >= gap:
			var to := lvl + 1
			if status >= STATUS_CRITICAL:
				to = Quality.throttle_max()
			reason = "thermal" if hot_thermal else "frames"
			_step(to)
	elif cool and lvl > 0:
		_cool_t += dt
		if _cool_t >= _cool_need and _since_change >= STEP_GAP:
			_cool_t = 0.0
			_step(lvl - 1)
	else:
		_cool_t = 0.0


## Сменить шаг авто-снижения и применить графику; сообщение в HUD.
func _step(to: int) -> void:
	var from := Quality.throttle_level()
	if to == from:
		return
	if to > from and _time - _restored_at < REHEAT:
		_cool_need = minf(_cool_need * 2.0, COOL_TIME_MAX)
	if to < from:
		_restored_at = _time
	Quality.set_throttle(to)
	_since_change = 0.0
	_slow_t = 0.0
	_settle = SETTLE
	frame_avg = 0.0
	if is_inside_tree():
		Quality.apply(get_tree())
	var text := ""
	if to > from and from == 0:
		text = "Телефон нагрелся — графика снижена" if reason == "thermal" \
			else "Телефон не успевает рисовать кадры — графика снижена"
	elif to > from:
		text = "Телефон всё ещё горячий — графика снижена ещё"
	elif to == 0:
		text = "Телефон остыл — графика восстановлена"
	print("ThermalGuard: шаг %d → %d (%s; статус %d, запас %d‰, кадр %.1f мс)" % [from, to, reason, status, headroom,
		frame_avg * 1000.0])
	if text != "":
		_say(text)


## Сбросить авто-снижение (выключили настройку): графика как выбрана.
func reset() -> void:
	_cool_t = 0.0
	_slow_t = 0.0
	_cool_need = COOL_TIME
	_since_change = STEP_GAP
	frame_avg = 0.0
	# Температуру — спросить заново на следующем шаге
	_poll_t = 0.0
	status = -1
	headroom = -1
	if Quality.throttle_level() != 0:
		Quality.set_throttle(0)
		if is_inside_tree():
			Quality.apply(get_tree())


## Сколько секунд прохлады нужно для шага вверх сейчас (тест).
func cool_need() -> float:
	return _cool_need


func _say(text: String) -> void:
	var p := get_parent()
	if p == null:
		return
	var hud := p.get("hud") as HUD
	if hud != null and is_instance_valid(hud):
		hud.show_message(text, 4.0)


## Значение источника: подставленный Callable или метод плагина MyRappelzDownload (нет плагина или метода в
## старом AAR — −1, больше не спрашиваем).
func _read(src: Callable, method: String) -> int:
	if src.is_valid():
		return int(src.call())
	if not _plugin_ok:
		return -1
	var p := Assets.download_plugin()
	if p == null:
		_plugin_ok = false
		return -1
	var v: Variant = p.call(method)
	if typeof(v) != TYPE_INT:
		_plugin_ok = false
		return -1
	return int(v)

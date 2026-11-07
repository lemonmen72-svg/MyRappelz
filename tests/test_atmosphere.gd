extends "res://tests/test_base.gd"
## Атмосфера мира (0.46, atmo/): часы мира (сутки 24 мин, общие для всех — от unix-времени; солнце и луна, день,
## ночь, заря), погода по расписанию (одинаковая у всех, плавная смена, туман и мокрая земля после дождя, своя
## погода из админ-панели), узел Atmosphere на острове (свет: днём солнце, ночью луна; окружение, туман, небо;
## глобальные параметры шейдеров), дождь (RainFx), ночные огни (NightLights: пул ближайших, ночью ярче, огонь
## мерцает), огни (FireFx: пламя факелов и костров одним MultiMesh, искры у ближних), туман у воды (HazeFx «mist» —
## по погоде), подземелье (вечная ночь для огней, изумрудная дымка над озёрами у алтаря, чёрная — над озером
## босса), админ-панель («Мир» → «Время и погода»).

var _phase := 0


func run_step() -> void:
	match step:
		0:
			if not main._started:
				return
			_clock()
			_weather()
			step = 1
		1:
			_island()
			ok_done()


func _clock() -> void:
	WorldClock.reset()
	# Сутки — 24 минуты настоящего времени, у всех одинаково (от unix-времени)
	WorldClock.unix_override = 1440.0 * 1000.0 + 60.0 * 13.5
	check(absf(WorldClock.hour() - 13.5) < 0.01, "час от unix-времени: 13:30 (%s)" % WorldClock.clock_text())
	WorldClock.unix_override += 60.0
	check(absf(WorldClock.hour() - 14.5) < 0.01, "минута настоящего времени — час игры")
	check(WorldClock.day_index() == 1000, "номер суток: %d" % WorldClock.day_index())
	# Солнце: восход на востоке, полдень высоко, закат на западе, ночью под горизонтом
	var s6 := WorldClock.sun_dir_at(6.0)
	var s12 := WorldClock.sun_dir_at(12.0)
	var s18 := WorldClock.sun_dir_at(18.0)
	var s0 := WorldClock.sun_dir_at(0.0)
	check(absf(s6.y) < 0.05 and s6.x > 0.8, "6:00 — солнце у горизонта на востоке %s" % s6)
	check(s12.y > 0.85, "полдень — солнце высоко %s" % s12)
	check(absf(s18.y) < 0.05 and s18.x < -0.8, "18:00 — на западе %s" % s18)
	check(s0.y < -0.8 and WorldClock.moon_dir_at(0.0).y > 0.6, "полночь — солнце внизу, луна высоко")
	check(WorldClock.daylight_at(12.0) > 0.99 and WorldClock.daylight_at(0.0) < 0.01, "день и ночь")
	check(WorldClock.dusk_at(6.0) > 0.8 and WorldClock.dusk_at(12.0) < 0.05, "заря на восходе, днём нет")
	check(WorldClock.phase_name_at(12.0) == "День" and WorldClock.phase_name_at(0.0) == "Ночь"
		and WorldClock.phase_name_at(6.2) == "Рассвет" and WorldClock.phase_name_at(18.0) == "Закат", "названия времени суток")
	WorldClock.set_hour(21.0)
	check(absf(WorldClock.hour() - 21.0) < 0.02, "поставить час (админ-панель): %s" % WorldClock.clock_text())
	WorldClock.speed = 60.0
	var h0 := WorldClock.hour()
	WorldClock.unix_override += 1.0
	check(absf(fposmod(WorldClock.hour() - h0, 24.0) - 1.0) < 0.02, "×60: секунда — час")
	WorldClock.reset()
	WorldClock.unix_override = -1.0


func _weather() -> void:
	Weather.force = ""
	# Расписание одинаковое для всех (детерминировано) и разнообразное
	var seen := {}
	for d in 40:
		for s in 8:
			seen[Weather.scheduled(d, s)] = true
	check(seen.size() == Weather.ORDER.size(), "за 40 суток бывает вся погода: %s" % [seen.keys()])
	check(Weather.scheduled(7, 3) == Weather.scheduled(7, 3), "расписание детерминировано")
	# Смена — плавная в конце отрезка
	for d in 60:
		for s in 8:
			var a := Weather.scheduled(d, s)
			var b := Weather.scheduled(d, s + 1)
			if a == "clear" and b == "rain":
				var h := float(s) * Weather.SEG_HOURS
				var w0 := Weather.sample(h + 0.5, d)
				var w1 := Weather.sample(h + Weather.SEG_HOURS * 0.85, d)
				var w2 := Weather.sample(h + Weather.SEG_HOURS * 0.999, d)
				check(float(w0["rain"]) < 0.01 and float(w1["rain"]) > 0.05 and float(w1["rain"]) < float(w2["rain"]),
					"ясно → дождь плавно: %.2f %.2f %.2f" % [w0["rain"], w1["rain"], w2["rain"]])
				break
	# После дождя — туман и мокрая земля
	var found := false
	for d in 120:
		for s in 7:
			if Weather.scheduled(d, s) == "rain" and Weather.scheduled(d, s + 1) == "clear" and Weather.scheduled(d, s + 2) == "clear":
				var after := Weather.sample(float(s + 1) * Weather.SEG_HOURS + 0.5, d)
				check(float(after["fog"]) > 0.3 and float(after["wet"]) > 0.3, "после дождя: туман %.2f, мокро %.2f"
					% [after["fog"], after["wet"]])
				var later := Weather.sample(float(s + 2) * Weather.SEG_HOURS + 2.5, d)
				check(float(later["fog"]) < float(after["fog"]) and float(later["wet"]) < float(after["wet"]),
					"туман и мокрота уходят")
				found = true
				break
		if found:
			break
	check(found, "в расписании есть дождь, после которого ясно")
	Weather.force = "storm"
	var st := Weather.sample(12.0, 5)
	check(float(st["rain"]) > 0.9 and float(st["storm"]) > 0.9 and float(st["cloud"]) > 0.9, "своя погода: гроза")
	Weather.force = ""


func _island() -> void:
	var at := Atmosphere.current
	check(at != null and not at.dungeon, "на острове есть атмосфера")
	if at == null:
		return
	for g in Atmosphere.GLOBALS:
		check(ProjectSettings.has_setting("shader_globals/" + g) and at.globals.has(g), "параметр шейдеров %s есть" % g)
	# Полдень и ясно: солнце сверху, свет тёплый и яркий
	WorldClock.force_hour = 12.0
	Weather.force = "clear"
	at._first = true
	at.tick(0.1)
	var l := at.light
	check(l != null and l.light_energy > 0.6, "полдень: свет солнца %.2f" % (l.light_energy if l else 0.0))
	check(-l.global_transform.basis.z.y < -0.8, "полдень: свет сверху вниз")
	check(float(at.globals["atmo_night"]) < 0.05, "полдень: не ночь")
	# Полночь: луна, свет слабый и синий, окружение синее
	WorldClock.force_hour = 0.0
	at._first = true
	at.tick(0.1)
	check(l.light_energy < 0.3 and l.light_color.b > l.light_color.r, "полночь: лунный свет %.2f %s" % [l.light_energy, l.light_color])
	check(at.env.ambient_light_color.b > at.env.ambient_light_color.r, "полночь: синие тени")
	check(Atmosphere.night() > 0.95, "полночь: ночь %.2f" % Atmosphere.night())
	# Закат: тёплый свет
	WorldClock.force_hour = 17.6
	at._first = true
	at.tick(0.1)
	check(l.light_color.r > l.light_color.b * 1.3, "закат: тёплый свет %s" % l.light_color)
	# Дождь: дождь виден, туман гуще
	WorldClock.force_hour = 12.0
	Weather.force = "rain"
	at._first = true
	at.tick(0.1)
	var fog_rain := at.env.fog_density
	check(Atmosphere.rain() > 0.7 and fog_rain > Atmosphere.FOG_BASE, "дождь: %.2f, туман %.4f" % [Atmosphere.rain(), fog_rain])
	var rain := at.rain_fx as RainFx
	if rain != null:
		rain.tick()
		check(rain.near_mi.visible and rain.far_mi.visible, "струи дождя видны")
	# Гроза: молнии
	Weather.force = "storm"
	at._first = true
	var n0 := at.lightnings
	for i in 200:
		at.tick(0.1)
	check(at.lightnings > n0, "гроза: молнии (%d)" % (at.lightnings - n0))
	Weather.force = "clear"
	at._first = true
	at.tick(0.1)
	if rain != null:
		rain.tick()
		check(not rain.near_mi.visible, "ясно — дождя нет")
	# Ночные огни: пул ближайших, ночью ярче
	var nl := NightLights.current
	check(nl != null and nl.sources.size() >= 10, "огней в мире: %d" % (nl.sources.size() if nl else 0))
	if nl != null:
		nl.camera_override = main.player
		WorldClock.force_hour = 0.0
		at._first = true
		at.tick(0.1)
		nl._t = 0.0
		nl.tick(0.1)
		var night_e := 0.0
		for om in nl._pool:
			night_e += om.light_energy
		WorldClock.force_hour = 12.0
		at._first = true
		at.tick(0.1)
		nl.tick(0.1)
		var day_e := 0.0
		for om in nl._pool:
			day_e += om.light_energy
		check(nl._pool.size() == NightLights.count() and night_e > day_e * 3.0, "ночью огни ярче (%.2f против %.2f днём)" % [night_e, day_e])
	# Огни: пламя у построек
	var ff := FireFx.current
	check(ff != null and ff.fires.size() >= 5 and ff.mmi != null, "пламя огней: %d" % (ff.fires.size() if ff else 0))
	# Туман у воды: слои есть, видны только в туман
	var hz := HazeFx.current
	check(hz != null and hz.count_of("mist") >= 5, "туман у воды: слоёв %d" % (hz.count_of("mist") if hz else 0))
	if hz != null:
		Weather.force = "mist"
		at._first = true
		at.tick(0.1)
		hz._t = 0.0
		hz.tick(0.1)
		var vis := false
		for lay in hz.layers:
			if String(lay["kind"]) == "mist" and (lay["nodes"][0] as Node3D).visible:
				vis = true
		check(vis, "в туман слои над водой видны")
	WorldClock.force_hour = -1.0
	Weather.force = ""

class_name Weather
extends RefCounted
## Погода (атмосфера, задача Максима 07.11). Расписание — от часов мира (WorldClock): сутки делятся на отрезки по
## SEG_HOURS игровых часа, у отрезка — погода по хэшу (номер суток, номер отрезка): у всех игроков одна и та же
## (готово к серверу, ничего не сохраняется). Смена погоды — плавно в конце отрезка (BLEND — доля отрезка).
## После дождя — туман (сильнее у воды — IslandAtmo) и мокрая земля, высыхает за DRY_HOURS.
##
## sample(h, day) → {cloud, rain, storm, fog, wet, wind, state, next}: cloud — облачность 0…1, rain — дождь 0…1,
## storm — гроза (молнии), fog — туман 0…1, wet — мокрая земля 0…1, wind — ветер 0…1. Админ-панель («Мир» →
## «Время и погода») — force (своя погода на эту игру).

## Погоды: id → [название, облачность, дождь, гроза, туман, ветер, вес в расписании].
const STATES := {
	"clear": ["Ясно", 0.22, 0.0, 0.0, 0.0, 0.25, 46],
	"cloudy": ["Облачно", 0.72, 0.0, 0.0, 0.05, 0.45, 24],
	"rain": ["Дождь", 0.95, 0.8, 0.0, 0.15, 0.6, 16],
	"storm": ["Гроза", 1.0, 1.0, 1.0, 0.1, 0.95, 6],
	"mist": ["Туман", 0.45, 0.0, 0.0, 0.85, 0.1, 8],
}
const ORDER := ["clear", "cloudy", "rain", "storm", "mist"]
const SEG_HOURS := 3.0
## Конец отрезка, где погода плавно меняется на следующую (доля отрезка).
const BLEND := 0.3
## Туман после дождя: сила и сколько игровых часов держится.
const AFTER_RAIN_FOG := 0.75
const AFTER_RAIN_HOURS := 2.5
## Мокрая земля сохнет столько игровых часов.
const DRY_HOURS := 3.0

## Своя погода (админ-панель, тесты; "" — по расписанию).
static var force := ""


static func state_name(id: String) -> String:
	return String((STATES[id] as Array)[0]) if STATES.has(id) else id


## Погода отрезка seg суток day (по расписанию).
static func scheduled(day: int, seg: int) -> String:
	var segs := int(24.0 / SEG_HOURS)
	var d := day + floori(float(seg) / float(segs))
	var s := posmod(seg, segs)
	var total := 0
	for id in ORDER:
		total += int((STATES[id] as Array)[6])
	var r := posmod(_hash(d * 31 + s * 7 + 12345), total)
	# Туман — чаще утром: ночные и утренние отрезки (0–9 ч) вдвое чаще, днём — реже
	for id in ORDER:
		var w := int((STATES[id] as Array)[6])
		if r < w:
			if id == "mist" and s > 3:
				return "cloudy"
			return String(id)
		r -= w
	return "clear"


static func _hash(n: int) -> int:
	var x := n * 374761393 + 668265263
	x = (x ^ (x >> 13)) * 1274126177
	return absi(x ^ (x >> 16))


## Погода в час h суток day: числа погоды (см. шапку).
static func sample(h: float, day: int) -> Dictionary:
	var seg := floori(h / SEG_HOURS)
	var t := fposmod(h, SEG_HOURS) / SEG_HOURS
	var cur := force if force != "" else scheduled(day, seg)
	var nxt := force if force != "" else scheduled(day, seg + 1)
	var k := smoothstep(1.0 - BLEND, 1.0, t)
	var a: Array = STATES[cur]
	var b: Array = STATES[nxt]
	var res := {
		"cloud": lerpf(float(a[1]), float(b[1]), k),
		"rain": lerpf(float(a[2]), float(b[2]), k),
		"storm": lerpf(float(a[3]), float(b[3]), k),
		"fog": lerpf(float(a[4]), float(b[4]), k),
		"wind": lerpf(float(a[5]), float(b[5]), k),
		"state": cur, "next": nxt, "blend": k,
	}
	# После дождя (в прошлом или этом отрезке) — туман и мокрая земля
	var wet := float(res["rain"])
	if force == "":
		for back in [0, 1, 2]:
			var ps := scheduled(day, seg - back)
			var pr := float((STATES[ps] as Array)[2])
			if pr <= 0.0:
				continue
			# Часов с конца дождевого отрезка (у текущего — 0)
			var since := 0.0 if back == 0 else (float(back - 1) + t) * SEG_HOURS
			if back == 0 or ps == cur:
				continue
			wet = maxf(wet, pr * clampf(1.0 - since / DRY_HOURS, 0.0, 1.0))
			if float(res["rain"]) < 0.2:
				res["fog"] = maxf(float(res["fog"]), AFTER_RAIN_FOG * pr * clampf(1.0 - since / AFTER_RAIN_HOURS, 0.0, 1.0))
	elif force == "mist":
		wet = 0.35
	res["wet"] = clampf(wet, 0.0, 1.0)
	return res


## Погода сейчас (часы мира).
static func now() -> Dictionary:
	return sample(WorldClock.hour(), WorldClock.day_index())

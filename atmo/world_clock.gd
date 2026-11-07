class_name WorldClock
extends RefCounted
## Часы мира (атмосфера, решение Максима 07.11: «сутки в игре 24 минуты, 1 минута — 1 час»). Время суток — от
## настоящего времени (unix): у всех игроков одно и то же (готово к серверу, ничего не сохраняется), сутки —
## DAY_SEC = 1440 с. Солнце встаёт в SUNRISE (6:00) на востоке, в полдень высоко на юге, садится в SUNSET (18:00)
## на западе; ночью светит луна (напротив солнца, ниже по небу). Админ-панель («Мир» → «Время и погода»):
## поставить час (offset), ускорить (speed), остановить (frozen); тесты — force_hour.
##
## Что дают: hour() — 0…24; sun_dir() / moon_dir() — направление НА светило (единичный вектор, y — высота);
## daylight() — 0 ночью … 1 днём (плавно через рассвет и закат), dusk() — насколько сейчас заря (рассвет/закат,
## 0…1), night() = 1 − daylight(); phase_name() — «Ночь» / «Рассвет» / «День» / «Закат».

## Секунд настоящего времени на игровой час и сутки.
const SEC_PER_HOUR := 60.0
const DAY_SEC := SEC_PER_HOUR * 24.0
const SUNRISE := 6.0
const SUNSET := 18.0
## Наклон пути солнца: в полдень высота MAX_ELEV (рад), азимут восход → юг → запад.
const MAX_ELEV := deg_to_rad(68.0)
## Луна ниже солнца по небу.
const MOON_ELEV := deg_to_rad(52.0)
## Заря: солнце от DUSK_LOW до DUSK_HIGH над горизонтом (sin высоты) — небо и свет тёплые.
const DUSK_LOW := -0.18
const DUSK_HIGH := 0.32

## Сдвиг часов (игровых часов) — «поставить час» в админ-панели; на эту игру.
static var offset := 0.0
## Ускорение времени (×1 — сутки 24 мин); на эту игру.
static var speed := 1.0
## Время стоит (на часе frozen_hour).
static var frozen := false
static var frozen_hour := 12.0
## Тесты: час ровно этот (< 0 — нет).
static var force_hour := -1.0
## Своё «настоящее» время (тесты; < 0 — системное unix).
static var unix_override := -1.0
## Ускорение: сколько игровых секунд накоплено сверх настоящих (speed ≠ 1).
static var _extra := 0.0
static var _last_unix := -1.0


static func unix_now() -> float:
	return unix_override if unix_override >= 0.0 else Time.get_unix_time_from_system()


## Игровой час 0…24.
static func hour() -> float:
	if force_hour >= 0.0:
		return fposmod(force_hour, 24.0)
	if frozen:
		return fposmod(frozen_hour, 24.0)
	var now := unix_now()
	if speed != 1.0:
		if _last_unix >= 0.0:
			_extra += (now - _last_unix) * (speed - 1.0)
		_last_unix = now
	else:
		_last_unix = -1.0
	return fposmod((now + _extra) / SEC_PER_HOUR + offset, 24.0)


## Номер игровых суток (для погоды: у всех один и тот же).
static func day_index() -> int:
	if force_hour >= 0.0 or frozen:
		return 0
	return floori((unix_now() + _extra + offset * SEC_PER_HOUR) / DAY_SEC)


## Поставить час h (админ-панель): дальше время идёт от него.
static func set_hour(h: float) -> void:
	frozen_hour = fposmod(h, 24.0)
	force_hour = -1.0
	var cur := fposmod((unix_now() + _extra) / SEC_PER_HOUR, 24.0)
	offset = fposmod(h - cur, 24.0)


static func reset() -> void:
	offset = 0.0
	speed = 1.0
	frozen = false
	force_hour = -1.0
	_extra = 0.0
	_last_unix = -1.0


## Доля пути солнца: 0 — восход, 0.5 — полдень, 1 — закат; ночью — луны (0…1 от заката до восхода).
static func _arc(h: float) -> Vector2:
	if h >= SUNRISE and h <= SUNSET:
		return Vector2((h - SUNRISE) / (SUNSET - SUNRISE), 1.0)
	var t := fposmod(h - SUNSET, 24.0) / (24.0 - (SUNSET - SUNRISE))
	return Vector2(t, -1.0)


## Направление на солнце при часе h (единичный; ночью — под горизонтом).
static func sun_dir_at(h: float) -> Vector3:
	# Угол по кругу: 6:00 — восток (+X), 12:00 — верх, 18:00 — запад (−X); плоскость наклонена к югу (+Z)
	var a := (h - SUNRISE) / 24.0 * TAU
	var up := sin(a)
	var east := cos(a)
	var d := Vector3(east, up * sin(MAX_ELEV), up * cos(MAX_ELEV) * 0.55 + 0.25)
	return d.normalized()


static func sun_dir() -> Vector3:
	return sun_dir_at(hour())


## Направление на луну: напротив солнца, ниже по небу.
static func moon_dir_at(h: float) -> Vector3:
	var a := (h - SUNRISE) / 24.0 * TAU + PI
	var up := sin(a)
	var east := cos(a)
	return Vector3(east, up * sin(MOON_ELEV), up * cos(MOON_ELEV) * 0.5 - 0.3).normalized()


static func moon_dir() -> Vector3:
	return moon_dir_at(hour())


## Насколько день: 0 — ночь (солнце ниже DUSK_LOW), 1 — солнце выше DUSK_HIGH.
static func daylight_at(h: float) -> float:
	var y := sun_dir_at(h).y
	return smoothstep(DUSK_LOW, DUSK_HIGH * 0.6, y)


static func daylight() -> float:
	return daylight_at(hour())


static func night() -> float:
	return 1.0 - daylight()


## Заря (рассвет и закат): солнце у горизонта — 1, высоко или глубоко ночью — 0.
static func dusk_at(h: float) -> float:
	var y := sun_dir_at(h).y
	return clampf(1.0 - absf(y - 0.03) / 0.26, 0.0, 1.0)


static func dusk() -> float:
	return dusk_at(hour())


static func is_night() -> bool:
	return daylight() < 0.35


static func phase_name_at(h: float) -> String:
	var d := daylight_at(h)
	if d < 0.15:
		return "Ночь"
	if dusk_at(h) > 0.45:
		return "Рассвет" if fposmod(h, 24.0) < 12.0 else "Закат"
	return "День"


static func phase_name() -> String:
	return phase_name_at(hour())


## «14:35» — часы и минуты игрового времени.
static func clock_text(h: float = -1.0) -> String:
	var hh := hour() if h < 0.0 else fposmod(h, 24.0)
	var m := floori(hh * 60.0)
	return "%02d:%02d" % [m / 60, m % 60]

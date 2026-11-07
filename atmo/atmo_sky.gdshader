// Небо атмосферы (0.46, задача Максима: смена дня и ночи, погода, эффекты неба и солнца).
// Цвет неба — рассеяние Рэлея и Ми (аналитическое, без лучей: оптическая толщина по высоте взгляда, фазы Рэлея и
// Хеньи — Гринстейна) по TimeOfDay (J. Cuéllar, MIT) / Sky3D (Cory Petkovsek, Tokisan Games, MIT) — функции
// atm_depth, atm_scatter; дальше своё: солнце и луна — свои направления (uniform от WorldClock, не LIGHT0: ночью
// свет сцены — луна), луна с фазой и «морями», звёзды процедурно (мерцают), аниме-облака (как прежнее небо: чёткие
// края, светлая кайма) — облачность и дождь от погоды (Weather), цвет — от солнца, зари и ночи, вспышка молнии,
// насыщенность и яркость под аниме-палитру игры. Значения задаёт Atmosphere (atmo/atmosphere.gd) раз в кадр.
shader_type sky;

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform float daylight : hint_range(0.0, 1.0) = 1.0;
uniform float dusk : hint_range(0.0, 1.0) = 0.0;
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.3;
uniform float rain : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float moon_phase : hint_range(0.0, 1.0) = 0.5;
uniform vec2 cloud_offset = vec2(0.0);
uniform float exposure = 1.55;
uniform float saturation = 1.3;
uniform float star_intensity = 1.0;
// Рассеяние (длины волн 680 / 550 / 440 нм; Ми: мутность 0.001, g = 0.8)
uniform vec3 beta_ray = vec3(5.805e-6, 1.3565e-5, 3.311e-5);
uniform vec3 beta_mie = vec3(3.038e-8);
uniform float atm_thickness = 0.7;
uniform float atm_darkness = 0.5;
uniform float sun_intensity = 18.0;
uniform vec3 day_tint : source_color = vec3(0.808, 0.91, 1.0);
uniform vec3 horizon_tint : source_color = vec3(0.98, 0.635, 0.463);
uniform vec3 night_tint : source_color = vec3(0.05, 0.075, 0.16);
uniform vec3 mie_partial = vec3(0.36, 1.64, 1.6);
uniform vec3 moon_mie_tint : source_color = vec3(0.18, 0.24, 0.38);
uniform float moon_mie_intensity = 0.15;
uniform float sun_size = 0.028;
uniform float moon_size = 0.055;
uniform vec3 ground_color : source_color = vec3(0.32, 0.40, 0.38);
uniform vec3 cloud_day : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shade : source_color = vec3(0.70, 0.78, 0.94);
uniform vec3 cloud_rain : source_color = vec3(0.42, 0.45, 0.52);
uniform vec3 cloud_night : source_color = vec3(0.10, 0.12, 0.20);

const float RAYLEIGH_ZENITH = 8.4e3;
const float MIE_ZENITH = 1.25e3;
const float THREE_8PI = 3.0 / (8.0 * PI);

float sk_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float sk_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = sk_hash(i);
	float b = sk_hash(i + vec2(1.0, 0.0));
	float c = sk_hash(i + vec2(0.0, 1.0));
	float d = sk_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float sk_fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * sk_noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

// --- Рассеяние (TimeOfDay / Sky3D, MIT) ---
float rayleigh_phase(float mu) {
	return THREE_8PI * (1.0 + mu * mu);
}

float mie_phase(float mu, vec3 partial) {
	return 4.0 * PI * partial.x * pow(max(partial.y - partial.z * mu, 0.0001), -1.5);
}

void atm_depth(float y, out float sr, out float sm) {
	y = max(0.03, y + 0.03);
	y = 1.0 / y;
	sr = y * RAYLEIGH_ZENITH;
	sm = y * MIE_ZENITH;
}

vec3 atm_scatter(float sr, float sm, float mu_sun, float mu_moon, float horizon_k, float sun_k) {
	vec3 br = beta_ray * atm_thickness;
	vec3 extc = clamp(exp(-(br * sr + beta_mie * sm)), 0.0, 1.0);
	float ff = mix(clamp(atm_thickness * 0.5, 0.0, 1.0), 1.0, horizon_k);
	vec3 fext = mix(1.0 - extc, (1.0 - extc) * extc, ff);
	vec3 brt = br * rayleigh_phase(mu_sun);
	vec3 bmt = beta_mie * mie_phase(mu_sun, mie_partial);
	vec3 brmt = (brt + bmt) / (br + beta_mie);
	vec3 sc = sun_intensity * brmt * fext * day_tint * sun_k;
	sc = mix(sc, sc * (1.0 - extc), atm_darkness);
	vec3 lcol = mix(day_tint, horizon_tint, horizon_k);
	vec3 night = (1.0 - extc) * night_tint;
	night += mie_phase(mu_moon, mie_partial) * moon_mie_tint * moon_mie_intensity * 0.005;
	return sc * lcol + night;
}

// --- Звёзды: по ячейкам на развёртке направления, у ячейки — одна звезда со своим блеском и мерцанием ---
float stars(vec3 dir, float t) {
	vec2 uv = vec2(atan(dir.x, dir.z), asin(clamp(dir.y, -1.0, 1.0)));
	float sc = 140.0;
	vec2 g = uv * sc;
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float h = sk_hash(cell);
	if (h < 0.82) {
		return 0.0;
	}
	vec2 pos = vec2(sk_hash(cell + 7.1), sk_hash(cell + 3.3)) * 0.7 + 0.15;
	float d = length(f - pos);
	float b = pow(sk_hash(cell + 1.9), 3.0) * 1.6 + 0.25;
	float tw = 0.65 + 0.35 * sin(t * (1.0 + h * 3.0) + h * 40.0);
	return smoothstep(0.09, 0.0, d) * b * tw;
}

// --- Луна: диск с освещённой стороной (фаза) и тёмными «морями» ---
vec3 moon(vec3 dir, out float mask) {
	float d = distance(dir, moon_dir);
	mask = 1.0 - smoothstep(moon_size * 0.92, moon_size, d);
	if (mask <= 0.0) {
		return vec3(0.0);
	}
	// Координаты на диске
	vec3 right = normalize(cross(moon_dir, vec3(0.0, 1.0, 0.0)) + vec3(0.0001));
	vec3 up = normalize(cross(right, moon_dir));
	vec2 p = vec2(dot(dir - moon_dir, right), dot(dir - moon_dir, up)) / moon_size;
	float z = sqrt(max(0.0, 1.0 - dot(p, p)));
	vec3 n = vec3(p, z);
	// Фаза: свет падает сбоку (0 — новолуние, 0.5 — полнолуние)
	float ang = (moon_phase - 0.5) * 2.0 * PI;
	vec3 l = normalize(vec3(sin(ang), 0.0, cos(ang)));
	float lit = smoothstep(-0.05, 0.15, dot(n, l));
	float seas = sk_fbm(p * 3.0 + 4.0);
	vec3 albedo = mix(vec3(0.92, 0.92, 0.86), vec3(0.62, 0.64, 0.66), smoothstep(0.45, 0.7, seas));
	return albedo * (lit * 1.4 + 0.04);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = dir.y;
	float sun_up = clamp(sun_dir.y + 0.45, 0.0, 1.0);
	float horizon_k = clamp(1.0 - sun_dir.y, 0.0, 1.0);
	float sr;
	float sm;
	atm_depth(max(h, 0.0), sr, sm);
	vec3 col = atm_scatter(sr, sm, dot(sun_dir, dir), dot(moon_dir, dir), horizon_k, sun_up);
	// Аниме-палитра: ярче и насыщеннее (у горизонта — бледнее, дымка), яркое — мягко к белому
	col *= exposure;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = max(mix(vec3(lum), col, mix(1.0, saturation, smoothstep(0.0, 0.3, max(h, 0.0)))), vec3(0.0));
	col = mix(col, 0.6 + 0.4 * (1.0 - exp(-(col - 0.6) / 0.4)), step(vec3(0.6), col));
	// Дождь: небо серее и темнее
	col = mix(col, vec3(lum) * vec3(0.78, 0.82, 0.9), rain * 0.7);

	// Солнце: диск и ореол (за облаками и под горизонтом — нет)
	float sd = distance(dir, sun_dir);
	float above = smoothstep(-0.02, 0.02, h);
	vec3 sun_col = mix(vec3(1.0, 0.97, 0.88), vec3(1.0, 0.62, 0.32), dusk);
	float glow = (exp(-sd * 6.0) * 0.35 + exp(-sd * 22.0) * 0.6) * sun_up;
	col += sun_col * glow * (1.0 - rain * 0.8) * above;
	float disk = (1.0 - smoothstep(sun_size * 0.8, sun_size, sd)) * above * smoothstep(-0.12, 0.0, sun_dir.y);

	// Ночное небо: звёзды и луна (днём не видны)
	float night = 1.0 - daylight;
	float mmask;
	vec3 mcol = moon(dir, mmask);
	float st = stars(dir, TIME) * star_intensity * night * smoothstep(0.0, 0.25, h) * (1.0 - mmask);
	col += vec3(0.85, 0.9, 1.0) * st * (1.0 - cloud_cover * 0.8) * (1.0 - rain);
	col = mix(col, mcol * mix(0.35, 1.0, night), mmask * above * smoothstep(-0.1, 0.05, moon_dir.y));
	col += vec3(0.5, 0.6, 0.85) * exp(-distance(dir, moon_dir) * 10.0) * 0.18 * night * above;
	col = mix(col, sun_col * 2.2, disk);

	// Облака: аниме — чёткий край, тень от солнца, светлая кайма; облачность и дождь — от погоды
	if (h > 0.0) {
		vec2 uv = dir.xz / (h + 0.15);
		vec2 q = uv * 0.9 + cloud_offset;
		float n = sk_fbm(q);
		float cover = clamp(cloud_cover + rain * 0.25, 0.0, 0.98);
		float thr = 1.0 - cover;
		float soft = mix(0.015, 0.09, rain);
		float cl = smoothstep(thr - soft, thr + soft, n);
		vec3 light_dir = daylight > 0.25 ? sun_dir : moon_dir;
		vec2 to_l = normalize(light_dir.xz + vec2(0.0001, 0.0));
		float n2 = sk_fbm(q + to_l * 0.06);
		float shadow = smoothstep(0.0, 0.02, n2 - n);
		float core = smoothstep(thr + 0.08, thr + 0.25, n);
		// Цвет: день — белые, заря — розово-золотые, ночь — тёмно-синие, дождь — серые
		vec3 lit_col = mix(cloud_day, mix(vec3(1.0, 0.72, 0.52), vec3(1.0, 0.55, 0.45), dusk * 0.5), dusk);
		lit_col = mix(cloud_night * 1.6, lit_col, daylight);
		vec3 sh_col = mix(cloud_night, mix(cloud_shade, vec3(0.62, 0.48, 0.62), dusk), daylight);
		vec3 cc = mix(lit_col, sh_col, max(shadow * 0.85, core * 0.4));
		cc = mix(cc, cloud_rain * mix(0.3, 1.0, daylight), rain * 0.85);
		cc += sun_col * (1.0 - smoothstep(thr, thr + 0.05, n)) * 0.3 * (1.0 - shadow) * daylight * (1.0 - rain);
		cc += vec3(0.75, 0.8, 1.0) * flash * 1.6 * cl;
		col = mix(col, cc, cl * smoothstep(0.0, 0.18, h));
	}
	// Вспышка молнии — всё небо светлее
	col += vec3(0.55, 0.6, 0.8) * flash * 0.5;
	// Под горизонтом — дымка земли цвета неба у горизонта
	col = mix(col, ground_color * (0.25 + 0.75 * daylight) + col * 0.3, 1.0 - smoothstep(-0.12, 0.0, h));
	COLOR = col;
}

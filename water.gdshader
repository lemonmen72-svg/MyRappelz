// Вода острова в аниме-стиле: море (бирюза у берега → синева вдали), река с течением и пруд.
// Один меш (IslandWater): UV — координаты течения (s вдоль, t поперёк), UV2.x — доля реки/пруда,
// UV2.y — сила морских волн, COLOR.r — скорость течения.
// Глубина и расстояние до берега берутся из текстуры данных (без текстуры глубины экрана —
// её нет в GL Compatibility): R — расстояние до берега, G — глубина, B — пена у камней.
// Пена ступенчатая (чёткие края), лёгкие волны в вершинах, линии бликов, искры солнца, френель.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled, world_vertex_coords;

uniform sampler2D data_tex : filter_linear, repeat_disable;
uniform vec2 data_origin = vec2(-178.5, -104.5);
uniform vec2 data_size = vec2(360.0, 203.0);
uniform float cd_range = 24.0;
uniform float depth_range = 8.0;
uniform vec3 sun_dir = vec3(0.35, 0.82, 0.45);

uniform vec3 sea_shallow : source_color = vec3(0.40, 0.90, 0.84);
uniform vec3 sea_mid : source_color = vec3(0.14, 0.64, 0.82);
uniform vec3 sea_deep : source_color = vec3(0.08, 0.34, 0.64);
uniform vec3 river_shallow : source_color = vec3(0.46, 0.88, 0.80);
uniform vec3 river_deep : source_color = vec3(0.16, 0.56, 0.68);
uniform vec3 foam_color : source_color = vec3(0.97, 0.99, 1.0);
uniform vec3 sky_color : source_color = vec3(0.80, 0.91, 1.0);
uniform vec3 glint_color : source_color = vec3(1.0, 0.97, 0.86);
uniform float wave_height = 0.12;
uniform float wave_speed = 1.0;
uniform float flow_speed = 1.0;
// false — облегчённый режим для слабых пресетов (Quality): 2 шума на пиксель вместо ~10,
// без линий бликов, штрихов течения, рваных полос прибоя и искр солнца.
uniform bool rich = true;

varying vec3 v_pos;
varying vec3 v_nrm;
varying vec2 v_flow;
varying float v_river;
varying float v_speed;

float wt_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float wt_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = wt_hash(i);
	float b = wt_hash(i + vec2(1.0, 0.0));
	float c = wt_hash(i + vec2(0.0, 1.0));
	float d = wt_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	vec2 p = VERTEX.xz;
	float amp = wave_height * UV2.y;
	float t = TIME * wave_speed;
	vec2 d1 = vec2(0.80, 0.60);
	vec2 d2 = vec2(-0.45, 0.89);
	vec2 d3 = vec2(0.96, -0.28);
	float a1 = dot(p, d1) * 0.23 + t * 1.1;
	float a2 = dot(p, d2) * 0.37 + t * 1.4;
	float a3 = dot(p, d3) * 0.61 + t * 1.9;
	VERTEX.y += (sin(a1) * 0.5 + sin(a2) * 0.32 + sin(a3) * 0.18) * amp;
	vec2 g = d1 * (0.23 * 0.5 * cos(a1)) + d2 * (0.37 * 0.32 * cos(a2)) + d3 * (0.61 * 0.18 * cos(a3));
	g *= amp;
	v_nrm = normalize(vec3(-g.x, 1.0, -g.y));
	v_pos = VERTEX;
	v_flow = UV;
	v_river = UV2.x;
	v_speed = COLOR.r;
}

void fragment() {
	vec2 p = v_pos.xz;
	float t = TIME;
	vec4 data = texture(data_tex, (p - data_origin) / data_size);
	// За краем карты — открытое море: «расстояние от берега» растёт дальше
	vec2 outside = max(data_origin - p, p - (data_origin + data_size));
	float off = -(data.r * 2.0 - 1.0) * cd_range + max(max(outside.x, outside.y), 0.0);
	float depth = data.g * depth_range;
	float rock = data.b;

	// --- Цвет моря: бирюза у берега → лазурь → синева, границы слегка «плывут»
	float n_slow = wt_noise(p * 0.12 + vec2(t * 0.04, -t * 0.03));
	vec3 sea = mix(sea_shallow, sea_mid, smoothstep(1.0, 9.0, off + (n_slow - 0.5) * 3.0));
	sea = mix(sea, sea_deep, smoothstep(12.0, 42.0, off + (n_slow - 0.5) * 8.0));
	float sea_a = mix(0.48, 0.88, smoothstep(0.2, 3.0, depth));
	sea_a = mix(sea_a, 0.95, smoothstep(8.0, 30.0, off));

	// --- Река и пруд: светлее и прозрачнее на мели
	vec3 riv = mix(river_shallow, river_deep, smoothstep(0.15, 1.3, depth));
	float riv_a = mix(0.4, 0.86, smoothstep(0.1, 1.2, depth));

	vec3 col = mix(sea, riv, v_river);
	float alpha = mix(sea_a, riv_a, v_river);

	// --- Линии бликов (как каустика на мелководье): изолиния суммы двух шумов
	if (rich) {
		vec2 q = p * 0.42;
		float r1 = wt_noise(q + vec2(t * 0.11, t * 0.06));
		float r2 = wt_noise(q * 1.6 + vec2(-t * 0.08, t * 0.12) + 5.2);
		float lines = smoothstep(0.90, 0.95, 1.0 - abs(r1 + r2 - 1.0));
		// Течение: вытянутые вдоль русла светлые штрихи, плывут по течению
		float fs = v_speed * flow_speed;
		vec2 fq = vec2(v_flow.y * 0.55, v_flow.x * 0.16 - t * fs * 0.25);
		float s1 = wt_noise(fq + 3.0);
		float s2 = wt_noise(fq * vec2(1.7, 1.3) + vec2(7.1, -t * fs * 0.12));
		float streak = smoothstep(0.66, 0.70, s1 * 0.65 + s2 * 0.35);
		float shine = mix(lines * mix(0.38, 0.16, smoothstep(2.0, 24.0, off)),
			mix(lines * 0.32, streak * 0.4, v_speed), v_river);
		col = mix(col, foam_color, shine);
		alpha = max(alpha, shine);
	}

	// --- Пена
	float fn = wt_noise(p * 0.55 + vec2(t * 0.15, t * 0.1));
	// У самой кромки: мель (по глубине) или подножие обрыва (по расстоянию до берега)
	float edge = 1.0 - smoothstep(0.1, 0.4 + fn * 0.3, depth);
	edge = max(edge, (1.0 - smoothstep(-0.6, 1.2 + fn * 1.2, off)) * (1.0 - v_river));
	// Полосы прибоя: бегут к берегу, рвутся на куски, гаснут вдали
	float b = fract(off * 0.32 + t * 0.14 + fn * 0.35);
	float band = smoothstep(0.0, 0.06, b) * (1.0 - smoothstep(0.10, 0.17, b));
	band *= (1.0 - smoothstep(1.5, 8.0, off)) * smoothstep(-0.8, 0.5, off) * (1.0 - v_river);
	if (rich) {
		band *= smoothstep(0.38, 0.5, wt_noise(p * 0.22 + 11.0));
	}
	// Вокруг камней в воде (пульсирует)
	float rf = rock + (fn - 0.5) * 0.25 + 0.06 * sin(t * 2.2 + p.x * 0.7 + p.y * 0.4);
	float foam = max(max(edge, band), smoothstep(0.42, 0.5, rf));
	float fm = smoothstep(0.45, 0.58, foam);
	float soft = smoothstep(0.12, 0.45, foam) * 0.3;
	float fa = max(fm, soft);
	col = mix(col, foam_color, fa);
	alpha = max(alpha, max(fm * 0.95, soft));

	// --- Френель (отражение неба под углом), широкий отблеск и искры солнца
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 V = normalize(cam - v_pos);
	float fres = pow(1.0 - clamp(dot(V, v_nrm), 0.0, 1.0), 4.0);
	col = mix(col, sky_color, fres * 0.55 * (1.0 - fm));
	alpha = mix(alpha, 1.0, fres * 0.6);
	vec3 H = normalize(normalize(sun_dir) + V);
	float wide = pow(clamp(dot(v_nrm, H), 0.0, 1.0), 40.0);
	col += glint_color * wide * 0.18 * (1.0 - fm);
	if (rich) {
		vec2 nn = vec2(wt_noise(p * 0.9 + t * 0.4), wt_noise(p * 0.9 - t * 0.35 + 3.3)) - 0.5;
		vec3 N = normalize(v_nrm + vec3(nn.x, 0.0, nn.y) * 0.35);
		float spec = pow(clamp(dot(N, H), 0.0, 1.0), 220.0);
		float glint = smoothstep(0.35, 0.45, spec) * (1.0 - fm);
		col = mix(col, glint_color, glint);
		alpha = max(alpha, glint);
	}

	ALBEDO = col;
	ALPHA = clamp(alpha, 0.0, 1.0);
}

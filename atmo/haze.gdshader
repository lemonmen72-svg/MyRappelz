// Дымка и туман над водой (0.46, задача Максима: «туман после дождя, особенно около воды; дымка над зелёными
// озёрами в подземелье; чёрная магическая дымка над озером, где босс»). Горизонтальный слой (PlaneMesh): плотность —
// шум fbm, бежит по ветру (drift) и медленно клубится (два слоя навстречу), края слоя тают по кругу (UV), у камеры
// тает (не видно «плоскости», когда камера внутри). swirl > 0 — завихрение вокруг центра (магическая дымка),
// glow — светящиеся прожилки цвета glow_color (изумруд секты). Сила — density (× atmo_fog у тумана острова: use_fog).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

global uniform float atmo_fog;
global uniform float atmo_night;
global uniform vec4 atmo_sky_color;
uniform vec4 haze_color : source_color = vec4(0.82, 0.88, 0.94, 1.0);
uniform vec4 glow_color : source_color = vec4(0.3, 1.0, 0.55, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.6;
uniform bool use_fog = true;
uniform float scale = 0.08;
uniform vec2 drift = vec2(0.03, 0.012);
uniform float swirl = 0.0;
uniform float glow = 0.0;
uniform float edge = 0.35;
uniform float night_dim = 0.55;
// Туман острова (use_fog) берёт часть цвета неба и тумана мира: днём белёсый, на заре тёплый, ночью серо-синий
uniform float sky_tint = 0.35;

varying vec3 v_world;

float hz_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float hz_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hz_hash(i), hz_hash(i + vec2(1.0, 0.0)), u.x), mix(hz_hash(i + vec2(0.0, 1.0)), hz_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float hz_fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * hz_noise(p);
		p = p * 2.07 + vec2(3.1, 1.7);
		a *= 0.5;
	}
	return v / 0.875;
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 c = UV - 0.5;
	float r = length(c) * 2.0;
	vec2 p = v_world.xz * scale;
	// Завихрение вокруг центра; у второго слоя swirl < 0 — крутится навстречу
	if (swirl != 0.0) {
		float ang = swirl * TIME * 0.15 + r * swirl * 2.5;
		float cs = cos(ang);
		float sn = sin(ang);
		p = vec2(c.x * cs - c.y * sn, c.x * sn + c.y * cs) * 6.0;
	}
	float n1 = hz_fbm(p + drift * TIME);
	float n2 = hz_fbm(p * 1.7 - drift.yx * TIME * 1.3 + 7.0);
	float n = n1 * 0.6 + n2 * 0.4;
	// Края слоя тают по кругу, у камеры — тоже (камера внутри слоя): и дымка, и прожилки
	float fade = 1.0 - smoothstep(1.0 - edge, 1.0, r);
	float cam_d = distance(CAMERA_POSITION_WORLD, v_world);
	fade *= smoothstep(2.0, 9.0, cam_d);
	float d = smoothstep(0.35, 0.75, n) * fade;
	float k = density * (use_fog ? atmo_fog : 1.0);
	vec3 base = use_fog ? mix(haze_color.rgb, atmo_sky_color.rgb, sky_tint) : haze_color.rgb;
	vec3 col = base * mix(1.0, night_dim, atmo_night);
	// Светящиеся прожилки (магия, изумрудная плесень)
	float veins = smoothstep(0.62, 0.7, n2) * (1.0 - smoothstep(0.7, 0.8, n2)) * fade;
	col = mix(col, glow_color.rgb * 1.6, veins * glow);
	ALBEDO = col;
	ALPHA = clamp(d * k * haze_color.a + veins * glow * 0.35 * density, 0.0, 1.0);
}

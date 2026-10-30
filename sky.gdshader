// Аниме-небо: насыщенный голубой зенит → светлый горизонт, солнечный диск с ореолом,
// мягкие облака с чёткими краями (плывут по TIME), снизу — дымка земли.
shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.13, 0.42, 0.90);
uniform vec3 mid_color : source_color = vec3(0.36, 0.66, 0.98);
uniform vec3 horizon_color : source_color = vec3(0.80, 0.91, 1.0);
uniform vec3 ground_color : source_color = vec3(0.52, 0.66, 0.62);
uniform vec3 cloud_light : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shadow : source_color = vec3(0.70, 0.78, 0.94);
uniform vec3 sun_tint : source_color = vec3(1.0, 0.93, 0.74);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.45;
uniform float cloud_speed = 0.006;
uniform float sun_size = 0.045;

float sky_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float sky_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = sky_hash(i);
	float b = sky_hash(i + vec2(1.0, 0.0));
	float c = sky_hash(i + vec2(0.0, 1.0));
	float d = sky_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float sky_fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * sky_noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = dir.y;
	vec3 col = mix(horizon_color, mid_color, smoothstep(0.0, 0.25, h));
	col = mix(col, zenith_color, smoothstep(0.25, 0.85, h));
	col = mix(col, ground_color, 1.0 - smoothstep(-0.12, 0.0, h));

	vec3 sun_dir = LIGHT0_ENABLED ? normalize(LIGHT0_DIRECTION) : vec3(0.0, 1.0, 0.0);
	float sd = distance(dir, sun_dir);
	if (LIGHT0_ENABLED) {
		col += sun_tint * (exp(-sd * 5.0) * 0.3 + exp(-sd * 18.0) * 0.45);
		float disk = 1.0 - smoothstep(sun_size * 0.85, sun_size, sd);
		col = mix(col, vec3(1.0, 0.98, 0.9) * 1.4, disk);
	}

	if (h > 0.0) {
		vec2 uv = dir.xz / (h + 0.15);
		vec2 q = uv * 0.9 + vec2(1.0, 0.35) * TIME * cloud_speed;
		float n = sky_fbm(q);
		float thr = 1.0 - cloud_cover;
		float cl = smoothstep(thr - 0.015, thr + 0.015, n);
		// Сторона облака от солнца — в тени (сравниваем плотность со сдвигом к солнцу)
		vec2 to_sun = normalize(sun_dir.xz + vec2(0.0001, 0.0));
		float n2 = sky_fbm(q + to_sun * 0.06);
		float shadow = smoothstep(0.0, 0.02, n2 - n);
		float core = smoothstep(thr + 0.08, thr + 0.25, n);
		vec3 cc = mix(cloud_light, cloud_shadow, max(shadow * 0.85, core * 0.4));
		// Светлая кайма по краю облака
		cc += sun_tint * (1.0 - smoothstep(thr, thr + 0.05, n)) * 0.25 * (1.0 - shadow);
		col = mix(col, cc, cl * smoothstep(0.0, 0.18, h));
	}
	COLOR = col;
}

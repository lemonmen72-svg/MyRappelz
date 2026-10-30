// Общие функции шейдеров мира (земля, трава, цветы, флажки): шум, цвет луга, тропинки, toon-свет.
// Параметры тропинок и площадки задаёт WorldBuilder (те же числа использует расстановка травы и деревьев).

uniform vec3 grass_dark : source_color = vec3(0.29, 0.56, 0.25);
uniform vec3 grass_mid : source_color = vec3(0.40, 0.68, 0.27);
uniform vec3 grass_light : source_color = vec3(0.58, 0.78, 0.31);
// Углы тропинок (радианы, atan(z, x)), ширина тропинки (м), радиус площадки (м).
uniform vec4 path_angles = vec4(0.25, 1.75, 3.35, 4.75);
uniform float path_wobble = 0.18;
uniform float path_width = 1.9;
uniform float plaza_radius = 9.0;

float wc_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Плавный шум значений 0..1.
float wc_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = wc_hash(i);
	float b = wc_hash(i + vec2(1.0, 0.0));
	float c = wc_hash(i + vec2(0.0, 1.0));
	float d = wc_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Цвет луга в точке мира (мягкие пятна трёх оттенков).
vec3 wc_meadow(vec2 p) {
	float n = wc_noise(p * 0.045) * 0.65 + wc_noise(p * 0.11 + 7.3) * 0.35;
	vec3 c = mix(grass_dark, grass_mid, smoothstep(0.32, 0.48, n));
	return mix(c, grass_light, smoothstep(0.56, 0.68, n));
}

float wc_arc(float a, float r, float target) {
	return abs(mod(a - target + PI, TAU) - PI) * r;
}

// Расстояние (м) до ближайшей тропинки. Совпадает с WorldBuilder.path_distance().
float wc_path_dist(vec2 p) {
	float r = length(p);
	float a = atan(p.y, p.x);
	float s = r * 0.06;
	float d = wc_arc(a, r, path_angles.x + path_wobble * sin(s));
	d = min(d, wc_arc(a, r, path_angles.y + path_wobble * sin(s + 1.7)));
	d = min(d, wc_arc(a, r, path_angles.z + path_wobble * sin(s + 3.4)));
	d = min(d, wc_arc(a, r, path_angles.w + path_wobble * sin(s + 5.1)));
	return d;
}

// Toon-свет: ступенька освещённости и чёткая граница тени. Использовать в light().
vec3 wc_toon(vec3 n, vec3 l, float atten, vec3 light_color) {
	float lit = smoothstep(0.0, 0.1, dot(n, l)) * smoothstep(0.3, 0.6, atten);
	return light_color * lit / PI;
}

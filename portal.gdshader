// Воронка портала (Portal): закрученная спираль изумрудного и фиолетового света к тёмному центру, по краю — яркий
// обод, по кругу бегут блики. Плоский квадрат с UV 0..1; круг вписан, за кругом прозрачно.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

uniform vec3 color_a : source_color = vec3(0.25, 1.0, 0.6);
uniform vec3 color_b : source_color = vec3(0.62, 0.35, 1.0);
uniform vec3 core : source_color = vec3(0.02, 0.04, 0.06);
uniform float speed = 1.0;
uniform float open = 1.0;

float pt_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float pt_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(pt_hash(i), pt_hash(i + vec2(1.0, 0.0)), u.x), mix(pt_hash(i + vec2(0.0, 1.0)), pt_hash(i + vec2(1.0)), u.x), u.y);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float a = atan(q.y, q.x);
	float t = TIME * speed;
	// Спираль: угол сдвигается к центру
	float sw = a + r * 5.0 - t * 1.6;
	float arms = 0.5 + 0.5 * sin(sw * 3.0);
	float n = pt_noise(vec2(sw * 1.3, r * 6.0 - t * 2.0));
	vec3 c = mix(color_b, color_a, smoothstep(0.2, 0.9, arms * 0.7 + n * 0.5));
	float bright = smoothstep(0.15, 0.95, r) * (0.55 + 0.6 * arms * n);
	c = mix(core, c, bright);
	// Обод и бегущие блики
	float rim = smoothstep(0.8, 0.95, r) * (1.0 - smoothstep(0.95, 1.0, r));
	float run = smoothstep(0.85, 1.0, sin(a * 4.0 + t * 3.0));
	c += color_a * rim * (1.2 + run);
	float alpha = (1.0 - smoothstep(0.96, 1.0, r)) * mix(0.75, 0.98, smoothstep(0.3, 0.9, r)) * open;
	ALBEDO = c;
	ALPHA = alpha;
}

// Вода подземелья (DungeonWater): тёмная бирюза, у кромки светлее и прозрачнее, по глубине — изумрудное свечение
// снизу пятнами, медленная рябь светлыми линиями (без текстуры глубины экрана — глубина в UV.x вершин).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

uniform vec3 shallow : source_color = vec3(0.10, 0.42, 0.40);
uniform vec3 deep : source_color = vec3(0.02, 0.14, 0.17);
uniform vec3 glow : source_color = vec3(0.25, 0.95, 0.55);
uniform vec3 line_color : source_color = vec3(0.55, 1.0, 0.85);
uniform bool rich = true;

varying vec3 v_pos;

float dw_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float dw_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(dw_hash(i), dw_hash(i + vec2(1.0, 0.0)), u.x), mix(dw_hash(i + vec2(0.0, 1.0)), dw_hash(i + vec2(1.0)), u.x), u.y);
}

void vertex() {
	v_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = v_pos.xz;
	float depth = UV.x;
	float edge = UV.y;
	float t = TIME * 0.25;
	vec3 col = mix(shallow, deep, smoothstep(0.1, 1.3, depth));
	// Свечение снизу пятнами (руны и плесень на дне)
	float g = dw_noise(p * 0.12 + vec2(t * 0.3, -t * 0.2));
	col += glow * smoothstep(0.62, 0.9, g) * 0.22;
	if (rich) {
		// Рябь: две бегущие сетки шума, светлые тонкие линии
		float a = dw_noise(p * 0.9 + vec2(t, t * 0.6));
		float b = dw_noise(p * 1.3 - vec2(t * 0.7, t));
		float lines = 1.0 - smoothstep(0.0, 0.035, abs(a - b));
		col += line_color * lines * 0.18;
	}
	// Кромка: светлая полоса у берега
	col = mix(col, line_color * 0.7, (1.0 - smoothstep(0.0, 0.8, edge)) * 0.35);
	ALBEDO = col;
	ALPHA = mix(0.55, 0.92, smoothstep(0.05, 1.0, depth));
}

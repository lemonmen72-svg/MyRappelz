// Дождь (0.46): открытый цилиндр вокруг камеры (два — ближний и дальний, параллакс), струи — процедурно: столбцы по
// окружности, у столбца своя скорость и сдвиг, капля — тонкий штрих, падает вниз; ветер — наклон (wind). Сила —
// rain (Atmosphere), цвет — от неба (atmo_sky_color) и вспышки молнии (atmo_flash). Без текстур и частиц: дёшево.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

global uniform vec4 atmo_sky_color;
global uniform float atmo_flash;
uniform float rain : hint_range(0.0, 1.0) = 0.0;
uniform float columns = 220.0;
uniform float speed = 1.4;
uniform float streak = 0.07;
uniform float wind = 0.1;
uniform float opacity = 0.32;

float rn_hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	uv.x += uv.y * wind;
	float col = floor(uv.x * columns);
	float h1 = rn_hash(col);
	float h2 = rn_hash(col + 31.7);
	// Капля в столбце: своя скорость, сдвиг, 2 капли на высоту цилиндра
	float y = fract(uv.y * 2.0 + TIME * speed * (0.8 + h1 * 0.6) + h2);
	float drop = smoothstep(0.0, 0.02, y) * (1.0 - smoothstep(streak * (0.6 + h2), streak * (0.6 + h2) + 0.02, y));
	// Тонкая линия по ширине столбца
	float fx = fract(uv.x * columns);
	float line = 1.0 - smoothstep(0.05, 0.25, abs(fx - 0.5 - (h1 - 0.5) * 0.4));
	// Часть столбцов пустая — гуще с силой дождя
	float on = step(1.0 - rain * 0.9, rn_hash(col + 7.3));
	float a = drop * line * on * opacity * rain;
	// Сверху и снизу цилиндра — тает
	a *= smoothstep(0.0, 0.15, UV.y) * (1.0 - smoothstep(0.85, 1.0, UV.y));
	vec3 c = mix(atmo_sky_color.rgb * 1.3 + 0.15, vec3(0.9, 0.95, 1.0), atmo_flash);
	ALBEDO = c;
	ALPHA = clamp(a, 0.0, 1.0);
}

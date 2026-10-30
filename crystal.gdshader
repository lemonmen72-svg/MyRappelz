// Светящиеся кристаллы: собственное свечение без освещения, светлая кромка по френелю,
// огранка (грани разной яркости), градиент от тёмного основания к яркой верхушке и мягкая
// пульсация по TIME (у каждого кристалла своя фаза по положению в мире).
// Цвет задаётся параметрами: голубые/золотые у светлых эльфов, фиолетовые у тёмных.
// Кристаллы склеены в общий меш зоны (PoiModels.Kit.append_kit), поэтому высота над основанием
// своей модели берётся из UV.x, а фаза пульсации своего объекта — из UV.y.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled;

uniform vec4 color : source_color = vec4(0.45, 0.82, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(0.16, 0.32, 0.66, 1.0);
uniform vec4 edge_color : source_color = vec4(0.92, 0.99, 1.0, 1.0);
uniform float glow : hint_range(0.0, 3.0) = 1.1;
uniform float fresnel_power : hint_range(0.5, 8.0) = 2.4;
// Высота (м в координатах меша), на которой цвет доходит до самого яркого.
uniform float height_range = 1.6;
uniform float pulse_speed = 1.7;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.3;

varying float v_phase;
varying float v_h;
varying vec3 v_wn;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	v_phase = fract(sin(dot(o.xz, vec2(12.9898, 78.233))) * 43758.5453) * 6.2832 + UV.y;
	v_h = UV.x;
	v_wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	float pulse = 1.0 - pulse_amount + pulse_amount * (0.5 + 0.5 * sin(TIME * pulse_speed + v_phase + v_h * 1.5));
	// Огранка: грани, смотрящие вверх и к «солнцу», светлее
	float facet = 0.72 + 0.28 * clamp(dot(normalize(v_wn), normalize(vec3(0.35, 0.8, 0.45))), 0.0, 1.0);
	vec3 body = mix(core_color.rgb, color.rgb, smoothstep(0.0, height_range, v_h)) * facet;
	vec3 c = mix(body, edge_color.rgb, fres * 0.85);
	ALBEDO = c * glow * pulse;
}

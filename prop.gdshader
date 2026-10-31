// Объекты локации из файлов (PropAsset, assets/props — модели Meshy, переработанные tools/prepare_props.py):
// цвет из атласа страницы (одна текстура на страницу — склеенные меши зон и участков растительности рисуются
// одной поверхностью на страницу), cel-shading как у toon.gdshader (2 тона, цветная тень, кромка со стороны
// света). Детальные маски WorldTextures поверх не кладутся — у текстур Meshy свой рисунок.
// Свечение (кристаллы, стекло фонарей, огонь жаровни) — альфа цвета вершины (0..1, пишет скрипт по цвету
// текстуры): свой цвет текстуры без света и мягкая пульсация (фаза — по мировым координатам, у склеенного меша
// нет своего объекта). Один сэмплер — дёшево для GL Compatibility на телефоне.
// Двусторонний (cull_disabled) — страховка: у одинарных панелей Meshy скрипт разворачивает грани наружу
// (orient_faces), но изнанка всё равно не даёт дыры. Нормаль изнанки Godot сам переворачивает
// (DO_SIDE_CHECK при cull_disabled: на задней грани NORMAL = −нормаль), свет на ней верный.
// Светлое (белые стены эльфов, солома, штукатурка) мягко ограничено сверху (highlight_knee/slope):
// с солнцем, небом и кромкой белое не выжигается в сплошное пятно.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_disable;
// Множитель цвета текстуры (тёмные модели чуть светлее и т. п.).
uniform vec4 tint : source_color = vec4(1.0);
uniform float threshold : hint_range(-1.0, 1.0) = 0.05;
uniform float softness : hint_range(0.001, 0.3) = 0.04;
uniform vec4 shadow_color : source_color = vec4(0.72, 0.68, 0.88, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.15;
uniform float rim_width : hint_range(0.0, 1.0) = 0.3;
uniform vec4 rim_color : source_color = vec4(1.0, 0.96, 0.88, 1.0);
// Яркость текстуры выше knee растёт с наклоном slope (по наибольшему каналу — оттенок сохраняется).
uniform float highlight_knee : hint_range(0.0, 1.0) = 0.58;
uniform float highlight_slope : hint_range(0.0, 1.0) = 0.35;
uniform float glow_energy = 1.1;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.25;
uniform float pulse_speed = 1.7;

varying float v_glow;
varying vec3 v_wpos;

void vertex() {
	v_glow = COLOR.a;
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb * tint.rgb;
	float m = max(c.r, max(c.g, c.b));
	if (m > highlight_knee) {
		c *= (highlight_knee + (m - highlight_knee) * highlight_slope) / m;
	}
	ALBEDO = c * (1.0 - 0.7 * v_glow);
	if (v_glow > 0.01) {
		float pulse = 1.0 - pulse_amount + pulse_amount * (0.5 + 0.5 * sin(TIME * pulse_speed
			+ dot(v_wpos.xz, vec2(0.37, 0.23)) + v_wpos.y * 0.6));
		EMISSION = c * v_glow * glow_energy * pulse;
	}
}

void light() {
	// Тень от объектов (ATTENUATION) переводит точку на теневую сторону
	float v = min(dot(NORMAL, LIGHT), ATTENUATION * 2.0 - 1.0);
	float t = smoothstep(threshold - softness, threshold + softness, v);
	float k = LIGHT_IS_DIRECTIONAL ? 1.0 : ATTENUATION;
	vec3 tone = mix(shadow_color.rgb, vec3(1.0), t);
	DIFFUSE_LIGHT += LIGHT_COLOR * tone * k / PI;
	float edge = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(1.0 - rim_width - 0.04, 1.0 - rim_width + 0.04, edge);
	DIFFUSE_LIGHT += LIGHT_COLOR * rim_color.rgb * rim * rim_strength * (0.3 + 0.7 * t) * k / PI;
}

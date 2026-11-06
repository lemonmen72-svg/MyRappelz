// Общий шейдер эффектов умений (VFX 2.0, VfxKit.fx): форма из маски, «живой» шум (пламя, энергия, дым), растворение
// с горящей кромкой, раскалённое ядро, свечение краёв (френель), росчерк, пробегающий по дуге (reveal), повороты к
// камере. Только то, что есть и в Mobile (Vulkan), и в Compatibility. Варианты — vfx_add.gdshader (сложение цветов,
// свечение) и vfx_mix.gdshader (обычная прозрачность: дым, пыль, тьма).

uniform sampler2D mask : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform sampler2D noise : hint_default_white, filter_linear_mipmap, repeat_enable;
// Цвет и прозрачность (VfxMat.albedo_color), ядро — цвет самых плотных мест и кромки растворения
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 core_color : source_color = vec4(1.0);
uniform float hdr = 1.0;
uniform float core_amt = 0.0;
// Шум: насколько разъедает форму, масштаб, бег по UV, искажение формы
uniform float noise_amt = 0.0;
uniform vec2 noise_scale = vec2(1.0);
uniform vec2 scroll = vec2(0.0);
uniform float distort = 0.0;
// Шум по кругу (кольца, круги на земле): угол и радиус вместо UV, twist — закрутка
uniform float polar = 0.0;
uniform float twist = 0.0;
// Растворение: порог, рост порога с возрастом частицы, мягкость края, яркость кромки
uniform float dissolve = 0.0;
uniform float age_dissolve = 0.0;
uniform float soft = 0.12;
uniform float edge = 0.0;
// Свечение краёв объёмных мешей (сфера, труба): 0 — нет, 1 — только края
uniform float fresnel = 0.0;
// Росчерк: голова в reveal (по UV.x), хвост длиной reveal_tail; < 0 — выключено
uniform float reveal = -1.0;
uniform float reveal_tail = 0.6;
// Поворот маски (рад) и мерцание (частота, 0 — нет)
uniform float rot = 0.0;
uniform float pulse = 0.0;
// 0 — как есть, 1 — частицы к камере (CPUParticles3D), 2 — картинка к камере, 3 — частица вдоль скорости
uniform int billboard = 0;
uniform float seed = 0.0;

varying float v_rand;
varying float v_age;

void vertex() {
	v_rand = fract(INSTANCE_CUSTOM.x * 1.1140846 + seed * 0.618034);
	v_age = INSTANCE_CUSTOM.y;
	if (billboard == 1) {
		mat4 w = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]),
			MODEL_MATRIX[3]);
		w = w * mat4(vec4(cos(INSTANCE_CUSTOM.x), -sin(INSTANCE_CUSTOM.x), 0.0, 0.0),
			vec4(sin(INSTANCE_CUSTOM.x), cos(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_MATRIX = VIEW_MATRIX * w;
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	} else if (billboard == 2) {
		mat4 w2 = mat4(normalize(INV_VIEW_MATRIX[0]) * length(MODEL_MATRIX[0].xyz),
			normalize(INV_VIEW_MATRIX[1]) * length(MODEL_MATRIX[1].xyz),
			normalize(INV_VIEW_MATRIX[2]) * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = VIEW_MATRIX * w2;
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	} else if (billboard == 3) {
		// Ось Y частицы — по скорости (particle_flag_align_y), плоскость повёрнута к камере
		vec3 p = MODEL_MATRIX[3].xyz;
		vec3 yv = MODEL_MATRIX[1].xyz;
		vec3 yn = normalize(yv + vec3(0.0, 1e-5, 0.0));
		vec3 to_cam = normalize(INV_VIEW_MATRIX[3].xyz - p);
		vec3 xn = cross(yn, to_cam);
		xn = length(xn) < 1e-4 ? normalize(INV_VIEW_MATRIX[0].xyz) : normalize(xn);
		vec3 zn = normalize(cross(xn, yn));
		mat4 w3 = mat4(vec4(xn * length(MODEL_MATRIX[0].xyz), 0.0), vec4(yv, 0.0),
			vec4(zn * length(MODEL_MATRIX[2].xyz), 0.0), vec4(p, 1.0));
		MODELVIEW_MATRIX = VIEW_MATRIX * w3;
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	vec2 uv = UV;
	if (billboard == 3) {
		uv = vec2(UV.y, UV.x);
	}
	if (rot != 0.0) {
		vec2 c0 = uv - 0.5;
		float cs = cos(rot);
		float sn = sin(rot);
		uv = vec2(c0.x * cs - c0.y * sn, c0.x * sn + c0.y * cs) + 0.5;
	}
	float t = TIME;
	float nn = 0.5;
	vec2 muv = uv;
	if (noise_amt > 0.0 || distort > 0.0) {
		vec2 nuv = uv;
		if (polar > 0.5) {
			vec2 c = uv - 0.5;
			float r = length(c) * 2.0;
			nuv = vec2(atan(c.y, c.x) * 0.1591549 + r * twist, r);
		}
		nuv = nuv * noise_scale + scroll * t + vec2(v_rand * 7.13, v_rand * 3.71);
		float n1 = texture(noise, nuv).r;
		float n2 = texture(noise, nuv * 2.03 + vec2(0.41, 0.17) - scroll * t * 0.5).r;
		nn = n1 * 0.62 + n2 * 0.38;
		muv = uv + (vec2(n1, n2) - 0.5) * distort;
	}
	float m = texture(mask, muv).a;
	float val = m * mix(1.0, nn * 1.8, noise_amt);
	float thr = dissolve + v_age * age_dissolve;
	float a = smoothstep(thr, thr + soft, val);
	vec3 col = tint.rgb * COLOR.rgb;
	if (reveal >= 0.0) {
		float x = uv.x;
		float body = smoothstep(reveal - reveal_tail, reveal, x) * (1.0 - smoothstep(reveal, reveal + 0.05, x));
		a *= body;
		col = mix(col, core_color.rgb, smoothstep(reveal - reveal_tail * 0.25, reveal, x) * 0.7);
	}
	col = mix(col, core_color.rgb, smoothstep(0.5, 1.0, val) * core_amt);
	if (edge > 0.0 && thr > 0.001) {
		float e = 1.0 - smoothstep(0.0, 0.14, val - thr);
		col += core_color.rgb * e * edge;
	}
	if (fresnel > 0.0) {
		float ndv = abs(dot(normalize(NORMAL), normalize(VIEW)));
		float rim = pow(1.0 - ndv, 2.2);
		a *= mix(1.0, rim * 1.7 + 0.05, fresnel);
		col = mix(col, core_color.rgb, rim * fresnel * 0.55);
	}
	if (pulse > 0.0) {
		col *= 1.0 + 0.3 * sin(t * pulse + v_rand * 6.2831853);
	}
	ALBEDO = col * hdr;
	ALPHA = clamp(a * tint.a * COLOR.a, 0.0, 1.0);
}

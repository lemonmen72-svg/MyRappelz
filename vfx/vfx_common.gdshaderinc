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
// 0 — как есть, 1 — частицы к камере (CPUParticles3D), 2 — картинка к камере, 3 — частица вдоль скорости,
// 4 — стоит вертикально, повёрнута к камере вокруг Y (эффект «сбоку» на земле), 5 — к камере, ось X кадра — по
// face_dir (эффект «вправо»: укол, рёв, поток душ; смотрит на экране влево — кадр зеркально, верх остаётся верхом)
uniform int billboard = 0;
uniform float seed = 0.0;
uniform vec3 face_dir = vec3(1.0, 0.0, 0.0);
// face_dir — отрезок (молния, поток душ): ширина кадра — его длина на экране, а не масштаб узла
uniform bool face_span = false;
// Сдвиг к камере, м (эффект на персонаже рисуется перед моделью, а не внутри неё); на экране — то же место и размер
uniform float cam_push = 0.0;
// Раскадровка (VfxFlip): маска — сетка кадров flip (столбцы, строки; 0 — обычная маска), яркость — в .r. Кадр —
// flip_f (дробный: соседние кадры смешиваются) или возраст частицы (flip_age). flip_cycle — петля: две половины
// цикла со сдвигом на полцикла, каждая гаснет к своему шву (вес sin²), сумма весов — 1: без скачка на любом листе.
// Опора pivot — точка кадра (доли от левого верхнего угла) в начале координат узла (у видов «сбоку» — земля).
uniform vec2 flip = vec2(0.0);
uniform float flip_n = 16.0;
uniform float flip_f = 0.0;
uniform bool flip_cycle = false;
uniform bool flip_age = false;
uniform bool flip_mirror = false;
uniform vec2 pivot = vec2(0.5);
// Цвет по яркости кадра: тёмное — ramp_lo, середина — tint, самое яркое — core_color (core_amt); flip_gain — яркость
uniform vec4 ramp_lo : source_color = vec4(1.0);
uniform float ramp_amt = 0.0;
uniform float flip_gain = 1.0;

varying float v_rand;
varying float v_age;
varying float v_mirror;

void vertex() {
	v_rand = fract(INSTANCE_CUSTOM.x * 1.1140846 + seed * 0.618034);
	v_age = INSTANCE_CUSTOM.y;
	v_mirror = 0.0;
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
	} else if (billboard == 4) {
		vec3 p4 = MODEL_MATRIX[3].xyz;
		vec3 tc = INV_VIEW_MATRIX[3].xyz - p4;
		tc.y = 0.0;
		vec3 back = vec3(INV_VIEW_MATRIX[2].x, 0.0, INV_VIEW_MATRIX[2].z);
		vec3 zn4 = length(tc) > 1e-4 ? normalize(tc) : (length(back) > 1e-4 ? normalize(back) : vec3(0.0, 0.0, 1.0));
		vec3 xn4 = normalize(cross(vec3(0.0, 1.0, 0.0), zn4));
		mat4 w4 = mat4(vec4(xn4 * length(MODEL_MATRIX[0].xyz), 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(zn4 * length(MODEL_MATRIX[2].xyz), 0.0), vec4(p4, 1.0));
		MODELVIEW_MATRIX = VIEW_MATRIX * w4;
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	} else if (billboard == 5) {
		vec3 p5 = MODEL_MATRIX[3].xyz;
		vec3 zn5 = normalize(INV_VIEW_MATRIX[3].xyz - p5);
		vec3 d5 = face_dir - zn5 * dot(face_dir, zn5);
		vec3 cr = normalize(INV_VIEW_MATRIX[0].xyz);
		vec3 xn5 = length(d5) > 1e-4 ? normalize(d5) : cr;
		if (dot(xn5, cr) < 0.0) {
			xn5 = -xn5;
			v_mirror = 1.0;
		}
		vec3 yn5 = normalize(cross(zn5, xn5));
		float sx = face_span ? max(length(d5), 0.05) : length(MODEL_MATRIX[0].xyz);
		mat4 w5 = mat4(vec4(xn5 * sx, 0.0), vec4(yn5 * length(MODEL_MATRIX[1].xyz), 0.0),
			vec4(zn5 * length(MODEL_MATRIX[2].xyz), 0.0), vec4(p5, 1.0));
		MODELVIEW_MATRIX = VIEW_MATRIX * w5;
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
	// Опора кадра — в начало координат квада (QuadMesh 1×1 в XY; зеркальный кадр — опора тоже зеркально)
	if (flip.x > 0.5 && (billboard == 2 || billboard == 4 || billboard == 5)) {
		bool mir = flip_mirror != (v_mirror > 0.5);
		float px = mir ? 1.0 - pivot.x : pivot.x;
		VERTEX.xy += vec2(0.5 - px, pivot.y - 0.5);
	}
	if (cam_push > 0.0) {
		vec3 t0 = MODELVIEW_MATRIX[3].xyz;
		float dd = length(t0);
		float k = max(dd - cam_push, 0.3) / max(dd, 1e-4);
		MODELVIEW_MATRIX[0] *= k;
		MODELVIEW_MATRIX[1] *= k;
		MODELVIEW_MATRIX[2] *= k;
		MODELVIEW_MATRIX[3].xyz = t0 * k;
	}
}

// Кадр раскадровки f (0…flip_n − 1, дробный — смешать с соседним): яркость в точке cuv кадра.
float flip_at(float f, vec2 cuv, bool wrap) {
	float f0 = floor(f);
	float w = f - f0;
	float f1 = f0 + 1.0;
	if (f1 > flip_n - 1.0) {
		f1 = wrap ? 0.0 : flip_n - 1.0;
	}
	f0 = clamp(f0, 0.0, flip_n - 1.0);
	vec2 cs = vec2(1.0) / flip;
	vec2 a0 = (vec2(mod(f0, flip.x), floor(f0 / flip.x)) + cuv) * cs;
	vec2 a1 = (vec2(mod(f1, flip.x), floor(f1 / flip.x)) + cuv) * cs;
	return mix(texture(mask, a0).r, texture(mask, a1).r, w);
}

float flip_mask(vec2 uv) {
	vec2 cuv = clamp(uv, vec2(0.004), vec2(0.996));
	if (flip_age) {
		return flip_at(clamp(v_age, 0.0, 1.0) * (flip_n - 1.0), cuv, false);
	}
	if (flip_cycle) {
		float fa = mod(flip_f, flip_n);
		float fb = mod(flip_f + flip_n * 0.5, flip_n);
		float wa = sin(3.14159265 * fa / flip_n);
		wa *= wa;
		return flip_at(fa, cuv, true) * wa + flip_at(fb, cuv, true) * (1.0 - wa);
	}
	return flip_at(clamp(flip_f, 0.0, flip_n - 1.0), cuv, false);
}

void fragment() {
	vec2 uv = UV;
	if (billboard == 3) {
		uv = vec2(UV.y, UV.x);
	}
	if (flip_mirror != (v_mirror > 0.5)) {
		uv.x = 1.0 - uv.x;
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
	bool fb = flip.x > 0.5;
	float m = fb ? flip_mask(muv) : texture(mask, muv).a;
	float val = m * mix(1.0, nn * 1.8, noise_amt);
	float thr = dissolve + v_age * age_dissolve;
	float a = smoothstep(thr, thr + soft, val);
	vec3 col = tint.rgb * COLOR.rgb;
	if (fb) {
		// Нарисованный кадр: прозрачность — его яркость (мягкие ореолы остаются), цвет — по яркости
		a = clamp(val * flip_gain, 0.0, 1.0) * (thr > 0.001 ? smoothstep(thr, thr + soft, val) : 1.0);
		col = mix(ramp_lo.rgb, tint.rgb, mix(1.0, smoothstep(0.0, 0.55, val), ramp_amt)) * COLOR.rgb;
	}
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

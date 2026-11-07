// Пламя факелов, костров и жаровен (0.46, задача Максима: «на факелах и кострах эффекты огня соответствующего
// цвета»; уровень — как у эффектов умений, vfx/vfx_common.gdshaderinc). Квад, всегда к камере (поворот в вершинах,
// вытянут вверх), сложение цвета. Форма — капля огня, края рвёт шум, бежит вверх; ядро светлое, кромка — цвет огня
// (INSTANCE_CUSTOM: rgb — цвет, a — фаза), внизу — синеватое основание у тёплого огня; ночью ярче (atmo_night).
// Один материал на все огни мира (MultiMesh), без текстур — шум процедурный (FastNoise на телефоне дороже).
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

global uniform float atmo_night;
uniform float intensity = 1.6;
uniform float night_boost = 0.6;

varying vec4 v_custom;

float fl_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float fl_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(fl_hash(i), fl_hash(i + vec2(1.0, 0.0)), u.x), mix(fl_hash(i + vec2(0.0, 1.0)), fl_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fl_fbm(vec2 p) {
	return fl_noise(p) * 0.55 + fl_noise(p * 2.1 + 5.3) * 0.3 + fl_noise(p * 4.3 + 1.7) * 0.15;
}

void vertex() {
	v_custom = INSTANCE_CUSTOM;
	// К камере: ось Y — вверх мира, ширина — поперёк взгляда
	vec3 center = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	vec3 to_cam = CAMERA_POSITION_WORLD - center;
	to_cam.y = 0.0;
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), normalize(to_cam + vec3(0.0001, 0.0, 0.0))));
	vec3 world = center + right * VERTEX.x * sx + vec3(0.0, 1.0, 0.0) * (VERTEX.y + 0.5) * sy;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	vec2 uv = UV;
	float ph = v_custom.a * 6.2831;
	float t = TIME * 1.6 + ph;
	// Капля: шире внизу, к верху сужается; края колышет шум
	float y = 1.0 - uv.y;
	float sway = (fl_noise(vec2(y * 2.0 - t * 0.9, ph)) - 0.5) * 0.18 * y;
	float x = (uv.x - 0.5 - sway) * 2.0;
	float width = mix(0.95, 0.12, pow(y, 0.85));
	float shape = 1.0 - smoothstep(width * 0.55, width, abs(x));
	shape *= smoothstep(0.0, 0.12, y) * (1.0 - smoothstep(0.62, 1.0, y));
	// Языки пламени: шум бежит вверх, у верха рвёт сильнее
	float n = fl_fbm(vec2(x * 1.6, y * 2.4 - t * 2.2));
	float tongues = smoothstep(0.25 + y * 0.55, 0.55 + y * 0.45, n + (1.0 - y) * 0.35);
	float a = shape * tongues;
	// Цвет: ядро светлое, середина — цвет огня, кончики темнее; у тёплого огня основание синее
	vec3 fire = v_custom.rgb;
	float core = smoothstep(0.35, 0.9, a) * (1.0 - smoothstep(0.2, 0.7, y));
	vec3 col = mix(fire * 0.55, fire, smoothstep(0.1, 0.5, a));
	col = mix(col, vec3(1.0, 0.97, 0.85), core * 0.85);
	float warm = clamp(fire.r - fire.b, 0.0, 1.0);
	col = mix(col, vec3(0.35, 0.55, 1.0), (1.0 - smoothstep(0.0, 0.18, y)) * warm * 0.5 * shape);
	float k = intensity * (1.0 + atmo_night * night_boost);
	ALBEDO = col * a * k;
	ALPHA = 1.0;
}

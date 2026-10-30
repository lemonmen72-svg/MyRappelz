// Контур зверя или питомца (next_pass материала creature.gdshader): вывернутая оболочка, как
// outline.gdshader, но для слитого меша. Направление раздувания — в TANGENT (CreatureModels пишет
// туда направление от центра детали, у тора — нормаль), поэтому у боксов и конусов нет разрывов.
// Цвет контура — тёмный оттенок цвета вершины (как Util.outline_mat). Детали с UV.y = 0
// (глаза, блики, румянец, светящиеся) без контура: их вершины стягиваются в точку.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, fog_disabled;

// Толщина контура в метрах на расстоянии 10 м от камеры.
uniform float width = 0.02;

varying vec3 v_col;

vec3 rgb2hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
	return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

void vertex() {
	if (UV.y < 0.5) {
		VERTEX = vec3(0.0);
	} else {
		vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float dist = length(world - CAMERA_POSITION_WORLD);
		float scale = length(MODEL_MATRIX[0].xyz);
		vec3 dir = TANGENT;
		if (dot(dir, dir) < 1.0e-6) {
			dir = NORMAL;
		}
		VERTEX += normalize(dir) * width * clamp(dist / 10.0, 0.6, 3.0) / max(scale, 0.001);
	}
	vec3 hsv = rgb2hsv(COLOR.rgb);
	hsv.y = min(1.0, hsv.y * 1.2 + 0.1);
	hsv.z *= 0.28;
	vec3 c = hsv2rgb(hsv);
	if (!OUTPUT_IS_SRGB) {
		c = mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
	}
	v_col = c;
}

void fragment() {
	ALBEDO = v_col;
}

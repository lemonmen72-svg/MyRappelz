// Постобработка (canvas_item на полноэкранном ColorRect в слое под HUD, PostFx). Части включаются
// #define вместо строки-метки ниже (PostFx.shader_for), без define — простая копия экрана:
// - USE_FXAA: сглаживание краёв (FXAA по яркости: 5 выборок, на краях ещё 4 вдоль края; на ровных местах —
//   ранний выход). Для GL Compatibility, где нет встроенного FXAA; MSAA — отдельно (Viewport.msaa_3d);
// - USE_GRADE: цветокоррекция — насыщенность, лёгкий контраст, тёплые света и прохладные тени, виньетка;
// - USE_BLOOM: мягкое свечение светлых мест — размытие выборками вокруг точки (только вместе с USE_GRADE).
shader_type canvas_item;
render_mode unshaded;

// @VARIANT

// Без mip-уровней экранной текстуры: в GL Compatibility 4.3 при масштабе 3D-кадра ≠ 1 (900p/720p) их построение
// писало уменьшенные копии кадра в угол экрана (копии кадра «лесенкой», мерцание краёв — жалоба Максима, 0.24).
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;

uniform float saturation = 1.0;
uniform float contrast = 1.04;
uniform vec3 warm_tint = vec3(1.035, 1.0, 0.95);
uniform vec3 cool_tint = vec3(0.97, 0.99, 1.04);
uniform float vignette = 0.18;
uniform float bloom_strength = 0.3;
uniform float bloom_threshold = 0.93;
// FXAA: наибольший сдвиг вдоль края (px), порог контраста (доля яркости), подавление на тёмных местах.
uniform float fxaa_span = 6.0;
uniform float fxaa_edge = 0.125;
uniform float fxaa_edge_min = 0.0312;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

vec3 sample_screen(vec2 uv) {
	return textureLod(screen_tex, uv, 0.0).rgb;
}

#ifdef USE_FXAA
vec3 fxaa(vec2 uv, vec2 px) {
	vec3 m = sample_screen(uv);
	vec3 nw = sample_screen(uv + vec2(-1.0, -1.0) * px);
	vec3 ne = sample_screen(uv + vec2(1.0, -1.0) * px);
	vec3 sw = sample_screen(uv + vec2(-1.0, 1.0) * px);
	vec3 se = sample_screen(uv + vec2(1.0, 1.0) * px);
	float l_m = dot(m, LUMA);
	float l_nw = dot(nw, LUMA);
	float l_ne = dot(ne, LUMA);
	float l_sw = dot(sw, LUMA);
	float l_se = dot(se, LUMA);
	float l_min = min(l_m, min(min(l_nw, l_ne), min(l_sw, l_se)));
	float l_max = max(l_m, max(max(l_nw, l_ne), max(l_sw, l_se)));
	if (l_max - l_min < max(fxaa_edge_min, l_max * fxaa_edge)) {
		return m;
	}
	vec2 dir = vec2(-((l_nw + l_ne) - (l_sw + l_se)), (l_nw + l_sw) - (l_ne + l_se));
	float reduce = max((l_nw + l_ne + l_sw + l_se) * (0.25 / 8.0), 1.0 / 128.0);
	float rcp_min = 1.0 / (min(abs(dir.x), abs(dir.y)) + reduce);
	dir = clamp(dir * rcp_min, vec2(-fxaa_span), vec2(fxaa_span)) * px;
	vec3 a = 0.5 * (sample_screen(uv + dir * (1.0 / 3.0 - 0.5)) + sample_screen(uv + dir * (2.0 / 3.0 - 0.5)));
	vec3 b = a * 0.5 + 0.25 * (sample_screen(uv - dir * 0.5) + sample_screen(uv + dir * 0.5));
	float l_b = dot(b, LUMA);
	return (l_b < l_min || l_b > l_max) ? a : b;
}
#endif

void fragment() {
	vec2 uv = SCREEN_UV;
#ifdef USE_FXAA
	vec3 c = fxaa(uv, SCREEN_PIXEL_SIZE);
#else
	vec3 c = sample_screen(uv);
#endif
#ifdef USE_BLOOM
	if (bloom_strength > 0.0) {
		// Размытие выборками нулевого уровня: два кольца по 6 точек (7 и 16 px) — без mip-уровней
		vec3 b = vec3(0.0);
		for (int i = 0; i < 6; i++) {
			float a = float(i) * 1.0472 + 0.26;
			vec2 dir = vec2(cos(a), sin(a)) * SCREEN_PIXEL_SIZE;
			b += textureLod(screen_tex, uv + dir * 7.0, 0.0).rgb * 0.1;
			b += textureLod(screen_tex, uv + dir * 16.0, 0.0).rgb * 0.0667;
		}
		float bl = max(b.r, max(b.g, b.b));
		c += b * smoothstep(bloom_threshold, 1.0, bl) * bloom_strength;
	}
#endif
#ifdef USE_GRADE
	float l = dot(c, LUMA);
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c *= mix(cool_tint, warm_tint, smoothstep(0.15, 0.75, l));
	vec2 d = uv - 0.5;
	float vig = 1.0 - vignette * smoothstep(0.2, 0.75, dot(d, d) * 2.0);
	c *= vig;
#endif
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}

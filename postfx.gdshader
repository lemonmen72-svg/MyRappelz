// Постобработка (canvas_item на полноэкранном ColorRect в слое под HUD, PostFx):
// - мягкое свечение светлых мест (по mip-уровням экранной текстуры; только полный вариант);
// - цветокоррекция: насыщенность, лёгкий контраст, тёплые света и прохладные тени (в духе аниме);
// - лёгкая виньетка.
// Облегчённый вариант (строка-метка ниже заменяется на #define POSTFX_LITE в PostFx): без свечения
// и без mip-уровней — одна выборка на пиксель.
shader_type canvas_item;
render_mode unshaded;

// @VARIANT

#ifdef POSTFX_LITE
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
#else
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;
#endif

uniform float saturation = 1.0;
uniform float contrast = 1.04;
uniform vec3 warm_tint = vec3(1.035, 1.0, 0.95);
uniform vec3 cool_tint = vec3(0.97, 0.99, 1.04);
uniform float vignette = 0.18;
uniform float bloom_strength = 0.3;
uniform float bloom_threshold = 0.93;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = textureLod(screen_tex, uv, 0.0).rgb;
#ifndef POSTFX_LITE
	if (bloom_strength > 0.0) {
		vec2 o = SCREEN_PIXEL_SIZE * 10.0;
		vec3 b = textureLod(screen_tex, uv, 3.0).rgb * 0.3;
		b += textureLod(screen_tex, uv + vec2(o.x, o.y), 4.0).rgb * 0.15;
		b += textureLod(screen_tex, uv + vec2(-o.x, o.y), 4.0).rgb * 0.15;
		b += textureLod(screen_tex, uv + vec2(o.x, -o.y), 4.0).rgb * 0.15;
		b += textureLod(screen_tex, uv + vec2(-o.x, -o.y), 4.0).rgb * 0.15;
		b += textureLod(screen_tex, uv, 5.5).rgb * 0.1;
		float bl = max(b.r, max(b.g, b.b));
		c += b * smoothstep(bloom_threshold, 1.0, bl) * bloom_strength;
	}
#endif
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c *= mix(cool_tint, warm_tint, smoothstep(0.15, 0.75, l));
	vec2 d = uv - 0.5;
	float vig = 1.0 - vignette * smoothstep(0.2, 0.75, dot(d, d) * 2.0);
	COLOR = vec4(clamp(c * vig, 0.0, 1.0), 1.0);
}

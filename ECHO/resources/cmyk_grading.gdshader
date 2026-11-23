shader_type canvas_item;
render_mode unshaded;
// Restores the environment's colour channel by channel, in the CMYK sense:
// each colour is split into a grey part (K) and chroma in C, M and Y; only the chroma of
// restored channels is kept. Nothing restored = a dark, grey world.
// On top of that:
//  - area_full: an area whose blobs AND vassal were all helped gets its colour even stronger;
//  - bloom (after K): the whole world opens into a soft rainbow, stronger the more blobs
//    were helped along the journey.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec3 restored = vec3(0.0); // C, M, Y amounts 0..1
uniform float brightness = 0.55;
// Restored inks come back a little stronger than they were, so each return is noticeable.
uniform float chroma_boost = 1.8;
// World rects (x, y, w, h) of the three sense areas: vista, som, tato.
uniform vec4 area_rect_0 = vec4(0.0);
uniform vec4 area_rect_1 = vec4(0.0);
uniform vec4 area_rect_2 = vec4(0.0);
uniform vec3 area_full = vec3(0.0);
uniform float bloom = 0.0;
uniform float time_s = 0.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float rect_weight(vec4 rect, vec2 p) {
	if (rect.z <= 0.0) {
		return 0.0;
	}
	vec2 center = rect.xy + rect.zw * 0.5;
	vec2 d = abs(p - center) - rect.zw * 0.5;
	float outside = length(max(d, vec2(0.0)));
	return 1.0 - smoothstep(0.0, 260.0, outside);
}

vec3 hue(float h) {
	return clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

void fragment() {
	vec3 rgb = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	vec3 cmy = vec3(1.0) - rgb;
	float k = min(cmy.r, min(cmy.g, cmy.b));
	float full = area_full.x * rect_weight(area_rect_0, world_pos)
		+ area_full.y * rect_weight(area_rect_1, world_pos)
		+ area_full.z * rect_weight(area_rect_2, world_pos);
	float boost = chroma_boost + 0.9 * full + 0.7 * bloom;
	vec3 graded = clamp(vec3(k) + (cmy - vec3(k)) * restored * boost, 0.0, 1.0);
	vec3 result = (vec3(1.0) - graded);
	// Slightly darker greys while colour is missing, so restored areas feel alive.
	float luma = dot(rgb, vec3(0.299, 0.587, 0.114));
	result = mix(vec3(luma), result, 0.35 + 0.65 * max(restored.r, max(restored.g, restored.b)));
	result *= brightness * (1.0 + 0.12 * full);
	// After the end: a slow rainbow drifting over the ground (every colour, not only CMYK).
	if (bloom > 0.0) {
		float h = world_pos.x * 0.00045 - world_pos.y * 0.00035 + sin(world_pos.y * 0.0021 + time_s * 0.15) * 0.18 + time_s * 0.01;
		vec3 rainbow = hue(h);
		float rl = dot(result, vec3(0.299, 0.587, 0.114));
		vec3 tinted = mix(result, rainbow * (rl * 1.7 + 0.035), 0.55);
		result = mix(result, tinted, clamp(bloom, 0.0, 1.0) * 0.6);
	}
	COLOR = vec4(result, 1.0);
}

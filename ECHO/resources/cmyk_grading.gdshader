shader_type canvas_item;
render_mode unshaded;
// Restores the environment's colour channel by channel, in the CMYK sense:
// each colour is split into a grey part (K) and chroma in C, M and Y; only the chroma of
// restored channels is kept. Nothing restored = a dark, grey world.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec3 restored = vec3(0.0); // C, M, Y amounts 0..1
uniform float brightness = 0.55;
// Restored inks come back a little stronger than they were, so each return is noticeable.
uniform float chroma_boost = 1.8;

void fragment() {
	vec3 rgb = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	vec3 cmy = vec3(1.0) - rgb;
	float k = min(cmy.r, min(cmy.g, cmy.b));
	vec3 graded = clamp(vec3(k) + (cmy - vec3(k)) * restored * chroma_boost, 0.0, 1.0);
	vec3 result = (vec3(1.0) - graded);
	// Slightly darker greys while colour is missing, so restored areas feel alive.
	float luma = dot(rgb, vec3(0.299, 0.587, 0.114));
	result = mix(vec3(luma), result, 0.35 + 0.65 * max(restored.r, max(restored.g, restored.b)));
	COLOR = vec4(result * brightness, 1.0);
}

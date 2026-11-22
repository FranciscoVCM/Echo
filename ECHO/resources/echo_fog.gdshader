shader_type canvas_item;
render_mode unshaded;
// Fog of war for the Echo world. Based on field_of_view.gdshader (wall-blocked visibility
// polygon + radius), plus soft light sources (e.g. freed blobs in the dark caves).

const int MAX_POINTS = 384;
const int MAX_LIGHTS = 48;

uniform vec2 visibility_points[MAX_POINTS];
uniform int point_count = 0;
uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform vec2 player_uv = vec2(0.5, 0.5);
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float vision_radius_pixels = 250.0;
uniform vec4 fog_color : source_color = vec4(0.05, 0.06, 0.08, 1.0);
uniform float fog_opacity : hint_range(0.0, 1.0) = 0.7;
uniform float edge_softness = 90.0;
uniform float wall_edge_softness = 8.0;
uniform float blur_strength = 0.35;
// xy: screen pixels, z: radius in pixels, w: strength 0..1
uniform vec4 lights[MAX_LIGHTS];
uniform int light_count = 0;

void fragment() {
	vec2 pixel = UV * viewport_size;
	bool inside_visibility = false;
	float nearest_edge = 100000.0;
	for (int index = 0; index < MAX_POINTS; index++) {
		if (index >= point_count) {
			break;
		}
		int next_index = index + 1;
		if (next_index >= point_count) {
			next_index = 0;
		}
		vec2 a = visibility_points[index] * viewport_size;
		vec2 b = visibility_points[next_index] * viewport_size;
		if ((a.y > pixel.y) != (b.y > pixel.y)) {
			float crossing_x = (b.x - a.x) * (pixel.y - a.y) / (b.y - a.y) + a.x;
			if (pixel.x < crossing_x) {
				inside_visibility = !inside_visibility;
			}
		}
		vec2 segment = b - a;
		float along = clamp(dot(pixel - a, segment) / max(dot(segment, segment), 0.001), 0.0, 1.0);
		nearest_edge = min(nearest_edge, distance(pixel, a + segment * along));
	}
	float distance_from_player = distance(pixel, player_uv * viewport_size);
	float range_fog = smoothstep(max(vision_radius_pixels - edge_softness, 0.0), vision_radius_pixels, distance_from_player);
	float wall_fog = 1.0 - smoothstep(0.0, max(wall_edge_softness, 0.001), nearest_edge);
	float fog_amount = inside_visibility ? max(range_fog, wall_fog) : 1.0;
	for (int index = 0; index < MAX_LIGHTS; index++) {
		if (index >= light_count) {
			break;
		}
		vec4 light = lights[index];
		float lit = 1.0 - smoothstep(light.z * 0.35, light.z, distance(pixel, light.xy));
		fog_amount = min(fog_amount, 1.0 - lit * light.w);
	}
	float blur_lod = blur_strength * smoothstep(0.08, 0.85, fog_amount);
	vec3 scene_color = textureLod(screen_texture, SCREEN_UV, blur_lod).rgb;
	COLOR = vec4(mix(scene_color, fog_color.rgb, fog_opacity * fog_amount), 1.0);
}

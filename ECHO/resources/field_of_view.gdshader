shader_type canvas_item;
render_mode unshaded;

const int MAX_POINTS = 256;

uniform vec2 visibility_points[MAX_POINTS];
uniform int point_count = 0;
uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform vec2 player_uv = vec2(0.5, 0.5);
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float vision_radius_pixels = 250.0;
uniform vec4 fog_color : source_color = vec4(0.14, 0.19, 0.23, 1.0);
uniform float fog_opacity : hint_range(0.0, 1.0) = 0.48;
uniform float edge_softness : hint_range(0.0, 180.0) = 80.0;
uniform float wall_edge_softness : hint_range(0.0, 24.0) = 8.0;
uniform float blur_strength : hint_range(0.0, 2.0) = 0.28;


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
		bool crosses_scanline = (a.y > pixel.y) != (b.y > pixel.y);
		if (crosses_scanline) {
			float crossing_x = (b.x - a.x) * (pixel.y - a.y) / (b.y - a.y) + a.x;
			if (pixel.x < crossing_x) {
				inside_visibility = !inside_visibility;
			}
		}

		vec2 segment = b - a;
		float segment_length_squared = max(dot(segment, segment), 0.001);
		float along_segment = clamp(dot(pixel - a, segment) / segment_length_squared, 0.0, 1.0);
		nearest_edge = min(nearest_edge, distance(pixel, a + segment * along_segment));
	}

	float distance_from_player = distance(pixel, player_uv * viewport_size);
	float range_fog = smoothstep(
		max(vision_radius_pixels - edge_softness, 0.0),
		vision_radius_pixels,
		distance_from_player
	);
	float wall_fog = 1.0 - smoothstep(0.0, max(wall_edge_softness, 0.001), nearest_edge);
	float fog_amount = inside_visibility ? max(range_fog, wall_fog) : 1.0;
	float blur_lod = blur_strength * smoothstep(0.08, 0.85, fog_amount);
	vec3 scene_color = textureLod(screen_texture, SCREEN_UV, blur_lod).rgb;
	vec3 fogged_color = mix(scene_color, fog_color.rgb, fog_opacity * fog_amount);
	COLOR = vec4(fogged_color, 1.0);
}

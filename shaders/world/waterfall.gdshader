shader_type spatial;
// Stylised waterfall: flowing noise layers coloured into lighter water bands
// and foam, foam and gaps towards the edges. A 3D (spatial) port of a
// canvas_item waterfall shader, for the waterfall meshes (waterfall.gd).
//
// UV: x = 0..1 across the water (0 / 1 = its sides), y = 0..1 from the top of
// the fall to the bottom. sprite_or_color_rect_resolution = its size in
// "pixels" (waterfall.gd uses 10 per metre), so the pattern keeps its scale.
render_mode cull_disabled, depth_draw_opaque;

uniform vec2 sprite_or_color_rect_resolution = vec2(65.0, 400.0);

// If the waterfall is very tall or wide and the noise pattern start to repeat too much in the waterfall,
// increase the resolution of the sampler2D noise texture
uniform sampler2D noise_texture : repeat_enable; // Tick the checkbox "seamless" on the noise texture too
uniform float noise_zoom = 2.0;
uniform vec2 noise_stretch = vec2(1.0, 0.1);

// color_noise() can use either some set colors or a gradient.
uniform sampler2D water_gradient : source_color; // GradientTexture1D
uniform vec3 foam_color : source_color = vec3(0.915, 0.965, 0.938);

// number of thresholds = number of lighter layers in the water.
// For example threshold 1 = 0.5 and threshold 2 = 0.7 means any noise greyscale value above 0.5 = first lighter layer blue etc
uniform float lighter_water_color_threshold_1 = 0.47;
uniform float lighter_water_color_threshold_2 = 0.57;
uniform float foam_color_threshold = 0.6;

uniform float waterfall_speed = 140.0;
uniform float waterfall_noise_blend_speed = 8.0;

uniform float opacity_strength = 0.9; // higher value = opacity at the edges only, lower value = gaps in the middle of the waterfall too
uniform float opacity_edge_up = 2.0;
uniform float opacity_edge_down = 50.0;
uniform float opacity_edge_left = 6.0;
uniform float opacity_edge_right = 6.0;

uniform float edge_foam_up = 7.0;
uniform float edge_foam_down = 70.0;
uniform float edge_foam_left = 5.0;
uniform float edge_foam_right = 5.0;

// terrain_foam_mask should cover the waterfall like its UV (0..1 both ways).
// Paint grey/white on top of an transparent background where the extra foam should be. Let the white fade to opaque for the foam to look better.
uniform bool use_terrain_foam_mask = false;
uniform sampler2D terrain_foam_mask;


float get_moving_noise_layer(vec2 uv, vec2 noise_scale, vec2 move_dir, vec2 random_noise_offset) {
	// random_noise_offset = make it so the same noise texture can be reused for many layers without a visual "loop/symmetry" in the pattern.
	vec2 speed = vec2(waterfall_noise_blend_speed, waterfall_speed) * noise_scale;
	return texture(noise_texture, uv + move_dir * TIME * speed + random_noise_offset).r;
}

vec3 color_noise(float noise, vec2 uv) {
	// Add more or less if checks depending on how many lighter layers in the water that should exist.
	vec3 waterfall_color = texture(water_gradient, vec2(uv.y, 0.5)).rgb;
	if (noise > lighter_water_color_threshold_1) {
		waterfall_color += vec3(0.07);
	}
	if (noise > lighter_water_color_threshold_2) {
		waterfall_color += vec3(0.07);
	}
	if (noise > foam_color_threshold) {
		waterfall_color = foam_color;
	}
	return waterfall_color;
}

void fragment() {
	// Scaled UV: the effect looks the same whatever the size of the water and of the noise texture.
	vec2 uv = UV;
	vec2 noise_scale = (noise_zoom * noise_stretch) / vec2(textureSize(noise_texture, 2));
	vec2 scaled_uv = uv * sprite_or_color_rect_resolution * noise_scale;

	// Flowing water: several copies of the noise moving in slightly different directions, blended.
	float number_of_noise_layers = 3.0;
	float noise = (
		get_moving_noise_layer(scaled_uv, noise_scale, vec2(0.0, -1.0), vec2(46.2, -32.1)) +
		get_moving_noise_layer(scaled_uv, noise_scale, vec2(1.0, -1.0), vec2(23.7, 41.2)) +
		get_moving_noise_layer(scaled_uv, noise_scale, vec2(-1.0, -1.0), vec2(-81.3, 12.9))
	) / number_of_noise_layers;

	// Opacity edges: brighten the noise exponentially towards each edge; the brightest parts become gaps.
	float o_up = pow(1.0 - uv.y, sprite_or_color_rect_resolution.y / opacity_edge_up);
	float o_down = pow(uv.y, sprite_or_color_rect_resolution.y / opacity_edge_down);
	float o_left = pow(1.0 - uv.x, sprite_or_color_rect_resolution.x / opacity_edge_left);
	float o_right = pow(uv.x, sprite_or_color_rect_resolution.x / opacity_edge_right);
	float opacity_edges = o_up + o_down + o_left + o_right;
	float noise_copy = noise + opacity_edges;
	float waterfall_opacity = noise_copy > opacity_strength ? 0.0 : 1.0;

	// Foam: the brightest parts of the noise, plus extra towards the edges (and the optional mask).
	float f_up = pow(1.0 - uv.y, sprite_or_color_rect_resolution.y / edge_foam_up);
	float f_down = pow(uv.y, sprite_or_color_rect_resolution.y / edge_foam_down);
	float f_left = pow(1.0 - uv.x, sprite_or_color_rect_resolution.x / edge_foam_left);
	float f_right = pow(uv.x, sprite_or_color_rect_resolution.x / edge_foam_right);
	noise += f_up + f_down + f_left + f_right;
	if (use_terrain_foam_mask) {
		noise += texture(terrain_foam_mask, uv).a;
	}

	ALBEDO = color_noise(noise, uv);
	ALPHA = waterfall_opacity;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.4;
	SPECULAR = 0.4;
}

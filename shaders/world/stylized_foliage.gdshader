shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;

// Leaves for the Stylized Nature MegaKit (free edition). Its leaf textures
// are cut-out masks only (the leaf shapes are in the alpha); the paid
// edition colours them with its own shader. This does the same job in a
// soft, painted style: leaves facing up are lighter, leaves facing down and
// the inner, shaded ones (the model's vertex colours) are darker, with
// broad patches of colour variation across the canopy.

uniform sampler2D leaf_mask : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 color_shade : source_color = vec4(0.22, 0.45, 0.15, 1.0);
uniform vec4 color_light : source_color = vec4(0.55, 0.78, 0.25, 1.0);
uniform vec4 color_variation : source_color = vec4(0.62, 0.72, 0.2, 1.0);
uniform float variation_amount : hint_range(0.0, 1.0) = 0.25;
uniform float variation_scale = 0.15;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.2;

varying vec3 world_pos;
varying float world_up;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
}

void fragment() {
	vec4 mask = texture(leaf_mask, UV);
	float light = clamp(world_up * 0.5 + 0.5, 0.0, 1.0);
	vec3 col = mix(color_shade.rgb, color_light.rgb, light);
	float patches = noise(world_pos.xz * variation_scale + world_pos.y * 0.05);
	col = mix(col, color_variation.rgb, patches * variation_amount);
	// Vertex colours hold the model's baked shading (white = open, dark =
	// inside), times any per-instance tint.
	col *= mix(vec3(0.65), vec3(1.0), COLOR.rgb);
	ALBEDO = col;
	ALPHA = mask.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
	ROUGHNESS = 0.9;
	BACKLIGHT = col * 0.35;
}

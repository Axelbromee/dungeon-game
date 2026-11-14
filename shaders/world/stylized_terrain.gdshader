shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;

// Ground for floor 1 and the guild's surroundings, matching the Stylized
// Nature pack's painted look: the per-face palette colour (vertex colour,
// or albedo_color where there is none) with soft, wrapped lighting and
// broad painterly brush variation, so the faces don't read as hard facets.

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool use_vertex_color = true;
// Strength and size (metres) of the brush-stroke variation.
uniform float paint_amount : hint_range(0.0, 0.5) = 0.12;
uniform float paint_scale = 3.5;
// How much the ground's lighting is softened toward facing up.
uniform float soften : hint_range(0.0, 1.0) = 0.35;

varying vec3 world_pos;

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
}

void fragment() {
	vec3 base = albedo_color.rgb;
	if (use_vertex_color) {
		base *= COLOR.rgb;
	}
	// Long, soft strokes (stretched noise) plus a finer layer.
	vec2 p = world_pos.xz / paint_scale;
	float strokes = noise(vec2(p.x * 0.6 + p.y * 0.3, p.y * 1.8));
	float fine = noise(p * 4.0);
	float paint = (strokes - 0.5) * 0.7 + (fine - 0.5) * 0.3;
	ALBEDO = base * (1.0 + paint * paint_amount * 2.0);
	vec3 up = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	NORMAL = normalize(mix(NORMAL, up, soften * clamp(dot(NORMAL, up), 0.0, 1.0)));
	ROUGHNESS = 1.0;
}

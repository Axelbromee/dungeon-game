shader_type spatial;
// White foam where the waterfall lands: broken rings spreading out from the
// middle (UV centre), fading at the edge (GL Compatibility friendly).
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 foam_color : source_color = vec4(0.96, 0.99, 1.0, 0.9);
// How fast the rings spread.
uniform float speed = 4.0;

void fragment() {
	vec2 c = UV - vec2(0.5);
	float r = length(c) * 2.0;
	float a = atan(c.y, c.x);
	float rings = sin(r * 14.0 - TIME * speed + sin(a * 5.0) * 1.5) * 0.5 + 0.5;
	float patches = rings * (1.0 - r) + 0.25 * sin(a * 7.0 + TIME * 2.0);
	ALBEDO = foam_color.rgb;
	ALPHA = foam_color.a * step(0.4, patches) * (1.0 - smoothstep(0.75, 1.0, r));
}

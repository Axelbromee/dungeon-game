// Additive, flickering fire shell for the fireball. Hot core colour in the
// middle fading to a red/orange rim, with a wobbling surface.
shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never;

uniform vec4 core_color : source_color = vec4(1.0, 0.85, 0.35, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.22, 0.02, 1.0);
uniform float intensity = 2.5;
uniform float wobble_amount = 0.12;
uniform float flicker_speed = 7.0;

void vertex() {
	float t = TIME * flicker_speed;
	float n = sin(VERTEX.x * 31.0 + t)
			* sin(VERTEX.y * 27.0 + t * 1.3)
			* sin(VERTEX.z * 23.0 - t * 0.8);
	VERTEX += NORMAL * n * wobble_amount * length(VERTEX);
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, 1.6);
	float flicker = 0.85 + 0.15 * sin(TIME * flicker_speed * 2.3 + UV.y * 12.0);
	vec3 col = mix(core_color.rgb, rim_color.rgb, rim);
	ALBEDO = col * intensity * flicker * (1.0 - rim * 0.5);
}

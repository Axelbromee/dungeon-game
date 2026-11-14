shader_type spatial;
// Floor 1 water: a bright painted teal like the Stylized Nature pack, with
// soft lighter streaks drifting the way the water flows (GL Compatibility
// friendly).
//
// Per vertex (set by forest_floor.gd and waterfall.gd):
//   UV.x  = across the flow (metres), UV.y = along it (metres, increasing in
//           the direction the water moves);
//   COLOR.r = how much it flows (0 = still lake / pool, 1 = moving),
//   COLOR.g = speed (x4: 0.25 = 1x),
//   COLOR.b = how white it is (falling water),
//   COLOR.a = how visible it is (hides the stream under the lake / pool).
render_mode blend_mix, cull_disabled, depth_draw_opaque;

uniform vec4 water_color : source_color = vec4(0.36, 0.72, 0.78, 0.82);
uniform vec4 streak_color : source_color = vec4(0.8, 0.94, 0.97, 0.9);
uniform vec4 white_color : source_color = vec4(0.93, 0.97, 1.0, 0.92);
// Metres per second at speed 1x.
uniform float flow_speed = 1.4;
// Larger = shorter, closer streaks.
uniform float streak_scale = 1.0;

void fragment() {
	float flow = COLOR.r;
	float phase = (UV.y - TIME * flow_speed * COLOR.g * 4.0) * streak_scale;
	float wobble = sin(UV.x * 2.3 + UV.y * 0.37) * 1.2;
	float wave = sin(phase * 1.4 + wobble) * sin(phase * 0.47 + UV.x * 0.9 + 1.7);
	// Soft-edged streaks, like brush strokes.
	float streak = smoothstep(0.3, 0.6, wave) * flow;
	vec3 color = mix(water_color.rgb, streak_color.rgb, streak * 0.75);
	color = mix(color, white_color.rgb, COLOR.b);
	ALBEDO = color;
	ALPHA = mix(mix(water_color.a, streak_color.a, streak * 0.5), white_color.a, COLOR.b) * COLOR.a;
	ROUGHNESS = 0.2;
	SPECULAR = 0.6;
}

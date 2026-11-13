shader_type spatial;
// Inverted-hull outline for item pickups lying in the world (works with the
// GL Compatibility renderer). Drawn on a copy of the mesh: only its back faces
// show, pushed outwards, so a solid rim appears around the item.
//
// The hull grows away from the mesh's centre rather than along the normals,
// so flat-shaded (hard-edged) low-poly models don't crack open at corners.
render_mode unshaded, cull_front, shadows_disabled, depth_draw_opaque;

uniform vec4 outline_color : source_color = vec4(1.0);
// Outline width in metres (world space, whatever the mesh's scale).
uniform float thickness = 0.02;
// Centre of the mesh (its own space) the hull grows away from.
uniform vec3 hull_center = vec3(0.0);

void vertex() {
	vec3 dir = VERTEX - hull_center;
	dir = length(dir) > 0.0001 ? normalize(dir) : NORMAL;
	float scale = max(length(MODEL_MATRIX[0].xyz), 0.0001);
	VERTEX += dir * thickness / scale;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}

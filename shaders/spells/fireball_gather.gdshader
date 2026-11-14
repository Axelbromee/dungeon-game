// Embers gathering for a fireball being cast: each spark starts on a ring
// around the gathering point (above the book) and spirals inward into it,
// fading in, speeding up and shrinking as it goes. Local coordinates: the
// emitter sits on the gathering point. `speed` makes them spiral in faster;
// `scatter` (0 -> 1) throws them outward and fades them (cast cancelled).
shader_type particles;

// Ring the sparks start on, and how close to the centre they end (metres).
uniform float start_radius = 0.35;
uniform float end_radius = 0.02;
// Turns each spark makes on its way in.
uniform float turns = 1.1;
// How far above / below the fireball sparks may start.
uniform float height_spread = 0.12;
uniform float spark_scale = 1.0;
// Trips per lifetime (higher = faster inward).
uniform float speed = 1.0;
// 0 = gathering, 1 = fully scattered and faded.
uniform float scatter = 0.0;
// How far outward the sparks fly when scattering (metres).
uniform float scatter_distance = 0.5;
uniform vec4 color : source_color = vec4(1.0, 0.62, 0.22, 1.0);

float hash(uint x) {
	x = ((x >> 16u) ^ x) * 0x45d9f3bu;
	x = ((x >> 16u) ^ x) * 0x45d9f3bu;
	x = (x >> 16u) ^ x;
	return float(x) / 4294967295.0;
}

void start() {
	if (RESTART_CUSTOM) {
		uint seed = NUMBER * 7919u + RANDOM_SEED;
		// x: start angle, y: start height (-1..1), z: progress 0..1, w: radius jitter.
		CUSTOM = vec4(hash(seed) * TAU, hash(seed + 1u) * 2.0 - 1.0, 0.0, 0.75 + hash(seed + 2u) * 0.5);
	}
	if (RESTART_COLOR) {
		COLOR = vec4(color.rgb, 0.0);
	}
	if (RESTART_VELOCITY) {
		VELOCITY = vec3(0.0);
	}
}

void process() {
	CUSTOM.z = min(CUSTOM.z + DELTA * speed / max(LIFETIME, 0.001), 1.0);
	float a = CUSTOM.z;
	// Slow at the edge, fast near the centre.
	float inward = a * a;
	float r = mix(start_radius * CUSTOM.w, end_radius, inward) + scatter * scatter_distance;
	float angle = CUSTOM.x + inward * turns * TAU;
	float y = CUSTOM.y * height_spread * (1.0 - inward);
	float s = spark_scale * mix(1.0, 0.4, a);
	TRANSFORM = mat4(
		vec4(s, 0.0, 0.0, 0.0),
		vec4(0.0, s, 0.0, 0.0),
		vec4(0.0, 0.0, s, 0.0),
		vec4(cos(angle) * r, y, sin(angle) * r, 1.0));
	COLOR.rgb = color.rgb * (1.0 + a);
	COLOR.a = smoothstep(0.0, 0.2, a) * (1.0 - smoothstep(0.85, 1.0, a)) * (1.0 - scatter);
	if (a >= 1.0) {
		ACTIVE = false;
	}
}

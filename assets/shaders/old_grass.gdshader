// Low-key pixel-art grass floor with straw-like patch edges.
// Patch and cloud-shadow technique adapted from Dylearn's 3D Pixel Art Grass Demo (MIT).
shader_type canvas_item;

uniform float tile_size = 16.0;

// ---- Ground -------------------------------------------------------------
uniform vec4 base_color : source_color = vec4(0.30, 0.48, 0.20, 1.0);
uniform float checker_strength : hint_range(0.0, 0.2) = 0.02;
uniform float jitter : hint_range(0.0, 0.2) = 0.03;

// Patches: bigger scale = smaller patches, higher threshold = fewer patches
uniform vec4 patch_color_1 : source_color = vec4(0.36, 0.54, 0.24, 1.0);
uniform float patch_scale_1 : hint_range(0.001, 0.1) = 0.018;
uniform float patch_threshold_1 : hint_range(0.0, 1.0) = 0.58;
uniform vec4 patch_color_2 : source_color = vec4(0.26, 0.42, 0.18, 1.0);
uniform float patch_scale_2 : hint_range(0.001, 0.1) = 0.012;
uniform float patch_threshold_2 : hint_range(0.0, 1.0) = 0.62;

// ---- Blades: the straw-like fringe where patches meet -------------------
// Each blade takes the patch colour at its own base, so blades poke over
// the patch boundary and break the smooth edge, like the demo's grass quads.
uniform float blade_density : hint_range(0.0, 1.0) = 0.7;
uniform float blade_cell : hint_range(3.0, 8.0, 1.0) = 4.0;   // spacing in pixels (smaller = denser)
uniform float blade_height : hint_range(2.0, 8.0, 1.0) = 6.0; // max height in pixels
uniform float blade_width : hint_range(1.0, 3.0, 1.0) = 2.0;  // base width in pixels
uniform float blade_lean : hint_range(0.0, 0.7) = 0.35;       // sideways tilt, lets blades cross vertical edges
uniform float blade_contrast : hint_range(0.0, 0.15) = 0.03;  // brightness variation between blades
uniform float tip_light : hint_range(0.0, 0.15) = 0.04;       // lighter blade tips

// ---- Drifting cloud shadows ---------------------------------------------
uniform float cloud_strength : hint_range(0.0, 0.5) = 0.10;
uniform float cloud_scale : hint_range(0.001, 0.05) = 0.006;
uniform float cloud_threshold : hint_range(0.0, 1.0) = 0.58;
uniform float cloud_speed = 5.0;
uniform vec2 cloud_direction = vec2(1.0, 0.35);
uniform float step_fps = 6.0;

varying vec2 world_pos;

float hash21(vec2 p) {
	uvec2 q = uvec2(ivec2(p)) * uvec2(1597334673u, 3812015801u);
	uint n = (q.x ^ q.y) * 1597334673u;
	return float(n) * (1.0 / 4294967295.0);
}

uint pcg(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

vec4 hash24(vec2 p) {
	uvec2 q = uvec2(ivec2(p));
	uint a = pcg(q.x + pcg(q.y));
	uint b = pcg(a);
	uint c = pcg(b);
	uint d = pcg(c);
	return vec4(float(a), float(b), float(c), float(d)) * (1.0 / 4294967295.0);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float patch_noise(vec2 p) {
	return 0.65 * value_noise(p) + 0.35 * value_noise(p * 2.7 + 17.0);
}

// Flat patch colour at a world-pixel position (later patches override earlier ones)
vec3 ground_color(vec2 p) {
	vec3 c = base_color.rgb;
	if (patch_noise(p * patch_scale_1 + vec2(11.0, 3.0)) > patch_threshold_1) c = patch_color_1.rgb;
	if (patch_noise(p * patch_scale_2 + vec2(-7.0, 29.0)) > patch_threshold_2) c = patch_color_2.rgb;
	return c;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 px = floor(world_pos);          // snap to whole world pixels
	vec2 tile = floor(px / tile_size);

	// Per-tile variation (chessboard + random), applied to ground and blades alike
	// so the tile pattern stays visible under the blades
	float tile_shift = (mod(tile.x + tile.y, 2.0) - 0.5) * checker_strength
			+ (hash21(tile) - 0.5) * jitter;

	// Ground: patches
	vec3 col = ground_color(px) + tile_shift;

	// Blades: check nearby jittered blade bases. A blade points up, so its base
	// is at or below this pixel. Lower-on-screen blades are in front.
	vec2 cell0 = floor(px / blade_cell);
	bool found = false;
	for (int r = 3; r >= 0; r--) {
		for (int c = -2; c <= 2; c++) {
			if (!found) {
				vec2 cell = cell0 + vec2(float(c), float(r));
				vec4 h = hash24(cell);
				vec2 o = floor(cell * blade_cell + h.xy * blade_cell);   // blade base pixel
				float height = floor(blade_height * (0.5 + 0.5 * h.z) + 0.5);
				float dy = o.y - px.y;                                   // pixels above the base
				if (dy >= 0.0 && dy <= height && hash21(cell + vec2(57.0, 13.0)) <= blade_density) {
					float t = dy / max(height, 1.0);                     // 0 at base, 1 at tip
					float lean = (h.w - 0.5) * 2.0 * blade_lean;
					float cx = floor(o.x + lean * dy + 0.5);
					float w = floor(mix(blade_width, 1.0, t) + 0.5);     // tapers to a 1px tip
					float dx = px.x - cx;
					if (dx >= -floor(w * 0.5) && dx <= floor((w - 1.0) * 0.5)) {
						found = true;
						vec3 bc = ground_color(o) + tile_shift;          // colour of the patch it grows in
						bc += (h.z - 0.5) * 2.0 * blade_contrast;
						bc += tip_light * step(0.7, t);
						col = bc;
					}
				}
			}
		}
	}

	// Cloud shadows: two noises drifting in slightly different directions,
	// time-stepped so the edges advance in pixel-sized ticks
	float ts = floor(TIME * step_fps) / step_fps;
	vec2 dir1 = normalize(cloud_direction);
	vec2 dir2 = vec2(dir1.x * 0.985 - dir1.y * 0.174, dir1.x * 0.174 + dir1.y * 0.985);
	float c1 = patch_noise((px - dir1 * ts * cloud_speed) * cloud_scale);
	float c2 = patch_noise((px * 0.8 - dir2 * ts * cloud_speed * 0.89) * cloud_scale + vec2(41.0, 5.0));
	float shade = step(cloud_threshold, (c1 + c2) * 0.5);
	col *= 1.0 - shade * cloud_strength;

	COLOR.rgb *= col;
}
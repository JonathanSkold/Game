shader_type canvas_item;

// Logical tile size in world pixels.
uniform float tile_size : hint_range(1.0, 64.0) = 16.0;

// Grass palette.
uniform vec4 grass_dark : source_color = vec4(0.26, 0.42, 0.18, 1.0);
uniform vec4 grass_light : source_color = vec4(0.36, 0.54, 0.24, 1.0);

// Larger values produce smaller groups of similarly colored tiles.
uniform float region_scale : hint_range(0.05, 1.0) = 0.3;

// Independent variation between neighboring tiles.
// Zero gives only the broader regional variation.
uniform float tile_variation : hint_range(0.0, 0.5) = 0.15;

// Maximum border displacement along each axis, in world pixels.
uniform float border_amount : hint_range(0.0, 4.0) = 2.0;

// Approximate size of the bends in the borders, in world pixels.
uniform float border_size : hint_range(2.0, 24.0) = 6.0;

// Frequent blades at boundaries, sparse blades inside regions.
uniform float edge_blade_density : hint_range(0.0, 1.0) = 0.9;
uniform float interior_blade_density : hint_range(0.0, 1.0) = 0.12;

// Brightness variation of individual blades.
uniform float blade_contrast : hint_range(0.0, 0.1) = 0.025;

// 0 = current natural variation, 1 = full checkerboard.
uniform float checker_blend : hint_range(0.0, 1.0) = 0.3;

// Larger values create smaller groups of checker-influenced tiles.
uniform float checker_scale : hint_range(0.05, 1.0) = 0.8;

// Higher values make the checker pattern appear less often.
uniform float checker_threshold : hint_range(0.0, 1.0) = 0.4;

varying vec2 world_pos;


uint pcg(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state)
			* 277803737u;
	return (word >> 22u) ^ word;
}


float hash21(vec2 p) {
	uvec2 q = uvec2(ivec2(p));
	uint n = pcg(q.x + pcg(q.y));
	return float(n) * (1.0 / 4294967295.0);
}


float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);

	// Smooth interpolation between neighboring noise samples.
	vec2 blend = local * local * (3.0 - 2.0 * local);

	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));

	return mix(
		mix(a, b, blend.x),
		mix(c, d, blend.x),
		blend.y
	);
}


vec2 get_border_offset(vec2 pixel) {
	vec2 sample_pos = pixel / border_size;

	// Separate noise samples avoid identical X and Y offsets.
	vec2 noise = vec2(
		value_noise(sample_pos + vec2(17.0, 43.0)),
		value_noise(sample_pos + vec2(-31.0, 11.0))
	);

	// Convert 0..1 noise into -border_amount..border_amount.
	return (noise * 2.0 - 1.0) * border_amount;
}


vec3 get_tile_color(vec2 tile) {
	// Sample using the tile coordinate, not the pixel coordinate.
	// Every pixel assigned to this tile gets the same color.
	float regional_shade = value_noise(
		(tile + vec2(0.5)) * region_scale + vec2(8.0, 29.0)
	);

	float individual_shade =
		(hash21(tile + vec2(71.0, -19.0)) - 0.5)
		* 2.0 * tile_variation;

	float shade = clamp(
		regional_shade + individual_shade,
		0.0,
		1.0
	);
	
	// Sample once per tile, so this doesn't introduce patches inside tiles.
	float checker_noise = value_noise(
		(tile + vec2(0.5)) * checker_scale + vec2(137.0, -53.0)
	);

	// Fade between natural areas and checker-influenced areas.
	float checker_mask = smoothstep(
		checker_threshold,
		checker_threshold + 0.2,
		checker_noise
	);

	float checker = mod(tile.x + tile.y, 2.0);
	shade = mix(shade, checker, checker_blend * checker_mask);
	
	return mix(grass_dark.rgb, grass_light.rgb, shade);
}

vec2 get_grass_tile(vec2 pixel) {
	return floor(
		(pixel + get_border_offset(pixel)) / tile_size
	);
}


vec3 add_grass_blades(vec2 pixel, vec3 ground) {
	// One potential blade base per 4 × 4 world-pixel cell.
	const float spacing = 4.0;
	vec2 local_cell = floor(pixel / spacing);

	// Check bases below this pixel because blades grow upward.
	// Lower bases take priority when blades overlap.
	for (int row = 2; row >= 0; row--) {
		for (int column = -1; column <= 1; column++) {
			vec2 cell = local_cell
				+ vec2(float(column), float(row));

			vec2 scatter = vec2(
				hash21(cell + vec2(13.0, 37.0)),
				hash21(cell + vec2(53.0, 19.0))
			);

			vec2 base = floor(cell * spacing + scatter * spacing)
				+ vec2(0.5);

			// Between 2 and 5 pixels tall.
			float height = 2.0 + floor(
				hash21(cell + vec2(79.0, 7.0)) * 3.999
			);

			// Tip can lean up to two pixels sideways.
			float lean = floor(
				hash21(cell + vec2(31.0, 61.0)) * 4.999
			) - 2.0;

			float rise = base.y - pixel.y;

			if (rise < 0.0 || rise > height) {
				continue;
			}

			float progress = rise / height;
			float center_x = base.x + floor(lean * progress + 0.5);

			// Two pixels wide at the base, one near the tip.
			float width = mix(1.0, 0.0, step(0.45, progress));
			float offset_x = pixel.x - center_x;

			if (offset_x < -width || offset_x > 0.0) {
				continue;
			}

			vec2 tip = base + vec2(lean, -height);
			vec3 base_color = get_tile_color(get_grass_tile(base));
			vec3 tip_color = get_tile_color(get_grass_tile(tip));

			// Compare colors, so visually merged tiles don't create
			// unnecessary dense fringes at invisible boundaries.
			float difference = length(base_color - tip_color);
			float edge_weight = smoothstep(0.005, 0.04, difference);

			float density = mix(
				interior_blade_density,
				edge_blade_density,
				edge_weight
			);

			if (hash21(cell + vec2(97.0, 41.0)) >= density) {
				continue;
			}

			float variation = (
				hash21(cell + vec2(23.0, 89.0)) * 2.0 - 1.0
			) * blade_contrast;

			// Each blade carries its base region's color across
			// the boundary, with a small individual variation.
			return clamp(
				base_color + vec3(variation),
				vec3(0.0),
				vec3(1.0)
			);
		}
	}

	return ground;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}


void fragment() {
	vec2 pixel = floor(world_pos) + vec2(0.5);

	vec3 grass = get_tile_color(get_grass_tile(pixel));
	grass = add_grass_blades(pixel, grass);

	COLOR.rgb *= grass;
}
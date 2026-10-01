shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.05, 0.07, 0.04, 1.0);

// Each sprite supplies its own atlas rectangle in pixels:
// x, y, width, height.
instance uniform vec4 atlas_region = vec4(0.0, 0.0, 16.0, 16.0);

varying vec2 sprite_pixel;
varying vec4 sprite_tint;


void vertex() {
	// This matches your current Sprite setup:
	// centered = false, offset = zero, no flipping.
	vec2 size = atlas_region.zw;
	vec2 corner = VERTEX / size;

	// Expand the drawing rectangle by one pixel on every side.
	// The original artwork keeps its original size and position.
	VERTEX += corner * 2.0 - 1.0;

	sprite_pixel = VERTEX;
	sprite_tint = COLOR;
}


vec4 sample_sprite(sampler2D atlas, vec2 pixel) {
	// Treat everything outside this sprite's region as transparent.
	// Never read artwork belonging to a neighboring atlas region.
	if (
		pixel.x < 0.0 ||
		pixel.y < 0.0 ||
		pixel.x >= atlas_region.z ||
		pixel.y >= atlas_region.w
	) {
		return vec4(0.0);
	}

	// Sample the center of the requested texture pixel.
	vec2 atlas_pixel = atlas_region.xy + floor(pixel) + vec2(0.5);
	vec2 atlas_size = vec2(textureSize(atlas, 0));

	return texture(atlas, atlas_pixel / atlas_size);
}


void fragment() {
	vec4 source = sample_sprite(TEXTURE, sprite_pixel);

	float neighbor_alpha = 0.0;

	// Check all eight neighboring pixels.
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			if (x == 0 && y == 0) {
				continue;
			}

			vec2 offset = vec2(float(x), float(y));
			float alpha = sample_sprite(
				TEXTURE,
				sprite_pixel + offset
			).a;

			neighbor_alpha = max(neighbor_alpha, alpha);
		}
	}

	// Draw the outline behind the original artwork.
	float outline_alpha = neighbor_alpha * outline_color.a;
	float behind_alpha = outline_alpha * (1.0 - source.a);
	float combined_alpha = source.a + behind_alpha;

	vec3 combined_rgb = (
		source.rgb * sprite_tint.rgb * source.a
		+ outline_color.rgb * behind_alpha
	) / max(combined_alpha, 0.00001);

	COLOR = vec4(
		combined_rgb,
		combined_alpha * sprite_tint.a
	);
}
shader_type canvas_item;

uniform vec2 resolution = vec2(600.0, 400.0);
uniform vec3 spiral_color: source_color = vec3(0.2, 0.6, 0.3);
uniform float frequency: hint_range(1.0, 10.0, 0.1) = 8.0;
uniform float speed: hint_range(0.0, 20.0, 0.1) = 8.0;
uniform float brightness: hint_range(1.0, 10.0, 0.1) = 5.0;
uniform float balance: hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float octaves: hint_range(1.0, 10.0, 1.0) = 4.0;
uniform float pixel_size: hint_range(1.0, 1000.0) = 8.0;
uniform float time_offset: hint_range(0.0, 100.0) = 50.0;
uniform float dither_strength: hint_range(0.0, 1.0) = 0.5;
uniform float dither_pixel_size: hint_range(1.0, 32.0) = 4.0;
uniform float dither_levels: hint_range(2.0, 16.0, 1.0) = 6.0;
uniform float dither_brightness: hint_range(0.0, 4.0) = 1.0;

float bayer4x4(vec2 pos) {
	int x = int(mod(pos.x, 4.0));
	int y = int(mod(pos.y, 4.0));
	int index = x + y * 4;
	float matrix[16] = float[16](
		 0.0,  8.0,  2.0, 10.0,
		12.0,  4.0, 14.0,  6.0,
		 3.0, 11.0,  1.0,  9.0,
		15.0,  7.0, 13.0,  5.0
	);
	return matrix[index] / 16.0;
}

float draw_spiral(vec2 uv, float rotation) {
	float uv_radius = length(uv);
	float uv_phi = atan(uv.y, uv.x) + rotation;
	float spiral_phi = (log(uv_radius) * frequency - uv_phi) / TAU;
	float spiral_ceil_radius = exp((TAU * ceil(spiral_phi) + uv_phi) / frequency);
	float spiral_floor_radius = exp((TAU * floor(spiral_phi) + uv_phi) / frequency);
	return mix(mix(abs(uv_radius - spiral_ceil_radius), abs(uv_radius - spiral_floor_radius), balance), max(abs(uv_radius - spiral_ceil_radius), abs(uv_radius - spiral_floor_radius)), balance);
}

void fragment() {
	vec2 pixelated_uv = floor(UV * pixel_size) / pixel_size;
	vec2 uv = pixelated_uv - 0.5;
	uv.x *= resolution.x / resolution.y;
	float spiral = 0.0;
	for (float i = 0.0; i < octaves; i += 1.0) {
		spiral += draw_spiral(uv, (TIME + time_offset) * speed * (0.5 + sin(i)));
	}
	spiral /= octaves;
	
	// Dithering
	vec2 screen_pos = floor(FRAGCOORD.xy / dither_pixel_size);
	float threshold = bayer4x4(screen_pos);
	float level_size = 1.0 / dither_levels;
	float lower = floor(spiral * dither_levels) * level_size;
	float upper = lower + level_size;
	float frac = (spiral - lower) / level_size;
	float dithered = (threshold < frac) ? upper : lower;
	float effective_strength = dither_strength * clamp(spiral * dither_levels, 0.0, 1.0);
	spiral = mix(spiral, dithered * dither_brightness, effective_strength);
	
	
	vec3 color = spiral * spiral_color;
	COLOR = vec4(color * brightness, 1.0);
}
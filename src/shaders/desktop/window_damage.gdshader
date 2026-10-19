shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float damage : hint_range(0.0, 1.0) = 0.0;
uniform vec2 window_size = vec2(900.0, 620.0);
uniform float cell_size : hint_range(60.0, 300.0) = 150.0;
uniform float crack_width : hint_range(0.5, 4.0) = 1.4;
uniform float refraction_pixels : hint_range(0.0, 12.0) = 5.0;
uniform float seed = 17.0;

// 为每个玻璃分区生成稳定种子。输入: 分区坐标。输出: 二维随机值。
vec2 cell_random(vec2 point) {
	return fract(sin(vec2(dot(point, vec2(127.1, 311.7)), dot(point, vec2(269.5, 183.3))) + seed) * 43758.5453);
}

// 在完整窗口画面上绘制裂缝和细微折射。输入: 实时屏幕纹理。输出: 破损后的窗口像素。
void fragment() {
	vec2 point = UV * window_size / cell_size;
	vec2 cell = floor(point);
	float nearest = 100.0;
	float second = 100.0;
	vec2 nearest_cell = cell;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 candidate = cell + vec2(float(x), float(y));
			float distance_to_site = length(candidate + 0.2 + cell_random(candidate) * 0.6 - point);
			if (distance_to_site < nearest) {
				second = nearest;
				nearest = distance_to_site;
				nearest_cell = candidate;
			} else {
				second = min(second, distance_to_site);
			}
		}
	}
	float edge = second - nearest;
	float width = crack_width / cell_size;
	float crack = 1.0 - smoothstep(width * 0.2, width * 1.7, edge);
	float rim = 1.0 - smoothstep(width * 1.7, width * 3.5, edge);
	vec2 screen_extent = vec2(dFdx(SCREEN_UV.x) / dFdx(UV.x), dFdy(SCREEN_UV.y) / dFdy(UV.y));
	vec2 screen_min = SCREEN_UV - UV * screen_extent + SCREEN_PIXEL_SIZE * 0.5;
	vec2 screen_max = screen_min + screen_extent - SCREEN_PIXEL_SIZE;
	vec2 displacement = (cell_random(nearest_cell) - 0.5) * refraction_pixels * damage * SCREEN_PIXEL_SIZE;
	vec4 source = textureLod(screen_texture, clamp(SCREEN_UV + displacement, screen_min, screen_max), 0.0);
	source.rgb = mix(source.rgb, vec3(0.94, 0.98, 1.0), rim * damage * 0.55);
	source.rgb = mix(source.rgb, vec3(0.04, 0.06, 0.09), crack * damage * 0.95);
	COLOR = source;
}

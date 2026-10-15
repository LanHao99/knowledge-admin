shader_type canvas_item;
render_mode unshaded;

uniform vec4 accent_color : source_color = vec4(0.12, 0.72, 0.8, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.34, 0.24, 0.72, 1.0);
uniform float animation_speed : hint_range(0.0, 2.0) = 0.55;

// 生成稳定的二维星点种子。输入: 网格坐标。输出: 0 到 1 的伪随机值。
float cell_random(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

// 绘制按屏幕比例校正的雾光、网格与扫描光。输入: UV。输出: 不透明背景颜色。
void fragment() {
	vec2 point = UV - 0.5;
	point.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float clock = TIME * animation_speed;
	vec3 shade = vec3(0.012, 0.022, 0.041);
	float halo = exp(-3.8 * length(point * vec2(0.9, 1.3)));
	shade += accent_color.rgb * halo * 0.095;
	vec2 cloud = point - vec2(0.48, -0.18);
	shade += secondary_color.rgb * exp(-5.5 * dot(cloud, cloud)) * 0.05;

	vec2 grid_uv = point * 36.0;
	vec2 grid_width = max(fwidth(grid_uv), vec2(0.0001));
	vec2 grid_distance = abs(fract(grid_uv - 0.5) - 0.5) / grid_width;
	float grid = 1.0 - smoothstep(0.0, 0.8, min(grid_distance.x, grid_distance.y));
	shade += accent_color.rgb * grid * halo * 0.055;

	vec2 star_uv = point * 64.0;
	vec2 cell = floor(star_uv);
	float seed = cell_random(cell);
	vec2 star_position = vec2(cell_random(cell + 2.7), cell_random(cell + 9.2));
	float star_distance = length(fract(star_uv) - star_position);
	float star = (1.0 - smoothstep(0.015, 0.075, star_distance)) * step(0.985, seed);
	shade += vec3(0.44, 0.8, 0.88) * star * (0.35 + 0.15 * sin(clock + seed * TAU));

	float sweep_y = fract(clock * 0.13) * 1.5 - 0.25;
	float sweep = exp(-abs(UV.y - sweep_y) * 110.0);
	shade += accent_color.rgb * sweep * halo * 0.1;
	float horizon = exp(-abs(point.y - 0.28) * 170.0) * exp(-point.x * point.x * 3.0);
	shade += accent_color.rgb * horizon * 0.045;
	float vignette = 1.0 - smoothstep(0.22, 1.1, length(point * vec2(0.7, 1.0)));
	COLOR = vec4(shade * mix(0.45, 1.0, vignette), 1.0);
}

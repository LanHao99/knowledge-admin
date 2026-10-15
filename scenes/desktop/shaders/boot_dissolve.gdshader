shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float edge_roughness : hint_range(0.0, 0.4) = 0.12;
uniform float noise_scale : hint_range(1.0, 16.0) = 6.0;
uniform float edge_width : hint_range(0.001, 0.08) = 0.012;
uniform vec4 edge_color : source_color = vec4(0.38, 0.78, 0.98, 1.0);

// 生成稳定的二维噪声种子。输入: 网格坐标。输出: 0 到 1 的伪随机值。
float random_value(vec2 point) {
	vec3 seed = fract(vec3(point.xyx) * 0.1031);
	seed += dot(seed, seed.yzx + 33.33);
	return fract((seed.x + seed.y) * seed.z);
}

// 计算连续平滑噪声，使溶解边界自然起伏。输入: 坐标。输出: 0 到 1 的噪声。
float smooth_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 part = fract(point);
	vec2 blend = part * part * (3.0 - 2.0 * part);
	return mix(mix(random_value(cell), random_value(cell + vec2(1.0, 0.0)), blend.x),
		mix(random_value(cell + vec2(0.0, 1.0)), random_value(cell + vec2(1.0, 1.0)), blend.x), blend.y);
}

// 对文字与背景的合成结果统一开孔，保留未溶解部分并照亮边缘。输入: 合成屏幕纹理、进度。输出: 封面透明度。
void fragment() {
	vec4 cover = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (cover.a > 0.0001) {
		cover.rgb /= cover.a;
	}
	vec2 point = SCREEN_UV - 0.5;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	point.x *= aspect;
	float radial_distance = length(point) / length(vec2(aspect * 0.5, 0.5));
	float noise_value = smooth_noise(point * noise_scale) * 0.65 + smooth_noise(point * noise_scale * 2.1) * 0.35;
	float field = radial_distance + (noise_value - 0.5) * edge_roughness;
	float threshold = mix(-edge_roughness - edge_width, 1.0 + edge_roughness + edge_width, progress);
	float opacity = smoothstep(threshold - edge_width, threshold + edge_width, field);
	float rim = exp(-abs(field - threshold) / max(edge_width, 0.001)) * opacity;
	if (progress <= 0.0) {
		opacity = 1.0;
		rim = 0.0;
	} else if (progress >= 1.0) {
		opacity = 0.0;
		rim = 0.0;
	}
	cover.rgb = mix(cover.rgb, edge_color.rgb, rim * 0.55);
	COLOR *= vec4(cover.rgb, cover.a * opacity);
}

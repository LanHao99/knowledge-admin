shader_type canvas_item;
render_mode unshaded;

uniform vec4 base_color : source_color = vec4(0.045, 0.055, 0.17, 1.0);
uniform vec4 accent_color : source_color = vec4(0.08, 0.55, 0.64, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.36, 0.2, 0.66, 1.0);
uniform float animation_speed : hint_range(0.0, 2.0) = 0.4;
uniform float wave_scale : hint_range(1.0, 10.0) = 4.5;
uniform float distortion_strength : hint_range(0.0, 3.0) = 1.25;

// 旋转液态场坐标。输入: 坐标与弧度。输出: 旋转后的二维坐标。
vec2 rotate_point(vec2 point, float angle) {
	return mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * point;
}

// 以连续坐标扭曲形成全屏流动色带。输入: UV 与时间。输出: 不透明波浪封面。
void fragment() {
	vec2 point = UV - 0.5;
	point.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float clock = TIME * animation_speed;
	point = rotate_point(point, 0.35 * sin(clock * 0.23));
	float swirl = 1.2 * exp(-length(point) * 1.5);
	point = rotate_point(point, swirl + clock * 0.12);
	for (int index = 0; index < 4; index++) {
		float octave = float(index) + 1.0;
		vec2 flow = vec2(sin(point.y * 3.0 + clock + octave * 1.7), cos(point.x * 3.5 - clock * 0.8 + octave));
		point += flow * distortion_strength * 0.22 / octave;
	}
	float phase = (point.x + point.y * 0.65) * wave_scale + sin(point.y * 3.2 - clock * 0.7) * 1.3;
	float bands = sin(phase * 2.0 + clock * 0.55);
	float ribbon = smoothstep(-0.7, 0.65, bands);
	vec3 shade = mix(base_color.rgb, accent_color.rgb, ribbon * 0.8);
	float purple_band = smoothstep(-0.15, 0.85, sin(phase * 1.3 - clock * 0.35 + 1.5));
	shade = mix(shade, secondary_color.rgb, purple_band * 0.68);
	float fine_wave = sin(phase * 2.0 + clock * 0.55 + 0.35);
	float vein = exp(-abs(fine_wave - 0.2) * 22.0);
	shade += mix(accent_color.rgb, vec3(0.3, 0.42, 0.7), purple_band) * vein * 0.16;
	float vignette = 1.0 - smoothstep(0.2, 1.3, length(UV - 0.5));
	shade *= mix(0.65, 1.0, vignette);
	COLOR = vec4(shade, 1.0);
}

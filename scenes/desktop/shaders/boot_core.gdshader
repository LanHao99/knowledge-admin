shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 accent_color : source_color = vec4(0.22, 0.95, 0.88, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.46, 0.4, 1.0, 1.0);
uniform float animation_speed : hint_range(0.0, 2.0) = 0.7;
uniform float glow_strength : hint_range(0.0, 2.0) = 1.0;

// 旋转二维坐标。输入: 坐标与弧度。输出: 旋转后的坐标。
vec2 turn(vec2 point, float angle) {
	float sine = sin(angle);
	float cosine = cos(angle);
	return mat2(vec2(cosine, sine), vec2(-sine, cosine)) * point;
}

// 计算带柔和光晕的细线。输入: 距离、半宽。输出: 线条及其衰减光晕。
float light_line(float distance_to_line, float width) {
	float distance_abs = abs(distance_to_line);
	return exp(-distance_abs / width) + exp(-distance_abs / (width * 5.0)) * 0.15;
}

// 绘制玻璃核心、旋转弧线、倾斜轨道和光点。输入: 方形控件 UV。输出: 叠加发光颜色。
void fragment() {
	vec2 point = UV - 0.5;
	float radius = length(point);
	float angle = atan(point.y, point.x);
	float clock = TIME * animation_speed;
	float pixel = max(fwidth(radius), 0.001);
	vec3 light = accent_color.rgb * exp(-radius * radius * 24.0) * 0.065;

	float shell = 1.0 - smoothstep(0.197, 0.197 + pixel * 2.0, radius);
	float depth = sqrt(max(0.0, 1.0 - pow(radius / 0.2, 2.0)));
	float edge_light = pow(1.0 - depth, 3.0);
	light += mix(secondary_color.rgb, accent_color.rgb, point.x * 2.0 + 0.5) * shell * (0.035 + edge_light * 0.16);
	light += accent_color.rgb * light_line(radius - 0.2, 0.0015) * (0.28 + 0.22 * sin(angle - clock));

	vec2 surface = point * vec2(1.0, 1.8);
	float wave = sin(surface.x * 32.0 + clock * 1.5) * 0.016;
	float filament = light_line(surface.y - wave, 0.0018);
	filament += light_line(surface.y - wave - 0.065, 0.0012) * 0.5;
	filament += light_line(surface.y - wave + 0.065, 0.0012) * 0.5;
	light += accent_color.rgb * filament * shell * (0.15 + depth * 0.25);

	float outer_ring = light_line(radius - 0.352, 0.0012);
	float ticks = pow(max(0.0, cos(angle * 64.0)), 18.0);
	float tick_band = smoothstep(0.36, 0.365, radius) * (1.0 - smoothstep(0.379, 0.384, radius));
	light += accent_color.rgb * (outer_ring * 0.16 + ticks * tick_band * 0.3);

	float arc_phase = fract((angle + clock * 1.3) / TAU);
	float arc = smoothstep(0.05, 0.45, arc_phase) * (1.0 - smoothstep(0.72, 0.76, arc_phase));
	light += accent_color.rgb * light_line(radius - 0.29, 0.0022) * arc * 0.9;
	float reverse_phase = fract((angle - clock * 0.9) / TAU + 0.5);
	float reverse_arc = smoothstep(0.3, 0.6, reverse_phase) * (1.0 - smoothstep(0.8, 0.84, reverse_phase));
	light += secondary_color.rgb * light_line(radius - 0.315, 0.0018) * reverse_arc * 0.85;

	vec2 orbit = turn(point, -0.55);
	float orbit_radius = length(orbit / vec2(1.0, 0.42));
	light += accent_color.rgb * light_line(orbit_radius - 0.42, 0.002) * 0.45;
	vec2 satellite = turn(vec2(cos(clock * 1.6), sin(clock * 1.6) * 0.42) * 0.42, 0.55);
	float satellite_distance = length(point - satellite);
	light += vec3(0.7, 1.0, 1.0) * exp(-satellite_distance * 360.0);
	light += accent_color.rgb * exp(-satellite_distance * 75.0) * 0.45;

	vec2 second_orbit = turn(point, 0.65);
	float second_radius = length(second_orbit / vec2(1.0, 0.55));
	light += secondary_color.rgb * light_line(second_radius - 0.395, 0.0015) * 0.3;
	float core_cross = light_line(point.x, 0.001) * light_line(point.y, 0.012);
	light += vec3(0.65, 1.0, 0.97) * core_cross * 0.3;
	float edge_fade = 1.0 - smoothstep(0.45, 0.5, radius);
	COLOR = vec4(light * glow_strength * edge_fade, COLOR.a);
}

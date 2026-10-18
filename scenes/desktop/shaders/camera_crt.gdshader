// CRT warp, scanlines and RGB grille adapted from the CC0 shader:
// https://godotshaders.com/shader/vhs-and-crt-monitor-effect/
// Local reference: public-demo/13#crt_effect/CRT.gdshader.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D portrait_texture : source_color, filter_linear, repeat_disable;
uniform bool has_portrait = false;
uniform float portrait_aspect = 1.0;
uniform float feed_aspect = 1.0;
uniform float portrait_zoom = 1.0;
uniform vec2 portrait_offset = vec2(0.0);
uniform bool portrait_flip_h = false;
uniform vec4 background_color : source_color = vec4(0.063, 0.145, 0.129, 1.0);

uniform bool crt_enabled = true;
uniform vec2 resolution = vec2(320.0, 240.0);
uniform bool pixelate = false;
uniform float scanlines_opacity : hint_range(0.0, 1.0) = 0.22;
uniform float grille_opacity : hint_range(0.0, 1.0) = 0.06;
uniform float warp_amount : hint_range(0.0, 5.0) = 0.6;
uniform float aberration : hint_range(0.0, 0.1) = 0.008;
uniform float brightness : hint_range(0.0, 2.0) = 1.18;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.35;
uniform float static_noise_intensity : hint_range(0.0, 1.0) = 0.035;
uniform bool roll = true;
uniform float roll_speed = 2.0;
uniform float distort_intensity : hint_range(0.0, 0.2) = 0.008;

// 保持图片比例并将透明像素合成到摄像头背景。输入: 局部 UV。输出: 不透明 RGB。
vec3 sample_feed(vec2 uv) {
	vec3 result = background_color.rgb;
	if (has_portrait) {
		vec2 fit = vec2(min(1.0, portrait_aspect / feed_aspect), min(1.0, feed_aspect / portrait_aspect));
		vec2 image_uv = (uv - vec2(0.5) - portrait_offset) / (fit * portrait_zoom) + vec2(0.5);
		if (portrait_flip_h) {
			image_uv.x = 1.0 - image_uv.x;
		}
		if (all(greaterThanEqual(image_uv, vec2(0.0))) && all(lessThanEqual(image_uv, vec2(1.0)))) {
			vec4 portrait = texture(portrait_texture, image_uv);
			result = mix(result, portrait.rgb, portrait.a);
		}
	}
	return result;
}

// 模拟球面玻璃的边缘弯曲。输入: 局部 UV。输出: 弯曲后的 UV。
vec2 warp(vec2 uv) {
	vec2 delta = uv - vec2(0.5);
	float radius_squared = dot(delta, delta);
	return uv + delta * radius_squared * radius_squared * warp_amount;
}

// 在扭曲后画面边缘形成圆角黑框。输入: 局部 UV。输出: 边缘遮罩。
float border(vec2 uv) {
	float radius = max(min(warp_amount, 0.08), 0.00001);
	vec2 edge = abs(uv * 2.0 - vec2(1.0)) - vec2(1.0) + vec2(radius);
	float distance_to_edge = length(max(vec2(0.0), edge)) / radius;
	return 1.0 - smoothstep(0.96, 1.0, distance_to_edge);
}

// 生成随时间变化的细颗粒。输入: 采样位置。输出: 0 到 1 的噪声。
float signal_noise(vec2 uv) {
	return fract(sin(dot(uv, vec2(127.1, 311.7))) * 43758.5453);
}

// 在单个 ColorRect 内合成立绘与 CRT，不读取桌面屏幕。输入: UV。输出: 不透明画面。
void fragment() {
	vec2 uv = crt_enabled ? warp(UV) : UV;
	vec2 sample_uv = uv;
	if (crt_enabled && pixelate) {
		sample_uv = (floor(uv * resolution) + vec2(0.5)) / resolution;
	}
	if (crt_enabled && roll) {
		float roll_line = smoothstep(0.3, 0.9, sin(uv.y * 15.0 - TIME * roll_speed));
		roll_line *= roll_line * smoothstep(0.3, 0.9, sin(uv.y * 27.0 - TIME * roll_speed * 1.8));
		sample_uv.x += roll_line * distort_intensity * (1.0 - UV.x);
	}
	vec3 result = sample_feed(sample_uv);
	if (crt_enabled) {
		result.r = sample_feed(sample_uv + vec2(aberration * 0.1, 0.0)).r;
		result.g = sample_feed(sample_uv - vec2(aberration * 0.1, 0.0)).g;
		vec3 grille = smoothstep(vec3(0.85), vec3(0.95), abs(sin(vec3(uv.x * resolution.x * 3.14159265) + vec3(0.0, 1.05, 2.1))));
		result *= mix(vec3(1.0), grille, grille_opacity) * brightness;
		float scanline = smoothstep(0.25, 0.75, abs(sin(uv.y * resolution.y * 3.14159265)));
		result *= mix(1.0, scanline, scanlines_opacity);
		result += (signal_noise(floor(uv * resolution) + fract(TIME)) - 0.5) * static_noise_intensity;
		vec2 vignette_uv = clamp(uv, vec2(0.0), vec2(1.0));
		vignette_uv *= vec2(1.0) - vignette_uv;
		float vignette = pow(max(vignette_uv.x * vignette_uv.y * 16.0, 0.00001), 0.4);
		result *= mix(1.0, vignette, vignette_opacity) * border(uv);
	}
	COLOR = vec4(clamp(result, vec3(0.0), vec3(1.0)), 1.0);
}

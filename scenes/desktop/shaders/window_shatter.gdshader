shader_type canvas_item;
render_mode unshaded;

uniform float progress = 0.0;
uniform vec2 source_size = vec2(900.0, 620.0);
uniform float gravity = 1800.0;
uniform float horizontal_speed = 190.0;
uniform float initial_lift = 130.0;
uniform float spin_speed = 3.0;

// 按碎片中心旋转并计算重力位移，UV 保留原窗口内容。输入: 原始顶点与分区元数据。输出: 运动后的顶点。
void vertex() {
	vec2 center = COLOR.rg * source_size;
	float shard_seed = COLOR.b;
	float angle = (shard_seed * 2.0 - 1.0) * spin_speed * progress;
	vec2 relative = VERTEX - center;
	vec2 rotated = vec2(cos(angle) * relative.x - sin(angle) * relative.y, sin(angle) * relative.x + cos(angle) * relative.y);
	vec2 velocity = vec2((fract(shard_seed * 7.13) * 2.0 - 1.0) * horizontal_speed, -initial_lift * (0.4 + 0.6 * shard_seed));
	VERTEX = center + rotated + velocity * progress + vec2(0.0, 0.5 * gravity * progress * progress);
	COLOR = vec4(1.0);
}

// 从固定快照采样，让文字、按钮和边框与碎片共同旋转。输入: 原始 UV。输出: 快照像素。
void fragment() {
	COLOR = texture(TEXTURE, UV);
}

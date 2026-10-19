class_name WindowImpact
extends RefCounted
## 为实时窗口和已销毁应用的快照提供相同的衰减冲击波形。


## 计算快速往返且逐渐归零的整窗偏移。## 输入: 秒数、震幅、时长和频率。输出: 逻辑像素偏移。
static func sample_offset(seconds: float, amplitude: float, duration: float, frequency: float) -> Vector2:
	if seconds <= 0.0 or duration <= 0.0 or seconds >= duration or amplitude <= 0.0:
		return Vector2.ZERO
	var phase: float = seconds * frequency * TAU
	var envelope: float = pow(1.0 - seconds / duration, 2.0)
	return (Vector2(sin(phase), sin(phase * 1.73) * 0.55) * amplitude * envelope).round()

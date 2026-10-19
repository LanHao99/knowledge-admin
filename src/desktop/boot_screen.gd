extends Control
## 启动入口，将一次性封面交给独立画布后准备桌面。

@export_range(0.1, 10.0, 0.1, "suffix:s") var boot_duration: float = 3.0
@export_range(0.1, 5.0, 0.1, "suffix:s") var dissolve_duration: float = 1.4
@export_range(0.1, 2.0, 0.1, "suffix:s") var accelerated_duration: float = 0.6


## 延迟交接，保证主场景及封面均已进入场景树。## 输入: 无。输出: 无。
func _ready() -> void:
	_start_transition.call_deferred()


## 保留封面，使标准场景切换只释放启动入口。## 输入: 无。输出: 无。
func _start_transition() -> void:
	var transition: CanvasLayer = $BootTransition
	transition.reparent(get_tree().root)
	transition.start(boot_duration, dissolve_duration, accelerated_duration)

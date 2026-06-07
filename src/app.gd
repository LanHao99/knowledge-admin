# App.gd（Autoload 单例）
extends Node


## 退出应用程序（由剧情/教程触发）。包含短暂延迟让玩家看到最后的信息。## 输入: 无。
## 输出: 无（不会返回）。
func quit_app() -> void:
	await get_tree().create_timer(1.5).timeout
	get_tree().quit(0)

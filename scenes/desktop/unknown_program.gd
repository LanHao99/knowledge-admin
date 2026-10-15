extends Control
## 隐藏剧情程序，正文和待机页共用同一个窗口实例。

## 初始化为后台待机页。## 输入: 无。输出: 无。
func _ready() -> void:
	end_story()

## 取得可复用的剧情正文。## 输入: 无。输出: Control。
func get_view() -> Control:
	return %DialogueView

## 显示正文并隐藏待机页。## 输入: 无。输出: 无。
func begin_story() -> void:
	%StandbyLabel.hide()
	%DialogueView.show()

## 剧情结束后恢复待机展示。## 输入: 无。输出: 无。
func end_story() -> void:
	%StandbyLabel.show()
	%DialogueView.hide()

extends Control
## 未知程序窗口内容。由剧情触发开启，对话进行时锁定最小化和关闭。
## 对话结束后进入待机状态；关闭待机窗口只隐藏，不销毁后台实例。

enum State { STANDBY, STORY_ACTIVE }

var _state: State = State.STANDBY
var _parent_window: ManagedWindow = null

@onready var _standby_label: Label = %StandbyLabel
@onready var _story_container: Control = %StoryContainer


## 进入待机状态，等待剧情触发。
## 输入: 无。
## 输出: 无。
func _ready() -> void:
	_set_state(State.STANDBY)
	# 获取父窗口引用（用于锁定控制）
	call_deferred("_find_parent_window")


## 延迟获取父 ManagedWindow 引用。
## 输入: 无。
## 输出: 无。
func _find_parent_window() -> void:
	var p: Node = get_parent()
	while p != null:
		if p is ManagedWindow:
			_parent_window = p as ManagedWindow
			break
		p = p.get_parent()


## 切换内部状态并更新显示。
## 输入: new_state (State) - 新状态。
## 输出: 无。
func _set_state(new_state: State) -> void:
	_state = new_state
	if _standby_label != null:
		_standby_label.visible = (_state == State.STANDBY)
	if _story_container != null:
		_story_container.visible = (_state == State.STORY_ACTIVE)


## 剧情开始时由 App 调用：锁定窗口并切换到剧情状态。
## 输入: 无。
## 输出: 无。
func begin_story() -> void:
	_set_state(State.STORY_ACTIVE)
	if _parent_window != null and is_instance_valid(_parent_window):
		_parent_window.set_close_locked(true)
		_parent_window.set_minimize_locked(true)


## 剧情结束时由 App 调用：解锁窗口并切回待机状态。
## 输入: 无。
## 输出: 无。
func end_story() -> void:
	_set_state(State.STANDBY)
	if _parent_window != null and is_instance_valid(_parent_window):
		_parent_window.set_close_locked(false)
		_parent_window.set_minimize_locked(false)

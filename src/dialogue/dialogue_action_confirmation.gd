class_name DialogueActionConfirmation
extends CanvasLayer
## 剧情动作的模态确认层，屏蔽背景输入并等待一次明确选择。

signal decided(accepted: bool)

@export_multiline var message: String = "是否执行此操作？"
@export var allow_no: bool = true
@export var show_test_stop: bool = false

var _resolved: bool = false


## 同步可编辑文案与按钮，并把键盘焦点限制在确认层内。## 输入: 无。输出: 无。
func _ready() -> void:
	%Message.text = message
	%NoButton.visible = allow_no
	%StopTestButton.visible = show_test_stop
	%YesButton.pressed.connect(accept)
	%NoButton.pressed.connect(reject)
	%StopTestButton.pressed.connect(_stop_test)
	var buttons: Array[Button] = [%YesButton]
	if allow_no:
		buttons.append(%NoButton)
	if show_test_stop:
		buttons.append(%StopTestButton)
	for index: int in buttons.size():
		var next_button: Button = buttons[(index + 1) % buttons.size()]
		var previous_button: Button = buttons[(index - 1 + buttons.size()) % buttons.size()]
		buttons[index].focus_next = buttons[index].get_path_to(next_button)
		buttons[index].focus_previous = buttons[index].get_path_to(previous_button)
		buttons[index].focus_neighbor_left = buttons[index].get_path_to(previous_button)
		buttons[index].focus_neighbor_right = buttons[index].get_path_to(next_button)
		buttons[index].focus_neighbor_top = buttons[index].get_path_to(previous_button)
		buttons[index].focus_neighbor_bottom = buttons[index].get_path_to(next_button)
	%YesButton.grab_focus()


## Esc 仅在允许拒绝时选择否，强制确认时吞掉按键。## 输入: event (InputEvent)。输出: 无。
func _input(event: InputEvent) -> void:
	if _resolved or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	reject()


## 明确选择是，关闭确认层并通知等待中的脚本。## 输入: 无。输出: 无。
func accept() -> void:
	_resolve(true)


## 只有允许否时才拒绝，强制剧情不能通过 Esc 或按钮回调绕过。## 输入: 无。输出: 无。
func reject() -> void:
	if allow_no:
		_resolve(false)


## 调试停止或宿主清理时解除等待，始终不执行待确认动作。## 输入: 无。输出: 无。
func cancel_pending() -> void:
	_resolve(false)


## 只允许一次结果，隐藏后再发出信号以免重复按键。## 输入: accepted (bool)。输出: 无。
func _resolve(accepted: bool) -> void:
	if _resolved:
		return
	_resolved = true
	hide()
	decided.emit(accepted)


## 调试确认层提供停止入口，避免强制确认阻塞剧情测试台。## 输入: 无。输出: 无。
func _stop_test() -> void:
	App.stop_story_test("已停止测试")

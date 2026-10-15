extends Button
## 双击或键盘确认启动的桌面快捷方式。

## 配置选择与启动输入。## 输入: 无。输出: 无。
func _ready() -> void:
	gui_input.connect(_on_gui_input)

## 鼠标双击启动，键盘确认同样可打开。## 输入: event。输出: 无。
func _on_gui_input(event: InputEvent) -> void:
	var launch: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.double_click
	launch = launch or event.is_action_pressed("ui_accept")
	if launch:
		App.open_app(str(get_meta("app_id")))
		accept_event()

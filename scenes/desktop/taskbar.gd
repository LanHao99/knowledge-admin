extends Panel
## 任务栏、开始菜单和本机时钟。

var _start_menu: Control
var _app_buttons: Dictionary = {}
@onready var _start_button: Button = $TaskbarHBox/StartButton
@onready var _task_buttons: HBoxContainer = $TaskbarHBox/TaskScroll/TaskButtons

## 连接开始按钮并定时刷新时钟。## 输入: 无。输出: 无。
func _ready() -> void:
	_update_clock()
	var timer: Timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_update_clock)
	add_child(timer)
	timer.start()
	_start_button.pressed.connect(_toggle_start_menu)

## 新建单个可切换的任务按钮。## 输入: 应用 ID、标题。输出: 无。
func add_app_button(app_id: String, title_text: String) -> void:
	if _app_buttons.has(app_id):
		return
	var button: Button = Button.new()
	button.text = title_text
	button.tooltip_text = title_text
	button.toggle_mode = true
	button.custom_minimum_size.x = 170
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.pressed.connect(_on_task_button_pressed.bind(app_id))
	_task_buttons.add_child(button)
	_app_buttons[app_id] = button

## 删除任务按钮。## 输入: app_id。输出: 无。
func remove_app_button(app_id: String) -> void:
	var button: Button = _app_buttons.get(app_id) as Button
	if is_instance_valid(button):
		_task_buttons.remove_child(button)
		button.queue_free()
	_app_buttons.erase(app_id)

## 同步任务按钮的按下状态。## 输入: app_id。输出: 无。
func set_active_button(app_id: String) -> void:
	for entry: String in _app_buttons:
		(_app_buttons[entry] as Button).set_pressed_no_signal(entry == app_id)

## 刷新时钟及日期提示。## 输入: 无。输出: 无。
func _update_clock() -> void:
	var now: Dictionary = Time.get_time_dict_from_system()
	$TaskbarHBox/RightArea/ClockLabel.text = "  %02d:%02d  " % [now.hour, now.minute]
	$TaskbarHBox/RightArea/ClockLabel.tooltip_text = Time.get_date_string_from_system()

## 安全关闭当前开始菜单。## 输入: 无。输出: 无。
func dismiss_start_menu() -> void:
	if is_instance_valid(_start_menu):
		_start_menu.hide()
		_start_menu.queue_free()
	_start_menu = null

## 切换开始菜单，定位在开始按钮上方。## 输入: 无。输出: 无。
func _toggle_start_menu() -> void:
	if WindowManager._story_locked:
		return
	if is_instance_valid(_start_menu):
		dismiss_start_menu()
		return
	_start_menu = preload("res://scenes/desktop/start_menu.tscn").instantiate() as Control
	get_parent().add_child(_start_menu)
	_start_menu.position = Vector2(4, position.y - _start_menu.size.y)
	_start_menu.tree_exited.connect(_on_start_menu_exited)

## 清理已释放菜单引用。## 输入: 无。输出: 无。
func _on_start_menu_exited() -> void:
	_start_menu = null

## 点击当前任务可最小化，其他任务切到前台。## 输入: app_id。输出: 无。
func _on_task_button_pressed(app_id: String) -> void:
	if WindowManager._story_locked:
		set_active_button("unknown_program")
		return
	var window: ManagedWindow = WindowManager.get_app_window(app_id)
	if window == null:
		return
	if WindowManager.get_active_app_id() == app_id and not window.is_minimized():
		window._on_minimize_pressed()
	else:
		WindowManager.open_app(app_id)

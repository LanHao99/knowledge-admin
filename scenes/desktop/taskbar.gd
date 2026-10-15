extends Panel
## 任务栏控件。管理开始菜单按钮、应用任务栏按钮和时钟。

@export var taskbar_height: float = 32.0

var _start_menu: Control = null

@onready var _start_button: Button = $TaskbarHBox/StartButton
@onready var _task_buttons: HBoxContainer = $TaskbarHBox/TaskButtons
@onready var _clock_label: Label = $TaskbarHBox/RightArea/ClockLabel

## 应用任务栏按钮字典：app_id -> Button
var _app_buttons: Dictionary = {}


## 初始化时钟定时器并连接开始菜单。
## 输入: 无。
## 输出: 无。
func _ready() -> void:
	_update_clock()
	var timer: Timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_update_clock)
	add_child(timer)
	timer.start()
	_start_button.pressed.connect(_on_start_pressed)


## 添加指定应用的任务栏按钮。
## 输入: app_id (String), title (String) - 应用 ID 和显示名称。
## 输出: 无。
func add_app_button(app_id: String, title: String) -> void:
	if _app_buttons.has(app_id):
		return
	var btn: Button = Button.new()
	btn.text = title
	btn.custom_minimum_size = Vector2(120.0, 24.0)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_on_task_button_pressed.bind(app_id))
	_task_buttons.add_child(btn)
	_app_buttons[app_id] = btn


## 移除指定应用的任务栏按钮。
## 输入: app_id (String) - 应用 ID。
## 输出: 无。
func remove_app_button(app_id: String) -> void:
	if not _app_buttons.has(app_id):
		return
	var btn: Button = _app_buttons[app_id]
	_app_buttons.erase(app_id)
	if is_instance_valid(btn):
		btn.queue_free()


## 设置活动（按下状态）的按钮。
## 输入: app_id (String) - 应用 ID，空字符串清除所有激活状态。
## 输出: 无。
func set_active_button(app_id: String) -> void:
	for aid: String in _app_buttons:
		var btn: Button = _app_buttons[aid]
		if is_instance_valid(btn):
			btn.button_pressed = (aid == app_id)


## 更新时钟标签为当前系统时间。
## 输入: 无。
## 输出: 无。
func _update_clock() -> void:
	if _clock_label == null:
		return
	var t: Dictionary = Time.get_time_dict_from_system()
	_clock_label.text = "%02d:%02d" % [t.hour, t.minute]


## 开始菜单按钮点击处理。
## 输入: 无。
## 输出: 无。
func _on_start_pressed() -> void:
	_toggle_start_menu()


## 切换开始菜单的显示状态。
## 输入: 无。
## 输出: 无。
func _toggle_start_menu() -> void:
	if _start_menu != null and is_instance_valid(_start_menu):
		_start_menu.queue_free()
		_start_menu = null
		return
	var scene_path: String = "res://scenes/desktop/start_menu.tscn"
	if not ResourceLoader.exists(scene_path):
		push_warning("[Taskbar] 开始菜单场景不存在")
		return
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		return
	_start_menu = packed.instantiate() as Control
	if _start_menu == null:
		return
	# 挂到桌面根节点
	get_tree().root.get_child(get_tree().root.get_child_count() - 1).add_child(_start_menu)
	# 定位到开始按钮上方
	var btn_global: Vector2 = _start_button.global_position
	_start_menu.global_position = Vector2(btn_global.x, btn_global.y - _start_menu.size.y - 4.0)
	_start_menu.tree_exited.connect(func() -> void: _start_menu = null)


## 任务栏应用按钮被点击时，激活或最小化对应窗口。
## 输入: app_id (String) - 应用 ID。
## 输出: 无。
func _on_task_button_pressed(app_id: String) -> void:
	var window: ManagedWindow = WindowManager.get_app_window(app_id)
	if window == null or not is_instance_valid(window):
		return
	if WindowManager.get_active_app_id() == app_id and not window.is_minimized():
		window.call("_on_minimize_pressed")
	elif window.is_minimized():
		window.restore()
	else:
		WindowManager.open_app(app_id)

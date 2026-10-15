extends Panel
## 任务栏、开始菜单和本机时钟。

const APP_BUTTON_SCENE: PackedScene = preload("res://scenes/desktop/taskbar_app_button.tscn")

@export_range(24.0, 80.0, 1.0) var app_button_size: float = 40.0
@export_range(16.0, 64.0, 1.0) var app_icon_size: float = 36.0

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
	UiSettings.font_scale_changed.connect(_update_app_button_layout)
	_task_buttons.resized.connect(_on_task_buttons_resized)

## 新建单个可切换的任务按钮。## 输入: 应用 ID、标题。输出: 无。
func add_app_button(app_id: String, title_text: String) -> void:
	if _app_buttons.has(app_id):
		return
	var button: Button = APP_BUTTON_SCENE.instantiate() as Button
	button.tooltip_text = title_text
	button.accessibility_name = title_text
	var config: Dictionary = WindowManager.REGISTRY.get(app_id, {})
	var icon_path: String = str(config.get("icon_path", ""))
	if not icon_path.is_empty():
		(button.get_node("Icon") as TextureRect).texture = load(icon_path) as Texture2D
	button.pressed.connect(_on_task_button_pressed.bind(app_id))
	_task_buttons.add_child(button)
	_app_buttons[app_id] = button
	_update_app_button_layout(UiSettings.font_scale)

## 按任务栏可用高度填满方形按钮，图标按配置比例放大并留出边框。## 输入: scale_value - 字体倍率。输出: 无。
func _update_app_button_layout(scale_value: float) -> void:
	var minimum_side: float = roundf(app_button_size * scale_value)
	var side: float = maxf(minimum_side, _task_buttons.size.y)
	var icon_side: float = minf(roundf(side * app_icon_size / app_button_size), side - 4.0)
	for button: Button in _app_buttons.values():
		button.custom_minimum_size = Vector2(side, minimum_side)
		var icon: TextureRect = button.get_node("Icon") as TextureRect
		icon.offset_left = -icon_side * 0.5
		icon.offset_top = -icon_side * 0.5
		icon.offset_right = icon_side * 0.5
		icon.offset_bottom = icon_side * 0.5

## 容器完成布局后同步按钮宽度，避免任务栏变厚时图标仍保持小尺寸。## 输入: 无。输出: 无。
func _on_task_buttons_resized() -> void:
	_update_app_button_layout.call_deferred(UiSettings.font_scale)

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

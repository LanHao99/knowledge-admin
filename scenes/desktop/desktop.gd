extends Control
## 桌面主场景。包含桌面背景、快捷图标、窗口容器和任务栏。
## 启动时由启动画面跳转而来；负责初始化 WindowManager。

const ICON_GRID_X: int = 80
const ICON_GRID_Y: int = 90

@export var taskbar_height: float = 32.0

@onready var _desktop_bg: ColorRect = %DesktopBg
@onready var _window_container: Control = %WindowContainer
@onready var _taskbar: Control = %Taskbar
@onready var _icon_grid: GridContainer = %DesktopIconGrid


## 初始化 WindowManager 并生成桌面图标。
## 输入: 无。
## 输出: 无。
func _ready() -> void:
	WindowManager.setup(_window_container, _taskbar)
	_populate_icons()
	# 调整窗口容器高度：留出任务栏空间
	_on_resized()
	resized.connect(_on_resized)


## 当游戏窗口大小改变时，重新计算容器布局。
## 输入: 无。
## 输出: 无。
func _on_resized() -> void:
	if _window_container == null:
		return
	var ts: float = _taskbar.size.y if _taskbar != null else taskbar_height
	_window_container.custom_minimum_size = Vector2(0.0, size.y - ts)


## 根据 WindowManager 注册表生成桌面快捷方式图标。
## 输入: 无。
## 输出: 无。
func _populate_icons() -> void:
	for child: Node in _icon_grid.get_children():
		child.queue_free()
	var apps: Array[Dictionary] = WindowManager.get_visible_apps()
	for app_info: Dictionary in apps:
		var icon_node: Button = _make_icon_button(app_info)
		_icon_grid.add_child(icon_node)


## 创建单个桌面图标按钮。双击打开对应应用。
## 输入: app_info (Dictionary) - 含 app_id、title、icon_path 的配置字典。
## 输出: Button。
func _make_icon_button(app_info: Dictionary) -> Button:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(float(ICON_GRID_X), float(ICON_GRID_Y))
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.text = app_info.get("title", "")
	# 双击用单次点击模拟（双击检测在 gui_input 中实现）
	var app_id: String = app_info.get("app_id", "")
	btn.pressed.connect(func() -> void:
		WindowManager.open_app(app_id)
	)
	return btn

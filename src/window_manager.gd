extends Node
## 窗口管理器 Autoload。负责应用窗口的注册、开关、Z 轴排序和任务栏同步。
## 所有应用通过 open_app / close_app 管理，单实例策略：重复打开只激活现有窗口。

## 某个应用窗口被打开。
signal app_opened(app_id: String)
## 某个应用窗口被关闭。
signal app_closed(app_id: String)
## 某个应用窗口获得焦点。
signal app_focused(app_id: String)

## 应用注册表：app_id → {title, icon_path, scene_path, entry_visible}
## entry_visible=false 的应用不出现在桌面快捷方式或开始菜单中。
const REGISTRY: Dictionary = {
	"knowledge_admin": {
		"title": "Knowledge Admin",
		"icon_path": "res://assets/icons/app_knowledge.png",
		"scene_path": "res://scenes/ui/main_menu.tscn",
		"entry_visible": true,
		"default_size": Vector2(900, 650),
	},
	"ai_cards": {
		"title": "AI 制卡助手",
		"icon_path": "res://assets/icons/app_ai.png",
		"scene_path": "res://game/AI/ai_debug.tscn",
		"entry_visible": true,
		"default_size": Vector2(860, 620),
	},
	"control_panel": {
		"title": "控制面板",
		"icon_path": "res://assets/icons/app_settings.png",
		"scene_path": "res://scenes/ui/settings.tscn",
		"entry_visible": true,
		"default_size": Vector2(760, 560),
	},
	"my_computer": {
		"title": "我的电脑",
		"icon_path": "res://assets/icons/app_computer.png",
		"scene_path": "res://scenes/desktop/my_computer.tscn",
		"entry_visible": true,
		"default_size": Vector2(640, 480),
	},
	"recycle_bin": {
		"title": "回收站",
		"icon_path": "res://assets/icons/app_recycle.png",
		"scene_path": "res://scenes/desktop/recycle_bin.tscn",
		"entry_visible": true,
		"default_size": Vector2(480, 360),
	},
	"unknown_program": {
		"title": "未知程序",
		"icon_path": "res://assets/icons/app_unknown.png",
		"scene_path": "res://scenes/desktop/unknown_program.tscn",
		"entry_visible": false,  ## 故意隐藏：由剧情触发
		"default_size": Vector2(640, 480),
	},
}

const WINDOW_SCENE_PATH: String = "res://scenes/desktop/managed_window.tscn"

## app_id -> ManagedWindow（已开启的窗口）
var _open_windows: Dictionary = {}
var _window_container: Control = null
var _taskbar: Node = null
var _active_app_id: String = ""


## 绑定窗口容器和任务栏（由 Desktop 场景在 _ready 中调用）。
## 输入: container (Control) - 所有窗口的父节点。taskbar (Node) - 任务栏实例。
## 输出: 无。
func setup(container: Control, taskbar: Node) -> void:
	_window_container = container
	_taskbar = taskbar


## 打开指定应用。已开启则激活现有窗口（单实例）。
## 输入: app_id (String) - 注册表中的应用 ID。
## 输出: bool - 成功打开或激活返回 true。
func open_app(app_id: String) -> bool:
	if _open_windows.has(app_id):
		var existing: ManagedWindow = _open_windows[app_id]
		if is_instance_valid(existing):
			if existing.is_minimized():
				existing.restore()
			_activate_window(existing, app_id)
			return true

	if not REGISTRY.has(app_id):
		push_warning("[WindowManager] 未知的应用 ID: %s" % app_id)
		return false

	var config: Dictionary = REGISTRY[app_id]
	var scene_path: String = config.get("scene_path", "")
	if not ResourceLoader.exists(scene_path):
		push_warning("[WindowManager] 场景不存在: %s (app_id=%s)" % [scene_path, app_id])
		return false

	if not ResourceLoader.exists(WINDOW_SCENE_PATH):
		push_error("[WindowManager] 窗口模板不存在: %s" % WINDOW_SCENE_PATH)
		return false

	var window_packed: PackedScene = load(WINDOW_SCENE_PATH) as PackedScene
	if window_packed == null:
		push_error("[WindowManager] 窗口场景加载失败")
		return false

	var window: ManagedWindow = window_packed.instantiate() as ManagedWindow
	if window == null:
		push_error("[WindowManager] 窗口实例化失败")
		return false

	var def_size: Vector2 = config.get("default_size", Vector2(800, 600))
	window.default_size = def_size

	_window_container.add_child(window)
	window.initialize(app_id, config.get("title", app_id), scene_path)
	window.close_requested.connect(_on_window_close_requested.bind(app_id))
	window.window_clicked.connect(_on_window_clicked.bind(app_id))
	window.minimized.connect(_on_window_minimized.bind(app_id))
	window.restored.connect(_on_window_restored.bind(app_id))

	_open_windows[app_id] = window

	if _taskbar != null and _taskbar.has_method("add_app_button"):
		_taskbar.add_app_button(app_id, config.get("title", app_id))

	_activate_window(window, app_id)
	app_opened.emit(app_id)
	return true


## 关闭指定应用并释放窗口节点。
## 输入: app_id (String) - 应用 ID。
## 输出: 无。
func close_app(app_id: String) -> void:
	if not _open_windows.has(app_id):
		return

	var window: ManagedWindow = _open_windows[app_id]
	_open_windows.erase(app_id)

	if _active_app_id == app_id:
		_active_app_id = ""

	if _taskbar != null and _taskbar.has_method("remove_app_button"):
		_taskbar.remove_app_button(app_id)

	if is_instance_valid(window):
		window.queue_free()

	app_closed.emit(app_id)


## 在当前活动窗口内切换内容场景（in-window 页面导航）。
## 输入: path (String) - 新内容场景的 res:// 路径。
## 输出: int - OK 或错误码。
func navigate_in_active(path: String) -> int:
	if _active_app_id.is_empty():
		return ERR_DOES_NOT_EXIST
	var window: ManagedWindow = _open_windows.get(_active_app_id, null)
	if window == null or not is_instance_valid(window):
		return ERR_DOES_NOT_EXIST
	return window.navigate_to(path)


## 返回当前是否有活动（非最小化）的窗口。
## 输入: 无。
## 输出: bool。
func has_active_window() -> bool:
	return not _active_app_id.is_empty() and _open_windows.has(_active_app_id)


## 返回当前活动应用的 ID。
## 输入: 无。
## 输出: String（空字符串表示无活动窗口）。
func get_active_app_id() -> String:
	return _active_app_id


## 取得已开启窗口的实例（包括最小化状态）。
## 输入: app_id (String) - 应用 ID。
## 输出: ManagedWindow 或 null。
func get_app_window(app_id: String) -> ManagedWindow:
	return _open_windows.get(app_id, null)
	return _open_windows.get(app_id, null)


## 返回注册表中 entry_visible=true 的应用列表，供桌面图标和开始菜单使用。
## 输入: 无。
## 输出: Array[Dictionary]，每项含 app_id、title、icon_path。
func get_visible_apps() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for app_id: String in REGISTRY:
		var config: Dictionary = REGISTRY[app_id]
		if config.get("entry_visible", false):
			result.append({
				"app_id": app_id,
				"title": config.get("title", app_id),
				"icon_path": config.get("icon_path", ""),
			})
	return result


## 将窗口提到最前并标记为活动，同时取消其他窗口的激活状态。
## 输入: window (ManagedWindow) - 目标窗口。app_id (String) - 应用 ID。
## 输出: 无。
func _activate_window(window: ManagedWindow, app_id: String) -> void:
	if not is_instance_valid(window):
		return
	if _window_container != null and is_instance_valid(_window_container):
		_window_container.move_child(window, _window_container.get_child_count() - 1)
	window.set_window_active(true)
	for other_id: String in _open_windows:
		if other_id != app_id:
			var other: ManagedWindow = _open_windows[other_id]
			if is_instance_valid(other):
				other.set_window_active(false)
	_active_app_id = app_id
	if _taskbar != null and _taskbar.has_method("set_active_button"):
		_taskbar.set_active_button(app_id)
	app_focused.emit(app_id)


func _on_window_close_requested(app_id: String) -> void:
	close_app(app_id)


func _on_window_clicked(app_id: String) -> void:
	if _active_app_id != app_id:
		var window: ManagedWindow = _open_windows.get(app_id, null)
		if window != null and is_instance_valid(window):
			_activate_window(window, app_id)


func _on_window_minimized(app_id: String) -> void:
	if _active_app_id == app_id:
		_active_app_id = ""
	if _taskbar != null and _taskbar.has_method("set_active_button"):
		_taskbar.set_active_button("")


func _on_window_restored(app_id: String) -> void:
	var window: ManagedWindow = _open_windows.get(app_id, null)
	if window != null and is_instance_valid(window):
		_activate_window(window, app_id)

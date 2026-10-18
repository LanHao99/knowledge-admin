extends Node
## 桌面应用注册、窗口层级、页面路由和模态输入的唯一管理器。

signal app_opened(app_id: String)
signal app_closed(app_id: String)
signal app_focused(app_id: String)

const REGISTRY: Dictionary = {
	"knowledge_admin": {"title": "Knowledge Admin", "icon_path": "res://assets/icons/desktop_knowledge.svg", "scene_path": "res://scenes/ui/main_menu.tscn", "entry_visible": true, "default_size": Vector2(1440, 900)},
	"ai_cards": {"title": "AI 制卡助手", "icon_path": "res://assets/icons/desktop_ai.svg", "scene_path": "res://game/AI/ai_debug.tscn", "entry_visible": true, "default_size": Vector2(1220, 850)},
	"control_panel": {"title": "控制面板", "icon_path": "res://assets/icons/desktop_settings.svg", "scene_path": "res://scenes/ui/settings.tscn", "entry_visible": true, "default_size": Vector2(1200, 880)},
	"my_computer": {"title": "我的电脑", "icon_path": "res://assets/icons/desktop_computer.svg", "scene_path": "res://scenes/desktop/my_computer.tscn", "entry_visible": true, "default_size": Vector2(1000, 720)},
	"recycle_bin": {"title": "回收站", "icon_path": "res://assets/icons/desktop_recycle.svg", "scene_path": "res://scenes/desktop/recycle_bin.tscn", "entry_visible": true, "default_size": Vector2(820, 560)},
	"camera": {"title": "摄像头", "icon_path": "res://assets/icons/desktop_camera.svg", "scene_path": "res://scenes/desktop/camera.tscn", "entry_visible": true, "default_size": Vector2(560, 560), "keep_square": true, "min_size": Vector2(320, 320)},
	"window_lab": {"title": "窗口实验室", "icon_path": "res://assets/icons/control/window.svg", "scene_path": "res://scenes/desktop/window_lab.tscn", "entry_visible": true, "default_size": Vector2(900, 620)},
	"story_test": {"title": "剧情测试台", "icon_path": "res://assets/icons/desktop_ai.svg", "scene_path": "res://scenes/desktop/story_test_bench.tscn", "entry_visible": true, "debug_only": true, "default_size": Vector2(1100, 760)},
	"unknown_program": {"title": "未知程序", "icon_path": "res://assets/icons/desktop_unknown.svg", "scene_path": "res://scenes/desktop/unknown_program.tscn", "entry_visible": false, "default_size": Vector2(1180, 800)},
	"help": {"title": "使用帮助", "icon_path": "res://assets/icons/desktop_knowledge.svg", "scene_path": "res://game/dialogue/story_dialogue_overlay.tscn", "entry_visible": false, "default_size": Vector2(1100, 740)},
}
const WINDOW_SCENE_PATH: String = "res://scenes/desktop/managed_window.tscn"

var _open_windows: Dictionary = {}
var _window_container: Control
var _taskbar: Node
var _active_app_id: String = ""
var _modal_layer: Control
var _modal_container: Control
var _story_locked: bool = false
var _previous_app: String = ""
var _help_owner: String = ""
var _suspended_popups: Array[WeakRef] = []
var _layouts: Dictionary = {}
var _minimized_popups: Dictionary = {}
var _close_confirm: ConfirmationDialog
var _window_effects: DesktopWindowEffects
var _pending_shatters: Dictionary[String, int] = {}

## 绑定当前桌面及其模态层。## 输入: 窗口容器、任务栏。输出: 无。
func setup(container: Control, taskbar: Node) -> void:
	_window_container = container
	_taskbar = taskbar
	var desktop_root: Node = container.get_parent()
	_window_effects = desktop_root.get_node_or_null("WindowEffects") as DesktopWindowEffects if desktop_root != null else null
	_modal_layer = desktop_root.get_node_or_null("ModalLayer") as Control if desktop_root != null else null
	_modal_container = desktop_root.get_node_or_null("ModalLayer/ModalWindows") as Control if desktop_root != null else null
	_open_windows.clear()
	_pending_shatters.clear()
	_active_app_id = ""
	_story_locked = false
	if not is_inside_tree():
		return
	get_tree().root.gui_embed_subwindows = true
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)

## 桌面是否已绑定且仍在场景树中。## 输入: 无。输出: bool。
func is_available() -> bool:
	return is_instance_valid(_window_container) and _window_container.is_inside_tree()

## 打开或激活一个单实例应用。## 输入: app_id。输出: 是否成功。
func open_app(app_id: String) -> bool:
	if not is_available() or not REGISTRY.has(app_id) or _pending_shatters.has(app_id):
		return false
	if bool(REGISTRY[app_id].get("debug_only", false)) and not _debug_entry_enabled():
		return false
	if _story_locked and app_id != "unknown_program":
		return false
	if not _help_owner.is_empty() and app_id == _help_owner:
		app_id = "help"
	var existing: ManagedWindow = get_app_window(app_id)
	if existing != null:
		existing.restore()
		_activate_window(existing, app_id)
		for reference: WeakRef in _minimized_popups.get(app_id, []):
			var popup: Window = reference.get_ref() as Window
			if is_instance_valid(popup):
				popup.show()
		_minimized_popups.erase(app_id)
		return true
	var config: Dictionary = REGISTRY[app_id]
	var window: ManagedWindow = load(WINDOW_SCENE_PATH).instantiate() as ManagedWindow
	var sizes: Dictionary = _window_container.get_parent().get("application_sizes")
	window.default_size = sizes.get(app_id, config.default_size)
	window.keep_square = bool(config.get("keep_square", false))
	window.min_window_size = config.get("min_size", window.min_window_size)
	if app_id in ["my_computer", "recycle_bin", "window_lab"]:
		window.min_window_size = Vector2(520, 360)
	_open_windows[app_id] = window
	_window_container.add_child(window)
	window.close_requested.connect(close_app.bind(app_id))
	window.window_clicked.connect(_on_window_clicked.bind(app_id))
	window.minimized.connect(_on_window_minimized.bind(app_id))
	window.restored.connect(_on_window_clicked.bind(app_id))
	window.initialize(app_id, config.title, config.scene_path)
	if _layouts.has(app_id):
		var bounds: Rect2 = _layouts[app_id]
		window.position = bounds.position
		window.size = bounds.size
		window.fit_work_area()
	_taskbar.add_app_button(app_id, config.title)
	_activate_window(window, app_id)
	app_opened.emit(app_id)
	return true

## 请求关闭，剧情锁定、帮助及写入过程不允许绕过。## 输入: app_id。输出: 无。
func close_app(app_id: String) -> void:
	var window: ManagedWindow = get_app_window(app_id)
	if window == null or _story_locked or app_id == "help" or app_id == _help_owner or _pending_shatters.has(app_id):
		return
	var page: Control = window.get_content()
	if _contains_import(page):
		return
	if page != null and page.has_method("desktop_has_active_session") and page.desktop_has_active_session():
		if is_instance_valid(_close_confirm):
			return
		_close_confirm = ConfirmationDialog.new()
		_close_confirm.title = "结束学习"
		_close_confirm.dialog_text = "结束当前学习并关闭闪卡软件？已完成的评分会保留。"
		_close_confirm.confirmed.connect(_confirm_study_close.bind(app_id))
		window.add_child(_close_confirm)
		_close_confirm.popup_centered()
		_close_confirm.canceled.connect(_close_confirm.queue_free)
		return
	if page != null and page.has_method("desktop_request_close"):
		page.desktop_request_close(_force_close.bind(app_id))
		return
	_force_close(app_id)

## 调整普通应用的整窗玻璃损伤；不会改变内容和布局。## 输入: 应用 ID、损伤强度。输出: 是否接受。
func set_app_damage(app_id: String, amount: float) -> bool:
	var window: ManagedWindow = _effect_target(app_id)
	if window == null or not is_finite(amount):
		return false
	window.set_damage(amount)
	return true

## 冻结目标并请求单次整窗快照，动画交由桌面层持有。## 输入: 应用 ID。输出: 是否接受。
func shatter_app(app_id: String) -> bool:
	var window: ManagedWindow = _effect_target(app_id)
	if window == null or not is_instance_valid(_window_effects) or _window_effects.is_capturing:
		return false
	var instance_id: int = window.get_instance_id()
	_pending_shatters[app_id] = instance_id
	_taskbar.dismiss_start_menu()
	window.begin_shatter()
	_window_effects.capture_and_shatter(window, _finish_shatter.bind(app_id, instance_id))
	return true

## 剧情专用损伤入口，只接受模态层中正在播放的未知程序。## 输入: amount (float)。输出: bool。
func set_story_window_damage(amount: float) -> bool:
	var window: ManagedWindow = _story_effect_target()
	if window == null or not is_finite(amount):
		return false
	window.set_damage(amount)
	return true

## 捕获剧情窗口并在回调结束剧情后销毁真实实例，普通特效入口保持原有保护。## 输入: on_captured (Callable)。输出: bool。
func shatter_story_window(on_captured: Callable) -> bool:
	var window: ManagedWindow = _story_effect_target()
	if window == null or not on_captured.is_valid() or not is_instance_valid(_window_effects) or _window_effects.is_capturing:
		return false
	var instance_id: int = window.get_instance_id()
	_pending_shatters["unknown_program"] = instance_id
	window.begin_shatter()
	_window_effects.capture_and_shatter(window, _finish_story_shatter.bind(instance_id, on_captured))
	return true

## 校验剧情锁、模态归属及弹窗，拒绝待机窗口或重复请求。## 输入: 无。输出: ManagedWindow 或 null。
func _story_effect_target() -> ManagedWindow:
	var window: ManagedWindow = get_app_window("unknown_program")
	if not _story_locked or window == null or window.get_parent() != _modal_container:
		return null
	if _pending_shatters.has("unknown_program") or not window.is_visible_in_tree() or _has_visible_popup(window):
		return null
	return window

## 快照取得后解除对话模态，再按原实例标识关闭未知程序。## 输入: 实例标识、剧情完成回调。输出: 无。
func _finish_story_shatter(instance_id: int, on_captured: Callable) -> void:
	if _pending_shatters.get("unknown_program", 0) != instance_id:
		return
	if on_captured.is_valid():
		on_captured.call()
	_finish_shatter("unknown_program", instance_id)

## 检查剧情、帮助、会话、写入与模态弹窗保护，禁止特效绕过业务限制。## 输入: 应用 ID。输出: 可用目标或 null。
func _effect_target(app_id: String) -> ManagedWindow:
	var window: ManagedWindow = get_app_window(app_id)
	if window == null or _story_locked or _pending_shatters.has(app_id) or app_id in ["unknown_program", "help", _help_owner]:
		return null
	if not window.is_visible_in_tree() or window._close_locked or _contains_import(window):
		return null
	var page: Control = window.get_content()
	if page != null and page.has_method("desktop_has_active_session") and page.desktop_has_active_session():
		return null
	if _has_visible_popup(window):
		return null
	return window

## 检查目标内部的可见弹窗，避免捕获遗漏弹窗或绕过确认。## 输入: 子树根。输出: bool。
func _has_visible_popup(node: Node) -> bool:
	for child: Node in node.get_children():
		if child is Window and child.visible:
			return true
		if _has_visible_popup(child):
			return true
	return false

## 在碎片第一帧出现前释放对应旧实例，过期回调不能关闭新窗口。## 输入: 应用 ID、实例标识。输出: 无。
func _finish_shatter(app_id: String, instance_id: int) -> void:
	if _pending_shatters.get(app_id, 0) != instance_id:
		return
	_pending_shatters.erase(app_id)
	var window: ManagedWindow = get_app_window(app_id)
	if window != null and window.get_instance_id() == instance_id:
		_force_close(app_id)

## 确认结束会话后再释放窗口。## 输入: app_id。输出: 无。
func _confirm_study_close(app_id: String) -> void:
	if _story_locked:
		return
	var window: ManagedWindow = get_app_window(app_id)
	if window != null and window.get_content().has_method("desktop_end_session"):
		window.get_content().desktop_end_session()
	_force_close(app_id)

## 判断子树是否有正在写入的导入向导。## 输入: node。输出: bool。
func _contains_import(node: Node) -> bool:
	if node == null:
		return false
	if node.has_method("is_importing") and node.is_importing():
		return true
	for child: Node in node.get_children():
		if _contains_import(child):
			return true
	return false

## 释放应用；未知程序通常保留实例，完全破碎时真实销毁。## 输入: app_id。输出: 无。
func _force_close(app_id: String) -> void:
	var window: ManagedWindow = get_app_window(app_id)
	if window == null:
		return
	window.stop_impact()
	_layouts[app_id] = Rect2(window.position, window.size)
	_taskbar.remove_app_button(app_id)
	if app_id == "unknown_program" and not window.is_shattering():
		window._on_minimize_pressed()
	else:
		_open_windows.erase(app_id)
		window.get_parent().remove_child(window)
		window.queue_free()
	_active_app_id = ""
	_focus_top_window()
	app_closed.emit(app_id)

## 页面按功能路由，闪卡导航始终归属闪卡应用。## 输入: path。输出: Godot 错误码。
func navigate_in_active(path: String) -> int:
	if _story_locked:
		return ERR_BUSY
	var app_id: String = "knowledge_admin"
	if path.ends_with("settings.tscn"):
		app_id = "control_panel"
	elif path.ends_with("ai_debug.tscn"):
		app_id = "ai_cards"
	if not open_app(app_id):
		return ERR_UNAVAILABLE
	if app_id == "knowledge_admin":
		var window: ManagedWindow = get_app_window(app_id)
		if window._current_scene_path != path:
			window.navigate_to.call_deferred(path)
	return OK

## 返回当前是否有活动窗口。## 输入: 无。输出: bool。
func has_active_window() -> bool:
	return get_app_window(_active_app_id) != null

## 返回活动应用标识。## 输入: 无。输出: String。
func get_active_app_id() -> String:
	return _active_app_id

## 读取有效窗口。## 输入: app_id。输出: ManagedWindow 或 null。
func get_app_window(app_id: String) -> ManagedWindow:
	var window: ManagedWindow = _open_windows.get(app_id) as ManagedWindow
	return window if is_instance_valid(window) else null

## 读取桌面和开始菜单允许展示的入口。## 输入: 无。输出: 应用信息数组。
func get_visible_apps() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for app_id: String in REGISTRY:
		if not REGISTRY[app_id].entry_visible:
			continue
		if bool(REGISTRY[app_id].get("debug_only", false)) and not _debug_entry_enabled():
			continue
		var entry: Dictionary = REGISTRY[app_id].duplicate()
		entry["app_id"] = app_id
		result.append(entry)
	return result


## 调试模式关闭时强制关闭调试应用，不抢占正在播放的剧情焦点。## 输入: app_id。
## 输出: 无。
func close_debug_app(app_id: String) -> void:
	if not bool(REGISTRY.get(app_id, {}).get("debug_only", false)):
		return
	var window: ManagedWindow = get_app_window(app_id)
	if window == null:
		return
	window.stop_impact()
	_layouts[app_id] = Rect2(window.position, window.size)
	if _taskbar != null and _taskbar.has_method("remove_app_button"):
		_taskbar.remove_app_button(app_id)
	_open_windows.erase(app_id)
	_minimized_popups.erase(app_id)
	if window.get_parent() != null:
		window.get_parent().remove_child(window)
	window.queue_free()
	if _active_app_id == app_id:
		_active_app_id = ""
		if not _story_locked:
			_focus_top_window()
	app_closed.emit(app_id)


## 读取调试开关，尚未进入场景树时视为关闭。## 输入: 无。
## 输出: bool。
func _debug_entry_enabled() -> bool:
	if not is_inside_tree():
		return false
	var tree := get_tree()
	if tree == null:
		return false
	var settings := tree.root.get_node_or_null("DebugSettings")
	return settings != null and bool(settings.get("debug_mode"))

## 提到前台并刷新只读页面，编辑和学习状态保持。## 输入: window、app_id。输出: 无。
func _activate_window(window: ManagedWindow, app_id: String) -> void:
	if window.is_shattering():
		return
	if _story_locked and app_id != "unknown_program":
		return
	for other_id: String in _open_windows:
		var other: ManagedWindow = get_app_window(other_id)
		if other != null:
			other.set_window_active(other_id == app_id)
	window.get_parent().move_child(window, window.get_parent().get_child_count() - 1)
	_active_app_id = app_id
	_taskbar.add_app_button(app_id, REGISTRY[app_id].title)
	_taskbar.set_active_button(app_id)
	var page: Control = window.get_content()
	if page != null and page.has_method("desktop_refresh"):
		page.call_deferred("desktop_refresh")
	app_focused.emit(app_id)

## 转发内容区或标题栏的激活请求。## 输入: app_id。输出: 无。
func _on_window_clicked(app_id: String) -> void:
	if _help_owner == app_id:
		open_app("help")
		return
	var window: ManagedWindow = get_app_window(app_id)
	if window != null and _active_app_id != app_id:
		_activate_window(window, app_id)

## 最小化后激活下一个可见窗口。## 输入: app_id。输出: 无。
func _on_window_minimized(app_id: String) -> void:
	if not _story_locked:
		var saved: Array[WeakRef] = _suspended_popups
		_suspended_popups = []
		_hide_owned_popups(get_app_window(app_id), true)
		_minimized_popups[app_id] = _suspended_popups
		_suspended_popups = saved
	if _active_app_id == app_id:
		_active_app_id = ""
		_focus_top_window()

## 选择堆叠顺序最上面的可见窗口。## 输入: 无。输出: 无。
func _focus_top_window() -> void:
	if not is_available():
		return
	var nodes: Array[Node] = _window_container.get_children()
	nodes.reverse()
	for node: Node in nodes:
		if node is ManagedWindow and node.visible and not node.is_shattering():
			_activate_window(node, node._app_id)
			return
	_taskbar.set_active_button("")

## 打开剧情或来源应用的帮助窗，并返回可复用正文。## 输入: story、source。输出: 对话视图。
func begin_dialogue(story: bool, source: Node) -> Control:
	_previous_app = _active_app_id
	var app_id: String = "unknown_program" if story else "help"
	if not open_app(app_id):
		return null
	var window: ManagedWindow = get_app_window(app_id)
	window.set_close_locked(true)
	window.set_minimize_locked(true)
	if story:
		_story_locked = true
		_taskbar.dismiss_start_menu()
		_hide_owned_popups(get_tree().root, true)
		for other_id: String in _open_windows:
			if other_id != app_id:
				get_app_window(other_id).process_mode = Node.PROCESS_MODE_DISABLED
		window.reparent(_modal_container)
		_modal_layer.show()
		window.fit_work_area()
		window.get_content().begin_story()
		return window.get_content().get_view()
	var parent: Node = source
	while parent != null and not parent is ManagedWindow:
		parent = parent.get_parent()
	if parent is ManagedWindow:
		_hide_owned_popups(parent, true)
		_help_owner = parent._app_id
		parent.process_mode = Node.PROCESS_MODE_DISABLED
	return window.get_content()

## 完成对话后恢复弹窗、学习现场及原先焦点。## 输入: story。输出: 无。
func end_dialogue(story: bool) -> void:
	if story:
		var window: ManagedWindow = get_app_window("unknown_program")
		_story_locked = false
		_modal_layer.hide()
		if window != null and not window.is_shattering():
			window.get_content().end_story()
			window.set_close_locked(false)
			window.set_minimize_locked(false)
			window.reparent(_window_container)
			window._on_minimize_pressed()
	else:
		_help_owner = ""
		_force_close("help")
	for app_id: String in _open_windows:
		get_app_window(app_id).process_mode = Node.PROCESS_MODE_INHERIT
	if not _previous_app.is_empty() and get_app_window(_previous_app) != null:
		open_app(_previous_app)
	for reference: WeakRef in _suspended_popups:
		var popup: Window = reference.get_ref() as Window
		if is_instance_valid(popup) and popup.get_parent().is_inside_tree():
			popup.show()
	_suspended_popups.clear()

## 隐藏所属窗口弹窗，剧情期间暂存可恢复对话框。## 输入: node、remember。输出: 无。
func _hide_owned_popups(node: Node, remember: bool) -> void:
	if node == null:
		return
	for child: Node in node.get_children():
		if child is Window and child.visible:
			if remember and not child is PopupMenu:
				_suspended_popups.append(weakref(child))
			child.hide()
		_hide_owned_popups(child, remember)

## 新的子窗口均嵌入游戏，剧情期间出现的异步弹窗也必须隐藏。## 输入: node。输出: 无。
func _on_node_added(node: Node) -> void:
	if node is Window and node != get_tree().root:
		if node is FileDialog:
			node.use_native_dialog = false
		node.visibility_changed.connect(_on_popup_visibility_changed.bind(weakref(node)))

## 防止异步回调产生的弹窗绕过剧情锁。## 输入: reference。输出: 无。
func _on_popup_visibility_changed(reference: WeakRef) -> void:
	var popup: Window = reference.get_ref() as Window
	if _story_locked and is_instance_valid(popup) and popup.visible:
		if not popup is PopupMenu:
			_suspended_popups.append(reference)
		popup.hide()

extends RefCounted
## 兼容独立运行与桌面宿主中的页面布局、导航和关闭行为。


## 打开共用的日期时间窗口，独立页面使用嵌入子窗口。## 输入: content (Node) - 请求打开的页面或任务栏。
## 输出: bool - 窗口成功打开或复用时返回 true。
static func open_time_settings(content: Node) -> bool:
	if WindowManager.is_available():
		return App.open_app("time_settings")
	var root: Window = content.get_tree().root
	var existing: Window = root.get_node_or_null("TimeSettingsStandalone") as Window
	if is_instance_valid(existing) and not existing.is_queued_for_deletion():
		existing.show()
		existing.grab_focus()
		return true
	root.gui_embed_subwindows = true
	var window: Window = Window.new()
	window.name = "TimeSettingsStandalone"
	window.title = "日期和时间"
	window.min_size = Vector2i(480, 400)
	window.size = Vector2i(720, 560)
	window.theme = UiSettings.runtime_theme
	window.close_requested.connect(window.queue_free)
	root.add_child(window)
	window.add_child(load("res://content/scenes/desktop/time_settings.tscn").instantiate())
	window.popup_centered()
	return true


## 查找提供页面导航与关闭信号的上级窗体。## 输入: content (Node) - 内容节点。
## 输出: Node - 宿主窗体；独立场景返回 null。
static func find_host(content: Node) -> Node:
	var parent: Node = content.get_parent()
	while parent != null:
		if parent.has_method("navigate_to") and parent.has_signal("close_requested"):
			return parent
		parent = parent.get_parent()
	return null


## 在调用者的宿主中导航；独立运行时沿用场景切换。## 输入: content (Node) - 调用者；path (String) - 场景路径。
## 输出: int - Godot 错误码。
static func navigate(content: Node, path: String) -> int:
	var host: Node = find_host(content)
	if host is ManagedWindow and WindowManager.is_available():
		return App.goto_scene(path)
	if host != null:
		return int(host.call("navigate_to", path))
	return content.get_tree().change_scene_to_file(path)


## 嵌入运行时隐去场景自己的桌面背景和重复标题栏。## 输入: content (Control) - 场景；frame (PanelContainer) - 窗体面板。
## 输出: 无。
static func adapt_content(content: Control, frame: PanelContainer) -> void:
	if find_host(content) == null:
		return
	content.get_node("DesktopBackground").hide()
	frame.get_node("FrameVBox/TitleBar").hide()
	frame.theme_type_variation = &""
	var margin: MarginContainer = content.find_child("RootMargin", true, false) as MarginContainer
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 0)

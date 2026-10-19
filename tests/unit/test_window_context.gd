extends GutTest
## 验证桌面嵌入与独立场景适配，不依赖某个桌面管理器实现。

const Context: GDScript = preload("res://src/ui/window_context.gd")

class HostWindow extends Control:
	signal close_requested()
	var last_path: String = ""

	## 记录宿主收到的页面导航。## 输入: path (String) - 场景路径。
	## 输出: int - 成功错误码。
	func navigate_to(path: String) -> int:
		last_path = path
		return OK


## 独立场景不被误判为宿主内的页面。## 输入: 无。
## 输出: 无。
func test_standalone_has_no_host() -> void:
	var scene: Control = autofree(Control.new())
	assert_null(Context.find_host(scene))


## 多层容器中查找正确宿主并向该宿主导航。## 输入: 无。
## 输出: 无。
func test_nested_page_navigates_in_its_host() -> void:
	var host: HostWindow = autofree(HostWindow.new())
	var container: Control = Control.new()
	var page: Control = Control.new()
	host.add_child(container)
	container.add_child(page)
	assert_same(Context.find_host(page), host)
	assert_eq(Context.navigate(page, "res://content/scenes/ui/settings.tscn"), OK)
	assert_eq(host.last_path, "res://content/scenes/ui/settings.tscn")


## 嵌入后保留宿主窗体，隐藏页面重复的背景和标题栏。## 输入: 无。
## 输出: 无。
func test_embedded_page_removes_duplicate_chrome() -> void:
	var host: HostWindow = autofree(HostWindow.new())
	var page: Control = Control.new()
	host.add_child(page)
	var background: Control = Control.new()
	background.name = "DesktopBackground"
	page.add_child(background)
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "RootMargin"
	margin.add_theme_constant_override("margin_left", 40)
	page.add_child(margin)
	var frame: PanelContainer = PanelContainer.new()
	frame.theme_type_variation = &"DesktopFrame"
	page.add_child(frame)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "FrameVBox"
	frame.add_child(vbox)
	var title: Control = Control.new()
	title.name = "TitleBar"
	vbox.add_child(title)
	Context.adapt_content(page, frame)
	assert_false(background.visible)
	assert_false(title.visible)
	assert_eq(frame.theme_type_variation, &"")
	assert_eq(margin.get_theme_constant("margin_left"), 0)

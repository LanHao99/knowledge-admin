extends Control
## 桌面入口，负责图标、任务栏工作区及缩放后的窗口布局。

@export var taskbar_height: float = 48.0
@export var application_sizes: Dictionary[String, Vector2] = {
	"knowledge_admin": Vector2(1440, 900), "ai_cards": Vector2(1220, 850),
	"control_panel": Vector2(1200, 880), "my_computer": Vector2(1000, 720),
	"recycle_bin": Vector2(820, 560), "unknown_program": Vector2(1180, 800),
	"help": Vector2(1100, 740),
	"window_lab": Vector2(900, 620),
	"story_test": Vector2(1100, 760),
	"camera": Vector2(560, 560),
}
var _shortcut_selection: ButtonGroup = ButtonGroup.new()
@onready var _window_container: Control = %WindowContainer
@onready var _taskbar: Control = %Taskbar

## 绑定桌面并生成场景实例化的快捷方式。## 输入: 无。输出: 无。
func _ready() -> void:
	WindowManager.setup(_window_container, _taskbar)
	_rebuild_shortcuts()
	if not DebugSettings.debug_mode_changed.is_connected(_on_debug_mode_changed):
		DebugSettings.debug_mode_changed.connect(_on_debug_mode_changed)
	resized.connect(_on_resized)
	_taskbar.resized.connect(_on_resized)
	UiSettings.font_scale_changed.connect(_on_font_scale_changed)
	if not WallpaperSettings.wallpaper_changed.is_connected(_apply_wallpaper):
		WallpaperSettings.wallpaper_changed.connect(_apply_wallpaper)
	_apply_wallpaper(WallpaperSettings.wallpaper_path, WallpaperSettings.display_mode)
	_on_resized.call_deferred()

## 桌面离开场景树时停止监听壁纸和调试模式，避免调用已释放节点。## 输入: 无。输出: 无。
func _exit_tree() -> void:
	if WallpaperSettings.wallpaper_changed.is_connected(_apply_wallpaper):
		WallpaperSettings.wallpaper_changed.disconnect(_apply_wallpaper)
	if DebugSettings.debug_mode_changed.is_connected(_on_debug_mode_changed):
		DebugSettings.debug_mode_changed.disconnect(_on_debug_mode_changed)

## 按当前调试模式重建桌面图标。## 输入: 无。
## 输出: 无。
func _rebuild_shortcuts() -> void:
	var grid: GridContainer = %DesktopIconGrid
	for child: Node in grid.get_children():
		grid.remove_child(child)
		child.free()
	var shortcut: PackedScene = preload("res://scenes/desktop/desktop_shortcut.tscn")
	for app_info: Dictionary in WindowManager.get_visible_apps():
		var entry: Button = shortcut.instantiate() as Button
		entry.button_group = _shortcut_selection
		entry.set_meta("app_id", app_info.app_id)
		grid.add_child(entry)
		entry.get_node("Layout/Icon").texture = load(app_info.icon_path) as Texture2D
		entry.get_node("Layout/Caption").text = app_info.title

## 调试模式变化后刷新入口。关闭时由 App 关掉测试台。## 输入: _enabled。
## 输出: 无。
func _on_debug_mode_changed(_enabled: bool) -> void:
	_rebuild_shortcuts()
	_on_resized()

## 按路径和显示方式更新桌面壁纸。无壁纸时露出青绿色底色。## 输入: path (String) - 壁纸路径，空字符串表示无壁纸；mode (int) - 铺满或原比例。输出: 无。
func _apply_wallpaper(path: String, mode: int) -> void:
	var layer := $WallpaperLayer as Control
	var wallpaper := %Wallpaper as TextureRect
	var texture := WallpaperSettings.load_texture(path)
	if texture == null:
		wallpaper.texture = null
		layer.visible = false
		return
	wallpaper.texture = texture
	if mode == WallpaperSettings.MODE_FIT:
		wallpaper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	else:
		wallpaper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	layer.visible = true

## 字体变化后等待容器布局，再调整工作区。## 输入: _value。输出: 无。
func _on_font_scale_changed(_value: float) -> void:
	_on_resized.call_deferred()

## 任务栏实际高度与窗口工作区保持一致。## 输入: 无。输出: 无。
func _on_resized() -> void:
	var bar_height: float = maxf(taskbar_height, _taskbar.get_node("TaskbarHBox").get_combined_minimum_size().y + 8.0)
	var grid: GridContainer = %DesktopIconGrid
	if grid.get_child_count() > 0:
		var item_height: float = (grid.get_child(0) as Control).get_combined_minimum_size().y
		grid.columns = maxi(1, ceili(item_height * grid.get_child_count() / maxf(200, size.y - bar_height - 30)))
	_taskbar.offset_top = -bar_height
	_window_container.offset_bottom = -bar_height
	$ModalLayer/ModalWindows.offset_bottom = -bar_height
	for app_id: String in WindowManager._open_windows:
		var window: ManagedWindow = WindowManager.get_app_window(app_id)
		if window != null:
			window.fit_work_area.call_deferred()

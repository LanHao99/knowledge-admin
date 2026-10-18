extends GutTest
## 验证壁纸列表、存档回退和桌面显示方式，不改写玩家的壁纸配置。

const SettingsScript: GDScript = preload("res://src/wallpaper_settings.gd")
const SAMPLE_WALLPAPER: String = "res://assets/wallpapers/leaf.jpg"

var _settings: Node
var _config_path: String = ""


## 使用独立设置实例和临时配置，避免碰到底层自动加载的存档。## 输入: 无。
## 输出: 无。
func before_each() -> void:
	_settings = autofree(SettingsScript.new())
	_config_path = "user://wallpaper_test_%d.cfg" % Time.get_ticks_usec()
	_settings.load_settings(_config_path)


## 停止延迟保存并删掉临时配置。## 输入: 无。
## 输出: 无。
func after_each() -> void:
	var timer: Timer = _settings.get("_save_timer") as Timer
	if is_instance_valid(timer):
		timer.stop()
	_settings.set("_dirty", false)
	if FileAccess.file_exists(_config_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_config_path))


## 验证壁纸目录里的图片都会被列出，且不带入 import 文件。## 输入: 无。
## 输出: 无。
func test_list_contains_wallpaper_images() -> void:
	var expected := PackedStringArray()
	var directory := DirAccess.open("res://assets/wallpapers")
	assert_not_null(directory)
	for file_name: String in directory.get_files():
		if ["png", "jpg", "jpeg", "webp"].has(file_name.get_extension().to_lower()):
			expected.append("res://assets/wallpapers".path_join(file_name))
	expected.sort()
	var paths: PackedStringArray = _settings.list_wallpapers()
	assert_gt(expected.size(), 0)
	assert_eq(paths, expected)


## 验证路径和显示方式可以写入后再被另一个实例读回。## 输入: 无。
## 输出: 无。
func test_configuration_round_trip() -> void:
	_settings.set_wallpaper(SAMPLE_WALLPAPER)
	_settings.set_display_mode(SettingsScript.MODE_FIT)
	assert_eq(_settings.save_settings(), OK)
	var reloaded: Node = autofree(SettingsScript.new())
	reloaded.load_settings(_config_path)
	assert_eq(reloaded.wallpaper_path, SAMPLE_WALLPAPER)
	assert_eq(reloaded.display_mode, SettingsScript.MODE_FIT)
	reloaded.set("_dirty", false)


## 验证失效路径和非法显示方式都会回到无壁纸、铺满。## 输入: 无。
## 输出: 无。
func test_invalid_path_and_mode_fall_back() -> void:
	var config := ConfigFile.new()
	config.set_value("wallpaper", "path", "res://assets/wallpapers/missing.jpg")
	config.set_value("wallpaper", "mode", 9)
	assert_eq(config.save(_config_path), OK)
	_settings.load_settings(_config_path)
	assert_eq(_settings.wallpaper_path, "")
	assert_eq(_settings.display_mode, SettingsScript.MODE_FILL)
	config.set_value("wallpaper", "path", SAMPLE_WALLPAPER)
	config.set_value("wallpaper", "mode", "fit")
	assert_eq(config.save(_config_path), OK)
	_settings.load_settings(_config_path)
	assert_eq(_settings.wallpaper_path, SAMPLE_WALLPAPER)
	assert_eq(_settings.display_mode, SettingsScript.MODE_FILL)
	_settings.set_wallpaper("res://icon.svg")
	assert_eq(_settings.wallpaper_path, SAMPLE_WALLPAPER)


## 验证重复选择不会再次通知，无法识别的方式会改回铺满。## 输入: 无。
## 输出: 无。
func test_duplicate_choice_is_quiet_and_invalid_mode_becomes_fill() -> void:
	watch_signals(_settings)
	_settings.set_wallpaper(SAMPLE_WALLPAPER)
	_settings.set_wallpaper(SAMPLE_WALLPAPER)
	assert_signal_emit_count(_settings, "wallpaper_changed", 1)
	_settings.set_display_mode(SettingsScript.MODE_FIT)
	_settings.set_display_mode(99)
	assert_eq(_settings.display_mode, SettingsScript.MODE_FILL)
	assert_signal_emit_count(_settings, "wallpaper_changed", 3)
	assert_null(_settings.load_texture(""))
	assert_not_null(_settings.load_texture(SAMPLE_WALLPAPER))


## 验证桌面在无壁纸、铺满和原比例之间切换纹理与拉伸方式。## 输入: 无。
## 输出: 无。
func test_desktop_applies_wallpaper_modes() -> void:
	var desktop := load("res://scenes/desktop/desktop.tscn").instantiate() as Control
	add_child_autofree(desktop)
	var layer := desktop.get_node("WallpaperLayer") as Control
	var wallpaper := desktop.get_node("%Wallpaper") as TextureRect
	var saved_path: String = WallpaperSettings.wallpaper_path
	var saved_mode: int = WallpaperSettings.display_mode
	desktop._apply_wallpaper("", SettingsScript.MODE_FILL)
	assert_false(layer.visible)
	assert_null(wallpaper.texture)
	desktop._apply_wallpaper(SAMPLE_WALLPAPER, SettingsScript.MODE_FILL)
	assert_true(layer.visible)
	assert_not_null(wallpaper.texture)
	assert_eq(wallpaper.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	assert_eq((layer.get_node("WallpaperBars") as ColorRect).color, Color(0, 0, 0, 1))
	WallpaperSettings.wallpaper_changed.emit(SAMPLE_WALLPAPER, SettingsScript.MODE_FIT)
	assert_eq(wallpaper.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	assert_eq(WallpaperSettings.wallpaper_path, saved_path)
	assert_eq(WallpaperSettings.display_mode, saved_mode)
	WallpaperSettings.wallpaper_changed.emit(saved_path, saved_mode)


## 验证控制面板仅列出无壁纸和已解锁图片，并按屏幕比例准备预览。## 输入: 无。
## 输出: 无。
func test_control_panel_lists_wallpapers_and_preview() -> void:
	var settings := load("res://scenes/ui/settings.tscn").instantiate() as Control
	add_child_autofree(settings)
	var wallpaper_list := settings.get_node("%WallpaperList") as ItemList
	assert_eq(wallpaper_list.get_item_text(0), "无壁纸")
	var available: int = 0
	for path: String in WallpaperSettings.list_wallpapers():
		if WallpaperSettings.is_wallpaper_unlocked(path):
			available += 1
	assert_eq(wallpaper_list.item_count, available + 1)
	for index: int in range(1, wallpaper_list.item_count):
		assert_true(WallpaperSettings.is_wallpaper_unlocked(str(wallpaper_list.get_item_metadata(index))))
	assert_eq(str(wallpaper_list.get_item_metadata(0)), "")
	assert_true(wallpaper_list.get_item_icon(1) != null)
	var ratio: AspectRatioContainer = settings.get_node("%WallpaperPreviewRatio") as AspectRatioContainer
	var viewport_size := settings.get_viewport().get_visible_rect().size
	assert_almost_eq(ratio.ratio, viewport_size.x / viewport_size.y, 0.001)
	var fill_check := settings.get_node("%WallpaperFillCheck") as CheckBox
	var fit_check := settings.get_node("%WallpaperFitCheck") as CheckBox
	assert_eq(fill_check.text, "铺满屏幕（保持比例，裁切边缘）")
	assert_eq(fit_check.text, "原始比例（可能有黑边）")
	if WallpaperSettings.wallpaper_path.is_empty():
		assert_true(fill_check.disabled)
		assert_true(fit_check.disabled)
		assert_false((settings.get_node("%WallpaperPreview") as CanvasItem).visible)


## 默认剧情图片不能被选择或读取纹理，普通壁纸不受限制。## 输入: 无。输出: 无。
func test_story_wallpapers_start_locked() -> void:
	for path: String in SettingsScript.LOCKED_BY_DEFAULT:
		assert_false(_settings.is_wallpaper_unlocked(path))
		_settings.set_wallpaper(path)
		assert_eq(_settings.wallpaper_path, "")
		assert_null(_settings.load_texture(path))
	assert_true(_settings.is_wallpaper_unlocked(SAMPLE_WALLPAPER))
	assert_false(_settings.unlock_wallpaper("res://icon.svg"))


## 领取立即持久化，重复领取不重复发信号，恢复后仍能切换。## 输入: 无。输出: 无。
func test_unlock_is_saved_before_wallpaper_selection() -> void:
	var path: String = SettingsScript.LOCKED_BY_DEFAULT[0]
	watch_signals(_settings)
	assert_true(_settings.unlock_wallpaper(path))
	assert_true(_settings.unlock_wallpaper(path))
	assert_signal_emit_count(_settings, "wallpaper_unlocked", 1)
	assert_eq(_settings.wallpaper_path, "")
	var reloaded: Node = autofree(SettingsScript.new())
	reloaded.load_settings(_config_path)
	assert_true(reloaded.is_wallpaper_unlocked(path))
	assert_false(reloaded.is_wallpaper_unlocked(SettingsScript.LOCKED_BY_DEFAULT[1]))
	reloaded.set_wallpaper(path)
	assert_eq(reloaded.wallpaper_path, path)
	assert_eq(reloaded.save_settings(), OK)
	_settings.load_settings(_config_path)
	assert_eq(_settings.wallpaper_path, path)
	reloaded.set("_dirty", false)


## 旧存档不会误解锁剧情图片，损坏的解锁项被过滤且不影响普通设置。## 输入: 无。输出: 无。
func test_legacy_and_invalid_unlock_records() -> void:
	var config: ConfigFile = ConfigFile.new()
	var path: String = SettingsScript.LOCKED_BY_DEFAULT[0]
	config.set_value("wallpaper", "path", path)
	assert_eq(config.save(_config_path), OK)
	_settings.load_settings(_config_path)
	assert_false(_settings.is_wallpaper_unlocked(path))
	assert_eq(_settings.wallpaper_path, "")
	config.set_value("wallpaper", "unlocked", [null, 3, "res://icon.svg", path, path])
	assert_eq(config.save(_config_path), OK)
	_settings.load_settings(_config_path)
	assert_eq(_settings.wallpaper_path, path)
	assert_eq(_settings.get("_unlocked_wallpapers"), PackedStringArray([path]))

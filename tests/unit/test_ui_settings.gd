extends GutTest
## 验证字体换算、富文本进度和配置异常，不使用正式玩家的配置文件。

const SettingsScript: GDScript = preload("res://src/ui_settings.gd")
var _settings: Node


## 创建不进入场景树的独立设置实例。## 输入: 无。
## 输出: 无。
func before_each() -> void:
	_settings = autofree(SettingsScript.new())
	_settings.settings_path = "user://ui_test_%d.cfg" % Time.get_ticks_usec()


## 验证语义字号与标准倍率。## 输入: 无。
## 输出: 无。
func test_default_typography() -> void:
	assert_eq(_settings.font_scale, 1.0)
	assert_eq(_settings.runtime_theme.default_font_size, 24)
	assert_eq(_settings.runtime_theme.get_font_size("font_size", "UiCaption"), 20)
	assert_eq(_settings.runtime_theme.get_font_size("font_size", "UiTitle"), 32)
	assert_eq(_settings.runtime_theme.get_font_size("font_size", "UiMetric"), 40)


## 验证边界、步进和非法浮点数。## 输入: 无。
## 输出: 无。
func test_scale_bounds_and_step() -> void:
	assert_almost_eq(SettingsScript.normalize_scale(0.1), 0.8, 0.001)
	assert_almost_eq(SettingsScript.normalize_scale(2.0), 1.5, 0.001)
	assert_almost_eq(SettingsScript.normalize_scale(1.12), 1.1, 0.001)
	assert_eq(SettingsScript.normalize_scale(NAN), 1.0)
	assert_eq(SettingsScript.normalize_scale(INF), 1.0)


## 验证多次缩放不累计误差，源资源和运行时资源身份保持稳定。## 输入: 无。
## 输出: 无。
func test_repeated_scaling_preserves_baseline_and_resource_identity() -> void:
	var theme_id: int = _settings.runtime_theme.get_instance_id()
	for _iteration: int in range(12):
		_settings.set_font_scale(1.5)
		assert_eq(_settings.runtime_theme.get_font_size("font_size", "UiMetric"), 60)
		_settings.set_font_scale(0.8)
		assert_eq(_settings.runtime_theme.get_font_size("font_size", "UiMetric"), 32)
		_settings.reset_font_scale()
		assert_eq(_settings.runtime_theme.get_font_size("font_size", "UiMetric"), 40)
	assert_eq(_settings.runtime_theme.get_instance_id(), theme_id)
	assert_eq(SettingsScript.BASE_THEME.get_font_size("font_size", "UiMetric"), 40)


## 验证粗体、斜体和等宽正文都使用同一倍率。## 输入: 无。
## 输出: 无。
func test_all_rich_text_faces_scale_together() -> void:
	_settings.set_font_scale(1.5)
	for key: String in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
		assert_eq(_settings.runtime_theme.get_font_size(key, "UiCardText"), 48)
		assert_eq(_settings.runtime_theme.get_font_size(key, "UiDialogueText"), 42)


## 验证字体设置可以被另一实例读取，模拟应用重启。## 输入: 无。
## 输出: 无。
func test_configuration_round_trip() -> void:
	_settings.set_font_scale(1.35)
	assert_eq(_settings.save_settings(), OK)
	var reloaded: Node = autofree(SettingsScript.new())
	reloaded.load_settings(_settings.settings_path)
	assert_almost_eq(reloaded.font_scale, 1.35, 0.001)
	assert_eq(reloaded.runtime_theme.get_font_size("font_size", "UiTitle"), 43)


## 验证配置不存在时恢复默认值。## 输入: 无。
## 输出: 无。
func test_missing_configuration_uses_default() -> void:
	_settings.set_font_scale(1.5)
	_settings.load_settings("user://missing_ui_%d.cfg" % Time.get_ticks_usec())
	assert_eq(_settings.font_scale, 1.0)


## 验证损坏配置回退，确认底层解析错误已被捕获。## 输入: 无。
## 输出: 无。
func test_corrupt_configuration_uses_default() -> void:
	var file: FileAccess = FileAccess.open(_settings.settings_path, FileAccess.WRITE)
	file.store_string("[appearance\nfont_scale=1.5")
	file.close()
	_settings.load_settings(_settings.settings_path)
	assert_eq(_settings.font_scale, 1.0)
	assert_engine_error_count(1)


## 验证配置类型错误与越界数值。## 输入: 无。
## 输出: 无。
func test_configuration_type_and_range() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("appearance", "font_scale", "large")
	config.save(_settings.settings_path)
	_settings.load_settings(_settings.settings_path)
	assert_eq(_settings.font_scale, 1.0)
	config.set_value("appearance", "font_scale", 10.0)
	config.save(_settings.settings_path)
	_settings.load_settings(_settings.settings_path)
	assert_eq(_settings.font_scale, 1.5)


## 验证保存失败通知且当前字号继续生效。## 输入: 无。
## 输出: 无。
func test_save_failure_keeps_current_scale() -> void:
	watch_signals(_settings)
	_settings.settings_path = "user://missing_ui_directory_%d/ui.cfg" % Time.get_ticks_usec()
	_settings.set_font_scale(1.2)
	assert_ne(_settings.save_settings(), OK)
	assert_signal_emitted(_settings, "settings_save_failed")
	assert_almost_eq(_settings.font_scale, 1.2, 0.001)


## 验证动态窗口和普通控件共用主题资源。## 输入: 无。
## 输出: 无。
func test_control_and_window_share_runtime_theme() -> void:
	var control: Control = autofree(Control.new())
	var window: Window = autofree(Window.new())
	_settings.apply_theme(control)
	_settings.apply_theme(window)
	assert_same(control.theme, window.theme)
	assert_same(control.theme, _settings.runtime_theme)


## 验证大字号弹窗的标题栏高度与原始纹理资源隔离。## 输入: 无。
## 输出: 无。
func test_window_titlebar_fits_scaled_font() -> void:
	var baseline: StyleBoxTexture = SettingsScript.BASE_THEME.get_stylebox("embedded_border", "Window") as StyleBoxTexture
	for scale: float in [0.8, 1.0, 1.5]:
		_settings.set_font_scale(scale)
		var border: StyleBoxTexture = _settings.runtime_theme.get_stylebox("embedded_border", "Window") as StyleBoxTexture
		var title_height: int = _settings.runtime_theme.get_constant("title_height", "Window")
		assert_gte(title_height, _settings.runtime_theme.get_font_size("title_font_size", "Window") + 8)
		assert_almost_eq(border.expand_margin_top, float(title_height), 0.001)
	assert_eq(baseline.expand_margin_top, 21.0)
	assert_eq(baseline.texture.get_image().get_size(), Vector2i(10, 25))


## 验证显式字号、颜色和强调格式，原文保持不变。## 输入: 无。
## 输出: 无。
func test_bbcode_sizes_and_formatting() -> void:
	var original: String = "[color=red][b][font_size=24]中文[/font_size][/b][/color] [font_size=16]ABC[/font_size]"
	_settings.set_font_scale(1.5)
	assert_eq(_settings.scale_bbcode_font_sizes(original), original.replace("=24]", "=36]").replace("=16]", "=24]"))
	_settings.reset_font_scale()
	assert_eq(_settings.scale_bbcode_font_sizes(original), original)


## 验证显示中调整字号不会丢失打字机字符进度或累计缩放。## 输入: 无。
## 输出: 无。
func test_rich_text_refresh_preserves_visible_characters() -> void:
	var label: RichTextLabel = autofree(RichTextLabel.new())
	label.bbcode_enabled = true
	label.visible_characters = 3
	_settings.set_rich_text(label, "[font_size=24]一段正在显示的文字[/font_size]")
	_settings.set_font_scale(1.5)
	assert_eq(label.visible_characters, 3)
	assert_string_contains(label.text, "[font_size=36]")
	_settings.set_font_scale(0.8)
	assert_string_contains(label.text, "[font_size=19]")
	_settings.reset_font_scale()
	assert_string_contains(label.text, "[font_size=24]")
	assert_eq(label.visible_characters, 3)


## 验证相同倍率不重复广播，释放过的富文本不会引起错误。## 输入: 无。
## 输出: 无。
func test_unchanged_scale_and_freed_rich_text() -> void:
	watch_signals(_settings)
	_settings.set_font_scale(1.0)
	assert_signal_not_emitted(_settings, "font_scale_changed")
	var label: RichTextLabel = RichTextLabel.new()
	_settings.set_rich_text(label, "文字")
	label.free()
	_settings.set_font_scale(1.5)
	assert_signal_emitted(_settings, "font_scale_changed")
	assert_engine_error_count(0)

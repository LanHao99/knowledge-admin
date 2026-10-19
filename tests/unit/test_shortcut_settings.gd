extends GutTest
## 验证学习快捷键的默认值、冲突、存档和按状态分发。

const SettingsScript: GDScript = preload("res://src/shortcut_settings.gd")
const StudyScript: GDScript = preload("res://src/ui/study.gd")

var _settings: Node


## 使用独立配置，避免写到玩家的快捷键存档。## 输入: 无。
## 输出: 无。
func before_each() -> void:
	var created: Node = SettingsScript.new()
	created.settings_path = "user://shortcut_test_%d.cfg" % Time.get_ticks_usec()
	_settings = autofree(created)


## 删除测试配置。## 输入: 无。
## 输出: 无。
func after_each() -> void:
	if _settings != null and FileAccess.file_exists(_settings.settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_settings.settings_path))


## 验证默认键是空格、1 到 4 和 Esc。## 输入: 无。
## 输出: 无。
func test_default_bindings() -> void:
	assert_eq(_settings.get_display_text(ShortcutSettings.ACTION_FLIP), "空格")
	assert_eq(_settings.get_display_text(ShortcutSettings.ACTION_AGAIN), "1")
	assert_eq(_settings.get_display_text(ShortcutSettings.ACTION_HARD), "2")
	assert_eq(_settings.get_display_text(ShortcutSettings.ACTION_GOOD), "3")
	assert_eq(_settings.get_display_text(ShortcutSettings.ACTION_EASY), "4")
	assert_eq(_settings.get_display_text(ShortcutSettings.ACTION_EXIT), "Esc")
	assert_eq(_settings.get_display_text(ShortcutSettings.ACTION_SAVE_DOCUMENT), "Ctrl+S")
	assert_eq(_settings.match_action(_key(KEY_SPACE)), ShortcutSettings.ACTION_FLIP)
	assert_eq(_settings.match_action(_key(KEY_4)), ShortcutSettings.ACTION_EASY)
	assert_eq(_settings.match_action(_key(KEY_ESCAPE)), ShortcutSettings.ACTION_EXIT)
	assert_eq(_settings.match_action(_key(KEY_S, false, true)), ShortcutSettings.ACTION_SAVE_DOCUMENT)
	assert_eq(_settings.match_action(_key(KEY_S)), &"")
	var echo := _key(KEY_SPACE)
	echo.echo = true
	assert_eq(_settings.match_action(echo), &"")


## 验证冲突不会覆盖原绑定，清除后才能改到同一键。## 输入: 无。
## 输出: 无。
func test_conflict_is_rejected_until_cleared() -> void:
	var result: Dictionary = _settings.set_binding(ShortcutSettings.ACTION_FLIP, _key(KEY_1))
	assert_false(bool(result.get("ok", true)))
	assert_eq(str(result.get("error", "")), "CONFLICT")
	assert_eq(_settings.match_action(_key(KEY_SPACE)), ShortcutSettings.ACTION_FLIP)
	assert_eq(_settings.clear_binding(ShortcutSettings.ACTION_AGAIN), OK)
	result = _settings.set_binding(ShortcutSettings.ACTION_FLIP, _key(KEY_1))
	assert_true(bool(result.get("ok", false)))
	assert_eq(_settings.match_action(_key(KEY_1)), ShortcutSettings.ACTION_FLIP)
	assert_eq(_settings.match_action(_key(KEY_SPACE)), &"")


## 验证修饰键组合可以保存并在重新读取后匹配。## 输入: 无。
## 输出: 无。
func test_modifier_round_trip() -> void:
	var chord := _key(KEY_F, true, true)
	var result: Dictionary = _settings.set_binding(ShortcutSettings.ACTION_FLIP, chord)
	assert_true(bool(result.get("ok", false)))
	assert_eq(_settings.get_display_text(ShortcutSettings.ACTION_FLIP), "Ctrl+Shift+F")
	assert_eq(_settings.match_action(_key(KEY_F)), &"")
	var reloaded: Node = SettingsScript.new()
	reloaded.load_settings(_settings.settings_path)
	autofree(reloaded)
	assert_eq(reloaded.get_display_text(ShortcutSettings.ACTION_FLIP), "Ctrl+Shift+F")
	assert_eq(reloaded.match_action(chord), ShortcutSettings.ACTION_FLIP)


## 验证单独的修饰键、清除和恢复默认。## 输入: 无。
## 输出: 无。
func test_modifier_clear_and_reset() -> void:
	var rejected: Dictionary = _settings.set_binding(ShortcutSettings.ACTION_FLIP, _key(KEY_CTRL))
	assert_false(bool(rejected.get("ok", true)))
	assert_eq(_settings.get_display_text(ShortcutSettings.ACTION_FLIP), "空格")
	assert_eq(_settings.clear_binding(ShortcutSettings.ACTION_EXIT), OK)
	assert_eq(_settings.get_display_text(ShortcutSettings.ACTION_EXIT), "")
	assert_eq(_settings.reset_defaults(), OK)
	assert_eq(_settings.get_display_text(ShortcutSettings.ACTION_EXIT), "Esc")
	assert_eq(SettingsScript.format_binding({"keycode": KEY_KP_1}, true), "小键盘 1")


## 验证损坏文件恢复默认，单条非法值或冲突只放弃该条。## 输入: 无。
## 输出: 无。
func test_corrupt_partial_and_conflict_on_load() -> void:
	var file: FileAccess = FileAccess.open(_settings.settings_path, FileAccess.WRITE)
	file.store_string("[bindings\nflip_card=\"Space\"")
	file.close()
	_settings.load_settings(_settings.settings_path)
	assert_eq(_settings.get_display_text(ShortcutSettings.ACTION_FLIP), "空格")
	assert_engine_error_count(1)

	var config := ConfigFile.new()
	config.set_value("bindings", "flip_card", 5)
	config.set_value("bindings", "rate_again", "Q")
	config.set_value("bindings", "exit_study", "")
	assert_eq(config.save(_settings.settings_path), OK)
	_settings.load_settings(_settings.settings_path)
	assert_eq(_settings.get_display_text(ShortcutSettings.ACTION_FLIP), "空格")
	assert_eq(_settings.get_display_text(ShortcutSettings.ACTION_AGAIN), "Q")
	assert_eq(_settings.get_display_text(ShortcutSettings.ACTION_EXIT), "")
	assert_eq(_settings.get_display_text(ShortcutSettings.ACTION_GOOD), "3")

	config.set_value("bindings", "flip_card", "1")
	config.set_value("bindings", "rate_again", "1")
	config.set_value("bindings", "exit_study", "Escape")
	assert_eq(config.save(_settings.settings_path), OK)
	_settings.load_settings(_settings.settings_path)
	assert_eq(_settings.match_action(_key(KEY_1)), ShortcutSettings.ACTION_FLIP)
	assert_eq(_settings.get_display_text(ShortcutSettings.ACTION_AGAIN), "")
	assert_eq(_settings.get_display_text(ShortcutSettings.ACTION_EXIT), "Esc")


## 验证保存失败时内存绑定仍然生效。## 输入: 无。
## 输出: 无。
func test_save_failure_keeps_binding() -> void:
	watch_signals(_settings)
	_settings.settings_path = "user://missing_shortcut_dir_%d/shortcuts.cfg" % Time.get_ticks_usec()
	var result: Dictionary = _settings.set_binding(ShortcutSettings.ACTION_FLIP, _key(KEY_F))
	assert_true(bool(result.get("ok", false)))
	assert_eq(str(result.get("error", "")), "SAVE_FAILED")
	assert_signal_emitted(_settings, "settings_save_failed")
	assert_eq(_settings.match_action(_key(KEY_F)), ShortcutSettings.ACTION_FLIP)


## 验证正面不评分、背面不翻面，对话等阻塞时不退出。## 输入: 无。
## 输出: 无。
func test_shortcut_effect_follows_card_state() -> void:
	assert_eq(StudyScript.resolve_shortcut(false, ShortcutSettings.ACTION_FLIP, true, false, true, false), &"flip")
	assert_eq(StudyScript.resolve_shortcut(false, ShortcutSettings.ACTION_FLIP, true, false, false, true), &"consume")
	assert_eq(StudyScript.resolve_shortcut(false, ShortcutSettings.ACTION_AGAIN, true, false, true, false), &"consume")
	assert_eq(StudyScript.resolve_shortcut(false, ShortcutSettings.ACTION_EASY, true, false, false, true), &"rate")
	assert_eq(StudyScript.resolve_shortcut(false, ShortcutSettings.ACTION_EXIT, true, false, false, true), &"exit")
	assert_eq(StudyScript.resolve_shortcut(false, ShortcutSettings.ACTION_EXIT, false, true, false, false), &"back")
	assert_eq(StudyScript.resolve_shortcut(false, ShortcutSettings.ACTION_EXIT, false, false, false, false), &"ignore")
	assert_eq(StudyScript.resolve_shortcut(true, ShortcutSettings.ACTION_EXIT, true, false, true, false), &"ignore")
	assert_eq(StudyScript.resolve_shortcut(false, ShortcutSettings.ACTION_SAVE_DOCUMENT, true, false, true, false), &"ignore")
	assert_eq(StudyScript.rating_for_action(ShortcutSettings.ACTION_HARD), CardEntity.RATING_HARD)


## 验证控制面板场景里有快捷键标签，并且列出七项动作。## 输入: 无。
## 输出: 无。
func test_settings_scene_has_shortcut_tab() -> void:
	var scene: Control = load("res://content/scenes/ui/settings.tscn").instantiate()
	add_child(scene)
	var tabs := scene.find_child("SettingsTabs", true, false) as TabContainer
	assert_not_null(tabs)
	var names: PackedStringArray = PackedStringArray()
	for child: Node in tabs.get_children():
		names.append(child.name)
	assert_true(names.has("快捷键"))
	var rows := scene.find_child("ShortcutRows", true, false) as VBoxContainer
	assert_eq(rows.get_child_count(), 7)
	assert_eq((rows.get_child(0).get_child(1) as Button).text, "空格")
	var save_title: Label = rows.get_child(6).get_child(0).get_child(0) as Label
	assert_eq(save_title.text, "保存文档")
	scene.free()


## 验证文本框、开始菜单和确认框会挡住快捷键。## 输入: 无。
## 输出: 无。
func test_focus_menu_and_dialog_block_shortcuts() -> void:
	assert_true(ShortcutSettings.focus_blocks_shortcuts(autofree(LineEdit.new())))
	assert_true(ShortcutSettings.focus_blocks_shortcuts(autofree(TextEdit.new())))
	assert_false(ShortcutSettings.focus_blocks_shortcuts(autofree(Button.new())))
	var menu := Control.new()
	add_child(menu)
	menu.add_to_group(&"start_menu")
	menu.visible = true
	assert_true(ShortcutSettings.start_menu_blocks(get_tree()))
	menu.visible = false
	assert_false(ShortcutSettings.start_menu_blocks(get_tree()))
	menu.free()
	var host: Node = autofree(Node.new())
	var dialog := ConfirmationDialog.new()
	host.add_child(dialog)
	dialog.visible = false
	assert_false(ShortcutSettings.visible_dialog_blocks(host))
	dialog.visible = true
	assert_true(ShortcutSettings.visible_dialog_blocks(host))


## 构造一次按下的键盘事件。## 输入:
##   code (Key) - 键码。
##   shift_pressed (bool) - 是否按住 Shift。
##   ctrl_pressed (bool) - 是否按住 Ctrl。
## 输出: InputEventKey - 按下事件。
func _key(code: Key, shift_pressed: bool = false, ctrl_pressed: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	event.physical_keycode = code
	event.shift_pressed = shift_pressed
	event.ctrl_pressed = ctrl_pressed
	return event

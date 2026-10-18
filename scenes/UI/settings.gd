extends Control
## 设置场景。管理调试模式开关、教程重置、应用信息展示。

const WindowContext: GDScript = preload("res://src/ui/window_context.gd")


# ── 节点引用 ──

@onready var _back_button: Button = %BackButton
@onready var _debug_check: CheckButton = %DebugCheck
@onready var _debug_console_btn: Button = %DebugConsoleButton
@onready var _reset_tutorial_btn: Button = %ResetTutorialBtn
@onready var _reset_tutorial_confirm: ConfirmationDialog = %ResetTutorialConfirm
@onready var _status_label: Label = %StatusLabel
@onready var _font_slider: HSlider = %FontScaleSlider
@onready var _font_value: Label = %FontScaleValue
@onready var _decrease_font: Button = %DecreaseFontButton
@onready var _increase_font: Button = %IncreaseFontButton
@onready var _reset_font: Button = %ResetFontButton
@onready var _meta_extras: VBoxContainer = %MetaExtras
@onready var _shortcut_rows: VBoxContainer = %ShortcutRows
@onready var _reset_shortcuts: Button = %ResetShortcutsButton

var _listening_action: StringName = &""
var _shortcut_buttons: Dictionary = {}


# ── 生命周期 ──


## 初始化信号连接、加载当前设置、检查教程。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	WindowContext.adapt_content(self, %SettingsFrame)
	%CloseSettingsButton.pressed.connect(_on_back_pressed)
	%SettingsCenter.resized.connect(_schedule_settings_layout)
	_schedule_settings_layout()
	_font_slider.value_changed.connect(_on_font_scale_requested)
	_decrease_font.pressed.connect(_on_decrease_font_pressed)
	_increase_font.pressed.connect(_on_increase_font_pressed)
	_reset_font.pressed.connect(UiSettings.reset_font_scale)
	UiSettings.font_scale_changed.connect(_sync_font_controls)
	UiSettings.settings_save_failed.connect(_on_font_save_failed)
	UiSettings.settings_saved.connect(_on_font_settings_saved)
	_sync_font_controls(UiSettings.font_scale)
	_connect_signals()
	_load_current_settings()
	_rebuild_meta_extras()
	if not App.flags_changed.is_connected(_on_flags_changed):
		App.flags_changed.connect(_on_flags_changed)
	_setup_shortcuts()
	TutorialManager.check_and_show("settings", self)


## 离开设置时断开标记信号。## 输入: 无。
## 输出: 无。
func _exit_tree() -> void:
	if App.flags_changed.is_connected(_on_flags_changed):
		App.flags_changed.disconnect(_on_flags_changed)
	if ShortcutSettings.bindings_changed.is_connected(_refresh_shortcut_buttons):
		ShortcutSettings.bindings_changed.disconnect(_refresh_shortcut_buttons)
	if ShortcutSettings.settings_save_failed.is_connected(_on_shortcut_save_failed):
		ShortcutSettings.settings_save_failed.disconnect(_on_shortcut_save_failed)
	if WindowManager.app_focused.is_connected(_on_shortcut_app_focused):
		WindowManager.app_focused.disconnect(_on_shortcut_app_focused)


# ── 信号连接 ──


## 连接 UI 控件信号与全局 DebugSettings 信号。## 输入: 无。
## 输出: 无。
func _connect_signals() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_debug_check.toggled.connect(_on_debug_toggled)
	_debug_console_btn.pressed.connect(_on_debug_console_pressed)
	_reset_tutorial_btn.pressed.connect(_on_reset_tutorial_pressed)
	_reset_tutorial_confirm.confirmed.connect(_on_reset_tutorial_confirmed)
	DebugSettings.debug_mode_changed.connect(_on_external_debug_changed)


# ── 设置加载 ──


## 从 DebugSettings autoload 同步调试模式开关状态到 UI。## 输入: 无。
## 输出: 无。
func _load_current_settings() -> void:
	_debug_check.button_pressed = DebugSettings.debug_mode
	_sync_debug_console_button(DebugSettings.debug_mode)


# ── 按钮回调 ──


## 返回主菜单；嵌在桌面窗口里时关闭控制面板，而不是切掉整个场景。## 输入: 无。
## 输出: 无。
func _on_back_pressed() -> void:
	if WindowContext.find_host(self) != null:
		App.close_app("control_panel")
		return
	_set_status("正在返回主菜单…")
	_switch_scene("res://scenes/ui/main_menu.tscn", "主菜单")


## 调试模式开关切换回调，写入 DebugSettings autoload。## 输入: enabled (bool) — 目标状态。
## 输出: 无。
func _on_debug_toggled(enabled: bool) -> void:
	DebugSettings.set_debug_mode(enabled)
	_sync_debug_console_button(enabled)


## 调试功能开启后才能进入调试台。## 输入: enabled (bool) - 调试功能是否开启。
## 输出: 无。
func _sync_debug_console_button(enabled: bool) -> void:
	if _debug_console_btn != null:
		_debug_console_btn.disabled = not enabled


## 在当前窗口或独立场景中打开调试台。## 输入: 无。
## 输出: 无。
func _on_debug_console_pressed() -> void:
	if not DebugSettings.debug_mode:
		return
	var result: int = WindowContext.navigate(self, "res://scenes/ui/debug_crud_panel.tscn")
	if result != OK:
		_set_status("打开调试台失败 (%d)" % result)


## 重置教程按钮回调，弹出确认对话框。## 输入: 无。
## 输出: 无。
func _on_reset_tutorial_pressed() -> void:
	_reset_tutorial_confirm.popup_centered()


## 确认对话框确认回调，执行教程重置并更新状态栏。## 输入: 无。
## 输出: 无。
func _on_reset_tutorial_confirmed() -> void:
	TutorialManager.reset_all()
	_set_status("所有教程已重置")


## 外部（其他场景）修改调试模式时同步 UI 开关状态。## 输入: enabled (bool) — 当前调试模式状态。
## 输出: 无。
func _on_external_debug_changed(enabled: bool) -> void:
	_debug_check.button_pressed = enabled
	_sync_debug_console_button(enabled)


## 标记变化后重建设置附加行。## 输入:
##   _flag_name (String) - 发生变化的标记名。
##   _value (Variant) - 新值。
## 输出: 无。
func _on_flags_changed(_flag_name: String, _value: Variant) -> void:
	_rebuild_meta_extras()


## 按主逻辑规则表，在固定设置行下面动态加控件。## 输入: 无。
## 输出: 无。
func _rebuild_meta_extras() -> void:
	if _meta_extras == null:
		return
	for child in _meta_extras.get_children():
		child.queue_free()
	var extras: Array[Dictionary] = App.get_setting_extras()
	for item: Dictionary in extras:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var label := Label.new()
		label.text = str(item.get("label", ""))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.theme_type_variation = &"UiBody"
		row.add_child(label)
		var control_type := str(item.get("control", "label"))
		if control_type == "check":
			var flag_name := str(item.get("flag", ""))
			var check := CheckButton.new()
			check.set_pressed_no_signal(bool(App.get_flag(flag_name, false)))
			check.toggled.connect(_on_extra_check_toggled.bind(flag_name))
			row.add_child(check)
		_meta_extras.add_child(row)


## 动态勾选行写回世界标记。## 输入:
##   pressed (bool) - 勾选状态。
##   flag_name (String) - 要写入的标记名。
## 输出: 无。
func _on_extra_check_toggled(pressed: bool, flag_name: String) -> void:
	if flag_name.is_empty():
		return
	App.set_flag(flag_name, pressed)


# ── 工具方法 ──


## 安全切换到目标场景，文件不存在时更新状态提示。## 输入:
##   path (String) — 场景文件路径。
##   label (String) — 场景名称用于提示。
## 输出: 无。
func _switch_scene(path: String, label: String) -> void:
	if not ResourceLoader.exists(path):
		_set_status("场景不存在: %s" % label)
		return
	var result: int = WindowContext.navigate(self, path)
	if result != OK:
		_set_status("跳转 %s 失败 (err=%d)" % [label, result])


## 录制快捷键时吃掉按键；确认框和失去焦点的控制面板不拦截。## 输入: event (InputEvent) - 输入事件。
## 输出: 无。
func _input(event: InputEvent) -> void:
	if _listening_action == &"" or not _shortcut_capture_allowed():
		return
	if get_tree() != null and ShortcutSettings.visible_dialog_blocks(get_tree().root):
		return
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed:
		return
	get_viewport().set_input_as_handled()
	if key.echo:
		return
	var code := key.keycode if key.keycode != KEY_NONE else key.physical_keycode
	var unmodified := not key.shift_pressed and not key.ctrl_pressed and not key.alt_pressed and not key.meta_pressed
	if unmodified and (code == KEY_BACKSPACE or code == KEY_DELETE):
		var clear_error := ShortcutSettings.clear_binding(_listening_action)
		_listening_action = &""
		_refresh_shortcut_buttons()
		if clear_error != OK:
			return
		_set_status("已清除快捷键")
		_status_label.theme_type_variation = &"UiMuted"
		return
	var result := ShortcutSettings.set_binding(_listening_action, key)
	if not bool(result.get("ok", false)):
		if str(result.get("error", "")) == "CONFLICT":
			var owner := ShortcutSettings.get_action_label(StringName(result.get("conflict_action", "")))
			_set_status("该按键已被「%s」使用" % owner)
			_status_label.theme_type_variation = &"UiError"
		return
	_listening_action = &""
	_refresh_shortcut_buttons()
	if str(result.get("error", "")) == "SAVE_FAILED":
		return
	_set_status("快捷键已保存")
	_status_label.theme_type_variation = &"UiMuted"


## 只有当前控制面板可以录制，避免后台窗口抢走按键。## 输入: 无。
## 输出: bool - 可以录制时返回 true。
func _shortcut_capture_allowed() -> bool:
	if not is_visible_in_tree():
		return false
	if WindowManager.is_available() and WindowManager.get_active_app_id() != "control_panel":
		return false
	return true


## 生成快捷键行并监听绑定变化。## 输入: 无。
## 输出: 无。
func _setup_shortcuts() -> void:
	_build_shortcut_rows()
	if not ShortcutSettings.bindings_changed.is_connected(_refresh_shortcut_buttons):
		ShortcutSettings.bindings_changed.connect(_refresh_shortcut_buttons)
	if not ShortcutSettings.settings_save_failed.is_connected(_on_shortcut_save_failed):
		ShortcutSettings.settings_save_failed.connect(_on_shortcut_save_failed)
	if not WindowManager.app_focused.is_connected(_on_shortcut_app_focused):
		WindowManager.app_focused.connect(_on_shortcut_app_focused)
	_reset_shortcuts.pressed.connect(_on_reset_shortcuts_pressed)


## 按动作表生成可录制的行。## 输入: 无。
## 输出: 无。
func _build_shortcut_rows() -> void:
	if _shortcut_rows == null:
		return
	for child: Node in _shortcut_rows.get_children():
		child.free()
	_shortcut_buttons.clear()
	for action: StringName in ShortcutSettings.get_actions():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var text_col := VBoxContainer.new()
		text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := Label.new()
		title.text = ShortcutSettings.get_action_label(action)
		title.theme_type_variation = &"UiBody"
		var hint := Label.new()
		hint.text = ShortcutSettings.get_action_hint(action)
		hint.theme_type_variation = &"UiMuted"
		text_col.add_child(title)
		text_col.add_child(hint)
		row.add_child(text_col)
		var button := Button.new()
		button.custom_minimum_size = Vector2(180, 44)
		button.pressed.connect(_on_shortcut_button_pressed.bind(action))
		row.add_child(button)
		_shortcut_rows.add_child(row)
		_shortcut_buttons[action] = button
	_refresh_shortcut_buttons()


## 刷新录制按钮上的当前按键。## 输入: 无。
## 输出: 无。
func _refresh_shortcut_buttons() -> void:
	for action: StringName in _shortcut_buttons:
		var button := _shortcut_buttons[action] as Button
		if button == null:
			continue
		if action == _listening_action:
			button.text = "请按键…"
			continue
		var label := ShortcutSettings.get_display_text(action)
		button.text = "未设置" if label.is_empty() else label


## 开始或取消某一行的录制。## 输入: action (StringName) - 被点击的动作。
## 输出: 无。
func _on_shortcut_button_pressed(action: StringName) -> void:
	if _listening_action == action:
		_listening_action = &""
		_refresh_shortcut_buttons()
		_set_status("已取消录制")
		_status_label.theme_type_variation = &"UiMuted"
		return
	_listening_action = action
	_refresh_shortcut_buttons()
	_set_status("请按下新的快捷键")
	_status_label.theme_type_variation = &"UiMuted"


## 恢复默认快捷键。## 输入: 无。
## 输出: 无。
func _on_reset_shortcuts_pressed() -> void:
	_listening_action = &""
	var error := ShortcutSettings.reset_defaults()
	_refresh_shortcut_buttons()
	if error != OK:
		return
	_set_status("已恢复默认快捷键")
	_status_label.theme_type_variation = &"UiMuted"


## 控制面板失焦时结束录制，避免下一次按键写到错误窗口。## 输入: app_id (String) - 新的活动应用。
## 输出: 无。
func _on_shortcut_app_focused(app_id: String) -> void:
	if app_id == "control_panel" or _listening_action == &"":
		return
	_listening_action = &""
	_refresh_shortcut_buttons()


## 快捷键已生效但配置没有写入。## 输入: _error (int) - 保存错误码。
## 输出: 无。
func _on_shortcut_save_failed(_error: int) -> void:
	_set_status("快捷键已应用，但暂时无法保存。")
	_status_label.theme_type_variation = &"UiError"


## 设置底部纯文本状态。## 输入: text (String) — 状态文本。
## 输出: 无。
func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


## 用户拖动滑块或使用键盘时立即调整字号。## 输入: value (float) - 新倍率。
## 输出: 无。
func _on_font_scale_requested(value: float) -> void:
	UiSettings.set_font_scale(value)


## 减少一个字号步进。## 输入: 无。
## 输出: 无。
func _on_decrease_font_pressed() -> void:
	UiSettings.set_font_scale(UiSettings.font_scale - UiSettings.SCALE_STEP)


## 增加一个字号步进。## 输入: 无。
## 输出: 无。
func _on_increase_font_pressed() -> void:
	UiSettings.set_font_scale(UiSettings.font_scale + UiSettings.SCALE_STEP)


## 同步滑块和按钮，不反向触发值变化。## 输入: value (float) - 当前倍率。
## 输出: 无。
func _sync_font_controls(value: float) -> void:
	_font_slider.set_value_no_signal(value)
	_font_value.text = "%d%%" % roundi(value * 100.0)
	_decrease_font.disabled = value <= UiSettings.MIN_SCALE
	_increase_font.disabled = value >= UiSettings.MAX_SCALE
	_reset_font.disabled = is_equal_approx(value, UiSettings.DEFAULT_SCALE)


## 告知设置暂未保存，保留已经生效的字号。## 输入: _error (int) - 保存错误码。
## 输出: 无。
func _on_font_save_failed(_error: int) -> void:
	_set_status("字号已应用，但设置暂时无法保存。")
	_status_label.theme_type_variation = &"UiError"


## 保存成功时清除旧错误提示。## 输入: 无。
## 输出: 无。
func _on_font_settings_saved() -> void:
	_set_status("显示设置已保存")
	_status_label.theme_type_variation = &"UiMuted"


## 延迟计算窗体尺寸，避免在容器排序中修改布局。## 输入: 无。
## 输出: 无。
func _schedule_settings_layout() -> void:
	_update_settings_layout.call_deferred()


## 限制窗体尺寸，页面内容超出时由标签页内部滚动。## 输入: 无。
## 输出: 无。
func _update_settings_layout() -> void:
	if not is_inside_tree():
		return
	var center: Container = %SettingsCenter
	var frame: PanelContainer = %SettingsFrame
	frame.custom_minimum_size = Vector2(minf(1120.0, center.size.x), minf(760.0, center.size.y))
	if WindowContext.find_host(self) != null:
		frame.custom_minimum_size = Vector2(maxf(600, size.x - 16), maxf(380, size.y - 16))

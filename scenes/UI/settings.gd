extends Control
## 设置场景。管理调试模式开关、教程重置、应用信息展示。


# ── 节点引用 ──

@onready var _back_button: Button = %BackButton
@onready var _debug_check: CheckButton = %DebugCheck
@onready var _reset_tutorial_btn: Button = %ResetTutorialBtn
@onready var _reset_tutorial_confirm: ConfirmationDialog = %ResetTutorialConfirm
@onready var _status_label: Label = %StatusLabel
@onready var _font_slider: HSlider = %FontScaleSlider
@onready var _font_value: Label = %FontScaleValue
@onready var _decrease_font: Button = %DecreaseFontButton
@onready var _increase_font: Button = %IncreaseFontButton
@onready var _reset_font: Button = %ResetFontButton
@onready var _meta_extras: VBoxContainer = %MetaExtras


# ── 生命周期 ──


## 初始化信号连接、加载当前设置、检查教程。## 输入: 无。
## 输出: 无。
func _ready() -> void:
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
	TutorialManager.check_and_show("settings", self)


## 离开设置时断开标记信号。## 输入: 无。
## 输出: 无。
func _exit_tree() -> void:
	if App.flags_changed.is_connected(_on_flags_changed):
		App.flags_changed.disconnect(_on_flags_changed)


# ── 信号连接 ──


## 连接 UI 控件信号与全局 DebugSettings 信号。## 输入: 无。
## 输出: 无。
func _connect_signals() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_debug_check.toggled.connect(_on_debug_toggled)
	_reset_tutorial_btn.pressed.connect(_on_reset_tutorial_pressed)
	_reset_tutorial_confirm.confirmed.connect(_on_reset_tutorial_confirmed)
	DebugSettings.debug_mode_changed.connect(_on_external_debug_changed)


# ── 设置加载 ──


## 从 DebugSettings autoload 同步调试模式开关状态到 UI。## 输入: 无。
## 输出: 无。
func _load_current_settings() -> void:
	_debug_check.button_pressed = DebugSettings.debug_mode


# ── 按钮回调 ──


## 返回主菜单按钮回调。## 输入: 无。
## 输出: 无。
func _on_back_pressed() -> void:
	_set_status("正在返回主菜单…")
	_switch_scene("res://scenes/ui/main_menu.tscn", "主菜单")


## 调试模式开关切换回调，写入 DebugSettings autoload。## 输入: enabled (bool) — 目标状态。
## 输出: 无。
func _on_debug_toggled(enabled: bool) -> void:
	DebugSettings.set_debug_mode(enabled)


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
	var result: int = App.goto_scene(path)
	if result != OK:
		_set_status("跳转 %s 失败 (err=%d)" % [label, result])


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
	var center: CenterContainer = %SettingsCenter
	var frame: PanelContainer = %SettingsFrame
	frame.custom_minimum_size = Vector2(minf(1120.0, center.size.x), minf(760.0, center.size.y))

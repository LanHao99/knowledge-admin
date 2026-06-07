extends Control
## 设置场景。管理调试模式开关、教程重置、应用信息展示。


# ── 节点引用 ──

@onready var _back_button: Button = %BackButton
@onready var _debug_check: CheckButton = %DebugCheck
@onready var _reset_tutorial_btn: Button = %ResetTutorialBtn
@onready var _reset_tutorial_confirm: ConfirmationDialog = %ResetTutorialConfirm
@onready var _status_label: Label = %StatusLabel


# ── 生命周期 ──


## 初始化信号连接、加载当前设置、检查教程。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	_connect_signals()
	_load_current_settings()
	TutorialManager.check_and_show("settings", self)


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
	_set_status("[color=#66FF66]所有教程已重置 ✓[/color]")


## 外部（其他场景）修改调试模式时同步 UI 开关状态。## 输入: enabled (bool) — 当前调试模式状态。
## 输出: 无。
func _on_external_debug_changed(enabled: bool) -> void:
	_debug_check.button_pressed = enabled


# ── 工具方法 ──


## 安全切换到目标场景，文件不存在时更新状态提示。## 输入:
##   path (String) — 场景文件路径。
##   label (String) — 场景名称用于提示。
## 输出: 无。
func _switch_scene(path: String, label: String) -> void:
	if not ResourceLoader.exists(path):
		_set_status("[color=#FF6666]场景不存在: %s[/color]" % label)
		return
	var result: int = get_tree().change_scene_to_file(path)
	if result != OK:
		_set_status("[color=#FF6666]跳转 %s 失败 (err=%d)[/color]" % [label, result])


## 设置底部状态栏文本（支持 BBCode）。## 输入: text (String) — 状态文本。
## 输出: 无。
func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text

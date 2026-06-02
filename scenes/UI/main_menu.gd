extends Control
## Knowledge Admin 主菜单入口场景。
## 提供牌组管理 / 笔记浏览 / 开始学习 三大导航入口，
## 以及设置和调试按钮。统计面板当前显示占位符 "—"。


# ── 顶部工具栏 ──
@onready var _settings_button: Button = $RootMargin/MainVBox/TopBar/SettingsButton
@onready var _debug_button: Button = $RootMargin/MainVBox/TopBar/DebugButton

# ── 中央卡片 ──
@onready var _main_card: PanelContainer = $RootMargin/MainVBox/CenterArea/MainCard
@onready var _deck_stat: RichTextLabel = $RootMargin/MainVBox/CenterArea/MainCard/CardVBox/StatsGrid/DeckStat
@onready var _due_stat: RichTextLabel = $RootMargin/MainVBox/CenterArea/MainCard/CardVBox/StatsGrid/DueStat
@onready var _today_stat: RichTextLabel = $RootMargin/MainVBox/CenterArea/MainCard/CardVBox/StatsGrid/TodayStat
@onready var _deck_list_btn: Button = $RootMargin/MainVBox/CenterArea/MainCard/CardVBox/DeckListBtn
@onready var _note_browse_btn: Button = $RootMargin/MainVBox/CenterArea/MainCard/CardVBox/NoteBrowseBtn
@onready var _study_btn: Button = $RootMargin/MainVBox/CenterArea/MainCard/CardVBox/StudyBtn

# ── 底部状态栏 ──
@onready var _version_label: Label = $RootMargin/MainVBox/BottomBar/VersionLabel
@onready var _status_label: Label = $RootMargin/MainVBox/BottomBar/StatusLabel


## 初始化 UI 样式与信号连接。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	_setup_panel_style()
	_connect_signals()
	_apply_bbcode_overrides()
	_set_status("数据库就绪 ✓")


## 设置主卡片的 PanelContainer 背景圆角样式。## 输入: 无。
## 输出: 无。
func _setup_panel_style() -> void:
	if _main_card == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.92)
	style.set_corner_radius_all(12)
	style.content_margin_left = 32
	style.content_margin_top = 24
	style.content_margin_right = 32
	style.content_margin_bottom = 24
	_main_card.add_theme_stylebox_override("panel", style)


## 连接顶部按钮与导航按钮的 pressed 信号。## 输入: 无。
## 输出: 无。
func _connect_signals() -> void:
	if _deck_list_btn != null:
		_deck_list_btn.pressed.connect(_on_deck_list_pressed)
	if _note_browse_btn != null:
		_note_browse_btn.pressed.connect(_on_note_browse_pressed)
	if _study_btn != null:
		_study_btn.pressed.connect(_on_study_pressed)
	if _settings_button != null:
		_settings_button.pressed.connect(_on_settings_pressed)
	if _debug_button != null:
		_debug_button.pressed.connect(_on_debug_pressed)


## 对需要 BBCode 动态效果的节点做额外样式覆盖，并设置按钮最小尺寸。## 输入: 无。
## 输出: 无。
func _apply_bbcode_overrides() -> void:
	# 高亮"开始学习"按钮
	if _study_btn != null:
		_study_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1.0))
		_study_btn.custom_minimum_size = Vector2(0, 48)
	# 导航按钮统一高度
	if _deck_list_btn != null:
		_deck_list_btn.custom_minimum_size = Vector2(0, 44)
	if _note_browse_btn != null:
		_note_browse_btn.custom_minimum_size = Vector2(0, 44)
	# 调试按钮用淡色
	if _debug_button != null:
		_debug_button.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 1.0))
		_debug_button.custom_minimum_size = Vector2(88, 36)
	# 设置按钮
	if _settings_button != null:
		_settings_button.custom_minimum_size = Vector2(88, 36)
	# 底部状态用半透明
	if _status_label != null:
		_status_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
	if _version_label != null:
		_version_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45, 1.0))


## 设置底部状态栏文本（支持 BBCode）。## 输入: text (String) - 状态文本。
## 输出: 无。
func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


# ──────────────────────────────────────────────────────────────
# 按钮回调
# ──────────────────────────────────────────────────────────────


## 跳转到牌组列表场景。## 输入: 无。
## 输出: 无。
func _on_deck_list_pressed() -> void:
	_set_status("正在打开牌组管理…")
	_switch_scene("res://scenes/ui/deck_list.tscn", "牌组管理")


## 跳转到笔记浏览场景。## 输入: 无。
## 输出: 无。
func _on_note_browse_pressed() -> void:
	_set_status("正在打开笔记浏览…")
	_switch_scene("res://scenes/ui/note_list.tscn", "笔记浏览")


## 跳转到学习会话场景。## 输入: 无。
## 输出: 无。
func _on_study_pressed() -> void:
	_set_status("正在打开学习会话…")
	_switch_scene("res://scenes/ui/study_session.tscn", "学习会话")


## 设置按钮（当前占位，弹出提示）。## 输入: 无。
## 输出: 无。
func _on_settings_pressed() -> void:
	_set_status("设置功能尚未实现")


## 跳转到调试面板场景。## 输入: 无。
## 输出: 无。
func _on_debug_pressed() -> void:
	_set_status("正在打开调试面板…")
	_switch_scene("res://scenes/ui/debug_crud_panel.tscn", "调试面板")


## 安全切换到目标场景，文件不存在时更新状态提示。## 输入:
##   path (String) - 场景文件路径。
##   label (String) - 场景名称用于提示。
## 输出: 无。
func _switch_scene(path: String, label: String) -> void:
	if not ResourceLoader.exists(path):
		_set_status("[color=#FF6666]场景不存在: %s[/color]" % label)
		return
	var result: int = get_tree().change_scene_to_file(path)
	if result != OK:
		_set_status("[color=#FF6666]跳转 %s 失败 (err=%d)[/color]" % [label, result])

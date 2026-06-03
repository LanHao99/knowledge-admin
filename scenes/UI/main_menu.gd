extends Control
## Knowledge Admin 主菜单入口场景。
## 提供牌组管理 / 笔记浏览 / 开始学习 三大导航入口，
## 以及设置和调试按钮。统计面板展示实时牌组/待复习/今日已学数据。


# ── 数据层（场景独立实例，_exit_tree 时释放）──
var _deck_manager: DeckManager = null
var _card_manager: CardManager = null

# ── 顶部工具栏 ──
@onready var _settings_button: Button = $RootMargin/MainVBox/TopBar/SettingsButton
@onready var _debug_button: Button = $RootMargin/MainVBox/TopBar/DebugButton
@onready var _ai_debug_button: Button = $RootMargin/MainVBox/TopBar/AIDebugButton

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


## 初始化 Manager、信号连接与统计数据加载。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	_connect_signals()
	var init_ok: bool = _ensure_managers_ready()
	if init_ok:
		_refresh_stats()
		_set_status("数据库就绪 ✓")
	else:
		_set_status("[color=#FF6666]数据库初始化失败[/color]")

	# 编辑器内运行场景时自动执行 FSRS 调度器单元测试
	if OS.has_feature("editor"):
		call_deferred("_run_scheduler_tests")


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
	if _ai_debug_button != null:
		_ai_debug_button.pressed.connect(_on_ai_debug_pressed)


## 设置底部状态栏文本（支持 BBCode）。## 输入: text (String) - 状态文本。
## 输出: 无。
func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


## 退出场景时释放独立创建的 Manager 实例。## 输入: 无。
## 输出: 无。
func _exit_tree() -> void:
	if _deck_manager != null:
		_deck_manager.queue_free()
		_deck_manager = null
	if _card_manager != null:
		_card_manager.queue_free()
		_card_manager = null


## 创建并初始化 DeckManager 和 CardManager（每个场景独立实例）。## 输入: 无。
## 输出: bool - 初始化成功返回 true。
func _ensure_managers_ready() -> bool:
	if _deck_manager != null and _deck_manager.is_ready() and _card_manager != null and _card_manager.is_ready():
		return true

	if _deck_manager != null:
		_deck_manager.queue_free()
		_deck_manager = null
	if _card_manager != null:
		_card_manager.queue_free()
		_card_manager = null

	const db_path: String = "user://knowledge_admin.db"

	_deck_manager = DeckManager.new()
	add_child(_deck_manager)
	if not _deck_manager.setup(db_path):
		push_error("[MainMenu] DeckManager 初始化失败")
		return false

	_card_manager = CardManager.new()
	add_child(_card_manager)
	if not _card_manager.setup(db_path):
		push_error("[MainMenu] CardManager 初始化失败")
		return false

	return true


## 从 Manager 拉取统计数据并更新三个 RichTextLabel 面板。## 输入: 无。
## 输出: 无。
func _refresh_stats() -> void:
	if _deck_manager == null or _card_manager == null:
		return

	# 牌组数
	var deck_result := _deck_manager.get_all_decks()
	var deck_count: int = 0
	if deck_result.get("success", false):
		var decks: Array = deck_result.get("data", [])
		deck_count = decks.size()
	_update_stat_label(_deck_stat, "牌组", deck_count)

	# 待复习数
	var now_ts: int = int(Time.get_unix_time_from_system())
	var now_day: int = int(now_ts / CardDB._SECONDS_PER_DAY)
	var due_result := _card_manager.get_global_due_count(now_day, now_ts)
	var due_count: int = 0
	if due_result.get("success", false):
		due_count = int(due_result.get("data", 0))
	_update_stat_label(_due_stat, "待复习", due_count)

	# 今日已学数
	var today_start: int = _get_today_start_ts(now_ts)
	var today_result := _card_manager.get_today_studied_count(today_start)
	var today_count: int = 0
	if today_result.get("success", false):
		today_count = int(today_result.get("data", 0))
	_update_stat_label(_today_stat, "今日已学", today_count)


## 用 BBCode 更新单个统计标签的文本（标题 + 数字）。## 输入:
##   label (RichTextLabel) - 目标标签控件。
##   title (String) - 统计项标题。
##   value (int) - 统计数字。
## 输出: 无。
func _update_stat_label(label: RichTextLabel, title: String, value: int) -> void:
	if label == null:
		return
	label.text = "[center]%s\n[font_size=26]%d[/font_size][/center]" % [title, value]


## 计算今天零点的 Unix 时间戳（秒）。## 输入: now_ts (int) - 当前时间戳。
## 输出: int - 今天零点的时间戳。
func _get_today_start_ts(now_ts: int) -> int:
	return int(now_ts / CardDB._SECONDS_PER_DAY) * CardDB._SECONDS_PER_DAY


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
	_switch_scene("res://scenes/ui/study.tscn", "学习会话")


## 设置按钮（当前占位，弹出提示）。## 输入: 无。
## 输出: 无。
func _on_settings_pressed() -> void:
	_set_status("设置功能尚未实现")


## 跳转到调试面板场景。## 输入: 无。
## 输出: 无。
func _on_debug_pressed() -> void:
	_set_status("正在打开调试面板…")
	_switch_scene("res://scenes/ui/debug_crud_panel.tscn", "调试面板")


## 跳转到 AI 调试控制台场景。## 输入: 无。
## 输出: 无。
func _on_ai_debug_pressed() -> void:
	_set_status("正在打开 AI 调试台…")
	_switch_scene("res://game/ai_debug.tscn", "AI 调试台")


## 加载并执行 FSRS 调度器单元测试（仅编辑器环境）。## 输入: 无。
## 输出: 无。
func _run_scheduler_tests() -> void:
	var test_script := load("res://data/test_fsrs_scheduler.gd")
	if test_script == null:
		push_error("[MainMenu] 无法加载 test_fsrs_scheduler.gd")
		return
	var runner := Node.new()
	runner.set_script(test_script)
	runner.run_all_tests()


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

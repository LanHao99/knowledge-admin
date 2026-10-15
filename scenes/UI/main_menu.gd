extends Control
## 学习桌面入口。展示统计、导航和受调试开关控制的工具菜单。

const WindowContext: GDScript = preload("res://src/ui/window_context.gd")

@export_group("布局")
@export var content_max_width: float = 1120.0

var _deck_manager: DeckManager = null
var _card_manager: CardManager = null

@onready var _settings_button: Button = %SettingsButton
@onready var _ai_card_button: Button = %AICardButton
@onready var _tools_button: MenuButton = %ToolsButton
@onready var _main_card: PanelContainer = %MainCard
@onready var _center_area: Container = %CenterArea
@onready var _content_scroll: ScrollContainer = %ContentScroll
@onready var _deck_stat: Label = %DeckValue
@onready var _due_stat: Label = %DueValue
@onready var _today_stat: Label = %TodayValue
@onready var _deck_list_btn: Button = %DeckListBtn
@onready var _note_browse_btn: Button = %NoteBrowseBtn
@onready var _study_btn: Button = %StudyBtn
@onready var _empty_hint: Label = %EmptyHint
@onready var _status_label: Label = %StatusLabel


## 连接导航、初始化统计并准备可滚动布局。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	WindowContext.adapt_content(self, _main_card)
	%CloseButton.pressed.connect(_on_close_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_ai_card_button.pressed.connect(_on_ai_card_pressed)
	_deck_list_btn.pressed.connect(_on_deck_list_pressed)
	_note_browse_btn.pressed.connect(_on_note_browse_pressed)
	_study_btn.pressed.connect(_on_study_pressed)
	_tools_button.get_popup().id_pressed.connect(_on_tool_pressed)
	DebugSettings.debug_mode_changed.connect(_rebuild_tools)
	_rebuild_tools()
	_content_scroll.resized.connect(_schedule_layout)
	_center_area.resized.connect(_schedule_layout)
	_schedule_layout()
	if _ensure_managers_ready():
		_refresh_stats()
	else:
		_set_status("数据库初始化失败", true)
	TutorialManager.check_and_show("main_menu", self)


## 延迟更新中央面板布局，避免干扰容器排序。## 输入: 无。
## 输出: 无。
func _schedule_layout() -> void:
	_update_layout.call_deferred()


## 限制中央面板宽度，内容过高时保留滚动空间。## 输入: 无。
## 输出: 无。
func _update_layout() -> void:
	if not is_inside_tree():
		return
	_main_card.custom_minimum_size.x = minf(content_max_width, _content_scroll.size.x)
	if WindowContext.find_host(self) != null:
		_main_card.custom_minimum_size = _content_scroll.size
	_center_area.custom_minimum_size.y = _content_scroll.size.y


## 刷新工具菜单，调试模式关闭时保留 AI 助手入口。## 输入: _enabled (bool) - 调试开关通知值。
## 输出: 无。
func _rebuild_tools(_enabled: bool = false) -> void:
	var popup: PopupMenu = _tools_button.get_popup()
	popup.clear()
	popup.add_item("AI 制卡助手", 0)
	if DebugSettings.debug_mode:
		popup.add_separator()
		popup.add_item("调试面板", 1)


## 退出时断开调试通知并释放本场景的数据管理器。## 输入: 无。
## 输出: 无。
func _exit_tree() -> void:
	if DebugSettings.debug_mode_changed.is_connected(_rebuild_tools):
		DebugSettings.debug_mode_changed.disconnect(_rebuild_tools)
	if _deck_manager != null:
		_deck_manager.queue_free()
	if _card_manager != null:
		_card_manager.queue_free()


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


## 按现有口径读取统计；读取失败显示占位符，不把失败视作零。## 输入: 无。
## 输出: 无。
func _refresh_stats() -> void:
	var decks: Dictionary = _deck_manager.get_all_decks()
	var deck_count: int = (decks.get("data", []) as Array).size() if decks.get("success", false) else -1
	var now_ts: int = int(Time.get_unix_time_from_system())
	var now_day: int = int(now_ts / CardDB._SECONDS_PER_DAY)
	var due: Dictionary = _card_manager.get_global_due_count(now_day, now_ts)
	var today: Dictionary = _card_manager.get_today_studied_count(_get_today_start_ts(now_ts))
	_update_stat_label(_deck_stat, deck_count)
	_update_stat_label(_due_stat, int(due.get("data", 0)) if due.get("success", false) else -1)
	_update_stat_label(_today_stat, int(today.get("data", 0)) if today.get("success", false) else -1)
	_study_btn.disabled = deck_count <= 0
	_empty_hint.visible = deck_count == 0
	var failed: bool = deck_count < 0 or not due.get("success", false) or not today.get("success", false)
	_set_status("统计暂时不可用，请稍后重试" if failed else "数据库就绪", failed)


## 显示统计数字或读取失败占位符。## 输入: label (Label) - 数字控件；value (int) - 统计值，负数表示失败。
## 输出: 无。
func _update_stat_label(label: Label, value: int) -> void:
	label.text = str(value) if value >= 0 else "—"


## 保持现有今日统计的零点计算口径。## 输入: now_ts (int) - Unix 时间戳。
## 输出: int - 今日起始时间戳。
func _get_today_start_ts(now_ts: int) -> int:
	return int(now_ts / CardDB._SECONDS_PER_DAY) * CardDB._SECONDS_PER_DAY


## 打开牌组管理。## 输入: 无。
## 输出: 无。
func _on_deck_list_pressed() -> void:
	_switch_scene("res://scenes/ui/deck_list.tscn", "牌组管理")


## 打开笔记浏览。## 输入: 无。
## 输出: 无。
func _on_note_browse_pressed() -> void:
	_switch_scene("res://scenes/ui/note_list.tscn", "笔记浏览")


## 进入现有的学习组装场景。## 输入: 无。
## 输出: 无。
func _on_study_pressed() -> void:
	_switch_scene("res://scenes/ui/study.tscn", "学习会话")


## 打开设置。## 输入: 无。
## 输出: 无。
func _on_settings_pressed() -> void:
	_switch_scene("res://scenes/ui/settings.tscn", "设置")


## 打开 AI 制卡助手。## 输入: 无。
## 输出: 无。
func _on_ai_card_pressed() -> void:
	var manager: Node = get_node_or_null("/root/WindowManager")
	if WindowContext.find_host(self) != null and manager != null and manager.has_method("open_app"):
		if bool(manager.call("open_app", "ai_cards")):
			return
	_switch_scene("res://game/AI/ai_debug.tscn", "AI 制卡助手")


## 处理 AI 助手及调试面板工具项。## 输入: id (int) - 菜单项标识。
## 输出: 无。
func _on_tool_pressed(id: int) -> void:
	if id == 0:
		_on_ai_card_pressed()
	elif id == 1 and DebugSettings.debug_mode:
		_switch_scene("res://scenes/ui/debug_crud_panel.tscn", "调试面板")


## 安全切换场景并反馈文件或加载错误。## 输入: path (String) - 场景路径；label (String) - 场景名称。
## 输出: 无。
func _switch_scene(path: String, label: String) -> void:
	if not ResourceLoader.exists(path):
		_set_status("场景不存在：%s" % label, true)
		return
	var result: int = WindowContext.navigate(self, path)
	if result != OK:
		_set_status("打开%s失败（%d）" % [label, result], true)


## 显示纯文本状态，并通过语义样式表达错误。## 输入: text (String) - 状态；is_error (bool) - 是否错误。
## 输出: 无。
func _set_status(text: String, is_error: bool = false) -> void:
	_status_label.text = text
	_status_label.theme_type_variation = &"UiError" if is_error else &"UiMuted"


## 关闭应用窗体并保存待写入的设置。## 输入: 无。
## 输出: 无。
func _on_close_pressed() -> void:
	var host: Node = WindowContext.find_host(self)
	if host != null:
		host.emit_signal("close_requested")
	else:
		get_tree().quit()


## 窗口重新激活时刷新只读统计。## 输入: 无。输出: 无。
func desktop_refresh() -> void:
	if _deck_manager != null and _card_manager != null:
		_refresh_stats()

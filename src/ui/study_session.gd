extends Control
class_name StudySession

## 牌组调度场景，负责牌组选择界面、学习浮层、完成面板。
## Manager 由父场景 study.gd 注入（通过 set_deck_manager/set_study_manager）。
## 牌组选择后发射 deck_selected 信号给 study.gd 桥接到 CardUI。

signal deck_selected(deck_id: int)  ## 用户选择了牌组，通知 study.gd 启动学习
signal learning_exited()            ## 用户在 InStudyBar 点击退出学习，通知 study.gd 隐藏 CardUI

enum StudyState {
	PICKING,   ## 牌组选择视图
	LEARNING,  ## 卡片学习中
	DONE       ## 学习完成统计面板
}


# ── 注入的 Manager（由 study.gd 注入）──
var _deck_manager: DeckManager = null
var _study_manager: StudyManager = null
var _card_manager: CardManager = null
var _signals_connected: bool = false

var _state: StudyState = StudyState.PICKING
var _last_stats: Dictionary = {}
var _studying_deck_name: String = ""
var _exiting: bool = false  ## 用户正在退出学习，跳过完成面板


# ── 牌组选择视图 ──
@onready var _deck_picker: Control = $"DeckPicker"
@onready var _deck_tree: Tree = $"DeckPicker/RootMargin/MainVBox/DeckTree"
@onready var _back_btn: Button = $"DeckPicker/RootMargin/MainVBox/TopBar/BackBtn"
@onready var _status_label: Label = $"DeckPicker/RootMargin/MainVBox/StatusBar/StatusLabel"

# ── 学习中的顶部浮层栏 ──
@onready var _in_study_bar: HBoxContainer = $"InStudyBar"
@onready var _exit_study_btn: Button = $"InStudyBar/ExitStudyBtn"
@onready var _studying_label: Label = $"InStudyBar/DeckNameLabel"
@onready var _study_progress_label: Label = $"InStudyBar/ProgressLabel"

# ── 剧情进度条（位于 InStudyBar 内）──
@onready var _story_progress_bar: ProgressBar = $"InStudyBar/StoryProgressBar"
@onready var _story_value_label: Label = $"InStudyBar/StoryValueLabel"
@onready var _debug_story_btn: Button = $"InStudyBar/DebugStory"

# ── 剧情进度数据 + 设置 ──
var _story_progress: StoryProgress = null

# ── 完成面板 ──
@onready var _completion_panel: Control = $"CompletionPanel"
@onready var _completion_stats: RichTextLabel = $"CompletionPanel/CompletionMargin/CompletionCenter/CompletionVBox/CompletionStats"
@onready var _completion_back_btn: Button = $"CompletionPanel/CompletionMargin/CompletionCenter/CompletionVBox/CompletionBackBtn"


## 连接按钮信号，构建牌组列表（等待 Manager 注入后由 study.gd 触发 _build_deck_list）。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	_bind_actions()
	_set_state(StudyState.PICKING)
	_setup_debug_mode()
	_bind_story_progress()


## 退出场景时断开信号。## 输入: 无。
## 输出: 无。
func _exit_tree() -> void:
	if App.story_progress_changed.is_connected(_on_story_progress_changed):
		App.story_progress_changed.disconnect(_on_story_progress_changed)
	_disconnect_study_signals()


## 绑定按钮事件与 Tree 双击信号。## 输入: 无。
## 输出: 无。
func _bind_actions() -> void:
	_back_btn.pressed.connect(_on_back_pressed)
	_exit_study_btn.pressed.connect(_on_exit_study_pressed)
	_deck_tree.item_activated.connect(_on_deck_activated)
	_completion_back_btn.pressed.connect(_on_completion_back_pressed)
	_debug_story_btn.pressed.connect(_on_debug_story_pressed)


## 初始化调试模式：监听全局开关，同步 debugUI 组可见性。## 输入: 无。
## 输出: 无。
func _setup_debug_mode() -> void:
	# 直接控制调试按钮可见性
	_debug_story_btn.visible = DebugSettings.debug_mode
	# 监听变化
	if not DebugSettings.debug_mode_changed.is_connected(_on_global_debug_changed):
		DebugSettings.debug_mode_changed.connect(_on_global_debug_changed)


# ──────────────────────────────────────────────────────────────
# Manager 注入（由 study.gd 调用）
# ──────────────────────────────────────────────────────────────


## 注入 DeckManager（用于构建牌组列表）。## 输入: deck_manager (DeckManager)。
## 输出: 无。
func set_deck_manager(deck_manager: DeckManager) -> void:
	_deck_manager = deck_manager


## 注入 StudyManager（用于进度信号 + 退出学习）。## 输入: study_manager (StudyManager)。
## 输出: 无。
func set_study_manager(study_manager: StudyManager) -> void:
	_study_manager = study_manager
	_connect_study_signals()


## 注入用于查询当前到期数量的卡片管理器。## 输入: card_manager (CardManager) - 闪卡业务服务。
## 输出: 无。
func set_card_manager(card_manager: CardManager) -> void:
	_card_manager = card_manager


## 当前是否正在学习卡片。对话结束时用它决定要不要把卡片显示回来。## 输入: 无。
## 输出: bool。处于 LEARNING 时返回 true。
func is_learning() -> bool:
	return _state == StudyState.LEARNING


## 从主逻辑取剧情进度，只用于进度条显示。## 输入: 无。
## 输出: 无。
func _bind_story_progress() -> void:
	var progress := App.get_story_progress()
	if progress != null:
		set_story_progress(progress)
	if not App.story_progress_changed.is_connected(_on_story_progress_changed):
		App.story_progress_changed.connect(_on_story_progress_changed)


## 主逻辑通知进度变化后刷新进度条。## 输入:
##   _current (int) - 当前进度。
##   _threshold (int) - 触发阈值。
## 输出: 无。
func _on_story_progress_changed(_current: int, _threshold: int) -> void:
	refresh_story_display()


## 连接 StudyManager 信号（InStudyBar 进度更新）。## 输入: 无。
## 输出: 无。
func _connect_study_signals() -> void:
	if _signals_connected or _study_manager == null:
		return
	_study_manager.session_started.connect(_on_session_started)
	_study_manager.queue_updated.connect(_on_queue_updated)
	_study_manager.session_ended.connect(_on_session_ended)
	_signals_connected = true


## 断开 StudyManager 信号。
func _disconnect_study_signals() -> void:
	if not _signals_connected or _study_manager == null:
		return
	if _study_manager.session_started.is_connected(_on_session_started):
		_study_manager.session_started.disconnect(_on_session_started)
	if _study_manager.queue_updated.is_connected(_on_queue_updated):
		_study_manager.queue_updated.disconnect(_on_queue_updated)
	if _study_manager.session_ended.is_connected(_on_session_ended):
		_study_manager.session_ended.disconnect(_on_session_ended)
	_signals_connected = false


# ──────────────────────────────────────────────────────────────
# 牌组列表构建
# ──────────────────────────────────────────────────────────────


## 按软件时间显示未归档牌组的到期数量，并保留选中的牌组。## 输入: 无。
## 输出: 无；牌组读取失败时保留空树，到期查询失败时显示占位符。
func build_deck_list() -> void:
	var previous: TreeItem = _deck_tree.get_selected()
	var previous_id: int = int(previous.get_metadata(0)) if previous != null else -1
	_deck_tree.clear()
	_deck_tree.columns = 4
	_deck_tree.set_column_title(0, "牌组")
	_deck_tree.set_column_title(1, "新")
	_deck_tree.set_column_title(2, "学习中")
	_deck_tree.set_column_title(3, "待复习")
	_deck_tree.set_column_expand(0, true)
	_deck_tree.set_column_expand(1, false)
	_deck_tree.set_column_expand(2, false)
	_deck_tree.set_column_expand(3, false)
	_deck_tree.set_column_custom_minimum_width(1, 60)
	_deck_tree.set_column_custom_minimum_width(2, 60)
	_deck_tree.set_column_custom_minimum_width(3, 60)
	_deck_tree.hide_root = true

	if _deck_manager == null:
		_deck_tree.create_item()
		return

	var deck_db: DeckDB = _deck_manager.get_deck_db()
	if deck_db == null:
		_deck_tree.create_item()
		return

	var result := deck_db.get_all_decks(false)
	if not result.get("success", false):
		_deck_tree.create_item()
		return

	var decks: Array[DeckEntity] = result.get("data", [])
	var root_item: TreeItem = _deck_tree.create_item()

	var total_non_empty: int = 0
	var failed: bool = false
	for deck in decks:
		var item: TreeItem = _deck_tree.create_item(root_item)
		item.set_text(0, deck.name)
		item.set_metadata(0, deck.id)
		if deck.id == previous_id:
			item.select(0)

		var counts_result: Dictionary = _card_manager.get_study_queue(deck.id) if _card_manager != null else {"success": false}
		if counts_result.get("success", false):
			var counts: Dictionary = counts_result.get("data", {}).get("counts", {})
			var new_cnt: int = int(counts.get("new", 0))
			var learn_cnt: int = int(counts.get("learning", 0))
			var review_cnt: int = int(counts.get("review", 0))
			item.set_text(1, str(new_cnt))
			item.set_text(2, str(learn_cnt))
			item.set_text(3, str(review_cnt))
			if new_cnt + learn_cnt + review_cnt > 0:
				total_non_empty += 1
		else:
			failed = true
			for column: int in range(1, 4):
				item.set_text(column, "—")

	if failed:
		_set_status_picker("到期数量暂时无法读取，请稍后重试")
	elif total_non_empty > 0:
		_set_status_picker("共 %d 个牌组有待学习卡片" % total_non_empty)
	else:
		_set_status_picker("当前没有到期的卡片")


# ──────────────────────────────────────────────────────────────
# 牌组选择 → 发射信号给 study.gd
# ──────────────────────────────────────────────────────────────


## Tree item_activated 回调：获取选中牌组 ID，发射 deck_selected 信号。
func _on_deck_activated() -> void:
	if _state != StudyState.PICKING:
		return

	var selected: TreeItem = _deck_tree.get_selected()
	if selected == null:
		return

	var deck_id: int = int(selected.get_metadata(0))
	if deck_id <= 0:
		return

	_studying_deck_name = selected.get_text(0)
	deck_selected.emit(deck_id)


## study.gd 回调：切换到学习视图，隐藏牌组选择器，显示浮层栏。## 输入: deck_id (int) - 选中的牌组 ID。
## 输出: 无。
func enter_learning(_deck_id: int) -> void:
	_exiting = false
	_deck_picker.visible = false
	_in_study_bar.visible = true
	_story_progress_bar.visible = true
	_story_value_label.visible = true
	_set_state(StudyState.LEARNING)


# ──────────────────────────────────────────────────────────────
# StudyManager 信号回调（InStudyBar 进度更新）
# ──────────────────────────────────────────────────────────────


## session_started 回调：在浮层栏显示牌组名称。
func _on_session_started(_deck_id: int, _counts: Dictionary) -> void:
	if _studying_label != null:
		_studying_label.text = "牌组: %s" % _studying_deck_name
	if _study_progress_label != null:
		_study_progress_label.text = ""


## queue_updated 回调：刷新浮层栏进度文字。
func _on_queue_updated(counts: Dictionary) -> void:
	if _study_progress_label == null:
		return
	var done: int = int(counts.get("done", 0))
	var total: int = int(counts.get("total", 0))
	if total > 0:
		_study_progress_label.text = "%d / %d" % [done, total]
	else:
		_study_progress_label.text = ""


## session_ended 回调：清空浮层栏进度。
func _on_session_ended(_stats: Dictionary) -> void:
	if _study_progress_label != null:
		_study_progress_label.text = ""


# ──────────────────────────────────────────────────────────────
# 学习结束 → 完成面板
# ──────────────────────────────────────────────────────────────


## study.gd 回调（由 card_ui.study_finished 桥接）：显示完成统计面板。## 输入: stats (Dictionary) - 学习统计。
## 输出: 无。
func show_completion(stats: Dictionary) -> void:
	if _exiting:
		return
	_in_study_bar.visible = false
	_last_stats = stats
	_show_completion_stats(stats)
	_completion_panel.visible = true
	_set_state(StudyState.DONE)


## 渲染完成统计面板（BBCode），包含学习卡片剩余信息。## 输入: stats (Dictionary) - 学习统计。
## 输出: 无。
func _show_completion_stats(stats: Dictionary) -> void:
	var done: int = int(stats.get("done", 0))
	var elapsed_ms: int = int(stats.get("elapsed_ms", 0))
	var elapsed_min: int = int(elapsed_ms / 60000)
	var elapsed_sec: int = int((elapsed_ms % 60000) / 1000)

	var answers: Array = stats.get("answers", [])
	var again_count: int = 0
	var hard_count: int = 0
	var good_count: int = 0
	var easy_count: int = 0
	for a in answers:
		if not (a is Dictionary):
			continue
		var r: int = int(a.get("rating", 0))
		match r:
			CardEntity.RATING_AGAIN: again_count += 1
			CardEntity.RATING_HARD:  hard_count += 1
			CardEntity.RATING_GOOD:  good_count += 1
			CardEntity.RATING_EASY:  easy_count += 1

	var learning_info: String = ""
	var learning_remaining: int = int(stats.get("learning_remaining", 0))
	var next_due_secs: int = int(stats.get("next_due_secs", -1))
	if learning_remaining > 0 and next_due_secs > 0:
		learning_info = "\n\n还有 [b]%d[/b] 张学习卡片\n将在 [b]%s[/b] 后到期" % [learning_remaining, _format_duration(next_due_secs)]
	elif learning_remaining > 0:
		learning_info = "\n\n还有 [b]%d[/b] 张学习卡片" % learning_remaining

	_completion_stats.text = (
		"[center]"
		+ "完成卡片数: [b]%d[/b]\n\n" % done
		+ "耗时: [b]%d分%d秒[/b]\n\n" % [elapsed_min, elapsed_sec]
		+ "重来: [color=#FF5555]%d[/color]  " % again_count
		+ "困难: [color=#FF9933]%d[/color]  " % hard_count
		+ "良好: [color=#33CC55]%d[/color]  " % good_count
		+ "简单: [color=#3388FF]%d[/color]" % easy_count
		+ learning_info
		+ "[/center]"
	)


# ──────────────────────────────────────────────────────────────
# 按钮回调
# ──────────────────────────────────────────────────────────────


## 牌组选择界面返回主菜单。
func _on_back_pressed() -> void:
	_switch_scene("res://content/scenes/ui/main_menu.tscn", "主菜单")


## 学习中退出按钮 → 结束学习，回到牌组选择。
func _on_exit_study_pressed() -> void:
	_exiting = true
	if _study_manager != null and _study_manager.is_session_active():
		_study_manager.end_session()
	# 通知 study.gd 隐藏 CardUI
	learning_exited.emit()
	_in_study_bar.visible = false
	build_deck_list()
	_deck_picker.visible = true
	_set_state(StudyState.PICKING)


## 完成面板"返回牌组列表" → 刷新并回到牌组选择。
func _on_completion_back_pressed() -> void:
	_completion_panel.visible = false
	build_deck_list()
	_deck_picker.visible = true
	_set_state(StudyState.PICKING)


## 调试按钮请求主逻辑填满进度并触发对话。## 输入: 无。
## 输出: 无。
func _on_debug_story_pressed() -> void:
	if not DebugSettings.debug_mode:
		return
	App.debug_fill_and_trigger()


## Autoload 调试模式变化回调 → 同步 debugUI 组可见性。## 输入: enabled (bool)。
## 输出: 无。
func _on_global_debug_changed(enabled: bool) -> void:
	_debug_story_btn.visible = enabled


# ──────────────────────────────────────────────────────────────
# 内部工具
# ──────────────────────────────────────────────────────────────

func _set_state(new_state: StudyState) -> void:
	_state = new_state

func _set_status_picker(text: String) -> void:
	if _status_label != null:
		_status_label.text = text

## 将秒数格式化为可读文案（用于学习卡片到期提示）。## 输入: seconds (int) - 秒数。
## 输出: String - "X分钟Y秒" / "X秒" 等。
func _format_duration(seconds: int) -> String:
	if seconds < 60:
		return "%d秒" % seconds
	if seconds < 3600:
		var mins: int = seconds / 60
		var secs: int = seconds % 60
		if secs > 0:
			return "%d分%d秒" % [mins, secs]
		return "%d分钟" % mins
	var hours: int = seconds / 3600
	return "%d小时" % hours

## 注入剧情进度数据，显示进度条（阈值已在 StoryProgress 中持久化）。## 输入:
##   progress (StoryProgress) - 剧情进度数据源。
## 输出: 无。
func set_story_progress(progress: StoryProgress) -> void:
	_story_progress = progress
	refresh_story_display()
	# 初始化时不显示进度条，等待 enter_learning 时 InStudyBar 统一控制
	_story_progress_bar.visible = false
	_story_value_label.visible = false


## 刷新剧情进度条。进度数据来自主逻辑，本界面只读。## 输入: 无。
## 输出: 无。
func refresh_story_display() -> void:
	if _story_progress == null:
		return
	var threshold: int = _story_progress.trigger_threshold
	var current: int = _story_progress.total_progress
	_story_progress_bar.max_value = float(threshold)
	_story_progress_bar.value = float(min(current, threshold))
	_story_value_label.text = "%d/%d" % [current, threshold]
	# 颜色：绿色满 → 橙色接近 → 黄色积累 → 灰色起步
	var ratio: float = float(current) / float(max(threshold, 1))
	var color: Color
	if ratio >= 1.0:
		color = Color(0.2, 0.8, 0.3, 1.0)
	elif ratio >= 0.7:
		color = Color(0.9, 0.7, 0.2, 1.0)
	elif ratio >= 0.3:
		color = Color(0.8, 0.8, 0.2, 1.0)
	else:
		color = Color(0.4, 0.4, 0.4, 1.0)
	_story_progress_bar.add_theme_color_override("font_color", color)


func _switch_scene(path: String, label: String) -> void:
	if not ResourceLoader.exists(path):
		if _status_label != null:
			_status_label.text = "[color=#FF6666]场景不存在: %s[/color]" % label
		return
	var result: int = App.goto_scene(path)
	if result != OK:
		if _status_label != null:
			_status_label.text = "[color=#FF6666]跳转 %s 失败 (err=%d)[/color]" % [label, result]

extends Control
class_name StudySession

## 学习入口场景，负责牌组选择 → 卡片学习 → 完成统计的完整流程。
## 状态机：PICKING → LEARNING → DONE → PICKING
## 自行创建全部 Manager 并注入 CardUI，CardUI 只负责学习渲染。

enum StudyState {
	PICKING,   ## 牌组选择视图
	LEARNING,  ## 卡片学习中（CardUI 可见）
	DONE       ## 学习完成统计面板
}


# ── 数据层 ──
var _deck_manager: DeckManager = null
var _card_manager: CardManager = null
var _note_manager: NoteManager = null
var _study_manager: StudyManager = null
var _scheduler: SimpleScheduler = null

var _state: StudyState = StudyState.PICKING
var _last_stats: Dictionary = {}
var _studying_deck_name: String = ""


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

# ── CardUI 实例 ──
@onready var _card_ui: CardUI = $"CardUI"

# ── 完成面板 ──
@onready var _completion_panel: Control = $"CompletionPanel"
@onready var _completion_stats: RichTextLabel = $"CompletionPanel/CompletionMargin/CompletionCenter/CompletionVBox/CompletionStats"
@onready var _completion_back_btn: Button = $"CompletionPanel/CompletionMargin/CompletionCenter/CompletionVBox/CompletionBackBtn"


## 初始化 Manager、注入 CardUI、构建牌组列表。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	_setup_managers()
	_inject_into_card_ui()
	_connect_signals()
	_build_deck_list()
	_set_state(StudyState.PICKING)


## 退出场景时断开信号并释放 Manager 实例。## 输入: 无。
## 输出: 无。
func _exit_tree() -> void:
	if _card_ui != null:
		if _card_ui.study_finished.is_connected(_on_study_finished):
			_card_ui.study_finished.disconnect(_on_study_finished)
	if _study_manager != null:
		_disconnect_study_signals()
	_cleanup_managers()


# ──────────────────────────────────────────────────────────────
# Manager 生命周期
# ──────────────────────────────────────────────────────────────


## 创建并初始化全部 4 个 Manager + Scheduler 实例。
func _setup_managers() -> void:
	const db_path: String = "user://knowledge_admin.db"

	_deck_manager = DeckManager.new()
	add_child(_deck_manager)
	if not _deck_manager.setup(db_path):
		push_error("[StudySession] DeckManager 初始化失败")
		return

	_card_manager = CardManager.new()
	add_child(_card_manager)
	if not _card_manager.setup(db_path):
		push_error("[StudySession] CardManager 初始化失败")
		return

	_scheduler = SimpleScheduler.new()
	_card_manager.set_scheduler(_scheduler)

	_note_manager = NoteManager.new()
	add_child(_note_manager)
	if not _note_manager.setup(db_path):
		push_error("[StudySession] NoteManager 初始化失败")
		return

	_study_manager = StudyManager.new()
	add_child(_study_manager)
	_study_manager.set_card_manager(_card_manager)
	_study_manager.set_note_manager(_note_manager)


## 将 Manager 注入 CardUI 实例。
func _inject_into_card_ui() -> void:
	if _card_ui == null:
		return
	_card_ui.set_managers(_study_manager, _note_manager, _card_manager)


## 释放全部 Manager 实例。
func _cleanup_managers() -> void:
	if _study_manager != null:
		_study_manager.queue_free()
		_study_manager = null
	if _note_manager != null:
		_note_manager.queue_free()
		_note_manager = null
	if _card_manager != null:
		_card_manager.queue_free()
		_card_manager = null
	if _scheduler != null:
		_scheduler = null
	if _deck_manager != null:
		_deck_manager.queue_free()
		_deck_manager = null


# ──────────────────────────────────────────────────────────────
# 信号连接
# ──────────────────────────────────────────────────────────────


## 连接按钮信号、CardUI 信号、StudyManager 信号。
func _connect_signals() -> void:
	_back_btn.pressed.connect(_on_back_pressed)
	_exit_study_btn.pressed.connect(_on_exit_study_pressed)
	_deck_tree.item_activated.connect(_on_deck_activated)
	_completion_back_btn.pressed.connect(_on_completion_back_pressed)
	if _card_ui != null:
		_card_ui.study_finished.connect(_on_study_finished)
	if _study_manager != null:
		_study_manager.session_started.connect(_on_session_started)
		_study_manager.queue_updated.connect(_on_queue_updated)
		_study_manager.session_ended.connect(_on_session_ended)


## 断开 StudyManager 信号。
func _disconnect_study_signals() -> void:
	if _study_manager == null:
		return
	if _study_manager.session_started.is_connected(_on_session_started):
		_study_manager.session_started.disconnect(_on_session_started)
	if _study_manager.queue_updated.is_connected(_on_queue_updated):
		_study_manager.queue_updated.disconnect(_on_queue_updated)
	if _study_manager.session_ended.is_connected(_on_session_ended):
		_study_manager.session_ended.disconnect(_on_session_ended)


# ──────────────────────────────────────────────────────────────
# 牌组列表构建
# ──────────────────────────────────────────────────────────────


## 从 DeckDB 获取全部牌组（不含归档），填充 Tree 控件并附带卡片统计。
func _build_deck_list() -> void:
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
	for deck in decks:
		var item: TreeItem = _deck_tree.create_item(root_item)
		item.set_text(0, deck.name)
		item.set_metadata(0, deck.id)

		var counts_result := deck_db.get_deck_card_counts(deck.id)
		if counts_result.get("success", false):
			var counts: Dictionary = counts_result.get("data", {})
			var new_cnt: int = int(counts.get("new", 0))
			var learn_cnt: int = int(counts.get("learning", 0))
			var review_cnt: int = int(counts.get("review", 0))
			item.set_text(1, str(new_cnt))
			item.set_text(2, str(learn_cnt))
			item.set_text(3, str(review_cnt))
			if new_cnt + learn_cnt + review_cnt > 0:
				total_non_empty += 1

	if total_non_empty > 0:
		_set_status_picker("共 %d 个牌组有待学习卡片" % total_non_empty)
	else:
		_set_status_picker("没有待学习的卡片，请先创建笔记")


# ──────────────────────────────────────────────────────────────
# 牌组选择 → 开始学习
# ──────────────────────────────────────────────────────────────


## Tree item_activated 回调：获取选中牌组 ID，切换到学习视图。
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
	_start_learning(deck_id)


## 启动指定牌组的学习会话：隐藏牌组选择器、显示 CardUI 和浮层栏。
func _start_learning(deck_id: int) -> void:
	_deck_picker.visible = false
	_card_ui.visible = true
	_in_study_bar.visible = true
	_set_state(StudyState.LEARNING)
	_card_ui.start_study(deck_id)


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
	var done: int = int(counts.get("total", 0)) - int(counts.get("remaining", 0))
	var total: int = int(counts.get("total", 0))
	if total > 0:
		_study_progress_label.text = "%d / %d" % [done, total]
	else:
		_study_progress_label.text = ""


## session_ended 回调：清空浮层栏进度（等待 study_finished 切换视图）。
func _on_session_ended(_stats: Dictionary) -> void:
	if _study_progress_label != null:
		_study_progress_label.text = ""


# ──────────────────────────────────────────────────────────────
# 学习结束
# ──────────────────────────────────────────────────────────────


## CardUI.study_finished 回调：显示完成统计面板。
func _on_study_finished(stats: Dictionary) -> void:
	_card_ui.visible = false
	_in_study_bar.visible = false
	_last_stats = stats
	_show_completion_stats(stats)
	_completion_panel.visible = true
	_set_state(StudyState.DONE)


## 渲染完成统计面板。
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

	_completion_stats.text = (
		"[center]"
		+ "完成卡片数: [b]%d[/b]\n\n" % done
		+ "耗时: [b]%d分%d秒[/b]\n\n" % [elapsed_min, elapsed_sec]
		+ "重来: [color=#FF5555]%d[/color]  " % again_count
		+ "困难: [color=#FF9933]%d[/color]  " % hard_count
		+ "良好: [color=#33CC55]%d[/color]  " % good_count
		+ "简单: [color=#3388FF]%d[/color]" % easy_count
		+ "[/center]"
	)


# ──────────────────────────────────────────────────────────────
# 按钮回调
# ──────────────────────────────────────────────────────────────


## 牌组选择界面返回主菜单。
func _on_back_pressed() -> void:
	_switch_scene("res://scenes/ui/main_menu.tscn", "主菜单")


## 学习中退出按钮 → 结束学习，回到牌组选择。
func _on_exit_study_pressed() -> void:
	if _study_manager != null and _study_manager.is_session_active():
		_study_manager.end_session()
	_card_ui.visible = false
	_in_study_bar.visible = false
	_build_deck_list()
	_deck_picker.visible = true
	_set_state(StudyState.PICKING)


## 完成面板"返回牌组列表" → 刷新并回到牌组选择。
func _on_completion_back_pressed() -> void:
	_completion_panel.visible = false
	_build_deck_list()
	_deck_picker.visible = true
	_set_state(StudyState.PICKING)


# ──────────────────────────────────────────────────────────────
# 内部工具
# ──────────────────────────────────────────────────────────────

func _set_state(new_state: StudyState) -> void:
	_state = new_state

func _set_status_picker(text: String) -> void:
	if _status_label != null:
		_status_label.text = text

func _switch_scene(path: String, label: String) -> void:
	if not ResourceLoader.exists(path):
		if _status_label != null:
			_status_label.text = "[color=#FF6666]场景不存在: %s[/color]" % label
		return
	var result: int = get_tree().change_scene_to_file(path)
	if result != OK:
		if _status_label != null:
			_status_label.text = "[color=#FF6666]跳转 %s 失败 (err=%d)[/color]" % [label, result]

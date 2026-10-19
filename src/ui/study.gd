extends Control
## 闪卡学习组装者。
## 创建牌组、笔记、卡片和学习会话，并注入给 StudySession 与 CardUI。
## 不创建剧情管理器，也不实例化对话窗。对话打开时只负责藏起卡片。


# ── Manager 实例 ──
var _deck_manager: DeckManager = null
var _card_manager: CardManager = null
var _note_manager: NoteManager = null
var _study_manager: StudyManager = null

# ── 子场景引用 ──
@onready var _session: StudySession = $StudySession
@onready var _card_ui: CardUI = $CardUI


## 创建 Manager、注入子场景，并监听主逻辑的对话开关。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	_setup_managers()
	_inject_all()
	_connect_bridge()
	AppClock.time_changed.connect(_on_clock_changed)
	AppClock.day_changed.connect(_on_clock_day_changed)
	if not App.dialogue_opened.is_connected(_on_dialogue_opened):
		App.dialogue_opened.connect(_on_dialogue_opened)
	if not App.dialogue_closed.is_connected(_on_dialogue_closed):
		App.dialogue_closed.connect(_on_dialogue_closed)
	TutorialManager.check_and_show("study", self)


## 退出时断开主逻辑信号并释放 Manager。## 输入: 无。
## 输出: 无。
func _exit_tree() -> void:
	if App.dialogue_opened.is_connected(_on_dialogue_opened):
		App.dialogue_opened.disconnect(_on_dialogue_opened)
	if App.dialogue_closed.is_connected(_on_dialogue_closed):
		App.dialogue_closed.disconnect(_on_dialogue_closed)
	_cleanup_managers()


## 创建闪卡引擎使用的 Manager。调度器由 CardManager 自己创建。## 输入: 无。
## 输出: 无。
func _setup_managers() -> void:
	const db_path: String = "user://knowledge_admin.db"

	_deck_manager = DeckManager.new()
	add_child(_deck_manager)
	_deck_manager.setup(db_path)

	_card_manager = CardManager.new()
	add_child(_card_manager)
	_card_manager.setup(db_path)

	_note_manager = NoteManager.new()
	add_child(_note_manager)
	_note_manager.setup(db_path)

	_study_manager = StudyManager.new()
	add_child(_study_manager)
	_study_manager.set_card_manager(_card_manager)
	_study_manager.set_note_manager(_note_manager)
	_study_manager.set_deck_manager(_deck_manager)


## 将 Manager 注入给 StudySession 和 CardUI，然后构建牌组列表。## 输入: 无。
## 输出: 无。
func _inject_all() -> void:
	if _session != null:
		_session.set_deck_manager(_deck_manager)
		_session.set_study_manager(_study_manager)
		_session.set_card_manager(_card_manager)
		_session.build_deck_list()
	if _card_ui != null:
		_card_ui.set_managers(_study_manager, _note_manager, _card_manager)


## 释放全部 Manager 实例。## 输入: 无。
## 输出: 无。
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
	if _deck_manager != null:
		_deck_manager.queue_free()
		_deck_manager = null


## 连接牌组选择和学习结束信号。## 输入: 无。
## 输出: 无。
func _connect_bridge() -> void:
	if _session != null:
		if not _session.deck_selected.is_connected(_on_deck_selected):
			_session.deck_selected.connect(_on_deck_selected)
		if not _session.learning_exited.is_connected(_on_learning_exited):
			_session.learning_exited.connect(_on_learning_exited)
	if _card_ui != null:
		if not _card_ui.study_finished.is_connected(_on_study_finished):
			_card_ui.study_finished.connect(_on_study_finished)


## 用户选中牌组后显示卡片并进入学习。## 输入: deck_id (int) - 选中的牌组 ID。
## 输出: 无。
func _on_deck_selected(deck_id: int) -> void:
	if _card_ui != null:
		_card_ui.visible = true
		_card_ui.start_study(deck_id)
	if _session != null:
		_session.enter_learning(deck_id)


## 用户中途退出学习时隐藏卡片。## 输入: 无。
## 输出: 无。
func _on_learning_exited() -> void:
	if _card_ui != null:
		_card_ui.visible = false


## 调时后保留卡面，刷新本轮剩余队列及牌组到期统计。## 输入: 无。
## 输出: 无。
func _on_clock_changed() -> void:
	if _study_manager != null:
		_study_manager.refresh_for_time_change()
	if _session != null:
		_session.build_deck_list()


## 复习日自然切换时复用队列刷新过程。## 输入: _day_index (int) - 当前 Unix 天索引。
## 输出: 无。
func _on_clock_day_changed(_day_index: int) -> void:
	_on_clock_changed()


## 学习会话结束时隐藏卡片并显示完成面板。## 输入: stats (Dictionary) - 学习统计。
## 输出: 无。
func _on_study_finished(stats: Dictionary) -> void:
	if _card_ui != null:
		_card_ui.visible = false
	if _session != null:
		_session.show_completion(stats)


## 主逻辑打开对话时藏起卡片。## 输入: _dialogue_key (String) - 对话标识。
## 输出: 无。
func _on_dialogue_opened(_dialogue_key: String) -> void:
	if _card_ui != null:
		_card_ui.visible = false


## 对话结束后，仅在仍处于学习中时恢复卡片。## 输入: _dialogue_key (String) - 对话标识。
## 输出: 无。
func _on_dialogue_closed(_dialogue_key: String) -> void:
	if _card_ui != null and _session != null and _session.is_learning():
		_card_ui.visible = true


## 查询当前学习是否需要关闭确认。## 输入: 无。输出: bool。
func desktop_has_active_session() -> bool:
	return _study_manager != null and _study_manager.is_session_active()


## 关闭窗口前结束会话并保存已有评分。## 输入: 无。输出: 无。
func desktop_end_session() -> void:
	if desktop_has_active_session():
		_study_manager.end_session()

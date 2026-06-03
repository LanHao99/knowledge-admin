extends Control
## 学习模块交换机（协调者）。
## 职责：创建 Manager → 注入给 StudySession 和 CardUI → 桥接两者信号。
## 不负责任何 UI 逻辑，只做数据交换和视图切换协调。


# ── Manager 实例 ──
var _deck_manager: DeckManager = null
var _card_manager: CardManager = null
var _note_manager: NoteManager = null
var _study_manager: StudyManager = null
var _scheduler: SimpleScheduler = null

# ── 子场景引用 ──
@onready var _session: StudySession = $StudySession
@onready var _card_ui: CardUI = $CardUI


## 创建 Manager → 注入 → 桥接信号。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	_setup_managers()
	_inject_all()
	_connect_bridge()


## 退出时释放 Manager 实例。## 输入: 无。
## 输出: 无。
func _exit_tree() -> void:
	_cleanup_managers()


# ──────────────────────────────────────────────────────────────
# Manager 生命周期
# ──────────────────────────────────────────────────────────────


## 创建全部 Manager + Scheduler 实例（study.gd 是唯一创建者）。## 输入: 无。
## 输出: 无。
func _setup_managers() -> void:
	const db_path: String = "user://knowledge_admin.db"

	_deck_manager = DeckManager.new()
	add_child(_deck_manager)
	_deck_manager.setup(db_path)

	_card_manager = CardManager.new()
	add_child(_card_manager)
	_card_manager.setup(db_path)

	_scheduler = SimpleScheduler.new()
	_card_manager.set_scheduler(_scheduler)

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
	if _scheduler != null:
		_scheduler = null
	if _deck_manager != null:
		_deck_manager.queue_free()
		_deck_manager = null


# ──────────────────────────────────────────────────────────────
# 信号桥接
# ──────────────────────────────────────────────────────────────


## 连接 StudySession.deck_selected 和 CardUI.study_finished 信号。## 输入: 无。
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


## StudySession.deck_selected 回调：显示 CardUI 并启动学习，通知 session 切换视图。## 输入: deck_id (int) - 选中的牌组 ID。
## 输出: 无。
func _on_deck_selected(deck_id: int) -> void:
	if _card_ui != null:
		_card_ui.visible = true
		_card_ui.start_study(deck_id)
	if _session != null:
		_session.enter_learning(deck_id)


## StudySession.learning_exited 回调：用户中途退出学习，隐藏 CardUI。## 输入: 无。
## 输出: 无。
func _on_learning_exited() -> void:
	if _card_ui != null:
		_card_ui.visible = false


## CardUI.study_finished 回调：隐藏 CardUI，通知 session 显示完成面板。## 输入: stats (Dictionary) - 学习统计。
## 输出: 无。
func _on_study_finished(stats: Dictionary) -> void:
	if _card_ui != null:
		_card_ui.visible = false
	if _session != null:
		_session.show_completion(stats)

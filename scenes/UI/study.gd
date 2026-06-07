extends Control
## 学习模块交换机（协调者）。
## 职责：创建 Manager → 注入给 StudySession 和 CardUI → 桥接两者信号。
## 同时管理 StoryManager（剧情系统）和 StoryDialogueOverlay（对话覆盖层）。
## 不负责任何 UI 逻辑，只做数据交换和视图切换协调。


# ── Manager 实例 ──
var _deck_manager: DeckManager = null
var _card_manager: CardManager = null
var _note_manager: NoteManager = null
var _study_manager: StudyManager = null
var _scheduler: FsrsScheduler = null

# ── 剧情系统 ──
var _story_manager: StoryManager = null

# ── 子场景引用 ──
@onready var _session: StudySession = $StudySession
@onready var _card_ui: CardUI = $CardUI
@onready var _story_overlay: StoryDialogueOverlay = $StoryDialogueOverlay


## 创建 Manager → 注入 → 桥接信号 → 初始化剧情系统。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	_setup_managers()
	_setup_story_system()
	_inject_all()
	_connect_bridge()

	TutorialManager.check_and_show("study", self )


## 退出时释放 Manager 实例和剧情管理器。## 输入: 无。
## 输出: 无。
func _exit_tree() -> void:
	_cleanup_story_system()
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

	_scheduler = FsrsScheduler.new()
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
# 剧情系统生命周期
# ──────────────────────────────────────────────────────────────


## 初始化 StoryManager、进度条 UI 和对话覆盖层。## 输入: 无。
## 输出: 无。
func _setup_story_system() -> void:
	# 创建 StoryManager（RefCounted，不加入节点树）
	_story_manager = StoryManager.new()
	var dm = Engine.get_singleton("DialogueManager")
	_story_manager.setup(dm)

	# 注册对话资源映射（按叙事顺序排列）
	_story_manager.register_dialogues({
		"chapter_1": {
			"intro": "res://game/dialogue/ch1_intro.dialogue",
			"explain": "res://game/dialogue/ch1_explain.dialogue",
			"trust": "res://game/dialogue/ch1_trust.dialogue",
			"warning": "res://game/dialogue/ch1_warning.dialogue",
			"past": "res://game/dialogue/ch1_past.dialogue",
			"choice": "res://game/dialogue/ch1_choice.dialogue",
			"revelation": "res://game/dialogue/ch1_revelation.dialogue",
			"end": "res://game/dialogue/ch1_end.dialogue"
		}
	})

	# 设置初始章节
	_story_manager.story_progress.current_chapter = "chapter_1"

	# 将剧情进度注入 session（阈值已在 StoryProgress 中持久化）
	if _session != null:
		_session.set_story_progress(_story_manager.story_progress)
		_session.inject_story_manager(_story_manager)

	# 注入 StoryManager 到 Overlay
	if _story_overlay != null:
		_story_overlay.set_story_manager(_story_manager)


## 清理剧情系统。## 输入: 无。
## 输出: 无。
func _cleanup_story_system() -> void:
	_story_manager = null


# ──────────────────────────────────────────────────────────────
# 信号桥接
# ──────────────────────────────────────────────────────────────


## 连接 StudySession.deck_selected 和 CardUI.study_finished 信号，以及剧情系统信号。## 输入: 无。
## 输出: 无。
func _connect_bridge() -> void:
	# 现有桥接
	if _session != null:
		if not _session.deck_selected.is_connected(_on_deck_selected):
			_session.deck_selected.connect(_on_deck_selected)
		if not _session.learning_exited.is_connected(_on_learning_exited):
			_session.learning_exited.connect(_on_learning_exited)
		if not _session.story_force_trigger.is_connected(_on_story_force_trigger):
			_session.story_force_trigger.connect(_on_story_force_trigger)
	if _card_ui != null:
		if not _card_ui.study_finished.is_connected(_on_study_finished):
			_card_ui.study_finished.connect(_on_study_finished)

	# 剧情系统桥接：评分后通知 StoryManager
	if _study_manager != null:
		if not _study_manager.card_answered.is_connected(_on_story_card_answered):
			_study_manager.card_answered.connect(_on_story_card_answered)

	# StoryManager 触发对话
	if _story_manager != null:
		if not _story_manager.story_triggered.is_connected(_on_story_triggered):
			_story_manager.story_triggered.connect(_on_story_triggered)
		if not _story_manager.story_ended.is_connected(_on_story_ended):
			_story_manager.story_ended.connect(_on_story_ended)

	# Overlay 对话结束 → 恢复复习
	if _story_overlay != null:
		if not _story_overlay.dialogue_finished.is_connected(_on_story_dialogue_finished):
			_story_overlay.dialogue_finished.connect(_on_story_dialogue_finished)


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


# ──────────────────────────────────────────────────────────────
# 剧情系统信号回调
# ──────────────────────────────────────────────────────────────


## 评分后桥接到 StoryManager（不阻塞复习流程）。## 输入:
##   _card (CardEntity) - 已评分卡片（未使用）。
##   rating (int) - 评分值。
##   _next_interval (String) - 下次间隔（未使用）。
## 输出: 无。
func _on_story_card_answered(_card: CardEntity, rating: int, _next_interval: String) -> void:
	if _story_manager == null:
		return
	_story_manager.on_review_answered(rating)
	# 同步刷新 session 内的剧情进度条（数据已在 StoryProgress 中更新）
	if _session != null:
		_session.refresh_story_display()


## StoryManager.story_triggered 回调：暂停复习，显示对话覆盖层。## 输入: dialogue_key (String) - 对话标识符。
## 输出: 无。
func _on_story_triggered(dialogue_key: String) -> void:
	if _story_overlay == null or _story_manager == null:
		return

	var resource = _story_manager.load_dialogue_resource(dialogue_key)
	if resource == null:
		return

	# 暂停 CardUI（隐藏复习界面）
	if _card_ui != null:
		_card_ui.visible = false

	# 显示对话覆盖层
	_story_overlay.start(resource, dialogue_key)


## StoryManager.story_ended 回调：恢复复习界面的可见性。## 输入: 无。
## 输出: 无。
func _on_story_ended() -> void:
	if _card_ui != null:
		_card_ui.visible = true


## StoryDialogueOverlay.dialogue_finished 回调：对话播放完毕，恢复复习界面。## 输入: 无。
## 输出: 无。
func _on_story_dialogue_finished() -> void:
	if _card_ui != null:
		_card_ui.visible = true


## StudySession.story_force_trigger 回调：调试按钮触发，强制填充进度并触发对话。## 输入: 无。
## 输出: 无。
func _on_story_force_trigger() -> void:
	if _story_manager == null:
		return

	# 临时关闭冷却，确保能触发
	var saved_cooldown: float = _story_manager.cooldown_seconds
	_story_manager.set_cooldown(0.0)

	# 以 Easy 评分触发对话（贡献 3 进度，已由 session 填满进度条）
	_story_manager.on_review_answered(4)

	# 恢复冷却
	_story_manager.set_cooldown(saved_cooldown)

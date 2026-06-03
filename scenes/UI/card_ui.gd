extends Control
class_name CardUI

## 卡片学习组件，负责渲染单张卡片的正反面内容，提供翻面交互与四档评分按钮。
## 监听 StudyManager 信号驱动 UI 状态切换，不直接操作数据库。
##
## 依赖注入：由父场景（study.gd）通过 set_managers() 注入 StudyManager/NoteManager/CardManager。
## 学习结束时发出 study_finished 信号，父场景负责导航。
##
## 状态机：LOADING → FRONT → BACK → FRONT → ... → DONE

# ── 信号 ──
signal study_finished(stats: Dictionary)  ## 学习会话结束，携带统计信息


# ── 状态枚举 ──
enum UIState {
	LOADING,  ## 等待信号
	FRONT,    ## 正面，等待点击翻面
	BACK,     ## 背面 + 评分按钮
	DONE      ## 会话结束
}


# ── 注入的 Manager（由父场景 set_managers() 注入）──
var _study_manager: StudyManager = null
var _note_manager: NoteManager = null
var _card_manager: CardManager = null

# ── UI 状态 ──
var _state: UIState = UIState.LOADING
var _cached_front: String = ""
var _cached_back: String = ""
var _current_card: CardEntity = null
var _managers_injected: bool = false
var _signals_connected: bool = false


# ── 顶部信息栏 ──
@onready var _progress_label: Label = $"MainVBox/TopBar/ProgressLabel"
@onready var _queue_label: Label = $"MainVBox/TopBar/QueueLabel"

# ── 卡片内容区 ──
@onready var _card_panel: PanelContainer = $"MainVBox/CardPanel"
@onready var _content_label: RichTextLabel = $"MainVBox/CardPanel/CardContentVBox/ContentLabel"
@onready var _flip_hint: Label = $"MainVBox/CardPanel/CardContentVBox/FlipHint"

# ── 评分按钮 ──
@onready var _answer_bar: HBoxContainer = $"MainVBox/AnswerBar"
@onready var _again_btn: Button = $"MainVBox/AnswerBar/AgainBtn"
@onready var _hard_btn: Button = $"MainVBox/AnswerBar/HardBtn"
@onready var _good_btn: Button = $"MainVBox/AnswerBar/GoodBtn"
@onready var _easy_btn: Button = $"MainVBox/AnswerBar/EasyBtn"

# ── 状态栏 ──
@onready var _status_label: Label = $"MainVBox/StatusBar/StatusLabel"


## 初始化按钮绑定，等待 set_managers() 注入。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	_bind_buttons()
	_set_state(UIState.LOADING)
	_set_status("等待选择牌组…")


## 清理信号连接（如果已注入 Manager 并连接了信号）。## 输入: 无。
## 输出: 无。
func _exit_tree() -> void:
	_disconnect_signals()


## 注入三个 Manager 并连接信号（由父场景 study.gd 调用）。## 输入:
##   study_manager (StudyManager) - 已初始化的学习会话管理器。
##   note_manager (NoteManager) - 已初始化的笔记管理器。
##   card_manager (CardManager) - 已初始化的卡片管理器。
## 输出: 无。
func set_managers(study_manager: StudyManager, note_manager: NoteManager, card_manager: CardManager) -> void:
	_study_manager = study_manager
	_note_manager = note_manager
	_card_manager = card_manager
	_managers_injected = true
	_connect_signals()


## 启动学习会话（由 study.gd 在用户选择牌组后调用）。## 输入: deck_id (int) - 目标牌组 ID。
## 输出: 无。
func start_study(deck_id: int) -> void:
	if not _managers_injected:
		_set_status("[color=#FF6666]管理器未注入[/color]")
		return
	if _study_manager.is_session_active():
		_set_status("[color=#FFAA44]学习会话已在运行中[/color]")
		return

	_set_state(UIState.LOADING)
	_set_status("正在加载学习卡片…")
	var result := _study_manager.start_session(deck_id, 20, 100)
	if not result.get("success", false):
		_set_status("[color=#FF6666]启动失败: %s[/color]" % str(result.get("error", "未知")))


# ──────────────────────────────────────────────────────────────
# 信号连接
# ──────────────────────────────────────────────────────────────


## 绑定按钮 pressed 信号与卡片面板点击事件。## 输入: 无。
## 输出: 无。
func _bind_buttons() -> void:
	_again_btn.pressed.connect(_on_again_pressed)
	_hard_btn.pressed.connect(_on_hard_pressed)
	_good_btn.pressed.connect(_on_good_pressed)
	_easy_btn.pressed.connect(_on_easy_pressed)
	_card_panel.gui_input.connect(_on_card_panel_gui_input)


## 连接 StudyManager 信号。## 输入: 无。
## 输出: 无。
func _connect_signals() -> void:
	if _signals_connected or _study_manager == null:
		return
	_study_manager.session_started.connect(_on_session_started)
	_study_manager.session_ended.connect(_on_session_ended)
	_study_manager.card_shown.connect(_on_card_shown)
	_study_manager.card_answered.connect(_on_card_answered)
	_study_manager.queue_updated.connect(_on_queue_updated)
	_signals_connected = true


## 断开 StudyManager 信号。
func _disconnect_signals() -> void:
	if not _signals_connected or _study_manager == null:
		return
	if _study_manager.session_started.is_connected(_on_session_started):
		_study_manager.session_started.disconnect(_on_session_started)
	if _study_manager.session_ended.is_connected(_on_session_ended):
		_study_manager.session_ended.disconnect(_on_session_ended)
	if _study_manager.card_shown.is_connected(_on_card_shown):
		_study_manager.card_shown.disconnect(_on_card_shown)
	if _study_manager.card_answered.is_connected(_on_card_answered):
		_study_manager.card_answered.disconnect(_on_card_answered)
	if _study_manager.queue_updated.is_connected(_on_queue_updated):
		_study_manager.queue_updated.disconnect(_on_queue_updated)
	_signals_connected = false


# ──────────────────────────────────────────────────────────────
# 卡片面板点击 → 翻面（仅 FRONT 状态生效）
# ──────────────────────────────────────────────────────────────


## 处理 CardPanel 的 gui_input 信号，左键点击时触发翻面。## 输入: event (InputEvent) - Godot 输入事件。
## 输出: 无。
func _on_card_panel_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_on_card_clicked()


## 点击卡片内容区 → 调用 StudyManager.show_answer() 翻面。
func _on_card_clicked() -> void:
	if _state != UIState.FRONT:
		return
	if _study_manager == null:
		return
	var result := _study_manager.show_answer()
	if not result.get("success", false):
		_set_status("[color=#FF6666]翻面失败: %s[/color]" % str(result.get("error", "")))


# ──────────────────────────────────────────────────────────────
# StudyManager 信号回调
# ──────────────────────────────────────────────────────────────


## session_started 回调：初始化进度显示。## 输入:
##   _deck_id (int) - 牌组 ID（未使用）。
##   counts (Dictionary) - {new, learning, review, total}。
## 输出: 无。
func _on_session_started(_deck_id: int, counts: Dictionary) -> void:
	var total: int = int(counts.get("total", 0))
	if total == 0:
		_content_label.text = "[center]该牌组暂无待学习的卡片[/center]"
		_set_state(UIState.DONE)
		return
	_set_status("开始学习，共 %d 张卡片" % total)


## session_ended 回调：发出 study_finished 信号通知父场景。## 输入: stats (Dictionary) - 会话统计。
## 输出: 无。
func _on_session_ended(stats: Dictionary) -> void:
	_set_state(UIState.DONE)
	study_finished.emit(stats)


## card_shown 回调：根据 is_back 渲染正面或反面。## 输入:
##   card (CardEntity) - 当前卡片实体。
##   is_back (bool) - true 为反面。
## 输出: 无。
func _on_card_shown(card: CardEntity, is_back: bool) -> void:
	if card == null:
		_set_status("[color=#FFAA44]卡片为空[/color]")
		return

	if is_back:
		_render_back()
	else:
		_render_front(card)


## card_answered 回调：状态栏反馈。## 输入:
##   _card (CardEntity) - 已评分的卡片（未使用）。
##   rating (int) - 评分。
##   next_interval (String) - 下次间隔文案。
## 输出: 无。
func _on_card_answered(_card: CardEntity, rating: int, next_interval: String) -> void:
	var rating_name: String = ""
	match rating:
		CardEntity.RATING_AGAIN:
			rating_name = "重来"
		CardEntity.RATING_HARD:
			rating_name = "困难"
		CardEntity.RATING_GOOD:
			rating_name = "良好"
		CardEntity.RATING_EASY:
			rating_name = "简单"
	_set_status("已答: %s → %s" % [rating_name, next_interval])


## queue_updated 回调：刷新顶部进度。
func _on_queue_updated(counts: Dictionary) -> void:
	var done: int = int(counts.get("total", 0)) - int(counts.get("remaining", 0))
	var total: int = int(counts.get("total", 0))
	_progress_label.text = "%d / %d" % [done, total]
	if _current_card != null:
		_queue_label.text = _current_card.get_queue_name()


# ──────────────────────────────────────────────────────────────
# UI 渲染
# ──────────────────────────────────────────────────────────────


## 渲染正面：调用 NoteManager 获取 front/back 文本并缓存。
func _render_front(card: CardEntity) -> void:
	_current_card = card
	_cached_front = ""
	_cached_back = ""

	if _note_manager == null:
		_content_label.text = "[center]笔记管理器未初始化[/center]"
		_set_state(UIState.FRONT)
		return

	var content_result := _note_manager.get_content_for_card(card.id)
	if not content_result.get("success", false):
		_content_label.text = "[center]无法加载卡片内容[/center]"
		_set_state(UIState.FRONT)
		return

	var data: Dictionary = content_result.get("data", {})
	_cached_front = str(data.get("front", ""))
	_cached_back = str(data.get("back", ""))
	if _cached_front == "":
		_cached_front = "（无正面内容）"

	_content_label.text = "[center]%s[/center]" % _cached_front
	_answer_bar.visible = false
	_flip_hint.visible = true
	_progress_label.text = _build_progress_text()
	_queue_label.text = card.get_queue_name()
	_set_state(UIState.FRONT)
	_set_status("点击卡片翻面查看答案")


## 渲染背面：使用缓存的 _cached_back。
func _render_back() -> void:
	if _cached_back == "":
		_cached_back = "（无背面内容）"
	_content_label.text = "[center]%s[/center]" % _cached_back
	_flip_hint.visible = false
	_answer_bar.visible = true
	_set_state(UIState.BACK)


## 构建进度文本。
func _build_progress_text() -> String:
	if _study_manager == null:
		return "— / —"
	var progress := _study_manager.get_session_progress()
	var done: int = int(progress.get("done", 0))
	var total: int = int(progress.get("total", 0))
	if total <= 0:
		return "— / —"
	return "%d / %d" % [done + 1, total]


# ──────────────────────────────────────────────────────────────
# 评分按钮
# ──────────────────────────────────────────────────────────────

func _on_again_pressed() -> void:
	_submit_rating(CardEntity.RATING_AGAIN)

func _on_hard_pressed() -> void:
	_submit_rating(CardEntity.RATING_HARD)

func _on_good_pressed() -> void:
	_submit_rating(CardEntity.RATING_GOOD)

func _on_easy_pressed() -> void:
	_submit_rating(CardEntity.RATING_EASY)


## 提交评分到 StudyManager，后续由 signal 自动推进。
func _submit_rating(rating: int) -> void:
	if _state != UIState.BACK:
		return
	if _study_manager == null:
		return

	var result := _study_manager.answer(rating)
	if not result.get("success", false):
		_set_status("[color=#FF6666]评分提交失败: %s[/color]" % str(result.get("error", "")))
		return

	_answer_bar.visible = false


# ──────────────────────────────────────────────────────────────
# 内部工具
# ──────────────────────────────────────────────────────────────

func _set_state(new_state: UIState) -> void:
	_state = new_state

func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text

extends GutTest
## 使用独立 SQLite 数据库验证软件时间与闪卡调度、会话和失败重试。

const BASE_TIME: int = 1709294400
const CARD_SCENE: PackedScene = preload("res://content/scenes/ui/card_ui.tscn")

var _path: String
var _deck_id: int
var _notes: NoteManager
var _decks: DeckManager
var _cards: FailingCardManager
var _study: StudyManager
var _saved_story: StoryProgress


class FailingCardManager:
	extends CardManager
	var unavailable: bool = false

	## 模拟临时查询故障，恢复后使用实际数据库。## 输入: deck_id (int) - 牌组；now_timestamp (int) - 软件 Unix 秒数。
	## 输出: Dictionary - 实际队列或预期的查询失败。
	func get_study_queue(deck_id: int, now_timestamp: int = -1) -> Dictionary:
		if unavailable:
			return {"success": false, "error": "测试查询暂时不可用"}
		return super.get_study_queue(deck_id, now_timestamp)


## 准备独立数据库，暂时提高剧情触发阈值以隔离评分测试。## 输入: 无。
## 输出: 无。
func before_each() -> void:
	_saved_story = App.get_story_progress().duplicate(true) as StoryProgress
	App.get_story_progress().trigger_threshold = 1000000
	App.get_story_progress().total_progress = 0
	AppClock.reset_to_system()
	_set_time(BASE_TIME)
	_path = "user://study_time_%d.db" % Time.get_ticks_usec()
	var types: NoteTypeManager = add_child_autofree(NoteTypeManager.new()) as NoteTypeManager
	assert_true(types.setup(_path))
	_decks = add_child_autofree(DeckManager.new()) as DeckManager
	assert_true(_decks.setup(_path))
	_notes = add_child_autofree(NoteManager.new()) as NoteManager
	assert_true(_notes.setup(_path))
	_cards = add_child_autofree(FailingCardManager.new()) as FailingCardManager
	assert_true(_cards.setup(_path))
	var scheduler: FsrsScheduler = FsrsScheduler.new()
	scheduler.enable_fuzzing = false
	_cards.set_scheduler(scheduler)
	_deck_id = int(_decks.create_deck("时间验证").data.id)
	_study = add_child_autofree(StudyManager.new()) as StudyManager
	_study.set_card_manager(_cards)
	_study.set_deck_manager(_decks)
	_study.set_note_manager(_notes)
	AppClock.time_changed.connect(_study.refresh_for_time_change)


## 结束测试会话并恢复原剧情状态和真实时间。## 输入: 无。
## 输出: 无。
func after_each() -> void:
	if is_instance_valid(_study):
		_study.end_session()
	AppClock.reset_to_system()
	App.get_story_progress().copy_from(_saved_story)
	App.get_story_progress().save_to_user()
	await get_tree().process_frame


## 通过时钟公共接口设置测试日期，保留秒数。## 输入: timestamp (int) - Unix 秒数。
## 输出: 无。
func _set_time(timestamp: int) -> void:
	assert_true(AppClock.set_datetime(AppClock.local_datetime(timestamp)).success)


## 通过实际笔记生成流程创建卡片，再布置调度测试条件。## 输入:
##   queue (int) - 队列类型。
##   due (int) - 对应队列单位的到期值。
##   last_review (int) - 上次复习时间，默认为 BASE_TIME 前一天。
## 输出: CardEntity - 已写入测试数据库的卡片。
func _card(queue: int, due: int, last_review: int = BASE_TIME - 86400) -> CardEntity:
	var result: Dictionary = _notes.create_note("__default__", {"front": "时间问题", "back": "保留的答案"}, _deck_id)
	assert_true(result.success, str(result))
	var card: CardEntity = result.data.cards[0] as CardEntity
	card.queue = queue
	card.due = due
	if queue != CardEntity.QUEUE_NEW:
		card.reps = 2
		card.stability = 3.0
		card.difficulty = 5.0
		card.last_review_time = last_review
		card.step = 0 if queue == CardEntity.QUEUE_LEARNING else -1
	assert_true(_cards.get_card_db().update_card(card).success)
	return card


## 读取本轮队列中的 ID，便于检查排序及重复。## 输入: 无。
## 输出: Array[int] - 按队列顺序排列的 ID。
func _ids() -> Array[int]:
	var ids: Array[int] = []
	for card: CardEntity in _study._current_queue:
		ids.append(card.id)
	return ids


## 学习卡用秒数、复习卡用天索引，入口查询与综合队列一致。## 输入: 无。
## 输出: 无。
func test_learning_and_review_due_units_follow_clock() -> void:
	_card(CardEntity.QUEUE_NEW, int(BASE_TIME / 86400))
	_card(CardEntity.QUEUE_LEARNING, BASE_TIME + 30)
	_card(CardEntity.QUEUE_REVIEW, int(BASE_TIME / 86400) + 1)
	assert_eq(_cards.get_study_queue(_deck_id).data.counts, {"new": 1, "learning": 0, "review": 0})
	_set_time(BASE_TIME + 60)
	assert_eq((_cards.get_due_cards(_deck_id, CardEntity.QUEUE_LEARNING).data as Array).size(), 1)
	_set_time(BASE_TIME + 86400)
	assert_eq(_cards.get_study_queue(_deck_id).data.counts, {"new": 1, "learning": 1, "review": 1})


## 一次评分的实体、历史、SQL 时间戳与下一状态来自同一软件时间。## 输入: 无。
## 输出: 无。
func test_review_timestamp_history_and_saved_due_agree() -> void:
	var card: CardEntity = _card(CardEntity.QUEUE_NEW, int(BASE_TIME / 86400))
	var result: Dictionary = _cards.answer_card(card.id, CardEntity.RATING_AGAIN, 345)
	assert_true(result.success)
	var saved: CardEntity = _cards.get_card(card.id).data as CardEntity
	var history: Array = JSON.parse_string(saved.review_history_json)
	assert_between(saved.last_review_time, BASE_TIME, BASE_TIME + 2)
	assert_eq(saved.last_review_time, result.data.card.last_review_time)
	assert_eq(int(history[0].get("reviewed_at", -1)), saved.last_review_time)
	assert_eq(saved.due - saved.last_review_time, 60)
	assert_eq(result.data.interval_text, "1分钟后")
	assert_eq(saved.last_time_taken, 345)


## 逻辑时间只决定新卡初始到期日，笔记和牌组创建时间保持真实。## 输入: 无。
## 输出: 无。
func test_creation_uses_virtual_due_and_real_metadata() -> void:
	var result: Dictionary = _notes.create_note("__default__", {"front": "创建", "back": "时间"}, _deck_id)
	assert_true(result.success)
	assert_eq(int(result.data.cards[0].due), int(BASE_TIME / 86400))
	assert_gt(int(result.data.note.created_at), BASE_TIME + 86400)
	assert_gt(int(_decks.get_deck(_deck_id).data.created_at), BASE_TIME + 86400)


## 今日统计只包含复习日上下界之间的最后一次复习。## 输入: 无。
## 输出: 无。
func test_today_count_excludes_past_and_future_days() -> void:
	var day_start: int = int(BASE_TIME / 86400) * 86400
	_card(CardEntity.QUEUE_REVIEW, 0, day_start - 1)
	_card(CardEntity.QUEUE_REVIEW, 0, day_start)
	_card(CardEntity.QUEUE_REVIEW, 0, day_start + 86399)
	_card(CardEntity.QUEUE_REVIEW, 0, day_start + 86400)
	assert_eq(int(_cards.get_today_studied_count(day_start).data), 2)


## 单纯调时和恢复时间不改写 cards 表。## 输入: 无。
## 输出: 无。
func test_clock_changes_do_not_rewrite_cards() -> void:
	var card: CardEntity = _card(CardEntity.QUEUE_REVIEW, int(BASE_TIME / 86400))
	var before: Dictionary = (_cards.get_card(card.id).data as CardEntity).to_dict()
	_set_time(BASE_TIME + 864000)
	AppClock.reset_to_system()
	assert_eq((_cards.get_card(card.id).data as CardEntity).to_dict(), before)


## 回退到上次复习前仍产生有限的记忆状态和合法的复习日。## 输入: 无。
## 输出: 无。
func test_review_before_last_review_clamps_elapsed() -> void:
	var card: CardEntity = _card(CardEntity.QUEUE_REVIEW, int(BASE_TIME / 86400), BASE_TIME + 86400)
	var result: Dictionary = _cards.answer_card(card.id, CardEntity.RATING_GOOD, 100)
	assert_true(result.success)
	assert_true(is_finite(result.data.card.stability))
	assert_gt(float(result.data.card.stability), 0.0)
	assert_gte(int(result.data.card.due), int(BASE_TIME / 86400) + 1)


## 调时保留当前卡、翻面与答题起点，仅刷新后续到期卡片。## 输入: 无。
## 输出: 无。
func test_refresh_preserves_current_face_and_rebuilds_remaining() -> void:
	var first: CardEntity = _card(CardEntity.QUEUE_REVIEW, int(BASE_TIME / 86400))
	_card(CardEntity.QUEUE_REVIEW, int(BASE_TIME / 86400))
	var future: CardEntity = _card(CardEntity.QUEUE_REVIEW, int(BASE_TIME / 86400) + 1)
	assert_true(_study.start_session(_deck_id).success)
	_study.show_answer()
	var question_start: int = _study._question_shown_at_ms
	watch_signals(App)
	watch_signals(_study)
	_set_time(BASE_TIME + 86400)
	assert_eq(int(_study.get_current_card().data.id), first.id)
	assert_true(_study._showing_back)
	assert_eq(_study._question_shown_at_ms, question_start)
	assert_has(_ids(), future.id)
	assert_signal_not_emitted(App, "card_answered")
	assert_signal_not_emitted(_study, "card_shown")
	_set_time(BASE_TIME - 86400)
	assert_eq(_ids(), [first.id])
	assert_eq(int(_study.get_session_progress().done), 0)
	assert_eq(int(_study.get_session_progress().total), 1)


## 新到期卡片遵守本轮额度，学习卡优先且重复刷新不会重复入队。## 输入: 无。
## 输出: 无。
func test_refresh_respects_quotas_order_and_deduplication() -> void:
	var first: CardEntity = _card(CardEntity.QUEUE_NEW, int(BASE_TIME / 86400))
	_card(CardEntity.QUEUE_NEW, int(BASE_TIME / 86400))
	var review: CardEntity = _card(CardEntity.QUEUE_REVIEW, int(BASE_TIME / 86400))
	_card(CardEntity.QUEUE_REVIEW, int(BASE_TIME / 86400))
	var learning: CardEntity = _card(CardEntity.QUEUE_LEARNING, BASE_TIME + 30)
	_study.start_session(_deck_id, 1, 1)
	_set_time(BASE_TIME + 60)
	assert_eq(_ids(), [first.id, learning.id, review.id])
	_set_time(BASE_TIME + 120)
	assert_eq(_ids(), [first.id, learning.id, review.id])
	assert_eq(_study._admitted_new.size(), 1)
	assert_eq(_study._admitted_review.size(), 1)


## 已答复习卡再次到期时沿用原额度，并保留已完成数量。## 输入: 无。
## 输出: 无。
func test_answered_card_can_become_due_again_without_extra_quota() -> void:
	var new_card: CardEntity = _card(CardEntity.QUEUE_NEW, int(BASE_TIME / 86400))
	var review: CardEntity = _card(CardEntity.QUEUE_REVIEW, int(BASE_TIME / 86400))
	var excluded: CardEntity = _card(CardEntity.QUEUE_REVIEW, int(BASE_TIME / 86400))
	_study.start_session(_deck_id, 1, 1)
	_study.skip_card()
	assert_eq(int(_study.get_current_card().data.id), review.id)
	assert_true(_study.answer(CardEntity.RATING_EASY).success)
	_set_time(BASE_TIME + 400 * 86400)
	assert_eq(_ids(), [new_card.id, review.id])
	assert_does_not_have(_ids(), excluded.id)
	assert_eq(_study._admitted_review.size(), 1)
	assert_eq(int(_study.get_session_progress().done), 1)
	assert_eq(int(_study.get_session_progress().total), 3)


## 查询失败暂停所有评分入口，重试后恢复当前卡片。## 输入: 无。
## 输出: 无。
func test_failed_refresh_blocks_rating_until_retry() -> void:
	var first: CardEntity = _card(CardEntity.QUEUE_NEW, int(BASE_TIME / 86400))
	var view: CardUI = add_child_autofree(CARD_SCENE.instantiate()) as CardUI
	view.set_managers(_study, _notes, _cards)
	_study.start_session(_deck_id)
	_study.show_answer()
	var content: String = view._content_label.text
	_cards.unavailable = true
	_set_time(BASE_TIME + 86400)
	assert_eq(view._state, CardUI.UIState.BACK)
	assert_eq(view._content_label.text, content)
	assert_true(view._good_btn.disabled)
	assert_true(view._retry_queue_button.visible)
	assert_false(_study.answer(CardEntity.RATING_GOOD).success)
	assert_eq(int(_study.get_session_progress().done), 0)
	_cards.unavailable = false
	view._retry_queue_button.pressed.emit()
	assert_false(view._good_btn.disabled)
	assert_false(view._retry_queue_button.visible)
	assert_eq(int(_study.get_current_card().data.id), first.id)
	assert_eq(view._content_label.text, content)


## 整轮和单题耗时依据单调计时，不受一天快进影响。## 输入: 无。
## 输出: 无。
func test_elapsed_time_is_monotonic_and_completion_stays_completed() -> void:
	_card(CardEntity.QUEUE_NEW, int(BASE_TIME / 86400))
	_study.start_session(_deck_id)
	_study._session_started_at_ms -= 1500
	_study._question_shown_at_ms -= 500
	_set_time(BASE_TIME + 86400)
	assert_between(int(_study.get_session_progress().elapsed_ms), 1500, 3000)
	assert_true(_study.answer(CardEntity.RATING_EASY).success)
	assert_false(_study.is_session_active())
	_set_time(BASE_TIME + 400 * 86400)
	assert_false(_study.is_session_active())


## 两种调度器都使用显式时间，学习间隔以秒保存。## 输入: 无。
## 输出: 无。
func test_scheduler_time_is_explicit_and_learning_due_is_seconds() -> void:
	var card: CardEntity = CardEntity.new()
	var simple: SimpleScheduler = SimpleScheduler.new()
	var state: Dictionary = simple.calculate_next_state(card, CardEntity.RATING_AGAIN, BASE_TIME)
	assert_eq(int(state.due), BASE_TIME + 600)
	assert_eq(simple.format_interval(state, BASE_TIME), "10分钟后")
	assert_eq(simple.estimate_next_interval(card, CardEntity.RATING_AGAIN, BASE_TIME), "10分钟后")
	var fsrs: FsrsScheduler = FsrsScheduler.new()
	fsrs.enable_fuzzing = false
	assert_eq(fsrs.estimate_next_interval(card, CardEntity.RATING_AGAIN, BASE_TIME), "1分钟后")

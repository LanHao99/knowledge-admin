extends Manager
class_name StudyManager


signal session_started(deck_id: int, counts: Dictionary)
signal session_ended(stats: Dictionary)
signal card_shown(card: CardEntity, is_back: bool)
signal card_answered(card: CardEntity, rating: int, next_interval: String)
signal queue_updated(counts: Dictionary)


var _deck_manager: DeckManager = null
var _card_manager: CardManager = null
var _note_manager: NoteManager = null

var _session: StudySessionEntity = null
var _current_queue: Array[CardEntity] = []
var _current_card_index: int = -1
var _is_active: bool = false
var _showing_back: bool = false
var _question_shown_at_ms: int = 0
var _done_count: int = 0
var _last_answer_stack: Array = []


## 注入 DeckManager。## 输入: deck_manager (DeckManager) - 牌组业务管理器。
## 输出: 无。
func set_deck_manager(deck_manager: DeckManager) -> void:
	_deck_manager = deck_manager


## 注入 CardManager。## 输入: card_manager (CardManager) - 卡片业务管理器。
## 输出: 无。
func set_card_manager(card_manager: CardManager) -> void:
	_card_manager = card_manager


## 注入 NoteManager（可选）。## 输入: note_manager (NoteManager) - 笔记业务管理器。
## 输出: 无。
func set_note_manager(note_manager: NoteManager) -> void:
	_note_manager = note_manager


## 开启学习会话。## 输入:
##   deck_id (int) - 目标牌组 ID。
##   new_limit (int) - 新卡上限。
##   review_limit (int) - 复习卡上限。
## 输出: 返回标准字典。成功时 `data` 为 `{counts: {new, learning, review, total}}`。
func start_session(deck_id: int, new_limit: int = 20, review_limit: int = 100) -> Dictionary:
	if _card_manager == null:
		return fail("CARD_MANAGER_NOT_SET", "card_manager 未注入")
	if deck_id <= 0:
		return fail("DECK_ID_INVALID", "deck_id 必须大于 0")

	if _deck_manager != null:
		var deck_result := _deck_manager.get_deck(deck_id)
		if not deck_result.get("success", false):
			return deck_result
		if deck_result.get("data", null) == null:
			return fail("DECK_NOT_FOUND", "牌组不存在")

	var queue_result := _card_manager.get_study_queue(deck_id)
	if not queue_result.get("success", false):
		return queue_result

	var queue_data: Dictionary = queue_result.get("data", {})
	var new_cards_source: Array[CardEntity] = _to_card_array(queue_data.get("new", []))
	var learning_cards: Array[CardEntity] = _to_card_array(queue_data.get("learning", []))
	var review_cards_source: Array[CardEntity] = _to_card_array(queue_data.get("review", []))
	var new_cards: Array[CardEntity] = _slice_cards(new_cards_source, max(new_limit, 0))
	var review_cards: Array[CardEntity] = _slice_cards(review_cards_source, max(review_limit, 0))

	_current_queue = []
	_current_queue.append_array(learning_cards)
	_current_queue.append_array(new_cards)
	_current_queue.append_array(review_cards)

	_session = StudySessionEntity.create_new(deck_id)
	_current_card_index = 0 if not _current_queue.is_empty() else -1
	_is_active = true
	_showing_back = false
	_question_shown_at_ms = _now_msec()
	_done_count = 0
	_last_answer_stack.clear()

	var counts := {
		"new": new_cards.size(),
		"learning": learning_cards.size(),
		"review": review_cards.size(),
		"total": _current_queue.size()
	}

	session_started.emit(deck_id, counts)
	if _current_card_index >= 0:
		card_shown.emit(_current_queue[_current_card_index], false)
	return ok({"counts": counts})


## 结束学习会话并清理内存状态。## 输入: 无。
## 输出: 返回标准字典。成功时 `data` 为统计信息字典。
func end_session() -> Dictionary:
	if not _is_active:
		return ok({})

	var stats: Dictionary = _build_stats()
	session_ended.emit(stats)
	_reset_runtime_state()
	return ok(stats)


## 判断会话是否处于激活状态。## 输入: 无。
## 输出: bool。激活返回 true。
func is_session_active() -> bool:
	return _is_active


## 获取当前卡片。## 输入: 无。
## 输出: 返回标准字典。成功时 `data` 为 CardEntity 或 null。
func get_current_card() -> Dictionary:
	if not _is_active:
		return ok(null)
	if _current_card_index < 0 or _current_card_index >= _current_queue.size():
		return ok(null)
	return ok(_current_queue[_current_card_index])


## 显示答案面（翻卡）。## 输入: 无。
## 输出: 返回标准字典。成功时 `data` 为当前 CardEntity。
func show_answer() -> Dictionary:
	if not _is_active:
		return fail("SESSION_NOT_ACTIVE", "学习会话未启动")

	var current_result := get_current_card()
	if not current_result.get("success", false):
		return current_result
	var card: CardEntity = current_result.get("data", null)
	if card == null:
		return fail("CARD_NOT_FOUND", "当前无可学习卡片")

	_showing_back = true
	card_shown.emit(card, true)
	return ok(card)


## 回答当前卡片并推进队列。## 输入: rating (int) - 用户评分（1~4）。
## 输出: 返回标准字典。成功时 `data` 为 `{next_card, counts, interval}`。
func answer(rating: int) -> Dictionary:
	if not _is_active:
		return fail("SESSION_NOT_ACTIVE", "学习会话未启动")
	if _card_manager == null:
		return fail("CARD_MANAGER_NOT_SET", "card_manager 未注入")
	if rating < CardEntity.RATING_AGAIN or rating > CardEntity.RATING_EASY:
		return fail("RATING_INVALID", "rating 必须在 1~4 范围内")

	var current_result := get_current_card()
	if not current_result.get("success", false):
		return current_result
	var card: CardEntity = current_result.get("data", null)
	if card == null:
		return fail("CARD_NOT_FOUND", "当前无可学习卡片")

	var elapsed_ms: int = max(_now_msec() - _question_shown_at_ms, 0)
	var answer_result := _card_manager.answer_card(card.id, rating, elapsed_ms)
	if not answer_result.get("success", false):
		return answer_result

	var answer_data: Dictionary = answer_result.get("data", {})
	var updated_card: CardEntity = answer_data.get("card", card)
	var interval_text: String = str(answer_data.get("interval_text", ""))

	_session.record_answer(rating, elapsed_ms, card.queue == CardEntity.QUEUE_NEW)
	_done_count += 1
	_last_answer_stack.append({
		"card_id": card.id,
		"rating": rating,
		"time_taken_ms": elapsed_ms,
		"queued_again": rating == CardEntity.RATING_AGAIN
	})

	# FSRS: 任何仍在 LEARNING 状态的卡片需继续留在队列中（下次到期可能仍在当天）
	if rating == CardEntity.RATING_AGAIN or updated_card.queue == CardEntity.QUEUE_LEARNING:
		_current_queue.append(updated_card)

	if _current_card_index >= 0 and _current_card_index < _current_queue.size():
		_current_queue.remove_at(_current_card_index)

	var counts_after_answer: Dictionary = _calculate_counts()
	card_answered.emit(updated_card, rating, interval_text)
	queue_updated.emit(counts_after_answer)

	if _current_queue.is_empty():
		var end_result := end_session()
		if not end_result.get("success", false):
			return end_result
		return ok({
			"next_card": null,
			"counts": counts_after_answer,
			"interval": interval_text
		})

	if _current_card_index >= _current_queue.size():
		_current_card_index = _current_queue.size() - 1

	# 找到下一个已到期的卡片（跳过未来到期的 LEARNING 卡片）
	var now_ts: int = _now_timestamp()
	var found_due: bool = false
	var search_steps: int = _current_queue.size()
	while search_steps > 0:
		search_steps -= 1
		if _current_card_index >= _current_queue.size():
			_current_card_index = 0
		var candidate: CardEntity = _current_queue[_current_card_index]
		# REVIEW/NEW 总是立即到期；LEARNING 需检查 due 秒级时间戳
		if candidate.queue != CardEntity.QUEUE_LEARNING or candidate.due <= now_ts:
			found_due = true
			break
		_current_card_index += 1

	if not found_due:
		# 所有剩余卡片都是未来到期的 LEARNING 卡 → 结束会话
		var end_result := end_session()
		if not end_result.get("success", false):
			return end_result
		return ok({
			"next_card": null,
			"counts": counts_after_answer,
			"interval": interval_text
		})

	_showing_back = false
	_question_shown_at_ms = _now_msec()
	var next_card: CardEntity = _current_queue[_current_card_index]
	card_shown.emit(next_card, false)

	return ok({
		"next_card": next_card,
		"counts": counts_after_answer,
		"interval": interval_text
	})


## 跳过当前卡片并推进到下一张。## 输入: 无。
## 输出: 返回标准字典。成功时 `data` 为下一个 CardEntity 或 null。
func skip_card() -> Dictionary:
	if not _is_active:
		return fail("SESSION_NOT_ACTIVE", "学习会话未启动")
	if _current_queue.is_empty() or _current_card_index < 0:
		return ok(null)

	var old_index: int = _current_card_index
	var card: CardEntity = _current_queue[_current_card_index]
	_current_queue.remove_at(_current_card_index)
	_current_queue.append(card)
	if _current_queue.size() > 0:
		if old_index >= _current_queue.size() - 1:
			_current_card_index = 0
		else:
			_current_card_index = old_index
		_showing_back = false
		_question_shown_at_ms = _now_msec()
		var next_card: CardEntity = _current_queue[_current_card_index]
		queue_updated.emit(_calculate_counts())
		card_shown.emit(next_card, false)
		return ok(next_card)

	return ok(null)


## 撤销上一次答案（预留能力，当前返回未实现）。## 输入: 无。
## 输出: 返回标准字典。当前固定返回失败。
func undo_last_answer() -> Dictionary:
	return fail("UNDO_NOT_IMPLEMENTED", "撤销功能尚未实现")


## 获取当前会话进度。## 输入: 无。
## 输出: Dictionary - `{total, done, remaining, new_seen, review_seen, elapsed_ms}`。
func get_session_progress() -> Dictionary:
	if _session == null:
		return {
			"total": 0,
			"done": 0,
			"remaining": 0,
			"new_seen": 0,
			"review_seen": 0,
			"elapsed_ms": 0
		}

	return {
		"total": _done_count + _current_queue.size(),
		"done": _done_count,
		"remaining": _current_queue.size(),
		"new_seen": _session.new_cards_seen,
		"review_seen": _session.review_cards_seen,
		"elapsed_ms": _session.get_elapsed_time_ms()
	}


## 对卡片数组做限量截取。## 输入:
##   cards (Array[CardEntity]) - 原卡片数组。
##   limit (int) - 最大数量，<=0 表示不限制。
## 输出: Array[CardEntity] - 截取后的数组。
func _slice_cards(cards: Array[CardEntity], limit: int) -> Array[CardEntity]:
	if limit <= 0:
		return cards
	if cards.size() <= limit:
		return cards
	var result: Array[CardEntity] = []
	for i in range(limit):
		result.append(cards[i])
	return result


## 计算当前队列分布统计。## 输入: 无。
## 输出: Dictionary - `{new, learning, review, total, remaining}`。
func _calculate_counts() -> Dictionary:
	var stats := {
		"new": 0,
		"learning": 0,
		"review": 0,
		"total": _done_count + _current_queue.size(),
		"remaining": _current_queue.size()
	}
	for card in _current_queue:
		match card.queue:
			CardEntity.QUEUE_NEW:
				stats["new"] += 1
			CardEntity.QUEUE_LEARNING:
				stats["learning"] += 1
			CardEntity.QUEUE_REVIEW:
				stats["review"] += 1
	return stats


## 构建会话结束统计。## 输入: 无。
## 输出: Dictionary - 会话统计汇总。
func _build_stats() -> Dictionary:
	if _session == null:
		return {}
	var stats: Dictionary = _session.to_stats_dict()
	stats["done"] = _done_count
	stats["remaining"] = _current_queue.size()
	stats["answers"] = _last_answer_stack.duplicate(true)
	return stats


## 重置运行时状态。
func _reset_runtime_state() -> void:
	_session = null
	_current_queue.clear()
	_current_card_index = -1
	_is_active = false
	_showing_back = false
	_question_shown_at_ms = 0
	_done_count = 0
	_last_answer_stack.clear()


## 获取当前毫秒时间戳。## 输入: 无。
## 输出: int - 当前毫秒时间戳。
func _now_msec() -> int:
	return Time.get_ticks_msec()


## 将任意数组安全转换为 CardEntity 强类型数组。## 输入: value (Variant) - 任意数组值，元素可为 CardEntity/Dictionary。
## 输出: Array[CardEntity] - 转换后的卡片数组。
func _to_card_array(value: Variant) -> Array[CardEntity]:
	var cards: Array[CardEntity] = []
	if typeof(value) != TYPE_ARRAY:
		return cards
	for item in value:
		if item is CardEntity:
			cards.append(item)
		elif item is Dictionary:
			var card := CardEntity.new()
			card.from_dict(item)
			cards.append(card)
	return cards

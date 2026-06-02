extends Manager
class_name CardManager


var _card_db: CardDB = null
var _note_db: NoteDB = null
var _scheduler: Scheduler = null


## 注入 CardDB 数据仓库。
##
## 输入: card_db (CardDB) - 卡片仓库对象。
## 输出: 无。
func set_card_db(card_db: CardDB) -> void:
	_card_db = card_db


## 注入 NoteDB 数据仓库（用于渲染内容聚合）。
##
## 输入: note_db (NoteDB) - 笔记仓库对象。
## 输出: 无。
func set_note_db(note_db: NoteDB) -> void:
	_note_db = note_db


## 注入调度器实例。
##
## 输入: scheduler (Scheduler) - 调度算法实现。
## 输出: 无。
func set_scheduler(scheduler: Scheduler) -> void:
	_scheduler = scheduler


## 获取单张卡片。
##
## 输入: card_id (int) - 卡片 ID。
## 输出: 返回标准字典。成功时 `data` 为 CardEntity 或 null。
func get_card(card_id: int) -> Dictionary:
	if _card_db == null:
		return fail("CARD_DB_NOT_SET", "card_db 未注入")
	return _card_db.get_card_by_id(card_id)


## 获取某条笔记下的卡片列表。
##
## 输入: note_id (int) - 笔记 ID。
## 输出: 返回标准字典。成功时 `data` 为 Array[CardEntity]。
func get_cards_by_note(note_id: int) -> Dictionary:
	if _card_db == null:
		return fail("CARD_DB_NOT_SET", "card_db 未注入")
	if note_id <= 0:
		return fail("NOTE_ID_INVALID", "note_id 必须大于 0")

	var rows_result := _card_db.fetch_all("SELECT * FROM cards WHERE note_id = ? ORDER BY id ASC;", [note_id])
	if not rows_result.get("success", false):
		return rows_result

	return ok(_map_rows_to_cards(rows_result.get("data", [])))


## 获取某个牌组下的卡片列表。
##
## 输入: deck_id (int) - 牌组 ID。
## 输出: 返回标准字典。成功时 `data` 为 Array[CardEntity]。
func get_cards_by_deck(deck_id: int) -> Dictionary:
	if _card_db == null:
		return fail("CARD_DB_NOT_SET", "card_db 未注入")
	if deck_id <= 0:
		return fail("DECK_ID_INVALID", "deck_id 必须大于 0")

	var rows_result := _card_db.fetch_all("SELECT * FROM cards WHERE deck_id = ? ORDER BY due ASC, id ASC;", [deck_id])
	if not rows_result.get("success", false):
		return rows_result

	return ok(_map_rows_to_cards(rows_result.get("data", [])))


## 获取指定队列的到期卡片。
##
## 输入:
##   deck_id (int) - 牌组 ID。
##   queue_type (int) - 队列类型。
##   limit (int) - 限制条数。
## 输出: 返回标准字典。成功时 `data` 为 Array[CardEntity]。
func get_due_cards(deck_id: int, queue_type: int, limit: int = 20) -> Dictionary:
	if _card_db == null:
		return fail("CARD_DB_NOT_SET", "card_db 未注入")
	return _card_db.get_due_cards(deck_id, queue_type, limit)


## 组装某牌组的学习队列。
##
## 输入: deck_id (int) - 牌组 ID。
## 输出: 返回标准字典。成功时 `data` 为 `{new, learning, review, counts}`。
func get_study_queue(deck_id: int) -> Dictionary:
	if _card_db == null:
		return fail("CARD_DB_NOT_SET", "card_db 未注入")
	if deck_id <= 0:
		return fail("DECK_ID_INVALID", "deck_id 必须大于 0")

	var now_ts: int = _now_timestamp()
	var now_day: int = int(now_ts / 86400)
	var due_result := _card_db.get_all_due_cards(deck_id, now_day, now_ts)
	if not due_result.get("success", false):
		return due_result

	var data: Dictionary = due_result.get("data", {})
	var new_cards: Array[CardEntity] = _to_card_array(data.get("new", []))
	var learning_cards: Array[CardEntity] = _to_card_array(data.get("learning", []))
	var review_cards: Array[CardEntity] = _to_card_array(data.get("review", []))

	return ok({
		"new": new_cards,
		"learning": learning_cards,
		"review": review_cards,
		"counts": {
			"new": new_cards.size(),
			"learning": learning_cards.size(),
			"review": review_cards.size()
		}
	})


## 提交一次卡片作答，计算并落库下一状态。
##
## 输入:
##   card_id (int) - 卡片 ID。
##   rating (int) - 评分（1~4）。
##   time_taken_ms (int) - 本次作答耗时（毫秒）。
## 输出: 返回标准字典。成功时 `data` 为 `{card, next_due, interval_days, interval_text}`。
func answer_card(card_id: int, rating: int, time_taken_ms: int) -> Dictionary:
	if _card_db == null:
		return fail("CARD_DB_NOT_SET", "card_db 未注入")
	if _scheduler == null:
		return fail("SCHEDULER_NOT_SET", "scheduler 未注入")
	if card_id <= 0:
		return fail("CARD_ID_INVALID", "card_id 必须大于 0")
	if rating < CardEntity.RATING_AGAIN or rating > CardEntity.RATING_EASY:
		return fail("RATING_INVALID", "rating 必须在 1~4 范围内")

	var card_result := _card_db.get_card_by_id(card_id)
	if not card_result.get("success", false):
		return card_result
	var card: CardEntity = card_result.get("data", null)
	if card == null:
		return fail("CARD_NOT_FOUND", "卡片不存在")

	var now_ts: int = _now_timestamp()
	var next_state: Dictionary = _scheduler.calculate_next_state(card, rating, now_ts)
	if not _is_valid_next_state(next_state):
		return fail("SCHEDULER_STATE_INVALID", "scheduler 返回状态缺少必要字段", next_state)

	card.queue = int(next_state.get("queue", card.queue))
	card.due = int(next_state.get("due", card.due))
	card.reps = int(next_state.get("reps", card.reps + 1))
	card.lapses = int(next_state.get("lapses", card.lapses))
	card.stability = float(next_state.get("stability", card.stability))
	card.difficulty = float(next_state.get("difficulty", card.difficulty))
	card.last_review_time = now_ts
	card.last_rating = rating
	card.last_time_taken = max(time_taken_ms, 0)
	card.append_review_history(rating, max(time_taken_ms, 0), now_ts)

	var save_result := _card_db.record_review(
		card.id,
		rating,
		card.last_time_taken,
		card.due,
		card.queue,
		card.reps,
		card.lapses,
		card.stability,
		card.difficulty,
		card.review_history_json
	)
	if not save_result.get("success", false):
		return save_result

	_notify_updated("card", card_id)
	return ok({
		"card": card,
		"next_due": card.due,
		"interval_days": int(next_state.get("interval_days", 0)),
		"interval_text": _scheduler.estimate_next_interval(card, rating)
	})


## 暂停或恢复单张卡片。
##
## 输入:
##   card_id (int) - 卡片 ID。
##   suspended (bool) - true 暂停，false 恢复。
## 输出: 返回标准字典。成功时 `data` 为 CardEntity。
func suspend_card(card_id: int, suspended: bool = true) -> Dictionary:
	if _card_db == null:
		return fail("CARD_DB_NOT_SET", "card_db 未注入")
	if card_id <= 0:
		return fail("CARD_ID_INVALID", "card_id 必须大于 0")

	var result := _card_db.suspend_cards([card_id], suspended)
	if not result.get("success", false):
		return result

	var card_result := _card_db.get_card_by_id(card_id)
	if not card_result.get("success", false):
		return card_result

	_notify_updated("card", card_id)
	return ok(card_result.get("data", null))


## 搁置或取消搁置单张卡片。
##
## 输入:
##   card_id (int) - 卡片 ID。
##   buried (bool) - true 搁置，false 取消搁置。
## 输出: 返回标准字典。成功时 `data` 为 CardEntity。
func bury_card(card_id: int, buried: bool = true) -> Dictionary:
	if _card_db == null:
		return fail("CARD_DB_NOT_SET", "card_db 未注入")
	if card_id <= 0:
		return fail("CARD_ID_INVALID", "card_id 必须大于 0")

	var card_result := _card_db.get_card_by_id(card_id)
	if not card_result.get("success", false):
		return card_result
	var card: CardEntity = card_result.get("data", null)
	if card == null:
		return fail("CARD_NOT_FOUND", "卡片不存在")

	if buried:
		card.queue = CardEntity.QUEUE_BURIED
		card.due = int(_now_timestamp() / 86400) + 1
	else:
		card.queue = CardEntity.QUEUE_NEW
		card.due = 0

	var update_result := _card_db.update_card(card)
	if not update_result.get("success", false):
		return update_result

	_notify_updated("card", card_id)
	return ok(card)


## 将卡片重置为全新状态。
##
## 输入: card_id (int) - 卡片 ID。
## 输出: 返回标准字典。成功时 `data` 为 CardEntity。
func reset_card(card_id: int) -> Dictionary:
	if _card_db == null:
		return fail("CARD_DB_NOT_SET", "card_db 未注入")
	if card_id <= 0:
		return fail("CARD_ID_INVALID", "card_id 必须大于 0")

	var card_result := _card_db.get_card_by_id(card_id)
	if not card_result.get("success", false):
		return card_result
	var card: CardEntity = card_result.get("data", null)
	if card == null:
		return fail("CARD_NOT_FOUND", "卡片不存在")

	card.queue = CardEntity.QUEUE_NEW
	card.due = 0
	card.reps = 0
	card.lapses = 0
	card.last_review_time = 0
	card.last_rating = 0
	card.last_time_taken = 0
	card.review_history_json = "[]"
	card.stability = 0.0
	card.difficulty = 0.0

	var update_result := _card_db.update_card(card)
	if not update_result.get("success", false):
		return update_result

	_notify_updated("card", card_id)
	return ok(card)


## 移动单张卡片到新牌组。
##
## 输入:
##   card_id (int) - 卡片 ID。
##   new_deck_id (int) - 新牌组 ID。
## 输出: 返回标准字典。成功时 `data` 为 CardEntity。
func move_card_to_deck(card_id: int, new_deck_id: int) -> Dictionary:
	if _card_db == null:
		return fail("CARD_DB_NOT_SET", "card_db 未注入")
	if card_id <= 0:
		return fail("CARD_ID_INVALID", "card_id 必须大于 0")
	if new_deck_id <= 0:
		return fail("DECK_ID_INVALID", "new_deck_id 必须大于 0")

	var deck_count_result := _card_db.count("decks", "id = ?", [new_deck_id])
	if not deck_count_result.get("success", false):
		return deck_count_result
	if int(deck_count_result.get("data", 0)) <= 0:
		return fail("DECK_NOT_FOUND", "目标牌组不存在")

	var move_result := _card_db.move_cards_to_deck([card_id], new_deck_id)
	if not move_result.get("success", false):
		return move_result

	var card_result := _card_db.get_card_by_id(card_id)
	if not card_result.get("success", false):
		return card_result

	_notify_updated("card", card_id)
	return ok(card_result.get("data", null))


## 获取渲染卡片所需内容（卡片 + 关联笔记字段）。
##
## 输入: card_id (int) - 卡片 ID。
## 输出: 返回标准字典。成功时 `data` 为 `{front, back, fields, card, note}`。
func get_card_content(card_id: int) -> Dictionary:
	if _card_db == null:
		return fail("CARD_DB_NOT_SET", "card_db 未注入")
	if _note_db == null:
		return fail("NOTE_DB_NOT_SET", "note_db 未注入")

	var card_result := _card_db.get_card_by_id(card_id)
	if not card_result.get("success", false):
		return card_result
	var card: CardEntity = card_result.get("data", null)
	if card == null:
		return fail("CARD_NOT_FOUND", "卡片不存在")

	var note_result := _note_db.get_note_by_id(card.note_id)
	if not note_result.get("success", false):
		return note_result
	var note: NoteEntity = note_result.get("data", null)
	if note == null:
		return fail("NOTE_NOT_FOUND", "关联笔记不存在")

	var front: String = _pick_field_value(note.fields_data, ["front", "Front", "正面", "question", "Question"])
	var back: String = _pick_field_value(note.fields_data, ["back", "Back", "背面", "answer", "Answer"])
	if front == "" and not note.fields_data.is_empty():
		var first_key: Variant = note.fields_data.keys()[0]
		front = str(note.fields_data.get(first_key, ""))
	if back == "" and note.fields_data.size() > 1:
		var keys: Array = note.fields_data.keys()
		var second_key: Variant = keys[1]
		back = str(note.fields_data.get(second_key, ""))

	return ok({
		"front": front,
		"back": back,
		"fields": note.fields_data.duplicate(true),
		"card": card,
		"note": note
	})


## 校验调度器返回的 next_state 是否包含必要字段。
##
## 输入: next_state (Dictionary) - 调度器返回字典。
## 输出: bool。字段齐全返回 true。
func _is_valid_next_state(next_state: Dictionary) -> bool:
	return next_state.has("queue") and next_state.has("due") and next_state.has("reps") and next_state.has("lapses")


## 将查询行数组映射为 CardEntity 数组。
##
## 输入: rows (Array) - cards 表行字典数组。
## 输出: Array[CardEntity]。
func _map_rows_to_cards(rows: Array) -> Array[CardEntity]:
	var cards: Array[CardEntity] = []
	for row in rows:
		if not (row is Dictionary):
			continue
		var card := CardEntity.new()
		card.from_dict(row)
		cards.append(card)
	return cards


## 将任意数组安全转换为 CardEntity 强类型数组。
##
## 输入: value (Variant) - 任意数组值，元素可为 CardEntity/Dictionary。
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


## 按候选字段名顺序获取第一个非空值。
##
## 输入:
##   fields (Dictionary) - 字段字典。
##   candidates (Array[String]) - 候选键名列表。
## 输出: String。找到则返回对应文本，否则返回空字符串。
func _pick_field_value(fields: Dictionary, candidates: Array[String]) -> String:
	for key in candidates:
		if fields.has(key):
			var value: String = str(fields.get(key, "")).strip_edges()
			if value != "":
				return value
	return ""

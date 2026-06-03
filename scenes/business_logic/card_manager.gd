extends Manager
class_name CardManager

## 卡片复习管理器，负责卡片的复习生命周期（调度、评分、状态变更）。
## 不持有 note 相关数据——卡片内容渲染由 NoteManager.get_content_for_card() 提供。


var _card_db: CardDB = null
var _scheduler: Scheduler = null


## 初始化数据层并打开数据库，由 Manager 自行管理 DB 生命周期。## 输入: db_path (String) - 数据库文件路径（如 "user://knowledge_admin.db"）。
## 输出: bool - 初始化成功返回 true。
func setup(db_path: String) -> bool:
	_card_db = CardDB.new()
	add_child(_card_db)
	_card_db.configure(db_path)
	if not _card_db.open():
		push_error("[CardManager] CardDB 打开失败: %s" % _card_db.get_last_error())
		return false
	if not _card_db.init_schema():
		push_error("[CardManager] CardDB Schema 初始化失败")
		return false

	return true


## 检查是否已完成 setup 初始化。## 输入: 无。
## 输出: bool - 已初始化返回 true。
func is_ready() -> bool:
	return _card_db != null and _card_db.is_open()


## 暴露底层 CardDB 实例，供 NoteManager 跨仓库事务编排使用。## 输入: 无。
## 输出: CardDB - 卡片仓库对象；未初始化时返回 null。
func get_card_db() -> CardDB:
	return _card_db


## 注入调度器实例。## 输入: scheduler (Scheduler) - 调度算法实现。
## 输出: 无。
func set_scheduler(scheduler: Scheduler) -> void:
	_scheduler = scheduler


## 创建一张复习卡片（供 NoteManager 在创建笔记后调用）。
## 调用方负责事务边界，本方法仅执行单条 INSERT 并返回实体。## 输入:
##   note_id (int) - 关联笔记 ID。
##   deck_id (int) - 归属牌组 ID。
##   template_order (int) - 模板序号，默认 0。
## 输出: 返回标准字典。成功时 `data` 为 CardEntity。
func create_card(note_id: int, deck_id: int, template_order: int = 0) -> Dictionary:
	if _card_db == null:
		return fail("CARD_DB_NOT_SET", "card_db 未注入")
	if note_id <= 0:
		return fail("NOTE_ID_INVALID", "note_id 必须大于 0")
	if deck_id <= 0:
		return fail("DECK_ID_INVALID", "deck_id 必须大于 0")

	return _card_db.create_card(note_id, deck_id, template_order)


## 删除某笔记下的全部卡片（供 NoteManager 在删除笔记前调用）。
## 调用方负责事务边界。## 输入: note_id (int) - 笔记 ID。
## 输出: 返回标准字典。成功时 `data` 为 int（删除的卡片数量）。
func delete_cards_by_note(note_id: int) -> Dictionary:
	if _card_db == null:
		return fail("CARD_DB_NOT_SET", "card_db 未注入")
	if note_id <= 0:
		return fail("NOTE_ID_INVALID", "note_id 必须大于 0")

	return _card_db.delete_cards_by_note(note_id)


## 获取单张卡片。## 输入: card_id (int) - 卡片 ID。
## 输出: 返回标准字典。成功时 `data` 为 CardEntity 或 null。
func get_card(card_id: int) -> Dictionary:
	if _card_db == null:
		return fail("CARD_DB_NOT_SET", "card_db 未注入")
	return _card_db.get_card_by_id(card_id)


## 获取某条笔记下的卡片列表。## 输入: note_id (int) - 笔记 ID。
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


## 获取某个牌组下的卡片列表。## 输入: deck_id (int) - 牌组 ID。
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


## 获取指定队列的到期卡片。## 输入:
##   deck_id (int) - 牌组 ID。
##   queue_type (int) - 队列类型。
##   limit (int) - 限制条数。
## 输出: 返回标准字典。成功时 `data` 为 Array[CardEntity]。
func get_due_cards(deck_id: int, queue_type: int, limit: int = 20) -> Dictionary:
	if _card_db == null:
		return fail("CARD_DB_NOT_SET", "card_db 未注入")
	return _card_db.get_due_cards(deck_id, queue_type, limit)


## 组装某牌组的学习队列。## 输入: deck_id (int) - 牌组 ID。
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


## 跨全牌组统计到期卡片总数（不含暂停/搁置）。## 输入:
##   now_day_index (int) - 当前天数索引。
##   now_timestamp (int) - 当前 Unix 时间戳（秒）。
## 输出: 返回标准字典。成功时 `data` 为 int（到期卡片总数）。
func get_global_due_count(now_day_index: int, now_timestamp: int) -> Dictionary:
	if _card_db == null:
		return fail("CARD_DB_NOT_SET", "card_db 未注入")
	return _card_db.get_global_due_count(now_day_index, now_timestamp)


## 统计今天复习过的卡片数。## 输入: today_start_ts (int) - 今天零点的 Unix 时间戳。
## 输出: 返回标准字典。成功时 `data` 为 int。
func get_today_studied_count(today_start_ts: int) -> Dictionary:
	if _card_db == null:
		return fail("CARD_DB_NOT_SET", "card_db 未注入")
	return _card_db.get_today_studied_count(today_start_ts)


## 提交一次卡片作答，计算并落库下一状态。## 输入:
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
		return fail("RATING_INVALID", "rating 必须在 1~4 范围")

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


## 暂停或恢复单张卡片。## 输入:
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


## 搁置或取消搁置单张卡片。## 输入:
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


## 将卡片重置为全新状态。## 输入: card_id (int) - 卡片 ID。
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


## 移动单张卡片到新牌组。## 输入:
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


# ── 内部工具方法 ──


## 校验调度器返回的 next_state 是否包含必要字段。## 输入: next_state (Dictionary) - 调度器返回字典。
## 输出: bool。字段齐全返回 true。
func _is_valid_next_state(next_state: Dictionary) -> bool:
	return next_state.has("queue") and next_state.has("due") and next_state.has("reps") and next_state.has("lapses")


## 将查询行数组映射为 CardEntity 数组。## 输入: rows (Array) - cards 表行字典数组。
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
extends DBManager
class_name CardDB


const _SECONDS_PER_DAY: int = 86400


## 创建一张新卡片并返回创建后的实体对象。## 输入:
##   note_id (int) - 关联笔记 ID。
##   deck_id (int) - 归属牌组 ID。
##   template_order (int) - 模板序号。
## 输出: 返回标准字典。成功时 `data` 为 CardEntity。
func create_card(note_id: int, deck_id: int, template_order: int = 0) -> Dictionary:
	if note_id <= 0:
		return fail("CARD_NOTE_ID_INVALID", "note_id 必须大于 0")
	if deck_id <= 0:
		return fail("CARD_DECK_ID_INVALID", "deck_id 必须大于 0")

	var due_day_index: int = int(Time.get_unix_time_from_system() / _SECONDS_PER_DAY)
	var insert_result := execute_bind(
		"INSERT INTO cards(note_id, deck_id, template_order, queue, due, reps, lapses, last_review_time, last_rating, last_time_taken, review_history_json, stability, difficulty) VALUES(?, ?, ?, ?, ?, 0, 0, 0, 0, 0, '[]', 0.0, 0.0);",
		[note_id, deck_id, template_order, CardEntity.QUEUE_NEW, due_day_index]
	)
	if not insert_result.get("success", false):
		return insert_result

	var id_result := last_insert_rowid()
	if not id_result.get("success", false):
		return id_result

	return get_card_by_id(int(id_result.get("data", 0)))


## 根据 ID 查询单张卡片。## 输入: card_id (int) - 卡片 ID。
## 输出: 返回标准字典。成功时 `data` 为 CardEntity；未找到时为 null。
func get_card_by_id(card_id: int) -> Dictionary:
	var result := fetch_one("SELECT * FROM cards WHERE id = ? LIMIT 1;", [card_id])
	if not result.get("success", false):
		return result

	var row: Dictionary = result.get("data", {})
	if row.is_empty():
		return ok(null)

	return ok(_row_to_card_entity(row))


## 更新整张卡片记录。## 输入: card (CardEntity) - 待更新实体，要求 id > 0。
## 输出: 返回标准字典。成功时 `data` 为 null。
func update_card(card: CardEntity) -> Dictionary:
	if card == null or card.id <= 0:
		return fail("CARD_ID_INVALID", "更新卡片时 card.id 必须大于 0")

	var sql := "UPDATE cards SET note_id = ?, deck_id = ?, template_order = ?, queue = ?, due = ?, reps = ?, lapses = ?, last_review_time = ?, last_rating = ?, last_time_taken = ?, review_history_json = ?, stability = ?, difficulty = ? WHERE id = ?;"
	return execute_bind(sql, [
		card.note_id,
		card.deck_id,
		card.template_order,
		card.queue,
		card.due,
		card.reps,
		card.lapses,
		card.last_review_time,
		card.last_rating,
		card.last_time_taken,
		card.review_history_json,
		card.stability,
		card.difficulty,
		card.id
	])


## 删除单张卡片。## 输入: card_id (int) - 卡片 ID。
## 输出: 返回标准字典。成功时 `data` 为 null。
func delete_card(card_id: int) -> Dictionary:
	return execute_bind("DELETE FROM cards WHERE id = ?;", [card_id])


## 删除某个笔记下的全部卡片。## 输入: note_id (int) - 笔记 ID。
## 输出: 返回标准字典。成功时 `data` 为 int（删除数量）。
func delete_cards_by_note(note_id: int) -> Dictionary:
	var before_result := count("cards", "note_id = ?", [note_id])
	if not before_result.get("success", false):
		return before_result
	var to_delete: int = int(before_result.get("data", 0))

	var delete_result := execute_bind("DELETE FROM cards WHERE note_id = ?;", [note_id])
	if not delete_result.get("success", false):
		return delete_result

	return ok(to_delete)


## 批量更新某个笔记下所有卡片的牌组归属。## 输入:
##   note_id (int) - 笔记 ID。
##   new_deck_id (int) - 新牌组 ID。
## 输出: 返回标准字典。成功时 `data` 为 int（更新数量）。
func update_cards_deck_by_note(note_id: int, new_deck_id: int) -> Dictionary:
	if note_id <= 0:
		return fail("CARD_NOTE_ID_INVALID", "note_id 必须大于 0")
	if new_deck_id <= 0:
		return fail("CARD_DECK_ID_INVALID", "deck_id 必须大于 0")
	return execute_bind("UPDATE cards SET deck_id = ? WHERE note_id = ?;", [new_deck_id, note_id])


## 查询指定队列的到期卡片。## 输入:
##   deck_id (int) - 牌组 ID。
##   queue_type (int) - 队列类型（0=new, 1=learning, 2=review）。
##   limit (int) - 限制条数，<=0 表示不限制。
## 输出: 返回标准字典。成功时 `data` 为 Array[CardEntity]。
func get_due_cards(deck_id: int, queue_type: int, limit: int = 20) -> Dictionary:
	var now_ts: int = int(Time.get_unix_time_from_system())
	var now_day_index: int = int(now_ts / _SECONDS_PER_DAY)

	var compare_value: int = now_day_index
	if queue_type == CardEntity.QUEUE_LEARNING:
		compare_value = now_ts

	var sql := "SELECT * FROM cards WHERE deck_id = ? AND queue = ? AND due <= ? ORDER BY due ASC, id ASC"
	var params: Array = [deck_id, queue_type, compare_value]
	if limit > 0:
		sql += " LIMIT ?"
		params.append(limit)
	sql += ";"

	var result := fetch_all(sql, params)
	if not result.get("success", false):
		return result

	return ok(_rows_to_card_entities(result.get("data", [])))


## 综合查询某牌组全部到期卡片（new/learning/review）。## 输入:
##   deck_id (int) - 牌组 ID。
##   now_day_index (int) - 当前天数索引（review/new 使用）。
##   now_timestamp (int) - 当前 Unix 时间戳（learning 使用）。
## 输出: 返回标准字典。成功时 `data` 为 `{new:Array, learning:Array, review:Array}`。
func get_all_due_cards(deck_id: int, now_day_index: int, now_timestamp: int) -> Dictionary:
	var new_result := _get_due_cards_with_time(deck_id, CardEntity.QUEUE_NEW, 0, now_day_index, now_timestamp)
	if not new_result.get("success", false):
		return new_result

	var learning_result := _get_due_cards_with_time(deck_id, CardEntity.QUEUE_LEARNING, 0, now_day_index, now_timestamp)
	if not learning_result.get("success", false):
		return learning_result

	var review_result := _get_due_cards_with_time(deck_id, CardEntity.QUEUE_REVIEW, 0, now_day_index, now_timestamp)
	if not review_result.get("success", false):
		return review_result

	return ok({
		"new": new_result.get("data", []),
		"learning": learning_result.get("data", []),
		"review": review_result.get("data", [])
	})


## 查询牌组卡片数量统计。## 输入: deck_id (int) - 牌组 ID。
## 输出: 返回标准字典。成功时 `data` 为 `{new, learning, review, suspended, total}`。
func get_card_counts(deck_id: int) -> Dictionary:
	var stats := {
		"new": 0,
		"learning": 0,
		"review": 0,
		"suspended": 0,
		"total": 0
	}

	var group_result := fetch_all("SELECT queue, COUNT(*) AS cnt FROM cards WHERE deck_id = ? GROUP BY queue;", [deck_id])
	if not group_result.get("success", false):
		return group_result

	for row in group_result.get("data", []):
		if not (row is Dictionary):
			continue
		var queue: int = int(row.get("queue", 0))
		var cnt: int = int(row.get("cnt", 0))
		match queue:
			CardEntity.QUEUE_NEW:
				stats["new"] = cnt
			CardEntity.QUEUE_LEARNING:
				stats["learning"] = cnt
			CardEntity.QUEUE_REVIEW:
				stats["review"] = cnt
			CardEntity.QUEUE_SUSPENDED:
				stats["suspended"] = cnt

	var total_result := count("cards", "deck_id = ?", [deck_id])
	if not total_result.get("success", false):
		return total_result
	stats["total"] = int(total_result.get("data", 0))

	return ok(stats)


## 跨全牌组统计到期卡片总数（不含暂停/搁置）。## 输入:
##   now_day_index (int) - 当前天数索引。
##   now_timestamp (int) - 当前 Unix 时间戳（秒）。
## 输出: 返回标准字典。成功时 `data` 为 int（到期卡片总数）。
func get_global_due_count(now_day_index: int, now_timestamp: int) -> Dictionary:
	var sql := """SELECT COUNT(*) AS cnt FROM cards 
		WHERE queue IN (?, ?, ?) 
		AND (
			(queue IN (?, ?) AND due <= ?)
			OR
			(queue = ? AND due <= ?)
		);"""
	var params: Array = [
		CardEntity.QUEUE_NEW, CardEntity.QUEUE_LEARNING, CardEntity.QUEUE_REVIEW,
		CardEntity.QUEUE_NEW, CardEntity.QUEUE_REVIEW, now_day_index,
		CardEntity.QUEUE_LEARNING, now_timestamp
	]
	return scalar(sql, params)


## 统计今天复习过的卡片数（按 last_review_time 落在今天的内部）。## 输入: today_start_ts (int) - 今天零点的 Unix 时间戳。
## 输出: 返回标准字典。成功时 `data` 为 int（今日复习卡片数）。
func get_today_studied_count(today_start_ts: int) -> Dictionary:
	var sql := "SELECT COUNT(*) AS cnt FROM cards WHERE last_review_time >= ?;"
	return scalar(sql, [today_start_ts])


## 记录一次复习结果（单条更新）。## 输入:
##   card_id (int) - 卡片 ID。
##   rating (int) - 评分（1~4）。
##   time_taken_ms (int) - 答题耗时（毫秒）。
##   new_due (int) - 新到期值。
##   new_queue (int) - 新队列。
##   new_reps (int) - 新复习次数。
##   new_lapses (int) - 新遗忘次数。
##   stability (float) - 新稳定性。
##   difficulty (float) - 新困难度。
##   history_json (String) - 新历史 JSON。
## 输出: 返回标准字典。成功时 `data` 为 null。
func record_review(card_id: int, rating: int, time_taken_ms: int, new_due: int, new_queue: int, new_reps: int, new_lapses: int, stability: float, difficulty: float, history_json: String) -> Dictionary:
	var now_ts: int = int(Time.get_unix_time_from_system())
	var sql := "UPDATE cards SET due = ?, queue = ?, reps = ?, lapses = ?, last_review_time = ?, last_rating = ?, last_time_taken = ?, review_history_json = ?, stability = ?, difficulty = ? WHERE id = ?;"
	return execute_bind(sql, [
		new_due,
		new_queue,
		new_reps,
		new_lapses,
		now_ts,
		rating,
		time_taken_ms,
		history_json,
		stability,
		difficulty,
		card_id
	])


## 批量移动卡片到新牌组。## 输入:
##   card_ids (Array[int]) - 卡片 ID 列表。
##   new_deck_id (int) - 新牌组 ID。
## 输出: 返回标准字典。成功时 `data` 为 int（更新数量）。
func move_cards_to_deck(card_ids: Array[int], new_deck_id: int) -> Dictionary:
	if card_ids.is_empty():
		return ok(0)
	if new_deck_id <= 0:
		return fail("DECK_ID_INVALID", "new_deck_id 必须大于 0")

	var unique_ids: Array[int] = _unique_int_ids(card_ids)
	if unique_ids.is_empty():
		return ok(0)
	var sql := "UPDATE cards SET deck_id = ? WHERE id IN (%s);" % _build_in_placeholders(unique_ids.size())
	var params: Array = [new_deck_id]
	for card_id in unique_ids:
		params.append(card_id)

	var result := execute_bind(sql, params)
	if not result.get("success", false):
		return result

	return ok(unique_ids.size())


## 批量暂停或恢复卡片。## 输入:
##   card_ids (Array[int]) - 卡片 ID 列表。
##   suspended (bool) - true 设为暂停；false 从暂停恢复为新卡队列。
## 输出: 返回标准字典。成功时 `data` 为 int（更新数量）。
func suspend_cards(card_ids: Array[int], suspended: bool = true) -> Dictionary:
	if card_ids.is_empty():
		return ok(0)

	var unique_ids: Array[int] = _unique_int_ids(card_ids)
	if unique_ids.is_empty():
		return ok(0)
	var placeholders: String = _build_in_placeholders(unique_ids.size())
	var params: Array = []
	var sql: String

	if suspended:
		sql = "UPDATE cards SET queue = ? WHERE id IN (%s);" % placeholders
		params.append(CardEntity.QUEUE_SUSPENDED)
	else:
		sql = "UPDATE cards SET queue = ? WHERE id IN (%s) AND queue = ?;" % placeholders
		params.append(CardEntity.QUEUE_NEW)

	for card_id in unique_ids:
		params.append(card_id)

	if not suspended:
		params.append(CardEntity.QUEUE_SUSPENDED)

	var result := execute_bind(sql, params)
	if not result.get("success", false):
		return result

	return ok(unique_ids.size())


## 在指定时间上下文中查询到期卡片。## 输入:
##   deck_id (int) - 牌组 ID。
##   queue_type (int) - 队列类型。
##   limit (int) - 限制条数，<=0 表示不限制。
##   now_day_index (int) - 当前天数索引。
##   now_timestamp (int) - 当前 Unix 时间戳。
## 输出: 返回标准字典。成功时 `data` 为 Array[CardEntity]。
func _get_due_cards_with_time(deck_id: int, queue_type: int, limit: int, now_day_index: int, now_timestamp: int) -> Dictionary:
	var compare_value: int = now_day_index
	if queue_type == CardEntity.QUEUE_LEARNING:
		compare_value = now_timestamp

	var sql := "SELECT * FROM cards WHERE deck_id = ? AND queue = ? AND due <= ? ORDER BY due ASC, id ASC"
	var params: Array = [deck_id, queue_type, compare_value]
	if limit > 0:
		sql += " LIMIT ?"
		params.append(limit)
	sql += ";"

	var result := fetch_all(sql, params)
	if not result.get("success", false):
		return result

	return ok(_rows_to_card_entities(result.get("data", [])))


## 将单行查询结果转换为 CardEntity。## 输入: row (Dictionary) - cards 表的一行数据。
## 输出: CardEntity - 反序列化后的实体对象。
func _row_to_card_entity(row: Dictionary) -> CardEntity:
	var entity := CardEntity.new()
	entity.from_dict(row)
	return entity


## 将多行查询结果转换为 CardEntity 数组。## 输入: rows (Array) - cards 表的多行数据。
## 输出: Array[CardEntity]。
func _rows_to_card_entities(rows: Array) -> Array[CardEntity]:
	var entities: Array[CardEntity] = []
	for row in rows:
		if row is Dictionary:
			entities.append(_row_to_card_entity(row))
	return entities


## 构造 SQL IN 子句占位符（如 "?,?,?"）。## 输入: count_value (int) - 占位符数量。
## 输出: String - 占位符字符串。
func _build_in_placeholders(count_value: int) -> String:
	if count_value <= 0:
		return ""
	var parts: PackedStringArray = []
	for i in range(count_value):
		parts.append("?")
	return ",".join(parts)


## 去重并清洗 ID 列表（仅保留 >0 的整数）。## 输入: ids (Array[int]) - 原始 ID 列表。
## 输出: Array[int] - 去重后的 ID 列表。
func _unique_int_ids(ids: Array[int]) -> Array[int]:
	var visited: Dictionary = {}
	var result: Array[int] = []
	for raw_id in ids:
		var value: int = int(raw_id)
		if value <= 0:
			continue
		if visited.has(value):
			continue
		visited[value] = true
		result.append(value)
	return result

extends Manager
class_name NoteManager

## 笔记管理器，负责笔记（知识点）的完整生命周期，同时管理 笔记↔卡片 的派生关系。
## 笔记是"知识单元"的载体（fields_data 存储实际内容），卡片是复习引擎的调度单元。
## NoteManager 持有 card_db 用于 create_note/delete_note 中的跨表事务编排——
## 这是合理的，因为"创建笔记时生成卡片"和"删除笔记时级联删卡"是笔记领域的业务规则。


var _note_db: NoteDB = null
var _card_db: CardDB = null # 保留用于跨表事务（create_note / delete_note），不直接写 SQL
var _deck_db: DeckDB = null
var _last_generate_error: Dictionary = {}


## 初始化数据层并打开数据库，由 Manager 自行管理 DB 生命周期。## 输入: db_path (String) - 数据库文件路径（如 "user://knowledge_admin.db"）。
## 输出: bool - 初始化成功返回 true。
func setup(db_path: String) -> bool:
	_note_db = NoteDB.new()
	add_child(_note_db)
	_note_db.configure(db_path)
	if not _note_db.open():
		push_error("[NoteManager] NoteDB 打开失败: %s" % _note_db.get_last_error())
		return false
	if not _note_db.init_schema():
		push_error("[NoteManager] NoteDB Schema 初始化失败")
		return false

	_card_db = CardDB.new()
	add_child(_card_db)
	_card_db.configure(db_path)
	if not _card_db.open():
		push_error("[NoteManager] CardDB 打开失败: %s" % _card_db.get_last_error())
		return false
	if not _card_db.init_schema():
		push_error("[NoteManager] CardDB Schema 初始化失败")
		return false

	_deck_db = DeckDB.new()
	add_child(_deck_db)
	_deck_db.configure(db_path)
	if not _deck_db.open():
		push_error("[NoteManager] DeckDB 打开失败: %s" % _deck_db.get_last_error())
		return false

	return true


## 检查是否已完成 setup 初始化。## 输入: 无。
## 输出: bool - 已初始化返回 true。
func is_ready() -> bool:
	return _note_db != null and _note_db.is_open() and _card_db != null and _card_db.is_open()


## 创建笔记并生成对应卡片。## 输入:
##   note_type_id (int) - 笔记类型 ID。
##   fields (Dictionary) - 字段数据。
##   deck_id (int) - 目标牌组 ID。
##   tags (Array[String]) - 标签列表（当前仅保留接口）。
## 输出: 返回标准字典。成功时 `data` 为 `{note: NoteEntity, cards: Array[CardEntity]}`。
func create_note(note_type_id: int, fields: Dictionary, deck_id: int, tags: Array[String] = []) -> Dictionary:
	if _note_db == null:
		return fail("NOTE_DB_NOT_SET", "note_db 未注入")
	if _card_db == null:
		return fail("CARD_DB_NOT_SET", "card_db 未注入")
	if note_type_id <= 0:
		return fail("NOTE_TYPE_INVALID", "note_type_id 必须大于 0")
	if fields.is_empty():
		return fail("NOTE_FIELDS_EMPTY", "fields 不能为空")
	if deck_id <= 0:
		return fail("DECK_ID_INVALID", "deck_id 必须大于 0")

	var deck_check := _validate_deck_exists(deck_id)
	if not deck_check.get("success", false):
		return deck_check

	var note_fields_json: String = JSON.new().stringify(fields)
	if note_fields_json == "":
		return fail("NOTE_FIELDS_JSON_INVALID", "fields 无法序列化为 JSON")

	var tx_result := run_in_databases_transaction([_note_db, _card_db], func() -> Dictionary:
		var note_result := _note_db.create_note(note_type_id, note_fields_json, deck_id, ",".join(tags))
		if not note_result.get("success", false):
			return note_result

		var note: NoteEntity = note_result.get("data", null)
		if note == null:
			return fail("NOTE_CREATE_FAILED", "创建笔记后未返回实体")

		var cards: Array[CardEntity] = _generate_cards_for_note(note.id, deck_id, note_type_id)
		if cards.is_empty() and not _last_generate_error.is_empty():
			return _last_generate_error

		_notify_created("note", note.id)
		if not cards.is_empty():
			batch_operation_completed.emit("card", cards.size())
		return ok({
			"note": note,
			"cards": cards
		})
	)

	return tx_result


## 更新笔记字段与标签，可选变更所属牌组。## 输入:
##   note_id (int) - 笔记 ID。
##   fields (Dictionary) - 新字段数据。
##   deck_id (int) - 可选，新牌组 ID。传 -1 表示不更改。
##   tags (Array[String]) - 标签列表（当前仅保留接口）。
## 输出: 返回标准字典。成功时 `data` 为 NoteEntity。
func update_note(note_id: int, fields: Dictionary, deck_id: int = -1, tags: Array[String] = []) -> Dictionary:
	if _note_db == null:
		return fail("NOTE_DB_NOT_SET", "note_db 未注入")
	if note_id <= 0:
		return fail("NOTE_ID_INVALID", "note_id 必须大于 0")
	if fields.is_empty():
		return fail("NOTE_FIELDS_EMPTY", "fields 不能为空")

	if not tags.is_empty():
		# 当前 schema 暂无 tags 独立存储，预留参数仅用于接口兼容
		pass

	var note_result := _note_db.get_note_by_id(note_id)
	if not note_result.get("success", false):
		return note_result
	var note: NoteEntity = note_result.get("data", null)
	if note == null:
		return fail("NOTE_NOT_FOUND", "笔记不存在")

	note.fields_data = fields.duplicate(true)
	if deck_id >= 0:
		note.deck_id = deck_id
	var update_result := _note_db.update_note(note)
	if not update_result.get("success", false):
		return update_result

	_notify_updated("note", note_id)
	return ok(note)


## 删除笔记及其关联卡片。## 输入: note_id (int) - 笔记 ID。
## 输出: 返回标准字典。成功时 `data` 为 `{deleted_cards: int}`。
func delete_note(note_id: int) -> Dictionary:
	if _note_db == null:
		return fail("NOTE_DB_NOT_SET", "note_db 未注入")
	if _card_db == null:
		return fail("CARD_DB_NOT_SET", "card_db 未注入")
	if note_id <= 0:
		return fail("NOTE_ID_INVALID", "note_id 必须大于 0")

	var note_result := _note_db.get_note_by_id(note_id)
	if not note_result.get("success", false):
		return note_result
	if note_result.get("data", null) == null:
		return fail("NOTE_NOT_FOUND", "笔记不存在")

	var tx_result := run_in_databases_transaction([_note_db, _card_db], func() -> Dictionary:
		var delete_cards_result := _card_db.delete_cards_by_note(note_id)
		if not delete_cards_result.get("success", false):
			return delete_cards_result

		var delete_note_result := _note_db.delete_note(note_id)
		if not delete_note_result.get("success", false):
			return delete_note_result

		var deleted_cards: int = int(delete_cards_result.get("data", 0))
		_notify_deleted("note", note_id)
		if deleted_cards > 0:
			batch_operation_completed.emit("card", deleted_cards)
		return ok({"deleted_cards": deleted_cards})
	)

	return tx_result


## 获取单条笔记。## 输入: note_id (int) - 笔记 ID。
## 输出: 返回标准字典。成功时 `data` 为 NoteEntity 或 null。
func get_note(note_id: int) -> Dictionary:
	if _note_db == null:
		return fail("NOTE_DB_NOT_SET", "note_db 未注入")
	return _note_db.get_note_by_id(note_id)


## 获取全部笔记列表。## 输入: 无。
## 输出: 返回标准字典。成功时 `data` 为 Array[NoteEntity]。
func get_all_notes() -> Dictionary:
	if _note_db == null:
		return fail("NOTE_DB_NOT_SET", "note_db 未注入")
	return _note_db.get_all_notes()


## 按牌组获取笔记列表。## 输入: deck_id (int) - 牌组 ID。
## 输出: 返回标准字典。成功时 `data` 为 Array[NoteEntity]。
func get_notes_by_deck(deck_id: int) -> Dictionary:
	if _note_db == null:
		return fail("NOTE_DB_NOT_SET", "note_db 未注入")
	return _note_db.get_notes_by_deck(deck_id)


## 按关键词搜索笔记。## 输入:
##   query (String) - 搜索词。
##   deck_id (int) - 可选牌组过滤，0 表示全局搜索。
## 输出: 返回标准字典。成功时 `data` 为 Array[NoteEntity]。
func search_notes(query: String, deck_id: int = 0) -> Dictionary:
	if _note_db == null:
		return fail("NOTE_DB_NOT_SET", "note_db 未注入")
	return _note_db.search_notes(query, deck_id)


## 获取渲染卡片所需的内容（卡片 + 关联笔记的字段数据）。
## Note ↔ Card 的内容拼接逻辑归属 NoteManager，因为内容的"正反面"由笔记字段决定。## 输入: card_id (int) - 卡片 ID。
## 输出: 返回标准字典。成功时 `data` 为 `{front, back, fields, card, note}`。
func get_content_for_card(card_id: int) -> Dictionary:
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


# ── 内部工具方法 ──


## 根据 note_type 生成卡片（V1 每条笔记只生成 1 张卡）。## 输入:
##   note_id (int) - 笔记 ID。
##   deck_id (int) - 目标牌组 ID。
##   note_type_id (int) - 笔记类型 ID。
## 输出: Array[CardEntity] - 创建成功的卡片数组。
func _generate_cards_for_note(note_id: int, deck_id: int, note_type_id: int) -> Array[CardEntity]:
	_last_generate_error = {}
	if _card_db == null:
		_last_generate_error = fail("CARD_DB_NOT_SET", "card_db 未注入")
		return []
	if note_id <= 0:
		_last_generate_error = fail("NOTE_ID_INVALID", "note_id 必须大于 0")
		return []
	if deck_id <= 0:
		_last_generate_error = fail("DECK_ID_INVALID", "deck_id 必须大于 0")
		return []
	if note_type_id <= 0:
		_last_generate_error = fail("NOTE_TYPE_INVALID", "note_type_id 必须大于 0")
		return []

	var card_result := _card_db.create_card(note_id, deck_id, 0)
	if not card_result.get("success", false):
		_last_generate_error = card_result
		return []

	var card: CardEntity = card_result.get("data", null)
	if card == null:
		_last_generate_error = fail("CARD_CREATE_FAILED", "创建卡片后未返回实体")
		return []

	return [card]


## 校验牌组是否存在。## 输入: deck_id (int) - 牌组 ID。
## 输出: 返回标准字典。成功时 `data` 为 true。
func _validate_deck_exists(deck_id: int) -> Dictionary:
	if deck_id <= 0:
		return fail("DECK_ID_INVALID", "deck_id 必须大于 0")

	if _deck_db != null:
		var deck_result := _deck_db.get_deck_by_id(deck_id)
		if not deck_result.get("success", false):
			return deck_result
		if deck_result.get("data", null) == null:
			return fail("DECK_NOT_FOUND", "牌组不存在")
		return ok(true)

	if _card_db == null:
		return fail("DECK_DB_NOT_SET", "deck_db 未注入，且无法回退到 card_db 校验")

	var count_result := _card_db.count("decks", "id = ?", [deck_id])
	if not count_result.get("success", false):
		return count_result
	if int(count_result.get("data", 0)) <= 0:
		return fail("DECK_NOT_FOUND", "牌组不存在")
	return ok(true)


## 按候选字段名顺序获取第一个非空值。## 输入:
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
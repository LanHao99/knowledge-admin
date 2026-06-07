extends DBManager
class_name NoteDB


## 创建一条笔记记录并返回创建后的实体对象。## 输入:
##   note_type_id (String) - 笔记类型 ID（TEXT 主键，如 "__default__" 或 UUID）。
##   fields_json (String) - 字段 JSON 字符串。
##   deck_id (int) - 所属牌组 ID。
##   tags (String) - 预留标签字符串，当前 schema 未落库，仅保留参数兼容。
## 输出: 返回标准字典。成功时 `data` 为 NoteEntity。
func create_note(note_type_id: String, fields_json: String, deck_id: int = 0, tags: String = "") -> Dictionary:
	if note_type_id.is_empty():
		return fail("NOTE_TYPE_INVALID", "note_type_id 不能为空")

	if tags != "":
		# 当前 schema 暂无 tags 列，仅保留接口兼容；标签由上层决定是否另行落库。
		pass
	var now_ts: int = int(Time.get_unix_time_from_system())
	var insert_result := execute_bind(
		"INSERT INTO notes(note_type_id, deck_id, fields_data, created_at) VALUES(?, ?, ?, ?);",
		[note_type_id, deck_id, fields_json, now_ts]
	)
	if not insert_result.get("success", false):
		return insert_result

	var id_result := last_insert_rowid()
	if not id_result.get("success", false):
		return id_result

	return get_note_by_id(int(id_result.get("data", 0)))


## 根据 ID 查询单条笔记。## 输入: note_id (int) - 笔记 ID。
## 输出: 返回标准字典。成功时 `data` 为 NoteEntity；未找到时为 null。
func get_note_by_id(note_id: int) -> Dictionary:
	var result := fetch_one("SELECT * FROM notes WHERE id = ? LIMIT 1;", [note_id])
	if not result.get("success", false):
		return result

	var row: Dictionary = result.get("data", {})
	if row.is_empty():
		return ok(null)

	return ok(_row_to_note_entity(row))


## 更新已有笔记。## 输入: note (NoteEntity) - 待更新实体，要求 id > 0。
## 输出: 返回标准字典。成功时 `data` 为 null。
func update_note(note: NoteEntity) -> Dictionary:
	if note == null or note.id <= 0:
		return fail("NOTE_ID_INVALID", "更新笔记时 note.id 必须大于 0")

	var sql := "UPDATE notes SET note_type_id = ?, deck_id = ?, fields_data = ? WHERE id = ?;"
	return execute_bind(sql, [note.note_type_id, note.deck_id, note.fields_to_json(), note.id])


## 删除单条笔记。## 输入: note_id (int) - 笔记 ID。
## 输出: 返回标准字典。成功时 `data` 为 null。
func delete_note(note_id: int) -> Dictionary:
	return execute_bind("DELETE FROM notes WHERE id = ?;", [note_id])


## 根据牌组查询笔记列表（通过 cards 表关联）。## 输入:
##   deck_id (int) - 牌组 ID。
##   limit (int) - 限制条数，<=0 表示不限制。
##   offset (int) - 偏移量。
## 输出: 返回标准字典。成功时 `data` 为 Array[NoteEntity]。
func get_notes_by_deck(deck_id: int, limit: int = 0, offset: int = 0) -> Dictionary:
	var sql := "SELECT DISTINCT n.* FROM notes n INNER JOIN cards c ON c.note_id = n.id WHERE c.deck_id = ? ORDER BY n.id DESC"
	var params: Array = [deck_id]
	if limit > 0:
		sql += " LIMIT ?"
		params.append(limit)
		if offset > 0:
			sql += " OFFSET ?"
			params.append(offset)
	sql += ";"

	var result := fetch_all(sql, params)
	if not result.get("success", false):
		return result

	return ok(_rows_to_note_entities(result.get("data", [])))


## 根据笔记类型查询笔记列表。## 输入: note_type_id (String) - 笔记类型 ID（TEXT 主键）。
## 输出: 返回标准字典。成功时 `data` 为 Array[NoteEntity]。
func get_notes_by_type(note_type_id: String) -> Dictionary:
	var result := fetch_all("SELECT * FROM notes WHERE note_type_id = ? ORDER BY id DESC;", [note_type_id])
	if not result.get("success", false):
		return result
	return ok(_rows_to_note_entities(result.get("data", [])))


## 搜索笔记（在 fields_data 文本中执行 LIKE 匹配）。## 输入:
##   query (String) - 搜索关键词。
##   deck_id (int) - 可选牌组过滤，0 表示不过滤。
## 输出: 返回标准字典。成功时 `data` 为 Array[NoteEntity]。
func search_notes(query: String, deck_id: int = 0) -> Dictionary:
	var keyword: String = query.strip_edges()
	if keyword == "":
		return ok([])

	var sql: String
	var params: Array
	if deck_id > 0:
		sql = "SELECT DISTINCT n.* FROM notes n INNER JOIN cards c ON c.note_id = n.id WHERE c.deck_id = ? AND n.fields_data LIKE ? ORDER BY n.id DESC;"
		params = [deck_id, "%" + keyword + "%"]
	else:
		sql = "SELECT * FROM notes WHERE fields_data LIKE ? ORDER BY id DESC;"
		params = ["%" + keyword + "%"]

	var result := fetch_all(sql, params)
	if not result.get("success", false):
		return result

	return ok(_rows_to_note_entities(result.get("data", [])))


## 获取笔记数量。## 输入: deck_id (int) - 可选牌组过滤，0 表示统计全库笔记。
## 输出: 返回标准字典。成功时 `data` 为 int。
func get_notes_count(deck_id: int = 0) -> Dictionary:
	if deck_id <= 0:
		return count("notes")

	var result := scalar(
		"SELECT COUNT(DISTINCT n.id) AS cnt FROM notes n INNER JOIN cards c ON c.note_id = n.id WHERE c.deck_id = ?;",
		[deck_id],
		0
	)
	if not result.get("success", false):
		return result
	return ok(int(result.get("data", 0)))


## 获取全部笔记列表。## 输入: 无。
## 输出: 返回标准字典。成功时 `data` 为 Array[NoteEntity]。
func get_all_notes() -> Dictionary:
	var result := fetch_all("SELECT * FROM notes ORDER BY id DESC;", [])
	if not result.get("success", false):
		return result
	return ok(_rows_to_note_entities(result.get("data", [])))


## 将单行查询结果转换为 NoteEntity。## 输入: row (Dictionary) - notes 表的一行数据。
## 输出: NoteEntity - 反序列化后的实体对象。
func _row_to_note_entity(row: Dictionary) -> NoteEntity:
	var entity := NoteEntity.new()
	entity.from_dict(row)
	return entity


## 将多行查询结果转换为 NoteEntity 数组。## 输入: rows (Array) - notes 表的多行数据。
## 输出: Array[NoteEntity]。
func _rows_to_note_entities(rows: Array) -> Array[NoteEntity]:
	var entities: Array[NoteEntity] = []
	for row in rows:
		if row is Dictionary:
			entities.append(_row_to_note_entity(row))
	return entities

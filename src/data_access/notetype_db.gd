extends DBManager
class_name NoteTypeDB


## 创建一条笔记类型记录并返回创建后的实体对象。## 输入:
##   entity (NoteTypeEntity) - 待创建的笔记类型实体，要求 id 非空且 name 非空。
## 输出: 返回标准字典。成功时 `data` 为 NoteTypeEntity。
func create_notetype(entity: NoteTypeEntity) -> Dictionary:
	if entity == null:
		return fail("NOTETYPE_NULL", "entity 不能为 null")
	if entity.id.is_empty():
		return fail("NOTETYPE_ID_EMPTY", "entity.id 不能为空")
	if entity.name.is_empty():
		return fail("NOTETYPE_NAME_EMPTY", "entity.name 不能为空")

	var d := entity.to_dict()
	var insert_result := execute_bind(
		"INSERT INTO note_types(id, name, fields_schema, card_templates, created_at) VALUES(?, ?, ?, ?, ?);",
		[d["id"], d["name"], d["fields_schema"], d["card_templates"], d["created_at"]]
	)
	if not insert_result.get("success", false):
		return insert_result

	return get_notetype_by_id(entity.id)


## 根据 ID 查询单条笔记类型。## 输入: notetype_id (String) - 笔记类型 ID。
## 输出: 返回标准字典。成功时 `data` 为 NoteTypeEntity；未找到时为 null。
func get_notetype_by_id(notetype_id: String) -> Dictionary:
	var result := fetch_one("SELECT * FROM note_types WHERE id = ? LIMIT 1;", [notetype_id])
	if not result.get("success", false):
		return result

	var row: Dictionary = result.get("data", {})
	if row.is_empty():
		return ok(null)

	return ok(_row_to_entity(row))


## 获取全部笔记类型列表（按 created_at 降序）。## 输入: 无。
## 输出: 返回标准字典。成功时 `data` 为 Array[NoteTypeEntity]。
func get_all_notetypes() -> Dictionary:
	var result := fetch_all("SELECT * FROM note_types ORDER BY created_at DESC;", [])
	if not result.get("success", false):
		return result

	var entities: Array[NoteTypeEntity] = []
	for row in result.get("data", []):
		if row is Dictionary:
			entities.append(_row_to_entity(row))
	return ok(entities)


## 更新已有笔记类型。## 输入: entity (NoteTypeEntity) - 待更新实体，要求 id 非空。
## 输出: 返回标准字典。成功时 `data` 为 null。
func update_notetype(entity: NoteTypeEntity) -> Dictionary:
	if entity == null:
		return fail("NOTETYPE_NULL", "entity 不能为 null")
	if entity.id.is_empty():
		return fail("NOTETYPE_ID_EMPTY", "更新笔记类型时 entity.id 不能为空")

	var d := entity.to_dict()
	var sql := "UPDATE note_types SET name = ?, fields_schema = ?, card_templates = ? WHERE id = ?;"
	return execute_bind(sql, [d["name"], d["fields_schema"], d["card_templates"], d["id"]])


## 删除单条笔记类型。## 输入: notetype_id (String) - 笔记类型 ID。
## 输出: 返回标准字典。成功时 `data` 为 null。
func delete_notetype(notetype_id: String) -> Dictionary:
	return execute_bind("DELETE FROM note_types WHERE id = ?;", [notetype_id])


## 检查指定名称的笔记类型是否已存在。## 输入: name_str (String) - 待检查的名称。
## 输出: bool。存在返回 true，不存在或查询失败返回 false。
func name_exists(name_str: String) -> bool:
	var result := scalar("SELECT COUNT(*) AS cnt FROM note_types WHERE name = ?;", [name_str], 0)
	if not result.get("success", false):
		return false
	return int(result.get("data", 0)) > 0


## 插入默认笔记类型（如果尚未存在）。使用 INSERT OR IGNORE 保证幂等。
## 即使多次调用也不会重复插入或报错。## 输入: 无。
## 输出: 返回标准字典。成功时 `data` 为 null（若已存在）或 NoteTypeEntity（若新建）。
func insert_default_notetype() -> Dictionary:
	var default_entity := NoteTypeEntity.make_default_notetype()
	var d := default_entity.to_dict()

	var result := execute_bind(
		"INSERT OR IGNORE INTO note_types(id, name, fields_schema, card_templates, created_at) VALUES(?, ?, ?, ?, ?);",
		[d["id"], d["name"], d["fields_schema"], d["card_templates"], d["created_at"]]
	)
	if not result.get("success", false):
		return result

	# 检查是否真的插入了（changes() > 0 表示新插入，否则表示已存在被 IGNORE）
	var changes_result := changes()
	if changes_result.get("success", false) and int(changes_result.get("data", 0)) > 0:
		return get_notetype_by_id(default_entity.id)

	return ok(null)


# ---- 内部辅助方法 ----

## 将单行查询结果转换为 NoteTypeEntity。## 输入: row (Dictionary) - note_types 表的一行数据。
## 输出: NoteTypeEntity - 反序列化后的实体对象。
func _row_to_entity(row: Dictionary) -> NoteTypeEntity:
	var entity := NoteTypeEntity.new()
	entity.from_dict(row)
	return entity

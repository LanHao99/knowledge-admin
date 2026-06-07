extends Manager
class_name NoteTypeManager

## 笔记类型管理器，负责笔记类型的创建、查询、更新、删除。
## 持有 NoteTypeDB 引用，在 setup() 中自动初始化数据库并插入默认笔记类型。


var _notetype_db: NoteTypeDB = null


## 初始化数据层并打开数据库，由 Manager 自行管理 DB 生命周期。
## 初始化完成后自动调用 insert_default_notetype() 确保默认类型存在。## 输入: db_path (String) - 数据库文件路径（如 "user://knowledge_admin.db"）。
## 输出: bool - 初始化成功返回 true。
func setup(db_path: String) -> bool:
	_notetype_db = NoteTypeDB.new()
	add_child(_notetype_db)
	_notetype_db.configure(db_path)

	if not _notetype_db.open():
		push_error("[NoteTypeManager] NoteTypeDB 打开失败: %s" % _notetype_db.get_last_error())
		return false

	var init_result: Dictionary = _notetype_db.init_schema()
	if not init_result.get("success", false):
		push_error("[NoteTypeManager] Schema 初始化失败: %s" % init_result.get("error", ""))
		return false

	var default_result := _notetype_db.insert_default_notetype()
	if not default_result.get("success", false):
		push_error("[NoteTypeManager] 插入默认笔记类型失败: %s" % default_result.get("error", ""))
		return false

	return true


## 获取当前 NoteTypeDB 引用（供其他 Manager 跨仓库查询）。## 输入: 无。
## 输出: NoteTypeDB - 笔记类型仓库对象；未初始化时为 null。
func get_notetype_db() -> NoteTypeDB:
	return _notetype_db


## 检查是否已完成 setup 初始化。## 输入: 无。
## 输出: bool - 已初始化返回 true。
func is_ready() -> bool:
	return _notetype_db != null and _notetype_db.is_open()


## 创建笔记类型。## 输入:
##   name (String) - 笔记类型名称（不可为空）。
##   fields_schema (Array) - 字段 schema 数组，如 [{"name": "正面", "order": 0}, ...]。
##   card_templates (Array) - 卡片模板数组，如 [{"name": "正面→背面", "qfmt": "{{正面}}", "afmt": "{{背面}}"}]。
## 输出: 返回标准字典。成功时 `data` 为 NoteTypeEntity。
func create_notetype(name: String, fields_schema: Array, card_templates: Array) -> Dictionary:
	if _notetype_db == null:
		return fail("NOTETYPE_DB_NOT_SET", "notetype_db 未注入")

	var trimmed_name: String = name.strip_edges()
	if trimmed_name == "":
		return fail("NOTETYPE_NAME_EMPTY", "笔记类型名称不能为空")
	if fields_schema.is_empty():
		return fail("NOTETYPE_FIELDS_EMPTY", "fields_schema 不能为空")
	if card_templates.is_empty():
		return fail("NOTETYPE_TEMPLATES_EMPTY", "card_templates 不能为空")

	if _notetype_db.name_exists(trimmed_name):
		return fail("NOTETYPE_NAME_DUPLICATE", "笔记类型名称已存在: %s" % trimmed_name)

	var entity := NoteTypeEntity.new()
	entity.id = _generate_id()
	entity.name = trimmed_name
	entity.fields_schema = fields_schema.duplicate(true)
	entity.card_templates = card_templates.duplicate(true)
	entity.created_at = Time.get_datetime_string_from_system()

	var tx_result := run_in_databases_transaction([_notetype_db], func() -> Dictionary:
		var created_result := _notetype_db.create_notetype(entity)
		if not created_result.get("success", false):
			return created_result
		var saved: NoteTypeEntity = created_result.get("data", null)
		if saved == null:
			return fail("NOTETYPE_CREATE_FAILED", "创建笔记类型后未返回实体")
		_notify_created("notetype", saved.id)
		return ok(saved)
	)
	return tx_result


## 根据 ID 查询笔记类型。## 输入: notetype_id (String) - 笔记类型 ID。
## 输出: 返回标准字典。成功时 `data` 为 NoteTypeEntity 或 null。
func get_notetype(notetype_id: String) -> Dictionary:
	if _notetype_db == null:
		return fail("NOTETYPE_DB_NOT_SET", "notetype_db 未注入")
	return _notetype_db.get_notetype_by_id(notetype_id)


## 获取全部笔记类型列表。## 输入: 无。
## 输出: 返回标准字典。成功时 `data` 为 Array[NoteTypeEntity]。
func get_all_notetypes() -> Dictionary:
	if _notetype_db == null:
		return fail("NOTETYPE_DB_NOT_SET", "notetype_db 未注入")
	return _notetype_db.get_all_notetypes()


## 更新笔记类型（名称、字段 schema、卡片模板）。## 输入: entity (NoteTypeEntity) - 待更新实体，要求 id 非空。
## 输出: 返回标准字典。成功时 `data` 为 null。
func update_notetype(entity: NoteTypeEntity) -> Dictionary:
	if _notetype_db == null:
		return fail("NOTETYPE_DB_NOT_SET", "notetype_db 未注入")
	if entity == null:
		return fail("NOTETYPE_NULL", "entity 不能为 null")
	if entity.id.is_empty():
		return fail("NOTETYPE_ID_EMPTY", "更新笔记类型时 entity.id 不能为空")

	# 名称唯一性校验：检查是否存在同名的其他笔记类型
	var existing_result := _notetype_db.get_notetype_by_id(entity.id)
	if not existing_result.get("success", false):
		return existing_result
	var existing: NoteTypeEntity = existing_result.get("data", null)
	if existing == null:
		return fail("NOTETYPE_NOT_FOUND", "要更新的笔记类型不存在")
	if existing.name != entity.name and _notetype_db.name_exists(entity.name):
		return fail("NOTETYPE_NAME_DUPLICATE", "笔记类型名称已存在: %s" % entity.name)

	var update_result := _notetype_db.update_notetype(entity)
	if not update_result.get("success", false):
		return update_result

	_notify_updated("notetype", entity.id)
	return ok()


## 删除笔记类型（默认类型不可删除）。## 输入: notetype_id (String) - 笔记类型 ID。
## 输出: 返回标准字典。成功时 `data` 为 null。
func delete_notetype(notetype_id: String) -> Dictionary:
	if _notetype_db == null:
		return fail("NOTETYPE_DB_NOT_SET", "notetype_db 未注入")

	var get_result := _notetype_db.get_notetype_by_id(notetype_id)
	if not get_result.get("success", false):
		return get_result
	var entity: NoteTypeEntity = get_result.get("data", null)
	if entity == null:
		return fail("NOTETYPE_NOT_FOUND", "笔记类型不存在")

	if entity.is_default():
		return fail("CANNOT_DELETE_DEFAULT", "默认笔记类型不可删除")

	var delete_result := _notetype_db.delete_notetype(notetype_id)
	if not delete_result.get("success", false):
		return delete_result

	_notify_deleted("notetype", notetype_id)
	return ok()


## 生成唯一 ID（毫秒时间戳 + 随机数）。## 输入: 无。
## 输出: String - 格式为 "timestamp_random"。
func _generate_id() -> String:
	return "%d_%d" % [Time.get_ticks_msec(), randi()]

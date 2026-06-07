extends Manager
class_name ImportManager

## 批量导入管理器，负责将 JSON 数据批量导入为笔记。
## 核心流程：JSON 文件 → 数组 → 逐行调用 NoteManager.create_note()。
## 复用 NoteManager 的 create_note 逻辑（含 cards 自动生成），保证单行失败不影响其他行。


# 委托 SchemaParser 进行 JSON 文件解析
const SchemaParserUtil := preload("res://src/utils/schema_parser.gd")

# 持有引用
var _note_manager: NoteManager = null
var _notetype_manager: NoteTypeManager = null
var _deck_db: DeckDB = null

# 信号
signal import_progress(current: int, total: int)
signal import_completed(result: Dictionary)
signal import_failed(error: Dictionary)

# 错误码常量
const ERR_JSON_FILE_NOT_FOUND := "JSON_FILE_NOT_FOUND"
const ERR_JSON_PARSE_FAILED := "JSON_PARSE_FAILED"
const ERR_JSON_NOT_ARRAY_OR_OBJECT := "JSON_NOT_ARRAY_OR_OBJECT"
const ERR_NESTED_OBJECT_DETECTED := "NESTED_OBJECT_DETECTED"
const ERR_REQUIRED_FIELD_MISSING := "REQUIRED_FIELD_MISSING"
const ERR_NOTE_TYPE_NOT_FOUND := "NOTE_TYPE_NOT_FOUND"
const ERR_DECK_NOT_FOUND := "DECK_NOT_FOUND"
const ERR_IMPORT_PARTIAL := "IMPORT_PARTIAL"

const PROGRESS_INTERVAL := 500


## 注入依赖引用。## 输入:
##   note_manager (NoteManager) - 笔记管理器，用于调用 create_note()。
##   notetype_manager (NoteTypeManager) - 笔记类型管理器，用于查询 note type 信息。
##   deck_db (DeckDB) - 牌组数据仓库，用于校验 deck 是否存在。
func setup(note_manager: NoteManager, notetype_manager: NoteTypeManager, deck_db: DeckDB) -> void:
	_note_manager = note_manager
	_notetype_manager = notetype_manager
	_deck_db = deck_db


## 检查依赖是否已注入。## 输入: 无。
## 输出: bool - 全部已注入返回 true。
func is_ready() -> bool:
	return _note_manager != null and _notetype_manager != null and _deck_db != null


## 从 JSON 文件导入数据。## 输入:
##   path (String) - JSON 文件路径（如 "user://data.json"）。
##   deck_id (String) - 目标牌组 ID。
##   note_type_id (String) - 笔记类型 ID。
##   mapping (Dictionary) - 字段映射，格式 {json_key: note_type_field_name}。传空字典则自动映射。
## 输出: 返回标准字典。`data` 为 ImportResult（{total_rows, imported, failed, failures}）。
func import_from_file(path: String, deck_id: String, note_type_id: String, mapping: Dictionary = {}) -> Dictionary:
	if not is_ready():
		return fail("IMPORT_NOT_READY", "ImportManager 依赖未注入")

	# 1) 解析 JSON 文件
	var parse_result := _parse_json_file(path)
	if not parse_result.get("success", false):
		return parse_result

	var raw_data: Variant = parse_result.get("data", null)
	if raw_data == null:
		return fail(ERR_JSON_PARSE_FAILED, "JSON 文件解析结果为空")

	# 2) 归一化为数组
	var data_array: Array = _normalize_to_array(raw_data)
	if data_array.is_empty():
		return fail(ERR_JSON_NOT_ARRAY_OR_OBJECT, "JSON 数据为空，无法导入")

	# 3) 验证扁平结构
	var flat_result := _validate_flat_structure(data_array)
	if not flat_result.get("success", false):
		return flat_result

	# 4) 执行导入
	return _do_import(data_array, mapping, deck_id, note_type_id)


## 从 Dictionary 数组导入数据（与 import_from_file 共用核心逻辑）。## 输入:
##   data_array (Array) - 要导入的数据数组。
##   deck_id (String) - 目标牌组 ID。
##   note_type_id (String) - 笔记类型 ID。
##   mapping (Dictionary) - 字段映射，格式 {json_key: note_type_field_name}。传空字典则自动映射。
## 输出: 返回标准字典。`data` 为 ImportResult。
func import_from_dict(data_array: Array, deck_id: String, note_type_id: String, mapping: Dictionary = {}) -> Dictionary:
	if not is_ready():
		return fail("IMPORT_NOT_READY", "ImportManager 依赖未注入")

	# 1) 归一化
	var normalized: Array = _normalize_to_array(data_array)
	if normalized.is_empty():
		return fail(ERR_JSON_NOT_ARRAY_OR_OBJECT, "数据为空，无法导入")

	# 2) 验证扁平结构
	var flat_result := _validate_flat_structure(normalized)
	if not flat_result.get("success", false):
		return flat_result

	# 3) 执行导入
	return _do_import(normalized, mapping, deck_id, note_type_id)


# ── 核心导入逻辑 ──


## 执行完整的导入流程：校验 → 自动映射 → 批量插入。## 输入:
##   data_array (Array) - 已归一化并验证的 Dictionary 数组。
##   mapping (Dictionary) - 用户提供的字段映射，空则自动生成。
##   deck_id (String) - 目标牌组 ID。
##   note_type_id (String) - 笔记类型 ID。
## 输出: ImportResult。
func _do_import(data_array: Array, mapping: Dictionary, deck_id: String, note_type_id: String) -> Dictionary:
	# 1) 校验牌组存在
	var deck_check := _validate_deck(deck_id)
	if not deck_check.get("success", false):
		return deck_check

	# 2) 获取笔记类型
	var nt_result := _notetype_manager.get_notetype(note_type_id)
	if not nt_result.get("success", false):
		return nt_result
	var note_type: NoteTypeEntity = nt_result.get("data", null)
	if note_type == null:
		return fail(ERR_NOTE_TYPE_NOT_FOUND, "笔记类型不存在: %s" % note_type_id)

	# 3) 收集 JSON keys
	var json_keys: Array[String] = []
	for row in data_array:
		if row is Dictionary:
			for key in row.keys():
				if not json_keys.has(str(key)):
					json_keys.append(str(key))

	# 4) 自动映射（若用户未提供）
	var final_mapping: Dictionary = mapping
	if mapping.is_empty():
		final_mapping = auto_map_fields(json_keys, note_type)
	# 如果 mapping 是合法字典则直接使用
	elif mapping is Dictionary and not mapping.is_empty():
		final_mapping = mapping

	# 5) 校验必需字段
	var required_check := _validate_required_fields(final_mapping, note_type)
	if not required_check.get("success", false):
		return required_check

	# 6) 执行批量导入
	return _execute_batch_import(data_array, final_mapping, deck_id, note_type_id)


## 批量逐行导入：对每行调用 note_manager.create_note()。## 输入:
##   data_array (Array) - 数据行数组。
##   mapping (Dictionary) - {json_key: note_type_field_name}。
##   deck_id (String) - 目标牌组 ID。
##   note_type_id (String) - 笔记类型 ID。
## 输出: ImportResult。
func _execute_batch_import(data_array: Array, mapping: Dictionary, deck_id: String, note_type_id: String) -> Dictionary:
	var total: int = data_array.size()
	var imported: int = 0
	var failed: int = 0
	var failures: Array = []

	for i in range(total):
		var row: Variant = data_array[i]
		if not (row is Dictionary):
			failures.append({"row": i, "error": "行 %d 不是 Dictionary 类型" % (i + 1)})
			failed += 1
			continue

		var row_dict: Dictionary = row as Dictionary

		# 按 mapping 构造 fields Dictionary
		var fields: Dictionary = {}
		for json_key in mapping.keys():
			var note_type_field: String = str(mapping[json_key])
			var raw_value: Variant = row_dict.get(json_key, "")
			fields[note_type_field] = _coerce_to_string(raw_value)

	# 调用 NoteManager 创建笔记（内部会生成卡片）
		var result: Dictionary = _note_manager.create_note(note_type_id, fields, int(deck_id), [])
		if result.get("success", false):
			imported += 1
		else:
			var err_msg: String = result.get("error", "未知错误")
			failures.append({"row": i + 1, "error": err_msg})
			failed += 1

		# 每 500 行发射进度信号
		if (i + 1) % PROGRESS_INTERVAL == 0 or (i + 1) == total:
			import_progress.emit(i + 1, total)

	# 构造结果
	var import_data := {
		"total_rows": total,
		"imported": imported,
		"failed": failed,
		"failures": failures
	}

	var final_code: String = "OK"
	if failed > 0 and imported > 0:
		final_code = ERR_IMPORT_PARTIAL
	elif failed > 0 and imported == 0:
		final_code = ERR_IMPORT_PARTIAL

	var result := ok(import_data)
	# 覆盖 code 以反映部分成功
	if failed > 0:
		result["code"] = ERR_IMPORT_PARTIAL
		result["success"] = (imported > 0)

	if imported == 0 and failed > 0:
		result["success"] = false
		import_failed.emit(result)
	else:
		import_completed.emit(result)

	return result


# ── 校验与映射辅助方法 ──


## 校验数据数组中无嵌套 Dictionary 或 Array 值（仅支持扁平键值对导入）。## 输入: data_array (Array) - 待校验数据。
## 输出: 返回标准字典。存在嵌套对象时 fail。
func _validate_flat_structure(data_array: Array) -> Dictionary:
	for i in range(data_array.size()):
		var item: Variant = data_array[i]
		if not (item is Dictionary):
			return fail(ERR_NESTED_OBJECT_DETECTED, "行 %d 不是 Dictionary 类型，导入仅支持扁平键值对" % (i + 1))

		var row: Dictionary = item as Dictionary
		for key in row.keys():
			var value: Variant = row[key]
			if typeof(value) == TYPE_DICTIONARY:
				return fail(ERR_NESTED_OBJECT_DETECTED,
					"行 %d 字段 '%s' 包含嵌套对象，导入仅支持扁平键值对" % [i + 1, str(key)])
			if typeof(value) == TYPE_ARRAY:
				return fail(ERR_NESTED_OBJECT_DETECTED,
					"行 %d 字段 '%s' 包含数组，导入仅支持扁平键值对" % [i + 1, str(key)])

	return ok(true)


## 双向小写自动映射：json_keys ↔ note_type.get_field_names()。
## 优先级：精确匹配 > 包含匹配 > 按位置兜底。## 输入:
##   json_keys (Array[String]) - JSON 数据的键名列表。
##   note_type (NoteTypeEntity) - 目标笔记类型，提供 field_names。
## 输出: Dictionary - {json_key: note_type_field_name}。
func auto_map_fields(json_keys: Array[String], note_type: NoteTypeEntity) -> Dictionary:
	var field_names: Array[String] = note_type.get_field_names()
	var mapping: Dictionary = {}
	var used_fields: Array[String] = []
	var used_json_keys: Array[String] = []

	# 第一轮：精确小写匹配
	for jk in json_keys:
		var jk_lower: String = jk.to_lower()
		for fn in field_names:
			if used_fields.has(fn):
				continue
			if jk_lower == fn.to_lower():
				mapping[jk] = fn
				used_fields.append(fn)
				used_json_keys.append(jk)
				break

	# 第二轮：包含匹配（双向）
	for jk in json_keys:
		if used_json_keys.has(jk):
			continue
		var jk_lower: String = jk.to_lower()
		for fn in field_names:
			if used_fields.has(fn):
				continue
			if jk_lower in fn.to_lower() or fn.to_lower() in jk_lower:
				mapping[jk] = fn
				used_fields.append(fn)
				used_json_keys.append(jk)
				break

	# 第三轮：兜底按位置分配（剩余未匹配的 json_key ↔ 未匹配的 field_name）
	var remaining_json: Array[String] = []
	for jk in json_keys:
		if not used_json_keys.has(jk):
			remaining_json.append(jk)

	var remaining_fields: Array[String] = []
	for fn in field_names:
		if not used_fields.has(fn):
			remaining_fields.append(fn)

	var pair_count: int = mini(remaining_json.size(), remaining_fields.size())
	for idx in range(pair_count):
		mapping[remaining_json[idx]] = remaining_fields[idx]

	return mapping


## 校验 mapping 的 values 是否覆盖了 note_type 的所有字段名。## 输入:
##   mapping (Dictionary) - {json_key: note_type_field_name}。
##   note_type (NoteTypeEntity) - 目标笔记类型。
## 输出: 返回标准字典。缺少必需字段时 fail。
func _validate_required_fields(mapping: Dictionary, note_type: NoteTypeEntity) -> Dictionary:
	var field_names: Array[String] = note_type.get_field_names()

	# 收集 mapping 中覆盖的 field names
	var covered: Array[String] = []
	for mkey in mapping.keys():
		var field_name: String = str(mapping[mkey])
		if not covered.has(field_name):
			covered.append(field_name)

	# 检查是否有缺失
	var missing: Array[String] = []
	for fn in field_names:
		if not covered.has(fn):
			missing.append(fn)

	if not missing.is_empty():
		return fail(ERR_REQUIRED_FIELD_MISSING,
			"缺少必需字段映射: %s。已映射: %s" % [", ".join(missing), ", ".join(covered)])

	return ok(true)


## 将任意值安全转换为 String。## 输入: value (Variant) - 任意类型值。
## 输出: String。
func _coerce_to_string(value: Variant) -> String:
	match typeof(value):
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_NIL:
			return "null"
		TYPE_INT, TYPE_FLOAT:
			return str(value)
		_:
			return str(value)


# ── JSON 解析辅助 ──


## 解析 JSON 文件（委托给 SchemaParser 的静态方法）。## 输入: path (String) - JSON 文件路径。
## 输出: 返回标准字典。成功时 `data` 为解析结果。
func _parse_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return fail(ERR_JSON_FILE_NOT_FOUND, "JSON 文件不存在: %s" % path)

	var parse_result: Dictionary = SchemaParserUtil.parse_json_file(path)
	if not parse_result.get("success", false):
		return fail(ERR_JSON_PARSE_FAILED, parse_result.get("error", "JSON 解析失败"))

	return ok(parse_result.get("data"))


## 归一化：如果顶层是单个 Dictionary → 包装成单元素 Array。## 输入: data (Variant) - 可能是 Dictionary 或 Array。
## 输出: Array。
func _normalize_to_array(data: Variant) -> Array:
	if typeof(data) == TYPE_ARRAY:
		return data as Array
	if typeof(data) == TYPE_DICTIONARY:
		return [data as Dictionary]

	var result: Array = []
	result.append(data)
	return result


## 校验牌组是否存在（通过 DeckDB）。## 输入: deck_id (String) - 牌组 ID。
## 输出: 返回标准字典。
func _validate_deck(deck_id: String) -> Dictionary:
	if _deck_db == null:
		return fail("DECK_DB_NOT_SET", "deck_db 未注入")

	# DeckDB 使用 int 作为 deck_id，此处尝试转为 int
	var deck_id_int: int = int(deck_id)
	if deck_id_int <= 0 and deck_id != "0":
		return fail(ERR_DECK_NOT_FOUND, "无效的牌组 ID: %s" % deck_id)

	var deck_result := _deck_db.get_deck_by_id(deck_id_int)
	if not deck_result.get("success", false):
		return deck_result
	if deck_result.get("data", null) == null:
		return fail(ERR_DECK_NOT_FOUND, "牌组不存在: %s" % deck_id)

	return ok(true)

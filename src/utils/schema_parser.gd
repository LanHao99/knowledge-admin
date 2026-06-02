class_name SchemaParser
extends RefCounted

# 这是一个纯静态工具类，专门负责把 JSON 格式的表结构配置翻译成 SQL 语句。
# 它的所有方法都是 static 的，不需要实例化即可调用。
# 这样做可以将“解析逻辑”与“数据库执行逻辑”彻底解耦。

## 解析 JSON 文件并返回 schema_config 字典。## 输入: file_path (String) - JSON 文件的绝对或相对路径（如 "res://data/db_schema.json"）。
## 输出: 返回标准字典。成功时 `data` 为解析出来的 Dictionary。
static func parse_json_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return _fail("SCHEMA_FILE_NOT_FOUND", "找不到 schema 文件: %s" % file_path)

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return _fail("SCHEMA_FILE_OPEN_FAILED", "无法打开 schema 文件: %s" % file_path)
	
	var text: String = file.get_as_text()
	var parser := JSON.new()
	var parse_code: int = parser.parse(text)
	
	if parse_code != OK:
		return _fail("SCHEMA_JSON_PARSE_FAILED", "schema JSON 解析失败: line=%d msg=%s" % [parser.get_error_line(), parser.get_error_message()])

	if typeof(parser.data) != TYPE_DICTIONARY:
		return _fail("SCHEMA_JSON_INVALID", "schema JSON 顶层必须是 Dictionary")

	return _ok(parser.data)


## 主入口1：生成建表和建索引语句。## 输入: schema_config (Dictionary) - 从 db_schema.json 解析出来的完整字典，必须包含 "tables" 和 "indexes" 键。
## 输出: 返回标准字典。成功时 `data` 为 Array[String]，包含所有要执行的 CREATE TABLE 和 CREATE INDEX 语句。
static func build_schema_statements(schema_config: Dictionary) -> Dictionary:
	if not schema_config.has("tables"):
		return _fail("SCHEMA_TABLES_MISSING", "schema 缺少 tables 字段")
	if not schema_config.has("indexes"):
		return _fail("SCHEMA_INDEXES_MISSING", "schema 缺少 indexes 字段")

	var statements: Array[String] = []
	var tables: Dictionary = schema_config.get("tables", {})

	# 先拼每张表的 CREATE TABLE
	for table_name in tables.keys():
		var table_cfg: Dictionary = tables[table_name]
		var table_result := _build_create_table_sql(table_name, table_cfg)
		if not table_result.get("success", false):
			return table_result
		statements.append(table_result.get("data", ""))

	# 再拼索引 CREATE INDEX
	var indexes: Array = schema_config.get("indexes", [])
	for index_cfg in indexes:
		if index_cfg is Dictionary:
			var index_result := _build_create_index_sql(index_cfg)
			if not index_result.get("success", false):
				return index_result
			statements.append(index_result.get("data", ""))

	return _ok(statements)


## 主入口2：生成删表语句（用于重置数据库）。## 输入: schema_config (Dictionary) - 必须包含 "drop_tables_order" 数组，指示安全删除表的顺序。
## 输出: 返回标准字典。成功时 `data` 为 Array[String]，包含按顺序排列的 DROP TABLE IF EXISTS 语句。
static func build_drop_statements(schema_config: Dictionary) -> Dictionary:
	if not schema_config.has("drop_tables_order"):
		return _fail("SCHEMA_DROP_ORDER_MISSING", "schema 缺少 drop_tables_order 字段")

	var order: Array = schema_config.get("drop_tables_order", [])
	var statements: Array[String] = []
	for table_name in order:
		statements.append("DROP TABLE IF EXISTS %s;" % table_name)

	return _ok(statements)


static func _build_create_table_sql(table_name: String, table_cfg: Dictionary) -> Dictionary: ## 依据表配置拼接 CREATE TABLE SQL
	if not table_cfg.has("columns"):
		return _fail("SCHEMA_COLUMNS_MISSING", "表 %s 缺少 columns 定义" % table_name)

	var columns_cfg: Dictionary = table_cfg.get("columns", {})
	var parts: Array[String] = []

	# 1) 拼接字段定义
	for column_name in columns_cfg.keys():
		var column_cfg: Dictionary = columns_cfg[column_name]
		parts.append(_build_column_sql(column_name, column_cfg))

	# 2) 拼接外键定义
	var foreign_keys: Array = table_cfg.get("foreign_keys", [])
	for fk in foreign_keys:
		if fk is Dictionary:
			parts.append(_build_foreign_key_sql(fk))

	# 把字段定义和外键定义拼成 CREATE TABLE (...) 主体
	var body: String = ", ".join(parts)
	var sql: String = "CREATE TABLE IF NOT EXISTS %s (%s);" % [table_name, body]
	return _ok(sql)


static func _build_column_sql(column_name: String, column_cfg: Dictionary) -> String: ## 把单个字段配置转换成列 SQL 片段
	# 先拼 "字段名 + 类型"
	var part: String = "%s %s" % [column_name, str(column_cfg.get("data_type", "TEXT"))]

	# 再按配置追加约束
	if bool(column_cfg.get("primary_key", false)):
		part += " PRIMARY KEY"
	if bool(column_cfg.get("auto_increment", false)):
		part += " AUTOINCREMENT"
	if bool(column_cfg.get("not_null", false)):
		part += " NOT NULL"
	if column_cfg.has("default"):
		part += " DEFAULT %s" % _format_default_value(column_cfg.get("default"))

	return part


static func _build_foreign_key_sql(fk_cfg: Dictionary) -> String: ## 把外键配置转换成 FOREIGN KEY SQL 片段
	var column: String = str(fk_cfg.get("column", ""))
	var ref_table: String = str(fk_cfg.get("ref_table", ""))
	var ref_column: String = str(fk_cfg.get("ref_column", "id"))
	var part: String = "FOREIGN KEY(%s) REFERENCES %s(%s)" % [column, ref_table, ref_column]

	if fk_cfg.has("on_delete"):
		part += " ON DELETE %s" % str(fk_cfg.get("on_delete", ""))

	return part


static func _build_create_index_sql(index_cfg: Dictionary) -> Dictionary: ## 依据索引配置拼接 CREATE INDEX SQL
	var name: String = str(index_cfg.get("name", ""))
	var table_name: String = str(index_cfg.get("table", ""))
	var columns: Array = index_cfg.get("columns", [])
	if name == "" or table_name == "" or columns.is_empty():
		return _fail("SCHEMA_INDEX_INVALID", "索引配置不完整: %s" % str(index_cfg))

	# unique=true 时生成 UNIQUE INDEX，否则普通 INDEX
	var unique_prefix: String = ""
	if bool(index_cfg.get("unique", false)):
		unique_prefix = "UNIQUE "

	var column_list: PackedStringArray = []
	for column_name in columns:
		column_list.append(str(column_name))

	var sql: String = "CREATE %sINDEX IF NOT EXISTS %s ON %s(%s);" % [unique_prefix, name, table_name, ", ".join(column_list)]
	return _ok(sql)


static func _format_default_value(value: Variant) -> String: ## 把 JSON 默认值转换为 SQL 可用文本
	# JSON 默认值要转换成 SQL 字面量：
	# null -> NULL, string -> 'text', bool -> 1/0, 数字保持原样
	match typeof(value):
		TYPE_NIL:
			return "NULL"
		TYPE_STRING:
			return "'%s'" % str(value).replace("'", "''")
		TYPE_BOOL:
			return "1" if value else "0"
		_:
			return str(value)


static func _ok(data: Variant = null) -> Dictionary: ## 返回标准成功结构
	return {
		"success": true,
		"data": data,
		"error": "",
		"code": "OK",
		"warning": ""
	}


static func _fail(code: String, message: String) -> Dictionary: ## 返回标准失败结构并记录警告
	push_warning("[SchemaParser Fail] [%s] %s" % [code, message])
	return {
		"success": false,
		"data": null,
		"error": message,
		"code": code
	}

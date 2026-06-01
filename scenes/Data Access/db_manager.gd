extends Node
class_name DBManager

# 这是“数据层基类”，专门负责：
# 1) 管理 sqlite 连接
# 2) 执行 SQL（查询/写入/事务）
# 3) 把 JSON 格式的表结构配置转成真实 SQL 并初始化数据库
#
# 你可以把它理解成：
# - 业务层只说“我要查/改什么”
# - DBManager 负责“具体怎么和数据库沟通”

signal db_error(code: String, message: String)

const SCHEMA_JSON_PATH: String = "res://data/db_schema.json" # 表结构配置文件路径

var _db: SQLite = null
var _db_path: String = "user://knowledge_admin.db"
var _schema_config: Dictionary = {}
var _last_error: String = ""
var _last_code: String = ""
var _last_rows: Array[Dictionary] = []


func configure(db_path: String = "user://knowledge_admin.db") -> void: ## 配置数据库文件路径
	_db_path = db_path


func open() -> bool: ## 创建并打开数据库连接，同时加载 schema JSON
	clear_last_error()

	# 1) 创建并打开数据库
	_db = SQLite.new()
	_db.path = _db_path
	if not _db.open_db():
		_fail("DB_OPEN_FAILED", "打开数据库失败: %s" % _db_path)
		return false

	# 2) 读取 schema 配置文件（后续 init_schema 会用到）
	var schema_result := load_schema_config()
	if not schema_result.get("success", false):
		close()
		return false

	return true


func close() -> void: ## 关闭数据库连接（当前插件无显式 close 时直接置空）
	_db = null


func is_open() -> bool: ## 检查数据库是否已经打开
	return _db != null


func require_open() -> bool: ## 要求数据库已打开，否则返回失败
	if is_open():
		return true
	_fail("DB_NOT_OPEN", "数据库尚未打开，请先调用 open()")
	return false


func load_schema_config() -> Dictionary: ## 从 JSON 文件读取 schema 配置
	# 1) 检查文件是否存在
	if not FileAccess.file_exists(SCHEMA_JSON_PATH):
		return fail("SCHEMA_FILE_NOT_FOUND", "找不到 schema 文件: %s" % SCHEMA_JSON_PATH)

	# 2) 读取文本（这里只负责读文件，不做建表）
	var file := FileAccess.open(SCHEMA_JSON_PATH, FileAccess.READ)
	if file == null:
		return fail("SCHEMA_FILE_OPEN_FAILED", "无法打开 schema 文件: %s" % SCHEMA_JSON_PATH)
	var text: String = file.get_as_text()

	# 3) 解析 JSON 并缓存到 _schema_config
	var parser := JSON.new()
	var parse_code: int = parser.parse(text)
	if parse_code != OK:
		return fail("SCHEMA_JSON_PARSE_FAILED", "schema JSON 解析失败: line=%d msg=%s" % [parser.get_error_line(), parser.get_error_message()])

	if typeof(parser.data) != TYPE_DICTIONARY:
		return fail("SCHEMA_JSON_INVALID", "schema JSON 顶层必须是 Dictionary")

	_schema_config = parser.data
	return ok(_schema_config)


func begin_transaction() -> bool: ## 开始事务，保证多步写入要么全成功要么全失败
	return _exec_bool("BEGIN TRANSACTION;", "TX_BEGIN_FAILED", "开启事务失败")


func commit_transaction() -> bool: ## 提交事务，把草稿中的改动真正写入数据库
	return _exec_bool("COMMIT;", "TX_COMMIT_FAILED", "提交事务失败")


func rollback_transaction() -> bool: ## 回滚事务，放弃本次事务中的所有草稿改动
	return _exec_bool("ROLLBACK;", "TX_ROLLBACK_FAILED", "回滚事务失败")


func execute(sql: String) -> Dictionary: ## 执行不带参数的 SQL，返回统一结果字典
	if not require_open():
		return fail("DB_NOT_OPEN", "数据库尚未打开")

	clear_last_error()
	if not _db.query(sql):
		return _sqlite_fail("SQL_EXEC_FAILED", sql)

	_last_rows = [] # 写操作后清空上一轮查询缓存
	return ok()


func execute_bind(sql: String, params: Array = []) -> Dictionary: ## 执行带参数 SQL（推荐写操作都用这个）
	if not require_open():
		return fail("DB_NOT_OPEN", "数据库尚未打开")

	clear_last_error()
	if not _db.query_with_bindings(sql, params):
		return _sqlite_fail("SQL_BIND_EXEC_FAILED", sql)

	_last_rows = [] # 写操作后清空上一轮查询缓存
	return ok()


func fetch_all(sql: String, params: Array = []) -> Dictionary: ## 查询多行数据，返回 data=Array[Dictionary]
	if not require_open():
		return fail("DB_NOT_OPEN", "数据库尚未打开")

	# 1) 执行查询（支持带参/不带参）
	clear_last_error()
	var success: bool = false
	if params.is_empty():
		success = _db.query(sql)
	else:
		success = _db.query_with_bindings(sql, params)

	if not success:
		return _sqlite_fail("SQL_QUERY_FAILED", sql)

	# 2) 整理结果，确保是字典数组
	var rows: Array = _db.query_result
	_last_rows = []
	for row in rows:
		if row is Dictionary:
			_last_rows.append(row)

	return ok(_last_rows)


func fetch_one(sql: String, params: Array = []) -> Dictionary: ## 查询单行数据，返回 data=Dictionary（没有则空字典）
	var result := fetch_all(sql, params)
	if not result.get("success", false):
		return result

	var rows: Array = result.get("data", [])
	if rows.is_empty():
		return ok({})

	return ok(rows[0])


func scalar(sql: String, params: Array = [], default_value: Variant = null) -> Dictionary: ## 查询单值（如 COUNT(*)），返回 data=单个值
	var result := fetch_one(sql, params)
	if not result.get("success", false):
		return result

	var row: Dictionary = result.get("data", {})
	if row.is_empty():
		return ok(default_value)

	for key in row.keys():
		return ok(row[key])

	return ok(default_value)


func init_schema() -> Dictionary: ## 根据 JSON 动态创建表和索引
	if not require_open():
		return fail("DB_NOT_OPEN", "数据库尚未打开")
	if _schema_config.is_empty():
		return fail("SCHEMA_NOT_LOADED", "schema 配置未加载，请先调用 open()")

	# 1) 先把 JSON 配置转成 SQL 列表
	var statements_result := _build_schema_statements()
	if not statements_result.get("success", false):
		return statements_result

	var statements: Array[String] = statements_result.get("data", [])

	# 2) 用事务执行，保证“要么都成功，要么都失败”
	if not begin_transaction():
		return fail("TX_BEGIN_FAILED", "初始化表结构时无法开启事务")

	for sql in statements:
		if not _db.query(sql):
			rollback_transaction()
			return _sqlite_fail("SCHEMA_INIT_FAILED", sql)

	# 3) 全部成功后提交
	if not commit_transaction():
		rollback_transaction()
		return fail("TX_COMMIT_FAILED", "初始化表结构提交失败")

	return ok()


func reset_schema() -> Dictionary: ## 根据 JSON 配置的删除顺序重置表结构（开发调试用）
	if not require_open():
		return fail("DB_NOT_OPEN", "数据库尚未打开")
	if _schema_config.is_empty():
		return fail("SCHEMA_NOT_LOADED", "schema 配置未加载，请先调用 open()")

	# 1) 根据配置拿到 DROP TABLE 顺序
	var drop_result := _build_drop_statements()
	if not drop_result.get("success", false):
		return drop_result

	var drop_sql: Array[String] = drop_result.get("data", [])

	# 2) 先删旧表，再重建
	if not begin_transaction():
		return fail("TX_BEGIN_FAILED", "重置表结构时无法开启事务")

	for sql in drop_sql:
		if not _db.query(sql):
			rollback_transaction()
			return _sqlite_fail("SCHEMA_RESET_FAILED", sql)

	if not commit_transaction():
		rollback_transaction()
		return fail("TX_COMMIT_FAILED", "删除旧表提交失败")

	# 3) 删除完成后立刻按最新 JSON 重建
	return init_schema()


func get_last_error() -> String: ## 获取最近一次失败信息
	return _last_error


func get_last_code() -> String: ## 获取最近一次失败代码
	return _last_code


func get_last_rows() -> Array[Dictionary]: ## 获取最近一次查询结果缓存
	return _last_rows


func clear_last_error() -> void: ## 清空最近一次错误信息
	_last_error = ""
	_last_code = ""


func ok(data: Variant = null, warning: String = "") -> Dictionary: ## 返回与 Manager 对齐的成功结构
	var result := {
		"success": true,
		"data": data,
		"error": "",
		"code": "OK",
		"warning": warning
	}
	if warning != "":
		push_warning("[DBManager OK with warning] %s" % warning)
	return result


func fail(code: String, message: String, data: Variant = null) -> Dictionary: ## 返回与 Manager 对齐的失败结构（公开入口）
	return _fail(code, message, data)


func _fail(code: String, message: String, data: Variant = null) -> Dictionary: ## 记录错误、打印控制台并发出错误信号
	_last_code = code
	_last_error = message
	push_warning("[%s] %s" % [code, message])
	printerr("[DBManager Fail] code=", code, " message=", message, " data=", data)
	db_error.emit(code, message)
	return {
		"success": false,
		"data": data,
		"error": message,
		"code": code
	}


func _build_schema_statements() -> Dictionary: ## 把 schema 配置转换成 CREATE TABLE/INDEX SQL 列表
	if not _schema_config.has("tables"):
		return fail("SCHEMA_TABLES_MISSING", "schema 缺少 tables 字段")
	if not _schema_config.has("indexes"):
		return fail("SCHEMA_INDEXES_MISSING", "schema 缺少 indexes 字段")

	var statements: Array[String] = []
	var tables: Dictionary = _schema_config.get("tables", {})

	# 先拼每张表的 CREATE TABLE
	for table_name in tables.keys():
		var table_cfg: Dictionary = tables[table_name]
		var table_result := _build_create_table_sql(table_name, table_cfg)
		if not table_result.get("success", false):
			return table_result
		statements.append(table_result.get("data", ""))

	# 再拼索引 CREATE INDEX
	var indexes: Array = _schema_config.get("indexes", [])
	for index_cfg in indexes:
		if index_cfg is Dictionary:
			var index_result := _build_create_index_sql(index_cfg)
			if not index_result.get("success", false):
				return index_result
			statements.append(index_result.get("data", ""))

	return ok(statements)


func _build_drop_statements() -> Dictionary: ## 把 schema 配置中的 drop 顺序转换成 DROP TABLE SQL 列表
	if not _schema_config.has("drop_tables_order"):
		return fail("SCHEMA_DROP_ORDER_MISSING", "schema 缺少 drop_tables_order 字段")

	var order: Array = _schema_config.get("drop_tables_order", [])
	var statements: Array[String] = []
	for table_name in order:
		statements.append("DROP TABLE IF EXISTS %s;" % table_name)

	return ok(statements)


func _build_create_table_sql(table_name: String, table_cfg: Dictionary) -> Dictionary: ## 依据表配置拼接 CREATE TABLE SQL
	if not table_cfg.has("columns"):
		return fail("SCHEMA_COLUMNS_MISSING", "表 %s 缺少 columns 定义" % table_name)

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
	return ok(sql)


func _build_column_sql(column_name: String, column_cfg: Dictionary) -> String: ## 把单个字段配置转换成列 SQL 片段
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


func _build_foreign_key_sql(fk_cfg: Dictionary) -> String: ## 把外键配置转换成 FOREIGN KEY SQL 片段
	var column: String = str(fk_cfg.get("column", ""))
	var ref_table: String = str(fk_cfg.get("ref_table", ""))
	var ref_column: String = str(fk_cfg.get("ref_column", "id"))
	var part: String = "FOREIGN KEY(%s) REFERENCES %s(%s)" % [column, ref_table, ref_column]

	if fk_cfg.has("on_delete"):
		part += " ON DELETE %s" % str(fk_cfg.get("on_delete", ""))

	return part


func _build_create_index_sql(index_cfg: Dictionary) -> Dictionary: ## 依据索引配置拼接 CREATE INDEX SQL
	var name: String = str(index_cfg.get("name", ""))
	var table_name: String = str(index_cfg.get("table", ""))
	var columns: Array = index_cfg.get("columns", [])
	if name == "" or table_name == "" or columns.is_empty():
		return fail("SCHEMA_INDEX_INVALID", "索引配置不完整: %s" % str(index_cfg))

	# unique=true 时生成 UNIQUE INDEX，否则普通 INDEX
	var unique_prefix: String = ""
	if bool(index_cfg.get("unique", false)):
		unique_prefix = "UNIQUE "

	var column_list: PackedStringArray = []
	for column_name in columns:
		column_list.append(str(column_name))

	var sql: String = "CREATE %sINDEX IF NOT EXISTS %s ON %s(%s);" % [unique_prefix, name, table_name, ", ".join(column_list)]
	return ok(sql)


func _format_default_value(value: Variant) -> String: ## 把 JSON 默认值转换为 SQL 可用文本
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


func _exec_bool(sql: String, code: String, message: String) -> bool: ## 给事务命令使用的简化布尔执行器
	if not require_open():
		return false

	clear_last_error()
	if not _db.query(sql):
		_sqlite_fail(code, sql, message)
		return false

	return true


func _sqlite_fail(code: String, sql: String, prefix: String = "") -> Dictionary: ## 统一包装 sqlite 插件报错内容
	var plugin_error: String = ""
	if is_open():
		plugin_error = str(_db.error_message)

	var message: String = "%s | SQL: %s" % [code, sql]
	if prefix != "":
		message = "%s | %s" % [prefix, message]
	if plugin_error != "":
		message = "%s | sqlite: %s" % [message, plugin_error]

	return _fail(code, message)

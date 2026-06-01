extends Node
class_name DBManager

signal db_error(code: String, message: String)

var _db: SQLite = null
var _db_path: String = "user://knowledge_admin.db"
var _last_error: String = ""
var _last_code: String = ""
var _last_rows: Array[Dictionary] = []


func configure(db_path: String = "user://knowledge_admin.db") -> void: ## 配置数据库文件路径
	_db_path = db_path


func open() -> bool: ## 创建并打开数据库连接
	clear_last_error()

	_db = SQLite.new()
	_db.path = _db_path

	if not _db.open_db():
		_fail("DB_OPEN_FAILED", "打开数据库失败: %s" % _db_path)
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

	_last_rows = []
	return ok()


func execute_bind(sql: String, params: Array = []) -> Dictionary: ## 执行带参数 SQL（推荐写操作都用这个）
	if not require_open():
		return fail("DB_NOT_OPEN", "数据库尚未打开")

	clear_last_error()
	if not _db.query_with_bindings(sql, params):
		return _sqlite_fail("SQL_BIND_EXEC_FAILED", sql)

	_last_rows = []
	return ok()


func fetch_all(sql: String, params: Array = []) -> Dictionary: ## 查询多行数据，返回 data=Array[Dictionary]
	if not require_open():
		return fail("DB_NOT_OPEN", "数据库尚未打开")

	# 1) 执行查询（支持是否带参数）
	clear_last_error()
	var success: bool = false
	if params.is_empty():
		success = _db.query(sql)
	else:
		success = _db.query_with_bindings(sql, params)

	if not success:
		return _sqlite_fail("SQL_QUERY_FAILED", sql)

	# 2) 拿到插件返回的查询结果
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


func init_schema() -> Dictionary: ## 初始化项目需要的数据表和索引
	if not require_open():
		return fail("DB_NOT_OPEN", "数据库尚未打开")

	# 1) 组织建表语句
	var statements: Array[String] = [
		"CREATE TABLE IF NOT EXISTS decks (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, parent_id INTEGER DEFAULT NULL, sort_order INTEGER NOT NULL DEFAULT 0, is_archived INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, FOREIGN KEY(parent_id) REFERENCES decks(id) ON DELETE CASCADE);",
		"CREATE UNIQUE INDEX IF NOT EXISTS idx_decks_parent_name ON decks(parent_id, name);",
		"CREATE TABLE IF NOT EXISTS notes (id INTEGER PRIMARY KEY AUTOINCREMENT, note_type_id INTEGER NOT NULL, fields_data TEXT NOT NULL, created_at INTEGER NOT NULL);",
		"CREATE TABLE IF NOT EXISTS cards (id INTEGER PRIMARY KEY AUTOINCREMENT, note_id INTEGER NOT NULL, deck_id INTEGER NOT NULL, template_order INTEGER NOT NULL DEFAULT 0, queue INTEGER NOT NULL DEFAULT 0, due INTEGER NOT NULL, reps INTEGER NOT NULL DEFAULT 0, lapses INTEGER NOT NULL DEFAULT 0, last_review_time INTEGER NOT NULL DEFAULT 0, last_rating INTEGER NOT NULL DEFAULT 0, last_time_taken INTEGER NOT NULL DEFAULT 0, review_history_json TEXT NOT NULL DEFAULT '[]', stability REAL NOT NULL DEFAULT 0.0, difficulty REAL NOT NULL DEFAULT 0.0, FOREIGN KEY(note_id) REFERENCES notes(id) ON DELETE CASCADE, FOREIGN KEY(deck_id) REFERENCES decks(id) ON DELETE CASCADE);",
		"CREATE INDEX IF NOT EXISTS idx_cards_deck_queue_due ON cards(deck_id, queue, due);",
		"CREATE INDEX IF NOT EXISTS idx_cards_note_id ON cards(note_id);"
	]

	# 2) 用事务保证要么全成功要么全失败
	if not begin_transaction():
		return fail("TX_BEGIN_FAILED", "初始化表结构时无法开启事务")

	for sql in statements:
		if not _db.query(sql):
			rollback_transaction()
			return _sqlite_fail("SCHEMA_INIT_FAILED", sql)

	if not commit_transaction():
		rollback_transaction()
		return fail("TX_COMMIT_FAILED", "初始化表结构提交失败")

	return ok()


func reset_schema() -> Dictionary: ## 重置数据表（开发调试用，会清空数据）
	if not require_open():
		return fail("DB_NOT_OPEN", "数据库尚未打开")

	var drop_sql: Array[String] = [
		"DROP TABLE IF EXISTS cards;",
		"DROP TABLE IF EXISTS notes;",
		"DROP TABLE IF EXISTS decks;"
	]

	if not begin_transaction():
		return fail("TX_BEGIN_FAILED", "重置表结构时无法开启事务")

	for sql in drop_sql:
		if not _db.query(sql):
			rollback_transaction()
			return _sqlite_fail("SCHEMA_RESET_FAILED", sql)

	if not commit_transaction():
		rollback_transaction()
		return fail("TX_COMMIT_FAILED", "删除旧表提交失败")

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

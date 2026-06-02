extends Node
class_name DBManager

## 这是"数据层基类"，专门负责：
# 1) 管理 sqlite 连接
# 2) 执行 SQL（查询/写入/事务）
# 3) 把 JSON 格式的表结构配置转成真实 SQL 并初始化数据表
# 4) 统一错误处理和返回格式
# 你可以把它理解成：
# - 业务层只说"我要查/改什么"
# - DBManager 负责"具体怎么和数据库沟通"

signal db_error(code: String, message: String)

const SCHEMA_JSON_PATH: String = "res://data/db_schema.json" # 表结构配置文件路径

# 进程内共享的 SQLite 句柄缓存：同一 db_path 仅持有一个底层连接，避免多连接对同一文件同时写入触发 SQLITE_BUSY (database is locked)
# 值结构: {"db": SQLite, "refs": int}
static var _shared_connections: Dictionary = {}

var _db: SQLite = null
var _db_path: String = "user://knowledge_admin.db"
var _owns_connection: bool = false  # 当前实例是否对共享连接持有一份引用计数
var _schema_config: Dictionary = {}
var _last_error: String = ""
var _last_code: String = ""
var _last_rows: Array[Dictionary] = []


func configure(db_path: String = "user://knowledge_admin.db") -> void: ## 配置数据库文件路径
	_db_path = db_path


func open() -> bool: ## 创建或复用同 db_path 的共享连接，并加载 schema JSON
	clear_last_error()

	# 1) 优先复用已存在的共享连接，避免对同一文件开多个 SQLite 句柄导致跨连接写锁冲突
	if _shared_connections.has(_db_path):
		var entry: Dictionary = _shared_connections[_db_path]
		_db = entry.get("db", null)
		if _db == null:
			_shared_connections.erase(_db_path)
		elif not _owns_connection:
			entry["refs"] = int(entry.get("refs", 0)) + 1
			_owns_connection = true

	# 2) 没有共享连接则新建一个并登记
	if _db == null:
		_db = SQLite.new()
		_db.path = _db_path
		if not _db.open_db():
			_fail("DB_OPEN_FAILED", "打开数据库失败: %s" % _db_path)
			_db = null
			return false
		_shared_connections[_db_path] = {"db": _db, "refs": 1}
		_owns_connection = true

	# 3) 读取 schema 配置文件（后续 init_schema 会用到）
	var schema_result := load_schema_config()
	if not schema_result.get("success", false):
		close()
		return false

	return true


func close() -> void: ## 释放当前实例对共享连接的引用，归零时真正放手底层 SQLite
	if _owns_connection and _shared_connections.has(_db_path):
		var entry: Dictionary = _shared_connections[_db_path]
		var refs: int = int(entry.get("refs", 0)) - 1
		if refs <= 0:
			_shared_connections.erase(_db_path)
		else:
			entry["refs"] = refs
	_owns_connection = false
	_db = null


## 暴露底层 SQLite 句柄，供跨仓库事务做"同连接去重"使用。
##
## 输入: 无。
## 输出: SQLite - 当前持有的底层连接；未打开返回 null。
func get_sqlite() -> SQLite:
	return _db


func _exit_tree() -> void: ## 节点销毁时自动释放共享连接引用，避免泄漏
	if _owns_connection:
		close()


func is_open() -> bool: ## 检查数据库是否已经打开
	return _db != null


func require_open() -> bool: ## 要求数据库已打开，否则返回失败
	if is_open():
		return true
	_fail("DB_NOT_OPEN", "数据库尚未打开，请先调用 open()")
	return false


func load_schema_config() -> Dictionary: ## 从 JSON 文件读取 schema 配置
	var result := SchemaParser.parse_json_file(SCHEMA_JSON_PATH)
	if not result.get("success", false):
		# 如果失败了，直接透传带有错误代码和信息的字典
		return result

	# 成功则缓存下来
	_schema_config = result.get("data", {})
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

	# 1) 执行查询（支持带/不带参）
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


## 获取最后一次 INSERT 的 rowid。
##
## 输入: 无。
## 输出: 返回标准字典。成功时 `data` 为 int（本连接最近一次 INSERT 的自增 ID）。
func last_insert_rowid() -> Dictionary:
	var result := scalar("SELECT last_insert_rowid() AS rowid;", [], 0)
	if not result.get("success", false):
		return result
	return ok(int(result.get("data", 0)))


## 获取最后一次 INSERT、UPDATE 或 DELETE 操作影响的行数。
##
## 输入: 无。
## 输出: 返回标准字典。成功时 `data` 为 int（最后一次数据变更影响的行数）。
func changes() -> Dictionary:
	var result := scalar("SELECT changes() AS cnt;", [], 0)
	if not result.get("success", false):
		return result
	return ok(int(result.get("data", 0)))


## 检查指定表是否存在。
##
## 输入: table_name (String) - 表名（如 "decks"）。
## 输出: bool。存在返回 true，不存在或查询失败返回 false。
func table_exists(table_name: String) -> bool:
	if not _is_safe_identifier(table_name):
		push_warning("[DBManager] 非法表名: %s" % table_name)
		return false
	var result := scalar("SELECT COUNT(*) AS cnt FROM sqlite_master WHERE type='table' AND name=?;", [table_name], 0)
	if not result.get("success", false):
		return false
	return int(result.get("data", 0)) > 0


## 获取表行数（支持 WHERE 子句）。
##
## 输入:
##   table_name (String) - 表名。
##   where_sql (String) - 可选过滤条件，不要含 `WHERE` 关键字（如 "deck_id=? AND queue=?"）。
##   params (Array) - where_sql 对应的绑定参数。
## 输出: 返回标准字典。成功时 `data` 为 int（符合条件的行数）。
func count(table_name: String, where_sql: String = "", params: Array = []) -> Dictionary:
	if not _is_safe_identifier(table_name):
		return fail("INVALID_TABLE_NAME", "非法表名: %s" % table_name)

	var sql: String = "SELECT COUNT(*) AS cnt FROM %s" % table_name
	if where_sql.strip_edges() != "":
		sql += " WHERE %s" % where_sql
	sql += ";"

	var result := scalar(sql, params, 0)
	if not result.get("success", false):
		return result
	return ok(int(result.get("data", 0)))


func init_schema() -> Dictionary: ## 根据 JSON 动态创建表和索引
	if not require_open():
		return fail("DB_NOT_OPEN", "数据库尚未打开")
	if _schema_config.is_empty():
		return fail("SCHEMA_NOT_LOADED", "schema 配置未加载，请先调用 open()")

	# 1) 调用专门的 SchemaParser，把 JSON 配置转成 SQL 列表
	var statements_result := SchemaParser.build_schema_statements(_schema_config)
	if not statements_result.get("success", false):
		return statements_result

	var statements: Array[String] = statements_result.get("data", [])

	# 2) 用事务执行，保证"要么都成功，要么都失败"
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

	# 1) 调用专门的 SchemaParser，根据配置拿到 DROP TABLE 顺序
	var drop_result := SchemaParser.build_drop_statements(_schema_config)
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


## 校验 SQL 标识符是否合法（仅允许字母、数字、下划线，且不能以数字开头）。
##
## 输入: identifier (String) - 待校验的标识符。
## 输出: bool。合法返回 true，否则返回 false。
func _is_safe_identifier(identifier: String) -> bool:
	if identifier == "":
		return false
	var regex := RegEx.new()
	var compile_code: int = regex.compile("^[A-Za-z_][A-Za-z0-9_]*$")
	if compile_code != OK:
		return false
	return regex.search(identifier) != null
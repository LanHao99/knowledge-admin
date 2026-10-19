extends Node
class_name Manager

# 这是"业务层基类"
# 作用：
# 1) 给所有子管理器提供统一的数据库入口（_db_manager）
# 2) 提供统一事务包装（begin/commit/rollback/run_in_transaction）
# 3) 提供统一返回格式（ok/fail）
#
# 你可以把它理解成：
# - 子类负责"做什么业务"
# - 这个基类负责"如何安全地和数据库配合"

signal manager_error(code: String, message: String)
signal entity_created(entity_type: String, entity_id: Variant)
signal entity_updated(entity_type: String, entity_id: Variant)
signal entity_deleted(entity_type: String, entity_id: Variant)
signal batch_operation_completed(entity_type: String, count: int)

# 初始化数据库应用
var _db_manager: DBManager = null


## 注入数据层管理器引用，子管理器后续的 SQL 操作都经它转发。## 输入: db_manager (DBManager) - 已初始化的数据层管理器实例。
## 输出: 无。
func set_db_manager(db_manager: DBManager) -> void:
	_db_manager = db_manager


## 获取当前注入的数据层管理器。## 输入: 无。
## 输出: DBManager - 当前注入的实例，未注入时返回 null。
func get_db_manager() -> DBManager:
	return _db_manager


## 检查是否已注入数据层管理器。## 输入: 无。
## 输出: bool - 已注入返回 true，否则返回 false。
func has_db_manager() -> bool:
	return _db_manager != null


## 要求数据层管理器必须存在，缺失时打印错误并发出 manager_error 信号。## 输入: 无。
## 输出: bool - 已注入返回 true；未注入返回 false，错误码为 DB_NOT_SET。
func require_db_manager() -> bool:
	if has_db_manager():
		return true
	push_error("DB manager not set")
	manager_error.emit("DB_NOT_SET", "db_manager is not assigned")
	return false


## 发出"实体已创建"通知信号。## 输入:
##   entity_type (String) - 实体类型，如 "deck"、"note"、"card"、"notetype"。
##   entity_id (Variant) - 实体主键 ID（int 或 String，兼容 TEXT 主键）。
## 输出: 无。
func _notify_created(entity_type: String, entity_id: Variant) -> void:
	entity_created.emit(entity_type, entity_id)


## 发出"实体已更新"通知信号。## 输入:
##   entity_type (String) - 实体类型，如 "deck"、"note"、"card"、"notetype"。
##   entity_id (Variant) - 实体主键 ID（int 或 String，兼容 TEXT 主键）。
## 输出: 无。
func _notify_updated(entity_type: String, entity_id: Variant) -> void:
	entity_updated.emit(entity_type, entity_id)


## 发出"实体已删除"通知信号。## 输入:
##   entity_type (String) - 实体类型，如 "deck"、"note"、"card"、"notetype"。
##   entity_id (Variant) - 实体主键 ID（int 或 String，兼容 TEXT 主键）。
## 输出: 无。
func _notify_deleted(entity_type: String, entity_id: Variant) -> void:
	entity_deleted.emit(entity_type, entity_id)

# 数据库修改操作规范化，先检测再提交，若提交失败则回滚
## 统一开始事务：先校验 db_manager 及其事务方法是否存在，再转发调用。## 输入: 无。
## 输出: bool - 转发到 DBManager.begin_transaction() 的结果；db_manager 缺失或方法不存在时返回 false。
func begin_transaction() -> bool:
	if not require_db_manager():
		return false
	if not _db_manager.has_method("begin_transaction"):
		_fail("DB_METHOD_MISSING", "begin_transaction() is not available")
		return false
	return _db_manager.call("begin_transaction")


## 统一提交事务：先校验 db_manager 及其事务方法是否存在，再转发调用。## 输入: 无。
## 输出: bool - 转发到 DBManager.commit_transaction() 的结果；db_manager 缺失或方法不存在时返回 false。
func commit_transaction() -> bool:
	if not require_db_manager():
		return false
	if not _db_manager.has_method("commit_transaction"):
		_fail("DB_METHOD_MISSING", "commit_transaction() is not available")
		return false
	return _db_manager.call("commit_transaction")


## 统一回滚事务：先校验 db_manager 及其事务方法是否存在，再转发调用。## 输入: 无。
## 输出: bool - 转发到 DBManager.rollback_transaction() 的结果；db_manager 缺失或方法不存在时返回 false。
func rollback_transaction() -> bool:
	if not require_db_manager():
		return false
	if not _db_manager.has_method("rollback_transaction"):
		_fail("DB_METHOD_MISSING", "rollback_transaction() is not available")
		return false
	return _db_manager.call("rollback_transaction")


## 用自动挡事务执行业务动作：自动开启事务，按 action 返回值提交或回滚，推荐子类优先使用。## 输入: action (Callable) - 事务体，约定返回标准结果字典。
## 输出: 返回标准字典。action 成功且提交成功时透传 action 的结果；开启事务失败返回 TX_BEGIN_FAILED，提交失败返回 TX_COMMIT_FAILED，业务失败则回滚后透传原结果或包装为 TX_ACTION_FAILED。
func run_in_transaction(action: Callable) -> Dictionary:
	# 步骤 1：先开事务
	if not begin_transaction():
		return fail("TX_BEGIN_FAILED", "无法开启事务")

	# 步骤 2：执行外部传进来的业务代码
	var result = action.call()

	# 步骤 3：根据返回结果决定提交还是回滚
	if typeof(result) == TYPE_DICTIONARY and result.get("success", false) == true:
		if commit_transaction():
			return result
		else:
			# 提交失败时也回滚，避免脏状态
			rollback_transaction()
			return fail("TX_COMMIT_FAILED", "操作成功了，但最后打包存入数据库时失败了")
	else:
		# 业务失败，直接回滚
		rollback_transaction()
		# 如果 result 已是标准错误字典，就原样透传
		if typeof(result) == TYPE_DICTIONARY and result.has("success"):
			return result
		else:
			# 不是标准结构时，统一包装为 fail
			return fail("TX_ACTION_FAILED", "事务操作执行失败或返回值不规范", result)


## 在多个 DBManager 上执行统一事务（跨仓库业务编排使用）。
## 内部会按底层 SQLite 句柄去重，同一物理连接只发一次 BEGIN/COMMIT，
## 避免同一 SQLite 文件被多个连接各自持锁导致 SQLITE_BUSY。## 输入:
##   databases (Array) - 参与事务的 DBManager 列表。
##   action (Callable) - 事务体，需返回标准结果字典。
## 输出: 返回标准字典。成功时透传 action 的成功结果。
func run_in_databases_transaction(databases: Array, action: Callable) -> Dictionary:
	# 1) 按底层 SQLite 句柄去重，保证同一物理连接只跑一次事务
	var dbs_by_conn: Array = _dedupe_by_sqlite(databases)
	if dbs_by_conn.is_empty():
		var direct_result: Variant = action.call()
		if _is_success_result(direct_result):
			return direct_result
		if typeof(direct_result) == TYPE_DICTIONARY and direct_result.has("success"):
			return direct_result
		return fail("TX_ACTION_FAILED", "事务操作执行失败或返回值不规范", direct_result)

	for db in dbs_by_conn:
		if not db.begin_transaction():
			_rollback_databases(dbs_by_conn)
			return fail("TX_BEGIN_FAILED", "无法开启跨仓库事务")

	var result: Variant = action.call()
	if not _is_success_result(result):
		_rollback_databases(dbs_by_conn)
		if typeof(result) == TYPE_DICTIONARY and result.has("success"):
			return result
		return fail("TX_ACTION_FAILED", "事务操作执行失败或返回值不规范", result)

	for db in dbs_by_conn:
		if not db.commit_transaction():
			_rollback_databases(dbs_by_conn)
			return fail("TX_COMMIT_FAILED", "跨仓库事务提交失败")

	return result


## 按底层 SQLite 句柄去重：多个 DBManager 若共享同一底层连接，只保留一个。
## DBManager.get_sqlite() 返回 null 的实例会被过滤（未初始化或已关闭）。## 输入: databases (Array) - 原始 DBManager 列表。
## 输出: Array - 去重后的 DBManager 列表，每个唯一 SQLite 句柄对应一个实例。
func _dedupe_by_sqlite(databases: Array) -> Array:
	var seen_connections: Array = [] # Array[SQLite]
	var unique_dbs: Array = [] # Array[DBManager]

	for obj in databases:
		if obj == null:
			continue
		if not (obj is DBManager):
			continue
		var db: DBManager = obj as DBManager
		var sqlite: SQLite = db.get_sqlite()
		if sqlite == null:
			continue
		if seen_connections.has(sqlite):
			continue
		seen_connections.append(sqlite)
		unique_dbs.append(db)

	return unique_dbs


## 判断一个返回值是否是标准成功字典。## 输入: result (Variant) - 任意返回值。
## 输出: bool。是标准成功结构时返回 true。
func _is_success_result(result: Variant) -> bool:
	return typeof(result) == TYPE_DICTIONARY and result.get("success", false) == true


## 对给定数据库列表执行回滚（忽略回滚失败，尽力而为）。## 输入: databases (Array) - DBManager 列表。
## 输出: 无。
func _rollback_databases(databases: Array) -> void:
	for db in databases:
		if db != null and db is DBManager:
			db.rollback_transaction()


## 获取当前 Unix 时间戳（秒级）。## 输入: 无。
## 输出: int - 当前系统时间戳。
func _now_timestamp() -> int:
	return int(Time.get_unix_time_from_system())


# 接收函数返回信息
## 返回标准成功结果结构，可携带警告信息。## 输入:
##   data (Variant) - 成功时携带的数据，默认 null。
##   warning (String) - 可选警告文本，非空时打印 push_warning，默认空字符串。
## 输出: 返回标准字典，含 success=true、data、code="OK" 和 warning。
func ok(data: Variant = null, warning: String = "") -> Dictionary:
	var result := {
		"success": true,
		"data": data,
		"error": "",
		"code": "OK",
		"warning": warning
	}
	if warning != "":
		push_warning("[Manager OK with warning] %s" % warning)
	return result


## 返回标准失败结果结构，是子类可调用的公开失败入口。## 输入:
##   code (String) - 错误代码，如 DB_NOT_SET。
##   message (String) - 面向调用者的错误描述。
##   data (Variant) - 失败时一并返回的数据，默认 null。
## 输出: 返回标准字典，含 success=false、error、code 和 data。
func fail(code: String, message: String, data: Variant = null) -> Dictionary:
	return _fail(code, message, data)


## 记录失败信息、打印警告与错误，并发出 manager_error 信号。## 输入:
##   code (String) - 错误代码。
##   message (String) - 错误描述。
##   data (Variant) - 失败时一并返回的数据，默认 null。
## 输出: 返回标准字典，含 success=false、error、code 和 data。
func _fail(code: String, message: String, data: Variant = null) -> Dictionary:
	push_warning("[%s] %s" % [code, message])
	printerr("[Manager Fail] code=", code, " message=", message, " data=", data)
	manager_error.emit(code, message)
	return {
		"success": false,
		"data": data,
		"error": message,
		"code": code
	}
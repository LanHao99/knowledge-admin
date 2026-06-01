extends Node
class_name Manager

signal manager_error(code: String, message: String)

# 初始化数据库应用
var _db_manager: DBManager = null


func set_db_manager(db_manager: DBManager) -> void: ## 注入数据层管理器引用
	_db_manager = db_manager


func get_db_manager() -> DBManager: ## 获取当前注入的 db_manager
	return _db_manager


func has_db_manager() -> bool: ## 检查是否已注入 db_manager
	return _db_manager != null


func require_db_manager() -> bool:
	if has_db_manager():
		return true
	push_error("DB manager not set")
	manager_error.emit("DB_NOT_SET", "db_manager is not assigned")
	return false

# 数据库修改操作规范化，先检测再提交，若提交失败则回滚
func begin_transaction() -> bool: ## 统一开始事务并做方法存在性校验
	if not require_db_manager():
		return false
	if not _db_manager.has_method("begin_transaction"):
		_fail("DB_METHOD_MISSING", "begin_transaction() is not available")
		return false
	return _db_manager.call("begin_transaction")


func commit_transaction() -> bool: ## 统一提交事务并做方法存在性校验
	if not require_db_manager():
		return false
	if not _db_manager.has_method("commit_transaction"):
		_fail("DB_METHOD_MISSING", "commit_transaction() is not available")
		return false
	return _db_manager.call("commit_transaction")


func rollback_transaction() -> bool: ## 统一回滚事务并做方法存在性校验
	if not require_db_manager():
		return false
	if not _db_manager.has_method("rollback_transaction"):
		_fail("DB_METHOD_MISSING", "rollback_transaction() is not available")
		return false
	return _db_manager.call("rollback_transaction")


func run_in_transaction(action: Callable) -> Dictionary: ## 数据库操作自动化
	if not begin_transaction():
		return fail("TX_BEGIN_FAILED", "无法开启事务")
		
	var result = action.call()
	

	if typeof(result) == TYPE_DICTIONARY and result.get("success", false) == true:
		if commit_transaction():
			return result
		else:
			rollback_transaction()
			return fail("TX_COMMIT_FAILED", "操作成功了，但最后打包存入数据库时失败了")
	else:
		rollback_transaction()
		# 如果它本来就是个标准错误字典，就原样返回；不然就帮它包装成标准错误
		if typeof(result) == TYPE_DICTIONARY and result.has("success"):
			return result
		else:
			return fail("TX_ACTION_FAILED", "事务操作执行失败或返回值不规范", result)


# 接收函数返回信息
func ok(data: Variant = null, warning: String = "") -> Dictionary: ## 返回标准成功结果结构，可携带警告信息
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


func fail(code: String, message: String, data: Variant = null) -> Dictionary: ## 返回标准失败结果结构（公开接口）
	return _fail(code, message, data)


func _fail(code: String, message: String, data: Variant = null) -> Dictionary: ## 记录警告并发出错误信号（内部实现）
	push_warning("[%s] %s" % [code, message])
	printerr("[Manager Fail] code=", code, " message=", message, " data=", data)
	manager_error.emit(code, message)
	return {
		"success": false,
		"data": data,
		"error": message,
		"code": code
	}

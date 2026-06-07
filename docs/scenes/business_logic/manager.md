# manager.gd (Manager)

> **路径**: `res://scenes/business_logic/manager.gd`
> **继承**: `Node`
> **类型**: 逻辑层 - 基类

## 概述
业务层基类，为所有子管理器提供统一的数据库入口（DBManager）、事务包装（begin/commit/rollback/run_in_transaction）和标准返回格式（ok/fail）。

## 公共方法
### `set_db_manager(db_manager: DBManager) -> void`
**输入**: `db_manager: DBManager` — 数据层管理器引用  **输出**: 无  **说明**: 注入数据层管理器引用。

### `get_db_manager() -> DBManager`
**输入**: 无  **输出**: `DBManager` — 当前注入的数据库管理器  **说明**: 获取当前注入的 db_manager。

### `has_db_manager() -> bool`
**输入**: 无  **输出**: `bool` — 是否已注入  **说明**: 检查是否已注入 db_manager。

### `require_db_manager() -> bool`
**输入**: 无  **输出**: `bool` — 存在返回 `true`，否则 `false`  **说明**: 要求 db_manager 必须存在，否则立刻报错（`push_error` + 发射 `manager_error`）。

### `begin_transaction() -> bool`
**输入**: 无  **输出**: `bool` — 开启成功/失败  **说明**: 统一开始事务并做方法存在性校验。

### `commit_transaction() -> bool`
**输入**: 无  **输出**: `bool` — 提交成功/失败  **说明**: 统一提交事务并做方法存在性校验。

### `rollback_transaction() -> bool`
**输入**: 无  **输出**: `bool` — 回滚成功/失败  **说明**: 统一回滚事务并做方法存在性校验。

### `run_in_transaction(action: Callable) -> Dictionary`
**输入**: `action: Callable` — 事务体内执行的业务动作（需返回标准结果字典）  **输出**: `Dictionary` — 标准结果（success/error/code/data）  **说明**: 用"自动挡事务"执行业务动作（推荐子类优先用它）。内部自动 begin → 执行 action → 根据结果 commit 或 rollback。

### `run_in_databases_transaction(databases: Array, action: Callable) -> Dictionary`
**输入**: `databases: Array` — 参与事务的 DBManager 列表；`action: Callable` — 事务体  **输出**: `Dictionary` — 标准结果  **说明**: 在多个 DBManager 上执行统一事务（跨仓库业务编排使用）。内部按底层 SQLite 句柄去重，同一物理连接只发一次 BEGIN/COMMIT，避免 SQLITE_BUSY。

### `ok(data: Variant = null, warning: String = "") -> Dictionary`
**输入**: `data: Variant` — 成功数据（可选）；`warning: String` — 警告信息（可选）  **输出**: `Dictionary` — 标准成功结果 `{success: true, data, error: "", code: "OK", warning}`  **说明**: 返回标准成功结果结构，可携带警告信息。

### `fail(code: String, message: String, data: Variant = null) -> Dictionary`
**输入**: `code: String` — 错误码；`message: String` — 错误描述；`data: Variant` — 附加数据（可选）  **输出**: `Dictionary` — 标准失败结果 `{success: false, data, error: message, code}`  **说明**: 返回标准失败结果结构（公开接口）。内部委托 `_fail`，会记录警告、打印错误并发射 `manager_error` 信号。

## 信号
| 信号 | 参数 | 说明 |
|------|------|------|
| `manager_error` | `code: String, message: String` | 管理器内部错误通知（如 DB 未注入、方法缺失等） |
| `entity_created` | `entity_type: String, entity_id: int` | 实体已创建通知 |
| `entity_updated` | `entity_type: String, entity_id: int` | 实体已更新通知 |
| `entity_deleted` | `entity_type: String, entity_id: int` | 实体已删除通知 |
| `batch_operation_completed` | `entity_type: String, count: int` | 批量操作完成通知 |

## 常量
无。

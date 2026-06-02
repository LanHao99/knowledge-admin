# db_manager.gd (DBManager)

> **路径**: `res://scenes/data_access/db_manager.gd`
> **继承**: `Node`
> **类型**: 数据层 - 基类

## 概述

数据层基类，专门负责：管理 SQLite 连接、执行 SQL（查询/写入/事务）、把 JSON 格式的表结构配置转成真实 SQL 并初始化数据表、统一错误处理和返回格式。业务层只说"我要查/改什么"，DBManager 负责"具体怎么和数据库沟通"。

## 公共方法

### `configure(db_path: String = "user://knowledge_admin.db") -> void`
**输入**: `db_path` - 数据库文件路径（默认 `user://knowledge_admin.db`）。  
**输出**: 无。  
**说明**: 配置数据库文件路径。

### `open() -> bool`
**输入**: 无。  
**输出**: `bool` - 成功返回 `true`，失败返回 `false`。  
**说明**: 创建或复用同 `db_path` 的共享连接，并加载 schema JSON。优先复用已存在的共享连接，避免对同一文件开多个 SQLite 句柄导致跨连接写锁冲突。

### `close() -> void`
**输入**: 无。  
**输出**: 无。  
**说明**: 释放当前实例对共享连接的引用，引用计数归零时真正关闭底层 SQLite 连接。

### `get_sqlite() -> SQLite`
**输入**: 无。  
**输出**: `SQLite` - 当前持有的底层连接；未打开返回 `null`。  
**说明**: 暴露底层 SQLite 句柄，供跨仓库事务做"同连接去重"使用。

### `is_open() -> bool`
**输入**: 无。  
**输出**: `bool` - 已打开返回 `true`。  
**说明**: 检查数据库是否已经打开。

### `require_open() -> bool`
**输入**: 无。  
**输出**: `bool` - 已打开返回 `true`，否则设置错误码 `DB_NOT_OPEN` 并返回 `false`。  
**说明**: 要求数据库已打开，否则返回失败。

### `load_schema_config() -> Dictionary`
**输入**: 无。  
**输出**: 统一结果字典。成功时 `data` 为 schema 配置字典，失败时透传错误信息。  
**说明**: 从 JSON 文件读取 schema 配置并缓存到内部。

### `begin_transaction() -> bool`
**输入**: 无。  
**输出**: `bool` - 成功返回 `true`。  
**说明**: 开始事务，保证多步写入要么全成功要么全失败。

### `commit_transaction() -> bool`
**输入**: 无。  
**输出**: `bool` - 成功返回 `true`。  
**说明**: 提交事务，把草稿中的改动真正写入数据库。

### `rollback_transaction() -> bool`
**输入**: 无。  
**输出**: `bool` - 成功返回 `true`。  
**说明**: 回滚事务，放弃本次事务中的所有草稿改动。

### `execute(sql: String) -> Dictionary`
**输入**: `sql` - 待执行的 SQL 语句（不带参数）。  
**输出**: 统一结果字典，`success` 表示是否成功。  
**说明**: 执行不带参数的 SQL，返回统一结果字典。写操作后清空上一轮查询缓存。

### `execute_bind(sql: String, params: Array = []) -> Dictionary`
**输入**: `sql` - 带占位符的 SQL；`params` - 绑定参数数组（默认空）。  
**输出**: 统一结果字典，`success` 表示是否成功。  
**说明**: 执行带参数 SQL（推荐写操作都用这个）。写操作后清空上一轮查询缓存。

### `fetch_all(sql: String, params: Array = []) -> Dictionary`
**输入**: `sql` - 查询 SQL；`params` - 绑定参数数组（默认空，为空时走无参查询路径）。  
**输出**: 统一结果字典，成功时 `data` 为 `Array[Dictionary]`。  
**说明**: 查询多行数据，返回 `data=Array[Dictionary]`。

### `fetch_one(sql: String, params: Array = []) -> Dictionary`
**输入**: `sql` - 查询 SQL；`params` - 绑定参数数组（默认空）。  
**输出**: 统一结果字典，成功时 `data` 为单行 `Dictionary`（无结果则为空字典）。  
**说明**: 查询单行数据，返回 `data=Dictionary`（没有则空字典）。内部复用 `fetch_all`。

### `scalar(sql: String, params: Array = [], default_value: Variant = null) -> Dictionary`
**输入**: `sql` - 查询 SQL；`params` - 绑定参数数组（默认空）；`default_value` - 无结果时的默认值（默认 `null`）。  
**输出**: 统一结果字典，成功时 `data` 为单个值（取结果集第一行第一列）。  
**说明**: 查询单值（如 `COUNT(*)`），返回 `data=单个值`。

### `last_insert_rowid() -> Dictionary`
**输入**: 无。  
**输出**: 统一结果字典。成功时 `data` 为 `int`（本连接最近一次 INSERT 的自增 ID）。  
**说明**: 获取最后一次 INSERT 的 rowid。

### `changes() -> Dictionary`
**输入**: 无。  
**输出**: 统一结果字典。成功时 `data` 为 `int`（最后一次数据变更影响的行数）。  
**说明**: 获取最后一次 INSERT、UPDATE 或 DELETE 操作影响的行数。

### `table_exists(table_name: String) -> bool`
**输入**: `table_name` (String) - 表名（如 `"decks"`）。  
**输出**: `bool` - 存在返回 `true`，不存在或查询失败返回 `false`。  
**说明**: 检查指定表是否存在。含非法标识符校验。

### `count(table_name: String, where_sql: String = "", params: Array = []) -> Dictionary`
**输入**: `table_name` (String) - 表名；`where_sql` (String) - 可选过滤条件，不含 `WHERE` 关键字（如 `"deck_id=? AND queue=?"`）；`params` (Array) - `where_sql` 对应的绑定参数。  
**输出**: 统一结果字典。成功时 `data` 为 `int`（符合条件的行数）。  
**说明**: 获取表行数（支持 WHERE 子句）。

### `init_schema() -> Dictionary`
**输入**: 无。  
**输出**: 统一结果字典。成功时 `success=true`。  
**说明**: 根据 JSON 动态创建表和索引。使用事务保证原子性——要么全部成功，要么全部回滚。

### `reset_schema() -> Dictionary`
**输入**: 无。  
**输出**: 统一结果字典。成功时 `success=true`。  
**说明**: 根据 JSON 配置的删除顺序重置表结构（开发调试用）。先删旧表（按依赖逆序），再重建。

### `get_last_error() -> String`
**输入**: 无。  
**输出**: `String` - 最近一次失败信息。  
**说明**: 获取最近一次失败信息。

### `get_last_code() -> String`
**输入**: 无。  
**输出**: `String` - 最近一次失败代码。  
**说明**: 获取最近一次失败代码。

### `get_last_rows() -> Array[Dictionary]`
**输入**: 无。  
**输出**: `Array[Dictionary]` - 最近一次查询结果缓存。  
**说明**: 获取最近一次查询结果缓存。

### `clear_last_error() -> void`
**输入**: 无。  
**输出**: 无。  
**说明**: 清空最近一次错误信息。

### `ok(data: Variant = null, warning: String = "") -> Dictionary`
**输入**: `data` - 成功时携带的数据（默认 `null`）；`warning` - 可选的警告信息（默认空）。  
**输出**: 统一成功字典：`{"success": true, "data": ..., "error": "", "code": "OK", "warning": ...}`。  
**说明**: 返回与 Manager 对齐的成功结构。

### `fail(code: String, message: String, data: Variant = null) -> Dictionary`
**输入**: `code` - 错误代码；`message` - 错误描述；`data` - 可选的附加数据（默认 `null`）。  
**输出**: 统一失败字典：`{"success": false, "data": ..., "error": message, "code": code}`。  
**说明**: 返回与 Manager 对齐的失败结构（公开入口）。内部委托给 `_fail`，会记录错误、打印控制台并发出 `db_error` 信号。

## 信号

| 信号 | 参数 | 说明 |
| --- | --- | --- |
| `db_error` | `code: String, message: String` | 发生错误时发出，携带错误码和描述信息 |

## 常量

| 常量 | 值 | 说明 |
| --- | --- | --- |
| `SCHEMA_JSON_PATH` | `"res://data/db_schema.json"` | 表结构配置文件路径 |

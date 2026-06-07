# schema_parser.gd (SchemaParser)

> **路径**: `res://src/utils/schema_parser.gd`
> **继承**: `RefCounted`
> **类型**: 工具层 — 纯静态工具类

## 概述
纯静态工具类，专门负责把 JSON 格式的表结构配置翻译成 SQL 语句。所有方法都是 `static` 的，不需要实例化即可调用。将"解析逻辑"与"数据库执行逻辑"彻底解耦。

## 公共方法

### `parse_json_file(file_path: String) -> Dictionary` *static*
**输入**: file_path (String) — JSON 文件的绝对或相对路径（如 `"res://data/db_schema.json"`）。  
**输出**: 返回标准字典。成功时 `data` 为解析出来的 Dictionary。  
**说明**: 解析 JSON 文件并返回 schema_config 字典。失败时返回对应错误码（`SCHEMA_FILE_NOT_FOUND`/`SCHEMA_FILE_OPEN_FAILED`/`SCHEMA_JSON_PARSE_FAILED`/`SCHEMA_JSON_INVALID`）。

### `build_schema_statements(schema_config: Dictionary) -> Dictionary` *static*
**输入**: schema_config (Dictionary) — 从 `db_schema.json` 解析出来的完整字典，必须包含 `"tables"` 和 `"indexes"` 键。  
**输出**: 返回标准字典。成功时 `data` 为 `Array[String]`，包含所有要执行的 CREATE TABLE 和 CREATE INDEX 语句。  
**说明**: 主入口1——生成建表和建索引语句。

### `build_drop_statements(schema_config: Dictionary) -> Dictionary` *static*
**输入**: schema_config (Dictionary) — 必须包含 `"drop_tables_order"` 数组，指示安全删除表的顺序。  
**输出**: 返回标准字典。成功时 `data` 为 `Array[String]`，包含按顺序排列的 DROP TABLE IF EXISTS 语句。  
**说明**: 主入口2——生成删表语句（用于重置数据库）。

## 私有方法

### `_build_create_table_sql(table_name: String, table_cfg: Dictionary) -> Dictionary` *static*
依据表配置拼接 CREATE TABLE SQL，包括字段定义和外键定义。

### `_build_column_sql(column_name: String, column_cfg: Dictionary) -> String` *static*
把单个字段配置转换成列 SQL 片段（类型 + PRIMARY KEY + AUTOINCREMENT + NOT NULL + DEFAULT）。

### `_build_foreign_key_sql(fk_cfg: Dictionary) -> String` *static*
把外键配置转换成 FOREIGN KEY SQL 片段（含 ON DELETE 子句）。

### `_build_create_index_sql(index_cfg: Dictionary) -> Dictionary` *static*
依据索引配置拼接 CREATE INDEX 或 CREATE UNIQUE INDEX SQL。

### `_format_default_value(value: Variant) -> String` *static*
把 JSON 默认值转换为 SQL 可用文本（null → NULL、string → 'text'、bool → 1/0）。

### `_ok(data: Variant = null) -> Dictionary` *static*
返回标准成功结构 `{success: true, data, error: "", code: "OK", warning: ""}`。

### `_fail(code: String, message: String) -> Dictionary` *static*
返回标准失败结构并记录 `push_warning`。

## 信号
无。

## 常量
无。

# note_entity.gd (NoteEntity)

> **路径**: `res://src/entities/note_entity.gd`
> **继承**: `RefCounted`
> **类型**: 实体层

## 概述
笔记实体类，纯数据结构，对应数据库 `notes` 表的一行记录。笔记是"知识单元"的载体，包含字段数据（`fields_data`）和标签（`tags`）。一个 Note 可通过模板生成多张 Card（见 `CardEntity.note_id`）。

## 公共方法

### `to_dict() -> Dictionary`
**输入**: 无。  
**输出**: Dictionary — 键名与数据库 `notes` 表字段一一对应；`fields_data` 字典会被 JSON 序列化后存入数据库；`id` 为 0 时不写入。  
**说明**: 将当前实体序列化为字典，便于传给数据层执行 INSERT/UPDATE。

### `from_dict(d: Dictionary) -> void`
**输入**: d (Dictionary) — 数据库查询返回的行字典，键名应与 `notes` 表字段对应。  
**输出**: 无。  
**说明**: 从字典反序列化，会自动调用 `fields_from_json()` 将 JSON 字符串解析为 `fields_data` 字典。

### `get_field(field_name: String) -> String`
**输入**: field_name (String) — 字段名，如 "正面"、"背面"。  
**输出**: String — 字段值；字段不存在时返回空字符串。  
**说明**: 获取指定字段的内容。

### `set_field(field_name: String, value: String) -> void`
**输入**:
- field_name (String) — 字段名。
- value (String) — 要写入的内容。

**输出**: 无。  
**说明**: 设置指定字段的内容。

### `fields_to_json() -> String`
**输入**: 无。  
**输出**: String — JSON 格式的字符串；序列化失败时返回 `"{}"`。  
**说明**: 将 `fields_data` 字典序列化为 JSON 字符串，用于写入数据库。

### `fields_from_json(json_str: String) -> void`
**输入**: json_str (String) — JSON 格式的字符串。  
**输出**: 无。  
**说明**: 将 JSON 字符串解析为 `fields_data` 字典，用于从数据库读取后恢复。

### `get_default_deck_id() -> int`
**输入**: 无。  
**输出**: int — 默认牌组 ID（当前为占位实现，固定返回 0）。  
**说明**: 获取该笔记对应的卡片应该归属的默认牌组 ID。当前返回 0 表示由调用方（NoteManager）根据业务规则决定。

### `now_timestamp() -> int` *static*
**输入**: 无。  
**输出**: int — 当前系统时间的 Unix 时间戳（秒级）。  
**说明**: 生成一个当前时间的 Unix 时间戳。

## 信号
无。

## 常量
无。

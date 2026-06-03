# note_entity.gd (NoteEntity)

> **路径**: `res://src/entities/note_entity.gd`
> **继承**: `RefCounted`
> **类型**: 实体层

## 概述
笔记实体类，纯数据结构，对应数据库 `notes` 表的一行记录。笔记是"知识单元"的载体，包含字段数据（`fields_data`）、标签（`tags`）和所属牌组 ID（`deck_id`）。一个 Note 可通过模板生成多张 Card（见 `CardEntity.note_id`）。不加入 Godot 节点树，由 Manager 持有引用，引用计数归零时自动释放。

## 常量与字段

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `id` | `int` | `0` | 唯一标识符（自增主键）。`0` 表示尚未写入数据库的临时对象。 |
| `note_type_id` | `int` | `0` | 笔记类型 ID，用于决定该笔记使用哪种模板生成卡片。对应 `note_type_id` 字段（INTEGER, NOT NULL）。当前 schema 中 `note_types` 表尚未创建，此字段为预留。 |
| `fields_data` | `Dictionary` | `{}` | 字段数据字典，键为字段名，值为字段内容。对应数据库中 JSON 序列化后的 `fields_data`（TEXT）。示例：`{"正面": "你好", "背面": "Hello"}`。 |
| `tags` | `Array[String]` | `[]` | 标签数组，用于分类和检索。当前为预留字段，数据库 schema 中尚未独立建 `tags` 列，未来可通过独立 tag 表或逗号分隔字符串扩展。 |
| `deck_id` | `int` | `0` | 所属牌组 ID，用于按牌组分组和过滤。对应 `deck_id` 字段（INTEGER, NOT NULL）。 |
| `created_at` | `int` | `0` | 创建时间的 Unix 时间戳（秒级）。对应 `created_at` 字段（INTEGER, NOT NULL）。 |

## 公共方法

### `to_dict() -> Dictionary`
**输入**: 无。  
**输出**: Dictionary — 键名与数据库 `notes` 表字段一一对应；`fields_data` 字典会被 JSON 序列化后存入数据库；`id` 为 0 时不写入。  
**说明**: 将当前实体序列化为字典，便于传给数据层执行 INSERT/UPDATE。

### `from_dict(d: Dictionary) -> void`
**输入**: d (Dictionary) — 数据库查询返回的行字典，键名应与 `notes` 表字段对应。  
**输出**: 无。  
**说明**: 从字典反序列化，用于数据层 SELECT 查询后将行记录转换为类型安全的实体对象。会自动调用 `fields_from_json()` 将 JSON 字符串解析为 `fields_data` 字典。

### `get_field(field_name: String) -> String`
**输入**: field_name (String) — 字段名，如"正面"、"背面"。  
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
**输出**: int — 默认牌组 ID。  
**说明**: 获取该笔记对应的卡片应该归属的默认牌组 ID。当前为占位实现：返回 0 表示由调用方（NoteManager）根据业务规则决定。未来可在 `note_types` 表中扩展 `default_deck_id` 字段。

### `now_timestamp() -> int` *static*
**输入**: 无。  
**输出**: int — 当前系统时间的 Unix 时间戳（秒级）。  
**说明**: 生成一个当前时间的 Unix 时间戳。

## 信号
无。

## 常量
无。

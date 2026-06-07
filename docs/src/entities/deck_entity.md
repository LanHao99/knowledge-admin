# deck_entity.gd (DeckEntity)
> **路径**: `res://src/entities/deck_entity.gd` | **继承**: `RefCounted` | **类型**: 实体层

## 概述
牌组实体类，纯数据结构，对应数据库 `decks` 表的一行记录，用于 Manager 与 DB 层之间传递牌组数据以替代裸 Dictionary。

## 公共方法

### `to_dict() -> Dictionary`
将当前实体序列化为字典。
- **输出**: `Dictionary` — 键名与 `decks` 表字段一一对应；`id` 为 0 时不写入（让数据库自增），`parent_id` 为 0 时写入 `null`。

### `from_dict(d: Dictionary) -> void`
从字典反序列化，用于数据层 `SELECT` 后将行记录转换为类型安全的实体对象。
- **输入**: `d` (`Dictionary`) — 数据库查询返回的行字典，键名与 `decks` 表字段对应。

### `is_root() -> bool`
判断当前牌组是否为根级（无父节点）。
- **输出**: `bool` — `parent_id == 0` 时返回 `true`。

### `get_path_separator() -> String`
返回牌组路径层级分隔符（对齐 Anki 的牌组层级表示习惯）。
- **输出**: `String` — 固定返回 `"::"`。

### `get_full_path(parent_name: String = "") -> String`
返回牌组在 UI 中显示的完整路径字符串（如 `"语言::日语::N1词汇"`）。当前为占位实现，未来可配合 `DeckManager.get_deck_tree` 递归拼接父节点名称。
- **输入**: `parent_name` (`String`, 可选) — 父牌组名称，空字符串表示根级。
- **输出**: `String` — 拼接后的完整路径。

### `now_timestamp() -> int` (static)
生成当前时间的 Unix 时间戳，用于新建或更新时填充 `created_at` / `updated_at`。
- **输出**: `int` — 当前系统时间的 Unix 时间戳（秒级）。

## 常量
无。

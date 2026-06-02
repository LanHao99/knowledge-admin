# note_manager.gd (NoteManager)

> **路径**: `res://scenes/business_logic/note_manager.gd`
> **继承**: `Manager`
> **类型**: 逻辑层

## 概述
笔记管理器，负责笔记的创建、更新、删除、检索与搜索，并在创建/删除笔记时自动管理关联卡片。

## 公共方法
### `setup(db_path: String) -> bool`
**输入**: `db_path` (String) — 数据库文件路径（如 `"user://knowledge_admin.db"`）。

**输出**: `bool` — 初始化成功返回 `true`。

**说明**: 初始化数据层并打开数据库，由 Manager 自行管理 DB 生命周期。

---

### `is_ready() -> bool`
**输入**: 无。

**输出**: `bool` — 已初始化返回 `true`。

**说明**: 检查是否已完成 setup 初始化。

---

### `create_note(note_type_id: int, fields: Dictionary, deck_id: int, tags: Array[String] = []) -> Dictionary`
**输入**:
- `note_type_id` (int) — 笔记类型 ID。
- `fields` (Dictionary) — 字段数据。
- `deck_id` (int) — 目标牌组 ID。
- `tags` (Array[String]) — 标签列表（当前仅保留接口）。

**输出**: 返回标准字典。成功时 `data` 为 `{note: NoteEntity, cards: Array[CardEntity]}`。

**说明**: 创建笔记并生成对应卡片。

---

### `update_note(note_id: int, fields: Dictionary, tags: Array[String] = []) -> Dictionary`
**输入**:
- `note_id` (int) — 笔记 ID。
- `fields` (Dictionary) — 新字段数据。
- `tags` (Array[String]) — 标签列表（当前仅保留接口）。

**输出**: 返回标准字典。成功时 `data` 为 `NoteEntity`。

**说明**: 更新笔记字段与标签。

---

### `delete_note(note_id: int) -> Dictionary`
**输入**: `note_id` (int) — 笔记 ID。

**输出**: 返回标准字典。成功时 `data` 为 `{deleted_cards: int}`。

**说明**: 删除笔记及其关联卡片。

---

### `get_note(note_id: int) -> Dictionary`
**输入**: `note_id` (int) — 笔记 ID。

**输出**: 返回标准字典。成功时 `data` 为 `NoteEntity` 或 `null`。

**说明**: 获取单条笔记。

---

### `get_all_notes() -> Dictionary`
**输入**: 无。

**输出**: 返回标准字典。成功时 `data` 为 `Array[NoteEntity]`。

**说明**: 获取全部笔记列表。

---

### `get_notes_by_deck(deck_id: int) -> Dictionary`
**输入**: `deck_id` (int) — 牌组 ID。

**输出**: 返回标准字典。成功时 `data` 为 `Array[NoteEntity]`。

**说明**: 按牌组获取笔记列表。

---

### `search_notes(query: String, deck_id: int = 0) -> Dictionary`
**输入**:
- `query` (String) — 搜索词。
- `deck_id` (int) — 可选牌组过滤，`0` 表示全局搜索。

**输出**: 返回标准字典。成功时 `data` 为 `Array[NoteEntity]`。

**说明**: 按关键词搜索笔记。

## 信号
> 以下信号均继承自基类 `Manager`。

| 信号 | 参数 | 说明 |
|------|------|------|
| `entity_created` | `entity_type: String, entity_id: int` | 实体创建成功时触发；创建笔记时 `entity_type` 为 `"note"` |
| `entity_updated` | `entity_type: String, entity_id: int` | 实体更新成功时触发；更新笔记时 `entity_type` 为 `"note"` |
| `entity_deleted` | `entity_type: String, entity_id: int` | 实体删除成功时触发；删除笔记时 `entity_type` 为 `"note"` |
| `batch_operation_completed` | `entity_type: String, count: int` | 批量操作完成时触发；创建/删除笔记的关联卡片时 `entity_type` 为 `"card"` |
| `manager_error` | `code: String, message: String` | 管理器内部发生错误时触发 |

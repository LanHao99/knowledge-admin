# note_db.gd (NoteDB)

> **路径**: `res://scenes/data_access/note_db.gd`
> **继承**: `DBManager`
> **类型**: 数据层

## 概述
笔记数据访问层，封装 notes 表的 CRUD、牌组关联查询、全文搜索及计数操作，返回统一的标准字典结构。

## 公共方法

### `create_note(note_type_id: int, fields_json: String, deck_id: int = 0, tags: String = "") -> Dictionary`
**输入**: `note_type_id` 笔记类型 ID；`fields_json` 字段 JSON 字符串；`deck_id` 所属牌组 ID；`tags` 预留标签字符串，当前 schema 未落库仅保留参数兼容。
**输出**: 返回标准字典，成功时 `data` 为 `NoteEntity`；失败时 `data` 为错误信息。
**说明**: 创建一条笔记记录并返回创建后的实体对象。

### `get_note_by_id(note_id: int) -> Dictionary`
**输入**: `note_id` 笔记 ID。
**输出**: 返回标准字典，成功时 `data` 为 `NoteEntity`，未找到时为 `null`。
**说明**: 根据 ID 查询单条笔记。

### `update_note(note: NoteEntity) -> Dictionary`
**输入**: `note` 待更新的 `NoteEntity` 实体，要求 `id > 0`。
**输出**: 返回标准字典，成功时 `data` 为 `null`。
**说明**: 更新已有笔记。

### `delete_note(note_id: int) -> Dictionary`
**输入**: `note_id` 笔记 ID。
**输出**: 返回标准字典，成功时 `data` 为 `null`。
**说明**: 删除单条笔记。

### `get_notes_by_deck(deck_id: int, limit: int = 0, offset: int = 0) -> Dictionary`
**输入**: `deck_id` 牌组 ID；`limit` 限制条数（`<=0` 不限制）；`offset` 偏移量。
**输出**: 返回标准字典，成功时 `data` 为 `Array[NoteEntity]`。
**说明**: 根据牌组查询笔记列表（通过 `cards` 表关联）。

### `get_notes_by_type(note_type_id: int) -> Dictionary`
**输入**: `note_type_id` 笔记类型 ID。
**输出**: 返回标准字典，成功时 `data` 为 `Array[NoteEntity]`。
**说明**: 根据笔记类型查询笔记列表。

### `search_notes(query: String, deck_id: int = 0) -> Dictionary`
**输入**: `query` 搜索关键词；`deck_id` 可选牌组过滤（`0` 表示不过滤）。
**输出**: 返回标准字典，成功时 `data` 为 `Array[NoteEntity]`。
**说明**: 搜索笔记（在 `fields_data` 文本中执行 `LIKE` 匹配）。

### `get_notes_count(deck_id: int = 0) -> Dictionary`
**输入**: `deck_id` 可选牌组过滤（`0` 表示统计全库笔记）。
**输出**: 返回标准字典，成功时 `data` 为 `int`。
**说明**: 获取笔记数量。

### `get_all_notes() -> Dictionary`
**输入**: 无。
**输出**: 返回标准字典，成功时 `data` 为 `Array[NoteEntity]`。
**说明**: 获取全部笔记列表。

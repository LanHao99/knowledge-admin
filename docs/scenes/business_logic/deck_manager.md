# deck_manager.gd (DeckManager)

> **路径**: `res://scenes/business_logic/deck_manager.gd`
> **继承**: `Manager`
> **类型**: 逻辑层

## 概述
牌组管理器，负责牌组的增删改查、移动、归档及统计，所有写操作通过数据库事务保证一致性。

## 公共方法

### `setup(db_path: String) -> bool`
**输入**: `db_path` (String) — 数据库文件路径（如 `"user://knowledge_admin.db"`）。  
**输出**: `bool` — 初始化成功返回 `true`。  
**说明**: 初始化数据层并打开数据库，由 Manager 自行管理 DB 生命周期。

### `get_deck_db() -> DeckDB`
**输入**: 无。  
**输出**: `DeckDB` — 牌组仓库对象；未初始化时为 `null`。  
**说明**: 获取当前 DeckDB 引用（供其他 Manager 跨仓库查询）。

### `is_ready() -> bool`
**输入**: 无。  
**输出**: `bool` — 已初始化返回 `true`。  
**说明**: 检查是否已完成 setup 初始化。

### `create_deck(name: String, parent_id: int = 0) -> Dictionary`
**输入**: `name` (String) — 牌组名称；`parent_id` (int) — 父牌组 ID，0 表示根级。  
**输出**: 返回标准字典，成功时 `data` 为 `DeckEntity`。  
**说明**: 创建牌组，自动校验名称非空、父牌组存在性及同级名称唯一性。

### `rename_deck(deck_id: int, new_name: String) -> Dictionary`
**输入**: `deck_id` (int) — 牌组 ID；`new_name` (String) — 新名称。  
**输出**: 返回标准字典，成功时 `data` 为 `DeckEntity`。  
**说明**: 重命名牌组，校验名称非空及同级唯一性。

### `move_deck(deck_id: int, new_parent_id: int) -> Dictionary`
**输入**: `deck_id` (int) — 牌组 ID；`new_parent_id` (int) — 新父牌组 ID，0 表示移动到根级。  
**输出**: 返回标准字典，成功时 `data` 为 `DeckEntity`。  
**说明**: 移动牌组到新的父节点，禁止移动到自身或其子树中。

### `archive_deck(deck_id: int, archived: bool = true) -> Dictionary`
**输入**: `deck_id` (int) — 牌组 ID；`archived` (bool) — `true` 表示归档，`false` 表示恢复。  
**输出**: 返回标准字典，成功时 `data` 为 `DeckEntity`。  
**说明**: 归档或恢复牌组。

### `delete_deck(deck_id: int) -> Dictionary`
**输入**: `deck_id` (int) — 牌组 ID。  
**输出**: 返回标准字典，成功时 `data` 为 `null`。  
**说明**: 删除牌组（硬删除），若牌组下仍有卡片则拒绝删除。

### `get_deck(deck_id: int) -> Dictionary`
**输入**: `deck_id` (int) — 牌组 ID。  
**输出**: 返回标准字典，成功时 `data` 为 `DeckEntity` 或 `null`。  
**说明**: 获取单个牌组。

### `get_deck_by_name(name: String) -> Dictionary`
**输入**: `name` (String) — 牌组名称。  
**输出**: 返回标准字典，成功时 `data` 为 `DeckEntity` 或 `null`。  
**说明**: 按名称获取牌组。

### `get_all_decks() -> Dictionary`
**输入**: 无。  
**输出**: 返回标准字典，成功时 `data` 为 `Array[DeckEntity]`。  
**说明**: 获取全部牌组列表（默认不含归档）。

### `get_deck_tree() -> Dictionary`
**输入**: 无。  
**输出**: 返回标准字典，成功时 `data` 为树节点数组。  
**说明**: 获取牌组树结构。

### `get_deck_counts(deck_id: int) -> Dictionary`
**输入**: `deck_id` (int) — 牌组 ID。  
**输出**: 返回标准字典，成功时 `data` 为 `{new, learning, review, total}`。  
**说明**: 获取牌组卡片统计。

### `clear_all_data() -> Dictionary`
**输入**: 无。  
**输出**: 返回标准字典，成功时 `data` 为删除统计 `Dictionary`。  
**说明**: 清空全部数据（cards、notes、decks）。

## 信号

> 全部继承自 `Manager`，DeckManager 自身未定义新信号。

| 信号 | 参数 | 说明 |
|---|---|---|
| `manager_error` | `code: String, message: String` | 管理器内部错误通知 |
| `entity_created` | `entity_type: String, entity_id: int` | 实体创建通知（如 `"deck"`） |
| `entity_updated` | `entity_type: String, entity_id: int` | 实体更新通知（如 `"deck"`） |
| `entity_deleted` | `entity_type: String, entity_id: int` | 实体删除通知（如 `"deck"`） |
| `batch_operation_completed` | `entity_type: String, count: int` | 批量操作完成通知（如 `"all_data"`） |

## 常量

> 无。DeckManager 自身未定义常量。

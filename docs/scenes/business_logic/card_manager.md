# card_manager.gd (CardManager)

> **路径**: `res://scenes/business_logic/card_manager.gd`
> **继承**: `Manager`
> **类型**: 逻辑层

## 概述
卡片管理器，负责卡片的 CRUD、学习队列组装、作答调度状态落库，以及暂停/搁置/重置/移动等卡片生命周期操作。

## 公共方法
### `setup(db_path: String) -> bool`
**输入**: db_path (String) - 数据库文件路径（如 "user://knowledge_admin.db"）。  
**输出**: bool - 初始化成功返回 true。  
**说明**: 初始化数据层并打开数据库，由 Manager 自行管理 DB 生命周期。

### `is_ready() -> bool`
**输入**: 无。  
**输出**: bool - 已初始化返回 true。  
**说明**: 检查是否已完成 setup 初始化。

### `set_scheduler(scheduler: Scheduler) -> void`
**输入**: scheduler (Scheduler) - 调度算法实现。  
**输出**: 无。  
**说明**: 注入调度器实例。

### `get_card(card_id: int) -> Dictionary`
**输入**: card_id (int) - 卡片 ID。  
**输出**: 返回标准字典。成功时 `data` 为 CardEntity 或 null。  
**说明**: 获取单张卡片。

### `get_cards_by_note(note_id: int) -> Dictionary`
**输入**: note_id (int) - 笔记 ID。  
**输出**: 返回标准字典。成功时 `data` 为 Array[CardEntity]。  
**说明**: 获取某条笔记下的卡片列表。

### `get_cards_by_deck(deck_id: int) -> Dictionary`
**输入**: deck_id (int) - 牌组 ID。  
**输出**: 返回标准字典。成功时 `data` 为 Array[CardEntity]。  
**说明**: 获取某个牌组下的卡片列表。

### `get_due_cards(deck_id: int, queue_type: int, limit: int = 20) -> Dictionary`
**输入**: deck_id (int) - 牌组 ID、queue_type (int) - 队列类型、limit (int) - 限制条数。  
**输出**: 返回标准字典。成功时 `data` 为 Array[CardEntity]。  
**说明**: 获取指定队列的到期卡片。

### `get_study_queue(deck_id: int) -> Dictionary`
**输入**: deck_id (int) - 牌组 ID。  
**输出**: 返回标准字典。成功时 `data` 为 `{new, learning, review, counts}`。  
**说明**: 组装某牌组的学习队列。

### `answer_card(card_id: int, rating: int, time_taken_ms: int) -> Dictionary`
**输入**: card_id (int) - 卡片 ID、rating (int) - 评分（1~4）、time_taken_ms (int) - 本次作答耗时（毫秒）。  
**输出**: 返回标准字典。成功时 `data` 为 `{card, next_due, interval_days, interval_text}`。  
**说明**: 提交一次卡片作答，计算并落库下一状态。

### `suspend_card(card_id: int, suspended: bool = true) -> Dictionary`
**输入**: card_id (int) - 卡片 ID、suspended (bool) - true 暂停，false 恢复。  
**输出**: 返回标准字典。成功时 `data` 为 CardEntity。  
**说明**: 暂停或恢复单张卡片。

### `bury_card(card_id: int, buried: bool = true) -> Dictionary`
**输入**: card_id (int) - 卡片 ID、buried (bool) - true 搁置，false 取消搁置。  
**输出**: 返回标准字典。成功时 `data` 为 CardEntity。  
**说明**: 搁置或取消搁置单张卡片。

### `reset_card(card_id: int) -> Dictionary`
**输入**: card_id (int) - 卡片 ID。  
**输出**: 返回标准字典。成功时 `data` 为 CardEntity。  
**说明**: 将卡片重置为全新状态。

### `move_card_to_deck(card_id: int, new_deck_id: int) -> Dictionary`
**输入**: card_id (int) - 卡片 ID、new_deck_id (int) - 新牌组 ID。  
**输出**: 返回标准字典。成功时 `data` 为 CardEntity。  
**说明**: 移动单张卡片到新牌组。

### `get_card_content(card_id: int) -> Dictionary`
**输入**: card_id (int) - 卡片 ID。  
**输出**: 返回标准字典。成功时 `data` 为 `{front, back, fields, card, note}`。  
**说明**: 获取渲染卡片所需内容（卡片 + 关联笔记字段）。

## 信号
| 信号 | 参数 | 说明 |
|------|------|------|
| `manager_error` | `code: String, message: String` | 继承自 Manager，业务错误时发出 |
| `entity_created` | `entity_type: String, entity_id: int` | 继承自 Manager，实体创建后发出 |
| `entity_updated` | `entity_type: String, entity_id: int` | 继承自 Manager，卡片状态变更后发出（如 answer/suspend/bury/reset/move） |
| `entity_deleted` | `entity_type: String, entity_id: int` | 继承自 Manager，实体删除后发出 |
| `batch_operation_completed` | `entity_type: String, count: int` | 继承自 Manager，批量操作完成时发出 |

# card_entity.gd (CardEntity)

> **路径**: `res://src/entities/card_entity.gd`
> **继承**: `RefCounted`
> **类型**: 实体层

## 概述
卡片实体类，纯数据结构，对应数据库 `cards` 表的一行记录。卡片是"学习单元"，是用户实际看到和复习的对象。一张 Card 关联一个 Note（通过 `note_id`）和一个 Deck（通过 `deck_id`）。一张 Note 可生成多张 Card（通过 `template_order` 区分）。队列状态（`queue`）和到期时间（`due`）是调度系统的核心字段。

## 公共方法

### `to_dict() -> Dictionary`
**输入**: 无。  
**输出**: Dictionary — 键名与数据库 `cards` 表字段一一对应；`id` 为 0 时不写入（让数据库自增）。  
**说明**: 将当前实体序列化为字典，便于传给数据层执行 INSERT/UPDATE。

### `from_dict(d: Dictionary) -> void`
**输入**: d (Dictionary) — 数据库查询返回的行字典，键名应与 `cards` 表字段对应。  
**输出**: 无。  
**说明**: 从字典反序列化，用于数据层 SELECT 查询后将行记录转换为类型安全的实体对象。

### `is_due(now_day_index: int) -> bool`
**输入**: now_day_index (int) — 当前天数索引（用于 review 队列）或 Unix 时间戳（用于 learning 队列）。  
**输出**: bool — `due <= now_day_index` 时返回 true。  
**说明**: 判断卡片是否到期，调用方需根据 `queue` 类型传入正确的时间单位。

### `is_new() -> bool`
**输入**: 无。  
**输出**: bool — `queue == QUEUE_NEW` 时返回 true。  
**说明**: 判断卡片是否为新卡片（从未学习过）。

### `is_learning() -> bool`
**输入**: 无。  
**输出**: bool — `queue == QUEUE_LEARNING` 时返回 true。  
**说明**: 判断卡片是否处于学习阶段（短期间隔）。

### `is_review() -> bool`
**输入**: 无。  
**输出**: bool — `queue == QUEUE_REVIEW` 时返回 true。  
**说明**: 判断卡片是否处于复习阶段（长期间隔，按天计）。

### `is_suspended() -> bool`
**输入**: 无。  
**输出**: bool — `queue == QUEUE_SUSPENDED` 时返回 true。  
**说明**: 判断卡片是否已暂停。

### `is_buried() -> bool`
**输入**: 无。  
**输出**: bool — `queue == QUEUE_BURIED` 时返回 true。  
**说明**: 判断卡片是否已搁置（当天推迟）。

### `append_review_history(rating: int, time_taken_ms: int, reviewed_at: int = 0) -> void`
**输入**:
- rating (int) — 本次评分，取值 1~4。
- time_taken_ms (int) — 本次答题耗时（毫秒）。
- reviewed_at (int) — 复习时间的 Unix 时间戳，默认使用当前时间。

**输出**: 无。  
**说明**: 将本次复习记录追加到历史 JSON 中（`review_history_json` 字段）。

### `get_review_history() -> Array`
**输入**: 无。  
**输出**: Array[Dictionary] — 每个元素包含 `rating`/`time_taken`/`reviewed_at` 键。  
**说明**: 获取复习历史记录数组。

### `get_queue_name() -> String`
**输入**: 无。  
**输出**: String — 如 "新卡片"、"学习中"、"复习"、"已暂停"、"已搁置"。  
**说明**: 获取当前卡片在 UI 中的显示队列名称（用于调试或状态展示）。

### `get_last_rating_name() -> String`
**输入**: 无。  
**输出**: String — 如 "Again"、"Hard"、"Good"、"Easy"、"未评分"。  
**说明**: 获取当前卡片在 UI 中的显示评分名称。

### `now_timestamp() -> int` *static*
**输入**: 无。  
**输出**: int — 当前系统时间的 Unix 时间戳（秒级）。  
**说明**: 生成当前时间的 Unix 时间戳。

### `day_index_from_timestamp(unix_ts: int) -> int` *static*
**输入**: unix_ts (int) — Unix 时间戳（秒级）。  
**输出**: int — 天数索引（自 1970-01-01 起的天数）。  
**说明**: 将 Unix 时间戳转换为天数索引，用于 review 队列的 `due` 字段计算。

### `today_day_index() -> int` *static*
**输入**: 无。  
**输出**: int — 今天的天数索引。  
**说明**: 获取今天的天数索引。

## 常量

| 常量 | 值 | 说明 |
|------|----|------|
| `QUEUE_NEW` | `0` | 新卡片，从未学习过 |
| `QUEUE_LEARNING` | `1` | 学习中（短期间隔，按秒/分钟计） |
| `QUEUE_REVIEW` | `2` | 复习中（长期间隔，按天计） |
| `QUEUE_SUSPENDED` | `-1` | 已暂停，不加入学习队列 |
| `QUEUE_BURIED` | `-2` | 已搁置（当天推迟，明天自动恢复） |
| `RATING_AGAIN` | `1` | 完全遗忘，需重新学习 |
| `RATING_HARD` | `2` | 勉强想起，间隔缩短 |
| `RATING_GOOD` | `3` | 正常回忆，标准间隔 |
| `RATING_EASY` | `4` | 轻松回忆，间隔拉长 |

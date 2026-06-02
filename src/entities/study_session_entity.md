# study_session_entity.gd (StudySessionEntity)

> **路径**: `res://src/entities/study_session_entity.gd`
> **继承**: `RefCounted`
> **类型**: 实体层 — 暂态实体

## 概述
学习会话实体类，纯数据结构，用于记录一次学习会话的暂态统计信息。"暂态"意味着该实体不直接映射到数据库的持久化表，而是存在于内存中。会话结束后可将汇总数据写入 `review_logs` 或 `cards` 的历史记录中。由 `StudyManager` 在会话开始时创建，会话结束时销毁。

## 公共方法

### `to_dict() -> Dictionary`
**输入**: 无。  
**输出**: Dictionary — 包含会话的所有统计字段。  
**说明**: 将会话实体序列化为字典，便于调试日志输出或持久化存储。

### `from_dict(d: Dictionary) -> void`
**输入**: d (Dictionary) — 包含会话数据的字典。  
**输出**: 无。  
**说明**: 从字典反序列化，用于从持久化存储恢复会话状态（如断点续学场景）。

### `increment_new_seen() -> void`
**输入**: 无。  
**输出**: 无。  
**说明**: 递增新卡片计数器，当用户看到一张新卡片时调用。

### `increment_review_seen() -> void`
**输入**: 无。  
**输出**: 无。  
**说明**: 递增复习卡片计数器，当用户看到一张复习卡片时调用。

### `add_time_ms(time_ms: int) -> void`
**输入**: time_ms (int) — 本次答题耗时（毫秒）。  
**输出**: 无。  
**说明**: 累加答题耗时。

### `record_answer(rating: int, time_taken_ms: int, is_new_card: bool = false) -> void`
**输入**:
- rating (int) — 评分，取值 1=Again, 2=Hard, 3=Good, 4=Easy。
- time_taken_ms (int) — 本次答题耗时（毫秒）。
- is_new_card (bool) — 是否为新卡片，影响 `new_cards_seen` 计数。

**输出**: 无。  
**说明**: 记录一次评分事件，自动递增计数器、累加时间，并按评分分类更新 `session_stats`（含 `again_count`/`hard_count`/`good_count`/`easy_count`/`average_time_ms`）。

### `get_total_cards_seen() -> int`
**输入**: 无。  
**输出**: int — 总卡片数（`new_cards_seen + review_cards_seen`）。  
**说明**: 获取会话中已处理的总卡片数量。

### `get_elapsed_time_ms(now_timestamp: int = 0) -> int`
**输入**: now_timestamp (int) — 当前 Unix 时间戳，默认使用当前系统时间。  
**输出**: int — 已持续时间（毫秒）。  
**说明**: 获取会话已持续的时间。

### `to_stats_dict() -> Dictionary`
**输入**: 无。  
**输出**: Dictionary — 包含所有原始字段 + 派生计算字段（`total_cards_seen`、`correct_count`、`accuracy`、`elapsed_time_ms`）。  
**说明**: 将会话统计转换为更详细的汇总字典，供 UI 层展示或持久化存储。

### `now_timestamp() -> int` *static*
**输入**: 无。  
**输出**: int — 当前系统时间的 Unix 时间戳（秒级）。  
**说明**: 生成当前时间的 Unix 时间戳。

### `create_new(target_deck_id: int = 0) -> StudySessionEntity` *static*
**输入**: target_deck_id (int) — 目标牌组 ID，0 表示全部牌组。  
**输出**: StudySessionEntity — 已初始化的会话实体（`started_at` 自动填充为当前时间）。  
**说明**: 创建一个新的会话实体。

## 常量

| 常量 | 值 | 说明 |
|------|----|------|
| `RATING_AGAIN` | `1` | 完全遗忘 |
| `RATING_HARD` | `2` | 勉强想起 |
| `RATING_GOOD` | `3` | 正常回忆 |
| `RATING_EASY` | `4` | 轻松回忆 |

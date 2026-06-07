# simple_scheduler.gd (SimpleScheduler)

> **路径**: `res://src/scheduler/simple_scheduler.gd`
> **继承**: `Scheduler`
> **类型**: 调度层 — 默认实现

## 概述
基于 SM-2 思路的简化调度器实现。只做纯计算，不触碰数据库。
- learning 队列按秒级时间戳调度（步长 10 分钟）
- review 队列按天数索引调度
- 评分逻辑：Again → 重新学习，Hard → 间隔×1.2，Good → 间隔×ease_factor，Easy → 间隔×ease_factor×1.3

## 公共方法

### `calculate_next_state(card: CardEntity, rating: int, now_timestamp: int) -> Dictionary`
**输入**:
- card (CardEntity) — 当前卡片实体。
- rating (int) — 用户评分，取值见 `Scheduler.Rating`。
- now_timestamp (int) — 当前 Unix 时间戳（秒）。

**输出**: Dictionary — 包含 `queue`/`due`/`reps`/`lapses`/`stability`/`difficulty`/`interval_days`。  
**说明**: 计算下一次复习状态。Again 时 queue=LEARNING、due=当前+10分钟、lapses+1、stability减半；Hard 时 queue=REVIEW、interval×1.2；Good 时 queue=REVIEW、interval×ease_factor；Easy 时 queue=REVIEW、interval×ease_factor×1.3。

### `classify_queue(card: CardEntity, now_day_index: int, now_timestamp: int) -> int`
**输入**:
- card (CardEntity) — 当前卡片实体。
- now_day_index (int) — 当前天数索引。
- now_timestamp (int) — 当前 Unix 时间戳（秒）。

**输出**: int — 队列值。SUSPENDED/BURIED 直接返回；NEW/LEARNING/REVIEW 根据 `due` 判断是否到期后返回对应队列。  
**说明**: 获取卡片当前应归属的队列。

### `get_initial_state() -> Dictionary`
**输入**: 无。  
**输出**: Dictionary — `{queue: NEW, due: 0, reps: 0, lapses: 0, stability: 0.0, difficulty: 3.0}`。  
**说明**: 返回新卡片的默认调度状态。

### `estimate_next_interval(card: CardEntity, rating: int) -> String`
**输入**:
- card (CardEntity) — 当前卡片实体。
- rating (int) — 用户评分，取值见 `Scheduler.Rating`。

**输出**: String — Again 返回 "10分钟后"；其余按公式估算返回 "N天后"。  
**说明**: 估算某评分对应的下次间隔文案。

## 私有方法

### `_resolve_current_interval_days(card: CardEntity, now_day_index: int) -> int`
解析当前卡片的基础间隔天数：NEW/LEARNING 返回 1；REVIEW 根据 `due` 和 `stability` 估算。

### `_get_ease_factor(card: CardEntity) -> float`
计算简单版易度因子（SM-2 风格），基于 `difficulty` 映射到 1.3~3.0 范围。

### `_now_timestamp() -> int`
返回当前 Unix 时间戳（秒）。

### `_day_index_from_timestamp(unix_timestamp: int) -> int`
将 Unix 时间戳转换为天数索引。

### `_clampf(value: float, min_value: float, max_value: float) -> float`
对浮点数做区间裁剪。

## 常量

| 常量 | 值 | 说明 |
|------|----|------|
| `_LEARNING_STEP_SECONDS` | `600`（10分钟） | learning 队列步长（私有） |
| `_SECONDS_PER_DAY` | `86400` | 每天秒数（私有） |

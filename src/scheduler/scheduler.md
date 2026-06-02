# scheduler.gd (Scheduler)

> **路径**: `res://src/scheduler/scheduler.gd`
> **继承**: `RefCounted`
> **类型**: 调度层 — 抽象基类

## 概述
调度器抽象基类：只负责状态计算，不负责数据库读写和 UI 交互。设计目标是将算法与持久化彻底分离。Scheduler 只负责**状态机计算**，不负责**保存状态**。子类（如 `SimpleScheduler`）必须实现所有 `@abstract` 方法。

## 公共方法

### `calculate_next_state(card: CardEntity, rating: int, now_timestamp: int) -> Dictionary` *abstract*
**输入**:
- card (CardEntity) — 当前卡片实体。
- rating (int) — 用户评分，取值见 `Rating` 枚举。
- now_timestamp (int) — 当前 Unix 时间戳（秒）。

**输出**: Dictionary — 至少包含 `queue`/`due`/`reps`/`lapses`/`stability`/`difficulty`/`interval_days` 键。  
**说明**: 计算下一次复习状态（纯函数，无副作用）。不修改原 `CardEntity`，返回新的状态字典。

### `classify_queue(card: CardEntity, now_day_index: int, now_timestamp: int) -> int` *abstract*
**输入**:
- card (CardEntity) — 当前卡片实体。
- now_day_index (int) — 当前天数索引（Unix 时间戳 / 86400）。
- now_timestamp (int) — 当前 Unix 时间戳（秒）。

**输出**: int — 队列值，取值见 `Queue` 枚举。  
**说明**: 获取卡片当前应归属的队列（用于初始化/恢复）。

### `get_initial_state() -> Dictionary` *abstract*
**输入**: 无。  
**输出**: Dictionary — 至少包含 `queue`/`due`/`reps`/`lapses`/`stability`/`difficulty` 键。  
**说明**: 初始化新卡片的默认调度参数。

### `estimate_next_interval(card: CardEntity, rating: int) -> String` *abstract*
**输入**:
- card (CardEntity) — 当前卡片实体。
- rating (int) — 用户评分，取值见 `Rating` 枚举。

**输出**: String — 形如 "10分钟后"、"4天后"。  
**说明**: 估算某评分对应的下次间隔（用于按钮上展示）。

## 枚举

| 枚举 | 值 | 说明 |
|------|----|------|
| `Rating.AGAIN` | `1` | 完全遗忘 |
| `Rating.HARD` | `2` | 勉强想起 |
| `Rating.GOOD` | `3` | 正常回忆 |
| `Rating.EASY` | `4` | 轻松回忆 |
| `Queue.NEW` | `0` | 新卡片 |
| `Queue.LEARNING` | `1` | 学习中 |
| `Queue.REVIEW` | `2` | 复习中 |
| `Queue.SUSPENDED` | `-1` | 已暂停 |
| `Queue.BURIED` | `-2` | 已搁置 |

## 信号
无。

## 常量
无。

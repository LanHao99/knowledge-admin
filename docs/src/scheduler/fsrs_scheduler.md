# fsrs_scheduler.gd (FsrsScheduler)

> **路径**: `res://src/scheduler/fsrs_scheduler.gd`
> **继承**: `Scheduler`
> **类型**: 调度层

## 概述

FSRS（Free Spaced Repetition Scheduler）的 GDScript 实现，基于 py-fsrs v1.x 算法。使用 21 个可训练参数建模人类记忆曲线，比 SM-2 精确度提升 30%+。与 SimpleScheduler 实现相同接口，可无缝切换。

## FSRS 三态模型

| FSRS 状态 | queue 值 | step | 说明 |
|-----------|---------|------|------|
| **Learning** | QUEUE_LEARNING (1) | 0..N | 新卡首次学习，经过 learning_steps 逐步推进 |
| **Review** | QUEUE_REVIEW (2) | -1 (NULL) | 已毕业卡片，长间隔复习 |
| **Relearning** | QUEUE_LEARNING (1) | 0..N | Review 卡片挂科后重学 |

## 21 参数

| 索引 | 默认值 | 用途 |
|------|--------|------|
| w₀ | 0.212 | Again 初始 stability |
| w₁ | 1.2931 | Hard 初始 stability |
| w₂ | 2.3065 | Good 初始 stability |
| w₃ | 8.2956 | Easy 初始 stability |
| w₄ | 6.4133 | 初始 difficulty 参数 |
| w₅ | 0.8334 | 初始 difficulty 参数 |
| w₆ | 3.0194 | difficulty Δ 因子 |
| w₇ | 0.001 | 均值回归权重 |
| w₈ | 1.8722 | recall stability 增长率 |
| w₉ | 0.1666 | stability 幂衰减 |
| w₁₀ | 0.796 | retrievability 因子 |
| w₁₁ | 1.4835 | forget stability 系数 |
| w₁₂ | 0.0614 | forget stability difficulty 幂 |
| w₁₃ | 0.2629 | forget stability 幂 |
| w₁₄ | 1.6483 | forget stability retrievability 因子 |
| w₁₅ | 0.6014 | Hard 惩罚 |
| w₁₆ | 1.8729 | Easy 奖励 |
| w₁₇ | 0.5425 | short-term stability 因子 |
| w₁₈ | 0.0912 | short-term stability 偏移 |
| w₁₉ | 0.0658 | short-term stability 幂 |
| DECAY | 0.1542 | 遗忘曲线衰减率 |

## 公共方法

### `calculate_next_state(card: CardEntity, rating: int, now_timestamp: int) -> Dictionary`

**输入**:
- `card` (CardEntity) — 当前卡片实体。
- `rating` (int) — 用户评分（1=Again, 2=Hard, 3=Good, 4=Easy）。
- `now_timestamp` (int) — 当前 Unix 时间戳（秒）。

**输出**: 返回字典，包含 `queue`, `due`, `reps`, `lapses`, `stability`, `difficulty`, `interval_days`, `step`。

**说明**: FSRS 核心入口。三步：① 推导 FSRS 状态 → ② 更新 stability/difficulty → ③ 确定下一状态和间隔。

---

### `classify_queue(card, now_day_index, now_timestamp) -> int`

保持与 SimpleScheduler 一致的逻辑：SUSPENDED/BURIED 保持不变，其余返回 card.queue。

---

### `get_initial_state() -> Dictionary`

返回 `{queue: LEARNING, step: 0, stability: 0.0, difficulty: 0.0, ...}`。新卡从 Learning step=0 开始。

---

### `estimate_next_interval(card, rating) -> String`

估算评分后的间隔文案。根据当前 FSRS 状态和评分给出 "10分钟后" / "4天后" 等文案。

## 配置属性

| 属性 | 默认值 | 说明 |
|------|--------|------|
| `desired_retention` | 0.9 | 期望最低记忆保留率 |
| `learning_steps` | [60, 600] | 学习步进（1分钟 → 10分钟） |
| `relearning_steps` | [600] | 重学习步进（10分钟） |
| `maximum_interval` | 36500 | 最大间隔天数 |
| `enable_fuzzing` | true | 是否启用模糊化 |

## 核心公式

```
检索概率:     R = (1 + FACTOR * t / S) ^ (-DECAY)
初始稳定性:   S₀ = w[rating-1]
初始难度:     D₀ = w₄ - e^(w₅*(rating-1)) + 1
下次间隔:     I = (S / FACTOR) * (retention^(1/DECAY) - 1)
成功稳定性:   S' = S * (1 + e^w₈*(11-D)*S^(-w₉)*(e^((1-R)*w₁₀)-1)*hard*easy)
遗忘稳定性:   S' = min(w₁₁*D^(-w₁₂)*((S+1)^w₁₃-1)*e^((1-R)*w₁₄), S/e^(w₁₇*w₁₈))
难度更新:     D' = w₇*D₀(Easy) + (1-w₇)*(D + (10-D)*ΔD/9), ΔD = -w₆*(r-3)
```

## 与 SimpleScheduler 的差异

| 维度 | SimpleScheduler | FsrsScheduler |
|------|----------------|---------------|
| 参数模型 | 硬编码公式 | 21 个可训练参数 |
| 遗忘建模 | 无 | 检索概率 R(t) |
| 学习阶段 | 固定 10 分钟 | 多步可配置 |
| 重学习阶段 | 无 | 独立 relearning_steps |
| 难度 | 简单 SM-2 ease_factor | 均值回归 + 线性衰减 |
| 遗忘稳定性 | S × 0.5 | 双公式取 min |
| 间隔模糊 | 无 | 三段 fuzzing |

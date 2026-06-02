## 调度层接口（Scheduler）

> 设计目标：算法与持久化彻底分离。Scheduler 只负责**状态机计算**，不负责**保存状态**。

### 4.1 Scheduler 基类（抽象接口）

```gdscript
@abstract
class_name Scheduler
extends RefCounted

# 评分枚举
enum Rating { AGAIN = 1, HARD = 2, GOOD = 3, EASY = 4 }

# 队列类型
enum Queue { NEW = 0, LEARNING = 1, REVIEW = 2, SUSPENDED = -1, BURIED = -2 }

# ── 核心算法接口 ──

## 计算下一次复习状态（纯函数，无副作用）
## 输入：当前 CardEntity + 用户评分
## 输出：新的状态字典（不修改原始 CardEntity）
@abstract func calculate_next_state(card: CardEntity, rating: int, now_timestamp: int) -> Dictionary
    # return {
    #   "queue": int,
    #   "due": int,
    #   "reps": int,
    #   "lapses": int,
    #   "stability": float,
    #   "difficulty": float,
    #   "interval_days": int     # 仅用于展示/调试
    # }

## 获取卡片当前应归属的队列（用于初始化/恢复）
@abstract func classify_queue(card: CardEntity, now_day_index: int, now_timestamp: int) -> int

## 初始化新卡片的默认调度参数
@abstract func get_initial_state() -> Dictionary

# ── 学习进度估算 ──

## 估算某评分对应的下次间隔（用于按钮上展示"4天后"）
@abstract func estimate_next_interval(card: CardEntity, rating: int) -> String
```

### 4.2 SimpleScheduler（简易实现 —— V1 可用）

```gdscript
class_name SimpleScheduler
extends Scheduler

# 基于 SM-2 简化版：
# - Again → queue=LEARNING, due=+10min, reps+1, lapses+1
# - Hard  → queue=REVIEW, interval*1.2, reps+1
# - Good  → queue=REVIEW, interval*ease_factor, reps+1
# - Easy  → queue=REVIEW, interval*ease_factor*1.3, reps+1
# - New → 首次 Review 根据评分进入 LEARNING/REVIEW
```

### 4.3 FsrsScheduler（未来预留）

```gdscript
class_name FsrsScheduler
extends Scheduler

# 预留 FSRS-4.5/5.0 参数化实现
# 从数据库读取 stability/difficulty，运行 FSRS 公式
```

---

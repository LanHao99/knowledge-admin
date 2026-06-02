@abstract
class_name Scheduler
extends RefCounted

# 调度器抽象基类：只负责状态计算，不负责数据库读写和 UI 交互。

# 评分枚举
enum Rating {
	AGAIN = 1,
	HARD = 2,
	GOOD = 3,
	EASY = 4
}

# 队列枚举
enum Queue {
	NEW = 0,
	LEARNING = 1,
	REVIEW = 2,
	SUSPENDED = -1,
	BURIED = -2
}


## 计算下一次复习状态（抽象接口，子类必须重写）。## 输入:
##   card (CardEntity) - 当前卡片实体。
##   rating (int) - 用户评分，取值见 Rating 枚举。
##   now_timestamp (int) - 当前 Unix 时间戳（秒）。
## 输出: Dictionary。成功时至少包含 queue/due/reps/lapses/stability/difficulty/interval_days 键。
@abstract func calculate_next_state(card: CardEntity, rating: int, now_timestamp: int) -> Dictionary


## 获取卡片当前应归属的队列（抽象接口，子类可按规则重写）。## 输入:
##   card (CardEntity) - 当前卡片实体。
##   now_day_index (int) - 当前天数索引（Unix 时间戳 / 86400）。
##   now_timestamp (int) - 当前 Unix 时间戳（秒）。
## 输出: int，队列值，取值见 Queue 枚举。
@abstract func classify_queue(card: CardEntity, now_day_index: int, now_timestamp: int) -> int


## 初始化新卡片的默认调度状态（抽象接口，子类可按算法返回默认值）。## 输入: 无。
## 输出: Dictionary，至少包含 queue/due/reps/lapses/stability/difficulty 键。
@abstract func get_initial_state() -> Dictionary


## 估算某评分对应的下次间隔文案（抽象接口，子类必须重写）。## 输入:
##   card (CardEntity) - 当前卡片实体。
##   rating (int) - 用户评分，取值见 Rating 枚举。
## 输出: String，形如 "10分钟后"、"4天后"。
@abstract func estimate_next_interval(card: CardEntity, rating: int) -> String

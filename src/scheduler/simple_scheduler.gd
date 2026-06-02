class_name SimpleScheduler
extends Scheduler

# 基于 SM-2 思路的简化调度器：
# - 只做纯计算，不触碰数据库。
# - learning 队列按秒级时间戳调度。
# - review 队列按天数索引调度。

const _LEARNING_STEP_SECONDS: int = 10 * 60
const _SECONDS_PER_DAY: int = 86400


## 计算下一次复习状态。
##
## 输入:
##   card (CardEntity) - 当前卡片实体。
##   rating (int) - 用户评分，取值见 Scheduler.Rating。
##   now_timestamp (int) - 当前 Unix 时间戳（秒）。
## 输出: Dictionary，包含 queue/due/reps/lapses/stability/difficulty/interval_days。
func calculate_next_state(card: CardEntity, rating: int, now_timestamp: int) -> Dictionary:
	var now_day_index: int = _day_index_from_timestamp(now_timestamp)
	var current_interval_days: int = _resolve_current_interval_days(card, now_day_index)
	var next_reps: int = card.reps + 1
	var next_lapses: int = card.lapses
	var next_queue: int = Queue.REVIEW
	var next_due: int = now_day_index + 1
	var next_stability: float = max(card.stability, 0.0)
	var next_difficulty: float = _clampf(card.difficulty, 0.0, 10.0)
	var next_interval_days: int = 1

	match rating:
		Rating.AGAIN:
			next_queue = Queue.LEARNING
			next_due = now_timestamp + _LEARNING_STEP_SECONDS
			next_lapses += 1
			next_interval_days = 0
			next_stability = max(0.1, next_stability * 0.5)
			next_difficulty = _clampf(next_difficulty + 0.35, 0.0, 10.0)
		Rating.HARD:
			next_queue = Queue.REVIEW
			next_interval_days = max(1, int(ceil(float(current_interval_days) * 1.2)))
			next_due = now_day_index + next_interval_days
			next_stability = max(1.0, float(next_interval_days))
			next_difficulty = _clampf(next_difficulty + 0.1, 0.0, 10.0)
		Rating.GOOD:
			next_queue = Queue.REVIEW
			var ease_factor: float = _get_ease_factor(card)
			next_interval_days = max(1, int(round(float(current_interval_days) * ease_factor)))
			next_due = now_day_index + next_interval_days
			next_stability = max(1.0, float(next_interval_days))
			next_difficulty = _clampf(next_difficulty - 0.05, 0.0, 10.0)
		Rating.EASY:
			next_queue = Queue.REVIEW
			var easy_factor: float = _get_ease_factor(card) * 1.3
			next_interval_days = max(2, int(round(float(current_interval_days) * easy_factor)))
			next_due = now_day_index + next_interval_days
			next_stability = max(1.0, float(next_interval_days))
			next_difficulty = _clampf(next_difficulty - 0.15, 0.0, 10.0)
		_:
			# 未知评分按 GOOD 处理，确保流程可继续。
			next_queue = Queue.REVIEW
			var fallback_factor: float = _get_ease_factor(card)
			next_interval_days = max(1, int(round(float(current_interval_days) * fallback_factor)))
			next_due = now_day_index + next_interval_days
			next_stability = max(1.0, float(next_interval_days))

	return {
		"queue": next_queue,
		"due": next_due,
		"reps": next_reps,
		"lapses": next_lapses,
		"stability": next_stability,
		"difficulty": next_difficulty,
		"interval_days": next_interval_days
	}


## 获取卡片当前应归属的队列。
##
## 输入:
##   card (CardEntity) - 当前卡片实体。
##   now_day_index (int) - 当前天数索引。
##   now_timestamp (int) - 当前 Unix 时间戳（秒）。
## 输出: int，队列值。
func classify_queue(card: CardEntity, now_day_index: int, now_timestamp: int) -> int:
	match card.queue:
		Queue.SUSPENDED:
			return Queue.SUSPENDED
		Queue.BURIED:
			if card.due <= now_day_index:
				return Queue.NEW
			return Queue.BURIED
		Queue.LEARNING:
			if card.due <= now_timestamp:
				return Queue.LEARNING
			return Queue.LEARNING
		Queue.REVIEW:
			if card.due <= now_day_index:
				return Queue.REVIEW
			return Queue.REVIEW
		_:
			return Queue.NEW


## 返回新卡片的默认调度状态。
##
## 输入: 无。
## 输出: Dictionary，包含 queue/due/reps/lapses/stability/difficulty。
func get_initial_state() -> Dictionary:
	return {
		"queue": Queue.NEW,
		"due": 0,
		"reps": 0,
		"lapses": 0,
		"stability": 0.0,
		"difficulty": 3.0
	}


## 估算某评分对应的下次间隔文案。
##
## 输入:
##   card (CardEntity) - 当前卡片实体。
##   rating (int) - 用户评分，取值见 Scheduler.Rating。
## 输出: String，形如 "10分钟后"、"4天后"。
func estimate_next_interval(card: CardEntity, rating: int) -> String:
	if rating == Rating.AGAIN:
		return "10分钟后"

	var now_day_index: int = _day_index_from_timestamp(_now_timestamp())
	var current_interval_days: int = _resolve_current_interval_days(card, now_day_index)
	var estimated_days: int = 1

	match rating:
		Rating.HARD:
			estimated_days = max(1, int(ceil(float(current_interval_days) * 1.2)))
		Rating.GOOD:
			estimated_days = max(1, int(round(float(current_interval_days) * _get_ease_factor(card))))
		Rating.EASY:
			estimated_days = max(2, int(round(float(current_interval_days) * _get_ease_factor(card) * 1.3)))
		_:
			estimated_days = 1

	return "%d天后" % estimated_days


## 解析当前卡片的基础间隔天数。
##
## 输入:
##   card (CardEntity) - 当前卡片实体。
##   now_day_index (int) - 当前天数索引。
## 输出: int，最小为 1 的间隔天数。
func _resolve_current_interval_days(card: CardEntity, now_day_index: int) -> int:
	if card.queue == Queue.NEW:
		return 1
	if card.queue == Queue.LEARNING:
		return 1
	if card.queue == Queue.REVIEW:
		if card.due > now_day_index:
			return max(1, card.due - now_day_index)
		if card.stability > 0.0:
			return max(1, int(round(card.stability)))
		return 1
	return 1


## 计算简单版易度因子（SM-2 风格）。
##
## 输入: card (CardEntity) - 当前卡片实体。
## 输出: float，取值范围 1.3~3.0。
func _get_ease_factor(card: CardEntity) -> float:
	if card.difficulty <= 0.0:
		return 2.5
	var factor: float = 2.7 - card.difficulty * 0.15
	return _clampf(factor, 1.3, 3.0)


## 返回当前 Unix 时间戳（秒）。
##
## 输入: 无。
## 输出: int，当前系统时间戳。
func _now_timestamp() -> int:
	return int(Time.get_unix_time_from_system())


## 将 Unix 时间戳转换为天数索引。
##
## 输入: unix_timestamp (int) - Unix 时间戳（秒）。
## 输出: int，天数索引。
func _day_index_from_timestamp(unix_timestamp: int) -> int:
	return int(unix_timestamp / _SECONDS_PER_DAY)


## 对浮点数做区间裁剪（兼容性封装）。
##
## 输入:
##   value (float) - 待裁剪值。
##   min_value (float) - 最小值。
##   max_value (float) - 最大值。
## 输出: float，裁剪后的结果。
func _clampf(value: float, min_value: float, max_value: float) -> float:
	if value < min_value:
		return min_value
	if value > max_value:
		return max_value
	return value

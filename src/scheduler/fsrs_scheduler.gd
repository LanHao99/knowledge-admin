class_name FsrsScheduler
extends Scheduler

## FSRS (Free Spaced Repetition Scheduler) 的 GDScript 实现。
## 基于 py-fsrs v1.x 算法，使用 21 个可训练参数建模人类记忆曲线。
## 与 SimpleScheduler 实现相同接口，可无缝切换。
##
## 核心概念：
##   - stability (S): 记忆半衰期，单位天。从 S 出发遗忘概率降至 90% 需要的时间。
##   - difficulty (D): 卡片固有难度，范围 [1, 10]。越高越难记住。
##   - retrievability (R): 当前正确回忆此卡的概率，范围 [0, 1]。
##   - step: 学习/重学习步进索引。NULL(-1) = Review 状态，0..N = 步进中。
##
## 三态模型 → CardEntity.queue 映射：
##   FSRS Learning    → QUEUE_LEARNING (step >= 0)
##   FSRS Review      → QUEUE_REVIEW   (step = -1)
##   FSRS Relearning  → QUEUE_LEARNING (step >= 0)
##   QUEUE_NEW        → 视为 Learning step=0 进入

# ── 21 个 FSRS 模型参数（py-fsrs 默认值，经千万级用户数据训练）──
const _W0: float = 0.212
const _W1: float = 1.2931
const _W2: float = 2.3065
const _W3: float = 8.2956
const _W4: float = 6.4133
const _W5: float = 0.8334
const _W6: float = 3.0194
const _W7: float = 0.001
const _W8: float = 1.8722
const _W9: float = 0.1666
const _W10: float = 0.796
const _W11: float = 1.4835
const _W12: float = 0.0614
const _W13: float = 0.2629
const _W14: float = 1.6483
const _W15: float = 0.6014
const _W16: float = 1.8729
const _W17: float = 0.5425
const _W18: float = 0.0912
const _W19: float = 0.0658
const _DECAY: float = 0.1542

# ── 从 DECAY 推导的公式常数 ──
const _FACTOR: float = pow(0.9, -1.0 / _DECAY) - 1.0  # ≈ 0.981（py-fsrs: FACTOR = 0.9^(1/DECAY)-1, DECAY=-w20）

# ── 数值安全边界 ──
const _STABILITY_MIN: float = 0.001
const _DIFFICULTY_MIN: float = 1.0
const _DIFFICULTY_MAX: float = 10.0
const _SECONDS_PER_DAY: int = 86400

# ── 调度配置（可参数化，当前使用默认值）──
## 期望最低记忆保留率。R 降至该值以下时卡片到期。
var desired_retention: float = 0.9

## 学习阶段步进间隔（秒）。新卡从 step=0 开始，逐步推进。
## 默认: 1 分钟 → 10 分钟
var learning_steps: Array[int] = [60, 600]

## 重学习阶段步进间隔（秒）。Review 卡片挂科后进入。
## 默认: 10 分钟一步
var relearning_steps: Array[int] = [600]

## Review 卡片最大间隔（天）。默认 36500 天 ≈ 100 年。
var maximum_interval: int = 36500

## 是否启用间隔模糊化（避免同分卡片扎堆到期）。
var enable_fuzzing: bool = true

# ── 21 参数数组（方便用 rating-1 索引）──
var _w: Array[float] = [_W0, _W1, _W2, _W3, _W4, _W5, _W6, _W7, _W8, _W9, _W10, _W11, _W12, _W13, _W14, _W15, _W16, _W17, _W18, _W19, _DECAY]


## 计算下一次复习状态（FSRS 核心入口）。## 输入:
##   card (CardEntity) - 当前卡片实体。
##   rating (int) - 用户评分，取值 1~4（Again/Hard/Good/Easy）。
##   now_timestamp (int) - 当前 Unix 时间戳（秒）。
## 输出: Dictionary，包含 queue/due/reps/lapses/stability/difficulty/interval_days/step。
func calculate_next_state(card: CardEntity, rating: int, now_timestamp: int) -> Dictionary:
	var now_day_index: int = now_timestamp / _SECONDS_PER_DAY

	# 1) 确定当前 FSRS 状态
	var fsrs_state: int = _derive_fsrs_state(card)

	# 2) 计算自上次复习经过的天数
	var days_since_last_review: int = -1
	if card.last_review_time > 0:
		var elapsed_sec: int = max(now_timestamp - card.last_review_time, 0)
		days_since_last_review = int(elapsed_sec / _SECONDS_PER_DAY)

	# 3) 按 FSRS 三态分发
	var next_stability: float = card.stability
	var next_difficulty: float = card.difficulty
	var next_step: int = card.step

	match fsrs_state:
		0:  # Learning (含 NEW 首次学习)
			var sd: Array[float] = _update_learning_stability_difficulty(
				card, rating, days_since_last_review, now_timestamp
			)
			next_stability = sd[0]
			next_difficulty = sd[1]
		1:  # Review
			next_stability = _update_review_stability(
				card, rating, days_since_last_review, now_timestamp
			)
			next_difficulty = _next_difficulty(card.difficulty, rating)
		2:  # Relearning
			next_stability = _update_review_stability(
				card, rating, days_since_last_review, now_timestamp
			)
			next_difficulty = _next_difficulty(card.difficulty, rating)

	# 4) 确定下一状态和间隔
	var next_queue: int
	var next_due: int
	var next_interval_days: int = 0

	match fsrs_state:
		0:  # Learning
			var step_result := _advance_learning_step(
				card, rating, next_stability, learning_steps
			)
			next_queue = step_result.get("queue", CardEntity.QUEUE_LEARNING)
			next_step = step_result.get("step", 0)
			if next_queue == CardEntity.QUEUE_REVIEW:
				next_interval_days = _next_interval(next_stability)
				next_due = now_day_index + next_interval_days
				next_step = -1
			else:
				next_interval_days = 0
				next_due = now_day_index  # 当天可复习（不再等固定秒数）

		1:  # Review
			match rating:
				Rating.AGAIN:
					if relearning_steps.is_empty():
						# 无 relearning steps 则留在 Review
						next_queue = CardEntity.QUEUE_REVIEW
						next_step = -1
						next_interval_days = _next_interval(next_stability)
						next_due = now_day_index + next_interval_days
					else:
						# 进入 Relearning
						next_queue = CardEntity.QUEUE_LEARNING
						next_step = 0
						next_interval_days = 0
						next_due = now_day_index  # 当天可复习
				_:
					next_queue = CardEntity.QUEUE_REVIEW
					next_step = -1
					next_interval_days = _next_interval(next_stability)
					next_due = now_day_index + next_interval_days

		2:  # Relearning
			var step_result := _advance_learning_step(
				card, rating, next_stability, relearning_steps
			)
			next_queue = step_result.get("queue", CardEntity.QUEUE_LEARNING)
			next_step = step_result.get("step", 0)
			if next_queue == CardEntity.QUEUE_REVIEW:
				next_interval_days = _next_interval(next_stability)
				next_due = now_day_index + next_interval_days
				next_step = -1
			else:
				next_interval_days = 0
				next_due = now_day_index  # 当天可复习

		_:
			# 未知状态退化为 NEW 逻辑
			next_queue = CardEntity.QUEUE_NEW
			next_due = now_day_index
			next_step = 0

	# 5) Review 状态模糊化间隔
	if enable_fuzzing and next_queue == CardEntity.QUEUE_REVIEW and next_interval_days >= 1:
		next_interval_days = _apply_fuzz(next_interval_days)
		next_due = now_day_index + next_interval_days

	var next_reps: int = card.reps + 1
	var next_lapses: int = card.lapses
	if rating == Rating.AGAIN:
		next_lapses += 1

	return {
		"queue": next_queue,
		"due": next_due,
		"reps": next_reps,
		"lapses": next_lapses,
		"stability": next_stability,
		"difficulty": next_difficulty,
		"interval_days": next_interval_days,
		"step": next_step
	}


## 获取卡片当前应归属的队列。## 输入:
##   card (CardEntity) - 当前卡片实体。
##   now_day_index (int) - 当前天数索引。
##   now_timestamp (int) - 当前 Unix 时间戳（秒）。
## 输出: int，队列值。
func classify_queue(card: CardEntity, now_day_index: int, now_timestamp: int) -> int:
	match card.queue:
		CardEntity.QUEUE_SUSPENDED:
			return CardEntity.QUEUE_SUSPENDED
		CardEntity.QUEUE_BURIED:
			return CardEntity.QUEUE_NEW if card.due <= now_day_index else CardEntity.QUEUE_BURIED
		_:
			# FSRS 直接用 queue 字段，到期检测走 due
			return card.queue


## 返回新卡片的默认调度状态。## 输入: 无。
## 输出: Dictionary，包含 queue/due/reps/lapses/stability/difficulty/step。
func get_initial_state() -> Dictionary:
	return {
		"queue": CardEntity.QUEUE_LEARNING,
		"due": 0,
		"reps": 0,
		"lapses": 0,
		"stability": 0.0,
		"difficulty": 0.0,
		"step": 0
	}


## 估算某评分对应的下次间隔文案。## 输入:
##   card (CardEntity) - 当前卡片实体。
##   rating (int) - 用户评分。
## 输出: String，形如 "10分钟后"、"4天后"。
func estimate_next_interval(card: CardEntity, rating: int) -> String:
	if rating == Rating.AGAIN:
		if _derive_fsrs_state(card) == 1:  # Review 的 Again
			if not relearning_steps.is_empty():
				return _format_seconds(relearning_steps[0])
		if card.step >= 0:
			var steps: Array[int] = _get_step_array(card)
			if not steps.is_empty():
				return _format_seconds(steps[0])
		return "10分钟后"

	match _derive_fsrs_state(card):
		0:  # Learning
			if rating == Rating.EASY:
				var s: float = _initial_stability(rating)
				var days: int = _next_interval(s)
				return "%d天后" % days
			var steps: Array[int] = learning_steps
			if card.step >= 0 and card.step + 1 < steps.size():
				return _format_seconds(steps[card.step + 1])
			return "%d天后" % _next_interval(_initial_stability(Rating.GOOD))

		1:  # Review
			var s: float = card.stability if card.stability > 0 else _initial_stability(rating)
			var days: int = _next_interval(s)
			return "%d天后" % days

		2:  # Relearning
			if rating == Rating.EASY:
				var s: float = card.stability
				return "%d天后" % _next_interval(s)
			var steps: Array[int] = relearning_steps
			if card.step >= 0 and card.step + 1 < steps.size():
				return _format_seconds(steps[card.step + 1])
			return "%d天后" % _next_interval(card.stability)

	return "1天后"


# ── 内部：状态推导 ──


## 从 CardEntity 推导当前 FSRS 三态。## 输入: card (CardEntity) - 卡片实体。
## 输出: int - 0=Learning, 1=Review, 2=Relearning。
func _derive_fsrs_state(card: CardEntity) -> int:
	if card.queue == CardEntity.QUEUE_NEW:
		return 0  # Learning
	if card.queue == CardEntity.QUEUE_REVIEW:
		return 1  # Review
	if card.queue == CardEntity.QUEUE_LEARNING:
		if card.step >= 0:
			# 通过稳定性判断：stability < 1 且 reps 很少 → Learning；否则 Relearning
			if card.reps <= 1 and card.stability < 1.0:
				return 0  # Learning
			else:
				return 2  # Relearning
		else:
			return 1  # Review（step=-1 的 LEARNING 视为 Review 的退化）
	return 1  # 默认 Review


# ── 内部：稳定性/难度更新 ──


## 更新 Learning 状态下的 stability 和 difficulty。## 输入:
##   card (CardEntity) - 卡片实体。
##   rating (int) - 评分。
##   days_since_last_review (int) - 间隔天数，-1 表示首次。
##   now_timestamp (int) - 当前时间戳。
## 输出: Array[float] - [new_stability, new_difficulty]。
func _update_learning_stability_difficulty(card: CardEntity, rating: int, days_since_last_review: int, now_timestamp: int) -> Array[float]:
	var new_stability: float
	var new_difficulty: float
	var is_first: bool = (card.stability <= 0.0 or card.difficulty <= 0.0)

	if is_first:
		# 首次学习：使用初始公式
		new_stability = _initial_stability(rating)
		new_difficulty = _initial_difficulty(rating)
	elif days_since_last_review < 1:
		# 同一天内：短时稳定性公式
		new_stability = _short_term_stability(card.stability, rating)
		new_difficulty = _next_difficulty(card.difficulty, rating)
	else:
		# 跨天：长时稳定性公式
		var retrievability: float = _retrievability(card, now_timestamp)
		new_stability = _next_stability(card.difficulty, card.stability, retrievability, rating)
		new_difficulty = _next_difficulty(card.difficulty, rating)

	return [new_stability, new_difficulty]


## 更新 Review 状态下的 stability。## 输入:
##   card (CardEntity) - 卡片实体。
##   rating (int) - 评分。
##   days_since_last_review (int) - 间隔天数。
##   now_timestamp (int) - 当前时间戳。
## 输出: float - new_stability。
func _update_review_stability(card: CardEntity, rating: int, days_since_last_review: int, now_timestamp: int) -> float:
	if days_since_last_review < 1:
		# 同一天内 Review → 短时公式
		return _short_term_stability(card.stability, rating)

	var retrievability: float = _retrievability(card, now_timestamp)
	return _next_stability(card.difficulty, card.stability, retrievability, rating)


# ── 内部：步进推进 ──


## 在 Learning/Relearning 阶段推进步进。## 输入:
##   card (CardEntity) - 卡片实体。
##   rating (int) - 评分。
##   stability (float) - 当前 stability。
##   steps (Array[int]) - 步进间隔数组（秒）。
## 输出: Dictionary - {queue, step, interval_sec}。
func _advance_learning_step(card: CardEntity, rating: int, stability: float, steps: Array[int]) -> Dictionary:
	if steps.is_empty():
		# 无步进数组 → 直接毕业到 Review
		return {"queue": CardEntity.QUEUE_REVIEW, "step": -1, "interval_sec": 0}

	var current_step: int = card.step if card.step >= 0 else 0

	# 处理边缘情况：当前 step 已经超出 steps 数组（换用不同长度的 steps 时）
	if current_step >= steps.size() and rating in [Rating.HARD, Rating.GOOD, Rating.EASY]:
		return {"queue": CardEntity.QUEUE_REVIEW, "step": -1, "interval_sec": 0}

	match rating:
		Rating.AGAIN:
			return {"queue": CardEntity.QUEUE_LEARNING, "step": 0, "interval_sec": steps[0]}

		Rating.HARD:
			# step 不变，计算 Hard 的间隔
			var interval_sec: int
			if current_step == 0 and steps.size() == 1:
				interval_sec = int(steps[0] * 1.5)
			elif current_step == 0 and steps.size() >= 2:
				interval_sec = int((steps[0] + steps[1]) / 2.0)
			else:
				interval_sec = steps[current_step]
			return {"queue": CardEntity.QUEUE_LEARNING, "step": current_step, "interval_sec": interval_sec}

		Rating.GOOD:
			if current_step + 1 >= steps.size():
				# 最后一步 → 毕业到 Review
				return {"queue": CardEntity.QUEUE_REVIEW, "step": -1, "interval_sec": 0}
			else:
				return {"queue": CardEntity.QUEUE_LEARNING, "step": current_step + 1, "interval_sec": steps[current_step + 1]}

		Rating.EASY:
			# 直接毕业
			return {"queue": CardEntity.QUEUE_REVIEW, "step": -1, "interval_sec": 0}

		_:
			return {"queue": CardEntity.QUEUE_LEARNING, "step": 0, "interval_sec": steps[0]}


# ── 内部：核心数学公式 ──


## 计算检索概率 R(t)（当前正确回忆此卡的概率）。## 输入:
##   card (CardEntity) - 卡片实体。
##   now_timestamp (int) - 当前时间戳（秒）。
## 输出: float - retrievability [0, 1]。
func _retrievability(card: CardEntity, now_timestamp: int) -> float:
	if card.stability <= 0.0 or card.last_review_time <= 0:
		return 0.0
	var elapsed_days: int = max((now_timestamp - card.last_review_time) / _SECONDS_PER_DAY, 0)
	return pow(1.0 + _FACTOR * float(elapsed_days) / card.stability, -_DECAY)


## 初始稳定性 S₀ = w[rating-1]。## 输入: rating (int) - 评分。
## 输出: float - initial_stability，≥ STABILITY_MIN。
func _initial_stability(rating: int) -> float:
	return max(_w[rating - 1], _STABILITY_MIN)


## 初始难度 D₀ = w₄ - e^(w₅ × (rating - 1)) + 1，clamp 到 [1, 10]。## 输入: rating (int) - 评分。
## 输出: float - initial_difficulty。
func _initial_difficulty(rating: int) -> float:
	var d: float = _W4 - exp(_W5 * float(rating - 1)) + 1.0
	return clampf(d, _DIFFICULTY_MIN, _DIFFICULTY_MAX)


## 将 stability 转为下次间隔天数（核心调度公式）。## 输入: stability (float) - 当前稳定性。
## 输出: int - 间隔天数，clamp 到 [1, maximum_interval]。
func _next_interval(stability: float) -> int:
	var s: float = max(stability, _STABILITY_MIN)
	var interval: int = roundi((s / _FACTOR) * (pow(desired_retention, 1.0 / _DECAY) - 1.0))
	return clampi(interval, 1, maximum_interval)


## 短时稳定性（同一天内复习）。## 输入:
##   stability (float) - 当前稳定性。
##   rating (int) - 评分。
## 输出: float - short_term_stability。
func _short_term_stability(stability: float, rating: int) -> float:
	var s: float = max(stability, _STABILITY_MIN)
	var increase: float = exp(_W17 * (float(rating) - 3.0 + _W18)) * pow(s, -_W19)
	if rating in [Rating.GOOD, Rating.EASY]:
		increase = max(increase, 1.0)
	return max(s * increase, _STABILITY_MIN)


## 下一次难度（均值回归公式 + 线性衰减）。## 输入:
##   difficulty (float) - 当前难度。
##   rating (int) - 评分。
## 输出: float - next_difficulty [1, 10]。
func _next_difficulty(difficulty: float, rating: int) -> float:
	var d: float = clampf(difficulty, _DIFFICULTY_MIN, _DIFFICULTY_MAX)
	# ΔD = -w₆ × (rating - 3)
	var delta: float = -_W6 * (float(rating) - 3.0)
	# 线性衰减: (10 - D) × ΔD / 9
	var damped: float = d + (10.0 - d) * delta / 9.0
	# 均值回归: w₇ × D₀(Easy) + (1 - w₇) × damped
	var d_easy: float = _W4 - exp(_W5 * 3.0) + 1.0  # D₀ for Easy (rating=4 → rating-1=3)
	var next_d: float = _W7 * d_easy + (1.0 - _W7) * damped
	return clampf(next_d, _DIFFICULTY_MIN, _DIFFICULTY_MAX)


## 下一次稳定性（按评分分发）。## 输入:
##   difficulty (float) - 当前难度。
##   stability (float) - 当前稳定性。
##   retrievability (float) - 当前检索概率。
##   rating (int) - 评分。
## 输出: float - next_stability。
func _next_stability(difficulty: float, stability: float, retrievability: float, rating: int) -> float:
	var d: float = clampf(difficulty, _DIFFICULTY_MIN, _DIFFICULTY_MAX)
	var s: float = max(stability, _STABILITY_MIN)

	if rating == Rating.AGAIN:
		return _forget_stability(d, s, retrievability)

	return _recall_stability(d, s, retrievability, rating)


## 遗忘后稳定性（Again）。取长期遗忘公式和短期遗忘公式的 min。## 输入:
##   difficulty (float) - 当前难度。
##   stability (float) - 当前稳定性。
##   retrievability (float) - 检索概率。
## 输出: float。
func _forget_stability(difficulty: float, stability: float, retrievability: float) -> float:
	# 长期遗忘公式
	var long_term: float = _W11 * pow(difficulty, -_W12) * (pow(stability + 1.0, _W13) - 1.0) * exp((1.0 - retrievability) * _W14)
	# 短期遗忘公式
	var short_term: float = stability / exp(_W17 * _W18)
	return max(min(long_term, short_term), _STABILITY_MIN)


## 成功回忆稳定性（Hard/Good/Easy）。## 输入:
##   difficulty (float) - 当前难度。
##   stability (float) - 当前稳定性。
##   retrievability (float) - 检索概率。
##   rating (int) - 评分。
## 输出: float。
func _recall_stability(difficulty: float, stability: float, retrievability: float, rating: int) -> float:
	var hard_penalty: float = _W15 if rating == Rating.HARD else 1.0
	var easy_bonus: float = _W16 if rating == Rating.EASY else 1.0

	var result: float = stability * (
		1.0
		+ exp(_W8)
		* (11.0 - difficulty)
		* pow(stability, -_W9)
		* (exp((1.0 - retrievability) * _W10) - 1.0)
		* hard_penalty
		* easy_bonus
	)
	return max(result, _STABILITY_MIN)


# ── 内部：Fuzzing ──


## 对间隔天数施加模糊化（避免同分卡片扎堆到期）。## 输入: interval_days (int) - 原始间隔。
## 输出: int - 模糊化后的间隔。
func _apply_fuzz(interval_days: int) -> int:
	if interval_days < 3:
		return interval_days

	# 三段 FUZZ_RANGES: [{2.5,7,0.15}, {7,20,0.10}, {20,INF,0.05}]
	var delta: float = 1.0
	var iv: float = float(interval_days)

	delta += 0.15 * max(min(iv, 7.0) - 2.5, 0.0)
	delta += 0.10 * max(min(iv, 20.0) - 7.0, 0.0)
	delta += 0.05 * max(iv - 20.0, 0.0)

	var min_ivl: int = max(2, roundi(iv - delta))
	var max_ivl: int = min(roundi(iv + delta), maximum_interval)
	min_ivl = min(min_ivl, max_ivl)

	var fuzzed: int = min_ivl + randi() % (max_ivl - min_ivl + 1)
	return clampi(fuzzed, 1, maximum_interval)


# ── 内部：工具 ──


## 根据当前 step 获取对应的步进数组。## 输入: card (CardEntity)。
## 输出: Array[int] - learning_steps 或 relearning_steps。
func _get_step_array(card: CardEntity) -> Array[int]:
	var state: int = _derive_fsrs_state(card)
	if state == 2:
		return relearning_steps
	return learning_steps


## 获取当前 Unix 时间戳（秒）。## 输入: 无。
## 输出: int。
func _now_timestamp() -> int:
	return int(Time.get_unix_time_from_system())


## 秒数格式化为可读文案。## 输入: seconds (int)。
## 输出: String - "X分钟后" / "X秒后" 等。
func _format_seconds(seconds: int) -> String:
	if seconds < 60:
		return "%d秒后" % seconds
	if seconds < 3600:
		return "%d分钟后" % (seconds / 60)
	if seconds < 86400:
		return "%d小时后" % (seconds / 3600)
	return "%d天后" % (seconds / 86400)

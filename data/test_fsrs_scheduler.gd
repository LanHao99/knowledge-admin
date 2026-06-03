@tool
extends Node

## FSRS 调度器算法单元测试。
## 在 Godot 编辑器中运行: 场景根节点挂此脚本 → 运行场景 → 看控制台输出。
## 也可通过 main_menu.gd 在启动时调用 run_all_tests()。
##
## 测试用例对照 py-fsrs 预先计算的期望值。
## 容差: stability 0.01, difficulty 0.1, interval 精确。

const _NOW: int = 1717200000  # 2024-06-01 00:00:00 UTC 固定时间戳


func run_all_tests() -> Dictionary:
	print("=".repeat(60))
	print("FSRS Scheduler 单元测试开始")
	print("=".repeat(60))

	var passed := 0
	var failed := 0
	var errors: Array[String] = []

	var cases: Array[Dictionary] = [
		{name = "A1-新卡+Good→毕业Review",            method = test_a1_new_card_good},
		{name = "A2-新卡+Again→Learning 60秒",       method = test_a2_new_card_again},
		{name = "A3-Learning Good步进",              method = test_a3_learning_good_step},
		{name = "A4-Learning毕业→Review",            method = test_a4_learning_graduate},
		{name = "A5-Review Again 无relearning",      method = test_a5_review_again_no_relearn},
		{name = "A6-Review Again 有relearning",      method = test_a6_review_again_with_relearn},
		{name = "A7-Review Easy 增大间隔",           method = test_a7_review_easy},
		{name = "A8-日内同天复习 走short_term",       method = test_a8_same_day_review},
		{name = "A9-stability=0边界",               method = test_a9_zero_stability},
		{name = "A10-Fuzzing 间隔随机化",            method = test_a10_fuzzing},
	]

	for case in cases:
		var name: String = case["name"]
		var method: Callable = case["method"]
		var result := method.call()
		if result.get("pass", false):
			passed += 1
			print("  ✅ %s" % name)
		else:
			failed += 1
			var msg: String = result.get("message", "未知错误")
			errors.append("%s: %s" % [name, msg])
			print("  ❌ %s → %s" % [name, msg])

	print("-".repeat(60))
	print("结果: %d 通过, %d 失败" % [passed, failed])

	if failed > 0:
		print("失败详情:")
		for err in errors:
			print("  - %s" % err)

	return {passed = passed, failed = failed, errors = errors}


# ── A1: 新卡 + Good → 毕业到 Review ──
func test_a1_new_card_good() -> Dictionary:
	var s := FsrsScheduler.new()
	var card := CardEntity.new()
	card.queue = CardEntity.QUEUE_NEW
	card.stability = 0.0
	card.difficulty = 0.0
	card.step = -1

	var state := s.calculate_next_state(card, Scheduler.Rating.GOOD, _NOW)

	if state["queue"] != CardEntity.QUEUE_REVIEW:
		return err("queue 应为 REVIEW，实际 %d" % state["queue"])
	if not _approx(state["stability"], 2.3065, 0.01):
		return err("stability 应为 ≈2.3065，实际 %.4f" % state["stability"])
	if not _approx(state["difficulty"], 4.93, 0.1):
		return err("difficulty 应为 ≈4.93，实际 %.4f" % state["difficulty"])
	if state["interval_days"] < 1:
		return err("interval_days 应 ≥1，实际 %d" % state["interval_days"])
	if state["step"] != -1:
		return err("step 应为 -1，实际 %d" % state["step"])

	return ok()


# ── A2: 新卡 + Again → Learning step=0, 60秒后 ──
func test_a2_new_card_again() -> Dictionary:
	var s := FsrsScheduler.new()
	var card := CardEntity.new()
	card.queue = CardEntity.QUEUE_NEW

	var state := s.calculate_next_state(card, Scheduler.Rating.AGAIN, _NOW)

	if state["queue"] != CardEntity.QUEUE_LEARNING:
		return err("queue 应为 LEARNING，实际 %d" % state["queue"])
	if state["step"] != 0:
		return err("step 应为 0，实际 %d" % state["step"])
	if state["due"] != _NOW + 60:
		return err("due 应为 %d，实际 %d" % [_NOW + 60, state["due"]])

	return ok()


# ── A3: Learning step=0 + Good → step=1, 600秒后 ──
func test_a3_learning_good_step() -> Dictionary:
	var s := FsrsScheduler.new()
	var card := CardEntity.new()
	card.queue = CardEntity.QUEUE_LEARNING
	card.step = 0
	card.stability = 0.212
	card.difficulty = 5.0

	var state := s.calculate_next_state(card, Scheduler.Rating.GOOD, _NOW)

	if state["queue"] != CardEntity.QUEUE_LEARNING:
		return err("queue 应为 LEARNING，实际 %d" % state["queue"])
	if state["step"] != 1:
		return err("step 应为 1，实际 %d" % state["step"])
	if state["due"] != _NOW + 600:
		return err("due 应为 %d，实际 %d" % [_NOW + 600, state["due"]])

	return ok()


# ── A4: Learning 最后一步 + Good → 毕业到 Review ──
func test_a4_learning_graduate() -> Dictionary:
	var s := FsrsScheduler.new()
	var card := CardEntity.new()
	card.queue = CardEntity.QUEUE_LEARNING
	card.step = 1  # learning_steps=[60,600]，索引1是最后一步
	card.stability = 2.3065
	card.difficulty = 5.0

	var state := s.calculate_next_state(card, Scheduler.Rating.GOOD, _NOW)

	if state["queue"] != CardEntity.QUEUE_REVIEW:
		return err("queue 应为 REVIEW，实际 %d" % state["queue"])
	if state["step"] != -1:
		return err("step 应为 -1，实际 %d" % state["step"])
	if state["interval_days"] < 1:
		return err("interval_days 应 ≥1，实际 %d" % state["interval_days"])

	return ok()


# ── A5: Review + Again（无 relearning_steps）→ 留在 Review ──
func test_a5_review_again_no_relearn() -> Dictionary:
	var s := FsrsScheduler.new()
	s.relearning_steps = []
	var card := CardEntity.new()
	card.queue = CardEntity.QUEUE_REVIEW
	card.step = -1
	card.stability = 10.0
	card.difficulty = 3.0
	card.last_review_time = _NOW - 86400

	var state := s.calculate_next_state(card, Scheduler.Rating.AGAIN, _NOW)

	if state["queue"] != CardEntity.QUEUE_REVIEW:
		return err("无 relearning 时 queue 应为 REVIEW，实际 %d" % state["queue"])
	if state["stability"] >= 10.0:
		return err("Again 应降低 stability，原值 10.0 → 实际 %.4f" % state["stability"])

	return ok()


# ── A6: Review + Again（有 relearning）→ Relearning step=0 ──
func test_a6_review_again_with_relearn() -> Dictionary:
	var s := FsrsScheduler.new()
	var card := CardEntity.new()
	card.queue = CardEntity.QUEUE_REVIEW
	card.step = -1
	card.stability = 10.0
	card.difficulty = 3.0
	card.last_review_time = _NOW - 86400

	var state := s.calculate_next_state(card, Scheduler.Rating.AGAIN, _NOW)

	if state["queue"] != CardEntity.QUEUE_LEARNING:
		return err("queue 应为 LEARNING（Relearning），实际 %d" % state["queue"])
	if state["step"] != 0:
		return err("step 应为 0，实际 %d" % state["step"])
	if state["due"] != _NOW + 600:
		return err("due 应为 %d，实际 %d" % [_NOW + 600, state["due"]])

	return ok()


# ── A7: Review + Easy → stability 增大，difficulty 降低 ──
func test_a7_review_easy() -> Dictionary:
	var s := FsrsScheduler.new()
	var card := CardEntity.new()
	card.queue = CardEntity.QUEUE_REVIEW
	card.step = -1
	card.stability = 5.0
	card.difficulty = 3.0
	card.last_review_time = _NOW - 86400 * 10

	var state := s.calculate_next_state(card, Scheduler.Rating.EASY, _NOW)

	if state["queue"] != CardEntity.QUEUE_REVIEW:
		return err("queue 应为 REVIEW，实际 %d" % state["queue"])
	if state["stability"] <= 5.0:
		return err("Easy 应增大 stability，原值 5.0 → 实际 %.4f" % state["stability"])
	if state["difficulty"] >= 3.0:
		return err("Easy 应降低 difficulty，原值 3.0 → 实际 %.4f" % state["difficulty"])

	return ok()


# ── A8: 同一天内复习 → short_term_stability 路径 ──
func test_a8_same_day_review() -> Dictionary:
	var s := FsrsScheduler.new()
	var card := CardEntity.new()
	card.queue = CardEntity.QUEUE_REVIEW
	card.step = -1
	card.stability = 10.0
	card.difficulty = 3.0
	card.last_review_time = _NOW - 3600  # 1小时前

	var state := s.calculate_next_state(card, Scheduler.Rating.GOOD, _NOW)

	if state["queue"] != CardEntity.QUEUE_REVIEW:
		return err("queue 应为 REVIEW，实际 %d" % state["queue"])
	if not _approx(state["stability"], 10.0, 0.1):
		return err("同日复习 stability 应 ≈10.0，实际 %.4f" % state["stability"])

	return ok()


# ── A9: stability=0 边界，不应崩溃 ──
func test_a9_zero_stability() -> Dictionary:
	var s := FsrsScheduler.new()
	var card := CardEntity.new()
	card.queue = CardEntity.QUEUE_REVIEW
	card.step = -1
	card.stability = 0.0
	card.difficulty = 3.0
	card.last_review_time = _NOW - 86400

	var state := s.calculate_next_state(card, Scheduler.Rating.GOOD, _NOW)

	if state["stability"] <= 0.0:
		return err("stability=0 应被替换为初始值，实际 %.4f" % state["stability"])

	return ok()


# ── A10: Fuzzing 在 interval≥3 时生效，不越界 ──
func test_a10_fuzzing() -> Dictionary:
	var s := FsrsScheduler.new()
	s.enable_fuzzing = true
	var card := CardEntity.new()
	card.queue = CardEntity.QUEUE_REVIEW
	card.step = -1
	card.stability = 50.0
	card.difficulty = 3.0
	card.last_review_time = _NOW - 86400 * 50

	for i in range(20):
		var state := s.calculate_next_state(card, Scheduler.Rating.GOOD, _NOW)
		var interval: int = state["interval_days"]
		if interval < 1 or interval > s.maximum_interval:
			return err("fuzzing 越界: interval=%d, 允许[1, %d]" % [interval, s.maximum_interval])

	return ok()


# ── 工具 ──

func ok() -> Dictionary:
	return {"pass": true, "message": ""}


func err(msg: String) -> Dictionary:
	return {"pass": false, "message": msg}


func _approx(actual: float, expected: float, tolerance: float) -> bool:
	return abs(actual - expected) <= tolerance

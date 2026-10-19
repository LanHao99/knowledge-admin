extends GutTest
## 验证会话时钟、日期验证与界面草稿不直接修改真实时钟。

const CLOCK_SCRIPT: GDScript = preload("res://src/app_clock.gd")
const TIME_SCENE: PackedScene = preload("res://content/scenes/desktop/time_settings.tscn")


class FakeClock:
	extends "res://src/app_clock.gd"
	var system_seconds: int = 1709294400

	## 返回可控的真实时间，避免计时测试依赖等待。## 输入: 无。
	## 输出: int - 测试时间戳。
	func _system_timestamp() -> int:
		return system_seconds


## 清除上一个用例留下的全局时钟偏移。## 输入: 无。
## 输出: 无。
func before_each() -> void:
	AppClock.reset_to_system()


## 恢复真实时间并等待已关闭节点释放。## 输入: 无。
## 输出: 无。
func after_each() -> void:
	AppClock.reset_to_system()
	await get_tree().process_frame


## 会话偏移随真实时间前进，恢复后立即与真实时钟一致。## 输入: 无。
## 输出: 无。
func test_offset_ticks_and_reset() -> void:
	var clock: FakeClock = add_child_autofree(FakeClock.new()) as FakeClock
	var target: int = clock.system_seconds + 86400
	assert_true(clock.set_datetime(clock.local_datetime(target)).success)
	assert_eq(clock.now_unix(), target)
	assert_true(clock.is_adjusted())
	clock.system_seconds += 19
	assert_eq(clock.now_unix(), target + 19)
	clock.reset_to_system()
	assert_eq(clock.now_unix(), clock.system_seconds)
	assert_false(clock.is_adjusted())


## 新时钟实例没有继承另一实例的内存偏移。## 输入: 无。
## 输出: 无。
func test_fresh_instance_has_no_persisted_offset() -> void:
	var first: FakeClock = add_child_autofree(FakeClock.new()) as FakeClock
	first.set_datetime(first.local_datetime(first.now_unix() + 864000))
	var second: FakeClock = add_child_autofree(FakeClock.new()) as FakeClock
	assert_false(second.is_adjusted())
	assert_eq(second.now_unix(), second.system_seconds)


## 有效闰日可应用，非法日期和类型保持原时间且不发出调时信号。## 输入: 无。
## 输出: 无。
func test_calendar_validation_and_signal() -> void:
	var clock: FakeClock = add_child_autofree(FakeClock.new()) as FakeClock
	watch_signals(clock)
	assert_true(clock.set_datetime({"year": 2024, "month": 2, "day": 29, "hour": 12, "minute": 3}).success)
	var saved: int = clock.now_unix()
	for date: Dictionary in [
		{"year": 2023, "month": 2, "day": 29, "hour": 12, "minute": 3},
		{"year": 2024, "month": 4, "day": 31, "hour": 12, "minute": 3},
		{"year": 2024, "month": 1, "day": 1, "hour": 24, "minute": 3},
		{"year": "2024", "month": 1, "day": 1, "hour": 12, "minute": 3},
		{"year": 10000, "month": 1, "day": 1, "hour": 12, "minute": 3},
	]:
		assert_false(clock.set_datetime(date).success)
		assert_eq(clock.now_unix(), saved)
	assert_signal_emit_count(clock, "time_changed", 1)


## 本地时间与 Unix 秒数往返时只应用一次当前系统时区偏移。## 输入: 无。
## 输出: 无。
func test_local_timezone_round_trip() -> void:
	var clock: FakeClock = add_child_autofree(FakeClock.new()) as FakeClock
	var date: Dictionary = clock.local_datetime()
	assert_eq(clock.datetime_to_unix(date).data, clock.system_seconds)
	var bias: int = int(Time.get_time_zone_from_system().bias) * 60
	assert_eq(Time.get_unix_time_from_datetime_dict(date), clock.system_seconds + bias)


## 自然跨复习日发出一次通知，手动跨日只发调时通知。## 输入: 无。
## 输出: 无。
func test_day_rollover_and_manual_jump_notifications() -> void:
	var clock: FakeClock = FakeClock.new()
	clock.system_seconds = int(clock.system_seconds / 86400) * 86400 + 86399
	add_child_autofree(clock)
	watch_signals(clock)
	clock.system_seconds += 2
	clock.check_day()
	clock.check_day()
	assert_signal_emit_count(clock, "day_changed", 1)
	clock.set_datetime(clock.local_datetime(clock.now_unix() + 86400))
	clock.check_day()
	assert_signal_emit_count(clock, "day_changed", 1)
	assert_signal_emit_count(clock, "time_changed", 1)


## 快捷跳转只修改输入草稿，应用后才改变时钟。## 输入: 无。
## 输出: 无。
func test_dialog_draft_and_apply() -> void:
	var page: Control = add_child_autofree(TIME_SCENE.instantiate()) as Control
	var before: int = AppClock.now_unix()
	page.get_node("%NextDayButton").pressed.emit()
	assert_false(AppClock.is_adjusted())
	assert_between(AppClock.now_unix(), before, before + 2)
	page.get_node("%ApplyButton").pressed.emit()
	assert_true(AppClock.is_adjusted())
	assert_between(AppClock.now_unix() - before, 86340, 86402)
	page.get_node("%ResetTimeButton").pressed.emit()
	assert_false(AppClock.is_adjusted())


## 无效草稿不能生效，界面实时更新不覆盖未应用输入。## 输入: 无。
## 输出: 无。
func test_dialog_invalid_date_and_live_update_preserve_draft() -> void:
	var page: Control = add_child_autofree(TIME_SCENE.instantiate()) as Control
	(page.get_node("%YearValue") as SpinBox).value = 2023
	(page.get_node("%MonthValue") as SpinBox).value = 2
	(page.get_node("%DayValue") as SpinBox).value = 29
	page.get_node("%ApplyButton").pressed.emit()
	assert_false(AppClock.is_adjusted())
	assert_false((page.get_node("%TimeStatusLabel") as Label).text.is_empty())
	page._update_current_time()
	assert_eq(int((page.get_node("%DayValue") as SpinBox).value), 29)


## 关闭编辑页不会应用尚未确认的草稿或重置已应用的偏移。## 输入: 无。
## 输出: 无。
func test_reopening_editor_retains_clock_and_discards_draft() -> void:
	AppClock.set_datetime(AppClock.local_datetime(AppClock.now_unix() + 86400))
	var page: Control = TIME_SCENE.instantiate() as Control
	add_child(page)
	page.get_node("%NextDayButton").pressed.emit()
	page.queue_free()
	await get_tree().process_frame
	assert_true(AppClock.is_adjusted())
	var reopened: Control = add_child_autofree(TIME_SCENE.instantiate()) as Control
	var date: Dictionary = AppClock.local_datetime()
	assert_eq(int((reopened.get_node("%DayValue") as SpinBox).value), int(date.day))

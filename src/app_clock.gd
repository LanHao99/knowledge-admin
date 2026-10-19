extends Node
## 本次进程共用的软件时间，只在内存中保存相对系统时间的偏移。

signal time_changed()
signal day_changed(day_index: int)

const SECONDS_PER_DAY: int = 86400

var _offset_seconds: int = 0
var _last_day: int = -1


## 记录当前复习日并每秒检查自然跨日。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_day = int(now_unix() / SECONDS_PER_DAY)
	var timer: Timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(check_day)
	add_child(timer)
	timer.start()


## 获取继续按真实速度前进的软件 Unix 时间。## 输入: 无。
## 输出: int - 秒级 Unix 时间戳。
func now_unix() -> int:
	return _system_timestamp() + _offset_seconds


## 判断软件时间是否与系统时间存在偏移。## 输入: 无。
## 输出: bool - 偏移非零时返回 true。
func is_adjusted() -> bool:
	return _offset_seconds != 0


## 将时间戳转换为系统当前时区的日期时间。## 输入: timestamp (int) - Unix 秒数，负数表示软件当前时间。
## 输出: Dictionary - 包含 year、month、day、hour、minute、second 的日期时间。
func local_datetime(timestamp: int = -1) -> Dictionary:
	var value: int = now_unix() if timestamp < 0 else timestamp
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return Time.get_datetime_dict_from_unix_time(value + bias)


## 格式化系统当前时区的软件日期时间。## 输入: 无。
## 输出: String - 年月日与时分秒。
func display_datetime() -> String:
	var date: Dictionary = local_datetime()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [date.year, date.month, date.day, date.hour, date.minute, date.second]


## 验证本地日期时间并转换为 Unix 时间，不改变软件时间。## 输入: date (Dictionary) - 年月日时分，秒可省略并默认为零。
## 输出: Dictionary - 成功时 data 为 Unix 秒数；失败时 error 为说明。
func datetime_to_unix(date: Dictionary) -> Dictionary:
	var values: Dictionary = {}
	for key: String in ["year", "month", "day", "hour", "minute", "second"]:
		var value: Variant = date.get(key, 0 if key == "second" else -1)
		if typeof(value) != TYPE_INT:
			return {"success": false, "error": "日期和时间必须为整数。"}
		values[key] = value
	if values.year < 1970 or values.year > 9999 or values.month < 1 or values.month > 12 or values.day < 1 or values.day > 31:
		return {"success": false, "error": "请输入有效日期，年份范围为 1970–9999。"}
	if values.hour < 0 or values.hour > 23 or values.minute < 0 or values.minute > 59 or values.second < 0 or values.second > 59:
		return {"success": false, "error": "请输入有效的时、分、秒。"}
	var month_days: Array[int] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if int(values.year) % 400 == 0 or (int(values.year) % 4 == 0 and int(values.year) % 100 != 0):
		month_days[1] = 29
	if int(values.day) > month_days[int(values.month) - 1]:
		return {"success": false, "error": "该日期不存在，请检查月份、天数和闰年。"}
	var local_stamp: int = Time.get_unix_time_from_datetime_dict(values)
	var round_trip: Dictionary = Time.get_datetime_dict_from_unix_time(local_stamp)
	for key: String in values:
		if round_trip.get(key) != values[key]:
			return {"success": false, "error": "该日期不存在，请检查月份、天数和闰年。"}
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var timestamp: int = local_stamp - bias
	if timestamp < 0:
		return {"success": false, "error": "日期不能早于 Unix 时间起点。"}
	return {"success": true, "data": timestamp}


## 应用本地日期时间，并通知使用软件时间的界面。## 输入: date (Dictionary) - 经整数表示的年月日时分秒。
## 输出: Dictionary - 成功时 data 为应用的 Unix 秒数，失败时保持原时间。
func set_datetime(date: Dictionary) -> Dictionary:
	var result: Dictionary = datetime_to_unix(date)
	if not result.get("success", false):
		return result
	_offset_seconds = int(result.data) - _system_timestamp()
	_last_day = int(now_unix() / SECONDS_PER_DAY)
	time_changed.emit()
	return result


## 清除会话内偏移并立即恢复真实时间。## 输入: 无。
## 输出: 无。
func reset_to_system() -> void:
	_offset_seconds = 0
	_last_day = int(now_unix() / SECONDS_PER_DAY)
	time_changed.emit()


## 检查现有 Unix 天索引的自然变化，手动调时使用独立信号。## 输入: 无。
## 输出: 无。
func check_day() -> void:
	var current_day: int = int(now_unix() / SECONDS_PER_DAY)
	if current_day != _last_day:
		_last_day = current_day
		day_changed.emit(current_day)


## 读取操作系统提供的真实 Unix 时间，允许测试替身覆盖。## 输入: 无。
## 输出: int - 系统秒级时间戳。
func _system_timestamp() -> int:
	return int(Time.get_unix_time_from_system())

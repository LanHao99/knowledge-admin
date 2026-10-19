extends Control
## 日期时间编辑草稿、预览和会话内应用，不保存时钟设置。

const WindowContext: GDScript = preload("res://src/ui/window_context.gd")

@onready var _fields: Dictionary[String, SpinBox] = {
	"year": %YearValue, "month": %MonthValue, "day": %DayValue,
	"hour": %HourValue, "minute": %MinuteValue,
}


## 初始化日期草稿、快捷跳转和实时软件时间显示。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	for key: String in _fields:
		_fields[key].value_changed.connect(_update_preview)
	%PreviousDayButton.pressed.connect(_shift_draft.bind(-86400))
	%NextDayButton.pressed.connect(_shift_draft.bind(86400))
	%PreviousHourButton.pressed.connect(_shift_draft.bind(-3600))
	%NextHourButton.pressed.connect(_shift_draft.bind(3600))
	%ApplyButton.pressed.connect(_apply_draft)
	%ResetTimeButton.pressed.connect(_reset_time)
	%CloseButton.pressed.connect(_close_window)
	AppClock.time_changed.connect(_update_current_time)
	var timer: Timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_update_current_time)
	add_child(timer)
	timer.start()
	_set_draft(AppClock.local_datetime())
	_update_current_time()


## 刷新当前软件时间，不覆盖正在编辑的草稿。## 输入: 无。
## 输出: 无。
func _update_current_time() -> void:
	%CurrentTimeValue.text = AppClock.display_datetime()
	%TimeModeValue.text = "已调整 · 仅本次运行" if AppClock.is_adjusted() else "正在使用真实时间"


## 将草稿控件转换为整数日期时间，分钟输入的秒数设为零。## 输入: 无。
## 输出: Dictionary - 年月日时分秒。
func _read_draft() -> Dictionary:
	var date: Dictionary = {"second": 0}
	for key: String in _fields:
		date[key] = int(_fields[key].value)
	return date


## 将日期时间放入输入控件并刷新预览。## 输入: date (Dictionary) - 本地日期时间。
## 输出: 无。
func _set_draft(date: Dictionary) -> void:
	for key: String in _fields:
		_fields[key].set_value_no_signal(int(date[key]))
	_update_preview()


## 展示草稿或日期错误，输入变化不应用到软件时钟。## 输入: _value (float) - 输入框发出的数值，可省略。
## 输出: 无。
func _update_preview(_value: float = 0.0) -> void:
	var result: Dictionary = AppClock.datetime_to_unix(_read_draft())
	if not result.get("success", false):
		%PreviewValue.text = str(result.error)
		return
	var date: Dictionary = _read_draft()
	%PreviewValue.text = "将调整为 %04d-%02d-%02d %02d:%02d:00" % [date.year, date.month, date.day, date.hour, date.minute]


## 在当前草稿上前后移动，不改动实际时钟或复习数据。## 输入: seconds (int) - 前进或回退的秒数。
## 输出: 无。
func _shift_draft(seconds: int) -> void:
	var result: Dictionary = AppClock.datetime_to_unix(_read_draft())
	if not result.get("success", false):
		%TimeStatusLabel.text = str(result.error)
		return
	var timestamp: int = int(result.data) + seconds
	var date: Dictionary = AppClock.local_datetime(maxi(timestamp, 0))
	if timestamp < 0 or int(date.year) > 9999:
		%TimeStatusLabel.text = "跳转超出支持的日期范围。"
		return
	_set_draft(date)
	%TimeStatusLabel.text = "草稿已调整，点击应用后生效。"


## 应用有效草稿，保留正在进行的闪卡学习。## 输入: 无。
## 输出: 无。
func _apply_draft() -> void:
	if WindowManager._story_locked:
		return
	var result: Dictionary = AppClock.set_datetime(_read_draft())
	%TimeStatusLabel.text = "时间已应用，正在进行的学习会继续。" if result.get("success", false) else str(result.error)


## 立即恢复真实时间，并以当前日期重新建立草稿。## 输入: 无。
## 输出: 无。
func _reset_time() -> void:
	if WindowManager._story_locked:
		return
	AppClock.reset_to_system()
	_set_draft(AppClock.local_datetime())
	%TimeStatusLabel.text = "已恢复真实时间，复习结果已保留。"


## 关闭所属窗口，丢弃未应用草稿。## 输入: 无。
## 输出: 无。
func _close_window() -> void:
	if WindowContext.find_host(self) != null:
		App.close_app("time_settings")
	elif get_parent() is Window and get_parent() != get_tree().root:
		get_parent().queue_free()
	else:
		queue_free()

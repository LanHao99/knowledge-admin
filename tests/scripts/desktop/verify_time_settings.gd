extends Node
## 隔离工程中验证日期时间的真实输入、渲染、学习连续性和跨进程复习存档。

const WindowContext: GDScript = preload("res://src/ui/window_context.gd")

var _checks: int = 0
var _failures: Array[String] = []
var _output: String = "user://time_settings_review"


## 等待 Autoload 完成初始化后启动验收。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	_run.call_deferred()


## 执行桌面入口、字号矩阵及独立窗口验收，或运行跨进程存档阶段。## 输入: 无。
## 输出: 无。
func _run() -> void:
	if ProjectSettings.get_setting("application/config/name") != "KnowledgeAdminDesktopVerification":
		push_error("日期时间验收必须使用独立测试副本")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	_check(not AppClock.is_adjusted(), "每次进程启动使用真实时间")
	_check(absi(AppClock.now_unix() - int(Time.get_unix_time_from_system())) <= 1, "启动软件时间等于真实时间")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--restart-phase="):
			_run_restart(argument.get_slice("=", 1))
			return
	UiSettings.settings_path = "user://time_review_ui.cfg"
	App.get_story_progress().trigger_threshold = 1000000
	App.get_story_progress().total_progress = 0
	var tutorial: TutorialProgress = TutorialProgress.new()
	for key: String in TutorialManager._tutorials:
		tutorial.mark_completed(key)
	TutorialManager._progress = tutorial
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	UiSettings.set_font_scale(1.0)
	var desktop: Control = load("res://content/scenes/desktop/desktop.tscn").instantiate() as Control
	add_child(desktop)
	await _frames()
	var clock_button: Button = desktop.get_node("Taskbar/TaskbarHBox/RightArea/ClockButton") as Button
	clock_button.grab_focus()
	_key(KEY_ENTER)
	await _frames()
	var window: ManagedWindow = WindowManager.get_app_window("time_settings")
	_check(window != null, "右下角时钟可以通过 Enter 打开")
	if window == null:
		_finish("verification")
		return
	WindowManager.open_app("control_panel")
	await _frames()
	var settings: Control = WindowManager.get_app_window("control_panel").get_content()
	_show_general_tab(settings)
	await _frames()
	_click(settings.get_node("%TimeSettingsButton") as Button)
	await _frames()
	_check(WindowManager.get_app_window("time_settings") == window, "设置入口复用同一窗口")
	window._on_minimize_pressed()
	clock_button.pressed.emit()
	await _frames()
	_check(not window.is_minimized(), "任务栏时钟恢复已最小化的日期时间窗口")
	var page: Control = window.get_content()
	var actual: int = AppClock.now_unix()
	_click(page.get_node("%NextDayButton") as Button)
	_check(not AppClock.is_adjusted(), "快捷跳转只修改草稿")
	_click(page.get_node("%ApplyButton") as Button)
	await _frames()
	_check(AppClock.now_unix() - actual >= 86340, "应用日期草稿后时间前进一天")
	_check(clock_button.text.contains("*"), "右下角显示已调整标记")
	_check((settings.get_node("%SoftwareTimeValue") as Label).text.contains("已调整"), "设置同步软件时间状态")
	var applied: int = AppClock.now_unix()
	_click(page.get_node("%NextDayButton") as Button)
	WindowManager.close_app("time_settings")
	await _frames()
	clock_button.pressed.emit()
	await _frames()
	window = WindowManager.get_app_window("time_settings")
	page = window.get_content()
	_check(AppClock.is_adjusted() and absi(AppClock.now_unix() - applied) < 5, "重开窗口保留偏移并丢弃未应用草稿")
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_tree().root.size = resolution
		get_tree().root.content_scale_size = resolution
		for scale_value: float in [0.8, 1.0, 1.5]:
			UiSettings.set_font_scale(scale_value)
			window.size = Vector2(740, 620)
			window.position = Vector2(50, 24)
			window.fit_work_area()
			await _frames()
			_check_layout(window, page)
			await _capture("time_%dx%d_%d" % [resolution.x, resolution.y, roundi(scale_value * 100)])
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	UiSettings.set_font_scale(1.5)
	window.size = Vector2(480, 400)
	window.fit_work_area()
	await _frames()
	_check_layout(window, page)
	await _capture("time_minimum_480x400_150")
	_click(page.get_node("%ResetTimeButton") as Button)
	_check(not AppClock.is_adjusted(), "恢复按钮立即恢复真实时间")
	WindowManager.close_app("time_settings")
	await _frames()
	WindowManager._story_locked = true
	clock_button.pressed.emit()
	_check(WindowManager.get_app_window("time_settings") == null, "剧情模态锁阻止打开日期时间窗口")
	WindowManager._story_locked = false
	UiSettings.set_font_scale(1.0)
	await _verify_study()
	WindowManager.close_app("control_panel")
	WindowManager.close_app("time_settings")
	var knowledge: ManagedWindow = WindowManager.get_app_window("knowledge_admin")
	if knowledge != null:
		var study: Control = knowledge.get_content()
		study.desktop_end_session()
		WindowManager.close_app("knowledge_admin")
	desktop.queue_free()
	await _frames()
	var standalone: Control = load("res://content/scenes/ui/settings.tscn").instantiate() as Control
	add_child(standalone)
	await _frames()
	standalone._open_time_settings()
	standalone._open_time_settings()
	await _frames()
	var popup: Window = get_tree().root.get_node_or_null("TimeSettingsStandalone") as Window
	_check(popup != null, "独立运行设置页面可打开日期时间窗口")
	if popup != null:
		_check(popup.get_child_count() == 1, "独立设置入口同样复用单实例")
		var popup_page: Control = popup.get_child(0) as Control
		popup_page.get_node("%NextHourButton").pressed.emit()
		popup_page.get_node("%ApplyButton").pressed.emit()
		_check(AppClock.is_adjusted(), "独立窗口共用软件时钟")
		popup_page.get_node("%CloseButton").pressed.emit()
		await _frames()
		_check(not is_instance_valid(popup), "独立日期时间窗口可关闭")
	AppClock.reset_to_system()
	_finish("verification")


## 使用真实业务场景确认调时不会重置卡面、答题进度或计时。## 输入: 无。
## 输出: 无。
func _verify_study() -> void:
	var types: NoteTypeManager = NoteTypeManager.new()
	add_child(types)
	types.setup("user://knowledge_admin.db")
	var decks: DeckManager = DeckManager.new()
	add_child(decks)
	decks.setup("user://knowledge_admin.db")
	var notes: NoteManager = NoteManager.new()
	add_child(notes)
	notes.setup("user://knowledge_admin.db")
	var deck_id: int = int(decks.create_deck("日期时间验收_%d" % Time.get_ticks_usec()).data.id)
	for number: int in range(2):
		notes.create_note("__default__", {"front": "时间调整问题 %d" % number, "back": "这张卡片的答案应在调整时间后继续显示。"}, deck_id)
	WindowManager.open_app("knowledge_admin")
	await _frames()
	App.goto_scene("res://content/scenes/ui/study.tscn")
	await _frames()
	var study: Control = WindowManager.get_app_window("knowledge_admin").get_content()
	study._on_deck_selected(deck_id)
	study._study_manager.show_answer()
	study._study_manager.answer(CardEntity.RATING_EASY)
	study._study_manager.show_answer()
	await _frames()
	var card_id: int = study._card_ui._current_card.id
	var content: String = study._card_ui._content_label.text
	var before: int = int(study._study_manager.get_session_progress().elapsed_ms)
	WindowManager.open_app("time_settings")
	await _frames()
	var time_window: ManagedWindow = WindowManager.get_app_window("time_settings")
	time_window.size = Vector2(740, 620)
	time_window.position = Vector2(36, 16)
	time_window.fit_work_area()
	await _frames()
	var page: Control = time_window.get_content()
	var before_clock: int = AppClock.now_unix()
	_click(page.get_node("%NextDayButton") as Button)
	_click(page.get_node("%ApplyButton") as Button)
	await _frames()
	_check(AppClock.now_unix() - before_clock >= 86340, "学习时通过可见控件实际快进一天")
	_check(study._card_ui._current_card.id == card_id, "学习中调时保留当前卡片")
	_check(study._card_ui._state == CardUI.UIState.BACK and study._card_ui._content_label.text == content, "学习中调时保留背面及正文")
	_check(int(study._study_manager.get_session_progress().done) == 1, "学习中调时保留已完成数量")
	_check(int(study._study_manager.get_session_progress().elapsed_ms) - before < 3000, "快进一天没有增加一天学习耗时")
	await _capture("study_continues_after_time_change")
	types.queue_free()
	decks.queue_free()
	notes.queue_free()


## 检查输入框不横向裁切、动作按钮位于窗体内，窄窗使用纵向滚动。## 输入: window (ManagedWindow) - 窗体；page (Control) - 内容。
## 输出: 无。
func _check_layout(window: ManagedWindow, page: Control) -> void:
	var scroll: ScrollContainer = page.get_node("Margin/Layout/Scroll") as ScrollContainer
	var bounds: Rect2 = scroll.get_global_rect()
	for name_value: String in ["YearValue", "MonthValue", "DayValue", "HourValue", "MinuteValue"]:
		var field: SpinBox = page.get_node("%" + name_value) as SpinBox
		var rect: Rect2 = field.get_global_rect()
		_check(rect.position.x >= bounds.position.x - 1 and rect.end.x <= bounds.end.x + 1, "输入框横向完整：%s" % name_value)
		var line: LineEdit = field.get_line_edit()
		var text_width: float = line.get_theme_font("font").get_string_size(line.text, HORIZONTAL_ALIGNMENT_LEFT, -1, line.get_theme_font_size("font_size")).x
		_check(line.size.x >= text_width + 8, "输入值可完整显示：%s" % name_value)
	for name_value: String in ["ApplyButton", "ResetTimeButton", "CloseButton"]:
		var button: Button = page.get_node("%" + name_value) as Button
		_check(window.get_global_rect().encloses(button.get_global_rect()), "动作按钮位于窗体内：%s" % name_value)
	_check(scroll.get_h_scroll_bar().max_value <= scroll.size.x + 1, "不需要横向滚动")


## 选择控制面板的通用标签页。## 输入: settings (Control) - 设置页面。
## 输出: 无。
func _show_general_tab(settings: Control) -> void:
	var tabs: TabContainer = settings.find_child("SettingsTabs", true, false) as TabContainer
	for index: int in range(tabs.get_tab_count()):
		if tabs.get_tab_title(index) == "通用":
			tabs.current_tab = index


## 通过视口发送真实鼠标点击。## 输入: button (Button) - 可见按钮。
## 输出: 无。
func _click(button: Button) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_tree().root.push_input(event, true)
	event = event.duplicate() as InputEventMouseButton
	event.pressed = false
	get_tree().root.push_input(event, true)


## 发送完整的键盘按下与松开。## 输入: keycode (Key) - 目标按键。
## 输出: 无。
func _key(keycode: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	get_tree().root.push_input(event, true)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	get_tree().root.push_input(event, true)


## 在两个独立进程中分别保存未来复习、验证时钟重置及数据库保留。## 输入: phase (String) - write 或 read。
## 输出: 无。
func _run_restart(phase: String) -> void:
	var cards: CardManager = CardManager.new()
	add_child(cards)
	_check(cards.setup("user://time_restart.db"), "跨进程数据库可打开")
	var probe_path: String = _output.path_join("restart_probe.json")
	if phase == "write":
		var types: NoteTypeManager = NoteTypeManager.new()
		add_child(types)
		types.setup("user://time_restart.db")
		var decks: DeckManager = DeckManager.new()
		add_child(decks)
		decks.setup("user://time_restart.db")
		var notes: NoteManager = NoteManager.new()
		add_child(notes)
		notes.setup("user://time_restart.db")
		var deck_id: int = int(decks.create_deck("进程重启_%d" % Time.get_ticks_usec()).data.id)
		AppClock.set_datetime(AppClock.local_datetime(AppClock.now_unix() + 30 * 86400))
		var created: Dictionary = notes.create_note("__default__", {"front": "重启", "back": "复习结果保留"}, deck_id)
		var card_id: int = int(created.data.cards[0].id)
		var result: Dictionary = cards.answer_card(card_id, CardEntity.RATING_EASY, 250)
		_check(result.get("success", false), "未来时间评分成功保存")
		var saved: CardEntity = cards.get_card(card_id).data as CardEntity
		FileAccess.open(probe_path, FileAccess.WRITE).store_string(JSON.stringify(saved.to_dict(), "", true, true))
		_check(AppClock.is_adjusted(), "保存进程仍保留软件时间偏移")
	elif phase == "read":
		var probe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(probe_path))
		var saved: CardEntity = cards.get_card(int(probe.id)).data as CardEntity
		var expected: CardEntity = CardEntity.new()
		expected.from_dict(probe)
		_check(saved.to_dict() == expected.to_dict(), "新进程读取的复习状态与保存时完全一致")
		_check(saved.last_review_time > AppClock.now_unix(), "未来评分时间在真实时间恢复后仍保留")
		_check((cards.get_study_queue(saved.deck_id).data.review as Array).is_empty(), "真实时间下未来复习卡尚未到期")
		var today: int = int(AppClock.now_unix() / 86400) * 86400
		_check(int(cards.get_today_studied_count(today).data) == 0, "未来评分没有进入真实今天的统计")
	else:
		_check(false, "未知的跨进程验收阶段")
	_finish("restart_" + phase)


## 等待容器和真实渲染稳定。## 输入: 无。
## 输出: 无。
func _frames() -> void:
	for frame: int in range(6):
		await get_tree().process_frame


## 保存当前 GPU 画面。## 输入: filename (String) - 文件名，不含扩展名。
## 输出: 无。
func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(_output.path_join(filename + ".png"))


## 记录断言并继续收集失败项。## 输入: condition (bool) - 条件；description (String) - 说明。
## 输出: 无。
func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
		print("TIME_CHECK_FAILED: ", description)


## 写入验证结果并按失败情况退出进程。## 输入: name_value (String) - 报告名称。
## 输出: 无。
func _finish(name_value: String) -> void:
	var report: Dictionary = {"checks": _checks, "failures": _failures, "engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method()}
	FileAccess.open(_output.path_join(name_value + ".json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("TIME_VERIFICATION: ", JSON.stringify(report))
	get_tree().quit.call_deferred(0 if _failures.is_empty() else 1)

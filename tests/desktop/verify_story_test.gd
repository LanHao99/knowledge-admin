extends Node
## 在隔离工程里验收剧情测试台的播放、停止、退出和真实渲染。

var _failures: Array[String] = []
var _checks: int = 0
var _output: String = "user://story_test_review"


## 保留验收节点并开始。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	get_tree().current_scene = null
	_run.call_deferred()


## 执行播放、焦点恢复和多分辨率渲染检查。## 输入: 无。
## 输出: 无。
func _run() -> void:
	if ProjectSettings.get_setting("application/config/name") != "KnowledgeAdminDesktopVerification":
		push_error("剧情测试台验收必须使用隔离工程")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	UiSettings.settings_path = "user://story_test_ui.cfg"
	var tutorial := TutorialProgress.new()
	for key: String in TutorialManager._tutorials:
		tutorial.mark_completed(key)
	TutorialManager._progress = tutorial
	get_tree().change_scene_to_file("res://scenes/desktop/desktop.tscn")
	await _frames()
	_check(get_tree().current_scene.scene_file_path.ends_with("desktop.tscn"), "进入桌面")
	DebugSettings.set_debug_mode(true)
	var reset: Dictionary = App.reset_story_data()
	_check(reset.success, "重置剧情: " + str(reset.get("message", "")))
	await _verify_playback()
	await _verify_window()
	_finish()


## 连续开启、自然结束、选项处停止、延迟回调和测试退出。## 输入: 无。
## 输出: 无。
func _verify_playback() -> void:
	App.open_app("knowledge_admin")
	await _frames()
	App.goto_scene("res://scenes/ui/study.tscn")
	await _frames()
	var study_window: ManagedWindow = WindowManager.get_app_window("knowledge_admin")
	var study: Control = study_window.get_content()
	study._session.enter_learning(1)
	var card: Control = study.get_node("CardUI")
	card.visible = true
	App.open_app("knowledge_admin")
	_check(WindowManager.get_active_app_id() == "knowledge_admin", "学习窗口位于前台")
	_check(study._session.is_learning() and card.visible, "学习中的卡片可见")

	var threshold: int = App.get_story_progress().trigger_threshold
	var started: Dictionary = App.start_next_story()
	_check(started.success, "开启下一段: " + str(started.get("message", "")))
	await _frames()
	_check(WindowManager._story_locked and App._overlay != null and App._overlay._stop_button.visible, "测试播放显示停止测试")
	_check(not card.visible, "剧情打开时藏起学习卡片")
	_check(not App.start_next_story().success, "播放中不能再次开启")
	await _advance_until_choice()
	App.stop_story_test("选项等待时停止")
	await _until_unlocked()
	_check(not App.get_story_progress().is_chapter_dialogue_completed("chapter_1", "intro"), "选项处停止不记完成")
	_check(App.get_story_progress().trigger_threshold == threshold + 5, "开启下一段仍提高阈值")
	await _dismiss_dialogs()
	_check(not WindowManager._story_locked and WindowManager.get_active_app_id() == "knowledge_admin", "停止后焦点回到学习窗口")
	_check(card.visible and study._session.is_learning(), "停止后恢复学习卡片")

	started = App.start_next_story()
	_check(started.success, "再次开启以检查延迟回调")
	await _frames()
	var view: StoryDialogueOverlay = App._overlay
	_check(view != null, "延迟回调测试已经打开剧情")
	await _advance_until_auto(view)
	var scheduled: int = view.auto_advance_count
	App.stop_story_test("延迟回调停止")
	await _until_unlocked()
	await get_tree().create_timer(0.8).timeout
	_check(view.auto_advance_count == scheduled, "停止后不再安排新的延迟推进")
	await _dismiss_dialogs()
	_check(not App.get_story_progress().is_chapter_dialogue_completed("chapter_1", "intro"), "延迟回调停止不记完成")
	_check(not WindowManager._story_locked and not App._test_playback, "延迟停止后桌面解锁")

	var before_natural: int = App.get_story_progress().trigger_threshold
	started = App.start_next_story()
	_check(started.success, "自然结束前再次开启")
	await _finish_dialogue()
	await _frames()
	_check(App.get_story_progress().is_chapter_dialogue_completed("chapter_1", "intro"), "自然结束记完成")
	_check(App.get_story_progress().trigger_threshold == before_natural + 5, "自然结束后阈值保持本次增长")
	await _dismiss_dialogs()
	_check(WindowManager.get_active_app_id() == "knowledge_admin" and card.visible, "自然结束后恢复桌面焦点和学习界面")

	var before_second: int = App.get_story_progress().trigger_threshold
	started = App.start_next_story()
	var started_data: Dictionary = started.get("data", {})
	_check(started.success and str(started_data.get("key", "")) == "explain", "下一段进入讲解")
	await _frames()
	_check(not App.start_next_story().success, "连续点击不会启动第二段")
	await _finish_dialogue()
	await _frames()
	_check(App.get_story_progress().is_chapter_dialogue_completed("chapter_1", "explain"), "第二段自然结束")
	_check(App.get_story_progress().trigger_threshold == before_second + 5, "连续开启继续提高阈值")
	await _dismiss_dialogs()
	_check(card.visible and WindowManager.get_active_app_id() == "knowledge_admin", "第二段结束后学习界面仍在")

	var jumped: Dictionary = App.jump_to_story("chapter_1", "warning")
	_check(jumped.success, "跳转到警告: " + str(jumped.get("message", "")))
	_check(App.get_story_progress().bond == 0, "跳转不提高好感度")
	await _frames()
	await _choose_quit_branch()
	await _until_unlocked()
	_check(not App.get_story_progress().is_chapter_dialogue_completed("chapter_1", "warning"), "退出指令不记完成")
	_check(_has_stop_dialog("退出游戏"), "退出指令显示停止原因")
	_check(not WindowManager._story_locked, "退出指令停止后回到桌面")


## 检查单实例、默认尺寸、滚动、拖动和调试入口。## 输入: 无。
## 输出: 无。
func _verify_window() -> void:
	for node: Node in App.find_children("*", "AcceptDialog", true, false):
		if node is Window:
			(node as Window).hide()
		node.queue_free()
	await _frames()
	DebugSettings.set_debug_mode(true)
	await _frames()
	_check(_has_shortcut("story_test"), "调试模式显示桌面图标")
	App.open_app("story_test")
	await _frames()
	var bench: ManagedWindow = WindowManager.get_app_window("story_test")
	var instance_id: int = bench.get_instance_id()
	App.open_app("story_test")
	_check(WindowManager.get_app_window("story_test").get_instance_id() == instance_id, "测试台单实例")
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_tree().root.size = resolution
		get_tree().root.content_scale_size = resolution
		for font_scale: float in [1.0, 1.5]:
			UiSettings.set_font_scale(font_scale)
			await _frames()
			bench.size = Vector2(1100, 760)
			bench.fit_work_area()
			await _frames()
			var page: Control = bench.get_content()
			var scrolls: Array[Node] = page.find_children("*", "ScrollContainer", true, false)
			_check(scrolls.size() >= 3, "三个内容页都使用滚动容器")
			var work_area: Vector2 = bench.get_parent().size
			_check(bench.size.x <= work_area.x + 1.0 and bench.size.y <= work_area.y + 1.0, "窗口落在工作区内")
			if resolution == Vector2i(1920, 1080) and is_equal_approx(font_scale, 1.0):
				_check(bench.size.is_equal_approx(Vector2(1100, 760)), "默认窗口大小 1100×760")
			var overflows: bool = false
			for node: Node in scrolls:
				var scroll: ScrollContainer = node as ScrollContainer
				if scroll != null and scroll.get_v_scroll_bar().max_value > 1.0:
					overflows = true
			if resolution.y <= 720 or font_scale >= 1.5:
				_check(overflows, "小窗口或大字号时内容可滚动")
			await _capture("story_test_%dx%d_%d" % [resolution.x, resolution.y, roundi(font_scale * 100)])
	UiSettings.set_font_scale(1.0)
	get_tree().root.size = Vector2i(1920, 1080)
	get_tree().root.content_scale_size = Vector2i(1920, 1080)
	await _frames()
	bench.position = Vector2(80, 40)
	bench.size = Vector2(1100, 760)
	var before_drag: Vector2 = bench.position
	await _drag(bench.get_node("%TitleBar").get_global_rect().position + Vector2(80, 16), Vector2(48, 24))
	_check(bench.position.is_equal_approx(before_drag + Vector2(48, 24)), "测试台可以拖动")
	var before_resize: Vector2 = bench.size
	var handle: Control = bench.get_node("ResizeHandles").get_child(0)
	await _drag(handle.get_global_rect().get_center(), Vector2(-24, -16))
	_check(bench.size != before_resize, "测试台可以缩放")
	bench._on_minimize_pressed()
	_check(bench.is_minimized(), "测试台可以最小化")
	bench.restore()
	_check(not bench.is_minimized(), "测试台可以从任务栏恢复")
	DebugSettings.set_debug_mode(false)
	await _frames()
	_check(WindowManager.get_app_window("story_test") == null and not _has_shortcut("story_test"), "关闭调试模式后隐藏入口并关闭测试台")
	var taskbar: Node = get_tree().current_scene.get_node("%Taskbar")
	await _click(taskbar._start_button.get_global_rect().get_center())
	_check(is_instance_valid(taskbar._start_menu) and not _menu_has("剧情测试台"), "开始菜单在调试关闭时没有测试台")
	await _click(Vector2(900, 80))
	DebugSettings.set_debug_mode(true)
	await _frames()
	_check(_has_shortcut("story_test"), "重新开启调试模式后恢复图标")


## 推进到出现选项。## 输入: 无。
## 输出: 无。
func _advance_until_choice() -> void:
	for _step: int in range(30):
		var view: StoryDialogueOverlay = App._overlay
		if view == null or not is_instance_valid(view):
			return
		if view._is_animating:
			view._skip_typewriter()
		await _frames(2)
		if view._is_waiting_for_choice:
			return
		view._on_card_panel_clicked()
		await _frames(2)


## 推进到延迟自动播放被安排。## 输入: view。
## 输出: 无。
func _advance_until_auto(view: StoryDialogueOverlay) -> void:
	if view == null:
		return
	for _step: int in range(40):
		if not is_instance_valid(view) or view._closed:
			return
		var line_text := ""
		if view._current_line != null:
			line_text = str(view._current_line.text)
		if line_text.contains("{auto}"):
			if view._is_animating:
				view._skip_typewriter()
			await _frames(1)
			return
		if view._is_animating:
			view._skip_typewriter()
		await _frames(2)
		if view._is_waiting_for_choice:
			view._on_option_selected(0)
		else:
			view._on_card_panel_clicked()
		await _frames(2)


## 选择会请求退出游戏的分支并继续推进到停止。## 输入: 无。
## 输出: 无。
func _choose_quit_branch() -> void:
	var selected: bool = false
	for _step: int in range(40):
		if not WindowManager._story_locked:
			return
		var view: StoryDialogueOverlay = App._overlay
		if view == null or not is_instance_valid(view) or view._closed:
			return
		if view._is_animating:
			view._skip_typewriter()
		await _frames(2)
		if view._is_waiting_for_choice and not selected:
			view._on_option_selected(1)
			selected = true
		elif not view._is_waiting_for_choice:
			view._on_card_panel_clicked()
		await _frames(2)


## 把当前测试剧情播放到自然结束。## 输入: 无。
## 输出: 无。
func _finish_dialogue() -> void:
	for _wait_open: int in range(50):
		var current: StoryDialogueOverlay = App._overlay
		if current != null and is_instance_valid(current) and not current._closed and App._test_playback:
			break
		await _frames(1)
	var initial_key: String = App._active_dialogue_key
	for _step: int in range(80):
		var view: StoryDialogueOverlay = App._overlay
		if view == null or not is_instance_valid(view) or App._active_dialogue_key != initial_key or view._closed:
			await _until_unlocked()
			return
		if view._is_animating:
			view._skip_typewriter()
			await _frames(1)
		if not is_instance_valid(view) or view._closed:
			await _until_unlocked()
			return
		if view._current_line != null and str(view._current_line.text).contains("{auto}"):
			await get_tree().create_timer(0.7).timeout
		elif view._is_waiting_for_choice:
			view._on_option_selected(0)
		else:
			view._on_card_panel_clicked()
		for _wait: int in range(30):
			if not is_instance_valid(view) or view._closed or not view._resolving_line:
				break
			await _frames(1)
	await _until_unlocked()


## 关掉测试停止后留下的说明框，避免挡住后续焦点。## 输入: 无。
## 输出: 无。
func _dismiss_dialogs() -> void:
	for node: Node in App.find_children("*", "AcceptDialog", true, false):
		if node is Window:
			(node as Window).hide()
		node.queue_free()
	await _frames()


## 等待剧情锁解除。## 输入: 无。
## 输出: 无。
func _until_unlocked() -> void:
	for _step: int in range(40):
		if not WindowManager._story_locked and not App._test_playback:
			await _frames(2)
			return
		await _frames(2)


## 查找停止原因对话框。## 输入: fragment。
## 输出: bool。
func _has_stop_dialog(fragment: String) -> bool:
	for node: Node in App.find_children("*", "AcceptDialog", true, false):
		if node is AcceptDialog and str((node as AcceptDialog).dialog_text).contains(fragment):
			return true
	return false


## 桌面图标里是否有指定应用。## 输入: app_id。
## 输出: bool。
func _has_shortcut(app_id: String) -> bool:
	for child: Node in get_tree().current_scene.get_node("%DesktopIconGrid").get_children():
		if str(child.get_meta("app_id", "")) == app_id:
			return true
	return false


## 开始菜单文字里是否有测试台。## 输入: title。
## 输出: bool。
func _menu_has(title: String) -> bool:
	var menu: Node = get_tree().current_scene.get_node("%Taskbar")._start_menu
	if not is_instance_valid(menu):
		return false
	for child: Node in menu.get_node("%AppList").get_children():
		if child is Button and str((child as Button).text).contains(title):
			return true
	return false


## 等待布局。## 输入: count。
## 输出: 无。
func _frames(count: int = 8) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


## 注入鼠标点击。## 输入: point。
## 输出: 无。
func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	get_tree().root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_tree().root.push_input(event, true)
	event.pressed = false
	get_tree().root.push_input(event, true)
	await _frames()


## 注入拖动。## 输入: point、movement。
## 输出: 无。
func _drag(point: Vector2, movement: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_tree().root.push_input(event, true)
	var motion := InputEventMouseMotion.new()
	motion.position = point + movement
	motion.global_position = point + movement
	motion.relative = movement
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_tree().root.push_input(motion, true)
	event.position = point + movement
	event.pressed = false
	get_tree().root.push_input(event, true)
	await _frames()


## 保存当前画面。## 输入: filename。
## 输出: 无。
func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var picture: Image = get_tree().root.get_texture().get_image()
	_check(picture != null and not picture.is_empty(), "真实渲染：" + filename)
	if picture != null:
		picture.save_png(_output.path_join(filename + ".png"))


## 记录一项断言。## 输入: passed、message。
## 输出: 无。
func _check(passed: bool, message: String) -> void:
	_checks += 1
	if not passed:
		_failures.append(message)
		print("STORY_TEST_FAILED: ", message)


## 写出报告并退出。## 输入: 无。
## 输出: 无。
func _finish() -> void:
	var report: Dictionary = {"checks": _checks, "failures": _failures, "engine": Engine.get_version_info().string}
	var file := FileAccess.open(_output.path_join("verification.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("STORY_TEST_VERIFICATION: ", JSON.stringify(report))
	get_tree().quit.call_deferred(0 if _failures.is_empty() else 1)

extends Node
## 在隔离工程执行真实渲染、鼠标操作、数据导航和剧情验收。

var _failures: Array[String] = []
var _checks: int = 0
var _output: String = "user://desktop_review"

## 保留验收节点，使启动画面切换不会销毁测试。## 输入: 无。输出: 无。
func _ready() -> void:
	get_tree().current_scene = null
	_run.call_deferred()

## 执行交互及多分辨率验收并输出报告。## 输入: 无。输出: 无。
func _run() -> void:
	if ProjectSettings.get_setting("application/config/name") != "KnowledgeAdminDesktopVerification":
		push_error("桌面验收必须使用隔离工程")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	UiSettings.settings_path = "user://desktop_test_ui.cfg"
	if "--taskbar-icons-only" in OS.get_cmdline_user_args():
		await _run_taskbar_review()
		return
	App.get_story_progress().total_progress = 0
	App.get_story_progress().trigger_threshold = 100000
	var tutorial: TutorialProgress = TutorialProgress.new()
	for key: String in TutorialManager._tutorials:
		tutorial.mark_completed(key)
	TutorialManager._progress = tutorial
	get_tree().change_scene_to_file("res://scenes/desktop/boot_screen.tscn")
	await _frames()
	await _capture("boot")
	var key_event: InputEventKey = InputEventKey.new()
	key_event.keycode = KEY_SPACE
	key_event.pressed = true
	get_tree().root.push_input(key_event, true)
	var boot_deadline: int = Time.get_ticks_msec() + 3000
	while get_tree().get_first_node_in_group(&"boot_transition") != null and Time.get_ticks_msec() < boot_deadline:
		await get_tree().process_frame
	await _frames()
	_check(get_tree().get_first_node_in_group(&"boot_transition") == null, "启动溶解完成并释放封面")
	_check(get_tree().current_scene.scene_file_path.ends_with("desktop.tscn"), "按键跳过开机到桌面")
	_check(WindowManager._open_windows.is_empty(), "启动为空桌面")
	await _capture("desktop_empty")
	var taskbar: Node = get_tree().current_scene.get_node("%Taskbar")
	await _click(taskbar._start_button.get_global_rect().get_center())
	_check(is_instance_valid(taskbar._start_menu), "开始按钮打开菜单")
	await _capture("start_menu")
	await _click(Vector2(800, 100))
	_check(not is_instance_valid(taskbar._start_menu), "外部点击收起开始菜单")
	var desktop: Control = get_tree().current_scene
	var shortcut: Button = desktop.get_node("%DesktopIconGrid").get_child(0)
	var shortcuts: Array[Node] = desktop.get_node("%DesktopIconGrid").get_children()
	for entry: Button in shortcuts:
		_check(not entry.button_pressed, "初始图标未选中：" + str(entry.get_meta("app_id")))
	for entry: Button in shortcuts:
		await _click(entry.get_global_rect().get_center())
		for candidate: Button in shortcuts:
			_check(candidate.button_pressed == (candidate == entry), "单击只高亮当前图标：%s / %s" % [entry.get_meta("app_id"), candidate.get_meta("app_id")])
	await _capture("desktop_single_selection")
	await _click(shortcut.get_global_rect().get_center())
	await _click(shortcut.get_global_rect().get_center())
	_check(shortcut.button_pressed, "重复单击已选中的图标保持高亮")
	_check(WindowManager.get_app_window("knowledge_admin") == null, "单击图标只选中")
	await _click(shortcut.get_global_rect().get_center(), true)
	_check(WindowManager.get_app_window("knowledge_admin") != null, "双击图标启动应用")
	if "--desktop-selection-only" in OS.get_cmdline_user_args():
		_finish()
		return
	var flash: ManagedWindow = WindowManager.get_app_window("knowledge_admin")
	if flash == null:
		_finish()
		return
	var home: Control = flash.get_content()
	App.open_app("knowledge_admin")
	_check(WindowManager.get_app_window("knowledge_admin") == flash, "重复打开使用同一实例")
	await _frames()
	var before_drag: Vector2 = flash.position
	await _drag(flash.get_node("%TitleBar").get_global_rect().position + Vector2(60, 15), Vector2(70, 45))
	_check(flash.position.is_equal_approx(before_drag + Vector2(70, 45)), "真实鼠标拖动改变窗口位置")
	await _capture("flash_home")
	for handle: Control in flash.get_node("ResizeHandles").get_children():
		var before_resize: Vector2 = flash.size
		await _drag(handle.get_global_rect().get_center(), Vector2(-8, -8))
		_check(flash.size != before_resize, "真实鼠标缩放：" + handle.name)

	App.goto_scene("res://scenes/ui/deck_list.tscn")
	await _frames()
	_check(get_tree().current_scene == desktop and flash.get_content() != home, "导航保留桌面与宿主窗口")
	var deck_page: Control = flash.get_content()
	var created: Dictionary = deck_page._deck_manager.create_deck("桌面验收_%d" % Time.get_ticks_usec())
	_check(created.success, "牌组创建")
	var deck_id: int = created.data.id
	App.goto_scene("res://scenes/ui/note_list.tscn")
	await _frames()
	_check(flash._current_scene_path.ends_with("note_list.tscn"), "笔记页导航")
	App.open_app("ai_cards")
	await _frames()
	var ai: Control = WindowManager.get_app_window("ai_cards").get_content()
	ai._show_import_dialog([{"正面": "桌面验收正面", "背面": "桌面验收答案"}])
	await _frames()
	var import_dialog: ConfirmationDialog = ai.get_node("ImportDeckDialog")
	var deck_select: OptionButton = import_dialog.get_node("DeckSelect")
	for index: int in range(deck_select.item_count):
		if deck_select.get_item_id(index) == deck_id:
			deck_select.select(index)
	import_dialog.confirmed.emit()
	await _frames()
	_check(ai._note_manager.get_notes_by_deck(deck_id).data.size() > 0, "AI 生成结果走真实导入路径")
	WindowManager.close_app("ai_cards")
	App.goto_scene("res://scenes/ui/deck_list.tscn")
	await _frames()
	deck_page = flash.get_content()
	deck_page._editing_deck_id = deck_id
	deck_page._on_import_pressed()
	await _frames()
	var wizard: Node = null
	for child: Node in deck_page.get_children():
		if child is ImportMain:
			wizard = child
	_check(wizard != null, "JSON 导入向导保持在闪卡窗口中")
	if wizard != null:
		var source_file: FileAccess = FileAccess.open("user://desktop_import.json", FileAccess.WRITE)
		source_file.store_string(JSON.stringify([{"正面": "JSON 导入正面", "背面": "JSON 导入答案"}]))
		source_file.close()
		wizard._writing = true
		WindowManager.close_app("knowledge_admin")
		_check(WindowManager.get_app_window("knowledge_admin") == flash, "写入期间拒绝关闭闪卡")
		wizard._writing = false
		wizard._json_file_path = "user://desktop_import.json"
		wizard._selected_note_type_id = "__default__"
		wizard._on_mapping_confirmed({"正面": "正面", "背面": "背面"})
		_check(wizard._current_step == 3 and not wizard.is_importing(), "JSON 文件真实写入并结束事务")
		wizard.queue_free()
	App.goto_scene("res://scenes/ui/study.tscn")
	await _frames()
	var study: Control = flash.get_content()
	study._on_deck_selected(deck_id)
	await _frames()
	var card: CardUI = study.get_node("CardUI")
	_check(study.desktop_has_active_session(), "学习会话已启动")
	var content_id: int = card.get_instance_id()
	flash._on_minimize_pressed()
	flash.restore()
	_check(card.get_instance_id() == content_id and study.desktop_has_active_session(), "最小化恢复保留当前卡和会话")
	WindowManager.close_app("knowledge_admin")
	await _frames()
	_check(is_instance_valid(WindowManager._close_confirm) and WindowManager._close_confirm.visible, "学习中关闭需要确认")
	WindowManager._close_confirm.canceled.emit()
	await _frames()
	_check(WindowManager.get_app_window("knowledge_admin") == flash, "取消关闭保留学习")
	await _verify_story(study)
	for _answer: int in range(5):
		if not study.desktop_has_active_session():
			break
		card._render_back()
		card._on_good_pressed()
		await _frames()
	_check(not study.desktop_has_active_session(), "评分完成一张卡并正常结束学习")
	App.goto_scene("res://scenes/ui/main_menu.tscn")
	await _frames()
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_tree().root.size = resolution
		get_tree().root.content_scale_size = resolution
		for font_scale: float in [0.8, 1.0, 1.5]:
			UiSettings.set_font_scale(font_scale)
			await _frames()
			App.open_app("control_panel")
			App.open_app("my_computer")
			App.open_app("recycle_bin")
			await _frames()
			var prefix: String = "%dx%d_%d" % [resolution.x, resolution.y, roundi(font_scale * 100)]
			for app_id: String in ["knowledge_admin", "control_panel", "my_computer", "recycle_bin"]:
				var window: ManagedWindow = WindowManager.get_app_window(app_id)
				App.open_app(app_id)
				window._on_maximize_pressed()
				await _frames()
				_check(Rect2(Vector2.ZERO, desktop.get_node("%WindowContainer").size).grow(1).encloses(Rect2(window.position, window.size)), "最大化保留任务栏：" + app_id + prefix)
				if app_id == "knowledge_admin":
					var page: Control = window.get_content()
					var holder: Control = page.get_node("%CenterArea")
					_check(holder.global_position.x >= window.global_position.x, "首页没有向左裁切：" + prefix)
				if app_id == "control_panel":
					var page: Control = window.get_content()
					page.get_node("%PageScroll").scroll_vertical = 0
					_check(page.get_node("%SettingsCenter").global_position.x >= window.global_position.x, "设置没有向左裁切：" + prefix)
				await _capture(app_id + "_" + prefix)
				window._on_maximize_pressed()
			for app_id: String in ["control_panel", "my_computer", "recycle_bin"]:
				WindowManager.close_app(app_id)
			await _frames()
	UiSettings.set_font_scale(1.0)
	await _frames()
	flash.position = Vector2(180, 70)
	flash.size = Vector2(1260, 840)
	App.open_app("my_computer")
	var computer: ManagedWindow = WindowManager.get_app_window("my_computer")
	computer.position = Vector2(1130, 120)
	computer.size = Vector2(740, 580)
	App.open_app("ai_cards")
	var ai_window: ManagedWindow = WindowManager.get_app_window("ai_cards")
	ai_window.position = Vector2(760, 460)
	ai_window.size = Vector2(1060, 550)
	ai_window.fit_work_area()
	await _frames()
	await _capture("desktop_apps")
	_finish()

## 检查实际图标尺寸、提示名称、激活及最小化恢复，并保存预览。## 输入: 无。输出: 无。
func _run_taskbar_review() -> void:
	_output = "user://taskbar_icons_review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	var tutorial: TutorialProgress = TutorialProgress.new()
	for key: String in TutorialManager._tutorials:
		tutorial.mark_completed(key)
	TutorialManager._progress = tutorial
	get_tree().change_scene_to_file("res://scenes/desktop/desktop.tscn")
	await _frames()
	for app_info: Dictionary in WindowManager.get_visible_apps():
		App.open_app(app_info.app_id)
	App.open_app("unknown_program")
	await _frames()
	var taskbar: Node = get_tree().current_scene.get_node("%Taskbar")
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_tree().root.size = resolution
		get_tree().root.content_scale_size = resolution
		for font_scale: float in [0.8, 1.0, 1.5]:
			UiSettings.set_font_scale(font_scale)
			await _frames()
			for app_id: String in taskbar._app_buttons:
				var button: Button = taskbar._app_buttons[app_id]
				_check(is_equal_approx(button.size.x, button.size.y), "任务栏正方形：" + app_id)
				_check(button.text.is_empty() and button.get_node("Icon").texture != null, "只显示程序图标：" + app_id)
				_check(button.tooltip_text == WindowManager.REGISTRY[app_id].title and button.accessibility_name == button.tooltip_text, "名称提示与无障碍名称：" + app_id)
			await _capture("icons_%dx%d_%d" % [resolution.x, resolution.y, roundi(font_scale * 100)])
	UiSettings.set_font_scale(1.0)
	await _frames()
	var flash: ManagedWindow = WindowManager.get_app_window("knowledge_admin")
	var original_page: Control = flash.get_content()
	var flash_button: Button = taskbar._app_buttons["knowledge_admin"]
	await _click(flash_button.get_global_rect().get_center())
	_check(flash_button.button_pressed and WindowManager.get_active_app_id() == "knowledge_admin", "点击图标激活并高亮")
	await _click(flash_button.get_global_rect().get_center())
	_check(flash.is_minimized() and not flash_button.button_pressed, "再次点击图标最小化")
	await _click(flash_button.get_global_rect().get_center())
	_check(not flash.is_minimized() and flash.get_content() == original_page, "点击图标恢复原页面")
	for app_id: String in ["control_panel", "recycle_bin", "unknown_program"]:
		WindowManager.get_app_window(app_id)._on_minimize_pressed()
	flash.position = Vector2(180, 70)
	flash.size = Vector2(1260, 840)
	var computer: ManagedWindow = WindowManager.get_app_window("my_computer")
	computer.position = Vector2(1130, 120)
	computer.size = Vector2(740, 580)
	App.open_app("ai_cards")
	var ai: ManagedWindow = WindowManager.get_app_window("ai_cards")
	ai.position = Vector2(760, 460)
	ai.size = Vector2(1060, 550)
	ai.fit_work_area()
	await _frames()
	await _capture("taskbar_icons")
	_finish()

## 验证剧情突现、输入锁、选择、进程释放和教程分流。## 输入: source。输出: 无。
func _verify_story(source: Node) -> void:
	var resource: Resource = load("res://tests/desktop/story_fixture.dialogue")
	var popup: ConfirmationDialog = ConfirmationDialog.new()
	source.add_child(popup)
	popup.dialog_text = "验证弹窗恢复"
	popup.popup_centered()
	App.request_dialogue(load("res://game/tutorial/dialogue/main_menu.dialogue"), "desktop_help_fixture", false, source)
	App.request_dialogue(resource, "desktop_story_fixture", true)
	await _frames()
	var unknown: ManagedWindow = WindowManager.get_app_window("unknown_program")
	var previous_unknown: WeakRef = weakref(unknown)
	_check(unknown != null and WindowManager._story_locked, "剧情优先于排队教程并独立弹出")
	_check(not popup.visible, "剧情隐藏已有嵌入式弹窗")
	_check(not WindowManager.open_app("control_panel"), "剧情期间禁止激活其他软件")
	unknown._on_minimize_pressed()
	WindowManager.close_app("unknown_program")
	_check(not unknown.is_minimized() and unknown.visible, "剧情期间不能关闭或最小化")
	await _capture("unexpected_program")
	await _finish_dialogue()
	await _frames()
	_check(App.get_flag("desktop_choice_verified", false) == true, "剧情选项执行并保存世界标记")
	_check(not WindowManager._story_locked and previous_unknown.get_ref() == null, "剧情结束恢复桌面并释放未知程序")
	_check(WindowManager.get_app_window("unknown_program") == null, "剧情结束不保留后台未知实例")
	_check(WindowManager.get_app_window("help") != null, "排队教程显示为正常帮助窗口")
	await _finish_dialogue()
	await _frames()
	_check(popup.visible, "剧情与帮助结束恢复来源弹窗")
	popup.queue_free()
	App.request_dialogue(resource, "desktop_story_second", true)
	await _frames()
	var reconnected: ManagedWindow = WindowManager.get_app_window("unknown_program")
	_check(reconnected != null and previous_unknown.get_ref() == null and is_zero_approx(reconnected.damage_amount), "后续剧情创建无损新实例")
	await _finish_dialogue()
	await _frames()

## 通过真实逐句和选项处理完成对话，不调用结束方法。## 输入: 无。输出: 无。
func _finish_dialogue() -> void:
	var initial_key: String = App._active_dialogue_key
	for _step: int in range(40):
		var view: StoryDialogueOverlay = App._overlay
		if view == null or App._active_dialogue_key != initial_key:
			return
		if view._is_animating:
			view._skip_typewriter()
		await _frames(2)
		if view._is_waiting_for_choice:
			var before: String = App._active_dialogue_key
			var cancel: InputEventKey = InputEventKey.new()
			cancel.keycode = KEY_ESCAPE
			cancel.pressed = true
			view._unhandled_input(cancel)
			_check(App._active_dialogue_key == before, "Esc 不跳过选项")
			view._on_option_selected(0)
		else:
			view._on_card_panel_clicked()
		await _frames(2)

## 等待容器布局和异步页面装载。## 输入: count。输出: 无。
func _frames(count: int = 8) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame

## 注入鼠标点击。## 输入: point、double_click。输出: 无。
func _click(point: Vector2, double_click: bool = false) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	get_tree().root.push_input(motion, true)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.double_click = double_click
	event.pressed = true
	get_tree().root.push_input(event, true)
	event.pressed = false
	get_tree().root.push_input(event, true)
	await _frames()

## 注入按下、移动、释放的完整拖动。## 输入: point、movement。输出: 无。
func _drag(point: Vector2, movement: Vector2) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_tree().root.push_input(event, true)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point + movement
	motion.global_position = point + movement
	motion.relative = movement
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_tree().root.push_input(motion, true)
	event.position = point + movement
	event.pressed = false
	get_tree().root.push_input(event, true)
	await _frames()

## 保存真实 GPU 渲染结果。## 输入: filename。输出: 无。
func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var picture: Image = get_tree().root.get_texture().get_image()
	_check(not picture.is_empty(), "真实渲染：" + filename)
	picture.save_png(_output.path_join(filename + ".png"))

## 记录一项断言。## 输入: passed、message。输出: 无。
func _check(passed: bool, message: String) -> void:
	_checks += 1
	if not passed:
		_failures.append(message)
		print("DESKTOP_CHECK_FAILED: ", message)

## 写入报告并退出验收工程。## 输入: 无。输出: 无。
func _finish() -> void:
	var report: Dictionary = {"checks": _checks, "failures": _failures, "engine": Engine.get_version_info().string}
	var file: FileAccess = FileAccess.open(_output.path_join("verification.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("DESKTOP_VERIFICATION: ", JSON.stringify(report))
	get_tree().quit.call_deferred(0 if _failures.is_empty() else 1)

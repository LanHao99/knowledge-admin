extends Node
## 仅在隔离工程验证剧情动作、模态输入及两种窗口破损的实际渲染。

var _failures: Array[String] = []
var _checks: int = 0
var _desktop: Control
var _effect: WindowShatterEffect
var _output: String = "user://dialogue_actions_review"


## 全部 Autoload 就绪后再开始验收。## 输入: 无。输出: 无。
func _ready() -> void:
	_run.call_deferred()


## 在隔离存档运行真实剧本，输出截图和检查结果。## 输入: 无。输出: 无。
func _run() -> void:
	if ProjectSettings.get_setting("application/config/name") != "KnowledgeAdminDesktopVerification":
		push_error("剧情动作验收必须使用隔离工程")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	var tutorial: TutorialProgress = TutorialProgress.new()
	for key: String in TutorialManager._tutorials:
		tutorial.mark_completed(key)
	TutorialManager._progress = tutorial
	_desktop = load("res://scenes/desktop/desktop.tscn").instantiate() as Control
	add_child(_desktop)
	_desktop.get_node("WindowEffects").effect_started.connect(_on_effect_started)
	DebugSettings.set_debug_mode(true)
	_check(App.reset_story_data().success, "重置隔离剧情")
	WallpaperSettings.load_settings("user://dialogue_actions_wallpaper_%d.cfg" % Time.get_ticks_usec())
	WindowManager.open_app("window_lab")
	await _verify_wallpaper()
	await _verify_partial_damage()
	await _verify_shatter()
	var report: Dictionary = {"checks": _checks, "failures": _failures, "renderer": RenderingServer.get_current_rendering_method(), "version": Engine.get_version_info().string}
	var file: FileAccess = FileAccess.open(_output.path_join("verification.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("DIALOGUE_ACTIONS_REVIEW: ", JSON.stringify(report))
	get_tree().quit(0 if _failures.is_empty() else 1)


## 验证第二章先等待强制确认、Esc 不推进、停止可解除等待，确认后壁纸真实生效。## 输入: 无。输出: 无。
func _verify_wallpaper() -> void:
	_check(WindowManager.open_app("control_panel"), "打开壁纸设置")
	var panel: Control = WindowManager.get_app_window("control_panel").get_content()
	var items: ItemList = panel.get_node("%WallpaperList") as ItemList
	var tabs: TabContainer = panel.find_child("SettingsTabs", true, false) as TabContainer
	tabs.current_tab = tabs.get_tab_idx_from_control(tabs.get_node("壁纸"))
	for index: int in items.item_count:
		_check(not WallpaperSettings.LOCKED_BY_DEFAULT.has(str(items.get_item_metadata(index))), "锁定图片不生成选项")
	await _frames(5)
	await _capture("wallpaper_choices_locked_hidden")
	_check(App.jump_to_story("chapter_2", "revelation").success, "跳转世界的真相")
	await _frames(6)
	var confirmation: DialogueActionConfirmation = App._action_confirmation
	_check(is_instance_valid(confirmation), "第二章开头弹出确认层")
	if not is_instance_valid(confirmation):
		return
	_check(WallpaperSettings.is_wallpaper_unlocked("res://assets/wallpapers/mountain1.png"), "收到时解锁山景")
	_check(not WallpaperSettings.is_wallpaper_unlocked("res://assets/wallpapers/tower1.png"), "塔楼保持锁定")
	_check(WallpaperSettings.wallpaper_path.is_empty(), "确认前不更换壁纸")
	_check(App._overlay._resolving_line and App._overlay._current_line == null, "确认期间不读取下一句")
	_check(not (confirmation.get_node("%NoButton") as Button).visible, "强制确认隐藏否")
	await _key(KEY_ESCAPE)
	_check(App._action_confirmation == confirmation and confirmation.visible, "Esc 无法跳过强制确认")
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_tree().root.size = resolution
		get_tree().root.content_scale_size = resolution
		for font_scale: float in [0.8, 1.5]:
			UiSettings.set_font_scale(font_scale)
			await _frames(5)
			var frame: Control = confirmation.get_node("InputBlocker/SafeMargin/Center/Frame") as Control
			_check(get_viewport().get_visible_rect().encloses(frame.get_global_rect()), "确认框处于屏幕内 %s/%s" % [resolution, font_scale])
			await _capture("confirm_%dx%d_%d" % [resolution.x, resolution.y, roundi(font_scale * 100)])
	await _click((confirmation.get_node("%StopTestButton") as Button).get_global_rect().get_center())
	await _frames(6)
	_check(App._action_confirmation == null and not WindowManager._story_locked, "停止测试解除确认与剧情锁")
	_check(not App.get_story_progress().is_chapter_dialogue_completed("chapter_2", "revelation"), "停止时当前段不记完成")
	_check(WallpaperSettings.wallpaper_path.is_empty(), "停止不执行壁纸脚本")
	_dismiss_stop_dialogs()
	UiSettings.set_font_scale(1.0)
	_check(App.jump_to_story("chapter_2", "revelation").success, "重新播放强制壁纸")
	await _frames(6)
	confirmation = App._action_confirmation
	await _click((confirmation.get_node("%YesButton") as Button).get_global_rect().get_center())
	await _frames(6)
	_check(WallpaperSettings.wallpaper_path == "res://assets/wallpapers/mountain1.png", "确认后自动切换山景")
	_check((_desktop.get_node("%Wallpaper") as TextureRect).texture != null, "桌面真实使用壁纸纹理")
	_check(App._overlay._current_line != null and not App._overlay._resolving_line, "确认后继续第一句")
	await _drive(0)
	_check(App.get_story_progress().is_chapter_dialogue_completed("chapter_2", "revelation"), "第二章本段自然完成")
	var unlocked_paths: PackedStringArray = []
	for index: int in items.item_count:
		unlocked_paths.append(str(items.get_item_metadata(index)))
	_check(unlocked_paths.has("res://assets/wallpapers/mountain1.png"), "已打开设置即时加入收到的壁纸")
	_check(not unlocked_paths.has("res://assets/wallpapers/tower1.png"), "尚未收到的塔楼仍不出现在选项中")
	await _capture("wallpaper_choices_after_unlock")
	WindowManager.close_app("control_panel")
	await _capture("wallpaper_applied")


## 第一分支到系统台词之后施加局部破损，继续阅读并自然完成。## 输入: 无。输出: 无。
func _verify_partial_damage() -> void:
	_check(App.jump_to_story("chapter_1", "warning").success, "开启局部破损分支")
	await _frames(4)
	for _step: int in range(80):
		var window: ManagedWindow = WindowManager.get_app_window("unknown_program")
		if window != null and window.damage_amount > 0.0:
			break
		await _advance(0)
	var window: ManagedWindow = WindowManager.get_app_window("unknown_program")
	_check(window != null and is_equal_approx(window.damage_amount, 0.7), "系统再分配后局部破损")
	_check(WindowManager._story_locked and not window.is_shattering(), "局部破损保留剧情与交互")
	if App._overlay._is_animating:
		App._overlay._skip_typewriter()
	await _frames(20)
	await _capture("warning_partial_damage")
	await _drive(0)
	_check(App.get_story_progress().is_chapter_dialogue_completed("chapter_1", "warning"), "局部破损分支自然完成")
	_check(WindowManager.open_app("unknown_program"), "剧情结束后恢复未知程序")
	_check(WindowManager.get_app_window("unknown_program") == window and is_equal_approx(window.damage_amount, 0.7), "收起并恢复仍保留半破碎实例")
	window._on_minimize_pressed()
	WindowManager.open_app("unknown_program")
	_check(is_equal_approx(window.damage_amount, 0.7), "最小化不清除裂纹")
	var previous: WeakRef = weakref(window)
	await _click((window.get_node("%CloseButton") as Button).get_global_rect().get_center())
	await _frames(4)
	_check(previous.get_ref() == null and WindowManager.get_app_window("unknown_program") == null, "点击关闭真实销毁半破碎进程")
	_check(not _desktop.get_node("%Taskbar")._app_buttons.has("unknown_program"), "关闭后移除未知程序任务栏按钮")
	_check(WindowManager.open_app("unknown_program"), "关闭后重新打开未知程序")
	var reopened: ManagedWindow = WindowManager.get_app_window("unknown_program")
	_check(is_equal_approx(reopened.damage_amount, 0.0) and not (reopened.get_node("DamageOverlay") as CanvasItem).visible, "新进程恢复完整窗口")
	await _frames(5)
	await _capture("unknown_program_after_close")


## 第二分支释放未知程序，产生真实 GPU 快照和碎片，并可打开无损的新剧情。## 输入: 无。输出: 无。
func _verify_shatter() -> void:
	_check(App.jump_to_story("chapter_1", "warning").success, "开启完全破碎分支")
	await _frames(4)
	var previous: WeakRef = weakref(WindowManager.get_app_window("unknown_program"))
	await _drive(1)
	await _frames(6)
	_check(previous.get_ref() == null, "未知程序旧实例已释放")
	_check(WindowManager.get_app_window("unknown_program") == null, "注册表不保留破碎窗口")
	_check(not WindowManager._story_locked and not _desktop.get_node("ModalLayer").visible, "完整破碎解除模态")
	_check(App.get_story_progress().is_chapter_dialogue_completed("chapter_1", "warning"), "完整破碎完成本段")
	_check(is_instance_valid(_effect) and _effect.shard_count > 0, "真实捕获模态剧情并创建碎片")
	if is_instance_valid(_effect):
		await _capture("warning_shatter_impact")
		_effect.elapsed = _effect._impact_duration + 0.22
		_effect._process(0.0)
		await _frames(3)
		await _capture("warning_shatter_falling")
		_effect.set_process(true)
	_check(WindowManager.get_app_window("window_lab").process_mode == Node.PROCESS_MODE_INHERIT, "其他应用恢复处理")
	_check(App.jump_to_story("chapter_2", "revelation").success, "碎片期间可以开始下段")
	await _frames(6)
	_check(is_equal_approx(WindowManager.get_app_window("unknown_program").damage_amount, 0.0), "新的未知程序无损")
	App._action_confirmation.accept()
	await _drive(0)
	await _frames(120)
	_check(_desktop.get_node("WindowEffects").get_child_count() == 0, "独立碎片最终清理")


## 暂停碎片时间以检查首帧快照，保留真实绘制。## 输入: effect (WindowShatterEffect)。输出: 无。
func _on_effect_started(effect: WindowShatterEffect) -> void:
	_effect = effect
	effect.set_process(false)


## 推进剧情到自然结束，设置有界等待以暴露异步死锁。## 输入: first_choice (int)。输出: 无。
func _drive(first_choice: int) -> void:
	for _step: int in range(180):
		if not WindowManager._story_locked:
			return
		await _advance(first_choice)
	_check(false, "剧情应在限定步数内结束")


## 跳过当前打字机后选择选项或点击正文，等待真实异步解析。## 输入: choice (int)。输出: 无。
func _advance(choice: int) -> void:
	var view: StoryDialogueOverlay = App._overlay
	if not is_instance_valid(view) or view._window_shatter_pending:
		await _frames(2)
		return
	if view._is_animating:
		view._skip_typewriter()
	if view._is_waiting_for_choice:
		view._on_option_selected(mini(choice, view._current_line.responses.size() - 1))
	else:
		view._on_card_panel_clicked()
	await _frames(2)


## 使用实际鼠标输入点击确认按钮。## 输入: point (Vector2)。输出: 无。
func _click(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_tree().root.push_input(event, true)
		await _frames(2)


## 使用实际键盘输入验证取消行为。## 输入: keycode (Key)。输出: 无。
func _key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = keycode
		event.pressed = pressed
		get_tree().root.push_input(event, true)
		await _frames(2)


## 清理测试停止说明，避免其遮挡下一次输入。## 输入: 无。输出: 无。
func _dismiss_stop_dialogs() -> void:
	for dialog: Node in App.find_children("*", "AcceptDialog", true, false):
		(dialog as Window).hide()
		dialog.queue_free()


## 等待布局与渲染完成。## 输入: count (int)。输出: 无。
func _frames(count: int = 3) -> void:
	for _frame: int in count:
		await get_tree().process_frame


## 保存 GPU 实际画面。## 输入: label (String)。输出: 无。
func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_output.path_join(label + ".png"))


## 记录一项验收结果。## 输入: passed (bool)、label (String)。输出: 无。
func _check(passed: bool, label: String) -> void:
	_checks += 1
	if not passed:
		_failures.append(label)
		push_error("DIALOGUE_ACTIONS_CHECK: " + label)

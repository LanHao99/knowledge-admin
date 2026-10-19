extends Node
## 隔离工程中验证知识空间的真实渲染、鼠标路由及窗口生命周期。

var _checks: int = 0
var _failures: Array[String] = []
var _output: String = "user://knowledge_space_review"
var _desktop: Control
var _view: KnowledgeSpace
var _window: ManagedWindow
var _saved_records: Array[String] = []


## 等待 Autoload 完成后开始隔离验收。## 输入: 无。输出: 无。
func _ready() -> void:
	_run.call_deferred()


## 建立隔离数据并依次运行画面、飞行、档案和桌面检查。## 输入: 无。输出: 无。
func _run() -> void:
	if ProjectSettings.get_setting("application/config/name") != "KnowledgeAdminDesktopVerification":
		push_error("知识空间验收必须使用隔离工程与存档")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	get_tree().root.grab_focus()
	UiSettings.set_font_scale(1.0)
	_seed_database()
	_saved_records = App.get_story_progress().completed_dialogues.duplicate()
	_unlock_archives()
	_desktop = load("res://scenes/desktop/desktop.tscn").instantiate() as Control
	add_child(_desktop)
	await _frames()
	for entry: Button in _desktop.get_node("%DesktopIconGrid").get_children():
		if str(entry.get_meta("app_id")) == "knowledge_space":
			await _click_control_twice(entry)
			break
	_check(WindowManager.get_app_window("knowledge_space") != null, "实际双击桌面快捷方式启动知识空间")
	_check(WindowManager.open_app("knowledge_space"), "知识空间从桌面打开")
	await _frames()
	_window = WindowManager.get_app_window("knowledge_space")
	_view = _window.get_content() as KnowledgeSpace
	_check(_view != null, "窗口正确实例化知识空间")
	if _view == null:
		_finish()
		return
	_check(_view._card_count == 24 and _view._archive_count == 6, "真实数据库读取24份卡片及6份档案")
	_check(WindowManager.open_app("knowledge_space") and _window == WindowManager.get_app_window("knowledge_space"), "重复打开保持单实例")
	_check((_view.get_node("%SpaceViewport") as SubViewport).world_3d != get_tree().root.world_3d, "空间使用独立World3D")
	await _capture("overview_1280_100")
	await _verify_selection_and_focus()
	await _verify_flight()
	await _verify_lifecycle()
	await _verify_progress()
	await _verify_display_matrix()
	await _verify_minimum_and_long_text()
	await _verify_close_and_standalone()
	_finish()


## 通过现有业务接口创建独立数据库样本，供窗口真实读取。## 输入: 无。输出: 无。
func _seed_database() -> void:
	var types: NoteTypeManager = NoteTypeManager.new()
	add_child(types)
	_check(types.setup("user://knowledge_admin.db"), "测试笔记类型初始化")
	var decks: DeckManager = DeckManager.new()
	add_child(decks)
	_check(decks.setup("user://knowledge_admin.db"), "测试牌组初始化")
	var notes: NoteManager = NoteManager.new()
	add_child(notes)
	_check(notes.setup("user://knowledge_admin.db"), "测试笔记初始化")
	var existing: Dictionary = decks.get_all_decks()
	if not existing.get("data", []).is_empty():
		return
	var first_id: int = int(decks.create_deck("记忆与认知").data.id)
	var second_id: int = int(decks.create_deck("信号与计算").data.id)
	var examples: Array[Dictionary] = [
		{"front": "间隔重复为什么能够帮助记忆？", "back": "在逐渐拉长的时间间隔中主动回忆，能反复加强对知识的提取。\n\n记忆不是一份始终完整的副本，而是每次提取时重新建立的联系。"},
		{"front": "知识之间的联系是什么？", "back": "一条新知识可以通过共同概念、例子和应用条件与已有知识联系起来。\n\n这个空间按来源牌组组织文档，帮助观察属于同一个主题的片段。"},
		{"front": "数字信号如何表示信息？", "back": "信息通过离散的符号序列编码。发送端与接收端遵循同一套约定，才能解释这些符号。"},
		{"front": "什么是噪声？", "back": "噪声是干扰信息识别的变化。恢复信号需要区分有效结构与随机扰动。\n\n并非所有尚未解释的变化都是随机的。"},
	]
	for index: int in range(32):
		var sample: Dictionary = examples[index % examples.size()].duplicate()
		sample.front = str(sample.front) + " / %02d" % (index + 1)
		var result: Dictionary = notes.create_note("__default__", sample, first_id if index % 2 == 0 else second_id)
		_check(result.get("success", false), "创建隔离卡片 %d" % index)


## 在隔离进度内解锁全部样本，不保存到任何正式玩家存档。## 输入: 无。输出: 无。
func _unlock_archives() -> void:
	var progress: StoryProgress = App.get_story_progress()
	progress.completed_dialogues.clear()
	for record: String in ["chapter_1/intro", "chapter_1/explain", "chapter_1/warning", "chapter_2/revelation", "chapter_2/xanaku", "chapter_2/trojan"]:
		progress.completed_dialogues.append(record)
	App.story_state_changed.emit()


## 用真实鼠标选择、工具栏聚焦与双击聚焦验证画面坐标。## 输入: 无。输出: 无。
func _verify_selection_and_focus() -> void:
	var target: KnowledgeSpaceDocument = _view._documents["archive:first_contact"]
	await _click_document(target)
	_check(_view._selected_id == target.document_id, "实际鼠标选择剧情档案")
	await _click_control(_view.get_node("%FocusButton") as Control)
	await get_tree().create_timer(0.8).timeout
	_check(_page_fits(target), "自动聚焦后完整页面位于视野内")
	_check((_view.get_node("%SpaceCamera") as Camera3D).position.z > target.position.z, "聚焦停在文档正面")
	await _capture("focused_archive")
	await _click_control(_view.get_node("%ReadButton") as Control)
	_check(_view.get_node("%Reader").visible, "阅读全文按钮打开阅读层")
	_check(str(_view.get_node("%ReaderText").text) == target.body, "阅读层显示完整档案正文")
	await _capture("archive_reader")
	await _click_control(_view.get_node("%CloseReader") as Control)
	_check(not _view.get_node("%Reader").visible, "返回空间关闭阅读层")
	_view.return_to_entrance()
	await get_tree().create_timer(0.8).timeout
	await _click_document(target, true)
	await get_tree().create_timer(0.8).timeout
	_check(_page_fits(target), "实际双击文档可聚焦")


## 注入右键、移动、转向及 Esc，验证自由飞行与动画中断。## 输入: 无。输出: 无。
func _verify_flight() -> void:
	var camera: Camera3D = _view.get_node("%SpaceCamera") as Camera3D
	_view.return_to_entrance()
	await get_tree().create_timer(0.15).timeout
	await _right_button(true)
	_check(_view._owns_mouse_capture, "右键捕获鼠标")
	var stopped_position: Vector3 = camera.position
	await get_tree().create_timer(0.18).timeout
	_check(camera.position.is_equal_approx(stopped_position), "手动飞行立即中断自动移动")
	_key(KEY_W, true)
	await get_tree().create_timer(0.2).timeout
	_key(KEY_W, false)
	_check(camera.position.distance_to(stopped_position) > 0.8, "W键持续前进实际移动摄像头")
	var before_y: float = camera.position.y
	_key(KEY_E, true)
	await get_tree().create_timer(0.15).timeout
	_key(KEY_E, false)
	_check(camera.position.y > before_y + 0.5, "E键升高摄像头")
	var turn: InputEventMouseMotion = InputEventMouseMotion.new()
	turn.screen_relative = Vector2(40, -20)
	get_tree().root.push_input(turn, true)
	_check(absf(camera.rotation.y) > 0.05 and is_zero_approx(camera.rotation.z), "鼠标转向且无翻滚")
	await _right_button(false)
	_check(not _view._owns_mouse_capture and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "右键释放归还鼠标")
	await _right_button(true)
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await _frames()
	_check(not _view._owns_mouse_capture, "Esc释放飞行鼠标")


## 检查切换应用、最小化、处理禁用、剧情与系统失焦的捕获回收。## 输入: 无。输出: 无。
func _verify_lifecycle() -> void:
	await _right_button(true)
	var kept_position: Vector3 = (_view.get_node("%SpaceCamera") as Camera3D).position
	WindowManager.open_app("recycle_bin")
	await _frames()
	_check(not _view._owns_mouse_capture, "切换其他应用时释放鼠标")
	WindowManager.open_app("knowledge_space")
	await _frames()
	_check((_view.get_node("%SpaceCamera") as Camera3D).position.is_equal_approx(kept_position), "普通激活保持视角")
	WindowManager.close_app("recycle_bin")
	await _right_button(true)
	_window._on_minimize_pressed()
	await _frames()
	_check(not _view._owns_mouse_capture, "最小化释放鼠标")
	_check((_view.get_node("%SpaceViewport") as SubViewport).render_target_update_mode == SubViewport.UPDATE_DISABLED, "最小化暂停3D渲染")
	WindowManager.open_app("knowledge_space")
	await _frames()
	_check(_window.get_content() == _view and (_view.get_node("%SpaceCamera") as Camera3D).position.is_equal_approx(kept_position), "恢复复用实例及摄像头位置")
	var taskbar: Node = _desktop.get_node("%Taskbar")
	var task_button: Button = taskbar._app_buttons["knowledge_space"]
	_check(task_button.tooltip_text == "知识空间" and task_button.get_node("Icon").texture != null, "任务栏使用知识空间图标与名称提示")
	await _click_control(task_button)
	_check(_window.is_minimized(), "实际任务栏点击最小化知识空间")
	await _click_control(task_button)
	_check(not _window.is_minimized() and _window.get_content() == _view, "实际任务栏点击恢复原实例")
	await _right_button(true)
	_window.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames()
	_check(not _view._owns_mouse_capture and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "父级禁用仍立即归还鼠标")
	_window.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames()
	await _right_button(true)
	WindowManager.begin_dialogue(true, null)
	await _frames()
	_check(not _view._owns_mouse_capture, "真实剧情模态弹出释放鼠标")
	WindowManager.end_dialogue(true)
	await _frames()
	await _right_button(true)
	get_tree().root.focus_exited.emit()
	_check(not _view._owns_mouse_capture, "系统失焦信号释放鼠标")


## 正式进度改变时立即更新档案，隐藏正在阅读的档案并保持卡片位置。## 输入: 无。输出: 无。
func _verify_progress() -> void:
	var target: KnowledgeSpaceDocument = _view._documents["archive:first_contact"]
	_view._select_document(target)
	_view.read_selected()
	var first_card_id: String = ""
	for document_id: String in _view._documents:
		if document_id.begins_with("card:"):
			first_card_id = document_id
			break
	var kept_position: Vector3 = _view._documents[first_card_id].position
	App.get_story_progress().completed_dialogues.clear()
	App.story_state_changed.emit()
	await _frames()
	_check(_view._archive_count == 0 and not _view._documents.has("archive:first_contact"), "剧情重置完全移除档案页面")
	_check(not _view.get_node("%Reader").visible, "档案重锁关闭阅读层")
	_check(_view._documents[first_card_id].position == kept_position, "剧情显隐不重排普通卡片")
	_unlock_archives()
	await _frames()
	_check(_view._archive_count == 6, "进度信号重新显示六篇档案")


## 验证两种分辨率和三种字号下的真实选择、文本与最大化。## 输入: 无。输出: 无。
func _verify_display_matrix() -> void:
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_tree().root.size = dimensions
		get_tree().root.content_scale_size = dimensions
		for font_scale: float in [0.8, 1.0, 1.5]:
			UiSettings.set_font_scale(font_scale)
			_window.size = Vector2(1100, 740)
			_window.fit_work_area()
			(_view.get_node("%SpaceCamera") as Camera3D).position = _view.configuration.entrance_position
			(_view.get_node("%SpaceCamera") as Camera3D).rotation = Vector3.ZERO
			await _frames()
			var label: String = "%d_%d" % [dimensions.x, roundi(font_scale * 100)]
			var target: KnowledgeSpaceDocument = _view._documents["archive:first_contact"]
			await _click_document(target)
			_check(_view._selected_id == target.document_id, "缩放后的真实鼠标选择 " + label)
			_check((_view.get_node("%FlightSurface") as Control).size.y > 180, "视图区有足够高度 " + label)
			_window._on_maximize_pressed()
			await _frames()
			await _click_document(target)
			_check(_view._selected_id == target.document_id, "最大化后选取坐标正确 " + label)
			await _capture("overview_" + label)
			_window._on_maximize_pressed()
			await _frames()


## 最小窗口和最大字号下长文本仍可滚动阅读，工具按钮不溢出。## 输入: 无。输出: 无。
func _verify_minimum_and_long_text() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	UiSettings.set_font_scale(1.5)
	_window.size = Vector2(720, 480)
	_window.fit_work_area()
	var rows: Array[Dictionary] = [{"card_id": 9001, "deck_id": 1, "deck_name": "超长正文测试", "front": "长问题".repeat(300), "back": "完整正文不会截断。\n".repeat(600)}]
	_view.set_card_documents(rows)
	_view._select_document(_view._documents["card:9001"])
	_view.read_selected()
	await _frames()
	var scroll: ScrollContainer = _view.get_node("%ReaderScroll") as ScrollContainer
	_check(scroll.size.y > 160, "最小窗口及150%字号保留可用阅读高度")
	_check(scroll.get_v_scroll_bar().max_value > scroll.size.y, "长正文实际产生纵向滚动")
	_check((_view.get_node("%ReaderText") as Label).text.ends_with("完整正文不会截断。\n".repeat(599) + "完整正文不会截断。"), "阅读层保留长正文末尾")
	_check((_view.get_node("%ReaderText") as Label).size.x <= scroll.size.x, "长文本没有横向溢出")
	await _capture("minimum_reader_720x480_150")
	_view.close_reader()
	await _frames()
	await _capture("minimum_space_720x480_150")
	_view.refresh_content()


## 捕获中关闭必须释放，重开为新实例；独立场景也可正常读取及显示。## 输入: 无。输出: 无。
func _verify_close_and_standalone() -> void:
	UiSettings.set_font_scale(1.0)
	await _frames()
	await _right_button(true)
	var previous_view: WeakRef = weakref(_view)
	WindowManager.close_app("knowledge_space")
	await _frames()
	_check(previous_view.get_ref() == null and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "捕获中关闭释放页面与鼠标")
	var taskbar: Node = _desktop.get_node("%Taskbar")
	await _click_control(taskbar._start_button as Control)
	var menu: Control = taskbar._start_menu as Control
	_check(is_instance_valid(menu), "实际开始按钮打开菜单")
	if is_instance_valid(menu):
		for child: Node in menu.get_node("%AppList").get_children():
			if child is Button and (child as Button).text.strip_edges() == "知识空间":
				await _click_control(child as Control)
				break
	_check(WindowManager.get_app_window("knowledge_space") != null, "实际开始菜单启动知识空间")
	if WindowManager.get_app_window("knowledge_space") == null:
		WindowManager.open_app("knowledge_space")
	await _frames()
	var reopened: KnowledgeSpace = WindowManager.get_app_window("knowledge_space").get_content() as KnowledgeSpace
	_check(reopened._card_count == 24 and not reopened._owns_mouse_capture, "重开创建干净的新实例")
	WindowManager.close_app("knowledge_space")
	_desktop.queue_free()
	await _frames()
	var standalone: KnowledgeSpace = load("res://scenes/desktop/knowledge_space.tscn").instantiate() as KnowledgeSpace
	add_child(standalone)
	await _frames()
	_check(standalone._host == null and standalone._card_count == 24, "F6独立场景可运行并读取本地卡片")
	await _capture("standalone")
	standalone.queue_free()
	await _frames()


## 检查聚焦后的四角确实落在渲染视口中。## 输入: document。输出: bool。
func _page_fits(document: KnowledgeSpaceDocument) -> bool:
	var camera: Camera3D = _view.get_node("%SpaceCamera") as Camera3D
	var viewport_size: Vector2 = Vector2((_view.get_node("%SpaceViewport") as SubViewport).size)
	var half_size: Vector2 = _view.configuration.page_size * 0.5
	for corner: Vector2 in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
		var point: Vector2 = camera.unproject_position(document.position + Vector3(corner.x * half_size.x, corner.y * half_size.y, 0.08))
		if not Rect2(Vector2.ZERO, viewport_size).has_point(point):
			return false
	return true


## 将文档投影位置映射到实际 GUI 视图区并注入鼠标。## 输入: document、double_click。输出: 无。
func _click_document(document: KnowledgeSpaceDocument, double_click: bool = false) -> void:
	var camera: Camera3D = _view.get_node("%SpaceCamera") as Camera3D
	var surface: Control = _view.get_node("%FlightSurface") as Control
	var viewport_size: Vector2 = Vector2((_view.get_node("%SpaceViewport") as SubViewport).size)
	var local_point: Vector2 = camera.unproject_position(document.global_position) * surface.size / viewport_size
	await _click(surface.global_position + local_point, double_click)


## 点击实际按钮中心。## 输入: control。输出: 无。
func _click_control(control: Control) -> void:
	await _click(control.get_global_rect().get_center())


## 实际双击桌面入口。## 输入: control。输出: 无。
func _click_control_twice(control: Control) -> void:
	await _click(control.get_global_rect().get_center(), true)


## 向根视口注入完整鼠标点击，坐标使用逻辑画布。## 输入: point、double_click。输出: 无。
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


## 在视图区中心按下或释放右键，覆盖捕获时的全局释放路径。## 输入: pressed (bool)。输出: 无。
func _right_button(pressed: bool) -> void:
	var point: Vector2 = (_view.get_node("%FlightSurface") as Control).get_global_rect().get_center()
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = pressed
	get_tree().root.push_input(event, true)
	await _frames()


## 通过 Input 更新实际按键状态，覆盖逐帧飞行轮询。## 输入: keycode、pressed。输出: 无。
func _key(keycode: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)


## 等待 UI 布局和实际渲染状态稳定。## 输入: 无。输出: 无。
func _frames() -> void:
	for index: int in range(5):
		await get_tree().process_frame


## 保存真实 GPU 图像，拒绝空画面。## 输入: filename。输出: 无。
func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var picture: Image = get_tree().root.get_texture().get_image()
	_check(not picture.is_empty(), "真实GPU画面 " + filename)
	picture.save_png(_output.path_join(filename + ".png"))


## 记录断言与失败信息，保证剩余检查继续执行。## 输入: condition、description。输出: 无。
func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
		print("KNOWLEDGE_SPACE_CHECK_FAILED: ", description)


## 还原隔离进度并写入最终报告，以失败数量确定退出状态。## 输入: 无。输出: 无。
func _finish() -> void:
	App.get_story_progress().completed_dialogues = _saved_records
	var report: Dictionary = {"checks": _checks, "failures": _failures, "engine": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name()}
	var file: FileAccess = FileAccess.open(_output.path_join("verification.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("KNOWLEDGE_SPACE_VERIFICATION: ", JSON.stringify(report))
	get_tree().quit.call_deferred(0 if _failures.is_empty() else 1)

extends SceneTree
## 在隔离工程验收真实启动遮罩、场景交接、输入隔离与多分辨率 GPU 渲染。

const BOOT_SCENE: String = "res://scenes/desktop/boot_screen.tscn"
const OUTPUT: String = "res://boot_transition_review"

var _checks: Array[Dictionary] = []
var _failures: Array[String] = []
var _desktop_instances: int = 0


## 延迟启动，等待自动加载系统就绪。## 输入: 无。输出: 无。
func _initialize() -> void:
	_run.call_deferred()


## 记录桌面实例化次数。## 输入: node (Node) - 新进入场景树的节点。输出: 无。
func _track_desktop(node: Node) -> void:
	if node.scene_file_path == "res://scenes/desktop/desktop.tscn":
		_desktop_instances += 1


## 记录断言及错误说明。## 输入: condition、description。输出: 无。
func _check(condition: bool, description: String) -> void:
	_checks.append({"passed": condition, "description": description})
	if not condition:
		_failures.append(description)
		push_error(description)


## 等待布局和 GPU 帧完成。## 输入: count (int) - 等待帧数。输出: 无。
func _frames(count: int = 4) -> void:
	for index: int in range(count):
		await process_frame
	await RenderingServer.frame_post_draw


## 等待转场释放，设置超时以避免验收挂起。## 输入: timeout (float) - 最长秒数。输出: 是否完成。
func _wait_finished(timeout: float = 4.0) -> bool:
	var deadline: int = Time.get_ticks_msec() + roundi(timeout * 1000.0)
	while get_first_node_in_group(&"boot_transition") != null and Time.get_ticks_msec() < deadline:
		await process_frame
	await _frames()
	return get_first_node_in_group(&"boot_transition") == null


## 打开真实启动入口并等待下层桌面可绘制。## 输入: 无。输出: 封面控制器。
func _begin_boot() -> CanvasLayer:
	change_scene_to_file(BOOT_SCENE)
	await scene_changed
	var deadline: int = Time.get_ticks_msec() + 4000
	var cover: CanvasLayer = get_first_node_in_group(&"boot_transition") as CanvasLayer
	while is_instance_valid(cover) and not cover._desktop_ready and Time.get_ticks_msec() < deadline:
		await process_frame
		cover = get_first_node_in_group(&"boot_transition") as CanvasLayer
	_check(is_instance_valid(cover) and cover._desktop_ready, "桌面在溶解前已完成初始化与绘制")
	return cover


## 保存真实渲染画面。## 输入: filename (String) - 文件名。输出: 渲染图像。
func _capture(filename: String) -> Image:
	await _frames()
	var picture: Image = root.get_texture().get_image()
	picture.save_png(OUTPUT.path_join(filename + ".png"))
	return picture


## 注入按键按下、松开或自动重复。## 输入: pressed、echo_event。输出: 无。
func _key(pressed: bool = true, echo_event: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = pressed
	event.echo = echo_event
	root.push_input(event, true)


## 注入完整鼠标点击。## 输入: point、double_click。输出: 无。
func _click(point: Vector2, double_click: bool = false) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.double_click = double_click
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)


## 比较两个颜色，忽略微小渲染量化差异。## 输入: first、second。输出: 是否近似相等。
func _same_color(first: Color, second: Color) -> bool:
	return absf(first.r - second.r) + absf(first.g - second.g) + absf(first.b - second.b) < 0.015


## 检查停留、开孔及结束时的真实像素与界面布局。## 输入: cover。输出: 无。
func _verify_rendering(cover: CanvasLayer) -> void:
	cover.set_process(false)
	var mask: ShaderMaterial = cover.get_node("%CoverGroup").material as ShaderMaterial
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(800, 600)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await _frames()
		var suffix: String = "%dx%d" % [dimensions.x, dimensions.y]
		var status: RichTextLabel = cover.get_node("%Status")
		_check(root.get_visible_rect().encloses(status.get_global_rect()), "中文完整显示 " + suffix)
		_check(status.get_global_rect().get_center().distance_to(Vector2(dimensions) * 0.5) < 2.0, "文字准确居中 " + suffix)
		mask.set_shader_parameter("progress", 1.0)
		var desktop_image: Image = await _capture("complete_" + suffix)
		mask.set_shader_parameter("progress", 0.0)
		var hold_image: Image = await _capture("hold_" + suffix)
		await create_timer(0.15).timeout
		await _frames()
		var animated_image: Image = root.get_texture().get_image()
		_check(hold_image.get_data() != animated_image.get_data(), "全屏波浪持续动画 " + suffix)
		mask.set_shader_parameter("progress", 0.2)
		await _capture("early_" + suffix)
		mask.set_shader_parameter("progress", 0.5)
		var middle_image: Image = await _capture("middle_" + suffix)
		mask.set_shader_parameter("progress", 0.8)
		await _capture("late_" + suffix)
		var center: Vector2i = Vector2i(Vector2(dimensions) * 0.5)
		var corner: Vector2i = Vector2i(4, 4)
		_check(not _same_color(hold_image.get_pixelv(corner), desktop_image.get_pixelv(corner)), "停留期封面覆盖桌面 " + suffix)
		_check(_same_color(middle_image.get_pixelv(center), desktop_image.get_pixelv(center)), "中心开孔露出真实桌面 " + suffix)
		_check(not _same_color(middle_image.get_pixelv(corner), desktop_image.get_pixelv(corner)), "中期四角仍由封面覆盖 " + suffix)
		cover.visible = false
		await _frames()
		var uncovered: Image = root.get_texture().get_image()
		_check(desktop_image.get_data() == uncovered.get_data(), "完成画面与无遮罩桌面逐像素一致 " + suffix)
		cover.visible = true
		mask.set_shader_parameter("progress", 0.0)


## 验证转场输入拦截、进度单调性及结束后的桌面操作。## 输入: cover。输出: 无。
func _verify_input(cover: CanvasLayer) -> void:
	var desktop: Control = current_scene as Control
	var desktop_id: int = desktop.get_instance_id()
	var taskbar: Node = desktop.get_node("%Taskbar")
	_check(desktop.process_mode == Node.PROCESS_MODE_DISABLED, "转场期间桌面处理被暂停")
	_key(false)
	_key(true, true)
	_check(not cover._accelerated, "松开与重复按键不触发加速")
	_click(taskbar._start_button.get_global_rect().get_center())
	_check(cover._accelerated, "真实鼠标按下触发加速")
	_check(not is_instance_valid(taskbar._start_menu), "转场点击未泄漏到开始菜单")
	cover._process(0.2)
	var before: float = cover._dissolve_progress
	var rate: float = cover._dissolve_rate
	for index: int in range(5):
		_key()
	_check(is_equal_approx(cover._dissolve_progress, before), "连续输入不会重置进度")
	_check(cover._dissolve_rate >= rate, "连续输入不会延长剩余时长")
	cover.set_process(true)
	_check(await _wait_finished(1.0), "加速溶解在期限内完成并释放封面")
	_check(current_scene.get_instance_id() == desktop_id, "完成时保留同一桌面实例")
	_check(desktop.process_mode == Node.PROCESS_MODE_INHERIT, "结束后恢复桌面处理")
	_check(root.get_node_or_null("BootScreen") == null, "启动入口已释放")
	_click(taskbar._start_button.get_global_rect().get_center())
	await _frames()
	_check(is_instance_valid(taskbar._start_menu), "转场后开始菜单可正常操作")
	_click(Vector2(dimensions_safe_x(), 200.0))
	await _frames()
	_check(not is_instance_valid(taskbar._start_menu), "转场后菜单可正常收起")
	for entry: Button in desktop.get_node("%DesktopIconGrid").get_children():
		if entry.get_meta("app_id") == "my_computer":
			_click(entry.get_global_rect().get_center(), true)
			break
	await _frames()
	_check(root.get_node("WindowManager").get_app_window("my_computer") != null, "转场后双击快捷方式可打开应用")
	root.get_node("WindowManager").close_app("my_computer")


## 选择图标与菜单外的安全测试横坐标。## 输入: 无。输出: 横坐标。
func dimensions_safe_x() -> float:
	return root.get_visible_rect().size.x * 0.75


## 执行真实时间、延迟准备和中断清理场景。## 输入: 无。输出: 无。
func _verify_timing() -> void:
	var instance_count: int = _desktop_instances
	var started_at: int = Time.get_ticks_msec()
	var cover: CanvasLayer = await _begin_boot()
	cover.start(3.0, 1.4, 0.6)
	_check(await _wait_finished(), "默认转场自动完成")
	var elapsed_ms: int = Time.get_ticks_msec() - started_at
	_check(elapsed_ms >= 2800 and elapsed_ms < 3800, "正常播放约三秒：%d ms" % elapsed_ms)
	_check(_desktop_instances == instance_count + 1, "一次启动只实例化一个桌面，重复 start 无副作用")
	cover = await _begin_boot()
	cover._elapsed = cover._hold_duration
	await create_timer(0.2).timeout
	var progress_before: float = cover._dissolve_progress
	_key()
	_check(cover._dissolve_progress >= progress_before, "溶解途中按键不会倒退")
	started_at = Time.get_ticks_msec()
	_check(await _wait_finished(1.0), "溶解途中可加速完成")
	_check(Time.get_ticks_msec() - started_at < 800, "途中加速不超过约 0.6 秒")
	cover = await _begin_boot()
	cover.set_process(false)
	cover._desktop_ready = false
	_key()
	cover._process(10.0)
	_check(is_zero_approx(cover._dissolve_progress), "准备较慢时即使加速也保持封面不透明")
	cover._desktop_ready = true
	cover._process(0.1)
	_check(cover._dissolve_progress > 0.0, "准备完成后兑现提前请求的加速")
	var desktop: Control = current_scene as Control
	cover.queue_free()
	await _frames()
	_check(desktop.process_mode == Node.PROCESS_MODE_INHERIT, "提前销毁封面也会恢复桌面处理")


## 执行完整验收并输出可追溯报告。## 输入: 无。输出: 报告、截图和退出码。
func _run() -> void:
	if ProjectSettings.get_setting("application/config/name") != "KnowledgeAdminBootVerification":
		push_error("启动转场验收必须使用隔离工程")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	node_added.connect(_track_desktop)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	var cover: CanvasLayer = await _begin_boot()
	if cover == null:
		quit(1)
		return
	_check(cover.get_node("%Status").get_parsed_text() == "正在启动系统...", "主文案正确")
	await _verify_rendering(cover)
	await _verify_input(cover)
	await _verify_timing()
	var report: Dictionary = {"engine": Engine.get_version_info().string, "checks": _checks.size(), "failures": _failures, "results": _checks}
	var file: FileAccess = FileAccess.open(OUTPUT.path_join("verification.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("BOOT_TRANSITION_REVIEW ", JSON.stringify(report))
	quit(0 if _failures.is_empty() else 1)

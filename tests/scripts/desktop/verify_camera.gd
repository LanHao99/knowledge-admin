extends Node
## 隔离工程中验证摄像头的真实 GPU 输出、透明立绘与桌面生命周期。

var _checks: int = 0
var _failures: Array[String] = []
var _output: String = "user://camera_review"


## 等待 Autoload 就绪后执行 GPU 验收。## 输入: 无。输出: 无。
func _ready() -> void:
	_run.call_deferred()


## 使用测试色卡验证立绘采样，并保存真实空信号界面。## 输入: 无。输出: 无。
func _run() -> void:
	if ProjectSettings.get_setting("application/config/name") != "KnowledgeAdminDesktopVerification":
		push_error("摄像头验收必须使用隔离工程")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	UiSettings.set_font_scale(1.0)
	var desktop: Control = load("res://content/scenes/desktop/desktop.tscn").instantiate() as Control
	add_child(desktop)
	await _frames()
	_check(WindowManager.open_app("camera"), "桌面可打开摄像头")
	await _frames()
	var window: ManagedWindow = WindowManager.get_app_window("camera")
	var camera: Control = window.get_content()
	var screen: ColorRect = camera.get_node("%Screen") as ColorRect
	_check(window.size == Vector2(560, 560), "默认整窗为 560×560")
	_check(WindowManager.open_app("camera") and WindowManager.get_app_window("camera") == window, "重复启动复用单实例")
	await _capture("mira_camera")
	camera.set("portrait_texture", null)
	await _frames()
	await _capture("waiting_signal")
	var portrait: Image = Image.create(128, 256, false, Image.FORMAT_RGBA8)
	portrait.fill(Color.TRANSPARENT)
	portrait.fill_rect(Rect2i(0, 64, 64, 128), Color.RED)
	portrait.fill_rect(Rect2i(64, 64, 64, 128), Color.BLUE)
	camera.set("portrait_texture", ImageTexture.create_from_image(portrait))
	camera.set("background_color", Color(0.1, 0.3, 0.2))
	camera.set("crt_enabled", false)
	await _frames()
	var clean: Image = await _capture("test_card_clean")
	var feed_rect: Rect2 = screen.get_global_rect()
	var center: Vector2 = feed_rect.get_center()
	var red_point: Vector2 = center - Vector2(feed_rect.size.y * 0.125, 0)
	var blue_point: Vector2 = center + Vector2(feed_rect.size.y * 0.125, 0)
	_check(_pixel(clean, red_point).r > 0.9 and _pixel(clean, blue_point).b > 0.9, "纵向立绘完整等比显示，左右颜色正确")
	var transparent_point: Vector2 = center - Vector2(0, feed_rect.size.y * 0.4)
	_check(_color_difference(_pixel(clean, transparent_point), Color(0.1, 0.3, 0.2)) < 0.025, "透明区域合成摄像头背景")
	camera.set("portrait_flip_h", true)
	await _frames()
	var flipped: Image = await _capture("test_card_flipped")
	_check(_pixel(flipped, red_point).b > 0.9 and _pixel(flipped, blue_point).r > 0.9, "镜像实时交换立绘左右")
	camera.set("crt_enabled", true)
	await _frames()
	var crt: Image = await _capture("test_card_crt")
	_check(_difference(flipped, crt, feed_rect) > 500, "CRT 扫描线、弯曲与色偏产生实际像素变化")
	var title: Rect2 = (window.get_node("%TitleBarPanel") as Control).get_global_rect()
	_check(_difference(flipped, crt, title) == 0, "CRT 不影响标题栏和按钮")
	window._on_minimize_pressed()
	_check(window.is_minimized(), "可最小化")
	WindowManager.open_app("camera")
	_check(window.get_content() == camera and not window.is_minimized(), "恢复保留立绘与参数")
	for font_scale: float in [0.8, 1.0, 1.5]:
		UiSettings.set_font_scale(font_scale)
		window._on_maximize_pressed()
		await _frames()
		_check(is_equal_approx(window.size.x, window.size.y), "最大化保持方形，字号 %s" % font_scale)
		_check(Rect2(Vector2.ZERO, (window.get_parent() as Control).size).encloses(window.get_rect()), "最大化在工作区内")
		window._on_maximize_pressed()
	WindowManager.close_app("camera")
	await _frames()
	_check(WindowManager.get_app_window("camera") == null, "可关闭并释放窗口")
	_finish()


## 读取逻辑坐标对应的实际 GPU 像素。## 输入: 图像、坐标。输出: 颜色。
func _pixel(picture: Image, point: Vector2) -> Color:
	return picture.get_pixelv(Vector2i(point))


## 统计指定矩形内变化明显的像素，避开渲染量化噪声。## 输入: 两张图像、逻辑矩形。输出: 变化数量。
func _difference(first: Image, second: Image, bounds: Rect2) -> int:
	var count: int = 0
	for y: int in range(ceili(bounds.position.y), floori(bounds.end.y)):
		for x: int in range(ceili(bounds.position.x), floori(bounds.end.x)):
			if _color_difference(first.get_pixel(x, y), second.get_pixel(x, y)) > 0.03:
				count += 1
	return count


## 比较两种颜色的最大 RGB 通道差。## 输入: 两种颜色。输出: 差值。
func _color_difference(first: Color, second: Color) -> float:
	return maxf(absf(first.r - second.r), maxf(absf(first.g - second.g), absf(first.b - second.b)))


## 等待容器布局与材质更新完成。## 输入: 无。输出: 无。
func _frames() -> void:
	for frame: int in range(5):
		await get_tree().process_frame


## 保存真实渲染结果。## 输入: 文件名。输出: GPU 图像。
func _capture(filename: String) -> Image:
	await RenderingServer.frame_post_draw
	var picture: Image = get_tree().root.get_texture().get_image()
	picture.save_png(_output.path_join(filename + ".png"))
	return picture


## 记录检查结果并继续收集其余失败。## 输入: 条件、说明。输出: 无。
func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
		print("CAMERA_CHECK_FAILED: ", description)


## 写入验收报告并按结果退出。## 输入: 无。输出: 无。
func _finish() -> void:
	var report: Dictionary = {"checks": _checks, "failures": _failures, "engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method()}
	var file: FileAccess = FileAccess.open(_output.path_join("verification.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("CAMERA_VERIFICATION: ", JSON.stringify(report))
	get_tree().quit.call_deferred(0 if _failures.is_empty() else 1)

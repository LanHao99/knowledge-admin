extends Node
## 在隔离工程中通过真实输入和 GPU 像素验证整窗破损、快照及独立碎片。

var _desktop: Control
var _effects: DesktopWindowEffects
var _effect: WindowShatterEffect
var _previous_window: WeakRef
var _previous_content: WeakRef
var _checks: int = 0
var _failures: Array[String] = []
var _cases: Array[Dictionary] = []
var _output: String = "user://window_effects_review"


## 延迟执行验收，保证全部 Autoload 和根视口已就绪。## 输入: 无。输出: 无。
func _ready() -> void:
	_run.call_deferred()


## 只在隔离工程运行六组尺寸字号以及画布缩放验收。## 输入: 无。输出: 无。
func _run() -> void:
	if ProjectSettings.get_setting("application/config/name") != "KnowledgeAdminDesktopVerification":
		push_error("窗口特效验收必须使用隔离工程")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	UiSettings.settings_path = "user://window_effects_ui.cfg"
	_desktop = load("res://content/scenes/desktop/desktop.tscn").instantiate() as Control
	add_child(_desktop)
	_effects = _desktop.get_node("WindowEffects") as DesktopWindowEffects
	_effects.effect_started.connect(_on_effect_started)
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		for font_scale: float in [0.8, 1.0, 1.5]:
			await _verify_case(resolution, font_scale, false)
	await _verify_case(Vector2i(1280, 720), 1.0, true)
	_finish()


## 检查单组窗口的输入、裂纹、恢复、碎裂与重新打开。## 输入: 分辨率、字号和是否使用 1920 逻辑画布。输出: 无。
func _verify_case(resolution: Vector2i, font_scale: float, stretched: bool) -> void:
	get_tree().root.size = resolution
	get_tree().root.content_scale_size = Vector2i(1920, 1080) if stretched else resolution
	UiSettings.set_font_scale(font_scale)
	await _frames()
	var label: String = "%dx%d_%03d%s" % [resolution.x, resolution.y, roundi(font_scale * 100.0), "_stretched" if stretched else ""]
	_check(WindowManager.open_app("window_lab"), label + " 打开应用")
	await _frames()
	var window: ManagedWindow = WindowManager.get_app_window("window_lab")
	window.size = Vector2(900, 620).min((window.get_parent() as Control).size)
	window.position = (((window.get_parent() as Control).size - window.size) * 0.5).round()
	window.fit_work_area()
	var page: Control = window.get_content()
	var sample: TextEdit = page.get_node("%SampleText") as TextEdit
	sample.text = "META WINDOW / 整个界面一起破碎\n可以在破损后继续输入。"
	await _frames()
	var intact: Image = await _capture(label + "_intact")
	await _click((page.get_node("%DamageButton") as Button).get_global_rect().get_center())
	_check(window.damage_amount > 0.0, label + " 真实点击启用局部破损")
	var damaged: Image = await _capture(label + "_damaged")
	_check(_black_fraction(damaged, window.get_global_rect()) < 0.15, label + " 破损画面无未初始化黑色区域")
	var title_rect: Rect2 = (window.get_node("%TitleBarPanel") as Control).get_global_rect()
	_check(_different_pixels(intact, damaged, title_rect) > 15, label + " 标题栏也出现裂纹")
	await _verify_partial_impact(window, label)
	await _verify_live_input(window, sample, label)
	var before_restore: Rect2 = Rect2(window.position, window.size)
	var saved_text: String = sample.text
	(page.get_node("Scroll") as ScrollContainer).scroll_vertical = 0
	await _frames()
	await _click((page.get_node("%RestoreButton") as Button).get_global_rect().get_center())
	_check(is_zero_approx(window.damage_amount) and sample.text == saved_text, label + " 恢复保留输入")
	_check(Rect2(window.position, window.size) == before_restore, label + " 恢复保留布局")
	if font_scale >= 1.5:
		window._on_maximize_pressed()
		await _frames()
		_check(window.size.is_equal_approx((window.get_parent() as Control).size), label + " 最大化后破碎")
	if font_scale >= 1.0:
		WindowManager.set_app_damage("window_lab", 0.7)
	await _frames()
	await _verify_shatter(window, label)
	_cases.append({"name": label, "resolution": [resolution.x, resolution.y], "font_scale": font_scale, "stretched": stretched})


## 从实际画面验证整窗反向抖动和原位恢复，UI 不与边框分离。## 输入: 窗口与标签。输出: 无。
func _verify_partial_impact(window: ManagedWindow, label: String) -> void:
	window.play_impact()
	window.set_process(false)
	var origin: Vector2 = window.position
	var title: Control = window.get_node("%TitleBar") as Control
	var sample: Control = window.get_content().get_node("%SampleText") as Control
	var title_origin: Vector2 = title.global_position
	var sample_origin: Vector2 = sample.global_position
	window._process(0.012)
	var offset: Vector2 = window.position - origin
	_check(offset.length() > 4.0, label + " 局部破损触发可见整窗冲击")
	_check((title.global_position - title_origin).is_equal_approx(offset) and (sample.global_position - sample_origin).is_equal_approx(offset), label + " 标题与输入区跟随同一震动")
	var first: Image = await _capture(label + "_damage_impact")
	window._process(0.025)
	var second: Image = await _capture(label + "_damage_recoil")
	_check((window.position - origin).x * offset.x < 0.0, label + " 冲击向相反方向回弹")
	_check(_different_pixels(first, second, Rect2(origin, window.size)) > 500, label + " GPU 画面真实抖动")
	window._process(window.impact_duration)
	_check(window.position == origin and not window.is_processing(), label + " 震动结束精确回到原位")


## 通过键盘和鼠标证明局部破损仍保留输入与标题栏拖动。## 输入: 窗口、示例输入和标签。输出: 无。
func _verify_live_input(window: ManagedWindow, sample: TextEdit, label: String) -> void:
	var scroll: ScrollContainer = window.get_content().get_node("Scroll") as ScrollContainer
	scroll.ensure_control_visible(sample)
	await _frames()
	await _click(sample.get_global_rect().position + Vector2(40, 20))
	var previous: String = sample.text
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_X
	key.unicode = 120
	key.pressed = true
	get_tree().root.push_input(key, true)
	key.pressed = false
	get_tree().root.push_input(key, true)
	await _frames()
	_check(sample.text != previous, label + " 破损后仍可输入")
	var original: Vector2 = window.position
	await _drag((window.get_node("%TitleBar") as Control).get_global_rect().position + Vector2(65, 15), Vector2(30, 10))
	_check(window.position != original, label + " 破损后仍可拖动")


## 检查应用先释放，再显示快照碎片，最后清理不影响新实例。## 输入: 窗口和标签。输出: 无。
func _verify_shatter(window: ManagedWindow, label: String) -> void:
	_previous_window = weakref(window)
	_previous_content = weakref(window.get_content())
	_effect = null
	_send_click((window.get_content().get_node("%ShatterButton") as Button).get_global_rect().get_center())
	_check(window.is_shattering(), label + " 真实点击接受完全破碎")
	_check(window.process_mode == Node.PROCESS_MODE_DISABLED, label + " 当场冻结应用")
	_check(not WindowManager.shatter_app("window_lab"), label + " 重复请求被拒绝")
	var deadline: int = Time.get_ticks_msec() + 3000
	while _effect == null and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if _effect == null:
		_check(false, label + " 未生成碎片")
		return
	var zero: Image = await _capture(label + "_shards_start")
	_check(_snapshot_matches(_effect, zero), label + " 第一帧碎片保留完整窗口像素")
	_effect._process(0.012)
	var impact_material: ShaderMaterial = _effect.material as ShaderMaterial
	var impact_offset: Vector2 = impact_material.get_shader_parameter("impact_offset")
	_check(impact_offset.length() > 8.0 and is_zero_approx(float(impact_material.get_shader_parameter("progress"))), label + " 完全破碎先整窗猛烈震动")
	var impact: Image = await _capture(label + "_shatter_impact")
	_check(_different_pixels(zero, impact, Rect2(Vector2.ZERO, get_tree().root.get_visible_rect().size)) > 1000, label + " 原应用释放后快照继续抖动")
	_effect._process(0.6 - _effect.elapsed)
	var falling: Image = await _capture(label + "_falling")
	_check(_different_pixels(zero, falling, Rect2(Vector2.ZERO, get_tree().root.get_visible_rect().size)) > 1000, label + " 碎片真实移动")
	_check(WindowManager.open_app("recycle_bin"), label + " 碎裂期间其他应用可打开")
	await _frames()
	var other: ManagedWindow = WindowManager.get_app_window("recycle_bin")
	var previous_position: Vector2 = other.position
	await _drag((other.get_node("%TitleBar") as Control).get_global_rect().position + Vector2(60, 15), Vector2(25, 10))
	_check(other.position != previous_position, label + " 碎裂期间其他应用仍可操作")
	_check(WindowManager.open_app("window_lab"), label + " 动画期间可重新打开")
	var fresh: ManagedWindow = WindowManager.get_app_window("window_lab")
	_check(is_zero_approx(fresh.damage_amount), label + " 新实例完整")
	var old_effect: WeakRef = weakref(_effect)
	_effect._process(3.0)
	await _frames()
	_check(old_effect.get_ref() == null, label + " 快照和碎片完成清理")
	_check(WindowManager.get_app_window("window_lab") == fresh, label + " 清理不会关闭新实例")
	await _capture(label + "_reopened")
	WindowManager.close_app("window_lab")
	WindowManager.close_app("recycle_bin")
	await _frames()


## 在特效出现的同一时刻确认旧窗口和内容都已经释放。## 输入: 新碎片实例。输出: 无。
func _on_effect_started(effect: WindowShatterEffect) -> void:
	_effect = effect
	effect.set_process(false)
	_check(_previous_window.get_ref() == null, "碎片第一帧前旧窗口已释放")
	_check(_previous_content.get_ref() == null, "碎片第一帧前旧 UI 已释放")
	_check(WindowManager.get_app_window("window_lab") == null, "碎片第一帧前注册表已移除")
	_check(not _desktop.get_node("%Taskbar")._app_buttons.has("window_lab"), "碎片第一帧前任务按钮已移除")
	_check(effect.shard_count == 80, "完整窗口生成 80 块不规则碎片")


## 对比快照与零时刻的真实 GPU 输出，发现错误 UV、颜色和尺寸映射。## 输入: 碎片和屏幕图像。输出: 是否基本一致。
func _snapshot_matches(effect: WindowShatterEffect, screen: Image) -> bool:
	var source: Image = effect.texture.get_image()
	var shader_material: ShaderMaterial = effect.material as ShaderMaterial
	var extent: Vector2 = shader_material.get_shader_parameter("source_size")
	var ratio: Vector2 = Vector2(screen.get_size()) / get_tree().root.get_visible_rect().size
	var matched: int = 0
	var total: int = 0
	for row: int in range(4, source.get_height() - 4, 13):
		for column: int in range(4, source.get_width() - 4, 13):
			var at: Vector2i = Vector2i((effect.position + Vector2(column, row) / Vector2(source.get_size()) * extent) * ratio)
			if Rect2i(Vector2i.ZERO, screen.get_size()).has_point(at):
				total += 1
				if _same_color(source.get_pixel(column, row), screen.get_pixelv(at)):
					matched += 1
	return total > 100 and float(matched) / float(total) > 0.95


## 在指定逻辑区域统计发生改变的像素。## 输入: 两帧图像和逻辑矩形。输出: 改变像素数量。
func _different_pixels(first: Image, second: Image, region: Rect2) -> int:
	var ratio: Vector2 = Vector2(first.get_size()) / get_tree().root.get_visible_rect().size
	var pixels: Rect2i = Rect2i(Vector2i(region.position * ratio), Vector2i(region.size * ratio)).intersection(Rect2i(Vector2i.ZERO, first.get_size()))
	var changed: int = 0
	for row: int in range(pixels.position.y, pixels.end.y, 2):
		for column: int in range(pixels.position.x, pixels.end.x, 2):
			if not _same_color(first.get_pixel(column, row), second.get_pixel(column, row)):
				changed += 1
	return changed


## 容许纹理采样和颜色转换带来的微小差异。## 输入: 两个颜色。输出: 是否接近。
func _same_color(first: Color, second: Color) -> bool:
	return absf(first.r - second.r) + absf(first.g - second.g) + absf(first.b - second.b) < 0.08


## 检查屏幕复制是否遗漏窗口右侧或底部。## 输入: 屏幕与窗口区域。输出: 黑色像素占比。
func _black_fraction(picture: Image, region: Rect2) -> float:
	var ratio: Vector2 = Vector2(picture.get_size()) / get_tree().root.get_visible_rect().size
	var pixels: Rect2i = Rect2i(Vector2i(region.position * ratio), Vector2i(region.size * ratio)).intersection(Rect2i(Vector2i.ZERO, picture.get_size()))
	var black: int = 0
	var total: int = 0
	for row: int in range(pixels.position.y, pixels.end.y, 5):
		for column: int in range(pixels.position.x, pixels.end.x, 5):
			var color: Color = picture.get_pixel(column, row)
			total += 1
			if color.r + color.g + color.b < 0.05:
				black += 1
	return float(black) / float(maxi(1, total))


## 等待布局完成。## 输入: 帧数。输出: 无。
func _frames(count: int = 5) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


## 注入完整鼠标点击，不直接调用按钮处理函数。## 输入: 逻辑坐标。输出: 无。
func _click(point: Vector2) -> void:
	_send_click(point)
	await _frames()


## 同步注入鼠标事件，允许检查点击当场的冻结状态。## 输入: 逻辑坐标。输出: 无。
func _send_click(point: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	get_tree().root.push_input(motion, true)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_tree().root.push_input(event, true)
	event.pressed = false
	get_tree().root.push_input(event, true)


## 注入标题栏的按下、移动和释放。## 输入: 起点与位移。输出: 无。
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
	event.global_position = point + movement
	event.pressed = false
	get_tree().root.push_input(event, true)
	await _frames()


## 保存 GPU 渲染图像作为可复查证据。## 输入: 文件名。输出: 屏幕图像。
func _capture(filename: String) -> Image:
	await RenderingServer.frame_post_draw
	var picture: Image = get_tree().root.get_texture().get_image()
	picture.save_png(_output.path_join(filename + ".png"))
	return picture


## 记录断言，保留全部失败以便集中修复。## 输入: 条件与描述。输出: 无。
func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
		print("WINDOW_EFFECTS_CHECK_FAILED: ", description)


## 输出机器可读报告并以测试状态退出隔离进程。## 输入: 无。输出: 无。
func _finish() -> void:
	var report: Dictionary = {"checks": _checks, "failures": _failures, "cases": _cases, "engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method()}
	var file: FileAccess = FileAccess.open(_output.path_join("verification.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("WINDOW_EFFECTS_VERIFICATION: ", JSON.stringify(report))
	get_tree().quit.call_deferred(0 if _failures.is_empty() else 1)

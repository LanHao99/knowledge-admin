extends GutTest
## 使用隔离桌面测试破损、冻结、释放和快照失败的生命周期。

class ImportingPage extends Control:
	## 模拟正在写入的导入向导。## 输入: 无。输出: true。
	func is_importing() -> bool:
		return true

class StudyingPage extends Control:
	## 模拟尚未结束的学习会话。## 输入: 无。输出: true。
	func desktop_has_active_session() -> bool:
		return true

var _desktop: Control


## 构造真实桌面，但不启动学习或访问玩家数据库。## 输入: 无。输出: 无。
func before_each() -> void:
	_desktop = load("res://scenes/desktop/desktop.tscn").instantiate() as Control
	_desktop.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_desktop.size = Vector2(1280, 720)
	add_child_autofree(_desktop)
	assert_true(WindowManager.open_app("window_lab"))


## 注册表同时为桌面和开始菜单提供新应用入口。## 输入: 无。输出: 无。
func test_lab_registry_and_single_instance() -> void:
	assert_true(WindowManager.REGISTRY.window_lab.entry_visible)
	assert_eq(WindowManager.REGISTRY.window_lab.default_size, Vector2(900, 620))
	var window: ManagedWindow = WindowManager.get_app_window("window_lab")
	assert_true(WindowManager.open_app("window_lab"))
	assert_same(window, WindowManager.get_app_window("window_lab"))
	assert_not_null(window.get_content().get_node("%ShatterButton"))


## 破损和恢复不重建页面，也不丢失文本、布局及交互。## 输入: 无。输出: 无。
func test_damage_restore_preserves_content_and_layout() -> void:
	var window: ManagedWindow = WindowManager.get_app_window("window_lab")
	var page: Control = window.get_content()
	var sample: TextEdit = page.get_node("%SampleText") as TextEdit
	sample.text = "保留这段输入"
	var bounds: Rect2 = Rect2(window.position, window.size)
	assert_true(WindowManager.set_app_damage("window_lab", 0.7))
	assert_eq(window.damage_amount, 0.7)
	assert_true(window.get_node("DamageOverlay").visible)
	assert_eq(window.get_node("DamageCopy").copy_mode, BackBufferCopy.COPY_MODE_VIEWPORT)
	assert_ne(window.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_eq(window.get_node("DamageOverlay").mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_true(WindowManager.set_app_damage("window_lab", 0.7))
	assert_true(WindowManager.set_app_damage("window_lab", 0.0))
	assert_false(window.get_node("DamageOverlay").visible)
	assert_eq(window.get_node("DamageCopy").copy_mode, BackBufferCopy.COPY_MODE_DISABLED)
	assert_same(page, window.get_content())
	assert_eq(sample.text, "保留这段输入")
	assert_eq(Rect2(window.position, window.size), bounds)
	assert_false(WindowManager.set_app_damage("window_lab", NAN))


## 每个窗口持有独立材质，损伤不能扩散到其他应用。## 输入: 无。输出: 无。
func test_damage_is_isolated_per_window() -> void:
	WindowManager.open_app("recycle_bin")
	var lab: ManagedWindow = WindowManager.get_app_window("window_lab")
	var other: ManagedWindow = WindowManager.get_app_window("recycle_bin")
	WindowManager.set_app_damage("window_lab", 0.7)
	assert_not_same(lab.get_node("DamageOverlay").material, other.get_node("DamageOverlay").material)
	assert_eq(other.damage_amount, 0.0)
	assert_false(other.get_node("DamageOverlay").visible)


## 接受请求后立即禁止交互，重复关闭和恢复不能绕过冻结。## 输入: 无。输出: 无。
func test_shatter_freezes_then_closes_once_and_can_reopen() -> void:
	var window: ManagedWindow = WindowManager.get_app_window("window_lab")
	var previous: WeakRef = weakref(window)
	var page: WeakRef = weakref(window.get_content())
	var always_child: Node = Node.new()
	always_child.process_mode = Node.PROCESS_MODE_ALWAYS
	window.add_child(always_child)
	watch_signals(WindowManager)
	assert_true(WindowManager.shatter_app("window_lab"))
	assert_true(window.is_shattering())
	assert_eq(window.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_eq(always_child.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_false(WindowManager.shatter_app("window_lab"))
	assert_false(WindowManager.set_app_damage("window_lab", 0.0))
	assert_false(WindowManager.open_app("window_lab"))
	assert_eq(window.navigate_to("res://scenes/desktop/recycle_bin.tscn"), ERR_BUSY)
	window._on_minimize_pressed()
	window._on_maximize_pressed()
	assert_false(window.is_minimized())
	WindowManager.close_app("window_lab")
	assert_not_null(WindowManager.get_app_window("window_lab"))
	await wait_process_frames(5)
	assert_null(WindowManager.get_app_window("window_lab"))
	assert_null(previous.get_ref())
	assert_null(page.get_ref())
	assert_signal_emit_count(WindowManager, "app_closed", 1)
	assert_false(_desktop.get_node("%Taskbar")._app_buttons.has("window_lab"))
	assert_true(WindowManager.open_app("window_lab"))
	assert_eq(WindowManager.get_app_window("window_lab").damage_amount, 0.0)


## 正式剧情、来源帮助、导入和学习会话均受到保护。## 输入: 无。输出: 无。
func test_effects_respect_business_locks() -> void:
	WindowManager._story_locked = true
	assert_false(WindowManager.set_app_damage("window_lab", 0.7))
	assert_false(WindowManager.shatter_app("window_lab"))
	WindowManager._story_locked = false
	WindowManager._help_owner = "window_lab"
	assert_false(WindowManager.shatter_app("window_lab"))
	WindowManager._help_owner = ""
	var window: ManagedWindow = WindowManager.get_app_window("window_lab")
	var importer: Control = ImportingPage.new()
	window.get_content().add_child(importer)
	assert_false(WindowManager.shatter_app("window_lab"))
	importer.free()
	var original: Control = window.get_content()
	window.get_node("%ContentArea").remove_child(original)
	var studying: Control = StudyingPage.new()
	window.get_node("%ContentArea").add_child(studying)
	assert_false(WindowManager.shatter_app("window_lab"))
	original.free()
	assert_false(WindowManager.shatter_app("unknown_program"))
	assert_false(WindowManager.shatter_app("missing_app"))


## 陈旧回调只认原实例标识，不能关闭重新打开的应用。## 输入: 无。输出: 无。
func test_stale_callback_cannot_close_new_instance() -> void:
	var old_id: int = WindowManager.get_app_window("window_lab").get_instance_id()
	WindowManager.close_app("window_lab")
	WindowManager.open_app("window_lab")
	var current: ManagedWindow = WindowManager.get_app_window("window_lab")
	WindowManager._pending_shatters["window_lab"] = old_id
	WindowManager._finish_shatter("window_lab", old_id)
	assert_same(WindowManager.get_app_window("window_lab"), current)
	await wait_process_frames(2)


## 最小化、关闭锁和可见确认框均阻止视觉操作绕过窗口状态。## 输入: 无。输出: 无。
func test_effects_reject_hidden_locked_or_popup_windows() -> void:
	var window: ManagedWindow = WindowManager.get_app_window("window_lab")
	window._on_minimize_pressed()
	assert_false(WindowManager.set_app_damage("window_lab", 0.7))
	assert_false(WindowManager.shatter_app("window_lab"))
	window.restore()
	window.set_close_locked(true)
	assert_false(WindowManager.shatter_app("window_lab"))
	window.set_close_locked(false)
	var popup: AcceptDialog = AcceptDialog.new()
	window.add_child(popup)
	popup.popup_centered(Vector2i(200, 100))
	assert_false(WindowManager.shatter_app("window_lab"))
	popup.hide()
	popup.queue_free()


## Delaunay 分区无重叠地覆盖整窗，UV 与原始像素一一对应。## 输入: 无。输出: 无。
func test_shard_mesh_covers_whole_snapshot_and_keeps_uv() -> void:
	var picture: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	picture.fill(Color.WHITE)
	var effect: WindowShatterEffect = autofree(WindowShatterEffect.new())
	var extent: Vector2 = Vector2(900, 620)
	assert_true(effect.configure(ImageTexture.create_from_image(picture), Rect2(Vector2(100, 80), extent), Vector2i(8, 5), 712, 1800.0, 190.0, 130.0, 3.0))
	assert_eq(effect.shard_count, 80)
	var arrays: Array = (effect.mesh as ArrayMesh).surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var area: float = 0.0
	for index: int in range(0, vertices.size(), 3):
		var first: Vector2 = Vector2(vertices[index].x, vertices[index].y)
		var second: Vector2 = Vector2(vertices[index + 1].x, vertices[index + 1].y)
		var third: Vector2 = Vector2(vertices[index + 2].x, vertices[index + 2].y)
		area += absf((second - first).cross(third - first)) * 0.5
		assert_almost_eq(uvs[index], first / extent, Vector2.ONE * 0.00001)
	assert_almost_eq(area, extent.x * extent.y, 1.0)
	assert_false(effect.all_shards_below(1080.0))
	effect.elapsed = 2.0
	assert_true(effect.all_shards_below(1080.0))

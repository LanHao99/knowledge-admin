extends GutTest
## 摄像头画面的配置隔离、立绘替换及方形宿主几何验证。


## 空图片可在运行时接入与移除，透明贴图尺寸不改变控制布局。## 输入: 无。输出: 无。
func test_portrait_can_connect_and_disconnect() -> void:
	var camera: Control = add_child_autofree(load("res://content/scenes/desktop/camera.tscn").instantiate())
	camera.set("portrait_texture", null)
	assert_true((camera.get_node("%WaitingSignal") as Label).visible)
	var image: Image = Image.create(64, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 0, 0, 0.5))
	var portrait: ImageTexture = ImageTexture.create_from_image(image)
	camera.set("portrait_texture", portrait)
	var feed_material: ShaderMaterial = (camera.get_node("%Screen") as ColorRect).material as ShaderMaterial
	assert_false((camera.get_node("%WaitingSignal") as Label).visible)
	assert_true(feed_material.get_shader_parameter("has_portrait"))
	assert_same(feed_material.get_shader_parameter("portrait_texture"), portrait)
	assert_eq(feed_material.get_shader_parameter("portrait_aspect"), 0.5)
	camera.set("portrait_texture", null)
	assert_true((camera.get_node("%WaitingSignal") as Label).visible)
	assert_false(feed_material.get_shader_parameter("has_portrait"))


## 编辑一个摄像头的参数不能污染其他场景实例。## 输入: 无。输出: 无。
func test_crt_material_is_independent_per_instance() -> void:
	var scene: PackedScene = load("res://content/scenes/desktop/camera.tscn")
	var first: Control = add_child_autofree(scene.instantiate())
	var second: Control = add_child_autofree(scene.instantiate())
	first.set("scanlines_opacity", 0.8)
	first.set("portrait_zoom", 1.8)
	first.set("portrait_offset", Vector2(0.1, -0.2))
	first.set("crt_enabled", false)
	var first_material: ShaderMaterial = (first.get_node("%Screen") as ColorRect).material as ShaderMaterial
	var second_material: ShaderMaterial = (second.get_node("%Screen") as ColorRect).material as ShaderMaterial
	assert_not_same(first_material, second_material)
	assert_almost_eq(float(first_material.get_shader_parameter("scanlines_opacity")), 0.8, 0.001)
	assert_almost_eq(float(second_material.get_shader_parameter("scanlines_opacity")), 0.22, 0.001)
	assert_eq(first_material.get_shader_parameter("portrait_offset"), Vector2(0.1, -0.2))
	assert_false(first_material.get_shader_parameter("crt_enabled"))
	assert_true(second_material.get_shader_parameter("crt_enabled"))


## 虚拟分辨率不能为零，防止像素化除零。## 输入: 无。输出: 无。
func test_resolution_rejects_zero_dimensions() -> void:
	var camera: Control = add_child_autofree(load("res://content/scenes/desktop/camera.tscn").instantiate())
	camera.set("resolution", Vector2(0, -10))
	assert_eq(camera.get("resolution"), Vector2.ONE)


## 八向拖动均保持方形，左侧与上侧拖动不漂移对边。## 输入: 无。输出: 无。
func test_square_resize_preserves_shape_and_opposite_edges() -> void:
	var original: Rect2 = Rect2(100, 80, 560, 560)
	for direction: int in range(1, 9):
		var result: Rect2 = ManagedWindow.resized_rect(original, Vector2(45, 30), direction, Vector2(320, 320), true)
		assert_eq(result.size.x, result.size.y, "方形缩放方向 %d" % direction)
		if direction in [ManagedWindow.ResizeDir.LEFT, ManagedWindow.ResizeDir.TOP_LEFT, ManagedWindow.ResizeDir.BOTTOM_LEFT]:
			assert_eq(result.end.x, original.end.x)
		if direction in [ManagedWindow.ResizeDir.TOP, ManagedWindow.ResizeDir.TOP_LEFT, ManagedWindow.ResizeDir.TOP_RIGHT]:
			assert_eq(result.end.y, original.end.y)
	var minimum: Rect2 = ManagedWindow.resized_rect(original, Vector2(999, 999), ManagedWindow.ResizeDir.TOP_LEFT, Vector2(320, 320), true)
	assert_eq(minimum.size, Vector2(320, 320))
	assert_eq(minimum.end, original.end)


## 最大化、还原及小工作区均保持整窗方形且不覆盖任务栏。## 输入: 无。输出: 无。
func test_square_window_fits_work_area_and_restores() -> void:
	var area: Control = add_child_autofree(Control.new())
	area.size = Vector2(1280, 672)
	var window: ManagedWindow = load("res://content/scenes/desktop/managed_window.tscn").instantiate() as ManagedWindow
	window.keep_square = true
	window.default_size = Vector2(560, 560)
	window.min_window_size = Vector2(320, 320)
	area.add_child(window)
	window.initialize("camera", "摄像头", "res://content/scenes/desktop/camera.tscn")
	var original: Rect2 = Rect2(window.position, window.size)
	window._on_maximize_pressed()
	assert_eq(window.size, Vector2(672, 672))
	assert_true(Rect2(Vector2.ZERO, area.size).encloses(Rect2(window.position, window.size)))
	window._on_maximize_pressed()
	assert_eq(Rect2(window.position, window.size), original)
	area.size = Vector2(280, 240)
	window.fit_work_area()
	assert_eq(window.size, Vector2(240, 240))
	assert_true(Rect2(Vector2.ZERO, area.size).encloses(Rect2(window.position, window.size)))

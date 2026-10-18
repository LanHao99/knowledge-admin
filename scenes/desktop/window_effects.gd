class_name DesktopWindowEffects
extends Control
## 桌面级的一次性捕获与碎片层，不依赖已经结束的应用实例。

signal effect_started(effect: WindowShatterEffect)

const CAPTURE_Z_INDEX: int = 200
const SHATTER_SCRIPT: Script = preload("res://scenes/desktop/window_shatter.gd")

@export var shard_grid: Vector2i = Vector2i(8, 5)
@export_range(100.0, 5000.0, 50.0) var gravity: float = 1800.0
@export_range(0.0, 1000.0, 10.0) var horizontal_speed: float = 190.0
@export_range(0.0, 600.0, 10.0) var initial_lift: float = 130.0
@export_range(0.0, 10.0, 0.1) var spin_speed: float = 3.0
@export_group("Impact")
@export_range(0.0, 80.0, 1.0) var impact_amplitude: float = 24.0
@export_range(0.0, 1.0, 0.01, "suffix:s") var impact_duration: float = 0.18
@export_range(1.0, 60.0, 1.0, "suffix:Hz") var impact_frequency: float = 24.0
var is_capturing: bool = false


## 等待完整窗口绘制，关闭真实应用后才开始独立碎片动画。## 输入: 目标窗口、关闭回调。输出: 无。
func capture_and_shatter(window: ManagedWindow, close_callback: Callable) -> void:
	var scene_tree: SceneTree = get_tree()
	is_capturing = true
	window.z_as_relative = false
	window.z_index = CAPTURE_Z_INDEX
	if DisplayServer.get_name() == "headless":
		await scene_tree.process_frame
	else:
		await RenderingServer.frame_post_draw
	var capture: Dictionary = _read_window(window)
	var effect: WindowShatterEffect
	if not capture.is_empty():
		effect = SHATTER_SCRIPT.new() as WindowShatterEffect
		if effect.configure(capture.snapshot, capture.target, shard_grid, randi(), gravity, horizontal_speed, initial_lift, spin_speed):
			effect.configure_impact(impact_amplitude, impact_duration, impact_frequency)
			add_child(effect)
			effect.set_process(false)
		else:
			effect.queue_free()
			effect = null
	is_capturing = false
	close_callback.call()
	if effect == null or not is_inside_tree():
		return
	while is_instance_valid(window):
		await scene_tree.process_frame
	if is_instance_valid(effect) and is_inside_tree():
		effect.set_process(true)
		effect_started.emit(effect)


## 将目标窗口在当前帧的完整像素映射到桌面特效坐标。## 输入: 冻结的窗口。输出: 快照和目标矩形；失败时为空字典。
func _read_window(window: ManagedWindow) -> Dictionary:
	var modal: CanvasItem = get_parent().get_node_or_null("ModalLayer") as CanvasItem
	var obscured: bool = modal != null and modal.is_visible_in_tree()
	if DisplayServer.get_name() == "headless" or obscured or not is_instance_valid(window) or not window.is_inside_tree():
		return {}
	var viewport: Viewport = window.get_viewport()
	var picture: Image = viewport.get_texture().get_image()
	if picture == null or picture.is_empty():
		return {}
	var ratio: Vector2 = Vector2(picture.get_size()) / viewport.get_visible_rect().size
	var window_rect: Rect2 = window.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, window.size)
	var pixel_start: Vector2i = Vector2i((window_rect.position * ratio).floor())
	var pixel_end: Vector2i = Vector2i((window_rect.end * ratio).ceil())
	var pixel_rect: Rect2i = Rect2i(pixel_start, pixel_end - pixel_start).intersection(Rect2i(Vector2i.ZERO, picture.get_size()))
	if not pixel_rect.has_area():
		return {}
	var snapshot: ImageTexture = ImageTexture.create_from_image(picture.get_region(pixel_rect))
	var viewport_rect: Rect2 = Rect2(Vector2(pixel_rect.position) / ratio, Vector2(pixel_rect.size) / ratio)
	var target: Rect2 = get_global_transform_with_canvas().affine_inverse() * viewport_rect
	return {"snapshot": snapshot, "target": target}

class_name ManagedWindow
extends Control
## 场景组成的游戏内窗口，负责拖动、八向缩放和内容页生命周期。

signal close_requested
signal window_clicked
signal minimized
signal restored

enum ResizeDir { NONE, TOP, BOTTOM, LEFT, RIGHT, TOP_LEFT, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_RIGHT }
@export var default_size: Vector2 = Vector2(1200, 820)
@export var min_window_size: Vector2 = Vector2(720, 500)
@export var keep_square: bool = false
@export var taskbar_height: float = 48.0
@export_group("Impact")
@export_range(0.0, 80.0, 1.0) var impact_amplitude: float = 14.0
@export_range(0.0, 1.0, 0.01, "suffix:s") var impact_duration: float = 0.26
@export_range(1.0, 60.0, 1.0, "suffix:Hz") var impact_frequency: float = 22.0

var _app_id: String = ""
var _is_maximized: bool = false
var _is_minimized: bool = false
var _close_locked: bool = false
var _minimize_locked: bool = false
var _pre_max_rect: Rect2
var _current_scene_path: String = ""
var _is_dragging: bool = false
var _resize_dir: int = ResizeDir.NONE
var _gesture_rect: Rect2
var _gesture_mouse: Vector2
var _last_focus: WeakRef
var damage_amount: float = 0.0
var _is_shattering: bool = false
var _impact_active: bool = false
var _impact_elapsed: float = 0.0
var _impact_origin: Vector2
@onready var _title_label: Label = %TitleLabel
@onready var _title_bar_panel: Panel = %TitleBarPanel
@onready var _content_area: Control = %ContentArea

## 连接标题栏、按钮和场景中的八个缩放区域。## 输入: 无。输出: 无。
func _ready() -> void:
	%CloseButton.pressed.connect(_on_close_pressed)
	%MinimizeButton.pressed.connect(_on_minimize_pressed)
	%MaximizeButton.pressed.connect(_on_maximize_pressed)
	%TitleBar.gui_input.connect(_on_title_bar_gui_input)
	for handle: Control in $ResizeHandles.get_children():
		handle.gui_input.connect(_on_resize_input.bind(int(handle.get_meta("direction"))))
	get_parent().resized.connect(fit_work_area)
	UiSettings.font_scale_changed.connect(_update_typography)
	_update_typography(UiSettings.font_scale)
	resized.connect(_sync_damage_geometry)
	_sync_damage_geometry()
	set_process(false)

## 从当前位置开始短促的整窗震动，重复冲击不会积累位置误差。## 输入: 无。输出: 无。
func play_impact() -> void:
	stop_impact()
	if _is_shattering or impact_amplitude <= 0.0 or impact_duration <= 0.0:
		return
	_impact_origin = position
	_impact_elapsed = 0.0
	_impact_active = true
	set_process(true)

## 结束冲击并精确恢复业务布局坐标。## 输入: 无。输出: 无。
func stop_impact() -> void:
	if _impact_active:
		position = _impact_origin
	_impact_active = false
	set_process(false)

## 整体移动标题栏、边框、内容与输入区域，震动结束后恢复原位。## 输入: 帧间隔。输出: 无。
func _process(delta: float) -> void:
	if not _impact_active:
		return
	_impact_elapsed += delta
	if _impact_elapsed >= impact_duration:
		stop_impact()
		return
	position = _impact_origin + WindowImpact.sample_offset(_impact_elapsed, impact_amplitude, impact_duration, impact_frequency)

## 对完整窗口启用或移除实时玻璃破损。## 输入: 损伤强度，范围 0 到 1。输出: 无。
func set_damage(amount: float) -> void:
	if _is_shattering or not is_finite(amount):
		return
	damage_amount = clampf(amount, 0.0, 1.0)
	$DamageOverlay.visible = damage_amount > 0.0
	$DamageCopy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT if damage_amount > 0.0 else BackBufferCopy.COPY_MODE_DISABLED
	($DamageOverlay.material as ShaderMaterial).set_shader_parameter("damage", damage_amount)
	_sync_damage_geometry()
	if damage_amount > 0.0:
		play_impact()
	else:
		stop_impact()

## 同步局部破损着色器使用的窗口像素尺寸。## 输入: 无。输出: 无。
func _sync_damage_geometry() -> void:
	($DamageOverlay.material as ShaderMaterial).set_shader_parameter("window_size", size)

## 标记不可逆的关闭状态并冻结输入，保留一帧画面用于快照。## 输入: 无。输出: 无。
func begin_shatter() -> void:
	stop_impact()
	_is_shattering = true
	_is_dragging = false
	_resize_dir = ResizeDir.NONE
	_last_focus = null
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()
	_freeze_subtree(self)
	$ShatterInputBlocker.show()
	$ShatterInputBlocker.mouse_filter = Control.MOUSE_FILTER_STOP

## 禁用包含 ALWAYS 子节点在内的业务处理和键盘焦点。## 输入: 子树根。输出: 无。
func _freeze_subtree(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is Control:
		(node as Control).focus_mode = Control.FOCUS_NONE
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_freeze_subtree(child)

## 查询窗口是否已接受不可逆的完全破碎请求。## 输入: 无。输出: bool。
func is_shattering() -> bool:
	return _is_shattering

## 装载起始页并居中。## 输入: 应用 ID、标题、场景路径。输出: 无。
func initialize(app_id: String, title_text: String, scene_path: String) -> void:
	_app_id = app_id
	_title_label.text = title_text
	size = default_size.min((get_parent() as Control).size)
	if keep_square:
		size = Vector2.ONE * minf(size.x, size.y)
	position = (((get_parent() as Control).size - size) * 0.5).round()
	navigate_to(scene_path)
	fit_work_area()

## 加载新内容，加载失败时保留原页面。## 输入: path。输出: Godot 错误码。
func navigate_to(path: String) -> int:
	if _is_shattering:
		return ERR_BUSY
	if not ResourceLoader.exists(path):
		return ERR_FILE_NOT_FOUND
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return ERR_FILE_CANT_OPEN
	var instance: Control = packed.instantiate() as Control
	if instance == null:
		return ERR_INVALID_DATA
	for child: Node in _content_area.get_children():
		_content_area.remove_child(child)
		child.queue_free()
	_current_scene_path = path
	_content_area.add_child(instance)
	instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return OK

## 读取当前页面。## 输入: 无。输出: 内容 Control 或 null。
func get_content() -> Control:
	return _content_area.get_child(0) as Control if _content_area.get_child_count() > 0 else null

## 切换标题色并保存或恢复实际键盘焦点。## 输入: active。输出: 无。
func set_window_active(active: bool) -> void:
	if _is_shattering:
		return
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("000080") if active else Color("808080")
	_title_bar_panel.add_theme_stylebox_override("panel", style)
	var focused: Control = get_viewport().gui_get_focus_owner()
	if not active and focused != null and is_ancestor_of(focused):
		_last_focus = weakref(focused)
		focused.release_focus()
	if active and _last_focus != null:
		var previous: Control = _last_focus.get_ref() as Control
		if is_instance_valid(previous) and previous.is_visible_in_tree():
			previous.grab_focus()

## 查询最小化状态。## 输入: 无。输出: bool。
func is_minimized() -> bool:
	return _is_minimized

## 锁定关闭按钮。## 输入: locked。输出: 无。
func set_close_locked(locked: bool) -> void:
	_close_locked = locked
	%CloseButton.disabled = locked

## 锁定最小化按钮。## 输入: locked。输出: 无。
func set_minimize_locked(locked: bool) -> void:
	_minimize_locked = locked
	%MinimizeButton.disabled = locked

## 恢复隐藏的窗口，保留内容和最大化状态。## 输入: 无。输出: 无。
func restore() -> void:
	if _is_shattering:
		return
	_is_minimized = false
	show()
	fit_work_area()
	restored.emit()

## 最小化而不释放内容。## 输入: 无。输出: 无。
func _on_minimize_pressed() -> void:
	if _minimize_locked or _is_shattering:
		return
	stop_impact()
	_is_minimized = true
	hide()
	minimized.emit()

## 请求管理器检查会话和导入状态后关闭。## 输入: 无。输出: 无。
func _on_close_pressed() -> void:
	if not _close_locked and not _is_shattering:
		close_requested.emit()

## 切换最大化及原始矩形。## 输入: 无。输出: 无。
func _on_maximize_pressed() -> void:
	if _is_shattering:
		return
	stop_impact()
	if _is_maximized:
		_is_maximized = false
		position = _pre_max_rect.position
		size = _pre_max_rect.size
	else:
		_pre_max_rect = Rect2(position, size)
		_is_maximized = true
	%MaximizeButton.text = "▣" if _is_maximized else "□"
	$ResizeHandles.visible = not _is_maximized
	fit_work_area()

## 根据已扣除任务栏的父容器限制尺寸和位置。## 输入: 无。输出: 无。
func fit_work_area() -> void:
	if not is_node_ready() or _is_shattering:
		return
	stop_impact()
	var area: Vector2 = (get_parent() as Control).size.max(Vector2.ONE)
	if _is_maximized:
		position = Vector2.ZERO
		size = area
		if keep_square:
			size = Vector2.ONE * minf(area.x, area.y)
			position = ((area - size) * 0.5).round()
	else:
		size = size.clamp(min_window_size.min(area), area)
		if keep_square:
			var maximum_side: float = minf(area.x, area.y)
			var minimum_side: float = minf(maxf(min_window_size.x, min_window_size.y), maximum_side)
			size = Vector2.ONE * clampf(minf(size.x, size.y), minimum_side, maximum_side)
		position = position.clamp(Vector2.ZERO, (area - size).max(Vector2.ZERO)).round()

## 标题栏拖动或双击最大化。## 输入: event。输出: 无。
func _on_title_bar_gui_input(event: InputEvent) -> void:
	if _is_shattering:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		stop_impact()
		window_clicked.emit()
		if event.double_click:
			_on_maximize_pressed()
		elif not _is_maximized:
			_is_dragging = true
			_gesture_rect = Rect2(position, size)
			_gesture_mouse = event.global_position
		accept_event()

## 缩放把手开始手势。## 输入: event、direction。输出: 无。
func _on_resize_input(event: InputEvent, direction: int) -> void:
	if _is_shattering:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		stop_impact()
		window_clicked.emit()
		_resize_dir = direction
		_gesture_rect = Rect2(position, size)
		_gesture_mouse = event.global_position
		accept_event()

## 跟踪越出把手的拖动和释放，内容区点击同步激活。## 输入: event。输出: 无。
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _is_shattering:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			_is_dragging = false
			_resize_dir = ResizeDir.NONE
		else:
			var hovered: Control = get_viewport().gui_get_hovered_control()
			if hovered == self or (hovered != null and is_ancestor_of(hovered)):
				window_clicked.emit()
	if event is InputEventMouseMotion and (_is_dragging or _resize_dir != ResizeDir.NONE):
		var movement: Vector2 = event.position - _gesture_mouse
		if _is_dragging:
			position = _gesture_rect.position + movement
		else:
			var next_rect: Rect2 = resized_rect(_gesture_rect, movement, _resize_dir, min_window_size, keep_square)
			position = next_rect.position
			size = next_rect.size
		fit_work_area()
		get_viewport().set_input_as_handled()

## 计算八向缩放，方形模式以拖动主轴等比缩放并保持对边固定。## 输入: 矩形、位移、方向、下限、是否保持方形。输出: Rect2。
static func resized_rect(rect: Rect2, movement: Vector2, direction: int, minimum: Vector2, square: bool = false) -> Rect2:
	var result: Rect2 = rect
	if direction in [ResizeDir.RIGHT, ResizeDir.TOP_RIGHT, ResizeDir.BOTTOM_RIGHT]:
		result.size.x = maxf(minimum.x, rect.size.x + movement.x)
	if direction in [ResizeDir.BOTTOM, ResizeDir.BOTTOM_LEFT, ResizeDir.BOTTOM_RIGHT]:
		result.size.y = maxf(minimum.y, rect.size.y + movement.y)
	if direction in [ResizeDir.LEFT, ResizeDir.TOP_LEFT, ResizeDir.BOTTOM_LEFT]:
		result.size.x = maxf(minimum.x, rect.size.x - movement.x)
		result.position.x = rect.end.x - result.size.x
	if direction in [ResizeDir.TOP, ResizeDir.TOP_LEFT, ResizeDir.TOP_RIGHT]:
		result.size.y = maxf(minimum.y, rect.size.y - movement.y)
		result.position.y = rect.end.y - result.size.y
	if square:
		var horizontal: bool = direction not in [ResizeDir.TOP, ResizeDir.BOTTOM]
		var vertical: bool = direction not in [ResizeDir.LEFT, ResizeDir.RIGHT]
		var use_width: bool = horizontal and (not vertical or absf(movement.x) > absf(movement.y))
		var side: float = maxf(result.size.x if use_width else result.size.y, maxf(minimum.x, minimum.y))
		result.size = Vector2.ONE * side
		if direction in [ResizeDir.LEFT, ResizeDir.TOP_LEFT, ResizeDir.BOTTOM_LEFT]:
			result.position.x = rect.end.x - side
		if direction in [ResizeDir.TOP, ResizeDir.TOP_LEFT, ResizeDir.TOP_RIGHT]:
			result.position.y = rect.end.y - side
	return result

## 标题和按钮随字体倍率变化。## 输入: scale_value。输出: 无。
func _update_typography(scale_value: float) -> void:
	if _is_shattering:
		return
	_title_bar_panel.custom_minimum_size.y = roundf(38.0 * scale_value)
	_title_label.add_theme_font_size_override("font_size", roundi(22.0 * scale_value))
	for button: Button in [%MinimizeButton, %MaximizeButton, %CloseButton]:
		button.custom_minimum_size = Vector2(32, 28) * scale_value
		button.add_theme_font_size_override("font_size", roundi(18.0 * scale_value))

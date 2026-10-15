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
@export var taskbar_height: float = 48.0

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

## 装载起始页并居中。## 输入: 应用 ID、标题、场景路径。输出: 无。
func initialize(app_id: String, title_text: String, scene_path: String) -> void:
	_app_id = app_id
	_title_label.text = title_text
	size = default_size.min((get_parent() as Control).size)
	position = (((get_parent() as Control).size - size) * 0.5).round()
	navigate_to(scene_path)
	fit_work_area()

## 加载新内容，加载失败时保留原页面。## 输入: path。输出: Godot 错误码。
func navigate_to(path: String) -> int:
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
	_is_minimized = false
	show()
	fit_work_area()
	restored.emit()

## 最小化而不释放内容。## 输入: 无。输出: 无。
func _on_minimize_pressed() -> void:
	if _minimize_locked:
		return
	_is_minimized = true
	hide()
	minimized.emit()

## 请求管理器检查会话和导入状态后关闭。## 输入: 无。输出: 无。
func _on_close_pressed() -> void:
	if not _close_locked:
		close_requested.emit()

## 切换最大化及原始矩形。## 输入: 无。输出: 无。
func _on_maximize_pressed() -> void:
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
	if not is_node_ready():
		return
	var area: Vector2 = (get_parent() as Control).size.max(Vector2.ONE)
	if _is_maximized:
		position = Vector2.ZERO
		size = area
	else:
		size = size.clamp(min_window_size.min(area), area)
		position = position.clamp(Vector2.ZERO, (area - size).max(Vector2.ZERO)).round()

## 标题栏拖动或双击最大化。## 输入: event。输出: 无。
func _on_title_bar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		window_clicked.emit()
		_resize_dir = direction
		_gesture_rect = Rect2(position, size)
		_gesture_mouse = event.global_position
		accept_event()

## 跟踪越出把手的拖动和释放，内容区点击同步激活。## 输入: event。输出: 无。
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
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
			var next_rect: Rect2 = resized_rect(_gesture_rect, movement, _resize_dir, min_window_size)
			position = next_rect.position
			size = next_rect.size
		fit_work_area()
		get_viewport().set_input_as_handled()

## 计算八向缩放，达到最小值时保持对边固定。## 输入: 矩形、位移、方向、下限。输出: Rect2。
static func resized_rect(rect: Rect2, movement: Vector2, direction: int, minimum: Vector2) -> Rect2:
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
	return result

## 标题和按钮随字体倍率变化。## 输入: scale_value。输出: 无。
func _update_typography(scale_value: float) -> void:
	_title_bar_panel.custom_minimum_size.y = roundf(38.0 * scale_value)
	_title_label.add_theme_font_size_override("font_size", roundi(22.0 * scale_value))
	for button: Button in [%MinimizeButton, %MaximizeButton, %CloseButton]:
		button.custom_minimum_size = Vector2(32, 28) * scale_value
		button.add_theme_font_size_override("font_size", roundi(18.0 * scale_value))

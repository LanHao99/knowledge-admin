extends Control
class_name ManagedWindow
## 可拖拽、可缩放的伪窗口控件。提供标题栏、内容区和 8 方向缩放把手。
## 通过 initialize() 加载内容场景；通过 navigate_to() 切换内容。

## 请求关闭该窗口（由 WindowManager 响应）。
signal close_requested
## 用户点击了窗口（需要提升 Z 轴）。
signal window_clicked
## 窗口被最小化。
signal minimized
## 窗口从最小化恢复。
signal restored

## 缩放方向枚举
enum ResizeDir {
	NONE,
	TOP, BOTTOM, LEFT, RIGHT,
	TOP_LEFT, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_RIGHT
}

const RESIZE_MARGIN: float = 6.0
const TITLE_BAR_HEIGHT: int = 26
const TITLE_COLOR_ACTIVE: Color = Color(0.0, 0.0, 0.5, 1.0)
const TITLE_COLOR_INACTIVE: Color = Color(0.49, 0.49, 0.49, 1.0)

## 打开时的默认窗口大小（由 WindowManager 在 initialize 前写入）。
@export var default_size: Vector2 = Vector2(800, 600)
## 可缩放的最小尺寸。
@export var min_window_size: Vector2 = Vector2(200, 120)
## 任务栏高度（用于最大化时留出底部空间）。
@export var taskbar_height: float = 32.0

var _app_id: String = ""
var _is_maximized: bool = false
var _close_locked: bool = false
var _minimize_locked: bool = false
var _pre_max_rect: Rect2 = Rect2()
var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _is_resizing: bool = false
var _resize_dir: ResizeDir = ResizeDir.NONE
var _resize_start_rect: Rect2 = Rect2()
var _resize_start_mouse: Vector2 = Vector2.ZERO
var _is_minimized: bool = false
var _is_active: bool = false
var _current_scene_path: String = ""

@onready var _title_label: Label = %TitleLabel
@onready var _close_btn: Button = %CloseButton
@onready var _minimize_btn: Button = %MinimizeButton
@onready var _maximize_btn: Button = %MaximizeButton
@onready var _title_bar: Control = %TitleBar
@onready var _title_bar_panel: Panel = %TitleBarPanel
@onready var _content_area: Control = %ContentArea


## 初始化后连接按钮信号。
## 输入: 无。
## 输出: 无。
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	clip_contents = true
	_close_btn.pressed.connect(_on_close_pressed)
	_minimize_btn.pressed.connect(_on_minimize_pressed)
	_maximize_btn.pressed.connect(_on_maximize_pressed)
	_title_bar.gui_input.connect(_on_title_bar_gui_input)
	_update_title_bar_color()


## 设置应用 ID、标题并加载内容场景。由 WindowManager 在 add_child 后立即调用。
## 输入: app_id (String), title (String), scene_path (String)。
## 输出: 无。
func initialize(app_id: String, title_text: String, scene_path: String) -> void:
	_app_id = app_id
	_title_label.text = title_text
	size = default_size
	_center_on_parent()
	navigate_to(scene_path)


## 在内容区加载新场景（in-window 页面导航）。
## 输入: path (String) - 场景 res:// 路径。
## 输出: int - OK 或错误码。
func navigate_to(path: String) -> int:
	if not ResourceLoader.exists(path):
		push_warning("[ManagedWindow] 场景不存在: %s" % path)
		return ERR_FILE_NOT_FOUND
	for child: Node in _content_area.get_children():
		child.queue_free()
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_warning("[ManagedWindow] 场景加载失败: %s" % path)
		return ERR_FILE_CANT_OPEN
	var instance: Node = packed.instantiate()
	if instance is Control:
		var ctrl: Control = instance as Control
		ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content_area.add_child(instance)
	_current_scene_path = path
	return OK


## 设置窗口激活状态（影响标题栏颜色）。
## 输入: active (bool)。
## 输出: 无。
func set_window_active(active: bool) -> void:
	_is_active = active
	_update_title_bar_color()


## 返回窗口是否处于最小化状态。
## 输入: 无。
## 输出: bool。
func is_minimized() -> bool:
	return _is_minimized


## 设置关闭按钮锁定（剧情进行时禁止关闭）。
## 输入: locked (bool)。
## 输出: 无。
func set_close_locked(locked: bool) -> void:
	_close_locked = locked
	if _close_btn != null:
		_close_btn.modulate = Color(0.5, 0.5, 0.5, 1.0) if locked else Color.WHITE


## 设置最小化按钮锁定（剧情进行时禁止最小化）。
## 输入: locked (bool)。
## 输出: 无。
func set_minimize_locked(locked: bool) -> void:
	_minimize_locked = locked
	if _minimize_btn != null:
		_minimize_btn.modulate = Color(0.5, 0.5, 0.5, 1.0) if locked else Color.WHITE


## 从最小化恢复，或从最大化恢复到原始大小。
## 输入: 无。
## 输出: 无。
func restore() -> void:
	if _is_minimized:
		visible = true
		_is_minimized = false
		restored.emit()
	elif _is_maximized:
		_do_restore()


## ────────────── 标题栏交互 ──────────────

## 处理标题栏上的鼠标输入（拖拽、双击最大化）。
## 输入: event (InputEvent)。
## 输出: 无。
func _on_title_bar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.double_click:
				_on_maximize_pressed()
				accept_event()
				return
			if mb.pressed:
				window_clicked.emit()
				if not _is_maximized:
					_is_dragging = true
					_drag_offset = global_position - get_global_mouse_position()
				accept_event()
			else:
				_is_dragging = false
	elif event is InputEventMouseMotion and _is_dragging:
		var new_pos: Vector2 = get_global_mouse_position() + _drag_offset
		_clamp_position(new_pos)
		accept_event()


## ────────────── 整体 GUI 输入（缩放） ──────────────

## 处理窗口边缘的缩放输入。
## 输入: event (InputEvent)。
## 输出: 无。
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			window_clicked.emit()
			if mb.pressed and not _is_maximized:
				var dir: ResizeDir = _get_resize_dir(mb.position)
				if dir != ResizeDir.NONE:
					_is_resizing = true
					_resize_dir = dir
					_resize_start_rect = Rect2(position, size)
					_resize_start_mouse = get_global_mouse_position()
					accept_event()
			elif not mb.pressed:
				_is_resizing = false
				_is_dragging = false
				_resize_dir = ResizeDir.NONE
	elif event is InputEventMouseMotion:
		if _is_resizing:
			_do_resize()
			accept_event()
		else:
			var dir: ResizeDir = _get_resize_dir(event.position)
			_set_resize_cursor(dir)


## 全局鼠标释放时停止拖拽和缩放。
## 输入: event (InputEvent)。
## 输出: 无。
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			if _is_dragging or _is_resizing:
				_is_dragging = false
				_is_resizing = false
				_resize_dir = ResizeDir.NONE


## ────────────── 关闭 / 最小化 / 最大化 ──────────────

func _on_close_pressed() -> void:
	if _close_locked:
		return
	close_requested.emit()


func _on_minimize_pressed() -> void:
	if _minimize_locked:
		return
	_is_minimized = true
	visible = false
	minimized.emit()


func _on_maximize_pressed() -> void:
	if _is_maximized:
		_do_restore()
	else:
		_do_maximize()


func _do_maximize() -> void:
	_pre_max_rect = Rect2(position, size)
	_is_maximized = true
	var parent_ctrl: Control = get_parent() as Control
	if parent_ctrl == null:
		return
	position = Vector2.ZERO
	var parent_h: float = parent_ctrl.size.y
	size = Vector2(parent_ctrl.size.x, parent_h - taskbar_height)


func _do_restore() -> void:
	_is_maximized = false
	position = _pre_max_rect.position
	size = _pre_max_rect.size


## ────────────── 辅助函数 ──────────────

func _center_on_parent() -> void:
	var parent_ctrl: Control = get_parent() as Control
	if parent_ctrl == null:
		return
	var parent_size: Vector2 = parent_ctrl.size
	position = ((parent_size - size) * 0.5).round()
	position.y = maxf(0.0, position.y)


## 限制窗口位置，保证标题栏始终可见。
## 输入: new_pos (Vector2) - 期望的新位置。
## 输出: 无。
func _clamp_position(new_pos: Vector2) -> void:
	var parent_ctrl: Control = get_parent() as Control
	if parent_ctrl == null:
		position = new_pos
		return
	var parent_size: Vector2 = parent_ctrl.size
	# 标题栏至少保留 60px 宽可见，顶部不超出桌面
	new_pos.x = clampf(new_pos.x, -(size.x - 60.0), parent_size.x - 60.0)
	new_pos.y = clampf(new_pos.y, 0.0, parent_size.y - float(TITLE_BAR_HEIGHT))
	position = new_pos.round()


func _update_title_bar_color() -> void:
	if _title_bar_panel == null:
		return
	var col: Color = TITLE_COLOR_ACTIVE if _is_active else TITLE_COLOR_INACTIVE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = col
	_title_bar_panel.add_theme_stylebox_override("panel", sb)


func _get_resize_dir(local_pos: Vector2) -> ResizeDir:
	if _is_maximized:
		return ResizeDir.NONE
	var m: float = RESIZE_MARGIN
	var s: Vector2 = size
	var on_l: bool = local_pos.x < m
	var on_r: bool = local_pos.x > s.x - m
	var on_t: bool = local_pos.y < m
	var on_b: bool = local_pos.y > s.y - m
	# 内容区域不响应缩放
	if local_pos.y > float(TITLE_BAR_HEIGHT) and not on_l and not on_r and not on_b:
		return ResizeDir.NONE
	if on_t and on_l: return ResizeDir.TOP_LEFT
	if on_t and on_r: return ResizeDir.TOP_RIGHT
	if on_b and on_l: return ResizeDir.BOTTOM_LEFT
	if on_b and on_r: return ResizeDir.BOTTOM_RIGHT
	if on_l: return ResizeDir.LEFT
	if on_r: return ResizeDir.RIGHT
	if on_t: return ResizeDir.TOP
	if on_b: return ResizeDir.BOTTOM
	return ResizeDir.NONE


func _set_resize_cursor(dir: ResizeDir) -> void:
	match dir:
		ResizeDir.LEFT, ResizeDir.RIGHT:
			mouse_default_cursor_shape = CURSOR_HSIZE
		ResizeDir.TOP, ResizeDir.BOTTOM:
			mouse_default_cursor_shape = CURSOR_VSIZE
		ResizeDir.TOP_LEFT, ResizeDir.BOTTOM_RIGHT:
			mouse_default_cursor_shape = CURSOR_FDIAGSIZE
		ResizeDir.TOP_RIGHT, ResizeDir.BOTTOM_LEFT:
			mouse_default_cursor_shape = CURSOR_BDIAGSIZE
		_:
			mouse_default_cursor_shape = CURSOR_ARROW


## 根据缩放方向和鼠标位移更新窗口位置与大小。
## 输入: 无（读取 _resize_start_rect 和当前鼠标位置）。
## 输出: 无。
func _do_resize() -> void:
	var delta: Vector2 = get_global_mouse_position() - _resize_start_mouse
	var r: Rect2 = _resize_start_rect
	var min_w: float = min_window_size.x
	var min_h: float = min_window_size.y

	match _resize_dir:
		ResizeDir.RIGHT:
			r.size.x = maxf(min_w, r.size.x + delta.x)
		ResizeDir.BOTTOM:
			r.size.y = maxf(min_h, r.size.y + delta.y)
		ResizeDir.LEFT:
			var nw: float = maxf(min_w, r.size.x - delta.x)
			r.position.x = r.end.x - nw
			r.size.x = nw
		ResizeDir.TOP:
			var nh: float = maxf(min_h, r.size.y - delta.y)
			r.position.y = r.end.y - nh
			r.size.y = nh
		ResizeDir.BOTTOM_RIGHT:
			r.size.x = maxf(min_w, r.size.x + delta.x)
			r.size.y = maxf(min_h, r.size.y + delta.y)
		ResizeDir.BOTTOM_LEFT:
			var nw: float = maxf(min_w, r.size.x - delta.x)
			r.position.x = r.end.x - nw
			r.size.x = nw
			r.size.y = maxf(min_h, r.size.y + delta.y)
		ResizeDir.TOP_RIGHT:
			r.size.x = maxf(min_w, r.size.x + delta.x)
			var nh: float = maxf(min_h, r.size.y - delta.y)
			r.position.y = r.end.y - nh
			r.size.y = nh
		ResizeDir.TOP_LEFT:
			var nw: float = maxf(min_w, r.size.x - delta.x)
			r.position.x = r.end.x - nw
			r.size.x = nw
			var nh: float = maxf(min_h, r.size.y - delta.y)
			r.position.y = r.end.y - nh
			r.size.y = nh

	position = r.position.round()
	size = r.size.round()

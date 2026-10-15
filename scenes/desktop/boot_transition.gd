extends CanvasLayer
## 一次性启动遮罩，统一溶解波浪和文字，并在准备完成后交还桌面输入。

const DESKTOP_SCENE: String = "res://scenes/desktop/desktop.tscn"

var _started: bool = false
var _desktop_ready: bool = false
var _accelerated: bool = false
var _dissolving: bool = false
var _finished: bool = false
var _elapsed: float = 0.0
var _hold_duration: float = 1.6
var _dissolve_duration: float = 1.4
var _accelerated_duration: float = 0.6
var _dissolve_progress: float = 0.0
var _dissolve_rate: float = 0.0
var _desktop: Control
var _desktop_process_mode: Node.ProcessMode = Node.PROCESS_MODE_INHERIT

@onready var _mask_material: ShaderMaterial = %CoverGroup.material as ShaderMaterial
@onready var _status: Label = %Status
@onready var _cover: Control = %Cover
@onready var _input_blocker: Control = $InputBlocker


## 准备全不透明遮罩与自适应像素字号。## 输入: 无。输出: 无。
func _ready() -> void:
	_mask_material.set_shader_parameter("progress", 0.0)
	get_viewport().size_changed.connect(_fit_layout)
	_fit_layout()


## 配置时间并在封面下执行标准桌面切换。## 输入: 总时长、正常溶解时长、加速时长，单位秒。输出: 无。
func start(total_duration: float, dissolve_duration: float, accelerated_duration: float) -> void:
	if _started:
		return
	_started = true
	_dissolve_duration = maxf(0.1, dissolve_duration)
	_accelerated_duration = maxf(0.1, accelerated_duration)
	_hold_duration = maxf(0.0, total_duration - _dissolve_duration)
	_prepare_desktop.call_deferred()


## 等待真实桌面完成初始化及绘制，准备期间保持封面覆盖。## 输入: 无。输出: 无。
func _prepare_desktop() -> void:
	var scene_tree: SceneTree = get_tree()
	var error: Error = scene_tree.change_scene_to_file(DESKTOP_SCENE)
	if error != OK:
		push_error("无法准备启动桌面，错误码：%d" % error)
		return
	await scene_tree.scene_changed
	_desktop = scene_tree.current_scene as Control
	if _desktop == null:
		push_error("启动转场未获得桌面实例")
		return
	_desktop_process_mode = _desktop.process_mode
	_desktop.process_mode = Node.PROCESS_MODE_DISABLED
	await scene_tree.process_frame
	await RenderingServer.frame_post_draw
	_desktop_ready = true


## 按时间推进中心溶解，桌面尚未准备好时不打开遮罩。## 输入: delta (float) - 帧时间。输出: 无。
func _process(delta: float) -> void:
	if not _started or _finished:
		return
	_elapsed += delta
	if not _desktop_ready:
		return
	if not _dissolving:
		if not _accelerated and _elapsed < _hold_duration:
			return
		_dissolving = true
		_dissolve_rate = 1.0 / (_accelerated_duration if _accelerated else _dissolve_duration)
	_dissolve_progress = minf(1.0, _dissolve_progress + delta * _dissolve_rate)
	_mask_material.set_shader_parameter("progress", smoothstep(0.0, 1.0, _dissolve_progress))
	if _dissolve_progress >= 1.0:
		_finish()


## 吞掉转场输入，有效按下只缩短剩余时长而不重置进度。## 输入: event (InputEvent)。输出: 无。
func _input(event: InputEvent) -> void:
	if _finished:
		return
	get_viewport().set_input_as_handled()
	var accelerate: bool = event is InputEventMouseButton and event.is_pressed()
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		accelerate = key_event.pressed and not key_event.echo
	if accelerate:
		_accelerated = true
		if _dissolving:
			_dissolve_rate = maxf(_dissolve_rate, (1.0 - _dissolve_progress) / _accelerated_duration)


## 同步非 Control 父节点下的封面尺寸，并选择整倍数像素字号。## 输入: 无。输出: 无。
func _fit_layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_cover.size = viewport_size
	_input_blocker.size = viewport_size
	_status.add_theme_font_size_override("font_size", 48 if viewport_size.y >= 900.0 else 32)


## 遮罩完全打开后恢复桌面处理并释放封面。## 输入: 无。输出: 无。
func _finish() -> void:
	if _finished:
		return
	_finished = true
	_mask_material.set_shader_parameter("progress", 1.0)
	_restore_desktop()
	queue_free()


## 释放或中断遮罩时恢复同一桌面的原处理模式。## 输入: 无。输出: 无。
func _restore_desktop() -> void:
	if is_instance_valid(_desktop):
		_desktop.process_mode = _desktop_process_mode


## 外部切场景或提前销毁封面时清理处理锁。## 输入: 无。输出: 无。
func _exit_tree() -> void:
	_restore_desktop()

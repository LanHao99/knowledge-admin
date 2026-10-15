extends Control
## 着色器启动封面。播放能量核心与启动进度后进入桌面，支持点击或按键跳过。

const DESKTOP_SCENE: String = "res://scenes/desktop/desktop.tscn"

@export_range(1.0, 10.0, 0.1, "suffix:s") var boot_duration: float = 2.2

@onready var _boot_progress: ProgressBar = %BootProgress
@onready var _content: VBoxContainer = %BootContent
@onready var _fade: ColorRect = %Fade
@onready var _core: ColorRect = %EnergyCore

var _elapsed: float = 0.0
var _skipped: bool = false


## 启动定时器并准备跳过输入。
## 输入: 无。
## 输出: 无。
func _ready() -> void:
	_elapsed = 0.0
	_skipped = false
	_boot_progress.value = 0.0
	_content.modulate.a = 0.0
	_fade.color.a = 1.0
	resized.connect(_fit_layout)
	_fit_layout()


## 按视口高度调整能量核心大小，为标题和底部跳过提示留出空间。
## 输入: 无。
## 输出: 无。
func _fit_layout() -> void:
	var core_size: float = roundf(clampf(size.y * 0.455, 192.0, 420.0))
	_core.custom_minimum_size = Vector2.ONE * core_size


## 推进封面时间、进度条和淡入淡出，到期后跳转桌面。
## 输入: delta (float) - 帧时间。
## 输出: 无。
func _process(delta: float) -> void:
	_elapsed += delta
	var progress: float = clampf(_elapsed / maxf(boot_duration, 0.1), 0.0, 1.0)
	_boot_progress.value = progress * 100.0
	_content.modulate.a = smoothstep(0.0, 0.28, _elapsed)
	_fade.color.a = maxf(1.0 - smoothstep(0.0, 0.24, _elapsed), smoothstep(0.92, 1.0, progress))
	if progress >= 1.0:
		_go_to_desktop()


## 捕捉任意输入跳过启动画面。
## 输入: event (InputEvent)。
## 输出: 无。
func _unhandled_input(event: InputEvent) -> void:
	if _skipped:
		return
	var skip: bool = false
	if event is InputEventMouseButton:
		skip = (event as InputEventMouseButton).pressed
	elif event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		skip = key_event.pressed and not key_event.echo
	if skip:
		_go_to_desktop()


## 跳转到桌面场景（只执行一次）。
## 输入: 无。
## 输出: 无。
func _go_to_desktop() -> void:
	if _skipped:
		return
	_skipped = true
	set_process(false)
	get_tree().change_scene_to_file(DESKTOP_SCENE)

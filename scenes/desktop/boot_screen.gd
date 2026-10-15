extends Control
## 启动画面。显示约 2 秒后自动跳转到桌面；鼠标点击或任意键可提前跳过。

const DESKTOP_SCENE: String = "res://scenes/desktop/desktop.tscn"
const BOOT_DURATION: float = 2.2

var _elapsed: float = 0.0
var _skipped: bool = false


## 启动定时器并准备跳过输入。
## 输入: 无。
## 输出: 无。
func _ready() -> void:
	_elapsed = 0.0
	_skipped = false


## 每帧累计时间，到期后跳转桌面。
## 输入: delta (float) - 帧时间。
## 输出: 无。
func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= BOOT_DURATION:
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
		skip = (event as InputEventKey).pressed
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

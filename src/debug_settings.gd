extends Node
## 全局调试设置 Autoload。控制调试 UI 的显示/隐藏，持久化到 user://settings.tres。
## 其他场景通过 DebugSettings.debug_mode 查询状态，通过 debug_mode_changed 信号响应变化。

# ── 信号 ──

## 调试模式切换时发射。
signal debug_mode_changed(enabled: bool)


# ── 持久化 ──

const SAVE_PATH: String = "user://settings.tres"


# ── 属性 ──

## 调试模式开关。
var debug_mode: bool = false


# ── 生命周期 ──


## 启动时从 user://settings.tres 加载设置。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	_load_from_user()


# ── 公共接口 ──


## 切换调试模式并保存。## 输入: 无。
## 输出: 无。
func toggle() -> void:
	debug_mode = not debug_mode
	_save_to_user()
	debug_mode_changed.emit(debug_mode)


## 设置调试模式为指定值并保存。## 输入: enabled (bool) — 目标状态。
## 输出: 无。
func set_debug_mode(enabled: bool) -> void:
	if debug_mode == enabled:
		return
	debug_mode = enabled
	_save_to_user()
	debug_mode_changed.emit(debug_mode)


# ── 持久化实现 ──


## 从 user://settings.tres 读取设置（不存在则使用默认值）。## 输入: 无。
## 输出: 无。
func _load_from_user() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var content: String = file.get_as_text()
	file.close()

	var data: Dictionary = {}
	# 简单解析：每行 key=value
	for line in content.split("\n"):
		line = line.strip_edges()
		if line.is_empty() or line.begins_with(";"):
			continue
		var eq_pos: int = line.find("=")
		if eq_pos == -1:
			continue
		var key: String = line.substr(0, eq_pos).strip_edges()
		var value: String = line.substr(eq_pos + 1).strip_edges()
		data[key] = value

	debug_mode = data.get("debug_mode", "false") == "true"


## 保存当前设置到 user://settings.tres。## 输入: 无。
## 输出: 无。
func _save_to_user() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return

	file.store_string("; Debug Settings\n")
	file.store_string("debug_mode=%s\n" % ("true" if debug_mode else "false"))
	file.close()

extends Node
## 管理桌面壁纸路径、铺满或原比例两种显示方式，以及独立存档。
## 配置写入 user://wallpaper_settings.cfg，避免被字号存档整文件覆盖。

signal wallpaper_changed(path: String, mode: int)
signal settings_save_failed(error: int)
signal settings_saved()

const SAVE_PATH: String = "user://wallpaper_settings.cfg"
const WALLPAPER_DIR: String = "res://assets/wallpapers/"
const MODE_FILL: int = 0
const MODE_FIT: int = 1
const IMAGE_EXTENSIONS: PackedStringArray = ["png", "jpg", "jpeg", "webp"]

var wallpaper_path: String = ""
var display_mode: int = MODE_FILL
var settings_path: String = SAVE_PATH
var _save_timer: Timer
var _dirty: bool = false


## 创建延迟保存计时器并读取壁纸配置。## 输入: 无。
## 输出: 无。
func _ready() -> void:
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.3
	_save_timer.timeout.connect(save_settings)
	add_child(_save_timer)
	load_settings()


## 离开场景树前保存尚未落盘的壁纸设置。## 输入: 无。
## 输出: 无。
func _exit_tree() -> void:
	if _dirty:
		save_settings()


## 列出壁纸目录中的图片，路径按文件名排序。## 输入: 无。
## 输出: PackedStringArray - res:// 图片路径；目录不可读时为空。
func list_wallpapers() -> PackedStringArray:
	var paths := PackedStringArray()
	var entries := PackedStringArray()
	if ResourceLoader.has_method("list_directory"):
		entries = ResourceLoader.list_directory(WALLPAPER_DIR)
	else:
		var directory := DirAccess.open(WALLPAPER_DIR)
		if directory == null:
			return paths
		entries = directory.get_files()
	for entry: String in entries:
		var file_name := entry.trim_suffix("/").get_file()
		if file_name.is_empty() or file_name.begins_with("."):
			continue
		if not IMAGE_EXTENSIONS.has(file_name.get_extension().to_lower()):
			continue
		paths.append(WALLPAPER_DIR.path_join(file_name))
	paths.sort()
	return paths


## 加载一张壁纸纹理。空路径、目录外路径或加载失败时返回空。## 输入: path (String) - 壁纸资源路径。
## 输出: Texture2D - 可绘制的纹理；不可用时为 null。
func load_texture(path: String) -> Texture2D:
	var sanitized := _sanitize_path(path)
	if sanitized.is_empty():
		return null
	return ResourceLoader.load(sanitized) as Texture2D


## 切换壁纸。空字符串表示不使用壁纸，恢复桌面底色。## 输入: path (String) - 壁纸资源路径或空字符串。
## 输出: 无。
func set_wallpaper(path: String) -> void:
	var sanitized := _sanitize_path(path)
	if not path.strip_edges().is_empty() and sanitized.is_empty():
		return
	if wallpaper_path == sanitized:
		return
	wallpaper_path = sanitized
	_notify_changed()


## 切换显示方式。无法识别的值按铺满处理。## 输入: mode (int) - MODE_FILL 或 MODE_FIT。
## 输出: 无。
func set_display_mode(mode: int) -> void:
	var sanitized := _sanitize_mode(mode)
	if display_mode == sanitized:
		return
	display_mode = sanitized
	_notify_changed()


## 读取壁纸配置。文件缺失、损坏或路径失效时恢复为无壁纸、铺满。## 输入: path (String) - 配置路径。
## 输出: 无。
func load_settings(path: String = SAVE_PATH) -> void:
	settings_path = path
	var config := ConfigFile.new()
	var stored_path: Variant = ""
	var stored_mode: Variant = MODE_FILL
	if FileAccess.file_exists(path) and config.load(path) == OK:
		stored_path = config.get_value("wallpaper", "path", "")
		stored_mode = config.get_value("wallpaper", "mode", MODE_FILL)
	wallpaper_path = _sanitize_path(stored_path)
	display_mode = _sanitize_mode(stored_mode)
	_dirty = false
	wallpaper_changed.emit(wallpaper_path, display_mode)


## 保存壁纸路径和显示方式。失败时保留待保存状态并发出通知。## 输入: 无。
## 输出: Error - 保存结果。
func save_settings() -> Error:
	var config := ConfigFile.new()
	config.set_value("wallpaper", "path", wallpaper_path)
	config.set_value("wallpaper", "mode", display_mode)
	var error := config.save(settings_path)
	_dirty = error != OK
	if error != OK:
		settings_save_failed.emit(error)
	else:
		settings_saved.emit()
	return error


## 通知监听者，并在短暂停顿后写入配置。## 输入: 无。
## 输出: 无。
func _notify_changed() -> void:
	_dirty = true
	wallpaper_changed.emit(wallpaper_path, display_mode)
	if is_instance_valid(_save_timer):
		_save_timer.start()


## 只接受壁纸目录中的图片路径。## 输入: path (Variant) - 存档或界面传入的路径。
## 输出: String - 合法路径；否则为空字符串。
func _sanitize_path(path: Variant) -> String:
	if not (path is String):
		return ""
	var text := str(path).strip_edges().replace("\\", "/")
	if text.is_empty() or not list_wallpapers().has(text):
		return ""
	return text


## 只接受两种显示方式，其余值都视为铺满。## 输入: mode (Variant) - 存档或界面传入的方式。
## 输出: int - MODE_FILL 或 MODE_FIT。
func _sanitize_mode(mode: Variant) -> int:
	if (mode is int or mode is float) and int(mode) == MODE_FIT:
		return MODE_FIT
	return MODE_FILL

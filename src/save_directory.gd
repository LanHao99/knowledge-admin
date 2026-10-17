extends Node
## 在其他 Autoload 读取存档前，将 Windows 游戏进程的 user:// 指向指定目录。

const ENABLED: bool = true
const DIRECTORY: String = "res://saves"


## 创建存档目录并切换当前进程的用户数据路径。## 输入: 无。
## 输出: 无；目录创建失败时保留引擎默认路径并报告错误。
func _init() -> void:
	if not ENABLED or OS.get_name() != "Windows":
		return
	var directory: String = ProjectSettings.globalize_path(DIRECTORY).simplify_path().trim_suffix("/")
	var error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		push_error("[SaveDirectory] 无法创建存档目录 %s，错误码: %d" % [directory, error])
		return
	OS.set_environment("APPDATA", directory.get_base_dir())
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", directory.get_file())
	print("[SaveDirectory] user:// = %s" % OS.get_user_data_dir())

extends SceneTree
## 加载自有脚本与场景，验证目录移动后的解析、资源引用和场景实例化。

var _failures: Array[String] = []
var _scripts: int = 0
var _scenes: int = 0


## 启动资源扫描并按检查结果结束进程。## 输入: 无。
## 输出: 无。
func _initialize() -> void:
	_scan_scripts("res://src")
	_scan_scenes("res://content/scenes")
	_scan_scenes("res://tests/scenes")
	print("RESOURCE_VERIFICATION: ", JSON.stringify({"scripts": _scripts, "scenes": _scenes, "failures": _failures}))
	quit(0 if _failures.is_empty() else 1)


## 递归加载实现脚本并检查是否可以实例化。## 输入: directory (String) - 目录。
## 输出: 无。
func _scan_scripts(directory: String) -> void:
	for file_name: String in DirAccess.get_files_at(directory):
		if file_name.ends_with(".gd"):
			var path: String = directory.path_join(file_name)
			var script: GDScript = load(path) as GDScript
			_scripts += 1
			if script == null or not script.can_instantiate():
				_failures.append(path)
	for child: String in DirAccess.get_directories_at(directory):
		_scan_scripts(directory.path_join(child))


## 递归加载场景并实例化节点树，不启动其运行逻辑。## 输入: directory (String) - 场景目录。
## 输出: 无。
func _scan_scenes(directory: String) -> void:
	for file_name: String in DirAccess.get_files_at(directory):
		if file_name.ends_with(".tscn"):
			var path: String = directory.path_join(file_name)
			var packed: PackedScene = load(path) as PackedScene
			_scenes += 1
			if packed == null or not packed.can_instantiate():
				_failures.append(path)
				continue
			var instance: Node = packed.instantiate()
			if instance == null:
				_failures.append(path)
			else:
				instance.free()
	for child: String in DirAccess.get_directories_at(directory):
		_scan_scenes(directory.path_join(child))

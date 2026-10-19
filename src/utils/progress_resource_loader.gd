extends RefCounted
## 读取剧情与教程资源，兼容存档中保存的脚本位置。

const SCRIPT_PATHS: Dictionary[String, String] = {
	"res://game/dialogue/story_progress.gd": "res://src/dialogue/story_progress.gd",
	"res://game/tutorial/tutorial_progress.gd": "res://src/tutorial/tutorial_progress.gd",
}


## 读取进度资源；脚本路径需要转换时使用临时副本，保留原存档。## 输入: path (String) - 资源路径；cache_mode (int) - 直接加载时的缓存模式。
## 输出: Resource - 成功加载的资源，文件不可读或转换失败时为 null。
static func load_resource(path: String, cache_mode: int = ResourceLoader.CACHE_MODE_REPLACE) -> Resource:
	var source: FileAccess = FileAccess.open(path, FileAccess.READ)
	if source == null:
		return null
	var original: String = source.get_as_text()
	source.close()
	var converted: String = original
	for previous: String in SCRIPT_PATHS:
		converted = converted.replace('path="%s"' % previous, 'path="%s"' % SCRIPT_PATHS[previous])
	if converted == original:
		return ResourceLoader.load(path, "", cache_mode)
	var temporary: String = "%s.paths_%d.tres" % [path.get_basename(), Time.get_ticks_usec()]
	var output: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if output == null:
		push_error("无法创建进度资源的临时副本: %s" % temporary)
		return null
	output.store_string(converted)
	output.close()
	var loaded: Resource = ResourceLoader.load(temporary, "", ResourceLoader.CACHE_MODE_IGNORE)
	var cleanup_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
	if cleanup_error != OK:
		push_warning("无法清理进度资源的临时副本: %s" % temporary)
	return loaded

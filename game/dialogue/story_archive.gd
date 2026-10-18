class_name StoryArchive
extends RefCounted
## 剧情存档的验证、备份和原位写回。失败时不替换已经打开的 StoryProgress。

var save_path: String = StoryProgress.SAVE_PATH
var backup_dir: String = "user://story_backups"
var save_handler: Callable = Callable()


## 校验数值、备份、写入临时文件，成功后再覆盖正式存档并原位同步。## 输入: live、replacement、reason。
## 输出: Dictionary。失败时 live 保持调用前的字段。
func commit(live: StoryProgress, replacement: StoryProgress, reason: String) -> Dictionary:
	if live == null or replacement == null:
		return _failure("剧情存档未就绪")
	var numbers := replacement.validate_numbers()
	if not numbers.success:
		return numbers
	var backup := create_backup(live, reason)
	if not backup.success:
		return backup
	var temporary := save_path.get_basename() + ".tmp.tres"
	var save_error := _store(replacement, temporary)
	if save_error != OK:
		_remove_file(temporary)
		return _failure("保存剧情失败，错误码: %d" % save_error)
	var replace_error := _copy_file(temporary, save_path)
	_remove_file(temporary)
	if replace_error != OK:
		return _failure("写入剧情存档失败，错误码: %d" % replace_error)
	live.copy_from(replacement)
	return {"success": true, "data": true, "backup": str(backup.data.get("path", ""))}


## 把当前内存中的剧情写成独立备份。## 输入: progress、reason。
## 输出: Dictionary。成功时 data.path 为 user:// 备份路径。
func create_backup(progress: StoryProgress, reason: String) -> Dictionary:
	if progress == null:
		return _failure("没有可备份的剧情")
	var directory := ProjectSettings.globalize_path(backup_dir)
	var directory_error := DirAccess.make_dir_recursive_absolute(directory)
	if directory_error != OK and not DirAccess.dir_exists_absolute(directory):
		return _failure("无法创建备份目录，错误码: %d" % directory_error)
	var safe_reason := reason if not reason.is_empty() else "backup"
	var path := "%s/story_%s_%d_%s.tres" % [backup_dir, _timestamp(), Time.get_ticks_usec(), safe_reason]
	var error := _store(progress, path)
	if error != OK:
		_remove_file(path)
		return _failure("创建备份失败，错误码: %d" % error)
	return {"success": true, "data": {"path": path}}


## 读取一个备份并按提交流程恢复到当前存档。## 输入: live、backup_path。
## 输出: Dictionary。备份不存在或内容无效时不修改 live。
func restore(live: StoryProgress, backup_path: String) -> Dictionary:
	if not FileAccess.file_exists(backup_path):
		return _failure("备份不存在")
	var loaded := ResourceLoader.load(backup_path, "", ResourceLoader.CACHE_MODE_IGNORE) as StoryProgress
	if loaded == null:
		return _failure("备份无法读取")
	var replacement := StoryProgress.new()
	replacement.copy_from(loaded)
	return commit(live, replacement, "restore")


## 按修改时间列出备份，新的在前。## 输入: 无。
## 输出: Array[Dictionary]，每项含 path、name、modified。
func list_backups() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var directory := DirAccess.open(ProjectSettings.globalize_path(backup_dir))
	if directory == null:
		return rows
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.ends_with(".tres"):
			var path := backup_dir.path_join(file_name)
			rows.append({
				"path": path,
				"name": file_name,
				"modified": FileAccess.get_modified_time(path),
			})
		file_name = directory.get_next()
	directory.list_dir_end()
	rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.get("modified", 0)) > int(right.get("modified", 0))
	)
	return rows


## 保存资源。测试可替换 save_handler。## 输入: progress、path。
## 输出: Error。
func _store(progress: StoryProgress, path: String) -> Error:
	var parent := path.get_base_dir()
	if not parent.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(parent))
	if save_handler.is_valid():
		var value: Variant = save_handler.call(progress, path)
		if typeof(value) == TYPE_INT:
			return value as Error
		return ERR_CANT_CREATE
	return ResourceSaver.save(progress, path)


## 复制文件内容。## 输入: source_path、target_path。
## 输出: Error。
func _copy_file(source_path: String, target_path: String) -> Error:
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return FileAccess.get_open_error()
	var target := FileAccess.open(target_path, FileAccess.WRITE)
	if target == null:
		var error := FileAccess.get_open_error()
		source.close()
		return error
	target.store_buffer(source.get_buffer(source.get_length()))
	source.close()
	target.close()
	return OK


## 删除临时文件，文件不存在时忽略。## 输入: path。
## 输出: 无。
func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## 生成备份文件名用的时间文本。## 输入: 无。
## 输出: String。
func _timestamp() -> String:
	return Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace(" ", "_")


## 组装失败结果。## 输入: message。
## 输出: Dictionary。
func _failure(message: String) -> Dictionary:
	return {"success": false, "error": "STORY_ARCHIVE", "message": message}

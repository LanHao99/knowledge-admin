extends GutTest
## 验证脚本分离后，进度和备份资源仍可读取且不改写原文件。

const Loader: GDScript = preload("res://src/utils/progress_resource_loader.gd")
var _paths: Array[String] = []


## 移除本用例创建的进度副本。## 输入: 无。
## 输出: 无。
func after_each() -> void:
	for path: String in _paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_paths.clear()


## 无 UID 的剧情存档保留章节、羁绊和完成记录，并能被备份恢复流程使用。## 输入: 无。
## 输出: 无。
func test_story_progress_without_uid_preserves_saved_fields() -> void:
	var text: String = '[gd_resource type="Resource" format=3]\n\n[ext_resource type="Script" path="res://game/dialogue/story_progress.gd" id="1"]\n\n[resource]\nscript = ExtResource("1")\ncurrent_chapter = "chapter_2"\nbond = 9\ncompleted_dialogues = Array[String](["chapter_1/intro"])\n'
	var path: String = _write_fixture(text)
	var loaded: StoryProgress = Loader.load_resource(path) as StoryProgress
	assert_not_null(loaded)
	if loaded == null:
		return
	assert_eq(loaded.current_chapter, "chapter_2")
	assert_eq(loaded.bond, 9)
	assert_eq(loaded.completed_dialogues, ["chapter_1/intro"] as Array[String])
	assert_eq(FileAccess.get_file_as_string(path), text)
	var archive: StoryArchive = StoryArchive.new()
	archive.save_path = _write_fixture("")
	archive.backup_dir = "user://layout_restore_backups_%d" % Time.get_ticks_usec()
	var live: StoryProgress = StoryProgress.new()
	var result: Dictionary = archive.restore(live, path)
	assert_true(result.success)
	assert_eq(live.bond, 9)
	assert_eq(live.current_chapter, "chapter_2")
	if result.success:
		_paths.append(str(result.backup))


## 无 UID 的教程存档保留已看过的教程列表。## 输入: 无。
## 输出: 无。
func test_tutorial_progress_without_uid_preserves_completed_ids() -> void:
	var text: String = '[gd_resource type="Resource" format=3]\n\n[ext_resource type="Script" path="res://game/tutorial/tutorial_progress.gd" id="1"]\n\n[resource]\nscript = ExtResource("1")\ncompleted_ids = Array[String](["main_menu", "study"])\n'
	var path: String = _write_fixture(text)
	var loaded: TutorialProgress = Loader.load_resource(path) as TutorialProgress
	assert_not_null(loaded)
	if loaded == null:
		return
	assert_true(loaded.is_completed("main_menu"))
	assert_true(loaded.is_completed("study"))
	assert_false(loaded.is_completed("deck_list"))
	assert_eq(FileAccess.get_file_as_string(path), text)


## 当前路径保存的资源可以直接读回。## 输入: 无。
## 输出: 无。
func test_current_resource_round_trip() -> void:
	var path: String = _write_fixture("")
	var progress: StoryProgress = StoryProgress.new()
	progress.bond = 12
	assert_eq(ResourceSaver.save(progress, path), OK)
	var loaded: StoryProgress = Loader.load_resource(path) as StoryProgress
	assert_not_null(loaded)
	if loaded != null:
		assert_eq(loaded.bond, 12)
		loaded.bond = 7
		var separate: StoryProgress = Loader.load_resource(path, ResourceLoader.CACHE_MODE_IGNORE) as StoryProgress
		assert_not_null(separate)
		if separate != null:
			assert_eq(separate.bond, 12)
		assert_eq(loaded.bond, 7)
	assert_null(Loader.load_resource("user://missing_layout_progress.tres"))


## 写入独立的文本资源样本并登记清理路径。## 输入: text (String) - 样本内容。
## 输出: String - 临时资源路径。
func _write_fixture(text: String) -> String:
	var path: String = "user://layout_progress_%d.tres" % Time.get_ticks_usec()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	_paths.append(path)
	return path

extends GutTest
## 剧情测试台的完成记录、迁移、跳转、存档和草稿冲突。

var _folders: Array[String] = []
var _debug_before: bool = false
var _story_before: Dictionary = {}
var _archive_path: String = ""
var _archive_dir: String = ""


## 记住调试开关和当前剧情，测试结束后原样放回。## 输入: 无。
## 输出: 无。
func before_each() -> void:
	_debug_before = DebugSettings.debug_mode
	var progress := App.get_story_progress()
	_story_before = {} if progress == null else progress.capture_state()
	if App._story_manager != null and App._story_manager._archive != null:
		_archive_path = App._story_manager._archive.save_path
		_archive_dir = App._story_manager._archive.backup_dir
	App.clear_story_draft()


## 恢复玩家剧情、调试开关，并删除临时备份。## 输入: 无。
## 输出: 无。
func after_each() -> void:
	_restore_live_story()
	_restore_live_archive()
	DebugSettings.debug_mode = _debug_before
	App.clear_story_draft()
	if App._story_manager != null:
		App._story_manager.end_dialogue()
		App._story_manager._archive.save_handler = Callable()
	App._dialogue_queue.clear()
	App._active_dialogue_key = ""
	App._test_playback = false
	App._stop_reason = ""
	App._drop_next_story = false
	for folder in _folders:
		_remove_tree(folder)
	_folders.clear()


## 同名剧情在不同章节里分别记录。## 输入: 无。
## 输出: 无。
func test_cross_chapter_completion_records() -> void:
	var progress := StoryProgress.new()
	progress.current_chapter = "chapter_2"
	progress.mark_chapter_dialogue("chapter_1", "revelation")
	assert_true(progress.is_chapter_dialogue_completed("chapter_1", "revelation"))
	assert_false(progress.is_chapter_dialogue_completed("chapter_2", "revelation"))
	var manager := _manager(progress, _temp_archive())
	assert_false(manager.is_dialogue_completed("revelation"))
	progress.mark_chapter_dialogue("chapter_2", "revelation")
	assert_true(manager.is_dialogue_completed("revelation"))
	assert_true(progress.is_chapter_dialogue_completed("chapter_1", "revelation"))


## 旧短标识归最早章节，未知记录保留，并先写备份。## 输入: 无。
## 输出: 无。
func test_legacy_records_migrate_after_backup() -> void:
	var progress := StoryProgress.new()
	progress.current_chapter = "chapter_2"
	StoryProgress.assign_strings(progress.completed_dialogues, ["revelation", "choice", "not_a_story", "chapter_2/end", "revelation"])
	var archive := _temp_archive()
	var manager := _manager(progress, archive)
	var migrated: Dictionary = manager.migrate_loaded_records()
	assert_true(migrated.success, str(migrated.get("message", "")))
	assert_true(bool(migrated.get("changed", false)))
	assert_eq(_count(progress.completed_dialogues, "chapter_1/revelation"), 1)
	assert_true("chapter_1/choice" in progress.completed_dialogues)
	assert_true("not_a_story" in progress.completed_dialogues)
	assert_true("chapter_2/end" in progress.completed_dialogues)
	assert_false("revelation" in progress.completed_dialogues)
	assert_gte(archive.list_backups().size(), 1)


## 羁绊前置只认它所属章节的主线。## 输入: 无。
## 输出: 无。
func test_bond_prerequisite_is_chapter_specific() -> void:
	var progress := StoryProgress.new()
	progress.current_chapter = "chapter_1"
	progress.bond = 8
	var manager := _manager(progress, _temp_archive())
	progress.mark_chapter_dialogue("chapter_2", "trust")
	assert_eq(str(manager.preview_next_entry().get("key", "")), "intro")
	progress.mark_chapter_dialogue("chapter_1", "trust")
	assert_eq(str(manager.preview_next_entry().get("key", "")), "bond_memory_1")
	progress.bond = 0
	assert_eq(str(manager.preview_next_entry().get("key", "")), "intro")


## 跳转重排主线、保留更早的羁绊，并按已完成主线数重算阈值。## 输入: 无。
## 输出: 无。
func test_jump_reorders_records_without_changing_bond_or_flags() -> void:
	var progress := StoryProgress.new()
	progress.current_chapter = "chapter_2"
	progress.bond = 4
	progress.total_progress = 9
	progress.trigger_threshold = 99
	progress.last_triggered_at = 50.0
	progress.set_flag("branch_kept", "left")
	progress.mark_bond_dialogue_triggered("bond_memory_1")
	progress.mark_bond_dialogue_triggered("bond_memory_2")
	progress.mark_chapter_dialogue("chapter_1", "end")
	var manager := _manager(progress, _temp_archive())
	var jumped: Dictionary = manager.prepare_story_jump("chapter_1", "bond_memory_2")
	assert_true(jumped.success, str(jumped.get("message", "")))
	assert_eq(progress.current_chapter, "chapter_1")
	assert_eq(progress.bond, 4)
	assert_eq(progress.get_flag("branch_kept"), "left")
	assert_eq(progress.total_progress, 0)
	assert_eq(progress.last_triggered_at, 0.0)
	assert_eq(progress.trigger_threshold, 40)
	assert_true(progress.is_bond_dialogue_triggered("bond_memory_1"))
	assert_false(progress.is_bond_dialogue_triggered("bond_memory_2"))
	assert_true(progress.is_chapter_dialogue_completed("chapter_1", "choice"))
	assert_false(progress.is_chapter_dialogue_completed("chapter_1", "revelation"))
	assert_false(progress.is_chapter_dialogue_completed("chapter_1", "end"))
	manager.end_dialogue()


## 章节将要切换时，预览不改当前存档。## 输入: 无。
## 输出: 无。
func test_preview_next_does_not_mutate_when_chapter_advances() -> void:
	var progress := StoryProgress.new()
	progress.current_chapter = "chapter_1"
	var manager := _manager(progress, _temp_archive())
	for key in manager._dialogue_definitions["chapter_1"]:
		progress.mark_chapter_dialogue("chapter_1", str(key))
	var before := progress.capture_state()
	var first := manager.preview_next_entry()
	var second := manager.preview_next_entry()
	assert_eq(str(first.get("chapter", "")), "chapter_2")
	assert_eq(str(first.get("key", "")), "revelation")
	assert_eq(str(second.get("key", "")), "revelation")
	assert_eq(progress.current_chapter, "chapter_1")
	assert_true(StoryCatalog.same_snapshot(before, progress.capture_state()))


## 保存后重新读取，且原来的存档对象不被替换。## 输入: 无。
## 输出: 无。
func test_commit_round_trip_updates_same_instance() -> void:
	var live := StoryProgress.new()
	var instance_id := live.get_instance_id()
	live.current_chapter = "chapter_1"
	live.bond = 3
	live.set_flag("kept", true)
	var archive := _temp_archive()
	var replacement := StoryProgress.new()
	replacement.copy_from(live)
	replacement.total_progress = 4
	replacement.trigger_threshold = 12
	replacement.mark_chapter_dialogue("chapter_2", "choice")
	var committed: Dictionary = archive.commit(live, replacement, "apply")
	assert_true(committed.success, str(committed.get("message", "")))
	assert_eq(live.get_instance_id(), instance_id)
	assert_eq(live.total_progress, 4)
	assert_true(live.is_chapter_dialogue_completed("chapter_2", "choice"))
	var loaded := ResourceLoader.load(archive.save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as StoryProgress
	assert_not_null(loaded)
	assert_eq(loaded.total_progress, 4)
	assert_eq(loaded.bond, 3)
	assert_eq(loaded.get_flag("kept"), true)
	assert_true(loaded.is_chapter_dialogue_completed("chapter_2", "choice"))


## 恢复备份后回到备份里的好感度，并保留新的备份。## 输入: 无。
## 输出: 无。
func test_restore_backup_replaces_current_story() -> void:
	var live := StoryProgress.new()
	live.current_chapter = "chapter_1"
	var archive := _temp_archive()
	var first := StoryProgress.new()
	first.copy_from(live)
	first.bond = 2
	assert_true(archive.commit(live, first, "apply").success)
	var second := StoryProgress.new()
	second.copy_from(live)
	second.bond = 9
	var committed: Dictionary = archive.commit(live, second, "apply")
	assert_true(committed.success, str(committed.get("message", "")))
	var restored: Dictionary = archive.restore(live, str(committed.get("backup", "")))
	assert_true(restored.success, str(restored.get("message", "")))
	assert_eq(live.bond, 2)
	assert_gte(archive.list_backups().size(), 3)


## 正式写入失败时保留内存和原文件。## 输入: 无。
## 输出: 无。
func test_save_failure_keeps_original_state() -> void:
	var live := StoryProgress.new()
	live.current_chapter = "chapter_1"
	live.bond = 2
	var archive := _temp_archive()
	var initial := StoryProgress.new()
	initial.copy_from(live)
	assert_true(archive.commit(live, initial, "seed").success)
	var before := FileAccess.get_file_as_bytes(archive.save_path)
	archive.save_handler = _fail_main_save.bind(archive)
	var replacement := StoryProgress.new()
	replacement.copy_from(live)
	replacement.bond = 9
	var failed: Dictionary = archive.commit(live, replacement, "apply")
	assert_false(failed.success)
	assert_string_contains(str(failed.get("message", "")), "保存")
	assert_eq(live.bond, 2)
	assert_eq(FileAccess.get_file_as_bytes(archive.save_path), before)


## 草稿读取后真实状态变化时，不能用旧草稿覆盖。## 输入: 无。
## 输出: 无。
func test_stale_draft_cannot_overwrite_live_state() -> void:
	DebugSettings.debug_mode = true
	var progress := App.get_story_progress()
	assert_not_null(progress)
	var original := progress.total_progress
	App.read_story_draft()
	var draft: Dictionary = App._draft.duplicate(true)
	draft["total_progress"] = original + 1
	App.update_story_draft(draft)
	progress.total_progress = original + 5
	var applied: Dictionary = App.apply_story_draft()
	assert_false(applied.success)
	assert_string_contains(str(applied.get("message", "")), "重新读取")
	assert_eq(progress.total_progress, original + 5)


## 调试关闭、草稿未保存或正在播放时不能启动。## 输入: 无。
## 输出: 无。
func test_launch_checks_debug_draft_and_playback() -> void:
	DebugSettings.debug_mode = false
	var closed: Dictionary = App.start_next_story()
	assert_false(closed.success)
	assert_string_contains(str(closed.get("message", "")), "调试")
	DebugSettings.debug_mode = true
	App.read_story_draft()
	var draft: Dictionary = App._draft.duplicate(true)
	draft["total_progress"] = int(draft.get("total_progress", 0)) + 2
	App.update_story_draft(draft)
	var dirty: Dictionary = App.start_next_story()
	assert_string_contains(str(dirty.get("message", "")), "未保存")
	App.clear_story_draft()
	App._story_manager._is_dialogue_active = true
	var busy: Dictionary = App.jump_to_story("chapter_1", "intro")
	assert_string_contains(str(busy.get("message", "")), "播放")
	App._story_manager.end_dialogue()
	App._dialogue_queue.append({"resource": null, "key": "queued", "story": true, "source": null})
	var queued: Dictionary = App.start_next_story()
	assert_false(queued.success)
	App._dialogue_queue.clear()


## 非法阈值不会写入，复杂标记不能被普通编辑改掉。## 输入: 无。
## 输出: 无。
func test_draft_validation_and_complex_flags() -> void:
	DebugSettings.debug_mode = true
	var progress := App.get_story_progress()
	var original := progress.trigger_threshold
	App.read_story_draft()
	var draft: Dictionary = App._draft.duplicate(true)
	draft["trigger_threshold"] = 0
	App.update_story_draft(draft)
	var applied: Dictionary = App.apply_story_draft()
	assert_false(applied.success)
	assert_string_contains(str(applied.get("message", "")), "阈值")
	assert_eq(progress.trigger_threshold, original)
	var changed := StoryCatalog.merge_flags({"matrix": {"a": 1}, "met": true}, {"matrix": {"a": 2}, "met": false})
	assert_false(changed.success)
	var merged := StoryCatalog.merge_flags({"matrix": {"a": 1}, "met": true, "bond_tier": 1}, {"met": false, "note": "x"})
	assert_true(merged.success, str(merged.get("message", "")))
	var flags: Dictionary = merged.flags
	assert_eq((flags["matrix"] as Dictionary).get("a"), 1)
	assert_eq(flags["met"], false)
	assert_eq(flags["note"], "x")
	assert_false(flags.has("bond_tier"))


## 目录显示名来自对话标题。重置剧情不会清空教程。## 输入: 无。
## 输出: 无。
func test_catalog_title_and_story_reset_keeps_tutorial() -> void:
	var progress := StoryProgress.new()
	progress.current_chapter = "chapter_1"
	var manager := _manager(progress, _temp_archive())
	var catalog: Dictionary = manager.build_catalog()
	var chapters: Array = catalog.chapters
	var entries: Array = (chapters[0] as Dictionary).entries
	assert_eq(str((entries[0] as Dictionary).get("key", "")), "intro")
	assert_eq(str((entries[0] as Dictionary).get("title", "")), "初次相遇")
	DebugSettings.debug_mode = true
	_redirect_live_archive(_temp_archive())
	var tutorial: Array[String] = []
	if TutorialManager._progress != null:
		tutorial = TutorialManager._progress.completed_ids.duplicate()
	var reset: Dictionary = App.reset_story_data()
	assert_true(reset.success, str(reset.get("message", "")))
	assert_eq(App.get_story_progress().current_chapter, "chapter_1")
	assert_eq(App.get_story_progress().bond, 0)
	assert_eq(App.get_story_progress().completed_dialogues.size(), 0)
	if TutorialManager._progress != null:
		assert_eq(TutorialManager._progress.completed_ids, tutorial)


## 调试模式决定测试台是否出现在入口列表。## 输入: 无。
## 输出: 无。
func test_story_test_entry_follows_debug_mode() -> void:
	DebugSettings.debug_mode = false
	assert_false(_visible_has("story_test"))
	DebugSettings.debug_mode = true
	assert_true(_visible_has("story_test"))
	assert_eq(WindowManager.REGISTRY["story_test"].default_size, Vector2(1100, 760))


## 创建使用临时目录的剧情管理器。## 输入: progress、archive。
## 输出: StoryManager。
func _manager(progress: StoryProgress, archive: StoryArchive) -> StoryManager:
	var manager := StoryManager.new()
	manager.setup(null, progress, archive)
	return manager


## 创建临时存档和备份目录。## 输入: 无。
## 输出: StoryArchive。
func _temp_archive() -> StoryArchive:
	var folder := "user://story_test_unit_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	_folders.append(folder)
	var archive := StoryArchive.new()
	archive.save_path = folder.path_join("story_progress.tres")
	archive.backup_dir = folder.path_join("backups")
	return archive


## 让当前游戏的后续写入进入临时目录。## 输入: archive。
## 输出: 无。
func _redirect_live_archive(archive: StoryArchive) -> void:
	App._story_manager._archive.save_path = archive.save_path
	App._story_manager._archive.backup_dir = archive.backup_dir


## 把正式存档路径放回测试前的位置。## 输入: 无。
## 输出: 无。
func _restore_live_archive() -> void:
	if App._story_manager == null or App._story_manager._archive == null or _archive_path.is_empty():
		return
	App._story_manager._archive.save_path = _archive_path
	App._story_manager._archive.backup_dir = _archive_dir


## 把内存中的剧情放回测试开始时的内容。## 输入: 无。
## 输出: 无。
func _restore_live_story() -> void:
	var progress := App.get_story_progress()
	if progress == null or _story_before.is_empty():
		return
	progress.total_progress = int(_story_before.get("total_progress", 0))
	progress.current_chapter = str(_story_before.get("current_chapter", ""))
	progress.trigger_threshold = int(_story_before.get("trigger_threshold", 10))
	progress.bond = int(_story_before.get("bond", 0))
	progress.last_triggered_at = float(_story_before.get("last_triggered_at", 0.0))
	StoryProgress.assign_strings(progress.completed_dialogues, _story_before.get("completed_dialogues", []))
	StoryProgress.assign_strings(progress.bond_dialogues_triggered, _story_before.get("bond_dialogues_triggered", []))
	var flags: Variant = _story_before.get("flags", {})
	progress.flags = flags.duplicate(true) if flags is Dictionary else {}


## 正式存档和临时文件写入失败，备份仍允许保存。## 输入: progress、path、archive。
## 输出: int，Godot 错误码。
func _fail_main_save(_progress: StoryProgress, path: String, archive: StoryArchive) -> int:
	if path == archive.save_path or path.ends_with(".tmp.tres"):
		return ERR_CANT_CREATE
	var error := ResourceSaver.save(_progress, path)
	return error


## 统计数组中某个值出现的次数。## 输入: rows、expected。
## 输出: int。
func _count(rows: Array, expected: String) -> int:
	var count := 0
	for item in rows:
		if str(item) == expected:
			count += 1
	return count


## 可见入口里是否有指定应用。## 输入: app_id。
## 输出: bool。
func _visible_has(app_id: String) -> bool:
	for entry in WindowManager.get_visible_apps():
		if str(entry.get("app_id", "")) == app_id:
			return true
	return false


## 递归删除测试临时目录。## 输入: path。
## 输出: 无。
func _remove_tree(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	var directory := DirAccess.open(absolute)
	if directory == null:
		return
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		var child := path.path_join(file_name)
		if directory.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(child))
		file_name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute)

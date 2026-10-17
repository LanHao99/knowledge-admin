extends GutTest
## 验证统一目录对文件、配置、资源与 SQLite 持久化均生效。

const DirectoryScript: GDScript = preload("res://src/save_directory.gd")
var _temporary_paths: Array[String] = []


## 删除本用例创建的文件，保留玩家存档。## 输入: 无。输出: 无。
func after_each() -> void:
	for path: String in _temporary_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_temporary_paths.clear()


## 检查目录重定向和 Autoload 初始化顺序。## 输入: 无。输出: 无。
func test_workspace_directory_is_applied_before_save_consumers() -> void:
	if OS.get_name() != "Windows" or not DirectoryScript.ENABLED:
		pending("工作区存档重定向未启用")
		return
	var expected: String = ProjectSettings.globalize_path(DirectoryScript.DIRECTORY).simplify_path()
	assert_eq(OS.get_user_data_dir().simplify_path(), expected)
	assert_eq(ProjectSettings.globalize_path("user://story_progress.tres"), expected.path_join("story_progress.tres"))
	var bootstrap: Node = get_tree().root.get_node("SaveDirectory")
	for singleton_name: String in ["DebugSettings", "UiSettings", "ShortcutSettings", "App"]:
		var singleton: Node = get_tree().root.get_node_or_null(singleton_name)
		if singleton != null:
			assert_true(bootstrap.get_index() < singleton.get_index(), singleton_name)


## 文件通过 user:// 写入后，应能从目标绝对路径读取。## 输入: 无。输出: 无。
func test_file_access_round_trip() -> void:
	var path: String = _new_path("txt")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	file.store_string("存档目录验证")
	file.close()
	assert_eq(FileAccess.get_file_as_string(_absolute_path(path)), "存档目录验证")


## 配置通过 user:// 写入后，应能被新的配置实例读回。## 输入: 无。输出: 无。
func test_config_file_round_trip() -> void:
	var path: String = _new_path("cfg")
	var config: ConfigFile = ConfigFile.new()
	config.set_value("probe", "value", 42)
	assert_eq(config.save(path), OK)
	var reloaded: ConfigFile = ConfigFile.new()
	assert_eq(reloaded.load(_absolute_path(path)), OK)
	assert_eq(reloaded.get_value("probe", "value", 0), 42)


## 剧情资源通过 user:// 保存后，应保留章节、羁绊与世界标记。## 输入: 无。输出: 无。
func test_story_resource_round_trip() -> void:
	var path: String = _new_path("tres")
	var progress: StoryProgress = StoryProgress.new()
	progress.current_chapter = "chapter_2"
	progress.bond = 9
	progress.set_flag("save_directory_probe", true)
	assert_eq(ResourceSaver.save(progress, path), OK)
	var reloaded: StoryProgress = ResourceLoader.load(_absolute_path(path), "", ResourceLoader.CACHE_MODE_IGNORE) as StoryProgress
	assert_not_null(reloaded)
	if reloaded == null:
		return
	assert_eq(reloaded.current_chapter, "chapter_2")
	assert_eq(reloaded.bond, 9)
	assert_true(reloaded.has_flag("save_directory_probe"))


## SQLite 数据库关闭后，应能从目标绝对路径重新打开并读回数据。## 输入: 无。输出: 无。
func test_sqlite_round_trip() -> void:
	var path: String = _new_path("db")
	var database: SQLite = SQLite.new()
	database.path = path
	var opened: bool = database.open_db()
	assert_true(opened)
	if not opened:
		return
	assert_true(database.query("CREATE TABLE probe (value INTEGER);"))
	assert_true(database.query("INSERT INTO probe VALUES (42);"))
	database.close_db()
	assert_true(FileAccess.file_exists(_absolute_path(path)))
	var reloaded: SQLite = SQLite.new()
	reloaded.path = _absolute_path(path)
	opened = reloaded.open_db()
	assert_true(opened)
	if not opened:
		return
	assert_true(reloaded.query("SELECT value FROM probe;"))
	assert_eq(reloaded.query_result, [{"value": 42}])
	reloaded.close_db()


## 创建唯一测试文件路径，并登记到清理列表。## 输入: extension (String) - 扩展名。输出: String。
func _new_path(extension: String) -> String:
	var path: String = "user://save_directory_probe_%d.%s" % [Time.get_ticks_usec(), extension]
	_temporary_paths.append(path)
	return path


## 返回测试文件在实际存档目录中的绝对路径。## 输入: path (String) - user:// 文件路径。输出: String。
func _absolute_path(path: String) -> String:
	return OS.get_user_data_dir().path_join(path.get_file())
